# 08 - 下一阶段 Prompt

> 当开启新的 Claude 会话继续实施时，使用以下 Prompt 恢复上下文并开始工作。
>
> **重要**：当前已完成 Phase 0（文档修订）、Phase 1（mediation 基础骨架）、Phase 1.1（Router Provider weak→strong 补丁）、Phase 2（pt=tk 初始化主链路）、Phase 2.1（文档清残 + 代码自检）、Phase 3A（Reward 广告创建链路解耦）、Phase 3A.1（编译验证，BUILD SUCCEEDED）、Phase 3B（Splash/Interstitial/Banner/Native 解耦，BUILD SUCCEEDED）、Phase 3B.1（编译复查 + 运行测试全部通过）、Phase 4（缓存策略调整，网络优先 fallback 缓存，BUILD SUCCEEDED）、Phase 4.1（AtNativeSelfRenderView 自渲染链路补查，确认 TK 内部实现）、Phase 5（TB Provider + Reward，BUILD SUCCEEDED）。下一阶段建议是 Phase 6（TB 其他广告类型接入）。

## 快速启动 Prompt

```
请阅读以下文件恢复上下文：

1. doc/flame_mediation/tobid_doc/07_claude_compact_context.md
2. doc/flame_mediation/tobid_doc/02_multi_mediation_architecture.md
3. doc/flame_mediation/tobid_doc/05_implementation_plan.md

这是 Flame iOS SDK 多聚合平台可扩展架构改造项目。
当前分支: feat/tb_adapter
工程路径: /Users/khj/Documents/code/97_ad/ios/flame_ios_sdk

Phase 0（文档修订）、Phase 1（mediation 基础骨架）、Phase 1.1（Router Provider weak→strong 补丁）、Phase 2（pt=tk 初始化主链路）、Phase 2.1（文档清残 + 代码自检）、Phase 3A（Reward 广告创建链路解耦）、Phase 3A.1（编译验证，BUILD SUCCEEDED）均已完成。

请按照 05_implementation_plan.md 中的 Phase 3B 开始实施：
补齐 Splash / Interstitial / Banner / Native 的广告创建链路解耦。

红线：
- FlameRewardAdImpl 不再 import AtRewardAdapter
- FlameRewardAdImpl 不再 alloc AtRewardAdapter
- 不在 FlameRewardAdImpl 中写 tk/tb/xxx 平台判断
- AtRewardAdapter 不直接实现对外 FlameRewardAd 协议，而是实现内部 FlameRewardAdapterProtocol
- FlameRewardAdImpl 仍然是对外广告对象
- 不修改 Splash / Interstitial / Banner / Native
- 不接入 ToBid
- mediation 内部类不暴露到 flame_sdk_ios.h
```

## 按 Phase 启动的 Prompt

### Phase 1: mediation 基础骨架（不接主链路）

```
请阅读：
- doc/flame_mediation/tobid_doc/07_claude_compact_context.md
- doc/flame_mediation/tobid_doc/02_multi_mediation_architecture.md（一、二、四节）
- doc/flame_mediation/tobid_doc/05_implementation_plan.md（Phase 1 部分）

实施 Phase 1：创建 mediation/ 目录下的核心架构文件，但不接入主链路。
需要：
1. 新增 mediation/FlameMediationProvider.h（协议定义）
2. 新增 mediation/FlameMediationRegistry.h/.m（注册表，key 为 NSString platformCode）
3. 新增 mediation/FlameMediationRouter.h/.m（路由）

红线：
- 不修改任何已有源码
- 不修改 FlameErrorCode.h/.m
- 不修改 FlameSdk.m
- 不修改 FlameConfigManager
- 不修改 FlameAdapterManager
- 不修改任何 Impl
- 不注册任何 Provider
- 不接入 ToBid
- mediation 类不导入 flame_sdk_ios.h
- 现有 TK 功能完全不受影响

验收标准：编译通过，新增类可独立实例化，TK 回归测试通过。
```

### Phase 2: pt=tk 初始化主链路

```
请阅读：
- doc/flame_mediation/tobid_doc/07_claude_compact_context.md
- doc/flame_mediation/tobid_doc/02_multi_mediation_architecture.md（四节）
- doc/flame_mediation/tobid_doc/05_implementation_plan.md（Phase 2 部分）

Phase 2：只接入 pt=tk 初始化主链路。

允许：
- 新增 mediation/tk/FlameTKProvider.h/.m
- FlameTKProvider 内部复用 FlameAdapterManager 初始化 TopOn
- 修改 FlameSdk.m，在初始化拿到 FlameAppEntity 后读取 pt
- FlameSdk 根据 pt 从 Registry 获取 Provider
- FlameSdk 激活 Router
- FlameSdk 调用当前 Provider 初始化
- 新增 FlameErrorCode 14003 表示不支持的聚合平台（14002 已被 INVALID_PARAM 占用）
- 注册 TKProvider 到统一注册入口

禁止：
- 不修改 FlameConfigManager 触发 Router
- 不新增 cv/cachedAt
- 不做缓存策略重构
- 不修改广告创建链路
- 不修改 Flame*AdImpl
- 不修改 adapter/tk/
- 不接入 ToBid

红线：
- 不改变 TK 现有行为
- 不修改 At*Adapter
- 不在 Phase 2 改广告创建链路（广告创建解耦在 Phase 3）
- Provider 注册在 registerAllProviders 统一入口，不在 create*Ad 中
- mediation 类不导入 flame_sdk_ios.h
- FlameConfigManager 继续只负责配置请求、解析、缓存、返回 FlameAppEntity
- Provider 选择和 Router 激活由 FlameSdk 初始化链路在拿到 FlameAppEntity 后处理

验收标准：pt=tk 时 SDK 通过 Registry → Router → TKProvider → FlameAdapterManager 初始化，
未知 pt 时返回 14003 错误，
TK 全部广告类型仍走原有创建路径（Phase 3 才解耦）。
```

### Phase 3A: Reward 广告创建链路解耦（先只做激励视频）

```
请阅读：
- doc/flame_mediation/tobid_doc/07_claude_compact_context.md
- doc/flame_mediation/tobid_doc/02_multi_mediation_architecture.md（五、六节）
- doc/flame_mediation/tobid_doc/05_implementation_plan.md（Phase 3A 部分）

实施 Phase 3A：只解耦 Reward 广告创建链路。
需要：
1. 新增 FlameRewardAdapterProtocol 内部协议
2. AtRewardAdapter 实现 FlameRewardAdapterProtocol
3. FlameMediationProvider 协议新增 createRewardAdapter: 方法
4. FlameTKProvider 实现 createRewardAdapter:，内部调用 FlameAdapterManager
5. FlameRewardAdImpl 内部持有 id<FlameRewardAdapterProtocol>，不再 alloc AtRewardAdapter
6. FlameSdk.createRewardAdWithVC 通过 Router → Provider 获取 Reward Adapter

允许：
- 新增 FlameRewardAdapterProtocol
- AtRewardAdapter 实现 FlameRewardAdapterProtocol
- FlameTKProvider 增加 createRewardAdapter 方法
- FlameRewardAdImpl 内部持有 id<FlameRewardAdapterProtocol>
- FlameSdk.createRewardAdWithVC 通过 Router → Provider 获取 Reward Adapter

禁止：
- 不修改 Splash / Interstitial / Banner / Native
- 不接入 ToBid
- 不新增 TBProvider / TbRewardAdapter
- 不改 podspec / Podfile / Info.plist
- 不让 AtRewardAdapter 实现对外 FlameRewardAd 协议
- 不在 FlameRewardAdImpl 中写 tk/tb 判断

验收标准：
- TK Reward 通过 Router → TKProvider → AtRewardAdapter 正常工作
- Reward 广告加载/展示/回调/释放与改造前完全一致
- 回归测试通过
```

### Phase 3B: 补齐其他 TK 广告类型解耦

```
请阅读：
- doc/flame_mediation/tobid_doc/07_claude_compact_context.md
- doc/flame_mediation/tobid_doc/02_multi_mediation_architecture.md（五、六节）
- doc/flame_mediation/tobid_doc/05_implementation_plan.md（Phase 3B 部分）

前置条件：Phase 3A 验收通过

实施 Phase 3B：补齐 Splash / Interstitial / Banner / Native 的广告创建链路解耦。
需要：
1. 新增 FlameSplashAdapterProtocol / FlameInterstitialAdapterProtocol / FlameBannerAdapterProtocol / FlameNativeAdapterProtocol
2. 对应 At*Adapter 实现内部协议
3. FlameMediationProvider 协议新增 create*Adapter 方法
4. FlameTKProvider 实现所有 create*Adapter 方法
5. 所有 Flame*AdImpl 内部持有 id<FlameXxxAdapterProtocol>
6. FlameSdk.create*Ad 通过 Router → Provider 获取适配器

红线：
- 所有 Impl 不再 import At*Adapter
- 所有 Impl 不再 alloc At*Adapter
- 不在 Impl 中写 tk/tb/xxx 平台判断
- 平台 Adapter 不直接实现对外 Flame 协议
- 不接入 ToBid
- Flame*AdImpl 仍然是对外广告对象

验收标准：
- TK 全部 5 种广告类型通过 Router → TKProvider → At*Adapter 正常工作
- 回归测试全部通过
```

### Phase 4: 缓存策略调整

```
请阅读：
- doc/flame_mediation/tobid_doc/07_claude_compact_context.md
- doc/flame_mediation/tobid_doc/03_backend_config_and_cache.md（三节）
- doc/flame_mediation/tobid_doc/05_implementation_plan.md（Phase 4 部分）

实施 Phase 4：缓存策略改为网络优先，失败 fallback 完整缓存。
需要：
1. 修改 FlameConfigLocalStorage 新增 cv/cachedAt 缓存键读写
2. 修改 FlameConfigManager 改为网络优先策略
3. 修改 FlameAppEntity fromJson 解析 cv

红线：
- 不采用 24 小时 TTL 作为主刷新策略
- 缓存完整性必须包含 pt + aId + aKey + pMap
- cv/cachedAt 为可选字段，不强依赖

验收标准：
- 每次冷启动优先请求后台
- 网络成功：使用最新配置，更新缓存
- 网络失败 + 缓存完整：fallback 使用缓存
- 网络失败 + 缓存不完整：callback.fail
```

### Phase 5: TB Provider + Reward（先只做激励视频）

```
请阅读：
- doc/flame_mediation/tobid_doc/07_claude_compact_context.md
- doc/flame_mediation/tobid_doc/04_tobid_integration_notes.md
- doc/flame_mediation/tobid_doc/05_implementation_plan.md（Phase 5 部分）
- doc/tobid_doc/sdk集成下载说明/ (ToBid 官方集成文档)
- doc/tobid_doc/ToBidDemo官方/ (ToBid 官方 Demo)

实施 Phase 5：先只打通激励视频，验证 TB 完整链路。
需要：
1. 新增 mediation/tb/FlameTBProvider.h/.m
2. 新增 adapter/tb/TbRewardAdapter.h/.m
3. 修改 FlameSdk.m registerAllProviders 注册 TBProvider
4. 修改 flame_sdk_ios.podspec 新增 ToBid SDK 依赖

红线：
- 先只做 Reward，不做其他广告类型
- TB 代码放在 adapter/tb/，不混入 adapter/tk/
- mediation 类不导入 flame_sdk_ios.h

验收标准：
- 后台返回 pt: "tb" 时 SDK 初始化 ToBid SDK
- Reward 广告正常加载/展示/回调/释放
- TB 回调正确映射到 FlameRewardListener
- 错误码正确映射
```

### Phase 6: TB 其他广告类型

```
请阅读：
- doc/flame_mediation/tobid_doc/07_claude_compact_context.md
- doc/flame_mediation/tobid_doc/04_tobid_integration_notes.md
- doc/flame_mediation/tobid_doc/05_implementation_plan.md（Phase 6 部分）

实施 Phase 6：补齐 ToBid 插屏、开屏、Banner、原生。
实现顺序：TbInterstitialAdapter → TbSplashAdapter → TbBannerAdapter → TbNativeAdapter

每个适配器需要：
1. 实现对应内部适配器协议（FlameRewardAdapterProtocol 等），不直接实现对外 Flame 协议
2. 内部调用 ToBid SDK API
3. 将 ToBid 回调映射到 Flame Listener
4. 错误码映射到 Flame 14xxx 体系

红线：
- TB 代码放在 adapter/tb/，不混入 adapter/tk/
```

### Phase 7: 完整回归和依赖验证

```
请阅读：
- doc/flame_mediation/tobid_doc/07_claude_compact_context.md
- doc/flame_mediation/tobid_doc/06_risk_and_rollback.md
- doc/flame_mediation/tobid_doc/05_implementation_plan.md（Phase 7 部分）

实施 Phase 7：全面测试和依赖验证。

测试项：
- TK 回归：pt=tk 时全流程与改造前完全一致
- TB 全类型：pt=tb 时 5 种广告类型全流程
- 缓存：冷启动/热启动/离线/清除
- 未知平台：返回不存在 pt 时回调 14003
- 依赖冲突：TK + TB Pod 同时引入
- SKAdNetworkItems、Info.plist、ATT/IDFA 验证
```
