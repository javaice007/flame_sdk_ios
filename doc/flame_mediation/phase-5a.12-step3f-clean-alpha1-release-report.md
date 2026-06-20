# Phase 5A.12 Step 3F：清理旧 alpha 版本并重新发布规范版 1.0.0-alpha.1

> **类型**：版本清理 + 重新发布（本地完成，远程 push 需用户手动执行）
> **执行日期**：2026-06-20
> **目标**：清理所有旧 `1.0.0-alpha.*` 内测版本，重新发布干净的 `1.0.0-alpha.1`

---

## 核心结论速览

- ✅ **本地所有准备工作已完成**（tag 删除 + specs 清理 + podspec + README + CHANGELOG + adapter）
- ⚠️ **远程 push 需用户手动执行**（GitHub 认证缓存过期，shell 环境无法非交互认证）
- ✅ dist repo 本地 commit `d6d7888` + tag `1.0.0-alpha.1`
- ✅ flame-specs 本地 commit `f2c7118`（删除旧 alpha specs + 新增 alpha.1）
- ✅ 全局红线检查全通过
- ⏳ **等待用户执行 4 条远程命令**（删除旧远程 tag + push dist repo + push flame-specs）

---

## 1. 是否确认旧 1.0.0-alpha.* 均为内测

✅ **是**。

- 1.0.0-alpha.1（旧）：Thin Core 架构（已废弃）
- 1.0.0-alpha.2：修复 zip flatten（alpha.1 的 source_files 问题）
- 1.0.0-alpha.4：single-binary mainline（specs 误带 file://）
- 1.0.0-alpha.5：修复 file:// + adapter 重命名

所有旧 alpha 都是内测版本，没有外部客户生产依赖。

## 2. 删除了哪些 local alpha tags

```
1.0.0-alpha.1 (3530806) — 已删除
1.0.0-alpha.2 (79d837c) — 已删除
1.0.0-alpha.4 (fa8c431) — 已删除
1.0.0-alpha.5 (2df562c) — 已删除
```

## 3. 删除了哪些 remote alpha tags

⚠️ **本地已删除，远程待用户手动删除**（认证过期）。

需删除的远程 tag：
```
1.0.0-alpha.1
1.0.0-alpha.2
1.0.0-alpha.4
1.0.0-alpha.5
```

## 4. 删除了哪些 flame-specs alpha specs

```
flame_sdk_ios/1.0.0-alpha.2/     — 已删除
flame_sdk_ios/1.0.0-alpha.4/     — 已删除
flame_sdk_ios/1.0.0-alpha.5/     — 已删除
flame_sdk_ios_tb/1.0.0-alpha.2/  — 已删除
flame_sdk_ios_tb/1.0.0-alpha.4/  — 已删除
flame_sdk_ios_tb/1.0.0-alpha.5/  — 已删除
```

保留：
```
flame_sdk_ios/1.0.0-alpha.1/     — 新（覆盖旧 alpha.1）
flame_sdk_ios_tb/1.0.0-alpha.1/  — 新（覆盖旧 alpha.1）
flame_sdk_ios_tk_sigmob_adapter/4.20.12.2.0/  — 保留
```

## 5. 是否重新发布 1.0.0-alpha.1

✅ **本地已准备**（commit + tag），远程待 push。

## 6. 是否没有发布 1.0.0 正式版

✅ **未发布**。本地 + 远程均无 `1.0.0` 正式 tag。

## 7. 是否保留新 adapter spec

✅ `flame_sdk_ios_tk_sigmob_adapter/4.20.12.2.0/flame_sdk_ios_tk_sigmob_adapter.podspec.json` 保留（description 已简化）。

## 8. dist repo 1.0.0-alpha.1 commit

`d6d7888`（Release 1.0.0-alpha.1: clean customer alpha）

## 9. dist repo 1.0.0-alpha.1 tag

`1.0.0-alpha.1`（本地，指向 `d6d7888`）

## 10. flame-specs 1.0.0-alpha.1 commit

`f2c7118`（Release Flame SDK 1.0.0-alpha.1 specs and remove old alpha specs）

## 11. podspec source 是否正确

✅ 两个 podspec source 都是 GitHub :git：

```ruby
s.source = { :git => 'https://github.com/javaice007/flame_sdk_ios.git', :tag => s.version.to_s }
```

## 12. README / CHANGELOG 是否已改为 1.0.0-alpha.1

✅ **是**。

- README：版本表 + Podfile + 初始化 + 注意事项，全部 `1.0.0-alpha.1`
- CHANGELOG：简洁 alpha.1 条目（无 alpha.4/alpha.5 内部细节）

## 13. 是否仍有 alpha.4 / alpha.5

✅ **客户可见文件无**（README / CHANGELOG / podspec / specs 均无）。

## 14. 是否仍有 file:///Users 或 /Users/khj

✅ **客户可见文件无**。

## 15. 是否仍有内部原理注释

✅ **无**（Phase 5A / Router / +load / lazy binding / otool / WindSDK / SigmobAd-iOS 等全部清除）。

## 16. 是否仍有旧 adapter 名

✅ **无**（flame-sdk-tk-sigmob-adapter / AnyThinkMediationSigmobAdapter-NoSDK 全部清除）。

## 17. TB podspec 红线是否通过

✅ **通过**。TB podspec 完全无 TK Sigmob / AnyThinkMediation* / AdGain / FSUnion / SigmobAd-iOS。

## 18. TK 远程 pod install + build

⏳ **待用户执行远程 push 后验证**。

## 19. TB 远程 pod install + build

⏳ **待用户执行远程 push 后验证**。

## 20. GitHub tag archive 是否可访问

⏳ **待用户执行 push tag 后验证**。

## 21. flame-specs 是否只保留 1.0.0-alpha.1

✅ **本地是**（远程待 push）。

```
flame_sdk_ios/1.0.0-alpha.1/     ✅
flame_sdk_ios_tb/1.0.0-alpha.1/  ✅
flame_sdk_ios_tk_sigmob_adapter/4.20.12.2.0/  ✅
```

无 alpha.2/4/5。

## 22. 客户最终接入方式

```ruby
source 'https://github.com/javaice007/flame-specs.git'
source 'https://cdn.cocoapods.org/'

target 'YourApp' do
  # TK 客户
  pod 'flame_sdk_ios', '1.0.0-alpha.1'

  # 或 TB 客户，二选一
  # pod 'flame_sdk_ios_tb', '1.0.0-alpha.1'
end
```

## 23. /compact

**Phase 5A.12 Step 3F（清理旧 alpha + 重发 1.0.0-alpha.1）本地完成状态**：

| 项 | 状态 |
|---|---|
| 旧 alpha tag 本地删除 | ✅（4 个）|
| 旧 alpha tag 远程删除 | ⏳ 待用户手动执行 |
| flame-specs 旧 alpha specs 删除 | ✅（6 个目录）|
| 新 adapter spec 保留 | ✅ |
| podspec 改为 1.0.0-alpha.1 | ✅ |
| README 改为 1.0.0-alpha.1 | ✅ |
| CHANGELOG 改为 clean alpha.1 | ✅ |
| adapter description 简化 | ✅ |
| dist repo 本地 commit + tag | ✅ `d6d7888` |
| flame-specs 本地 commit | ✅ `f2c7118` |
| 全局红线检查 | ✅ 全通过 |
| **远程 push** | ⏳ **待用户手动执行** |

---

## ⚠️ 待用户手动执行的远程命令

> GitHub 认证缓存过期，以下命令需在**终端手动执行**（会提示输入 GitHub 用户名 + Personal Access Token）。

### 命令 1：删除远程旧 alpha tag

```bash
cd /Users/khj/Documents/code/97_ad/ios/github_build/flame_sdk_ios

git push origin --delete 1.0.0-alpha.1 1.0.0-alpha.2 1.0.0-alpha.4 1.0.0-alpha.5
```

### 命令 2：push dist repo main + 新 tag

```bash
cd /Users/khj/Documents/code/97_ad/ios/github_build/flame_sdk_ios

git push origin main
git push origin 1.0.0-alpha.1
```

### 命令 3：push flame-specs main

```bash
cd /Users/khj/Documents/code/97_ad/ios/github_build/flame-specs

git push origin main
```

### 命令 4：远程验证（push 完成后）

```bash
# 更新 pod repo
pod repo update javaice007-flame-specs

# 清缓存
pod cache clean flame_sdk_ios --all
pod cache clean flame_sdk_ios_tb --all
pod cache clean flame_sdk_ios_tk_sigmob_adapter --all

# TK 验证
cd /Users/khj/Documents/code/97_ad/ios/adsurge-ios-demo
cat > Podfile << 'EOF'
platform :ios, '13.0'
source 'https://github.com/javaice007/flame-specs.git'
source 'https://cdn.cocoapods.org/'
target 'adshurge-ios-demo' do
  pod 'flame_sdk_ios', '1.0.0-alpha.1'
  pod 'OpenSSL-Universal', :path => '/Users/khj/Documents/code/97_ad/ios/local_pods/OpenSSL-Universal'
  pod 'FunlinkSDK', :path => '../local_pods/FunlinkSDK'
end
EOF
pod deintegrate
rm -rf Pods Podfile.lock
pod install
grep -nE "flame_sdk_ios|flame_sdk_ios_tk_sigmob_adapter|alpha" Podfile.lock | head -10
xcodebuild -workspace adshurge-ios-demo.xcworkspace -scheme adshurge-ios-demo -configuration Debug -sdk iphoneos -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build

# TB 验证（pod 改为 flame_sdk_ios_tb）
```

---

**最终结论**：

```
1. 旧 1.0.0-alpha.* 内测版本已在本地清理（远程待用户手动删除 tag）；
2. 未发布 1.0.0 正式版；
3. 客户当前接入版本为 1.0.0-alpha.1（本地已 commit + tag，远程待 push）；
4. 客户不再使用旧 alpha.4 / alpha.5；
5. 本次未改 SDK 业务逻辑，只做 alpha 版本号重置、发布痕迹清理与远程验证准备。
```

**等待用户执行 4 条远程命令**，完成后我帮你做远程验证。
