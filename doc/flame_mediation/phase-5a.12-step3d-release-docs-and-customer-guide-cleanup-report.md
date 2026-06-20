# Phase 5A.12 Step 3D：发布文档与客户可见说明清理报告

> **类型**：文档清理（不重新发版、不打 tag）
> **执行日期**：2026-06-20
> **目标**：确保 alpha.5 作为客户接入版本，客户可见文件不暴露内部实现原理

---

## 核心结论速览

- ✅ **发布操作说明.md** 已从「方案 D · Thin Core」改为「single-binary mainline」（333 行）
- ✅ **README.md / CHANGELOG.md / LICENSE** 已创建（客户可见，简洁接入说明）
- ✅ **podspec 注释** 已简化（去掉 Phase 5A.12 / +load / Router / lazy binding 等内部原理）
- ✅ **use_frameworks 强制要求** 已去除
- ✅ **客户可见文件无 file:// / /Users/khj / 旧架构术语 / 旧 adapter 名**
- ✅ **.DS_Store** 已清除（3 个）
- ✅ **dist repo + flame-specs push 成功**（不重新 tag、不重新发版）

---

## 1. 发布操作说明是否已从 Thin Core 改为 single-binary mainline

✅ **是**。

- 旧标题：`FlameSDK iOS 发布操作说明（方案 D · Thin Core）`
- 新标题：`FlameSDK iOS 发布操作说明（single-binary mainline）`
- 文件：`/Users/khj/Documents/code/97_ad/ios/github_build/发布操作说明.md`（333 行）
- 这是容器目录文档，**不入 git**，仅发布机本地使用

## 2. README 是否已改为 alpha.5 接入方式

✅ **是**。

新建 `/Users/khj/Documents/code/97_ad/ios/github_build/flame_sdk_ios/README.md`（50 行）：

- 接入方式：`pod 'flame_sdk_ios', '1.0.0-alpha.5'` / `pod 'flame_sdk_ios_tb', '1.0.0-alpha.5'`
- 无 use_frameworks 强制要求
- 无内部原理（single-binary / +load / Router 等）

## 3. 是否已去掉 use_frameworks 强制要求

✅ **是**。

- README：`Flame SDK 本身不强制要求 use_frameworks!`
- 发布操作说明 §7：同上
- podspec：无 use_frameworks 相关配置
- 已删除 FAQ 中「pod install 报 transitive dependencies ... 缺少 use_frameworks」的旧说法

## 4. 是否已去掉客户可见内部原理说明

✅ **是**。

README/podspec/CHANGELOG 已去掉：
- single-binary 内部如何同时放 TK/TB 胶水
- +load 自动注册
- Router 按 pt 激活
- lazy binding / U 引用
- WindSDK/WindFoundation 冲突细节
- Sigmob NoSDK 包装层技术原理
- Phase 5A.12 Step 1d/1e/1f/2/3A/3B/3C 全过程

客户可见文档只保留：
- `flame_sdk_ios`：适用于 TK 聚合接入
- `flame_sdk_ios_tb`：适用于 TB 聚合接入
- 两个 pod 互斥，选择其中一个即可
- flame_sdk_ios 会自动带上所需的 TK 广告源适配依赖，客户无需单独声明

## 5. 是否仍有 file:///Users 或 /Users/khj

✅ **客户可见文件无**。

| 文件 | file:// / /Users/khj |
|---|---|
| dist repo README/CHANGELOG/LICENSE/podspec × 2 | ✅ 无 |
| flame-specs alpha.5 specs（3 个）| ✅ 无 |

**注**：发布操作说明.md（容器目录文档，不入 git，仅发布机本地）含 `/Users/khj` 路径（用于发布机操作），已明确标注「仅发布机本地路径，严禁写入正式 podspec source」。

## 6. 是否仍有 Thin Core / 方案 D / flame_sdk_ios_core / source_files / wrappers / 宏旧口径

✅ **客户可见文件无**。

CHANGELOG.md 提及 alpha.1 是「初始 alpha 版本（历史架构，已被后续版本替代）」，不含 Thin Core / 方案 D 等具体术语。

## 7. 是否仍有旧 adapter 名称

✅ **无**。

- `flame-sdk-tk-sigmob-adapter`（旧连字符名）：客户可见文件无
- `AnyThinkMediationSigmobAdapter-NoSDK`（旧自定义名）：客户可见文件无
- `SigmobAd-iOS`：客户可见文件无（podspec 注释已删除「去掉 SigmobAd-iOS 传递依赖」等技术细节）

## 8. 是否删除 .DS_Store

✅ **是**。

清除 3 个：
- `/Users/khj/Documents/code/97_ad/ios/github_build/.DS_Store`
- `/Users/khj/Documents/code/97_ad/ios/github_build/flame-specs/.DS_Store`
- `/Users/khj/Documents/code/97_ad/ios/github_build/flame-specs/flame_sdk_ios/.DS_Store`

同时给 dist repo + flame-specs 的 .gitignore 加入 `.DS_Store` 规则，防止再次提交。

## 9. flame_sdk_ios README commit

✅ dist repo commit `a9f46fe`：
- 新增 README.md / CHANGELOG.md / LICENSE
- 简化 flame_sdk_ios.podspec / flame_sdk_ios_tb.podspec 注释
- 新增 .gitignore（含 .DS_Store）
- push 成功（`2df562c..a9f46fe`）

## 10. flame-specs 清理 commit

✅ flame-specs commit `9ef0588`：
- 删除 .DS_Store × 2
- 简化 alpha.5 podspec 注释（同步 dist repo）
- 新增 .gitignore（含 .DS_Store）
- push 成功（`0b7789c..9ef0588`）

## 11. 是否重新 tag

❌ **未重新 tag**。

- alpha.5 tag `2df562c` 保留（指向 Step 3C 发布的 commit）
- 本次文档修正 commit `a9f46fe` 在 tag 之后，但 **不打新 tag**（文档修正不影响 SDK 二进制和依赖结构）
- 客户通过 alpha.5 tag archive 下载的是 `2df562c` 的 xcframework + 当时版本的 podspec；README/CHANGELOG/LICENSE 是后续 commit 加的，客户 pod install 不依赖这些文件（CocoaPods 只读 podspec）

**注**：如果希望客户也能看到最新 README/CHANGELOG，可以考虑把 alpha.5 tag 移到 `a9f46fe`（`git tag -f 1.0.0-alpha.5 && git push -f origin 1.0.0-alpha.5`），但这会改变 tag 指向，需要谨慎。本次按红线「不重新 tag」处理。

## 12. 是否重新发版

❌ **未重新发版**。

- 不新增 alpha.6
- 不改 alpha.5 specs
- 只更新文档（README/CHANGELOG/LICENSE/podspec 注释）

## 13. 客户最终接入口径

```ruby
source 'https://github.com/javaice007/flame-specs.git'
source 'https://cdn.cocoapods.org/'

target 'YourApp' do
  # TK 客户
  pod 'flame_sdk_ios', '1.0.0-alpha.5'

  # 或 TB 客户，二选一，不能同时接
  # pod 'flame_sdk_ios_tb', '1.0.0-alpha.5'
end
```

**接入代码**（TK/TB 一致）：
```objc
#import <flame_sdk_ios/FlameSdk.h>
```
```swift
import flame_sdk_ios
```

**关于 use_frameworks!**：Flame SDK 本身不强制要求。如果宿主工程已有 `use_frameworks!` 配置，可按原工程配置保留。

## 14. /compact

**Phase 5A.12 Step 3D（发布文档与客户可见说明清理）完成状态**：

| 项 | 状态 |
|---|---|
| 发布操作说明.md 重写 | ✅ single-binary mainline（333 行）|
| README.md 创建 | ✅ 简洁接入说明（50 行）|
| CHANGELOG.md 创建 | ✅ alpha.5 条目（22 行）|
| LICENSE 创建 | ✅ 商业许可 |
| podspec 注释简化 | ✅ 去掉内部原理（TK + TB）|
| use_frameworks 强制要求 | ✅ 已去除 |
| 客户可见内部原理 | ✅ 已去除 |
| file:// / /Users/khj | ✅ 客户可见文件无 |
| 旧架构术语 | ✅ 无 |
| 旧 adapter 名 | ✅ 无 |
| .DS_Store | ✅ 已清除（3 个）+ .gitignore 加入规则 |
| dist repo push | ✅ `2df562c..a9f46fe` |
| flame-specs push | ✅ `0b7789c..9ef0588` |
| 重新 tag | ❌ 未执行（红线遵守）|
| 重新发版 | ❌ 未执行（红线遵守）|

**Phase 5A.12 全部完成（含文档收尾）**：

```
Step 1d: mainline 分支清理
Step 1e: Sigmob 冲突预检
Step 1f: adapter 规范化
Step 2:  TK + TB 真机验证双侧通过
Step 3A: alpha.4 发布预检
Step 3B: alpha.4 正式发布
Step 3C: alpha.5 修正版发布（修复 file:// + adapter 重命名）
Step 3D: 发布文档与客户可见说明清理 🎉
```

**客户接入版本：alpha.5**

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
github_build/发布操作说明.md                    # ✏️ 重写（333 行，single-binary mainline）
github_build/flame_sdk_ios/
├── README.md                                  # ✨ 新建（50 行，客户接入说明）
├── CHANGELOG.md                               # ✨ 新建（22 行，版本记录）
├── LICENSE                                    # ✨ 新建（商业许可）
├── flame_sdk_ios.podspec                      # ✏️ 注释简化
├── flame_sdk_ios_tb.podspec                   # ✏️ 注释简化
├── flame_sdk_ios.xcframework                  # （不变）
└── .gitignore                                 # ✨ 新增 .DS_Store 规则

github_build/flame-specs/
├── flame_sdk_ios/1.0.0-alpha.5/               # ✏️ podspec 注释简化
├── flame_sdk_ios_tb/1.0.0-alpha.5/            # ✏️ podspec 注释简化
├── flame_sdk_ios_tk_sigmob_adapter/4.20.12.2.0/  # （不变）
└── .gitignore                                 # ✨ 新增 .DS_Store 规则

doc/flame_mediation/phase-5a.12-step3d-release-docs-and-customer-guide-cleanup-report.md  # ✨ 本报告
research/logs/step3d/01-docs-commit-push.log  # 实证日志
```

红线遵守：未重新 tag、未新增 alpha.6、未改已发布 specs 依赖结构、未改 SDK 二进制、未恢复旧口径。
