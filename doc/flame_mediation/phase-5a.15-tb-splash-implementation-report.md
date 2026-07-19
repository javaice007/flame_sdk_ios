# Phase 5A.15：TB 开屏广告（Splash）接入实施报告

> 本报告记录 Phase 5A.15：ToBid (WindMill) 开屏广告 Adapter 接入与真机验证。
> 验收口径严格区分 **实现（代码）** / **静态审计** / **真机实测** 三档，未做专项实测的异常场景不写成"已验证"。

> **修订记录（Phase 5A.15.1，docs 收口）**：初版（commit `0d13dd5`）R3/Reward/TK 三项均为"未完成/留待后续"。Phase 5A.15.1 补齐：(1) R3 真正独立冷启动通过（见 §20 修订）；(2) Reward 完整展示回归通过（两轮闭环，见 §25 修订）；(3) TK 干净 pod install + BUILD SUCCEEDED（见 §26 修订）。本报告相应章节已用真实数据替换初版表述，§30 结论已更新为"Phase 5A.15 正式完成"。



---

## 1. 基线

| 项 | 值 |
|---|---|
| SDK 仓库路径 | `/Users/khj/Documents/code/97_ad/ios/flame_ios_sdk` |
| Demo 仓库路径 | `/Users/khj/Documents/code/97_ad/ios/adsurge-ios-demo` |
| SDK 分支 | `release/ios-dual-line` |
| SDK 开始 HEAD | `4c101d0`（Phase 5A.14.1 收口） |
| SDK 结束 HEAD | 本阶段本地 commit（见 §28） |
| Demo 开始 HEAD | `11c5958`（Phase 5A.14.1 Demo 预加载时机修正） |
| Demo 结束 HEAD | `11c5958`（**Demo 代码零改动**，仅本地临时填入 TB Splash 测试 placementId） |
| 工作区 | SDK：`project.pbxproj` 环境性 UUID 差异（严格排除）；Demo：Pods/Podfile.lock/xcworkspace 由 pod install 重建（排除） |

前置阶段已完成：
- Phase 5A.13：AnyThink 弱链接 + TK/TB 依赖隔离
- Phase 5A.14：TB 插屏 Adapter 接入
- Phase 5A.14.1：Demo 插屏预加载时机修正（onShow→load 改为 onClosed→load）+ 验收口径修正

---

## 2. Flame Splash 接口审计

### 2.1 `FlameSplashAdapterProtocol`（内部协议，`flame_sdk_ios/mediation/FlameSplashAdapterProtocol.h`）

全部 `@required`：

```objc
- (void)load;
- (void)loadWithUserId:(NSString *)userId userCustomData:(NSString *)userCustomData;
- (BOOL)isReady;
- (BOOL)isLoading;
- (void)show:(UIWindow *)window;   // ← 取 UIWindow*（与 Reward/Interstitial 的无参 show 不同）
- (void)destroy;
```

### 2.2 `FlameSplashListener`（对外回调协议，`flame_sdk_ios/ads/splash/FlameSplashAd.h`）

全部 `@optional`：

| 方法 | 语义 |
|---|---|
| `onAdLoaded` | 加载成功 |
| `onAdShow` | 展示成功（已曝光） |
| `onAdClicked` | 点击 |
| `onAdClosed` | 关闭（**skip 与倒计时关闭都坍缩到此处**） |
| `onAdError:desc:` | 错误 |
| `onAdShowComplete:userId:userCustomData:` | 展示完成（AnyThink 的 dismiss_type==3 倒计时专用，WindMill 无对应） |
| `onAdLoadTimeout` | 加载超时（AnyThink 专用，WindMill 无对应） |
| `onAdReward:userId:userCustomData:` | 奖励（splash 无 reward 语义，不调用） |

**关键缺口**：Flame 的 Splash listener **没有** `onAdSkip` / `onAdWillClose` / `onAdDidClose` / `onAdDidVisible` / `onAdShowFailed` 独立回调。ToBid 的 `onSplashAdSkiped:` 与 `onSplashAdClosed:` 必须收敛到同一个 `onAdClosed`，用幂等机制保证只通知一次（见 §10）。

### 2.3 `FlameSplashAd` 工厂（`FlameSdk.createSplashAd...`）

```objc
+ (id<FlameSplashAd>)createSplashAdWithViewController:(UIViewController *)viewController
                                          placementId:(NSString *)placementId
                                             listener:(id<FlameSplashListener>)listener;
```

调用链：`FlameSdk.createSplashAd` → `Router.currentProvider` → `FlameTBProvider.createSplashAdapter...` → 返回 `id<FlameSplashAdapterProtocol>` → 包成 `FlameSplashAdImpl`。

`listener` 同一个引用同时传给 adapter 和 Impl，两层共享。

---

## 3. TK Splash 实现（参考，不改）

`flame_sdk_ios/adapter/tk/AtSplashAdapter.{h,m}`：
- 用 `ATAdManager` 共享管理器，不持有 ad 对象指针（按 placementId 查询）
- `show:` 取运行时 `window` 参数，presenter 用 init 时缓存的 `self.viewController`
- skip (dismiss_type==2) → `onAdClosed`；倒计时 (dismiss_type==3) → `onAdShowComplete` + `onAdClosed`
- 错误码：`@"AD_NOT_READY"`、`@"INVALID_PARAMETER"`、`ERROR_CODE_INVALID_AD_PLACEMENT`
- **无诊断日志标签**（与 TB adapter 的 `[TB_*_DIAG]` 约定不同）

---

## 4. ToBid 5.5.6 公开 API（WindMillSplashAd）

来源：`Pods/ToBid-iOS-RC/.../WindMillSDK.framework/Headers/WindMillSDK.h:2376-2480`

### 4.1 类与初始化

```objc
@interface WindMillSplashAd : WindMillAd
@property (nonatomic, readonly, copy) NSString *placementId;
@property (nonatomic, weak) id<WindMillSplashAdDelegate> delegate;
@property (nonatomic, weak) UIViewController *rootViewController;   // host VC
@property (nonatomic, readonly) BOOL ready;
- (BOOL)isAdReady;
- (instancetype)initWithRequest:(WindMillAdRequest *)request;
- (instancetype)initWithRequest:(WindMillAdRequest *)request extra:(NSDictionary *)extra;
```

### 4.2 加载与展示（**与 Reward/Interstitial 关键不同**）

```objc
- (void)loadAd;                                   // ← 加载（不是 loadAdData）
- (void)loadAdAndShow;                            // 组合（本 adapter 不用）
- (void)loadAdAndShowWithBottomView:(UIView *)bottomView;
- (void)showAdInWindow:(UIWindow *)window;        // ← 展示取 UIWindow*
- (void)showAdInWindow:(UIWindow *)window withBottomView:(UIView *)bottomView;
- (void)showAdInWindow:(UIWindow *)window title:(NSString *)title desc:(NSString *)desc;
```

`WindMillAdRequest` 只设 `placementId`（与 Interstitial 一致，userId/customData 是激励专用）。

### 4.3 `WindMillSplashAdDelegate`（全部 @optional，14 个方法）

注意以下命名按头文件原样（拼写错误保留）：

| 方法 | 说明 |
|---|---|
| `onSplashAdDidLoad:` | 加载成功 |
| `onSplashAdLoadFail:error:` | 加载失败（label `error:`） |
| `onSplashAdWillPresentScreen:` | 即将曝光 |
| `onSplashAdSuccessPresentScreen:` | 曝光成功（→ onAdShow） |
| `onSplashAdFailToPresent:withError:` | 展示失败（label `withError:`） |
| `onSplashAdClicked:` | 点击 |
| `onSplashAdSkiped:` | **跳过（单 p，原文如此）** |
| `onSplashAdWillClosed:` | **即将关闭（过去式，原文如此）** |
| `onSplashAdClosed:` | 关闭 |
| `onSplashAdViewControllerDidClose:` | VC 关闭（CSJ 专用） |
| `onSplashAdWillPresentFullScreenModal:` | 全屏详情（groMore csj gdt） |
| `onSplashAdDidCloseOtherController:interactionType:` | 关闭其他控制器（groMore csj） |
| `onSplashAdAdDidAutoLoad:` | **自动加载成功（双 Ad，原文如此）** |
| `onSplashAd:didAutoLoadFailWithError:` | 自动加载失败 |

**无 timeout API**：`WindMillSDK.h` 全文 grep `tolerateTimeout` 零命中，`onAdLoadTimeout` 在 TB 侧无法触发。

---

## 5. 回调映射表

| Flame (`FlameSplashListener`) | ToBid (`WindMillSplashAdDelegate`) | 处理 |
|---|---|---|
| `onAdLoaded` | `onSplashAdDidLoad:` | stale 守卫 → 调用 |
| `onAdError:desc:` | `onSplashAdLoadFail:error:` | code=`%ld` of error.code（fallback `14001`），desc=localizedDescription |
| `onAdError:desc:` | `onSplashAdFailToPresent:withError:` | show 失败，同上 code/desc 规则 |
| `onAdShow` | `onSplashAdSuccessPresentScreen:` | stale 守卫 → 调用 |
| —（仅日志） | `onSplashAdWillPresentScreen:` | log `[TB_SPLASH_DIAG] willPresent` |
| `onAdClicked` | `onSplashAdClicked:` | stale 守卫 → 调用（**click 不视为 close**） |
| —（坍缩到 onAdClosed） | `onSplashAdSkiped:` | **finishOnce("skip")** → onAdClosed |
| —（仅日志） | `onSplashAdWillClosed:` | log `[TB_SPLASH_DIAG] willClose` |
| `onAdClosed` | `onSplashAdClosed:` | **finishOnce("close")** → onAdClosed |
| —（no-op） | `onSplashAdViewControllerDidClose:` | 空（CSJ 专用） |
| —（no-op） | `onSplashAdWillPresentFullScreenModal:` | 空 |
| —（no-op） | `onSplashAdDidCloseOtherController:interactionType:` | 空（CSJ 专用） |
| —（no-op） | `onSplashAdAdDidAutoLoad:` | 空 |
| —（no-op） | `onSplashAd:didAutoLoadFailWithError:` | 空 |
| `onAdShowComplete:` | **（无对应）** | 不调用（WindMill 无倒计时完成回调） |
| `onAdLoadTimeout` | **（无对应）** | 不调用（WindMill 无 timeout 回调） |
| `onAdReward:` | **（无对应）** | 不调用（splash 无 reward） |

---

## 6. Adapter 实现

### 6.1 文件

| 文件 | 行数 | 说明 |
|---|---|---|
| `flame_sdk_ios/adapter/tb/TbSplashAdapter.h`（新增） | — | 镜像 `TbInterstitialAdapter.h`，前向声明 `WindMillSplashAd` / `WindMillSplashAdDelegate` |
| `flame_sdk_ios/adapter/tb/TbSplashAdapter.m`（新增） | — | 实现 `FlameSplashAdapterProtocol` + `WindMillSplashAdDelegate`（14 方法全实现） |

### 6.2 与 Reward/Interstitial 的关键差异

| 维度 | Reward / Interstitial | **Splash** |
|---|---|---|
| 加载方法 | `[ad loadAdData]` | **`[ad loadAd]`** |
| 展示方法 | `[ad showAdFromRootViewController:vc options:@{}]` | **`[ad showAdInWindow:window withBottomView:nil]`** |
| show 参数来源 | 动态 `flame_topViewController()` | **协议 `show:(UIWindow *)window`**（Demo 传入 LaunchScreenWindow / keyWindow） |
| 关闭语义 | 单一 didClose → onAdClosed | **skip + close 收敛**：`onSplashAdSkiped` + `onSplashAdClosed` → `finishOnce` → onAdClosed |
| topVC 辅助函数 | 需要（show 时 VC 可能失效） | **不需要**（show 不取 VC，window 由 Demo 管理） |

### 6.3 stale callback 守卫（与 Interstitial 同模式）

每个回调：`if (splashAd != self.splashAd) { log "stale callback ignored"; return; }`
（指针身份判断：每次 loadWithUserId: 清旧 delegate + 新建对象，旧对象迟到回调必失败）

### 6.4 finishOnce 幂等机制（§7.3 重点）

```objc
- (void)finishOnceWithReason:(NSString *)reason {
    if (_didFinish) {
        [FlameLogger w:[NSString stringWithFormat:@"[TB_SPLASH_DIAG] finish already done: reason=%@ ad=%p", reason, self.splashAd]];
        return;
    }
    _didFinish = YES;
    [FlameLogger i:[NSString stringWithFormat:@"[TB_SPLASH_DIAG] finish: reason=%@ ad=%p", reason, self.splashAd]];
    if (self.listener && [self.listener respondsToSelector:@selector(onAdClosed)]) {
        [self.listener onAdClosed];
    }
}
```

- `onSplashAdSkiped:` → `finishOnce("skip")`
- `onSplashAdClosed:` → `finishOnce("close")`
- `onSplashAdClicked:` **不调** finishOnce（click ≠ close）
- 每次 `loadWithUserId:` 重置 `_didFinish = NO`
- `destroy` 也清零

---

## 7. Window 解析

**Splash 的 window 由 Demo 提供，Adapter 内不做 Window 解析**：
- Demo `SplashAdManager.show()` 取 `LaunchScreenWindow.shared`（冷启动）或 `getKeyWindow()`（热启动）
- Adapter `show:(UIWindow *)window` 守卫：
  - `if (!splashAd || !splashAd.isAdReady)` → `onAdError:@"AD_NOT_READY"`
  - `if (window == nil)` → `onAdError:@"INVALID_PARAMETER"`（镜像 AtSplashAdapter）
- 然后直接 `[splashAd showAdInWindow:window withBottomView:nil]`

**红线遵守**：不通过固定 sleep 掩盖 Window 就绪问题（Demo `SplashAdManager` 自己有 0.5s 重试逻辑，Adapter 不重复造）。

---

## 8. 冷启动时序（真机实测）

基于 R1（看完倒计时关闭）真机日志 `pasted-text-20260719-230133-935a61ee.txt`：

```
23:01:20.576  [SDK_INIT] 初始化开始
23:01:20.984  [SDK] 初始化完成
23:01:21.087  ■ 初始化成功 | 耗时 0.511s     ← pt=tb，Router 激活 FlameTBProvider
23:01:21.091  [Splash] 创建广告实例
23:01:21.091  [Splash] 开始加载
23:01:21.093  [FlameSDK] Start loading Splash Ad
23:01:21.094  [TB_SPLASH_DIAG] load: adapter=0x11af57d50 oldAd=0x0 placementId=8374774642581842 thread=1
23:01:21.095  [TB_SPLASH_DIAG] load created: adapter=0x11af57d50 newAd=0x11aed3e80
23:01:22.022  [TB_SPLASH_DIAG] didLoad: ad=0x11aed3e80 adapter=0x11af57d50 isCurrent=1  ← 1s 内加载成功
23:01:22.022  [Splash][trace] #1 +1083ms onAdLoaded
23:01:22.022  [TB_SPLASH_DIAG] show: adapter=0x11af57d50 ad=0x11aed3e80 window=0x106102fa0 thread=1 ready=1
23:01:22.022  [TB_SPLASH_DIAG] willPresent: ad=0x11aed3e80 isCurrent=1
23:01:22.022  [TB_SPLASH_DIAG] didPresent(didVisible): ad=0x11aed3e80 isCurrent=1
23:01:22.089  [Splash][trace] #1 +67ms onAdShow
23:01:22.242  [Splash] 展示
23:01:28.028  [TB_SPLASH_DIAG] willClose: ad=0x11aed3e80 isCurrent=1   ← ~6s 倒计时
23:01:28.028  [TB_SPLASH_DIAG] didClose: ad=0x11aed3e80 adapter=0x11af57d50 isCurrent=1
23:01:28.028  [TB_SPLASH_DIAG] finish: reason=close ad=0x11aed3e80     ← finish 第一次（仅一次）
23:01:28.207  [Splash][trace] #2 +6094ms onAdClosed                     ← 业务 onAdClosed 一次
23:01:28.270  [Splash] 关闭
23:01:28.277  [Coordinator] 开始预加载所有广告                           ← 主页面切换正常
```

placementId 映射：`q<REDACTED>`（Demo 本地配置，不提交）→ `8374774642581842`（后台下发，pMap 解析）。

**R1 关键确认**：
- `window=0x106102fa0` 非空（Demo LaunchScreenWindow 已就绪）
- `thread=1`（主线程）
- `ready=1`（show 前 isAdReady 通过）
- `isCurrent=1`（adapter 未被替换，无 stale）
- `finish` 仅执行一次（reason=close）
- 关闭后 Coordinator 正常预加载下一条 → 主页面切换正常
- 无黑屏、无重复 present、无 AnyThink ADX 弹窗

---

## 9. Ready 状态

`isReady` 实现：`if (!self.splashAd) return NO; return self.splashAd.isAdReady;`

真机日志确认：
- `load` 后约 1s 收到 `onSplashAdDidLoad` → `didLoad` → Demo `[Splash] 加载成功`
- `show` 时 `ready=1`（R1 line 135 / R2 line 131）
- 倒计时/skip 后 WindMill 内部 deinit `WindMillSplashAd`，下次 load 新建对象

---

## 10. finish 幂等（§7.3 关键验证 — R2 skip 真机实测）

基于 R2（跳过）真机日志 `pasted-text-20260719-230215-d6104b60.txt`，这是 **skip + close 连续到达**的决定性验证：

```
23:02:07.112  [Splash] 展示
23:02:09.009  [ToBid] onSplashAdSkiped(_:)                          ← Sigmob 先回调 skip
23:02:09.009  [ToBid] onSplashAdClosed(_:)                          ← 紧接着回调 close
23:02:09.009  [TB_SPLASH_DIAG] didSkip: ad=0x124ed3b60 isCurrent=1
23:02:09.009  [TB_SPLASH_DIAG] finish: reason=skip ad=0x124ed3b60   ← finish 第一次（skip 触发）
23:02:09.659  [Splash][trace] #2 +2642ms onAdClosed                 ← 业务 onAdClosed 通知【一次】
23:02:09.685  [Splash] 关闭
23:02:09.686  [TB_SPLASH_DIAG] willClose: ad=0x124ed3b60 isCurrent=1
23:02:09.687  [TB_SPLASH_DIAG] didClose: ad=0x124ed3b60 adapter=0x124f41f20 isCurrent=1
23:02:09.687  [TB_SPLASH_DIAG] finish already done: reason=close ad=0x124ed3b60  ← 【finishOnce 守卫拦下第二次】
```

**关键确认**：
- Sigmob 在用户点击跳过后，**先**触发 `onSplashAdSkiped`，**紧接着**触发 `onSplashAdClosed`（两个都到达）
- Adapter 处理：`didSkip → finishOnce("skip")` → 业务 `onAdClosed` **通知一次**
- 随后 `didClose → finishOnce("close")` 命中 `_didFinish==YES` → **日志 `finish already done: reason=close`**，**不再通知业务**
- 业务侧 `[Splash][trace] onAdClosed` 只出现 1 次
- 主页面切换正常（`[Coordinator] 开始预加载所有广告`）

**这是 §7.3 幂等要求的真机专项验证通过**：skip + close 连续到达，业务完成通知只触发一次。

---

## 11. stale callback 守卫

代码实现：每个回调 `if (splashAd != self.splashAd) { log "stale callback ignored"; return; }`

| 状态 | 说明 |
|---|---|
| 实现 | ✅ 14 个回调全有守卫 |
| 静态审计 | ✅ 通过（与 TbRewardAdapter/TbInterstitialAdapter 同模式，已验证） |
| 真机实测 | ⚠️ **未实际触发**：R1/R2 两次冷启动中 `isCurrent` 全 1，对象替换时机正确，未观察到 stale 守卫命中 |

---

## 12. 错误映射

沿用 TB adapter 内联字符串约定（不引入新常量，不改 FlameErrorCode.h）：

| 场景 | code | desc |
|---|---|---|
| placementId 空（load） | `14004` | `ToBid Splash: placementId is empty` |
| show 未就绪 | `AD_NOT_READY` | `ToBid Splash ad is not ready to show` |
| show window=nil | `INVALID_PARAMETER` | `The 'window' parameter is required and cannot be nil.` |
| 加载失败（NSError） | `%ld` of error.code（fallback `14001`） | `error.localizedDescription` |
| 展示失败（NSError） | `%ld` of error.code（fallback `14001`） | `error.localizedDescription ?: @"ToBid Splash show failed"` |

未新增 `SPLASH_NOT_READY` / `SPLASH_WINDOW_UNAVAILABLE` 等常量（保持与现有 TB adapter 一致）。

---

## 13. Provider 接入

`flame_sdk_ios/mediation/tb/FlameTBProvider.m`：
- 新增 `#import "TbSplashAdapter.h"`（在 `#import "TbInterstitialAdapter.h"` 之后）
- 原 `#pragma mark - Phase 6 占位` 占位 `return nil` 改为：
  ```objc
  TbSplashAdapter *adapter = [[TbSplashAdapter alloc] initWithViewController:viewController
                                                                placementId:placementId
                                                                    listener:listener];
  return adapter;
  ```
- 其他占位（Banner / Native）保持 `return nil`
- **不动** +load 注册逻辑、Router 语义

---

## 14. Demo 调用时序

**Demo 代码零改动**（用户已确认）。Demo `SplashAdManager` 已通过通用 `FlameSdk.createSplashAd(with:placementId:listener:)` 创建，自动 `onAdLoaded → show(window) → onAdClosed → 主页面切换`。

仅本地临时改动（**不提交**）：
- `Sources/Ad/FlameAdConfig.swift:45`：`splash = ""` → `splash = "q<REDACTED>"`（测试 placementId）

Demo 冷启动时序（真机日志确认）：
1. `LaunchScreenWindow.show()` + `sdkManager.initialize()`
2. SDK init success → `SplashAdManager.loadWhenSdkReady()`
3. `loadAndShow()` → `FlameSdk.createSplashAd` → `TbSplashAdapter` → `loadAd`
4. `onSplashAdDidLoad` → `[Splash] 加载成功` → `show(window)` → `showAdInWindow:`
5. `onSplashAdSuccessPresentScreen` → `onAdShow` → `[Splash] 展示`
6. 倒计时/skip → `onAdClosed` → `[Splash] 关闭` → `.splashAdFinished` 通知 → 主页面

---

## 15. 构建结果

`./xcFramework_build.sh`：

| 检查 | 结果 |
|---|---|
| 双 Archive | ✅ ARCHIVE SUCCEEDED（device + simulator） |
| XCFramework 生成 | ✅ `build/flame_sdk_ios.xcframework` |
| AnyThink weak patch | ✅ 幂等通过 |
| 二进制体积 | 324K |

### 15.1 符号校验（两 slice）

| 符号 | sim (x86_64) | device (arm64) |
|---|---|---|
| `TbSplashAdapter` (NEW) | ✅ `_OBJC_CLASS_$_TbSplashAdapter` | ✅ `_OBJC_CLASS_$_TbSplashAdapter` |
| `TbInterstitialAdapter`（回归） | ✅ | ✅ |
| `TbRewardAdapter`（回归） | ✅ | ✅ |
| `FlameTBProvider` / `FlameTKProvider` | ✅ | ✅ |

### 15.2 诊断字符串（两 slice）

| 字符串 | sim | device |
|---|---|---|
| `TB_SPLASH_DIAG` (NEW) | ✅ 23 条 | ✅ 23 条（全 14 delegate + load/show/finish/stale） |
| `TB_INTERSTITIAL_DIAG`（回归） | ✅ 20 条 | ✅ 20 条 |
| `TB_REWARD_DIAG`（回归） | ✅ 11 条 | ✅ 11 条 |
| `TK_PLATFORM_REQUIRES_ANYTHINK`（回归） | ✅ | ✅ |

---

## 16. AnyThink weak 断言（无回归）

| 检查 | sim | device |
|---|---|---|
| `otool -L` AnyThinkSDK | ✅ `(weak)` 标记 | ✅ `(weak)` 标记 |
| `otool -l` LC command | ✅ `LC_LOAD_WEAK_DYLIB` | ✅ `LC_LOAD_WEAK_DYLIB` |
| Podfile.lock AnyThinkiOS | ✅ 0 命中（absent） | — |
| 真机 ADX 弹窗 | ✅ R1/R2 全程未出现 | — |

---

## 17. TB 依赖树（Podfile.lock）

```
DEPENDENCIES:
  - flame_sdk_ios_tb (from `../flame_ios_sdk`)
  - FunlinkSDK (from `../local_pods/FunlinkSDK`)
  - OpenSSL-Universal (from `/Users/khj/Documents/code/97_ad/ios/local_pods/OpenSSL-Universal`)

SPEC REPOS:
  trunk:
    - ToBid-iOS-RC
```

4 pods installed: `flame_sdk_ios_tb 1.0.0-alpha.4-local`、`ToBid-iOS-RC 5.5.6`、`FunlinkSDK 2.9.0.1.2`、`OpenSSL-Universal 3.6.2000`。
**无 AnyThinkiOS**（TB podspec 不带入）。

---

## 18. R1 冷启动（看完 / 倒计时关闭）

见 §8 完整时序。关键确认：
- ✅ pt=tb（Router 激活 FlameTBProvider）
- ✅ 无 AnyThink ADX 弹窗
- ✅ window 非空（`0x106102fa0`）
- ✅ thread=1
- ✅ ready=1（show 前 isAdReady 通过）
- ✅ 无黑屏、无重复 present
- ✅ 关闭后主界面可交互（Coordinator 预加载下一轮）
- ✅ finish 仅执行一次（reason=close）
- ✅ 完整闭环：load → didLoad → show → willPresent → didPresent(didVisible) → [6s] → willClose → didClose → finish → onAdClosed

---

## 19. R2 跳过（skip + close 幂等验证）

见 §10 完整时序。关键确认：
- ✅ 新 adapter（`0x124f41f20` ≠ R1 `0x11af57d50`）
- ✅ 新 splashAd（`0x124ed3b60` ≠ R1 `0x11aed3e80`）
- ✅ 动态 window 解析成功（`0x1037b6f00`）
- ✅ 正常 visible
- ✅ **手动点击跳过按钮**：Sigmob 先 `onSplashAdSkiped` 后 `onSplashAdClosed`
- ✅ **skip + close 收敛到一次 onAdClosed**（finishOnce 守卫正确拦下第二次 finish）
- ✅ 主页面正常显示

---

## 20. R3 冷启动（Phase 5A.15.1 独立冷启动补齐）

> **修订（Phase 5A.15.1）**：初版本节写"R3 未单独执行（R2 关闭后预热 load 已成功，等价覆盖）"。该表述口径错误——**预热 load 不等于独立冷启动**。Phase 5A.15.1 执行了真正的独立冷启动（完全杀进程后 Xcode Run），替换如下。

**操作**：完全杀掉 Demo App → 等待数秒确认进程退出 → Xcode Run → 等 Splash 独立完成展示 + 关闭。

**完整链路（真机日志 `pasted-text-20260719-232755-54803477.txt`）**：

```
23:27:28.970  [SDK_INIT] 初始化开始
23:27:29.340  [SDK] 初始化完成
23:27:29.417  ■ 初始化成功 | 耗时 0.447s     ← pt=tb，Router 激活 FlameTBProvider
23:27:29.421  [Splash] 创建广告实例
23:27:29.421  [Splash] 开始加载
23:27:29.423  [TB_SPLASH_DIAG] load: adapter=0x10ef0d140 oldAd=0x0 placementId=8374774642581842 thread=1
23:27:29.425  [TB_SPLASH_DIAG] load created: adapter=0x10ef0d140 newAd=0x10eea3c00
23:27:30.030  [TB_SPLASH_DIAG] didLoad: ad=0x10eea3c00 adapter=0x10ef0d140 isCurrent=1
23:27:30.030  [Splash][trace] #1 +906ms onAdLoaded
23:27:30.030  [TB_SPLASH_DIAG] show: adapter=0x10ef0d140 ad=0x10eea3c00 window=0x10618fe40 thread=1 ready=1
23:27:30.030  [TB_SPLASH_DIAG] willPresent: ad=0x10eea3c00 isCurrent=1
23:27:30.030  [TB_SPLASH_DIAG] didPresent(didVisible): ad=0x10eea3c00 isCurrent=1
23:27:30.327  [Splash][trace] #1 +73ms onAdShow
23:27:30.400  [Splash] 展示
23:27:31.031  [ToBid] onSplashAdSkiped(_:)                       ← Sigmob 先回调 skip
23:27:31.031  [ToBid] onSplashAdClosed(_:)                       ← 紧接着回调 close
23:27:31.031  [TB_SPLASH_DIAG] didSkip: ad=0x10eea3c00 isCurrent=1
23:27:31.031  [TB_SPLASH_DIAG] finish: reason=skip ad=0x10eea3c00  ← finish 第一次（skip 触发）
23:27:31.613  [Splash] 关闭                                     ← 业务 onAdClosed 通知【一次】
23:27:31.031  [TB_SPLASH_DIAG] willClose: ad=0x10eea3c00 isCurrent=1
23:27:31.031  [TB_SPLASH_DIAG] didClose: ad=0x10eea3c00 adapter=0x10ef0d140 isCurrent=1
23:27:31.031  [TB_SPLASH_DIAG] finish already done: reason=close  ← 【finishOnce 守卫拦下第二次】
23:27:31.619  [Coordinator] 开始预加载所有广告                  ← 主页面切换正常
```

placementId 映射：`q<REDACTED>`（Demo 本地配置，不提交）→ `8374774642581842`（后台下发，pMap 解析）。

### 20.1 R3 验收项

| 项 | 结果 |
|---|---|
| 是否完全杀进程后重启 | ✅ 是（独立冷启动，不复用 R2 进程） |
| pt | ✅ `tb` |
| Router | ✅ 激活 `tb` |
| adapter | `0x10ef0d140`（新生命周期） |
| ad | `0x10eea3c00` |
| window | ✅ `0x10618fe40`（非空，Demo LaunchScreenWindow） |
| ready | ✅ `1` |
| thread | ✅ `1` |
| willPresent | ✅ 到达（isCurrent=1） |
| didPresent(didVisible) | ✅ 到达（isCurrent=1） |
| close/skip | ✅ skip 路径（Sigmob 先 `onSplashAdSkiped` 后 `onSplashAdClosed`） |
| finish reason | `skip` |
| finish 通知次数 | ✅ **1 次**（第二次 `finish already done: reason=close` 被守卫拦截） |

### 20.2 用户肉眼确认项（人工）

| 项 | 结果 |
|---|---|
| AnyThink ADX 弹窗 | ✅ 未出现 |
| Splash 黑屏 | ✅ 否 |
| Splash 内容正常显示 | ✅ 是 |
| Splash 重复展示 | ✅ 否 |
| Splash 关闭后主页面正常显示 | ✅ 是 |
| 主页面可正常交互 | ✅ 是 |
| 卡在启动页 | ✅ 否 |
| 闪退 | ✅ 未发生 |
| skip + close 到达，finishOnce 仅通知业务一次 | ✅ 是 |

### 20.3 R3 地址判断

> 不以裸 ad 指针值判断对象是否为"同一对象"——对象释放后地址可能被内存分配器复用。R3 判定依据：**新的 App 冷启动** + **新的 Adapter 生命周期**（`0x10ef0d140` ≠ R2 `0x124f41f20` ≠ R1 `0x11af57d50`）+ **新的 load created** + **`isCurrent=1`** + **finish 生命周期重新开始**。

### 20.4 R1/R2/R3 对照

| 项 | R1 | R2 | R3 |
|---|---|---|---|
| 冷启动 load → didLoad | ✅ | ✅ | ✅ |
| show → didVisible | ✅ | ✅ | ✅ |
| 关闭路径 | ✅ 倒计时 close | ✅ skip + close 幂等 | ✅ skip + close 幂等（finishOnce 二次拦截） |
| 主页面恢复 | ✅ | ✅ | ✅ |

**三次冷启动全部通过**。R2/R3 均为 skip 路径，且都验证了 finishOnce 二次拦截生效。

---

## 21. 未就绪 show（异常场景 A）

| 维度 | 状态 |
|---|---|
| 代码实现 | ✅ `show:` 入口 `if (!splashAd || !splashAd.isAdReady)` → `onAdError:@"AD_NOT_READY"` |
| 静态审计 | ✅ 通过（镜像 AtSplashAdapter/TbInterstitialAdapter） |
| 真机实测 | ⚠️ **未专项触发**：R1/R2 中 Splash 均在 ~1s 内 ready，未构造"未就绪时点击 show"的场景 |

---

## 22. 重复 show（异常场景 B）

| 维度 | 状态 |
|---|---|
| 代码实现 | ✅ `isReady` 守卫（show 后 WindMill 内部置 ready=false）；`finishOnce` 防重复回调 |
| 静态审计 | ✅ 通过 |
| 真机实测 | ⚠️ **未专项触发**：R1/R2 均为正常顺序单次 show，未在同一 Splash 上快速双击 show |

---

## 23. skip/close 幂等（异常场景 C）

| 维度 | 状态 |
|---|---|
| 代码实现 | ✅ `finishOnceWithReason:` + `_didFinish` 标记 |
| 静态审计 | ✅ 通过 |
| **真机实测** | ✅ **专项验证通过**（R2，见 §10）：Sigmob 先 `onSplashAdSkiped` 后 `onSplashAdClosed`，finishOnce 守卫正确拦下第二次 finish，业务 `onAdClosed` 只通知一次 |

**这是本阶段唯一真机专项验证通过的异常场景**。

---

## 24. 插屏回归

基于 R1 日志（line 185-198, 246-248）与 R2 日志（line 191-203, 260-262）：

```
[Interstitial] 开始加载
[TB_INTERSTITIAL_DIAG] load: adapter=0x1274e8720 oldAd=0x0 placementId=9690693976929807 thread=1
[TB_INTERSTITIAL_DIAG] load created: adapter=0x1274e8720 newAd=0x1274bd7a0
[TB_INTERSTITIAL_DIAG] didLoad: ad=0x1274bd7a0 adapter=0x1274e8720 isCurrent=1
[Interstitial] 加载成功
```

| 项 | 结果 |
|---|---|
| 插屏 load | ✅ 通过 |
| 插屏 didLoad | ✅ 通过（isCurrent=1） |
| 插屏 show/didClose | ⚠️ 本轮未触发展示（Splash 关闭后 Coordinator 仅预加载，未自动 show 插屏） |

**结论**：Phase 5A.14.1 Demo 修正未回归（插屏加载链路正常）。完整 show/close 回归沿用 Phase 5A.14.1 R1/R2 已验证结论。

---

## 25. Reward 完整回归（Phase 5A.15.1 补齐）

> **修订（Phase 5A.15.1）**：初版本节写"仍为仅加载回归通过，未补齐 show/close"。Phase 5A.15.1 在 R3 同一次 TB 真机运行中手动触发了两次 Reward 展示，取得完整闭环证据，**Reward 完整展示回归通过**。

基于真机日志 `pasted-text-20260719-232755-54803477.txt`（R3 冷启动后续运行）。

### 25.1 第一轮（23:27:38~23:27:41）

```
23:27:31.632  [RewardVideo] 开始加载                         ← R3 主页面后 Coordinator 预加载
23:27:31.031  [TB_REWARD_DIAG] load: adapter=0x12491d290 oldAd=0x0 placementId=1886359231652093 thread=1
23:27:31.031  [TB_REWARD_DIAG] load created: adapter=0x12491d290 newAd=0x1248b0a20
23:27:32.032  [TB_REWARD_DIAG] didLoad: ad=0x1248b0a20 adapter=0x12491d290 isCurrent=1
23:27:32.094  [RewardVideo] 加载成功
23:27:38.038  [TB_REWARD_DIAG] show: adapter=0x12491d290 ad=0x1248b0a20 presenter=0x10c2d0000 vcWindow=0x106193f30 cachedVC=0x10c2d0000 thread=1
23:27:38.038  [TB_REWARD_DIAG] willVisible: ad=0x1248b0a20
23:27:39.039  [TB_REWARD_DIAG] didVisible: ad=0x1248b0a20
23:27:39.379  [RewardVideo] 展示
23:27:41.041  [ToBid] rewardVideoAdDidClose(_:)
23:27:41.041  [TB_REWARD_DIAG] willClose: ad=0x1248b0a20
23:27:41.041  [TB_REWARD_DIAG] didClose: ad=0x1248b0a20 adapter=0x12491d290
23:27:41.117  [RewardVideo] 关闭 → 加载下一个
23:27:41.041  [TB_REWARD_DIAG] load: adapter=0x13c3bca80 oldAd=0x0 placementId=1886359231652093 thread=1
23:27:41.041  [TB_REWARD_DIAG] load created: adapter=0x13c3bca80 newAd=0x13c368ae0
23:27:41.318  [RewardVideo] 加载成功（第二轮 didLoad isCurrent=1）
```

### 25.2 第二轮（23:27:42~23:27:44，证明 close→next load 循环未断）

```
23:27:41.318  [RewardVideo] 加载成功                          ← 上一轮关闭后自动加载
23:27:42.042  [TB_REWARD_DIAG] show: adapter=0x13c3bca80 ad=0x13c368ae0 presenter=0x10c2d0000 vcWindow=0x106193f30 cachedVC=0x0 thread=1
23:27:42.042  [TB_REWARD_DIAG] willVisible: ad=0x13c368ae0
23:27:42.042  [TB_REWARD_DIAG] didVisible: ad=0x13c368ae0
23:27:42.878  [RewardVideo] 展示
23:27:44.044  [ToBid] rewardVideoAdDidClose(_:)
23:27:44.044  [TB_REWARD_DIAG] willClose: ad=0x13c368ae0
23:27:44.044  [TB_REWARD_DIAG] didClose: ad=0x13c368ae0 adapter=0x13c3bca80
23:27:44.138  [RewardVideo] 关闭 → 加载下一个
23:27:44.044  [TB_REWARD_DIAG] load: adapter=0x13c3091a0 newAd=0x13c36a0a0
23:27:44.341  [RewardVideo] 加载成功（第三轮 didLoad isCurrent=1）
```

### 25.3 Reward 验收项

| 项 | 第一轮 | 第二轮 |
|---|---|---|
| load → load created → didLoad | ✅ isCurrent=1 | ✅ isCurrent=1 |
| show | ✅ presenter=`0x10c2d0000`（**非空**） | ✅ presenter=`0x10c2d0000`（**非空**） |
| vcWindow | ✅ `0x106193f30`（**非空**） | ✅ `0x106193f30`（**非空**） |
| thread | ✅ `1` | ✅ `1` |
| willVisible | ✅ | ✅ |
| didVisible | ✅ | ✅ |
| didClose | ✅ adapter=0x12491d290 | ✅ adapter=0x13c3bca80 |
| `[RewardVideo] 关闭 → 加载下一个` | ✅ | ✅ |
| next load → next load created → next didLoad | ✅ isCurrent=1 | ✅ isCurrent=1 |
| 奖励回调 | ⚠️ 本轮未出现（非强制项） | ⚠️ 本轮未出现（非强制项） |

**补充观察**：第二轮 show 时 `cachedVC=0x0`（Demo 重建 adapter 时传入 nil），但 `presenter=0x10c2d0000` 非空——`flame_topViewController()` 动态解析到稳定 presenter，**与 Interstitial 同款动态 presenter 修复在 Reward 场景同样生效**。

### 25.4 下一轮对象判断

> 不强制要求"下一条 Reward ad 地址必须不同"——对象地址可能被系统复用。验收以 **didClose 后 Demo 触发下一轮 load** + **新的 load 日志** + **新的 load created** + **新的 didLoad** + **`isCurrent=1`** + **下一轮无 stale callback 污染** 为准。本轮两轮均满足。

### 25.5 Reward 回归结论

✅ **Reward 完整展示回归通过**：`load → show → didVisible → didClose → next load → next didLoad`（两轮闭环，presenter/vcWindow 非空，thread=1，循环未断）。

奖励回调本轮未出现（非强制项，不阻塞验收）。

---

## 26. TK 编译回归（Phase 5A.15.1 补齐）

> **修订（Phase 5A.15.1）**：初版本节写"本轮未执行 TK 编译回归"。Phase 5A.15.1 完成了 TK 干净 pod install + xcodebuild，结果如下。**本阶段后续未再修改 SDK 二进制或 podspec，不重复执行**（Phase 5A.15.1 v2 §二）。

### 26.1 操作

Demo Podfile 临时切到 TK（`pod 'flame_sdk_ios', :path => '../flame_ios_sdk'`，保留本地 OpenSSL/Funlink + post_install 签名设置），执行：
```
pod deintegrate || true
rm -rf Pods Podfile.lock
find . -maxdepth 1 -name "*.xcworkspace" -exec rm -rf {} +
pod install
xcodebuild -workspace adshurge-ios-demo.xcworkspace -scheme adshurge-ios-demo \
  -configuration Debug -sdk iphoneos CODE_SIGNING_ALLOWED=NO build
```
验证完成后恢复 Podfile 到 TB + 重新 pod install（4 pods）。

### 26.2 验收项

| 检查项 | 结果 |
|---|---|
| TK pod install | ✅ 通过，28 pods |
| `flame_sdk_ios` | 1.0.0-alpha.4-local |
| `AnyThinkiOS` | 6.5.71 |
| `flame_sdk_ios_tk_sigmob_adapter` | 4.20.12.2.0 |
| `ToBid-iOS-RC` | 5.5.6 |
| `OpenSSL-Universal` | 3.6.2000 |
| Podfile.lock 是否包含 `flame_sdk_ios_tb` | ❌ 否（TK 构建正确不带入 TB pod） |
| `xcodebuild ... build` | ✅ **BUILD SUCCEEDED** |
| AnyThinkSDK.framework 进入 TK App | ✅ `App/Frameworks/AnyThinkSDK.framework` 存在 |
| flame_sdk_ios.framework 进入 TK App | ✅ 存在 |
| Flame binary 对 AnyThink 链接方式 | ✅ **LC_LOAD_WEAK_DYLIB**（`otool -l` 确认；`otool -L` 显示 `(weak)`） |
| TK guard | ✅ 二进制含 `TK_PLATFORM_REQUIRES_ANYTHINK` 常量（已编入） |
| Demo 环境恢复 | ✅ 已恢复 TB（4 pods） |

### 26.3 AnyThink 表述（按 Phase 5A.15.1 §6.1）

> ❌ 不写"TK 构建中 AnyThink 强加载"。
>
> ✅ 正确写法：**TK podspec 负责将 AnyThinkSDK.framework 带入并嵌入 App；Flame binary 对 AnyThinkSDK 仍保持 LC_LOAD_WEAK_DYLIB。** 即 TK App 的 AnyThinkSDK 是通过 podspec 嵌入 + 系统加载（运行时 dyld 解析），Flame 二进制本身对它只是弱链接声明（TB App 缺该 framework 时不崩溃，TK App 有该 framework 时正常解析）。

### 26.4 TK guard 表述（按 Phase 5A.15.1 §6.2）

> ❌ 不写"二进制有 guard 字符串，因此本轮 guard 未触发"——字符串存在只能证明守卫代码已编入，不能证明运行时未触发。
>
> ✅ 正确写法：**TK guard 已编入二进制；本轮 TK 验证只做 pod install / 编译 / App Framework 审计 / 二进制链接审计，未重新执行 TK 真机初始化。Phase 5A.13 Step 1.3 的 TK 真机验证中 ATAPI 守卫通过，未出现 `TK_PLATFORM_REQUIRES_ANYTHINK`。**

### 26.5 第三方 warning（按 Phase 5A.15.1 §6.3）

构建过程的 warning 全部来自第三方 SDK（AnyThinkiOS/ToBid/KSAdSDK/GDTMobSDK 等）的 `IPHONEOS_DEPLOYMENT_TARGET` 配置（如 KSAdSDK 设为 9.0、OctopusSDK 设为 11.0 等），与 Flame 修改无关。

> ✅ 正确写法：**构建通过；warning 来自第三方 SDK 的 deployment target 配置，本轮未发现由 Flame 修改引起的新编译错误。**（不对所有第三方 warning 逐项下"无影响"结论。）

### 26.6 TK 编译回归结论

✅ **TK 干净 pod install + 编译回归通过**：28 pods、BUILD SUCCEEDED、AnyThinkSDK 进入 App、Flame binary 保持 weak link、TK guard 已编入（真机 guard 未触发沿用 Phase 5A.13 Step 1.3 结论）。

---

## 27. 文件修改

### 27.1 Phase 5A.15（commit `0d13dd5`）

| 文件 | 类型 | 说明 |
|---|---|---|
| `flame_sdk_ios/adapter/tb/TbSplashAdapter.h` | 新增 | 镜像 TbInterstitialAdapter.h |
| `flame_sdk_ios/adapter/tb/TbSplashAdapter.m` | 新增 | FlameSplashAdapterProtocol + WindMillSplashAdDelegate（14 方法）+ finishOnce 幂等 |
| `flame_sdk_ios/mediation/tb/FlameTBProvider.m` | 修改 | +1 import、占位 return nil → 创建 adapter |
| `doc/flame_mediation/phase-5a.14-tb-interstitial-implementation-report.md` | 修改（§3 前置） | 异常场景口径收紧 + R3 内存复用说明 |
| `doc/flame_mediation/phase-5a.15-tb-splash-implementation-report.md` | 新增 | 本报告（初版） |
| `doc/flame_mediation/09_change_log.md` | 修改 | Phase 5A.15 条目 |
| `README.md` | 修改 | 开屏 ToBid 列 ⏳ → ✅ |

### 27.2 Phase 5A.15.1（docs 收口 commit）

| 文件 | 类型 | 说明 |
|---|---|---|
| `doc/flame_mediation/phase-5a.15-tb-splash-implementation-report.md` | 修改 | §20 R3 独立冷启动、§25 Reward 完整回归、§26 TK 编译回归、§29/§30/§31 收口 |
| `doc/flame_mediation/09_change_log.md` | 修改 | Phase 5A.15.1 条目（R3 / Reward 完整 / TK） |
| `README.md` | 修改 | 补充三项补齐说明 |

**SDK 业务代码零改动**（Phase 5A.15.1 仅文档收口）。
**project.pbxproj 零改动**（PBXFileSystemSynchronizedRootGroup 自动同步）。

---

## 28. Git

### 28.1 Phase 5A.15（commit `0d13dd5`）

**SDK commit**（adapter + provider + 文档）：
- 消息：`feat: add ToBid splash adapter`
- 排除：project.pbxproj 环境差异、Pods、Podfile.lock、xcworkspace、DerivedData、build、Archives、测试 placementId、真机日志、临时脚本

### 28.2 Phase 5A.15.1（docs 收口 commit）

**SDK commit**（仅文档收口，业务代码零改动）：
- 消息：`test: complete ToBid splash regression validation`
- 排除：同 28.1

**Demo commit**：无（Demo 代码零改动，仅本地临时 placementId）

### 28.3 操作状态

| 操作 | 状态 |
|---|---|
| push | ❌ 未执行 |
| tag | ❌ 未执行 |
| release | ❌ 未执行 |
| pod repo push | ❌ 未执行 |
| 修改远程 flame-specs | ❌ 未执行 |
| 修改版本号 | ❌ 未执行 |

---

## 29. 剩余问题

> **修订（Phase 5A.15.1）**：初版本节列出的"Reward 完整回归 / TK 编译回归 / R3 独立冷启动"三项均已在 Phase 5A.15.1 补齐（见 §20/§25/§26）。更新后的剩余项如下。

| 问题 | 归属 | 处理 |
|---|---|---|
| 异常场景"未就绪 show"真机实测 | SDK 验证项 | 守卫已实现 + 静态审计通过；App 启动后 Splash 未 ready 时点击展示 → 观察 onAdError AD_NOT_READY，留待后续专项触发 |
| 异常场景"重复 show"真机实测 | SDK 验证项 | 守卫已实现 + 静态审计通过；同一 Splash 快速双击 show，留待后续专项触发 |
| 异常场景"stale callback"真机实测 | SDK 验证项 | 守卫已实现 + 静态审计通过；R1/R2/R3 中 `isCurrent` 全 1，未观察到触发 |
| Reward 奖励回调真机实测 | SDK 验证项 | Phase 5A.15.1 两轮 Reward 完整回归中奖励回调未出现（非阻塞，奖励链路留待后续有奖励素材时验证） |
| Reward NSURLErrorDomain -1002 | 第三方（Sigmob WindSDK S2S） | Phase 5A.13 已登记为"高概率推断"，非阻塞 |

---

## 30. 结论（Phase 5A.15.1 三项补齐后更新）

| 项 | 结果 |
|---|---|
| 公共 API 是否变化 | ❌ 未变（FlameSplashListener / FlameSplashAd / FlameSplashAdapterProtocol 零改动） |
| 单一 XCFramework | ✅ 保持（TK/TB 共享同一 binary，TbSplashAdapter 符号在两个 App 都存在） |
| 是否重新引入 AnyThink | ❌ 否（TB 包仍不携带 AnyThinkSDK，Flame binary 保持 LC_LOAD_WEAK_DYLIB，TK 真机无 ADX 弹窗） |
| AnyThink 隔离 | ✅ TK podspec 带入嵌入 / Flame binary 保持 weak / TB podspec 不带入（Phase 5A.13 方案无回归） |
| TB Splash 三次独立冷启动 | ✅ R1 倒计时关闭 + R2/R3 skip+close 幂等（finishOnce 守卫二次拦截均生效） |
| skip/close 幂等 | ✅ R2/R3 真机专项验证通过（Sigmob 先 skip 后 close，业务只通知一次） |
| Reward 完整展示回归 | ✅ 两轮闭环（load/show/didVisible/didClose/next-load/next-didLoad），presenter/vcWindow 非空 |
| TK 干净编译回归 | ✅ 28 pods + BUILD SUCCEEDED + AnyThinkSDK 进入 App + Flame binary 保持 weak link |
| 异常场景 | ⚠️ skip/close 幂等真机实测通过；未就绪 show / 重复 show / stale callback 为代码实现 + 静态审计 |
| **Phase 5A.15 是否正式完成** | ✅ **正式完成**（Phase 5A.15.1 三项补齐全部通过） |

---

## 31. /compact

Phase 5A.15.1 收口：补齐 Phase 5A.15 三项验收。R3 独立冷启动通过（完全杀进程重启，pt=tb，load/show/willPresent/didPresent/skip+close 完整链路，finishOnce 二次拦截生效，无 AnyThink 弹窗/黑屏/重复展示，主页面正常）。Reward 完整展示回归通过（两轮闭环 load/show/willVisible/didVisible/didClose/next-load/next-didLoad，presenter/vcWindow 非空，thread=1，cachedVC=0x0 时动态 presenter 修复仍生效；奖励回调本轮未出现非阻塞）。TK 干净编译回归通过（28 pods，BUILD SUCCEEDED，AnyThinkSDK 进入 App，Flame binary 保持 LC_LOAD_WEAK_DYLIB，TK guard 已编入）。Phase 5A.15 正式完成。本地 docs commit `test: complete ToBid splash regression validation`，未 push/tag/release。Phase 5A.15.1 完成后停止，Banner 接入方案存在待沟通问题，未进入 Phase 5A.16，未创建或修改 Banner Adapter。
