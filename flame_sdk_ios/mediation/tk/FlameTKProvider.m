//
//  FlameTKProvider.m
//  FlameSDK
//
//  Created by flame.
//  Copyright © 2026 Flame. All rights reserved.
//

// TK 平台源码宏隔离：TB 构建变体下整个文件置空，避免编译期 import AnyThink/TopOn
#if defined(FLAME_BUILD_TK) || (!defined(FLAME_BUILD_TK) && !defined(FLAME_BUILD_TB) && !defined(FLAME_BUILD_CORE))

#import "FlameTKProvider.h"
#import "FlameAdapterManager.h"
#import "FlameLogger.h"
#import "FlameMediationRegistry.h"
#import <AnyThinkSDK/AnyThinkSDK.h>
#import "AtRewardAdapter.h"
#import "AtSplashAdapter.h"
#import "AtInterstitialAdapter.h"
#import "AtBannerAdapter.h"
#import "AtNativeAdapter.h"

/// TK 平台标识常量
static NSString * const kFlamePlatformTK = @"tk";

@implementation FlameTKProvider

#pragma mark - 插件自动注册（仅 Thin Core 插件模式启用）

// FLAME_PLUGIN_TK 仅由 research/podspecs/flame_sdk_ios.thin_core.tk.podspec 的
// pod_target_xcconfig 注入。旧双二进制构建（xcFramework_build.sh tk）只定义
// FLAME_BUILD_TK，不定义 FLAME_PLUGIN_TK，因此此处 +load 不会在旧 TK binary 中触发，
// 避免 Core binary + 旧 TK binary 同时存在时重复注册。
#if defined(FLAME_PLUGIN_TK)
+ (void)load {
    @autoreleasepool {
        FlameTKProvider *provider = [[FlameTKProvider alloc] init];
        [[FlameMediationRegistry sharedRegistry] registerProvider:provider];
        [FlameLogger i:[NSString stringWithFormat:@"FlameTKProvider: +load 自动注册完成 (plugin 模式, platformCode=%@)", [provider platformCode]]];
    }
}
#endif // FLAME_PLUGIN_TK

- (NSString *)platformCode {
    return kFlamePlatformTK;
}

- (void)initializeWithAppId:(NSString *)appId
                    appKey:(NSString *)appKey
                  callback:(id<FlameCallback>)callback {
    [FlameLogger i:@"FlameTKProvider: 开始初始化 TopOn / AnyThink"];

    // AnyThink / TopOn 初始化已从 FlameAdapterManager.initSDKWithAppId 迁移至此。
    // Core binary 中的 FlameAdapterManager 不再含 AnyThink 初始化逻辑（Core 模式下
    // initSDKWithAppId 整体被宏置空），插件源码必须在此直接完成初始化。
    // 行为与改造前 FlameAdapterManager.initSDKWithAppId 完全一致：
    //   1. 开启日志 + 集成环境检测
    //   2. startWithAppID:appKey:error:
    //   3. 成功/失败回调
    if ([FlameAdapterManager isInitialized]) {
        [FlameLogger w:@"FlameSdk is already initialized."];
        if (callback && [callback respondsToSelector:@selector(success)]) {
            [callback success];
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
        [FlameLogger e:[NSString stringWithFormat:@"FlameSdk UP-SDK Start Failed: %@", error.localizedDescription]];
        if (callback && [callback respondsToSelector:@selector(fail:desc:)]) {
            [callback fail:[NSString stringWithFormat:@"%ld", (long)error.code]
                     desc:error.localizedDescription];
        }
    } else {
        [FlameLogger i:@"FlameSdk initialized successfully."];
        if (callback && [callback respondsToSelector:@selector(success)]) {
            [callback success];
        }
    }
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
