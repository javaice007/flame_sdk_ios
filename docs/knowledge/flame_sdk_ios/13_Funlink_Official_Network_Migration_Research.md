# 13 · Flame iOS SDK：Funlink 官方 Network 迁移可行性调研报告

> **报告标识**：Flame_iOS_SDK_Funlink_Official_Network_Migration_Research
> **调研日期**：2026-09-14（代码证据基线：`release/ios-dual-line` @ b03ddea，版本 1.0.1-alpha.4）
> **性质**：可行性调研（本轮禁止实施迁移 / 升级依赖 / 改生产代码，本文档为唯一交付物）
> **调研范围**：代码事实 + Taku/Funlink 最新官方文档核验 + 宿主兼容审计 + 旧版本灰度路径

---

## 1. Executive Summary

**核心发现（推翻调研前提）**：Flame iOS SDK 的 TK 线**当前已经在使用 Taku 官方 Funlink Network Adapter**，且"非官方 Adapter → 官方 Adapter"的迁移**早在 0.1.8（2026-06-04 发布）就已完成后**：

1. **当前 1.0.1-alpha.4 的 TK podspec 依赖官方 `AnyThinkMediationFunlinkAdapter 2.9.0.1.2.2.0`**（`flame_sdk_ios.podspec:72`）。该 pod 由 TopOn 官方账号（owner `topon`，mct-js@toponad.com）发布在 CocoaPods trunk，二进制托管在 TopOn 官方 OSS，是 **trunk 上的最新版本**（trunk 仅 2 个版本：2.9.0.1.2.0 / 2.9.0.1.2.2.0，均发布于 2026-05-28）。
2. **Flame iOS 仓库全 git 历史（含所有分支）中不存在任何自研 Funlink Adapter**：无 `registerCustomNetwork`、无 `ATFunlink` 引用、无自研 adapter pod。Flame 自己的 `At*Adapter` 胶水层封装的是 **Taku 单元 API（`ATAdManager`）**，不是 Funlink Custom Network。
3. **唯一存在过的"非官方 Adapter"是 0.1.7（已发布到 flame-specs）**：使用 Funlink 供应商（北京前呈无限科技/Mediatom）自家分发的 `FunlinkTopOnAdapter`（Gitee mergex 仓库）+ `FLAD/FLAdFunLinkAdapter` + `FunlinkSDK 2.9.0.1.0`，且彼时 `AnyThinkiOS 6.5.42` **低于官方 Funlink Network 要求的 6.5.52**。0.1.8 起切换为官方 Adapter 并同步升 Core 至 6.5.71。
4. **版本合规性**：官方文档要求 Funlink 源"支持的 SDK 版本须是 6.5.52 及以上"（help.takuad.com/docs/YfG41D3N）；adapter podspec 声明依赖 `AnyThinkiOS >= 6.5.45`。Flame 锁定的 6.5.71 **两项均满足**。
5. **官方 Funlink Network ID（network_firm_id）= 97**，Bidding 支持 ✓（C2S 客户端竞价 + 竞价底价）。

**因此本报告对原始问题的回答是**：

> **"把 Custom Funlink Adapter 迁移为 Taku 官方 Funlink Network"这一迁移在 Flame iOS SDK 侧无需实施——它已经完成。** 剩余工作是**运营/后端侧核验**（Taku 后台 iOS waterfall 是否已挂官方 Funlink 源、`/v2/fullreport` 中 Funlink 行的 `network_firm_id` 归属、Funlink Report API 绑定、线上 0.1.x 老版本分布），不涉及任何 Flame SDK 代码、二进制或 podspec 改动。
>
> **宿主契约 = 0 Breaking Change：YES**（宿主零改动；已发 1.0.x 版本的宿主甚至不需要升级 Flame SDK）。

**最终状态：`READY_WITH_CONDITIONS`**（条件全部为运营/后端核验项，见 §16；SDK 代码侧无待实施项）。

---

## 2. Current Architecture

### 2.1 完整调用链（代码实证）

```
宿主 App
  │  FlameSdk.initWithAppId:appKey:callback:        （Flame 平台 aId/aKey）
  ▼
FlameConfigManager.updateAppWithAppId:appKey:callback:   core/FlameConfigManager.m:100
  │  POST https://api.adsurge.cn/api/v1/sdk/init        （MD5 签名 + AES-GCM 解密）
  │  返回: pt(tk|tb) + aId/aKey + pIds(Flame placementId → Taku placementId 映射)
  │  网络失败 → 本地缓存回退（pt+aId+aKey+pMap 完整才可用）
  ▼
FlameSdk.m UpdateAppCallback.success                     core/FlameSdk.m:136-178
  │  getPt → FlameMediationRegistry.providerForPlatformCode
  │  → FlameMediationRouter.activateProvider（+load 自动注册 tk/tb）
  ▼
FlameTKProvider.initializeWithAppId:appKey:callback:     mediation/tk/FlameTKProvider.m:42
  │  守卫: NSClassFromString(@"ATAPI")==nil → fail("TK_PLATFORM_REQUIRES_ANYTHINK")
  │  [ATAPI setLogEnabled:YES] + integrationChecking + startWithAppID:appKey:error:
  ▼
宿主: FlameSdk.create{Reward|Splash|Interstitial|Banner|Native}Ad...（Flame placementId）
  │  getPId 映射后传 Taku placementId                    core/FlameConfigManager.m:337
  ▼
At*Adapter（TK 胶水，adapter/tk/）                        封装 ATAdManager 单元 API
  ▼
AnyThinkSDK 6.5.71（Taku Core，动态 framework）
  │  按 waterfall 中广告源的 network_firm_id 路由到对应 Network Adapter
  ▼
ATFunlink*Adapter（Taku 官方，AnyThinkMediationFunlinkAdapter 2.9.0.1.2.2.0，静态归档）
  ▼
FunlinkSDK 2.9.0.1.2（FLinkAdSaas.framework，Funlink 方发布的静态归档）
  ▼
Funlink 服务端（union.funlinkads.com）
```

### 2.2 关键工程事实

| 项 | 事实 | 证据 |
|---|---|---|
| 语言 | 纯 Objective-C | `flame_sdk_ios/`（60 个 .h/.m） |
| 最低 iOS | 13.0 | `flame_sdk_ios.podspec:45`、xcframework Info.plist `MinimumOSVersion=13.0` |
| 产物形态 | 静态 XCFramework（ar 归档，外壳 FMWK），TK/TB 双线互斥 | `flame_sdk_ios.xcframework`（`file`: current ar archive）；`xcFramework_build.sh tk-static/tb-static` |
| module | `flame_sdk_ios`（TK/TB 一致） | 两份 podspec `s.module_name` |
| 分发 | 私有 spec repo `javaice007/flame-specs` + 二进制仓库 `javaice007/flame_sdk_ios`（tag 机械绑定） | podspec `s.source`；docs/knowledge/flame_sdk_ios/11 |
| 依赖管理 | CocoaPods；**无 SPM Package.swift**（全仓库不存在） | 仓库文件清单 |
| 公共 API | 伞头文件 `flame_sdk_ios/flame_sdk_ios.h` 导出 7 个头：Callback/Splash/Banner/BannerMaterial/BannerRenderSlots/Reward/Interstitial/FlameSdk（Native 头未进伞文件但 FlameSdk.h 引入 FlameNativeAd.h） | `flame_sdk_ios.h` |
| 链接要求 | 宿主 `-ObjC`（+load 自动注册 FlameTKProvider/FlameTBProvider 依赖它） | podspec `user_target_xcconfig` |
| `pt` 路由 | 服务端 `/api/v1/sdk/init` 下发 `pt`；为空时兼容默认 `tk`（FlameSdk.m:139） | core/FlameSdk.m |
| placement 映射 | 宿主只见 Flame placementId，`pIds` 服务端下发 + `getPId` 完成 Flame→Taku 映射；公共 API 不收第三方 ID | docs/knowledge/flame_sdk_ios/05、12 |
| Funlink 范围 | **仅 TK 线**；TB 线（ToBid 5.5.6）8 个广告源中无 Funlink | `flame_sdk_ios_tb.podspec:73-80` |

---

## 3. Version Matrix

### 3.1 Flame SDK 版本 × Funlink 接入形态（私有 spec repo 逐版本核验）

| 发布版本（flame-specs 实存） | AnyThinkiOS | Funlink 接入形态 | 发布时间 |
|---|---|---|---|
| 0.1.0 – 0.1.6 | 6.5.34/6.5.42 | **无 Funlink** | ≤2026-05 |
| **0.1.7** | 6.5.42 | **非官方三方形态**：`FunlinkTopOnAdapter`（Gitee mergex/北京前呈无限）+ `FunlinkSDK 2.9.0.1.0` + `FLAD 2.9.0.1.1`（含 `FLAD/FLAdFunLinkAdapter` subspec） | 2026-05 末 |
| **0.1.8 – 0.1.8.4** | **6.5.71** | **官方 `AnyThinkMediationFunlinkAdapter 2.9.0.1.2.2.0`**（迁移完成点） | 2026-06-04 起 |
| 1.0.0-alpha.1 / alpha.2 / 1.0.0 | 6.5.71 | 同上（动态单二进制时代；⚠️ 1.0.0 接入即闪退已知缺陷） | 2026-07-21 |
| 1.0.1-alpha.1 – alpha.4（当前） | 6.5.71 | 同上（静态双线产物） | 2026-08-26 – 08-31 |

> 核验方法：遍历本机 `~/.cocoapods/repos/javaice007-flame-specs/flame_sdk_ios/` 全部 20 个已发布 podspec，grep `Funlink` 与 `AnyThinkiOS`。dev 仓库 git 历史与发布记录在 0.1.7 存在一处出入（dev 仓库 0.1.7 podspec 无 Funlink，而 flame-specs 发布的 0.1.7 有），以**发布产物**为准。

### 3.2 当前版本矩阵 × 官方最新

| 组件 | Flame 锁定 | 官方最新（2026-09-14 核验） | 差距评估 |
|---|---|---|---|
| flame_sdk_ios（TK） | 1.0.1-alpha.4 | — | — |
| AnyThinkiOS（Taku Core） | **6.5.71**（精确锁） | **6.5.82**（2026-09-09 发布；另有新品牌孪生 pod TPNiOS 同步） | 落后 11 个 patch；**对 Funlink 迁移无阻碍**（官方要求 ≥6.5.52） |
| AnyThinkMediationFunlinkAdapter | **2.9.0.1.2.2.0** | **2.9.0.1.2.2.0**（trunk 最新，2026-05-28） | **已是最新** |
| FunlinkSDK | 2.9.0.1.2（由官方 adapter 精确锁定，不可单独升级） | 2.9.0.3.0（2026-09-08，Funlink 方自行维护，owner 非 topon） | 被 adapter 锁定；升级须等 TopOn 出新 adapter |
| OpenSSL-Universal | ~3.6 | — | 与 Funlink 无关 |
| ToBid-iOS-RC（TB 线） | 5.5.6 | — | TB 线与 Funlink 无关 |

### 3.3 Taku 版本管控与覆盖风险

- AnyThinkiOS 由 Flame **精确锁版本**（`s.dependency 'AnyThinkiOS', '6.5.71'`）。宿主若自行依赖其他版本的 AnyThinkiOS，CocoaPods 解析将冲突报错——**宿主无法静默覆盖 Taku 版本**（这是 SDK 产品化上的保护，也是强约束）。
- Funlink adapter 与 FunlinkSDK 由 Flame podspec **传递依赖**给宿主；宿主不直接声明。宿主若自己已用 `FunlinkSDK`/`AnyThinkMediationFunlinkAdapter`，版本不一致时同样在 `pod install` 阶段冲突暴露（见 §9.2）。

---

## 4. 当前 Funlink 接入形态（"Custom Adapter" 前提的事实修正）

### 4.1 原始前提 vs 代码事实

| 原始调研前提 | iOS 代码事实 | 判定 |
|---|---|---|
| "Funlink 由 Taku Custom Network / 自研 Adapter 接入" | 全 git 历史无 `registerCustomNetwork`/`ATFunlink`/自研 adapter pod；0.1.8 起即官方 Adapter pod | ❌ 不成立（对 iOS 全部已发布版本） |
| "Taku 官方已提供正式 Funlink Network" | 属实：`AnyThinkMediationFunlinkAdapter`（topon 官方发布）+ 官方文档页《泛连(Funlink)》、firm_id=97 | ✅ 成立 |
| "最低 Taku SDK 版本结论需重新核验" | 官方文档：**≥6.5.52**；adapter podspec：≥6.5.45。Flame 6.5.71 满足 | ✅ 已核验 |

**前提偏差的可能来源**（供后端同事对齐）：
1. **0.1.7 时代的非官方 Adapter**（`FunlinkTopOnAdapter` 为 Funlink 供应商三方分发，命名非 TopOn 官方体系），后端早期调研可能取材于此；
2. Android 线的接入形态（不在本仓库范围）；
3. **Taku 后台**侧如果曾把 Funlink 配成"自定义广告平台"（见 §13 决策树）——后台配置无法从本仓库核验，属运营侧事实。

### 4.2 Flame 自有胶水 ≠ Taku Network Adapter（概念澄清）

Flame SDK 有**两层 Adapter**，极易混淆：

| 层 | 类 | 面向 | 注册方式 | 与 Funlink 的关系 |
|---|---|---|---|---|
| Flame 胶水层 | `AtRewardAdapter` / `AtSplashAdapter` / `AtInterstitialAdapter` / `AtBannerAdapter` / `AtNativeAdapter`（adapter/tk/，ObjC） | **Taku 单元 API**（`ATAdManager` / `ATBannerView` / `ATNativeADView`） | `FlameTKProvider` `+load` → `FlameMediationRegistry`（Flame 自有注册表，非 Taku） | 不感知 Funlink——Funlink 由 Taku 内部 waterfall 决定 |
| Taku Network 层 | `ATFunlink{Init|Splash|Banner|Interstitial|RewardedVideo|Native}Adapter`（官方闭源二进制） | **FunlinkSDK（FLinkAdSaas）** | Taku Core 按 waterfall 广告源的 `network_firm_id=97` 自动路由 | **这一层已经是官方实现** |

Flame 胶水层的关键实现事实（迁移审计需知的全部行为）：

- **init**（`FlameTKProvider.m:42`）：`ATAPI` 类存在性守卫 → `setLogEnabled:YES` → `integrationChecking` → `startWithAppID:appKey:error:`；
- **load**：`[[ATAdManager sharedManager] loadADWithPlacementID:extra:delegate:]`；Reward 写入 `kATAdLoadingExtraUserIDKey` / `kATAdLoadingExtraUserDataKeywordKey` / `kATAdLoadingExtraMediaExtraKey`（alpha.4 起双写，后两个面向三方透传与 Taku 服务端激励回传）；Splash 默认补 `kATSplashExtraTolerateTimeoutKey=5s`；Interstitial 写 `kATInterstitialExtraAdSizeKey=屏幕尺寸`；Native 写 `kATNativeAdSizeToFitKey=YES`；
- **show/present**：Reward/Interstitial 走 `show{RewardedVideo|Interstitial}WithPlacementID:inViewController:delegate:`；Splash 走 `showSplashWithPlacementID:config:window:inViewController:extra:delegate:`（`ATShowConfig` + UIWindow 双参）；Banner 设 `ATBannerView.presentingViewController`；Native 在 `ATNativeADConfiguration.rootViewController` 传入；
- **UIViewController 获取方式**：**全部由宿主在 create API 传入**，Flame 不自取 keyWindow/rootVC（`initWithViewController:` 链路）；Splash show 阶段再传 UIWindow 并做 nil 校验（`AtSplashAdapter.m:77`）；
- **delegate/callback**：逐方法转发到 Flame Listener（`ATRewardedVideoDelegate` / `ATInterstitialDelegate` / `ATBannerDelegate` / `ATAdLoadingDelegate` / Native ADView 回调），错误回调统一转字符串错误码；
- **error code**：Taku `NSError.code` 数字字符串透传 + Flame 自有码（`FlameErrorCode.h` 6 个符号 + 14xxx/15000 系列，docs/knowledge 07/12）；
- **bidding/price**：胶水层不感知；竞价由 Taku 内部处理；
- **revenue callback**：客户端仅插屏/开屏实现了 `didRevenueForPlacementID:extra:`（`AtInterstitialAdapter.m:146` 把它映射为 `onAdReward`；`AtSplashAdapter.m:193` 刻意不触发任何回调）；**激励/横幅/原生无客户端收益回调**；**收益口径完全依赖 Taku 服务端报表**（见 §14）；
- **自研 workaround**：Reward `capturedShowId` 快照（`AtRewardAdapter.m:15-17`，发奖 transId 取值链：发奖 extra 展示ID → 展示回调快照 → 空串，alpha.4 按 Taku 官方文档修正）；TK 平台 `NSClassFromString(@"ATAPI")` 弱链接守卫；无任何针对 Taku 生命周期的私有补丁。

---

## 5. 实际广告类型矩阵（代码实证）

| 类型 | Flame Public API | Flame TK 胶水 | Taku 单元 API | 官方 Funlink Adapter 类（二进制实证） | Bidding | 容器/VC 约束 | 备注 |
|---|---|---|---|---|---|---|---|
| Splash 开屏 | `<FlameSplashAd>` `createSplashAdWithViewController:placementId:listener:`；`show:(UIWindow*)` | `AtSplashAdapter` | `showSplashWithPlacementID:config:window:inViewController:extra:delegate:`；`kATSplashExtraTolerateTimeoutKey`=5s | `ATFunlinkSplashAdapter` ✅ | C2S ✅ | 宿主传 VC + UIWindow；有 `onAdLoadTimeout` | — |
| Banner 横幅 | `<FlameBannerAd>` Express `createBannerAd` / SelfRender `createSelfRenderBannerAd`；`loadWithWidth:height:viewController:` | `AtBannerAdapter`（Express=ATBannerView；SelfRender=Banner Native Mix → `FlameBannerAdMaterial`） | `retrieveBannerViewForPlacementID` + `presentingViewController`；`nativeMixBannerViewBlock` | `ATFunlinkBannerAdapter` ✅ | C2S ✅ | VC 在 load 阶段传入 | TB 线 SelfRender 降级 14003（与 Funlink 无关） |
| Interstitial 插屏 | `<FlameInterstitialAd>` `createInterstitialAdWithViewController:...`；`show` | `AtInterstitialAdapter` | `showInterstitialWithPlacementID:inViewController:delegate:`；`kATInterstitialExtraAdSizeKey`=屏幕尺寸 | `ATFunlinkInterstitialAdapter` ✅ | C2S ✅ | 宿主传 VC | `didRevenue` 被映射为 `onAdReward`（语义 quirk） |
| Rewarded 激励 | `<FlameRewardAd>` `createRewardAdWithViewController:...`；`loadWithUserId:userCustomData:`；`show` | `AtRewardAdapter` | `showRewardedVideoWithPlacementID:inViewController:delegate:`；userId/userCustomData 双写三个 extra key | `ATFunlinkRewardedVideoAdapter` ✅ | C2S ✅ | 宿主传 VC | transId 修复见 alpha.4 |
| Native 原生 | `<FlameNativeAd>` `createNativeAdWithViewController:...`；`showInContainer:`；`setRenderType`（hint） | `AtNativeAdapter` + `AtNativeSelfRenderView` | `getNativeAdOfferWithPlacementID:scene:` + `ATNativeADConfiguration`（rootViewController/自动播）→ `ATNativeADView`；Express/自渲染按物料自动分支 | `ATFunlinkNativeAdapter` ✅ | C2S ✅ | 宿主传 VC + 宿主容器 UIView | Listener 全 @required；伞头文件未导出 Native 头 |
| Fullscreen Video 全屏视频 | **N/A**（Flame 公共 API 无独立类型；Taku 侧全屏视频归入插屏/激励单元） | N/A | N/A | N/A（官方 adapter 无独立类，与 Taku 行为一致） | — | — | 不适用 |

> FunlinkSDK 本体（FLinkAdSaas）含 `FLinkSplashManager` / `FLinkBannerManager` / `FLinkInterstitialManager` / `FLinkRewardVideoManager` / `FLinkNativeManager` 与 `FLinkBiddingModel`（firstPrice/secondPrice/isWin/bidfloor），与官方 Adapter 五类一一对应。

---

## 6. Taku 官方 Funlink iOS 能力核验（2026-09-14 最新官方资料）

| # | 核验项 | 结论 | 证据（URL + 页面标题，调研日 2026-09-14） |
|---|---|---|---|
| 1 | 最低 Taku SDK 版本 | **官方文档：6.5.52 及以上**；adapter podspec 声明 `AnyThinkiOS >= 6.5.45` | 《泛连(Funlink) - Taku 帮助中心》 https://help.takuad.com/docs/YfG41D3N ；trunk podspec `pod spec cat AnyThinkMediationFunlinkAdapter` |
| 2 | 官方 Adapter 依赖方式 | CocoaPods（首选）+ 手动集成；pod 名 **`AnyThinkMediationFunlinkAdapter`**（新品牌孪生 pod `TPNMediationFunlinkAdapter` 版本同步） | 同上 + 《Taku SDK导入说明》 https://help.takuad.com/docs/zODjLF + trunk API https://trunk.cocoapods.org/api/v1/pods/AnyThinkMediationFunlinkAdapter （owner= topon / mct-js@toponad.com） |
| 3 | 对应 Funlink SDK 版本 | **精确锁 `FunlinkSDK 2.9.0.1.2`**（vendored `FLinkAdSaas.xcframework`）；版本命名：前 5 段=FunlinkSDK 版本，末 1-2 段=adapter 修订号（强推断，无官方明文页） | trunk podspec（pod spec cat，2026-09-14） |
| 4 | CocoaPods pod 名 | `AnyThinkMediationFunlinkAdapter`（pod 名未出现在公开文档正文——Taku 文档 Podfile 由登录态下载中心生成，权威性来自 trunk 官方发布者 + 官方 OSS 包三重交叉验证） | 同上；SDK 下载中心 https://portal.toponad.net/m/sdk/download?type=iOS |
| 5 | SPM | **官方无 SPM 支持**（仅 CocoaPods/手动） | 《Taku SDK导入说明》 https://help.takuad.com/docs/zODjLF |
| 6 | 手动集成 | 官方 OSS zip：`https://topon-sdk-release.oss-accelerate.aliyuncs.com/AnyThink_Release/iosnetwork_2/AnyThinkFunlinkAdapter/2.9.0.1.2.2.0/AnyThinkFunlinkAdapter-2.9.0.1.2.2.0.zip` | trunk podspec source 字段 |
| 7 | static/dynamic | Adapter 为**静态归档**（`static_framework: true` + 本地 `file` 实证 ar archive）；FunlinkSDK 同为静态归档（FMWK 外壳 + ar 本体，podspec `static_framework: true`） | 本地二进制 `file` + trunk podspec |
| 8 | 支持广告类型 | **Splash / Banner / Interstitial / RewardedVideo / Native 五类**（adapter 二进制符号实证；官方页面无类型矩阵表） | `ATFunlink{Splash|Banner|Interstitial|RewardedVideo|Native}Adapter`（官方 OSS 包 nm/strings 分析，2026-09-14） |
| 9 | C2S Bidding | **支持：Bidding ✓（C2S）、竞价底价 ✓、常规底价 ✗**；adapter 二进制含 `c2sPriceStringWithEcpm:` / `ATAdSendC2SBidPriceKey` | 《聚合平台概况 - Taku》 https://help.takuad.com/docs/2KR6QU （2026-07-24 更新版）；二进制旁证 |
| 10 | 最低 iOS | adapter 与 FunlinkSDK podspec 均 **iOS 11.0**；Taku 官方 demo Podfile 基准 iOS 13.0 | trunk podspec；TopOn-iOS-Pod-Demo https://github.com/toponteam/TopOn-iOS-Pod-Demo |
| 11 | Xcode 要求 | 官方仅"推荐最新版本的Xcode"，无强制最低版本 | 《Taku SDK导入说明》 https://help.takuad.com/docs/zODjLF |
| 12 | Swift 版本 | FunlinkSDK podspec `swift_version 5.1`（SDK 本体为 ObjC 静态归档，仅 pod 元数据）；Flame podspec `swift_version 5.0` | trunk podspec |
| 13 | arm64 simulator | AnyThinkSDK / FunlinkSDK / FunlinkAdapter 三者 xcframework 均含 `ios-arm64_x86_64-simulator` slice；FunlinkSDK 安装 xcconfig 排除 `i386`（Apple Silicon 模拟器不受影响） | 本地 Pods 目录实证 |
| 14 | privacy manifest | FunlinkSDK（FLinkAdSaas.framework）**自带 `PrivacyInfo.xcprivacy`**（声明 DeviceID/Tracking=ThirdPartyAdvertising + SystemBootTime 等 Required Reason API）；AnyThinkSDK 同样自带 | 本地 Pods 实证（Pods/FunlinkSDK/…/PrivacyInfo.xcprivacy） |
| 15 | required Info.plist | Funlink 侧无额外必配 Info.plist 项（官方文档仅要求 Taku 通用接入项） | 《泛连(Funlink)》《Taku SDK导入说明》 |
| 16 | SKAdNetwork IDs | 官方 Funlink 接入页未单独列 SKAdNetwork ID；宿主按 Taku 文档统一配置（Flame Demo 已配 21 个 ID + `NSUserTrackingUsageDescription`） | 《泛连(Funlink)》；Demo `Resources/Info.plist` |
| 17 | ATS | Taku 接入要求允许任意加载（Flame Demo `NSAllowsArbitraryLoads=true`）；Funlink 无额外 ATS 条款 | Demo Info.plist + 《Taku SDK导入说明》 |
| 18 | `-ObjC` | FunlinkSDK/Adapter podspec 均 `-lObjC`；Flame 已强制宿主 `-ObjC`（更强，覆盖） | trunk podspec + Flame podspec |
| 19 | category linker | 由 `-ObjC`/`-lObjC` 覆盖，无额外 `-load` 要求 | 同上 |
| 20 | resources/bundle | 官方 adapter 仅 xcframework（Headers/Modules/二进制），无独立 bundle；FunlinkSDK 同 | 本地 Pods 目录实证 |
| 21 | Network ID | **`network_firm_id = 97`（泛连 Funlink）** | 《聚合平台概况 - Taku》 https://help.takuad.com/docs/2KR6QU |
| 22 | Taku 后台配置字段 | 广告位级：**泛连 APP ID + Unit ID**（泛连后台 union.funlinkads.com 获取） | 《泛连(Funlink)》 https://help.takuad.com/docs/YfG41D3N |
| 23 | Report API 绑定 | Funlink 后台「账户信息→key」生成 **API KEY + API SECRET** → Taku 后台「广告平台→变现平台→泛连→编辑→开通报表API」填写；未开通不影响广告位配置 | 同上 |

**与既有旧结论的差异裁定**：官方口径为 **6.5.52**（文档）> 6.5.45（podspec 下限）。若旧调研记录记录的是 6.5.45 或其他值，以本次官方文档 6.5.52 为准（Flame 6.5.71 无论按哪个口径均满足）。

---

## 7. 迁移 GAP 逐项对照

**结论先行：不存在"Custom → Official"代码 GAP——两端已是同一官方实现。** 下表给出若以"0.1.7 非官方形态"为迁移起点、当前 1.0.1-alpha.4 为终点的逐项对照（即**已经发生的迁移**的完备性审计）：

| 能力 | 0.1.7 非官方形态（起点） | 当前官方 Adapter（现状/终点） | 等价性 | Flame SDK 需改动 | Host 需改动 |
|---|---|---|---|---|---|
| 初始化 | AnyThinkiOS 6.5.42，adapter 由 Funlink 方分发 | 6.5.71 + topon 官方 adapter（`ATFunlinkInitAdapter`） | ✅ 官方版更优 | 无 | 无 |
| Splash | 未知（三方 adapter 闭源） | `ATFunlinkSplashAdapter` + Taku splash 单元 API | ✅ | 无 | 无 |
| Banner | 未知 | `ATFunlinkBannerAdapter` | ✅ | 无 | 无 |
| Interstitial | 未知 | `ATFunlinkInterstitialAdapter` | ✅ | 无 | 无 |
| Reward | 未知 | `ATFunlinkRewardedVideoAdapter` | ✅ | 无 | 无 |
| Native | 未知 | `ATFunlinkNativeAdapter` | ✅ | 无 | 无 |
| Fullscreen | N/A | N/A（官方 adapter 也无独立类） | ✅ 同为 N/A | 无 | 无 |
| Bidding | 未知（FunlinkSDK 2.9.0.1.0 已含 BiddingModel） | C2S ✓ + 竞价底价 ✓（官方概况页） | ✅ | 无 | 无 |
| Placement Mapping | Flame pIds 机制不变 | 不变（Flame placementId→Taku placementId 由服务端控制） | ✅ | 无 | 无 |
| UIViewController | Flame 宿主传 VC 模式不变 | 不变（Taku 内部对 adapter 透明） | ✅ | 无 | 无 |
| Orientation | Flame 胶水不干预方向；由 Taku/宿主决定 | 不变 | ✅ | 无 | 无 |
| Callback | Flame Listener 协议不变 | 不变（胶水转发层零改动） | ✅ | 无 | 无 |
| Error Mapping | Taku 错误码透传不变 | 不变（缺 adapter 场景新增 2002/2006 语义，见 §12） | ✅ | 无 | 无 |
| Revenue | 未知（三方形态报表口径不明） | 官方源 firm_id=97，`/v2/fullreport` 可按 `network_firm_id` 拆分；`revenue` 字段口径不变 | ⚠️ 报表归属需后端核验（见 §14） | 无 | 无 |

**不等价项（均非代码 blocker）**：
1. **报表归属**（非 blocker）：官方源按 firm_id=97 上报；若历史 waterfall 中存在 0.1.7 时代自定义源（firm_id 为自定义平台分配 ID），切换后 Funlink 收益行会从旧 ID 迁移到 97——后端需做 ID 映射/并集（§14）。
2. **0.1.7 专属兼容**（非 blocker）：0.1.7 客户端既不满足 6.5.52 也不含官方 adapter，遇官方源必然 no-fill（§12）。

---

## 8. 宿主公共契约兼容审计

### 8.1 当前宿主真实依赖面（代码实证）

| 契约项 | 现状 | 证据 |
|---|---|---|
| public headers | 伞头文件 7 个 import（Callback/Splash/Banner/BannerMaterial/BannerRenderSlots/Reward/Interstitial/FlameSdk；Native 经 FlameSdk.h 引入） | `flame_sdk_ios/flame_sdk_ios.h` |
| init API | `+initWithAppId:appKey:(callback:)` / `+clear` / `+setDebug:` / `+isInitialized` / `-getVersion` | `core/FlameSdk.h` |
| load/show API | 各类型 create/load/show/destroy/isReady/isLoading；Splash `show:(UIWindow*)`；Banner `retrieveAdView`/物料 API | docs/knowledge/flame_sdk_ios/12（全表） |
| UIViewController 参数 | create 阶段传 VC（Splash/Banner 另有 UIWindow/VC 参数），**宿主自管 VC** | `FlameSdk.h` |
| delegates | `FlameCallback` + 五类 Listener 协议（错误码为字符串） | `core/FlameCallback.h` 等 |
| config keys | 无宿主可见 config key；服务端 pIds 透明 | §2 |
| Info.plist / URL Scheme / SKAdNetwork / ATS | 宿主自配：ATS `NSAllowsArbitraryLoads`、`NSUserTrackingUsageDescription`、SKAdNetworkItems（Demo 21 个） | Demo `Resources/Info.plist`；README |
| `-ObjC` | podspec `user_target_xcconfig` 自动注入 | `flame_sdk_ios.podspec:93-95` |
| CocoaPods 依赖 | `flame_sdk_ios`（flame-specs + trunk）→ 传递 AnyThinkiOS 6.5.71 + 13 个广告源 adapter + FunlinkSDK + OpenSSL | podspec / Demo Podfile.lock（TK 线 28 pods） |
| SPM | **不支持**（官方与 Flame 均无） | 全仓库无 Package.swift |
| resource bundles | Flame 无独立 bundle（OpenSSL 动态 framework 由依赖带入） | podspec |
| minimum deployment target | iOS 13.0 | podspec:45 |
| module name | `flame_sdk_ios` | podspec:28 |

### 8.2 迁移后判定

| 级别 | 内容 |
|---|---|
| **0 Breaking** | **全部**。Funlink 官方 Adapter 本就是 `flame_sdk_ios`（≥0.1.8）podspec 传递依赖的一部分；宿主视角的 headers/API/回调/错误码/plist/linker/最低系统零变化。已接 1.0.x 的宿主**无需任何动作**。 |
| Soft change | 无。 |
| Breaking | 无。 |

> **`Host API Contract = 0 Breaking Change: YES`**（最小 breaking surface：空集）

---

## 9. iOS 二进制与依赖冲突专项

### 9.1 Binary packaging 现状

| 产物 | 形态 | 链接方式 | 证据 |
|---|---|---|---|
| `flame_sdk_ios.xcframework`（TK） | **静态** framework（FMWK 外壳 + ar 归档） | 链接进宿主主程序；AnyThink/OpenSSL 符号在宿主链接期解析 | `file`: current ar archive；podspec 注释 |
| AnyThinkSDK（AnyThinkiOS 6.5.71 pod） | **动态** framework（Mach-O dylib） | 宿主 App 内嵌动态库 | `file`: dynamically linked shared library |
| AnyThinkFunlinkAdapter | **静态**归档（`static_framework: true`） | 经 CocoaPods 静态链入 App | trunk podspec + `file` |
| FunlinkSDK（FLinkAdSaas） | **静态**归档（FMWK 外壳 + ar 本体，`static_framework: true`） | 经 CocoaPods 静态链入 App | trunk podspec + `file` |
| OpenSSL-Universal | 动态 framework | 宿主内嵌 | Flame podspec 注释 |
| 分发方式 | CocoaPods vendored xcframework + 依赖传递；**无 SPM**；**无手工 framework 分发** | — | podspec |

### 9.2 冲突场景分析

| 场景 | 分析 | 结论 |
|---|---|---|
| 宿主已自用 Taku（AnyThinkiOS） | Flame 精确锁 6.5.71 → 版本不同则 `pod install` 冲突报错（可发现、可协商），相同则共用 | ⚠️ 已有约束，与 Funlink 迁移无关 |
| 宿主已自用 Funlink（FunlinkSDK/官方 adapter） | 同上：CocoaPods 版本仲裁；FunlinkSDK 被官方 adapter 精确锁 2.9.0.1.2，宿主若锁其他版本会显式冲突 | ⚠️ 已有约束 |
| 宿主用另一套 mediation（如 GroMore 直连/TradPlus） | 共享底层 SDK（BUAdSDK/CSJ 等）版本仲裁冲突，`pod install` 阶段暴露；官方 Funlink adapter 不新增此类风险 | ⚠️ 既有风险面不变 |
| duplicate symbols / duplicated frameworks | Funlink adapter+SDK 均为静态归档、按 pod 名单一来源（trunk），无第二份拷贝来源；Flame 不 re-vendor Funlink | ✅ 无新增 |
| module name collision | Funlink adapter module=AnyThinkFunlinkAdapter、FunlinkSDK module=FLinkAdSaas，与 `flame_sdk_ios` 无碰撞；umbrella header 互不相交 | ✅ |
| Swift ABI | Funlink 全链 ObjC 静态归档；无 Swift 运行时版本耦合（podspec swift_version 仅元数据） | ✅ |
| resource bundle 冲突 | 三者均无独立 bundle | ✅ |
| category 丢失 / `-ObjC` | Flame 已强制宿主 `-ObjC`（强于 FunlinkSDK 的 `-lObjC`），+load 注册与 category 均被加载 | ✅ |
| privacy manifest 冲突 | FunlinkSDK/AnyThinkSDK 各带各的 PrivacyInfo，App 层聚合规则由 Apple 合并语义处理，无同 key 冲突（§11） | ✅ |
| SKAdNetwork 重复 | SKAdNetworkItems 由宿主 Info.plist 维护，重复 ID 无害（系统去重）；无 SDK 强制注入 SKAN 条目 | ✅ |
| runtime class / selector collision | 官方 `ATFunlink*` 类名唯一；0.1.7 时代的 `FLTopOnAdapter` 类名体系已随 0.1.8 移除，任何一版 Flame 内只存在一套 Funlink adapter 类 | ✅ |
| 模拟器 slice | FunlinkSDK 排除 i386（仅影响老 Intel 32 位模拟器）；arm64/x86_64 sim slice 齐全；无 EXCLUDED_ARCHS[sdk=iphonesimulator*]=arm64 类问题（对比 ToBid MTG adapter 的已知限制） | ✅ |

### 9.3 App Store 合规（§11 详述）

官方 Funlink 迁移（已完成的 0.1.8 变更）引入的隐私面 = FunlinkSDK 静态归档本体：自带 `PrivacyInfo.xcprivacy`（DeviceID/Tracking=true/ThirdPartyAdvertising、SystemBootTime 等）、依赖 IDFA 相关 framework（AdSupport/AppTrackingTransparency/DeviceCheck）。**无新增权限、无新 tracking domain 声明义务**（由各 SDK 自带 manifest 承担）。

---

## 10. UIKit / UIViewController 生命周期

| 检查项 | Flame 现状 | 官方 Funlink Adapter 下是否安全 |
|---|---|---|
| Taku UIViewController 模型 | 宿主 create 时传 VC；Reward/Interstitial show 传 `inViewController`；Splash 传 `window + inViewController`；Banner `presentingViewController`；Native `ATNativeADConfiguration.rootViewController` | ✅ 与官方 adapter 无耦合——adapter 层的 VC 由 Taku Core 注入，Flame 胶水行为不变 |
| Funlink 官方 adapter 是否需要 presenting VC | 需要（全屏类必须有可 present 的 VC）——由 Taku Core 统一供给，Flame 已满足 | ✅ |
| Flame 是否包装 UINavigationController | **否**（无任何导航容器包装） | ✅ 无包装失效风险 |
| child containment / tabbar 内嵌 | Native 自渲染由宿主容器承载；Banner addSubview 模式（5A.16E 坐标审计通过） | ✅ 不受 adapter 层切换影响 |
| modal fullScreen | Taku 内部决定；Flame 不干预 | ✅ |
| portrait/landscape | Flame 胶水无方向干预代码 | ✅ |
| SceneDelegate / 多 window / iPad | Splash show 显式收 UIWindow 参数（宿主决定窗口）；其余 VC 由宿主传入；无 keyWindow 全局取用 | ✅（宿主对多 window 的既有语义保持不变） |
| 0.1.7→0.1.8 页面容器语义差异 | 二者都在 Taku Core 之下；页面容器行为由 Taku Core（6.5.42→6.5.71）与 FunlinkSDK 决定，**不存在 Flame 层包装需要重验的问题** | ✅；但 Core 升级伴随的全量真机回归已在 1.0.x 发布流程中完成（README 验证状态表） |

> 结论：**切官方 Adapter 后页面容器语义安全性 = 已被 0.1.8 以来的真实发布与真机验证覆盖**（TK 线 28 pods 全广告位真机验证记录见 README「当前验证状态」）。

---

## 11. Privacy / App Store 合规

| 项 | 现状 | 迁移影响 |
|---|---|---|
| Flame 自身 PrivacyInfo.xcprivacy | **Flame framework 无自带 privacy manifest**（Headers/Info.plist/Modules/二进制四件套） | 无变化（与本调研无关的既有债务，见 docs/knowledge 10） |
| FunlinkSDK privacy manifest | 自带：`NSPrivacyCollectedDataTypes`（DeviceID, Tracking=true, ThirdPartyAdvertising；PerformanceData）+ `NSPrivacyAccessedAPITypes`（SystemBootTime 等 Required Reason API） | 官方源与三方源使用同一 FunlinkSDK 2.9.0.1.2，**零差异** |
| AnyThinkSDK privacy manifest | 自带 | 零差异 |
| IDFA / ATT / NSUserTrackingUsageDescription | 宿主负责配置（Demo 已配 `NSUserTrackingUsageDescription`）；FunlinkSDK 链接 AdSupport/AppTrackingTransparency/DeviceCheck | 零差异 |
| tracking domain | 由各 SDK manifest 申报，无宿主新增义务 | 零差异 |
| Required Reason API | FunlinkSDK manifest 已申报 SystemBootTime | 零差异 |
| 新权限/隐私披露 | 无（Funlink adapter/SDK 不含权限触发代码；CoreTelephony/CoreLocation 为链接依赖） | 零差异 |
| SKAdNetwork | 宿主 Info.plist 配置（Demo 21 个 ID） | 零差异 |

> 结论：**官方 Funlink 迁移不引入任何新的合规动作**（因为 FunlinkSDK 二进制在 0.1.7→0.1.8 迁移前后都是同一供应商的同一版本族）。

---

## 12. 旧版 Flame SDK × 新 Taku 后台兼容（关键问题正面回答）

> **问题：Taku 后台直接将（自定义/Funlink 相关）广告源替换为官方 Funlink Network 源，线上旧 Flame iOS SDK 会怎样？**

### 12.1 分版本行为推演

| 线上版本 | 是否含官方 Funlink Adapter | AnyThinkiOS | 遇官方 Funlink 源（firm_id=97）的行为 |
|---|---|---|---|
| ≤ 0.1.6 | ❌ 完全无 Funlink | 6.5.34/6.5.42 | 该源请求时缺 adapter → Taku 报错误码 **2002**（"SDK 包导入不全，缺失第三方广告平台的 Adapter 包"）/ **2006**（版本不符），**不崩溃**，waterfall 顺序跳到下一源；全部源失败才 4005 no-fill |
| 0.1.7 | ❌ 只有 Funlink 方三方 adapter（FLTopOnAdapter） | 6.5.42（**< 6.5.52 不满足官方源最低要求**） | 官方源同样 2002/2006 no-fill；三方 adapter 仅服务旧后台配置（若后台已无对应自定义源则彻底失效） |
| **0.1.8 – 0.1.8.4** | ✅ 官方 adapter 2.9.0.1.2.2.0 | 6.5.71（≥6.5.52 ✅） | **正常参与 waterfall** |
| 1.0.0–1.0.1-alpha.4 | ✅ 同上 | 6.5.71 | **正常参与 waterfall** |

依据：官方错误码表（https://help.toponad.net/cn/docs/SDWgql 2002/2006/4005）、waterfall 顺序请求语义（https://help.toponad.net/cn/docs/chang-jian-wen-ti "顺序请求…全部失败才回调失败"）、官方 Funlink 源 SDK≥6.5.52 要求（https://help.takuad.com/docs/YfG41D3N）。**Taku 官方文档未明文描述"缺 adapter"一词，本节 2002/2006/4005 为官方错误码语义推演**（已在表中注明）。

### 12.2 并存与定向能力

1. **同 placement 新旧广告源并存**：✅ 官方支持一个 waterfall 多层多源（含同平台多源）；自定义源与官方源并存无互斥说明（https://help.takuad.com/docs/wlZjyk 广告源配置）。注意：**自定义源不支持自动价格、报表数据只能手动上传**（https://help.takuad.com/docs/fRMh7C）——并存期间两源收益口径不可比。
2. **Taku 定向灰度**：✅ 官方流量分组支持**按 SDK 版本（type 9）、App 版本（type 8）、渠道、设备等维度配置不同 waterfall**，1 个广告位可配多个分组按优先级返回；另有 A/B 测试（最多 10 组、按比例切量）（https://help.takuad.com/docs/nL5nyX 、https://help.toponad.net/cn/docs/3Uq5Zc 、https://help.toponad.net/cn/docs/cDHvbn）。
3. **后台配置生效范围**：配置约 5 分钟对**全部客户端**生效，不区分版本——因此"只让新 SDK 收到官方源"必须用流量分组或 Flame 侧路由，不能裸切。

### 12.3 安全灰度模型（设计，不实施）

理想模式 **old Flame SDK → 旧配置；new Flame SDK → 官方 Funlink**，推荐双通道（任选其一，推荐 A）：

**方案 A（推荐）：Flame 后端 pIds 版本路由（Flame 已有能力，零 Taku 依赖）**
- Taku 后台新建 iOS 官方 Funlink 广告源，挂到**新 Taku placement**（不动老 placement）；
- Flame 后端 `/api/v1/sdk/init` 按 SDK 版本（请求已携带 `version`，FlameConfigManager.m:143）下发不同 `pIds`：旧版本→老 placement，新版本→新 placement；
- 优点：灰度粒度/回滚都在 Flame 自己手里；老客户端完全无感；无需 Taku 分组配置。

**方案 B：Taku 流量分组（SDK 版本 type 9）**
- 同一 Taku placement 内建两个分组：SDK 版本 ≥ 0.1.8 → 官方 Funlink 源；其余 → 原配置；
- 优点：单一 placement；缺点：依赖 Taku 后台配置正确性，回滚走 Taku。

**无论 A/B**：0.1.x 老版本是否仍在投放需要先拿版本分布数据（flame-specs 下载统计 / Flame 后端 init 日志 `version` 字段）——若 ≤0.1.7 已归零，灰度可直接简化为后台平切。

---

## 13. Taku 后台迁移与运营决策树

本仓库**无法**核验 Taku 后台配置（服务端事实）。给出决策树供运营/后端执行：

```
登录 Taku 后台 → 目标 iOS App → 检查 Funlink 相关广告源：
├─ 情形 1：已存在「泛连/Funlink」官方源（平台=泛连，firm_id=97）
│   → 结论：iOS 侧迁移已彻底完成（代码+后台均官方化），只需按 §14 核对报表。
├─ 情形 2：存在「自定义广告平台」型 Funlink 源（自定义 firm_id）
│   → 说明 0.1.7 时代配置残留。iOS 客户端从未实现自定义平台 adapter 类，
│     这些源在 iOS 上要么一直 no-fill，要么从未配置到 iOS waterfall。
│   → 行动：新建官方泛连源（APP ID + Unit ID），按 §12.3 灰度切换，
│     然后删除/停用自定义源（防报表口径混淆）。
└─ 情形 3：iOS waterfall 无任何 Funlink 源
    → Funlink 此前仅用于其他端。行动：仅当 iOS 也需要 Funlink 时，
      按官方文档新建泛连源 + 配置报表 API（API KEY/SECRET）。
```

配套检查项：
- [ ] 泛连（Funlink）账号报表 API 绑定：Funlink 后台「账户信息→key」取 API KEY + API SECRET → Taku 后台泛连平台编辑页开通报表 API（help.takuad.com/docs/YfG41D3N）；
- [ ] Taku 后台「集成检测/测试」确认 iOS 各 placement 的 Funlink 源可填充（`ATSDK.integrationChecking` 日志中 networkFirmId/handle_class 可核对 adapter 挂接）。

---

## 14. 收益链路关联（本轮不改后端）

三条链路区分：

| 链路 | 承担方 | Funlink 相关要点 |
|---|---|---|
| SDK 展示链路 | Flame 胶水 → Taku Core → ATFunlink*Adapter → FunlinkSDK | 与收益口径无关；客户端仅插屏有（误映射的）`didRevenue` 回调，不参与结算 |
| Taku Network 报表链路 | Taku 后台 ← Funlink Report API（API KEY/SECRET 绑定后 Taku 自动拉取） | 官方源按 `network_firm_id=97` 归集；自定义源（若有）无 API 收益、只能手动上传——**这是官方源的最大报表优势** |
| Flame 后端结算链路 | Flame 后端 → `POST https://openapi.toponad.com/v2/fullreport` | `revenue`（收益 API，开发者账号币种）口径不变 |

- **`/v2/fullreport` 关键参数/返回**：`network_firm_id_list` 过滤、`group_by` 支持 `network_firm_id`/`placement`/`sdk_version`/`app_version` 等，返回 `placement.id`（开发者后台广告位 ID）、`network_firm_id`、`adsource.*`、`sdk_version` 等（https://help.takuad.com/docs/dukFyc 《综合报表》）。**用 `network_firm_id=97` 验证 Funlink 官方收益完全可行。**
- **切换日收益连续性**：若切换是"同 placement 换源"，adsource_id 变化但 placement.id 不变，按 placement 汇总的 `revenue` 连续；按 network_firm_id 拆分时，Funlink 行从旧（自定义）ID 迁移到 97，**后端需在切换日做 firm_id 并集映射**（`firm_id ∈ {97, 旧自定义ID}` → Funlink）。
- **双计风险**：同一展示只会归入其所属源的一个 firm_id，Taku 侧不存在同展示双计；真正的风险是**口径分裂**（Funlink 收益分散在两个 ID 上被漏算/错算），非重复计入。
- **验证口径建议**：单应用 × 单 placement × 单官方 Funlink adsource → Taku dashboard 概况页数值 vs `/v2/fullreport`（`network_firm_id=97`）vs Funlink 后台 T-1 报表三方对账。

---

## 15. 推荐迁移方案（Recommended Migration）

**SDK 代码侧：零改动**（禁止事项清单中的升级/改 adapter/改 podspec/发新包，全部无需执行）。

**实施清单（全部为运营/后端动作）**：

1. 运营：按 §13 决策树核验 Taku 后台 iOS Funlink 源形态；必要时新建官方泛连源并按 §12.3 灰度；
2. 运营：绑定 Funlink Report API（API KEY/SECRET）；
3. 后端：确认 `/v2/fullreport` 拉取是否需要把 `network_firm_id=97` 加入过滤/分组（当前若按全平台拉取则无需改动，只需在结算侧把 97 识别为 Funlink）；
4. 后端：核对切换日 firm_id 映射（若存在历史自定义源 ID）；
5. 数据：拉线上 Flame SDK 版本分布（`/api/v1/sdk/init` 日志 version 字段），确认 ≤0.1.7 占比，决定灰度方案 A/B 或直接平切；
6. （可选、独立决策，**不属于本迁移**）：AnyThinkiOS 6.5.71 → 6.5.82 及 FunlinkSDK 新版的跟进升级，按常规 SDK 版本流程另行评估。

---

## 16. Preconditions（进入"实施"前的条件清单）

| # | 条件 | 类型 | 当前状态 |
|---|---|---|---|
| 1 | Taku 后台 iOS Funlink 源形态核验（§13 决策树） | 运营核验 | **未完成**（仓库不可见） |
| 2 | 线上 SDK 版本分布（≤0.1.7 占比） | 数据核验 | **未完成** |
| 3 | Funlink Report API 绑定状态 | 运营核验 | **未完成** |
| 4 | `/v2/fullreport` Funlink 行 firm_id 归属抽样 | 后端核验 | **未完成** |
| 5 | 结算侧 firm_id=97 映射确认 | 后端核验 | **未完成** |
| 6 | 官方 Adapter/版本合规（≥6.5.52、adapter 最新、五类广告、C2S bidding） | 已核验 | ✅ 本报告 §3/§6 |

条件 1–5 全部通过后，本事项即无剩余工作（SDK 侧本就无待实施项）；任一条件失败（例如后台存在大量依赖自定义源的地域）也**不产生 SDK 代码工作**，只影响运营切换策略。

---

## 17. 后续实施验证计划（设计，不执行）

### 17.1 SDK 功能回归（若运营切换后台配置后）

- init（含 pt=tk 路由、缓存回退）、load、show、全回调矩阵（loaded/show/click/playComplete/reward/close/error/timeout）；
- **Funlink 专项**：Funlink 源真实填充的 Splash 冷启动、Reward 完整闭环 + transId 对账（`[TK_REWARD_DIAG]` src= 标注）、Banner Express/SelfRender、Interstitial、Native Express/自渲染；
- 场景：scene 切换、退后台再回、VC dismiss 后再 load、旋转、iPad、多 window、弱网、并发 load、bidding 竞得/竞失。

### 17.2 集成矩阵

CocoaPods（flame-specs+trunk）／manual（OSS zip，仅在必要时）／ObjC Host／Swift Host／`use_frameworks!` 开关／release archive／TestFlight／真机（iOS 13/16/17/18+）／模拟器（arm64 AS+Intel x86_64）；SPM 不适用（官方无支持）。

### 17.3 收益验证

单应用 → 单 placement → 单官方 Funlink adsource → Taku dashboard 与 `/v2/fullreport`（`network_firm_id=97` + `group_by=network_firm_id,placement`）→ Funlink 后台 T-1 报表，三方数值对齐（时区注意：Funlink 报表 UTC+8，见 §6-9 概况页）。

---

## 18. Rollback Strategy

| 阶段 | 回滚动作 | 影响 |
|---|---|---|
| Taku 后台灰度切换后 | 后台把 waterfall/流量分组切回旧配置（约 5 分钟全网生效） | 无版本发布，秒级 |
| Flame 后端 pIds 方案（§12.3-A） | 后端把 pIds 映射回老 placement | 下一次 init 生效 |
| 结算口径 | 撤销 firm_id 映射变更 | 仅报表口径 |
| SDK 版本本身 | **无需回滚**（0.1.8 以来 SDK 二进制未因 Funlink 变化；1.0.1-alpha.4 的变更仅为 reward 回调修复，与 Funlink 无关） | — |

---

## 19. Final Status

> ## `READY_WITH_CONDITIONS`

- **SDK 代码侧**：无任何待实施项——官方 Funlink Network Adapter 自 0.1.8（2026-06-04）起即为 TK 线唯一 Funlink 形态，当前版本（1.0.1-alpha.4）使用的是 **trunk 最新官方 adapter 2.9.0.1.2.2.0**，Core 6.5.71 满足官方 ≥6.5.52 要求。原始命题中的"Custom Funlink Adapter"在 iOS 全部已发布版本中不存在。
- **`Host API Contract = 0 Breaking Change: YES`**（空集 breaking surface）。
- **进入下一阶段（实施/切换）的前置条件**：§16 条件 1–5（全部为运营/后端核验，无一为代码工作）。
- **与旧结论的裁定**：官方 Funlink 最低 Taku SDK = **6.5.52**（文档口径，高于 podspec 下限 6.5.45）；以本次 2026-09-14 官方核验为准。

---

## 20. Evidence Index

### A. 代码证据（仓库内）

| 证据 | 路径 |
|---|---|
| TK podspec（Funlink 官方依赖 :72、AnyThinkiOS 6.5.71 :58、-ObjC :89-95） | `flame_sdk_ios.podspec` |
| TB podspec（无 Funlink） | `flame_sdk_ios_tb.podspec:73-80` |
| Podfile / Podfile.lock（AnyThinkiOS 6.5.71、ToBid 5.5.6） | `Podfile`、`Podfile.lock` |
| 初始化链 | `flame_sdk_ios/mediation/tk/FlameTKProvider.m:42`、`core/FlameSdk.m:136`、`adapter/FlameAdapterManager.m:61` |
| 配置/映射 | `core/FlameConfigManager.m:100,143,337`（init 请求/`version` 字段/getPId） |
| 胶水实现 | `adapter/tk/AtRewardAdapter.m`（capturedShowId :15、MediaExtraKey :62、transId 链 :164-177）、`AtSplashAdapter.m:75-103`（window+config show）、`AtInterstitialAdapter.m:146`（didRevenue→onAdReward）、`AtSplashAdapter.m:193`、`AtBannerAdapter.m:124-128`、`AtNativeAdapter.m:108-285` |
| 构建形态 | `xcFramework_build.sh`（tk-static/tb-static/Wind 隔离）、`flame_sdk_ios.xcframework`（ar archive 实测） |
| 知识库基线 | `docs/knowledge/flame_sdk_ios/04/05/11/12` |
| 发布快照 | `docs/releases/1.0.1-alpha.4.md`（transId 官方文档依据） |

### B. 二进制证据（本机 Pods / 官方包）

| 证据 | 结论 |
|---|---|
| `adsurge-ios-demo/Pods/AnyThinkMediationFunlinkAdapter/.../AnyThinkFunlinkAdapter` | ar 静态归档；ObjC 类 = `ATFunlink{Init|Splash|Banner|Interstitial|RewardedVideo|Native}Adapter` + `ATFunlinkNativeObject/RenderWrapView` |
| `Pods/FunlinkSDK/FLinkAdSaas.framework` | 静态归档（ar）；MinOS 10.0（plist）/podspec iOS 11；自带 PrivacyInfo.xcprivacy；含 FLinkBiddingModel(firstPrice/secondPrice/isWin/bidfloor)、五类 Manager |
| `Pods/AnyThinkiOS/core/AnyThinkSDK.framework` | 动态 dylib；MinOS 10.0；自带 PrivacyInfo.xcprivacy；arm64+arm64_x86_64-sim 双 slice |
| trunk podspec.json（本地 specs 缓存） | `AnyThinkMediationFunlinkAdapter 2.9.0.1.2.2.0`：author topon、source=TopOn OSS、依赖 `AnyThinkiOS>=6.5.45` + `FunlinkSDK==2.9.0.1.2`、iOS 11、static_framework |
| `~/.cocoapods/repos/trunk/Specs` 版本目录 | FunlinkAdapter 仅 2 版（2.9.0.1.2.0/2.2.0）；FunlinkSDK 至 2.9.0.2.8（缓存快照，在线最新 2.9.0.3.0）；AnyThinkiOS 至 6.5.81（缓存快照，在线最新 6.5.82） |
| `~/.cocoapods/repos/javaice007-flame-specs/flame_sdk_ios/` | 全部 20 个已发布版本逐个 grep：0.1.0–0.1.6 无 Funlink；0.1.7=FunlinkTopOnAdapter+FLAD+FunlinkSDK 2.9.0.1.0；0.1.8+ = 官方 adapter + 6.5.71 |
| `adsurge-ios-demo/Podfile(.lock)`、`Resources/Info.plist` | 宿主接入形态（1.0.1-alpha.4、flame-specs+trunk）、ATS/NSUserTrackingUsageDescription/21 个 SKAdNetwork ID |
| git 全历史 | `git log --all -S 'registerCustomNetwork' / -S 'ATFunlink'` 零命中 |

### C. 官方文档证据（网络核验，2026-09-14）

| 主题 | URL / 页面标题 |
|---|---|
| Funlink 接入官方页（≥6.5.52、APP ID/Unit ID、API KEY/SECRET 绑定） | 《泛连(Funlink) - Taku 帮助中心》 https://help.takuad.com/docs/YfG41D3N |
| 平台 ID 对照（Funlink=97，Bidding C2S ✓/竞价底价 ✓/常规底价 ✗） | 《聚合平台概况 - Taku》 https://help.takuad.com/docs/2KR6QU |
| SDK 导入（CocoaPods/手动/Xcode 要求） | 《Taku SDK导入说明》 https://help.takuad.com/docs/zODjLF |
| 错误码（2002/2006/4005） | 《错误码说明(iOS)》 https://help.toponad.net/cn/docs/SDWgql |
| waterfall 顺序请求/全败才失败/配置 5 分钟生效 | 《常见问题》 https://help.toponad.net/cn/docs/chang-jian-wen-ti |
| 流量分组（SDK 版本/应用版本维度） | 《流量分组》 https://help.takuad.com/docs/nL5nyX |
| AB 测试/Open API segment type | 《A/B测试》 https://help.toponad.net/cn/docs/cDHvbn 、《AB测试及流量分组管理》 https://help.toponad.net/cn/docs/3Uq5Zc |
| 自定义广告平台机制（含"自定义源无自动价格/手动上传报表"） | 《自定义广告平台》 https://help.takuad.com/docs/fRMh7C |
| /v2/fullreport（network_firm_id/revenue/group_by） | 《综合报表》 https://help.takuad.com/docs/dukFyc 、《数据报表API》 https://help.toponad.net/cn/docs/Rf16i5 |
| trunk 版本/owner | https://trunk.cocoapods.org/api/v1/pods/AnyThinkMediationFunlinkAdapter 、https://trunk.cocoapods.org/api/v1/pods/FunlinkSDK 、https://trunk.cocoapods.org/api/v1/pods/AnyThinkiOS |
| Funlink 官方 SDK releases / 官网 | https://github.com/QianChengWuXian/FunlinkSDK/releases 、《泛连》官网 https://www.adfunlink.com/ （运营方：北京泛连科技有限公司）、开发者后台 union.funlinkads.com |
| 0.1.7 三方 adapter 分发源 | Gitee https://gitee.com/mergex/funlinktoponadapter （北京前呈无限科技/Mediatom 体系）；FunlinkSDK homepage https://www.mediatom.cn/dockingdocs/detail?id=70 |

### D. 证据边界（诚实声明）

1. **Taku 后台当前 iOS Funlink 源配置**：服务端事实，本仓库不可见，标记为 §16 条件 1（UNKNOWN → 需运营核验）。
2. **线上 ≤0.1.7 版本分布**：无数据源，标记为 §16 条件 2。
3. **"缺 adapter → 2002/2006/跳源"为官方错误码语义推演**：官方无该场景明文页（竞品 TradPlus 才有"adapter not found"字样），已在 §12 标注。
4. **Adapter 版本命名规则**（前 5 段=FunlinkSDK 版本）为 podspec 依赖锁定的强推断，无官方明文。
5. `AnyThinkMediationFunlinkAdapter` pod 名未见于公开文档正文（登录态下载中心生成），权威性由 trunk 官方发布者 + 官方 OSS 包 + 二进制类名三重交叉验证。
