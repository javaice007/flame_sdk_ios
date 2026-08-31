//
//  TbRewardAdapter.m
//  FlameSDK
//
//  Created by flame.
//  Copyright © 2026 Flame. All rights reserved.
//

#import "TbRewardAdapter.h"
#import "FlameLogger.h"
#import <WindMillSDK/WindMillSDK.h>

#pragma mark - TopViewController helper

/// 动态获取当前 keyWindow 的顶层 UIViewController。
/// load 时缓存的 viewController 在关闭回调→重新加载时序中可能已失效，
/// 因此 show 时需要重新获取。
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

/// load 时入参快照：ToBid 客户端发奖回调不保证回传 userId（reward.userId 依赖
/// 服务端回显），userCustomData 则完全不回传（入参只进 request.options 服务端
/// 回传参数）。发奖回调以这两个属性兜底，保证与 TK 线一致的"传入即回传"语义。
@interface TbRewardAdapter ()
@property (nonatomic, copy) NSString *loadedUserId;
@property (nonatomic, copy) NSString *loadedUserCustomData;
@end

@implementation TbRewardAdapter

- (instancetype)initWithViewController:(UIViewController *)viewController
                           placementId:(NSString *)placementId
                               listener:(id<FlameRewardListener>)listener {
    self = [super init];
    if (self) {
        _viewController = viewController;
        _placementId = [placementId copy];
        _listener = listener;
    }
    return self;
}

#pragma mark - FlameRewardAdapterProtocol

- (void)load {
    [self loadWithUserId:nil userCustomData:nil];
}

- (void)loadWithUserId:(NSString *)userId
        userCustomData:(NSString *)userCustomData {
    if (self.placementId == nil || self.placementId.length == 0) {
        if (self.listener && [self.listener respondsToSelector:@selector(onAdError:desc:)]) {
            [self.listener onAdError:@"14001" desc:@"ToBid Reward: placementId is empty"];
        }
        return;
    }

    // 入参快照：供发奖回调兜底回传（见 loadedUserId / loadedUserCustomData 注释）
    self.loadedUserId = [userId copy];
    self.loadedUserCustomData = [userCustomData copy];

    // 清除旧对象（防止 stale delegate）
    if (self.rewardVideoAd) {
        self.rewardVideoAd.delegate = nil;
        self.rewardVideoAd = nil;
    }

    // 创建 WindMillAdRequest 并设置 placementId
    WindMillAdRequest *request = [WindMillAdRequest request];
    request.placementId = self.placementId;

    // ToBid 支持 userId / rewardName / rewardAmount / options 透传
    if (userId.length > 0) {
        request.userId = userId;
    }
    if (userCustomData.length > 0) {
        // WindMillAdRequest.options 是服务端激励回传参数
        request.options = @{ @"userCustomData": userCustomData };
    }

    [FlameLogger i:[NSString stringWithFormat:@"[TB_REWARD_DIAG] load: adapter=%p oldAd=%p placementId=%@ thread=%d",
        self, self.rewardVideoAd, self.placementId, [NSThread isMainThread]]];

    // 创建 WindMillRewardVideoAd 并加载
    self.rewardVideoAd = [[WindMillRewardVideoAd alloc] initWithRequest:request];
    self.rewardVideoAd.delegate = self;
    [self.rewardVideoAd loadAdData];

    [FlameLogger i:[NSString stringWithFormat:@"[TB_REWARD_DIAG] load created: adapter=%p newAd=%p", self, self.rewardVideoAd]];
}

- (BOOL)isReady {
    if (!self.rewardVideoAd) return NO;
    return self.rewardVideoAd.isAdReady;
}

- (BOOL)isLoading {
    // WindMill SDK 未暴露 isLoading 属性，通过 isReady 反推
    return NO;
}

- (void)show {
    if (!self.rewardVideoAd || !self.rewardVideoAd.isAdReady) {
        [FlameLogger e:@"[TB_REWARD_DIAG] show: NOT READY, skipping"];
        if (self.listener && [self.listener respondsToSelector:@selector(onAdError:desc:)]) {
            [self.listener onAdError:@"AD_NOT_READY" desc:@"ToBid Reward ad is not ready to show"];
        }
        return;
    }

    // 动态获取当前顶层 VC，而不是使用 load 时缓存的旧 VC。
    // 修复：关闭回调→重新加载→第二次 show 时序中，
    // load 时缓存的 viewController 可能已不在 window 层级中。
    UIViewController *presenter = flame_topViewController();
    if (!presenter) {
        // 回退到 load 时缓存的 VC
        presenter = self.viewController;
    }

    [FlameLogger i:[NSString stringWithFormat:@"[TB_REWARD_DIAG] show: adapter=%p ad=%p presenter=%p class=%@ vcWindow=%p cachedVC=%p thread=%d",
        self, self.rewardVideoAd, presenter, NSStringFromClass([presenter class]),
        presenter.view.window, self.viewController, [NSThread isMainThread]]];

    // 更新缓存的 VC（确保后续回调中使用的 VC 是最新的）
    self.viewController = presenter;

    [self.rewardVideoAd showAdFromRootViewController:presenter options:@{}];
}

- (void)destroy {
    if (self.rewardVideoAd) {
        self.rewardVideoAd.delegate = nil;
        self.rewardVideoAd = nil;
    }
    self.listener = nil;
    self.viewController = nil;
    self.loadedUserId = nil;
    self.loadedUserCustomData = nil;
}

#pragma mark - WindMillRewardVideoAdDelegate（ToBid 回调映射到 FlameRewardListener）

/// 加载成功
- (void)rewardVideoAdDidLoad:(WindMillRewardVideoAd *)rewardVideoAd {
    [FlameLogger i:[NSString stringWithFormat:@"[TB_REWARD_DIAG] didLoad: ad=%p adapter=%p isCurrent=%d",
        rewardVideoAd, self, rewardVideoAd == self.rewardVideoAd]];
    if ([self.listener respondsToSelector:@selector(onAdLoaded)]) {
        [self.listener onAdLoaded];
    }
}

/// 加载失败
- (void)rewardVideoAdDidLoad:(WindMillRewardVideoAd *)rewardVideoAd didFailWithError:(NSError *)error {
    [FlameLogger e:[NSString stringWithFormat:@"[TB_REWARD_DIAG] didLoadFail: ad=%p code=%ld desc=%@",
        rewardVideoAd, (long)error.code, error.localizedDescription]];
    if ([self.listener respondsToSelector:@selector(onAdError:desc:)]) {
        NSString *code = error ? [NSString stringWithFormat:@"%ld", (long)error.code] : @"14001";
        NSString *desc = error ? error.localizedDescription : @"ToBid Reward load failed";
        [self.listener onAdError:code desc:desc];
    }
}

/// 即将展示
- (void)rewardVideoAdWillVisible:(WindMillRewardVideoAd *)rewardVideoAd {
    [FlameLogger i:[NSString stringWithFormat:@"[TB_REWARD_DIAG] willVisible: ad=%p", rewardVideoAd]];
}

/// 已展示
- (void)rewardVideoAdDidVisible:(WindMillRewardVideoAd *)rewardVideoAd {
    [FlameLogger i:[NSString stringWithFormat:@"[TB_REWARD_DIAG] didVisible: ad=%p", rewardVideoAd]];
    if ([self.listener respondsToSelector:@selector(onAdShow)]) {
        [self.listener onAdShow];
    }
}

/// 展示失败
- (void)rewardVideoAdDidShowFailed:(WindMillRewardVideoAd *)rewardVideoAd error:(NSError *)error {
    [FlameLogger e:[NSString stringWithFormat:@"[TB_REWARD_DIAG] showFail: ad=%p code=%ld desc=%@",
        rewardVideoAd, (long)error.code, error.localizedDescription]];
    if ([self.listener respondsToSelector:@selector(onAdError:desc:)]) {
        NSString *code = error ? [NSString stringWithFormat:@"%ld", (long)error.code] : @"14001";
        NSString *desc = error.localizedDescription ?: @"ToBid Reward show failed";
        [self.listener onAdError:code desc:desc];
    }
}

/// 点击广告
- (void)rewardVideoAdDidClick:(WindMillRewardVideoAd *)rewardVideoAd {
    if ([self.listener respondsToSelector:@selector(onAdClicked)]) {
        [self.listener onAdClicked];
    }
}

/// 点击跳过
- (void)rewardVideoAdDidClickSkip:(WindMillRewardVideoAd *)rewardVideoAd {
}

/// 视频播放完成 / 播放失败
- (void)rewardVideoAdDidPlayFinish:(WindMillRewardVideoAd *)rewardVideoAd didFailWithError:(NSError *)error {
    if (error) {
        if ([self.listener respondsToSelector:@selector(onAdError:desc:)]) {
            NSString *code = [NSString stringWithFormat:@"%ld", (long)error.code];
            [self.listener onAdError:code desc:error.localizedDescription];
        }
    } else {
        if ([self.listener respondsToSelector:@selector(onAdPlayComplete)]) {
            [self.listener onAdPlayComplete];
        }
    }
}

/// 奖励发放
- (void)rewardVideoAd:(WindMillRewardVideoAd *)rewardVideoAd reward:(WindMillRewardInfo *)reward {
    if ([self.listener respondsToSelector:@selector(onAdReward:userCustomData:transId:)]) {
        // userId：优先 ToBid 回传（WindMillRewardInfo.userId），为空回退 load 时入参（对齐 TK 线语义）
        NSString *userId = reward.userId.length > 0 ? reward.userId : (self.loadedUserId ?: @"");
        // userCustomData：ToBid 客户端回调不回传（1.0.1-alpha.2 及之前此处硬编码空串），
        // 回退 load 时入参快照
        NSString *customData = self.loadedUserCustomData ?: @"";
        // transId（业务ID/发奖对账凭证）：优先 ToBid 交易id（WindMillRewardInfo.transId，
        // "交易的唯一id"），其次三方广告源标识（thirdTransId，腾讯/百度），仍为空由 Flame
        // 生成唯一事务号兜底，保证恒非空且每次发奖互不相同
        NSString *transId = reward.transId.length > 0 ? reward.transId : reward.thirdTransId;
        if (transId.length == 0) {
            transId = [[NSUUID UUID] UUIDString];
        }
        [FlameLogger i:[NSString stringWithFormat:@"[TB_REWARD_DIAG] reward: userId=%@ transId(len=%lu) src=%@",
            userId, (unsigned long)transId.length,
            reward.transId.length > 0 ? @"windmill" : (reward.thirdTransId.length > 0 ? @"thirdTransId" : @"flame-uuid")]];
        [self.listener onAdReward:userId userCustomData:customData transId:transId];
    }
}

/// 即将关闭
- (void)rewardVideoAdWillClose:(WindMillRewardVideoAd *)rewardVideoAd {
    [FlameLogger i:[NSString stringWithFormat:@"[TB_REWARD_DIAG] willClose: ad=%p", rewardVideoAd]];
}

/// 已关闭
- (void)rewardVideoAdDidClose:(WindMillRewardVideoAd *)rewardVideoAd {
    [FlameLogger i:[NSString stringWithFormat:@"[TB_REWARD_DIAG] didClose: ad=%p adapter=%p", rewardVideoAd, self]];
    if ([self.listener respondsToSelector:@selector(onAdClosed)]) {
        [self.listener onAdClosed];
    }
}

/// 自动加载成功
- (void)rewardVideoAdDidAutoLoad:(WindMillRewardVideoAd *)rewardVideoAd {
}

/// 自动加载失败
- (void)rewardVideoAd:(WindMillRewardVideoAd *)rewardVideoAd didAutoLoadFailWithError:(NSError *)error {
}

@end

