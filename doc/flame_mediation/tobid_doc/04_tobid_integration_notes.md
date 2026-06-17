# 04 - ToBid 接入专项笔记

> 本文档记录 ToBid (WindMill) 作为第一个新增聚合平台的接入注意事项。

## 一、ToBid SDK 概述

### 1.1 SDK 信息

| 项目 | 说明 |
|------|------|
| SDK 名称 | ToBid / WindMill |
| 平台标识 | `tb` |
| 官方文档 | `doc/tobid_doc/sdk集成下载说明/`（注意：此为 ToBid 官方资料目录，非架构文档目录） |
| Demo 工程 | `doc/tobid_doc/ToBidDemo官方/` |

### 1.2 集成方式

- CocoaPods 方式：`pod 'ToBid-iOS-RC', '5.5.6'`（Phase 5 已确认）
- 手动 Framework / xcFramework 方式：待确认

### 1.3 ToBid SDK 版本确认（Phase 5）

| 来源 | 版本 | Pod 名称 |
|------|------|----------|
| 接入代码（最新） | 5.5.6 | `ToBid-iOS-RC` |
| Demo_OC（官方 OC Demo） | 5.3.4 | `ToBid-iOS-RC` |
| Example（旧版 Example） | 4.6.0 | `ToBid-iOS` |

**Phase 5 采用 `ToBid-iOS-RC 5.5.6`**（接入代码为最新集成文档，版本最新）。
不混用 `ToBid-iOS` 和 `ToBid-iOS-RC`。

## 二、TBProvider 初始化设计

### 2.1 ToBid SDK 初始化方式

```objc
// FlameTBProvider.m

- (void)initSDKWithAppId:(NSString *)appId
                  appKey:(NSString *)appKey
            initListener:(id<FlameCallback>)listener {
    // TODO: 替换为 ToBid SDK 的实际初始化调用
    // 预计类似:
    // [[WindMillSDK sharedInstance] initWithAppId:appId appKey:appKey];
    // 或:
    // [ToBidSDK startWithAppId:appId appKey:appKey completion:^(BOOL success) { ... }];

    // 初始化成功回调
    self.isInitialized = YES;
    if (listener) {
        [listener success];
    }
}
```

> ⚠️ 具体初始化 API 需参考 ToBid 官方文档和 Demo 后补充。

### 2.2 初始化时机

TBProvider 的初始化在 `FlameMediationRouter.activateProviderForPlatform:` 中被调用，与 TKProvider 使用完全相同的时机和链路。

## 三、adapter/tb/ 适配器清单

### 3.1 需要新增的适配器

| 文件 | 实现内部协议 | 对应 ToBid 广告类型 |
|------|-----------------|---------------------|
| `TbSplashAdapter.h/.m` | `FlameSplashAdapterProtocol` | ToBid 开屏广告 |
| `TbRewardAdapter.h/.m` | `FlameRewardAdapterProtocol` | ToBid 激励视频 |
| `TbInterstitialAdapter.h/.m` | `FlameInterstitialAdapterProtocol` | ToBid 插屏广告 |
| `TbBannerAdapter.h/.m` | `FlameBannerAdapterProtocol` | ToBid 横幅广告 |
| `TbNativeAdapter.h/.m` | `FlameNativeAdapterProtocol` | ToBid 原生广告 |
| `TbNativeSelfRenderView.h/.m` | — | ToBid 原生自渲染视图（可选） |

### 3.2 ToBid Native 自渲染视图体系

ToBid / WindMill 有独立的 Native 视图体系，与 TopOn/AnyThink 完全不同：

| 类 | 用途 |
|----|------|
| `WindMillNativeAdsManager` | Native 广告管理器 |
| `WindMillNativeAd` | 单条原生广告数据对象 |
| `WindMillNativeAdView` | 原生广告视图容器 |
| `refreshData:` | 刷新广告数据到视图 |
| `setClickableViews:` | 注册可点击区域 |
| `viewController` | 关联的展示 ViewController |
| `unregisterDataObject` | 注销广告数据，释放资源 |
| `feedADMode` | Feed 流广告模式 |

**Phase 6 设计约束**（Phase 4.1 登记）：

1. `TbNativeAdapter` 必须使用 ToBid / WindMill 自己的 Native 视图体系
2. 可新增 `TbNativeSelfRenderView` 或 `TbWindMillNativeRenderView`，封装 `WindMillNativeAdView` / `WindMillNativeAd` 的自渲染逻辑
3. **不得复用** TK 的 `AtNativeSelfRenderView`
4. **不得让** `FlameNativeAdImpl` 直接 import / alloc `WindMillNativeAdView` 或 `TbNativeSelfRenderView`
5. `FlameNativeAdImpl` 仍然只面向 `FlameNativeAdapterProtocol`
6. TB Native 的 `showInContainer:` 由 `TbNativeAdapter` 内部完成 `WindMillNativeAdView` 创建、`refreshData:`、`setClickableViews:`、`viewController` 设置和 `unregisterDataObject` 生命周期管理

> 对比：TK 的 `AtNativeSelfRenderView` 使用 `ATNativeAdOffer` + `ATNativeADView` + `ATNativePrepareInfo`（AnyThink SDK），TB 的自渲染使用 `WindMillNativeAdView` + `WindMillNativeAd`（WindMill SDK），两套体系完全独立，不可混用。

### 3.3 适配器统一接口

每个适配器实现对应的**内部适配器协议**（如 `FlameRewardAdapterProtocol`），内部调用 ToBid SDK API。与 `At*Adapter` 保持一致的方法签名。

> **设计说明**：Provider 的 `create*Ad` 方法返回 `id<FlameXxxAdapterProtocol>` 内部适配器协议。平台 Adapter（AtRewardAdapter、TbRewardAdapter 等）**不直接实现对外 Flame 协议**（FlameRewardAd 等）。`FlameRewardAdImpl` 实现对外 FlameRewardAd 协议，内部持有 `id<FlameRewardAdapterProtocol>`，通过协议方法转发调用。平台 Adapter 不直接暴露给接入方。

```objc
// 以 TbRewardAdapter 为例
@interface TbRewardAdapter : NSObject <FlameRewardAdapterProtocol>

- (instancetype)initWithViewController:(UIViewController *)viewController
                          placementId:(NSString *)placementId
                                   pId:(NSString *)mappedId
                               listener:(id<FlameRewardListener>)listener;

- (void)load;
- (void)loadWithUserId:(NSString *)userId userCustomData:(NSString *)userCustomData;
- (BOOL)isReady;
- (BOOL)isLoading;
- (void)show;
- (void)destroy;

@end
```

## 四、TB 回调映射到 Flame Listener

### 4.1 激励视频回调映射

| ToBid 回调 | FlameRewardListener 方法 | 说明 |
|------------|-------------------------|------|
| onAdLoaded / onRewardVideoAdLoaded | `onAdLoaded` | 广告加载成功 |
| onAdShow / onRewardVideoAdShow | `onAdShow` | 广告展示 |
| onAdClick | `onAdClicked` | 广告点击 |
| onAdClose / onRewardVideoAdClose | `onAdClosed` | 广告关闭 |
| onReward / onRewardVerify | `onAdReward:userCustomData:transId:` | 激励发放 |
| onVideoComplete | `onAdPlayComplete` | 视频播放完成 |
| onError / onAdLoadFail | `onAdError:desc:` | 错误 |

> ⚠️ 具体回调方法名需参考 ToBid SDK 头文件确认。

### 4.2 开屏广告回调映射

| ToBid 回调 | FlameSplashListener 方法 |
|------------|------------------------|
| onAdLoaded | `onAdLoaded` |
| onAdShow | `onAdShow` |
| onAdClick | `onAdClicked` |
| onAdClose | `onAdClosed` / `onAdShowComplete:userCustomData:` |
| onError | `onAdError:desc:` |
| onAdLoadTimeout | `onAdLoadTimeout` |

### 4.3 通用映射原则

1. **一对一映射**：优先找语义最接近的 Flame 方法
2. **不丢失事件**：如果 ToBid 有 Flame 协议中没有的回调，通过 `userCustomData` 字段透传
3. **错误码转换**：ToBid 错误码映射到 Flame 14xxx 错误码体系
4. **参数适配**：ToBid 回调参数可能与 Flame 协议不完全匹配，在 Adapter 内部做转换

### 4.4 错误码映射

```objc
static NSString *mapTbErrorCode(NSInteger tbCode) {
    switch (tbCode) {
        case TB_ERROR_NO_FILL:
            return @"14003";  // 无广告填充
        case TB_ERROR_TIMEOUT:
            return @"15000";  // 超时
        case TB_ERROR_NETWORK:
            return @"15001";  // 网络错误
        default:
            return [NSString stringWithFormat:@"14%04ld", tbCode];
    }
}
```

## 五、Info.plist / SKAdNetworkItems / ATT 建议

### 5.1 Info.plist

ToBid SDK 可能要求的配置项（需参考官方文档确认）：

| 配置项 | 说明 | 处理方式 |
|--------|------|----------|
| `NSAppTransportSecurity` | 如果 ToBid 使用 HTTP 请求 | 在 podspec 的 `s.info_plist` 中声明 |
| `GADApplicationIdentifier` | 如 ToBid 内嵌 AdMob | 由 ToBid podspec 自行声明 |
| `SKAdNetworkItems` | SKAdNetwork 归因 | 见下节 |
| 自定义 URL Scheme | DeepLink 相关 | 由 ToBid SDK 自行配置 |

**建议**：通过 `flame_sdk_ios.podspec` 的 `s.info_plist` 声明，不手动修改接入方 Info.plist。

### 5.2 SKAdNetworkItems

- TopOn/AnyThink 已声明其 SKAdNetworkItems（通过 TopOn podspec）
- ToBid 也有自己的 SKAdNetworkItems
- 需要合并两套 SKAdNetwork ID，确保不冲突
- **建议**：在 `flame_sdk_ios.podspec` 中声明全集，或使用 CocoaPods 的 `resource_bundles` 机制

### 5.3 ATT / IDFA

**当前 SDK 无任何 ATT 相关代码。** 这意味着：

1. 接入方必须自行处理 ATT 授权（`ATTrackingManager.requestTrackingAuthorization`）
2. Flame SDK 依赖接入方在调用 `FlameSdk.initWithAppId:appKey:` 之前完成 ATT 授权
3. ToBid 的 IDFA 采集依赖接入方的 ATT 授权时机

**建议**（本次不改，未来考虑）：
- FlameSdk 初始化方法中增加 ATT 状态检查（warning 级别日志）
- 或新增 `FlameSdk.setATTStatus:` 方法供接入方告知 SDK

## 六、Pod 依赖策略

### 6.1 分发策略：单包全量分发（Phase 5A.5 落地）

**核心问题**：Phase 5A.4 的双 xcframework + subspec 方案虽然解决了二进制分发问题，但增加了产物管理复杂度（两份 xcframework、subspec 切换逻辑）。产品目标简化为：**`pod 'flame_sdk_ios'` 一行代码交付所有能力**。

**Phase 5A.5 决策**：从双 xcframework + subspec 改回**单包全量分发**。

| 决策项 | Phase 5A.4（已废弃） | Phase 5A.5（当前） |
|--------|---------------------|-------------------|
| 产物 | 2 个 xcframework（Core / ToBid） | 1 个 xcframework（全量） |
| podspec | Core + ToBid subspec | 单一 `s.vendored_frameworks` |
| ToBid-iOS-RC 依赖 | 仅 ToBid subspec 包含 | 根级 `s.dependency` |
| `#ifdef HAS_TOBID` | 保留（构建两个变体） | **完全移除** |
| 接入方式 | `pod 'flame_sdk_ios/ToBid'` | `pod 'flame_sdk_ios'` |
| 运行时平台切换 | subspec 选择决定 | 后台 `pt=tk/tb` 控制 |

**podspec 关键配置**：

```ruby
# 单一 xcframework 产物
s.vendored_frameworks = '**/flame_sdk_ios.xcframework'

# ToBid 依赖（全量包含）
s.dependency 'ToBid-iOS-RC', '5.5.6'
```

**`#ifdef HAS_TOBID` 完全移除**：

以下文件不再包含任何条件编译，ToBid 代码始终编译：

| 文件 | 移除内容 |
|------|----------|
| `FlameSdk.m` | `#ifdef HAS_TOBID` 包裹的 TBProvider 注册 |
| `FlameTBProvider.m` | `#ifdef HAS_TOBID` 包裹的 WindMill API 调用 |
| `TbRewardAdapter.h` | `#ifdef HAS_TOBID` 包裹的协议遵循和属性 |
| `TbRewardAdapter.m` | `#ifdef HAS_TOBID` 包裹的 WindMill API 和 13 个 delegate 方法 |

**`xcFramework_build.sh` 构建流程（简化）**：

1. 真机 archive → `flame_sdk_ios_ios.xcarchive`
2. 模拟器 archive → `flame_sdk_ios_sim.xcarchive`
3. 合并为 `flame_sdk_ios.xcframework`
4. Bitcode 剥离 + 冗余文件清理

**本地开发 Podfile**：

```ruby
def tb_pods
  pod 'ToBid-iOS-RC', '5.5.6'
end

target 'flame_sdk_ios' do
  use_frameworks! :linkage => :static
  tk_pods
  tb_pods
end
```

不再需要 `post_install` 中的 `GCC_PREPROCESSOR_DEFINITIONS` HAS_TOBID=1 设置。

### 6.2 已废弃方案记录

> ⚠️ 以下方案已被 6.1 单包全量方案替代，仅作历史记录。

**Phase 5A.4 双 xcframework + subspec（已废弃）**：
- 产出两个 xcframework（Core / ToBid），通过 subspec 控制分发
- `#ifdef HAS_TOBID` 条件编译保留，用于构建两个变体
- `pod 'flame_sdk_ios'`（Core）/ `pod 'flame_sdk_ios/ToBid'`（ToBid）

**Phase 5A.3 #ifdef HAS_TOBID 条件编译（已废弃）**：
- 源码级条件编译，仅对源码编译有效
- 二进制消费者无法通过宏改变已编译 framework 行为
- 接入方需手动定义 `HAS_TOBID=1`

### 6.3 依赖冲突风险

| 冲突项 | 说明 | 风险等级 |
|--------|------|----------|
| AnyThinkSDK vs ToBid SDK | 两者可能共享子广告网络（如 GDT、穿山甲） | 🔴 高 |
| OpenSSL | 当前已依赖 OpenSSL-Universal 3.x，ToBid 可能也依赖 | 🟡 中 |
| AdGainSDK | 当前通过 AdGainSDKTakuAdapter 接入，ToBid 可能不兼容 | 🟡 中 |
| 最低 iOS 版本 | ToBid 的最低 iOS 要求是否兼容 13.0 | 🟡 中 |
| 架构支持 | 是否需要 arm64 + x86_64（模拟器） | 🟢 低 |

### 6.3 版本统一建议

- 保持 `FLAME_SDK_VERSION` 与 podspec 版本一致
- 建议统一为 `0.2.0.0`（表示多聚合平台架构的首个版本）
- ToBid SDK 版本锁定到具体版本，不使用 `~>`（避免上游 breaking change）

## 七、参考资源

| 资源 | 位置 |
|------|------|
| ToBid Demo 工程 | `doc/tobid_doc/ToBidDemo官方/`（ToBid 官方资料目录） |
| ToBid SDK 集成说明 | `doc/tobid_doc/sdk集成下载说明/`（ToBid 官方资料目录） |
| 架构设计文档 | `doc/flame_mediation/tobid_doc/`（本系列文档） |
| 现有 TK 对接文档 | `doc/tk_doc/` |
| Flame SDK 对接说明 | `doc/flame_doc/` |
