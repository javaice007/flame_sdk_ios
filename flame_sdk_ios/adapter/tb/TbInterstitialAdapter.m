//
//  TbInterstitialAdapter.m
//  FlameSDK
//
//  Created by flame.
//  Copyright © 2026 Flame. All rights reserved.
//

#import "TbInterstitialAdapter.h"
#import "FlameLogger.h"
#import <WindMillSDK/WindMillSDK.h>

#pragma mark - TopViewController helper

/// 动态获取当前 keyWindow 的顶层 UIViewController。
/// load 时缓存的 viewController 在关闭回调→重新加载时序中可能已失效，
/// 因此 show 时需要重新获取（与 TbRewardAdapter 同一已验证修复）。
static UIViewController *flame_topViewController(void) {
    UIViewController *rootVC = nil;
    for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
        if (![scene isKindOfClass:[UIWindowScene class]]) continue;
        UIWindowScene *ws = (UIWindowScene *)scene;
        UIWindow *keyWindow = nil;
        for (UIWindow *w in ws.windows) {
            if (w.isKeyWindow) { keyWindow = w; break; }
        }
        if (!keyWindow) continue;
        rootVC = keyWindow.rootViewController;
        while (rootVC.presentedViewController && !rootVC.presentedViewController.isBeingDismissed) {
            rootVC = rootVC.presentedViewController;
        }
        if ([rootVC isKindOfClass:[UINavigationController class]]) {
            rootVC = [(UINavigationController *)rootVC visibleViewController];
        }
        if ([rootVC isKindOfClass:[UITabBarController class]]) {
            rootVC = [(UITabBarController *)rootVC selectedViewController];
        }
        if (rootVC.view.window != nil) break;
    }
    return rootVC;
}

@implementation TbInterstitialAdapter

- (instancetype)initWithViewController:(UIViewController *)viewController
                           placementId:(NSString *)placementId
                               listener:(id<FlameInterstitialListener>)listener {
    self = [super init];
    if (self) {
        _viewController = viewController;
        _placementId = [placementId copy];
        _listener = listener;
    }
    return self;
}

#pragma mark - FlameInterstitialAdapterProtocol

- (void)load {
    [self loadWithUserId:nil userCustomData:nil];
}

- (void)loadWithUserId:(NSString *)userId
        userCustomData:(NSString *)userCustomData {
    (void)userId;          // WindMill 插屏的 WindMillAdRequest 仅用 placementId（userId/customData 是激励专用，插屏忽略）
    (void)userCustomData;

    if (self.placementId == nil || self.placementId.length == 0) {
        [FlameLogger e:[NSString stringWithFormat:@"[TB_INTERSTITIAL_DIAG] load: placementId empty, adapter=%p", self]];
        if (self.listener && [self.listener respondsToSelector:@selector(onAdError:desc:)]) {
            [self.listener onAdError:@"14004" desc:@"ToBid Interstitial: placementId is empty"];
        }
        return;
    }

    [FlameLogger i:[NSString stringWithFormat:@"[TB_INTERSTITIAL_DIAG] load: adapter=%p oldAd=%p placementId=%@ thread=%d",
        self, self.intersititialAd, self.placementId, [NSThread isMainThread]]];

    // 清除旧对象（防止 stale delegate，参考 TbRewardAdapter 验证模式）
    if (self.intersititialAd) {
        self.intersititialAd.delegate = nil;
        self.intersititialAd = nil;
    }

    // 创建 WindMillAdRequest 并设置 placementId（与 Reward 同一 builder）
    WindMillAdRequest *request = [WindMillAdRequest request];
    request.placementId = self.placementId;

    // 创建 WindMillIntersititialAd 并加载
    // 注意：类名带历史拼写错误（Inter-s-i-titial），必须按此拼写
    self.intersititialAd = [[WindMillIntersititialAd alloc] initWithRequest:request];
    self.intersititialAd.delegate = self;
    [self.intersititialAd loadAdData];

    [FlameLogger i:[NSString stringWithFormat:@"[TB_INTERSTITIAL_DIAG] load created: adapter=%p newAd=%p", self, self.intersititialAd]];
}

- (BOOL)isReady {
    if (!self.intersititialAd) return NO;
    return self.intersititialAd.isAdReady;
}

- (BOOL)isLoading {
    // WindMill SDK 未暴露 isLoading 属性，与 TbRewardAdapter 一致返回 NO
    return NO;
}

- (void)show {
    if (!self.intersititialAd || !self.intersititialAd.isAdReady) {
        [FlameLogger e:[NSString stringWithFormat:@"[TB_INTERSTITIAL_DIAG] show: NOT READY, skipping (adapter=%p ad=%p)",
            self, self.intersititialAd]];
        if (self.listener && [self.listener respondsToSelector:@selector(onAdError:desc:)]) {
            [self.listener onAdError:@"AD_NOT_READY" desc:@"ToBid Interstitial ad is not ready to show"];
        }
        return;
    }

    // 动态获取当前顶层 VC，而不是使用 load 时缓存的旧 VC。
    // 修复：关闭回调→重新加载→第二次 show 时序中，
    // load 时缓存的 viewController 可能已不在 window 层级中（与 TbRewardAdapter 同一已验证修复）。
    UIViewController *presenter = flame_topViewController();
    if (!presenter) {
        // 回退到 load 时缓存的 VC
        presenter = self.viewController;
    }

    if (!presenter) {
        [FlameLogger e:[NSString stringWithFormat:@"[TB_INTERSTITIAL_DIAG] show: presenter nil, skipping (adapter=%p ad=%p cachedVC=%p)",
            self, self.intersititialAd, self.viewController]];
        if (self.listener && [self.listener respondsToSelector:@selector(onAdError:desc:)]) {
            [self.listener onAdError:@"14002" desc:@"ToBid Interstitial show failed: no valid presenter ViewController"];
        }
        return;
    }

    [FlameLogger i:[NSString stringWithFormat:@"[TB_INTERSTITIAL_DIAG] show: adapter=%p ad=%p presenter=%p class=%@ vcWindow=%p cachedVC=%p thread=%d",
        self, self.intersititialAd, presenter, NSStringFromClass([presenter class]),
        presenter.view.window, self.viewController, [NSThread isMainThread]]];

    // 更新缓存的 VC（确保后续回调中使用的 VC 是最新的）
    self.viewController = presenter;

    [self.intersititialAd showAdFromRootViewController:presenter options:@{}];
}

- (void)destroy {
    if (self.intersititialAd) {
        self.intersititialAd.delegate = nil;
        self.intersititialAd = nil;
    }
    self.listener = nil;
    self.viewController = nil;
}

#pragma mark - WindMillIntersititialAdDelegate（ToBid 回调映射到 FlameInterstitialListener）

/// 加载成功
- (void)intersititialAdDidLoad:(WindMillIntersititialAd *)intersititialAd {
    [FlameLogger i:[NSString stringWithFormat:@"[TB_INTERSTITIAL_DIAG] didLoad: ad=%p adapter=%p isCurrent=%d",
        intersititialAd, self, intersititialAd == self.intersititialAd]];
    if (intersititialAd != self.intersititialAd) {
        [FlameLogger w:[NSString stringWithFormat:@"[TB_INTERSTITIAL_DIAG] stale callback ignored: callbackAd=%p currentAd=%p",
            intersititialAd, self.intersititialAd]];
        return;
    }
    if ([self.listener respondsToSelector:@selector(onAdLoaded)]) {
        [self.listener onAdLoaded];
    }
}

/// 加载失败
- (void)intersititialAdDidLoad:(WindMillIntersititialAd *)intersititialAd didFailWithError:(NSError *)error {
    [FlameLogger e:[NSString stringWithFormat:@"[TB_INTERSTITIAL_DIAG] didLoadFail: ad=%p isCurrent=%d code=%ld desc=%@",
        intersititialAd, intersititialAd == self.intersititialAd, (long)error.code, error.localizedDescription]];
    if (intersititialAd != self.intersititialAd) {
        [FlameLogger w:[NSString stringWithFormat:@"[TB_INTERSTITIAL_DIAG] stale callback ignored: callbackAd=%p currentAd=%p",
            intersititialAd, self.intersititialAd]];
        return;
    }
    if ([self.listener respondsToSelector:@selector(onAdError:desc:)]) {
        NSString *code = error ? [NSString stringWithFormat:@"%ld", (long)error.code] : @"14001";
        NSString *desc = error ? error.localizedDescription : @"ToBid Interstitial load failed";
        [self.listener onAdError:code desc:desc];
    }
}

/// 即将展示（仅日志，FlameInterstitialListener 无对应回调）
- (void)intersititialAdWillVisible:(WindMillIntersititialAd *)intersititialAd {
    [FlameLogger i:[NSString stringWithFormat:@"[TB_INTERSTITIAL_DIAG] willVisible: ad=%p isCurrent=%d",
        intersititialAd, intersititialAd == self.intersititialAd]];
}

/// 已展示（→ onAdShow）
- (void)intersititialAdDidVisible:(WindMillIntersititialAd *)intersititialAd {
    [FlameLogger i:[NSString stringWithFormat:@"[TB_INTERSTITIAL_DIAG] didVisible: ad=%p isCurrent=%d",
        intersititialAd, intersititialAd == self.intersititialAd]];
    if (intersititialAd != self.intersititialAd) {
        [FlameLogger w:[NSString stringWithFormat:@"[TB_INTERSTITIAL_DIAG] stale callback ignored: callbackAd=%p currentAd=%p",
            intersititialAd, self.intersititialAd]];
        return;
    }
    if ([self.listener respondsToSelector:@selector(onAdShow)]) {
        [self.listener onAdShow];
    }
}

/// 展示失败（→ onAdError）
- (void)intersititialAdDidShowFailed:(WindMillIntersititialAd *)intersititialAd error:(NSError *)error {
    [FlameLogger e:[NSString stringWithFormat:@"[TB_INTERSTITIAL_DIAG] showFail: ad=%p isCurrent=%d code=%ld desc=%@",
        intersititialAd, intersititialAd == self.intersititialAd, (long)error.code, error.localizedDescription]];
    if (intersititialAd != self.intersititialAd) {
        [FlameLogger w:[NSString stringWithFormat:@"[TB_INTERSTITIAL_DIAG] stale callback ignored: callbackAd=%p currentAd=%p",
            intersititialAd, self.intersititialAd]];
        return;
    }
    if ([self.listener respondsToSelector:@selector(onAdError:desc:)]) {
        NSString *code = error ? [NSString stringWithFormat:@"%ld", (long)error.code] : @"14001";
        NSString *desc = error.localizedDescription ?: @"ToBid Interstitial show failed";
        [self.listener onAdError:code desc:desc];
    }
}

/// 点击广告（→ onAdClicked）
- (void)intersititialAdDidClick:(WindMillIntersititialAd *)intersititialAd {
    [FlameLogger i:[NSString stringWithFormat:@"[TB_INTERSTITIAL_DIAG] didClick: ad=%p isCurrent=%d",
        intersititialAd, intersititialAd == self.intersititialAd]];
    if (intersititialAd != self.intersititialAd) {
        return;
    }
    if ([self.listener respondsToSelector:@selector(onAdClicked)]) {
        [self.listener onAdClicked];
    }
}

/// 点击跳过（FlameInterstitialListener 无对应回调，空实现）
- (void)intersititialAdDidClickSkip:(WindMillIntersititialAd *)intersititialAd {
    [FlameLogger i:[NSString stringWithFormat:@"[TB_INTERSTITIAL_DIAG] didClickSkip: ad=%p", intersititialAd]];
}

/// 视频播放完成 / 播放失败
/// 插屏无 onAdPlayComplete 回调；error 时映射 onAdError，无 error 仅日志
- (void)intersititialAdDidPlayFinish:(WindMillIntersititialAd *)intersititialAd didFailWithError:(NSError *)error {
    if (error) {
        [FlameLogger e:[NSString stringWithFormat:@"[TB_INTERSTITIAL_DIAG] didPlayFinish(error): ad=%p code=%ld desc=%@",
            intersititialAd, (long)error.code, error.localizedDescription]];
        if (intersititialAd == self.intersititialAd && [self.listener respondsToSelector:@selector(onAdError:desc:)]) {
            NSString *code = [NSString stringWithFormat:@"%ld", (long)error.code];
            [self.listener onAdError:code desc:error.localizedDescription];
        }
    } else {
        [FlameLogger i:[NSString stringWithFormat:@"[TB_INTERSTITIAL_DIAG] didPlayFinish(ok): ad=%p", intersititialAd]];
    }
}

/// 关闭（→ onAdClosed）
- (void)intersititialAdDidClose:(WindMillIntersititialAd *)intersititialAd {
    [FlameLogger i:[NSString stringWithFormat:@"[TB_INTERSTITIAL_DIAG] didClose: ad=%p adapter=%p isCurrent=%d",
        intersititialAd, self, intersititialAd == self.intersititialAd]];
    if (intersititialAd != self.intersititialAd) {
        [FlameLogger w:[NSString stringWithFormat:@"[TB_INTERSTITIAL_DIAG] stale callback ignored: callbackAd=%p currentAd=%p",
            intersititialAd, self.intersititialAd]];
        return;
    }
    if ([self.listener respondsToSelector:@selector(onAdClosed)]) {
        [self.listener onAdClosed];
    }
}

/// 关闭其他控制器（CSJ 专用 mediation 维度，Flame 无对应，空实现）
- (void)intersititialAdDidCloseOtherController:(WindMillIntersititialAd *)intersititialAd
                           withInteractionType:(WindMillInteractionType)interactionType {
    [FlameLogger i:[NSString stringWithFormat:@"[TB_INTERSTITIAL_DIAG] didCloseOtherController: ad=%p interactionType=%ld",
        intersititialAd, (long)interactionType]];
}

/// 自动加载成功（Flame 无对应回调，空实现）
- (void)intersititialAdDidAutoLoad:(WindMillIntersititialAd *)intersititialAd {
    [FlameLogger i:[NSString stringWithFormat:@"[TB_INTERSTITIAL_DIAG] didAutoLoad: ad=%p", intersititialAd]];
}

/// 自动加载失败（Flame 无对应回调，空实现）
- (void)intersititialAd:(WindMillIntersititialAd *)intersititialAd didAutoLoadFailWithError:(NSError *)error {
    [FlameLogger e:[NSString stringWithFormat:@"[TB_INTERSTITIAL_DIAG] didAutoLoadFail: ad=%p code=%ld desc=%@",
        intersititialAd, (long)error.code, error.localizedDescription]];
}

@end
