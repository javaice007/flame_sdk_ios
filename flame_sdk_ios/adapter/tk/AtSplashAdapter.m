//
//  AtSplashAdapter.m
//  flame_sdk_ios
//
//  Created by Flame on 2026/1/20.
//

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
/// - Parameters:
///   - placementID: 广告位ID
///   - extra: 额外信息
- (void)splashDidCloseForPlacementID:(nonnull NSString *)placementID extra:(nonnull NSDictionary *)extra {
    if ([self.listener respondsToSelector:@selector(onAdClosed)]) {
        [self.listener onAdClosed];
    }
}

/// 开屏广告已展示
/// - Parameters:
///   - placementID: 广告位ID
///   - extra: 额外信息
- (void)splashDidShowForPlacementID:(nonnull NSString *)placementID extra:(nonnull NSDictionary *)extra {
    if ([self.listener respondsToSelector:@selector(onAdShowComplete:userCustomData:)]) {
        NSString *userId = self.localExtra[kATAdLoadingExtraUserIDKey] ?: @"";
        NSString *customData = self.localExtra[kATAdLoadingExtraUserDataKeywordKey] ?: @"";
        [self.listener onAdShowComplete:userId userCustomData:customData];
    }
}

/// 获得展示收益
/// - Parameters:
///   - placementID: 广告位ID
///   - extra: 额外信息字典
- (void)didRevenueForPlacementID:(NSString *)placementID extra:(NSDictionary *)extra {
    if ([self.listener respondsToSelector:@selector(onAdReward:userCustomData:)]) {
        // TopOn 成功回调的 extra 中通常包含之前传入的透传参数
        NSString *userId = self.localExtra[kATAdLoadingExtraUserIDKey] ?: @"";
        NSString *customData = self.localExtra[kATAdLoadingExtraUserDataKeywordKey] ?: @"";
        [self.listener onAdReward:userId userCustomData:customData];
    }
}

/// 开屏广告加载超时
/// - Parameter placementID: 广告位ID
- (void)didTimeoutLoadingSplashADWithPlacementID:(NSString *)placementID {
    if ([self.listener respondsToSelector:@selector(onAdLoadTimeout)]) {
        [self.listener onAdLoadTimeout];
    }
}


@end
