# Phase 5A.14：TB 插屏广告接入与真机验证报告

> **修订记录**
> - 初版（commit `f97e746`，2026-07-19 早段）：基于"展示即闭环"的口径，误将 R2/R3 仅 load/show/visible 的过程写成"3 轮全闭环"，并把 Reward 的 load/didLoad 写成"回归通过"。
> - **本次修订（Phase 5A.14.1）**：根据 §8 修正验收口径，按"实现 / 静态审计 / 真机实测"三档区分。在修正 Demo 预加载时机后，已重新完成 R1/R2 完整关闭闭环 + R3 load success；Reward 仅做加载回归（无 show/close 真机证据，未写"完整回归通过"）。详见 §8/§9/§10/§12。

## 1. 基线

| 项 | 值 |
|---|---|
| 分支 | `release/ios-dual-line` |
| 开始 HEAD | `2d9bfcc`（Phase 5A.13 收口） |
| 结束 HEAD | `f97e746`（Phase 5A.14）→ 本次 docs 修订（Phase 5A.14.1） |
| 工作区 | 仅 `project.pbxproj`（环境性 CocoaPods UUID 差异，**严格排除在 commit 外**） |

## 2. API 审计

### Flame 插屏协议（已存在，未改动）

- 公共 listener：`FlameInterstitialListener`（`onAdLoaded` / `onAdError:desc:` / `onAdClicked` / `onAdShow` / `onAdClosed` / `onAdReward:userId:userCustomData:`，全 @optional）
- 公共广告对象：`FlameInterstitialAd`（`load` / `loadWithUserId:userCustomData:` / `isReady` / `isLoading` / `show` / `destroy`）
- 内部 adapter 协议：`FlameInterstitialAdapterProtocol`（同 6 个方法，@required）
- `FlameSdk.createInterstitialAdWithViewController:placementId:listener:` → Router → Provider → Adapter 链路完整

### TK 实现（参考，未改动）

`flame_sdk_ios/adapter/tk/AtInterstitialAdapter.{h,m}` —— 基于 AnyThink `[ATAdManager sharedManager]` 的 placement 缓存模型，show 用 `self.viewController`（缓存的 VC，**未做动态获取**）。

### ToBid 5.5.6 公开 API（审计确认，非记忆）

| 项 | 值 |
|---|---|
| 公开类 | **`WindMillIntersititialAd`**（注意拼写错误：Inter-s-i-titial，单 i，必须按此拼写） |
| 公开 delegate 协议 | **`WindMillIntersititialAdDelegate`**（同拼写错误） |
| init | `- (nonnull instancetype)initWithRequest:(WindMillAdRequest *)request` |
| load | `- (void)loadAdData` |
| ready | `- (BOOL)isAdReady` / `@property (readonly) BOOL ready` |
| show | `- (void)showAdFromRootViewController:(UIViewController *)rootViewController options:(NSDictionary<NSString *, NSString *> *)options` |
| WindMillAdRequest | 与 Reward 同一 builder（`+request` + `placementId`），插屏只用 placementId |
| umbrella import | `#import <WindMillSDK/WindMillSDK.h>`（与 Reward 一致） |
| 回调数 | 12 个 @optional delegate 方法 |

### 关键 API 事实（已审计确认）

1. **类名带历史拼写错误**：`WindMillIntersititialAd` / `intersititialAd*` selector 前缀，必须严格保留。
2. **WindMillAdRequest 与 Reward 同一 builder**。
3. **show 签名与 Reward 完全一致**：`showAdFromRootViewController:options:`，传 `@{}`。
4. **无 reward 回调**：WindMill 插屏无 `intersititialAd:reward:`，对应 `FlameInterstitialListener.onAdReward:` 不调用（@optional）。

## 3. Flame ↔ ToBid 回调映射

| Flame (`FlameInterstitialListener`) | ToBid (`WindMillIntersititialAdDelegate`) | 处理 |
|---|---|---|
| `onAdLoaded` | `intersititialAdDidLoad:` | 直接调用 + stale callback 守卫 |
| `onAdError:desc:` | `intersititialAdDidLoad:didFailWithError:` | code = error.code 字符串 |
| `onAdError:desc:` | `intersititialAdDidShowFailed:error:` | show 失败 |
| —（仅日志） | `intersititialAdWillVisible:` | log `[TB_INTERSTITIAL_DIAG] willVisible` |
| `onAdShow` | `intersititialAdDidVisible:` | visible = 展示 |
| `onAdClicked` | `intersititialAdDidClick:` | 直接调用 |
| `onAdClosed` | `intersititialAdDidClose:` | 直接调用 |
| —（no-op） | `intersititialAdDidClickSkip:` | 空实现 |
| —（仅日志/error 时 onAdError） | `intersititialAdDidPlayFinish:didFailWithError:` | error→onAdError；无 error 仅日志 |
| —（no-op） | `intersititialAdDidCloseOtherController:withInteractionType:` | 空实现（CSJ 专用） |
| —（no-op） | `intersititialAdDidAutoLoad:` / `intersititialAd:didAutoLoadFailWithError:` | 空实现 |
| `onAdReward:userId:userCustomData:` | **（无对应）** | 不调用 |

## 4. 实现文件

| 文件 | 修改 |
|------|------|
| `flame_sdk_ios/adapter/tb/TbInterstitialAdapter.h`（新增） | 类声明，前向声明 `WindMillIntersititialAd` / `WindMillIntersititialAdDelegate`，conform `<FlameInterstitialAdapterProtocol, WindMillIntersititialAdDelegate>` |
| `flame_sdk_ios/adapter/tb/TbInterstitialAdapter.m`（新增） | 完整实现（生命周期 + presenter + ready + 错误 + 诊断日志） |
| `flame_sdk_ios/mediation/tb/FlameTBProvider.m`（修改） | `#import "TbInterstitialAdapter.h"` + `createInterstitialAdapter...` 占位 `return nil` 改为创建 adapter |

**Xcode 工程**：`PBXFileSystemSynchronizedRootGroup`（Xcode 16+ 自动文件同步）自动识别新文件，**project.pbxproj 零改动**。

## 5. 生命周期设计

- **当前 ad**：`@property (nonatomic, strong) WindMillIntersititialAd *intersititialAd`
- **delegate 清理**：每次 `load` 入口先 `intersititialAd.delegate = nil; intersititialAd = nil`（防 stale callback，参考 TbRewardAdapter 验证模式）
- **stale callback 守卫**：每个回调 `if (intersititialAd != self.intersititialAd) { log + return; }`
- **close 清理**：`destroy` 中 nil delegate + nil ad + nil listener + nil viewController
- **presenter**：`flame_topViewController()` 动态获取（与 Reward 同一已验证修复），回退 cachedVC

## 6. 构建

| 项 | 结果 |
|---|---|
| 双 Archive | ✅ SUCCEEDED |
| XCFramework | ✅ 生成成功（binary 300K→320K，+20K） |
| AnyThinkSDK weak patch 幂等 | ✅ 通过 |
| AnyThinkSDK LC_LOAD_WEAK_DYLIB 断言 | ✅ 通过（无回归） |
| OpenSSL 等其他链接 | ✅ 无异常 |
| `TbInterstitialAdapter` 符号（nm -gU） | ✅ 2 个（class + metaclass） |
| `[TB_INTERSTITIAL_DIAG]` 字串 | ✅ 20 个 format string |
| `TB_REWARD_DIAG` | ✅ 仍存在（无回归） |
| `TK_PLATFORM_REQUIRES_ANYTHINK` | ✅ 仍存在（无回归） |

## 7. TB 依赖

| 项 | 结果 |
|---|---|
| Podfile.lock | 4 pods（`flame_sdk_ios_tb` + `OpenSSL` + `ToBid-iOS-RC` + `FunlinkSDK`） |
| AnyThinkiOS | ❌ 无（不在依赖树） |
| App Frameworks | `OpenSSL.framework` + `flame_sdk_ios.framework`（无 AnyThinkSDK） |

## 8. Phase 5A.14.1 修正后的真机验证（基于修正后 Demo）

### 8.1 验证条件

- 分支：`release/ios-dual-line`（SDK HEAD `f97e746`）
- Demo：`adshurge-ios-demo` HEAD `11c5958`（`fix: preload next interstitial after close`）
- 时机：修正 `InterstitialAdManager.onShow` 不再触发 `load()`，预加载移到 `onClosed`
- 时间窗口：22:31:28 - 22:32:21（一气呵成的真机日志）

### 8.2 R1（第一轮）—— 完整关闭闭环 ✅

| 事件 | 值 |
|---|---|
| `[TB_INTERSTITIAL_DIAG] load` | `adapter=0x10a2ece70 oldAd=0x0 placementId=9690693976929807 thread=1` |
| `load created` | `newAd=0x10cf7c000` |
| `didLoad` | `ad=0x10cf7c000 adapter=0x10a2ece70 isCurrent=1` |
| `[Interstitial] 加载成功` | 22:31:30.213 |
| `show` | `presenter=0x10a304000 vcWindow=0x10428bd30 cachedVC=0x10a304000 thread=1` |
| `willVisible` | `ad=0x10cf7c000 isCurrent=1` |
| `didVisible` | `ad=0x10cf7c000 isCurrent=1` |
| `[Interstitial] 展示` | 22:31:46.268（修正后文案，不再带"预加载下一条"） |
| **`intersititialAdDidClose`** | 22:31:50.050（sigmob 原始回调到达） |
| **`[TB_INTERSTITIAL_DIAG] didClose`** | `ad=0x10cf7c000 adapter=0x10a2ece70 isCurrent=1` ✅ |
| `[Interstitial] 关闭 → 加载下一条` | 22:31:50.866（修正后文案） |
| next load 触发 | `load: adapter=0x13a164ea0 oldAd=0x0` ✅ |

**R1 关键确认**：
- `didClose` 的 `ad` 与 `show` 的 `ad` 一致（`0x10cf7c000`）；
- `isCurrent=1`（adapter 未被替换）；
- `didClose` 到达前未触发任何 `load`（说明展示期间 Adapter 未被替换）；
- 未出现 `stale callback ignored`。

### 8.3 R2（第二轮）—— 完整关闭闭环，ad ≠ R1 ✅

| 事件 | 值 |
|---|---|
| `load` | `adapter=0x13a164ea0`（≠ R1 `0x10a2ece70`）|
| `load created` | `newAd=0x1392ce100`（≠ R1 `0x10cf7c000`）|
| `didLoad` | `ad=0x1392ce100 adapter=0x13a164ea0 isCurrent=1` |
| `show` | `presenter=0x10a304000 vcWindow=0x10428bd30 **cachedVC=0x0** thread=1` |
| `willVisible` / `didVisible` | `ad=0x1392ce100 isCurrent=1` |
| `[Interstitial] 展示` | 22:32:17.867 |
| **`intersititialAdDidClose`** | 22:32:21.021 |
| **`[TB_INTERSTITIAL_DIAG] didClose`** | `ad=0x1392ce100 adapter=0x13a164ea0 isCurrent=1` ✅ |
| `[Interstitial] 关闭 → 加载下一条` | 22:32:21.483 |
| next load | `adapter=0x13a0ee3d0` ✅ |

**R2 关键确认**：
- 第二轮 `ad` (`0x1392ce100`) ≠ R1 `ad` (`0x10cf7c000`)，对象确已替换；
- `presenter=0x10a304000` 非空，`vcWindow=0x10428bd30` 非空，`thread=1`；
- **`cachedVC=0x0`（Demo 重建 adapter 时传入 nil），但 `flame_topViewController()` 动态解析到稳定的 `0x10a304000`，展示与关闭均正常** —— 动态 presenter 修复在插屏场景同样生效；
- 无黑屏、无重复 present。

### 8.4 R3（第三轮）—— 仅 load success（不强制展示）

| 事件 | 值 |
|---|---|
| `load` | `adapter=0x13a0ee3d0 oldAd=0x0` |
| `load created` | `newAd=0x1392ce100` |
| `didLoad` | `ad=0x1392ce100 adapter=0x13a0ee3d0 isCurrent=1` ✅ |
| `[Interstitial] 加载成功` | 22:32:21.836 |

R3 在 R2 关闭后立刻自动加载成功，证明"关闭 → 加载下一条"循环未断（与 Phase 5A.13 的 Reward 修复效果一致）。

> **关于 R3 `newAd=0x1392ce100` 与 R2 ad (`0x1392ce100`) 指针相同**：地址可能因对象释放后被内存分配器复用，**不能仅依据指针值判断是否为同一对象**。R3 是**新的 adapter 实例**（`0x13a0ee3d0` ≠ R2 `0x13a164ea0`），且 `didLoad` 时 `isCurrent=1`（即新 adapter 的 `self.intersititialAd` 已指向新创建的对象），因此判定为新一轮加载而非对象复用。后续轮次判定一律以 **adapter 轮次 + `isCurrent`** 为准，不以裸指针值为准。

## 9. 第一轮插屏（**已被 §8 取代**）

> ⚠️ **本节为初版（commit `f97e746`）基于旧 Demo 的过程数据**，由于旧 Demo `onShow → load()` 提前销毁 Adapter，**未产生 didClose**，按 §8 修订口径**不构成完整闭环**。保留以记录历史事实，验收以 §8 为准。

| 事件 | 值 |
|---|---|
| load | `adapter=0x12cda1680 oldAd=0x0 placementId=6364573199167167 thread=1` ✅ |
| load created | `newAd=0x12cf44120` ✅ |
| didLoad | `ad=0x12cf44120 isCurrent=1` ✅ |
| show | `presenter=0x12c6e4000 cachedVC=0x12c6e4000 thread=1` ✅ |
| willVisible / didVisible | `isCurrent=1` ✅ |
| `[Interstitial] 展示 → 预加载下一条` | ✅（旧 Demo 文案）|
| **`didClose`** | ❌ **未出现**（旧 Demo `onShow` 提前 destroy，导致 delegate 被清空）|

placementId 映射：`q<REDACTED>`（旧 Demo 配置）→ `6364573199167167`（后台下发，pMap 解析）。

## 10. 第二轮 / 第三轮（**已被 §8 取代**）

> ⚠️ 同 §9：初版（commit `f97e746`）的 R2/R3 仅有 load/show/visible，**无 didClose**。按修订口径不构成闭环。验收以 §8 为准。

| 事件 | 值 |
|---|---|
| R2 新 adapter | `0x13b887db0` |
| R2 新 newAd | `0x13aed8300` |
| R2 show | `cachedVC=0x0`，presenter 正常 ✅（动态 presenter 修复已生效）|
| R2/R3 didVisible | ✅ |
| R2/R3 **didClose** | ❌ **未出现**（同 §9 根因）|

## 11. 异常场景（按 §6 修订口径区分：实现 / 静态审计 / 真机实测）

| 场景 | 代码实现 | 静态审计 | 真机实测 |
|---|---|---|---|
| 未就绪 show | ✅ `show` 入口 `isAdReady` 守卫，不就绪 → `onAdError:@"AD_NOT_READY"`，不调 ToBid show | ✅ 通过 | ❌ **未专项触发**（本次 Run 中插屏均在用户点击前已 ready） |
| 连续 show | ✅ `isAdReady` 守卫 + 单实例强引用 | ✅ 通过 | ⚠️ **未专项实测**：代码已实现 isAdReady/单实例防护；本轮 R1/R2 为正常顺序展示，未专项进行同一广告快速重复点击 |
| load 中再次 load | ✅ `load` 入口先 `delegate=nil; intersititialAd=nil`，旧对象立即释放 | ✅ 通过 | ⚠️ **未专项实测**：正常关闭后重新加载已通过；未专项在上一轮 load 未完成时再次调用 load |
| stale callback | ✅ 每个回调 `if (intersititialAd != self.intersititialAd) return` | ✅ 通过 | ❌ **未实际触发**（本次 Run 中 `isCurrent` 全 1，对象替换时机正确，未观察到 stale 守卫命中） |

> 修订说明（Phase 5A.14.1 初版 → 收口）：
> - 初版把"代码已实现"误写为"已验证"；本次按 §6 三档口径（实现/静态审计/真机实测）严格区分。
> - **第二轮修订（Phase 5A.15 前置）**：进一步收紧"连续 show"与"load 中再次 load"的口径——这两项原本被列为"已实测"，但本轮真机仅观察到 R1/R2 顺序展示、R1→R2→R3 顺序加载，**未做专项的同一广告快速重复点击、未做 load 未完成时再次 load 的注入**，因此降级为"代码实现 + 静态审计，未专项实测"。
> - 仅"正常关闭后重新加载"与"R1/R2 完整关闭闭环"属于本轮真机实测项。

## 12. 回归

### 12.1 Reward 回归（**仅加载回归通过**）

| 项 | 结果 |
|---|---|
| `[TB_REWARD_DIAG] load` | ✅ `adapter=0x10cf1a640 placementId=1886359231652093 thread=1` |
| `[TB_REWARD_DIAG] didLoad` | ✅ `ad=0x10cf7ca80 adapter=0x10cf1a640 isCurrent=1` |
| `[RewardVideo] 加载成功` | ✅ 22:31:30.458 |
| **Reward show / didVisible / didClose** | ❌ **本次未实测**（用户未点击 Reward 展示按钮）|

> **结论**：插屏改动**未破坏 Reward 加载链路**（同次启动 Reward load/didLoad 正常）。**但不能称为"完整回归通过"** —— 缺 show/visible/close 的真机证据。若需要完整回归，应在下一轮专项触发 Reward 展示并观察 didClose。Reward 的 close 路径已由 Phase 5A.13 commit `1abfdae` 单独验证过。

### 12.2 其他回归

| 项 | 结果 |
|---|---|
| TK 编译回归 | ✅ TK Demo BUILD SUCCEEDED，App Frameworks 含 AnyThinkSDK + SmartdigimktSDK + flame_sdk_ios，TbInterstitialAdapter 符号在 binary（单一二进制双线共享） |
| AnyThink ADX 弹窗（本次 Run 全程） | ❌ 未出现（TB 包不携带 AnyThinkSDK） |
| AnyThinkSDK weak link | ✅ 无回归（otool -L 仍为 weak） |

## 13. didClose 未触发根因诊断与最终责任边界（Phase 5A.14.1 修正）

### 13.1 初版现象

初版（commit `f97e746`）3 轮插屏 show/visible 全部通过，但整段日志 **0 个 `intersititialAdDidClose` / `[TB_INTERSTITIAL_DIAG] didClose` 事件**。用户确认展示后曾关闭广告。

### 13.2 定位到的现象（修正前 Demo）

Demo `InterstitialAdManager.swift` 的 `onShow` 回调在展示后立即触发 `load()`：

```swift
listener.onShow = { [weak self] in
    FlameLogger.log("Interstitial", "展示 → 预加载下一条")
    DispatchQueue.main.async { self?.load() }    // ← 展示后立即预加载
}
```

`load()` 中 `interstitialAd?.destroy()` → `TbInterstitialAdapter.destroy()` → `intersititialAd.delegate = nil`。

因此当用户随后关闭广告时，`WindMillIntersititialAd` 已无 delegate → `intersititialAdDidClose:` 无法到达 adapter → `onAdClosed` 不触发。

### 13.3 修正后责任边界（按真实结果，非绝对断言）

- **SDK Adapter 的关闭回调实现**：在本轮真机修正 Demo 后已观察到完整的 `intersititialAdDidClose` → `[TB_INTERSTITIAL_DIAG] didClose isCurrent=1` → `[Interstitial] 关闭` 链路（见 §8.2/§8.3），未发现 Adapter 侧缺陷。
- **Demo 在展示期间替换 Adapter**：导致 delegate 生命周期提前结束。把预加载从 `onShow` 移到 `onClosed` 后（Demo commit `11c5958`），didClose 完整出现。
- **责任结论**：初版的 didClose 缺失源于 Demo 预加载时机错误；修正 Demo 后，SDK Adapter 的关闭路径在 R1/R2 两轮真实闭环中验证通过。本轮修正前**不绝对断言** SDK 无缺陷，仅以修正后的真机结果确认责任边界。

## 14. Git

| 项 | 状态 |
|---|---|
| Phase 5A.13 Step 1.2B | `c40e4fe` |
| Phase 5A.13 Step 1.3 | `fa6be94` |
| Phase 5A.13 措辞修正 | `2d9bfcc` |
| Phase 5A.14 SDK 接入 | `f97e746` |
| Phase 5A.14.1 Demo 修正 | Demo 仓库 `11c5958`（独立仓库，仅 1 文件 +18 -6） |
| Phase 5A.14.1 SDK 报告修订 | 本次本地 docs commit（见下） |
| push | ❌ 未 push（SDK 与 Demo 均未 push） |
| tag | ❌ 未 tag |
| release | ❌ 未发布 |

### 14.1 Phase 5A.14.1 SDK 本地 commit 内容

```
docs: close TB interstitial validation gap (Phase 5A.14.1)

- 修正 Phase 5A.14 报告验收口径：按"实现 / 静态审计 / 真机实测"三档区分
- §8 新增：修正 Demo 预加载时机后的 R1/R2 完整关闭闭环 + R3 load success
- §11 区分异常场景的实现 / 审计 / 实测
- §12 Reward 回归改为"仅加载回归通过"（无 show/close 真机证据，不写完整通过）
- §13 责任边界按真实结果表述，不绝对断言 SDK 无缺陷

仅文档变更；SDK 代码、Pods、Podfile.lock、project.pbxproj 环境差异、Demo 配置严格排除在外。
```

## 15. 结论

| 项 | 结果 |
|---|---|
| 公共 API 是否变化 | ❌ 未变（FlameInterstitialListener / FlameInterstitialAd 接口零改动） |
| 单一 XCFramework | ✅ 保持（TK/TB 共享同一 binary，TbInterstitialAdapter 符号在两个 App 都存在） |
| 是否重新引入 AnyThink | ❌ 否（TB 包仍不携带 AnyThinkSDK，弱链接无回归） |
| TB 插屏关闭闭环 | ✅ R1/R2 两轮真机完整闭环（load/show/visible/didClose/next-load），R3 load success |
| 动态 presenter 修复 | ✅ R2 cachedVC=0x0 时仍正常展示/关闭 |
| Reward 回归 | ⚠️ **仅加载回归通过**（load/didLoad 正常，未实测 show/close）|
| 异常场景 | ⚠️ 四项（未就绪 show / 连续 show / load 中再 load / stale callback）均为代码实现 + 静态审计；本轮真机仅做正常顺序展示，未做专项异常注入 |
| 是否可以进入 TB 开屏 | ✅ 可以（插屏关闭闭环已真实验证，Splash 同模式可复用） |

## 16. 剩余问题

| 问题 | 归属 | 处理 |
|---|---|---|
| Reward 完整回归（show/didClose） | SDK 验证项 | 下一轮专项触发 Reward 展示验证（Reward close 路径已由 1abfdae 验证过） |
| Reward NSURLErrorDomain -1002 | 第三方（Sigmob WindSDK S2S） | Phase 5A.13 已登记为"高概率推断"，非阻塞 |
| 异常场景"未就绪 show"真机实测 | SDK 验证项 | App 启动后插屏未 ready 时点击展示 → 观察 onAdError AD_NOT_READY |
| 异常场景"stale callback"真机实测 | SDK 验证项 | 当前未观察到触发，守卫已实现并静态审计通过 |

## 17. /compact

Phase 5A.14.1 收口：修正 Phase 5A.14 报告验收口径，按"实现/静态审计/真机实测"三档区分。修正 Demo `InterstitialAdManager` 预加载时机（`onShow→load()` 改为 `onClosed→load()`，Demo commit `11c5958`），重新真机验证 R1/R2 完整关闭闭环（load/show/willVisible/didVisible/**didClose**/next-load，ad 地址 R1≠R2，R2 cachedVC=0x0 动态 presenter 修复生效），R3 load success（注意：R3 `newAd` 指针与 R2 相同系内存分配器复用，判定以 adapter 轮次 + `isCurrent` 为准）。Reward 仅做加载回归（load/didLoad 正常，未实测 show/close，未写"完整回归通过"）。异常场景四项（未就绪 show / 连续 show / load 中再 load / stale callback）均为代码实现 + 静态审计，**未做专项异常注入**（第二轮修订进一步收紧，初版曾误把"连续 show"/"load 中再 load"列为已实测）。SDK 报告修订为本地 docs commit，未 push/tag/release。等用户确认进入 TB 开屏。
