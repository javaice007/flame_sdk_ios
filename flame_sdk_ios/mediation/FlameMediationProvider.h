//
//  FlameMediationProvider.h
//  FlameSDK
//
//  Created by flame.
//  Copyright © 2026 Flame. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "FlameCallback.h"
#import "FlameRewardAdapterProtocol.h"
#import "FlameRewardAd.h"
#import "FlameSplashAdapterProtocol.h"
#import "FlameSplashAd.h"
#import "FlameInterstitialAdapterProtocol.h"
#import "FlameInterstitialAd.h"
#import "FlameBannerAdapterProtocol.h"
#import "FlameBannerAd.h"
#import "FlameNativeAdapterProtocol.h"
#import "FlameNativeAd.h"

/**
 * 聚合平台提供商协议
 * SDK 内部使用，不导入 flame_sdk_ios.h 伞头文件，不对接入方公开
 *
 * 每个聚合平台（如 TopOn、ToBid 等）通过实现此协议接入 Flame SDK。
 * Phase 1 仅定义最小骨架，后续阶段逐步添加 initSDK / create*Ad 等方法。
 */
@protocol FlameMediationProvider <NSObject>

@required

/**
 * 平台标识符，如 @"tk"、@"tb"
 * 用于 Registry 注册和 Router 路由，不使用 NS_ENUM 以支持无限扩展
 */
- (NSString *)platformCode;

/**
 * 初始化聚合平台 SDK
 * @param appId  应用 ID（对应 FlameAppEntity.aId）
 * @param appKey 应用 Key（对应 FlameAppEntity.aKey）
 * @param callback 初始化结果回调，success 表示平台 SDK 初始化完成
 */
- (void)initializeWithAppId:(NSString *)appId
                    appKey:(NSString *)appKey
                  callback:(id<FlameCallback>)callback;

/**
 * 创建激励视频适配器（Phase 3A 新增）
 * @param viewController 视图控制器
 * @param placementId 平台广告位 ID（已映射）
 * @param listener Flame 激励视频回调监听器
 * @return 内部激励视频适配器，实现 FlameRewardAdapterProtocol
 */
- (id<FlameRewardAdapterProtocol>)createRewardAdapterWithViewController:(UIViewController *)viewController
                                                           placementId:(NSString *)placementId
                                                              listener:(id<FlameRewardListener>)listener;

/**
 * 创建开屏适配器（Phase 3B 新增）
 */
- (id<FlameSplashAdapterProtocol>)createSplashAdapterWithViewController:(UIViewController *)viewController
                                                           placementId:(NSString *)placementId
                                                              listener:(id<FlameSplashListener>)listener;

/**
 * 创建插屏适配器（Phase 3B 新增）
 */
- (id<FlameInterstitialAdapterProtocol>)createInterstitialAdapterWithViewController:(UIViewController *)viewController
                                                                  placementId:(NSString *)placementId
                                                                        listener:(id<FlameInterstitialListener>)listener;

/**
 * 创建横幅适配器（Phase 3B 新增）
 */
- (id<FlameBannerAdapterProtocol>)createBannerAdapterWithPlacementId:(NSString *)placementId
                                                          renderType:(FlameBannerRenderType)renderType
                                                            listener:(id<FlameBannerListener>)listener;

/**
 * 创建原生适配器（Phase 3B 新增）
 */
- (id<FlameNativeAdapterProtocol>)createNativeAdapterWithViewController:(UIViewController *)viewController
                                                          placementId:(NSString *)placementId
                                                                listener:(id<FlameNativeListener>)listener;

@end
