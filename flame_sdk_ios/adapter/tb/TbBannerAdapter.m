//
//  TbBannerAdapter.m
//  FlameSDK
//
//  Created by flame.
//  Copyright © 2026 Flame. All rights reserved.
//

#import "TbBannerAdapter.h"
#import "FlameLogger.h"
#import "FlameErrorCode.h"
#import <WindMillSDK/WindMillSDK.h>

@implementation TbBannerAdapter {
    /// 首次加载状态（与 TK AtBannerAdapter 一致：WindMill 无 isLoading 公开属性，内部标记）
    BOOL _isLoading;
    /// 是否已成功加载过一次（用于区分首次 load 与 refresh）
    BOOL _loaded;
}

- (instancetype)initWithPlacementId:(NSString *)placementId
                         renderType:(FlameBannerRenderType)renderType
                           listener:(id<FlameBannerListener>)listener {
    self = [super init];
    if (self) {
        _placementId = [placementId copy];
        _renderType = renderType;
        _listener = listener;
        _adSize = CGSizeZero;
        _isLoading = NO;
        _loaded = NO;
    }
    return self;
}

#pragma mark - FlameBannerAdapterProtocol

- (void)loadWithWidth:(CGFloat)width
               height:(CGFloat)height
       viewController:(UIViewController *)viewController {
    [self loadWithUserId:nil userCustomData:nil width:width height:height viewController:viewController];
}

- (void)loadWithUserId:(NSString *)userId
        userCustomData:(NSString *)userCustomData
                 width:(CGFloat)width
                height:(CGFloat)height
        viewController:(UIViewController *)viewController {
    (void)userCustomData;   // WindMill 的 WindMillAdRequest 无 userCustomData 字段（banner 不用）

    // SelfRender 模式：本阶段不实现（红线 #11），明确错误返回
    if (self.renderType == FlameBannerRenderTypeSelfRender) {
        [FlameLogger w:[NSString stringWithFormat:@"[TB_BANNER_DIAG] load: SelfRender not supported in Phase 5A.16C (use Express)"]];
        if (self.listener && [self.listener respondsToSelector:@selector(onAdError:desc:)]) {
            [self.listener onAdError:ERROR_CODE_UNSUPPORTED_PLATFORM desc:@"ToBid Banner SelfRender not implemented yet"];
        }
        return;
    }

    // 参数校验（顺序与 AtBannerAdapter 一致：placement → viewController → size）
    if (self.placementId == nil || self.placementId.length == 0) {
        [FlameLogger e:[NSString stringWithFormat:@"[TB_BANNER_DIAG] load: placementId empty, adapter=%p", self]];
        if (self.listener && [self.listener respondsToSelector:@selector(onAdError:desc:)]) {
            [self.listener onAdError:ERROR_CODE_INVALID_AD_PLACEMENT desc:@"Invalid mapping for placementId"];
        }
        return;
    }
    if (viewController == nil) {
        [FlameLogger e:[NSString stringWithFormat:@"[TB_BANNER_DIAG] load: viewController nil, adapter=%p", self]];
        if (self.listener && [self.listener respondsToSelector:@selector(onAdError:desc:)]) {
            [self.listener onAdError:ERROR_CODE_INVALID_PARAM desc:@"viewController is required"];
        }
        return;
    }
    if (width <= 0 || height <= 0 || isnan(width) || isnan(height) || isinf(width) || isinf(height)) {
        [FlameLogger e:[NSString stringWithFormat:@"[TB_BANNER_DIAG] load: invalid size %.2f x %.2f, adapter=%p", width, height, self]];
        if (self.listener && [self.listener respondsToSelector:@selector(onAdError:desc:)]) {
            [self.listener onAdError:ERROR_CODE_INVALID_PARAM
                                desc:[NSString stringWithFormat:@"Invalid ad size: %.2f x %.2f", width, height]];
        }
        return;
    }

    self.viewController = viewController;
    self.adSize = CGSizeMake(width, height);

    [FlameLogger i:[NSString stringWithFormat:@"[TB_BANNER_DIAG] load: adapter=%p oldBanner=%p placementId=%@ expectSize=%@ thread=%d",
        self, self.bannerView, self.placementId, NSStringFromCGSize(self.adSize), [NSThread isMainThread]]];

    // 清除旧 Banner（防止 stale delegate，参考 AtBannerAdapter.cleanupPreparedBannerViews）
    if (self.bannerView) {
        self.bannerView.delegate = nil;
        [self.bannerView removeFromSuperview];
        self.bannerView = nil;
    }
    _isLoading = YES;
    _loaded = NO;

    // 创建 WindMillAdRequest（仅设 placementId + 可选 userId，与 Reward/Interstitial/Splash 同一 builder）
    WindMillAdRequest *request = [WindMillAdRequest request];
    request.placementId = self.placementId;
    if (userId.length > 0) {
        request.userId = userId;
    }

    // 创建 WindMillBannerView（它本身是 UIView 子类，长生命周期，auto-refresh 依赖此实例）
    // 注意：selector 是 expectSize:（camelCase），不是 expect_size:（snake_case）
    self.bannerView = [[WindMillBannerView alloc] initWithRequest:request expectSize:self.adSize];
    self.bannerView.delegate = self;
    // viewController 必须设置（ToBid 官方文档要求，用于点击跳转落地页）
    self.bannerView.viewController = viewController;

    [FlameLogger i:[NSString stringWithFormat:@"[TB_BANNER_DIAG] load created: adapter=%p newBanner=%p", self, self.bannerView]];

    // 加载广告（注意：方法是 loadAdData，不是 loadAd）
    [self.bannerView loadAdData];
}

- (BOOL)isReady {
    // WindMill 无 isAdReady/ready 属性，只有 isAdValid（填充后才有意义）
    if (!self.bannerView) return NO;
    return self.bannerView.isAdValid;
}

- (BOOL)isLoading {
    return _isLoading;
}

- (UIView *)retrieveAdView {
    // SelfRender 模式不适用（与 AtBannerAdapter 一致）
    if (self.renderType == FlameBannerRenderTypeSelfRender) {
        [FlameLogger i:@"[TB_BANNER_DIAG] retrieveAdView: SelfRender mode, use retrieveMaterials + bindMaterialAtIndex:slots: instead"];
        return nil;
    }
    if (!self.bannerView || !self.bannerView.isAdValid) {
        [FlameLogger i:@"[TB_BANNER_DIAG] retrieveAdView: banner not ready/valid, returning nil"];
        return nil;
    }
    [FlameLogger i:[NSString stringWithFormat:@"[TB_BANNER_DIAG] retrieveAdView: banner=%p adSize=%@ thread=%d",
        self.bannerView, NSStringFromCGSize(self.bannerView.adSize), [NSThread isMainThread]]];
    // 返回 strong 持有的 WindMillBannerView（由 Demo 上层 addSubview + AutoLayout）
    return self.bannerView;
}

#pragma mark - SelfRender 占位（Phase 5A.16C 不实现，红线 #11）

- (NSArray<FlameBannerAdMaterial *> *)retrieveMaterials {
    // SelfRender 专用，Express 模式返回空数组（与 AtBannerAdapter Express 行为一致）
    return @[];
}

- (void)bindMaterialAtIndex:(NSInteger)index slots:(FlameBannerAdRenderSlots *)slots {
    // SelfRender 专用，Express 模式 no-op + log
    [FlameLogger i:@"[TB_BANNER_DIAG] bindMaterialAtIndex: Express mode no-op (SelfRender not implemented in Phase 5A.16C)"];
}

- (void)unbindMaterial {
    // SelfRender 专用，Express 模式 no-op
    [FlameLogger i:@"[TB_BANNER_DIAG] unbindMaterial: Express mode no-op"];
}

- (void)remove {
    // 软移除（与 AtBannerAdapter Express 一致：view 由上层管理，仅 log）
    [FlameLogger i:@"[TB_BANNER_DIAG] remove: view is managed by upper layer (Demo), please set your view reference to nil"];
}

- (void)destroy {
    [FlameLogger i:[NSString stringWithFormat:@"[TB_BANNER_DIAG] destroy: adapter=%p banner=%p hasSuperview=%d",
        self, self.bannerView, (self.bannerView.superview != nil)]];
    // 清理 WindMillBannerView（ToBid 无 destroy 方法，按官方文档：delegate=nil + removeFromSuperview + 释放强引用）
    if (self.bannerView) {
        self.bannerView.delegate = nil;
        [self.bannerView removeFromSuperview];
        self.bannerView = nil;
    }
    _isLoading = NO;
    _loaded = NO;
    _listener = nil;
    _viewController = nil;
    _adSize = CGSizeZero;
}

#pragma mark - WindMillBannerViewDelegate（ToBid 回调映射到 FlameBannerListener）
// 注意 selector label 按头文件原样（拼写错误保留）：
//   bannerAdViewFailedToLoad:error:        （label 是 error:）
//   bannerView:failedToAutoRefreshWithError: （第一参数 bannerView:，第二 failedToAutoRefreshWithError:）

/// 加载成功（首次 + 状态就绪 → onAdLoaded）
- (void)bannerAdViewLoadSuccess:(WindMillBannerView *)bannerAdView {
    [FlameLogger i:[NSString stringWithFormat:@"[TB_BANNER_DIAG] didLoadSuccess: banner=%p adapter=%p isCurrent=%d adSize=%@",
        bannerAdView, self, bannerAdView == self.bannerView, NSStringFromCGSize(bannerAdView.adSize)]];
    if (bannerAdView != self.bannerView) {
        [FlameLogger w:[NSString stringWithFormat:@"[TB_BANNER_DIAG] stale callback ignored: callbackBanner=%p currentBanner=%p",
            bannerAdView, self.bannerView]];
        return;
    }
    _isLoading = NO;
    _loaded = YES;
    // 按官方文档：用 bannerView.adSize 更新 frame（不是 self.adSize 期望值）
    if (!CGSizeEqualToSize(bannerAdView.adSize, CGSizeZero)) {
        bannerAdView.frame = CGRectMake(0, 0, bannerAdView.adSize.width, bannerAdView.adSize.height);
    }
    if ([self.listener respondsToSelector:@selector(onAdLoaded)]) {
        [self.listener onAdLoaded];
    }
}

/// 加载失败（首次 → onAdError；不内部重试，与 TK 一致）
- (void)bannerAdViewFailedToLoad:(WindMillBannerView *)bannerAdView error:(NSError *)error {
    [FlameLogger e:[NSString stringWithFormat:@"[TB_BANNER_DIAG] didFailToLoad: banner=%p isCurrent=%d code=%ld desc=%@",
        bannerAdView, bannerAdView == self.bannerView, (long)error.code, error.localizedDescription]];
    if (bannerAdView != self.bannerView) {
        [FlameLogger w:[NSString stringWithFormat:@"[TB_BANNER_DIAG] stale callback ignored: callbackBanner=%p currentBanner=%p",
            bannerAdView, self.bannerView]];
        return;
    }
    _isLoading = NO;
    if ([self.listener respondsToSelector:@selector(onAdError:desc:)]) {
        NSString *code = [NSString stringWithFormat:@"%ld", (long)error.code];
        NSString *desc = error.localizedDescription ?: @"ToBid Banner load failed";
        [self.listener onAdError:code desc:desc];
    }
}

/// 自动刷新成功（仅日志 + 更新 frame；不冒充 onAdLoaded，Flame 无 refresh 回调）
- (void)bannerAdViewDidAutoRefresh:(WindMillBannerView *)bannerAdView {
    [FlameLogger i:[NSString stringWithFormat:@"[TB_BANNER_DIAG] didAutoRefresh: banner=%p isCurrent=%d adSize=%@",
        bannerAdView, bannerAdView == self.bannerView, NSStringFromCGSize(bannerAdView.adSize)]];
    if (bannerAdView != self.bannerView) {
        [FlameLogger w:[NSString stringWithFormat:@"[TB_BANNER_DIAG] stale callback ignored: callbackBanner=%p currentBanner=%p",
            bannerAdView, self.bannerView]];
        return;
    }
    // 按官方文档：refresh 后 adSize 可能变化，更新 frame
    if (!CGSizeEqualToSize(bannerAdView.adSize, CGSizeZero)) {
        bannerAdView.frame = CGRectMake(0, 0, bannerAdView.adSize.width, bannerAdView.adSize.height);
    }
    // 不通知业务（Flame 无 refresh 回调），不重置 _loaded
}

/// 自动刷新失败（仅日志；不重试，不通知业务。ToBid 官方：首次成功后 refresh 失败 SDK 自动重试）
- (void)bannerView:(WindMillBannerView *)bannerAdView failedToAutoRefreshWithError:(NSError *)error {
    [FlameLogger e:[NSString stringWithFormat:@"[TB_BANNER_DIAG] didFailToAutoRefresh: banner=%p isCurrent=%d code=%ld desc=%@",
        bannerAdView, bannerAdView == self.bannerView, (long)error.code, error.localizedDescription]];
    if (bannerAdView != self.bannerView) {
        [FlameLogger w:[NSString stringWithFormat:@"[TB_BANNER_DIAG] stale callback ignored: callbackBanner=%p currentBanner=%p",
            bannerAdView, self.bannerView]];
        return;
    }
    // 不通知业务，不重试（ToBid SDK 自身处理 refresh 重试）
}

/// 即将曝光（→ onAdShow）
- (void)bannerAdViewWillExpose:(WindMillBannerView *)bannerAdView {
    [FlameLogger i:[NSString stringWithFormat:@"[TB_BANNER_DIAG] willExpose: banner=%p isCurrent=%d",
        bannerAdView, bannerAdView == self.bannerView]];
    if (bannerAdView != self.bannerView) {
        return;
    }
    if ([self.listener respondsToSelector:@selector(onAdShow)]) {
        [self.listener onAdShow];
    }
}

/// 点击（→ onAdClicked）
- (void)bannerAdViewDidClicked:(WindMillBannerView *)bannerAdView {
    [FlameLogger i:[NSString stringWithFormat:@"[TB_BANNER_DIAG] didClicked: banner=%p isCurrent=%d",
        bannerAdView, bannerAdView == self.bannerView]];
    if (bannerAdView != self.bannerView) {
        return;
    }
    if ([self.listener respondsToSelector:@selector(onAdClicked)]) {
        [self.listener onAdClicked];
    }
}

/// 广告视图被移除（→ onAdClosed）
- (void)bannerAdViewDidRemoved:(WindMillBannerView *)bannerAdView {
    [FlameLogger i:[NSString stringWithFormat:@"[TB_BANNER_DIAG] didRemoved: banner=%p adapter=%p isCurrent=%d",
        bannerAdView, self, bannerAdView == self.bannerView]];
    if (bannerAdView != self.bannerView) {
        [FlameLogger w:[NSString stringWithFormat:@"[TB_BANNER_DIAG] stale callback ignored: callbackBanner=%p currentBanner=%p",
            bannerAdView, self.bannerView]];
        return;
    }
    if ([self.listener respondsToSelector:@selector(onAdClosed)]) {
        [self.listener onAdClosed];
    }
}

/// 即将打开全屏落地页（仅日志，Flame 无对应回调）
- (void)bannerAdViewWillOpenFullScreen:(WindMillBannerView *)bannerAdView {
    [FlameLogger i:[NSString stringWithFormat:@"[TB_BANNER_DIAG] willOpenFullScreen: banner=%p", bannerAdView]];
}

/// 全屏落地页关闭（仅日志）
- (void)bannerAdViewCloseFullScreen:(WindMillBannerView *)bannerAdView {
    [FlameLogger i:[NSString stringWithFormat:@"[TB_BANNER_DIAG] closeFullScreen: banner=%p", bannerAdView]];
}

/// 即将离开 App（仅日志）
- (void)bannerAdViewWillLeaveApplication:(WindMillBannerView *)bannerAdView {
    [FlameLogger i:[NSString stringWithFormat:@"[TB_BANNER_DIAG] willLeaveApplication: banner=%p", bannerAdView]];
}

@end
