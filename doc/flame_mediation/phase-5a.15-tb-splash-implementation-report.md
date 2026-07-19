# Phase 5A.15：TB 开屏广告（Splash）接入实施报告

> 本报告记录 Phase 5A.15：ToBid (WindMill) 开屏广告 Adapter 接入与真机验证。
> 验收口径严格区分 **实现（代码）** / **静态审计** / **真机实测** 三档，未做专项实测的异常场景不写成"已验证"。

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

## 20. R3 冷启动

本轮真机日志包含 R1（看完）+ R2（跳过）两次独立冷启动。**R3（第三次冷启动）本轮未单独执行**——R1/R2 已覆盖"正常关闭"和"skip 关闭"两条核心路径，且每次冷启动后 Demo Coordinator 都会自动触发下一轮 Splash 后台预加载（日志中 `[Splash] 预加载｜开始后台加载` + `[TB_SPLASH_DIAG] didLoad` 已观察到第二轮 Splash 加载成功，即 R2 冷启动后的预热 load success）。

| 项 | R1 | R2 | R3 |
|---|---|---|---|
| 冷启动 load → didLoad | ✅ | ✅ | ⚠️ 未单独执行（R2 关闭后预热 load 已成功，等价覆盖） |
| show → visible | ✅ | ✅ | — |
| 关闭路径 | ✅ 倒计时 close | ✅ skip + close 幂等 | — |
| 主页面恢复 | ✅ | ✅ | — |

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

## 25. Reward 完整回归

基于 R1 日志（line 199-211, 254-256）与 R2 日志（line 205-217, 252-254）：

```
[RewardVideo] 开始加载
[TB_REWARD_DIAG] load: adapter=0x1274e9560 oldAd=0x0 placementId=1886359231652093 thread=1
[TB_REWARD_DIAG] load created: adapter=0x1274e9560 newAd=0x1274bdbc0
[TB_REWARD_DIAG] didLoad: ad=0x1274bdbc0 adapter=0x1274e9560 isCurrent=1
[RewardVideo] 加载成功
```

| 项 | 结果 |
|---|---|
| Reward load | ✅ 通过 |
| Reward didLoad | ✅ 通过（isCurrent=1） |
| Reward show/didVisible/didClose | ⚠️ 本轮未触发展示（Coordinator 仅预加载） |

**结论**：本轮 Reward **仍为仅加载回归通过**，未补齐 show/close 完整回归（与 Phase 5A.14.1 状态一致，未倒退）。Reward 完整回归留待后续专项触发。

---

## 26. TK 编译回归

| 维度 | 状态 |
|---|---|
| 本轮修改共享 Splash 协议 | ❌ 未修改（只新增 adapter + 改 FlameTBProvider 工厂） |
| TK pod install + BUILD | ⚠️ **本轮未执行 TK 编译回归**（仅完成 TB 真机验证；TK 回归留待后续） |

**风险评估**：本轮改动仅限 `flame_sdk_ios/adapter/tb/TbSplashAdapter.{h,m}`（新增）+ `FlameTBProvider.m`（import + 工厂），**未触碰** TK 侧任何文件（`AtSplashAdapter`、`FlameTKProvider`、共享协议 `FlameSplashAdapterProtocol`/`FlameSplashAd` 零改动）。TK 编译路径不受影响。建议下一阶段开始前补一次 TK pod install + BUILD 冒烟。

---

## 27. 文件修改

| 文件 | 类型 | 说明 |
|---|---|---|
| `flame_sdk_ios/adapter/tb/TbSplashAdapter.h` | 新增 | 镜像 TbInterstitialAdapter.h |
| `flame_sdk_ios/adapter/tb/TbSplashAdapter.m` | 新增 | FlameSplashAdapterProtocol + WindMillSplashAdDelegate（14 方法）+ finishOnce 幂等 |
| `flame_sdk_ios/mediation/tb/FlameTBProvider.m` | 修改 | +1 import、占位 return nil → 创建 adapter |
| `doc/flame_mediation/phase-5a.14-tb-interstitial-implementation-report.md` | 修改（§3 前置） | 异常场景口径收紧 + R3 内存复用说明 |
| `doc/flame_mediation/phase-5a.15-tb-splash-implementation-report.md` | 新增 | 本报告 |
| `doc/flame_mediation/09_change_log.md` | 修改 | Phase 5A.15 条目 |
| `README.md` | 修改 | 开屏 ToBid 列 ⏳ → ✅ |

**project.pbxproj 零改动**（PBXFileSystemSynchronizedRootGroup 自动同步）。

---

## 28. Git

**SDK commit**（adapter + provider + 文档）：
- 消息：`feat: add ToBid splash adapter`
- 排除：project.pbxproj 环境差异、Pods、Podfile.lock、xcworkspace、DerivedData、build、Archives、测试 placementId、真机日志、临时脚本

**Demo commit**：无（Demo 代码零改动，仅本地临时 placementId）

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

| 问题 | 归属 | 处理 |
|---|---|---|
| Reward 完整回归（show/didClose） | SDK 验证项 | 沿用 Phase 5A.14.1 状态（仅加载回归），留待后续专项触发 |
| TK 编译回归（pod install + BUILD） | SDK 验证项 | 本轮未执行（改动未触及 TK 侧，风险低）；下一阶段开始前补冒烟 |
| 异常场景"未就绪 show"真机实测 | SDK 验证项 | App 启动后 Splash 未 ready 时点击展示 → 观察 onAdError AD_NOT_READY |
| 异常场景"重复 show"真机实测 | SDK 验证项 | 同一 Splash 快速双击 show |
| 异常场景"stale callback"真机实测 | SDK 验证项 | 守卫已实现并静态审计通过，未观察到触发 |
| Reward NSURLErrorDomain -1002 | 第三方（Sigmob WindSDK S2S） | Phase 5A.13 已登记为"高概率推断"，非阻塞 |
| R3 第三次冷启动 | SDK 验证项 | R1/R2 已覆盖核心路径；R2 关闭后预热 load 已成功（等价覆盖） |

---

## 30. 结论

| 项 | 结果 |
|---|---|
| 公共 API 是否变化 | ❌ 未变（FlameSplashListener / FlameSplashAd / FlameSplashAdapterProtocol 零改动） |
| 单一 XCFramework | ✅ 保持（TK/TB 共享同一 binary，TbSplashAdapter 符号在两个 App 都存在） |
| 是否重新引入 AnyThink | ❌ 否（TB 包仍不携带 AnyThinkSDK，弱链接无回归，真机无 ADX 弹窗） |
| TB Splash 关闭闭环 | ✅ R1 倒计时关闭完整闭环（load/show/didVisible/didClose/finish/onAdClosed） |
| **skip/close 幂等** | ✅ **R2 真机专项验证通过**（skip+close 连续到达，业务只通知一次） |
| 异常场景 | ⚠️ 仅 skip/close 幂等真机实测通过；未就绪 show / 重复 show / stale callback 为代码实现 + 静态审计 |
| Reward 完整回归 | ⚠️ 仅加载回归通过（沿用 5A.14.1 状态，未倒退） |
| 是否可以进入 TB Banner | ✅ 可以（开屏核心路径 + 幂等已真机验证；Banner 同模式可复用，但建议先补 TK 编译回归） |

---

## 31. /compact

Phase 5A.15 完成：新增 `TbSplashAdapter.{h,m}`（实现 FlameSplashAdapterProtocol + WindMillSplashAdDelegate 14 方法），接入 FlameTBProvider 工厂。关键差异已落实：`loadAd`（非 loadAdData）、`showAdInWindow:withBottomView:`（非 showAdFromRootViewController:）、`finishOnceWithReason:` 幂等（skip+close 收敛到一次 onAdClosed）。XCFramework 构建成功，TbSplashAdapter 符号 + TB_SPLASH_DIAG 两 slice 命中，AnyThink weak-link 无回归。真机 R1（倒计时关闭）完整闭环，R2（跳过）**专项验证 skip+close 幂等**（日志显示 `finish already done: reason=close` 正确拦下第二次 finish）。异常场景仅幂等真机实测通过，其余为代码+静态审计。Reward 仍仅加载回归。未 push/tag/release，等用户确认进入 TB Banner。
