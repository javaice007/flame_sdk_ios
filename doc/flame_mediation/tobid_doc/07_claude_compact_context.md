# 07 - Claude AI 紧凑上下文

> 本文件用于 Claude AI 跨会话恢复上下文。包含 Flame iOS SDK 多聚合平台改造的关键信息摘要。

## 项目概述

- **项目**: Flame iOS 广告聚合 SDK
- **工程路径**: `/Users/khj/Documents/code/97_ad/ios/flame_ios_sdk`
- **当前分支**: `feat/tb_adapter`
- **改造目标**: 从"仅支持 TopOn"演进为"多聚合平台可扩展架构"
- **第一个新增平台**: ToBid (TB)，但架构不限 TK/TB，支持无限扩展

## 当前状态

- [x] 现状分析完成
- [x] 架构设计完成
- [x] 文档修订完成（Phase 0）
- [x] Phase 1 mediation 基础骨架已完成（5 个文件）
- [x] Phase 1.1 骨架补丁已完成（Router Provider weak→strong）
- [x] Phase 1.2 文档清残已完成（删除 cv/cachedAt 旧描述，统一 Phase 2 边界）
- [x] Phase 2 pt=tk 初始化主链路接入已完成
- [x] Phase 2.1 文档清残 + 代码自检已完成（14003 统一、Phase 3 拆分为 3A/3B）
- [x] Phase 3A Reward 广告创建链路解耦已完成
- [x] Phase 3A.1 编译验证已完成（BUILD SUCCEEDED，0 errors）
- [x] Phase 3B Splash/Interstitial/Banner/Native 广告创建链路解耦已完成（BUILD SUCCEEDED，0 errors）
- [x] Phase 3B.1 编译复查 + 用户运行测试已完成（全部 5 种广告正常）
- [x] Phase 4 缓存策略调整已完成（网络优先，失败 fallback 完整缓存，BUILD SUCCEEDED）
- [x] Phase 4.1 AtNativeSelfRenderView 自渲染链路补查已完成（确认属于 TK Native Adapter 内部实现，不阻塞 Phase 5A）
- [x] Phase 5 TB Provider + Reward 已完成（FlameTBProvider + TbRewardAdapter，BUILD SUCCEEDED）
- [x] Phase 5A.1 运行前代码审查修复已完成（completionHandler 签名修正、WindMillRewardInfo 属性提取、BUILD SUCCEEDED）
- [x] Phase 5A.3 ToBid 依赖隔离修正已完成（#ifdef HAS_TOBID 条件编译，移除 podspec 强依赖，双场景 BUILD SUCCEEDED）
- [x] Phase 5A.4 ToBid 可选 Adapter 分发方案落地（双 xcframework + subspec，已完成但被 5A.5 替代）
- [x] Phase 5A.5 单包全量方案已完成（移除 subspec + #ifdef HAS_TOBID，恢复单一 xcframework + ToBid-iOS-RC 根级依赖，BUILD SUCCEEDED）

### AtNativeSelfRenderView 依赖关系（Phase 4.1 确认）

- 只被 `AtNativeAdapter.m` 内部 import + alloc/init
- 不被 FlameNativeAdImpl、FlameSdk、FlameNativeAdapterProtocol、flame_sdk_ios.h 直接依赖
- 属于 TK Native Adapter 内部自渲染辅助视图
- 后续 TB Native 接入时需自行实现对应的自渲染视图，与 TK 完全独立
- ToBid / WindMill 有独立 Native 视图体系（WindMillNativeAd / WindMillNativeAdView / refreshData: / setClickableViews: / unregisterDataObject）
- Phase 6 TB Native 设计约束已登记到 04_tobid_integration_notes.md（TbNativeAdapter 不得复用 AtNativeSelfRenderView，FlameNativeAdImpl 不得直接依赖 WindMill 视图）

### 已知副作用（Phase 3C 清理建议）

`FlameAdapterManager` 全部 5 个 `create*Adapter` 工厂方法（Reward / Splash / Interstitial / Banner / Native）均已变为死代码，无调用者。原因是各 At*Adapter 不再声明对外 Flame*Ad 协议，而 FlameAdapterManager 工厂方法返回 `id<FlameXxxAd>`。产生编译 warning（非 error）。建议 Phase 3C 统一清理。

### 临时调试日志（Phase 7 统一清理）

Phase 3A.1 + Phase 3B 共新增 `NSLog("[Mediation] ...")` 用于验证新链路。Phase 7 完整回归后统一清除所有 `[Mediation]` 调试日志。

日志位置：
- `FlameSdk.m` 全部 5 个 create*Ad 方法：Router.currentProvider 入口 + Flame*AdImpl 创建出口
- `FlameTKProvider.m` 全部 5 个 create*Adapter 方法：At*Adapter 创建

过滤关键字：`[Mediation]`

已验证运行日志（2026-06-11，Phase 3A.1 Reward）：
```
[Mediation] createRewardAd → Router.currentProvider
[Mediation] FlameTKProvider.createRewardAdapter → AtRewardAdapter(pId=b69a652fd58df9)
[Mediation] createRewardAd → FlameRewardAdImpl(adapter=AtRewardAdapter, pId=b69a652fd58df9)
```

### mediation 内部类不暴露

以下类均属于 SDK 内部实现，**不导入 `flame_sdk_ios.h` 伞头文件**，不对接入方 App 公开：

- `FlameMediationProvider`（协议）
- `FlameMediationRegistry`（单例）
- `FlameMediationRouter`（单例）
- `FlameTKProvider`
- `FlameTBProvider`

SDK 对外 API 保持不变。

### 平台标识使用 NSString code

- Registry 的 key 使用 `NSString *platformCode`（如 `@"tk"`、`@"tb"`）
- **不使用 `NS_ENUM`** 限制平台数量
- 内部可定义字符串常量，如 `static NSString * const kFlamePlatformTK = @"tk";`
- 后续接入第三、第四、第五个平台无需修改类型定义

### Provider 注册在统一入口

- Provider 注册发生在 `registerAllProviders` / Registry bootstrap 中
- **不在 `create*Ad` 中注册 Provider**
- 广告创建链路只通过 Router 获取当前 Provider

### 缓存策略：网络优先，失败 fallback 缓存

- 每次冷启动 `init` 优先请求后台配置
- 网络成功：使用最新配置，并更新缓存
- 网络失败：如果本地缓存完整（pt + aId + aKey + pMap），则 fallback 使用缓存
- 无缓存且网络失败：初始化失败并回调错误
- `cv` / `configVersion` 推荐后台支持，但当前**不强依赖**
- `cachedAt` 用于日志和兜底判断，**不作为主刷新依据**
- **不采用 24 小时 TTL 作为主刷新策略**，避免后台从 tk 切到 tb 后 SDK 长时间不生效

### 当前阶段不实现广告位级平台路由

- 只做 App 级平台路由
- `pIds` 只支持 `Dict<String, String>`
- 不要求兼容 object 类型广告位配置
- 广告位级平台路由只作为未来设计预留

### ToBid 先只做 Reward

- Phase 5 先只打通激励视频
- Phase 6 再补齐其他广告类型（插屏、开屏、Banner、原生）

## 核心架构

### 入口

- `FlameSdk` 单例 → `initWithAppId:appKey:callback:`
- 状态机: Uninitialized → Initializing → Initialized / Failed

### 初始化链路（改造后）

```
FlameSdk.init → FlameConfigManager.updateApp (后台 API, 网络优先)
  → 解密响应 → FlameAppEntity {pt, aId, aKey, pIds, cv?}
  → FlameSdk 根据 pt 从 Registry 获取 Provider
  → FlameMediationRouter.activateProvider(provider)
  → Provider.initSDK
  → callback.success
```

> **FlameConfigManager 职责边界**：只负责配置请求、AES-GCM 解密、缓存、返回 FlameAppEntity。不触发 Router 激活。不选择 Provider。不初始化广告平台。不注册 Provider。Provider 选择和 Router 激活由 FlameSdk 初始化链路在拿到 FlameAppEntity 后处理。Phase 2 允许新增 `getPt` 只读访问器（与 `getAId`/`getAKey` 对称），仅返回 `appEntity.pt`，不包含任何 Router 逻辑。

### 广告创建链路（改造后，Phase 3A/3B 分步实施）

```
FlameSdk.createRewardAd → FlameMediationRouter → currentProvider.createRewardAdapter
  → AtRewardAdapter → FlameRewardAdImpl (持有 id<FlameRewardAdapterProtocol>)
```

> **Phase 3A + 3A.1 已完成 Reward 解耦并通过编译验证**，Phase 3B 补齐 Splash/Interstitial/Banner/Native。

### 新增核心类（SDK 内部实现，不暴露）

| 类 | 职责 |
|----|------|
| `FlameMediationProvider` | 协议：platformIdentifier, initSDK, create*Ad（返回 id\<FlameXxxAdapterProtocol\>） |
| `FlameMediationRegistry` | 注册表：register/unregister/get provider（key 为 NSString platformCode） |
| `FlameMediationRouter` | 路由：activateProvider, route create*Ad。**strong 持有 currentProvider**，clear 时释放 |
| `FlameTKProvider` | TK 封装：包装 FlameAdapterManager |
| `FlameTBProvider` | TB 封装：初始化 ToBid SDK |

### 内部适配器协议

| 协议 | 用途 |
|------|------|
| `FlameRewardAdapterProtocol` | 内部激励视频适配器协议 |
| `FlameSplashAdapterProtocol` | 内部开屏适配器协议 |
| `FlameInterstitialAdapterProtocol` | 内部插屏适配器协议 |
| `FlameBannerAdapterProtocol` | 内部横幅适配器协议 |
| `FlameNativeAdapterProtocol` | 内部原生适配器协议 |

> **Adapter 类型设计**：Provider 创建并返回 `id<FlameXxxAdapterProtocol>`。`FlameXxxAdImpl` 实现对外 `FlameXxxAd` 协议，内部持有 `id<FlameXxxAdapterProtocol>`。平台 Adapter 不直接实现对外 Flame 协议，不直接暴露给接入方。

## 目录结构

```
flame_sdk_ios/
  core/              FlameSdk, FlameConfigManager, FlameAppEntity
  utils/             FlameNetworkUtils, FlameAesCryptoUtils, FlameConfigLocalStorage
  mediation/          [新增] Provider, Registry, Router（SDK 内部，不暴露）
    tk/              [新增] FlameTKProvider
    tb/              [新增] FlameTBProvider
  adapter/
    tk/              [已有] AtSplashAdapter, AtRewardAdapter, AtInterstitialAdapter, AtBannerAdapter, AtNativeAdapter
    tb/              [新增] TbSplashAdapter, TbRewardAdapter, TbInterstitialAdapter, TbBannerAdapter, TbNativeAdapter
  ads/
    splash/          FlameSplashAdImpl
    reward/          FlameRewardAdImpl
    interstitial/    FlameInterstitialAdImpl
    banner/          FlameBannerAdImpl
    nativate/        FlameNativeAdImpl
```

## 后台配置

- API: `POST https://api.adsurge.cn/api/v1/sdk/init`
- 加密: AES-GCM，密钥 = appKey
- 返回: `{pt, aId, aKey, pIds, cv?}`
- 当前阶段 `pIds` 只支持 `Dict<String, String>`
- 缓存: NSUserDefaults (suite `flame_sdk_conf`)，网络优先，失败 fallback 完整缓存

## 依赖

- TopOn: `AnyThinkiOS 6.5.71`, `OpenSSL-Universal ~> 3.6`, `AdGainSDK 4.2.7.1`
- ToBid: `ToBid-iOS-RC 5.5.6`（Phase 5 新增）
- 最低 iOS: 13.0

### ToBid 分发策略（Phase 5A.5 单包全量）

- `flame_sdk_ios.podspec` **单包全量分发**，`s.vendored_frameworks = '**/flame_sdk_ios.xcframework'`
- `s.dependency 'ToBid-iOS-RC', '5.5.6'` 在根级声明，所有接入方自动获取 ToBid SDK
- **`#ifdef HAS_TOBID` 已完全移除**（Phase 5A.5），所有 ToBid 代码始终编译
- 受清理文件：`FlameSdk.m`（TBProvider 注册）、`FlameTBProvider.m`（WindMill API）、`TbRewardAdapter.h/.m`（协议遵循 + WindMill API）
- 运行时平台切换由后台 `pt=tk/tb` 控制，非编译时选择
- 本地开发：Podfile `tb_pods` + post_install（仅 OpenSSL + realpath 修补），无需 HAS_TOBID 宏

#### WindFoundation / WindSDK 依赖重叠

- SigmobAd-iOS（v4.20.12，via AnyThinkMediationSigmobAdapter）和 ToBid-iOS-RC（v5.5.6）均包含 `WindFoundation.xcframework v180` 和 `WindSDK.xcframework v1.0`
- **两者版本完全一致**（v180 / v1.0），Bundle ID 相同（`com.sigmob.WindFoundation` / `com.sigmob.WindSDK`）
- 当前未出现 pod install 硬错误，但存在同名 framework 覆盖风险
- 需要通过干净环境 pod install、最终 App 链接、真机运行验证后确认可接受
- WindMillSDK 仅存在于 ToBid-iOS-RC，SigmobAd-iOS 不包含

## 实施阶段

| Phase | 内容 | 状态 |
|-------|------|------|
| 0 | 文档修订 | ✅ 完成 |
| 1 | mediation 基础骨架（不接主链路，不改任何已有源码） | ✅ 完成 |
| 1.1 | 骨架补丁：Router Provider weak→strong | ✅ 完成 |
| 1.2 | 文档清残：删除 cv/cachedAt 旧描述，统一 Phase 2 边界 | ✅ 完成 |
| 2 | pt=tk 初始化主链路接入（含 14003 错误码） | ✅ 完成 |
| 2.1 | 文档清残 + 代码自检（14003 统一、Phase 3 拆分为 3A/3B） | ✅ 完成 |
| 3A | Reward 广告创建链路解耦（先只做激励视频） | ✅ 完成 |
| 3A.1 | 编译验证与回归确认 | ✅ 完成 |
| 3B | 补齐 Splash/Interstitial/Banner/Native 解耦 | ✅ 完成 |
| 3B.1 | 编译复查 + 运行测试 | ✅ 完成 |
| 4 | 缓存策略调整（网络优先） | ✅ 完成 |
| 4.1 | AtNativeSelfRenderView 自渲染链路补查 | ✅ 完成 |
| 5 | TB Provider + Reward | ✅ 完成 |
| 5A.1 | 运行前代码审查修复 | ✅ 完成 |
| 5A.2 | pt=tb Reward 真机验证 | 待开始（需后台配置 + adapter subspec） |
| 5A.3 | ToBid 依赖隔离修正 | ✅ 完成 |
| 5A.4 | ToBid 可选 Adapter 分发方案落地（双 xcframework + subspec） | ✅ 完成（已被 5A.5 替代） |
| 5A.5 | 单包全量方案（移除 subspec + #ifdef HAS_TOBID，单 xcframework） | ✅ 完成 |
| 6 | TB 其他广告类型 | 待开始 |
| 7 | 完整回归和依赖验证 | 待开始 |

## 红线

- 不改 SDK 对外 API
- 不暴露 mediation 内部类到伞头文件
- 不同时初始化所有平台
- 不在每个广告 Impl 里写 tk/tb/xxx 判断
- 不把 TB 代码混到 TK 目录
- 未知 pt 必须明确失败并回调错误（14003）
- 不提前实现广告位级平台路由
- **任何代码实施都必须等下一轮明确指令**
- **Router strong 持有 currentProvider，clear 时释放**（Phase 1.1 修正）
- **Phase 2 不包含 cv/cachedAt 新增**（cv/cachedAt 如需新增应在 Phase 4 缓存策略阶段处理）
- **Phase 2 不做缓存策略重构**
- **Phase 2 不由 FlameConfigManager 触发 Router**（由 FlameSdk 在拿到 FlameAppEntity 后处理）
- **14003 为不支持的聚合平台错误码**（文档原规划 14002，但 14002 已被 INVALID_PARAM 占用，Phase 2 改用 14003）

## 文档索引

架构文档位于 `doc/flame_mediation/tobid_doc/` 下 00-09 号文档。
