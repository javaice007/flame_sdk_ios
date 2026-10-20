# 28 · ToBid / WindMill（TB）广告源与 SDK 版本盘点（TB-P0 只读审计）

> 阶段标识：TB-P0-TOBID-INVENTORY ｜ 日期：2026-10-20
> 分支：`upgrade/ios-taku-6.5.84`（TK checkpoint = `024a2e6`）
> 性质：**只读审计 + 官方升级需求盘点**。本阶段未升级 ToBid、未改 TB podspec、未重建 TB 产物。
> 目标版本：`TB_TARGET_VERSION_MATRIX = PENDING_OFFICIAL_CONFIRMATION`（不猜最新版）

---

## 1. 起点与保护

```
TB_P0_START_HEAD = 024a2e6e5c774018a8ab5b9dc4d5459b56b8a1cf
TK_CHECKPOINT_PRESENT = YES
BRANCH = upgrade/ios-taku-6.5.84
WORKTREE_AT_START = clean
```

本阶段仓库变化仅：doc 04 一处口径纠偏 + 本文档 + INDEX。TK 依赖/产物/源码零改动。

## 2. TB Core 精确审计

```
CURRENT_TB_CORE_NAME = ToBid-iOS-RC（WindMill 系，CocoaPods trunk 官方 pod）
CURRENT_TB_CORE_VERSION = 5.5.6
CURRENT_TB_CORE_INTEGRATION_MODEL = Core subspec（ToBidSDK）+ 具名 Adapter subspec
```

ToBid-iOS-RC 5.5.6 podspec 结构（trunk 官方 spec 实测）：

- `default_subspecs = ToBidSDK`；`ToBidSDK` subspec vendored `tobid-sdk-ios-cocoapods-cn/Core/*.xcframework`
  —— Core 目录实际内容：`WindMillSDK.xcframework`、`WindSDK.xcframework`、`WindFoundation.xcframework`；
- 共 **22 个具名 Adapter subspec**：CSJ / Gromore / GromoreLite / GDT / KS / Baidu / AdScope(BeiZi) /
  MSAd / Mercury / Octopus / Admob / JADYun / Mintegral / Vungle / UnityAds / AppLovin / IronSource /
  QuMeng / JuTui / WangMai / PTG / BidResult；
- 每个 subspec 自带对应三方 SDK 的**精确版本依赖**（见 §4）；
- Flame TB 只用其中 8 个（与 `flame_sdk_ios_tb.podspec` 一一对应）。

证据：`flame_sdk_ios_tb.podspec:60-81`、`~/.cocoapods/repos/trunk/Specs/5/6/4/ToBid-iOS-RC/5.5.6/*.podspec.json`、
fresh consumer `Podfile.lock`。

## 3. 真实解析（fresh TB consumer，权威口径）

```
CocoaPods        = 1.16.2
sources          = https://cdn.cocoapods.org/（+ flame_sdk_ios_tb :path 本仓）
command          = pod install（全新目录）
resolved pods    = 11（含子 subspec 共 60+ 条 lock 行）
flame_sdk_ios_tb 依赖块（lock 实录）:
  OpenSSL-Universal ~> 3.6
  ToBid-iOS-RC (= 5.5.6)
  ToBid-iOS-RC/{Baidu,CSJ,GDT,Gromore,KS,Mintegral,MSAd,Octopus}Adapter (= 5.5.6)
禁止项: AnyThink=0, Taku=0, AdGain=0, FSUnion=0, SigmobAd-iOS=0
```

## 4. TB 广告源完整清单（subspec → Network SDK 实测映射）

| 广告源 | 当前是否启用 | ToBid subspec / Adapter | 当前 ToBid 版本 | 底层 Network SDK | 底层实际版本 | 集成方式 | 证据 | Flame 是否直接调用 | 后续升级状态 |
|---|---|---|---|---|---|---|---|---|---|
| CSJ / 穿山甲 | YES | `ToBid-iOS-RC/CSJAdapter` | 5.5.6 | Ads-CN/BUAdSDK | **7.6.0.4** | CocoaPods subspec | tb.podspec:73；lock | NO（仅胶水，无 Pangle API） | REQUIRES_OFFICIAL_MATRIX |
| GroMore | YES | `ToBid-iOS-RC/GromoreAdapter`（非 Lite） | 5.5.6 | Ads-CN/BUAdSDK 7.6.0.4 + **CSJMediation 7.6.0.4**（附带 BUAdLive / BUTTSDKFramework 1.48.2.3-premium） | 7.6.0.4 | CocoaPods subspec | tb.podspec:80；lock | NO | REQUIRES_OFFICIAL_MATRIX |
| GDT / 优量汇 | YES | `ToBid-iOS-RC/GDTAdapter` | 5.5.6 | GDTMobSDK | **4.15.90** | CocoaPods subspec | tb.podspec:74；lock | NO | REQUIRES_OFFICIAL_MATRIX |
| Baidu | YES | `ToBid-iOS-RC/BaiduAdapter` | 5.5.6 | BaiduMobAdSDK | **10.050** | CocoaPods subspec | tb.podspec:75；lock | NO | REQUIRES_OFFICIAL_MATRIX |
| 快手 KS | YES | `ToBid-iOS-RC/KSAdapter` | 5.5.6 | KSAdSDK | **5.4.10.1** | CocoaPods subspec | tb.podspec:76；lock | NO | REQUIRES_OFFICIAL_MATRIX |
| Mintegral（国内） | YES | `ToBid-iOS-RC/MintegralAdapter` | 5.5.6 | MintegralAdSDK（含 6 个 Bid* 子 spec） | **7.7.6** | CocoaPods subspec | tb.podspec:77；lock | NO | REQUIRES_OFFICIAL_MATRIX |
| 章鱼 Octopus | YES | `ToBid-iOS-RC/OctopusAdapter` | 5.5.6 | OctopusSDK | **2.6.4.29** | CocoaPods subspec | tb.podspec:78；lock | NO | REQUIRES_OFFICIAL_MATRIX |
| 美数 MS | YES | `ToBid-iOS-RC/MSAdAdapter` | 5.5.6 | MSMobAdSDK/MS（+ MotionLess） | **2.7.18.1** | CocoaPods subspec | tb.podspec:79；lock | NO | REQUIRES_OFFICIAL_MATRIX |
| Sigmob | YES | 无独立 subspec —— **ToBid Core 内置**（`ToBidSDK` vendored Core 内 WindSDK/WindFoundation） | 5.5.6 | Sigmob WindSDK / WindFoundation | WindSDK **4.20.23**（二进制版本串）/ WindFoundation bundle 180 | Core 内置（非独立 pod） | tb.podspec 注释；Core 目录；strings | NO | CORE_BUILT_IN |

```
CURRENT_IOS_TB_NETWORKS = [CSJ, GroMore, GDT, Baidu, KuaiShou, Mintegral, Octopus, MS(美数), Sigmob(Core内置)]
TB_NETWORK_VERSION_MATRIX = [CSJ:BUAdSDK 7.6.0.4, GroMore:BUAdSDK+CSJMediation 7.6.0.4, GDT:4.15.90,
  Baidu:10.050, KS:5.4.10.1, Mintegral:7.7.6, Octopus:2.6.4.29, MS:2.7.18.1,
  Sigmob:WindSDK 4.20.23(Core)]
```

> 说明：`BidResultAdapter` 存在但 Flame 未声明（历史文档同口径），不计入当前启用源。
> `AdScopeAdapter`（BeiZi）等其余 13 个 subspec 在 ToBid 中可用但 Flame TB 未接入。

## 5. Sigmob 专项

```
TB_SIGMOB_MODEL = CORE_BUILT_IN
TB_CURRENT_SIGMOB_VERSION = WindSDK 4.20.23 / WindFoundation(bundle 180)，随 ToBid-iOS-RC 5.5.6 的 ToBidSDK Core 分发
```

- 不存在独立 Sigmob subspec；
- 不存在额外手工 Sigmob Pod（lock 中 `SigmobAd-iOS` = 0）；
- TB 产物自身不含 WindSDK/WindFoundation 定义（只有对 WindMill 的未定义引用，客户链接期由 ToBid Core 静态归档解析）；
- 因此 TB 升级 ToBid 时 Sigmob 会**随 Core 一起**变化（属 CORE_BUILT_IN 项，需要官方矩阵给出 Core ↔ Sigmob 对应关系）；
- TK/TB 已独立分包，TK 的 `SigmobAd-iOS 5.1.3`（Taku 线）与 TB 的 Core 内置 WindSDK 互不共存，不存在历史共包冲突。

## 6. CSJ / GroMore 专项

```
TB_CSJ_PRESENT = YES
TB_GROMORE_PRESENT = YES
TB_CURRENT_PANGLE_VERSION = 7.6.0.4（Ads-CN/BUAdSDK）
TB_CURRENT_GROMORE_VERSION = 7.6.0.4（Ads-CN/CSJMediation 形态；GM 版本号与 Pangle 同源）
TB_PANGLE_SINGLE_COPY = PASS
```

- CSJAdapter 只拉 `BUAdSDK 7.6.0.4`；GromoreAdapter 拉同一 `BUAdSDK 7.6.0.4` + `CSJMediation 7.6.0.4`
  → 整个 TB 图里 BUAdSDK 只有 7.6.0.4 一个版本；
- GM 额外带 `Ads-CN/BUAdLive*` 与 `BUTTSDKFramework 1.48.2.3-premium`（CSJMediation 的真实传递依赖，非 Flame 手工引入）；
- 仓库无手工 Pangle Framework（`flame_sdk_ios/` 与 `tb/` 内无 Pangle 二进制）；
- lock 中无其它 BUAdSDK 版本 → 无重复 symbol 风险来源。

> 注意：ToBid 5.5.6 另有 `GromoreAdapterLite`（用 `CSJMediation-Only`，不拉 BUAdLive/TTSDK 全家桶）。
> Flame 当前用 **GromoreAdapter（full）**，这是现状事实；是否切换 Lite 属 TB-P2 决策项（会影响包体与 GM 能力）。

## 7. TB 五类 Flame API 调用链（供后续 breaking-change 判定）

公共链路：`Flame API` → `FlameMediationRouter`（pt=tb）→ `FlameTBProvider` → `Tb*Adapter` →
`WindMill*` 广告对象 → ToBid Network Adapter → Network SDK。

| Flame 类型 | Flame TB Adapter | ToBid/WindMill API | Network Adapter 层 |
|---|---|---|---|
| Reward | `TbRewardAdapter` | `WindMillRewardVideoAd` + `WindMillAdRequest` + `WindMillRewardInfo` | ToBid `*Adapter` subspec |
| Splash | `TbSplashAdapter` | `WindMillSplashAd` + `WindMillAdRequest` | 同上 |
| Interstitial | `TbInterstitialAdapter` | `WindMillIntersititialAd`（ToBid 命名，非 Interstitial） | 同上 |
| Banner | `TbBannerAdapter` | `WindMillBannerView` + `WindMillAdRequest` | 同上 |
| Native | `TbNativeAdapter` / `TbNativeSelfRenderView` | `WindMillNativeAd` / `WindMillNativeAdView` / `WindMillNativeAdsManager` / `WindMillFeedADMode*` | 同上 |

初始化：`FlameTBProvider` 使用 `WindMillAds` / `WindMillSDK`（`WindMill setup` 回调进程内一次性，
幂等 init 修复见 1.0.2 的 `6579346`）。Flame 对任何 Network SDK（Pangle/GDT/Baidu/KS/MTG/Octopus/MS/Sigmob）
**零直接 API 调用**，全部经 WindMill。

## 8. TB 生产构建链

```
TB_PRODUCTION_BUILD_COMMAND = ./xcFramework_build.sh tb-static
TB_XCFRAMEWORK_PATH = tb/flame_sdk_ios.xcframework（中间产物 build/tb-static/flame_sdk_ios.xcframework）
```

- 输入：`flame_sdk_ios/` 公共源码 + `mediation/tb` + `adapter/tb`；
  `EXCLUDED_SOURCE_FILE_NAMES="At*.* FlameTKProvider.*"`（排除 TK 胶水）；
- 构建：Xcode 26.0.1，Release，`MACH_O_TYPE=staticlib`，`BUILD_LIBRARY_FOR_DISTRIBUTION=YES`，
  真机切片 + 模拟器 x86_64 切片，`xcodebuild -create-xcframework` 合并；
- 内置断言：静态归档；Flame core 6 类；TB 胶水 7 类；**零 TK/AnyThink 符号污染**；module.modulemap；
  任一失败即中止；
- 产物实测：`current ar archive`、arm64 + x86_64、module `flame_sdk_ios`、公开头 10 个、
  arm64 切片 964,160 bytes；
- 构建完成后脚本自动复制到 `tb/`（TB）或根目录（TK），本阶段**未执行构建**。

## 9. TB 客户接入方式（与构建期 Podfile 严格区分）

```
TB_CUSTOMER_REQUIRES_ANYTHINK = NO
```

- **客户期**：`pod 'flame_sdk_ios_tb', '<version>'` → 依赖仅 OpenSSL-Universal `~>3.6` +
  ToBid-iOS-RC 5.5.6 + 8 个 Adapter subspec；**无 AnyThinkiOS / 无 Taku Adapter / 无 AdGain / 无 FSUnion**
  （fresh lock 实证计数全 0）；
- **构建期**：根 `Podfile` 同时声明 AnyThinkiOS 6.5.84（TK 头文件）与 ToBid-iOS-RC 5.5.6（TB 头文件），
  仅供本仓编译两条线胶水，**不进入任何客户依赖图**；
- TB 产物外壳名与内部 framework 名一致（`flame_sdk_ios.framework`），podspec 引用 `tb/` 子目录。

## 10. TB → TK 隔离 baseline（当前 5.5.6 产物）

对 `tb/flame_sdk_ios.xcframework/ios-arm64` 二进制实测：

| 检查 | 结果 |
|---|---|
| AnyThink / AT* 符号（定义+未定义） | **0** → `TB_ZERO_ANYTHINK_CORE_BASELINE = PASS` |
| Taku Adapter 类（ATSigmob/ATBaidu/ATGDT/ATKS/ATMS/ATZY/ATFunlink/ATBeiZi/ATGromore/ATTT/ATADX） | **0** → `TB_ZERO_TAKU_ADAPTER_BASELINE = PASS` |
| TB 胶水类（FlameTBProvider + 5 Tb*Adapter 等） | 12（在位） |
| WindMill 未定义引用 | 12（合法：客户链接期由 ToBid Core 解析） |

后续 TB 升级必须保持上表前两行为 0。

## 11. 我需要从 ToBid / WindMill 官方确认或获取的升级清单

> 目标版本统一"待 ToBid 官方矩阵确认"。本阶段不猜版本、不下载。

| 序号 | 当前组件 | 当前版本 | 当前底层 Network SDK | 目标版本 | 官方需要确认什么 | 是否必需 |
|---|---|---|---|---|---|---|
| 1 | ToBid-iOS-RC Core（ToBidSDK） | 5.5.6 | 内置 WindMillSDK / WindSDK 4.20.23 / WindFoundation | 待 ToBid 官方矩阵确认 | 最新稳定 Core 版本；Core 内置 Sigmob/WindSDK 的对应版本 | 必需 |
| 2 | CSJAdapter | 5.5.6 | BUAdSDK 7.6.0.4 | 待 ToBid 官方矩阵确认 | 新版 Core 配套的 CSJ/Pangle 精确版本 | 必需 |
| 3 | GromoreAdapter | 5.5.6 | BUAdSDK + CSJMediation 7.6.0.4 | 待 ToBid 官方矩阵确认 | 新版 GM 配套版本；是否建议改用 GromoreAdapterLite | 必需 |
| 4 | GDTAdapter | 5.5.6 | GDTMobSDK 4.15.90 | 待 ToBid 官方矩阵确认 | 配套 GDT 精确版本 | 必需 |
| 5 | BaiduAdapter | 5.5.6 | BaiduMobAdSDK 10.050 | 待 ToBid 官方矩阵确认 | 配套百度精确版本 | 必需 |
| 6 | KSAdapter | 5.5.6 | KSAdSDK 5.4.10.1 | 待 ToBid 官方矩阵确认 | 配套快手精确版本 | 必需 |
| 7 | MintegralAdapter | 5.5.6 | MintegralAdSDK 7.7.6 | 待 ToBid 官方矩阵确认 | 配套 Mintegral 精确版本与 Bid 子 spec 组合 | 必需 |
| 8 | OctopusAdapter | 5.5.6 | OctopusSDK 2.6.4.29 | 待 ToBid 官方矩阵确认 | 配套章鱼精确版本 | 必需 |
| 9 | MSAdAdapter | 5.5.6 | MSMobAdSDK/MS 2.7.18.1 | 待 ToBid 官方矩阵确认 | 配套美数精确版本 | 必需 |
| 10 | Sigmob（Core 内置） | Core 内 WindSDK 4.20.23 | — | 待 ToBid 官方矩阵确认 | 新版 Core 内置 Sigmob 版本；是否需要独立 spec | 随 Core 自动 |
| 11 | OpenSSL-Universal | ~> 3.6（3.6.2000） | — | 待确认 | 新版 ToBid 是否要求更高 OpenSSL（TK/TB 共用契约） | 视官方要求 |

## 12. 未确认项（本阶段 BLOCKED 的"事实性未知"，非阻塞 Gate）

1. ToBid 官方最新稳定版本号与配套 Network 矩阵（必须由项目负责人获取，禁止猜）；
2. WindMillSDK 自身的版本字符串（Core Info.plist 为 1.0，二进制无独立版本串）——需官方 release notes 对应；
3. WindFoundation 的对外版本号（bundle version 180 非语义版本）；
4. 新版 ToBid 是否改变 subspec 命名/拆分（例如 GromoreAdapter vs Lite、Sigmob 是否变独立 spec）；
5. 新版 ToBid 是否要求新 Xcode / Swift 版本（当前 DT13 工具链为 Xcode 26.0.1）。

## 13. TB 升级对已完成的 TK 6.5.84 的影响评估

- TK 与 TB 是**两个独立生产包**，TK 已移除 ToBid 依赖（P1-R1），TB 不含 AnyThink；
- 唯一共用契约 = `OpenSSL-Universal ~> 3.6`（两个 podspec 都声明）→ 若 ToBid 新版抬高 OpenSSL 下限，
  需要同时评估 TK 包契约（但 TK 产物本身不依赖 ToBid）；
- 因此 TB 升级**不会**改动根目录 TK 产物；本阶段已保证 `TK_CODE_CHANGED_IN_TB_P0 = NO`、
  `TK_BINARY_CHANGED_IN_TB_P0 = NO`。

## 14. 下一阶段 Gate

```
TB_P0_GATE = PASS（审计完整；目标矩阵待官方）
下一步：TB-P1 = 冻结 ToBid/WindMill 官方版本矩阵（需项目负责人提供官方版本与配套清单）
再下一步：TB-P2 = 正式升级 + 技术验收（构建 / fresh consumer / 真机 / 双线隔离）
```

## 15. 机器可读结论

```
TB_P0_START_HEAD = 024a2e6e5c774018a8ab5b9dc4d5459b56b8a1cf
TK_CHECKPOINT_PRESENT = YES

CURRENT_TB_CORE_NAME = ToBid-iOS-RC
CURRENT_TB_CORE_VERSION = 5.5.6
CURRENT_TB_CORE_INTEGRATION_MODEL = Core subspec(ToBidSDK) + 22 named adapter subspecs（Flame 用 8 个）

CURRENT_IOS_TB_NETWORKS = [CSJ, GroMore, GDT, Baidu, KuaiShou, Mintegral, Octopus, MS(美数), Sigmob(Core内置)]
TB_NETWORK_VERSION_MATRIX = [CSJ:BUAdSDK 7.6.0.4, GroMore:BUAdSDK+CSJMediation 7.6.0.4, GDT:4.15.90,
  Baidu:10.050, KS:5.4.10.1, Mintegral:7.7.6, Octopus:2.6.4.29, MS:2.7.18.1, Sigmob:WindSDK 4.20.23(Core)]

TB_SIGMOB_MODEL = CORE_BUILT_IN
TB_CURRENT_SIGMOB_VERSION = WindSDK 4.20.23 / WindFoundation(bundle 180)（ToBid Core 5.5.6 内置）

TB_CSJ_PRESENT = YES
TB_GROMORE_PRESENT = YES
TB_CURRENT_PANGLE_VERSION = 7.6.0.4
TB_CURRENT_GROMORE_VERSION = 7.6.0.4
TB_PANGLE_SINGLE_COPY = PASS

TB_PRODUCTION_BUILD_COMMAND = ./xcFramework_build.sh tb-static
TB_XCFRAMEWORK_PATH = tb/flame_sdk_ios.xcframework

TB_CUSTOMER_REQUIRES_ANYTHINK = NO
TB_ZERO_ANYTHINK_CORE_BASELINE = PASS
TB_ZERO_TAKU_ADAPTER_BASELINE = PASS

TOBID_OFFICIAL_UPGRADE_CONFIRMATION_REQUIRED = [Core 最新稳定版, CSJ/Pangle 配套, GroMore(GM) 配套,
  GDT, Baidu, KS, Mintegral, Octopus, MS, Core 内置 Sigmob 对应版本, OpenSSL 下限]
TB_TARGET_VERSION_MATRIX = PENDING_OFFICIAL_CONFIRMATION

TK_CODE_CHANGED_IN_TB_P0 = NO
TK_BINARY_CHANGED_IN_TB_P0 = NO

TB_P0_GATE = PASS
```

## 16. 验证环境

```
CocoaPods = 1.16.2
sources   = https://cdn.cocoapods.org/（TB 线不需要 flame-specs）
harness   = 仓库外 /Users/khj/Documents/code/97_ad/p2-tb-consumer（log: pod_install.log）
Toolchain = Xcode 26.0.1（本阶段未触发构建）
```
