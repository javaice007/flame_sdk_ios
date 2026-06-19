//
//  FlameTKProvider.m
//  FlameSDK
//
//  Created by flame.
//  Copyright © 2026 Flame. All rights reserved.
//

// TK 平台源码（Phase 5A.12 mainline：始终编译，不再用宏隔离）
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

#pragma mark - +load 自动注册（Phase 5A.12 mainline：始终启用）

// dyld 加载 flame_sdk_ios.framework 时自动触发，将 FlameTKProvider 注册到 Registry。
// +load 只做注册，不调用 AnyThink SDK（初始化延迟到 Router 激活后的 initializeWithAppId）。
+ (void)load {
    @autoreleasepool {
        FlameTKProvider *provider = [[FlameTKProvider alloc] init];
        [[FlameMediationRegistry sharedRegistry] registerProvider:provider];
        [FlameLogger i:[NSString stringWithFormat:@"FlameTKProvider: +load 自动注册完成 (platformCode=%@)", [provider platformCode]]];
    }
}

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

