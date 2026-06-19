//
//  FlameAdapterManager.m
//  FlameSDK
//
//  Created by flame.
//  Copyright © 2026 Flame. All rights reserved.
//

#import "FlameAdapterManager.h"

#import "FlameLogger.h"
#import "FlameCallback.h"
// 平台中立：checkInitialization 委托给 FlameSdk 状态机（TK / TB 两变体统一来源）
#import "FlameSdk.h"

// ============================================================
// FlameAdapterManager（Phase 5A.12 mainline：平台中立骨架）
// ------------------------------------------------------------
// isInitialized / checkInitialization / sharedInstance 等状态方法始终编译
// （ads/*Impl.m 依赖 checkInitialization）。
// initSDKWithAppId 保留 TK 初始化逻辑（ATAPI），但实际调用路径已迁移到
// FlameTKProvider.initializeWithAppId（本类的 initSDKWithAppId 仅作为历史兼容入口）。
// setDebug 平台中立：debug 开关由各 Provider 自己处理（TK 走 AnyThink，TB 走 WindMill）。
// 广告创建工厂方法已删除，统一走 Provider 链路。
// ============================================================
#import <AnyThinkSDK/AnyThinkSDK.h>


@implementation FlameAdapterManager

- (instancetype)init {
    self = [super init];
    if (self) {
        _isInitialized = NO;
    }
    return self;
}

// 1. 实现单例获取方法
+ (instancetype)sharedInstance {
    static FlameAdapterManager *_sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // 直接调用父类的 allocWithZone: 避免递归
        _sharedInstance = [[super allocWithZone:NULL] init];
    });
    return _sharedInstance;
}

// 移除 allocWithZone: 重写，避免递归问题

- (instancetype)copyWithZone:(NSZone *)zone {
    return self;
}

+ (void)initSDKWithAppId:(NSString *)appId
                  appKey:(NSString *)appKey
            initListener:(id<FlameCallback>) initListener{
    if ([self sharedInstance].isInitialized) {
        [FlameLogger w:@"FlameSdk is already initialized."];
        if ([initListener respondsToSelector:@selector(success)]) {
            [initListener success];
        }
        return;
    }

    // 日志开关 默认开启
    [ATAPI setLogEnabled:YES];
    // 检测集成环境（仅建议在测试阶段使用）
    [ATAPI integrationChecking];

    // 初始化 TopOn SDK
    NSError *error = nil;
    [[ATAPI sharedInstance] startWithAppID:appId appKey:appKey error:&error];

    if (error) {
        [FlameLogger e:[NSString stringWithFormat:@"FlameSdk  UP-SDK Start Failed: %@", error.localizedDescription]];

        // 触发失败回调
        if ([initListener respondsToSelector:@selector(fail:desc:)]) {
            [initListener fail:[NSString stringWithFormat:@"%ld", (long)error.code]
                         desc:error.localizedDescription];
        }
    } else {
        // 设置初始化标记
        [self sharedInstance].isInitialized = YES;
        [FlameLogger i:@"FlameSdk initialized successfully."];

        // 触发成功回调
        if ([initListener respondsToSelector:@selector(success)]) {
            [initListener success];
        }
    }
}

// 注：历史工厂方法 createRewardAdapter: / createInterstitialAdapter: /
// createSplashAdAdapter: / createBannerAdapter: / createNativeAdapter: 已删除。
// 当前广告创建链路为：
//   FlameSdk.create*Ad
//     → FlameMediationRouter.currentProvider
//     → FlameTKProvider / FlameTBProvider
//     → At*Adapter / TbRewardAdapter

// ========= 平台中立方法：TK / TB 两变体均编译 =========
// isInitialized / checkInitialization 被 ads/*Impl.m 调用，必须始终存在。
// 初始化状态统一来自 FlameSdk 状态机（由各 Provider 的初始化回调更新），
// 不再读取 FlameAdapterManager 私有标志，保证 TB 变体（不经 initSDKWithAppId）
// 也能正确反映初始化结果。

+ (void)setDebug:(BOOL)isDebug {
    // 平台中立：debug 开关由各 Provider 自己处理
    // - TK：FlameTKProvider.initializeWithAppId 调用 [ATAPI setLogEnabled:YES]
    // - TB：FlameTBProvider.initializeWithAppId 调用 [WindMillAds setDebugEnable:YES]
    // 此处仅记录调用（实际平台 debug 设置在 Provider 初始化时完成）。
    [FlameLogger i:[NSString stringWithFormat:@"FlameAdapterManager.setDebug:%@ (providers handle platform debug setting)", isDebug ? @"YES" : @"NO"]];
}

+ (BOOL)isInitialized {
    return [FlameSdk isInitialized];
}

+ (BOOL)checkInitialization {
    return [FlameSdk checkInitialization];
}

@end
