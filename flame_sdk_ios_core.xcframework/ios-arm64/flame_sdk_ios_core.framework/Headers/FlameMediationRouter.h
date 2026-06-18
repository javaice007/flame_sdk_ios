//
//  FlameMediationRouter.h
//  FlameSDK
//
//  Created by flame.
//  Copyright © 2026 Flame. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FlameMediationProvider.h"

/**
 * 聚合平台路由器
 * SDK 内部使用，不导入 flame_sdk_ios.h 伞头文件，不对接入方公开
 *
 * 持有当前激活的 Provider 引用（strong 持有，避免提前释放），将请求路由到当前 Provider。
 * Phase 1 仅做基础骨架：激活 Provider、查询状态、重置。
 * 后续阶段逐步添加 create*Ad 路由方法。
 */
@interface FlameMediationRouter : NSObject

/**
 * 获取单例实例
 */
+ (instancetype)sharedRouter;

/**
 * 激活指定 Provider
 * @param provider 要激活的 Provider 实例（不可为 nil）
 */
- (void)activateProvider:(id<FlameMediationProvider>)provider;

/**
 * 获取当前激活的 Provider
 * @return 当前 Provider，未激活时返回 nil
 */
- (id<FlameMediationProvider>)currentProvider;

/**
 * 获取当前激活的平台标识
 * @return 当前 platformCode，未激活时返回 nil
 */
- (NSString *)currentPlatformCode;

/**
 * 是否已激活 Provider
 */
- (BOOL)hasActiveProvider;

/**
 * 重置：清除当前激活的 Provider
 */
- (void)clear;

@end
