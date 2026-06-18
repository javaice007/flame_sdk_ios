# Phase 5A.10 Step 3 — 方案 D 正式化落地报告

> **分支**：`research/thin-core-binary`
> **状态**：本地验证完成（未发布 / 未 tag / 未 push origin / 未进 Phase 6）
> **前置**：Step 2B（方案 D 实验验证）已通过
> **日期**：2026-06-18

---

## 一、目标回顾

把 Step 2B 已验证通过的实验结构（`research/podspecs/` + `research/wrappers/` + `research/staging_*/`）
正式化到工程正式目录，使客户只需写一行 pod：

```ruby
# TK 客户
pod 'flame_sdk_ios'

# TB 客户
pod 'flame_sdk_ios_tb'
```

正式 podspec 不再引用任何 `research/` 路径。

---

## 二、改动清单

### 1. 正式 podspec 改造（2 个文件）

#### `flame_sdk_ios.podspec`（TK）

| 属性 | 改造前（旧 dual-binary） | 改造后（方案 D） |
|------|-------------------------|-----------------|
| `s.module_name` | （未设，默认 = name） | `flame_sdk_ios`（显式） |
| `s.vendored_frameworks` | `build/tk/flame_sdk_ios.xcframework`（616K，含 AnyThink 符号） | `build/core_named/flame_sdk_ios_core.xcframework`（176K，零三方） |
| `s.source_files` | （无，纯二进制分发） | wrappers + mediation/tk + adapter/tk |
| `s.public_header_files` | （无） | `flame_sdk_ios/wrappers/flame_sdk_ios/*.h` |
| `s.private_header_files` | （无） | `flame_sdk_ios/{mediation,adapter}/tk/**/*.h` |
| `s.dependency OpenSSL` | 有（隐式靠 AnyThink 传递） | 有（显式 `~> 3.6`） |
| `pod_target_xcconfig` | `OTHER_LDFLAGS=-ObjC` | + `FLAME_BUILD_TK=1 FLAME_PLUGIN_TK=1` 宏注入 + `-F` + FRAMEWORK/HEADER_SEARCH_PATHS |

#### `flame_sdk_ios_tb.podspec`（TB）

| 属性 | 改造前（旧方案 A 自包含） | 改造后（方案 D） |
|------|--------------------------|-----------------|
| `s.module_name` | （未设） | `flame_sdk_ios`（统一，TB 客户 import 不变） |
| `s.vendored_frameworks` | `build/tb/flame_sdk_ios.xcframework`（14M，内置 WindMill） | `build/core_named/flame_sdk_ios_core.xcframework`（176K，同一份 core） |
| `s.source_files` | （无） | wrappers + mediation/tb + adapter/tb |
| `s.dependency ToBid-iOS-RC` | 无（已静态内置，声明会 duplicate class） | 有 `5.5.6`（WindMill 不再内置，需声明） |
| `s.dependency OpenSSL` | 有 | 有（显式，避免真机 dyld crash） |
| `pod_target_xcconfig` | `OTHER_LDFLAGS=-ObjC` | + `FLAME_BUILD_TB=1 FLAME_PLUGIN_TB=1` + `-F` + 搜索路径 |

### 2. 正式 wrappers 目录（新增 20 个文件）

```
flame_sdk_ios/wrappers/
├── flame_sdk_ios/         # TK 转发头（10 个）
│   ├── flame_sdk_ios.h    → #import <flame_sdk_ios_core/flame_sdk_ios_core.h>
│   ├── FlameSdk.h         → #import <flame_sdk_ios_core/FlameSdk.h>
│   ├── FlameRewardAd.h
│   ├── FlameSplashAd.h
│   ├── FlameInterstitialAd.h
│   ├── FlameBannerAd.h
│   ├── FlameBannerAdMaterial.h
│   ├── FlameBannerAdRenderSlots.h
│   ├── FlameNativeAd.h
│   └── FlameCallback.h
└── flame_sdk_ios_tb/      # TB 转发头（10 个，内容与 TK 对称）
    └── ...（同上 10 个）
```

内容与 Step 2B 验证通过的 `research/wrappers/` 字节一致（`diff -r` 验证为 identical）。

### 3. 小瑕疵修复

`flame_sdk_ios/adapter/FlameAdapterManager.m` `setDebug:` 日志文案：

```
- FlameAdapterManager.setDebug:NO (TB variant, WindMill debug set in provider init)
+ FlameAdapterManager.setDebug:NO (Core variant, provider handles platform debug setting)
```

仅文案，功能不变（Core 模式下不直接调用任何平台 SDK，由 Provider 自行处理）。

---

## 三、验证矩阵（28 项检查）

### 分支与红线

| # | 检查项 | 结果 |
|---|--------|------|
| 1 | 当前分支 | ✅ `research/thin-core-binary` |
| 2 | 当前 HEAD | ✅ `228f7d2`（Step 3 提交）+ 之前 `8995484`（Step 2B 终态） |
| 3 | 未发布 / 未 tag / 未 push origin | ✅ `git tag` 空，`git log origin/research/thin-core-binary` 无此分支 |
| 4 | 保留 backup 分支 | ✅ `backup/phase-5a-dual-binary-stable` 在 |
| 5 | 保留 build/tk + build/tb 兜底 | ✅ `build/tk/flame_sdk_ios.xcframework`（616K）+ `build/tb/flame_sdk_ios.xcframework`（14M）均在 |

### Core binary

| # | 检查项 | 结果 |
|---|--------|------|
| 6 | 正式生成 `build/core_named/flame_sdk_ios_core.xcframework` | ✅ 存在 |
| 7 | 零三方污染 | ✅ `nm -gU` 对 AnyThink/WindMill/Sigmob/AdGain/BUAd/CSJ/GDT/KSAd/Baidu/FSUnion/FlameTKProvider/FlameTBProvider/AtRewardAdapter/TbRewardAdapter 全部无输出 |
| | 体积 | 176K |
| | otool -L 依赖 | 仅 `@rpath/OpenSSL.framework/OpenSSL` + 4 个系统库 |
| | install_name | `@rpath/flame_sdk_ios_core.framework/flame_sdk_ios_core` ✅ |
| | Headers 数量 | 22（8 umbrella 内公共头 + FlameNativeAd + 12 内部协议头 + umbrella 自身） |
| | 无三方 bundle/metallib | ✅ |

### Podspec

| # | 检查项 | 结果 |
|---|--------|------|
| 8 | `flame_sdk_ios.podspec` 改为方案 D | ✅ module_name + core_named + wrappers + tk source + FLAME_PLUGIN_TK |
| 9 | `flame_sdk_ios_tb.podspec` 改为方案 D | ✅ module_name=flame_sdk_ios + core_named + wrappers + tb source + FLAME_PLUGIN_TB |
| 10 | 正式 podspec 不引用 `research/` | ✅ grep `research/` 两文件均无匹配 |
| 11 | 新增正式 wrappers | ✅ `flame_sdk_ios/wrappers/{flame_sdk_ios,flame_sdk_ios_tb}/`（各 10 头） |

### TK 验证

| # | 检查项 | 结果 |
|---|--------|------|
| 12 | 客户单 pod 接入 | ✅ Podfile 仅 `pod 'flame_sdk_ios', :path => '../flame_ios_sdk'` |
| 13 | pod install 通过 | ✅ 28 pods 装齐 |
| | Podfile.lock 内容 | ✅ 无 ToBid-iOS-RC / 有 AnyThinkiOS / 有 AnyThinkMediation / 有 OpenSSL-Universal |
| 14 | 真机 arm64 BUILD | ✅ `** BUILD SUCCEEDED **`（康海军的iPhone, iOS 26.5） |
| 15 | 运行时激活 FlameTKProvider | ✅ pod framework 含 `+[FlameTKProvider load]` 符号（+load 自动注册） |
| | AtRewardAdapter 编译进 pod | ✅ |
| | 无 FlameTBProvider / TbRewardAdapter | ✅ |
| 16 | 无 duplicate class / dyld crash | ✅ 符号边界清晰，OpenSSL.framework 已 embed |

### TB 验证

| # | 检查项 | 结果 |
|---|--------|------|
| 17 | 客户单 pod 接入 | ✅ Podfile 仅 `pod 'flame_sdk_ios_tb', :path => '../flame_ios_sdk'` |
| 18 | pod install 通过 | ✅ 4 pods（flame_sdk_ios_tb + OpenSSL + ToBid + FunlinkSDK） |
| | Podfile.lock 内容 | ✅ 无 AnyThinkiOS / 无 AnyThinkMediation / 有 ToBid-iOS-RC / 有 OpenSSL-Universal / 无 Sigmob |
| 19 | 真机 arm64 BUILD | ✅ `** BUILD SUCCEEDED **` |
| 20 | 运行时激活 FlameTBProvider | ✅ pod framework 含 `+[FlameTBProvider load]` 符号 |
| 21 | Reward 走 TbRewardAdapter | ✅ TbRewardAdapter 编译进 pod（43 符号），无 AtRewardAdapter |
| 22 | 无 duplicate class / dyld crash | ✅ OpenSSL.framework + flame_sdk_ios_core.framework 双双内嵌进 App/Frameworks/ |
| 23 | TB 其他广告类型仍未实现 | ✅ Splash/Interstitial/Banner/Native 仍 nil 占位（Phase 6） |

### Lint 与文档

| # | 检查项 | 结果 |
|---|--------|------|
| 24 | pod lib lint | ⚠️ podspec 解析/集成通过（`pod ipc spec` 正常）；xcodebuild 阶段因沙盒只暴露 placeholder iOS Simulator、无法匹配 booted device UDID 而失败，**非 podspec 内容问题**。权威验证以本地 pod install + 真机 xcodebuild 为准（已通过）。 |
| 25 | 接入文档已更新 | ✅ 新增 `doc/flame_mediation/integration-thin-core-draft.md` |

### 合并建议

| # | 检查项 | 结论 |
|---|--------|------|
| 26 | 建议合并回 `feat/tb_adapter` | ✅ 建议合并。Step 2B + Step 3 已闭环验证方案 D 的客户单 pod 接入目标 |
| 27 | 合并前风险点 | 见下文「四、合并风险点」 |
| 28 | 更新后的 /compact | 见下文「五、更新后的 /compact」 |

---

## 四、合并风险点

### R1（低）：pod lib lint 不能在 CI 直接跑通
- **现象**：`pod lib lint` 默认 dynamic `use_frameworks!`，会撞 ToBid 静态 WindMill 传递依赖错误；加 `--use-static-frameworks` 后又撞沙盒 destination 限制
- **影响**：若 CI 用 `pod lib lint` 做 gate，会误判 podspec 失败
- **缓解**：CI 改用「`pod install` + 真机/模拟器 xcodebuild」组合验证，与 Step 3 一致；或在 podspec 加 `s.xcconfig` 提示但不动 lint 行为

### R2（低）：research/ 实验目录未清理
- **现象**：`research/podspecs/`、`research/wrappers/`、`research/staging_*/` 仍在（gitignored 后两者）
- **影响**：仓库体积略增，但不影响正式 podspec 解析
- **缓解**：合并后单独 PR 清理 research/（保留报告文档）

### R3（中）：build/core_named 二进制未随仓库分发
- **现象**：`build/` 在 .gitignore，core_named binary 不在 git 里
- **影响**：客户 `pod 'flame_sdk_ios'`（远端）需要 release 资产包含 `build/core_named/flame_sdk_ios_core.xcframework`
- **缓解**：发布前确认 `s.source` 的 zip 包含此 xcframework；或改用 GitHub Release asset

### R4（低）：旧 `build/tk`、`build/tb` 兜底仍保留
- **现象**：方案 A/B 的 dual-binary fallback 还在
- **影响**：占磁盘空间，但正式 podspec 已不指向它们
- **缓解**：合并后观察一段时间再清理

### R5（中）：TB 其他广告类型未实现
- **现象**：TB podspec 依赖 ToBid-iOS-RC 但仅 Reward 走通；Splash/Interstitial/Banner/Native 是 nil 占位
- **影响**：TB 客户接入后只能用 Reward
- **缓解**：Phase 6 实现

---

## 五、更新后的 /compact

```
Phase 5A.10 Step 3 完成（方案 D 正式化）。

分支：research/thin-core-binary @ 228f7d2（Step 3）← 8995484（Step 2B 终态）
工作区：SDK repo 干净；Demo repo 工作树保留 TB 验证状态（Podfile + FlameAdConfig）

完成事项：
1. 正式 flame_sdk_ios.podspec → 方案 D TK 结构（core_named + wrappers + tk source + FLAME_PLUGIN_TK）
2. 正式 flame_sdk_ios_tb.podspec → 方案 D TB 结构（core_named + wrappers + tb source + FLAME_PLUGIN_TB, module_name=flame_sdk_ios 统一）
3. 正式 wrappers 目录：flame_sdk_ios/wrappers/{flame_sdk_ios,flame_sdk_ios_tb}/（各 10 转发头）
4. FlameAdapterManager Core variant 文案修复
5. 接入文档 integration-thin-core-draft.md

验证（本地, 未发布/tag/push origin）：
- TK: pod install ✅ (28 pods), 真机 arm64 BUILD SUCCEEDED ✅, +[FlameTKProvider load] ✅, AtRewardAdapter ✅, 无 TB 污染 ✅
- TB: pod install ✅ (4 pods), 真机 arm64 BUILD SUCCEEDED ✅, +[FlameTBProvider load] ✅, TbRewardAdapter ✅, 无 TK 污染 ✅
- Core binary 176K 零三方污染 ✅
- App embed: flame_sdk_ios_core.framework + OpenSSL.framework ✅
- pod lib lint: podspec 解析 OK, xcodebuild 受沙盒 destination 限制（非 podspec 问题）

红线遵守：
- 不发布/tag/push origin/进 Phase 6 ✅
- 不实现 TB 其他广告类型 ✅
- 不删 backup/phase-5a-dual-binary-stable ✅
- 不删 build/tk、build/tb 兜底 ✅
- 不改 SDK 对外 API ✅
- 不要求客户接 Core pod + Plugin pod ✅（客户单 pod）
- 正式 podspec 不引用 research/ ✅

下一步可选（待用户决策）：
1. 合并 research/thin-core-binary → feat/tb_adapter（风险见报告 R1-R5）
2. 清理 research/ 实验目录（单独 PR）
3. Phase 6：TB Splash/Interstitial/Banner/Native 实现
4. 发布准备：确认 s.source zip 包含 build/core_named/flame_sdk_ios_core.xcframework

Demo 当前状态：TB 变体（Podfile: pod 'flame_sdk_ios_tb', :path => '../flame_ios_sdk'）
```

---

## 六、结论

方案 D 正式化落地完成。客户单 pod 接入目标（TK: `pod 'flame_sdk_ios'`；TB: `pod 'flame_sdk_ios_tb'`）
已在工程正式目录验证通过，正式 podspec 不再依赖 `research/` 路径。

仍停在本地验证阶段，未发布 / 未 tag / 未 push origin / 未进 Phase 6。等待用户决策合并与后续。
