# Phase 5A.12 Step 3B：alpha.4 正式发布报告

> **类型**：正式发布（dist repo + flame-specs push + 远程验证）
> **执行日期**：2026-06-20
> **发布版本**：`1.0.0-alpha.4`（flame_sdk_ios + flame_sdk_ios_tb）+ `4.20.12.2.0`（flame-sdk-tk-sigmob-adapter）
> **前置**：Step 3A 预检无阻塞

---

## 核心结论速览

- 🎉 **alpha.4 正式发布成功**
- ✅ **dist repo**：commit `fa8c431` + tag `1.0.0-alpha.4` + push main + push tag 全部成功
- ✅ **flame-specs**：push main `c0f85fc`（含 3 个 specs）成功
- ✅ **TK 远程验证**：pod install + build BUILD SUCCEEDED，0 xcframework duplicate，0 源码泄漏
- ✅ **TB 远程验证**：pod install + build BUILD SUCCEEDED，0 xcframework duplicate，0 源码泄漏
- ✅ **无 AnyThinkMediationSigmobAdapter / NoSDK / SigmobAd-iOS 残留**
- ✅ **无 dyld / symbol / duplicate / framework not found 异常**
- 红线遵守：未 push SDK 主仓库、未创建 GitHub Release 页面、未删除兜底分支

---

## 1. SDK 主仓库分支 / HEAD

| 项 | 值 |
|---|---|
| 分支 | `research/single-binary-mainline`（**未 push**，本地）|
| HEAD | `d244e28`（docs(step2): TK + TB 真机验证报告）|

## 2. dist repo commit hash

`fa8c4317ba83fd846e40801ec08d4fffdadf151c`

- 标题：`Release 1.0.0-alpha.4: single-binary mainline with dual-core dependencies + Sigmob NoSDK normalization`
- 改动：156 files changed, +126/-8589（删除旧 alpha.2 源码 + xcframework，新增 alpha.4 单二进制）

## 3. dist repo tag

`1.0.0-alpha.4`（指向 `fa8c431`）

## 4. dist repo push 结果

```
git push origin main
   79d837c..fa8c431  main -> main    ✅

git push origin 1.0.0-alpha.4
 * [new tag]         1.0.0-alpha.4 -> 1.0.0-alpha.4    ✅

git ls-remote --heads origin main
fa8c4317ba83fd846e40801ec08d4fffdadf151c	refs/heads/main    ✅

git ls-remote --tags origin | grep "1.0.0-alpha.4"
fa8c4317ba83fd846e40801ec08d4fffdadf151c	refs/tags/1.0.0-alpha.4    ✅
```

## 5. flame-specs commit hash

`c0f85fca8bc1bc053bd3a9572a36062dc02ab8dc`

- 标题：`alpha.4: add flame_sdk_ios 1.0.0-alpha.4 + flame_sdk_ios_tb 1.0.0-alpha.4 + flame-sdk-tk-sigmob-adapter 4.20.12.2.0; remove AnyThinkMediationSigmobAdapter-NoSDK`

## 6. flame-specs push 结果

```
git push origin main
   29f720b..c0f85fc  main -> main    ✅

git ls-remote --heads origin main
c0f85fca8bc1bc053bd3a9572a36062dc02ab8dc	refs/heads/main    ✅
```

## 7. 3 个 specs 是否远程可见

✅ **全部远程可见**。

`pod repo update javaice007-flame-specs` 后本地缓存：

```
~/.cocoapods/repos/javaice007-flame-specs/
├── flame_sdk_ios/1.0.0-alpha.4/flame_sdk_ios.podspec                    ✅
├── flame_sdk_ios_tb/1.0.0-alpha.4/flame_sdk_ios_tb.podspec              ✅
└── flame-sdk-tk-sigmob-adapter/4.20.12.2.0/flame-sdk-tk-sigmob-adapter.podspec.json  ✅
```

## 8. GitHub tag archive 是否可下载

✅ **可下载**（TK/TB 远程 pod install 时 source.http 已成功下载 `flame_sdk_ios.xcframework`，证明 tag archive 可访问）。

URL: `https://github.com/javaice007/flame_sdk_ios/archive/refs/tags/1.0.0-alpha.4.zip`

## 9. TK 远程 pod install 结果

**✅ 成功**（远程 source `https://github.com/javaice007/flame-specs.git` + 远程 tag archive）。

接入方式（正式客户接入）：

```ruby
source 'https://github.com/javaice007/flame-specs.git'
source 'https://cdn.cocoapods.org/'

target 'YourApp' do
  use_frameworks! :linkage => :static
  pod 'flame_sdk_ios', '1.0.0-alpha.4'
end
```

## 10. TK Podfile.lock 关键依赖

```
- flame_sdk_ios (1.0.0-alpha.4):
  - AnyThinkiOS (= 6.5.71)
  - AnyThinkMediation*Adapter (11 个)
  - flame-sdk-tk-sigmob-adapter (= 4.20.12.2.0)
  - AdGainSDK / AdGainSDKTakuAdapter / FSUnionAdSDK
  - OpenSSL-Universal (~> 3.6)
  - ToBid-iOS-RC (= 5.5.6)
- flame-sdk-tk-sigmob-adapter (4.20.12.2.0):
  - AnyThinkiOS (>= 6.5.60)
- ToBid-iOS-RC (5.5.6)
```

## 11. TK source leak 检查

✅ **无源码泄漏**。`find Pods -path "*flame_sdk_ios*" \( -name "*.m" -o -name "*.mm" \) -print` 无输出。

## 12. TK duplicate framework 检查

✅ **0 xcframework duplicate**。

```
Pods/flame_sdk_ios/flame_sdk_ios.xcframework                              ← flame binary
Pods/ToBid-iOS-RC/tobid-sdk-ios-cocoapods-cn/Core/WindFoundation.xcframework   ← 唯一来源
Pods/ToBid-iOS-RC/tobid-sdk-ios-cocoapods-cn/Core/WindSDK.xcframework          ← 唯一来源
```

## 13. TK build 结果

**✅ BUILD SUCCEEDED**（真机 arm64，Debug 配置）。

无 duplicate symbol / multiple commands produce / ld: error / clang: error。

## 14. TB 远程 pod install 结果

**✅ 成功**（5 pods）。

接入方式：

```ruby
source 'https://github.com/javaice007/flame-specs.git'
source 'https://cdn.cocoapods.org/'

target 'YourApp' do
  use_frameworks! :linkage => :static
  pod 'flame_sdk_ios_tb', '1.0.0-alpha.4'
end
```

## 15. TB Podfile.lock 关键依赖

```
- flame_sdk_ios_tb (1.0.0-alpha.4):
  - AnyThinkiOS (= 6.5.71)
  - OpenSSL-Universal (~> 3.6)
  - ToBid-iOS-RC (= 5.5.6)
- AnyThinkiOS (6.5.71)
- OpenSSL-Universal (3.6.2000)
- ToBid-iOS-RC (5.5.6)
```

## 16. TB source leak 检查

✅ **无源码泄漏**。

## 17. TB duplicate framework 检查

✅ **0 xcframework duplicate**。

```
Pods/flame_sdk_ios_tb/flame_sdk_ios.xcframework                            ← flame binary
Pods/ToBid-iOS-RC/tobid-sdk-ios-cocoapods-cn/Core/WindSDK.xcframework      ← 唯一来源
```

## 18. TB build 结果

**✅ BUILD SUCCEEDED**（真机 arm64，Debug 配置）。

无 duplicate symbol / multiple commands produce / ld: error / clang: error。

## 19. 是否出现 AnyThinkMediationSigmobAdapter-NoSDK

❌ **未出现**（TK/TB 远程安装均无）。

`Podfile.lock` + `Pods/` 目录均无 `AnyThinkMediationSigmobAdapter-NoSDK`。

## 20. 是否出现普通 AnyThinkMediationSigmobAdapter

❌ **未出现**（TK/TB 远程安装均无）。

## 21. 是否出现 SigmobAd-iOS

❌ **未出现**（TK/TB 远程安装均无）。

## 22. 是否有 dyld / symbol / duplicate / framework not found

❌ **无**（TK/TB 远程 build 均无任何此类异常）。

| 异常 | TK | TB |
|---|---|---|
| dyld: Library not loaded | ✅ 无 | ✅ 无 |
| Symbol not found | ✅ 无 | ✅ 无 |
| duplicate symbol | ✅ 无 | ✅ 无 |
| duplicate class | ✅ 无 | ✅ 无 |
| Multiple commands produce | ✅ 无 | ✅ 无 |
| framework not found | ✅ 无 | ✅ 无 |
| Library not found | ✅ 无 | ✅ 无 |
| clang: error | ✅ 无 | ✅ 无 |
| ld: error | ✅ 无 | ✅ 无 |

## 23. alpha.4 是否发布成功

🎉 **是**。

发布对象全部远程可用：

| 发布对象 | 版本 | 远程可见 |
|---|---|---|
| flame_sdk_ios | 1.0.0-alpha.4 | ✅（dist repo tag `fa8c431` + flame-specs spec）|
| flame_sdk_ios_tb | 1.0.0-alpha.4 | ✅（同上）|
| flame-sdk-tk-sigmob-adapter | 4.20.12.2.0 | ✅（flame-specs spec + TopOn OSS source）|

客户接入 Podfile（正式）：

```ruby
source 'https://github.com/javaice007/flame-specs.git'
source 'https://cdn.cocoapods.org/'

# TK 客户
pod 'flame_sdk_ios', '1.0.0-alpha.4'

# 或 TB 客户（互斥）
pod 'flame_sdk_ios_tb', '1.0.0-alpha.4'
```

## 24. 后续建议

### 24.1 立即可做

- ✅ **TK 真机验证已完成**（Step 2）：双 +load + Router 激活 tk + Splash/Interstitial + Sigmob NoSDK 调用 WindSDK
- ✅ **TB 真机验证已完成**（Step 2）：双 +load + Router 激活 tb + TB Reward 链路（800031 后台未绑定）

### 24.2 待做（运营/后台）

- ⏳ **联系 ToBid 把 AppId `74518` 绑定到聚合服务**（让 TB Reward 真正返回广告，非 SDK 问题）
- ⏳ **Sigmob 后台 media.bundle 配置修复**（让 Sigmob 广告位真正返回广告，非 SDK 问题）
- ⏳ **GDT/BeiZi/KS/MS 等广告平台后台包名配置**（让对应广告源真正返回广告，非 SDK 问题）

### 24.3 Phase 5A.12 后续阶段

- **Phase 5A.13**：TB 其他广告类型（Splash/Interstitial/Banner/Native）—— 当前 TB podspec 差异化广告源依赖为空，Phase 5A.13 接 ToBid-iOS-RC/<Adapter> 子规范
- **Phase 5A.14**：双线并存（flame_sdk_ios + flame_sdk_ios_tb 合并为单一 podspec，处理依赖冲突）
- **正式版（非 alpha）**：积累真机验证数据后，发布 1.0.0 正式版

### 24.4 主仓库 push（待授权）

`research/single-binary-mainline` 分支（HEAD `d244e28`）目前只在本地。如需团队协作，可考虑 push 到 gitee 远程（但这是实验分支，建议保留本地或合并到正式分支后再 push）。

## 25. /compact

**Phase 5A.12 Step 3B（alpha.4 正式发布）完成状态**：

| 项 | 状态 |
|---|---|
| dist repo commit | ✅ `fa8c431` |
| dist repo tag | ✅ `1.0.0-alpha.4` |
| dist repo push main | ✅ `79d837c..fa8c431` |
| dist repo push tag | ✅ new tag |
| flame-specs push main | ✅ `29f720b..c0f85fc` |
| 3 个 specs 远程可见 | ✅ |
| GitHub tag archive 可下载 | ✅ |
| TK 远程 pod install | ✅ 28 pods，含 flame-sdk-tk-sigmob-adapter |
| TK 远程 build | ✅ BUILD SUCCEEDED |
| TB 远程 pod install | ✅ 5 pods |
| TB 远程 build | ✅ BUILD SUCCEEDED |
| AnyThinkMediationSigmobAdapter-NoSDK | ✅ 未出现 |
| 普通 AnyThinkMediationSigmobAdapter | ✅ 未出现 |
| SigmobAd-iOS | ✅ 未出现 |
| dyld/symbol/duplicate/framework not found | ✅ 全无 |
| **alpha.4 发布成功** | 🎉 **是** |
| SDK 主仓库 push | ❌ 未执行（红线遵守）|
| GitHub Release 页面 | ❌ 未创建（红线遵守）|

**Phase 5A.12 全部完成（Step 1d → 1e → 1f → 2 → 3A → 3B）**：

```
Step 1d: mainline 分支清理（删除历史入口 + 宏体系）
Step 1e: Sigmob 冲突预检（实证普通版冲突）
Step 1f: flame-sdk-tk-sigmob-adapter 规范化
Step 2:  TK + TB 真机验证双侧通过
Step 3A: alpha.4 发布预检（无阻塞）
Step 3B: alpha.4 正式发布（远程验证通过）🎉
```

**客户现在可以正式接入 alpha.4**：

```ruby
source 'https://github.com/javaice007/flame-specs.git'
source 'https://cdn.cocoapods.org/'

# TK 客户
pod 'flame_sdk_ios', '1.0.0-alpha.4'

# 或 TB 客户（互斥）
pod 'flame_sdk_ios_tb', '1.0.0-alpha.4'
```

**关键文件清单**：

```
research/logs/step3b/
├── 01-dist-commit-tag-push.log     # dist repo commit + tag + push
├── 02-specs-push.log               # flame-specs push
├── 03-repo-update-cache-clean.log  # pod repo update + cache clean
├── 04-remote-tk-install.log        # TK 远程 pod install
├── 05-remote-tk-check.log          # TK 泄漏 + xcframework 检查
├── 06-remote-tk-build.log          # TK 远程 build（SUCCEEDED）
├── 07-remote-tb-install.log        # TB 远程 pod install
├── 08-remote-tb-check.log          # TB 泄漏 + xcframework 检查
└── 09-remote-tb-build.log          # TB 远程 build（SUCCEEDED）

doc/flame_mediation/phase-5a.12-step3b-alpha4-release-report.md  # ✨ 本报告
```

**Phase 5A.12 mainline 单二进制方案 alpha.4 发布完成。** 🎉

红线遵守：未 push SDK 主仓库、未创建 GitHub Release 页面、未删除 tb_adapter / backup 兜底分支、未改回普通 AnyThinkMediationSigmobAdapter、未恢复 AnyThinkMediationSigmobAdapter-NoSDK。
