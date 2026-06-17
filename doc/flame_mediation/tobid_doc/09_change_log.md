# 09 - 变更日志

## 2026-06-12 — Phase 5A.5 单包全量方案（移除 subspec + #ifdef HAS_TOBID）

### 背景

Phase 5A.4 的双 xcframework + subspec 方案虽然解决了二进制分发问题，但增加了产物管理复杂度（两份 xcframework、subspec 切换逻辑）。产品目标简化为：**`pod 'flame_sdk_ios'` 一行代码交付所有能力**（Core + TK + TB + 全部 adapter + 全部依赖），后台通过 `pt=tk/tb` 控制运行时 Provider 切换。

### 方案选择

| 方案 | 产物数 | 接入方式 | HAS_TOBID | 选择 |
|------|--------|----------|-----------|------|
| Phase 5A.4: 双 xcframework + subspec | 2 | `pod 'flame_sdk_ios/ToBid'` | 保留 | ❌ 过于复杂 |
| **Phase 5A.5: 单包全量** | **1** | **`pod 'flame_sdk_ios'`** | **完全移除** | **✅ 采用** |

### 修改文件

| 文件 | 变更 |
|------|------|
| `flame_sdk_ios.podspec` | 移除 Core/ToBid subspec 结构，恢复 `s.vendored_frameworks = '**/flame_sdk_ios.xcframework'`；恢复根级 `s.dependency 'ToBid-iOS-RC', '5.5.6'` |
| `xcFramework_build.sh` | 移除 ToBid 第二组 archive（`GCC_PREPROCESSOR_DEFINITIONS='HAS_TOBID=1'`）；恢复单次真机+模拟器 archive → 合并单一 xcframework |
| `FlameSdk.m` | 移除 `#ifdef HAS_TOBID`，TBProvider 注册无条件执行 |
| `FlameTBProvider.m` | 移除所有 `#ifdef HAS_TOBID` / `#else` / `#endif`，WindMill API 调用无条件执行 |
| `TbRewardAdapter.h` | 移除 `#ifdef HAS_TOBID`，`<WindMillRewardVideoAdDelegate>` 协议遵循和 `rewardVideoAd` 属性无条件声明 |
| `TbRewardAdapter.m` | 移除所有 `#ifdef HAS_TOBID`，所有 WindMill API 调用和 13 个 delegate 方法无条件编译 |
| `Podfile` | 移除 `post_install` 中的 `GCC_PREPROCESSOR_DEFINITIONS` HAS_TOBID=1 设置（pod target + aggregate target 均移除） |

### 编译验证

| # | 验证项 | 结果 |
|---|--------|------|
| 一 | Podfile `pod install`（基本依赖：AnyThinkiOS + OpenSSL + ToBid-iOS-RC） | ✅ 成功 |
| 二 | SDK 编译（无 HAS_TOBID 宏，ToBid 源码直接参与编译） | ✅ BUILD SUCCEEDED |
| 三 | 0 errors | ✅ |
| 四 | 0 新增 warnings | ✅ |

### 依赖重叠检查

| # | 检查项 | 结果 |
|---|--------|------|
| 一 | WindFoundation.xcframework 版本（SigmobAd-iOS vs ToBid-iOS-RC） | 均为 v180，Bundle ID `com.sigmob.WindFoundation` 完全一致 |
| 二 | WindSDK.xcframework 版本（SigmobAd-iOS vs ToBid-iOS-RC） | 均为 v1.0，Bundle ID `com.sigmob.WindSDK` 完全一致 |
| 三 | WindMillSDK | 仅存在于 ToBid-iOS-RC，SigmobAd-iOS 不包含 |
| 四 | pod install 冲突 | CocoaPods 输出同名 framework 警告，但未产生硬错误 |
| 五 | 风险评估 | 当前未出现 pod install 硬错误，但存在同名 framework 覆盖风险，需要通过干净环境 pod install、最终 App 链接、真机运行验证后确认可接受 |

### 未改动（红线验证）

| # | 红线 | 状态 |
|---|------|------|
| 一 | 不进入 Phase 6（TB Splash/Interstitial/Banner/Native） | ✅ 未进入 |
| 二 | 不修改 TK Adapter（adapter/tk/ 全部 .h/.m 零改动） | ✅ 零改动 |
| 三 | 不修改 FlameRewardAdImpl | ✅ 零改动 |
| 四 | 不修改 FlameConfigManager | ✅ 零改动 |
| 五 | 不修改 flame_sdk_ios.h | ✅ 零改动 |
| 六 | 不修改 SDK 对外 API（FlameSdk.create*Ad 签名不变） | ✅ 零改动 |
| 七 | 不修改 FlameAdapterManager | ✅ 零改动 |
| 八 | 不新增 Phase 6 代码 | ✅ 未新增 |

### 待完成验证（需真机/后台配合）

| # | 验证项 | 阻塞原因 |
|---|--------|----------|
| 一 | pt=tk Reward 回归测试 | 需真机运行 |
| 二 | pt=tb Reward 完整链路 | 需后台配置 pt=tb + ToBid AppId + PlacementId |
| 三 | 干净环境 pod install（全量依赖） | 网络问题阻塞（Podfile.lock 未能完整生成） |
| 四 | xcframework 完整构建 | 需在完整依赖环境执行 |
| 五 | 最终 App 链接验证 | 需集成到接入方 App |
| 六 | 同名 framework 真机运行验证 | 需真机运行确认 WindFoundation 覆盖不导致崩溃 |

---

## 2026-06-11 — Phase 5A.4 ToBid 可选 Adapter 分发方案落地（已被 Phase 5A.5 替代）

> ⚠️ 本方案已被 Phase 5A.5 单包全量方案替代。双 xcframework + subspec 不再使用。

### 背景

Phase 5A.3 的 `#ifdef HAS_TOBID` 条件编译仅对源码编译有效。SDK 以预编译二进制 `flame_sdk_ios.xcframework` 分发（`s.vendored_frameworks`），下游 App 侧定义 `HAS_TOBID=1` 无法改变已编译 framework 的行为。需要一个完整的产品分发策略。

### 方案选择

方案 C+A（双 framework 产物 + subspec 接入糖衣），评估了 4 种方案：

| 方案 | 可行性 | 选择 |
|------|--------|------|
| A: subspec | subspec 可控制 dependency，但无法控制源码编译 | 部分采用（接入糖衣） |
| B: 独立 Adapter Pod | 需暴露 Registry 内部类，侵入性大 | ❌ |
| C: 双 framework 产物 | 最小侵入，适配二进制分发 | ✅ |
| D: HAS_TOBID 宏 | 仅适用于源码编译，二进制消费者无效 | ❌ 作为最终方案 |

### 修改文件

| 文件 | 变更 |
|------|------|
| `xcFramework_build.sh` | 增加第二组 archive（`GCC_PREPROCESSOR_DEFINITIONS='HAS_TOBID=1'`），产出 `flame_sdk_ios_tobid.xcframework` |
| `flame_sdk_ios.podspec` | 移除根级 `vendored_frameworks`，新增 `Core` + `ToBid` subspec，`default_subspecs = ['Core']` |
| `04_tobid_integration_notes.md` | §6.1 更新为双 xcframework + subspec 分发策略 |
| `07_claude_compact_context.md` | 更新 ToBid 依赖隔离描述 + Phase 5A.4 状态 |

### 产物

| 产物 | 构建宏 | 内容 |
|------|--------|------|
| `flame_sdk_ios.xcframework` | 无 | Core SDK（pt=tk） |
| `flame_sdk_ios_tobid.xcframework` | `HAS_TOBID=1` | Core + ToBid（pt=tk + pt=tb） |

### 接入方式

```ruby
# 不使用 ToBid（默认）
pod 'flame_sdk_ios'

# 使用 ToBid
pod 'flame_sdk_ios/ToBid'
```

### 未改动

- 源码 `.m/.h` 文件（`#ifdef HAS_TOBID` 已在 Phase 5A.3 完成）
- `Podfile`（本地开发配置不变）
- SDK 对外 API（`flame_sdk_ios.h` 伞头文件不变）
- `FlameMediationRegistry` / Provider 注册入口（不需要暴露）

---

## 2026-06-11 — Phase 5A.3 ToBid 依赖隔离修正

### 背景

Phase 5A 在 `flame_sdk_ios.podspec` 中添加了 `s.dependency 'ToBid-iOS-RC', '5.5.6'`。发现 ToBid-iOS-RC 内含 `WindFoundation.xcframework` / `WindSDK.xcframework`，与现有 `AnyThinkMediationSigmobAdapter` / `SigmobAd-iOS` 中的同名 framework 冲突。

这不是 Demo 侧问题，而是 SDK podspec 依赖策略问题：基础 SDK 不应强制所有接入方拉取 ToBid-iOS-RC。

### 方案选择

| 方案 | 可行性 | 选择 |
|------|--------|------|
| A: 最小修正（仅移除 podspec 依赖） | ❌ TB 源码 `#import <WindMillSDK/WindMillSDK.h>` 会导致编译失败 | 排除 |
| B: subspec（Core + ToBid） | ❌ podspec 使用 `vendored_frameworks`（二进制分发），subspec `source_files` 不适用 | 排除 |
| C: 独立 adapter pod | ✅ 长期可选，但当前阶段过重 | 未来考虑 |
| **D: #ifdef HAS_TOBID 条件编译** | ✅ **选中** — 最小风险，兼容二进制 podspec，本地/远程均适用 | **采用** |

### 修改内容

| 文件 | 变更 |
|------|------|
| `flame_sdk_ios.podspec` | 移除 `s.dependency 'ToBid-iOS-RC', '5.5.6'`，添加注释说明接入方自行添加 |
| `FlameSdk.m` | `#import "FlameTBProvider.h"` 和 TBProvider 注册包裹在 `#ifdef HAS_TOBID` |
| `FlameTBProvider.m` | `#import <WindMillSDK/WindMillSDK.h>`、WindMill 初始化 API、Reward adapter 创建包裹在 `#ifdef HAS_TOBID`；`#else` 分支返回错误回调 |
| `TbRewardAdapter.h` | `<WindMillRewardVideoAdDelegate>` 协议遵循、`rewardVideoAd` 属性包裹在 `#ifdef HAS_TOBID` |
| `TbRewardAdapter.m` | `#import <WindMillSDK/WindMillSDK.h>`、所有 WindMill API 调用和 13 个 delegate 方法包裹在 `#ifdef HAS_TOBID`；`#else` 分支返回错误回调 |
| `Podfile` | `tb_pods` 注释更新；`post_install` 通过 `aggregate_targets.user_project.targets` 为所有 target 设置 `HAS_TOBID=1` |

### 编译验证

| 场景 | 配置 | 结果 |
|------|------|------|
| 场景 1：带 ToBid | Podfile 含 `tb_pods`，post_install 设 `HAS_TOBID=1` | ✅ BUILD SUCCEEDED |
| 场景 2：无 ToBid | Podfile 移除 `tb_pods`，无 `HAS_TOBID` | ✅ BUILD SUCCEEDED |
| SDK 源码 warnings | 0 新增 | ✅ |
| pt=tk Reward | 未修改 TK 代码 | ✅ 不受影响 |

### 接入方使用 ToBid 的步骤

1. Podfile 添加 `pod 'ToBid-iOS-RC', '5.5.6'`
2. Build Settings → Preprocessor Macros 添加 `HAS_TOBID=1`
3. 后台配置 `pt=tb` + ToBid AppId + PlacementId

---

## 2026-06-11 — Phase 5A.1 ToBid Reward 运行前代码审查修复

### 背景

Phase 5A 编译通过但未真机测试。通过读取 ToBid SDK 5.5.6 实际头文件（`WindMillSDK.h`），发现 3 个运行时问题。

### SDK 头文件关键发现

| API | 实际签名 | 影响 |
|-----|---------|------|
| `setupSDKWithAppId:completionHandler:` | `(void (^)(BOOL success, NSError *error))completionHandler` | 有成功/失败回调，应使用 |
| `WindMillRewardInfo` | `.transId`、`.userId`、`.isCompeltedView` | reward 回调可提取真实字段 |
| `WindMillAdRequest` | `.rewardName`(NSString)、`.rewardAmount`(int64_t) | loadWithUserId 可透传 |

### 修复内容

| 文件 | 变更 | 原因 |
|------|------|------|
| `FlameTBProvider.m` | `completionHandler:nil` → 使用真实 completionHandler block | SDK 有失败回调，弃用则丢失 WindMill 初始化失败信号 |
| `TbRewardAdapter.m` | `onAdReward` 从空字符串 → `reward.transId` / `reward.userId` | SDK 头文件确认有真实属性可用 |
| `TbRewardAdapter.m` | 日志补充 `isCompeltedView` / `userId` 信息 | 便于真机调试 |

### 编译验证

- ✅ `xcodebuild BUILD SUCCEEDED`
- ✅ 0 errors
- ✅ 0 SDK 源码新增 warnings

### 真机测试前置条件

1. 后台返回 `pt: "tb"` + `aId`（ToBid AppId）+ `pIds`（ToBid Reward PlacementId）
2. ToBid 后台已配置对应 PlacementId
3. 至少一个 ToBid adapter subspec 已安装（当前仅装了核心 SDK，无广告渠道 adapter，**无法真实填充广告**）

### ⚠️ 已知限制

当前 Podfile / podspec 仅引入 `ToBid-iOS-RC` 核心 SDK，不含任何 adapter subspec（CSJAdapter / GDTAdapter 等）。这意味着：
- 编译通过 ✅
- WindMillRewardVideoAd 可创建 ✅
- `loadAdData` 调用正常 ✅
- 但 **无法从真实广告网络获取广告填充**（无 adapter = 无广告渠道）
- 真正的 Reward 广告展示需要在 Phase 7 添加至少一个 adapter subspec

建议：Phase 7 添加 `ToBid-iOS-RC/CSJAdapter`（穿山甲，国内最大激励视频渠道）后再做完整 Reward 真机测试。

---

## 2026-06-11 — Phase 5 TB Provider + Reward 接入

### 目标

接入 ToBid / WindMill 的 Provider + Reward，验证 pt=tb 完整链路：`FlameSdk.init → Registry → Router → FlameTBProvider → TbRewardAdapter → WindMillRewardVideoAd → FlameRewardListener`。

### ToBid API 确认（来自本地官方 Demo）

| 项目 | 确认结果 |
|------|----------|
| Pod 名称和版本 | `ToBid-iOS-RC 5.5.6`（来自接入代码，Demo_OC 用 5.3.4，Example 用 4.6.0） |
| use_frameworks | 需要（Podfile 中 `use_frameworks!`） |
| 初始化 API | `[WindMillAds setupSDKWithAppId:appId completionHandler:nil]` |
| completionHandler | 官方 Demo 传 nil，无明确失败回调签名，初始化后同步回调 success |
| Reward 类 | `WindMillRewardVideoAd` |
| Reward 请求 | `[WindMillAdRequest request]` → `.placementId` / `.userId` / `.options` |
| Reward 创建 | `[[WindMillRewardVideoAd alloc] initWithRequest:request]` |
| Reward 加载 | `[rewardVideoAd loadAdData]` |
| Reward 展示 | `[rewardVideoAd showAdFromRootViewController:vc options:@{}]` |
| Ready 判断 | `rewardVideoAd.isAdReady` |
| Delegate | `WindMillRewardVideoAdDelegate` |

### Reward 回调映射（已确认方法签名来自 Demo_OC RewardVideoAdListener.m）

| WindMill 回调 | FlameRewardListener | 说明 |
|----------------|-------------------|------|
| `rewardVideoAdDidLoad:` | `onAdLoaded` | 加载成功 |
| `rewardVideoAdDidLoad:didFailWithError:` | `onAdError:desc:` | 加载失败 |
| `rewardVideoAdDidVisible:` | `onAdShow` | 展示 |
| `rewardVideoAdDidShowFailed:error:` | `onAdError:desc:` | 展示失败 |
| `rewardVideoAdDidClick:` | `onAdClicked` | 点击 |
| `rewardVideoAdDidPlayFinish:didFailWithError:` | `onAdPlayComplete`（error=nil）/ `onAdError:desc:`（error!=nil） | 播放完成 |
| `rewardVideoAd:reward:` | `onAdReward:userCustomData:transId:` | 激励发放（TODO: 待 SDK 头文件确认 WindMillRewardInfo 属性） |
| `rewardVideoAdDidClose:` | `onAdClosed` | 关闭 |
| `rewardVideoAdWillVisible:` | — | 仅日志（无对应 Flame 方法） |
| `rewardVideoAdWillClose:` | — | 仅日志 |
| `rewardVideoAdDidClickSkip:` | — | 仅日志 |
| `rewardVideoAdDidAutoLoad:` | — | 仅日志 |
| `rewardVideoAd:didAutoLoadFailWithError:` | — | 仅日志 |

### 新增文件

| 文件 | 职责 |
|------|------|
| `mediation/tb/FlameTBProvider.h` | TB Provider 头文件，实现 FlameMediationProvider |
| `mediation/tb/FlameTBProvider.m` | TB Provider 实现：init WindMill SDK，创建 TbRewardAdapter，其他广告类型 Phase 6 占位返回 nil |
| `adapter/tb/TbRewardAdapter.h` | TB Reward 适配器头文件，前向声明 WindMill 类型 |
| `adapter/tb/TbRewardAdapter.m` | TB Reward 适配器实现：FlameRewardAdapterProtocol + WindMillRewardVideoAdDelegate |

### 修改文件

| 文件 | 变更 |
|------|------|
| `core/FlameSdk.m` | registerAllProvidersIfNeeded 中注册 FlameTBProvider |
| `flame_sdk_ios.podspec` | 新增 `s.dependency 'ToBid-iOS-RC', '5.5.6'` |
| `Podfile` | 临时新增 `tb_pods` 函数（仅本地编译验证，不提交 SDK 主变更） |

### Pod 依赖写法

```ruby
# flame_sdk_ios.podspec
s.dependency 'ToBid-iOS-RC', '5.5.6'
```

说明：
- 仅引入 ToBid-iOS-RC 核心SDK（WindMillSDK），不含 adapter subspecs
- adapter subspecs（CSJAdapter / GDTAdapter 等）在 Phase 7 完整回归时按需添加
- 避免与现有 AnyThinkMediation*Adapter 产生依赖冲突
- Podfile 中临时添加 `pod 'ToBid-iOS-RC', '5.5.6'` 用于本地编译，不提交 SDK 主变更

### 编译验证

- `pod install` ✅ 成功
- `xcodebuild -sdk iphoneos -configuration Release` ✅ **BUILD SUCCEEDED**
- 0 errors
- 0 SDK 源码新增 warnings
- Phase 5A 新增文件 0 warnings

### TODO

1. `WindMillRewardInfo` 属性提取：待安装 ToBid SDK 后从头文件确认 `rewardName` / `rewardAmount` / `transId` 等字段
2. Phase 7 添加 ToBid adapter subspecs（CSJAdapter / GDTAdapter 等）
3. Phase 6 补齐 TB Splash / Interstitial / Banner / Native
4. 真实后台 pt=tb Reward 测试（需后台配合）

---

## 2026-06-11 — Phase 4.1 AtNativeSelfRenderView 自渲染链路补查

### 目标

确认 `AtNativeSelfRenderView` 是否只是 TK Native Adapter 内部实现，还是被 FlameNativeAdImpl / FlameSdk / 对外 API 直接依赖。为后续 TB Native 接入（Phase 6）做准备。

### 搜索结果

| # | 检查项 | 结果 |
|---|--------|------|
| 一 | `AtNativeSelfRenderView.h` 被 import 的文件 | 仅 `AtNativeSelfRenderView.m`（自身）和 `AtNativeAdapter.m` |
| 二 | `AtNativeSelfRenderView` 被 alloc/init 的文件 | 仅 `AtNativeAdapter.m`（line 251） |
| 三 | FlameNativeAdImpl.h/.m 是否引用 | ❌ 未引用 |
| 四 | FlameSdk.m 是否引用 | ❌ 未引用 |
| 五 | FlameNativeAdapterProtocol.h 是否引用 | ❌ 未引用 |
| 六 | flame_sdk_ios.h 或公开头文件是否暴露 | ❌ 未暴露 |
| 七 | 参与的渲染逻辑 | 在 AtNativeAdapter `showInContainer:` 内部创建，用于自渲染模式的物料绑定、点击区域注册、mediaView 挂载 |

### 结论

**情况一：AtNativeSelfRenderView 属于 TK Native Adapter 内部实现细节。**

- 只被 `AtNativeAdapter.m` 内部使用（import + alloc/init）
- 不被 FlameNativeAdImpl、FlameSdk、FlameNativeAdapterProtocol、flame_sdk_ios.h 或任何公开 API 直接依赖
- 它是 TopOn/AnyThink 自渲染物料到 UIView 的适配层，将 ATNativeAdOffer 的素材绑定到自定义 UI 组件
- 完全在 AtNativeAdapter 的 `showInContainer:` 方法内部创建和配置，生命周期由 AtNativeAdapter 管理

### 处理方式

- 无需新增 Provider 创建方法
- 无需新增独立 View Protocol
- 无需修改 FlameNativeAdImpl
- 无需修改 FlameSdk
- 无需修改 FlameNativeAdapterProtocol
- 后续 TB Native 接入（Phase 6）时，TbNativeAdapter 可自行实现对应的自渲染视图（TbNativeSelfRenderView），完全独立于 TK

### Phase 4.1 验证

- [x] AtNativeSelfRenderView 只被 AtNativeAdapter.m 内部使用
- [x] FlameNativeAdImpl 不直接依赖
- [x] FlameSdk.m 不直接依赖
- [x] FlameNativeAdapterProtocol 不依赖
- [x] flame_sdk_ios.h 未暴露
- [x] 未修改任何源码
- [x] 未接入 ToBid
- [x] Phase 5A 不受阻塞（Phase 5A 只做 Reward，不碰 Native）

### Phase 6 TB Native 注意事项

进入 Phase 6 接入 TbNativeAdapter 时：
- TbNativeAdapter 需自行实现 ToBid (WindMill) 的自渲染视图逻辑
- ToBid SDK 的自渲染 API 与 TopOn/AnyThink 不同（需参考 ToBid Demo 中的原生广告示例）
- 可按需创建 `adapter/tb/TbNativeSelfRenderView.h/.m`，与 `adapter/tk/AtNativeSelfRenderView.h/.m` 完全独立
- FlameNativeAdapterProtocol 无需修改（showInContainer: 接口足够通用）

**设计约束**（已登记到 04_tobid_integration_notes.md）：
- TbNativeAdapter 必须使用 ToBid / WindMill 自己的 Native 视图体系（WindMillNativeAd / WindMillNativeAdView / refreshData: / setClickableViews: / unregisterDataObject）
- 不得复用 TK 的 AtNativeSelfRenderView
- 不得让 FlameNativeAdImpl 直接 import / alloc WindMillNativeAdView 或 TbNativeSelfRenderView
- FlameNativeAdImpl 仍然只面向 FlameNativeAdapterProtocol
- TB Native 的 showInContainer: 由 TbNativeAdapter 内部完成 WindMillNativeAdView 创建、refreshData:、setClickableViews:、viewController 设置和 unregisterDataObject 生命周期管理

---

## 2026-06-11 — Phase 4 缓存策略调整（网络优先，失败 fallback 完整缓存）

### 目标

将 FlameConfigManager 缓存策略从"有缓存直接跳过网络请求"改为"每次冷启动优先请求后台，网络失败 fallback 完整缓存"。确保后台从 tk 切到 tb 后，SDK 下次冷启动能及时感知切换。

### 修改文件

| # | 文件 | 修改内容 |
|---|------|----------|
| 一 | `utils/FlameConfigLocalStorage.h` | 新增 `getCV`、`getCachedAt`、`putWithPt:aId:aKey:pMap:cv:cachedAt:` 方法声明 |
| 二 | `utils/FlameConfigLocalStorage.m` | 新增 KEY_CV / KEY_CACHED_AT 常量；新增 getCV / getCachedAt 实现；原 `putWithPt:aId:aKey:pMap:` 委托到新方法；新方法写入 cv 和 cachedAt（秒级时间戳） |
| 三 | `core/FlameAppEntity.h` | 新增 `cv`（NSString）和 `cachedAt`（NSDate）属性 |
| 四 | `core/FlameAppEntity.m` | fromJson 新增 cv 字段解析（可选）；cachedAt 不从网络 JSON 解析，仅在缓存构建时写入；description 更新 |
| 五 | `core/FlameConfigManager.m` | **核心改造**：updateAppWithAppId 逻辑重写为网络优先策略（见下方详细说明） |

### FlameConfigManager 核心改造详解

**旧逻辑**（已删除）：
- 读取本地缓存 → aId + aKey + pMap 非空 → 直接 return success，跳过网络请求
- 缓存命中条件不包含 pt
- 后台从 tk 切到 tb 后，SDK 仍使用旧 tk 缓存

**新逻辑**：
1. 读取本地缓存，判断完整性（pt + aId + aKey + pMap 均非空），但不立即返回 success
2. 每次冷启动都发起后台网络请求
3. 网络成功 → 使用最新配置 + 更新缓存（含 cv 和 cachedAt）
4. 网络失败 → 检查缓存完整性：
   - 缓存完整（pt + aId + aKey + pMap）→ fallback 使用缓存 + warning 日志
   - 缓存不完整 → callback.fail（使用原有网络错误码）
5. 服务端数据格式错误（非网络错误）→ 不 fallback，直接 fail（因为网络是通的，后台返回异常数据不应使用旧缓存）

**缓存完整性条件**（必须全部满足）：
- `pt` 非空（新增，旧逻辑不检查 pt）
- `aId` 非空
- `aKey` 非空
- `pMap` 非空

**未修改**：
- FlameSdk.m 初始化链路不变（仍通过 UpdateAppCallback.success → Registry → Router → Provider）
- FlameSdk.m 广告创建链路不变
- FlameSdk.m pt 为空兼容逻辑不变
- flame_sdk_ios.h 不变
- adapter/tk/ 不变
- mediation Provider / Router / Registry 结构不变

### 编译验证

| # | 项目 | 结果 |
|---|------|------|
| 一 | 构建方式 | xcodebuild -workspace flame_sdk_ios.xcworkspace -scheme flame_sdk_ios -sdk iphoneos |
| 二 | 构建结果 | **BUILD SUCCEEDED** ✅ |
| 三 | Errors | **0** |
| 四 | SDK 源码新增 warning | **0**（原有 warning 不变） |

### 5 个缓存场景预期行为

| # | 场景 | 预期行为 |
|---|------|----------|
| 一 | 有缓存 + 网络成功 + 后台 pt=tk | 请求后台 → 使用网络返回 pt=tk → 更新缓存 |
| 二 | 有缓存 + 网络成功 + 后台 pt 变化（如 tk→tb）| 请求后台 → 使用网络最新 pt → 更新缓存 → Router 切换 Provider |
| 三 | 网络失败 + 有完整缓存 | fallback 缓存 → 使用缓存 pt → warning 日志 |
| 四 | 网络失败 + 无完整缓存 | callback.fail → 初始化失败 |
| 五 | 缓存缺 pt | 缓存不完整 → 请求网络 → 网络失败则 fail |

---

## 2026-06-11 — Phase 3B 补齐 Splash/Interstitial/Banner/Native 广告创建链路解耦

### 新增文件

| # | 文件 | 职责 |
|---|------|------|
| 一 | `mediation/FlameSplashAdapterProtocol.h` | 内部开屏适配器协议（load / loadWithUserId:userCustomData: / isReady / isLoading / show: / destroy） |
| 二 | `mediation/FlameInterstitialAdapterProtocol.h` | 内部插屏适配器协议（load / loadWithUserId:userCustomData: / isReady / isLoading / show / destroy） |
| 三 | `mediation/FlameBannerAdapterProtocol.h` | 内部横幅适配器协议（loadWithWidth:height:VC: / loadWithUserId:userCustomData:width:height:VC: / isReady / isLoading / retrieveAdView / retrieveMaterials / bindMaterialAtIndex:slots: / unbindMaterial / remove / destroy） |
| 四 | `mediation/FlameNativeAdapterProtocol.h` | 内部原生适配器协议（loadWithWidth:height: / loadWithUserId:userCustomData:width:height: / isLoading / isReady / showInContainer: / setRenderType: / remove / destroy） |

### 修改文件

| # | 文件 | 修改内容 |
|---|------|----------|
| 一 | `mediation/FlameMediationProvider.h` | 新增 createSplashAdapter / createInterstitialAdapter / createBannerAdapter / createNativeAdapter @required 方法；新增对应 protocol 和 public header import |
| 二 | `mediation/tk/FlameTKProvider.m` | 实现上述 4 个 create*Adapter 方法，内部直接创建 AtSplashAdapter / AtInterstitialAdapter / AtBannerAdapter / AtNativeAdapter；新增 import |
| 三 | `adapter/tk/AtSplashAdapter.h` | 协议从 `<FlameSplashAd, ATSplashDelegate>` 改为 `<FlameSplashAdapterProtocol, ATSplashDelegate>`；新增 `#import FlameSplashAdapterProtocol.h` |
| 四 | `adapter/tk/AtInterstitialAdapter.h` | 协议从 `<FlameInterstitialAd, ATInterstitialDelegate>` 改为 `<FlameInterstitialAdapterProtocol, ATInterstitialDelegate>`；新增 `#import FlameInterstitialAdapterProtocol.h` |
| 五 | `adapter/tk/AtBannerAdapter.h` | 协议从 `<FlameBannerAd, ATBannerDelegate, ATAdLoadingDelegate>` 改为 `<FlameBannerAdapterProtocol, ATBannerDelegate, ATAdLoadingDelegate>`；新增 `#import FlameBannerAdapterProtocol.h` |
| 六 | `adapter/tk/AtNativeAdapter.h` | 协议从 `<FlameNativeAd, ATNativeADDelegate>` 改为 `<FlameNativeAdapterProtocol, ATNativeADDelegate>`；新增 `#import FlameNativeAdapterProtocol.h` |
| 七 | `ads/splash/FlameSplashAdImpl.h` | adapter 属性从 `id<FlameSplashAd>` 改为 `id<FlameSplashAdapterProtocol>`；init 改为接收 adapter 参数；新增 `#import FlameSplashAdapterProtocol.h` |
| 八 | `ads/splash/FlameSplashAdImpl.m` | init 不再调用 `FlameAdapterManager.createSplashAdAdapter`，改为接收外部传入的 adapter |
| 九 | `ads/interstitial/FlameInterstitialAdImpl.h` | adapter 属性从 `id<FlameInterstitialAd>` 改为 `id<FlameInterstitialAdapterProtocol>`；init 改为接收 adapter 参数；新增 `#import FlameInterstitialAdapterProtocol.h` |
| 十 | `ads/interstitial/FlameInterstitialAdImpl.m` | init 不再调用 `FlameAdapterManager.createInterstitialAdapter`，改为接收外部传入的 adapter |
| 十一 | `ads/banner/FlameBannerAdImpl.h` | adapter 属性从 `id<FlameBannerAd>` 改为 `id<FlameBannerAdapterProtocol>`；init 改为接收 adapter 参数；新增 `#import FlameBannerAdapterProtocol.h` |
| 十二 | `ads/banner/FlameBannerAdImpl.m` | init 不再调用 `FlameAdapterManager.createBannerAdapter`，改为接收外部传入的 adapter |
| 十三 | `ads/nativate/FlameNativeAdImpl.h` | adapter 属性从 `id<FlameNativeAd>` 改为 `id<FlameNativeAdapterProtocol>`；init 改为接收 adapter 参数；新增 `#import FlameNativeAdapterProtocol.h` |
| 十四 | `ads/nativate/FlameNativeAdImpl.m` | init 不再调用 `FlameAdapterManager.createNativeAdapter`，改为接收外部传入的 adapter |
| 十五 | `core/FlameSdk.m` | createSplashAd / createInterstitialAd / createBannerAd / createSelfRenderBannerAd / createNativeAd 全部改为通过 Router → Provider → create*Adapter 获取适配器；新增 `[Mediation]` 调试日志和 4 个 protocol import |

### At*Adapter .m 文件

以下 .m 文件 **零改动**，TopOn 调用逻辑和回调映射完全保持不变：
- `adapter/tk/AtSplashAdapter.m`（184 行）
- `adapter/tk/AtInterstitialAdapter.m`（162 行）
- `adapter/tk/AtBannerAdapter.m`（452 行）
- `adapter/tk/AtNativeAdapter.m`（557 行）

### 编译验证

| # | 项目 | 结果 |
|---|------|------|
| 一 | 构建方式 | xcodebuild -workspace flame_sdk_ios.xcworkspace -scheme flame_sdk_ios -sdk iphoneos |
| 二 | 构建结果 | **BUILD SUCCEEDED** ✅ |
| 三 | Errors | **0** |
| 四 | SDK 源码新增 warning | FlameAdapterManager.m 4 条新增死代码 warning（见下方分析） |

### Warnings 分析

| # | Warning | 文件 | 来源 | 说明 |
|---|---------|------|------|------|
| 一 | returning 'AtRewardAdapter' from incompatible 'id\<FlameRewardAd\>' | FlameAdapterManager.m:129 | Phase 3A 副作用 | 已知，Phase 3A.1 确认 |
| 二 | returning 'AtInterstitialAdapter' from incompatible 'id\<FlameInterstitialAd\>' | FlameAdapterManager.m:151 | ⚠️ **Phase 3B 新增** | AtInterstitialAdapter 不再声明 FlameInterstitialAd 协议，死代码 |
| 三 | returning 'AtSplashAdapter' from incompatible 'id\<FlameSplashAd\>' | FlameAdapterManager.m:174 | ⚠️ **Phase 3B 新增** | AtSplashAdapter 不再声明 FlameSplashAd 协议，死代码 |
| 四 | returning 'AtBannerAdapter' from incompatible 'id\<FlameBannerAd\>' | FlameAdapterManager.m:202 | ⚠️ **Phase 3B 新增** | AtBannerAdapter 不再声明 FlameBannerAd 协议，死代码 |
| 五 | returning 'AtNativeAdapter' from incompatible 'id\<FlameNativeAd\>' | FlameAdapterManager.m:228 | ⚠️ **Phase 3B 新增** | AtNativeAdapter 不再声明 FlameNativeAd 协议，死代码 |
| 六 | pointer missing nullability | FlameBannerAd.h:33,63,66 | 预存 | 非新增 |
| 七 | block implicitly retains self | FlameConfigManager.m:178 | 预存 | 非新增 |
| 八 | CC_MD5 deprecated | FlameMd5SignatureUtils.m:37 | 预存 | 非新增 |

### FlameAdapterManager 死代码清理建议

Phase 3B 完成后，FlameAdapterManager 的全部 5 个 create*Adapter 工厂方法（Reward / Splash / Interstitial / Banner / Native）均已变为死代码，无调用者。建议：

- **Phase 3C**：统一清理 FlameAdapterManager 死代码工厂方法，或整体评估是否可以移除 FlameAdapterManager
- **不建议在 Phase 3B 中扩大范围**

### [Mediation] 调试日志（Phase 7 统一清理）

Phase 3B 在 FlameSdk.m 新增以下 `[Mediation]` 日志：
- `createSplashAd → Router.currentProvider`
- `createSplashAd → FlameSplashAdImpl(adapter=..., pId=...)`
- `createInterstitialAd → Router.currentProvider`
- `createInterstitialAd → FlameInterstitialAdImpl(adapter=..., pId=...)`
- `createBannerAd(Express) → Router.currentProvider`
- `createBannerAd(Express) → FlameBannerAdImpl(adapter=..., pId=...)`
- `createBannerAd(SelfRender) → Router.currentProvider`
- `createBannerAd(SelfRender) → FlameBannerAdImpl(adapter=..., pId=...)`
- `createNativeAd → Router.currentProvider`
- `createNativeAd → FlameNativeAdImpl(adapter=..., pId=...)`

FlameTKProvider.m 新增：
- `createSplashAdapter → AtSplashAdapter(pId=...)`
- `createInterstitialAdapter → AtInterstitialAdapter(pId=...)`
- `createBannerAdapter → AtBannerAdapter(pId=..., renderType=...)`
- `createNativeAdapter → AtNativeAdapter(pId=...)`

过滤关键字：`[Mediation]`

### Phase 3B 验证

- [x] Splash: FlameSdk.createSplashAd → Router → TKProvider → AtSplashAdapter → FlameSplashAdImpl
- [x] Interstitial: FlameSdk.createInterstitialAd → Router → TKProvider → AtInterstitialAdapter → FlameInterstitialAdImpl
- [x] Banner: FlameSdk.createBannerAd → Router → TKProvider → AtBannerAdapter → FlameBannerAdImpl
- [x] Native: FlameSdk.createNativeAd → Router → TKProvider → AtNativeAdapter → FlameNativeAdImpl
- [x] AtSplashAdapter 实现 FlameSplashAdapterProtocol
- [x] AtInterstitialAdapter 实现 FlameInterstitialAdapterProtocol
- [x] AtBannerAdapter 实现 FlameBannerAdapterProtocol
- [x] AtNativeAdapter 实现 FlameNativeAdapterProtocol
- [x] At*Adapter 仍只调用 TopOn / AnyThink
- [x] Flame*AdImpl 不再 import At*Adapter
- [x] Flame*AdImpl 不再 alloc At*Adapter
- [x] Flame*AdImpl 中无 tk/tb 判断
- [x] create*Ad 方法中无 tk/tb 判断
- [x] 对外 API 签名不变
- [x] isInitialized 检查保留
- [x] getPId 映射保留
- [x] currentProvider nil 有错误回调
- [x] create*Adapter nil 有错误回调
- [x] 未修改 Reward 已通过链路
- [x] 未接入 ToBid
- [x] 未新增 TBProvider / Tb*Adapter
- [x] 未修改 Podfile / podspec / Info.plist
- [x] 未修改 flame_sdk_ios.h
- [x] BUILD SUCCEEDED, 0 errors

### 已知副作用（Phase 3C 清理）

FlameAdapterManager 全部 5 个 create*Adapter 工厂方法（Reward / Splash / Interstitial / Banner / Native）均变为死代码，产生编译 warning。这些方法在所有广告创建路径中已无调用者。建议 Phase 3C 统一清理。

---

## 2026-06-11 — Phase 3A.1 编译验证与回归确认

### 验证环境

| # | 项目 | 结果 |
|---|------|------|
| 一 | Xcode 版本 | 26.5 (Build 17F42) |
| 二 | CocoaPods | 1.16.2，pod install 成功 |
| 三 | 依赖 | AnyThinkiOS 6.5.71，OpenSSL-Universal 3.6.2000 |
| 四 | 构建方式 | xcodebuild -workspace flame_sdk_ios.xcworkspace -scheme flame_sdk_ios -sdk iphoneos |
| 五 | 构建结果 | **BUILD SUCCEEDED** ✅ |

### 编译 Warnings 分析

| # | Warning | 文件 | Phase 3A 引入？ | 说明 |
|---|---------|------|----------------|------|
| 一 | returning 'AtRewardAdapter *__strong' from incompatible result type 'id\<FlameRewardAd\>' | FlameAdapterManager.m:129 | ⚠️ **是（副作用）** | AtRewardAdapter 不再声明 FlameRewardAd 协议，但 FlameAdapterManager.createRewardAdapter 返回 id\<FlameRewardAd\>。此方法在 Reward 路径已无调用者（FlameRewardAdImpl 不再调用），属于死代码。FlameAdapterManager 不在 Phase 3A 允许修改范围内，将在 Phase 3B 自然清理 |
| 二 | pointer missing nullability | FlameBannerAd.h:33,63,66 | ❌ 否 | 预存 warning |
| 三 | block implicitly retains self | FlameConfigManager.m:178 | ❌ 否 | Phase 2 预存 |
| 四 | CC_MD5 deprecated | FlameMd5SignatureUtils.m:37 | ❌ 否 | 预存 |
| 五 | parameter already documented | FlameNetworkUtils.h:14,15 | ❌ 否 | 预存 |
| 六 | IPHONEOS_DEPLOYMENT_TARGET 10.0 | Pods (AnyThinkiOS) | ❌ 否 | AnyThinkSDK 预存 |

### Phase 3A.1 验证结论

- [x] pod install 成功
- [x] 使用 .xcworkspace 构建成功（BUILD SUCCEEDED，0 errors）
- [x] 无 AnyThinkSDK / OpenSSL / UIKit / FlameCallback 缺失问题
- [x] FlameRewardAdapterProtocol 6 个方法签名与 FlameRewardAd 公共协议完全一致
- [x] AtRewardAdapter 完整实现 FlameRewardAdapterProtocol（6/6 方法）
- [x] FlameRewardAdImpl 转发逻辑不变（load/show/destroy/isReady/isLoading）
- [x] AtRewardAdapter.m 的 TopOn 调用逻辑和回调映射不变（154 行零改动）
- [x] FlameSdk.createRewardAdWithVC 通过 Router → Provider → createRewardAdapter 路径
- [x] FlameRewardAdImpl 不 import / alloc AtRewardAdapter
- [x] FlameRewardAdImpl 中无 tk/tb 判断
- [x] createRewardAdWithVC 方法体中无 tk/tb 判断
- [x] Splash / Interstitial / Banner / Native 未修改
- [x] 未接入 ToBid
- [x] 未新增 TBProvider / TbRewardAdapter
- [x] 未修改 Podfile / podspec / Info.plist
- [x] 未修改 flame_sdk_ios.h
- [x] FlameAdapterManager.createRewardAdapter warning 已确认为副作用（死代码），非阻塞性问题

### 已知副作用（Phase 3B 清理）

FlameAdapterManager.createRewardAdapter 返回类型 `id<FlameRewardAd>` 与 AtRewardAdapter 新协议不匹配，产生编译 warning。此方法在 Reward 路径已无调用者（Phase 3A 改造后 FlameRewardAdImpl 不再调用）。Phase 3B 解耦其他广告类型时，FlameAdapterManager 的工厂方法将全部变为死代码，届时统一清理。

---

## 2026-06-11 — Phase 3A Reward 广告创建链路解耦

### 新增文件

| # | 文件 | 职责 |
|---|------|------|
| 一 | `mediation/FlameRewardAdapterProtocol.h` | 内部激励视频适配器协议（load / loadWithUserId:userCustomData: / isReady / isLoading / show / destroy） |

### 修改文件

| # | 文件 | 修改内容 |
|---|------|----------|
| 一 | `mediation/FlameMediationProvider.h` | 新增 `createRewardAdapterWithViewController:placementId:listener:` @required 方法；新增 `#import UIKit`、`FlameRewardAdapterProtocol.h`、`FlameRewardAd.h` |
| 二 | `mediation/tk/FlameTKProvider.h/.m` | 实现 `createRewardAdapterWithViewController:placementId:listener:`，内部直接创建 AtRewardAdapter |
| 三 | `adapter/tk/AtRewardAdapter.h` | 协议从 `<FlameRewardAd, ATRewardedVideoDelegate>` 改为 `<FlameRewardAdapterProtocol, ATRewardedVideoDelegate>`；新增 `#import FlameRewardAdapterProtocol.h` |
| 四 | `ads/reward/FlameRewardAdImpl.h` | adapter 属性类型从 `id<FlameRewardAd>` 改为 `id<FlameRewardAdapterProtocol>`；init 改为接收预创建的 adapter 参数；新增 `#import FlameRewardAdapterProtocol.h` |
| 五 | `ads/reward/FlameRewardAdImpl.m` | init 不再调用 `FlameAdapterManager.createRewardAdapter`，改为接收外部传入的 adapter；保持 `FlameAdapterManager.checkInitialization` 安全检查 |
| 六 | `core/FlameSdk.m` | `createRewardAdWithVC` 改为通过 Router → Provider → createRewardAdapter 获取适配器；新增 `#import FlameRewardAdapterProtocol.h` |

### 设计决策

| # | 决策 | 说明 |
|---|------|------|
| 一 | FlameRewardAdapterProtocol 方法与 FlameRewardAd 完全一致 | 保持最小改动，FlameRewardAdImpl 转发逻辑无需改变 |
| 二 | AtRewardAdapter 不再声明 FlameRewardAd 协议 | 内部协议隔离，平台适配器不直接暴露公共协议 |
| 三 | FlameTKProvider 直接创建 AtRewardAdapter | 不通过 FlameAdapterManager 工厂方法（工厂返回 id\<FlameRewardAd\>，此处需 id\<FlameRewardAdapterProtocol\> 精确类型） |
| 四 | FlameRewardAdImpl 保留 FlameAdapterManager.checkInitialization | 安全检查，防止 SDK 未初始化时调用广告方法 |

### Phase 3A 验证

- [x] FlameRewardAdImpl.h/.m 不 import AtRewardAdapter
- [x] FlameRewardAdImpl.m 不调用 FlameAdapterManager.createRewardAdapter
- [x] FlameRewardAdImpl adapter 属性类型为 id\<FlameRewardAdapterProtocol\>
- [x] AtRewardAdapter 声明 FlameRewardAdapterProtocol 协议
- [x] AtRewardAdapter 不声明 FlameRewardAd 公共协议
- [x] FlameTKProvider 直接创建 AtRewardAdapter
- [x] FlameSdk.createRewardAdWithVC 通过 Router → Provider → createRewardAdapter 获取适配器
- [x] createRewardAdWithVC 中无 tk/tb 字符串判断（兼容默认 tk 在初始化链路，非创建链路）
- [x] Splash / Interstitial / Banner / Native 未修改
- [x] 未接入 ToBid
- [x] 未新增 TBProvider / TbRewardAdapter
- [x] 未修改 podspec / Podfile / Info.plist
- [x] 未修改 flame_sdk_ios.h
- [x] FlameRewardAdImpl 仍然实现 FlameRewardAd 公共协议（对外广告对象）
- [x] FlameRewardAdapterProtocol 不导入 flame_sdk_ios.h

### Reward 广告创建链路（Phase 3A 改造后）

```
FlameSdk.createRewardAdWithVC
  → FlameConfigManager.getPId（广告位映射）
  → FlameMediationRouter.currentProvider
  → FlameTKProvider.createRewardAdapterWithViewController:placementId:listener:
  → AtRewardAdapter
  → FlameRewardAdImpl (持有 id<FlameRewardAdapterProtocol>)
  → load / show / destroy / callback 行为保持不变
```

---

## 2026-06-11 — Phase 2.1 文档清残 + 代码自检

### 修正内容

| # | 修正项 | 涉及文件 |
|---|--------|----------|
| 一 | 统一错误码 14003：全局清除文档中残留的 14002 活跃引用（02, 03, 05, 08），保留 07/09 中的历史说明 | 02, 03, 05, 08 |
| 二 | 明确 FlameConfigManager.getPt 边界：只读访问器，与 getAId/getAKey 对称，不触发 Router/Provider/初始化 | 05, 07 |
| 三 | Phase 3 拆分为 Phase 3A（Reward only）和 Phase 3B（Splash/Interstitial/Banner/Native） | 05, 07, 08, 09 |
| 四 | 更新 05 总修改清单 FlameConfigManager 描述：反映 Phase 2 已完成的最小修改 | 05 |
| 五 | Phase 2.1 代码自检：9 项全部通过，无源码修改 | — |

### Phase 2.1 验证

- [x] 全局搜索：文档中无残留 14002 活跃引用（历史说明除外）
- [x] 02_multi_mediation_architecture.md 代码示例中 14002 → 14003
- [x] 03_backend_config_and_cache.md 边缘场景 14002 → 14003
- [x] 05_implementation_plan.md 三处 14002 → 14003
- [x] 08_next_stage_prompt.md 三处 14002 → 14003
- [x] FlameConfigManager.getPt 边界已在 05/07 明确
- [x] Phase 3 已在 05/07/08/09 拆分为 3A/3B
- [x] FlameTKProvider 只复用 FlameAdapterManager，无 At*Adapter 直接依赖
- [x] registerAllProvidersIfNeeded 使用 dispatch_once
- [x] clear 调用 Router.clear，不误清 Registry
- [x] 未知 pt 返回 14003
- [x] pt 为空兼容默认 tk 并记录日志
- [x] getPt 只读，不触发 Router
- [x] 广告创建链路未修改
- [x] 未接入 ToBid
- [x] 未修改任何源码（本轮仅文档修改）

---

## 2026-06-11 — Phase 2 pt=tk 初始化主链路接入

### 新增文件

| # | 文件 | 职责 |
|---|------|------|
| 一 | `mediation/tk/FlameTKProvider.h` | TK Provider 头文件，实现 FlameMediationProvider 协议 |
| 二 | `mediation/tk/FlameTKProvider.m` | TK Provider 实现，内部复用 FlameAdapterManager 初始化 TopOn |

### 修改文件

| # | 文件 | 修改内容 |
|---|------|----------|
| 一 | `mediation/FlameMediationProvider.h` | 新增 `initializeWithAppId:appKey:callback:` @required 方法 |
| 二 | `core/FlameErrorCode.h/.m` | 新增 `ERROR_CODE_UNSUPPORTED_PLATFORM = @"14003"`（原计划 14002，但已被 INVALID_PARAM 占用） |
| 三 | `core/FlameConfigManager.h/.m` | 新增 `getPt` 访问器；修复缓存命中路径未从 storage 读取 pt 的 bug |
| 四 | `core/FlameSdk.m` | 新增 `registerAllProvidersIfNeeded`（注册 TKProvider）；改造 `UpdateAppCallback.success` 走 Registry→Router→Provider 链路；`clear` 中同步 Router.clear |

### 设计决策

| # | 决策 | 说明 |
|---|------|------|
| 一 | 错误码 14003 而非 14002 | 14002 已被 ERROR_CODE_INVALID_PARAM 占用，Phase 2 使用 14003 表示不支持的聚合平台 |
| 二 | pt 为空兼容默认 tk | 旧缓存可能不含 pt 字段，为兼容历史数据默认 tk 并记录警告日志 |
| 三 | FlameConfigManager 新增 getPt | 最小修改：仅新增对称访问器（与 getAId/getAKey 一致），不改变职责边界 |
| 四 | 修复缓存命中 pt 缺失 | FlameConfigManager 缓存命中路径未从 FlameConfigLocalStorage 读取 pt，属于既有 bug |

### 初始化链路（Phase 2 改造后）

```
FlameSdk.init
  → FlameConfigManager.updateApp（配置请求、解密、缓存、返回 FlameAppEntity）
  → FlameSdk.registerAllProvidersIfNeeded（注册 TKProvider 到 Registry）
  → FlameSdk 读取 appEntity.pt
  → FlameMediationRegistry 查找 Provider
  → FlameMediationRouter.activateProvider(provider)
  → FlameTKProvider.initializeWithAppId（内部调用 FlameAdapterManager）
  → AdapterInitCallback → callback.success / fail
```

### Phase 2 验证

- [x] pt=tk 时通过 Registry → Router → TKProvider → FlameAdapterManager 初始化
- [x] 未知 pt 时返回 14003 错误
- [x] pt 为空时兼容默认 tk 并记录日志
- [x] FlameConfigManager 只负责配置请求/解析/缓存/返回，不触发 Router
- [x] Provider 注册在 registerAllProvidersIfNeeded 统一入口
- [x] FlameSdk.clear 同步 Router.clear
- [x] 未修改广告创建链路
- [x] 未修改 Flame*AdImpl
- [x] 未修改 adapter/tk/
- [x] 未接入 ToBid
- [x] 未修改 flame_sdk_ios.h
- [x] 未修改 podspec / Podfile / Info.plist
- [x] mediation 类未导入 flame_sdk_ios.h

---

## 2026-06-11 — Phase 1.2 文档清残

### 修正内容

| # | 修正项 | 涉及文件 |
|---|--------|----------|
| 一 | Phase 2 Prompt 删除旧描述（修改 FlameAppEntity 新增 cv/cachedAt、FlameConfigManager 触发 Router 激活），改为允许/禁止清单 | 08 |
| 二 | 快速启动 Prompt 状态更新：Phase 0/1/1.1 已完成，下一阶段 Phase 2 | 08 |
| 三 | 总修改清单 FlameAppEntity 改为分阶段描述：Phase 2 不修改，Phase 4 再考虑 | 05 |
| 四 | 总修改清单 FlameConfigManager 改为分阶段描述：Phase 2 不修改职责，Phase 4 处理缓存策略 | 05 |
| 五 | 统一 Phase 2 边界：4 个文档（05/07/08/09）一致确认应做/不应做清单 | 05, 07, 08, 09 |

### Phase 1.2 验证

- [x] 08 Phase 2 Prompt 已删除 cv/cachedAt 和 FlameConfigManager 触发 Router 旧描述
- [x] 08 Phase 2 Prompt 已改为允许/禁止清单格式
- [x] 05 总修改清单 FlameAppEntity 已改为分阶段描述
- [x] 05 总修改清单 FlameConfigManager 已改为分阶段描述
- [x] 07 Phase 2 边界红线与 05/08 一致
- [x] 未修改任何源码
- [x] 未修改 mediation 骨架文件

---

## 2026-06-11 — Phase 1.1 骨架补丁

### 修正内容

| # | 修正项 | 涉及文件 |
|---|--------|----------|
| 一 | FlameMediationRouter currentProviderInternal 从 `weak` 改为 `strong`，避免 Provider 被提前释放 | `FlameMediationRouter.m` |
| 二 | FlameMediationRouter.h 注释更新，明确 strong 持有语义 | `FlameMediationRouter.h` |
| 三 | Phase 2 范围收紧：不包含 cv/cachedAt，不做缓存策略重构，不由 FlameConfigManager 触发 Router | 05, 07, 09 |
| 四 | 明确 FlameConfigManager 职责边界：只负责配置请求、解析、缓存、返回 FlameAppEntity | 07 |
| 五 | 明确 Provider 选择和 Router 激活由 FlameSdk 初始化链路在拿到 FlameAppEntity 后处理 | 05, 07 |
| 六 | Phase 1 状态更新为已完成 | 05, 07, 09 |

### Phase 1.1 验证

- [x] Router currentProviderInternal 改为 `strong`
- [x] Router.clear 时释放 currentProvider
- [x] Registry 仍然 strong 持有已注册 Provider
- [x] 未修改任何主链路代码
- [x] 未注册任何 Provider
- [x] 未接入 ToBid
- [x] 未影响现有 TK 行为

---

## 2026-06-11 — 文档补丁（Phase 0 修订）

### 修正内容

| # | 修正项 | 涉及文件 |
|---|--------|----------|
| 一 | Phase 1 不修改任何已有源码（移除 FlameErrorCode.h 14002 要求） | 05, 08, 07 |
| 二 | 删除"缓存命中增加 TTL 检查"残留描述 | 05 |
| 三 | 统一 Adapter 类型设计：Provider 返回 id\<FlameXxxAdapterProtocol\>，平台 Adapter 不直接实现对外 Flame 协议 | 02, 04, 05, 08 |
| 四 | 拆清 Phase 2（只做初始化主链路）和 Phase 3（只做广告创建解耦）边界，14002 移至 Phase 2 | 05, 08, 07 |
| 五 | 确认文档路径为 doc/flame_mediation/tobid_doc/ | — |

---

## 2026-06-11 — 文档修订（Phase 0）

### 修订范围

修订 `doc/flame_mediation/tobid_doc/` 下全部 10 个 Markdown 文档。

### 修订内容

| # | 修订项 | 涉及文件 |
|---|--------|----------|
| 一 | 统一文档路径为 `doc/flame_mediation/tobid_doc/` | 00_README.md, 04_tobid_integration_notes.md |
| 二 | mediation 内部类不暴露到伞头文件 | 00, 02, 05, 07, 08 |
| 三 | 平台标识使用 NSString code，不使用 NS_ENUM | 00, 02, 07 |
| 四 | Provider 注册在统一入口，不在 create*Ad 中 | 00, 02, 07, 08 |
| 五 | 缓存策略改为网络优先，失败 fallback 缓存 | 00, 03, 06, 07 |
| 六 | 当前阶段不实现广告位级平台路由 | 00, 02, 03, 07 |
| 七 | 预留内部适配器协议设计 | 02 |
| 八 | 实施计划改为 8 阶段（Phase 0-7）保守策略 | 05, 07, 08 |
| 九 | 更新 compact 文档 | 07 |
| 十 | 更新下一阶段 Prompt | 08 |

### 架构决策更新

| 决策 | 旧版本 | 新版本 | 原因 |
|------|--------|--------|------|
| mediation 类可见性 | Provider 协议导入 flame_sdk_ios.h | SDK 内部实现，不暴露给接入方 | 接入方不需要也不应该知道 mediation 层 |
| Provider 注册位置 | 在 create*Ad 中注册 | 在 registerAllProviders 统一注册 | 职责分离，广告创建不应负责注册 |
| 缓存策略 | TTL 24h 为主刷新策略 | 网络优先，失败 fallback 完整缓存 | 避免 tk→tb 切换后 24h 不生效 |
| pIds 类型 | 兼容 string 和 object | 当前阶段只支持 Dict\<String, String\> | 减少当前实施复杂度 |
| 实施计划 | 6 阶段（Phase 1-6） | 8 阶段（Phase 0-7）保守策略 | Phase 0 文档先行，Phase 1 不接主链路，TB 先只做 Reward |
| 内部适配器协议 | 无 | 预留 FlameRewardAdapterProtocol 等 | 为 Provider 返回类型提供更清晰的设计选择 |

### 待办

- [x] Phase 1: mediation 基础骨架（不接主链路）
- [x] Phase 1.1: 骨架补丁（Router Provider weak→strong，文档同步）
- [x] Phase 1.2: 文档清残（删除 cv/cachedAt 旧描述，统一 Phase 2 边界）
- [x] Phase 2: pt=tk 初始化主链路接入
- [x] Phase 2.1: 文档清残 + 代码自检（14003 统一、Phase 3 拆分 3A/3B）
- [x] Phase 3A: Reward 广告创建链路解耦
- [x] Phase 3A.1: 编译验证与回归确认（BUILD SUCCEEDED，0 errors，1 个已知副作用 warning）
- [x] Phase 3B: 补齐 Splash/Interstitial/Banner/Native 解耦（BUILD SUCCEEDED，0 errors，5 个 FlameAdapterManager 死代码 warning）
- [ ] Phase 4: 缓存策略调整
- [ ] Phase 5: TB Provider + Reward
- [ ] Phase 6: TB 其他广告类型
- [ ] Phase 7: 完整回归和依赖验证
- [ ] 与后台协商 API 返回结构（cv 字段）
- [ ] ToBid SDK 集成方式确认
- [ ] 依赖冲突检查

---

## 2026-06-11 — 文档创建（首次）

### 新建文档

| 文件 | 说明 |
|------|------|
| `00_README.md` | 文档索引与概述 |
| `01_current_sdk_context.md` | 当前 SDK 接入现状分析 |
| `02_multi_mediation_architecture.md` | 多聚合平台可扩展架构设计（核心设计文档） |
| `03_backend_config_and_cache.md` | 后台配置结构与缓存策略设计 |
| `04_tobid_integration_notes.md` | ToBid 接入专项笔记 |
| `05_implementation_plan.md` | 分阶段实施计划与文件清单 |
| `06_risk_and_rollback.md` | 风险评估与回滚方案 |
| `07_claude_compact_context.md` | Claude AI 紧凑上下文 |
| `08_next_stage_prompt.md` | 下一阶段 Prompt |
| `09_change_log.md` | 本文件 |

### 分析结论

1. 当前 SDK 为三层架构：FlameSdk → *AdImpl → At*Adapter
2. `FlameAppEntity.pt` 字段已存在但未使用，是最佳介入点
3. 现有 FlameAdapterManager 直接硬编码 TopOn SDK 初始化
4. 各 *AdImpl 直接 alloc At*Adapter，无平台抽象
5. 设计了 Provider + Registry + Router 可扩展架构
6. Impl 改为接收预创建的 adapter，实现平台解耦
