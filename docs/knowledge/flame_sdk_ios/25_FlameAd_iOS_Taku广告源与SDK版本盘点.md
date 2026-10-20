# 25 · FlameAd iOS Taku 广告源与 SDK 版本盘点（P0：升级分支建立 + TK/Taku 盘点）

> 阶段标识：P0-TAKU-IOS-UPGRADE-INVENTORY ｜ 日期：2026-10-20
> 性质：**只盘点，不升级**。本阶段禁止下载 SDK / pod update / 替换二进制 / 修改业务源码 / 修改 TB 线路。
> 升级目标依据：项目负责人提供的 **Taku 官方 iOS 稳定版本表**（本文 §3，已冻结，禁止自行改选版本）。

---

## 1. 分支事实（git 实测）

```
DUAL_LINE_BASE_BRANCH  = release/ios-dual-line
DUAL_LINE_BASE_COMMIT  = da19c68b406cb5f3f18835c505bcbd4d378de5c0
TAKU_UPGRADE_BRANCH    = upgrade/ios-taku-6.5.84
TAKU_UPGRADE_BASE_COMMIT = da19c68b406cb5f3f18835c505bcbd4d378de5c0
TAKU_UPGRADE_BRANCH_CREATED = YES
```

- 双线基线判定依据（非猜测）：`release/ios-dual-line` 同时携带 TK 证据（Podfile AnyThinkiOS、
  `flame_sdk_ios.podspec`、adapter/tk/、根目录 TK xcframework）与 TB 证据（Podfile ToBid-iOS-RC、
  `flame_sdk_ios_tb.podspec`、adapter/tb/、tb/ 子目录 TB xcframework），且为 1.0.2 已发布 CLOSED
  分支（docs 22/23/24）。
- 创建时工作区 clean（无未提交修改，未做任何 stash/reset）。
- 原双线分支 `release/ios-dual-line` 未被修改（仅 `git checkout -b`）。

## 2. 官方 iOS 稳定版本基线（项目负责人提供，已冻结）

| 官方组件/广告源 | iOS 目标版本 |
|---|---:|
| Taku 稳定 | **6.5.84** |
| TakuBeta | 6.5.90（**明确不使用**） |
| 穿山甲单接包 | 7.8.05 |
| GM 插件包 | 7.8.05 |
| 百度 | 10.061 |
| 优量汇 | 4.16.10 |
| 快手 | 5.9.10.1 |
| 酷盈（Taku ADX） | 6.5.90 |
| 章鱼 | 2.6.10.7 |
| 倍孜 | 5.5.60 |
| 美数 | 3.0.15.0 |
| Ubix | 2.12.1 |
| 领页 | 2.4.38 |
| 趣盟 | 无 |

> 冻结：`TARGET_TAKU_IOS_CORE_VERSION = 6.5.84`。
> 该表是"官方可用组件版本表"，**不是** Flame 当前广告源清单——Flame 实际使用以本文 §5 为准。

## 3. TK/Taku 线路入口（代码实测）

```
CURRENT_TK_ENTRY = [
  flame_sdk_ios/mediation/tk/FlameTKProvider.{h,m}      # TK 主入口：+load 自动注册 platformCode="tk"，
                                                        #   ATAPI startWithAppID:appKey: 完成初始化
  flame_sdk_ios/adapter/tk/At{Reward,Splash,Interstitial,Banner,Native}Adapter  # 5 个格式胶水（ATAdManager 单元 API）
  flame_sdk_ios/adapter/FlameAdapterManager.{h,m}       # 遗留 init 兼容层（AnyThink 初始化已迁入 Provider）
  flame_sdk_ios/mediation/FlameMediationRouter.m        # pt=tk/tb 路由激活
  flame_sdk_ios/mediation/FlameMediationRegistry.m      # Provider 注册表
]
```

| 检查项 | 事实 |
|---|---|
| Taku Core 引用位置 | `Podfile:48`（AnyThinkiOS 6.5.71）、`flame_sdk_ios.podspec:58`、`#import <AnyThinkSDK/AnyThinkSDK.h>`（FlameTKProvider.m:14） |
| TK 对网络 SDK 的直接引用 | **零**。adapter/tk 全部源码仅 import AnyThinkSDK 伞头文件（grep 实证，见 doc 04 §架构事实）；网络 SDK 适配全部由 Taku 官方 `AnyThinkMediation*Adapter` 在客户接入期完成 |
| TK 与 TB 的路由/切换 | 运行期：`FlameConfigManager` 调 `/api/v1/sdk/init`，服务端下发 `pt`(tk/tb) → Registry 取 Provider → Router 激活（doc 13 §2.1 调用链）。分发期：TK 客户用根目录 xcframework 的 `flame_sdk_ios` pod，TB 客户用 `tb/` 子目录产物的 `flame_sdk_ios_tb` pod，二者互斥 |
| TK Demo | 仓库内无 TK Demo App（flame_sdk_iosTests 为空壳单测 target）；真机验收走外部 Published Fresh Consumer harness（doc 23：TK 7/7 ALL_OK） |

## 4. Taku Core 单独确认

| 项 | 值 | 证据 |
|---|---|---|
| `CURRENT_TAKU_IOS_CORE` | AnyThinkiOS（AnyThinkSDK.framework，CocoaPods trunk 官方 pod） | Podfile.lock / podspec / Pods/AnyThinkiOS/ |
| `CURRENT_TAKU_IOS_CORE_VERSION` | **6.5.71** | Podfile.lock `AnyThinkiOS (6.5.71)` + `flame_sdk_ios.podspec:58`（双源一致；framework Info.plist 未打版本号为 Taku 惯例，以依赖清单为准） |
| `TARGET_TAKU_IOS_CORE_VERSION` | **6.5.84**（官方稳定版） | §2 冻结表 |
| `CORE_UPGRADE_REQUIRED` | **YES**（6.5.71 → 6.5.84，仅判定差异，本阶段不执行） | — |

## 5. 当前 TK 广告源主表（仓库事实）

**口径**：只统计 TK/Taku 线路实际依赖；TB 广告源不在本表（TB 见 §8）。
所有 13 项均为 `flame_sdk_ios.podspec:66-82`（1.0.2 已发布版）声明的客户接入期依赖，全部随 1.0.2 交付 = **启用 YES**；无 `RESIDUAL / NOT_ACTIVE` 项（残留扫描：仓库内无未引用的广告源二进制/目录；validation/ 与 build/ 下的 BaiduMobAdSDK 等命中均为 TB 侧 harness 的 pod 安装物，与 TK 无关）。
Adapter pod 版本语义：`AnyThinkMediation*Adapter A.B.C.NETWORKVER.ADAPTERVER`（如 KuaiShou 5.4.10.1.2.0 = KSAdSDK 5.4.10.1 + adapter 2.0）。

| 广告源 | 当前是否启用 | 当前 Adapter/插件 | 当前 Adapter 版本 | 当前 Network SDK | 当前 SDK 版本 | 集成方式 | 主要证据 | Demo | 官方稳定目标 | 需下载 |
|---|---|---|---|---|---|---|---|---|---|---|
| Taku Core（AnyThinkSDK） | YES | —（平台核心本体） | — | AnyThinkSDK | 6.5.71 | CocoaPods（Podfile 构建期 + podspec 客户期） | Podfile:48、podspec:58、Podfile.lock | 外部 harness | 6.5.84 | **是** |
| 穿山甲 CSJ | YES | AnyThinkMediationTTAdapter_Mix（官方混合包） | 7.6.0.4.2.0 | Ads-CN/BUAdSDK | 7.6.0.4 | CocoaPods（客户期） | podspec:78、doc 04、1.0.0 矩阵 | 外部 harness（真实物料已验证） | 单接包 7.8.05 | **是** |
| GroMore（GM） | YES | AnyThinkMediationGromoreAdapter | 7.6.0.4.2.0 | BUAdSDK + CSJMediation | 7.6.0.4 | CocoaPods（客户期） | podspec:68、doc 04 | 外部 harness | GM 插件包 7.8.05 | **是** |
| 百度 | YES | AnyThinkMediationBaiduAdapter | 10.050.2.1 | BaiduMobAdSDK | 10.050 | CocoaPods（客户期） | podspec:69、1.0.0 矩阵 | 外部 harness | 10.061 | **是** |
| 优量汇（GDT） | YES | AnyThinkMediationGDTAdapter | 4.15.90.2.0 | GDTMobSDK | 4.15.90 | CocoaPods（客户期） | podspec:79、1.0.0 矩阵 | 外部 harness | 4.16.10 | **是** |
| 快手（KS） | YES | AnyThinkMediationKuaiShouAdapter | 5.4.10.1.2.0 | KSAdSDK | 5.4.10.1 | CocoaPods（客户期） | podspec:74、1.0.0 矩阵 | 外部 harness | 5.9.10.1 | **是** |
| 酷盈（Taku ADX） | YES | AnyThinkMediationAdxSmartdigimktCNAdapter | 6.5.72.2.1 | Taku ADX（随 Core 发布节奏） | 6.5.72 系 | CocoaPods（客户期） | podspec:67、doc 04/14 | 外部 harness | 6.5.90 | **是** |
| 章鱼（Octopus/ZY） | YES | AnyThinkMediationZYAdapter | 2.6.4.29.2.0 | OctopusSDK | 2.6.4.29 | CocoaPods（客户期） | podspec:71、1.0.0 矩阵（ZY=Octopus 同源） | 外部 harness | 2.6.10.7 | **是** |
| 倍孜（BeiZi） | YES | AnyThinkMediationBeiZiAdapter | 5.5.0.3.2.0 | BeiZiSDK-iOS | 5.5.0.0 | CocoaPods（客户期） | podspec:73、1.0.0 矩阵 | 外部 harness | 5.5.60 | **是** |
| 美数（MS） | YES | AnyThinkMediationMSAdapter | 2.7.18.1.2.0 | MSMobAdSDK | 2.7.18.1 | CocoaPods（客户期） | podspec:70、1.0.0 矩阵 | 外部 harness | 3.0.15.0 | **是** |
| Sigmob | YES | flame_sdk_ios_tk_sigmob_adapter（Flame 私有 spec，去 SigmobAd-iOS 传递依赖） | 4.20.12.2.0 | WindSDK（由 ToBid-iOS-RC 统一提供） | 5.5.6 | CocoaPods（Flame 私有 spec） | podspec:75-77、doc 04/14 | 外部 harness（已真机完整验证） | NOT_IN_PROVIDED_STABLE_MATRIX | 否（BLOCKED，见 §10） |
| Funlink | YES | AnyThinkMediationFunlinkAdapter（Taku 官方 trunk） | 2.9.0.1.2.2.0 | FunlinkSDK | 2.9.0.1.2 | CocoaPods（客户期） | podspec:72、doc 13（官方 Adapter 自 0.1.8 起启用） | 外部 harness | NOT_IN_PROVIDED_STABLE_MATRIX | 否（BLOCKED，见 §10） |
| AdGain | YES | AdGainSDKTakuAdapter | 4.2.7.1 | AdGainSDK | 4.2.7.1 | CocoaPods（客户期） | podspec:80-81、doc 14 | 外部 harness | NOT_IN_PROVIDED_STABLE_MATRIX | 否（BLOCKED，见 §10） |
| FSUnion（飞梭） | YES | FSUnionAdSDK（SDK 自带 Taku 侧接入，无独立 Adapter pod） | 1.0.8.0 | FSUnionAdSDK | 1.0.8.0 | CocoaPods（客户期） | podspec:82、doc 14、1.0.0 矩阵 | 外部 harness | NOT_IN_PROVIDED_STABLE_MATRIX | 否（BLOCKED，见 §10） |

各源真机运行状态备注（沿用 1.0.0 矩阵口径）：Sigmob / CSJ / GDT / GroMore / Funlink / BeiZi / AdGain / FSUnion / ADX 已依赖+链接+运行时验证（CSJ 已取得真实物料）；百度 / 快手 / 美数 / 章鱼 4 源"依赖、链接、运行时已验证"，**真实填充待真实业务环境验证**——属运行态验收项，不影响本盘点结论。

## 6. 穿山甲 / GM 单独核查（官方表强制项）

| # | 问题 | 结论 |
|---|---|---|
| 1 | 是否存在穿山甲 | **YES**（AnyThinkMediationTTAdapter_Mix） |
| 2 | 当前穿山甲 Adapter/单接包 | Taku 官方 **TTAdapter_Mix 混合包**（单接 + GroMore 共存形态） |
| 3 | 当前版本 | 7.6.0.4.2.0（底层 Pangle BUAdSDK **7.6.0.4** + adapter 2.0） |
| 4 | 是否存在 GM 插件包 | **YES**（AnyThinkMediationGromoreAdapter） |
| 5 | 当前 GM 插件版本 | 7.6.0.4.2.0（BUAdSDK + CSJMediation 7.6.0.4） |
| 6/7/8 | 单接 only / GM only / 同时存在 | **两者同时存在**（podspec:68 + podspec:78） |
| 9 | Flame 是否直接集成底层 Pangle SDK | **NO**。全 git 历史零直接 API 调用（grep 仅注释命中，doc 04 硬约束事实）；Pangle 由聚合官方 adapter 携带，按 waterfall 由 AnyThinkSDK 初始化 |
| 10 | 是否存在两份 Pangle 二进制 | TK 线内**无重复**：TTAdapter_Mix 混合包即 Taku 官方"单接+GroMore 共用一份 Pangle"的形态，两 adapter 同为 7.6.0.4；TB 线的 CSJ/Gromore subspec 共享 BUAdSDK 7.6.0.4（另一套独立二进制，与 TK 无关） |
| 11 | 重复 SDK 风险 | TK 线内无；跨线无（TK/TB podspec 互斥不可同接）。**P1 升级注意**：7.8.05 必须按官方"单接包 + GM 插件包"配套关系成对升级，禁止混配不同 Pangle 版本 |

```
PANGLE_PRESENT = YES
GM_PLUGIN_PRESENT = YES
CURRENT_PANGLE_PACKAGE_VERSION = 7.6.0.4（经 AnyThinkMediationTTAdapter_Mix 7.6.0.4.2.0 携带）
CURRENT_GM_PLUGIN_VERSION = 7.6.0.4（经 AnyThinkMediationGromoreAdapter 7.6.0.4.2.0 携带）
TARGET_PANGLE_PACKAGE_VERSION = 7.8.05
TARGET_GM_PLUGIN_VERSION = 7.8.05
```

> 注：未根据 Android GroMore 情况推测 iOS；以上全部为 iOS 仓库/podspec/doc 04 iOS 口径事实。

## 7. Taku Core 升级对 TB 的影响（隔离确认）

升级分支源自双线基线（§1）；本文 §5 广告源清单只统计 TK。

| SDK/组件 | TK 使用 | TB 使用 | 是否共享 | 后续升级风险 |
|---|---|---|---|---|
| OpenSSL-Universal ~>3.6 | YES | YES | 共享（双 podspec 同契约） | 本次不动 → 无 |
| AnyThinkiOS 6.5.71 | YES（TK 核心，静态产物内为未解析符号引用） | 弱链接符号（TB App 不携带 AnyThinkSDK，TB 产物零 AnyThink 胶水） | 产物级互斥 | 升 6.5.84 仅重建根目录 TK 产物；`tb/` 产物不动 → 低。P1 重建后须复核 TB 产物 zero-AnyThink 断言与 TK 产物 zero-WindMill 断言 |
| ToBid-iOS-RC 5.5.6 | 经 flame_sdk_ios_tk_sigmob_adapter 使用其 WindSDK/WindFoundation | YES（TB 核心 + 8 广告源 subspec） | 共享（TK 单向借用 WindSDK/WindFoundation） | 本次**不升 ToBid**；Sigmob 亦 BLOCKED 不动 → 无。远期若 Taku 侧 Sigmob adapter 要求更高 WindSDK 才会冲突（P1 决策项） |
| Pangle（BUAdSDK/CSJ）7.6.0.4 | Taku adapter 家族携带 | ToBid subspec 家族携带 | **二进制不共享**（两家各自分发） | 各升各的，禁止混装；跨线无冲突（互斥接入） → 低 |

```
TB_CODE_CHANGED = NO（本阶段零改动；tb/ 目录、flame_sdk_ios_tb.podspec、adapter/tb/ 均原样）
```

## 8. 我需要从 Taku 官方下载的 SDK 清单

> 只列 Flame 当前 TK 线**实际接入**的组件（依据 §5 主表推导）。目标版本一律取 §2 冻结官方表，不做任何替换。
> **ZCode 不负责下载**——下表为项目负责人前往 Taku 官方后台/联系商务的下载任务清单。

| 序号 | 当前 TK 广告源 | 需要下载的官方包 | 当前版本 | 官方稳定目标版本 | 下载来源 | 是否必需 | 备注 |
|---|---|---|---|---|---|---|---|
| 1 | Taku Core | Taku iOS **稳定版** 6.5.84 整包（含 Core + 配套全量 Network Adapter） | 6.5.71 | **6.5.84** | Taku 官方 | **必需** | 不取 TakuBeta 6.5.90；整包内的各 Network Adapter 版本以 6.5.84 官方配套为准 |
| 2 | 穿山甲 | 穿山甲**单接包**（Pangle） | 7.6.0.4（TTAdapter_Mix 携带） | **7.8.05** | Taku 官方 | **必需** | 继续使用官方单接+GM 共存形态（对应 TTAdapter_Mix） |
| 3 | GroMore（GM） | **GM 插件包** | 7.6.0.4（GromoreAdapter 携带） | **7.8.05** | Taku 官方 | **必需**（当前实际使用） | 必须与序号 2 同为 7.8.05 配套，防 Pangle 双版本混装 |
| 4 | 百度 | 百度 Network 包 | 10.050 | **10.061** | Taku 官方 | **必需** | — |
| 5 | 优量汇 | 优量汇（GDT）Network 包 | 4.15.90 | **4.16.10** | Taku 官方 | **必需** | — |
| 6 | 快手 | 快手（KS）Network 包 | 5.4.10.1 | **5.9.10.1** | Taku 官方 | **必需** | — |
| 7 | 酷盈（Taku ADX） | 酷盈（Taku ADX）包 | 6.5.72 系（adapter 6.5.72.2.1） | **6.5.90** | Taku 官方 | **必需** | ADX adapter 随 Core 发布节奏，取 6.5.84 整包内配套版本即可 |
| 8 | 章鱼 | 章鱼（Octopus/ZY）Network 包 | 2.6.4.29 | **2.6.10.7** | Taku 官方 | **必需** | — |
| 9 | 倍孜 | 倍孜（BeiZi）Network 包 | 5.5.0.0 | **5.5.60** | Taku 官方 | **必需** | — |
| 10 | 美数 | 美数（MS）Network 包 | 2.7.18.1 | **3.0.15.0** | Taku 官方 | **必需** | — |

> 交付方式：项目负责人下载后交回，再进入正式替换阶段（P1+）。具体 adapter pod 的精确版本号以 6.5.84 官方整包清单为准，届时在 P1 中映射为 podspec 依赖行。

## 9. 官方稳定表中但当前 Flame TK 未接入的广告源（勿下载）

| 广告源 | 官方 iOS 版本 | Flame TK 当前是否使用 | 本次是否下载 |
|---|---:|---|---|
| Ubix | 2.12.1 | NO（仓库零引用） | **NO** |
| 领页 | 2.4.38 | NO（标准双线 TK 不含；领页为 TB 侧客户线，见 feature/ios-lingye-* 分支与 docs 17-21，另行评估） | **NO** |
| 趣盟 | 无（官方表未提供 iOS） | NO（仓库零引用） | **NO** |
| TakuBeta | 6.5.90 | NO（明确决定使用稳定版） | **NO** |

```
TAKU_OFFICIAL_DOWNLOAD_NOT_REQUIRED = [TakuBeta 6.5.90, Ubix 2.12.1, 领页 2.4.38, 趣盟]
```

## 10. 当前 TK 已使用但官方稳定表未覆盖的广告源（BLOCKED）

| 广告源 | 当前版本 | 当前证据 | 官方表状态 | 处理 |
|---|---|---|---|---|
| Sigmob | adapter 4.20.12.2.0（WindSDK 5.5.6） | flame_sdk_ios.podspec:77；Flame 私有 spec | 未提供 | **BLOCKED**，等待项目负责人确认 |
| Funlink | adapter 2.9.0.1.2.2.0（FunlinkSDK 2.9.0.1.2） | flame_sdk_ios.podspec:72；doc 13 | 未提供 | **BLOCKED**，等待项目负责人确认 |
| AdGain | 4.2.7.1（SDK+Taku adapter 同版） | flame_sdk_ios.podspec:80-81；doc 14 | 未提供 | **BLOCKED**，等待项目负责人确认 |
| FSUnion（飞梭） | 1.0.8.0 | flame_sdk_ios.podspec:82；doc 14 | 未提供 | **BLOCKED**，等待项目负责人确认 |

> 本阶段不删除、不自行找版本、不升级这四源。若项目负责人确认"维持现状"，四源以当前版本随 6.5.84 共存；
> 6.5.84 整包内若含同源新版 adapter，是否连带升级属 P1 决策项（须评估 WindSDK 冲突面，见 §7）。

```
CURRENT_TK_NETWORK_NOT_IN_OFFICIAL_MATRIX = [Sigmob, Funlink, AdGain, FSUnion]
```

## 11. 趣盟特殊核查

Flame 当前 TK 线**不存在趣盟**（全仓零引用，不在 podspec 13 依赖内）→ 正常记录，不下载。

```
QUMENG_IOS_MATRIX_CONFLICT = NO
```

## 12. 本阶段仓库变化声明

```
SDK_CHANGED = NO
SOURCE_CODE_CHANGED = NO
TB_CODE_CHANGED = NO
NEW_SDK_DOWNLOADED_BY_ZCODE = NO
```

本分支相对基线仅新增：本文档（25 号）+ 00_INDEX.md 索引行。未执行 pod install/update，
未替换任何 Framework/XCFramework，未修改 Podfile/podspec/源码/工程文件。

## 13. P0 Gate

| # | Gate 条件 | 结果 |
|---|---|---|
| 1 | 双线基线分支已确认 | ✅ release/ios-dual-line @ da19c68（git 实测，§1） |
| 2 | 已从双线基线创建独立升级分支 | ✅ upgrade/ios-taku-6.5.84 |
| 3 | Taku Core 当前版本已确认 | ✅ 6.5.71（双源一致，§4） |
| 4 | TK 实际广告源已完整盘点 | ✅ 13 项（podspec + doc 04/14 + 1.0.0 矩阵三方一致，§5） |
| 5 | 每个广告源都有代码/依赖证据 | ✅ podspec 行号 + 依赖文件 + 残留扫描（§5） |
| 6 | 每个当前广告源已映射官方稳定表 | ✅ 9 源有目标版本；4 源显式 NOT_IN_PROVIDED_STABLE_MATRIX 并 BLOCKED（§5/§10） |
| 7 | 已生成实际官方下载清单 | ✅ §8（10 项） |
| 8 | 已识别官方表未覆盖的现有广告源 | ✅ §10 |
| 9 | 已识别官方表存在但 Flame 未使用的广告源 | ✅ §9 |
| 10 | 穿山甲 / GM 已单独核实 | ✅ §6（两者同时存在，7.6.0.4，无重复二进制风险） |
| 11 | 没有下载任何新 SDK | ✅ NEW_SDK_DOWNLOADED_BY_ZCODE = NO |
| 12 | 没有替换任何 SDK | ✅ SDK_CHANGED = NO |
| 13 | 没有修改业务源码 | ✅ SOURCE_CODE_CHANGED = NO |
| 14 | 没有修改 TB 线路 | ✅ TB_CODE_CHANGED = NO |

```
P0_GATE = PASS
```

## 14. 停止点

P0 到此为止。下一动作在项目负责人侧：按 §8 清单从 Taku 官方下载对应 iOS 包并交回。
下载完成前，本分支不进行：下载 SDK、pod update、替换二进制、修改 Adapter、修改广告代码、
编译新版本、兼容性修复。
