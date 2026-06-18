//
//  TbRewardAdapter.m
//  FlameSDK
//
//  Created by flame.
//  Copyright © 2026 Flame. All rights reserved.
//

// TB 平台源码宏隔离：TK 构建变体下整个文件置空，避免编译期 import WindMill/ToBid
#if defined(FLAME_BUILD_TB)

#import "TbRewardAdapter.h"
#import "FlameLogger.h"
#import <WindMillSDK/WindMillSDK.h>

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

    // 创建 WindMillRewardVideoAd 并加载
    self.rewardVideoAd = [[WindMillRewardVideoAd alloc] initWithRequest:request];
    self.rewardVideoAd.delegate = self;
    [self.rewardVideoAd loadAdData];
}

- (BOOL)isReady {
    if (!self.rewardVideoAd) return NO;
    return self.rewardVideoAd.isAdReady;
}

- (BOOL)isLoading {
    // WindMill SDK 未暴露 isLoading 属性，通过 isReady 反推
    // 加载完成后 isReady=YES，加载前/失败 isReady=NO
    return NO;
}

- (void)show {
    if (!self.rewardVideoAd || !self.rewardVideoAd.isAdReady) {
        if (self.listener && [self.listener respondsToSelector:@selector(onAdError:desc:)]) {
            [self.listener onAdError:@"AD_NOT_READY" desc:@"ToBid Reward ad is not ready to show"];
        }
        return;
    }

    [self.rewardVideoAd showAdFromRootViewController:self.viewController options:@{}];
}

- (void)destroy {
    self.rewardVideoAd.delegate = nil;
    self.rewardVideoAd = nil;
    self.listener = nil;
    self.viewController = nil;
}

#pragma mark - WindMillRewardVideoAdDelegate（ToBid 回调映射到 FlameRewardListener）

/// 加载成功
- (void)rewardVideoAdDidLoad:(WindMillRewardVideoAd *)rewardVideoAd {
    if ([self.listener respondsToSelector:@selector(onAdLoaded)]) {
        [self.listener onAdLoaded];
    }
}

/// 加载失败
- (void)rewardVideoAdDidLoad:(WindMillRewardVideoAd *)rewardVideoAd didFailWithError:(NSError *)error {
    if ([self.listener respondsToSelector:@selector(onAdError:desc:)]) {
        NSString *code = error ? [NSString stringWithFormat:@"%ld", (long)error.code] : @"14001";
        NSString *desc = error ? error.localizedDescription : @"ToBid Reward load failed";
        [self.listener onAdError:code desc:desc];
    }
}

/// 即将展示
- (void)rewardVideoAdWillVisible:(WindMillRewardVideoAd *)rewardVideoAd {
    // FlameRewardListener 无对应方法，仅记录日志
}

/// 已展示
- (void)rewardVideoAdDidVisible:(WindMillRewardVideoAd *)rewardVideoAd {
    if ([self.listener respondsToSelector:@selector(onAdShow)]) {
        [self.listener onAdShow];
    }
}

/// 展示失败
- (void)rewardVideoAdDidShowFailed:(WindMillRewardVideoAd *)rewardVideoAd error:(NSError *)error {
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
    // FlameRewardListener 无对应方法，仅记录日志
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
        NSString *userId = reward.userId ?: @"";
        NSString *transId = reward.transId ?: @"";
        [self.listener onAdReward:userId userCustomData:@"" transId:transId];
    }
}

/// 即将关闭
- (void)rewardVideoAdWillClose:(WindMillRewardVideoAd *)rewardVideoAd {
    // FlameRewardListener 无对应方法，仅记录日志
}

/// 已关闭
- (void)rewardVideoAdDidClose:(WindMillRewardVideoAd *)rewardVideoAd {
    if ([self.listener respondsToSelector:@selector(onAdClosed)]) {
        [self.listener onAdClosed];
    }
}

/// 自动加载成功
- (void)rewardVideoAdDidAutoLoad:(WindMillRewardVideoAd *)rewardVideoAd {
    // FlameRewardListener 无对应方法，仅记录日志
}

/// 自动加载失败
- (void)rewardVideoAd:(WindMillRewardVideoAd *)rewardVideoAd didAutoLoadFailWithError:(NSError *)error {
    // FlameRewardListener 无对应方法，仅记录日志
}

@end

#endif // FLAME_BUILD_TB
