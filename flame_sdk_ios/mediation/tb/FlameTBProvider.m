//
//  FlameTBProvider.m
//  FlameSDK
//
//  Created by flame.
//  Copyright © 2026 Flame. All rights reserved.
//

// TB 平台源码（Phase 5A.12 mainline：始终编译，不再用宏隔离）
#import "FlameTBProvider.h"
#import "FlameLogger.h"
#import "FlameMediationRegistry.h"
#import <WindMillSDK/WindMillSDK.h>
#import "TbRewardAdapter.h"
#import "TbInterstitialAdapter.h"
#import "TbSplashAdapter.h"
#import "TbBannerAdapter.h"
#import "FlameRewardAd.h"
#import "FlameSplashAd.h"
#import "FlameInterstitialAd.h"
#import "FlameBannerAd.h"
#import "FlameNativeAd.h"

/// TB 平台标识常量
static NSString * const kFlamePlatformTB = @"tb";

@implementation FlameTBProvider

#pragma mark - +load 自动注册（Phase 5A.12 mainline：始终启用）

// dyld 加载 flame_sdk_ios.framework 时自动触发，将 FlameTBProvider 注册到 Registry。
// +load 只做注册，不调用 WindMill/ToBid SDK（初始化延迟到 Router 激活后的 initializeWithAppId）。
+ (void)load {
    @autoreleasepool {
        FlameTBProvider *provider = [[FlameTBProvider alloc] init];
        [[FlameMediationRegistry sharedRegistry] registerProvider:provider];
        [FlameLogger i:[NSString stringWithFormat:@"FlameTBProvider: +load 自动注册完成 (platformCode=%@)", [provider platformCode]]];
    }
}

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

#pragma mark - FlameSplashAdapterProtocol 创建（Phase 5A.15）

- (id<FlameSplashAdapterProtocol>)createSplashAdapterWithViewController:(UIViewController *)viewController
                                                           placementId:(NSString *)placementId
                                                              listener:(id<FlameSplashListener>)listener {
    TbSplashAdapter *adapter = [[TbSplashAdapter alloc] initWithViewController:viewController
                                                                    placementId:placementId
                                                                        listener:listener];
    return adapter;
}

- (id<FlameInterstitialAdapterProtocol>)createInterstitialAdapterWithViewController:(UIViewController *)viewController
                                                                  placementId:(NSString *)placementId
                                                                        listener:(id<FlameInterstitialListener>)listener {
    TbInterstitialAdapter *adapter = [[TbInterstitialAdapter alloc] initWithViewController:viewController
                                                                                placementId:placementId
                                                                                    listener:listener];
    return adapter;
}

#pragma mark - FlameBannerAdapterProtocol 创建（Phase 5A.16C）

- (id<FlameBannerAdapterProtocol>)createBannerAdapterWithPlacementId:(NSString *)placementId
                                                          renderType:(FlameBannerRenderType)renderType
                                                            listener:(id<FlameBannerListener>)listener {
    TbBannerAdapter *adapter = [[TbBannerAdapter alloc] initWithPlacementId:placementId
                                                                 renderType:renderType
                                                                   listener:listener];
    return adapter;
}

- (id<FlameNativeAdapterProtocol>)createNativeAdapterWithViewController:(UIViewController *)viewController
                                                          placementId:(NSString *)placementId
                                                                listener:(id<FlameNativeListener>)listener {
    return nil;
}

@end

