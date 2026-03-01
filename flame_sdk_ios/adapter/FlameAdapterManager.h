//
//  FlameAdapterManager.h
//  FlameSDK
//
//  Created by flame.
//  Copyright © 2026 Flame. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FlameCallback.h"
#import "FlameRewardAd.h"
#import "FlameInterstitialAd.h"
#import "FlameSplashAd.h"
#import "FlameBannerAd.h"
#import "FlameNativeAd.h"
#import "FlameDrawAd.h"

@interface FlameAdapterManager: NSObject

@property (atomic, assign, readwrite) BOOL isInitialized;

/**
 * 获取单例实例
 */
+ (instancetype)sharedInstance;

/**
 * 初始化 SDK
 * @param appId 对应 aId
 * @param appKey 对应 aKey
 */
+ (void)initSDKWithAppId:(NSString *)appId
                  appKey:(NSString *)appKey
                initListener:(id<FlameCallback>) initListener;

/**
 * 快速检查 SDK 是否已初始化 (类方法)
 */
+ (BOOL)isInitialized;

/**
 * 检查初始化状态，若未初始化则抛出异常 (类方法)
 */
+ (void)checkInitialization;

/**
 * 设置调试模式
 * @param isDebug 是否开启
 */
+ (void)setDebug:(BOOL)isDebug;

/**
 * 创建激励视频适配器
 * @param viewController view组件
 * @param atPlacementId   广告为ID
 * @param listener    监听器
 */
+ (id<FlameRewardAd>)createRewardAdapter:(UIViewController *)viewController
                           atPlacementId:(NSString *)atPlacementId
                                listener:(id<FlameRewardListener>)listener;

/**
 * 创建插屏广告适配器
 * @param viewController view组件
 * @param atPlacementId   广告为ID
 * @param listener    监听器
 */
+ (id<FlameInterstitialAd>)createInterstitialAdapter:(UIViewController *)viewController
                                       atPlacementId:(NSString *)atPlacementId
                                            listener:(id<FlameInterstitialListener>)listener;

/**
 * 创建开屏广告适配器
 * @param viewController view组件
 * @param atPlacementId   广告为ID
 * @param listener    监听器
 */
+ (id<FlameSplashAd>)createSplashAdAdapter:(UIViewController *)viewController
                           atPlacementId:(NSString *)atPlacementId
                                listener:(id<FlameSplashListener>)listener;

/**
 * 创建横幅广告适配器
 * @param atPlacementId   广告为ID
 * @param listener    监听器
 */
+ (id<FlameBannerAd>)createBannerAdapter:(NSString *)atPlacementId
                                listener:(id<FlameBannerListener>)listener;

/**
 * 创建原生广告适配器
 * @param viewController view组件
 * @param atPlacementId   广告为ID
 * @param listener    监听器
 */
+ (id<FlameNativeAd>)createNativeAdapter:(UIViewController *)viewController
                           atPlacementId:(NSString *)atPlacementId
                                listener:(id<FlameNativeListener>)listener;

/**
 * 创建视频流广告适配器
 * @param viewController view组件
 * @param atPlacementId   广告为ID
 * @param listener    监听器
 */
+ (id<FlameDrawAd>)createDrawAdapter:(UIViewController *)viewController
                           atPlacementId:(NSString *)atPlacementId
                                listener:(id<FlameDrawListener>)listener;

@end
