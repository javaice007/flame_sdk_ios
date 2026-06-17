//
//  FlameTKProvider.m
//  FlameSDK
//
//  Created by flame.
//  Copyright © 2026 Flame. All rights reserved.
//

// TK 平台源码宏隔离：TB 构建变体下整个文件置空，避免编译期 import AnyThink/TopOn
#if defined(FLAME_BUILD_TK) || (!defined(FLAME_BUILD_TK) && !defined(FLAME_BUILD_TB))

#import "FlameTKProvider.h"
#import "FlameAdapterManager.h"
#import "FlameLogger.h"
#import "AtRewardAdapter.h"
#import "AtSplashAdapter.h"
#import "AtInterstitialAdapter.h"
#import "AtBannerAdapter.h"
#import "AtNativeAdapter.h"

/// TK 平台标识常量
static NSString * const kFlamePlatformTK = @"tk";

@implementation FlameTKProvider

- (NSString *)platformCode {
    return kFlamePlatformTK;
}

- (void)initializeWithAppId:(NSString *)appId
                    appKey:(NSString *)appKey
                  callback:(id<FlameCallback>)callback {
    [FlameLogger i:@"FlameTKProvider: 开始初始化 TopOn / AnyThink"];

    // 复用 FlameAdapterManager 初始化 TopOn SDK
    // FlameAdapterManager 内部调用 [ATAPI sharedInstance] startWithAppID:appKey:error:
    // 初始化成功/失败通过 callback 回调，行为与改造前完全一致
    [FlameAdapterManager initSDKWithAppId:appId appKey:appKey initListener:callback];
}

#pragma mark - FlameRewardAdapterProtocol 创建

- (id<FlameRewardAdapterProtocol>)createRewardAdapterWithViewController:(UIViewController *)viewController
                                                           placementId:(NSString *)placementId
                                                              listener:(id<FlameRewardListener>)listener {
    // 直接创建 AtRewardAdapter，不通过 FlameAdapterManager 工厂方法
    // FlameAdapterManager.createRewardAdapter 返回 id<FlameRewardAd>（公共协议），
    // 此处返回 id<FlameRewardAdapterProtocol>（内部协议），保持类型精确
    AtRewardAdapter *adapter = [[AtRewardAdapter alloc] initWithViewController:viewController
                                                                 atPlacementId:placementId
                                                                      listener:listener];
    return adapter;
}

#pragma mark - FlameSplashAdapterProtocol 创建

- (id<FlameSplashAdapterProtocol>)createSplashAdapterWithViewController:(UIViewController *)viewController
                                                           placementId:(NSString *)placementId
                                                              listener:(id<FlameSplashListener>)listener {
    AtSplashAdapter *adapter = [[AtSplashAdapter alloc] initWithViewController:viewController
                                                                 atPlacementId:placementId
                                                                      listener:listener];
    return adapter;
}

#pragma mark - FlameInterstitialAdapterProtocol 创建

- (id<FlameInterstitialAdapterProtocol>)createInterstitialAdapterWithViewController:(UIViewController *)viewController
                                                                  placementId:(NSString *)placementId
                                                                        listener:(id<FlameInterstitialListener>)listener {
    AtInterstitialAdapter *adapter = [[AtInterstitialAdapter alloc] initWithViewController:viewController
                                                                         atPlacementId:placementId
                                                                              listener:listener];
    return adapter;
}

#pragma mark - FlameBannerAdapterProtocol 创建

- (id<FlameBannerAdapterProtocol>)createBannerAdapterWithPlacementId:(NSString *)placementId
                                                          renderType:(FlameBannerRenderType)renderType
                                                            listener:(id<FlameBannerListener>)listener {
    AtBannerAdapter *adapter = [[AtBannerAdapter alloc] initWithPlacementId:placementId
                                                                renderType:renderType
                                                                  listener:listener];
    return adapter;
}

#pragma mark - FlameNativeAdapterProtocol 创建

- (id<FlameNativeAdapterProtocol>)createNativeAdapterWithViewController:(UIViewController *)viewController
                                                          placementId:(NSString *)placementId
                                                                listener:(id<FlameNativeListener>)listener {
    AtNativeAdapter *adapter = [[AtNativeAdapter alloc] initWithViewController:viewController
                                                                 atPlacementId:placementId
                                                                      listener:listener];
    return adapter;
}

@end

#endif // FLAME_BUILD_TK / 默认 TK
