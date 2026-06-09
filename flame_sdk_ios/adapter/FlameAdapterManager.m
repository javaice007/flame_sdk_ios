//
//  FlameAdapterManager.m
//  FlameSDK
//
//  Created by flame.
//  Copyright © 2026 Flame. All rights reserved.
//

#import "FlameAdapterManager.h"
#import <AnyThinkSDK/AnyThinkSDK.h>

#import "FlameLogger.h"
#import "FlameCallback.h"
#import "FlameRewardAd.h"
#import "FlameInterstitialAd.h"
#import "FlameSplashAd.h"
#import "FlameNativeAd.h"

#import "AtRewardAdapter.h"
#import "AtInterstitialAdapter.h"
#import "AtSplashAdapter.h"
#import "AtBannerAdapter.h"
#import "AtNativeAdapter.h"


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

+ (void)setDebug:(BOOL)isDebug {
    // debug 状态下开启日志 TODO
    [ATAPI setLogEnabled:YES];
}

+ (BOOL)isInitialized {
    return [self sharedInstance].isInitialized;
}

+ (BOOL)checkInitialization {
    if (![self sharedInstance].isInitialized) {
        [FlameLogger e:@"FlameSdk must be initialized before requesting ads!"];
        return NO;
    }
    return YES;
}

+ (id<FlameRewardAd>)createRewardAdapter:(UIViewController *)viewController
                           atPlacementId:(NSString *)atPlacementId
                              listener:(id<FlameRewardListener>)listener{
    // 1. 安全检查：如果 SDK 未初始化，返回 nil
    if (![self sharedInstance].isInitialized) {
        [FlameLogger e:@"FlameSdk is NOT initialized! Please call initWithAppId:appKey: first."];
        return nil;
    }

    // 2. 参数合法性检查
    if (atPlacementId.length == 0) {
        [FlameLogger e:@"atPlacementId is empty, failed to create RewardAdapter."];
        return nil;
    }
    
    // 实例化当前类并传入监听器
    AtRewardAdapter *adapter = [[AtRewardAdapter alloc] initWithViewController:viewController
                                                                 atPlacementId:atPlacementId
                                                                      listener:listener];
    return adapter;
}

+ (id<FlameInterstitialAd>)createInterstitialAdapter:(UIViewController *)viewController
                                       atPlacementId:(NSString *)atPlacementId
                                            listener:(id<FlameInterstitialListener>)listener {
    // 1. 安全检查：如果 SDK 未初始化，返回 nil
    if (![self sharedInstance].isInitialized) {
        [FlameLogger e:@"FlameSdk is NOT initialized! Please call initWithAppId:appKey: first."];
        return nil;
    }

    // 2. 参数合法性检查
    if (atPlacementId.length == 0) {
        [FlameLogger e:@"atPlacementId is empty, failed to create InterstitialAdapter."];
        return nil;
    }
    
    // 实例化当前类并传入监听器
    AtInterstitialAdapter *adapter = [[AtInterstitialAdapter alloc] initWithViewController:viewController
                                                                             atPlacementId:atPlacementId
                                                                                  listener:listener];
    return adapter;
}


+ (id<FlameSplashAd>)createSplashAdAdapter:(UIViewController *)viewController
                             atPlacementId:(NSString *)atPlacementId
                                  listener:(id<FlameSplashListener>)listener {
    // 1. 安全检查：如果 SDK 未初始化，返回 nil
    if (![self sharedInstance].isInitialized) {
        [FlameLogger e:@"FlameSdk is NOT initialized! Please call initWithAppId:appKey: first."];
        return nil;
    }

    // 2. 参数合法性检查
    if (atPlacementId.length == 0) {
        [FlameLogger e:@"atPlacementId is empty, failed to create SplashAdapter."];
        return nil;
    }
    
    // 实例化当前类并传入监听器
    AtSplashAdapter *adapter = [[AtSplashAdapter alloc] initWithViewController:viewController
                                                                 atPlacementId:atPlacementId
                                                                      listener:listener];
    return adapter;
}

/**
 * 创建横幅广告适配器
 * @param atPlacementId   广告为ID
 * @param renderType    渲染模式
 * @param listener    监听器
 */
+ (id<FlameBannerAd>)createBannerAdapter:(NSString *)atPlacementId
                               renderType:(FlameBannerRenderType)renderType
                                 listener:(id<FlameBannerListener>)listener{
    // 1. 安全检查：如果 SDK 未初始化，返回 nil
    if (![self sharedInstance].isInitialized) {
        [FlameLogger e:@"FlameSdk is NOT initialized! Please call initWithAppId:appKey: first."];
        return nil;
    }

    // 2. 参数合法性检查
    if (atPlacementId.length == 0) {
        [FlameLogger e:@"atPlacementId is empty, failed to create BannerAdapter."];
        return nil;
    }

    // 实例化当前类并传入监听器
    AtBannerAdapter *adapter = [[AtBannerAdapter alloc] initWithPlacementId:atPlacementId
                                                                 renderType:renderType
                                                                   listener:listener];
    return adapter;
}

/**
 * 创建原生广告适配器
 * @param viewController view组件
 * @param atPlacementId   广告为ID
 * @param listener    监听器
 */
+ (id<FlameNativeAd>)createNativeAdapter:(UIViewController *)viewController
                           atPlacementId:(NSString *)atPlacementId
                                listener:(id<FlameNativeListener>)listener{
    // 1. 安全检查：如果 SDK 未初始化，返回 nil
    if (![self sharedInstance].isInitialized) {
        [FlameLogger e:@"FlameSdk is NOT initialized! Please call initWithAppId:appKey: first."];
        return nil;
    }

    // 2. 参数合法性检查
    if (atPlacementId.length == 0) {
        [FlameLogger e:@"atPlacementId is empty, failed to create NativeAdapter."];
        return nil;
    }
    
    // 实例化当前类并传入监听器
    AtNativeAdapter *adapter = [[AtNativeAdapter alloc] initWithViewController:viewController atPlacementId:atPlacementId listener:listener];
    return adapter;
}

@end
