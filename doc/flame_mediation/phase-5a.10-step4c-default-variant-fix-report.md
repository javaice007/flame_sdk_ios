# Phase 5A.10 Step 4C — 脚本默认变体修复报告

> **分支**：`research/thin-core-binary`
> **状态**：本地验证完成（未发布 / 未 tag / 未 push origin / 未进 Phase 6）
> **前置**：Step 4B（构建目录精简）已通过
> **日期**：2026-06-18

---

## 一、问题

Step 4B 完成后，正式 core binary 路径已是 `build/flame_sdk_ios_core.xcframework`。

但 `xcFramework_build.sh` 无参数执行时仍然默认走 **tk 变体**：

```bash
VARIANT="${1:-tk}"   # ← 旧默认
```

导致：

```text
🔍 符号校验（tk 变体）...
二进制体积: 276K     ← 含 AnyThink 符号，不是 thin core
build/tk/flame_sdk_ios.xcframework  ← 旧 dual-binary 产物
```

用户测试时无法判断当前用的是方案 D 还是旧双二进制兜底。

---

## 二、10 项检查清单

| # | 检查项 | 结果 |
|---|--------|------|
| 1 | 确认脚本之前默认走 tk | ✅ 旧代码 `VARIANT="${1:-tk}"`（line 31），符号校验日志显示「tk 变体」、二进制 276K |
| 2 | 已修复无参数默认行为 | ✅ 新代码 `VARIANT="${1:-core-named}"` |
| 3 | 无参数执行 `./xcFramework_build.sh` 构建 core-named | ✅ 日志显示「符号校验（core-named 变体）」、二进制 176K |
| 4 | 仍支持手动 `./xcFramework_build.sh tk / tb` 作为 legacy fallback | ✅ tk/tb/core 仍在 if/elif 链（line 47/50/58），显式传参可构建旧 dual-binary |
| 5 | `build/` 下最终只剩 `flame_sdk_ios_core.xcframework` | ✅ 无参数构建后 `find build -maxdepth 3` 仅 flame_sdk_ios_core.xcframework（无 tk/tb/core/core_named） |
| 6 | 日志显示 core-named 而不是 tk | ✅ `🔍 符号校验（core-named 变体）... 二进制体积: 176K` |
| 7 | core binary 体积 | 176K |
| 8 | core binary 零三方污染 | ✅ nm 对 14 类三方符号全部无输出；otool 仅 OpenSSL + 4 系统库 |
| 9 | podspec 只指向 `build/flame_sdk_ios_core.xcframework` | ✅ 两 podspec 均为此路径，无 research/core_named/tk/tb |
| 10 | 当前 commit hash | ✅ `c85021a` |

---

## 三、改动明细

### 3.1 `xcFramework_build.sh`

| 改动点 | 改造前 | 改造后 |
|--------|--------|--------|
| 默认变体 | `VARIANT="${1:-tk}"` | `VARIANT="${1:-core-named}"` |
| 未知变体错误信息 | 单行 ❌ 提示 | 多行 usage help（区分正式 core-named 与 legacy fallback） |
| 头部注释用法 | `# 默认 = tk` | `# 默认 = core-named（正式方案 D）`；tk/tb/core 标注为 legacy fallback |

### 3.2 符号校验分支逻辑（**未改**，已正确）

```bash
if [ "$VARIANT" = "tk" ]; then        # TK 污染检测
elif [ "$VARIANT" = "tb" ]; then      # TB 污染检测
else                                  # CORE 检测（含 core-named，最严格：14 类三方符号）
fi
```

旧默认 `tk` 命中 TK 分支（故日志显示 tk）；新默认 `core-named` 命中 else/CORE 分支（日志显示 core-named）。

### 3.3 legacy fallback 路径（**未改**，仍可用）

| 变体 | 输出路径 | 用途 |
|------|----------|------|
| `core-named`（默认） | `build/flame_sdk_ios_core.xcframework` | 正式方案 D |
| `tk` | `build/tk/flame_sdk_ios.xcframework` | legacy 兜底（backup 分支） |
| `tb` | `build/tb/flame_sdk_ios.xcframework` | legacy 兜底（backup 分支） |
| `core` | `build/core/flame_sdk_ios.xcframework` | legacy（未改名，仅历史对比） |

---

## 四、验证证据

### 4.1 无参数构建日志（关键片段）

```text
🛠️ 合并 XCFramework...
xcframework successfully written out to: .../build/flame_sdk_ios.xcframework
🏷️  core-named 改名：flame_sdk_ios → flame_sdk_ios_core
✅ core-named 改名完成
📋 core-named 补暴露 12 个内部头到 Headers/...
✅ 内部头补暴露完成
🧹 清理 core-named 中间 xcarchive...
🧹 剥离 bitcode...
✅ bitcode 剥离完成

🔍 符号校验（core-named 变体）...      ← ✅ 不再是 tk 变体
   二进制体积: 176K                    ← ✅ 不再是 276K
```

### 4.2 build/ 最终结构

```text
build
build/flame_sdk_ios_core.xcframework
build/flame_sdk_ios_core.xcframework/ios-arm64
build/flame_sdk_ios_core.xcframework/ios-arm64/flame_sdk_ios_core.framework
build/flame_sdk_ios_core.xcframework/ios-x86_64-simulator
build/flame_sdk_ios_core.xcframework/ios-x86_64-simulator/flame_sdk_ios_core.framework
```

无 `build/tk`、`build/tb`、`build/core`、`build/core_named`、`*.xcarchive`、`Archives/`。

### 4.3 Core binary 完整性

| 检查项 | 值 |
|--------|-----|
| 体积 | 176K |
| install_name | `@rpath/flame_sdk_ios_core.framework/flame_sdk_ios_core` ✅ |
| otool -L | 仅 OpenSSL + Foundation/libobjc/libSystem/CoreFoundation |
| nm 三方符号 | 零 |
| Headers | 22 |

---

## 五、结论

脚本默认变体修复完成。无参数执行 `./xcFramework_build.sh` 现在正确构建方案 D 的 thin core binary（`build/flame_sdk_ios_core.xcframework`，176K，零三方污染），不再误走旧 tk 变体。日志明确显示 `core-named 变体`。legacy fallback（tk/tb/core）仍可通过显式传参使用。

仍停在本地验证阶段，未发布 / 未 tag / 未 push origin / 未进 Phase 6。
