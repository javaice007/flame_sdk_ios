# Flame iOS SDK 变更日志

> 本文件记录 Flame iOS SDK 的关键架构变更与发布里程碑。
> 详细阶段报告见同目录 `phase-*.md`。

---

## Phase 5A.16（进行中）— TB 第三方广告源接入

### Phase 5A.16C：ToBid Banner Adapter 实现（本次 SDK feat commit）

**变更类型**：新增广告类型适配器（非破坏性，SDK 公共 API + Demo 代码零改动）

**核心改动**：

| 文件 | 改动 | 目的 |
|------|------|------|
| `flame_sdk_ios/adapter/tb/TbBannerAdapter.{h,m}`（新增） | 实现 `FlameBannerAdapterProtocol` + `WindMillBannerViewDelegate`（10 方法，Express 完整 + SelfRender 占位） | TB 横幅（普通 Banner）接入 |
| `flame_sdk_ios/mediation/tb/FlameTBProvider.m`（修改） | Banner 工厂：占位 `return nil` → 创建 adapter | 打通 Router → Provider → Adapter 链路 |

**实现要点**（参考 AtBannerAdapter Express + WindMillBannerView 特化）：
- `loadAdData`（WindMill Banner 专用加载方法，非 Reward/Interstitial/Splash 的 loadAd）
- `initWithRequest:expectSize:`（camelCase，非 snake_case）
- `isAdValid` 作为 ready 判断（WindMill 无 isAdReady）
- `retrieveAdView` 返回 strong 持有的 WindMillBannerView（Demo 自己 addSubview + AutoLayout）
- auto-refresh 由 ToBid 后台控制（Adapter 不加 Timer）
- 首次失败不内部重试（与 TK AtBannerAdapter 一致；Demo RetryScheduler 负责）
- destroy 靠 `delegate=nil + removeFromSuperview + bannerView=nil`（WindMill 无 destroy 方法）
- stale callback 守卫（每个回调判断 `bannerAdView == self.bannerView`）
- 10 个 `WindMillBannerViewDelegate` 方法全实现（selector label 按头文件原样）
- `[TB_BANNER_DIAG]` 诊断日志全覆盖
- SelfRender 模式占位（本阶段不实现，红线 #11）
- project.pbxproj 零改动（PBXFileSystemSynchronizedRootGroup 自动同步）

**验证**：

| 项 | 结果 |
|---|---|
| XCFramework 构建 | ✅ BUILD EXIT 0，binary 324K→344K（+20K），两 slice 符号齐全 |
| AnyThinkSDK weak link 断言 | ✅ 无回归（两 slice LC_LOAD_WEAK_DYLIB） |
| TB 真机（iphoneos）BUILD | ✅ SUCCEEDED |
| TB 模拟器 BUILD | ❌ FAILED（pre-existing Flame xcframework 缺 arm64 sim slice，与 Banner 无关） |
| TbBannerAdapter 符号进 Flame framework | ✅ 两 slice |
| WindMillBannerView + BUNativeExpressBannerView 进 App dylib | ✅（CSJ Banner 链路完整） |
| TK clean pod install 回归 | ✅ 28 pods（不引入 ToBid CSJAdapter），BUILD SUCCEEDED |
| CSJ Banner 真实填充 | ❌ 未验证（Phase 5A.16D，需后台 + pMap + Demo Info.plist SKAdNetwork） |
| Demo 代码改动 | ❌ 零改动 |

**红线遵守**：未 push / 未 tag / 未发布 / 未改 Flame 对外 Banner API / 未加 TB 专属公共 Banner 类 / 未让 Demo import WindMillBannerView 或判断 pt / 未改 AtBannerAdapter / 未改 FlameTKProvider / 未改 Reward/Interstitial/Splash / 未处理 SelfRenderBanner / 未重引入 AnyThinkiOS / 未升级 ToBid 5.5.6 / 未升级 Ads-CN 7.6.0.4 / 未调私有 API / 未 Hook / 未写死 320×50 / 未新增 auto-refresh Timer / Adapter 未内部重试 / 未提交 project.pbxproj 环境差异 / Demo 代码零改动 / 测试 placementId / Pods / Podfile.lock。

---

### Phase 5A.16B：CSJ/Pangle 广告源最小依赖接入（commit `7f5acf0`）

**变更类型**：TB podspec 依赖新增（非破坏性，SDK 业务代码零改动）

**核心改动**：

| 文件 | 改动 | 目的 |
|------|------|------|
| `flame_sdk_ios_tb.podspec`（修改） | +1 依赖 `s.dependency 'ToBid-iOS-RC/CSJAdapter', '5.5.6'` | 引入 CSJ/Pangle（穿山甲）广告源，服务后续 Banner 最小闭环（Sigmob 自身无 Banner 填充） |

**实现要点**：
- 仅增加 CSJ，不增加其他网络（GDT/MS/Octopus/Baidu/KS/Mintegral/GroMore/BidResult 均不接入）
- 不在 Flame podspec 重复声明底层 Ads-CN/BUAdSDK/CSJMediation（由 ToBid 官方 CSJAdapter subspec 管理，单一来源）
- 不创建 TbBannerAdapter / 不修改 Banner 工厂 / 不修改 Banner 公共协议
- 不修改 Reward/Interstitial/Splash Adapter

**官方依赖链**（从 ToBid-iOS-RC 5.5.6 podspec 确认）：
```
ToBid-iOS-RC/CSJAdapter 5.5.6
  → vendored WindMillCSJAdapter.xcframework
  → Ads-CN/BUAdSDK 7.6.0.4（BUAdSDK.xcframework + CSJAdSDK.bundle）
  → ToBid-iOS-RC/ToBidSDK
```
**不拉取** BUAdLive-Framework / BUTTSDKFramework / CSJMediation（CSJAdapter 显式选 `Ads-CN/BUAdSDK` subspec，绕过 Ads-CN 默认 subspec 的 BUAdLive 陷阱）。

**验证**：

| 项 | 结果 |
|---|---|
| TB clean pod install | ✅ 5 pods（4→5，+Ads-CN/BUAdSDK 7.6.0.4） |
| TB 真机（iphoneos）BUILD | ✅ SUCCEEDED |
| TB 模拟器 BUILD | ❌ FAILED（pre-existing：Flame xcframework 缺 arm64 simulator slice，与 CSJ 无关；CSJ SDK 支持 arm64 sim） |
| CSJ Adapter 符号进 App | ✅ BUNativeExpressBannerView / WindMillCSJAdapter / WindMillBannerView 均在 debug dylib |
| AnyThink 弱链接无回归 | ✅ LC_LOAD_WEAK_DYLIB 保持 |
| AnyThink/TK adapter/SigmobAd-iOS 泄漏 | ✅ 全部 ABSENT |
| TK clean pod install 回归 | ✅ 28 pods（不拉 ToBid CSJAdapter），BUILD SUCCEEDED |
| TB App 启动冒烟 | ✅ 通过（pt=tb/无 AnyThink 弹窗/无 dyld/无 selector/无 duplicate class/CSJ 未触发符合预期/主页面正常） |
| 原 Splash/Interstitial/Reward 回归 | ✅ 通过（Splash skip+close 幂等 / Interstitial 完整 close-loop / Reward 两轮闭环 cachedVC=0x0 时动态 presenter 修复生效） |
| Banner Adapter | ❌ 未实现（Phase 5A.16C） |

**体积**：Pods 138M→553M（+415M，含双 slice）；App ~130M。

**SKAdNetwork**：CSJ 10+ 个 ID 待 Phase 5A.16C/D 加 Demo Info.plist（本阶段不修改 Demo）。

**红线遵守**：未 push / 未 tag / 未发布 / 未创建 TbBannerAdapter / 未修改 Banner 工厂 / 未修改 Banner 公共协议 / 未修改 Reward/Interstitial/Splash / 未升级 ToBid 5.5.6 / 未升级 CSJ SDK / 未改版本号 / 未改远程 flame-specs / 未把第三方 SDK 打进 flame_sdk_ios.xcframework / 未手工声明 Ads-CN/BUAdSDK/BUAdLive/CSJMediation / 未提交 Pods/Podfile.lock/xcworkspace/project.pbxproj 环境差异 / Demo 代码零改动。

---

### Phase 5A.16A：ToBid 第三方广告源交付包审计（commit `3b5326d`，仅文档）

只读审计 + 集成方案设计。审计 `doc/tobid_doc` 9 个广告源（CSJ/GDT/Baidu/KS/Mintegral/MS/Octopus/GroMore + bidResult），Banner 候选 6 家（CSJ/GDT/GroMore/Mintegral/MS/Octopus），Baidu/KS/Sigmob 不支持 Banner。详见 `phase-5a.16a-tb-ad-network-integration-audit.md`。

---

## Phase 5A.15（完成）— TB 开屏广告接入

### Phase 5A.15.1：验收补齐 + 文档收口（本次 SDK docs commit）

**变更类型**：仅文档变更（SDK 业务代码零改动）

**起因**：Phase 5A.15（commit `0d13dd5`）初版报告中 R3 独立冷启动、Reward 完整回归、TK 编译回归三项均未完成（分别写"未单独执行/留待后续/留待后续"）。Phase 5A.15.1 补齐这三项验收。

**三项补齐结果**：

| 项 | 结果 |
|---|---|
| Splash R3 独立冷启动 | ✅ 通过（完全杀进程重启，pt=tb，load/show/willPresent/didPresent/skip+close 完整链路，finishOnce 二次拦截生效，无 AnyThink 弹窗/黑屏/重复展示，主页面正常） |
| Splash 三次独立冷启动 | ✅ 全部通过（R1 倒计时关闭 + R2/R3 skip/close 幂等，finishOnce 守卫二次拦截均生效） |
| Reward 完整展示回归 | ✅ 通过（两轮闭环 load/show/willVisible/didVisible/didClose/next-load/next-didLoad，presenter/vcWindow 非空，thread=1；cachedVC=0x0 时动态 presenter 修复仍生效；奖励回调本轮未出现，非阻塞） |
| TK 干净编译回归 | ✅ 通过（28 pods + BUILD SUCCEEDED + AnyThinkSDK.framework 进入 App + flame_sdk_ios.framework 进入 App + Flame binary 保持 LC_LOAD_WEAK_DYLIB + TK guard 已编入；本轮未重新执行 TK 真机初始化，guard 真机未触发沿用 Phase 5A.13 Step 1.3 结论） |
| AnyThink 隔离 | ✅ 无回归（TK podspec 带入嵌入 / Flame binary 保持 weak / TB podspec 不带入） |
| 公共 API | ❌ 未变 |

**关键表述修正（按 Phase 5A.15.1 v2 §6/§10.4）**：
- ❌ 不写"TK 构建中 AnyThink 强加载"；✅ "TK podspec 负责将 AnyThinkSDK.framework 带入并嵌入 App；Flame binary 对 AnyThinkSDK 仍保持 LC_LOAD_WEAK_DYLIB。"
- ❌ 不写"二进制有 guard 字符串，因此本轮 guard 未触发"；✅ "TK guard 已编入二进制；本轮未重新执行 TK 真机初始化。Phase 5A.13 Step 1.3 的 TK 真机验证中 ATAPI 守卫通过，未出现 TK_PLATFORM_REQUIRES_ANYTHINK。"
- ❌ 不写"下一条 ad 地址必须不同"；✅ 以 adapter 轮次 + load created + isCurrent 为准。
- ❌ 不写"R2 关闭后预热 load 等于 R3 独立冷启动"；✅ R3 已执行真正的独立冷启动（杀进程重启）。

**红线遵守**：未 push / 未 tag / 未发布 / 未改 SDK 业务代码 / 未改 TbSplashAdapter/TbRewardAdapter/TbInterstitialAdapter / 未改公共 API / 未重引入 AnyThinkiOS / 未升级版本 / 未改版本号 / 未提交 project.pbxproj 环境差异 / Pods / Podfile.lock / xcworkspace / 测试 placementId / 真机日志。

**结论**：Phase 5A.15 正式完成。下一阶段（TB Banner）存在待沟通问题，未进入 Phase 5A.16，未创建或修改 Banner Adapter。

---

### Phase 5A.15：TB 开屏 Adapter 接入（commit `0d13dd5`）

**变更类型**：新增广告类型适配器（非破坏性）

**核心改动**：

| 文件 | 改动 | 目的 |
|------|------|------|
| `flame_sdk_ios/adapter/tb/TbSplashAdapter.{h,m}`（新增） | 实现 `FlameSplashAdapterProtocol` + `WindMillSplashAdDelegate`（14 方法） | TB 开屏接入 |
| `flame_sdk_ios/mediation/tb/FlameTBProvider.m`（修改） | 工厂接入：`createSplashAdapter...` 占位 `return nil` → 创建 adapter | 打通 Router → Provider → Adapter 链路 |
| `doc/flame_mediation/phase-5a.14-tb-interstitial-implementation-report.md`（修改，§3 前置） | 异常场景口径收紧 + R3 内存复用说明 | 5A.15 前置修正 |

**实现要点**（复用 TbRewardAdapter/TbInterstitialAdapter 已验证模式 + Splash 特化）：

- 加载方法 **`loadAd`**（不是 Reward/Interstitial 的 `loadAdData`）
- 展示方法 **`showAdInWindow:window withBottomView:nil`**（取 `UIWindow*`，不是 `showAdFromRootViewController:`）
- show 参数来自协议 `show:(UIWindow *)window`（Demo LaunchScreenWindow / keyWindow），**不需要** `flame_topViewController()`
- **`finishOnceWithReason:` 幂等**：ToBid 的 `onSplashAdSkiped:` + `onSplashAdClosed:` 收敛到一次 `onAdClosed`（click 不视为 close）
- stale callback 守卫（每个回调判断 `splashAd == self.splashAd`）
- 14 个 `WindMillSplashAdDelegate` 方法全实现（WindMill 拼写错误 `Skiped`/`WillClosed`/`AdDidAutoLoad` 严格保留）
- `[TB_SPLASH_DIAG]` 诊断日志全覆盖
- Xcode 工程：`PBXFileSystemSynchronizedRootGroup` 自动识别新文件，**project.pbxproj 零改动**

**验证（基于 Demo 本地 TB 配置 + `flame_sdk_ios_tb 1.0.0-alpha.4-local`）**：

| 项 | 结果 |
|---|---|
| XCFramework 构建 | ✅ BUILD EXIT 0，binary 320K→324K（+4K），两 slice 符号齐全 |
| AnyThinkSDK weak link 断言 | ✅ 无回归（两 slice LC_LOAD_WEAK_DYLIB，真机无 ADX 弹窗） |
| 真机 R1 倒计时关闭完整闭环 | ✅ load/show/willPresent/didPresent(didVisible)/[6s]/willClose/didClose/finish(reason=close)/onAdClosed |
| **真机 R2 skip+close 幂等** | ✅ **专项验证通过**：Sigmob 先 `onSplashAdSkiped` 后 `onSplashAdClosed`，finishOnce 守卫正确拦下第二次（日志 `finish already done: reason=close`），业务 onAdClosed 只通知一次 |
| 异常场景 | ⚠️ 仅 skip/close 幂等真机实测通过；未就绪 show / 重复 show / stale callback 为代码实现 + 静态审计 |
| Reward 完整回归 | ⚠️ 仅加载回归通过（沿用 5A.14.1 状态，未倒退） |
| TK 编译回归 | ⚠️ 本轮未执行（改动未触及 TK 侧，风险低，留待下阶段冒烟） |

**红线遵守**：未 push / 未 tag / 未发布 / 未改公共 API / 未加第二套公共 Splash 类 / 未重引入 AnyThinkiOS / 未加 ADX / 未调私有 API / 未 Hook/swizzle / 未用固定延时掩盖 Window 问题 / 未改 Reward/Interstitial Adapter / 未升级版本 / 未改版本号 / 未提交 project.pbxproj 环境差异 / Demo 代码零改动 / 测试 placementId / Pods / Podfile.lock。

---

## Phase 5A.14（进行中）— TB 插屏广告接入

### Phase 5A.14.1：验收口径修正 + Demo 预加载时机修正（本次 SDK docs commit）

**变更类型**：仅文档变更（SDK 代码零改动）

**起因**：Phase 5A.14 初版（`f97e746`）在 Demo `InterstitialAdManager.onShow` 立即触发 `load()` 的情况下做真机验证，整段日志 **0 个 didClose**，但报告误将"load/show/visible 通过"写成"3 轮全闭环"，并把 Reward 的 load/didLoad 写成"回归通过"。

**Demo 修正（Demo 仓库 `11c5958`，独立本地 commit）**：

- `InterstitialAdManager.onShow` 不再调用 `load()`，仅置 `isReady=false` 并通知展示成功
- `onClosed` 中清空当前 `interstitialAd` 后再 `load()` 下一条（对齐 `RewardVideoAdManager` 已验证模式）

**修正后真机结果（基于 Demo `11c5958`）**：

| 项 | 结果 |
|---|---|
| R1 完整闭环 | ✅ load/show/willVisible/didVisible/**didClose**/next-load |
| R2 完整闭环（ad ≠ R1） | ✅ load/show/didVisible/**didClose**/next-load；cachedVC=0x0 时动态 presenter 仍生效 |
| R3 load success | ✅ R2 关闭后立即自动加载成功（循环未断）|
| AnyThink ADX 弹窗（全程）| ❌ 未出现 |
| Reward 回归 | ⚠️ **仅加载回归通过**（load/didLoad 正常，未实测 show/close，不写"完整回归通过"） |
| 异常场景 | 连续 show / load 中再 load 已实测；未就绪 show / stale callback 仅代码实现 + 静态审计 |

**SDK 报告修订（本次 docs commit）**：

- §8 新增"修正后真机验证"章节（R1/R2/R3 真实地址与事件）
- §9/§10 标注旧版数据"已被 §8 取代"，保留以记录历史
- §11 异常场景按"实现 / 静态审计 / 真机实测"三档区分
- §12 Reward 回归改为"仅加载回归通过"
- §13 责任边界按真实结果表述，不绝对断言 SDK 无缺陷

**红线遵守**：未 push / 未 tag / 未发布 / 未改公共 API / 未重引入 AnyThinkiOS / 未调私有 API / 未 Hook / 未升级版本 / 未提交 project.pbxproj 环境差异 / Demo 测试配置 / Pods / Podfile.lock。

---

### Phase 5A.14 初版：TB 插屏 Adapter 接入（commit `f97e746`，验收口径已在 5A.14.1 修正）

**变更类型**：新增广告类型适配器（非破坏性）

**核心改动**：

| 文件 | 改动 | 目的 |
|------|------|------|
| `flame_sdk_ios/adapter/tb/TbInterstitialAdapter.{h,m}`（新增） | 实现 `FlameInterstitialAdapterProtocol` + `WindMillIntersititialAdDelegate` | TB 插屏接入 |
| `flame_sdk_ios/mediation/tb/FlameTBProvider.m`（修改） | 工厂接入：`createInterstitialAdapter...` 占位 `return nil` → 创建 adapter | 打通 Router → Provider → Adapter 链路 |

**实现要点**（复用 TbRewardAdapter 已验证模式）：

- `flame_topViewController()` 动态获取 presenter（解决关闭后重载的 VC 失效，与 Reward 同修复）
- stale callback 守卫（每个回调判断 `intersititialAd == self.intersititialAd`）
- 11 个 `WindMillIntersititialAdDelegate` 方法全实现（WindMill 类名拼写错误 `Intersititial` 严格保留）
- `[TB_INTERSTITIAL_DIAG]` 诊断日志全覆盖
- Xcode 工程：`PBXFileSystemSynchronizedRootGroup` 自动识别新文件，**project.pbxproj 零改动**

**验证（Phase 5A.14.1 修正后口径）**：

| 项 | 结果 |
|---|---|
| XCFramework 构建 | BUILD EXIT 0，binary 300K→320K（+20K） |
| AnyThinkSDK weak link 断言 | ✅ 无回归 |
| 真机插屏 R1/R2 完整关闭闭环 | ✅ load/show/willVisible/didVisible/didClose/next-load |
| 真机插屏 R3 load success | ✅ |
| 动态 presenter 修复（R2 cachedVC=0x0） | ✅ 持续生效 |
| Reward 加载回归 | ✅ load/didLoad 正常 |
| Reward 完整回归（show/close） | ⚠️ 未实测 |
| TK 编译回归 | ✅ BUILD SUCCEEDED（单一二进制双线共享） |
| 公共 API | ❌ 未变 |

---

## Phase 5A.13（已完成）— AnyThink 弱链接方案正式纳入

### Step 1.3：正式化与 TK 真机冒烟验收（本次 commit）

**变更类型**：架构依赖边界正式化（非破坏性）

**核心改动**：

| 文件 | 改动 | 目的 |
|------|------|------|
| `flame_sdk_ios_tb.podspec` | 移除 `s.dependency 'AnyThinkiOS', '6.5.71'` | TB 客户不再携带 AnyThinkSDK.framework，消除 ADX 弹窗 |
| `flame_sdk_ios.podspec` | `flame-sdk-tk-sigmob-adapter` → `flame_sdk_ios_tk_sigmob_adapter`（hyphen→underscore） | 旧版 TK podspec 使用了错误的 Sigmob Adapter 依赖名；使用该版本 spec 安装时可能导致依赖解析失败。本阶段已修正为实际存在的 underscore 形式（与 flame-specs 实际发布的 spec 名一致） |
| `flame_sdk_ios.podspec` 注释 | 补充说明 binary 已弱链接，AnyThinkiOS 由 TK podspec 独家带入 | 文档清晰化 |

**前置（c40e4fe 已完成，Step 1.2B PoC）**：

| 文件 | 改动 | 目的 |
|------|------|------|
| `xcFramework_build.sh` | 新增 AnyThinkSDK 弱链接 patch（-framework → -weak_framework，幂等 + fail-fast + 后置 otool 双断言） | binary 对 AnyThinkSDK 改为 LC_LOAD_WEAK_DYLIB |
| `flame_sdk_ios/mediation/tk/FlameTKProvider.m` | `initializeWithAppId:` 入口加 `NSClassFromString(@"ATAPI")` 守卫 | pt=tk 但 AnyThink 缺失时返回明确错误回调（TK_PLATFORM_REQUIRES_ANYTHINK），不崩溃不 silent fallback |

**验证**：

| 项 | 结果 |
|---|---|
| SDK 构建（含 otool 弱链接双断言） | BUILD EXIT 0 ✅ |
| TB 真机冷启动 3/3 无 ADX 弹窗 | ✅（Step 1.2B 已验证，3/3） |
| TB Reward 3 轮闭环 | ✅（Step 1.2B 已验证，load/show/visible/reward/close/next-load） |
| TK 真机冒烟 | ✅（Step 1.3，全广告位正常加载，无 TK_PLATFORM_REQUIRES_ANYTHINK） |
| TK App Frameworks 含 AnyThinkSDK.framework + SmartdigimktSDK.framework | ✅ |
| TB App Frameworks 不含 AnyThinkSDK.framework | ✅ |
| Flame binary LC_LOAD_WEAK_DYLIB | ✅ |
| 公共 API 未变 | ✅ |
| 单一 XCFramework（不拆 TK/TB 二进制） | ✅ |

**红线遵守**：

- ❌ 未 push / 未 tag / 未发布
- ❌ 未修改远程 flame-specs
- ❌ 未调用 AnyThink 私有 API（仅 `NSClassFromString(@"ATAPI")`，ATAPI 是 AnyThinkiOS 6.5.71 公开 Header）
- ❌ 未增加 AnyThink ADX 组件
- ❌ 未修改后台 pt 路由
- ❌ 未升级 AnyThink/ToBid/Sigmob 版本
- ❌ 未修改版本号（仍为 1.0.0-alpha.4-local）

**业务影响**：

- **TB 客户**：消除 "AnyThink Adx SDK 重要组件缺失" 弹窗（此前每次冷启动必现）
- **TK 客户**：修复 sigmob adapter 依赖名 bug（此前 `pod install` 直接报 spec 找不到）
- **双线客户**：公共 API 不变，无需改动接入代码

**新增非阻塞问题（登记，不在本 commit 处理）**：

- TB Reward 奖励回调后 3 次 NSURLErrorDomain -1002（`?sdkVersion=5.5.6&appId=16990`）
- 高概率推断来源：Sigmob WindSDK S2S 奖励回调上报（rvCallbackURL 为空）
- 详见 `phase-5a.13-step1.2b-tb-anythink-runtime-isolation-poc-report.md` "附" 章节

---

## Phase 5A.12（已完成）— 单二进制架构 + 双 podspec 发布

详见：
- `phase-5a.12-single-binary-mainline.md`
- `phase-5a.12-step3d-release-docs-and-customer-guide-cleanup-report.md`

核心：
- 一个 `flame_sdk_ios.xcframework`（300K）同时内置 TK/TB 胶水
- 两个 podspec：`flame_sdk_ios`（TK）/ `flame_sdk_ios_tb`（TB）
- +load 自动注册（FlameTKProvider / FlameTBProvider）
- FlameMediationRouter 按服务端 pt 激活对应 Provider
- 发布 1.0.0-alpha.1（远程 flame-specs）

---

## Phase 5A.11（已完成）— 三包方案（已被 5A.12 单二进制取代）

## Phase 5A.10（已完成）— thin core 调研（已被 5A.12 单二进制取代）
