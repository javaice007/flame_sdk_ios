//
//  AtBannerAdapter.m
//  flame_sdk_ios
//
//  Created by Flame on 2026/1/21.
//

#import "AtBannerAdapter.h"
#import "FlameErrorCode.h"
#import "FlameLogger.h"

@implementation AtBannerAdapter

- (nonnull instancetype)initWithPlacementId:(NSString *)atPlacementId
                                   listener:(id<FlameBannerListener>)listener {
    self = [super init];
    if (self) {
        _atPlacementId = [atPlacementId copy];
        _listener = listener;
        
        _localExtra = [[NSMutableDictionary alloc] init];
    }
    return self;
}

#pragma mark - FlameBannerAd
/**
 * 加载广告
 * @param width 宽度
 * @param height 高度
 */
- (void)loadWithWidth:(CGFloat)width
               height:(CGFloat)height{
    [self loadWithUserId:nil userCustomData:nil width:width height:height];
}

/**
 * 加载广告（带用户信息）
 * @param userId 用户 ID
 * @param userCustomData 用户自定义数据
 * @param width 宽度
 * @param height 高度
 */
- (void)loadWithUserId:(NSString *)userId
        userCustomData:(NSString *)userCustomData
                 width:(CGFloat)width
                height:(CGFloat)height{
    // 1. 基础校验：广告位 ID
    if (self.atPlacementId == nil || self.atPlacementId.length == 0) {
        if (self.listener && [self.listener respondsToSelector:@selector(onAdError:desc:)]) {
            [self.listener onAdError:ERROR_CODE_INVALID_AD_PLACEMENT
                                desc:@"Invalid mapping for placementId"];
        }
        return;
    }

    // 2. 校验宽度和高度
    // isnan() 检查是否为非数字，isinf() 检查是否为无穷大
    if (width <= 0 || height <= 0 || isnan(width) || isnan(height) || isinf(width) || isinf(height)) {
        if (self.listener && [self.listener respondsToSelector:@selector(onAdError:desc:)]) {
            NSString *errorDesc = [NSString stringWithFormat:@"Invalid ad size: %.2f x %.2f", width, height];
            [self.listener onAdError:ERROR_CODE_INVALID_PARAM
                                desc:errorDesc];
        }
        return;
    }

    // 3. 填充用户信息
    if (userId.length > 0) {
        self.localExtra[kATAdLoadingExtraUserIDKey] = userId;
    }
    if (userCustomData.length > 0) {
        self.localExtra[kATAdLoadingExtraUserDataKeywordKey] = userCustomData;
    }

    // 4. 填充尺寸信息 (TopOn 要求使用 NSValue 包装 CGSize)
    CGSize adSize = CGSizeMake(width, height);
    [self.localExtra setObject:[NSValue valueWithCGSize:adSize]
                        forKey:kATAdLoadingExtraBannerAdSizeKey];

    // 5. 执行加载逻辑
    [[ATAdManager sharedManager] loadADWithPlacementID:self.atPlacementId extra:self.localExtra delegate:self];
}

- (BOOL)isLoading { 
    if (self.atPlacementId.length == 0) return NO;
    ATCheckLoadModel *status = [[ATAdManager sharedManager] checkBannerLoadStatusForPlacementID:self.atPlacementId];
    return status ? status.isLoading : NO;
}

- (BOOL)isReady { 
    if (self.atPlacementId.length == 0) return NO;
    return [[ATAdManager sharedManager] bannerAdReadyForPlacementID:self.atPlacementId];
}

/**
 * 获取广告View
 */
- (UIView *)retrieveAdView{
    // 1. 状态校验：依赖底层 TopOn SDK 的原始状态
    if (![self isReady]) {
        [FlameLogger i:@"Banner Ad is not ready in SDK."];
        return nil;
    }
    
    ATShowConfig *config = [[ATShowConfig alloc] initWithScene:@"" showCustomExt:@""];
    UIView *bannerView = [[ATAdManager sharedManager] retrieveBannerViewForPlacementID:self.atPlacementId config:config];
    
    if (bannerView) {
        // 重新设置代理，确保点击/关闭事件能重新绑定到当前的 Adapter 实例
        if ([bannerView respondsToSelector:@selector(setDelegate:)]) {
            [(id)bannerView setDelegate:self];
        }
        
        // 修正尺寸
        NSValue *sizeValue = self.localExtra[kATAdLoadingExtraBannerAdSizeKey];
        if (sizeValue) {
            CGSize adSize = [sizeValue CGSizeValue];
            bannerView.frame = CGRectMake(0, 0, adSize.width, adSize.height);
        }
    }
    return bannerView;
}

/**
 * 移除
 */
- (void)remove{
    [FlameLogger i:@"Note: View is managed by upper layer, please set your view reference to nil."];
}

- (void)destroy {
    // 1. 移除 UI
    [self remove];
    
    // 2. 断开所有引用
    _listener = nil;
    
    if (self.localExtra) {
        [self.localExtra removeAllObjects];
        _localExtra = nil;
    }
    
    // 3. 注意：TopOn 内部通常由 AdManager 管理，
    // 如果有特定的 Release 接口可在此调用，通常置空引用即可。
    _atPlacementId = nil;
}


- (void)didFailToLoadADWithPlacementID:(NSString *)placementID error:(NSError *)error {
    if ([self.listener respondsToSelector:@selector(onAdError:desc:)]) {
        [self.listener onAdError:[NSString stringWithFormat:@"%ld", (long)error.code]
                                 desc:error.localizedDescription];
    }
}

- (void)didFinishLoadingADWithPlacementID:(NSString *)placementID { 
    if ([self.listener respondsToSelector:@selector(onAdLoaded)]) {
        [self.listener onAdLoaded];
    }
}

/// 关闭按钮点击(当用户点击横幅上关闭按钮的情形)
/// - Parameters:
///   - bannerView: 横幅广告视图对象
///   - placementID: 广告位ID
///   - extra: 额外信息字典
- (void)bannerView:(ATBannerView *)bannerView didTapCloseButtonWithPlacementID:(NSString *)placementID extra:(NSDictionary *)extra {
    if ([self.listener respondsToSelector:@selector(onAdClosed:)]) {
        [self.listener onAdClosed];
    }
}

/// 横幅广告被点击
/// - Parameters:
///   - bannerView: 横幅广告视图对象
///   - placementID: 广告位ID
///   - extra: 额外信息字典
- (void)bannerView:(ATBannerView *)bannerView didClickWithPlacementID:(NSString *)placementID extra:(NSDictionary *)extra{
    if ([self.listener respondsToSelector:@selector(onAdClicked:)]) {
        [self.listener onAdClicked];
    }
}

/// 横幅广告已展示
/// - Parameters:
///   - bannerView: 横幅广告视图对象
///   - placementID: 广告位ID
///   - extra: 额外信息字典
- (void)bannerView:(ATBannerView *)bannerView didShowAdWithPlacementID:(NSString *)placementID extra:(NSDictionary *)extra {
    if ([self.listener respondsToSelector:@selector(onAdShow:)]) {
        [self.listener onAdShow];
    }
}

@end
