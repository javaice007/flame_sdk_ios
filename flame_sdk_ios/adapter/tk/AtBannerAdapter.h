//
//  AtBannerAdapter.h
//  flame_sdk_ios
//
//  Created by Flame on 2026/1/21.
//

// TK 平台源码宏隔离：TB 构建变体下整个文件置空，避免编译期 import AnyThink/TopOn
#if defined(FLAME_BUILD_TK) || (!defined(FLAME_BUILD_TK) && !defined(FLAME_BUILD_TB) && !defined(FLAME_BUILD_CORE))

#import <Foundation/Foundation.h>
#import <AnyThinkSDK/AnyThinkSDK.h>
#import "FlameBannerAdapterProtocol.h"
#import "FlameBannerAd.h"

NS_ASSUME_NONNULL_BEGIN

@interface AtBannerAdapter : NSObject<FlameBannerAdapterProtocol, ATBannerDelegate, ATAdLoadingDelegate>

@property (nonatomic, strong) NSMutableDictionary *localExtra;
@property (nonatomic, copy) NSString *atPlacementId;
@property (nonatomic, weak) id<FlameBannerListener> listener;
@property (nonatomic, assign) CGSize adSize;
@property (nonatomic, assign, readonly) FlameBannerRenderType renderType;
@property (nonatomic, weak) UIViewController *viewController;
@property (nonatomic, strong) NSArray<FlameBannerAdMaterial *> *materials;
@property (nonatomic, strong, nullable) ATBannerView *bannerView;
@property (nonatomic, strong, nullable) ATNativeBannerView *nativeBannerView;
@property (nonatomic, strong) NSArray<UIView *> *managedAssetViews;
@property (nonatomic, assign) BOOL hasShownPreparedBanner;
@property (nonatomic, assign) NSInteger boundMaterialIndex;

- (instancetype)initWithPlacementId:(NSString *)atPlacementId
                         renderType:(FlameBannerRenderType)renderType
                           listener:(id<FlameBannerListener>)listener;

@end

NS_ASSUME_NONNULL_END

#endif // FLAME_BUILD_TK / 默认 TK
