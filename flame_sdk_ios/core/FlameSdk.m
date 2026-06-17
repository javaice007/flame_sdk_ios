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

#import "FlameMediationRegistry.h"
#import "FlameMediationRouter.h"

// ============================================================
// 构建宏隔离：TK / TB / CORE 三变体
//   FLAME_BUILD_TK=1   → 只注册 FlameTKProvider（默认 TK 包）
//   FLAME_BUILD_TB=1   → 只注册 FlameTBProvider（TB 包）
//   FLAME_BUILD_CORE=1 → Thin Core 包：不注册任何内置 Provider，
//                        平台源码插件由 podspec source_files 编译进接入方 App 后
//                        自行注册（Step 2 实现）；create*Ad 仍走 Router.currentProvider。
//   三个宏都未定义时 → 按 TK 处理（源码开发兼容）
//   正式构建由 xcFramework_build.sh 显式注入宏，不依赖默认值
// ============================================================
#if defined(FLAME_BUILD_TK) && defined(FLAME_BUILD_TB)
#error "FLAME_BUILD_TK and FLAME_BUILD_TB cannot both be defined"
#endif

// 默认 TK 条件：显式 TK，或三个宏都未定义（源码开发兼容）。
// CORE 模式下显式排除，确保 Core binary 不直接 import FlameTKProvider。
#if defined(FLAME_BUILD_TK) || (!defined(FLAME_BUILD_TK) && !defined(FLAME_BUILD_TB) && !defined(FLAME_BUILD_CORE))
#import "FlameTKProvider.h"
#endif

#if defined(FLAME_BUILD_TB)
#import "FlameTBProvider.h"
#endif

#import "FlameRewardAdapterProtocol.h"
#import "FlameSplashAdapterProtocol.h"
#import "FlameInterstitialAdapterProtocol.h"
#import "FlameBannerAdapterProtocol.h"
#import "FlameNativeAdapterProtocol.h"

#import "FlameRewardAdImpl.h"
#import "FlameInterstitialAdImpl.h"
#import "FlameSplashAdImpl.h"
#import "FlameBannerAdImpl.h"
#import "FlameNativeAdImpl.h"

// SDK初始化状态枚举
typedef NS_ENUM(NSInteger, FlameSDKInitState) {
    FlameSDKInitStateUninitialized = 0,  // 未初始化
    FlameSDKInitStateInitializing,        // 初始化中
    FlameSDKInitStateInitialized,         // 已初始化
    FlameSDKInitStateFailed              // 初始化失败
};

// FlameSdk 私有接口
@interface FlameSdk ()
@property (nonatomic, assign, readwrite) BOOL isInitialized;
@property (atomic, assign) FlameSDKInitState initState;  // 初始化状态

// 等待中的初始化回调列表（Initializing 状态下多调用方共享等待）
@property (atomic, strong) NSMutableArray<id<FlameCallback>> *pendingCallbacks;

// 内部方法：更新初始化状态
+ (void)updateInitState:(FlameSDKInitState)state;

// 内部方法：注册所有 Provider（仅执行一次）
+ (void)registerAllProvidersIfNeeded;

@end

// ============= 初始化回调辅助类 =============

// AdapterInitCallback 接口定义（需要在 UpdateAppCallback 实现之前）
@interface AdapterInitCallback : NSObject<FlameCallback>

@property (atomic, strong) id<FlameCallback> userCallback;
@property (atomic, assign) BOOL hasCalled;  // 防止重复回调

- (instancetype)initWithCallback:(id<FlameCallback>)callback;

@end

// UpdateAppCallback 接口定义
@interface UpdateAppCallback : NSObject<FlameCallback>

@property (atomic, strong) id<FlameCallback> initCallback;
@property (atomic, assign) BOOL hasCalled;  // 防止 success/fail 重复调用

/**
 * 自定义初始化方法
 * @param callback 外部传入的初始回调实现
 */
- (instancetype)initWithInitCallback:(id<FlameCallback>)callback;

@end

// UpdateAppCallback 实现
@implementation UpdateAppCallback

- (instancetype)initWithInitCallback:(id<FlameCallback>)callback {
    self = [super init];
    if (self) {
        _initCallback = callback;
        _hasCalled = NO;
    }
    return self;
}

- (void)dealloc {
    [FlameLogger i:[NSString stringWithFormat:@"[DIAG] UpdateAppCallback=%p dealloc. initCallback=%p", (void *)self, (void *)_initCallback]];
}

#pragma mark - FlameCallback 实现
/**
 * 成功回调 - 配置获取成功，通过 Registry → Router → Provider 初始化聚合平台
 */
- (void)success{
    @synchronized (self) {
        if (_hasCalled) return;
        _hasCalled = YES;
    }

    [FlameLogger i:[NSString stringWithFormat:@"[DIAG] UpdateAppCallback=%p success called. initCallback=%p", (void *)self, (void *)_initCallback]];

    // 确保 Provider 已注册（仅执行一次）
    [FlameSdk registerAllProvidersIfNeeded];

    NSString *pt = [[FlameConfigManager sharedInstance] getPt];

    // pt 为空时兼容旧缓存：默认 tk 并记录日志
    if (!pt || pt.length == 0) {
        pt = @"tk";
        [FlameLogger w:@"FlameSdk: pt 为空，兼容默认使用 tk（可能来自旧缓存）"];
    }

    [FlameLogger i:[NSString stringWithFormat:@"FlameSdk: pt=%@, 开始通过 Registry 查找 Provider", pt]];

    // 从 Registry 查找对应 Provider
    id<FlameMediationProvider> provider = [[FlameMediationRegistry sharedRegistry] providerForPlatformCode:pt];

    if (!provider) {
        // 未找到 Provider：返回 14003 不支持的聚合平台
        [FlameLogger e:[NSString stringWithFormat:@"FlameSdk: 不支持的聚合平台 pt=%@", pt]];

        [FlameSdk updateInitState:FlameSDKInitStateFailed];

        // 直接 IVAR 访问：避免 atomic getter 的 autorelease over-release
        id<FlameCallback> callbackToForward = _initCallback;
        _initCallback = nil;

        if (callbackToForward && [callbackToForward respondsToSelector:@selector(fail:desc:)]) {
            [callbackToForward fail:ERROR_CODE_UNSUPPORTED_PLATFORM
                             desc:[NSString stringWithFormat:@"Unsupported mediation platform: %@", pt]];
        }
        return;
    }

    // 找到 Provider：通过 Router 激活
    [[FlameMediationRouter sharedRouter] activateProvider:provider];
    [FlameLogger i:[NSString stringWithFormat:@"FlameSdk: Router 已激活 Provider (pt=%@)", pt]];

    NSString *aId = [[FlameConfigManager sharedInstance] getAId];
    NSString *aKey = [[FlameConfigManager sharedInstance] getAKey];

    // 通过 Provider 初始化聚合平台 SDK
    // 创建 AdapterInitCallback 包装用户回调，在 Provider 初始化完成时更新 SDK 状态
    id<FlameCallback> initCallbackRef = _initCallback;
    _initCallback = nil;
    AdapterInitCallback *adapterCallback = [[AdapterInitCallback alloc] initWithCallback:initCallbackRef];
    [FlameLogger i:[NSString stringWithFormat:@"[DIAG] Created AdapterInitCallback=%p with userCallback=%p", (void *)adapterCallback, (void *)initCallbackRef]];

    [provider initializeWithAppId:aId appKey:aKey callback:adapterCallback];
}

/**
 * 失败回调 - 配置获取失败
 * @param code 错误码
 * @param desc 错误描述
 */
- (void)fail:(NSString *)code
        desc:(NSString *)desc{
    @synchronized (self) {
        if (_hasCalled) return;
        _hasCalled = YES;
    }

    [FlameLogger e:[NSString stringWithFormat:@"[DIAG] UpdateAppCallback=%p fail called. initCallback=%p RC=%lu", (void *)self, (void *)_initCallback, (unsigned long)CFGetRetainCount((__bridge CFTypeRef)self)]];

    [FlameLogger e:[NSString stringWithFormat:@"Config fetch failed:[code= %@], [desc=%@]", code, desc]];

    // 更新状态为失败
    [FlameSdk updateInitState:FlameSDKInitStateFailed];

    // 转发失败回调给 initCallback
    // 直接 IVAR 访问：避免 atomic getter 的 objc_autoreleaseReturnValue
    // 在 Debug 模式下产生延迟 autorelease，导致 pool drain 时 over-release
    id<FlameCallback> callbackToForward = _initCallback;
    _initCallback = nil;

    [FlameLogger e:[NSString stringWithFormat:@"[DIAG] After extract: self RC=%lu, callbackToForward=%p RC=%lu", (unsigned long)CFGetRetainCount((__bridge CFTypeRef)self), (void *)callbackToForward, (unsigned long)CFGetRetainCount((__bridge CFTypeRef)callbackToForward)]];

    if (callbackToForward && [callbackToForward respondsToSelector:@selector(fail:desc:)]) {
        [FlameLogger e:[NSString stringWithFormat:@"[DIAG] About to call initCallback.fail on %p", (void *)callbackToForward]];
        [callbackToForward fail:code desc:desc];
        [FlameLogger e:[NSString stringWithFormat:@"[DIAG] initCallback.fail returned for %p", (void *)callbackToForward]];
    }

    [FlameLogger e:[NSString stringWithFormat:@"[DIAG] UpdateAppCallback=%p fail method returning", (void *)self]];
}

@end

// AdapterInitCallback 实现

@implementation AdapterInitCallback

- (instancetype)initWithCallback:(id<FlameCallback>)callback {
    self = [super init];
    if (self) {
        _userCallback = callback;
        _hasCalled = NO;
    }
    return self;
}

- (void)dealloc {
    [FlameLogger i:[NSString stringWithFormat:@"[DIAG] AdapterInitCallback=%p dealloc. userCallback=%p", (void *)self, (void *)_userCallback]];
}

- (void)success {
    @synchronized (self) {
        if (_hasCalled) return;
        _hasCalled = YES;
    }

    [FlameLogger i:[NSString stringWithFormat:@"[DIAG] AdapterInitCallback=%p success. userCallback=%p", (void *)self, (void *)_userCallback]];

    // 更新SDK状态为已初始化
    [FlameSdk updateInitState:FlameSDKInitStateInitialized];

    // 转发给所有等待中的用户回调 + 当前回调
    FlameSdk *instance = [FlameSdk sharedInstance];

    // 先在锁内 copy 并清空，再在锁外回调，避免 callback 重入导致死锁
    NSArray *callbacksToNotify = nil;
    @synchronized (instance) {
        callbacksToNotify = [instance.pendingCallbacks copy];
        [instance.pendingCallbacks removeAllObjects];
    }

    // 直接 IVAR 访问：避免 atomic getter 的 autorelease over-release
    id<FlameCallback> userCb = _userCallback;
    _userCallback = nil;

    if (userCb && [userCb respondsToSelector:@selector(success)]) {
        [FlameLogger i:[NSString stringWithFormat:@"[DIAG] Calling userCallback.success on %p", (void *)userCb]];
        [userCb success];
        [FlameLogger i:[NSString stringWithFormat:@"[DIAG] userCallback.success returned for %p", (void *)userCb]];
    }

    for (id<FlameCallback> cb in callbacksToNotify) {
        [FlameLogger i:[NSString stringWithFormat:@"[DIAG] Notifying pendingCallback %p (success)", (void *)cb]];
        if ([cb respondsToSelector:@selector(success)]) {
            [cb success];
        }
    }
    [FlameLogger i:[NSString stringWithFormat:@"[DIAG] AdapterInitCallback=%p success done", (void *)self]];
}

- (void)fail:(NSString *)code desc:(NSString *)desc {
    @synchronized (self) {
        if (_hasCalled) return;
        _hasCalled = YES;
    }

    [FlameLogger i:[NSString stringWithFormat:@"[DIAG] AdapterInitCallback=%p fail. userCallback=%p", (void *)self, (void *)_userCallback]];

    // 更新SDK状态为失败
    [FlameSdk updateInitState:FlameSDKInitStateFailed];

    [FlameLogger e:[NSString stringWithFormat:@"AdapterManager init failed:[code= %@], [desc=%@]", code, desc]];

    // 转发给所有等待中的用户回调 + 当前回调
    FlameSdk *instance = [FlameSdk sharedInstance];

    // 先在锁内 copy 并清空，再在锁外回调，避免 callback 重入导致死锁
    NSArray *callbacksToNotify = nil;
    @synchronized (instance) {
        callbacksToNotify = [instance.pendingCallbacks copy];
        [instance.pendingCallbacks removeAllObjects];
    }

    // 直接 IVAR 访问：避免 atomic getter 的 autorelease over-release
    id<FlameCallback> callbackToForward = _userCallback;
    _userCallback = nil;

    if (callbackToForward && [callbackToForward respondsToSelector:@selector(fail:desc:)]) {
        [FlameLogger i:[NSString stringWithFormat:@"[DIAG] Calling userCallback.fail on %p", (void *)callbackToForward]];
        [callbackToForward fail:code desc:desc];
        [FlameLogger i:[NSString stringWithFormat:@"[DIAG] userCallback.fail returned for %p", (void *)callbackToForward]];
    }

    for (id<FlameCallback> cb in callbacksToNotify) {
        [FlameLogger i:[NSString stringWithFormat:@"[DIAG] Notifying pendingCallback %p (fail code=%@)", (void *)cb, code]];
        if ([cb respondsToSelector:@selector(fail:desc:)]) {
            [cb fail:code desc:desc];
        }
    }

    [FlameLogger i:[NSString stringWithFormat:@"[DIAG] AdapterInitCallback=%p fail done", (void *)self]];
}

@end

@implementation FlameSdk

+ (instancetype)sharedInstance {
    static FlameSdk *_instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // 直接调用父类的 allocWithZone: 避免递归
        _instance = [[super allocWithZone:NULL] init];
    });
    return _instance;
}

// 移除 allocWithZone: 和 copyWithZone: 重写，避免递归问题

- (instancetype)init {
    self = [super init];
    if (self) {
        _initState = FlameSDKInitStateUninitialized;
        _pendingCallbacks = [NSMutableArray array];
    }
    return self;
}

#pragma mark - 内部方法

/**
 * 更新SDK初始化状态（内部方法）
 */
+ (void)updateInitState:(FlameSDKInitState)state {
    [self sharedInstance].initState = state;
}

+ (void)registerAllProvidersIfNeeded {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // 构建变体决定注册哪些 Provider，不在 create*Ad 中做平台判断
        // Provider 选择仍通过 Registry → Router
        //
        // CORE 变体（FLAME_BUILD_CORE=1）：此处不注册任何内置 Provider。
        //   Core binary 不含 TK/TB 平台源码，Provider 由 Step 2 的平台源码插件
        //   （podspec source_files）在接入方 App 编译时自动注册。
        //   若 Core binary 单独运行（无插件），create*Ad 会走 Router.currentProvider=nil
        //   分支，返回 "No active provider" 错误，符合预期。
#if defined(FLAME_BUILD_TK) || (!defined(FLAME_BUILD_TK) && !defined(FLAME_BUILD_TB) && !defined(FLAME_BUILD_CORE))
        // TK 变体：注册 FlameTKProvider（TK / TopOn / AnyThink）
        FlameTKProvider *tkProvider = [[FlameTKProvider alloc] init];
        [[FlameMediationRegistry sharedRegistry] registerProvider:tkProvider];
        [FlameLogger i:@"FlameSdk: FlameTKProvider 已注册到 Registry"];
#endif

#if defined(FLAME_BUILD_TB)
        // TB 变体：注册 FlameTBProvider（TB / ToBid / WindMill）
        FlameTBProvider *tbProvider = [[FlameTBProvider alloc] init];
        [[FlameMediationRegistry sharedRegistry] registerProvider:tbProvider];
        [FlameLogger i:@"FlameSdk: FlameTBProvider 已注册到 Registry"];
#endif
    });
}

/**
 * 清空缓存，重置初始化状态，允许重新初始化
 */
+ (void)clear {
    FlameSdk *instance = [self sharedInstance];
    [FlameLogger i:[NSString stringWithFormat:@"[DIAG] FlameSdk.clear called. currentState=%ld, pendingCallbacks.count=%lu", (long)instance.initState, (unsigned long)instance.pendingCallbacks.count]];
    @synchronized (instance) {
        instance.initState = FlameSDKInitStateUninitialized;
        [instance.pendingCallbacks removeAllObjects];
    }
    [[FlameConfigManager sharedInstance] clearCache];
    // 同步重置 Router，清除当前激活的 Provider
    [[FlameMediationRouter sharedRouter] clear];
    [FlameLogger i:@"FlameSdk cleared, ready for re-init"];
}

+ (void)initWithAppId:(NSString *)appId appKey:(NSString *)appKey {
    [self initWithAppId:appId appKey:appKey callback:nil];
}

+ (void)initWithAppId:(NSString *)appId appKey:(NSString *)appKey callback:(id<FlameCallback>)callback {
    [FlameLogger i:@"LOCAL SDK PATCH init-state-callback-lifecycle loaded"];

    FlameSdk *instance = [self sharedInstance];
    [FlameLogger i:[NSString stringWithFormat:@"[DIAG] initWithAppId:callback: called. callback=%p, currentState=%ld", (void *)callback, (long)instance.initState]];

    // 使用 @synchronized 防止并发初始化
    @synchronized (instance) {
        FlameSDKInitState currentState = instance.initState;

        if (currentState == FlameSDKInitStateInitialized) {
            [FlameLogger w:@"FlameSdk is already initialized."];
            if (callback) {
                [callback success];
            }
            return;
        }

        if (currentState == FlameSDKInitStateInitializing) {
            // 初始化进行中：将当前 callback 加入等待队列，不重复发请求
            [FlameLogger i:@"FlameSdk is initializing, callback queued."];
            if (callback) {
                @synchronized (instance) {
                    [instance.pendingCallbacks addObject:callback];
                }
            }
            return;
        }

        if (currentState == FlameSDKInitStateFailed) {
            // 初始化失败：提示调用方需要 clear 后重试，不自动穿透重发
            [FlameLogger e:@"FlameSdk init failed previously. Call FlameSdk.clear() before retry."];
            if (callback) {
                [callback fail:ERROR_CODE_NOT_INIT
                          desc:@"SDK init failed previously. Call FlameSdk.clear() before retry initWithAppId:appKey:callback:"];
            }
            return;
        }

        // Uninitialized -> 设置为初始化中状态
        instance.initState = FlameSDKInitStateInitializing;
    }

    // 创建包装回调，在完成时更新状态
    UpdateAppCallback *cb = [[UpdateAppCallback alloc] initWithInitCallback:callback];
    [[FlameConfigManager sharedInstance] updateAppWithAppId:appId appKey:appKey callback:cb];
}

+ (void)setDebug:(BOOL)isDebug {
    [FlameAdapterManager setDebug:isDebug];
}

+ (BOOL)isInitialized {
    return [self sharedInstance].initState == FlameSDKInitStateInitialized;
}

+ (BOOL)checkInitialization {
    FlameSDKInitState state = [self sharedInstance].initState;
    if (state != FlameSDKInitStateInitialized) {
        [FlameLogger e:@"FlameSdk must be initialized before requesting ads!"];
        return NO;
    }
    return YES;
}

- (NSString *)getVersion {
    return [[FlameConfigManager sharedInstance] getSdkVersion];
}


+ (id<FlameRewardAd>)createRewardAdWithViewController:(UIViewController *)viewController
                                        placementId:(NSString *)placementId
                                           listener:(id<FlameRewardListener>)listener{
    // 0. 初始化状态检查
    if (![self isInitialized]) {
        [FlameLogger e:@"Create RewardAd Failed: SDK not initialized"];
        if (listener && [listener respondsToSelector:@selector(onAdError:desc:)]) {
            [listener onAdError:ERROR_CODE_NOT_INIT desc:@"SDK not initialized, please call initWithAppId:appKey: first"];
        }
        return nil;
    }

    // 1. 获取 pId
    NSString *pId = [[FlameConfigManager sharedInstance] getPId:placementId];

    // 2. 对 pId 进行异常判定 (判断是否为空或无效)
    if (pId == nil || pId.length == 0) {
        // 错误日志记录
        [FlameLogger e:[NSString stringWithFormat:@"Create RewardAd Failed: Invalid placementId=%@", placementId]];

        // 触发错误回调通知开发者
        if (listener && [listener respondsToSelector:@selector(onAdError:desc:)]) {
            [listener onAdError:ERROR_CODE_INVALID_AD_PLACEMENT
                           desc:[NSString stringWithFormat:@"Invalid placement ID: %@", placementId]];
        }

        // 3. 返回 nil，因为无法创建有效的广告对象
        return nil;
    }

    // 3. 通过 Router 获取当前 Provider，由 Provider 创建 Reward 适配器
    id<FlameMediationProvider> currentProvider = [[FlameMediationRouter sharedRouter] currentProvider];

    if (!currentProvider) {
        [FlameLogger e:@"Create RewardAd Failed: No active provider (Router has no currentProvider)"];
        if (listener && [listener respondsToSelector:@selector(onAdError:desc:)]) {
            [listener onAdError:ERROR_CODE_UNSUPPORTED_PLATFORM
                           desc:@"No active mediation provider"];
        }
        return nil;
    }

    id<FlameRewardAdapterProtocol> rewardAdapter = [currentProvider createRewardAdapterWithViewController:viewController
                                                                                             placementId:pId
                                                                                                listener:listener];

    if (!rewardAdapter) {
        [FlameLogger e:@"Create RewardAd Failed: Provider failed to create Reward adapter"];
        if (listener && [listener respondsToSelector:@selector(onAdError:desc:)]) {
            [listener onAdError:ERROR_CODE_UNSUPPORTED_PLATFORM
                           desc:@"Provider failed to create Reward adapter"];
        }
        return nil;
    }

    return [[FlameRewardAdImpl alloc] initWithViewController:viewController
                                                  placementId:pId
                                                     listener:listener
                                                     adapter:rewardAdapter];
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
    // 0. 初始化状态检查
    if (![self isInitialized]) {
        [FlameLogger e:@"Create InterstitialAd Failed: SDK not initialized"];
        if (listener && [listener respondsToSelector:@selector(onAdError:desc:)]) {
            [listener onAdError:ERROR_CODE_NOT_INIT desc:@"SDK not initialized, please call initWithAppId:appKey: first"];
        }
        return nil;
    }

    // 1. 获取 pId
    NSString *pId = [[FlameConfigManager sharedInstance] getPId:placementId];

    // 2. 对 pId 进行异常判定 (判断是否为空或无效)
    if (pId == nil || pId.length == 0) {
        // 错误日志记录
        [FlameLogger e:[NSString stringWithFormat:@"Create InterstitialAd Failed: Invalid placementId=%@", placementId]];

        // 触发错误回调通知开发者
        if (listener && [listener respondsToSelector:@selector(onAdError:desc:)]) {
            [listener onAdError:ERROR_CODE_INVALID_AD_PLACEMENT
                           desc:[NSString stringWithFormat:@"Invalid placement ID: %@", placementId]];
        }

        // 3. 返回 nil，因为无法创建有效的广告对象
        return nil;
    }

    // 3. 通过 Router 获取当前 Provider，由 Provider 创建 Interstitial 适配器
    id<FlameMediationProvider> currentProvider = [[FlameMediationRouter sharedRouter] currentProvider];

    if (!currentProvider) {
        [FlameLogger e:@"Create InterstitialAd Failed: No active provider (Router has no currentProvider)"];
        if (listener && [listener respondsToSelector:@selector(onAdError:desc:)]) {
            [listener onAdError:ERROR_CODE_UNSUPPORTED_PLATFORM
                           desc:@"No active mediation provider"];
        }
        return nil;
    }

    id<FlameInterstitialAdapterProtocol> interstitialAdapter = [currentProvider createInterstitialAdapterWithViewController:viewController
                                                                                                           placementId:pId
                                                                                                                 listener:listener];

    if (!interstitialAdapter) {
        [FlameLogger e:@"Create InterstitialAd Failed: Provider failed to create Interstitial adapter"];
        if (listener && [listener respondsToSelector:@selector(onAdError:desc:)]) {
            [listener onAdError:ERROR_CODE_UNSUPPORTED_PLATFORM
                           desc:@"Provider failed to create Interstitial adapter"];
        }
        return nil;
    }

    return [[FlameInterstitialAdImpl alloc] initWithViewController:viewController placementId:pId listener:listener adapter:interstitialAdapter];
}

+ (id<FlameSplashAd>)createSplashAdWithViewController:(UIViewController *)viewController
                                          placementId:(NSString *)placementId
                                             listener:(id<FlameSplashListener>)listener {
    // 0. 初始化状态检查
    if (![self isInitialized]) {
        [FlameLogger e:@"Create SplashAd Failed: SDK not initialized"];
        if (listener && [listener respondsToSelector:@selector(onAdError:desc:)]) {
            [listener onAdError:ERROR_CODE_NOT_INIT desc:@"SDK not initialized, please call initWithAppId:appKey: first"];
        }
        return nil;
    }

    // 1. 获取 pId
    NSString *pId = [[FlameConfigManager sharedInstance] getPId:placementId];

    // 2. 对 pId 进行异常判定 (判断是否为空或无效)
    if (pId == nil || pId.length == 0) {
        // 错误日志记录
        [FlameLogger e:[NSString stringWithFormat:@"Create SplashAd Failed: Invalid placementId=%@", placementId]];

        // 触发错误回调通知开发者
        if (listener && [listener respondsToSelector:@selector(onAdError:desc:)]) {
            [listener onAdError:ERROR_CODE_INVALID_AD_PLACEMENT
                           desc:[NSString stringWithFormat:@"Invalid placement ID: %@", placementId]];
        }

        // 3. 返回 nil，因为无法创建有效的广告对象
        return nil;
    }

    // 3. 通过 Router 获取当前 Provider，由 Provider 创建 Splash 适配器
    id<FlameMediationProvider> currentProvider = [[FlameMediationRouter sharedRouter] currentProvider];

    if (!currentProvider) {
        [FlameLogger e:@"Create SplashAd Failed: No active provider (Router has no currentProvider)"];
        if (listener && [listener respondsToSelector:@selector(onAdError:desc:)]) {
            [listener onAdError:ERROR_CODE_UNSUPPORTED_PLATFORM
                           desc:@"No active mediation provider"];
        }
        return nil;
    }

    id<FlameSplashAdapterProtocol> splashAdapter = [currentProvider createSplashAdapterWithViewController:viewController
                                                                                                   placementId:pId
                                                                                                      listener:listener];

    if (!splashAdapter) {
        [FlameLogger e:@"Create SplashAd Failed: Provider failed to create Splash adapter"];
        if (listener && [listener respondsToSelector:@selector(onAdError:desc:)]) {
            [listener onAdError:ERROR_CODE_UNSUPPORTED_PLATFORM
                           desc:@"Provider failed to create Splash adapter"];
        }
        return nil;
    }

    return [[FlameSplashAdImpl alloc] initWithViewController:viewController placementId:pId listener:listener adapter:splashAdapter];
}

/**
 * 创建横幅广告实例
 * @param placementId           广告位ID
 * @param listener                  回调函数
 */
+ (id<FlameBannerAd>)createBannerAdWithPlacementId:(NSString *)placementId
                                          listener:(id<FlameBannerListener>)listener{
    // 0. 初始化状态检查
    if (![self isInitialized]) {
        [FlameLogger e:@"Create BannerAd Failed: SDK not initialized"];
        if (listener && [listener respondsToSelector:@selector(onAdError:desc:)]) {
            [listener onAdError:ERROR_CODE_NOT_INIT desc:@"SDK not initialized, please call initWithAppId:appKey: first"];
        }
        return nil;
    }

    // 1. 获取 Express 模式的下游 pId
    NSString *pId = [[FlameConfigManager sharedInstance] getPId:placementId];

    // 2. 对 pId 进行异常判定 (判断是否为空或无效)
    if (pId == nil || pId.length == 0) {
        // 错误日志记录
        [FlameLogger e:[NSString stringWithFormat:@"Create BannerAd Failed: Invalid placementId=%@", placementId]];

        // 触发错误回调通知开发者
        if (listener && [listener respondsToSelector:@selector(onAdError:desc:)]) {
            [listener onAdError:ERROR_CODE_INVALID_AD_PLACEMENT
                           desc:[NSString stringWithFormat:@"Invalid placement ID: %@", placementId]];
        }

        // 3. 返回 nil，因为无法创建有效的广告对象
        return nil;
    }

    // 3. 通过 Router 获取当前 Provider，由 Provider 创建 Banner 适配器
    id<FlameMediationProvider> currentProvider = [[FlameMediationRouter sharedRouter] currentProvider];

    if (!currentProvider) {
        [FlameLogger e:@"Create BannerAd Failed: No active provider (Router has no currentProvider)"];
        if (listener && [listener respondsToSelector:@selector(onAdError:desc:)]) {
            [listener onAdError:ERROR_CODE_UNSUPPORTED_PLATFORM
                           desc:@"No active mediation provider"];
        }
        return nil;
    }

    id<FlameBannerAdapterProtocol> bannerAdapter = [currentProvider createBannerAdapterWithPlacementId:pId
                                                                                             renderType:FlameBannerRenderTypeExpress
                                                                                               listener:listener];

    if (!bannerAdapter) {
        [FlameLogger e:@"Create BannerAd Failed: Provider failed to create Banner adapter"];
        if (listener && [listener respondsToSelector:@selector(onAdError:desc:)]) {
            [listener onAdError:ERROR_CODE_UNSUPPORTED_PLATFORM
                           desc:@"Provider failed to create Banner adapter"];
        }
        return nil;
    }

    return [[FlameBannerAdImpl alloc] initWithPlacementId:pId
                                               renderType:FlameBannerRenderTypeExpress
                                                 listener:listener
                                                 adapter:bannerAdapter];
}

/**
 * 创建自渲染横幅广告实例
 * @param placementId           广告位ID
 * @param listener                  回调函数
 */
+ (id<FlameBannerAd>)createSelfRenderBannerAdWithPlacementId:(NSString *)placementId
                                                    listener:(id<FlameBannerListener>)listener{
    // 0. 初始化状态检查
    if (![self isInitialized]) {
        [FlameLogger e:@"Create SelfRender BannerAd Failed: SDK not initialized"];
        if (listener && [listener respondsToSelector:@selector(onAdError:desc:)]) {
            [listener onAdError:ERROR_CODE_NOT_INIT desc:@"SDK not initialized, please call initWithAppId:appKey: first"];
        }
        return nil;
    }

    // 1. 获取下游 pId
    NSString *pId = [[FlameConfigManager sharedInstance] getPId:placementId];

    // 2. 对 pId 进行异常判定
    if (pId == nil || pId.length == 0) {
        [FlameLogger e:[NSString stringWithFormat:@"Create SelfRender BannerAd Failed: Invalid placementId=%@", placementId]];
        if (listener && [listener respondsToSelector:@selector(onAdError:desc:)]) {
            [listener onAdError:ERROR_CODE_INVALID_AD_PLACEMENT
                           desc:[NSString stringWithFormat:@"Invalid placement ID: %@", placementId]];
        }
        return nil;
    }

    // 3. 通过 Router 获取当前 Provider，由 Provider 创建 Banner 适配器
    id<FlameMediationProvider> currentProvider = [[FlameMediationRouter sharedRouter] currentProvider];

    if (!currentProvider) {
        [FlameLogger e:@"Create SelfRender BannerAd Failed: No active provider (Router has no currentProvider)"];
        if (listener && [listener respondsToSelector:@selector(onAdError:desc:)]) {
            [listener onAdError:ERROR_CODE_UNSUPPORTED_PLATFORM
                           desc:@"No active mediation provider"];
        }
        return nil;
    }

    id<FlameBannerAdapterProtocol> bannerAdapter = [currentProvider createBannerAdapterWithPlacementId:pId
                                                                                             renderType:FlameBannerRenderTypeSelfRender
                                                                                               listener:listener];

    if (!bannerAdapter) {
        [FlameLogger e:@"Create SelfRender BannerAd Failed: Provider failed to create Banner adapter"];
        if (listener && [listener respondsToSelector:@selector(onAdError:desc:)]) {
            [listener onAdError:ERROR_CODE_UNSUPPORTED_PLATFORM
                           desc:@"Provider failed to create Banner adapter"];
        }
        return nil;
    }

    return [[FlameBannerAdImpl alloc] initWithPlacementId:pId
                                               renderType:FlameBannerRenderTypeSelfRender
                                                 listener:listener
                                                 adapter:bannerAdapter];
}

/**
 * 创建原生广告实例
 * @param placementId           广告位ID
 * @param listener                  回调函数
 */
+ (id<FlameNativeAd>)createNativeAdWithViewController:(UIViewController *)viewController
                                          placementId:(NSString *)placementId
                                             listener:(id<FlameNativeListener>)listener{
    // 0. 初始化状态检查
    if (![self isInitialized]) {
        [FlameLogger e:@"Create NativeAd Failed: SDK not initialized"];
        if (listener && [listener respondsToSelector:@selector(onAdError:desc:)]) {
            [listener onAdError:ERROR_CODE_NOT_INIT desc:@"SDK not initialized, please call initWithAppId:appKey: first"];
        }
        return nil;
    }

    // 1. 获取 pId
    NSString *pId = [[FlameConfigManager sharedInstance] getPId:placementId];

    // 2. 对 pId 进行异常判定 (判断是否为空或无效)
    if (pId == nil || pId.length == 0) {
        // 错误日志记录
        [FlameLogger e:[NSString stringWithFormat:@"Create NativeAd Failed: Invalid placementId=%@", placementId]];

        // 触发错误回调通知开发者
        if (listener && [listener respondsToSelector:@selector(onAdError:desc:)]) {
            [listener onAdError:ERROR_CODE_INVALID_AD_PLACEMENT
                           desc:[NSString stringWithFormat:@"Invalid placement ID: %@", placementId]];
        }

        // 3. 返回 nil，因为无法创建有效的广告对象
        return nil;
    }

    // 3. 通过 Router 获取当前 Provider，由 Provider 创建 Native 适配器
    id<FlameMediationProvider> currentProvider = [[FlameMediationRouter sharedRouter] currentProvider];

    if (!currentProvider) {
        [FlameLogger e:@"Create NativeAd Failed: No active provider (Router has no currentProvider)"];
        if (listener && [listener respondsToSelector:@selector(onAdError:desc:)]) {
            [listener onAdError:ERROR_CODE_UNSUPPORTED_PLATFORM
                           desc:@"No active mediation provider"];
        }
        return nil;
    }

    id<FlameNativeAdapterProtocol> nativeAdapter = [currentProvider createNativeAdapterWithViewController:viewController
                                                                                             placementId:pId
                                                                                               listener:listener];

    if (!nativeAdapter) {
        [FlameLogger e:@"Create NativeAd Failed: Provider failed to create Native adapter"];
        if (listener && [listener respondsToSelector:@selector(onAdError:desc:)]) {
            [listener onAdError:ERROR_CODE_UNSUPPORTED_PLATFORM
                           desc:@"Provider failed to create Native adapter"];
        }
        return nil;
    }

    return [[FlameNativeAdImpl alloc] initWithViewController:viewController placementId:pId listener:listener adapter:nativeAdapter];
}

@end
