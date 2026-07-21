//
//  TbNativeAdapter.m
//  FlameSDK
//
//  Created by flame.
//  Copyright © 2026 Flame. All rights reserved.
//

#import "TbNativeAdapter.h"
#import "TbNativeSelfRenderView.h"
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
    /// 当前 TbNativeSelfRenderView（仅 SelfRender 模式，showInContainer 后创建）
    TbNativeSelfRenderView *_selfRenderView;
    /// showInContainer 传入的容器（weak，Demo 持有）
    __weak UIView *_container;

    /// load 请求尺寸（来自 loadWithWidth:height:）
    CGSize _requestedSize;
    /// showInContainer 时传入容器的 bounds（用于初始化 nativeAdView frame）
    CGRect _containerBoundsAtShow;

    // ---- 状态标记（参考 TbBannerAdapter / AtNativeAdapter 模式）----
    BOOL _isLoading;                    // manager 请求中
    BOOL _loaded;                       // manager 成功且已选出 nativeAd
    BOOL _rendering;                    // refreshData 后等 render success/fail（仅 Express 模板）
    BOOL _rendered;                     // 模板渲染成功（仅 Express）
    BOOL _shown;                        // 首次曝光已触发
    BOOL _destroyed;                    // destroy 后阻断迟到回调（generation 守卫）
    BOOL _fallbackReported;             // render mode 不一致 warning 已输出（幂等）
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
    // Phase 5A.18D-B：renderType 仅作偏好 hint（与 TK 对齐）
    // 请求阶段不再按 renderType 分流——所有 renderType 均统一请求 WindMillNativeAdsManager，
    // 实际渲染模式在 showInContainer: 时由 _nativeAd.feedADMode 决定（物料驱动）。
    // （原 5A.18B 的 SelfRender 拦截 + 14003 在 Native 链路已撤销；
    //  Banner SelfRender 的 14003 降级行为不受影响，仍保留在 TbBannerAdapter。）
    // ============================================================

    // 参数校验（顺序与 AtBannerAdapter/AtNativeAdapter 一致）
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
    // adSize：宽度驱动模板渲染，height 传 0 让 WindMill 按物料自己算真实高度
    // （参照 ToBid 官方 demo NativeAdViewModel.swift:64-66：height 默认 0，由 SDK 决定）
    // 若 height > 0 仍传完整高度，模板广告会被强制拉伸到该高度（如屏幕高度 874），导致变形
    // _requestedSize 仍保留原始 height 用于自渲染场景的初始 frame 兜底
    _manager.adSize = CGSizeMake(width, 0);

    _isLoading = YES;
    _loaded = NO;
    _rendering = NO;
    _rendered = NO;
    _shown = NO;

    [FlameLogger i:[NSString stringWithFormat:
        @"[TB_NATIVE_DIAG] load: adapter=%p manager=%p placementId=%@ adSize=%@ (requestedSize=%@) thread=%d",
        self, _manager, _atPlacementId, NSStringFromCGSize(_manager.adSize), NSStringFromCGSize(_requestedSize), [NSThread isMainThread]]];

    // 加载广告（推荐 count=1，与 Banner 单条一致）
    [_manager loadAdDataWithCount:1];
}

- (BOOL)isLoading {
    return _isLoading;
}

- (BOOL)isReady {
    // Phase 5A.18D-B：renderType 不再参与判断（物料驱动，与 TK 一致）
    if (_destroyed) return NO;
    if (!_loaded || _nativeAd == nil) return NO;
    return _nativeAd.ready;
}

- (void)showInContainer:(UIView *)container {
    // 前置校验（renderType 不再拦截；所有 renderType 都可进入）
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
    if (_rendering || _rendered || _shown) {
        [FlameLogger w:@"[TB_NATIVE_DIAG] showInContainer: already rendering/rendered/shown, skip"];
        return;
    }

    _container = container;
    _containerBoundsAtShow = container.bounds;

    // 清理旧 NativeAdView / SelfRenderView（若存在）
    if (_selfRenderView) {
        [_selfRenderView cleanup];
        _selfRenderView = nil;
    }
    if (_nativeAdView) {
        _nativeAdView.delegate = nil;
        [_nativeAdView unregisterDataObject];
        [_nativeAdView removeFromSuperview];
        _nativeAdView = nil;
    }

    // ============================================================
    // Phase 5A.18D-B：按 _nativeAd.feedADMode 自动分支（物料驱动，与 TK 一致）
    // ============================================================
    BOOL actualIsExpress = (_nativeAd.feedADMode == WindMillFeedADModeNativeExpress);

    // 模式不一致 warning（仅日志，不影响渲染——与 TK AtNativeAdapter.m:194-198 同构）
    BOOL preferExpress = (_renderType == FlameNativeRenderTypeExpress);
    if (preferExpress != actualIsExpress && !_fallbackReported) {
        _fallbackReported = YES;
        NSString *preferred = preferExpress ? @"express" : @"self_render";
        NSString *actual = actualIsExpress ? @"express" : @"self_render";
        [FlameLogger w:[NSString stringWithFormat:
            @"[TB_NATIVE_RENDER_MODE_FALLBACK] preferredRenderMode=%@ | actualFeedADMode=%u | "
            "actualRenderMode=%@ | action=render_actual_material | "
            "message=\"请求渲染偏好与实际物料模式不一致，已按物料能力渲染\"",
            preferred, (unsigned int)_nativeAd.feedADMode, actual]];
    }

    // 创建 WindMillNativeAdView
    CGFloat viewWidth = _containerBoundsAtShow.size.width > 0 ? _containerBoundsAtShow.size.width : _requestedSize.width;
    // initialFrame 高度按渲染模式区分：
    // - Express 模板：用一个保守的小值（100），等 renderSuccess 后 WindMill 按物料真实高度回写
    //   若用 _requestedSize.height（如屏幕高 874），会被 ToBid 当作模板期望高度，导致拉伸变形
    // - SelfRender 自渲染：用 _requestedSize.height 作初始值，SelfRenderView 会重新 layoutSubviews 算真实高度
    CGFloat viewHeight = actualIsExpress ? 100 : (_requestedSize.height > 0 ? _requestedSize.height : 100);
    CGRect initialFrame = CGRectMake(0, 0, viewWidth, viewHeight);
    _nativeAdView = [[WindMillNativeAdView alloc] initWithFrame:initialFrame];
    _nativeAdView.delegate = self;
    _nativeAdView.viewController = self.viewController;

    [FlameLogger i:[NSString stringWithFormat:
        @"[TB_NATIVE_DIAG] showInContainer: container=%p nativeAdView=%p initialFrame=%@ feedADMode=%u actualIsExpress=%d",
        container, _nativeAdView, NSStringFromCGRect(initialFrame), (unsigned int)_nativeAd.feedADMode, actualIsExpress]];

    if (actualIsExpress) {
        // ====== Native Express 模板渲染 ======
        // refreshData 触发 ToBid 异步模板渲染 → 等 nativeExpressAdViewRenderSuccess: 回调
        _rendering = YES;
        _rendered = NO;
        [_nativeAdView refreshData:_nativeAd];
    } else {
        // ====== Native SelfRender 自渲染（Phase 5A.18D-B 新增） ======
        [self setupSelfRenderInContainer:container viewWidth:viewWidth];
    }
}

/// Phase 5A.18D-C：SelfRender 自渲染路径（对齐官方 ToBid demo 模式）
- (void)setupSelfRenderInContainer:(UIView *)container viewWidth:(CGFloat)viewWidth {
    // 1. 先 refreshData 让 WindMill 准备 mainImageView/mediaView/logoView/dislikeButton
    //    （必须在创建 SelfRenderView 之前，让它能正确借用 WindMill 的 view）
    [self->_nativeAdView refreshData:self->_nativeAd];

    // 2. 创建 TbNativeSelfRenderView（借用 WindMill 提供的 mainImageView/mediaView/logoView/dislikeButton）
    self->_selfRenderView = [[TbNativeSelfRenderView alloc] initWithNativeAd:self->_nativeAd
                                                              nativeAdView:self->_nativeAdView
                                                              containerSize:CGSizeMake(viewWidth, 0)];

    // 3. 设置高度变化回调（icon 异步加载完成后，layoutSubviews 重算高度，回写 nativeAdView.frame.height）
    __weak typeof(self) weakSelf = self;
    self->_selfRenderView.onLayoutChanged = ^(CGFloat height) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf || strongSelf->_destroyed) return;
        if (height > 0 && strongSelf->_nativeAdView) {
            CGRect f = strongSelf->_nativeAdView.frame;
            if (f.size.height != height) {
                f.size.height = height;
                strongSelf->_nativeAdView.frame = f;
            }
        }
    };

    // 4. SelfRenderView 作为 nativeAdView 子 view，承载所有自渲染 UI 控件 + 借用的 WindMill view
    [self->_nativeAdView addSubview:self->_selfRenderView];

    // 5. 注册 clickableViews（SelfRenderView 自建 icon/title/desc/cta + WindMill 的 mainImageView/mediaView/dislikeButton）
    NSArray<UIView *> *clickables = [self->_selfRenderView clickableViews];
    [self->_nativeAdView setClickableViews:clickables];

    // 6. 将 nativeAdView 加进 Demo 容器（曝光由 nativeAdViewWillExpose: 回调触发，不在此时）
    [container addSubview:self->_nativeAdView];

    // 7. 触发首帧布局（SelfRenderView.layoutSubviews 算出真实高度，并通过 onLayoutChanged 回写）
    [self->_nativeAdView setNeedsLayout];
    [self->_nativeAdView layoutIfNeeded];

    // 8. 兜底回写一次 nativeAdView 高度（首次同步）
    CGFloat realHeight = self->_selfRenderView.frame.size.height;
    if (realHeight > 0) {
        CGRect f = self->_nativeAdView.frame;
        if (f.size.height != realHeight) {
            f.size.height = realHeight;
            self->_nativeAdView.frame = f;
        }
    }

    [FlameLogger i:[NSString stringWithFormat:
        @"[TB_NATIVE_DIAG] selfRender setup: selfRenderView=%p nativeAdView=%p "
        "clickableViews=%lu realHeight=%.1f hasMainImage=%d hasMediaView=%d hasDislike=%d",
        self->_selfRenderView, self->_nativeAdView, (unsigned long)clickables.count,
        realHeight,
        (self->_nativeAdView.mainImageView != nil),
        (self->_nativeAdView.mediaView != nil),
        (self->_nativeAdView.dislikeButton != nil)]];
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
        @"[TB_NATIVE_DIAG] destroy: adapter=%p manager=%p nativeAd=%p nativeAdView=%p selfRenderView=%p",
        self, _manager, _nativeAd, _nativeAdView, _selfRenderView]];

    _destroyed = YES;
    _generation += 1;  // 失效所有迟到异步块

    [self cleanupCurrentAd];

    _isLoading = NO;
    _loaded = NO;
    _rendering = NO;
    _rendered = NO;
    _shown = NO;
    _fallbackReported = NO;
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
    // Phase 5A.18D-B：feedADMode 不再作为强约束（物料驱动，与 TK 一致）
    // 接受所有已知 feedADMode（NativeExpress / SmallImage / LargeImage / GroupImage / PortraitImage / Video 系列），
    // 实际渲染模式在 showInContainer: 时由 _nativeAd.feedADMode 自动分支。
    // 仅对"未知 feedADMode"报错（防御性，不误判）。
    // ============================================================
    switch (selected.feedADMode) {
        case WindMillFeedADModeNativeExpress:
        case WindMillFeedADModeSmallImage:
        case WindMillFeedADModeLargeImage:
        case WindMillFeedADModeGroupImage:
        case WindMillFeedADModePortraitImage:
        case WindMillFeedADModeVideo:
        case WindMillFeedADModeVideoPortrait:
        case WindMillFeedADModeVideoLandSpace:
            // 已知模式，接受
            break;
        default:
            // 未知 feedADMode，返回 unsupported feed mode 错误（不崩溃、不误判、不强行渲染）
            [FlameLogger e:[NSString stringWithFormat:
                @"[TB_NATIVE_DIAG] unknown feedADMode: got=%u", (unsigned int)selected.feedADMode]];
            [self notifyErrorOnMainThread:ERROR_CODE_INVALID_PARAM
                                     desc:[NSString stringWithFormat:@"Unsupported native feedADMode: %u", (unsigned int)selected.feedADMode]];
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
    // 高度：优先用 WindMill 模板渲染后的真实 bounds.height
    // 兜底：若 bounds.height 异常为 0，用一个保守比例（宽度的 0.75，约 3:4 卡片比例），
    //       不用 _requestedSize.height（可能被业务设成屏幕高度 874，导致拉伸变形）
    CGFloat renderHeight = nativeAdView.bounds.size.height > 0 ? nativeAdView.bounds.size.height : (renderWidth * 0.75);

    // 不拉伸模板广告：宽度用容器宽，高度用模板真实值
    nativeAdView.frame = CGRectMake(0, 0, renderWidth, renderHeight);

    [container addSubview:nativeAdView];

    [FlameLogger i:[NSString stringWithFormat:
        @"[TB_NATIVE_DIAG] renderSuccess addSubview: container=%p nativeAdView=%p finalFrame=%@ bounds=%@ requestedSize=%@",
        container, nativeAdView, NSStringFromCGRect(nativeAdView.frame), NSStringFromCGRect(nativeAdView.bounds), NSStringFromCGSize(_requestedSize)]];

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
    if (_selfRenderView) {
        [_selfRenderView cleanup];
        _selfRenderView = nil;
    }
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
