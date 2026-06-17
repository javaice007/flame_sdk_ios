# 01 - 当前 SDK 接入现状分析

> 本文档记录 Flame iOS SDK 在"多聚合平台改造"之前的代码现状，作为架构设计的事实基础。

## 一、SDK 整体入口

### 1.1 主入口类

**`FlameSdk`** — 单例，对外 API 层

- 头文件: `flame_sdk_ios/core/FlameSdk.h`
- 实现文件: `flame_sdk_ios/core/FlameSdk.m`
- 通过伞头文件 `flame_sdk_ios.h` 对外公开

**公开初始化方法**：

```objc
+ (void)initWithAppId:(NSString *)appId appKey:(NSString *)appKey;
+ (void)initWithAppId:(NSString *)appId appKey:(NSString *)appKey callback:(id<FlameCallback>)callback;
```

**其他公开方法**：

| 方法 | 说明 |
|------|------|
| `+ (void)clear` | 重置初始化状态，取消网络请求，清除缓存 |
| `+ (void)setDebug:(BOOL)isDebug` | 委托给 FlameAdapterManager（当前始终 YES，忽略传入值） |
| `+ (BOOL)isInitialized` | 检查 initState == Initialized |
| `+ (BOOL)checkInitialization` | 同上，附带错误日志 |

### 1.2 参数传入方式

| 参数 | 传入方式 | 传递路径 |
|------|----------|----------|
| appId | `initWithAppId:appKey:` | → `FlameConfigManager.updateAppWithAppId:appKey:callback:` |
| appKey | `initWithAppId:appKey:` | 同上；同时作为 AES-GCM 解密密钥 |
| 调试开关 | `setDebug:` | 委托 `FlameAdapterManager.setDebug`（当前始终 YES） |
| 渠道参数 | ❌ 不支持 | 无 channel 字段 |

### 1.3 初始化状态机

FlameSdk 内部使用 4 状态枚举：

```objc
typedef NS_ENUM(NSInteger, FlameInitState) {
    FlameInitStateUninitialized = 0,
    FlameInitStateInitializing,
    FlameInitStateInitialized,
    FlameInitStateFailed
};
```

状态转换逻辑（`@synchronized` 保护）：
- `Uninitialized` → 设为 `Initializing`，继续初始化
- `Initializing` → 回调加入 `pendingCallbacks` 队列，返回
- `Initialized` → 立即回调 success
- `Failed` → 回调 fail

## 二、初始化过程中调用的核心类

| # | 类 | 职责 | 路径 |
|---|---|---|---|
| 1 | `FlameSdk` | 入口，状态机，单例 | `core/FlameSdk.m` |
| 2 | `FlameConfigManager` | 配置拉取（网络/缓存）、AES 解密、实体解析 | `core/FlameConfigManager.m` |
| 3 | `FlameConfigLocalStorage` | NSUserDefaults 持久化 (suite `flame_sdk_conf`) | `utils/FlameConfigLocalStorage.m` |
| 4 | `FlameNetworkUtils` | HTTP POST (JSON)，15s 超时，主线程回调 | `utils/FlameNetworkUtils.m` |
| 5 | `FlameMd5SignatureUtils` | MD5 签名（sorted params + `&key=<appKey>`） | `utils/FlameMd5SignatureUtils.m` |
| 6 | `FlameAesCryptoUtils` | AES-GCM 加解密（OpenSSL EVP，128/192/256 自适配） | `utils/FlameAesCryptoUtils.m` |
| 7 | `FlameAppEntity` | 数据模型: `pt`, `aId`, `aKey`, `pIds` | `core/FlameAppEntity.m` |
| 8 | `FlameAdapterManager` | 初始化 TopOn SDK (`ATAPI`) + 广告创建 | `adapter/FlameAdapterManager.m` |
| 9 | `FlameLogger` | NSLog 封装，TAG `FlameSDK` | `core/FlameLogger.m` |
| 10 | `FlameErrorCode` | 错误码常量 | `core/FlameErrorCode.m` |

**内部回调类**（定义在 FlameSdk.m 内部）：
- `UpdateAppCallback` — 包装用户回调；成功时读取 aId/aKey 触发 Adapter 初始化
- `AdapterInitCallback` — 包装用户回调；成功/失败时更新 SDK 状态并通知 pendingCallbacks

## 三、完整初始化调用链

```
FlameSdk.initWithAppId:appKey:callback:
  │
  ├─ @synchronized 状态检查:
  │   Initialized    → 立即回调 success，返回
  │   Initializing   → 回调加入 pendingCallbacks，返回
  │   Failed         → 回调 fail，返回
  │   Uninitialized  → 设为 Initializing，继续
  │
  ├─ 创建 UpdateAppCallback(wrapper)
  ▼
FlameConfigManager.updateAppWithAppId:appKey:callback:
  │
  ├─ 检查本地缓存 (NSUserDefaults suite "flame_sdk_conf"):
  │   aId + aKey + pMap 均存在 → 构建 FlameAppEntity → callback success → 返回
  │
  ├─ 无缓存 → JSON POST https://api.adsurge.cn/api/v1/sdk/init
  │   参数: { appId, version:"1.0.0", timestamp(毫秒), sign(MD5) }
  │
  ├─ 响应处理:
  │   dict → data → edata → AES-GCM 解密(密钥=appKey) → JSON
  │   → FlameAppEntity { pt, aId, aKey, pIds }
  │   → 缓存至 NSUserDefaults → callback success
  │
  ▼
UpdateAppCallback.success:
  ├─ 从 FlameConfigManager 读取 aId + aKey
  ├─ 创建 AdapterInitCallback(wrapper)
  ▼
FlameAdapterManager.initSDKWithAppId:appKey:initListener:
  │
  ├─ [ATAPI setLogEnabled:YES]
  ├─ [ATAPI integrationChecking]
  ├─ [[ATAPI sharedInstance] startWithAppID:aId appKey:aKey error:&error]
  │
  ├─ 错误 → callback fail
  ├─ 成功 → isInitialized = YES → callback success
  ▼
AdapterInitCallback.success:
  ├─ FlameSdk 状态 → Initialized
  ├─ 触发 userCallback + pendingCallbacks success
  ▼
SDK 初始化完成 ✅
```

## 四、后台配置链路

### 4.1 请求位置

唯一入口: `FlameConfigManager.updateAppWithAppId:appKey:callback:`

- URL: `https://api.adsurge.cn/api/v1/sdk/init`（硬编码）
- 方法: JSON POST
- 超时: 15 秒

### 4.2 请求参数

```json
{
  "appId": "Flame平台AppId",
  "version": "1.0.0",
  "timestamp": 1718XXXXXXX,
  "sign": "<MD5签名>"
}
```

签名算法: 参数按 key 字母排序 → `key=value&` 拼接 → 末尾追加 `&key=<appKey>` → MD5

### 4.3 返回数据模型

```json
{
  "data": {
    "edata": "<AES-GCM 加密后的 Base64 字符串>"
  }
}
```

解密后 → `FlameAppEntity`：

| 字段 | 类型 | 用途 |
|------|------|------|
| `pt` | NSString | 平台类型标识（**已存储但未使用**） |
| `aId` | NSString | 下游聚合平台 App ID（当前为 TopOn） |
| `aKey` | NSString | 下游聚合平台 App Key |
| `pIds` | Dict<String,String> | 广告位映射: Flame ID → TopOn ID |

### 4.4 缓存机制

- 存储: `NSUserDefaults` (suite `flame_sdk_conf`)
- 缓存键: `pt`, `aId`, `aKey`, `pMap`
- 命中条件: `pt` && `aId` && `aKey` && `pMap` 均非空（当前代码缺少 pt 检查，改造后需补充）
- 清除: `FlameSdk.clear()` → 清空内存 + 清空 NSUserDefaults

### 4.5 关键发现

> **`pt` 字段已存在但完全未使用。** 该字段被持久化到 NSUserDefaults，但代码中从未读取或据此做分支逻辑。这是新增聚合平台介入点的最佳锚点。

## 五、当前 TK（TopOn/AnyThink）接入方式

### 5.1 关键类列表

| 文件 | 职责 |
|------|------|
| `adapter/FlameAdapterManager.h/.m` | TK SDK 初始化 + 广告创建工厂 |
| `adapter/tk/AtSplashAdapter.h/.m` | 开屏广告适配 |
| `adapter/tk/AtRewardAdapter.h/.m` | 激励视频适配 |
| `adapter/tk/AtInterstitialAdapter.h/.m` | 插屏广告适配 |
| `adapter/tk/AtBannerAdapter.h/.m` | 横幅广告适配（模板+自渲染） |
| `adapter/tk/AtNativeAdapter.h/.m` | 原生/信息流广告适配 |
| `adapter/tk/AtNativeSelfRenderView.h/.m` | 原生自渲染视图 |

### 5.2 广告类型映射表

| 广告类型 | Flame 协议 | Impl 层 | TK 适配器 | TopOn Delegate |
|----------|-------------|---------|-----------|----------------|
| 开屏 | `FlameSplashAd` | `FlameSplashAdImpl` | `AtSplashAdapter` | `ATSplashDelegate` |
| 激励视频 | `FlameRewardAd` | `FlameRewardAdImpl` | `AtRewardAdapter` | `ATRewardedVideoDelegate` |
| 插屏 | `FlameInterstitialAd` | `FlameInterstitialAdImpl` | `AtInterstitialAdapter` | `ATInterstitialDelegate` |
| 横幅 | `FlameBannerAd` | `FlameBannerAdImpl` | `AtBannerAdapter` | `ATBannerDelegate` |
| 原生 | `FlameNativeAd` | `FlameNativeAdImpl` | `AtNativeAdapter` | `ATNativeADDelegate` |

### 5.3 广告加载→展示→回调→释放调用链（激励视频）

```
【加载】
FlameSdk.createRewardAdWithVC:placementId:listener:
  → isInitialized 检查 (失败返回 14000)
  → FlameConfigManager.getPId(flamePlacementId)   // Flame ID → TopOn ID
  → FlameRewardAdImpl(vc, flameId, topOnId, listener)
    → AtRewardAdapter(vc, topOnId, listener)
      → [[ATAdManager sharedManager] loadADWithPlacementID:extra:delegate:]

【展示】
FlameRewardAdImpl.show → AtRewardAdapter.show
  → [[ATAdManager sharedManager] showRewardedVideoWithPlacementID:inVC:delegate:]

【回调 TopOn → Flame】
didFinishLoading       → listener.onAdLoaded
didStartPlaying        → listener.onAdShow
didClick               → listener.onAdClicked
didEndPlaying          → listener.onAdPlayComplete
didRewardSuccess       → listener.onAdReward:userCustomData:transId:
didClose               → listener.onAdClosed
didFailToLoad          → listener.onAdError:desc:
didFailToPlay          → listener.onAdError:desc:

【释放】
FlameRewardAdImpl.destroy → AtRewardAdapter.destroy (置空所有引用)
```

### 5.4 各适配器统一方法模式

| 方法 | 说明 |
|------|------|
| `initWithViewController:placementId:pId:listener:` | 初始化，接收映射后的 TopOn 广告位 ID |
| `load` / `loadWithUserId:userCustomData:` | 加载广告 |
| `isReady` | 检查广告是否就绪 |
| `isLoading` | 检查是否正在加载 |
| `show` / `showInContainer:` | 展示广告 |
| `destroy` | 销毁释放 |

## 六、当前 SDK 的广告抽象程度

### 6.1 已有三层封装

```
公开 API 层 (FlameSdk)
  → Impl 代理层 (FlameXxxAdImpl)
    → 适配器层 (AtXxxAdapter)
      → TopOn SDK (AnyThinkSDK)
```

- **FlameSdk**: 广告位 ID 映射 + Impl 创建（广告创建逻辑硬编码在 `create*Ad` 方法中）
- **FlameXxxAdImpl**: 薄代理，持有 `id<FlameXxxAd> adapter`，添加初始化状态检查和重复加载保护
- **AtXxxAdapter**: 实际调用 TopOn API，将 TopOn 回调翻译为 Flame Listener 回调

### 6.2 回调协议

**不共用**，每种广告类型有独立 Listener 协议：

| 广告类型 | Listener 协议 |
|----------|---------------|
| 开屏 | `FlameSplashListener` |
| 激励视频 | `FlameRewardListener` |
| 插屏 | `FlameInterstitialListener` |
| 横幅 | `FlameBannerListener` |
| 原生 | `FlameNativeListener` |

基础协议 `FlameCallback`（仅用于 SDK 初始化回调）：
```objc
@protocol FlameCallback <NSObject>
@required
- (void)success;
- (void)fail:(NSString *)code desc:(NSString *)desc;
@end
```

### 6.3 已有结构

| 模式 | 存在情况 |
|------|----------|
| Manager | ✅ `FlameAdapterManager`、`FlameConfigManager` |
| Adapter | ✅ `adapter/tk/At*Adapter` |
| Impl 代理 | ✅ `ads/*/Flame*AdImpl` |
| 协议 | ✅ 每种广告类型独立 Flame 协议 |
| Factory / Router / Provider / Registry | ❌ 不存在 |

## 七、依赖管理

### 7.1 Podfile 声明

```ruby
pod 'AnyThinkSDK', '6.3.12.1'           # TopOn 核心
pod 'AnyThinkMediation', '6.3.12.1'      # TopOn 聚合
pod 'AdGainSDKTakuAdapter', '~> 3.5.5'   # TopOn + AdGain 适配器
pod 'OpenSSL-Universal', '~> 3.0'        # AES 加密
```

### 7.2 构建相关

- `xcFramework_build.sh` — framework 打包脚本
- `OpenSSL.xcconfig` — OpenSSL 路径配置
- `flame_sdk_ios.podspec` — SDK 发布配置
- 最低 iOS 版本: 13.0
- 版本号不一致: `FLAME_SDK_VERSION = "1.0.0"` vs podspec `0.1.8.4`

## 八、已发现问题

| 问题 | 严重程度 |
|------|----------|
| `setDebug:` 忽略传入参数，始终 YES | 低 |
| `FlameLogger` 无级别控制，始终 NSLog | 低 |
| API 端点硬编码，无重试/备用 URL | 中 |
| 版本号不一致 (1.0.0 vs 0.1.8.4) | 低 |
| 无 ATT/IDFA 相关代码 | 中 |
| 无 Info.plist 配置声明 | 中 |
| `pt` 字段已存储但未使用 | 设计待完成 |
| 三处独立初始化状态标记可能失同步 | 中 |
| TOCTOU 竞态: `isInitialized` 检查与 `appEntity` 访问非原子 | 低 |
