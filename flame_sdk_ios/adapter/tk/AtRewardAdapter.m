//  Author: flame
//
// TK 平台源码宏隔离：TB 构建变体下整个文件置空，避免编译期 import AnyThink/TopOn
#if defined(FLAME_BUILD_TK) || (!defined(FLAME_BUILD_TK) && !defined(FLAME_BUILD_TB) && !defined(FLAME_BUILD_CORE))

#import "AtRewardAdapter.h"
#import <AnyThinkSDK/AnyThinkSDK.h>
#import "FlameConfigManager.h"
#import "FlameErrorCode.h"

@implementation AtRewardAdapter


- (instancetype)initWithViewController:(UIViewController *)viewController
                           atPlacementId:(NSString *)atPlacementId
                              listener:(id<FlameRewardListener>)listener{
    self = [super init];
    if (self) {
        _viewController = viewController;
        _atPlacementId = [atPlacementId copy];
        _listener = listener;
        
        _localExtra = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (void)load {
    [self loadWithUserId:nil userCustomData:nil];
}

- (void)loadWithUserId:(NSString *)userId
        userCustomData:(NSString *)userCustomData {
    // 1. 获取映射后的 TopOn PlacementId (假设 placementId 是类成员或可通过配置获取)
    // 注意：如果 placementId 是在 init 时传入的 self.atPlacementId，可直接使用
    if (self.atPlacementId == nil || self.atPlacementId.length == 0) {
        if (self.listener && [self.listener respondsToSelector:@selector(onAdError:desc:)]) {
            [self.listener onAdError:ERROR_CODE_INVALID_AD_PLACEMENT
                                desc:[NSString stringWithFormat:@"Invalid mapping for placementId"]];
        }
        return;
    }

    // 2. 将用户信息填充到 localExtra 中（TopOn 要求的特定 Key）
    if (userId.length > 0) {
        self.localExtra[kATAdLoadingExtraUserIDKey] = userId;
    }
    if (userCustomData.length > 0) {
        self.localExtra[kATAdLoadingExtraUserDataKeywordKey] = userCustomData;
    }

    // 3. 执行加载
    [[ATAdManager sharedManager] loadADWithPlacementID:self.atPlacementId
                                                 extra:self.localExtra
                                              delegate:self];
}

- (BOOL)isReady {
    if (self.atPlacementId.length == 0) return NO;
    return [[ATAdManager sharedManager] rewardedVideoReadyForPlacementID:self.atPlacementId];
}

- (BOOL)isLoading {
    if (self.atPlacementId.length == 0) return NO;
    ATCheckLoadModel *status = [[ATAdManager sharedManager] checkRewardedVideoLoadStatusForPlacementID:self.atPlacementId];
    return status ? status.isLoading : NO;
}

- (void)show {
    if (![self isReady]) {
        if (self.listener) {
            [self.listener onAdError:@"AD_NOT_READY" desc:@"Ad is not ready to show"];
        }
        return;
    }
    
    // 展示广告，无需传入特定的 Scene 可传空字符串
    [[ATAdManager sharedManager] showRewardedVideoWithPlacementID:self.atPlacementId
                                                 inViewController:self.viewController
                                                         delegate:self];
}

- (void)destroy {
    // 断开监听器引用（虽然是weak属性，但显式断开是最佳实践）
    _listener = nil;
    _viewController = nil;

    // 清理配置数据
    [_localExtra removeAllObjects];
    _localExtra = nil;

    _atPlacementId = nil;
}

#pragma mark - ATRewardedVideoDelegate (TopOn 回调)
// 加载失败
- (void)didFailToLoadADWithPlacementID:(NSString *)placementID error:(NSError *)error {
    if ([self.listener respondsToSelector:@selector(onAdError:desc:)]) {
        [self.listener onAdError:[NSString stringWithFormat:@"%ld", (long)error.code]
                                 desc:error.localizedDescription];
    }
}

// 加载成功
- (void)didFinishLoadingADWithPlacementID:(NSString *)placementID {
    if ([self.listener respondsToSelector:@selector(onAdLoaded)]) {
        [self.listener onAdLoaded];
    }
}

// 广告展示
- (void)rewardedVideoDidStartPlayingForPlacementID:(NSString *)placementID extra:(NSDictionary *)extra {
    if ([self.listener respondsToSelector:@selector(onAdShow)]) {
        [self.listener onAdShow];
    }
}

// 广告点击
- (void)rewardedVideoDidClickForPlacementID:(NSString *)placementID extra:(NSDictionary *)extra {
    if ([self.listener respondsToSelector:@selector(onAdClicked)]) {
        [self.listener onAdClicked];
    }
}

// 视频播放完成
- (void)rewardedVideoDidEndPlayingForPlacementID:(NSString *)placementID extra:(NSDictionary *)extra {
    if ([self.listener respondsToSelector:@selector(onAdPlayComplete)]) {
        [self.listener onAdPlayComplete];
    }
}

// 奖励发放
- (void)rewardedVideoDidRewardSuccessForPlacemenID:(NSString *)placementID extra:(NSDictionary *)extra {
    if ([self.listener respondsToSelector:@selector(onAdReward:userCustomData:transId:)]) {
        // TopOn 成功回调的 extra 中通常包含之前传入的透传参数
        NSString *userId = self.localExtra[kATAdLoadingExtraUserIDKey] ?: @"";
        NSString *customData = self.localExtra[kATAdLoadingExtraUserDataKeywordKey] ?: @"";
        NSString *transId = self.localExtra[@"transId"] ?: @"";
        [self.listener onAdReward:userId userCustomData:customData transId:transId];
    }
}

// 广告关闭
- (void)rewardedVideoDidCloseForPlacementID:(NSString *)placementID rewarded:(BOOL)rewarded extra:(NSDictionary *)extra {
    if ([self.listener respondsToSelector:@selector(onAdClosed)]) {
        [self.listener onAdClosed];
    }
}

// 播放失败
- (void)rewardedVideoDidFailToPlayForPlacementID:(NSString *)placementID error:(NSError *)error extra:(NSDictionary *)extra {
    if ([self.listener respondsToSelector:@selector(onAdError:desc:)]) {
        [self.listener onAdError:[NSString stringWithFormat:@"%ld", (long)error.code]
                                 desc:error.localizedDescription];
    }
}

@end

#endif // FLAME_BUILD_TK / 默认 TK
