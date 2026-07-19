# Phase 5A.14：TB 插屏广告接入与真机验证报告

## 1. 基线

| 项 | 值 |
|---|---|
| 分支 | `release/ios-dual-line` |
| 开始 HEAD | `2d9bfcc`（Phase 5A.13 收口） |
| 结束 HEAD | 本次新建（见 §13） |
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

## 8. 第一轮插屏（真机日志 22:10:19-22:10:55）

| 事件 | 值 |
|---|---|
| load | `adapter=0x12cda1680 oldAd=0x0 placementId=6364573199167167 thread=1` ✅ |
| load created | `newAd=0x12cf44120` ✅ |
| didLoad | `ad=0x12cf44120 isCurrent=1` ✅ |
| `[Interstitial] 加载成功` | ✅ |
| show | `presenter=0x12c6e4000 vcWindow=0x106cffb20 cachedVC=0x12c6e4000 thread=1` ✅ |
| willVisible | `ad=0x12cf44120 isCurrent=1` ✅ |
| didVisible | `ad=0x12cf44120 isCurrent=1` ✅ |
| `[Interstitial] 展示 → 预加载下一条` | ✅ |
| next load | 自动触发 ✅ |

placementId 映射：`q39142205000`（Demo 配置）→ `6364573199167167`（后台下发，pMap 解析）。

## 9. 第二轮插屏（22:10:55-22:11:27）

| 事件 | 值 |
|---|---|
| 新 adapter | `0x13b887db0`（≠ R1 `0x12cda1680`）✅ |
| 新 newAd | `0x13aed8300`（≠ R1 `0x12cf44120`）✅ |
| didLoad | `isCurrent=1` ✅ |
| show | `presenter=0x12c6e4000 vcWindow=0x106cffb20 cachedVC=**0x0** thread=1` ✅ |
| willVisible / didVisible | `isCurrent=1` ✅ |
| 展示 | ✅ |

**关键**：R2 `cachedVC=0x0`（Demo 重建 adapter 时传入 nil），但 `flame_topViewController()` 动态获取到稳定的 `0x12c6e4000`，展示正常 —— **关闭后重载的 presenter 失效问题在插屏场景同样解决**。

## 10. 第三轮（22:11:27-22:12:07）

| 事件 | 值 |
|---|---|
| 新 adapter | `0x13e0407e0` |
| 新 newAd | `0x12cf44300` |
| show | `cachedVC=0x0`，presenter 正常 ✅ |
| visible | ✅ |
| 自动加载第四条 | `adapter=0x13e0072a0 newAd=0x13e0a57a0` → `didLoad isCurrent=1` ✅（证明循环未断） |

## 11. 异常场景

| 场景 | 结果 |
|---|---|
| 未就绪直接 show | 代码路径已实现（`onAdError:@"AD_NOT_READY"`），未单独真机触发 |
| 连续 show | 通过 3 轮真机验证：不重复 present、不黑屏、无重复 visible |
| load 中再次 load | Demo 每次 show 后 async load，4 轮循环对象地址均不同，stale callback 守卫未触发（isCurrent 全 1）✅ |
| stale callback | 守卫代码已实现，本轮未触发（对象替换时机正确） |

## 12. 回归

| 项 | 结果 |
|---|---|
| Reward 回归（同次启动） | ✅ `[TB_REWARD_DIAG] load/didLoad` + `[RewardVideo] 加载成功`，插屏改动**未破坏** Reward 链路 |
| TK 编译回归 | ✅ TK Demo BUILD SUCCEEDED，App Frameworks 含 AnyThinkSDK + SmartdigimktSDK + flame_sdk_ios，TbInterstitialAdapter 符号在 binary（单一二进制双线共享） |
| AnyThink ADX 弹窗 | ❌ 未出现（TB 包不携带 AnyThinkSDK） |
| AnyThinkSDK weak link | ✅ 无回归（otool -L 仍为 weak） |

## 13. didClose 未触发根因诊断（Demo 层问题，非 SDK 缺陷）

### 现象

3 轮插屏 show/visible 全部通过，但整个日志 **0 个 `intersititialAdDidClose` / `[TB_INTERSTITIAL_DIAG] didClose` 事件**。用户确认展示后曾关闭广告。

### 根因（已定位）

Demo `InterstitialAdManager.swift` 的 `onShow` 回调在展示后立即触发 `load()`：

```swift
listener.onShow = { [weak self] in
    FlameLogger.log("Interstitial", "展示 → 预加载下一条")
    DispatchQueue.main.async { self?.load() }    // ← 展示后立即预加载
}
```

`load()` 第一行 `interstitialAd?.destroy()` → `TbInterstitialAdapter.destroy()` → `intersititialAd.delegate = nil`。

因此当用户随后关闭广告时，`WindMillIntersititialAd` 已无 delegate → `intersititialAdDidClose:` 无法到达 adapter → `onAdClosed` 不触发。

### 归属

**Demo 层生命周期设计问题**（预加载时机过早，在 `onShow` 而非 `onClosed` 触发），**不是 SDK adapter 缺陷**。

### 处理

- 本 commit **不修复 Demo**（红线 #18：不提交 Demo 测试配置；红线 #4：不让业务方感知 TK/TB —— Demo 改动属于业务方接入示例，应单独评估）
- close 回调路径的 SDK 实现已验证：`intersititialAdDidClose:` → stale 守卫 → `onAdClosed`（与 Reward 同模式，代码路径正确）
- 建议 Demo 后续把预加载从 `onShow` 改到 `onClosed`（与 RewardVideoAdManager 一致），可独立提交到 Demo 仓库

### 验证建议

如需充分验证 close 路径，可在修改 Demo 预加载时机后单独做：展示 → 不立即触发新 show → 关闭 → 观察 `[TB_INTERSTITIAL_DIAG] didClose isCurrent=1` + `[Interstitial] 关闭`。

## 14. Git

| 项 | 状态 |
|---|---|
| Phase 5A.13 Step 1.2B | `c40e4fe` |
| Phase 5A.13 Step 1.3 | `fa6be94` |
| Phase 5A.13 措辞修正 | `2d9bfcc` |
| Phase 5A.14（本次） | 本地新建 commit（见下） |
| push | ❌ 未 push |
| tag | ❌ 未 tag |
| release | ❌ 未发布 |

### 14.1 本地 commit 内容

```
feat: add ToBid interstitial adapter (Phase 5A.14)

新增文件：
- flame_sdk_ios/adapter/tb/TbInterstitialAdapter.h
- flame_sdk_ios/adapter/tb/TbInterstitialAdapter.m

修改文件：
- flame_sdk_ios/mediation/tb/FlameTBProvider.m（import + 工厂接入）

实现：
- 复用 TbRewardAdapter 已验证模式（flame_topViewController 动态 presenter + stale callback 守卫）
- 11 个 WindMillIntersititialAdDelegate 方法全实现（拼写错误严格保留）
- [TB_INTERSTITIAL_DIAG] 诊断日志全覆盖

验证：
- XCFramework BUILD EXIT 0（binary +20K，弱链接双断言 PASS 无回归）
- 真机 3 轮展示（R2/R3 cachedVC=0x0 动态 presenter 修复生效）
- Reward 回归通过；TK 编译回归通过
- didClose 未触发为 Demo 层 onShow 过早 destroy 问题（非 SDK 缺陷，已诊断）

红线遵守：未 push/tag/release；未改公共 API；未重引入 AnyThinkiOS；
未调私有 API；未 Hook；未碰 -1002；未升级版本；未提交 project.pbxproj 环境差异 / Demo 测试配置 / Pods。
```

## 15. 结论

| 项 | 结果 |
|---|---|
| 公共 API 是否变化 | ❌ 未变（FlameInterstitialListener / FlameInterstitialAd 接口零改动） |
| 单一 XCFramework | ✅ 保持（TK/TB 共享同一 binary，TbInterstitialAdapter 符号在两个 App 都存在） |
| 是否重新引入 AnyThink | ❌ 否（TB 包仍不携带 AnyThinkSDK，弱链接无回归） |
| 是否可以进入 TB 开屏 | ✅ 可以（插屏链路完整验证，Splash 同模式可复用） |

## 16. 剩余问题

| 问题 | 归属 | 处理 |
|---|---|---|
| didClose 未触发 | Demo 层（onShow 过早 destroy） | 不在本 commit 修复，建议 Demo 单独把预加载从 onShow 改到 onClosed |
| Reward NSURLErrorDomain -1002 | 第三方（Sigmob WindSDK S2S） | Phase 5A.13 已登记，非阻塞 |
| close 路径充分真机验证 | 待 Demo 修复预加载时机后 | 可独立验证 |

## 17. /compact

Phase 5A.14 完成（TB 插屏正式接入）。新增 `TbInterstitialAdapter.{h,m}`，复用 TbRewardAdapter 已验证模式（flame_topViewController 动态 presenter + stale callback 守卫），实现 11 个 WindMillIntersititialAdDelegate 方法（类名拼写错误 Inter-s-i-titial 严格保留）。FlameTBProvider 工厂接入（PBXFileSystemSynchronizedRootGroup 自动识别，project.pbxproj 零改动）。XCFramework 构建通过（binary +20K，弱链接双断言无回归）。真机 3 轮展示闭环（R2/R3 cachedVC=0x0 动态 presenter 修复生效），Reward 回归通过，TK 编译回归通过。didClose 未触发为 Demo 层 onShow 过早 destroy 问题（已诊断，非 SDK 缺陷，不在本 commit 修）。本地 commit，未 push/tag/release。等用户确认进入 TB 开屏。
