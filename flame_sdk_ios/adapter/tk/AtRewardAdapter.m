//  Author: flame
//
// TK 平台源码宏隔离：TB 构建变体下整个文件置空，避免编译期 import AnyThink/TopOn
#import "AtRewardAdapter.h"
#import <AnyThinkSDK/AnyThinkSDK.h>
#import "FlameConfigManager.h"
#import "FlameErrorCode.h"
#import "FlameLogger.h"

/// 展示唯一 ID 快照（kATADDelegateExtraIDKey，ATAPI.h 注释 "a unique ID generated
/// for each impression"）。Taku 服务端激励文档（help.takuad.com/docs/msbnkj §3.2）：
/// 服务端回调的 trans_id 由 Taku 服务端生成、唯一，"对应客户端展示回调信息中的
/// getShowId()"（Android 命名，iOS 即 kATADDelegateExtraIDKey），是发奖对账的
/// 官方凭证。展示回调里捕获，发奖回调时作为 transId 使用（reward extra 未带时兜底）。
@interface AtRewardAdapter ()
@property (nonatomic, copy) NSString *capturedShowId;
@end

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
        // Taku 服务端激励官方示例（help.takuad.com/docs/msbnkj §4.2）：用户自定义数据
        // 走 kATAdLoadingExtraMediaExtraKey，随服务端激励回调 URL 回传开发者服务器。
        // 双写两个 key：UserDataKeywordKey 面向三方网络透传（既有行为），
        // MediaExtraKey 面向 Taku 服务端激励回传（官方通道，此前缺失）。
        self.localExtra[kATAdLoadingExtraMediaExtraKey] = userCustomData;
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
    self.capturedShowId = nil;

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
    // 捕获展示唯一 ID（服务端 trans_id 的客户端对应物），供发奖回调取用
    id showId = extra[kATADDelegateExtraIDKey];
    if ([showId isKindOfClass:[NSString class]] && [(NSString *)showId length] > 0) {
        self.capturedShowId = showId;
    }
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
        // transId（业务ID/发奖对账凭证）：此前读 localExtra[@"transId"]，该 key 全链路
        // 只读不写 → 恒为空（1.0.1-alpha.2 及之前，真机实测确认）。
        // 修复（按 Taku 官方文档口径）：服务端 trans_id 对应客户端"展示唯一ID"
        // （kATADDelegateExtraIDKey，ATAPI.h；Android 侧命名 getShowId()）。
        // 取值链：发奖 extra 的展示ID → 展示回调捕获的展示ID → 空串。
        // 平台未回传时保持空串，不本地伪造 id（伪造值接收方无法分辨真实来源）；
        // 排查看 [TK_REWARD_DIAG] 日志的 src= 标注。
        NSString *transId = nil;
        NSString *transIdSrc = nil;
        id extraShowId = extra[kATADDelegateExtraIDKey];
        if ([extraShowId isKindOfClass:[NSString class]] && [(NSString *)extraShowId length] > 0) {
            transId = extraShowId;
            transIdSrc = @"topon-show-id(reward-extra)";
        } else if (self.capturedShowId.length > 0) {
            transId = self.capturedShowId;
            transIdSrc = @"topon-show-id(show-captured)";
        }
        if (transId.length == 0) {
            transId = @"";
            transIdSrc = @"none(平台未回传)";
        }
        [FlameLogger i:[NSString stringWithFormat:@"[TK_REWARD_DIAG] reward: userId=%@ transId(len=%lu) src=%@",
            userId, (unsigned long)transId.length, transIdSrc]];
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

