//
//  FlameMediationRegistry.h
//  FlameSDK
//
//  Created by flame.
//  Copyright © 2026 Flame. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FlameMediationProvider.h"

/**
 * 聚合平台 Provider 注册表
 * SDK 内部使用，不导入 flame_sdk_ios.h 伞头文件，不对接入方公开
 *
 * 管理所有已注册的 Provider，根据 NSString *platformCode 查找对应 Provider。
 * platformCode 使用 NSString 而非 NS_ENUM，支持任意平台扩展。
 */
@interface FlameMediationRegistry : NSObject

/**
 * 获取单例实例
 */
+ (instancetype)sharedRegistry;

/**
 * 注册 Provider
 * @param provider 要注册的 Provider 实例（不可为 nil）
 *                provider.platformCode 不可为空
 *                同一 platformCode 重复注册时，后注册的覆盖先注册的
 */
- (void)registerProvider:(id<FlameMediationProvider>)provider;

/**
 * 注销 Provider
 * @param platformCode 要注销的平台标识（不可为 nil）
 */
- (void)unregisterProviderForPlatformCode:(NSString *)platformCode;

/**
 * 根据 platformCode 获取 Provider
 * @param platformCode 平台标识
 * @return 对应的 Provider，未注册则返回 nil
 */
- (id<FlameMediationProvider>)providerForPlatformCode:(NSString *)platformCode;

/**
 * 是否已注册指定平台的 Provider
 * @param platformCode 平台标识
 */
- (BOOL)hasProviderForPlatformCode:(NSString *)platformCode;

/**
 * 获取所有已注册的 platformCode 列表
 * @return platformCode 字符串数组
 */
- (NSArray<NSString *> *)allRegisteredPlatformCodes;

/**
 * 清除所有已注册的 Provider
 */
- (void)clear;

@end
