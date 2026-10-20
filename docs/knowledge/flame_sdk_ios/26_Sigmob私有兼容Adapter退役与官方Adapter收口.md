# 26 · Sigmob 私有兼容 Adapter 退役与 Taku 官方原生 Adapter 收口（P1-R1）

> 阶段标识：P1-R1-SIGMOB-NATIVE-MIGRATION ｜ 日期：2026-10-20 ｜ 分支：upgrade/ios-taku-6.5.84
> 结论速览：`P1_R1_SIGMOB_NATIVE_MIGRATION = PASS`（构建/依赖收口口径；**真机广告验收未执行**，
> `SIGMOB_RUNTIME_ACCEPTANCE = NOT_YET_EXECUTED`）
> 官方版本（项目负责人提供，冻结）：`AnyThinkMediationSigmobAdapter 5.1.3.2.0`

---

## 1. 历史背景：私有 Adapter 当年为什么存在

Flame 曾以"单二进制（动态）"形态同时服务 TK（TopOn/AnyThink）与 TB（ToBid/WindMill）两类客户：
同一个 `flame_sdk_ios.xcframework` 内同时含 TK 胶水与 TB 胶水。Sigmob 广告源由此产生一个死结：

- Taku 官方 Sigmob Adapter pod（`AnyThinkMediationSigmobAdapter`）自带传递依赖 `SigmobAd-iOS`，
  其内含 Sigmob 官方 `WindSDK` / `WindFoundation` framework；
- TB 线核心 `ToBid-iOS-RC` 同样携带**同名** `WindSDK` / `WindFoundation`（Sigmob 系同源）；
- 同一 App 同时接 TK + TB 生产包 → 两份同名 framework → duplicate framework / 符号冲突。

当时的解法（phase-5a.12-step1e/1f 两轮设计）：

> 创建 Flame 私有 spec `flame_sdk_ios_tk_sigmob_adapter 4.20.12.2.0`：**vendored TopOn 官方
> `AnyThinkSigmobAdapter.xcframework` 原始二进制**（source.http 直指 TopOn 官方 OSS 下载地址），
> 但**去掉 `SigmobAd-iOS` 传递依赖**，`WindSDK`/`WindFoundation` 改由 TK podspec 显式声明的
> `ToBid-iOS-RC 5.5.6` 统一提供——全 App 只有一份 WindSDK。

## 2. 私有 Adapter 实际内容审计（先审计后退役，非直接删）

审计对象：`flame-specs` 仓 `flame_sdk_ios_tk_sigmob_adapter/4.20.12.2.0/flame_sdk_ios_tk_sigmob_adapter.podspec.json`
（本地 checkout：`/Users/khj/Documents/code/97_ad/ios/github_build/flame-specs`）。

| 审计维度 | 事实 |
|---|---|
| source_files / headers / module / script / patch | **无**（纯二进制 wrapper pod，无任何自研代码） |
| source | `https://topon-sdk-release.oss-accelerate.aliyuncs.com/AnyThink_Release/iosnetwork_2/AnyThinkSigmobAdapter/4.20.12.2.0/AnyThinkSigmobAdapter-4.20.12.2.0.zip`（**TopOn 官方 OSS**） |
| vendored_frameworks | `AnyThinkSigmobAdapter-4.20.12.2.0/AnyThinkSigmobAdapter.xcframework`（官方原始二进制，无改包） |
| dependencies | 仅 `AnyThinkiOS >= 6.5.60`；**无 SigmobAd-iOS**（与官方 pod 的唯一实质差异） |
| subspec / exclude_files / linker flags | 无特殊项；仅 `OTHER_LDFLAGS: -ObjC`、`static_framework: true` |

与 Taku 官方同版本 pod（`AnyThinkMediationSigmobAdapter 4.20.12.2.0`，trunk）对比：官方多一条
`SigmobAd-iOS` 依赖，其余（下载源、vendored 二进制、xcconfig）一致。官方 5.1.3.2.0 podspec 同源
（同一 TopOn OSS 域名 + `vendored_frameworks` 结构），差异仍仅为依赖声明。

```
PRIVATE_SIGMOB_HAS_SOURCE_PATCH = NO
PRIVATE_SIGMOB_ONLY_DEPENDENCY_WORKAROUND = YES
```

## 3. 为什么现在可以退役（前提变化证据）

两个历史前提均已消失：

**① TK/TB 已拆分为独立生产包**（`TK_TB_PRODUCTION_PACKAGE_SEPARATED = YES`）：

| 证据项 | TK | TB |
|---|---|---|
| 交付产物 | 根目录 `flame_sdk_ios.xcframework` | `tb/flame_sdk_ios.xcframework` |
| podspec | `flame_sdk_ios.podspec` | `flame_sdk_ios_tb.podspec`（互斥，module 同名不可同接） |
| 客户依赖 | AnyThinkiOS + TK adapter 生态（**迁移后不再含 ToBid**） | ToBid-iOS-RC 5.5.6 + 8 subspec，不含 AnyThink |
| 二进制断言（1.0.2 产物实测） | 根目录产物 `nm -u`/`strings`：WindMill/Wind/Sigmob 符号 = 0；`FlameTBProvider`/`Tb*` 类 = 0 | TB 产物零 AnyThink 胶水（doc 22/23 口径） |

→ TK 客户 App 不再与 ToBid 同 App 共存，WindSDK 只会有一份来源，冲突前提不存在。

**② Taku 官方已给出精确目标版本**：`AnyThinkMediationSigmobAdapter 5.1.3.2.0`
（trunk 官方 podspec：依赖 `AnyThinkiOS >=6.5.60` —— 与 TK 锁定的 6.5.71 兼容；依赖
`SigmobAd-iOS 5.1.3`；binary 同为 TopOn OSS 官方 zip）。

## 4. 修改内容（最小修改清单）

| 文件 | 修改 |
|---|---|
| `flame_sdk_ios.podspec` | ① `s.dependency 'flame_sdk_ios_tk_sigmob_adapter', '4.20.12.2.0'` → `s.dependency 'AnyThinkMediationSigmobAdapter', '5.1.3.2.0'`；② 删除 `s.dependency 'ToBid-iOS-RC', '5.5.6'`（其唯一用途即为私有 adapter 提供 WindSDK/WindFoundation，podspec 注释自证）；③ 注释区记录退役历史；④ 附录 note 2 的模拟器 slice 限制改述为 TK 侧 SigmobAd-iOS 事实（SigmobAd-iOS 5.1.3 自带 `EXCLUDED_ARCHS[sdk=iphonesimulator*]=arm64`，Apple Silicon 模拟器需 Rosetta，真机不受影响） |
| `README.md` | 3 处 Sigmob 表述同步（组成表 / 对比表 / 客户须知 3） |
| `docs/knowledge/flame_sdk_ios/04` | 顶部加 P1-R1 更新标注（13 源清单中私有 Sigmob 行已退役） |
| `docs/knowledge/flame_sdk_ios/25` | §10 Sigmob 行 BLOCKED → `SIGMOB_UPGRADE_PATH = OFFICIAL_NATIVE_ADAPTER`；机器字段同步 |
| `docs/knowledge/flame_sdk_ios/26` | 本文档 |
| `00_INDEX.md` | 26 号索引行 |

**未修改**（零 diff，见 §9）：`flame_sdk_ios_tb.podspec`、`tb/`、`adapter/tb/`、`adapter/tk/`、
`mediation/`、ToBid 版本、TB Network subspec、Flame 公共 API、Podfile（构建期依赖，仍为
AnyThinkiOS 6.5.71 + ToBid 5.5.6 双声明，服务本仓双产物构建，与客户依赖链无关）。

## 5. 官方 Adapter 依赖解析图（前后对比）

**Before**（adsurge-ios-demo @ flame_sdk_ios 1.0.1-alpha.4 Podfile.lock 实录，代表历史形态）：

```
flame_sdk_ios
├── flame_sdk_ios_tk_sigmob_adapter 4.20.12.2.0   （Flame 私有 spec，无 SigmobAd-iOS）
│     └── AnyThinkiOS >= 6.5.60
├── ToBid-iOS-RC 5.5.6                            ← TK 仅为借 WindSDK/WindFoundation 而引入
└── （其余 12 个 TK 广告源依赖不变）
```

**After**（本阶段 fresh consumer Podfile.lock 实录，28 pods）：

```
flame_sdk_ios (1.0.2)
├── AnyThinkMediationSigmobAdapter 5.1.3.2.0      （Taku 官方原生）
│     ├── AnyThinkiOS >= 6.5.60                   → 解析 6.5.71（与锁定核心一致）
│     └── SigmobAd-iOS = 5.1.3                    （Sigmob 官方 wind_release_ios_5.1.3）
│           └── subspec WindSDK → wind-sdk-ios/{WindSDK, WindFoundation}.xcframework
├── AnyThinkiOS 6.5.71
├── （其余 12 个 TK 广告源依赖逐字不变）
└── OpenSSL-Universal ~> 3.6
```

```
OFFICIAL_SIGMOB_RESOLVED_DEPENDENCIES = [
  AnyThinkiOS >= 6.5.60（实际解析 6.5.71）,
  SigmobAd-iOS = 5.1.3（subspec WindSDK → WindSDK.xcframework + WindFoundation.xcframework，
  Sigmob 官方 OSS wind_release_ios_5.1.3，无进一步 pod 传递依赖）
]
TK_SIGMOB_REQUIRES_TOBID = NO
```

专项回答（§九清单）：

| 问题 | 答案 |
|---|---|
| 实际解析出什么 Network SDK | `SigmobAd-iOS 5.1.3`（精确版本，官方 pin，非范围） |
| 依赖 WindSDK/WindFoundation？ | 是——由 **SigmobAd-iOS 自带**（wind-sdk-ios zip），不再来自 ToBid |
| 依赖 SigmobAd-iOS？ | 是（= 5.1.3 精确 pin） |
| 还需要 ToBid-iOS-RC？ | **NO**（lock/树/链接三重验证，见 §6） |
| 两个 WindSDK？ | 否：consumer Pods 树 `WindSDK.xcframework` 计数 = 1 |
| 两个 WindFoundation？ | 否：计数 = 1 |
| 同名 Sigmob framework 重复？ | 否：Pods 树仅 `Pods/SigmobAd-iOS/wind-sdk-ios/` 一处 |
| duplicate symbol 风险？ | 无：链接期 `duplicate symbol` 计数 = 0（§6 构建实录） |

## 6. 构建验证实录（TK_SIGMOB_NATIVE_BUILD）

**方式**：fresh TK consumer（xcodegen 最小 App，`pod 'flame_sdk_ios', :path => <本仓根目录>`）。
`:path` 模式说明：podspec 文件与发布流程完全同一份（原样未改的 `flame_sdk_ios.podspec`）；vendored
`flame_sdk_ios.xcframework` 取本仓根目录已提交副本，`git diff 1.0.2 HEAD -- flame_sdk_ios.xcframework`
为空 = 与已发布 tag 1.0.2 树逐字节一致（本阶段不重建 flame 二进制，产物不变）。采用 `:path` 仅因
验证时段 github clone 分发仓连接不稳定（curl 18 / SSL_ERROR_SYSCALL），与依赖契约无关。

**工具链**：`Xcode 26.0.1`（正式 DT13 发布工具链，memory P0G 冻结口径；默认 Xcode 27.1 最低部署
目标 15.0，不适用 13.0 契约）。构建目标：`-sdk iphoneos`（arm64 真机 SDK，无签名）。

```
pod install     = PASS（28 pods，CocoaPods 1.16.2）
compile         = PASS（0 error）
link            = PASS（BUILD SUCCEEDED，EXIT=0）
duplicate symbol = 0
module not found = 0
undefined symbols = 0
WindSDK/WindFoundation 重复 = 0（Pods 树单源 + 链接期 0 duplicate）
AnyThink Sigmob Adapter 缺类    = 0（见下方符号断言）
flame TK xcframework 正常参与链接 = 是（FlameTKProvider 符号在位）
TK_SIGMOB_NATIVE_BUILD = PASS
```

**产物符号断言**（app 主执行体为 Xcode 26 Debug 的 `.debug.dylib` 载体，78MB 全量静态链接，
对其断言）：

| 断言 | 结果 |
|---|---|
| `otool -L` ToBid/WindMill 动态依赖 | **0** |
| `nm -u` WindMill/ToBid 类符号 | **0** → `TK_ZERO_TOBID_CORE = PASS` |
| 已定义 `_OBJC_CLASS_$_Wind*`/`_Sigmob*` | 298（Sigmob 官方 SDK 实际链入） |
| `ATSigmob{Base,Interstitial,Native,NativeObject,RewardedVideo}Adapter` | 全部在位（官方 adapter 无缺类） |
| `FlameTKProvider` 类符号 | 1（flame 静态产物正常链接） |
| Frameworks/ 嵌入动态库 | AnyThinkSDK / GDTMobSDK / KSAdSDK / OpenSSL / TTSDK 系列（Taku 生态），**无任何 WindMill/ToBid** |

```
TK_ZERO_TOBID_CORE = PASS
TK_ZERO_TB_ADAPTER = PASS
PRIVATE_SIGMOB_RETIRED = YES
PRIVATE_SIGMOB_ACTIVE_REFERENCE_COUNT = 0
```

（`PRIVATE_SIGMOB_ACTIVE_REFERENCE_COUNT` 口径 = 当前 TK 正式依赖链中的依赖性引用；本仓
podspec/文档中的历史注释与 doc 记录属退役证据，非引用。）

## 7. 私有 Adapter 资产处理

```
本仓（flame_ios_sdk）：正式依赖引用 = 0（git grep 仅命中注释/文档，无 podspec 依赖行、
  无 Podfile/Podfile.lock/pbxproj 引用）。
flame-specs 仓（已发布 specs，github javaice007/flame-specs）：
  flame_sdk_ios_tk_sigmob_adapter/4.20.12.2.0 保留，不删除。
  原因：已发布的 flame_sdk_ios 1.0.0～1.0.2 各版 podspec 仍依赖它；删除会破坏已发布版本的
  客户端解析，违反发布不可变承诺（doc 23 §8.3 治理 Gate）。它继续存在≠继续被现行版本引用，
  下一版 TK podspec 已指向官方 Adapter。
本阶段未对 flame-specs 做任何写入（git status clean）。
```

## 8. TB 零影响证据

```
git diff --stat -- tb/ flame_sdk_ios_tb.podspec flame_sdk_ios/adapter/tb/ flame_sdk_ios/mediation/tb/
  = 空（零业务变化）
ToBid 版本 = 5.5.6 未动（TB podspec 未改）
TB Network dependency declarations = 未动
TB_CODE_CHANGED = NO
TB_DEPENDENCY_CHANGED = NO
```

TK/TB 唯一的历史耦合点（TK 私有 adapter 借 ToBid 的 WindSDK/WindFoundation）已随本次迁移解除；
ToBid 及 TB 产物完全不受影响。

## 9. 剩余真机验收项（后续阶段，非本阶段范围）

本阶段只收口依赖架构与编译链接。真实 Sigmob 广告链路需在真机广告源验收阶段执行：

- init / load / fill / show / callback / reward（transId）/ impression 全链路
- SigmobAd-iOS 5.1.3 与 Taku 6.5.84（后续升级后的核心）组合下的 waterfall 真实填充
- 模拟器限制确认：SigmobAd-iOS 5.1.3 自带 `EXCLUDED_ARCHS[sdk=iphonesimulator*]=arm64`
  （Apple Silicon 模拟器需 Rosetta；真机不受影响）

```
SIGMOB_RUNTIME_ACCEPTANCE = NOT_YET_EXECUTED
```

> **2026-10-20 P2-TK 补记**：Sigmob 5.1.3.2.0 已随 Taku Core 6.5.84 全矩阵完成升级与静态技术验证
> ——fresh consumer 解析 `SigmobAd-iOS 5.1.3`（WindSDK/WindFoundation 各 1 份）、构建链接 PASS、
> 真机 init smoke PASS（ATAPI 运行时版本 `UA_6.5.84`）。本节 P1-R1 的历史审计结论不变；
> 真机 Sigmob 广告填充验收仍为后续项。详见 doc 27。

## 10. 维护者须知（防回接）

> 原 `flame_sdk_ios_tk_sigmob_adapter` 是 TK/TB 共包时代为解决 WindSDK/Sigmob 依赖冲突引入的
> 兼容 workaround。随着 TK/TB 正式拆分为独立生产包，该 workaround 不再属于现行架构。TK 恢复
> 使用 Taku 官方原生 Sigmob Adapter。**不要把私有 spec 接回现行依赖**——它会使 TK 重新引入
> ToBid-iOS-RC，违反 TK 包的 ToBid 零依赖契约（`TK_SIGMOB_REQUIRES_TOBID = NO`）。

## 11. 机器可读结论

```
PRIVATE_SIGMOB_HAS_SOURCE_PATCH = NO
PRIVATE_SIGMOB_ONLY_DEPENDENCY_WORKAROUND = YES
TK_TB_PRODUCTION_PACKAGE_SEPARATED = YES
OLD_TK_SIGMOB_ADAPTER = flame_sdk_ios_tk_sigmob_adapter 4.20.12.2.0
NEW_TK_SIGMOB_ADAPTER = AnyThinkMediationSigmobAdapter 5.1.3.2.0
OFFICIAL_SIGMOB_RESOLVED_DEPENDENCIES = [AnyThinkiOS >= 6.5.60（解析 6.5.71）, SigmobAd-iOS = 5.1.3（WindSDK subspec → WindSDK + WindFoundation xcframework，单份单源）]
TK_SIGMOB_REQUIRES_TOBID = NO
PRIVATE_SIGMOB_ACTIVE_REFERENCE_COUNT = 0
PRIVATE_SIGMOB_RETIRED = YES
TK_ZERO_TOBID_CORE = PASS
TK_ZERO_TB_ADAPTER = PASS
TK_SIGMOB_NATIVE_BUILD = PASS
TB_CODE_CHANGED = NO
TB_DEPENDENCY_CHANGED = NO
SIGMOB_RUNTIME_ACCEPTANCE = NOT_YET_EXECUTED

P1_R1_SIGMOB_NATIVE_MIGRATION = PASS
```

## 12. 验证环境备注

- 验证 harness 实际执行位置：仓库外 `/Users/khj/Documents/code/97_ad/ios/p1r1-tk-sigmob-consumer/`
  （Podfile 以 `:path` 引用本仓 podspec + 根目录 vendored 产物；log：`pod_install.log`、
  `xcodebuild.log`）。harness 定义已入库 `validation/ios-taku-6.5.84-sigmob-migration/` 供复现。
- 入库原因备注：曾两次尝试在 `validation/ios-taku-6.5.84-sigmob-migration/` 内直接构建，
  构建期间该目录内容被环境侧清空（时间戳 17:39/17:44，仅剩 build/ 目录），原因未定位
  （非 git hooks，无残留进程）；移出仓库后同一构建一次通过。后续如需在仓内复跑，建议先
  在临时目录验证。
