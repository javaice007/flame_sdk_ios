# 27 · Taku iOS 6.5.84 全量升级与 TK 技术验收（P2-TK）

> 阶段标识：P2-TK-TAKU-6.5.84-FULL-UPGRADE ｜ 日期：2026-10-20
> 分支：`upgrade/ios-taku-6.5.84`（START_HEAD = `6aff124`，即 P1-R1 checkpoint）
> 结论：`TK_TECHNICAL_ACCEPTANCE = PASS`（技术口径：依赖矩阵 / 构建 / 链接 / 二进制隔离 / 真机 init smoke）
> 广告源真实填充验收 **不属本阶段**：`TK_REAL_AD_NETWORK_ACCEPTANCE = PENDING_MANUAL_DEVICE_VALIDATION`

---

## 1. 官方最终版本矩阵（本阶段唯一版本权威）

来源：项目负责人从 Taku 官方 iOS 下载中心按 Flame TK 广告源选择后生成的 CocoaPods 配置。
全部精确锁定（无 `~>` / `>=` / 未锁版本），本阶段未使用 TakuBeta 6.5.90。

| 组件 | 冻结版本 |
|---|---|
| AnyThinkiOS（Core） | **6.5.84** |
| AnyThinkMediationAdxSmartdigimktCNAdapter | 6.5.90.2.1 |
| AnyThinkMediationGromoreAdapter | 7.8.0.5.2.1 |
| AnyThinkMediationGDTAdapter | 4.16.10.2.0 |
| AnyThinkMediationBaiduAdapter | 10.061.2.0 |
| AnyThinkMediationSigmobAdapter | 5.1.3.2.0 |
| AnyThinkMediationKuaiShouAdapter | 5.9.10.1.2.0 |
| AnyThinkMediationMSAdapter | 3.0.15.0.2.0 |
| AnyThinkMediationZYAdapter | 2.6.10.7.2.0 |
| AnyThinkMediationFunlinkAdapter | 2.9.0.3.3.2.0 |
| AnyThinkMediationBeiZiAdapter | 5.5.6.0.2.0 |
| AnyThinkMediationTTAdapter_Mix | 7.8.0.5.2.1 |
| AdGainSDK / AdGainSDKTakuAdapter | 4.2.7.1（KEEP_CURRENT_OUT_OF_TAKU_SCOPE） |
| FSUnionAdSDK | 1.0.8.0（KEEP_CURRENT_OUT_OF_TAKU_SCOPE） |

冻结前的存在性核验（trunk CDN 逐项 `pod spec cat`）：12 个 Taku pod 全部存在，且依赖声明均为
`AnyThinkiOS >= 6.5.60`（Funlink 为 `>= 6.5.45`）——与 Core 6.5.84 无版本冲突。

## 2. Before / After（以真实 resolution 为准，非 podspec 文本）

| 组件 | Before | After | 结果 |
|---|---|---|---|
| AnyThinkiOS | 6.5.71 | 6.5.84 | PASS |
| ADX（SmartdigimktCN） | 6.5.72.2.1 | 6.5.90.2.1 | PASS |
| Gromore | 7.6.0.4.2.0 | 7.8.0.5.2.1 | PASS |
| GDT | 4.15.90.2.0 | 4.16.10.2.0 | PASS |
| Baidu | 10.050.2.1 | 10.061.2.0 | PASS |
| Sigmob | 5.1.3.2.0 | 5.1.3.2.0 | 已于 P1-R1 完成，本阶段保持 |
| KuaiShou | 5.4.10.1.2.0 | 5.9.10.1.2.0 | PASS |
| MS | 2.7.18.1.2.0 | 3.0.15.0.2.0 | PASS（底层 pod 名改为 MSMobAdSDKv3） |
| ZY（章鱼） | 2.6.4.29.2.0 | 2.6.10.7.2.0 | PASS |
| Funlink | 2.9.0.1.2.2.0 | 2.9.0.3.3.2.0 | PASS（BLOCKED → OFFICIAL_UPGRADE） |
| BeiZi | 5.5.0.3.2.0 | 5.5.6.0.2.0 | PASS |
| TTAdapter_Mix | 7.6.0.4.2.0 | 7.8.0.5.2.1 | PASS |
| AdGain | 4.2.7.1 | 4.2.7.1 | KEEP（out of Taku scope） |
| FSUnion | 1.0.8.0 | 1.0.8.0 | KEEP（out of Taku scope） |

底层 Network SDK 实际解析：SmartdigimktCNSDK 6.5.90 / Ads-CN(BUAdSDK + CSJMediation-Only) 7.8.0.5 /
GDTMobSDK 4.16.10 / BaiduMobAdSDK 10.061 / KSAdSDK 5.9.10.1 / MSMobAdSDKv3 3.0.15.0 /
OctopusSDK 2.6.10.7 / FunlinkSDK 2.9.0.3.3 / BeiZiSDK-iOS 5.5.6.0 / SigmobAd-iOS 5.1.3 /
OpenSSL-Universal 3.6.2000。

## 3. 修改文件清单

| 文件 | 修改 |
|---|---|
| `flame_sdk_ios.podspec` | Core → 6.5.84；11 个 Taku Adapter 全部升级到冻结版本；AdGain/FSUnion 保持并注明 KEEP 原因；补矩阵来源与穿山甲/GM 配套注释 |
| `Podfile` | 构建期 `AnyThinkiOS` 6.5.71 → 6.5.84（构建头文件与客户解析版本一致）；ToBid-iOS-RC 5.5.6 保持（仅构建期，TB 胶水源仍在本仓） |
| `flame_sdk_ios.xcframework/`（根目录 TK 产物） | `tk-static` 重建（arm64 + x86_64 静态归档）；仅根目录，未触碰 `tb/` |
| `flame_sdk_ios.xcodeproj/project.pbxproj` | `pod install` 集成产生的 GUID 重排（无语义变化） |
| `docs/knowledge/flame_sdk_ios/04` | 当前/历史口径分离：Core 6.5.84 与 7.8.0.5 配对写入"当前事实"；私有 Sigmob 移入"历史（仅存档）" |
| `docs/knowledge/flame_sdk_ios/25` | P2 状态更新：Funlink BLOCKED → OFFICIAL_UPGRADE；AdGain/FSUnion → KEEP_CURRENT_OUT_OF_TAKU_SCOPE；官方精确 podspec 版本写入矩阵，P0 简写版本保留为"当时官方下载表显示值" |
| `docs/knowledge/flame_sdk_ios/26` | 追加：Sigmob 5.1.3.2.0 随 Core 6.5.84 全矩阵完成技术验证（不改写 P1-R1 历史审计） |
| `docs/knowledge/flame_sdk_ios/27`（本文） | 本阶段交付文档 |
| `00_INDEX.md` | 27 号索引行 |

**零修改**：`flame_sdk_ios_tb.podspec`、`tb/`、`adapter/tb/`、`mediation/tb/`、ToBid 版本、
TB Network subspec、Flame 公共 API、`adapter/tk/`、`mediation/`、广告业务逻辑、广告位 ID、`pt` 路由。

## 4. Dependency resolution（fresh consumer 实录）

```
CocoaPods              = 1.16.2
Toolchain              = Xcode 26.0.1（DT13 正式工具链）
sources                = https://github.com/javaice007/flame-specs.git
                         https://cdn.cocoapods.org/
command                = pod install   （全新目录，无旧 Pods / 无旧 lock）
resolved pods          = 27
warnings               = 2（均为 SmartdigimktCNSDK LICENSE 文件读取提示，无害）
errors                 = 0
```

逐项核对（Podfile.lock 实测，全部精确相等）：

```
TK_CORE_RESOLVED_VERSION = 6.5.84
TK_ADAPTER_RESOLVED_MATRIX = [
  AdxSmartdigimktCN 6.5.90.2.1,
  Gromore 7.8.0.5.2.1,
  GDT 4.16.10.2.0,
  Baidu 10.061.2.0,
  Sigmob 5.1.3.2.0,
  KuaiShou 5.9.10.1.2.0,
  MS 3.0.15.0.2.0,
  ZY 2.6.10.7.2.0,
  Funlink 2.9.0.3.3.2.0,
  BeiZi 5.5.6.0.2.0,
  TTAdapter_Mix 7.8.0.5.2.1,
  AdGain 4.2.7.1（KEEP）, AdGainTaku 4.2.7.1（KEEP）,
  FSUnion 1.0.8.0（KEEP）
]
```

## 5. 百度 CocoaPods source 专项（§十一）

- 先按仓库既有 source（flame-specs + cdn.cocoapods.org）执行 fresh resolution；
- `AnyThinkMediationBaiduAdapter 10.061.2.0` 与 `BaiduMobAdSDK 10.061` **一次解析成功**，
  podspec 源为官方 `https://github.com/baidumobsdk/iosmobsdk.git`；
- 因此**未新增/未调整任何 source**。

```
BAIDU_EXTRA_COCOAPODS_SOURCE_REQUIRED = NO
```

## 6. GroMore / 穿山甲配对（§四）

- `TTAdapter_Mix 7.8.0.5.2.1` 与 `GromoreAdapter 7.8.0.5.2.1` 完全同版；
- 两者的依赖声明一致：`Ads-CN/BUAdSDK 7.8.0.5` + `Ads-CN/CSJMediation-Only 7.8.0.5`；
- Pods 树与 Podfile.lock 中只有这一套 Pangle/CSJ，无 7.6 残留（固定串 `7.6.0.4` 在 App 二进制中 = 0）；
- 无手工 Pangle Framework 与 Pod Pangle 并存（仓库无手工 Pangle 二进制）；
- 无 GroMore 7.8 + TT 7.6（或反向）混装。

```
TK_PANGLE_GROMORE_PAIRING = PASS
TK_PANGLE_BINARY_DUPLICATE_COUNT = 0
TK_DUPLICATE_NETWORK_VERSION_COUNT = 0
```

## 7. Sigmob 依赖图（§十四 专项）

```
AnyThinkMediationSigmobAdapter 5.1.3.2.0
├── AnyThinkiOS >= 6.5.60        → 6.5.84
└── SigmobAd-iOS = 5.1.3
      └── SigmobAd-iOS/WindSDK → wind-sdk-ios/WindSDK.xcframework
                                + wind-sdk-ios/WindFoundation.xcframework
```

- Pods 树 `WindSDK.xcframework` = 1、`WindFoundation.xcframework` = 1（单源，均来自 Sigmob 官方包）；
- `ToBid-iOS-RC` / `WindMill` / `flame_sdk_ios_tk_sigmob_adapter` 在 lock 与 Pods 树中出现次数 = 0；
- 注意区分：此处的 WindSDK/WindFoundation 是 **Sigmob Network SDK**，不是 ToBid/WindMill 聚合 Core。

```
TK_SIGMOB_REQUIRES_TOBID = NO
PRIVATE_SIGMOB_ACTIVE_REFERENCE_COUNT = 0
```

## 8. AdGain / FSUnion 冻结（§六）

```
ADGAIN_STATUS  = KEEP_CURRENT_OUT_OF_TAKU_SCOPE   （4.2.7.1，未删/未升/未降/未改接入）
FSUNION_STATUS = KEEP_CURRENT_OUT_OF_TAKU_SCOPE   （1.0.8.0，同上）
```

真实解析确认二者版本与升级前一致（表 §2）。

## 9. Adapter 重复版本扫描（§十四 其他 Network）

对 fresh consumer 的 App 二进制做固定串扫描：

| 旧版本串 | 命中 |
|---|---|
| 10.050（百度旧） | 0 |
| 4.15.90（GDT 旧） | 0 |
| 5.4.10.1（KS 旧） | 0 |
| 2.7.18.1（MS 旧） | 0 |
| 2.6.4.29（ZY 旧） | 0 |
| 2.9.0.1.2（Funlink 旧） | 0 |
| 5.5.0.3（BeiZi 旧） | 0 |
| 6.5.72（ADX 旧） | 0 |
| 7.6.0.4（Pangle 旧） | 0 |

新版串均命中（10.061 / 4.16.10 / 5.9.10.1 / 3.0.15.0 / 2.6.10.7 / 2.9.0.3.3 / 5.5.6.0 /
6.5.90 / 7.8.0.5）。11 个官方 adapter 的接线类全部在位（ATADX / ATBaidu / ATGDT / ATKS /
ATMS / ATZY / ATFunlink / ATBeiZi / ATGromore(含 ATMobrain*) / ATTT / ATSigmob）。

## 10. Core breaking-change 静态检查（6.5.71 → 6.5.84）

方法：对 Flame TK 胶水实际使用的 22 个 AnyThink 符号（ATAPI / ATAdManager / ATAdLoadingDelegate /
ATBannerView / ATRewardedVideoDelegate / ATSplashDelegate / ATInterstitialDelegate /
ATNativeADView / ATNativeAdOffer / ATNativeADConfiguration / ATNativePrepareInfo / ATShowConfig 等），
在 6.5.71 与 6.5.84 头文件树（各 290 个头文件，集合完全一致）中提取全部声明行并逐符号 diff。

结果：**仅 1 个符号有差异，且为纯新增**：

```
ATNativeADView: +2 / -0
  + - (void)didActRewardCompleteInAdView:(ATNativeADView *)adView
  + - (void)didActRewardTimerUpdateInAdView:(ATNativeADView *)adView
```

无任何 API 删除 / 签名变更 / 协议必选方法变更。

```
TAKU_CORE_BREAKING_CHANGE_FOUND = NO
TAKU_CORE_COMPATIBILITY_PATCHES = []   （零源码改动）
```

## 11. 五类 Flame API 技术验证（静态口径）

TK 胶水随 TK xcframework 用 6.5.84 头文件编译、在 fresh consumer 中链接：

| 类型 | Flame Adapter | Compile | Link | Breaking Change |
|---|---|---|---|---|
| Reward | AtRewardAdapter | PASS | PASS | NO |
| Splash | AtSplashAdapter | PASS | PASS | NO |
| Interstitial | AtInterstitialAdapter | PASS | PASS | NO |
| Banner | AtBannerAdapter | PASS | PASS | NO |
| Native | AtNativeAdapter / AtNativeSelfRenderView | PASS | PASS | NO |

```
TK_FIVE_FORMAT_STATIC_COMPAT = PASS
```

## 12. TK XCFramework 构建（§十七）

按仓库正式流程 `./xcFramework_build.sh tk-static`（Xcode 26.0.1，Release，MACH_O_TYPE=staticlib，
BUILD_LIBRARY_FOR_DISTRIBUTION=YES，EXCLUDED_SOURCE_FILE_NAMES 排除 TB 胶水）：

```
TK_XCFRAMEWORK_BUILD = PASS
TK_XCFRAMEWORK_PATH  = ./flame_sdk_ios.xcframework（根目录；中间产物 build/tk-static/）
```

脚本内置断言全过：

- 产物为 `current ar archive`（静态归档）
- Flame core 6 类齐全；TK 胶水 7 类齐全（FlameTKProvider + 5 个 At*Adapter + AtNativeSelfRenderView）
- **零 TB/WindMill 符号污染（定义+未定义均无）**
- AnyThink 未定义符号 8 个（客户链接期由 AnyThinkSDK.framework 解析）
- `Modules/module.modulemap` 存在

产物实测：

| 项 | 值 |
|---|---|
| arm64 切片体积 | 931,920 bytes（升级前 923,928，+8KB；胶水源码未变，差异来自链接期头文件/编译器信息，属正常量级） |
| simulator 切片体积 | 926,536 bytes（前 920,928） |
| 架构 | arm64 + x86_64（与分发口径一致） |
| 公开头文件 | 10 个（`flame_sdk_ios.h` 及 9 个广告/核心头） |
| module | `module.modulemap` 存在，module 名 `flame_sdk_ios` |

> 说明：本仓库静态双线流程用 `xcodebuild build`（staticlib）而非 `archive` —— 静态 framework 无需
> 签名/嵌入，规避 archive 对 staticlib 的兼容问题；这是仓库既有正式口径，非本阶段偏离。

## 13. Fresh Consumer 构建（§十九）

- 全新目录、全新 `pod install`（27 pods，见 §4）；
- `:path` 引用本仓 podspec + 根目录新 TK xcframework；
- `xcodebuild -workspace ... -scheme P2TKConsumer -sdk iphoneos -destination generic/platform=iOS`。

```
BUILD SUCCEEDED
error:                    0
duplicate symbol:         0
undefined symbol:         0
module not found:         0
linker error:             0
TK_FRESH_CONSUMER_BUILD = PASS
```

## 14. TK / TB 隔离断言（§十八）

对 fresh consumer 的 App 二进制（`P2TKConsumer.debug.dylib`，83 MB 全量静态链接）：

| 断言 | 结果 |
|---|---|
| `nm -a` 中 WindMill / ToBid 符号 | **0** → `TK_ZERO_WINDMILL = PASS` |
| `nm -a` 中 FlameTBProvider / Tb*Adapter | **0** → `TK_ZERO_TB_ADAPTER = PASS` |
| ToBid/WindMill 动态依赖（otool） | 0 |
| FlameTKProvider 定义 | 1（在位） |
| Sigmob 官方 Wind/Sigmob ObjC 类定义 | 298（Sigmob Network SDK 合法存在） |
| AnyThinkSDK 运行时版本串 | `6.5.84` |

```
TK_ZERO_TOBID_CORE = PASS
```

## 15. 运行时 Smoke（真机，§二十）

设备：`康海军的iPhone`（iPhone 16 Pro，iOS 26.6.2，paired）。测试 App：P2TKConsumer
（bundle id `com.flame.sdk.test`，team `BTY45V9GK4`，使用 flame demo 的真实 TK 凭据），
`devicectl device process launch --console` 采集日志：

```
P2SMOKE_START
[FlameSDK] FlameTKProvider: +load 自动注册完成 (platformCode=tk)
[FlameSDK] FlameSdk: pt=tk, 开始通过 Registry 查找 Provider
[FlameSDK] FlameTKProvider: 开始初始化 TopOn / AnyThink
[FlameSDK] FlameSdk initialized successfully.
P2SMOKE_FLAME_INIT=success
P2SMOKE_ATAPI_CLASS=YES
P2SMOKE_ATAPI_VERSION=UA_6.5.84
P2SMOKE_ADAPTER_PROTOCOL=2.0
P2SMOKE_FLAME_CLASS=YES
P2SMOKE_DONE → exit code 0（无 crash）
```

```
TK_RUNTIME_CORE_VERSION = UA_6.5.84
TK_RUNTIME_SMOKE = PASS（启动 / Flame init / Taku Core init / 版本读取 / 无 crash）
```

范围声明：本次 smoke **未**发起五类广告 load（需要业务广告位与真机逐源环境），
故不构成广告验收。

## 16. SKAdNetwork / LSApplicationQueriesSchemes（§十二 / §十三）

**所有权**：两者都属于**客户 App 的 Info.plist**，不写进 SDK framework。已断言当前
`flame_sdk_ios.xcframework/ios-arm64/flame_sdk_ios.framework/Info.plist` 不含
`SKAdNetworkItems` / `LSApplicationQueriesSchemes`。

**现有基数**（本阶段采集）：

| 来源 | 唯一 SKAdNetwork ID 数 |
|---|---|
| adsurge-ios-demo `Resources/Info.plist` | 21 |
| 仓库正式接入文档 `FlameSDK_IOS_对接说明0.1.8.1.md` | 117 |
| 两者并集 | 118（demo 独有 1 个：`238da6jt44.skadnetwork`） |

转义字符检查：上述并集内 `\` 残留 = 0（示例 `wzmmz9fp6w\.skadnetwork` 必须为
`wzmmz9fp6w.skadnetwork`，文档中已是正确形式）。

**官方新列表**：本项目任务未随附 Taku 官方本次选择的新 SKAdNetwork / URL scheme 清单文本，
因此无法计算 NEW / MERGED 数量，也不得编造。处理方式（待清单到手后执行）：
对旧表取并集 → 去重 → 校验无 `\` 转义 → 只更新客户接入文档与 demo Info.plist（可选），
不删除客户已有其他业务 ID。

**LSApplicationQueriesSchemes**：demo Info.plist 当前无该键；仓库接入文档 0.1.8.1 有历史列表。
官方新列表同样未随任务提供。处理方式：与客户现有列表 union + 去重，不覆盖客户原有 schemes。

```
SKADNETWORK_CONFIG_OWNER = CUSTOMER_APP
SKADNETWORK_EXISTING_COUNT = 118（demo 21 + 文档 117 并集）
SKADNETWORK_NEW_COUNT = NOT_PROVIDED（官方新表未随本任务提供）
SKADNETWORK_MERGED_COUNT = NOT_COMPUTED（待官方新表）
SKADNETWORK_INVALID_ESCAPED_ID_COUNT = 0

URL_SCHEMES_CONFIG_OWNER = CUSTOMER_APP
URL_SCHEMES_DUPLICATE_COUNT = 0（现有 demo 列表为空；待官方新表后 union 去重）
```

## 17. 剩余人工真机验收（§二十一，本阶段不做假）

`TK_REAL_AD_NETWORK_ACCEPTANCE = PENDING_MANUAL_DEVICE_VALIDATION`

需逐源执行：init / load / fill / show / impression / click / reward（transId）/ Splash 展示 /
Banner 展示 / Native 展示 / Interstitial 展示 / waterfall 切源。本阶段 BUILD + 真机 init smoke
通过**不代表**广告链路验收通过。

## 18. 后续 TB 升级范围（§二十三登记）

本分支在 TK checkpoint 之后将继续执行（本阶段未启动）：

1. TB 当前 ToBid Core / Network 版本盘点；
2. ToBid 官方稳定矩阵冻结；
3. TB Core + 广告源 SDK 升级；
4. TB xcframework 重建；
5. TB fresh consumer 验证；
6. TB 真机验收；
7. TK/TB 双线最终隔离验收。

```
TB_UPGRADE_STARTED = NO
```

## 19. 机器可读结论

```
DUAL_LINE_UPGRADE_BRANCH = upgrade/ios-taku-6.5.84
CURRENT_PHASE_SCOPE = TK_ONLY
TB_UPGRADE_STARTED = NO

TARGET_TAKU_IOS_CORE = 6.5.84
FUNLINK_STATUS = OFFICIAL_UPGRADE
ADGAIN_STATUS = KEEP_CURRENT_OUT_OF_TAKU_SCOPE
FSUNION_STATUS = KEEP_CURRENT_OUT_OF_TAKU_SCOPE

TK_CORE_RESOLVED_VERSION = 6.5.84
TK_ADAPTER_RESOLVED_MATRIX = [AdxSmartdigimktCN 6.5.90.2.1, Gromore 7.8.0.5.2.1, GDT 4.16.10.2.0, Baidu 10.061.2.0, Sigmob 5.1.3.2.0, KuaiShou 5.9.10.1.2.0, MS 3.0.15.0.2.0, ZY 2.6.10.7.2.0, Funlink 2.9.0.3.3.2.0, BeiZi 5.5.6.0.2.0, TTAdapter_Mix 7.8.0.5.2.1, AdGain 4.2.7.1(KEEP), AdGainTaku 4.2.7.1(KEEP), FSUnion 1.0.8.0(KEEP)]

BAIDU_EXTRA_COCOAPODS_SOURCE_REQUIRED = NO
TK_PANGLE_GROMORE_PAIRING = PASS
TK_PANGLE_BINARY_DUPLICATE_COUNT = 0
TK_SIGMOB_REQUIRES_TOBID = NO
PRIVATE_SIGMOB_ACTIVE_REFERENCE_COUNT = 0
TK_DUPLICATE_NETWORK_VERSION_COUNT = 0

TAKU_CORE_BREAKING_CHANGE_FOUND = NO
TAKU_CORE_COMPATIBILITY_PATCHES = []

TK_FIVE_FORMAT_STATIC_COMPAT = PASS
TK_XCFRAMEWORK_BUILD = PASS
TK_FRESH_CONSUMER_BUILD = PASS

TK_ZERO_TOBID_CORE = PASS
TK_ZERO_WINDMILL = PASS
TK_ZERO_TB_ADAPTER = PASS

SKADNETWORK_CONFIG_OWNER = CUSTOMER_APP
URL_SCHEMES_CONFIG_OWNER = CUSTOMER_APP

TK_RUNTIME_CORE_VERSION = UA_6.5.84
TK_RUNTIME_SMOKE = PASS
TK_REAL_AD_NETWORK_ACCEPTANCE = PENDING_MANUAL_DEVICE_VALIDATION

TB_CODE_CHANGED = NO
TB_DEPENDENCY_CHANGED = NO

TK_TECHNICAL_ACCEPTANCE = PASS
```

## 20. 验证环境记录

```
START_HEAD         = 6aff124fc669804a40c3a1c3b53bcecc4413665b
CocoaPods          = 1.16.2
Build toolchain    = Xcode 26.0.1（/Applications/Xcode_26.0.1.app）
Device             = iPhone 16 Pro / iOS 26.6.2（paired）
Fresh harness      = 仓库外 /Users/khj/Documents/code/97_ad/p2-tk-consumer（log: pod_install.log /
                     logs/xcodebuild.log / logs/xcodebuild_signed.log / logs/runtime_console.log）
```

> harness 放仓库外的原因同 doc 26 §12：此前在仓内 `validation/` 目录构建时目录曾被环境侧清空
> （原因未定位），仓外一次通过。P1-R1 的 harness 定义仍保留在
> `validation/ios-taku-6.5.84-sigmob-migration/` 供复现。
