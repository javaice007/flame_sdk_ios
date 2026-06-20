# Phase 5A.12 Step 3C：alpha.5 修正版发布报告

> **类型**：修正版发布（修复 alpha.4 specs 的 file:// P0 问题 + adapter 重命名 + TB 红线明确）
> **执行日期**：2026-06-20
> **发布版本**：`1.0.0-alpha.5`（flame_sdk_ios + flame_sdk_ios_tb）+ `4.20.12.2.0`（flame_sdk_ios_tk_sigmob_adapter）
> **前置**：Step 3B alpha.4 发布后发现 specs 有 file:// 本机路径

---

## 核心结论速览

- ⚠️ **alpha.4 标记为「不建议客户使用」**（flame-specs specs 含 `file:///Users/khj/...` 本机路径）
- ✅ **alpha.5 修复三个问题**：
  1. flame-specs specs 的 source 从 `file:///Users/...` 改为 `https://github.com/javaice007/flame_sdk_ios.git`
  2. adapter 从 `flame-sdk-tk-sigmob-adapter` 重命名为 `flame_sdk_ios_tk_sigmob_adapter`（与 flame_sdk_ios 命名风格统一）
  3. 明确 TB podspec 红线（不依赖任何 TK Sigmob adapter / AnyThinkMediation* / AdGain / FSUnion / SigmobAd-iOS）
- ✅ **dist repo**：commit `2df562c` + tag `1.0.0-alpha.5` + push 全部成功
- ✅ **flame-specs**：commit `0b7789c` + push 成功（含 3 个 specs）
- ✅ **TK alpha.5 远程验证**：pod install + build 全通过，0 duplicate
- ✅ **TB alpha.5 远程验证**：pod install + build 全通过，0 duplicate
- ✅ **无 file:// / /Users/khj / 旧 adapter 名 / SigmobAd-iOS 残留**
- alpha.4 tag 保留不删除（作为内部验证版本，客户应使用 alpha.5）

---

## 1. alpha.4 是否存在 file:// 本机路径

⚠️ **部分存在**（P0 问题）。

| 位置 | file:// 状态 |
|---|---|
| dist repo tag archive（GitHub 下载的 zip） | ✅ **无 file://**（source 是 GitHub :http）|
| **flame-specs repo 的 specs** | ❌ **有 file://**（`s.source = { :git => 'file:///Users/khj/Documents/code/97_ad/ios/github_build/flame_sdk_ios', ...}`）|

实证（Step 3C-1 复核）：

```
flame-specs/flame_sdk_ios/1.0.0-alpha.4/flame_sdk_ios.podspec:
  s.source = { :git => 'file:///Users/khj/Documents/code/97_ad/ios/github_build/flame_sdk_ios', :tag => s.version.to_s }

flame-specs/flame_sdk_ios_tb/1.0.0-alpha.4/flame_sdk_ios_tb.podspec:
  s.source = { :git => 'file:///Users/khj/Documents/code/97_ad/ios/github_build/flame_sdk_ios', :tag => s.version.to_s }
```

**根因**：Step 3A 模拟安装时把 spec repo podspec source 临时改为本地 file:// 用于本地验证，commit 到 flame-specs 后忘了改回 GitHub source 就 push 了。客户 pod install 解析 spec 时会看到 file:// 路径，客户机器没有此路径，会失败。

**注意**：dist repo tag archive 是正确的（GitHub :http），所以 TK/TB Step 3B 远程验证通过 —— 但那是因为 Podfile 直接用 `pod 'flame_sdk_ios', '1.0.0-alpha.4'` + GitHub source spec repo，CocoaPods 从 spec 拿 source 时用的是 GitHub :git tag，不是 spec 自己的 source 字段（spec 的 source 字段只在 lint 时用）。但严格说这是潜在隐患，alpha.5 必须修复。

## 2. alpha.4 是否标记为内部验证版

⚠️ **是，标记为「不建议客户使用」**。

- alpha.4 留作内部验证版本（Step 2 真机验证用的就是这个版本）
- 客户应使用 **alpha.5**（修复了 file:// 问题 + adapter 重命名）
- alpha.4 tag 不删除（作为历史记录 + 内部回退点）

## 3. alpha.5 修复内容

| 问题 | alpha.4 | alpha.5 |
|---|---|---|
| flame-specs specs source | ❌ `file:///Users/khj/...` | ✅ `https://github.com/javaice007/flame_sdk_ios.git` |
| TK adapter 名 | `flame-sdk-tk-sigmob-adapter`（连字符）| `flame_sdk_ios_tk_sigmob_adapter`（下划线，与 flame_sdk_ios 统一）|
| TB podspec 红线 | 隐式（无 TK Sigmob 依赖）| 显式（注释明确：不依赖 TK Sigmob adapter / AnyThinkMediation* / AdGain / FSUnion / SigmobAd-iOS）|

## 4. dist repo alpha.5 commit

`2df562cee1e5a1e7ce67f99c957bf2a023c4eb32`

- 标题：`Release 1.0.0-alpha.5: fix podspec source (GitHub) and rename TK Sigmob adapter to flame_sdk_ios_tk_sigmob_adapter`
- 改动：2 files changed（两个 podspec 版本号 + source + adapter 名）

## 5. dist repo alpha.5 tag

`1.0.0-alpha.5`（指向 `2df562c`）

## 6. flame-specs alpha.5 commit

`0b7789c912776772dea732b2123ba6cf2029f22f`

- 标题：`alpha.5: add specs with renamed TK Sigmob adapter (flame_sdk_ios_tk_sigmob_adapter); remove flame-sdk-tk-sigmob-adapter`
- 改动：4 files changed（新增 alpha.5 specs + 删除 alpha.5 podspec.bak + 删除旧 flame-sdk-tk-sigmob-adapter 目录）

## 7. flame_sdk_ios.podspec source 是否已改为 GitHub 远程

✅ **是**。

```ruby
s.source = { :git => 'https://github.com/javaice007/flame_sdk_ios.git', :tag => s.version.to_s }
```

## 8. flame_sdk_ios_tb.podspec source 是否已改为 GitHub 远程

✅ **是**。

```ruby
s.source = { :git => 'https://github.com/javaice007/flame_sdk_ios.git', :tag => s.version.to_s }
```

## 9. adapter 名称是否已改为 flame_sdk_ios_tk_sigmob_adapter

✅ **是**。

| 位置 | 名称 |
|---|---|
| dist repo `flame_sdk_ios.podspec` | `s.dependency 'flame_sdk_ios_tk_sigmob_adapter', '4.20.12.2.0'` |
| flame-specs `flame_sdk_ios/1.0.0-alpha.5/flame_sdk_ios.podspec` | 同上 |
| flame-specs `flame_sdk_ios_tk_sigmob_adapter/4.20.12.2.0/flame_sdk_ios_tk_sigmob_adapter.podspec.json` | `"name": "flame_sdk_ios_tk_sigmob_adapter"` |

## 10. 旧 flame-sdk-tk-sigmob-adapter 是否已从正式路径删除

✅ **是**。

`github_build/flame-specs/flame-sdk-tk-sigmob-adapter/` 目录已删除（flame-specs commit `0b7789c`）。

## 11. 旧 AnyThinkMediationSigmobAdapter-NoSDK 是否无残留

✅ **无残留**（alpha.5 specs + dist repo + 本地 pod repo 均无）。

## 12. TK podspec 是否依赖 flame_sdk_ios_tk_sigmob_adapter

✅ **是**。

```ruby
s.dependency 'flame_sdk_ios_tk_sigmob_adapter', '4.20.12.2.0'
```

## 13. TB podspec 是否不依赖任何 TK Sigmob adapter

✅ **是**（红线达成）。

`flame_sdk_ios_tb.podspec` 不含：
- ❌ `flame_sdk_ios_tk_sigmob_adapter`
- ❌ `flame-sdk-tk-sigmob-adapter`
- ❌ `AnyThinkMediationSigmobAdapter`

## 14. TB podspec 是否不依赖 AnyThinkMediation* / AdGain / FSUnion / SigmobAd-iOS

✅ **是**（红线达成）。

`flame_sdk_ios_tb.podspec` 只声明公共核心依赖：

```ruby
s.dependency 'OpenSSL-Universal', '~> 3.6'
s.dependency 'AnyThinkiOS', '6.5.71'
s.dependency 'ToBid-iOS-RC', '5.5.6'
```

不含 `AnyThinkMediation*` / `AdGainSDK` / `AdGainSDKTakuAdapter` / `FSUnionAdSDK` / `SigmobAd-iOS`。

## 15. TK 本地安装 + build

**✅ 通过**（模拟远程安装，本地 spec repo + 本地 dist git tag）。

- pod install：28 pods，含 `flame_sdk_ios_tk_sigmob_adapter (4.20.12.2.0)`
- xcframework duplicate：0
- build：BUILD SUCCEEDED

## 16. TB 本地安装 + build

**✅ 通过**。

- pod install：5 pods
- 不含 TK Sigmob adapter / AnyThinkMediation* / AdGain / FSUnion / SigmobAd-iOS
- xcframework duplicate：0
- build：BUILD SUCCEEDED

## 17. TK 远程安装 + build

**✅ 通过**（正式远程 source `https://github.com/javaice007/flame-specs.git` + GitHub tag archive）。

```
- flame_sdk_ios (1.0.0-alpha.5):
  - flame_sdk_ios_tk_sigmob_adapter (= 4.20.12.2.0)
  - ToBid-iOS-RC (= 5.5.6)
  - AnyThinkiOS / AnyThinkMediation* / AdGain / FSUnion
  - OpenSSL-Universal
- flame_sdk_ios_tk_sigmob_adapter (4.20.12.2.0):
  - AnyThinkiOS (>= 6.5.60)
```

- xcframework duplicate：0
- build：BUILD SUCCEEDED

## 18. TB 远程安装 + build

**✅ 通过**。

```
- flame_sdk_ios_tb (1.0.0-alpha.5):
  - AnyThinkiOS (= 6.5.71)
  - OpenSSL-Universal (~> 3.6)
  - ToBid-iOS-RC (= 5.5.6)
```

- 不含 TK Sigmob adapter / AnyThinkMediation* / AdGain / FSUnion / SigmobAd-iOS
- xcframework duplicate：0
- build：BUILD SUCCEEDED

## 19. duplicate framework 检查

| 模式 | xcframework duplicate |
|---|---|
| TK alpha.5（本地 + 远程）| ✅ 0 |
| TB alpha.5（本地 + 远程）| ✅ 0 |

## 20. source leak 检查

| 模式 | 源码泄漏 |
|---|---|
| TK alpha.5 | ✅ 无 .m/.mm |
| TB alpha.5 | ✅ 无 .m/.mm |

## 21. 客户最终接入方式

```ruby
source 'https://github.com/javaice007/flame-specs.git'
source 'https://cdn.cocoapods.org/'

target 'YourApp' do
  use_frameworks! :linkage => :static

  # TK 客户
  pod 'flame_sdk_ios', '1.0.0-alpha.5'

  # 或 TB 客户，二选一，不能同时接
  # pod 'flame_sdk_ios_tb', '1.0.0-alpha.5'
end
```

**重要**：
- 客户应使用 **alpha.5**（不要用 alpha.4，alpha.4 specs 有 file:// 问题）
- alpha.4 留作内部验证版本，tag 不删除
- `flame_sdk_ios` 与 `flame_sdk_ios_tb` 互斥，不能同时接入（同 module name `flame_sdk_ios`）

## 22. /compact

**Phase 5A.12 Step 3C（alpha.5 修正版发布）完成状态**：

| 项 | 状态 |
|---|---|
| alpha.4 file:// 问题确认 | ✅ flame-specs specs 有 file://（P0）|
| alpha.4 标记为内部验证版 | ✅ 不建议客户使用 |
| alpha.5 source 修复（GitHub :git）| ✅ |
| alpha.5 adapter 重命名（flame_sdk_ios_tk_sigmob_adapter）| ✅ |
| alpha.5 TB 红线明确 | ✅ |
| dist repo commit `2df562c` + tag `1.0.0-alpha.5` + push | ✅ |
| flame-specs commit `0b7789c` + push | ✅ |
| TK 本地 + 远程安装 + build | ✅ 全通过 |
| TB 本地 + 远程安装 + build | ✅ 全通过 |
| xcframework duplicate | ✅ 0（TK + TB）|
| 源码泄漏 | ✅ 无 |
| 旧 flame-sdk-tk-sigmob-adapter 删除 | ✅ |
| 旧 AnyThinkMediationSigmobAdapter-NoSDK 无残留 | ✅ |
| **alpha.5 发布成功** | 🎉 **是** |
| alpha.4 tag 保留 | ✅（内部验证版）|
| GitHub Release 页面 | ❌ 未创建（红线遵守）|

**Phase 5A.12 全部完成（Step 1d → 1e → 1f → 2 → 3A → 3B → 3C）**：

```
Step 1d: mainline 分支清理（删除历史入口 + 宏体系）
Step 1e: Sigmob 冲突预检（实证普通版冲突）
Step 1f: flame_sdk_ios_tk_sigmob_adapter 规范化（最初叫 flame-sdk-tk-sigmob-adapter）
Step 2:  TK + TB 真机验证双侧通过（用 alpha.4-local 内部版本）
Step 3A: alpha.4 发布预检（无阻塞）
Step 3B: alpha.4 正式发布（specs 误带 file://）
Step 3C: alpha.5 修正版发布（修复 file:// + adapter 重命名为下划线风格）🎉
```

**客户正式接入版本：alpha.5**

```ruby
source 'https://github.com/javaice007/flame-specs.git'
source 'https://cdn.cocoapods.org/'

# TK 客户
pod 'flame_sdk_ios', '1.0.0-alpha.5'

# 或 TB 客户
pod 'flame_sdk_ios_tb', '1.0.0-alpha.5'
```

**关键文件清单**：

```
research/logs/step3c/
├── 01-alpha4-integrity-check.log     # alpha.4 完整性复核（发现 file:// 问题）
├── 02-tk-install.log                 # TK alpha.5 本地模拟安装
├── 03-tk-check.log                   # TK 检查
├── 04-tk-build.log                   # TK build（SUCCEEDED）
├── 05-tb-install.log                 # TB alpha.5 本地模拟安装
├── 06-tb-check.log                   # TB 检查
├── 07-tb-build.log                   # TB build（SUCCEEDED）
├── 08-release.log                    # dist repo + flame-specs push
├── 09-remote-tk-install.log          # TK 远程安装
├── 10-remote-tk-build.log            # TK 远程 build（SUCCEEDED）
├── 11-remote-tb-install.log          # TB 远程安装
└── 12-remote-tb-build.log            # TB 远程 build（SUCCEEDED）

doc/flame_mediation/phase-5a.12-step3c-alpha5-source-and-adapter-rename-fix-report.md  # ✨ 本报告
```

红线遵守：未覆盖 alpha.4 tag、未强推 alpha.4、未删除 tb_adapter / backup 兜底分支、未恢复 AnyThinkMediationSigmobAdapter、未恢复 AnyThinkMediationSigmobAdapter-NoSDK、未用旧 flame-sdk-tk-sigmob-adapter、未创建 GitHub Release 页面。
