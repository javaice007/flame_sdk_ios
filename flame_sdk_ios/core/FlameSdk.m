//
//  FlameSdk.m
//  FlameSDK
//
//  Created by flame.
//  Copyright © 2026 Flame. All rights reserved.
//

#import "FlameSdk.h"
#import "FlameConfigManager.h"
#import "FlameAdapterManager.h"
#import "FlameLogger.h"

#import "FlameRewardAdImpl.h"
#import "FlameInterstitialAdImpl.h"
#import "FlameSplashAdImpl.h"
#import "FlameBannerAdImpl.h"
#import "FlameNativeAdImpl.h"
#import "FlameDrawAdImpl.h"


@interface UpdateAppCallback : NSObject<FlameCallback>

@property (nonatomic, strong) id<FlameCallback> initCallback;

/**
 * 自定义初始化方法
 * @param callback 外部传入的初始回调实现
 */
- (instancetype)initWithInitCallback:(id<FlameCallback>)callback;

@end

@implementation UpdateAppCallback

- (instancetype)initWithInitCallback:(id<FlameCallback>)callback {
    self = [super init];
    if (self) {
        _initCallback = callback;
    }
    return self;
}

#pragma mark - FlameCallback 实现
/**
 * 成功回调
 */
- (void)success{
    NSString *aId = [[FlameConfigManager sharedInstance] getAId];
    NSString *aKey = [[FlameConfigManager sharedInstance] getAKey];

    [FlameAdapterManager initSDKWithAppId:aId appKey:aKey initListener:self.initCallback];
}

/**
 * 失败回调
 * @param code 错误码
 * @param desc 错误描述
 */
- (void)fail:(NSString *)code
        desc:(NSString *)desc{
    [FlameLogger e:[NSString stringWithFormat:@"tk SDK Start Failed:[code= %@], [desc=%@]", code, desc]];
    
    // 转发失败回调给 initCallback
    if ([self.initCallback respondsToSelector:@selector(fail:desc:)]) {
        [self.initCallback fail:code desc:desc];
    }
}

@end


@interface FlameSdk ()
@property (nonatomic, assign, readwrite) BOOL isInitialized;
@end

@implementation FlameSdk

static FlameSdk *_instance = nil;

+ (instancetype)sharedInstance {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [[self alloc] init];
    });
    return _instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
    }
    return self;
}

/**
 * 清空缓存
 */
+ (void)clear {
    [[FlameConfigManager sharedInstance] clearCache];
}

+ (void)initWithAppId:(NSString *)appId appKey:(NSString *)appKey {
    [self initWithAppId:appId appKey:appKey callback:nil];
}

+ (void)initWithAppId:(NSString *)appId appKey:(NSString *)appKey callback:(id<FlameCallback>)callback {
    
    if ([self sharedInstance].isInitialized) {
        [FlameLogger w:@"FlameSdk is already initialized."];
        return;
    }
    
    UpdateAppCallback *cb = [[UpdateAppCallback alloc] initWithInitCallback: callback];
    [[FlameConfigManager sharedInstance] updateAppWithAppId:appId appKey:appKey callback:cb];
}

+ (void)setDebug:(BOOL)isDebug {
    [FlameAdapterManager setDebug:isDebug];
}

+ (BOOL)isInitialized {
    return [FlameAdapterManager sharedInstance].isInitialized;
}

+ (void)checkInitialization {
    if (![FlameAdapterManager sharedInstance].isInitialized) {
        @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                       reason:@"FlameSdk must be initialized before requesting ads!"
                                     userInfo:nil];
    }
}

- (NSString *)getVersion {
    return [[FlameConfigManager sharedInstance] getSdkVersion];
}


+ (id<FlameRewardAd>)createRewardAdWithViewController:(UIViewController *)viewController
                                        placementId:(NSString *)placementId
                                           listener:(id<FlameRewardListener>)listener{
    // 1. 获取 pId
    NSString *pId = [[FlameConfigManager sharedInstance] getPId:placementId];
    
    // 2. 对 pId 进行异常判定 (判断是否为空或无效)
    if (pId == nil || pId.length == 0) {
        // 错误日志记录
        [FlameLogger e:[NSString stringWithFormat:@"Create RewardAd Failed: Invalid placementId original=%@, mapped=%@", placementId, pId]];
        // 3. 返回 nil，因为无法创建有效的广告对象
        return nil;
    }
    
    return [[FlameRewardAdImpl alloc] initWithViewController:viewController placementId:pId listener:listener];
}

/**
 * 创建插屏广告实例
 * @param viewController    视图控制器
 * @param placementId           广告位ID
 * @param listener                  回调函数
 */
+ (id<FlameInterstitialAd>)createInterstitialAdWithViewController:(UIViewController *)viewController
                                                      placementId:(NSString *)placementId
                                                         listener:(id<FlameInterstitialListener>)listener {
    // 1. 获取 pId
    NSString *pId = [[FlameConfigManager sharedInstance] getPId:placementId];
    
    // 2. 对 pId 进行异常判定 (判断是否为空或无效)
    if (pId == nil || pId.length == 0) {
        // 错误日志记录
        [FlameLogger e:[NSString stringWithFormat:@"Create InterstitialAd Failed: Invalid placementId original=%@, mapped=%@", placementId, pId]];
        // 3. 返回 nil，因为无法创建有效的广告对象
        return nil;
    }
    
    return [[FlameInterstitialAdImpl alloc] initWithViewController:viewController placementId:pId listener:listener];
}

+ (id<FlameSplashAd>)createSplashAdWithViewController:(UIViewController *)viewController
                                          placementId:(NSString *)placementId
                                             listener:(id<FlameSplashListener>)listener {
    // 1. 获取 pId
    NSString *pId = [[FlameConfigManager sharedInstance] getPId:placementId];
    
    // 2. 对 pId 进行异常判定 (判断是否为空或无效)
    if (pId == nil || pId.length == 0) {
        // 错误日志记录
        [FlameLogger e:[NSString stringWithFormat:@"Create SplashAd Failed: Invalid placementId original=%@, mapped=%@", placementId, pId]];
        // 3. 返回 nil，因为无法创建有效的广告对象
        return nil;
    }
    
    return [[FlameSplashAdImpl alloc] initWithViewController:viewController placementId:pId listener:listener];
}

/**
 * 创建横幅广告实例
 * @param placementId           广告位ID
 * @param listener                  回调函数
 */
+ (id<FlameBannerAd>)createBannerAdWithPlacementId:(NSString *)placementId
                                          listener:(id<FlameBannerListener>)listener{
    // 1. 获取 pId
    NSString *pId = [[FlameConfigManager sharedInstance] getPId:placementId];
    
    // 2. 对 pId 进行异常判定 (判断是否为空或无效)
    if (pId == nil || pId.length == 0) {
        // 错误日志记录
        [FlameLogger e:[NSString stringWithFormat:@"Create BannerAd Failed: Invalid placementId original=%@, mapped=%@", placementId, pId]];
        // 3. 返回 nil，因为无法创建有效的广告对象
        return nil;
    }
    
    return [[FlameBannerAdImpl alloc] initWithPlacementId:pId listener:listener];
}

/**
 * 创建原生广告实例
 * @param placementId           广告位ID
 * @param listener                  回调函数
 */
+ (id<FlameNativeAd>)createNativeAdWithViewController:(UIViewController *)viewController
                                          placementId:(NSString *)placementId
                                             listener:(id<FlameNativeListener>)listener{
    // 1. 获取 pId
    NSString *pId = [[FlameConfigManager sharedInstance] getPId:placementId];
    
    // 2. 对 pId 进行异常判定 (判断是否为空或无效)
    if (pId == nil || pId.length == 0) {
        // 错误日志记录
        [FlameLogger e:[NSString stringWithFormat:@"Create NativeAd Failed: Invalid placementId original=%@, mapped=%@", placementId, pId]];
        // 3. 返回 nil，因为无法创建有效的广告对象
        return nil;
    }
    
    return [[FlameNativeAdImpl alloc] initWithViewController:viewController placementId:pId listener:listener];
}

/**
 * 创建视频流广告实例
 * @param viewController    视图控制器
 * @param placementId           广告位ID
 * @param listener                  回调函数
 */
+ (id<FlameDrawAd>)createDrawAdWithViewController:(UIViewController *)viewController
                                      placementId:(NSString *)placementId
                                         listener:(id<FlameDrawListener>)listener {
    // 1. 获取 pId
    NSString *pId = [[FlameConfigManager sharedInstance] getPId:placementId];
    
    // 2. 对 pId 进行异常判定 (判断是否为空或无效)
    if (pId == nil || pId.length == 0) {
        // 错误日志记录
        [FlameLogger e:[NSString stringWithFormat:@"Create DrawAd Failed: Invalid placementId original=%@, mapped=%@", placementId, pId]];
        // 3. 返回 nil，因为无法创建有效的广告对象
        return nil;
    }
    
    return [[FlameDrawAdImpl alloc] initWithViewController:viewController placementId:pId listener:listener];
}

@end
