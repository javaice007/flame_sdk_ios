//
//  FlameAdapterManager.h
//  FlameSDK
//
//  Created by flame.
//  Copyright © 2026 Flame. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FlameCallback.h"

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
 * 检查初始化状态，若未初始化则打印错误日志并返回 NO (类方法)
 * @return YES 已初始化，NO 未初始化
 */
+ (BOOL)checkInitialization;

/**
 * 设置调试模式
 * @param isDebug 是否开启
 */
+ (void)setDebug:(BOOL)isDebug;

// 注：历史工厂方法 createRewardAdapter: / createInterstitialAdapter: /
// createSplashAdAdapter: / createBannerAdapter: / createNativeAdapter: 已删除。
// 当前广告创建链路为：
//   FlameSdk.create*Ad
//     → FlameMediationRouter.currentProvider
//     → FlameTKProvider / FlameTBProvider
//     → At*Adapter / TbRewardAdapter

@end
