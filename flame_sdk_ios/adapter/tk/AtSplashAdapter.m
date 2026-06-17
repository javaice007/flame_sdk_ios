//
//  AtSplashAdapter.m
//  flame_sdk_ios
//
//  Created by Flame on 2026/1/20.
//

// TK 平台源码宏隔离：TB 构建变体下整个文件置空，避免编译期 import AnyThink/TopOn
#if defined(FLAME_BUILD_TK) || (!defined(FLAME_BUILD_TK) && !defined(FLAME_BUILD_TB) && !defined(FLAME_BUILD_CORE))

#import "AtSplashAdapter.h"
#import "FlameErrorCode.h"

@implementation AtSplashAdapter

- (nonnull instancetype)initWithViewController:(nonnull UIViewController *)viewController
                                 atPlacementId:(nonnull NSString *)atPlacementId
                                      listener:(nonnull id<FlameSplashListener>)listener {
    self = [super init];
    if (self) {
        _viewController = viewController;
        _atPlacementId = [atPlacementId copy];
        _listener = listener;
        
        _localExtra = [[NSMutableDictionary alloc] init];
    }
    return self;
}

#pragma mark - FlameSpalshAd
- (void)load {
    [self loadWithUserId:nil userCustomData:nil];
}

- (void)loadWithUserId:(NSString *)userId userCustomData:(NSString *)userCustomData {
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
    
    // 3. 判定并设置开屏超时时间
    // 逻辑：如果外部没有预设 kATSplashExtraTolerateTimeoutKey，则补充默认值 5s
    if (self.localExtra[kATSplashExtraTolerateTimeoutKey] == nil) {
        self.localExtra[kATSplashExtraTolerateTimeoutKey] = @(5);
    }
    
    // 4. 执行加载
    [[ATAdManager sharedManager] loadADWithPlacementID:self.atPlacementId
                                                 extra:self.localExtra
                                              delegate:self];
}

- (BOOL)isLoading { 
    if (self.atPlacementId.length == 0) return NO;
    ATCheckLoadModel *status = [[ATAdManager sharedManager] checkSplashLoadStatusForPlacementID:self.atPlacementId];
    return status ? status.isLoading : NO;
}

- (BOOL)isReady { 
    if (self.atPlacementId.length == 0) return NO;
    return [[ATAdManager sharedManager] splashReadyForPlacementID:self.atPlacementId];
}


- (void)show:(UIWindow *)window {
    if (![self isReady]) {
        if (self.listener) {
            [self.listener onAdError:@"AD_NOT_READY" desc:@"Ad is not ready to show"];
        }
        return;
    }
    
    // 2. Window 参数严格非空校验
    if (window == nil) {
        if (self.listener && [self.listener respondsToSelector:@selector(onAdError:desc:)]) {
            [self.listener onAdError:@"INVALID_PARAMETER"
                                desc:@"The 'window' parameter is required and cannot be nil."];
        }
        // 作为 SDK，参数非法时应直接拦截，避免引发底层 SDK 崩溃
        return;
    }
    
    ATShowConfig *config = [[ATShowConfig alloc] initWithScene:@"" showCustomExt:@""];
    
    // 3.展示广告
    [[ATAdManager sharedManager] showSplashWithPlacementID:self.atPlacementId
                                                    config:config
                                                    window:window
                                          inViewController:self.viewController
                                                     extra:self.localExtra
                                                  delegate:self];
}

- (void)destroy {
    // 1. 断开监听器引用，防止回调到已销毁的逻辑层
    _listener = nil;
    
    // 2. 清空 UI 引用
    _viewController = nil;
    
    // 3. 清理配置数据
    [_localExtra removeAllObjects];
    _localExtra = nil;
    
    // 显式将 ID 置空
    _atPlacementId = nil;
}

- (void)didFailToLoadADWithPlacementID:(NSString *)placementID error:(NSError *)error { 
    if ([self.listener respondsToSelector:@selector(onAdError:desc:)]) {
        [self.listener onAdError:[NSString stringWithFormat:@"%ld", (long)error.code]
                                 desc:error.localizedDescription];
    }
}

/// Callback when the successful loading of the ad
/// 加载成功且加载流程完毕
- (void)didFinishLoadingADWithPlacementID:(NSString *)placementID {
    if ([self.listener respondsToSelector:@selector(onAdLoaded)]) {
        [self.listener onAdLoaded];
    }
}

- (void)splashDidClickForPlacementID:(nonnull NSString *)placementID extra:(nonnull NSDictionary *)extra { 
    if ([self.listener respondsToSelector:@selector(onAdClicked)]) {
        [self.listener onAdClicked];
    }
}

/// 开屏广告已关闭
/// AnyThink 的 extra["dismiss_type"] 区分关闭原因：
///   2 = ATAdCloseSkip（用户点跳过）  3 = ATAdCloseCountdown（倒计时自然结束）
/// 只有"倒计时自然结束"才算"展示完成"，触发 onAdShowComplete；
/// 点跳过只触发 onAdClosed，不触发 onAdShowComplete。
/// - Parameters:
///   - placementID: 广告位ID
///   - extra: 额外信息
- (void)splashDidCloseForPlacementID:(nonnull NSString *)placementID extra:(nonnull NSDictionary *)extra {
    NSNumber *dismissType = extra[@"dismiss_type"];
    if ([dismissType integerValue] == 3) {
        // 倒计时自然结束 = 展示完成
        if ([self.listener respondsToSelector:@selector(onAdShowComplete:userCustomData:)]) {
            NSString *userId = self.localExtra[kATAdLoadingExtraUserIDKey] ?: @"";
            NSString *customData = self.localExtra[kATAdLoadingExtraUserDataKeywordKey] ?: @"";
            [self.listener onAdShowComplete:userId userCustomData:customData];
        }
    }
    if ([self.listener respondsToSelector:@selector(onAdClosed)]) {
        [self.listener onAdClosed];
    }
}

/// 开屏广告已展示
/// AnyThink 语义：广告素材已成功展示在屏幕上（倒计时开始）。
/// 映射到 Flame 的 onAdShow（广告展示回调，无参数）。
/// - Parameters:
///   - placementID: 广告位ID
///   - extra: 额外信息
- (void)splashDidShowForPlacementID:(nonnull NSString *)placementID extra:(nonnull NSDictionary *)extra {
    if ([self.listener respondsToSelector:@selector(onAdShow)]) {
        [self.listener onAdShow];
    }
}

/// 开屏广告即将关闭
/// 注意：AnyThink 在"倒计时结束"和"用户点跳过"两种场景都会回调此方法，
///       且 extra["dismiss_type"] 均为 1（无区分意义），故不在此映射任何 Flame 回调。
///       onAdShowComplete 的判定已下沉到 splashDidClose（dismiss_type==3 才触发）。
/// - Parameters:
///   - placementID: 广告位ID
///   - extra: 额外信息
- (void)splashWillCloseForPlacementID:(nonnull NSString *)placementID extra:(nonnull NSDictionary *)extra {
    // 不触发任何 Flame listener；展示完成的判定在 splashDidClose 中按 dismiss_type 处理。
}

/// 获得展示收益
/// AnyThink 语义：广告产生收益（展示即触发）。
/// 开屏广告无"奖励"语义，原错误映射 onAdReward 会导致展示即回调奖励，已移除。
/// - Parameters:
///   - placementID: 广告位ID
///   - extra: 额外信息字典
- (void)didRevenueForPlacementID:(NSString *)placementID extra:(NSDictionary *)extra {
    // 开屏无奖励回调，此处不触发任何 Flame listener 方法。
}

/// 开屏广告加载超时
/// - Parameter placementID: 广告位ID
- (void)didTimeoutLoadingSplashADWithPlacementID:(NSString *)placementID {
    if ([self.listener respondsToSelector:@selector(onAdLoadTimeout)]) {
        [self.listener onAdLoadTimeout];
    }
}


@end

#endif // FLAME_BUILD_TK / 默认 TK
