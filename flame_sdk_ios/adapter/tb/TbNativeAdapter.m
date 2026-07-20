//
//  TbNativeAdapter.m
//  FlameSDK
//
//  Created by flame.
//  Copyright © 2026 Flame. All rights reserved.
//

#import "TbNativeAdapter.h"
#import "FlameLogger.h"
#import "FlameErrorCode.h"
#import <WindMillSDK/WindMillSDK.h>

@implementation TbNativeAdapter {
    /// WindMillNativeAdsManager 实例（load 后创建，strong 持有）
    WindMillNativeAdsManager *_manager;
    /// 当前选中的 WindMillNativeAd（manager 加载成功后保存）
    WindMillNativeAd *_nativeAd;
    /// 当前 WindMillNativeAdView（showInContainer 后创建，refreshData 触发渲染）
    WindMillNativeAdView *_nativeAdView;
    /// showInContainer 传入的容器（weak，Demo 持有）
    __weak UIView *_container;

    /// load 请求尺寸（来自 loadWithWidth:height:）
    CGSize _requestedSize;
    /// showInContainer 时传入容器的 bounds（用于初始化 nativeAdView frame）
    CGRect _containerBoundsAtShow;

    // ---- 状态标记（参考 TbBannerAdapter / AtNativeAdapter 模式）----
    BOOL _isLoading;                    // manager 请求中
    BOOL _loaded;                       // manager 成功且已选出 nativeAd
    BOOL _rendering;                    // refreshData 后等 render success/fail
    BOOL _rendered;                     // 模板渲染成功
    BOOL _shown;                        // 首次曝光已触发
    BOOL _destroyed;                    // destroy 后阻断迟到回调（generation 守卫）
    BOOL _selfRenderUnsupportedReported; // SelfRender 降级日志幂等
    NSInteger _generation;              // 异步块 generation（destroy/load 时 +1）
}

#pragma mark - Lifecycle

- (instancetype)initWithViewController:(UIViewController *)viewController
                          atPlacementId:(NSString *)atPlacementId
                               listener:(id<FlameNativeListener>)listener {
    self = [super init];
    if (self) {
        _viewController = viewController;
        _atPlacementId = [atPlacementId copy];
        _listener = listener;
        _renderType = FlameNativeRenderTypeExpress;  // 默认 Express（与 FlameNativeAdImpl 默认一致）
        _requestedSize = CGSizeZero;
        _generation = 0;
    }
    return self;
}

#pragma mark - FlameNativeAdapterProtocol

- (void)setRenderType:(FlameNativeRenderType)renderType {
    _renderType = renderType;
    [FlameLogger i:[NSString stringWithFormat:@"[TB_NATIVE_DIAG] setRenderType: %ld", (long)renderType]];
}

- (void)loadWithWidth:(CGFloat)width
               height:(CGFloat)height {
    [self loadWithUserId:nil userCustomData:nil width:width height:height];
}

- (void)loadWithUserId:(NSString *)userId
        userCustomData:(NSString *)userCustomData
                 width:(CGFloat)width
                height:(CGFloat)height {
    (void)userCustomData;  // WindMillAdRequest 无 userCustomData 字段（native 不用）

    // ============================================================
    // Phase 5A.18B：Native SelfRender 明确降级为"未实现"
    // （不是 ToBid 不支持，而是当前 Flame SDK 的 ToBid Native SelfRender 桥接尚未接入）
    // ============================================================
    if (_renderType == FlameNativeRenderTypeSelfRender) {
        _isLoading = NO;
        _loaded = NO;

        if (!_selfRenderUnsupportedReported) {
            _selfRenderUnsupportedReported = YES;
            [FlameLogger w:[NSString stringWithFormat:
                @"[TB_NATIVE_SELF_RENDER_NOT_IMPLEMENTED] platform=tb | mediation=ToBid | "
                "mediationSdkVersion=5.5.6 | adFormat=native | renderMode=self_render | "
                "capability=sdk_not_implemented | action=skip_request | "
                "expressNativeAffected=false | message=\"当前 SDK 的 ToBid Native 自渲染能力尚未接入\""]];
        }

        // 异步派发到主线程回调一次 onAdError（避免 load 方法内同步回调导致业务方状态未就绪）
        // 复用 ERROR_CODE_UNSUPPORTED_PLATFORM（公共错误码 14003：不支持的聚合平台）
        // 注：此场景语义为"SDK 桥接未实现"，但 Flame 公共错误体系未提供更贴切的码；
        //     错误描述明确说明"尚未接入"，与 5A.17B Banner SelfRender 降级口径一致。
        NSInteger gen = _generation;
        __weak typeof(self) weakSelf = self;
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf || strongSelf->_destroyed || strongSelf->_generation != gen) {
                return;
            }
            if (strongSelf.listener && [strongSelf.listener respondsToSelector:@selector(onAdError:desc:)]) {
                [strongSelf.listener onAdError:ERROR_CODE_UNSUPPORTED_PLATFORM
                                         desc:@"当前 SDK 的 ToBid Native 自渲染能力尚未接入"];
            }
        });
        return;
    }

    // ============================================================
    // Express 模式：参数校验（顺序与 AtBannerAdapter/AtNativeAdapter 一致）
    // ============================================================
    if (_atPlacementId == nil || _atPlacementId.length == 0) {
        [FlameLogger e:[NSString stringWithFormat:@"[TB_NATIVE_DIAG] load: placementId empty, adapter=%p", self]];
        [self notifyErrorOnMainThread:ERROR_CODE_INVALID_AD_PLACEMENT
                                 desc:@"Invalid mapping for placementId"];
        return;
    }
    if (self.viewController == nil) {
        [FlameLogger e:[NSString stringWithFormat:@"[TB_NATIVE_DIAG] load: viewController nil, adapter=%p", self]];
        [self notifyErrorOnMainThread:ERROR_CODE_INVALID_PARAM
                                 desc:@"viewController is required"];
        return;
    }
    if (width <= 0 || height <= 0 || isnan(width) || isnan(height) || isinf(width) || isinf(height)) {
        [FlameLogger e:[NSString stringWithFormat:@"[TB_NATIVE_DIAG] load: invalid size %.2f x %.2f, adapter=%p", width, height, self]];
        [self notifyErrorOnMainThread:ERROR_CODE_INVALID_PARAM
                                 desc:[NSString stringWithFormat:@"Invalid ad size: %.2f x %.2f", width, height]];
        return;
    }

    _requestedSize = CGSizeMake(width, height);

    // 清理上一轮对象（防止 stale delegate）
    [self cleanupCurrentAd];
    _generation += 1;
    _destroyed = NO;

    // 创建 WindMillAdRequest（仅设 placementId + 可选 userId）
    WindMillAdRequest *request = [WindMillAdRequest request];
    request.placementId = _atPlacementId;
    if (userId.length > 0) {
        request.userId = userId;
    }

    // 创建 WindMillNativeAdsManager
    _manager = [[WindMillNativeAdsManager alloc] initWithRequest:request];
    _manager.delegate = self;
    // adSize 设为请求尺寸（宽度驱动模板高度，参考 ToBid 官方 demo）
    _manager.adSize = _requestedSize;

    _isLoading = YES;
    _loaded = NO;
    _rendering = NO;
    _rendered = NO;
    _shown = NO;

    [FlameLogger i:[NSString stringWithFormat:
        @"[TB_NATIVE_DIAG] load: adapter=%p manager=%p placementId=%@ adSize=%@ thread=%d",
        self, _manager, _atPlacementId, NSStringFromCGSize(_manager.adSize), [NSThread isMainThread]]];

    // 加载广告（推荐 count=1，与 Banner 单条一致）
    [_manager loadAdDataWithCount:1];
}

- (BOOL)isLoading {
    return _isLoading;
}

- (BOOL)isReady {
    // Express 模式：需要 nativeAd 存在 + nativeAd.ready + loaded + 未 destroy
    // （与 AtNativeAdapter 语义一致：load 成功即可 show，render 在 showInContainer 触发）
    if (_destroyed) return NO;
    if (_renderType != FlameNativeRenderTypeExpress) return NO;
    if (!_loaded || _nativeAd == nil) return NO;
    return _nativeAd.ready;
}

- (void)showInContainer:(UIView *)container {
    // SelfRender 模式：安全 no-op（load 阶段已 onAdError，这里不重复回调）
    if (_renderType == FlameNativeRenderTypeSelfRender) {
        [FlameLogger i:@"[TB_NATIVE_DIAG] showInContainer: SelfRender mode not implemented, no-op"];
        return;
    }

    // 前置校验
    if (_destroyed) {
        [FlameLogger w:@"[TB_NATIVE_DIAG] showInContainer: adapter destroyed"];
        return;
    }
    if (container == nil) {
        [FlameLogger w:@"[TB_NATIVE_DIAG] showInContainer: container nil"];
        return;
    }
    if (_nativeAd == nil || !_nativeAd.ready || !_loaded) {
        [FlameLogger w:[NSString stringWithFormat:
            @"[TB_NATIVE_DIAG] showInContainer: not ready (nativeAd=%p loaded=%d)", _nativeAd, _loaded]];
        return;
    }
    if (_rendering || _rendered) {
        [FlameLogger w:@"[TB_NATIVE_DIAG] showInContainer: already rendering/rendered, skip"];
        return;
    }

    _container = container;
    _containerBoundsAtShow = container.bounds;

    // 清理旧 NativeAdView（若存在）
    if (_nativeAdView) {
        _nativeAdView.delegate = nil;
        [_nativeAdView unregisterDataObject];
        [_nativeAdView removeFromSuperview];
        _nativeAdView = nil;
    }

    // 创建 WindMillNativeAdView，初始 frame 用容器宽度 + 请求高度（模板会在 renderSuccess 后更新真实高度）
    CGFloat viewWidth = _containerBoundsAtShow.size.width > 0 ? _containerBoundsAtShow.size.width : _requestedSize.width;
    CGFloat viewHeight = _requestedSize.height > 0 ? _requestedSize.height : 100;
    CGRect initialFrame = CGRectMake(0, 0, viewWidth, viewHeight);

    _nativeAdView = [[WindMillNativeAdView alloc] initWithFrame:initialFrame];
    _nativeAdView.delegate = self;
    _nativeAdView.viewController = self.viewController;

    [FlameLogger i:[NSString stringWithFormat:
        @"[TB_NATIVE_DIAG] showInContainer: container=%p nativeAdView=%p initialFrame=%@ feedADMode=%u",
        container, _nativeAdView, NSStringFromCGRect(initialFrame), (unsigned int)_nativeAd.feedADMode]];

    // 绑定物料 → 触发 Native Express 异步模板渲染
    _rendering = YES;
    _rendered = NO;
    [_nativeAdView refreshData:_nativeAd];
}

- (void)remove {
    // 软移除：从容器移除 view，但不销毁实例（与 AtNativeAdapter.remove 一致）
    [FlameLogger i:[NSString stringWithFormat:@"[TB_NATIVE_DIAG] remove: nativeAdView=%p", _nativeAdView]];
    if (_nativeAdView) {
        [_nativeAdView removeFromSuperview];
    }
}

- (void)destroy {
    [FlameLogger i:[NSString stringWithFormat:
        @"[TB_NATIVE_DIAG] destroy: adapter=%p manager=%p nativeAd=%p nativeAdView=%p",
        self, _manager, _nativeAd, _nativeAdView]];

    _destroyed = YES;
    _generation += 1;  // 失效所有迟到异步块

    [self cleanupCurrentAd];

    _isLoading = NO;
    _loaded = NO;
    _rendering = NO;
    _rendered = NO;
    _shown = NO;
    _listener = nil;
    _viewController = nil;
    _atPlacementId = nil;
    _requestedSize = CGSizeZero;
    _container = nil;
}

#pragma mark - WindMillNativeAdsManagerDelegate（load 成功/失败）

/// 加载成功
- (void)nativeAdsManagerSuccessToLoad:(WindMillNativeAdsManager *)nativeAdsManager {
    [FlameLogger i:[NSString stringWithFormat:
        @"[TB_NATIVE_DIAG] managerSuccessToLoad: callbackManager=%p currentManager=%p isCurrent=%d",
        nativeAdsManager, _manager, nativeAdsManager == _manager]];

    // stale 守卫
    if (nativeAdsManager != _manager) {
        [FlameLogger w:@"[TB_NATIVE_DIAG] stale callback ignored: manager mismatch"];
        return;
    }
    if (_destroyed) {
        [FlameLogger w:@"[TB_NATIVE_DIAG] stale callback ignored: destroyed"];
        return;
    }

    _isLoading = NO;

    // 选第一个有效广告（参考官方 demo）
    NSArray<WindMillNativeAd *> *ads = [_manager getAllNativeAds];
    WindMillNativeAd *selected = nil;
    for (WindMillNativeAd *ad in ads) {
        if (ad != nil && ad.ready) {
            selected = ad;
            break;
        }
    }

    if (selected == nil) {
        [FlameLogger e:[NSString stringWithFormat:
            @"[TB_NATIVE_DIAG] managerSuccessToLoad: no valid ad in %lu ads", (unsigned long)ads.count]];
        [self notifyErrorOnMainThread:ERROR_CODE_NETWORK_ERROR
                                 desc:@"ToBid Native load returned no valid ad"];
        return;
    }

    // ============================================================
    // feedADMode 保护：只接受 NativeExpress（模板渲染）
    // ============================================================
    if (selected.feedADMode != WindMillFeedADModeNativeExpress) {
        [FlameLogger e:[NSString stringWithFormat:
            @"[TB_NATIVE_DIAG] feedADMode mismatch: got=%u (expected NativeExpress=5)", (unsigned int)selected.feedADMode]];
        [self notifyErrorOnMainThread:ERROR_CODE_INVALID_AD_PLACEMENT
                                 desc:@"当前 ToBid Native 广告位未返回模板渲染广告，请检查后台渲染模式配置"];
        return;
    }

    _nativeAd = selected;
    _loaded = YES;

    [FlameLogger i:[NSString stringWithFormat:
        @"[TB_NATIVE_DIAG] ad selected: nativeAd=%p feedADMode=%u ready=%d isVideoAd=%d",
        _nativeAd, (unsigned int)_nativeAd.feedADMode, _nativeAd.ready, _nativeAd.isVideoAd]];

    // 通知业务：数据加载成功（不在此时触发曝光，等 Demo 调 showInContainer）
    // 与 TK AtNativeAdapter 语义一致：load success → onAdLoaded → Demo 调 show → 渲染+曝光
    if (self.listener && [self.listener respondsToSelector:@selector(onAdLoaded)]) {
        // 异步派发到主线程（manager 回调可能不在主线程）
        NSInteger gen = _generation;
        __weak typeof(self) weakSelf = self;
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf || strongSelf->_destroyed || strongSelf->_generation != gen) {
                return;
            }
            if (strongSelf.listener && [strongSelf.listener respondsToSelector:@selector(onAdLoaded)]) {
                [strongSelf.listener onAdLoaded];
            }
        });
    }
}

/// 加载失败
- (void)nativeAdsManager:(WindMillNativeAdsManager *)nativeAdsManager didFailWithError:(NSError *)error {
    [FlameLogger e:[NSString stringWithFormat:
        @"[TB_NATIVE_DIAG] managerDidFail: callbackManager=%p isCurrent=%d code=%ld desc=%@",
        nativeAdsManager, nativeAdsManager == _manager, (long)error.code, error.localizedDescription]];

    if (nativeAdsManager != _manager) {
        [FlameLogger w:@"[TB_NATIVE_DIAG] stale callback ignored: manager mismatch"];
        return;
    }
    if (_destroyed) {
        [FlameLogger w:@"[TB_NATIVE_DIAG] stale callback ignored: destroyed"];
        return;
    }

    _isLoading = NO;
    _loaded = NO;

    // 保留 ToBid 错误码 + 描述的可诊断信息（不伪装成 unsupported）
    NSString *code = [NSString stringWithFormat:@"%ld", (long)error.code];
    NSString *desc = error.localizedDescription ?: @"ToBid Native load failed";
    [self notifyErrorOnMainThread:code desc:desc];
}

// 自动加载（播放中）—— 仅日志
- (void)nativeAdsManagerSuccessAutoToLoad:(WindMillNativeAdsManager *)nativeAdsManager {
    [FlameLogger i:@"[TB_NATIVE_DIAG] managerSuccessAutoToLoad (log only)"];
}

- (void)nativeAdsManager:(WindMillNativeAdsManager *)nativeAdsManager didAutoFailWithError:(NSError *)error {
    [FlameLogger i:[NSString stringWithFormat:@"[TB_NATIVE_DIAG] managerDidAutoFail (log only): %@", error.localizedDescription]];
}

#pragma mark - WindMillNativeAdViewDelegate（渲染/曝光/点击/dislike）

/// Native Express 模板渲染成功（只针对模板渲染）
- (void)nativeExpressAdViewRenderSuccess:(WindMillNativeAdView *)nativeAdView {
    [FlameLogger i:[NSString stringWithFormat:
        @"[TB_NATIVE_DIAG] renderSuccess: callbackView=%p currentView=%p isCurrent=%d frame=%@",
        nativeAdView, _nativeAdView, nativeAdView == _nativeAdView, NSStringFromCGRect(nativeAdView.frame)]];

    if (nativeAdView != _nativeAdView) {
        [FlameLogger w:@"[TB_NATIVE_DIAG] stale callback ignored: view mismatch"];
        return;
    }
    if (_destroyed) {
        [FlameLogger w:@"[TB_NATIVE_DIAG] stale callback ignored: destroyed"];
        return;
    }

    _rendering = NO;
    _rendered = YES;

    // ============================================================
    // 动态高度处理（本阶段重点）
    // 模板渲染后 nativeAdView.frame.size.height 已由 ToBid 动态更新（WindMillSDK.h:2143 注释）
    // 策略（保守，不修改公共 API、不强行拉伸）：
    // - 读取 nativeAdView.bounds.size.height 作为真实渲染高度
    // - 若高度 > 0，使用真实高度；否则回退请求高度
    // - 把 nativeAdView 加进 container，frame 设为容器宽度 × 真实高度
    // - 不修改 SwiftUI/AutoLayout 管理的 container frame（container 由 Demo 管理）
    //   只设置 nativeAdView 自己的 frame，加为 container 子视图
    // ============================================================
    UIView *container = _container;
    if (container == nil) {
        [FlameLogger w:@"[TB_NATIVE_DIAG] renderSuccess: container nil (released?), skip addSubview"];
        return;
    }

    CGFloat renderWidth = container.bounds.size.width > 0 ? container.bounds.size.width : _requestedSize.width;
    CGFloat renderHeight = nativeAdView.bounds.size.height > 0 ? nativeAdView.bounds.size.height : _requestedSize.height;

    // 不拉伸模板广告：宽度用容器宽，高度用模板真实值
    nativeAdView.frame = CGRectMake(0, 0, renderWidth, renderHeight);

    [container addSubview:nativeAdView];

    [FlameLogger i:[NSString stringWithFormat:
        @"[TB_NATIVE_DIAG] renderSuccess addSubview: container=%p nativeAdView=%p finalFrame=%@ requestedSize=%@",
        container, nativeAdView, NSStringFromCGRect(nativeAdView.frame), NSStringFromCGSize(_requestedSize)]];

    // 不在此触发 onAdShow —— 曝光必须来自 ToBid 的 nativeAdViewWillExpose: 真实回调
}

/// Native Express 模板渲染失败（只针对模板渲染）
- (void)nativeExpressAdViewRenderFail:(WindMillNativeAdView *)nativeAdView error:(NSError *)error {
    [FlameLogger e:[NSString stringWithFormat:
        @"[TB_NATIVE_DIAG] renderFail: callbackView=%p isCurrent=%d code=%ld desc=%@",
        nativeAdView, nativeAdView == _nativeAdView, (long)error.code, error.localizedDescription]];

    if (nativeAdView != _nativeAdView) {
        [FlameLogger w:@"[TB_NATIVE_DIAG] stale callback ignored: view mismatch"];
        return;
    }
    if (_destroyed) {
        [FlameLogger w:@"[TB_NATIVE_DIAG] stale callback ignored: destroyed"];
        return;
    }

    _rendering = NO;
    _rendered = NO;

    // 清理失败的 NativeAdView
    if (_nativeAdView) {
        _nativeAdView.delegate = nil;
        [_nativeAdView unregisterDataObject];
        [_nativeAdView removeFromSuperview];
        _nativeAdView = nil;
    }

    // 返回渲染失败错误（区分于 load 失败）
    NSString *code = [NSString stringWithFormat:@"%ld", (long)error.code];
    NSString *desc = [NSString stringWithFormat:@"ToBid Native 模板渲染失败: %@", error.localizedDescription ?: @"unknown"];
    [self notifyErrorOnMainThread:code desc:desc];
}

/// 曝光回调
- (void)nativeAdViewWillExpose:(WindMillNativeAdView *)nativeAdView {
    [FlameLogger i:[NSString stringWithFormat:
        @"[TB_NATIVE_DIAG] willExpose: callbackView=%p isCurrent=%d", nativeAdView, nativeAdView == _nativeAdView]];

    if (nativeAdView != _nativeAdView) {
        [FlameLogger w:@"[TB_NATIVE_DIAG] stale callback ignored: view mismatch"];
        return;
    }
    if (_destroyed) {
        [FlameLogger w:@"[TB_NATIVE_DIAG] stale callback ignored: destroyed"];
        return;
    }

    // 避免重复首次曝光
    if (_shown) {
        return;
    }
    _shown = YES;

    if (self.listener && [self.listener respondsToSelector:@selector(onAdShow)]) {
        [self.listener onAdShow];
    }
}

/// 点击回调
- (void)nativeAdViewDidClick:(WindMillNativeAdView *)nativeAdView {
    [FlameLogger i:[NSString stringWithFormat:
        @"[TB_NATIVE_DIAG] didClick: callbackView=%p isCurrent=%d", nativeAdView, nativeAdView == _nativeAdView]];

    if (nativeAdView != _nativeAdView) {
        [FlameLogger w:@"[TB_NATIVE_DIAG] stale callback ignored: view mismatch"];
        return;
    }
    if (_destroyed) {
        return;
    }

    if (self.listener && [self.listener respondsToSelector:@selector(onAdClicked)]) {
        [self.listener onAdClicked];
    }
}

/// dislike 回调（开发者需移除视图）
- (void)nativeAdView:(WindMillNativeAdView *)nativeAdView dislikeWithReason:(NSArray<WindMillDislikeWords *> *)filterWords {
    [FlameLogger i:[NSString stringWithFormat:
        @"[TB_NATIVE_DIAG] dislike: callbackView=%p isCurrent=%d reason=%lu",
        nativeAdView, nativeAdView == _nativeAdView, (unsigned long)filterWords.count]];

    if (nativeAdView != _nativeAdView) {
        [FlameLogger w:@"[TB_NATIVE_DIAG] stale callback ignored: view mismatch"];
        return;
    }
    if (_destroyed) {
        return;
    }

    // dislike → onAdClosed（业务侧 destroy + 重新 load）
    if (self.listener && [self.listener respondsToSelector:@selector(onAdClosed)]) {
        [self.listener onAdClosed];
    }
}

/// 详情页关闭
- (void)nativeAdDetailViewClosed:(WindMillNativeAdView *)nativeAdView {
    [FlameLogger i:[NSString stringWithFormat:@"[TB_NATIVE_DIAG] detailViewClosed: view=%p", nativeAdView]];
    // 仅日志，Flame 无对应回调（与 TK AtNativeAdapter 一致）
}

/// 详情页即将展示
- (void)nativeAdDetailViewWillPresentScreen:(WindMillNativeAdView *)nativeAdView {
    [FlameLogger i:[NSString stringWithFormat:@"[TB_NATIVE_DIAG] detailWillPresent: view=%p", nativeAdView]];
    // 仅日志
}

/// 视频播放状态
- (void)nativeAdView:(WindMillNativeAdView *)nativeAdView
playerStatusChanged:(enum WindMillMediaPlayerStatus)status
            userInfo:(NSDictionary<NSString *, id> *)userInfo {
    (void)userInfo;
    [FlameLogger i:[NSString stringWithFormat:
        @"[TB_NATIVE_DIAG] playerStatusChanged: view=%p status=%d", nativeAdView, (int)status]];
    // 仅日志（Flame Native Listener 无视频回调）
}

/// 视频播放进度
- (void)nativeAdView:(WindMillNativeAdView *)nativeAdView
didUpdatePlaybackTime:(double)currentTime
            totalTime:(double)totalTime {
    (void)nativeAdView;
    [FlameLogger d:[NSString stringWithFormat:@"[TB_NATIVE_DIAG] playbackTime: cur=%.0f total=%.0f", currentTime, totalTime]];
}

#pragma mark - Private Helpers

/// 主线程异步回调 onAdError（避免 load 方法内同步回调导致业务方状态未就绪 + generation 守卫）
- (void)notifyErrorOnMainThread:(NSString *)code desc:(NSString *)desc {
    NSInteger gen = _generation;
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf || strongSelf->_destroyed || strongSelf->_generation != gen) {
            return;
        }
        if (strongSelf.listener && [strongSelf.listener respondsToSelector:@selector(onAdError:desc:)]) {
            [strongSelf.listener onAdError:code desc:desc];
        }
    });
}

/// 清理当前广告对象（manager + nativeAd + nativeAdView），不触发 listener 回调
- (void)cleanupCurrentAd {
    if (_nativeAdView) {
        _nativeAdView.delegate = nil;
        [_nativeAdView unregisterDataObject];
        [_nativeAdView removeFromSuperview];
        _nativeAdView = nil;
    }
    _nativeAd = nil;

    if (_manager) {
        _manager.delegate = nil;
        _manager = nil;
    }
}

@end
