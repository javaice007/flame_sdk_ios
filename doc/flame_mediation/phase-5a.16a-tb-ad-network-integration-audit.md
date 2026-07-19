# Phase 5A.16A：ToBid 第三方广告源交付包审计与集成方案设计

> **本阶段性质**：只读审计 + 方案设计。**不创建 TbBannerAdapter，不修改 Banner 业务代码，不修改正式 podspec，不修改远程 specs**。仅产出报告，等待用户确认广告源范围后再进入正式集成。

---

## 1. 基线

| 项 | 值 |
|---|---|
| SDK 路径 | `/Users/khj/Documents/code/97_ad/ios/flame_ios_sdk` |
| Demo 路径 | `/Users/khj/Documents/code/97_ad/ios/adsurge-ios-demo` |
| SDK 分支 | `release/ios-dual-line` |
| SDK HEAD（开始） | `60cb785`（Phase 5A.15.1 收口） |
| Demo HEAD | `11c5958`（Phase 5A.14.1） |
| 当前 TB Podfile.lock | `flame_sdk_ios_tb 1.0.0-alpha.4-local` + `OpenSSL-Universal 3.6.2000` + `ToBid-iOS-RC 5.5.6`（仅 `ToBidSDK` subspec，4 pods） |
| 广告源资料目录 | `/Users/khj/Documents/code/97_ad/ios/flame_ios_sdk/doc/tobid_doc` |

**背景**：Sigmob 自身不提供 Banner 填充；Banner 必须由第三方广告源（ToBid AdNetworks）提供。当前 TB Demo 仅装了 ToBid 核心（`ToBidSDK`），无任何第三方广告源 SDK / Adapter，因此 Banner 链路无法填充。

---

## 2. 交付包文件清单

`doc/tobid_doc` 顶层结构：

```
tobid_doc/
├── ToBidDemo官方/                  <- 嵌套 git 仓库（Demo_OC + Demo_Swift + Example 4.6.0 旧样例 + README）
└── sdk集成下载说明/                <- 交付包本体（SDK 二进制 + Adapter + 文档）
    ├── 接入代码/
    │   ├── Cocoapod引用代码.txt    <- Pod 引用代码（ToBid-iOS-RC 5.5.6 全 subspec 列表）
    │   └── SkAdneworkIDs代码.txt   <- SKAdNetwork IDs（Sigmob/CSJ/Mintegral）
    └── tobid-sdk-ios-cn/
        ├── Core/                   <- 3 个核心 xcframework
        └── AdNetworks/             <- 8 个广告源目录（+ bidResult 工具）
            ├── baidu/
            ├── bidResult/          <- 工具插件，非广告源
            ├── csj/
            ├── gdt/
            ├── gromore/
            ├── kuaishou/
            ├── meishu/
            ├── mintegral-cn/
            └── octopus/
```

**文件类别（全部 iOS，无 Android/.aar/zip/tar/license/podspec）**：
- 集成文档：3 个 txt + README
- Podfile 示例（非真实 SDK）：3 个（Demo_OC/Demo_Swift/Example 各一份；Example 是 4.6.0 旧样例，**stale**）
- 核心二进制：`WindFoundation.xcframework` / `WindMillSDK.xcframework` / `WindSDK.xcframework`
- 广告源 SDK 二进制：BUAdSDK / GDTMobSDK / Tquic / KSAdSDK / BaiduMobAdSDK（**legacy `.framework`，非 xcframework**）/ MSAdSDK / MSAdMotion / MTGSDK + 7 个类型拆分 xcframework / OctAdSDK / OctCore / CSJMediation
- ToBid Adapter 二进制：WindMillCSJAdapter / WindMillGDTAdapter / WindMillBaiduAdapter / WindMillKSAdapter / WindMillMSAdAdapter / WindMillMTGAdapter / WindMillOctopusAdapter / WindMillGroMoreAdapter / WindMillBidResultPlugin（全部 `.xcframework`，版本 5.5.6）
- 资源 bundle：baidumobadsdk / CSJAdSDK / MSAdSDK / OctAdSDK / OctCore + ~14 个 KSU*Resource.bundle（含 KSUBannerAdResource.bundle）
- 隐私清单 PrivacyInfo.xcprivacy：BaiduMobAdSDK / baidumobadsdk.bundle / CSJAdSDK.bundle / GDTMobSDK / KSAdSDK / MSAdSDK.bundle / MTGSDK / OctAdSDK.bundle / WindFoundation / WindMillSDK / WindSDK

---

## 3. 广告源清单（逐家版本矩阵）

| 广告源 | SDK 文件 | Adapter 文件 | SDK 版本 | Adapter 版本 | 集成方式 | 依赖 |
|---|---|---|---|---|---|---|
| **CSJ / Pangle / 穿山甲** | `BUAdSDK.xcframework` | `WindMillCSJAdapter.xcframework` | **7.6.0.4** | 5.5.6 | CocoaPods `ToBid-iOS-RC/CSJAdapter` | `Ads-CN/BUAdSDK 7.6.0.4`，CSJAdSDK.bundle，Core |
| **GDT / 腾讯优量汇** | `GDTMobSDK.xcframework` | `WindMillGDTAdapter.xcframework` | **4.15.90**（strings 推断 2.80.6 是 marketing ver） | 5.5.6 | CocoaPods `ToBid-iOS-RC/GDTAdapter` | `GDTMobSDK 4.15.90`，Tquic.xcframework，Core |
| **Baidu / 百度联盟** | `BaiduMobAdSDK.framework`（**legacy .framework**） | `WindMillBaiduAdapter.xcframework` | ⚠️ **unknown**（Info.plist 标 1.0；后台实际为 `10.050`，见 §6） | 5.5.6 | CocoaPods `ToBid-iOS-RC/BaiduAdapter` | `BaiduMobAdSDK 10.050`，baidumobadsdk.bundle，Core |
| **Kuaishou / 快手** | `KSAdSDK.xcframework` | `WindMillKSAdapter.xcframework` | **5.4.10**（含 5.4.10.1 build tag） | 5.5.6 | CocoaPods `ToBid-iOS-RC/KSAdapter` | `KSAdSDK 5.4.10.1`，14× KSU*Resource.bundle，Core |
| **Mintegral / 汇量** | `MTGSDK.xcframework` + 7 拆分 xcframework（MTGSDKBanner / MTGSDKBidding / MTGSDKInterstitialVideo / MTGSDKNativeAdvanced / MTGSDKNewInterstitial / MTGSDKReward / MTGSDKSplash） | `WindMillMTGAdapter.xcframework`（**⚠️ 仅 ios-arm64 slice，无 simulator slice**） | **15.0.0**（build tag 1500.0.40） | 5.5.6 | CocoaPods `ToBid-iOS-RC/MintegralAdapter` | `MintegralAdSDK 7.7.6` + 8 子 pod（含 BidBannerAd），Core |
| **Meishu / MS / 美数 (MobSmart)** | `MSAdSDK.xcframework` + `MSAdMotion.xcframework` | `WindMillMSAdAdapter.xcframework` | ⚠️ **unknown**（Info.plist 标 1.0；build path `/Users/lijing/Desktop/MSAdSDK_2_4_X/` 推断 2.4.x；后台为 `MSMobAdSDK/MS 2.7.18.1`） | 5.5.6 | CocoaPods `ToBid-iOS-RC/MSAdAdapter` | `MSMobAdSDK/MS 2.7.18.1`，MSAdSDK.bundle，Core |
| **Octopus / 章鱼 (ZhiYu)** | `OctAdSDK.xcframework` + `OctCore.xcframework` | `WindMillOctopusAdapter.xcframework` | OctAdSDK **1.0.0**，OctCore **0.1.0**（后台 `OctopusSDK 2.6.4.29`） | 5.5.6 | CocoaPods `ToBid-iOS-RC/OctopusAdapter` | `OctopusSDK 2.6.4.29`，OctAdSDK.bundle + OctCore.bundle，Core |
| **GroMore（CSJ Mediation wrapper）** | `CSJMediation.xcframework`（7.6.0） | `WindMillGroMoreAdapter.xcframework` | 7.6.0 | 5.5.6 | CocoaPods `ToBid-iOS-RC/GromoreAdapter`（或 `GromoreAdapterLite`） | `Ads-CN/BUAdSDK 7.6.0.4` + `Ads-CN/CSJMediation 7.6.0.4`，Core |
| **Sigmob（内置，无独立目录）** | （编入 `Core/WindMillSDK.xcframework` 内的 `WindMillSigmobAdapter`） | （无独立 Adapter） | = WindMillSDK | = WindMillSDK | 已在 Core | Core |
| BidResult 插件（工具，非广告源） | — | `WindMillBidResultPlugin.xcframework` | — | 5.5.6 | `ToBid-iOS-RC/BidResultAdapter` | Core |

**版本说明**：SDK 二进制 Info.plist 的 `CFBundleShortVersionString` 普遍标 `1.0`（不可靠）。上表 SDK 版本以 **CocoaPods 后台 subspec 实际 pin 的版本**为准（§6 冲突审计交叉验证）。Adapter 版本统一 5.5.6（来自 `Cocoapod引用代码.txt`）。

**未在交付包的广告源**：Sigmob（无独立 SDK，已在 Core）、Vungle、AdColony、UnityAds、TapJoy、IronSource、Chartboost、Mintwheel、BeiZi/AdScope、FSUnion、Funlink、Smartdigimkt/AdGain、AnyThink、Admob、AppLovin。（`Example/Podfile` 引用了 AdmobAdapter/VungleAdapter/UnityAdsAdapter/KlevinAdapter/TouTiaoAdapter/CSJMediationAdapter/QuMengAdapter 等，但 **Example 是 4.6.0 旧样例，二进制未随交付，stale，不可作为正式接入依据**。）

---

## 4. 识别计划接入的广告源范围

| 广告源 | 是否属于本次计划范围 | 依据 | 待确认项 |
|---|---|---|---|
| CSJ / Pangle | ⚠️ 待确认 | 交付包完整，Banner 支持最成熟 | 后台是否已创建 CSJ 测试广告位 |
| GDT / 腾讯 | ⚠️ 待确认 | 交付包完整，UnifiedBanner | 后台是否已创建 GDT 测试广告位 |
| GroMore | ⚠️ 待确认 | 依赖 CSJ，与 CSJ/Gromore 二选一避免重复 | 是否与 CSJ 同时接入 |
| Mintegral | ⚠️ 待确认 | 交付包完整，独立 MTGSDKBanner；**Adapter 缺 simulator slice** | 是否接受模拟器构建失败（仅真机） |
| Meishu / MS | ⚠️ 待确认 | 交付包完整，MSBannerView | 市场份额与优先级 |
| Octopus / 章鱼 | ⚠️ 待确认 | 交付包完整，OctAdBanner | 市场份额与优先级 |
| Baidu | ❌ 不适合 Banner | ToBid BaiduAdapter **未实现 BannerAdAdapter**（仅 Reward/Interstitial/Splash/Native） | — |
| Kuaishou | ❌ 不适合 Banner | ToBid KSAdapter **未实现 BannerAdAdapter**（虽 KSAdSDK 含 KSUBannerAdResource.bundle，但 ToBid 侧未接入） | — |
| Sigmob | ❌ 内置无 Banner | 已确认 Sigmob 自身不提供 Banner 填充（Phase 5A.15 真机验证） | — |
| BidResult 插件 | ⚠️ 可选 | 非广告源，是 S2S 竞价结果工具 | 是否需要服务端竞价 |

> **关键结论**：Banner 候选广告源 = **6 家**（CSJ / GDT / GroMore / Mintegral / MS / Octopus）。具体接入哪几家、是否全部进入默认 `flame_sdk_ios_tb.podspec`、是否 subspec 拆分，**必须由用户拍板**（§11）。

---

## 5. 广告类型支持矩阵

依据 Adapter 二进制 `strings` 提取的 `<Type>AdAdapter` 类名（每个 adapter 内嵌 `ConfigAdapter` + 每种类型一对 `<Type>AdAdapter`/`<Type>AdListener`）：

| 广告源 | Reward | Interstitial | Splash | Banner | Native | 证据 |
|---|:-:|:-:|:-:|:-:|:-:|---|
| **CSJ / Pangle** | ✅ | ✅ | ✅ | ✅ | ✅ | `BUNativeExpressBannerView` + BannerAdAdapter |
| **GDT** | ✅ | ✅ | ✅ | ✅ | ✅ | `GDTUnifiedBannerView` + BannerAdAdapter |
| **GroMore** | ✅ | ✅ | ✅ | ✅ | ✅ | `BUMNativeExpressBannerView`（mediated CSJ） |
| **Mintegral** | ✅ | ✅ | ✅ | ✅ | ✅ | `MTGBannerAdView` + 专用 `MTGSDKBanner.xcframework` |
| **MS / 美数** | ✅ | ✅ | ✅ | ✅ | ✅ | `MSBannerView` + BannerAdAdapter |
| **Octopus** | ✅ | ✅ | ✅ | ✅ | ✅ | `OctAdBanner` + BannerAdAdapter |
| Baidu | ✅ | ✅ | ✅ | ❌ | ✅ | 无 BannerAdAdapter 类 |
| Kuaishou | ✅ | ✅ | ✅ | ❌ | ✅ | 无 BannerAdAdapter 类（KSU bundle 存在但未接入） |
| Sigmob（内置） | ✅ | ✅ | ✅ | ❌ | ✅ | 无 BannerAdAdapter |

### 5.1 Banner 尺寸 / 模板 / 自动刷新

| 项 | 状态 |
|---|---|
| 320×50 / 320×100 / 自适应 | 由 `WindMillBannerView.adSize` 属性返回实际尺寸；初始化可用 `initWithRequest:expect_size:` 传期望尺寸 |
| 模板渲染 | 各底层 SDK 用 `BUNativeExpressBannerView`（CSJ/Express）/ `GDTUnifiedBannerView`（GDT）/ `MTGBannerAdView`（MTG）等，由广告源 SDK 决定 |
| 自动刷新 | `WindMillBannerViewDelegate.bannerAdViewDidAutoRefresh:` / `failedToAutoRefreshWithError:` 回调存在；**自动刷新由 ToBid 后台 / 广告源 SDK 控制，不由 Flame/Demo 控制**（待确认 §11.8） |
| 资源 bundle | KS 需要 14× KSU*Resource.bundle；CSJ/GDT/Baidu/MS/Octopus 各带 1 个 .bundle |
| 额外初始化 | Mintegral 需要 `MintegralAdSDK` 8 个子 pod；CSJ/Gromore 需要 `Ads-CN` subspec 选择 |

---

## 6. 当前依赖树审计

### 6.1 `flame_sdk_ios.podspec`（TK）`s.dependency`（17 项）

| 类别 | 依赖 |
|---|---|
| 公共核心 | `OpenSSL-Universal ~> 3.6`、`AnyThinkiOS 6.5.71`、`ToBid-iOS-RC 5.5.6` |
| TK Mediation Adapter | `AnyThinkMediationAdxSmartdigimktCNAdapter 6.5.72.2.1`、`AnyThinkMediationGromoreAdapter 7.6.0.4.2.0`、`AnyThinkMediationBaiduAdapter 10.050.2.1`、`AnyThinkMediationMSAdapter 2.7.18.1.2.0`、`AnyThinkMediationZYAdapter 2.6.4.29.2.0`、`AnyThinkMediationFunlinkAdapter 2.9.0.1.2.2.0`、`AnyThinkMediationBeiZiAdapter 5.5.0.3.2.0`、`AnyThinkMediationKuaiShouAdapter 5.4.10.1.2.0`、`AnyThinkMediationTTAdapter_Mix 7.6.0.4.2.0`、`AnyThinkMediationGDTAdapter 4.15.90.2.0` |
| TK 广告源 SDK | `AdGainSDK 4.2.7.1`、`AdGainSDKTakuAdapter 4.2.7.1`、`FSUnionAdSDK 1.0.8.0` |
| TK 私有 Sigmob 包装 | `flame_sdk_ios_tk_sigmob_adapter 4.20.12.2.0`（复用 TopOn AnyThinkSigmobAdapter，**已剥离 SigmobAd-iOS**，WindSDK/WindFoundation 由 ToBid-iOS-RC 提供） |

### 6.2 `flame_sdk_ios_tb.podspec`（TB）`s.dependency`（仅 2 项）

| 类别 | 依赖 |
|---|---|
| 公共核心 | `OpenSSL-Universal ~> 3.6`、`ToBid-iOS-RC 5.5.6` |

**TB podspec 红线已落实**（注释明确禁止）：不带入 `AnyThinkiOS` / `AnyThinkMediation*` / `flame_sdk_ios_tk_sigmob_adapter` / `AdGain` / `FSUnion` / 独立 `SigmobAd-iOS`。

### 6.3 ToBid-iOS-RC 5.5.6 当前实际安装内容

**当前 TB Demo 仅装了 `ToBid-iOS-RC` 的 `default_subspecs = ToBidSDK`**，即：
- `Core/WindFoundation.xcframework`（Sigmob foundation，SM*/Wind* 工具类）
- `Core/WindMillSDK.xcframework`（ToBid 聚合核心，WindMillAds + 全广告类型 + custom-adapter 协议）
- `Core/WindSDK.xcframework`（Sigmob publisher SDK，WindAds + WindRewardVideoAd + WindSplashAdView 等）

**关键事实**：当前安装的 ToBid **无任何 `AdNetworks/` 目录、无任何第三方 Adapter framework、无任何 `.bundle` 资源**。`ToBidSDK` subspec 声明 0 个第三方 pod 依赖。**当前 TB 包无任何第三方广告 SDK，因此当前无任何重复符号风险**。

### 6.4 ToBid-iOS-RC 5.5.6 可用 subspec 全集（21 个，均未激活）

| Subspec | 拉取的第三方 pod（精确版本） |
|---|---|
| `ToBidSDK`（默认，已装） | （无） |
| `BidResultAdapter` | （无，自包含） |
| `CSJAdapter` | `Ads-CN/BUAdSDK 7.6.0.4` |
| `GromoreAdapter` | `Ads-CN/BUAdSDK 7.6.0.4` + `Ads-CN/CSJMediation 7.6.0.4` |
| `GromoreAdapterLite` | `Ads-CN/BUAdSDK 7.6.0.4` + `Ads-CN/CSJMediation-Only 7.6.0.4` |
| `GDTAdapter` | `GDTMobSDK 4.15.90` |
| `KSAdapter` | `KSAdSDK 5.4.10.1` |
| `BaiduAdapter` | `BaiduMobAdSDK 10.050` |
| `AdScopeAdapter` | `BeiZiSDK-iOS/BeiZiSDK-iOS 5.5.0.0` |
| `MSAdAdapter` | `MSMobAdSDK/MS 2.7.18.1` |
| `MercuryAdapter` | `MercurySDK 4.7.2` |
| `OctopusAdapter` | `OctopusSDK 2.6.4.29` |
| `AdmobAdapter` | `Google-Mobile-Ads-SDK 13.1.0` |
| `JADYunAdapter` | `JADYun 2.6.8` |
| `MintegralAdapter` | `MintegralAdSDK 7.7.6`（+ BidNativeAd/BidRewardVideoAd/BidNativeAdvancedAd/**BidBannerAd**/BidSplashAd/NewInterstitialAd/BidNewInterstitialAd 子 pod） |
| `VungleAdapter` | `VungleAds 7.5.3` |
| `UnityAdsAdapter` | `UnityAds 4.12.2` |
| `AppLovinAdapter` | `AppLovinSDK 13.6.1` |
| `IronSourceAdapter` | `IronSourceSDK 8.2.0.0` |
| `QuMengAdapter` | `QuMengAdSDK 1.6.0.5` |
| `JuTuiAdapter` | `JTAdSDK 4.2.3.1` |
| `WangMaiAdapter` | `AdWangMaiSDK 7.9.4.33` |
| `PTGAdapter` | `PTGAdFramework 2.3.11` |

> **关键设计结论**：**Banner 集成应通过 `ToBid-iOS-RC/<Network>Adapter` subspec** 拉取第三方 SDK，而**不是**在 `flame_sdk_ios_tb.podspec` 中重复声明 `Ads-CN`/`GDTMobSDK`/`KSAdSDK` 等。这样：① 单一来源（CocoaPods 合并解析，不会重复）；② 版本与 ToBid 5.5.6 测试通过的一致；③ 不需要在 Flame 主二进制里塞第三方 framework。

---

## 7. 冲突审计

### 7.1 TK 已有 vs TB 计划接入

| 广告源 | TK 已有（pod@ver） | TB 计划（ToBid subspec → pod@ver） | 版本冲突 | 符号风险 | 处理建议 |
|---|---|---|---|---|---|
| **Pangle / CSJ** | `Ads-CN/BUAdSDK 7.6.0.4` + `CSJMediation 7.6.0.4`（via TTAdapter_Mix + GromoreAdapter）；TK 还传递带入 `BUTTSDKFramework 1.48.2.3-premium`（via `Ads-CN/BUAdLive-Framework` 默认 subspec） | `CSJAdapter` → `Ads-CN/BUAdSDK 7.6.0.4` | ❌ 无（同版本 7.6.0.4） | LOW（同 pod 合并） | 单一来源 = `Ads-CN 7.6.0.4`。**避免 TB 侧再选 `Ads-CN/BUAdLive-Framework`**（会重复带入 BUTTSDKFramework） |
| **Baidu** | `BaiduMobAdSDK 10.050`（via BaiduAdapter） | `BaiduAdapter` → `BaiduMobAdSDK 10.050` | ❌ 无 | LOW | 同 pod 同版本，安全（但 Baidu 不支持 Banner，不在候选） |
| **GDT** | `GDTMobSDK 4.15.90`（via GDTAdapter） | `GDTAdapter` → `GDTMobSDK 4.15.90` | ❌ 无 | LOW | 同 pod 同版本，安全 |
| **KS / 快手** | `KSAdSDK 5.4.10.1`（via KuaiShouAdapter） | `KSAdapter` → `KSAdSDK 5.4.10.1` | ❌ 无 | LOW | 同 pod 同版本（但 KS 不支持 Banner，不在候选） |
| **MS / 美数** | `MSMobAdSDK/MS 2.7.18.1`（via MSAdapter） | `MSAdAdapter` → `MSMobAdSDK/MS 2.7.18.1` | ❌ 无 | LOW | 同 pod 同版本，安全 |
| **Octopus** | `OctopusSDK 2.6.4.29`（via ZYAdapter） | `OctopusAdapter` → `OctopusSDK 2.6.4.29` | ❌ 无 | LOW | 同 pod 同版本，安全 |
| **GroMore** | `Ads-CN/BUAdSDK + CSJMediation 7.6.0.4`（via GromoreAdapter） | `GromoreAdapter` / `GromoreAdapterLite` → 同 | ❌ 无 | LOW | 与 CSJ 二选一（避免同时拉 Ads-CN 两次，虽版本同） |
| **BeiZi / AdScope** | `BeiZiSDK-iOS 5.5.0.3`（via BeiZiAdapter） | `AdScopeAdapter` → `BeiZiSDK-iOS 5.5.0.0` | ⚠️ **版本不一致**（5.5.0.3 vs 5.5.0.0） | MEDIUM（如 TK+TB 同装会解析失败） | BeiZi 不支持 Banner，不在本次候选；如未来要接需先对齐版本 |
| **Mintegral** | TK 未带入 | `MintegralAdapter` → `MintegralAdSDK 7.7.6` | ❌ 无（TK 侧无） | NONE | TB 独占，安全 |
| **Sigmob / WindSDK** | TK 仅通过 `flame_sdk_ios_tk_sigmob_adapter`（已剥离 SigmobAd-iOS，运行时 lazy binding 复用 ToBid-iOS-RC 的 WindSDK/WindFoundation） | `ToBidSDK`（默认已装）= Sigmob 核心 | ❌ 无（设计如此） | MEDIUM-LOW | 红线：**绝不**额外加 `SigmobAd-iOS`（会与 ToBid 内置 WindSDK 冲突） |
| **Smartdigimkt / AdGain / FSUnion / Funlink / BUTTSDKFramework** | TK 独占（ToBid 无对应 subspec） | 不计划接入 | ❌ 无 | NONE | TK-only，不影响 TB |

### 7.2 关键结论

1. **当前 TB 包无任何重复符号风险**（只装了 ToBid 核心 3 个 xcframework）。
2. **所有 Banner 候选广告源（CSJ/GDT/GroMore/Mintegral/MS/Octopus）通过 ToBid subspec 接入，与 TK 已有版本完全一致或 TK 侧不存在**，CocoaPods 会合并解析为单一副本。
3. **唯一版本冲突** BeiZi（TK 5.5.0.3 vs ToBid 5.5.0.0）不在 Banner 候选范围。
4. **TK-only 组件**（Smartdigimkt/AdGain/FSUnion/Funlink/BUTTSDKFramework）无 ToBid 对应，不会在 TB 引入。
5. **BUTTSDKFramework 陷阱**：TK 经 `Ads-CN/BUAdLive-Framework` 默认 subspec 带入；TB 接 CSJ 时**只选 `Ads-CN/BUAdSDK` + `CSJMediation-Only`，不选 `BUAdLive-Framework`**，避免重复。
6. **Sigmob 红线**：不得额外加 `SigmobAd-iOS`（与 ToBid-iOS-RC 内置 WindSDK 同名冲突）。

---

## 8. 集成方式设计

| 广告源 | CocoaPods 依赖 | 手工 vendored framework | 推荐方式 | 原因 |
|---|---|---|---|---|
| CSJ / Pangle | ✅ `ToBid-iOS-RC/CSJAdapter` | ❌ | **ToBid subspec** | 后台已 pin 7.6.0.4，与 TK 一致，单一来源 |
| GDT | ✅ `ToBid-iOS-RC/GDTAdapter` | ❌ | **ToBid subspec** | 同上 |
| GroMore | ✅ `ToBid-iOS-RC/GromoreAdapterLite` | ❌ | **ToBid subspec**（Lite 避免 BUAdLive-Framework） | 与 CSJ 二选一 |
| Mintegral | ✅ `ToBid-iOS-RC/MintegralAdapter` | ❌ | **ToBid subspec** | 后台 MintegralAdSDK 7.7.6（**注意 Adapter 缺 sim slice**） |
| MS / 美数 | ✅ `ToBid-iOS-RC/MSAdAdapter` | ❌ | **ToBid subspec** | 后台 2.7.18.1 |
| Octopus | ✅ `ToBid-iOS-RC/OctopusAdapter` | ❌ | **ToBid subspec** | 后台 2.6.4.29 |

**优先级顺序（按 §7 红线）**：① 官方稳定 CocoaPods（ToBid subspec 即是） > ② ToBid 官方 Adapter Pod > ③ 本地私有 Pod > ④ 最后才 vendored framework。

**禁止**：把大量第三方二进制塞进 `flame_sdk_ios.xcframework`。第三方广告源应通过 `flame_sdk_ios_tb.podspec` 依赖（具体是依赖 `ToBid-iOS-RC/<Network>Adapter` subspec）进入 App，**不重新打包进 Flame 主二进制**。

---

## 9. TB podspec 目标结构（建议 diff，**本阶段不修改正式文件**）

```ruby
# flame_sdk_ios_tb.podspec （公共核心保持不变）
s.dependency 'OpenSSL-Universal', '~> 3.6'
s.dependency 'ToBid-iOS-RC', '5.5.6'

# === Phase 5A.16B 起：TB 广告源（待用户确认范围后激活） ===
# Banner 候选（按 ToBid subspec 接入，版本由 ToBid 5.5.6 pin，单一来源）：
#   # 穿山甲（Pangle / CSJ）— Banner 支持最成熟
#   s.dependency 'ToBid-iOS-RC/CSJAdapter', '5.5.6'
#   # 腾讯优量汇（GDT）— UnifiedBanner
#   s.dependency 'ToBid-iOS-RC/GDTAdapter', '5.5.6'
#   # GroMore（CSJ Mediation wrapper，与 CSJ 二选一）
#   # s.dependency 'ToBid-iOS-RC/GromoreAdapterLite', '5.5.6'
#   # Mintegral（注意 Adapter 缺 simulator slice）
#   # s.dependency 'ToBid-iOS-RC/MintegralAdapter', '5.5.6'
#   # 美数 / MobSmart
#   # s.dependency 'ToBid-iOS-RC/MSAdAdapter', '5.5.6'
#   # 章鱼 / ZhiYu
#   # s.dependency 'ToBid-iOS-RC/OctopusAdapter', '5.5.6'
```

**决策点**（§11）：是否全部进默认 podspec？是否 subspec 拆分（如 `flame_sdk_ios_tb/Banner`）让客户可选？是否接受 Mintegral 的模拟器 slice 缺失？**本阶段不修改正式 podspec，等待用户确认**。

---

## 10. Banner 最小可验证广告源

从 6 家候选中推荐**首次 Banner 验证广告源**：

| 项 | 推荐 |
|---|---|
| **广告源** | **CSJ / Pangle（穿山甲）** |
| **SDK** | `Ads-CN/BUAdSDK 7.6.0.4`（via `ToBid-iOS-RC/CSJAdapter`） |
| **Adapter** | `WindMillCSJAdapter 5.5.6`（ToBid 内置） |
| **Banner 支持证据** | Adapter 二进制含 `BannerAdAdapter` 类 + 底层 `BUNativeExpressBannerView`/`BUNativeExpressBannerViewDelegate`；Demo_OC 有 Banner 示例 |
| **测试广告位要求** | ToBid 后台需创建 CSJ Banner 测试广告位（code ID），并配置到 pMap 映射 |
| **期望尺寸** | 320×50（标准）或自适应（由 ToBid 后台 / WindMillBannerView.adSize 决定，待确认 §11.7） |
| **后台需配置内容** | ① ToBid 后台开通 CSJ 渠道；② 创建 Banner 广告位（与 Splash/Reward 同样走 ToBid placementId 体系）；③ Flame 后台 pMap 加 `banner` 映射 |
| **风险** | ① BUTTSDKFramework 陷阱（不选 BUAdLive-Framework）；② CSJ SKAdNetwork ID 需加入 Info.plist；③ CSJAdSDK.bundle 资源需随 pod 进入 App |

**备选**：GDT（`WindMillGDTAdapter` + `GDTUnifiedBannerView`）作为 Batch 2 验证。

> 不能只使用 Sigmob 自身广告位验证 Banner（Phase 5A.15 已确认 Sigmob 无 Banner 填充）。

---

## 11. 分阶段集成建议

### Batch 1：Banner 最小闭环（仅 CSJ）

```
flame_sdk_ios_tb.podspec 加 s.dependency 'ToBid-iOS-RC/CSJAdapter', '5.5.6'
→ Demo pod install
→ BUILD（验证 CSJAdSDK.bundle / BUAdSDK.xcframework / WindMillCSJAdapter 进入 App）
→ TbBannerAdapter 实现（Phase 5A.16B，本阶段不做）
→ Banner fill → show/click/refresh/remove 真机验证
```

### Batch 2：其余核心广告源（逐个或按无冲突组合）

每批：clean pod install → BUILD → 检查 App Frameworks → 检查 duplicate symbols → 记录广告类型支持。

候选顺序：GDT → MS → Octopus →（GroMore 与 CSJ 二选一）→ Mintegral（注意 sim slice）。

### Batch 3：全量组合回归

- clean pod install
- TK clean build（确认 TK 不受影响）
- TB clean build
- TB Reward / Interstitial / Splash / Banner 冒烟
- 包体积审计
- Framework 列表
- 隐私清单（PrivacyInfo.xcprivacy 汇总）
- 启动耗时
- 无重复初始化

---

## 12. 需要用户确认的问题（不代替用户拍板）

1. **接入范围**：`doc/tobid_doc` 中哪些广告源是用户明确要求正式接入的？（6 家 Banner 候选全部？还是先 CSJ+GDT？）
2. **Banner 首次验证广告源**：是否同意推荐 CSJ 作为 Batch 1？
3. **默认 vs 可选**：是否所有计划广告源均进入默认 `flame_sdk_ios_tb`？还是按 subspec 拆分（`flame_sdk_ios_tb/Banner`、`/Reward`...）让客户可选？
4. **subspec 拆分需求**：客户是否需要按广告源选择安装？
5. **包体积**：是否接受 TB 默认包体积增加（CSJ BUAdSDK ~40MB+，GDT ~10MB，Mintegral MTGSDK 全家桶 ~30MB+）？
6. **后台广告位**：ToBid 后台是否已创建对应广告源 + Banner 测试广告位？（Phase 5A.15 的 Splash `q<REDACTED>` 是 Sigmob 的，Banner 需要新的 CSJ/GDT 广告位）
7. **Banner 期望尺寸**：320×50？320×100？自适应？
8. **自动刷新**：由 ToBid 后台控制，还是 Flame/Demo 控制？（WindMillBannerView 有 autoRefresh 回调但开关可能在后台）
9. **TK/TB 同装**：TK 与 TB 是否允许同一广告网络的不同 SDK 版本？（当前 BeiZi 是唯一冲突，不在 Banner 候选；其余均同版本）
10. **客户选装**：客户是否需要按广告源选择安装？

---

## 13. 包体积影响（粗估）

| 广告源 | 主要 framework | 粗估增量 |
|---|---|---|
| CSJ / Pangle | BUAdSDK.xcframework + CSJAdSDK.bundle | ~40 MB |
| GDT | GDTMobSDK.xcframework + Tquic.xcframework | ~10 MB |
| Mintegral | MTGSDK + 7 拆分 xcframework | ~30 MB |
| MS / 美数 | MSAdSDK + MSAdMotion | ~5 MB |
| Octopus | OctAdSDK + OctCore | ~3 MB |
| GroMore | CSJMediation.xcframework（依赖 CSJ） | ~5 MB（叠加在 CSJ 上） |

> 精确数字待 Batch 3 实测。若全量接入，TB App 增量可能 ~90 MB（未压缩）。

---

## 14. 隐私和资源要求

| 项 | 要求 |
|---|---|
| PrivacyInfo.xcprivacy | 各广告源 SDK 自带；汇总到 App 时需检查 `NSPrivacyAccessedAPITypes`（CSJ/GDT/KS/Baidu/MS/MTG/Octopus 均已含） |
| SKAdNetwork IDs | `SkAdneworkIDs代码.txt` 提供 Sigmob/CSJ/Mintegral 的 ID，需加入 App Info.plist `SKAdNetworkItems` |
| 资源 bundle | CSJAdSDK.bundle / baidumobadsdk.bundle / MSAdSDK.bundle / OctAdSDK.bundle / OctCore.bundle / 14× KSU*Resource.bundle 需随 pod 自动进入 App bundle |
| App Transport Security | 各 SDK 默认 HTTPS；CSJ/GDT 可能需例外域 |
| iOS 最低版本 | ToBid-iOS-RC 5.5.6 要求 iOS 11+；Flame podspec 是 iOS 13+，兼容 |

---

## 15. WindMillBannerView API（供 Phase 5A.16B 参考，**本阶段不设计 Adapter**）

`WindMillBannerView : WindMillAdView`（WindMillSDK.h:1562-1591）：

```objc
@interface WindMillBannerView : WindMillAdView
@property (nonatomic, readonly, copy) NSString *placementId;
@property (nonatomic, weak) id <WindMillBannerViewDelegate> delegate;
@property (nonatomic, weak) id <WindMillCustomViewListener> customViewListener;
@property (nonatomic, weak) id <WindMillAdnDelegate> adnDelegate;
@property (nonatomic, weak) UIViewController *viewController;
@property (nonatomic) BOOL animated;
@property (nonatomic, readonly) CGSize adSize;
@property (nonatomic, readonly, strong) WindMillAdInfo *adInfo;
@property (nonatomic, readonly) BOOL isAdValid;
- (instancetype)initWithRequest:(WindMillAdRequest *)request;
- (instancetype)initWithRequest:(WindMillAdRequest *)request expect_size:(CGSize)expectSize;
- (NSArray<WindMillAdInfo *> *)getCacheAdInfoList;
- (void)loadAdData;
@end
```

`WindMillBannerViewDelegate`（全 @optional）：`bannerAdViewDidAutoRefresh:` / `bannerView:failedToAutoRefreshWithError:` / `bannerAdViewLoadSuccess:` / `bannerAdViewFailedToLoad:error:` / `bannerAdViewWillExpose:` / `bannerAdViewDidClicked:` / `bannerAdViewWillLeaveApplication:` / `bannerAdViewWillOpenFullScreen:` / `bannerAdViewCloseFullScreen:` / `bannerAdViewDidRemoved:`。

> **关键差异（与 Splash/Reward/Interstitial）**：Banner 是 **UIView**（不是一次性广告对象），需 `addSubview:` 到 host view；有自动刷新；`loadAdData` 而非 `loadAd`；有 `expect_size` 尺寸参数。Phase 5A.16B 设计 `TbBannerAdapter` 时需复用 `FlameBannerAdapterProtocol` 并映射这些差异。

---

## 16. 推荐结论

| 项 | 结论 |
|---|---|
| 是否建议立即写 `TbBannerAdapter` | ❌ **否**——当前 TB 包无任何 Banner 广告源，写了也无法 fill |
| 是否应先集成广告源 | ✅ **是**——必须先通过 ToBid subspec 集成至少 1 家 Banner 广告源 |
| 第一批广告源 | ✅ **CSJ / Pangle**（`ToBid-iOS-RC/CSJAdapter 5.5.6`），最成熟、与 TK 同版本无冲突 |
| 集成路径 | ✅ **`flame_sdk_ios_tb.podspec` 加 `s.dependency 'ToBid-iOS-RC/CSJAdapter', '5.5.6'`**（单一来源，不重打包进 Flame binary） |
| 是否可进入正式广告源集成 | ⚠️ **需用户先确认 §11 全部 10 项**（接入范围 / subspec 拆分 / 包体积 / 后台广告位 / 尺寸 / 刷新 / TK 同装 / 客户选装 等） |

---

## 17. 是否可进入正式广告源集成

**❌ 暂不可**。需用户先回答 §11 的 10 个待确认问题，特别是：
- §11.1 接入范围（6 家全部？还是分批？）
- §11.3 默认 vs subspec 拆分
- §11.6 后台是否已创建 CSJ Banner 测试广告位
- §11.7 Banner 期望尺寸

确认后，下一阶段（Phase 5A.16B）将：
1. 修改 `flame_sdk_ios_tb.podspec`（按确认范围加 ToBid subspec 依赖）
2. Demo pod install + BUILD 验证广告源 SDK 进入 App
3. 实现 `TbBannerAdapter`（基于 §15 的 WindMillBannerView API + FlameBannerAdapterProtocol）
4. 真机 Banner fill/show/click/refresh/remove 验证

---

## 18. /compact

Phase 5A.16A 完成：审计 ToBid 第三方广告源交付包。`doc/tobid_doc/sdk集成下载说明` 含 9 个广告源（CSJ/GDT/Baidu/KS/Mintegral/MS/Octopus/GroMore + bidResult），Adapter 全 5.5.6。Banner 候选 6 家（CSJ/GDT/GroMore/Mintegral/MS/Octopus），Baidu/KS/Sigmob 不支持 Banner。当前 TB Demo 仅装 ToBid 核心 `ToBidSDK`（无任何 Adapter/第三方 SDK），无重复符号风险。所有 Banner 候选通过 `ToBid-iOS-RC/<Network>Adapter` subspec 接入，与 TK 同版本无冲突（唯一 BeiZi 5.5.0.3 vs 5.5.0.0 不在 Banner 候选）。BUTTSDKFramework 陷阱：TB 接 CSJ 时只选 `BUAdSDK`+`CSJMediation-Only`，不选 `BUAdLive-Framework`。Sigmob 红线：不得加 `SigmobAd-iOS`。推荐 Batch 1 用 CSJ 作首次 Banner 验证。Mintegral Adapter 缺 simulator slice。本阶段仅文档，未改 Banner 代码/podspec/远程 specs，未 push/tag/release。需用户确认 §11 十项（接入范围/subspec/包体积/后台广告位/尺寸/刷新/TK 同装/客户选装）后再进入 Phase 5A.16B 正式集成。

---

## Git

- commit：`docs: audit ToBid ad network integrations`（待创建，仅新增本报告）
- push：❌ 未执行
- tag：❌ 未执行
- release：❌ 未执行

**完成后停止，不修改 Banner 代码，不修改正式 podspec，等待用户确认广告源范围。**
