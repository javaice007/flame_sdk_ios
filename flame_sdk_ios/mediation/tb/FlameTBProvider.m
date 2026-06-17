//
//  FlameTBProvider.m
//  FlameSDK
//
//  Created by flame.
//  Copyright © 2026 Flame. All rights reserved.
//

// TB 平台源码宏隔离：TK 构建变体下整个文件置空，避免编译期 import WindMill/ToBid
#if defined(FLAME_BUILD_TB)

#import "FlameTBProvider.h"
#import "FlameLogger.h"
#import "FlameMediationRegistry.h"
#import <WindMillSDK/WindMillSDK.h>
#import "TbRewardAdapter.h"
#import "FlameRewardAd.h"
#import "FlameSplashAd.h"
#import "FlameInterstitialAd.h"
#import "FlameBannerAd.h"
#import "FlameNativeAd.h"

/// TB 平台标识常量
static NSString * const kFlamePlatformTB = @"tb";

@implementation FlameTBProvider

#pragma mark - 插件自动注册（仅 Thin Core 插件模式启用）

// FLAME_PLUGIN_TB 仅由 research/podspecs/flame_sdk_ios.thin_core.tb.podspec 的
// pod_target_xcconfig 注入。旧双二进制构建（xcFramework_build.sh tb）只定义
// FLAME_BUILD_TB，不定义 FLAME_PLUGIN_TB，因此此处 +load 不会在旧 TB binary 中触发，
// 避免 Core binary + 旧 TB binary 同时存在时重复注册。
#if defined(FLAME_PLUGIN_TB)
+ (void)load {
    @autoreleasepool {
        FlameTBProvider *provider = [[FlameTBProvider alloc] init];
        [[FlameMediationRegistry sharedRegistry] registerProvider:provider];
        [FlameLogger i:[NSString stringWithFormat:@"FlameTBProvider: +load 自动注册完成 (plugin 模式, platformCode=%@)", [provider platformCode]]];
    }
}
#endif // FLAME_PLUGIN_TB

- (NSString *)platformCode {
    return kFlamePlatformTB;
}

- (void)initializeWithAppId:(NSString *)appId
                    appKey:(NSString *)appKey
                  callback:(id<FlameCallback>)callback {
    if (appId == nil || appId.length == 0) {
        if (callback && [callback respondsToSelector:@selector(fail:desc:)]) {
            [callback fail:@"14001" desc:@"ToBid init failed: appId is empty"];
        }
        return;
    }

    // appKey: ToBid / WindMill 初始化不需要 appKey，仅接收不使用

    // 初始化 ToBid / WindMill SDK
    // API 签名（已从 SDK 头文件确认）：
    // + (void)setupSDKWithAppId:(NSString *)appId completionHandler:(void (^)(BOOL success, NSError *error))completionHandler;
    __weak typeof(callback) weakCallback = callback;
    [WindMillAds setupSDKWithAppId:appId completionHandler:^(BOOL success, NSError *error) {
        if (!success) {
            id<FlameCallback> cb = weakCallback;
            if (cb && [cb respondsToSelector:@selector(fail:desc:)]) {
                NSString *desc = error ? error.localizedDescription : @"ToBid SDK init failed (unknown reason)";
                [cb fail:@"14001" desc:desc];
            }
            return;
        }
        id<FlameCallback> cb = weakCallback;
        if (cb && [cb respondsToSelector:@selector(success)]) {
            [cb success];
        }
    }];
    [WindMillAds setDebugEnable:YES];
}

#pragma mark - FlameRewardAdapterProtocol 创建（Phase 5A）

- (id<FlameRewardAdapterProtocol>)createRewardAdapterWithViewController:(UIViewController *)viewController
                                                           placementId:(NSString *)placementId
                                                              listener:(id<FlameRewardListener>)listener {
    TbRewardAdapter *adapter = [[TbRewardAdapter alloc] initWithViewController:viewController
                                                                    placementId:placementId
                                                                        listener:listener];
    return adapter;
}

#pragma mark - Phase 6 占位（本阶段不实现，返回 nil）

- (id<FlameSplashAdapterProtocol>)createSplashAdapterWithViewController:(UIViewController *)viewController
                                                           placementId:(NSString *)placementId
                                                              listener:(id<FlameSplashListener>)listener {
    return nil;
}

- (id<FlameInterstitialAdapterProtocol>)createInterstitialAdapterWithViewController:(UIViewController *)viewController
                                                                  placementId:(NSString *)placementId
                                                                        listener:(id<FlameInterstitialListener>)listener {
    return nil;
}

- (id<FlameBannerAdapterProtocol>)createBannerAdapterWithPlacementId:(NSString *)placementId
                                                          renderType:(FlameBannerRenderType)renderType
                                                            listener:(id<FlameBannerListener>)listener {
    return nil;
}

- (id<FlameNativeAdapterProtocol>)createNativeAdapterWithViewController:(UIViewController *)viewController
                                                          placementId:(NSString *)placementId
                                                                listener:(id<FlameNativeListener>)listener {
    return nil;
}

@end

#endif // FLAME_BUILD_TB
