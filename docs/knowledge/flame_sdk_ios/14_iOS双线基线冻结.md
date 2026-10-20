# 14 · iOS 双线基线冻结（DUAL_LINE_BASELINE_FREEZE · P0A）

> 冻结日期：2026-10-17
> 阶段：P0A 双线基线固化（后续阶段 P0B = 领页 × TB/ToBid 共存调研）
> 本文是 Flame iOS 唯一正式开发基线的冻结记录与分支治理依据。

> **当前正式基线（2026-10-20，1.1.0 已发布）**
>
> | 线 | Flame | 聚合 Core | 产物 | podspec |
> |---|---|---|---|---|
> | TK | **1.1.0** | **AnyThinkiOS 6.5.84**（+11 Taku 官方 Adapter，Sigmob 官方 5.1.3.2.0，**不依赖 ToBid**） | 根目录 `flame_sdk_ios.xcframework` | `flame_sdk_ios` |
> | TB | **1.1.0** | **ToBid-iOS 5.10.1**（pod 名由 ToBid-iOS-RC 迁移；+11 Adapter subspec，含新增 JuTui/AdScope/Kuying） | `tb/flame_sdk_ios.xcframework` | `flame_sdk_ios_tb` |
>
> 基线分支仍为 `release/ios-dual-line`；正式 tag `1.1.0` → `19903c2`。1.1.0 完整依赖矩阵见 doc 27（TK）/ doc 29（TB）/ doc 31（RC）。
> **下文 §6 Dependency Boundary 与 §7 Build Gate 记录的是 2026-10-17 冻结时点（1.0.1-alpha.4 / AnyThink 6.5.71 / ToBid-iOS-RC 5.5.6）的历史基线**，保留作治理依据，不代表 1.1.0 现状。

## 1. 冻结声明

```
IOS_CANONICAL_BASE_BRANCH = release/ios-dual-line
IOS_CANONICAL_BASE_COMMIT = <BASELINE_COMMIT_SHA>   （见 §11，本文件所在提交的前一个提交之后的最终权威 HEAD 以 push 后核对为准）
IOS_SINGLE_BASELINE_POLICY = DUAL_LINE_ONLY
```

自本文件合入起，所有 Flame iOS 开发（TK 线 / TB 线 / 领页共存 / 新广告类型 / SDK 修复 / 发布准备）**必须从 `release/ios-dual-line` 派生**。

以下不得再作为正式开发起点：

- `feat/tk_adapter`（历史参考，已完全吸收）
- `feat/tb_adapter`（历史参考，已完全吸收）
- 旧单线 release / 历史 alpha 临时分支

## 2. 当前仓库

```
IOS_REPO = /Users/khj/Documents/code/97_ad/ios/flame_ios_sdk
REMOTE   = https://gitee.com/toowe-admin/flame_ios_sdk.git (origin)
```

- 二进制分发仓库（独立，不在本仓库内）：`github.com/javaice007/flame_sdk_ios`（podspec `source` 指向，Tag 拉取产物）
- `flame-specs` 为私有 spec repo（本轮未做任何变更）

## 3. 双线架构（同一基线双线，非分支双线）

`release/ios-dual-line` 单一代码树同时保有 TK 与 TB 两线全部源码：

| 能力 | TK 线（Taku/AnyThink/TopOn） | TB 线（ToBid/WindMill） |
|---|---|---|
| Provider | `flame_sdk_ios/mediation/tk/FlameTKProvider.{h,m}` | `flame_sdk_ios/mediation/tb/FlameTBProvider.{h,m}` |
| Reward Adapter | `flame_sdk_ios/adapter/tk/AtRewardAdapter.{h,m}` | `flame_sdk_ios/adapter/tb/TbRewardAdapter.{h,m}` |
| Splash Adapter | `adapter/tk/AtSplashAdapter.{h,m}` | `adapter/tb/TbSplashAdapter.{h,m}` |
| Interstitial Adapter | `adapter/tk/AtInterstitialAdapter.{h,m}` | `adapter/tb/TbInterstitialAdapter.{h,m}` |
| Banner Adapter | `adapter/tk/AtBannerAdapter.{h,m}` | `adapter/tb/TbBannerAdapter.{h,m}` |
| Native Adapter | `adapter/tk/AtNativeAdapter.{h,m}` + `AtNativeSelfRenderView` | `adapter/tb/TbNativeAdapter.{h,m}` + `TbNativeSelfRenderView` |
| 构建入口 | `./xcFramework_build.sh tk-static` → `build/tk-static/flame_sdk_ios.xcframework` | `./xcFramework_build.sh tb-static` → `build/tb-static/flame_sdk_ios.xcframework` |
| Podspec | `flame_sdk_ios.podspec`（根目录产物） | `flame_sdk_ios_tb.podspec`（tb/ 子目录产物） |

```
TK_AND_TB_COEXIST_IN_SINGLE_SOURCE_BASELINE = YES
```

切换 TK/TB 能力**不需要切分支**：两线胶水始终在源码树内，构建期通过
`FLAME_BUILD_TK / FLAME_BUILD_TB` 宏 + `EXCLUDED_SOURCE_FILE_NAMES`
（TK 排除 `Tb*.* FlameTBProvider.*`；TB 排除 `At*.* FlameTKProvider.*`）产出互斥静态归档。
运行期由 `FlameTKProvider` / `FlameTBProvider` 的 `+load` 向 `FlameMediationRegistry` 自动注册，
Router 按服务端下发 `pt=tk / pt=tb` 激活对应 Provider。

`feat/tk_adapter`、`feat/tb_adapter` 的全部提交均已包含在 `release/ios-dual-line` 历史中
（`git log release/ios-dual-line..feat/*_adapter` 为空），定位为**历史参考分支**：

```
TK_FEATURE_BRANCH_FULLY_ABSORBED = YES
TB_FEATURE_BRANCH_FULLY_ABSORBED = YES
MISSING_FROM_DUAL_LINE = []
```

## 4. 公共 API（TK/TB 完全一致）

TK 与 TB 对客户暴露**同一套**公共 API（同一份源码头文件，详见 `12_Public_API兼容基线.md`）：

- 初始化：`FlameSdk` `+initWithAppId:appKey:` / `+initWithAppId:appKey:callback:` / `+clear` / `+setDebug:` / `+isInitialized` / `-getVersion`
- 广告创建：`createSplashAd…` / `createRewardAd…` / `createInterstitialAd…` / `createBannerAd…` / `createSelfRenderBannerAd…` / `createNativeAd…`
- 监听协议：`FlameCallback` + 5 个广告 Listener（全 `@optional`，仅 `FlameNativeListener` 全 `@required`）

```
PUBLIC_API_PARITY = PASS
```

客户从 TK Pod 切到 TB Pod 只改 Podfile 依赖行（`flame_sdk_ios` → `flame_sdk_ios_tb`），
业务代码零改动。

## 5. Pod 模型

| | TK | TB |
|---|---|---|
| Pod 名 | `flame_sdk_ios` | `flame_sdk_ios_tb` |
| module_name | `flame_sdk_ios` | `flame_sdk_ios`（同名，import 一致） |
| 版本（冻结时） | 1.0.1-alpha.4 | 1.0.1-alpha.4 |
| vendored 产物 | 根目录 `flame_sdk_ios.xcframework`（静态） | `tb/flame_sdk_ios.xcframework`（静态） |

```
DUAL_POD_MODEL = PASS（两 pod 互斥、module/import 对客户一致）
TK_AND_TB_SHARE_BINARY = NO（两份独立静态归档，互斥分发）
```

## 6. Dependency Boundary（**历史基线**：2026-10-17 冻结时点事实，1.0.x 时期；1.1.0 现状见顶部与 doc 27/29）

**TK_DEPENDENCIES**（`flame_sdk_ios.podspec`，1.0.1-alpha.4）：

```
OpenSSL-Universal ~> 3.6
AnyThinkiOS 6.5.71
ToBid-iOS-RC 5.5.6            # 仅为 sigmob adapter 统一 WindSDK/WindFoundation 来源，flame 本体零 WindMill 符号
AnyThinkMediationAdxSmartdigimktCNAdapter 6.5.72.2.1
AnyThinkMediationGromoreAdapter 7.6.0.4.2.0
AnyThinkMediationBaiduAdapter 10.050.2.1
AnyThinkMediationMSAdapter 2.7.18.1.2.0
AnyThinkMediationZYAdapter 2.6.4.29.2.0
AnyThinkMediationFunlinkAdapter 2.9.0.1.2.2.0
AnyThinkMediationBeiZiAdapter 5.5.0.3.2.0
AnyThinkMediationKuaiShouAdapter 5.4.10.1.2.0
flame_sdk_ios_tk_sigmob_adapter 4.20.12.2.0   # Flame 私有 spec
AnyThinkMediationTTAdapter_Mix 7.6.0.4.2.0
AnyThinkMediationGDTAdapter 4.15.90.2.0
AdGainSDK 4.2.7.1 / AdGainSDKTakuAdapter 4.2.7.1
FSUnionAdSDK 1.0.8.0
```

**TB_DEPENDENCIES**（`flame_sdk_ios_tb.podspec`，1.0.1-alpha.4）：

```
OpenSSL-Universal ~> 3.6
ToBid-iOS-RC 5.5.6 + subspecs：CSJAdapter / GDTAdapter / BaiduAdapter / KSAdapter /
  MintegralAdapter / OctopusAdapter / MSAdAdapter / GromoreAdapter（全部 5.5.6）
```

TB podspec 红线（不得依赖）：AnyThinkiOS / AnyThinkMediation* / flame_sdk_ios_tk_sigmob_adapter / AdGain* / FSUnion* / 独立 SigmobAd-iOS（与 ToBid 内置 WindSDK 冲突）。

## 7. Build Gate 与二进制边界（**历史基线**：2026-10-17 冻结验证；1.1.0 RC 构建/隔离见 doc 31）

### 工具链事实（重要）

本机当前唯一 Xcode 为 **27.1**，其工具链支持的部署目标范围为 **iOS 15.0–27.1.x**，
**无法编译 iOS 13.0 部署目标**（`IPHONEOS_DEPLOYMENT_TARGET=13.0` 直接报错）。
SDK 产品契约为 iOS 13.0（两个 podspec / Podfile / 构建脚本一致）。
1.0.1-alpha.4 正式产物（2026-08-31，b03ddea）由旧版 Xcode 构建完成。

因此本轮 Build Gate 采用**验证口径**：镜像 `xcFramework_build.sh` 全部构建参数
（宏、排除清单、staticlib、BUILD_LIBRARY_FOR_DISTRIBUTION、Release、双切片），仅把部署目标
13.0 提升为 15.0，**未修改任何被跟踪文件**。该口径证明源码树健康与符号隔离；**不可用于发布产物**
（发布仍需 DT=13.0 的旧版 Xcode 环境）。

### 结果

```
TK_BUILD = PASS（DT=15 验证口径；device arm64 + simulator x86_64；libtool 静态归档）
TB_BUILD = PASS（DT=15 验证口径；同上）

TK_BINARY_AUDIT = PASS：
  build/tk-static/flame_sdk_ios.xcframework
  ios-arm64 + ios-x86_64-simulator，current ar archive，
  core（FlameSdk/Logger/Router/Registry/AdapterManager/ConfigManager）+ TK 胶水 7 类符号齐全，
  TB/WindMill 符号污染 = 0，AnyThink 未定义引用 8 个（客户链接期解析，设计内），
  Headers + Modules/module.modulemap 齐全。

TB_BINARY_AUDIT = PASS：
  build/tb-static/flame_sdk_ios.xcframework
  ios-arm64 + ios-x86_64-simulator，current ar archive，
  core + TB 胶水 7 类符号齐全，
  TK/AnyThink 符号污染 = 0，WindMill 未定义引用 12 个（ToBid-iOS-RC 链接期解析，设计内），
  OpenSSL 未定义引用 12 个（OpenSSL-Universal 解析，设计内），
  Headers + Modules 齐全。
```

（冻结前既有产物复核：根目录 TK 副本与 8/31 `build/tb-static` TB 产物同样通过上述符号审计。）

## 8. 未提交文件处置（P0A 审计，2026-10-17）

冻结前工作区共 15 个未提交文件（用户截图口径"约 16"）：

| 文件 | 分类 | 处置 |
|---|---|---|
| `flame_sdk_ios.xcodeproj/project.pbxproj`（47+/47-，纯 UUID 变更 + CP 脚本阶段重排） | B. DUAL_LINE_BUILD_CONFIG | 提交（pod install 重新集成产物，语义中性） |
| `docs/knowledge/flame_sdk_ios/00_INDEX.md`～`13_Funlink…md`（13 个知识库文档） | D. DUAL_LINE_DOC | 提交（事实审计资产，自声明不含凭证，已扫描确认） |
| `.zcode/plans/plan-sess_*.md`（ZCode 历史会话计划） | G. LOCAL_ENV | 不提交；`.zcode/` 已加入 `.gitignore` |

```
INITIAL_UNCOMMITTED_FILE_COUNT = 15
UNCOMMITTED_FILE_AUDIT = PASS
SECRET_PRESENT = NO
UNKNOWN_FILES = []
EXCLUDED_TEMP_FILES = [.zcode/plans/plan-sess_8e461569-….md]
```

本知识库目录（`docs/knowledge/flame_sdk_ios/`，00_INDEX.md 即索引）即本仓库的
context 文档体系，本文续其编号为 14，不另建第二套 docs。

## 9. 历史分支定位

| 分支 | 状态 | 定位 |
|---|---|---|
| `release/ios-dual-line` | 唯一正式基线 | 所有未来开发起点 |
| `feat/tk_adapter` | 已完全吸收 | 历史参考，禁止作为开发起点 |
| `feat/tb_adapter` | 已完全吸收 | 历史参考，禁止作为开发起点 |
| `main` / `master` | 旧单线历史 | 禁止作为新需求基线 |
| `research/ios-lingye-tobid-coexistence` | P0A 后创建 | 领页共存调研专用（见 §10） |

## 10. 后续分支治理与领页调研分支

冻结 push 成功后，从 `IOS_CANONICAL_BASE_COMMIT` 创建：

```
LINGYE_RESEARCH_BRANCH = research/ios-lingye-tobid-coexistence
RESEARCH_BRANCH_BASE_CORRECT = YES（merge-base == 基线 commit）
```

该分支第一阶段**只做调研**，不直接改正式 SDK。

## 11. 基线 Commit 与推送状态

```
DUAL_LINE_BASELINE_HEAD = <BASELINE_COMMIT_SHA>（docs 提交后的分支 HEAD，见 git log）
DUAL_LINE_BASELINE_PUSHED = <PUSH_STATUS>
LOCAL_DUAL_LINE_HEAD = <LOCAL_SHA>
REMOTE_DUAL_LINE_HEAD = <REMOTE_SHA>
```

（本文件先于最终 push 写入；上述占位符以 §12 决策记录与 push 后的 git 核对为准，
最终 SHA 在 P0A 报告中冻结。）

## 12. 冻结决策记录（D1–D4）

- **D1**：iOS 以后只有一个正式基线——TK/TB 双线版本（`release/ios-dual-line`）。
- **D2**：领页客户优先使用 TB/ToBid 线（`flame_sdk_ios_tb`），不用 TK/Taku 线。
- **D3**：选择 TB 的主要目的：避免 Flame 与领页争用 Taku/AnyThink manager（singleton / first-init ownership / credential ownership）。
- **D4**：TB 是否最终可用于领页，必须经静态依赖、二进制、Pod install/build、运行时共存验证后才能最终 PASS。当前状态：

```
RECOMMENDED_CUSTOMER_LINE = TB
LINGYE_TB_PRODUCT_DIRECTION = FROZEN
LINGYE_TB_COEXISTENCE_VALIDATED = NO
```

P0B 待办（下一阶段，本轮禁止执行正式修复）：TB 零 Taku/AnyThink 审计、真实领页 iOS artifact 审计、
ToBid/WindMill duplicate 检查、CocoaPods coexist build、初始化顺序、真机运行时验证方案。

## 13. 本轮禁止项（执行状态）

未发布 CocoaPods 新版本、未改 flame-specs、未 tag、未 merge 任何 feat 分支、未 force push、
未修改领页 SDK、未 patch 客户 binary、未删除 TK/TB 任一线、research 分支从干净基线创建。
