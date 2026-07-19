//
//  TbSplashAdapter.m
//  FlameSDK
//
//  Created by flame.
//  Copyright © 2026 Flame. All rights reserved.
//

#import "TbSplashAdapter.h"
#import "FlameLogger.h"
#import <WindMillSDK/WindMillSDK.h>

// 注：与 Reward/Interstitial 不同，Splash 的 show 取 UIWindow*（协议 show:(UIWindow *)window），
// 不需要动态解析顶层 VC，因此不需要 flame_topViewController() 静态函数。

@implementation TbSplashAdapter {
    /// finishOnce 幂等标记：skip/close 即使连续到达，onAdClosed 也只通知业务一次。
    /// 每次 loadWithUserId: 重置为 NO，destroy 时也清零。
    BOOL _didFinish;
}

- (instancetype)initWithViewController:(UIViewController *)viewController
                           placementId:(NSString *)placementId
                               listener:(id<FlameSplashListener>)listener {
    self = [super init];
    if (self) {
        _viewController = viewController;
        _placementId = [placementId copy];
        _listener = listener;
        _didFinish = NO;
    }
    return self;
}

#pragma mark - FlameSplashAdapterProtocol

- (void)load {
    [self loadWithUserId:nil userCustomData:nil];
}

- (void)loadWithUserId:(NSString *)userId
        userCustomData:(NSString *)userCustomData {
    (void)userId;          // WindMill 开屏的 WindMillAdRequest 仅用 placementId（userId/customData 是激励专用，开屏忽略）
    (void)userCustomData;

    if (self.placementId == nil || self.placementId.length == 0) {
        [FlameLogger e:[NSString stringWithFormat:@"[TB_SPLASH_DIAG] load: placementId empty, adapter=%p", self]];
        if (self.listener && [self.listener respondsToSelector:@selector(onAdError:desc:)]) {
            [self.listener onAdError:@"14004" desc:@"ToBid Splash: placementId is empty"];
        }
        return;
    }

    [FlameLogger i:[NSString stringWithFormat:@"[TB_SPLASH_DIAG] load: adapter=%p oldAd=%p placementId=%@ thread=%d",
        self, self.splashAd, self.placementId, [NSThread isMainThread]]];

    // 清除旧对象（防止 stale delegate，参考 TbRewardAdapter/TbInterstitialAdapter 验证模式）
    if (self.splashAd) {
        self.splashAd.delegate = nil;
        self.splashAd = nil;
    }
    // 重置 finishOnce 标记（新一轮开始）
    _didFinish = NO;

    // 创建 WindMillAdRequest 并设置 placementId（与 Reward/Interstitial 同一 builder）
    WindMillAdRequest *request = [WindMillAdRequest request];
    request.placementId = self.placementId;

    // 创建 WindMillSplashAd 并加载
    // 注意：开屏加载方法是 loadAd（不是 Reward/Interstitial 的 loadAdData）
    self.splashAd = [[WindMillSplashAd alloc] initWithRequest:request];
    self.splashAd.delegate = self;
    // rootViewController 仅作 host VC（ToBid SDK 内部用于转场/详情页），show 不直接取它
    self.splashAd.rootViewController = self.viewController;
    [self.splashAd loadAd];

    [FlameLogger i:[NSString stringWithFormat:@"[TB_SPLASH_DIAG] load created: adapter=%p newAd=%p", self, self.splashAd]];
}

- (BOOL)isReady {
    if (!self.splashAd) return NO;
    return self.splashAd.isAdReady;
}

- (BOOL)isLoading {
    // WindMill SDK 未暴露 isLoading 属性，与 TbRewardAdapter/TbInterstitialAdapter 一致返回 NO
    return NO;
}

- (void)show:(UIWindow *)window {
    // ready 守卫（与 AtSplashAdapter/TbInterstitialAdapter 一致的防御性检查）
    if (!self.splashAd || !self.splashAd.isAdReady) {
        [FlameLogger e:[NSString stringWithFormat:@"[TB_SPLASH_DIAG] show: NOT READY, skipping (adapter=%p ad=%p)",
            self, self.splashAd]];
        if (self.listener && [self.listener respondsToSelector:@selector(onAdError:desc:)]) {
            [self.listener onAdError:@"AD_NOT_READY" desc:@"ToBid Splash ad is not ready to show"];
        }
        return;
    }

    // window 守卫（与 AtSplashAdapter 一致：window 是 show 的必需参数）
    if (window == nil) {
        [FlameLogger e:[NSString stringWithFormat:@"[TB_SPLASH_DIAG] show: window nil, skipping (adapter=%p ad=%p)",
            self, self.splashAd]];
        if (self.listener && [self.listener respondsToSelector:@selector(onAdError:desc:)]) {
            [self.listener onAdError:@"INVALID_PARAMETER" desc:@"The 'window' parameter is required and cannot be nil."];
        }
        return;
    }

    [FlameLogger i:[NSString stringWithFormat:@"[TB_SPLASH_DIAG] show: adapter=%p ad=%p window=%p thread=%d ready=%d",
        self, self.splashAd, window, [NSThread isMainThread], self.splashAd.isAdReady]];

    // 展示开屏广告（与 Reward/Interstitial 不同：开屏取 UIWindow*，不是 showAdFromRootViewController:）
    [self.splashAd showAdInWindow:window withBottomView:nil];
}

- (void)destroy {
    if (self.splashAd) {
        self.splashAd.delegate = nil;
        self.splashAd = nil;
    }
    self.listener = nil;
    self.viewController = nil;
    _didFinish = NO;
}

#pragma mark - finishOnce 幂等（skip/close/showFailure 收敛到一次 onAdClosed）

/// 保证业务完成回调（onAdClosed）最多触发一次。
/// ToBid 开屏可能分别/连续触发 skip、close、countdown、showFailure，
/// Flame 的 FlameSplashListener 没有 skip/willClose/showFailure 回调，
/// 一律坍缩到 onAdClosed（点击不视为 close）。
- (void)finishOnceWithReason:(NSString *)reason {
    if (_didFinish) {
        [FlameLogger w:[NSString stringWithFormat:@"[TB_SPLASH_DIAG] finish already done: reason=%@ ad=%p",
            reason, self.splashAd]];
        return;
    }
    _didFinish = YES;
    [FlameLogger i:[NSString stringWithFormat:@"[TB_SPLASH_DIAG] finish: reason=%@ ad=%p", reason, self.splashAd]];
    if (self.listener && [self.listener respondsToSelector:@selector(onAdClosed)]) {
        [self.listener onAdClosed];
    }
}

#pragma mark - WindMillSplashAdDelegate（ToBid 回调映射到 FlameSplashListener）

/// 加载成功（→ onAdLoaded）
- (void)onSplashAdDidLoad:(WindMillSplashAd *)splashAd {
    [FlameLogger i:[NSString stringWithFormat:@"[TB_SPLASH_DIAG] didLoad: ad=%p adapter=%p isCurrent=%d",
        splashAd, self, splashAd == self.splashAd]];
    if (splashAd != self.splashAd) {
        [FlameLogger w:[NSString stringWithFormat:@"[TB_SPLASH_DIAG] stale callback ignored: callbackAd=%p currentAd=%p",
            splashAd, self.splashAd]];
        return;
    }
    if ([self.listener respondsToSelector:@selector(onAdLoaded)]) {
        [self.listener onAdLoaded];
    }
}

/// 加载失败（→ onAdError:desc:）
- (void)onSplashAdLoadFail:(WindMillSplashAd *)splashAd error:(NSError *)error {
    [FlameLogger e:[NSString stringWithFormat:@"[TB_SPLASH_DIAG] didLoadFail: ad=%p isCurrent=%d code=%ld desc=%@",
        splashAd, splashAd == self.splashAd, (long)error.code, error.localizedDescription]];
    if (splashAd != self.splashAd) {
        [FlameLogger w:[NSString stringWithFormat:@"[TB_SPLASH_DIAG] stale callback ignored: callbackAd=%p currentAd=%p",
            splashAd, self.splashAd]];
        return;
    }
    if ([self.listener respondsToSelector:@selector(onAdError:desc:)]) {
        NSString *code = error ? [NSString stringWithFormat:@"%ld", (long)error.code] : @"14001";
        NSString *desc = error ? error.localizedDescription : @"ToBid Splash load failed";
        [self.listener onAdError:code desc:desc];
    }
}

/// 即将曝光（仅日志，FlameSplashListener 无对应回调）
- (void)onSplashAdWillPresentScreen:(WindMillSplashAd *)splashAd {
    [FlameLogger i:[NSString stringWithFormat:@"[TB_SPLASH_DIAG] willPresent: ad=%p isCurrent=%d",
        splashAd, splashAd == self.splashAd]];
}

/// 曝光成功（→ onAdShow）
- (void)onSplashAdSuccessPresentScreen:(WindMillSplashAd *)splashAd {
    [FlameLogger i:[NSString stringWithFormat:@"[TB_SPLASH_DIAG] didPresent(didVisible): ad=%p isCurrent=%d",
        splashAd, splashAd == self.splashAd]];
    if (splashAd != self.splashAd) {
        [FlameLogger w:[NSString stringWithFormat:@"[TB_SPLASH_DIAG] stale callback ignored: callbackAd=%p currentAd=%p",
            splashAd, self.splashAd]];
        return;
    }
    if ([self.listener respondsToSelector:@selector(onAdShow)]) {
        [self.listener onAdShow];
    }
}

/// 展示失败（→ onAdError:desc:）
- (void)onSplashAdFailToPresent:(WindMillSplashAd *)splashAd withError:(NSError *)error {
    [FlameLogger e:[NSString stringWithFormat:@"[TB_SPLASH_DIAG] presentFail: ad=%p isCurrent=%d code=%ld desc=%@",
        splashAd, splashAd == self.splashAd, (long)error.code, error.localizedDescription]];
    if (splashAd != self.splashAd) {
        [FlameLogger w:[NSString stringWithFormat:@"[TB_SPLASH_DIAG] stale callback ignored: callbackAd=%p currentAd=%p",
            splashAd, self.splashAd]];
        return;
    }
    if ([self.listener respondsToSelector:@selector(onAdError:desc:)]) {
        NSString *code = error ? [NSString stringWithFormat:@"%ld", (long)error.code] : @"14001";
        NSString *desc = error.localizedDescription ?: @"ToBid Splash show failed";
        [self.listener onAdError:code desc:desc];
    }
}

/// 点击（→ onAdClicked）。注意：click 不视为 close，不触发 finishOnce。
- (void)onSplashAdClicked:(WindMillSplashAd *)splashAd {
    [FlameLogger i:[NSString stringWithFormat:@"[TB_SPLASH_DIAG] didClick: ad=%p isCurrent=%d",
        splashAd, splashAd == self.splashAd]];
    if (splashAd != self.splashAd) {
        return;
    }
    if ([self.listener respondsToSelector:@selector(onAdClicked)]) {
        [self.listener onAdClicked];
    }
}

/// 跳过（→ finishOnce("skip") → onAdClosed，幂等）。
/// 注意：ToBid 头文件方法名是 onSplashAdSkiped（单 p，原文如此）。
- (void)onSplashAdSkiped:(WindMillSplashAd *)splashAd {
    [FlameLogger i:[NSString stringWithFormat:@"[TB_SPLASH_DIAG] didSkip: ad=%p isCurrent=%d",
        splashAd, splashAd == self.splashAd]];
    if (splashAd != self.splashAd) {
        [FlameLogger w:[NSString stringWithFormat:@"[TB_SPLASH_DIAG] stale callback ignored: callbackAd=%p currentAd=%p",
            splashAd, self.splashAd]];
        return;
    }
    [self finishOnceWithReason:@"skip"];
}

/// 即将关闭（仅日志，FlameSplashListener 无对应回调）。
/// 注意：ToBid 头文件方法名是 onSplashAdWillClosed（过去式，原文如此）。
- (void)onSplashAdWillClosed:(WindMillSplashAd *)splashAd {
    [FlameLogger i:[NSString stringWithFormat:@"[TB_SPLASH_DIAG] willClose: ad=%p isCurrent=%d",
        splashAd, splashAd == self.splashAd]];
}

/// 关闭（→ finishOnce("close") → onAdClosed，幂等）。
/// 与 onSplashAdSkiped: 收敛到同一个 finishOnce，保证 skip + close 连续到达时业务只通知一次。
- (void)onSplashAdClosed:(WindMillSplashAd *)splashAd {
    [FlameLogger i:[NSString stringWithFormat:@"[TB_SPLASH_DIAG] didClose: ad=%p adapter=%p isCurrent=%d",
        splashAd, self, splashAd == self.splashAd]];
    if (splashAd != self.splashAd) {
        [FlameLogger w:[NSString stringWithFormat:@"[TB_SPLASH_DIAG] stale callback ignored: callbackAd=%p currentAd=%p",
            splashAd, self.splashAd]];
        return;
    }
    [self finishOnceWithReason:@"close"];
}

/// splash viewController 关闭（CSJ 专用 mediation 维度，Flame 无对应，空实现）
- (void)onSplashAdViewControllerDidClose:(WindMillSplashAd *)splashAd {
    [FlameLogger i:[NSString stringWithFormat:@"[TB_SPLASH_DIAG] viewControllerDidClose: ad=%p", splashAd]];
}

/// 即将展示全屏详情页（仅 groMore csj gdt，Flame 无对应，空实现）
- (void)onSplashAdWillPresentFullScreenModal:(WindMillSplashAd *)splashAd {
    [FlameLogger i:[NSString stringWithFormat:@"[TB_SPLASH_DIAG] willPresentFullScreenModal: ad=%p", splashAd]];
}

/// 关闭其他控制器（仅 groMore csj，Flame 无对应，空实现）
- (void)onSplashAdDidCloseOtherController:(WindMillSplashAd *)splashAd
                           interactionType:(enum WindMillInteractionType)interactionType {
    [FlameLogger i:[NSString stringWithFormat:@"[TB_SPLASH_DIAG] didCloseOtherController: ad=%p interactionType=%ld",
        splashAd, (long)interactionType]];
}

/// 自动加载成功（Flame 无对应回调，空实现）。
/// 注意：ToBid 头文件方法名是 onSplashAdAdDidAutoLoad（双 Ad，原文如此）。
- (void)onSplashAdAdDidAutoLoad:(WindMillSplashAd *)splashAd {
    [FlameLogger i:[NSString stringWithFormat:@"[TB_SPLASH_DIAG] didAutoLoad: ad=%p", splashAd]];
}

/// 自动加载失败（Flame 无对应回调，空实现）
- (void)onSplashAd:(WindMillSplashAd *)splashAd didAutoLoadFailWithError:(NSError *)error {
    [FlameLogger e:[NSString stringWithFormat:@"[TB_SPLASH_DIAG] didAutoLoadFail: ad=%p code=%ld desc=%@",
        splashAd, (long)error.code, error.localizedDescription]];
}

@end
