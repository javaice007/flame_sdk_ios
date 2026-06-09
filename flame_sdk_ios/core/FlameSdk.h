//
//  FlameSdk.h
//  FlameSDK
//
//  Created by flame.
//  Copyright © 2026 Flame. All rights reserved.
//
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "FlameCallback.h"

#import "FlameRewardAd.h"
#import "FlameInterstitialAd.h"
#import "FlameSplashAd.h"
#import "FlameBannerAd.h"
#import "FlameNativeAd.h"

/**
 * Flame SDK 核心管理类
 * 采用单例模式，托管所有聚合广告的初始化逻辑
 */
@interface FlameSdk : NSObject

/**
 * 获取单例实例
 */
+ (instancetype)sharedInstance;

/**
 * 初始化 SDK
 * @param appId  Flame 平台的 AppId
 * @param appKey Flame 平台的 AppKey
 */
+ (void)initWithAppId:(NSString *)appId appKey:(NSString *)appKey;

/**
 * 初始化 SDK（带回调）
 * @param appId    Flame 平台的 AppId
 * @param appKey   Flame 平台的 AppKey
 * @param callback 回调
 */
+ (void)initWithAppId:(NSString *)appId appKey:(NSString *)appKey callback:(id<FlameCallback>)callback;


/**
 * 清空缓存
 */
+ (void)clear;

/**
 * 设置是否开启 Debug 模式
 */
+ (void)setDebug:(BOOL)isDebug;

/**
 * 检查 SDK 是否初始化成功
 */
+ (BOOL)isInitialized;

/**
 * 内部校验方法，检查 SDK 是否已初始化成功
 * @return YES 已初始化，NO 未初始化
 */
+ (BOOL)checkInitialization;

/**
 * 获取 SDK 版本号
 */
- (NSString *)getVersion;

/**
 * 创建开屏广告实例
 * @param viewController    视图控制器
 * @param placementId           广告位ID
 * @param listener                  回调函数
 */
+ (id<FlameSplashAd>)createSplashAdWithViewController:(UIViewController *)viewController
                                          placementId:(NSString *)placementId
                                             listener:(id<FlameSplashListener>)listener;
/**
 * 创建激励视频广告实例
 * @param viewController    视图控制器
 * @param placementId           广告位ID
 * @param listener                  回调函数
 */
+ (id<FlameRewardAd>)createRewardAdWithViewController:(UIViewController *)viewController
                                        placementId:(NSString *)placementId
                                           listener:(id<FlameRewardListener>)listener;

/**
 * 创建插屏广告实例
 * @param viewController    视图控制器
 * @param placementId           广告位ID
 * @param listener                  回调函数
 */
+ (id<FlameInterstitialAd>)createInterstitialAdWithViewController:(UIViewController *)viewController
                                                      placementId:(NSString *)placementId
                                                         listener:(id<FlameInterstitialListener>)listener;

/**
 * 创建横幅广告实例（Express 模板渲染模式）
 * @param placementId           广告位ID
 * @param listener                  回调函数
 */
+ (id<FlameBannerAd>)createBannerAdWithPlacementId:(NSString *)placementId
                                          listener:(id<FlameBannerListener>)listener;

/**
 * 创建自渲染横幅广告实例（SelfRender 模式）
 * 创建时即确定渲染模式，无需额外调用 setRenderType
 * @param placementId           广告位ID（需映射到支持横幅尺寸的 TopOn Native 广告位）
 * @param listener                  回调函数
 */
+ (id<FlameBannerAd>)createSelfRenderBannerAdWithPlacementId:(NSString *)placementId
                                                    listener:(id<FlameBannerListener>)listener;

/**
 * 创建原生广告实例
 * @param viewController    视图控制器
 * @param placementId           广告位ID
 * @param listener                  回调函数
 */
+ (id<FlameNativeAd>)createNativeAdWithViewController:(UIViewController *)viewController
                                          placementId:(NSString *)placementId
                                             listener:(id<FlameNativeListener>)listener;
@end
