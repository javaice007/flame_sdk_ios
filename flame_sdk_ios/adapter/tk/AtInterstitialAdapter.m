//
//  AtInterstitialAdapter.m
//  flame_sdk_ios
//
//  Created by Flame on 2026/1/19.
//

// TK 平台源码宏隔离：TB 构建变体下整个文件置空，避免编译期 import AnyThink/TopOn
#if defined(FLAME_BUILD_TK) || (!defined(FLAME_BUILD_TK) && !defined(FLAME_BUILD_TB) && !defined(FLAME_BUILD_CORE))

#import "AtInterstitialAdapter.h"
#import "FlameErrorCode.h"

@implementation AtInterstitialAdapter

- (nonnull instancetype)initWithViewController:(nonnull UIViewController *)viewController
                                 atPlacementId:(nonnull NSString *)atPlacementId
                                      listener:(nonnull id<FlameInterstitialListener>)listener {
    self = [super init];
    if (self) {
        _viewController = viewController;
        _atPlacementId = [atPlacementId copy];
        _listener = listener;
        
        _localExtra = [[NSMutableDictionary alloc] init];
    }
    return self;
}

#pragma mark - FlameInterstitialAd
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

    // 3. 传入屏幕尺寸，避免各渠道使用默认尺寸导致渲染变形
    CGSize screenSize = UIScreen.mainScreen.bounds.size;
    self.localExtra[kATInterstitialExtraAdSizeKey] = [NSValue valueWithCGSize:screenSize];

    // 4. 执行加载
    [[ATAdManager sharedManager] loadADWithPlacementID:self.atPlacementId
                                                 extra:self.localExtra
                                              delegate:self];
}

- (BOOL)isLoading { 
    if (self.atPlacementId.length == 0) return NO;
    ATCheckLoadModel *status = [[ATAdManager sharedManager] checkInterstitialLoadStatusForPlacementID:self.atPlacementId];
    return status ? status.isLoading : NO;
}

- (BOOL)isReady { 
    if (self.atPlacementId.length == 0) return NO;
    return [[ATAdManager sharedManager] interstitialReadyForPlacementID:self.atPlacementId];
}

- (void)show { 
    if (![self isReady]) {
        if (self.listener) {
            [self.listener onAdError:@"AD_NOT_READY" desc:@"Ad is not ready to show"];
        }
        return;
    }
    
    // 展示广告，使用 ATShowConfig 确保与 TopOn 推荐用法一致
    ATShowConfig *config = [[ATShowConfig alloc] initWithScene:@"default" showCustomExt:@""];
    [[ATAdManager sharedManager] showInterstitialWithPlacementID:self.atPlacementId
                                                      showConfig:config
                                                inViewController:self.viewController
                                                        delegate:self
                                              nativeMixViewBlock:nil];
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

#pragma mark - ATAdLoadingDelegate
- (void)didFailToLoadADWithPlacementID:(NSString *)placementID error:(NSError *)error {
    if ([self.listener respondsToSelector:@selector(onAdError:desc:)]) {
        [self.listener onAdError:[NSString stringWithFormat:@"%ld", (long)error.code]
                                 desc:error.localizedDescription];
    }
}

// 加载完成
- (void)didFinishLoadingADWithPlacementID:(NSString *)placementID {
    if ([self.listener respondsToSelector:@selector(onAdLoaded)]) {
        [self.listener onAdLoaded];
    }
}

// 点击
- (void)interstitialDidClickForPlacementID:(nonnull NSString *)placementID extra:(nonnull NSDictionary *)extra {
    if ([self.listener respondsToSelector:@selector(onAdClicked)]) {
        [self.listener onAdClicked];
    }
}

// 关闭
- (void)interstitialDidCloseForPlacementID:(nonnull NSString *)placementID extra:(nonnull NSDictionary *)extra {
    if ([self.listener respondsToSelector:@selector(onAdClosed)]) {
        [self.listener onAdClosed];
    }
}

// 播放完成
#pragma mark - ATInterstitialDelegate
- (void)interstitialDidShowForPlacementID:(nonnull NSString *)placementID extra:(nonnull NSDictionary *)extra {
    if ([self.listener respondsToSelector:@selector(onAdShow)]) {
        [self.listener onAdShow];
    }
}

/// 获得展示收益
/// - Parameters:
///   - placementID: 广告位ID
///   - extra: 额外信息字典
- (void)didRevenueForPlacementID:(NSString *)placementID extra:(NSDictionary *)extra {
    if ([self.listener respondsToSelector:@selector(onAdReward:userId:userCustomData:)]) {
        // TopOn 成功回调的 extra 中通常包含之前传入的透传参数
        NSString *userId = self.localExtra[kATAdLoadingExtraUserIDKey] ?: @"";
        NSString *customData = self.localExtra[kATAdLoadingExtraUserDataKeywordKey] ?: @"";
        [self.listener onAdReward:placementID userId:userId userCustomData:customData];
    }
}

// 播放失败
- (void)interstitialDidFailToPlayVideoForPlacementID:(NSString *)placementID error:(NSError *)error extra:(NSDictionary *)extra {
    if ([self.listener respondsToSelector:@selector(onAdError:desc:)]) {
        [self.listener onAdError:[NSString stringWithFormat:@"%ld", (long)error.code]
                                 desc:error.localizedDescription];
    }
}

@end

#endif // FLAME_BUILD_TK / 默认 TK
