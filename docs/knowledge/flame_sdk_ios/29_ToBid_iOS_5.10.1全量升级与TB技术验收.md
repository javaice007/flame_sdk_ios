# 29 · ToBid iOS 5.10.1 全量升级与 TB 技术验收（TB-P1/P2）

> 阶段标识：TB-P2-TOBID-5.10.1-FULL-UPGRADE ｜ 日期：2026-10-20
> 分支：`upgrade/ios-taku-6.5.84`（TB_P2_START_HEAD = `43c63c7`，含 TK checkpoint `024a2e6` 与 TB-P0 `43c63c7`）
> 结论：`TB_TECHNICAL_ACCEPTANCE = PASS`（技术口径：依赖 / 构建 / 链接 / 二进制隔离 / 真机 init smoke）
> 真实广告验收 **不属本阶段**：`TB_REAL_AD_NETWORK_ACCEPTANCE = PENDING_MANUAL_DEVICE_VALIDATION`

---

## 1. 官方来源与冻结矩阵

项目负责人在 ToBid/Sigmob 官方 iOS 集成工具（地区=国内）选择 ToBid 5.10.1 并按业务 + 运营新增源生成
CocoaPods 代码。**唯一版本权威**：

```
TARGET_TOBID_IOS_VERSION = 5.10.1
TOBID_POD_NAME_MIGRATION = ToBid-iOS-RC -> ToBid-iOS   （官方新坐标；不得自造 ToBid-iOS-RC 5.10.1）
```

11 个官方 Adapter subspec（全部 5.10.1）：GDT / CSJ / Baidu / KS / MSAd / Octopus / Mintegral /
JuTui / AdScope / Kuying / Gromore。

### 1.1 第一硬 Gate：官方 5.10.1 真实存在性（CDN spec 实测）

| 检查 | 结果 |
|---|---|
| `ToBid-iOS 5.10.1` Core pod | **存在**（`default_subspecs = ToBidSDK`，共 26 subspec） |
| 11 个目标 subspec | **全部存在**，命名与官方代码逐字一致 |
| `ToBidSDK` default subspec | 保留（vendored `Core/*.xcframework`） |
| 额外 source | **不需要**（trunk 直解） |
| Beta/RC 关系 | trunk 同时存在 `ToBid-iOS-RC 5.10.1`（26 subspec）与 `ToBid-iOS 5.10.1`；按官方生成器使用 **ToBid-iOS**，不碰 RC/Beta |

```
TOBID_5_10_1_CORE_EXISTS = YES
TOBID_5_10_1_ALL_SUBSPECS_EXIST = YES
```

### 1.2 官方页面 vs 5.10.1 podspec 真实依赖

| Network | 官方页面版本 | 5.10.1 podspec 实际依赖 | 一致性 |
|---|---:|---:|---|
| Sigmob | 5.1.4 | Core 内置 WindSDK（二进制版本串 5.1.4） | PASS |
| GDT | 4.16.11 | GDTMobSDK 4.16.11 | PASS |
| CSJ | 7.8.0.5 | Ads-CN/BUAdSDK 7.8.0.5 | PASS |
| Baidu | 10.060 | BaiduMobAdSDK 10.060 | PASS |
| KS | 5.9.10.1 | KSAdSDK 5.9.10.1 | PASS |
| MS | 2.7.24.0 | MSMobAdSDK/MS 2.7.24.0 | PASS |
| Octopus | 2.6.9.17 | OctopusSDK 2.6.9.17 | PASS |
| Mintegral | 7.7.6 | MintegralAdSDK 7.7.6（+ 7 个 Bid 子 spec） | PASS |
| JuTui | 4.5.5.1 | JTAdSDK 4.5.5.1 | PASS |
| AdScope | 5.5.3.4 | BeiZiSDK-iOS/BeiZiSDK-iOS 5.5.3.4 | PASS |
| Kuying | 6.5.66 | SmartdigimktCNSDK 6.5.66 | PASS |
| GroMore | 7.8.0.5 | Ads-CN/BUAdSDK 7.8.0.5 + Ads-CN/CSJMediation 7.8.0.5 | PASS |

```
OFFICIAL_MATRIX_RESOLUTION_MISMATCH = NO
```

## 2. 范围：原 9 源升级 + 新增 3 源

```
TB_EXISTING_NETWORKS_TO_UPGRADE = [Sigmob, GDT, CSJ, Baidu, KS, MS, Octopus, Mintegral, GroMore]
TB_NEW_NETWORKS = [JuTui, AdScope, Kuying]      （NEW_NETWORK_INTEGRATION，非版本升级，须单独真机验收）
TB_TARGET_NETWORK_COUNT = 12
```

## 3. Before / After（真实 resolution）

| 组件 | Before（ToBid-iOS-RC 5.5.6） | After（ToBid-iOS 5.10.1） | 结果 |
|---|---|---|---|
| Core | ToBid-iOS-RC 5.5.6 | **ToBid-iOS 5.10.1**（pod 名迁移） | PASS |
| Sigmob（Core 内置） | WindSDK 4.20.23 | WindSDK **5.1.4** | PASS |
| CSJ | BUAdSDK 7.6.0.4 | BUAdSDK 7.8.0.5 | PASS |
| GroMore | BUAdSDK + CSJMediation 7.6.0.4 | BUAdSDK + CSJMediation 7.8.0.5 | PASS |
| GDT | 4.15.90 | 4.16.11 | PASS |
| Baidu | 10.050 | 10.060 | PASS |
| KS | 5.4.10.1 | 5.9.10.1 | PASS |
| MS | 2.7.18.1 | 2.7.24.0 | PASS |
| Octopus | 2.6.4.29 | 2.6.9.17 | PASS |
| Mintegral | 7.7.6 | 7.7.6 | **MINTEGRAL_VERSION_CHANGED = NO**（官方 5.10.1 当前配套即 7.7.6，非遗漏） |
| JuTui | — | JTAdSDK 4.5.5.1 | NEW |
| AdScope | — | BeiZiSDK-iOS 5.5.3.4 | NEW |
| Kuying | — | SmartdigimktCNSDK 6.5.66 | NEW |
| OpenSSL-Universal | 3.6.2000 | 3.6.2000（契约 ~>3.6 未变） | 不变 |

## 4. 修改文件

| 文件 | 修改 |
|---|---|
| `flame_sdk_ios_tb.podspec` | `ToBid-iOS-RC 5.5.6` + 8 subspec → `ToBid-iOS 5.10.1` + 11 subspec（新增 JuTui/AdScope/Kuying）；注释记录 pod 名迁移与 Sigmob Core 内置 |
| `Podfile`（构建期） | `ToBid-iOS-RC 5.5.6` → `ToBid-iOS 5.10.1`（仅 TB 头文件来源）；**`AnyThinkiOS 6.5.84` 原样不动** |
| `tb/flame_sdk_ios.xcframework/` | `tb-static` 重建；根目录 TK 产物未触碰（hash 不变，§12） |
| `flame_sdk_ios.xcodeproj/project.pbxproj` | pod install 集成 GUID 重排（无语义） |
| `doc/flame_doc/SKAdNetworkItems_merged_2026-10-20.plist` | 新增：合并后的单一 `SKAdNetworkItems` array（119 条，lowercase） |
| `docs/knowledge/flame_sdk_ios/28` | 顶部状态：PENDING → 已冻结 5.10.1（P0 审计快照保留） |
| `docs/knowledge/flame_sdk_ios/29`（本文）、`00_INDEX.md` | 新增 |

**零修改**：`flame_sdk_ios.podspec`、根目录 `flame_sdk_ios.xcframework`、`adapter/tk/`、`mediation/tk/`、
`adapter/tb/`、`mediation/tb/`（TB 胶水源码亦零改动——无 breaking change 无需补丁）、Flame 公共 API、
AdGain/FSUnion/Taku Adapter。

```
TK_ANYTHINK_VERSION_AFTER_TB_UPGRADE = 6.5.84
TK_PODSPEC_CHANGED_IN_TB_P2 = NO
```

## 5. Fresh TB dependency resolution

```
CocoaPods            = 1.16.2
sources              = https://cdn.cocoapods.org/（+ flame_sdk_ios_tb :path 本仓）
command              = pod install（全新目录，无旧 Pods/lock）
resolved pods        = 14
warnings             = 1（SmartdigimktCNSDK LICENSE 读取提示，无害）
errors               = 0
TB_CORE_RESOLVED_VERSION = 5.10.1
TB_ADAPTER_RESOLVED_MATRIX = [AdScope 5.10.1, Baidu 5.10.1, CSJ 5.10.1, GDT 5.10.1, Gromore 5.10.1,
  JuTui 5.10.1, KS 5.10.1, Kuying 5.10.1, MSAd 5.10.1, Mintegral 5.10.1, Octopus 5.10.1]（11/11）
TB_NETWORK_RESOLVED_MATRIX = [BUAdSDK+CSJMediation 7.8.0.5, GDTMobSDK 4.16.11, BaiduMobAdSDK 10.060,
  KSAdSDK 5.9.10.1, MSMobAdSDK 2.7.24.0, OctopusSDK 2.6.9.17, MintegralAdSDK 7.7.6, JTAdSDK 4.5.5.1,
  BeiZiSDK-iOS 5.5.3.4, SmartdigimktCNSDK 6.5.66, Sigmob WindSDK 5.1.4(Core), OpenSSL 3.6.2000]
禁止项（lock 计数）: ToBid-iOS-RC=0, AnyThink=0, SigmobAd-iOS=0, AdGain=0, FSUnion=0
```

> 网络备注：百度 SDK 的 podspec 源是 `github.com/baidumobsdk/iosmobsdk.git`，章鱼/AdScope 源是 gitee。
> 本机 shell 不继承系统代理，需对 github 走 Clash 7897、对 gitee/国内 OSS 直连（`no_proxy` +
> per-host `GIT_CONFIG_*` 进程级注入，未改全局 git 配置）。该规避只影响下载通路，不影响解析结果。

## 6. Sigmob 专项（Core 内置）

```
TB_SIGMOB_MODEL_AFTER = CORE_BUILT_IN（ToBidSDK Core: WindMillSDK + WindSDK + WindFoundation 三 xcframework）
TB_SIGMOB_RESOLVED_VERSION = WindSDK 5.1.4（二进制版本串；与官方页面 5.1.4 一致）
TB_SIGMOB_SINGLE_COPY = PASS（Pods 树 WindSDK.xcframework=1，WindFoundation.xcframework=1）
TB_OLD_SIGMOB_4_20_23_REMAINS = NO（Core 目录与 App 二进制中 4.20.23 = 0）
无新 SigmobAd-iOS pod、无独立 Sigmob subspec。
```

## 7. CSJ + GroMore 专项

```
TB_PANGLE_GROMORE_PAIRING = PASS（CSJAdapter 5.10.1 + GromoreAdapter 5.10.1，同指 Ads-CN 7.8.0.5）
TB_PANGLE_SINGLE_COPY = PASS（lock 中 BUAdSDK 仅 7.8.0.5 一个版本；无手工 Pangle framework）
TB_OLD_PANGLE_7_6_0_4_REMAINS = NO（App 二进制 7.6.0.4 = 0）
GromoreAdapter 形态 = Full（官方生成代码所指；未自行切 Lite），仍带 BUAdLive + BUTTSDKFramework 1.48.2.3-premium
```

## 8. SpriteKit 官方提醒的归属

- `ToBid-iOS 5.10.1` 自身 podspec **未**声明 SpriteKit；
- 真正声明方是 **`Ads-CN 7.8.0.5`**（穿山甲）podspec 的 `frameworks` 列表 → CocoaPods 自动写入
  聚合 xcconfig `-framework "SpriteKit"`；
- 二进制层：GDTMobSDK / KSAdSDK / SmartdigimktSDK 亦引用 SK* 符号，均由该 flag 满足；
- fresh consumer link：`otool -L` 含 SpriteKit，SpriteKit 缺失相关错误 = 0。

```
SPRITEKIT_LINK_REQUIREMENT = AUTO_BY_PODSPEC（Ads-CN 7.8.0.5 声明；Pod 接入无需手工 Link Binary）
```

> 官方"手动集成需新增 SpriteKit"提示仅针对手动拖 framework 的接入方式。

## 9. ToBid Core breaking-change（5.5.6 → 5.10.1）

方法：WindMillSDK 为 Swift 框架，ObjC 接口为单伞头 `WindMillSDK.h`（231KB → 243KB）。
对 Flame TB 胶水实际使用的 22 个 WindMill 类型逐个比对 `@interface/@protocol` 成员声明与枚举 case：

| 类型 | 成员 old → new | 删除 | 新增 |
|---|---|---|---|
| WindMillAds | — | 0 | +3（getProgrammaticRecommend / setProgrammaticRecommend / openPrivacyView） |
| WindMillAdRequest / WindMillAdView / WindMillDislikeWords | 9/6/5 → 同 | 0 | 0 |
| WindMillBannerView / WindMillIntersititialAd / WindMillSplashAd | 13/10/18 → 同 | 0 | 0 |
| WindMillRewardVideoAd | 12 → 12 | 0 | 0 |
| WindMillRewardVideoAdDelegate | — | 0 | +1（`rewardVideoAd:rewardFailWithError:`，可选） |
| WindMillRewardInfo | — | 0 | +1（`extraInfo`） |
| WindMillNativeAd | — | 0 | +1（`offId`） |
| WindMillNativeAdView | 24 → 24 | 0 | 0 |
| WindMillNativeAdsManager / …Delegate | 8 → 10 | 0 | +2（lossHighest 相关） |
| 枚举 WindMillFeedADMode / InteractionType / MediaPlayerStatus | 8/12/7 case → 同 | 0 | 0 |

```
TOBID_CORE_BREAKING_CHANGE_FOUND = NO
TOBID_COMPATIBILITY_PATCHES = []   （TB 胶水源码零改动）
```

## 10. 五类 Flame TB API 技术验证

| 类型 | TB Adapter | Compile | Link | Breaking |
|---|---|---|---|---|
| Reward | TbRewardAdapter | PASS | PASS | NO |
| Splash | TbSplashAdapter | PASS | PASS | NO |
| Interstitial | TbInterstitialAdapter | PASS | PASS | NO |
| Banner | TbBannerAdapter | PASS | PASS | NO |
| Native | TbNativeAdapter / TbNativeSelfRenderView | PASS | PASS | NO |

```
TB_FIVE_FORMAT_STATIC_COMPAT = PASS
```

## 11. 新增 JuTui / AdScope / Kuying 审计

| 源 | Network pod | 版本 | 来源 | 资源/配置 | 隐私清单 | 备注 |
|---|---|---|---|---|---|---|
| JuTui | JTAdSDK | 4.5.5.1 | 官方阿里云 OSS zip | 30 system frameworks + libs（bz2/c++/iconv/sqlite3/xml2/z）；`-ObjC`；无 bundle | 2 | static_framework |
| AdScope | BeiZiSDK-iOS | 5.5.3.4 | gitee 官方 | 28 frameworks + libs；`EXCLUDED_ARCHS[sdk=iphonesimulator*]=arm64`（Apple Silicon 模拟器需 Rosetta，同 Mintegral/Sigmob 类限制） | 2 | ToBid adapter 类名 `WindMillBeiZiAdapter` |
| Kuying | SmartdigimktCNSDK | 6.5.66 | 官方阿里云 OSS zip | 4 frameworks + libs；`SmartdigimktSDK.bundle` 资源（Pod 自动拷贝）；`-lObjC`；动态 framework 嵌入 | 2 | 与 TK 的 Taku ADX 同一供应商 SDK 不同版本线（TK 用 6.5.90），TK/TB 独立包不共存 |

全部由 Pod 自动处理 frameworks / libraries / resources / xcconfig，**无需手工配置**。
App 二进制中 adapter 类在位：WindMillJuTui*=6、WindMillBeiZi*=7、WindMillKuying*=9。

```
TB_NEW_NETWORK_MATRIX = [JuTui: JTAdSDK 4.5.5.1, AdScope: BeiZiSDK-iOS 5.5.3.4, Kuying: SmartdigimktCNSDK 6.5.66]
```

## 12. TB XCFramework 重建 + TK 产物保护

```
TB_XCFRAMEWORK_BUILD = PASS（./xcFramework_build.sh tb-static，Xcode 26.0.1；构建期 ToBid-iOS 5.10.1 + AnyThinkiOS 6.5.84）
TB_XCFRAMEWORK_PATH = tb/flame_sdk_ios.xcframework
```

脚本内置断言全过：静态归档；Flame core 6 类；TB 胶水 7 类；**零 TK/AnyThink 符号污染**；module.modulemap。
产物实测：`current ar archive`，arm64 + x86_64，10 public headers，arm64 切片 971,464 bytes（前 964,160）。

```
TK_XCFRAMEWORK_HASH_BEFORE = arm64 68a1e5d1…b92c / sim cc131594…f4fa
TK_XCFRAMEWORK_HASH_AFTER  = arm64 68a1e5d1…b92c / sim cc131594…f4fa   （sha256 完全一致）
TK_BINARY_UNCHANGED_DURING_TB_UPGRADE = YES
```

## 13. 双线隔离断言

TB 新产物（`tb/` arm64）：AnyThink/AT*/Taku adapter = **0**；FlameTKProvider/At*Adapter = **0**；
TB 胶水类 14；WindMill 未定义引用 12（客户链接期由 ToBid Core 解析）。
TB fresh consumer App 二进制（87.8MB）：AnyThink/Taku adapter = 0；FlameTKProvider = 0；
FlameTBProvider = 1；WindMill 符号 33,586；Sigmob/Wind 类 466。
TK 根目录产物反向抽查：ToBid/WindMill/FlameTBProvider/Tb* = **0**；FlameTKProvider 在位。

```
TB_ZERO_ANYTHINK_CORE = PASS
TB_ZERO_TAKU_ADAPTER = PASS
TK_ZERO_TOBID_CORE = PASS
TK_ZERO_WINDMILL = PASS
```

## 14. Fresh TB Consumer Build

```
BUILD SUCCEEDED（Xcode 26.0.1，-sdk iphoneos，generic/platform=iOS）
error=0  duplicate symbol=0  undefined symbol=0  module not found=0  linker error=0  SpriteKit 缺失=0
TB_FRESH_CONSUMER_BUILD = PASS
```

## 15. 旧版本残留扫描（App 二进制固定串）

| 旧版本串 | 命中 |
|---|---|
| ToBid-iOS-RC / 5.5.6 | 0 |
| BUAdSDK 7.6.0.4 | 0 |
| GDT 4.15.90 | 0 |
| Baidu 10.050 | 0 |
| KS 5.4.10.1 | 0 |
| MS 2.7.18.1 | 0 |
| Octopus 2.6.4.29 | 0 |
| Sigmob WindSDK 4.20.23 | 0 |

```
TB_OLD_NETWORK_VERSION_RESIDUAL_COUNT = 0
MINTEGRAL_VERSION_CHANGED = NO（7.7.6 = 官方 5.10.1 配套版本，非残留）
```

## 16. 真机 Runtime Smoke

设备：iPhone 16 Pro / iOS 26.6.2（USB 直连；Wi-Fi 隧道期间 CoreDevice `tunnelState=unavailable`
导致 error 4016，插线后恢复）。App：P2TBConsumer（`com.flame.sdk.test`，demo TB 凭据）。

```
[FlameSDK] FlameTBProvider: +load 自动注册完成 (platformCode=tb)
[FlameSDK] FlameSdk: pt=tb, Router 已激活 Provider (pt=tb)
TBSMOKE_FLAME_INIT=success
TBSMOKE_FLAMETB_CLASS=YES
TBSMOKE_WINDMILL_VERSION=5.10.1        ← +[WindMillAds sdkVersion]
TBSMOKE_DONE → exit 0（无 crash）
```

```
TB_RUNTIME_CORE_VERSION = 5.10.1
TB_RUNTIME_SMOKE = PASS
```

> 探针备注：`NSClassFromString(@"WindMillAds")` 返回 NO 是因为 WindMill 为 Swift 框架，运行时类名为
> mangled `_TtC11WindMillSDK11WindMillAds`（二进制中确认存在）；直接调用 `[WindMillAds sdkVersion]`
> 成功返回 5.10.1 已证明类在位。未发起任何广告 load。

## 17. SKAdNetwork union

官方生成器本次输出 22 条（Sigmob 1 / 穿山甲 2 / Mintegral 19），其余 Network 未输出新 ID（如实记录，不猜）。

```
TB_OFFICIAL_GENERATED_SKAD_COUNT = 22（含大小写混排，规范化 lowercase 后 22 唯一，无 \ 转义）
SKADNETWORK_EXISTING_COUNT = 118（demo Info.plist 21 ∪ 接入文档 0.1.8.1 共 117）
SKADNETWORK_MERGED_COUNT = 119（官方 22 中 21 已存在，新增 1：58922nb4gd.skadnetwork / Sigmob）
SKADNETWORK_CASE_INSENSITIVE_DUPLICATE_COUNT = 41（三源 160 条目 → 119 唯一）
SKADNETWORK_INVALID_COUNT = 0
SKADNETWORK_CONFIG_OWNER = CUSTOMER_APP
```

合并产物：`doc/flame_doc/SKAdNetworkItems_merged_2026-10-20.plist`（单一合法 `SKAdNetworkItems` array，
`plutil -lint` OK）。未覆盖任何现有合法 ID；未写入 SDK framework Info.plist。

## 18. 客户额外接入配置

```
TB_CUSTOMER_INTEGRATION_REQUIREMENTS = [
  1. Podfile: pod 'flame_sdk_ios_tb', '<next version>'（自动带入 ToBid-iOS 5.10.1 + 11 adapter；无需手工 Link SpriteKit）,
  2. Info.plist SKAdNetworkItems: 以 doc/flame_doc/SKAdNetworkItems_merged_2026-10-20.plist 为基础 union 客户自有 ID,
  3. Apple Silicon 模拟器: Mintegral / AdScope(BeiZi) 排除 arm64 sim slice → 需 Rosetta 或真机,
  4. ATT / ATS / LSApplicationQueriesSchemes: 沿用现有接入文档；官方本次未输出新 schemes,
  5. 新增 JuTui/AdScope/Kuying 需在 ToBid 后台配置对应 AppId/广告位并单独真机验收
]
```

## 19. 剩余人工真机验收（不属技术 PASS）

现有 9 源（Sigmob/GDT/CSJ/Baidu/KS/MS/Octopus/Mintegral/GroMore）+ 新增 3 源（JuTui/AdScope/Kuying）
逐源：init / load / fill / show / impression / click / reward(transId) / Splash / Banner / Native /
Interstitial / waterfall 切源。

```
TB_REAL_AD_NETWORK_ACCEPTANCE = PENDING_MANUAL_DEVICE_VALIDATION
```

## 20. 机器可读结论

```
TB_P2_START_HEAD = 43c63c7a738871ab44655d5310e33600c2790774
TK_CHECKPOINT_PRESENT = YES
TB_P0_CHECKPOINT_PRESENT = YES

TARGET_TOBID_IOS_VERSION = 5.10.1
TOBID_5_10_1_CORE_EXISTS = YES
TOBID_5_10_1_ALL_SUBSPECS_EXIST = YES
TOBID_POD_NAME_MIGRATION = ToBid-iOS-RC -> ToBid-iOS

TB_EXISTING_NETWORKS_TO_UPGRADE = [Sigmob, GDT, CSJ, Baidu, KS, MS, Octopus, Mintegral, GroMore]
TB_NEW_NETWORKS = [JuTui, AdScope, Kuying]
TB_TARGET_NETWORK_COUNT = 12

TB_CORE_RESOLVED_VERSION = 5.10.1
TB_ADAPTER_RESOLVED_MATRIX = [AdScope 5.10.1, Baidu 5.10.1, CSJ 5.10.1, GDT 5.10.1, Gromore 5.10.1, JuTui 5.10.1, KS 5.10.1, Kuying 5.10.1, MSAd 5.10.1, Mintegral 5.10.1, Octopus 5.10.1]
TB_NETWORK_RESOLVED_MATRIX = [BUAdSDK+CSJMediation 7.8.0.5, GDTMobSDK 4.16.11, BaiduMobAdSDK 10.060, KSAdSDK 5.9.10.1, MSMobAdSDK 2.7.24.0, OctopusSDK 2.6.9.17, MintegralAdSDK 7.7.6, JTAdSDK 4.5.5.1, BeiZiSDK-iOS 5.5.3.4, SmartdigimktCNSDK 6.5.66, Sigmob WindSDK 5.1.4(Core)]
OFFICIAL_MATRIX_RESOLUTION_MISMATCH = NO

TB_SIGMOB_MODEL_AFTER = CORE_BUILT_IN
TB_SIGMOB_RESOLVED_VERSION = WindSDK 5.1.4
TB_SIGMOB_SINGLE_COPY = PASS
TB_OLD_SIGMOB_4_20_23_REMAINS = NO

TB_PANGLE_GROMORE_PAIRING = PASS
TB_PANGLE_SINGLE_COPY = PASS
TB_OLD_PANGLE_7_6_0_4_REMAINS = NO
MINTEGRAL_VERSION_CHANGED = NO

SPRITEKIT_LINK_REQUIREMENT = AUTO_BY_PODSPEC
TOBID_CORE_BREAKING_CHANGE_FOUND = NO
TOBID_COMPATIBILITY_PATCHES = []
TB_FIVE_FORMAT_STATIC_COMPAT = PASS
TB_OLD_NETWORK_VERSION_RESIDUAL_COUNT = 0

TB_XCFRAMEWORK_BUILD = PASS
TB_XCFRAMEWORK_PATH = tb/flame_sdk_ios.xcframework
TB_FRESH_CONSUMER_BUILD = PASS

TB_ZERO_ANYTHINK_CORE = PASS
TB_ZERO_TAKU_ADAPTER = PASS
TK_ZERO_TOBID_CORE = PASS
TK_ZERO_WINDMILL = PASS
TK_BINARY_UNCHANGED_DURING_TB_UPGRADE = YES
TK_PODSPEC_CHANGED_IN_TB_P2 = NO
TK_ANYTHINK_VERSION_AFTER_TB_UPGRADE = 6.5.84

TB_RUNTIME_CORE_VERSION = 5.10.1
TB_RUNTIME_SMOKE = PASS

SKADNETWORK_CONFIG_OWNER = CUSTOMER_APP
TB_OFFICIAL_GENERATED_SKAD_COUNT = 22
SKADNETWORK_EXISTING_COUNT = 118
SKADNETWORK_MERGED_COUNT = 119
SKADNETWORK_CASE_INSENSITIVE_DUPLICATE_COUNT = 41
SKADNETWORK_INVALID_COUNT = 0

TB_CUSTOMER_INTEGRATION_REQUIREMENTS = [见 §18]
TB_REAL_AD_NETWORK_ACCEPTANCE = PENDING_MANUAL_DEVICE_VALIDATION

TB_TECHNICAL_ACCEPTANCE = PASS
```

## 21. 验证环境

```
CocoaPods = 1.16.2 ｜ Toolchain = Xcode 26.0.1 ｜ Device = iPhone 16 Pro / iOS 26.6.2（USB）
Fresh harness = 仓库外 /Users/khj/Documents/code/97_ad/ios/p2-tb-consumer
  （pod_install_5101g.log / logs/xcodebuild.log / logs/xcodebuild_signed.log / logs/runtime_console.log）
```
