# Phase 5A.12 Step 3E：README 实际内容复核与客户文档二次清理报告

> **类型**：文档复核（不重新发版、不重新打 tag）
> **执行日期**：2026-06-20
> **触发**：用户怀疑 GitHub 当前 README 仍是旧实现说明版（含目录结构 / FlameConfigManager / NSUserDefaults 等）

---

## 核心结论速览

- ✅ **GitHub dist repo README 已是简洁版**（Step 3D 创建），**不是旧实现说明版**
- ✅ **用户看到的旧实现说明是主仓库（flame_ios_sdk）README**，不是 dist repo README（两个不同文件）
- ✅ **按用户模板替换为更完整版**（版本表 + Podfile + 初始化 + 广告类型 + 注意事项 + 技术支持）
- ✅ **CHANGELOG 简化**（去掉 specs/source 本机路径等内部细节）
- ✅ **podspec 注释无内部原理**（已在 Step 3D 清理）
- ✅ **全局红线检查通过**（0 命中）
- ✅ **dist repo push 成功**（`a9f46fe..aefb33a`），未重新 tag

---

## 1. GitHub 当前 README 是否仍为旧实现说明版

❌ **不是**。

dist repo（`github_build/flame_sdk_ios/README.md`，GitHub 客户看到的）在 Step 3D 已是简洁版（50 行）。用户看到的「目录结构 / FlameConfigManager / NSUserDefaults / 两级缓存」等内容是**主仓库**（`/Users/khj/Documents/code/97_ad/ios/flame_ios_sdk/README.md`）的 README，那是开发仓库内部文档，**客户不会看到**（主仓库在 gitee 私有）。

实证：

| README | 位置 | 性质 | 客户可见 |
|---|---|---|---|
| dist repo README | `github_build/flame_sdk_ios/README.md` | 简洁客户接入说明（Step 3D 创建）| ✅ 是（GitHub javaice007/flame_sdk_ios）|
| 主仓库 README | `flame_ios_sdk/README.md` | 开发仓库内部实现说明（旧）| ❌ 否（gitee 私有）|

## 2. README redline check 结果

✅ **0 命中**。

```
grep -nE "目录结构|core/|adapter/|ads/|utils/|FlameConfigManager|FlameConfigLocalStorage|NSUserDefaults|缓存架构|两级缓存|TopOn|AnyThinkSDK|pt|aId|aKey|pMap|Router|\+load|lazy binding|Phase 5A|Thin Core|方案 D|flame_sdk_ios_core|source_files|wrappers|FLAME_BUILD|FLAME_PLUGIN|use_frameworks! :linkage => :static|file:///Users|/Users/khj" README.md
# 无输出
```

## 3. 是否替换为简洁客户接入版

✅ **是**（按用户 §5 模板替换为更完整版）。

新 README（78 行）包含：
- 一、版本说明（表格）
- 二、Podfile 配置
- 三、代码接入（ObjC + Swift）
- 四、初始化
- 五、广告类型
- 六、注意事项（4 条）
- 七、技术支持

## 4. CHANGELOG 是否清理

✅ **是**。

alpha.5 条目简化为：

```
## 1.0.0-alpha.5
- 修复 alpha.4 的发布配置问题，客户建议使用 alpha.5。
- 统一 TK Sigmob adapter 依赖命名。
- 明确 TK / TB 两种接入方式，二选一接入。
- 精简客户接入说明，去除不必要的内部实现说明。
```

去掉了「specs」「source 本机路径」等内部细节。

## 5. podspec 注释是否仍有内部原理

✅ **无**。

podspec 注释检查（Phase 5A / otool / lazy binding / +load / Router / WindMill / WindSDK / SigmobAd-iOS 等）：
- TK podspec：✅ 无
- TB podspec：✅ 无

（Step 3D 已清理）

## 6. 是否仍有 use_frameworks 强制要求

✅ **无**。

README/podspec/CHANGELOG 均无 `use_frameworks! :linkage => :static`。README 明确写：

> Flame SDK 本身不强制要求 `use_frameworks!`。如果宿主工程已有 `use_frameworks!` 配置，可按原工程配置保留。

## 7. 是否仍有 file:///Users 或 /Users/khj

✅ **客户可见文件无**。

## 8. 是否仍有 Thin Core / 方案 D / source_files / wrappers / 宏旧口径

✅ **无**。

## 9. 是否仍有旧 adapter 名称

✅ **无**。

- `flame-sdk-tk-sigmob-adapter`（旧连字符名）：客户可见文件无
- `AnyThinkMediationSigmobAdapter-NoSDK`（旧自定义名）：客户可见文件无
- `SigmobAd-iOS`：客户可见文件无

## 10. dist repo docs commit

✅ commit `aefb33a`：
- README.md：替换为用户模板版（78 行）
- CHANGELOG.md：alpha.5 条目简化
- push 成功（`a9f46fe..aefb33a`）

## 11. 是否重新 tag

❌ **未重新 tag**。

alpha.5 tag `2df562c` 保留不动。本次文档修正 commit `aefb33a` 在 tag 之后，不影响 SDK 二进制和依赖结构。

## 12. 是否重新发版

❌ **未重新发版**。

不新增 alpha.6，不改 specs 依赖，不改 SDK 二进制。

## 13. 最终客户接入方式

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
[FlameSdk initWithAppId:@"your_app_id" appKey:@"your_app_key"];
```

**关于 use_frameworks!**：Flame SDK 本身不强制要求。

## 14. /compact

**Phase 5A.12 Step 3E（README 实际内容复核与客户文档二次清理）完成状态**：

| 项 | 状态 |
|---|---|
| GitHub dist repo README 复核 | ✅ 已是简洁版（Step 3D 创建）|
| 用户看到旧实现的来源 | ✅ 确认是主仓库 README（gitee 私有，客户不可见）|
| README 替换为用户模板版 | ✅ 78 行（版本表 + 初始化 + 广告类型 + 注意事项）|
| CHANGELOG 简化 | ✅ 去掉内部细节 |
| podspec 注释内部原理 | ✅ 无（Step 3D 已清理）|
| use_frameworks 强制要求 | ✅ 无 |
| file:// / /Users/khj | ✅ 客户可见文件无 |
| 旧架构术语 | ✅ 无 |
| 旧 adapter 名 | ✅ 无 |
| .DS_Store | ✅ 无 |
| dist repo push | ✅ `a9f46fe..aefb33a` |
| 重新 tag | ❌ 未执行 |
| 重新发版 | ❌ 未执行 |

**Phase 5A.12 全部完成（含 README 二次清理）**：

```
Step 1d: mainline 分支清理
Step 1e: Sigmob 冲突预检
Step 1f: adapter 规范化
Step 2:  TK + TB 真机验证双侧通过
Step 3A: alpha.4 发布预检
Step 3B: alpha.4 正式发布
Step 3C: alpha.5 修正版发布
Step 3D: 发布文档与客户可见说明清理
Step 3E: README 实际内容复核与客户文档二次清理 🎉
```

**客户接入版本：alpha.5**

红线遵守：未重新 tag、未新增 alpha.6、未改 specs 依赖、未改 SDK 二进制、未改 podspec source、未恢复旧口径。
