# 02 - 多聚合平台可扩展架构设计

> 本文档是整个改造的核心设计文档。目标：Flame iOS SDK 从"仅支持 TopOn"演进为"多聚合平台可扩展架构"。

## 一、设计目标

1. **对外 API 不变** — `FlameSdk.initWithAppId:appKey:` 等方法签名完全不变
2. **mediation 内部类不暴露** — `FlameMediationProvider`、`FlameMediationRegistry`、`FlameMediationRouter`、`FlameTKProvider`、`FlameTBProvider` 等均属于 SDK 内部实现，**不导入 `flame_sdk_ios.h` 伞头文件**，不对接入方 App 公开
3. **接入方不感知平台** — App 不知道底层用的是 TK / TB / CSJ / GDT
4. **平台数量不写死** — 不是 tk/tb 双分支，而是 Registry + Provider 架构；Registry 的 key 使用 `NSString *platformCode`（如 `@"tk"`、`@"tb"`），不使用 `NS_ENUM` 限制平台数量，以便后续无限扩展
5. **Impl 层零 if-else** — `FlameRewardAdImpl` 等不包含任何平台判断
6. **新增平台最小改动** — 新平台 = 新 Provider + 新 Adapter + 一行注册
7. **Provider 注册在统一入口** — Provider 注册发生在 `registerAllProviders` / Registry bootstrap 中集中注册，**不在 `create*Ad` 中注册**；广告创建链路只通过 Router 获取当前 Provider
8. **TK 代码轻量封装** — 现有 TopOn 适配器保留，仅加 Provider 壳
9. **缓存网络优先** — 每次冷启动 `init` 优先请求后台配置；网络成功则更新缓存；网络失败则 fallback 使用完整本地缓存；不采用 24 小时 TTL 作为主刷新策略
10. **当前阶段不实现广告位级平台路由** — 只做 App 级平台路由，`pIds` 只支持 `Dict<String, String>`

## 二、整体架构图

```
┌─────────────────────────────────────────────────────────────────┐
│                        接入方 App                               │
│  FlameSdk.initWithAppId:appKey:                                 │
│  FlameSdk.createRewardAdWithVC:placementId:listener:             │
└──────────────────────┬──────────────────────────────────────────┘
                       │ 对外 API 不变
                       ▼
┌─────────────────────────────────────────────────────────────────┐
│                     FlameSdk (入口层)                             │
│  - 状态机 (Uninitialized/Initializing/Initialized/Failed)        │
│  - init → ConfigManager → Registry → Provider.initSDK           │
│  - create*Ad → Router → Provider.create*Ad → Impl               │
└──────────┬───────────────────────────────────────┬───────────────┘
           │                                       │
           ▼                                       ▼
┌──────────────────────┐              ┌─────────────────────────────┐
│ FlameConfigManager   │              │ FlameMediationRouter        │
│  - 请求后台配置       │              │  - routeToCurrentProvider    │
│  - 解析 pt/aId/aKey  │              │  - createSplashAd           │
│  - 缓存管理          │              │  - createRewardAd            │
│  - getPId 映射        │              │  - createInterstitialAd     │
└──────────────────────┘              │  - createBannerAd            │
                                      │  - createNativeAd            │
                                      └──────────┬──────────────────┘
                                                 │
                                                 ▼
                                      ┌─────────────────────────────┐
                                      │ FlameMediationProvider       │
                                      │  <<协议>>                    │
                                      │  - platformIdentifier        │
                                      │  - initSDKWithAppId:aKey:    │
                                      │  - isInitialized            │
                                      │  - createSplashAd:...:      │
                                      │  - createRewardAd:...:      │
                                      │  - createInterstitialAd:... │
                                      │  - createBannerAd:...:       │
                                      │  - createNativeAd:...:       │
                                      └──────────┬──────────────────┘
                                                 │
                              ┌──────────────────┼──────────────────┐
                              │                  │                  │
                              ▼                  ▼                  ▼
                     ┌─────────────┐   ┌─────────────┐   ┌─────────────┐
                     │ TKProvider   │   │ TBProvider   │   │ CSJProvider │
                     │  (当前)      │   │  (新增)      │   │  (未来)     │
                     └──────┬──────┘   └──────┬──────┘   └──────┬──────┘
                            │                  │                  │
                            ▼                  ▼                  ▼
                     ┌─────────────┐   ┌─────────────┐   ┌─────────────┐
                     │adapter/tk/  │   │adapter/tb/  │   │adapter/csj/ │
                     │ AtSplash    │   │ TbSplash    │   │ CsjSplash   │
                     │ AtReward    │   │ TbReward    │   │ CsjReward   │
                     │ AtInterst.  │   │ TbInterst.  │   │ CsjInterst. │
                     │ AtBanner    │   │ TbBanner    │   │ CsjBanner   │
                     │ AtNative    │   │ TbNative    │   │ CsjNative   │
                     └─────────────┘   └─────────────┘   └─────────────┘
```

**关键设计思路**：FlameSdk 创建广告时，不再直接 `alloc AtRewardAdapter`，而是通过 `FlameMediationRouter` 路由到当前 Provider，由 Provider 创建对应平台的 Adapter。Impl 层只持有 `id<FlameRewardAdapterProtocol>` 内部协议引用，不关心具体实现。平台 Adapter 不直接暴露给接入方。

## 三、新增类职责表

### 3.1 FlameMediationProvider 协议

| 项目 | 说明 |
|------|------|
| **文件** | `flame_sdk_ios/mediation/FlameMediationProvider.h` |
| **类型** | `@protocol` |
| **职责** | 定义聚合平台提供商的统一接口 |
| **可见性** | SDK 内部，不导入 `flame_sdk_ios.h` 伞头文件，不对接入方公开 |
| **依赖** | 无外部依赖（仅引用 Flame 协议头文件） |

```objc
@protocol FlameMediationProvider <NSObject>

/// 平台标识符，如 "tk", "tb", "csj"
- (NSString *)platformIdentifier;

/// 初始化聚合平台 SDK
- (void)initSDKWithAppId:(NSString *)appId
                  appKey:(NSString *)appKey
            initListener:(id<FlameCallback>)listener;

/// 是否已初始化
- (BOOL)isInitialized;

/// 创建开屏广告适配器（返回内部适配器协议，不直接返回对外 FlameSplashAd）
- (id<FlameSplashAdapterProtocol>)createSplashAdWithViewController:(UIViewController *)viewController
                                                     placementId:(NSString *)placementId
                                                        mappedId:(NSString *)mappedId
                                                        listener:(id<FlameSplashListener>)listener;

/// 创建激励视频广告适配器
- (id<FlameRewardAdapterProtocol>)createRewardAdWithViewController:(UIViewController *)viewController
                                                    placementId:(NSString *)placementId
                                                       mappedId:(NSString *)mappedId
                                                       listener:(id<FlameRewardListener>)listener;

/// 创建插屏广告适配器
- (id<FlameInterstitialAdapterProtocol>)createInterstitialAdWithViewController:(UIViewController *)viewController
                                                              placementId:(NSString *)placementId
                                                                 mappedId:(NSString *)mappedId
                                                                 listener:(id<FlameInterstitialListener>)listener;

/// 创建横幅广告适配器
- (id<FlameBannerAdapterProtocol>)createBannerAdWithViewController:(UIViewController *)viewController
                                                  placementId:(NSString *)placementId
                                                     mappedId:(NSString *)mappedId
                                                     listener:(id<FlameBannerListener>)listener;

/// 创建原生广告适配器
- (id<FlameNativeAdapterProtocol>)createNativeAdWithViewController:(UIViewController *)viewController
                                                  placementId:(NSString *)placementId
                                                     mappedId:(NSString *)mappedId
                                                     listener:(id<FlameNativeListener>)listener;

@end
```

### 3.2 FlameMediationRegistry

| 项目 | 说明 |
|------|------|
| **文件** | `flame_sdk_ios/mediation/FlameMediationRegistry.h/.m` |
| **类型** | 单例类 |
| **职责** | 管理所有已注册的 Provider，根据平台标识查找 Provider |
| **可见性** | SDK 内部，不对接入方公开 |
| **平台标识类型** | `NSString *platformCode`（如 `@"tk"`、`@"tb"`），不使用 `NS_ENUM`，支持任意平台扩展 |
| **依赖** | `FlameMediationProvider` |

```objc
@interface FlameMediationRegistry : NSObject

+ (instancetype)sharedRegistry;

/// 注册 Provider
- (void)registerProvider:(id<FlameMediationProvider>)provider;

/// 注销 Provider
- (void)unregisterProviderWithIdentifier:(NSString *)identifier;

/// 根据 platformIdentifier 获取 Provider
- (id<FlameMediationProvider>)providerForIdentifier:(NSString *)identifier;

/// 获取所有已注册的 Provider 标识符列表
- (NSArray<NSString *> *)allRegisteredIdentifiers;

@end
```

### 3.3 FlameMediationRouter

| 项目 | 说明 |
|------|------|
| **文件** | `flame_sdk_ios/mediation/FlameMediationRouter.h/.m` |
| **类型** | 单例类 |
| **职责** | 持有当前活跃的 Provider 引用，将广告创建请求路由到当前 Provider |
| **可见性** | SDK 内部，不对接入方公开 |
| **依赖** | `FlameMediationProvider`, `FlameMediationRegistry` |

```objc
@interface FlameMediationRouter : NSObject

+ (instancetype)sharedRouter;

/// 根据后台返回的 pt，从 Registry 中选择并激活 Provider
- (void)activateProviderForPlatform:(NSString *)platformIdentifier
                       initListener:(id<FlameCallback>)listener
                              appId:(NSString *)appId
                             appKey:(NSString *)appKey;

/// 获取当前活跃的 Provider
- (id<FlameMediationProvider>)currentProvider;

/// 获取当前平台标识符
- (NSString *)currentPlatformIdentifier;

/// 路由：创建开屏广告（转发给 currentProvider）
- (id<FlameSplashAdapterProtocol>)createSplashAdWithViewController:(UIViewController *)vc
                                                        placementId:(NSString *)placementId
                                                           mappedId:(NSString *)mappedId
                                                           listener:(id<FlameSplashListener>)listener;

/// 路由：创建激励视频广告
- (id<FlameRewardAdapterProtocol>)createRewardAdWithViewController:(UIViewController *)vc
                                                        placementId:(NSString *)placementId
                                                           mappedId:(NSString *)mappedId
                                                           listener:(id<FlameRewardListener>)listener;

/// 路由：创建插屏广告
- (id<FlameInterstitialAdapterProtocol>)createInterstitialAdWithViewController:(UIViewController *)vc
                                                              placementId:(NSString *)placementId
                                                                 mappedId:(NSString *)mappedId
                                                                 listener:(id<FlameInterstitialListener>)listener;

/// 路由：创建横幅广告
- (id<FlameBannerAdapterProtocol>)createBannerAdWithViewController:(UIViewController *)vc
                                                  placementId:(NSString *)placementId
                                                     mappedId:(NSString *)mappedId
                                                     listener:(id<FlameBannerListener>)listener;

/// 路由：创建原生广告
- (id<FlameNativeAdapterProtocol>)createNativeAdWithViewController:(UIViewController *)vc
                                                  placementId:(NSString *)placementId
                                                     mappedId:(NSString *)mappedId
                                                     listener:(id<FlameNativeListener>)listener;

/// 重置（clear 时调用）
- (void)reset;

@end
```

### 3.4 TKProvider

| 项目 | 说明 |
|------|------|
| **文件** | `flame_sdk_ios/mediation/tk/FlameTKProvider.h/.m` |
| **类型** | `FlameMediationProvider` 实现 |
| **职责** | 包装现有 TopOn/AnyThink SDK 初始化 + 创建 `At*Adapter` 实例 |
| **可见性** | SDK 内部，不对接入方公开 |
| **依赖** | `FlameAdapterManager`（复用现有 TK 初始化逻辑）, `adapter/tk/At*Adapter` |

```objc
@interface FlameTKProvider : NSObject <FlameMediationProvider>

- (NSString *)platformIdentifier;  // 返回 @"tk"

- (void)initSDKWithAppId:(NSString *)appId
                  appKey:(NSString *)appKey
            initListener:(id<FlameCallback>)listener;
    // 内部: 复用 FlameAdapterManager.initSDKWithAppId:appKey:initListener:

- (id<FlameRewardAdapterProtocol>)createRewardAdWithViewController:(UIViewController *)vc
                                                    placementId:(NSString *)placementId
                                                       mappedId:(NSString *)mappedId
                                                       listener:(id<FlameRewardListener>)listener;
    // 内部: return [[AtRewardAdapter alloc] initWithViewController:vc
    //               placementId:placementId pId:mappedId listener:listener];
    // 其他 create*Ad 方法类似

@end
```

### 3.5 TBProvider

| 项目 | 说明 |
|------|------|
| **文件** | `flame_sdk_ios/mediation/tb/FlameTBProvider.h/.m` |
| **类型** | `FlameMediationProvider` 实现 |
| **职责** | 初始化 ToBid/WindMill SDK + 创建 `Tb*Adapter` 实例 |
| **可见性** | SDK 内部，不对接入方公开 |
| **依赖** | `adapter/tb/Tb*Adapter`, ToBid SDK |

```objc
@interface FlameTBProvider : NSObject <FlameMediationProvider>

- (NSString *)platformIdentifier;  // 返回 @"tb"

- (void)initSDKWithAppId:(NSString *)appId
                  appKey:(NSString *)appKey
            initListener:(id<FlameCallback>)listener;
    // 内部: 初始化 ToBid WindMill SDK

- (id<FlameRewardAdapterProtocol>)createRewardAdWithViewController:(UIViewController *)vc
                                                    placementId:(NSString *)placementId
                                                       mappedId:(NSString *)mappedId
                                                       listener:(id<FlameRewardListener>)listener;
    // 内部: return [[TbRewardAdapter alloc] initWithViewController:vc
    //               placementId:placementId pId:mappedId listener:listener];

@end
```

## 四、初始化链路设计

### 4.1 初始化伪代码

```objc
// ========== FlameSdk.m 修改后的初始化 ==========

+ (void)initWithAppId:(NSString *)appId appKey:(NSString *)appKey callback:(id<FlameCallback>)callback {
    @synchronized(instance) {
        switch (instance.initState) {
            case FlameInitStateInitialized:
                callback.success;  // 或 dispatch async
                return;
            case FlameInitStateInitializing:
                [instance.pendingCallbacks addObject:callback];
                return;
            case FlameInitStateFailed:
                callback.fail(@"14000" desc:@"SDK init failed previously");
                return;
            case FlameInitStateUninitialized:
                instance.initState = FlameInitStateInitializing;
                break;
        }
    }

    // 【不变】注册所有 Provider（只需一次，可放在 +initialize 或 sharedInstance init）
    [self registerAllProviders];

    // 【不变】请求后台配置
    [FlameConfigManager updateAppWithAppId:appId appKey:appKey callback:^(BOOL success, NSString *errorMsg) {
        if (!success) {
            @synchronized(instance) {
                instance.initState = FlameInitStateFailed;
            }
            callback.fail(@"15000" desc:errorMsg);
            return;
        }

        // 【新增】读取 pt，从 Registry 获取 Provider
        FlameAppEntity *entity = [FlameConfigManager getAppEntity];
        NSString *pt = entity.pt;

        id<FlameMediationProvider> provider =
            [[FlameMediationRegistry sharedRegistry] providerForIdentifier:pt];

        if (!provider) {
            @synchronized(instance) {
                instance.initState = FlameInitStateFailed;
            }
            callback.fail(@"14003" desc:@"Unsupported platform: xxx");
            return;
        }

        // 【新增】通过 Router 激活当前 Provider 并初始化
        NSString *aId = entity.aId;
        NSString *aKey = entity.aKey;
        [[FlameMediationRouter sharedRouter] activateProviderForPlatform:pt
                                                            initListener:callback
                                                                   appId:aId
                                                                  appKey:aKey];
    }];
}

+ (void)registerAllProviders {
    // 每个平台一行注册代码
    // 新增平台只需在此追加一行，不改其他逻辑
    [[FlameMediationRegistry sharedRegistry] registerProvider:[[FlameTKProvider alloc] init]];
    [[FlameMediationRegistry sharedRegistry] registerProvider:[[FlameTBProvider alloc] init]];
    // 未来: [[FlameMediationRegistry sharedRegistry] registerProvider:[[FlameCSJProvider alloc] init]];
}
```

### 4.2 FlameMediationRouter.activateProvider 内部逻辑

```objc
- (void)activateProviderForPlatform:(NSString *)platformIdentifier
                       initListener:(id<FlameCallback>)listener
                              appId:(NSString *)appId
                             appKey:(NSString *)appKey {
    id<FlameMediationProvider> provider =
        [[FlameMediationRegistry sharedRegistry] providerForIdentifier:platformIdentifier];

    self.currentProvider = provider;
    self.currentPlatformIdentifier = platformIdentifier;

    [provider initSDKWithAppId:appId appKey:appKey initListener:listener];
}
```

### 4.3 状态管理

```
FlameSdk.initState          — SDK 全局状态 (4 态枚举)
FlameMediationRouter        — 持有 currentProvider + currentPlatformIdentifier
每个 Provider.isInitialized — 该平台是否已初始化
```

**初始化成功判定**: `Router.currentProvider.isInitialized == YES`

### 4.4 未知平台处理

```objc
id<FlameMediationProvider> provider = [Registry providerForIdentifier:pt];
if (!provider) {
    // 回调 fail，错误码 14003 = 不支持的聚合平台
    callback.fail(@"14003" desc:[NSString stringWithFormat:@"Unsupported platform: %@", pt]]);
    return;
}
```

### 4.5 配置未返回时广告请求处理

```objc
// FlameSdk.createRewardAdWithVC:placementId:listener:
if (![self isInitialized]) {
    listener.onAdError:@"14000" desc:@"SDK not initialized"];
    return nil;
}
// 如果正在 Initializing 状态，广告请求会被拒绝
// 接入方应在 callback.success 后再创建广告
```

### 4.6 重复初始化防护

- `FlameSdk.initState` 的 `@synchronized` 状态机已防护
- `FlameMediationRouter.currentProvider` 在 `clear` 时置 nil
- 各 Provider 内部的 `isInitialized` 标志防止聚合 SDK 重复初始化

## 五、广告创建链路设计（以激励视频为例）

### 5.1 改造前 vs 改造后

**改造前**:
```
FlameSdk.createRewardAd → getPId → FlameRewardAdImpl(vc, flameId, topOnId, listener)
  → [[AtRewardAdapter alloc] initWithVC:vc placementId:flameId pId:topOnId listener:listener]
```

**改造后**:
```
FlameSdk.createRewardAdWithVC:placementId:listener:
  │
  ├─ isInitialized 检查
  ├─ FlameConfigManager.getPId(flamePlacementId)  → mappedId
  │
  ├─ 【新增】通过 Router 获取当前 Provider 创建的适配器:
  │  id<FlameRewardAdapterProtocol> adapter = [[FlameMediationRouter sharedRouter]
  │      createRewardAdWithViewController:vc
  │                  placementId:flamePlacementId
  │                     mappedId:mappedId
  │                     listener:listener];
  │
  └─ FlameRewardAdImpl(vc, flamePlacementId, adapter)
       // Impl 不再自己创建 adapter，而是接收预创建的内部适配器
```

### 5.2 FlameRewardAdImpl 如何不感知平台

**核心变化**: `FlameRewardAdImpl` 的 `initWithViewController:placementId:pId:listener:` 改为 `initWithViewController:placementId:adapter:`

- `adapter` 类型为 `id<FlameRewardAdapterProtocol>`（内部适配器协议）
- Impl 只调用协议方法：`[adapter load]`, `[adapter show]`, `[adapter destroy]`, `[adapter isReady]`
- Impl **不关心** adapter 内部是 `AtRewardAdapter` 还是 `TbRewardAdapter`
- 平台选择在 `FlameSdk` → `Router` → `Provider` 层完成，Impl 完全解耦

### 5.3 激励视频完整伪代码

```objc
// ========== FlameSdk.m ==========

- (id<FlameRewardAd>)createRewardAdWithViewController:(UIViewController *)vc
                                         placementId:(NSString *)placementId
                                             listener:(id<FlameRewardListener>)listener {
    if (![self checkInitialization]) {
        listener.onAdError:@"14000" desc:@"SDK not initialized"];
        return nil;
    }

    NSString *mappedId = [[FlameConfigManager sharedInstance] getPId:placementId];
    if (!mappedId) {
        listener.onAdError:@"14004" desc:@"Invalid placement id"];
        return nil;
    }

    // 【核心变化】通过 Router 创建适配器，而非直接 alloc AtRewardAdapter
    id<FlameRewardAdapterProtocol> adapter = [[FlameMediationRouter sharedRouter]
        createRewardAdWithViewController:vc
                            placementId:placementId
                               mappedId:mappedId
                               listener:listener];

    return [[FlameRewardAdImpl alloc] initWithViewController:vc
                                               placementId:placementId
                                                    adapter:adapter];
}

// ========== FlameMediationRouter.m ==========

- (id<FlameRewardAdapterProtocol>)createRewardAdWithViewController:(UIViewController *)vc
                                         placementId:(NSString *)placementId
                                            mappedId:(NSString *)mappedId
                                            listener:(id<FlameRewardListener>)listener {
    return [self.currentProvider createRewardAdWithViewController:vc
                                                     placementId:placementId
                                                        mappedId:mappedId
                                                        listener:listener];
    // 如果 currentProvider 为 nil（理论上不应发生），返回 nil 并回调错误
}

// ========== FlameTKProvider.m (TK 平台) ==========

- (id<FlameRewardAdapterProtocol>)createRewardAdWithViewController:(UIViewController *)vc
                                                    placementId:(NSString *)placementId
                                                       mappedId:(NSString *)mappedId
                                                       listener:(id<FlameRewardListener>)listener {
    return [[AtRewardAdapter alloc] initWithViewController:vc
                                              placementId:placementId
                                                       pId:mappedId
                                                    listener:listener];
    // 完全复用现有 AtRewardAdapter，仅加 Provider 壳
}

// ========== FlameTBProvider.m (TB 平台) ==========

- (id<FlameRewardAdapterProtocol>)createRewardAdWithViewController:(UIViewController *)vc
                                                    placementId:(NSString *)placementId
                                                       mappedId:(NSString *)mappedId
                                                       listener:(id<FlameRewardListener>)listener {
    return [[TbRewardAdapter alloc] initWithViewController:vc
                                               placementId:placementId
                                                        pId:mappedId
                                                     listener:listener];
}

// ========== FlameRewardAdImpl.m (不改平台判断) ==========

- (instancetype)initWithViewController:(UIViewController *)vc
                           placementId:(NSString *)placementId
                                adapter:(id<FlameRewardAdapterProtocol>)adapter {
    if (self = [super init]) {
        _viewController = vc;
        _placementId = placementId;
        _adapter = adapter;  // id<FlameRewardAdapterProtocol> 内部协议，不关心具体类型
    }
    return self;
}

- (void)load {
    [self.adapter load];  // 委托给 adapter
}

- (void)show {
    [self.adapter show];
}

- (void)destroy {
    [self.adapter destroy];
    self.adapter = nil;
}
```

## 六、内部适配器协议设计

> **核心设计**：Provider 的 `create*Ad` 方法返回 `id<FlameXxxAdapterProtocol>` 内部适配器协议，**不是** 对外 Flame 协议（如 `id<FlameRewardAd>`）。
>
> 平台 Adapter（AtRewardAdapter、TbRewardAdapter 等）实现内部适配器协议，**不直接实现对外 Flame 协议**。
> `FlameRewardAdImpl` 实现对外 `FlameRewardAd` 协议，内部持有 `id<FlameRewardAdapterProtocol>`，通过协议方法转发 load/show/destroy 等调用。

```objc
// === 内部适配器协议（SDK 内部使用，不暴露给接入方） ===

@protocol FlameRewardAdapterProtocol <NSObject>
- (void)load;
- (void)loadWithUserId:(NSString *)userId userCustomData:(NSString *)userCustomData;
- (BOOL)isReady;
- (BOOL)isLoading;
- (void)show;
- (void)destroy;
@end

@protocol FlameSplashAdapterProtocol <NSObject>
- (void)load;
- (BOOL)isReady;
- (void)show;
- (void)destroy;
@end

@protocol FlameInterstitialAdapterProtocol <NSObject>
- (void)load;
- (BOOL)isReady;
- (void)show;
- (void)destroy;
@end

@protocol FlameBannerAdapterProtocol <NSObject>
- (void)load;
- (BOOL)isReady;
- (void)destroy;
@end

@protocol FlameNativeAdapterProtocol <NSObject>
- (void)load;
- (BOOL)isReady;
- (void)destroy;
@end
```

**设计要点**：
- `FlameRewardAdImpl` 实现对外 `FlameRewardAd` 协议（接入方使用）
- `FlameRewardAdImpl` 内部持有 `id<FlameRewardAdapterProtocol>` adapter
- 平台 Adapter（AtRewardAdapter、TbRewardAdapter 等）实现 `FlameRewardAdapterProtocol`，**不直接实现对外 FlameRewardAd**
- Provider 创建并返回 `id<FlameRewardAdapterProtocol>` 内部适配器
- Impl 只调用内部适配器的协议方法，不关心具体实现类
- 平台 Adapter 不直接暴露给接入方，不直接作为 SDK 对外广告对象使用

## 七、平台扩展方式

### 7.1 新增 CSJ 平台的完整示例

**需要新增的文件** (共 7 个):

| 文件 | 说明 |
|------|------|
| `mediation/csj/FlameCSJProvider.h/.m` | CSJ 平台 Provider，实现 `FlameMediationProvider` |
| `adapter/csj/CsjRewardAdapter.h/.m` | CSJ 激励视频适配器 |
| `adapter/csj/CsjSplashAdapter.h/.m` | CSJ 开屏适配器 |
| `adapter/csj/CsjInterstitialAdapter.h/.m` | CSJ 插屏适配器 |
| `adapter/csj/CsjBannerAdapter.h/.m` | CSJ 横幅适配器 |
| `adapter/csj/CsjNativeAdapter.h/.m` | CSJ 原生适配器 |

**需要修改的文件** (仅 2 处):

| 文件 | 修改内容 |
|------|----------|
| `FlameSdk.m` 的 `registerAllProviders` 方法 | 追加一行: `[registry registerProvider:[[FlameCSJProvider alloc] init]];` |
| `flame_sdk_ios.podspec` | 追加 CSJ SDK Pod 依赖 |

**不应修改的文件**:

| 文件 | 原因 |
|------|------|
| `FlameRewardAdImpl.m` | 不感知平台 |
| `FlameSplashAdImpl.m` | 不感知平台 |
| `FlameInterstitialAdImpl.m` | 不感知平台 |
| `FlameBannerAdImpl.m` | 不感知平台 |
| `FlameNativeAdImpl.m` | 不感知平台 |
| `FlameMediationProvider.h` | 协议不变 |
| `FlameMediationRouter.h/.m` | 路由逻辑不变 |
| `FlameMediationRegistry.h/.m` | 注册机制不变 |
| `FlameConfigManager.m` | 配置解析不变（pt/aId/aKey/pIds 通用） |

### 7.2 Provider 自注册机制选择

采用 **方案 A：手动注册（推荐）**，在 `FlameSdk.registerAllProviders` 中集中注册。

> **重要**：Provider 注册发生在统一注册入口（`registerAllProviders` / Registry bootstrap），**不在 `create*Ad` 中注册**。广告创建链路只通过 Router 获取当前 Provider，不负责注册 Provider。

理由：
- 注册代码集中在一处，一目了然
- 不依赖 ObjC runtime trick（`+load`），调试友好
- 编译时可检查，未注册的 Provider 有明确报错
- 符合当前工程风格（无 `+load` 使用先例）

备选方案（`+load` 自动注册）虽然更"插件化"，但增加了调试复杂度，不符合当前工程风格。

### 7.3 平台标识设计

平台标识使用 `NSString *platformCode`，不使用 `NS_ENUM`。

```objc
// 内部定义字符串常量（可选，用于统一管理）
static NSString * const kFlamePlatformTK = @"tk";
static NSString * const kFlamePlatformTB = @"tb";
// 未来: static NSString * const kFlamePlatformCSJ = @"csj";
```

**原因**：后续可能接入第三、第四、第五个平台。如果使用枚举，每新增平台都要改枚举定义，不利于扩展。使用 `NSString` 则只需在 Registry 中注册对应 Provider，无需修改任何类型定义。

## 八、目录结构规划

```
flame_sdk_ios/
  core/                          # 不变
    FlameSdk.h/.m
    FlameConfigManager.h/.m
    FlameAppEntity.h/.m
    FlameCallback.h
    FlameErrorCode.h/.m
    FlameLogger.h/.m
  utils/                         # 不变
    FlameNetworkUtils.h/.m
    FlameMd5SignatureUtils.h/.m
    FlameAesCryptoUtils.h/.m
    FlameConfigLocalStorage.h/.m
  mediation/                     # 【新增】聚合平台路由层
    FlameMediationProvider.h      # Provider 协议
    FlameMediationRegistry.h/.m   # Provider 注册表
    FlameMediationRouter.h/.m     # 广告创建路由
    tk/                           # 【新增】TK Provider 壳
      FlameTKProvider.h/.m
    tb/                           # 【新增】TB Provider 壳
      FlameTBProvider.h/.m
    csj/                          # 【未来】CSJ Provider 壳
      FlameCSJProvider.h/.m
  adapter/                       # 适配器层（已存在，扩展）
    tk/                           # 【不变】现有 TopOn 适配器
      AtSplashAdapter.h/.m
      AtRewardAdapter.h/.m
      AtInterstitialAdapter.h/.m
      AtBannerAdapter.h/.m
      AtNativeAdapter.h/.m
      AtNativeSelfRenderView.h/.m
    tb/                           # 【新增】ToBid 适配器
      TbSplashAdapter.h/.m
      TbRewardAdapter.h/.m
      TbInterstitialAdapter.h/.m
      TbBannerAdapter.h/.m
      TbNativeAdapter.h/.m
      TbNativeSelfRenderView.h/.m   # 可选
    csj/                          # 【未来】穿山甲适配器
      ...
  ads/                            # Impl 层（修改，但不加平台判断）
    splash/FlameSplashAdImpl.m    # 修改 init 签名，接收 adapter
    reward/FlameRewardAdImpl.m    # 同上
    interstitial/FlameInterstitialAdImpl.m  # 同上
    banner/FlameBannerAdImpl.m    # 同上
    nativate/FlameNativeAdImpl.m  # 同上
```
