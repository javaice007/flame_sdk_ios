# FlameSDK iOS 0.1.8.1 版本更新说明

> 基于 0.1.8 版本，本次为 **稳定性修复版本**，主要解决：① SDK 未初始化时调用广告 API 导致的 Crash；② 错误 AppId/AppKey 场景下 callback 初始化路径的 EXC_BAD_ACCESS 崩溃；③ 服务端返回异常数据时的类型安全问题。

---

## 版本信息

| 项目 | 内容 |
|------|------|
| 上级版本 | flame_sdk_ios 0.1.8 |
| 当前版本 | flame_sdk_ios 0.1.8.1 |
| 更新类型 | Bug Fix / 稳定性优化 |
| 集成方式 | CocoaPods（`pod 'flame_sdk_ios', '0.1.8.1'`） |

---

## 更新内容

### 1. 【崩溃修复】移除未初始化时的 @throw 异常抛出

**问题描述**：0.1.8 版本中，在 SDK 未初始化时调用广告相关方法（如 `load`、`show`、`destroy` 等），SDK 内部会通过 `@throw` 抛出 `NSException`。由于 Swift 的 `do-catch` 无法捕获 Objective-C 的 `NSException`，导致 App 直接 Crash。

**修复方案**：

- `checkInitialization` 方法返回值从 `void` 改为 `BOOL`，未初始化时返回 `NO` 并打印错误日志，不再抛出异常
- 所有广告 Impl 层调用处（Banner、Interstitial、Reward、Splash、Native）的未初始化检查从抛异常改为安全返回
- `isInitialized` 判断逻辑从依赖 `FlameAdapterManager.sharedInstance.isInitialized` 改为检查 SDK 内部 `FlameSDKInitState` 枚举状态，判断更准确

**影响范围**：所有广告类型（Banner、插屏、激励视频、开屏、信息流）

**涉及文件**：
- `FlameSdk.h` / `FlameSdk.m`
- `FlameAdapterManager.h` / `FlameAdapterManager.m`
- `FlameBannerAdImpl.m`
- `FlameInterstitialAdImpl.m`
- `FlameRewardAdImpl.m`
- `FlameSplashAdImpl.m`
- `FlameNativeAdImpl.m`

---

### 2. 【崩溃修复】广告创建入口增加初始化前置检查

**问题描述**：0.1.8 中 `createXxxAd` 系列方法未做初始化状态拦截，在 SDK 未初始化时仍会创建广告对象并执行后续逻辑，可能导致空指针或无效状态崩溃。

**修复方案**：

在 `FlameSdk` 中所有 6 个广告创建方法（`createRewardAd`、`createInterstitialAd`、`createSplashAd`、`createBannerAd`、`createSelfRenderBannerAd`、`createNativeAd`）的入口处增加初始化状态检查：
- 未初始化时打印错误日志
- 通过 `listener.onAdError` 回调通知调用方（错误码 `14000`，描述 `"SDK not initialized, please call initWithAppId:appKey: first"`）
- 返回 `nil`，阻止创建无效广告对象

**涉及文件**：`FlameSdk.m`

---

### 3. 【崩溃修复】Adapter 管理层未初始化时直接返回 nil

**问题描述**：0.1.8 中 `FlameAdapterManager` 的各 `createXxxAdapter` 方法在检测到未初始化时仅打印日志，但仍继续执行后续创建逻辑。

**修复方案**：

5 个 `createXxxAdapter` 方法（Reward、Interstitial、Splash、Banner、Native）在未初始化时直接 `return nil`，不再继续执行。同时修正日志中的初始化方法名提示（`initSDKWithAppId:` → `initWithAppId:appKey:`）。

**涉及文件**：`FlameAdapterManager.m`

---

### 4. 【崩溃修复】JSON 解析增加严格的类型校验与 NSNull 防护

**问题描述**：当服务端返回异常数据结构（如字段值为 `NSNull`、顶层非 JSON Object、字段类型不匹配等），SDK 内部直接强制类型转换会导致 Crash。

**修复方案**：

**FlameAppEntity（`fromJson:` 方法）**：
- 增加 `NSData` 空值检查
- JSON 反序列化后校验顶层是否为 `NSDictionary`
- 对 `pt`、`aId`、`aKey` 每个字段做 `isKindOfClass:[NSString class]` + `NSNull` 过滤
- `pIds` 字典遍历时过滤 `NSNull` 和非 `NSString` 值

**FlameConfigManager（`updateAppWithAppId:` 回调）**：
- 校验 `encryptedData` 是否为 `NSDictionary`
- 逐层校验 `data` 字段：存在性 → 非 NSNull → NSDictionary 类型
- 逐层校验 `edata` 字段：存在性 → 非 NSNull → NSString 类型 → 非空串
- 每个校验失败都通过 `callback fail:` 回调错误信息，不再继续执行

**涉及文件**：
- `FlameAppEntity.m`
- `FlameConfigManager.m`

---

### 5. 【崩溃修复】Callback 初始化路径 EXC_BAD_ACCESS（错误 AppId/AppKey 重复触发）

**问题描述**：使用错误 AppId/AppKey 调用 `initWithAppId:appKey:callback:` 重复触发初始化，在 fail callback 返回后发生 `EXC_BAD_ACCESS`。崩溃栈显示在 SDK 内部 block 释放阶段（`_Block_release → __destroy_helper_block_e8_32s40s48s`）。同步初始化 `initWithAppId:appKey:` 多次测试不崩溃。

**根因分析**：

1. **状态机缺少 `Failed` 状态守卫**：`initWithAppId:appKey:callback:` 方法只拦截了 `Initialized` 和 `Initializing` 两种状态，未拦截 `Failed` 状态。初始化失败后再次调用会从 `Failed` 穿透到 `Initializing`，重新发起网络请求，旧请求未取消，新旧请求的 completion block 生命周期交叉。
2. **`FlameConfigManager` 缺少请求去重机制**：`updateAppWithAppId:appKey:callback:` 每次调用都发起新的 `NSURLSessionDataTask`，无请求取消或 generation 隔离，旧请求的 completion 回来时仍访问旧 callback 对象。
3. **`UpdateAppCallback`/`AdapterInitCallback` 缺少防重入保护**：`success`/`fail` 没有幂等保护，理论上存在被多次调用的风险。

**修复方案**：

- **状态机补齐 `Failed` 守卫**：`Failed` 状态下调用 init 直接返回 fail callback，提示调用方需要先调用 `FlameSdk.clear()` 再重试，不自动穿透重发请求
- **`Initializing` 状态支持多调用方等待**：初始化进行中时，后续调用方的 callback 被加入 `pendingCallbacks` 队列，初始化完成后统一回调，不重复发请求
- **`FlameSdk.clear()` 重置完整状态**：清空缓存的同时重置 `initState` 为 `Uninitialized`，清空 `pendingCallbacks`，取消 ConfigManager 进行中的请求，允许重新初始化
- **请求 generation 机制**：`FlameConfigManager` 每次发请求前递增 generation，completion 回调时校验 generation 是否匹配，不匹配则直接忽略过期回调
- **`UpdateAppCallback` / `AdapterInitCallback` 增加 `hasCalled` 幂等保护**：确保 `success`/`fail` 只触发一次，防止 block 释放阶段重复调用

**涉及文件**：
- `FlameSdk.m`
- `FlameConfigManager.h` / `FlameConfigManager.m`

---

### 6. 【行为变更】初始化失败后的重试流程

**0.1.8 行为**：初始化失败后再次调用 init 会自动重新发请求（无限制）。

**0.1.8.1 行为**：

| 状态 | 再次调用 init 的行为 |
|------|---------------------|
| `Uninitialized` | 正常发请求 |
| `Initializing` | callback 加入等待队列，不重复发请求 |
| `Initialized` | 直接回调 success |
| **`Failed`** | **直接回调 fail，提示需要 clear 后重试** |

**正确的重试流程**：
```swift
// 初始化失败后，需要先 clear 再重试
FlameSdk.clear()
FlameSdk.initWithAppId("YOUR_APP_ID", appKey: "YOUR_APP_KEY") {
    // success
} fail: { code, desc in
    // fail
}
```

---

### 7. 【行为变更】Initializing 状态下多调用方共享等待

**0.1.8 行为**：`Initializing` 状态下再次调用 init 会立即返回 fail（"SDK is already initializing"）。

**0.1.8.1 行为**：`Initializing` 状态下再次调用 init，callback 会被加入等待队列。当初始化完成（成功或失败）时，所有等待中的 callback 都会收到对应的结果回调。

> 这意味着多个调用方可以安全地同时调用 `initWithAppId:appKey:callback:`，无需自行做互斥处理。

---

## 错误码说明（新增）

| 错误码常量 | 值 | 说明 |
|-----------|-----|------|
| `ERROR_CODE_NOT_INIT` | `14000` | SDK 未初始化 |
| `ERROR_CODE_INVALID_APP_ID` | `14001` | 无效的 App ID 或 App Key |
| `ERROR_CODE_INVALID_PARAM` | `14002` | 参数错误（如宽高、用户信息等非法） |
| `ERROR_CODE_INVALID_AD_PLACEMENT` | `14004` | 广告位不存在 |
| `ERROR_CODE_NETWORK_ERROR` | `15000` | 网络错误 |

> 开发者可通过 `onAdError(code:desc:)` 回调中的 `code` 值进行错误分类处理。

---

## 对接方注意事项

### ⚠️ Q2 内容更新

0.1.8 文档中的 **Q2（Swift 无法捕获 SDK Objective-C 异常）** 已在 0.1.8.1 中修复。SDK 不再使用 `@throw` 抛出异常，改为通过返回值和回调处理错误。**Swift 调用方无需再做额外的异常捕获处理。**

### 接入建议

1. **强烈建议升级**：如果您的 App 在初始化未完成时存在调用广告 API 的可能性（如页面预加载、定时任务等），请尽快升级到 0.1.8.1
2. **处理 `onAdError` 回调**：升级后 SDK 在未初始化时会通过 `onAdError` 回调通知，建议在所有广告 Listener 中正确处理 `onAdError(code:desc:)`，特别是 `code == "14000"` 的情况
3. **确保初始化完成后再创建广告**：虽然 SDK 不再崩溃，但仍建议通过 `FlameSdk.isInitialized()` 或异步初始化回调确认初始化成功后再调用广告 API

### 集成方式不变

```ruby
# Podfile 中将版本号改为 0.1.8.1 即可
pod 'flame_sdk_ios', '0.1.8.1'
```

其余 API 接口、回调协议、集成配置均与 0.1.8 完全一致，无需修改对接代码。

---

## 完整变更文件列表

| 文件 | 变更类型 | 说明 |
|------|---------|------|
| `FlameSdk.h` | 修改 | `checkInitialization` 返回值改为 `BOOL` |
| `FlameSdk.m` | 修改 | 移除 @throw；状态机补齐 Failed 守卫；Initializing 状态 pendingCallbacks 等待队列；UpdateAppCallback/AdapterInitCallback hasCalled 幂等保护；clear 重置完整状态 |
| `FlameConfigManager.h` | 修改 | 新增 `cancelCurrentRequest` 方法 |
| `FlameConfigManager.m` | 修改 | 服务端响应逐层类型校验和 NSNull 防护；请求 generation 去重机制；clearCache 时取消进行中请求 |
| `FlameAdapterManager.h` | 修改 | `checkInitialization` 返回值改为 `BOOL` |
| `FlameAdapterManager.m` | 修改 | 未初始化时 return nil；修正日志方法名 |
| `FlameBannerAdImpl.m` | 修改 | 未初始化检查改为安全返回 |
| `FlameInterstitialAdImpl.m` | 修改 | 未初始化检查改为安全返回 |
| `FlameRewardAdImpl.m` | 修改 | 未初始化检查改为安全返回 |
| `FlameSplashAdImpl.m` | 修改 | 未初始化检查改为安全返回 |
| `FlameNativeAdImpl.m` | 修改 | 未初始化检查改为安全返回 |
| `FlameAppEntity.m` | 修改 | JSON 解析增加类型校验和 NSNull 防护 |
