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
#import "FlameErrorCode.h"

#import "FlameRewardAdImpl.h"
#import "FlameInterstitialAdImpl.h"
#import "FlameSplashAdImpl.h"
#import "FlameBannerAdImpl.h"
#import "FlameNativeAdImpl.h"
#import "FlameDrawAdImpl.h"

// SDK初始化状态枚举
typedef NS_ENUM(NSInteger, FlameSDKInitState) {
    FlameSDKInitStateUninitialized = 0,  // 未初始化
    FlameSDKInitStateInitializing,        // 初始化中
    FlameSDKInitStateInitialized,         // 已初始化
    FlameSDKInitStateFailed              // 初始化失败
};


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
 * 成功回调 - 配置获取成功，继续初始化Adapter
 */
- (void)success{
    NSString *aId = [[FlameConfigManager sharedInstance] getAId];
    NSString *aKey = [[FlameConfigManager sharedInstance] getAKey];

    // 创建Adapter初始化回调，会在成功/失败时更新SDK状态
    AdapterInitCallback *adapterCallback = [[AdapterInitCallback alloc] initWithCallback:self.initCallback];
    [FlameAdapterManager initSDKWithAppId:aId appKey:aKey initListener:adapterCallback];
}

/**
 * 失败回调 - 配置获取失败
 * @param code 错误码
 * @param desc 错误描述
 */
- (void)fail:(NSString *)code
        desc:(NSString *)desc{
    [FlameLogger e:[NSString stringWithFormat:@"Config fetch failed:[code= %@], [desc=%@]", code, desc]];

    // 更新状态为失败
    [FlameSdk sharedInstance].initState = FlameSDKInitStateFailed;

    // 转发失败回调给 initCallback
    if ([self.initCallback respondsToSelector:@selector(fail:desc:)]) {
        [self.initCallback fail:code desc:desc];
    }
}

@end


@interface AdapterInitCallback : NSObject<FlameCallback>

@property (nonatomic, weak) id<FlameCallback> userCallback;

- (instancetype)initWithCallback:(id<FlameCallback>)callback;

@end

@implementation AdapterInitCallback

- (instancetype)initWithCallback:(id<FlameCallback>)callback {
    self = [super init];
    if (self) {
        _userCallback = callback;
    }
    return self;
}

- (void)success {
    // 更新SDK状态为已初始化
    [FlameSdk sharedInstance].initState = FlameSDKInitStateInitialized;

    // 转发给用户回调
    if ([self.userCallback respondsToSelector:@selector(success)]) {
        [self.userCallback success];
    }
}

- (void)fail:(NSString *)code desc:(NSString *)desc {
    // 更新SDK状态为失败
    [FlameSdk sharedInstance].initState = FlameSDKInitStateFailed;

    [FlameLogger e:[NSString stringWithFormat:@"AdapterManager init failed:[code= %@], [desc=%@]", code, desc]];

    // 转发给用户回调
    if ([self.userCallback respondsToSelector:@selector(fail:desc:)]) {
        [self.userCallback fail:code desc:desc];
    }
}

@end


@interface FlameSdk ()
@property (nonatomic, assign, readwrite) BOOL isInitialized;
@property (atomic, assign) FlameSDKInitState initState;  // 初始化状态
@property (nonatomic, strong) dispatch_semaphore_t initSemaphore;  // 初始化信号量
@end

@implementation FlameSdk

+ (instancetype)sharedInstance {
    static FlameSdk *_instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [[super allocWithZone:NULL] init];
    });
    return _instance;
}

+ (instancetype)allocWithZone:(struct _NSZone *)zone {
    return [self sharedInstance];
}

- (instancetype)copyWithZone:(NSZone *)zone {
    return self;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _initState = FlameSDKInitStateUninitialized;
        _initSemaphore = dispatch_semaphore_create(1);
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
    FlameSdk *instance = [self sharedInstance];

    // 使用信号量防止并发初始化
    dispatch_semaphore_wait(instance.initSemaphore, DISPATCH_TIME_FOREVER);

    // 检查当前状态
    FlameSDKInitState currentState = instance.initState;

    if (currentState == FlameSDKInitStateInitialized) {
        dispatch_semaphore_signal(instance.initSemaphore);
        [FlameLogger w:@"FlameSdk is already initialized."];
        if (callback) {
            [callback success];
        }
        return;
    }

    if (currentState == FlameSDKInitStateInitializing) {
        dispatch_semaphore_signal(instance.initSemaphore);
        [FlameLogger w:@"FlameSdk is initializing, please wait."];
        if (callback) {
            [callback fail:@"-1" desc:@"SDK is already initializing"];
        }
        return;
    }

    // 设置为初始化中状态
    instance.initState = FlameSDKInitStateInitializing;
    dispatch_semaphore_signal(instance.initSemaphore);

    // 创建包装回调，在完成时更新状态
    UpdateAppCallback *cb = [[UpdateAppCallback alloc] initWithInitCallback:callback];
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

        // 触发错误回调通知开发者
        if (listener && [listener respondsToSelector:@selector(onAdError:desc:)]) {
            [listener onAdError:ERROR_CODE_INVALID_AD_PLACEMENT
                           desc:[NSString stringWithFormat:@"Invalid placement ID: %@", placementId]];
        }

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

        // 触发错误回调通知开发者
        if (listener && [listener respondsToSelector:@selector(onAdError:desc:)]) {
            [listener onAdError:ERROR_CODE_INVALID_AD_PLACEMENT
                           desc:[NSString stringWithFormat:@"Invalid placement ID: %@", placementId]];
        }

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

        // 触发错误回调通知开发者
        if (listener && [listener respondsToSelector:@selector(onAdError:desc:)]) {
            [listener onAdError:ERROR_CODE_INVALID_AD_PLACEMENT
                           desc:[NSString stringWithFormat:@"Invalid placement ID: %@", placementId]];
        }

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

        // 触发错误回调通知开发者
        if (listener && [listener respondsToSelector:@selector(onAdError:desc:)]) {
            [listener onAdError:ERROR_CODE_INVALID_AD_PLACEMENT
                           desc:[NSString stringWithFormat:@"Invalid placement ID: %@", placementId]];
        }

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

        // 触发错误回调通知开发者
        if (listener && [listener respondsToSelector:@selector(onAdError:desc:)]) {
            [listener onAdError:ERROR_CODE_INVALID_AD_PLACEMENT
                           desc:[NSString stringWithFormat:@"Invalid placement ID: %@", placementId]];
        }

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

        // 触发错误回调通知开发者
        if (listener && [listener respondsToSelector:@selector(onAdError:desc:)]) {
            [listener onAdError:ERROR_CODE_INVALID_AD_PLACEMENT
                           desc:[NSString stringWithFormat:@"Invalid placement ID: %@", placementId]];
        }

        // 3. 返回 nil，因为无法创建有效的广告对象
        return nil;
    }

    return [[FlameDrawAdImpl alloc] initWithViewController:viewController placementId:pId listener:listener];
}

@end
