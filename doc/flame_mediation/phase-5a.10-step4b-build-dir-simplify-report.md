# Phase 5A.10 Step 4B — 构建目录精简报告

> **分支**：`research/thin-core-binary`
> **状态**：本地验证完成（未发布 / 未 tag / 未 push origin / 未进 Phase 6）
> **前置**：Step 4（正式测试态清理）已通过
> **日期**：2026-06-18

---

## 一、背景

Step 4 完成后，正式 core binary 路径是 `build/core_named/flame_sdk_ios_core.xcframework`。

问题：`core_named` 只是实验阶段子目录名，不是必须。真正必须保留的是：
- xcframework 包名：`flame_sdk_ios_core.xcframework`
- framework 名：`flame_sdk_ios_core.framework`
- binary 名：`flame_sdk_ios_core`
- module 名：`flame_sdk_ios_core`
- install name：`@rpath/flame_sdk_ios_core.framework/flame_sdk_ios_core`

本阶段把正式输出整理成更清爽的结构：`build/flame_sdk_ios_core.xcframework`（build/ 顶层，无子目录）。

---

## 二、12 项检查清单

| # | 检查项 | 结果 |
|---|--------|------|
| 1 | 确认 core_named 目录不是必须 | ✅ 仅实验阶段命名，framework/binary/module/install name 才是必须 |
| 2 | 正式输出改为 `build/flame_sdk_ios_core.xcframework` | ✅ |
| 3 | 删除 `build/core_named`、`build/core`、`build/tk`、`build/tb` | ✅ 全删（build/ 顶层只剩 flame_sdk_ios_core.xcframework） |
| 4 | 删除中间 xcarchive | ✅ 脚本构建期放 `Archives/core_named/`，构建后 `rm -rf Archives` |
| 5 | 两个正式 podspec 只引用 `build/flame_sdk_ios_core.xcframework` | ✅ grep 确认两 podspec 均为此路径，无 research/、无 core_named/core/tk/tb |
| 6 | core binary 零三方污染 | ✅ nm 对 14 类三方符号全部无输出；otool 仅 OpenSSL + 4 系统库；176K |
| 7 | TK 单 pod 验证通过 | ✅ pod install (28 pods, 无 ToBid) + 真机 BUILD SUCCEEDED + `+[FlameTKProvider load]` + AtRewardAdapter(38) + 无 TB 污染 + embed core+OpenSSL |
| 8 | TB 单 pod 验证通过 | ✅ pod install (4 pods, 无 AnyThink) + 真机 BUILD SUCCEEDED + `+[FlameTBProvider load]` + TbRewardAdapter(43) + 无 TK 污染 + embed core+OpenSSL |
| 9 | 当前最终目录结构 | ✅ `build/` 下仅 `flame_sdk_ios_core.xcframework`（无 core_named/core/tk/tb/xcarchive） |
| 10 | 未发布 / 未 tag / 未 push origin / 未进 Phase 6 | ✅ 无新 tag（仅历史 v0.1.1）；无 origin/research/thin-core-binary；TB 其他广告类型仍 nil |
| 11 | 本阶段 commit hash | ✅ `2f97fbe` |
| 12 | 更新后的 /compact | 见下文「四」 |

---

## 三、改动明细

### 3.1 `xcFramework_build.sh`

| 改动点 | 改造前 | 改造后 |
|--------|--------|--------|
| core-named `VARIANT_OUTPUT_SUBDIR` | `core_named` | `""`（空，正式产物直接到 build/） |
| core-named `OUTPUT_DIR` | `./build/core_named` | `./build` |
| core-named xcarchive 路径 | 与 OUTPUT_DIR 同目录（污染正式输出） | `./Archives/core_named/`（独立临时目录） |
| 构建后清理 | 无 | core-named 变体追加 `rm -rf ./Archives` |
| tk/tb/core 变体路径 | 不变 | 不变（仍 `build/<variant>/`） |
| 头部注释 | "Phase 5A.10 Step 2B" | "Phase 5A.10 Step 4B" |

### 3.2 `flame_sdk_ios.podspec` / `flame_sdk_ios_tb.podspec`

```ruby
# 改造前
s.vendored_frameworks = 'build/core_named/flame_sdk_ios_core.xcframework'

# 改造后
s.vendored_frameworks = 'build/flame_sdk_ios_core.xcframework'
```

注释同步更新。

---

## 四、最终目录结构

```
flame_ios_sdk/
├── build/
│   └── flame_sdk_ios_core.xcframework/      # ✅ 唯一正式二进制（gitignored）
│       ├── Info.plist
│       ├── ios-arm64/
│       │   └── flame_sdk_ios_core.framework/
│       │       ├── flame_sdk_ios_core       # 176K binary
│       │       ├── Headers/                 # 22 headers (10 public + 12 internal)
│       │       ├── Modules/module.modulemap
│       │       └── Info.plist
│       └── ios-x86_64-simulator/
│           └── flame_sdk_ios_core.framework/
│               └── ...
├── flame_sdk_ios.podspec                    # 方案 D TK 正式
├── flame_sdk_ios_tb.podspec                 # 方案 D TB 正式
├── flame_sdk_ios/wrappers/                  # 正式转发头（20 个）
├── xcFramework_build.sh                     # 构建脚本（输出到 build/ 顶层）
├── Podfile                                  # SDK 构建期依赖入口
└── doc/flame_mediation/                     # 所有阶段报告
```

**不再出现**：`build/core_named/`、`build/core/`、`build/tk/`、`build/tb/`、`Archives/`、`*.xcarchive`、`research/`。

---

## 五、Core binary 完整性

| 检查项 | 值 |
|--------|-----|
| 体积 | 176K |
| framework 名 | `flame_sdk_ios_core.framework` ✅ |
| binary 名 | `flame_sdk_ios_core` ✅ |
| module 名 | `flame_sdk_ios_core` ✅ |
| install_name | `@rpath/flame_sdk_ios_core.framework/flame_sdk_ios_core` ✅ |
| otool -L | 仅 `@rpath/OpenSSL.framework/OpenSSL` + Foundation/libobjc/libSystem/CoreFoundation |
| Headers | 22（10 公共 API + 12 内部协议） |
| nm 三方符号 | 零（AnyThink/WindMill/WindSDK/WindFoundation/Sigmob/AdGain/BUAd/CSJ/GDT/KSAd/Baidu/FSUnion/FlameTKProvider/FlameTBProvider/AtRewardAdapter/TbRewardAdapter 全无） |
| 三方 bundle/metallib | 无 |

---

## 六、更新后的 /compact

```
Phase 5A.10 Step 4B 完成（构建目录精简）。

分支：research/thin-core-binary @ 2f97fbe（Step 4B）← 5759d2b（Step 4）← 4fddaf2（Step 3）
工作区：SDK repo 干净；Demo repo 工作树保留 TB 验证状态

本阶段完成：
把正式 core binary 输出从 build/core_named/ 提升到 build/ 顶层。
- xcFramework_build.sh: core-named OUTPUT_DIR=./build, xcarchive 放 Archives/core_named/（构建后清理）
- 两个正式 podspec: s.vendored_frameworks = 'build/flame_sdk_ios_core.xcframework'
- build/ 下仅 flame_sdk_ios_core.xcframework（无 core_named/core/tk/tb/xcarchive/Archives）

正式结构（最清爽）：
- flame_sdk_ios.podspec / flame_sdk_ios_tb.podspec（方案 D）
- flame_sdk_ios/wrappers/{flame_sdk_ios, flame_sdk_ios_tb}/（各 10 转发头）
- build/flame_sdk_ios_core.xcframework（176K, 零三方污染, 22 headers, gitignored）
- xcFramework_build.sh（构建脚本，core-named 输出到 build/ 顶层）
- doc/flame_mediation/（所有阶段报告 + integration-thin-core-draft.md）

验证（本地, 未发布/tag/push origin）：
- 构建：./xcFramework_build.sh core-named → build/flame_sdk_ios_core.xcframework
- TK: pod install ✅ (28 pods, 无 ToBid), 真机 BUILD SUCCEEDED ✅, +[FlameTKProvider load] ✅
- TB: pod install ✅ (4 pods, 无 AnyThink), 真机 BUILD SUCCEEDED ✅, +[FlameTBProvider load] ✅
- Core binary: 176K, install_name 正确, nm 零三方符号, otool 仅 OpenSSL+系统库
- 正式 podspec: 无 research/ 无 core_named/core/tk/tb ✅

测试方法（不变，与 Step 4 相同）：
- TK: Demo Podfile 写 pod 'flame_sdk_ios', :path => '../flame_ios_sdk'
- TB: Demo Podfile 写 pod 'flame_sdk_ios_tb', :path => '../flame_ios_sdk'
- 前置：build/flame_sdk_ios_core.xcframework 存在（缺失则 ./xcFramework_build.sh core-named）

红线遵守：
- 不发布/tag/push origin/进 Phase 6 ✅
- backup/phase-5a-dual-binary-stable 保留 ✅
- 不改 SDK 对外 API ✅

下一步可选（待用户决策）：
1. 合并 research/thin-core-binary → feat/tb_adapter
2. Phase 6：实现 TB Splash/Interstitial/Banner/Native
3. 发布准备：确认 s.source zip 包含 build/flame_sdk_ios_core.xcframework

注意：build/ 在 gitignore，换机器/CI 需先跑 ./xcFramework_build.sh core-named 生成。
```

---

## 七、结论

构建目录精简完成。正式 core binary 现位于 `build/flame_sdk_ios_core.xcframework`（build/ 顶层），不再有实验性 `core_named/` 子目录。framework/binary/module/install name 全部保持 `flame_sdk_ios_core` 不变。TK/TB 单 pod 接入验证全部通过。

仍停在本地验证阶段，未发布 / 未 tag / 未 push origin / 未进 Phase 6。
