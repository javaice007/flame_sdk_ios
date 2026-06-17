# 05 - 分阶段实施计划与文件清单

## 一、总体原则

- **对外 API 零变更** — 接入方无感知
- **TK 现有功能零回归** — 改造不破坏已接入 TK 的 App
- **Impl 层零平台判断** — FlameRewardAdImpl 等不写 if-else
- **每个阶段可独立验证** — 阶段间有清晰的验收标准

## 二、文件新增清单

### 2.1 新增文件（共 18 个）

#### mediation/ — 聚合平台路由层（核心架构）

| 文件 | 职责 |
|------|------|
| `flame_sdk_ios/mediation/FlameMediationProvider.h` | Provider 协议定义 |
| `flame_sdk_ios/mediation/FlameMediationRegistry.h` | Registry 头文件 |
| `flame_sdk_ios/mediation/FlameMediationRegistry.m` | Registry 实现 |
| `flame_sdk_ios/mediation/FlameMediationRouter.h` | Router 头文件 |
| `flame_sdk_ios/mediation/FlameMediationRouter.m` | Router 实现 |

#### mediation/tk/ — TK Provider 壳（轻量封装）

| 文件 | 职责 |
|------|------|
| `flame_sdk_ios/mediation/tk/FlameTKProvider.h` | TK Provider 头文件 |
| `flame_sdk_ios/mediation/tk/FlameTKProvider.m` | TK Provider 实现（包装 FlameAdapterManager） |

#### mediation/tb/ — TB Provider 壳

| 文件 | 职责 |
|------|------|
| `flame_sdk_ios/mediation/tb/FlameTBProvider.h` | TB Provider 头文件 |
| `flame_sdk_ios/mediation/tb/FlameTBProvider.m` | TB Provider 实现（初始化 ToBid SDK） |

#### adapter/tb/ — TB 适配器

| 文件 | 职责 |
|------|------|
| `flame_sdk_ios/adapter/tb/TbSplashAdapter.h/.m` | TB 开屏广告适配器 |
| `flame_sdk_ios/adapter/tb/TbRewardAdapter.h/.m` | TB 激励视频适配器 |
| `flame_sdk_ios/adapter/tb/TbInterstitialAdapter.h/.m` | TB 插屏广告适配器 |
| `flame_sdk_ios/adapter/tb/TbBannerAdapter.h/.m` | TB 横幅广告适配器 |
| `flame_sdk_ios/adapter/tb/TbNativeAdapter.h/.m` | TB 原生广告适配器 |
| `flame_sdk_ios/adapter/tb/TbNativeSelfRenderView.h/.m` | TB 原生自渲染视图（可选） |

## 三、文件修改清单

### 3.1 需修改的文件（共 12 个）

#### core/ — 核心层

| 文件 | 修改内容 | 改动量 |
|------|----------|--------|
| `core/FlameSdk.m` | init 链路：添加 Provider 注册 + Router 激活；`create*Ad` 方法改为通过 Router 创建适配器；Impl init 签名变更 | 中 |
| `core/FlameAppEntity.h/.m` | Phase 2 不修改；Phase 4 如后台支持 configVersion / cachedAt，再考虑新增字段 | 小 |
| `core/FlameConfigManager.h/.m` | Phase 2 已新增 `getPt` 只读访问器（与 getAId/getAKey 对称），修复缓存命中路径未读取 pt 的 bug；职责边界不变：只负责配置请求、解析、缓存、返回 FlameAppEntity，不触发 Router；Phase 4 才处理网络优先缓存策略 | 中 |
| `core/FlameErrorCode.h/.m` | 新增错误码: 14003=不支持的聚合平台（14002 已被 INVALID_PARAM 占用） | 小 |

#### utils/ — 工具层

| 文件 | 修改内容 | 改动量 |
|------|----------|--------|
| `utils/FlameConfigLocalStorage.h/.m` | 新增 `cv` 和 `cachedAt` 缓存键读写 | 小 |

#### ads/ — Impl 层

| 文件 | 修改内容 | 改动量 |
|------|----------|--------|
| `ads/splash/FlameSplashAdImpl.h/.m` | init 签名改为接收 `id<FlameSplashAdapterProtocol>` 内部适配器，而非自行创建 | 小 |
| `ads/reward/FlameRewardAdImpl.h/.m` | 同上 | 小 |
| `ads/interstitial/FlameInterstitialAdImpl.h/.m` | 同上 | 小 |
| `ads/banner/FlameBannerAdImpl.h/.m` | 同上 | 小 |
| `ads/nativate/FlameNativeAdImpl.h/.m` | 同上 | 小 |

#### 构建/依赖

| 文件 | 修改内容 | 改动量 |
|------|----------|--------|
| `flame_sdk_ios.podspec` | 新增 ToBid SDK 依赖 | 小 |

#### 伞头文件

| 文件 | 修改内容 | 改动量 |
|------|----------|--------|
| `flame_sdk_ios.h` | **不修改** — mediation 内部类不暴露到伞头文件 | 无 |

> **注意**：`FlameMediationProvider`、`FlameMediationRegistry`、`FlameMediationRouter`、`FlameTKProvider`、`FlameTBProvider` 均属于 SDK 内部实现，**不导入 `flame_sdk_ios.h`**，不对接入方 App 公开。

## 四、不应修改的文件

| 文件 | 原因 |
|------|------|
| `adapter/tk/AtSplashAdapter.h/.m` | TK 适配器完全复用，不改 |
| `adapter/tk/AtRewardAdapter.h/.m` | 同上 |
| `adapter/tk/AtInterstitialAdapter.h/.m` | 同上 |
| `adapter/tk/AtBannerAdapter.h/.m` | 同上 |
| `adapter/tk/AtNativeAdapter.h/.m` | 同上 |
| `adapter/tk/AtNativeSelfRenderView.h/.m` | 同上 |
| `adapter/FlameAdapterManager.h/.m` | 保留现有 API，TKProvider 内部调用，不改（或仅极小改动） |
| `ads/*/FlameXxxAd.h` | 协议定义不变 |
| `core/FlameCallback.h` | 不变 |
| `utils/FlameNetworkUtils.h/.m` | 不变 |
| `utils/FlameAesCryptoUtils.h/.m` | 不变 |
| `utils/FlameMd5SignatureUtils.h/.m` | 不变 |
| `utils/FlameLogger.h/.m` | 不变 |

## 五、分阶段实施计划（保守策略）

> 每个阶段可独立验证，阶段间有清晰的验收标准。确保每步都不破坏 TK 现有行为。

### Phase 0：文档修订（当前阶段）

**目标**：修订 `doc/flame_mediation/tobid_doc/` 下所有 Markdown 文档，确保后续实施方向准确

**修改文件**：仅修改 `doc/flame_mediation/tobid_doc/*.md`

**红线**：
- 不创建任何 `.h` / `.m` 源码文件
- 不修改 `flame_sdk_ios/` 下任何源码
- 不修改 `Podfile` / `podspec` / `Info.plist`
- 不接入 ToBid
- 不新增 mediation 代码目录

**验收标准**：
- 所有文档路径统一为 `doc/flame_mediation/tobid_doc/`
- mediation 内部类不暴露到伞头文件
- 平台标识使用 NSString code，不使用 NS_ENUM
- Provider 注册在统一入口
- 缓存策略为网络优先，失败 fallback 缓存
- 当前阶段不实现广告位级平台路由

---

### Phase 1：新增 mediation 基础骨架（不接入主链路）

**目标**：只创建 Provider + Registry + Router 基础类文件，**不修改任何已有源码**

**新增文件**：
- `mediation/FlameMediationProvider.h` — Provider 协议定义
- `mediation/FlameMediationRegistry.h/.m` — Provider 注册表
- `mediation/FlameMediationRouter.h/.m` — 广告创建路由

**修改文件**：无（不修改任何已有源码）

**红线**：
- **不修改任何已有源码文件**
- **不修改 `FlameErrorCode.h/.m`**
- **不修改 `FlameSdk.m`**
- **不修改 `FlameConfigManager`**
- **不修改 `FlameAdapterManager`**
- **不修改任何 Impl**
- **不注册任何 Provider 到 Registry**
- **不接入 ToBid**
- 现有 TK 功能完全不受影响

> 注：14003（不支持的聚合平台）错误码在 Phase 2 接入主链路时已处理（原计划 14002，但已被 INVALID_PARAM 占用）。

**验收标准**：
- 编译通过，无 warning
- 新增类可独立实例化和基本测试
- TK 现有功能完全正常（回归测试通过）

**状态**：✅ 已完成

**预计工期**：1-2 天

---

### Phase 1.1：骨架补丁（Router Provider 持有方式修正）

**目标**：修正 Router 对当前 Provider 的持有方式，从 weak 改为 strong

**修改文件**：
- `mediation/FlameMediationRouter.h` — 注释更新，明确 strong 持有语义
- `mediation/FlameMediationRouter.m` — `currentProviderInternal` 从 `weak` 改为 `strong`

**红线**：
- 只修改 mediation 骨架文件
- 不修改任何主链路代码
- 不注册任何 Provider
- 不接入 ToBid

**状态**：✅ 已完成

---

### Phase 2：接入 pt=tk 初始化主链路

**目标**：让 TK 初始化通过新架构跑通，确保行为与旧版本完全一致

**新增文件**：
- `mediation/tk/FlameTKProvider.h/.m` — TK Provider 壳

**修改文件**：
- `mediation/FlameMediationProvider.h` — 新增 `initializeWithAppId:appKey:callback:` 方法
- `core/FlameSdk.m` — 添加 `registerAllProvidersIfNeeded`，init 链路在拿到 FlameAppEntity 后根据 pt 激活 Router
- `core/FlameErrorCode.h/.m` — 新增 14003（不支持的聚合平台，14002 已被 INVALID_PARAM 占用）
- `core/FlameConfigManager.h/.m` — 新增 `getPt` 访问器，修复缓存命中路径未读取 pt 的 bug

**红线**：
- 不改变 TK 现有行为
- 不修改 At*Adapter
- 不修改 FlameAdapterManager 的核心逻辑（TKProvider 内部调用即可）
- **不在 Phase 2 改广告创建链路**（广告创建解耦在 Phase 3）
- **不新增 cv/cachedAt**（cv/cachedAt 在 Phase 4 缓存策略阶段处理）
- **不做缓存策略重构**（Phase 4 职责）
- **不由 FlameConfigManager 触发 Router**（FlameConfigManager 继续只负责配置请求、解析、缓存、返回 FlameAppEntity；Phase 2 允许新增 `getPt` 只读访问器，与 `getAId`/`getAKey` 对称，不包含任何 Router/Provider/初始化逻辑；Provider 选择和 Router 激活由 FlameSdk 初始化链路在拿到 FlameAppEntity 后处理）

**验收标准**：
- `pt=tk` 时 SDK 通过 Registry → Router → TKProvider → FlameAdapterManager 初始化
- 未知 `pt` 时返回 14003 错误
- pt 为空时兼容默认 tk 并记录日志
- TK 全部广告类型**仍走原有创建路径**（Phase 3 才解耦）
- 行为与改造前完全一致（回归测试通过）

**状态**：✅ 已完成

**预计工期**：2-3 天

---

### Phase 3A：Reward 广告创建链路解耦（先只做激励视频）

**目标**：只解耦激励视频（Reward），验证 Impl 持有内部适配器协议的完整链路

**新增文件**：
- `mediation/FlameRewardAdapterProtocol.h` — 内部激励视频适配器协议（load / loadWithUserId:userCustomData: / isReady / isLoading / show / destroy）

**修改文件**：
- `mediation/FlameMediationProvider.h` — 新增 `createRewardAdapterWithViewController:placementId:listener:` 方法
- `mediation/tk/FlameTKProvider.m` — 实现 `createRewardAdapterWithViewController:placementId:listener:`，内部直接创建 AtRewardAdapter
- `adapter/tk/AtRewardAdapter.h` — 协议从 `<FlameRewardAd, ATRewardedVideoDelegate>` 改为 `<FlameRewardAdapterProtocol, ATRewardedVideoDelegate>`
- `ads/reward/FlameRewardAdImpl.h/.m` — adapter 属性改为 `id<FlameRewardAdapterProtocol>`，init 接收预创建的适配器，不再 `alloc AtRewardAdapter`
- `core/FlameSdk.m` — `createRewardAdWithVC` 改为通过 Router → Provider → createRewardAdapter 创建适配器

**红线**：
- **不修改 Splash / Interstitial / Banner / Native**
- 不接入 ToBid
- 不新增 TBProvider / TbRewardAdapter
- 不修改 `podspec` / `Podfile` / `Info.plist`
- 不让 `AtRewardAdapter` 实现对外 `FlameRewardAd` 协议
- 不在 `FlameRewardAdImpl` 中写 tk/tb 判断
- `FlameRewardAdImpl` 仍然是对外广告对象

**验收标准**：
- TK Reward 通过 Router → TKProvider → AtRewardAdapter 正常工作
- Reward 广告加载/展示/回调/释放与改造前完全一致
- 回归测试通过

**状态**：✅ 已完成（含 Phase 3A.1 编译验证 BUILD SUCCEEDED）

**预计工期**：1-2 天

---

### Phase 3B：补齐其他 TK 广告类型解耦

**前置条件**：Phase 3A 验收通过

**目标**：补齐 Splash / Interstitial / Banner / Native 的广告创建链路解耦

**修改文件**：
- `mediation/FlameMediationProvider.h` — 新增 `createSplashAdapter:` / `createInterstitialAdapter:` / `createBannerAdapter:` / `createNativeAdapter:` 方法
- `mediation/tk/FlameTKProvider.m` — 实现上述方法，内部调用 FlameAdapterManager
- `ads/splash/FlameSplashAdImpl.h/.m` — 内部持有 `id<FlameSplashAdapterProtocol>`
- `ads/interstitial/FlameInterstitialAdImpl.h/.m` — 内部持有 `id<FlameInterstitialAdapterProtocol>`
- `ads/banner/FlameBannerAdImpl.h/.m` — 内部持有 `id<FlameBannerAdapterProtocol>`
- `ads/nativate/FlameNativeAdImpl.h/.m` — 内部持有 `id<FlameNativeAdapterProtocol>`
- `core/FlameSdk.m` — 对应 `create*Ad` 方法改为通过 Router → Provider 创建适配器

**红线**：
- 所有 Impl 不再 import `At*Adapter`
- 所有 Impl 不再 `alloc At*Adapter`
- 不在 Impl 中写 tk/tb/xxx 平台判断
- 平台 Adapter 不直接实现对外 Flame 协议
- 不接入 ToBid
- 不修改 `podspec` / `Podfile` / `Info.plist`

**验收标准**：
- TK 全部 5 种广告类型通过 Router → TKProvider → At*Adapter 正常工作
- 回归测试全部通过

**状态**：✅ 已完成

**预计工期**：1-2 天

---

### Phase 4：缓存策略调整

**目标**：改为网络优先、失败 fallback 缓存

**修改文件**：
- `utils/FlameConfigLocalStorage.h/.m` — 新增 `cv`、`cachedAt` 缓存键读写
- `core/FlameConfigManager.m` — 改为网络优先策略
- `core/FlameAppEntity.m` — `fromJson` 解析 cv

**红线**：
- 不采用 24 小时 TTL 作为主刷新策略
- 缓存完整性必须包含 pt + aId + aKey + pMap

**验收标准**：
- 每次冷启动优先请求后台
- 网络成功：使用最新配置，更新缓存
- 网络失败 + 缓存完整：fallback 使用缓存
- 网络失败 + 缓存不完整：callback.fail
- `FlameSdk.clear()` 正常清除所有缓存

**预计工期**：1-2 天

---

### Phase 5：ToBid Provider + Reward

**目标**：先只打通激励视频，验证 TB 完整链路

**新增文件**：
- `mediation/tb/FlameTBProvider.h/.m`
- `adapter/tb/TbRewardAdapter.h/.m`

**修改文件**：
- `core/FlameSdk.m` — `registerAllProviders` 中注册 TBProvider
- `flame_sdk_ios.podspec` — 新增 ToBid SDK 依赖

**红线**：
- **先只做 Reward，不做其他广告类型**
- TB 代码放在 `adapter/tb/`，不混入 `adapter/tk/`

**验收标准**：
- 后台返回 `pt: "tb"` 时，SDK 初始化 ToBid SDK
- Reward 广告正常加载/展示/回调/释放
- TB 回调正确映射到 FlameRewardListener
- 错误码正确映射

**预计工期**：2-3 天

---

### Phase 6：补齐 ToBid 其他广告类型

**目标**：补齐插屏、开屏、Banner、原生

**新增文件**：
- `adapter/tb/TbSplashAdapter.h/.m`
- `adapter/tb/TbInterstitialAdapter.h/.m`
- `adapter/tb/TbBannerAdapter.h/.m`
- `adapter/tb/TbNativeAdapter.h/.m`
- `adapter/tb/TbNativeSelfRenderView.h/.m`（可选）

**实现顺序**（按复杂度递增）：
1. `TbInterstitialAdapter` — 逻辑与激励视频类似
2. `TbSplashAdapter` — 需处理超时
3. `TbBannerAdapter` — 含模板+自渲染两种模式
4. `TbNativeAdapter` — 最复杂，含自渲染视图

**红线**：
- TB 代码放在 `adapter/tb/`，不混入 `adapter/tk/`

**验收标准**：
- 后台返回 `pt: "tb"` 时，所有 5 种广告类型正常工作
- TB 回调完整映射到各 Flame Listener

**预计工期**：3-5 天

---

### Phase 7：完整回归和依赖验证

**目标**：全面测试，确保 TK/TB 双平台功能正常，依赖无冲突

| 测试项 | 说明 |
|--------|------|
| TK 回归测试 | 后台返回 `pt: "tk"` 时，全流程与改造前完全一致 |
| TB 全类型测试 | 后台返回 `pt: "tb"` 时，5 种广告类型全流程 |
| 缓存测试 | 冷启动/热启动/离线/清除 |
| 未知平台测试 | 后台返回不存在的 pt 值时，错误回调 14003 |
| 初始化时序测试 | callback.success 前创建广告被拒绝 |
| 重复初始化测试 | 连续多次调用 init 的行为 |
| 依赖冲突测试 | TK + TB Pod 同时引入，编译链接正常 |
| 内存测试 | 广告创建/销毁循环，无泄漏 |
| SKAdNetworkItems | TB Pod 引入后检查归因配置 |
| Info.plist | 检查 TB 所需配置项 |
| ATT / IDFA | 验证 TB 的 IDFA 采集依赖 |

**预计工期**：2-3 天

---

### 总预计工期

| Phase | 内容 | 工期 |
|-------|------|------|
| 0 | 文档修订 | ✅ 已完成 |
| 1 | mediation 基础骨架（不接主链路） | ✅ 已完成 |
| 1.1 | 骨架补丁（Router Provider weak→strong） | ✅ 已完成 |
| 1.2 | 文档清残（删除 cv/cachedAt 旧描述，统一 Phase 2 边界） | ✅ 已完成 |
| 2 | pt=tk 初始化主链路接入 | ✅ 已完成 |
| 2.1 | 文档清残 + 代码自检（14003 统一、Phase 3 拆分 3A/3B） | ✅ 已完成 |
| 3A | Reward 广告创建链路解耦（先只做激励视频） | ✅ 已完成 |
| 3A.1 | 编译验证与回归确认（BUILD SUCCEEDED） | ✅ 已完成 |
| 3B | 补齐 Splash/Interstitial/Banner/Native 解耦 | ✅ 已完成 |
| 4 | 缓存策略调整 | ✅ 已完成 |
| 4.1 | AtNativeSelfRenderView 自渲染链路补查 | ✅ 已完成 |
| 5 | TB Provider + Reward | ✅ 已完成 |
| 6 | TB 其他广告类型 | 3-5 天 |
| 7 | 完整回归和依赖验证 | 2-3 天 |
| **合计**（Phase 3A-7） | | **11-19 天** |

> Phase 3A-3B 串行（3B 依赖 3A 验收），Phase 4 可与 Phase 3A/3B 并行，Phase 5-6 串行。
