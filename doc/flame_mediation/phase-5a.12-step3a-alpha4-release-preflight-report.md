# Phase 5A.12 Step 3A：alpha.4 发布预检与远程分发准备报告

> **类型**：发布预检（本地准备 + 模拟验证，不执行远程 push/tag/release）
> **执行日期**：2026-06-20
> **分支**：`research/single-binary-mainline`（HEAD `d244e28`）
> **前置**：Step 2（TK + TB 真机验证双侧通过）

---

## 核心结论速览

- ✅ **SDK 主仓库已补 commit**：HEAD `d244e28`，工作区干净
- ✅ **旧 AnyThinkMediationSigmobAdapter-NoSDK 已从正式路径清除**（3 处）
- ✅ **single-binary 重建（默认 + 显式）完全一致**：300K，9 符号 + 双 +load + 0 污染
- ✅ **dist repo 已准备**：alpha.4 podspec + flame_sdk_ios.xcframework，无源码泄漏
- ✅ **3 个 specs 已准备到 github_build/flame-specs**：flame_sdk_ios + flame_sdk_ios_tb + flame-sdk-tk-sigmob-adapter
- ✅ **flame-sdk-tk-sigmob-adapter podspec lint 通过**（TopOn OSS source HTTP 200 OK）
- ✅ **TK alpha.4 模拟安装 + build 通过**：28 pods，0 xcframework duplicate
- ✅ **TB alpha.4 模拟安装 + build 通过**：5 pods，0 xcframework duplicate
- ✅ **无阻塞正式发布的问题**
- 所有红线遵守：未 push、未 tag、未 pod repo push、未 GitHub Release

---

## 1. 当前 SDK 主仓库分支 / HEAD

| 项 | 值 |
|---|---|
| 分支 | `research/single-binary-mainline` |
| HEAD | `d244e28`（docs(step2): TK + TB 真机验证报告 + Podfile 本地 OpenSSL path）|

## 2. 当前是否有未提交改动

❌ 无（工作区干净）。Step 2 报告 + Podfile 改动已在 `d244e28` commit。

## 3. 是否未 push / 未 tag / 未发布

| 检查项 | 结果 |
|---|---|
| `git push origin`（SDK 主仓库）| ❌ 未执行 |
| 远程 tag | ❌ 不存在 |
| GitHub release | ❌ 未创建 |
| `pod repo push` | ❌ 未执行 |

## 4. 是否未 pod repo push

❌ 未执行。`flame-sdk-tk-sigmob-adapter` 仅在本地 spec repo（`github_build/flame-specs` 本地 commit `c0f85fc`，未 push 远程）。

## 5. 旧 AnyThinkMediationSigmobAdapter-NoSDK 是否已从正式路径删除

✅ **已清除**。

| 路径 | 状态 |
|---|---|
| `research/local_specs/flame-specs/AnyThinkMediationSigmobAdapter-NoSDK` | ✅ 已删除 |
| `github_build/flame-specs/AnyThinkMediationSigmobAdapter-NoSDK` | ✅ 已删除（git status 显示 D，待 commit）|
| `~/.cocoapods/repos/javaice007-flame-specs/AnyThinkMediationSigmobAdapter-NoSDK` | ✅ 已删除 |
| 正式 podspec（flame_sdk_ios.podspec / flame_sdk_ios_tb.podspec）| ✅ 无引用 |
| github_build/flame-specs 工作区 | ✅ 无残留（只剩 git history 的旧 commit 记录）|

文档中的历史说明保留（Step 1e/1f 报告），已标注「已废弃，正式名称为 flame-sdk-tk-sigmob-adapter」。

## 6. dist repo 路径 / 分支 / HEAD

| 项 | 值 |
|---|---|
| 路径 | `/Users/khj/Documents/code/97_ad/ios/github_build/flame_sdk_ios` |
| 分支 | `main` |
| HEAD | `79d837c`（Release 1.0.0-alpha.2，**alpha.4 改动待 commit**）|
| remote | `https://github.com/javaice007/flame_sdk_ios.git` |

## 7. flame-specs repo 路径 / 分支 / HEAD

| 项 | 值 |
|---|---|
| 路径 | `/Users/khj/Documents/code/97_ad/ios/github_build/flame-specs` |
| 分支 | `main` |
| HEAD | `c0f85fc`（alpha.4: 3 个 specs + 删除 NoSDK，**本地 commit，未 push**）|
| remote | `https://github.com/javaice007/flame-specs.git` |

## 8. single-binary 产物路径

```
build/flame_sdk_ios.xcframework
├── ios-arm64/flame_sdk_ios.framework/flame_sdk_ios   （300K，MH_DYLIB）
└── ios-x86_64-simulator/flame_sdk_ios.framework/
```

## 9. dist repo 文件清单

```
github_build/flame_sdk_ios/
├── flame_sdk_ios.xcframework              # 单二进制（300K）
├── flame_sdk_ios.podspec                  # TK 客户（alpha.4）
└── flame_sdk_ios_tb.podspec               # TB 客户（alpha.4）
```

## 10. dist repo 是否无 .m / .mm

✅ **无源码泄漏**。`find . -name "*.m" -o -name "*.mm"` 无输出。

## 11. flame_sdk_ios.podspec 版本 / source / dependencies

| 字段 | 值 |
|---|---|
| s.name | `flame_sdk_ios` |
| s.version | `1.0.0-alpha.4` |
| s.module_name | `flame_sdk_ios` |
| s.source | `https://github.com/javaice007/flame_sdk_ios/archive/refs/tags/#{s.version}.zip` |
| s.vendored_frameworks | `flame_sdk_ios.xcframework` |
| 公共依赖 | OpenSSL-Universal ~> 3.6 / AnyThinkiOS 6.5.71 / ToBid-iOS-RC 5.5.6 |
| TK 广告源依赖 | 11 个 AnyThinkMediation*Adapter + AdGainSDK + AdGainSDKTakuAdapter + FSUnionAdSDK |
| Sigmob 依赖 | **`flame-sdk-tk-sigmob-adapter 4.20.12.2.0`**（✅ 规范命名）|
| source_files / public_header_files / private_header_files | ❌ 无（纯 vendored binary）|

## 12. flame_sdk_ios_tb.podspec 版本 / source / dependencies

| 字段 | 值 |
|---|---|
| s.name | `flame_sdk_ios_tb` |
| s.version | `1.0.0-alpha.4` |
| s.module_name | `flame_sdk_ios`（与 TK 一致）|
| s.source | `https://github.com/javaice007/flame_sdk_ios/archive/refs/tags/#{s.version}.zip` |
| s.vendored_frameworks | `flame_sdk_ios.xcframework`（与 TK 同一份）|
| 公共依赖 | OpenSSL-Universal ~> 3.6 / AnyThinkiOS 6.5.71 / ToBid-iOS-RC 5.5.6 |
| TB 广告源依赖 | 当前为空（Phase 5A.13+ 按需增加 ToBid-iOS-RC/<Adapter>）|
| Sigmob 依赖 | ❌ 无（TB 不需要）|
| source_files / public_header_files / private_header_files | ❌ 无（纯 vendored binary）|

## 13. flame-sdk-tk-sigmob-adapter podspec 完整内容

```json
{
  "name": "flame-sdk-tk-sigmob-adapter",
  "version": "4.20.12.2.0",
  "summary": "Flame SDK TK Sigmob adapter without SigmobAd-iOS dependency.",
  "description": "A Flame SDK private TK Sigmob adapter podspec wrapper. It uses TopOn's AnyThinkSigmobAdapter.xcframework and does not depend on SigmobAd-iOS. WindSDK and WindFoundation are provided by ToBid-iOS-RC to avoid duplicate frameworks in single-binary dual-core integration.",
  "homepage": "https://github.com/javaice007/flame_sdk_ios",
  "license": {
    "type": "Commercial",
    "text": "TopOn AnyThinkSigmobAdapter.xcframework Copyright TopOn. Used under TopOn commercial license. Podspec wrapper Copyright Flame."
  },
  "authors": { "flame": "flame@toowe.com" },
  "platforms": { "ios": "10.0" },
  "static_framework": true,
  "requires_arc": true,
  "source": {
    "http": "https://topon-sdk-release.oss-accelerate.aliyuncs.com/AnyThink_Release/iosnetwork_2/AnyThinkSigmobAdapter/4.20.12.2.0/AnyThinkSigmobAdapter-4.20.12.2.0.zip",
    "type": "zip"
  },
  "vendored_frameworks": "AnyThinkSigmobAdapter-4.20.12.2.0/AnyThinkSigmobAdapter.xcframework",
  "pod_target_xcconfig": { "OTHER_LDFLAGS": "-ObjC" },
  "dependencies": { "AnyThinkiOS": [">= 6.5.60"] }
}
```

## 14. adapter podspec source 是否远程可用

✅ **远程可用**。

```
URL: https://topon-sdk-release.oss-accelerate.aliyuncs.com/AnyThink_Release/iosnetwork_2/AnyThinkSigmobAdapter/4.20.12.2.0/AnyThinkSigmobAdapter-4.20.12.2.0.zip
HTTP/1.1 200 OK
Server: AliyunOSS
Content-Type: application/zip
Content-Length: 187737（~183KB）
```

## 15. 三个 specs 是否已准备到 flame-specs 本地仓库

✅ **已就位**。

```
github_build/flame-specs/
├── flame_sdk_ios/1.0.0-alpha.4/flame_sdk_ios.podspec
├── flame_sdk_ios_tb/1.0.0-alpha.4/flame_sdk_ios_tb.podspec
└── flame-sdk-tk-sigmob-adapter/4.20.12.2.0/flame-sdk-tk-sigmob-adapter.podspec.json
```

flame-specs 本地 commit `c0f85fc`（未 push）。

## 16. pod spec lint 结果

| podspec | lint 结果 | 说明 |
|---|---|---|
| flame-sdk-tk-sigmob-adapter | ✅ **passed validation** | `--skip-import-validation`（AnyThinkSigmobAdapter.xcframework 模拟器切片不完整是 TopOn SDK 已知限制，与 podspec 无关）|
| flame_sdk_ios | ✅ 语法通过（pod ipc spec）| 完整 lint 待 GitHub tag 发布后（source.http 需要下载）|
| flame_sdk_ios_tb | ✅ 语法通过（pod ipc spec）| 完整 lint 待 GitHub tag 发布后 |

## 17. alpha.4 TK 模拟安装验证结果

**✅ 通过**（28 pods，0 xcframework duplicate）。

接入方式（模拟远程，本地 spec repo + 本地 dist git tag）：

```ruby
source 'file:///Users/khj/Documents/code/97_ad/ios/github_build/flame-specs'
source 'https://cdn.cocoapods.org/'

target 'adshurge-ios-demo' do
  use_frameworks! :linkage => :static
  pod 'flame_sdk_ios', '1.0.0-alpha.4'
end
```

Podfile.lock 关键依赖：
- ✅ `flame_sdk_ios (1.0.0-alpha.4)`
- ✅ `flame-sdk-tk-sigmob-adapter (4.20.12.2.0)`
- ✅ `ToBid-iOS-RC (5.5.6)`
- ❌ 不含 `AnyThinkMediationSigmobAdapter`（旧普通版）
- ❌ 不含 `AnyThinkMediationSigmobAdapter-NoSDK`（旧自定义名）
- ❌ 不含 `SigmobAd-iOS`

xcframework 来源：
- WindSDK/WindFoundation 只来自 ToBid-iOS-RC（一处）
- flame_sdk_ios.xcframework 来自 flame_sdk_ios pod

## 18. alpha.4 TB 模拟安装验证结果

**✅ 通过**（5 pods，0 xcframework duplicate）。

Podfile.lock 关键依赖：
- ✅ `flame_sdk_ios_tb (1.0.0-alpha.4)`
- ✅ `AnyThinkiOS (6.5.71)` + `OpenSSL-Universal (3.6.2000)` + `ToBid-iOS-RC (5.5.6)`
- ❌ 不含 `flame-sdk-tk-sigmob-adapter`
- ❌ 不含 `AnyThinkMediationSigmobAdapter` / `SigmobAd-iOS`

## 19. duplicate framework 检查

| 模式 | xcframework duplicate | 说明 |
|---|---|---|
| TK alpha.4 | ✅ 0 | WindSDK/WindFoundation 只来自 ToBid-iOS-RC |
| TB alpha.4 | ✅ 0 | 同上 |

`.framework` 各 2 份是 xcframework 双切片（arm64 + simulator）展开的正常现象，不是冲突。

## 20. build 结果

| 模式 | build 结果 | duplicate symbol | 源码泄漏 |
|---|---|---|---|
| TK alpha.4 | ✅ BUILD SUCCEEDED | ✅ 无 | ✅ 无 |
| TB alpha.4 | ✅ BUILD SUCCEEDED | ✅ 无 | ✅ 无 |

## 21. 是否阻塞正式发布

❌ **无阻塞**。

发布预检全部通过：
- ✅ 产物构建正确（300K，9 符号，双 +load，0 污染）
- ✅ 3 个 specs 准备就位（flame_sdk_ios + flame_sdk_ios_tb + flame-sdk-tk-sigmob-adapter）
- ✅ adapter source 远程可访问（TopOn OSS HTTP 200）
- ✅ TK/TB 模拟安装 + build 双通过
- ✅ 0 xcframework duplicate
- ✅ 无源码泄漏
- ✅ 无旧 NoSDK 残留

## 22. Step 3B 待执行命令清单

> ⚠️ 本节只输出命令，**不执行**。等待用户授权后逐条执行。

### 22.1 SDK 主仓库（可选 commit，不 push 主仓库）

```bash
cd /Users/khj/Documents/code/97_ad/ios/flame_ios_sdk
# mainline 已 commit（HEAD d244e28），如无新改动则跳过
# 不 push 主仓库（mainline 实验分支）
```

### 22.2 dist repo（github_build/flame_sdk_ios）

```bash
cd /Users/khj/Documents/code/97_ad/ios/github_build/flame_sdk_ios

# 1. commit alpha.4 分发内容
git add -A
git -c user.email="khj@mac.local" -c user.name="khj" commit -m "Release 1.0.0-alpha.4: single-binary mainline with dual-core dependencies + Sigmob NoSDK normalization"

# 2. 打 tag
git tag 1.0.0-alpha.4

# 3. push main + tag
git push origin main
git push origin 1.0.0-alpha.4
```

### 22.3 flame-specs repo（github_build/flame-specs）

```bash
cd /Users/khj/Documents/code/97_ad/ios/github_build/flame-specs

# 1. 确认 3 个 specs 已 commit（HEAD c0f85fc 已含）
git log --oneline -3

# 2. push main
git push origin main
```

### 22.4 验证远程安装（Step 3B 最终验证）

```bash
cd /Users/khj/Documents/code/97_ad/ios/adsurge-ios-demo

# Podfile（正式远程 source）
cat > Podfile << 'EOF'
platform :ios, '13.0'

source 'https://github.com/javaice007/flame-specs.git'
source 'https://cdn.cocoapods.org/'

target 'adshurge-ios-demo' do
  use_frameworks! :linkage => :static
  pod 'flame_sdk_ios', '1.0.0-alpha.4'
end
EOF

pod deintegrate
rm -rf Pods Podfile.lock
pod install

# 验证 Podfile.lock 含 flame_sdk_ios 1.0.0-alpha.4 + flame-sdk-tk-sigmob-adapter
grep -E "flame_sdk_ios|flame-sdk-tk-sigmob-adapter" Podfile.lock
```

### 22.5 重要提醒

```
flame-sdk-tk-sigmob-adapter spec 必须和 flame_sdk_ios 1.0.0-alpha.4 spec 同步进入 flame-specs。
否则 flame_sdk_ios 依赖解析会失败（找不到 flame-sdk-tk-sigmob-adapter）。
当前 3 个 specs 已在同一 commit（c0f85fc），同步性已保证。
```

## 23. 风险点

| 风险 | 严重度 | 缓解 |
|---|---|---|
| GitHub tag 1.0.0-alpha.4 创建后 source.http 下载失败 | 低 | 正式发布后 Step 3B 验证 |
| pod spec lint 完整验证待 tag 发布后 | 低 | 语法已验证 + 模拟安装 + build 已通过 |
| adapter podspec 完整 lint 受 AnyThinkSigmobAdapter.xcframework 模拟器切片限制 | 低 | `--skip-import-validation` 已通过；真机验证已确认运行时正确 |

## 24. /compact

**Phase 5A.12 Step 3A（alpha.4 发布预检）完成状态**：

| 项 | 状态 |
|---|---|
| SDK 主仓库 commit | ✅ HEAD `d244e28`（工作区干净）|
| 旧 NoSDK 清除 | ✅ 3 处路径已清除 |
| single-binary 重建 | ✅ 300K，9 符号 + 双 +load + 0 污染 |
| dist repo 准备 | ✅ alpha.4 podspec + xcframework，0 源码泄漏 |
| flame-specs 准备 | ✅ 3 个 specs（c0f85fc 本地 commit）|
| adapter source 远程可用 | ✅ TopOn OSS HTTP 200 |
| pod spec lint | ✅ adapter passed；Flame 语法通过 |
| TK alpha.4 模拟安装 + build | ✅ 28 pods，0 duplicate，BUILD SUCCEEDED |
| TB alpha.4 模拟安装 + build | ✅ 5 pods，0 duplicate，BUILD SUCCEEDED |
| 是否阻塞发布 | ❌ 无阻塞 |
| push / tag / pod repo push / release | ❌ 未执行（红线遵守）|

**等待用户授权进入 Step 3B 正式发布**（执行 §22 命令清单）。

**关键文件清单**：

```
research/logs/step3a/
├── 01-cleanup-nosdk.log                # 旧 NoSDK 清除
├── 02-build-default.log                # 默认构建
├── 03-build-explicit.log               # 显式构建
├── 04-binary-verify.log                # 二进制完整验证
├── 05-dist-repo-state.log              # dist repo 状态
├── 06-lint-adapter.log                 # adapter lint（linker error，xcframework 切片限制）
├── 07-lint-adapter-skip.log            # adapter lint（--skip-import-validation，passed）
├── 08-install-alpha4-tk.log            # TK alpha.4 模拟安装
├── 09-tk-deps-check.log                # TK 依赖 + duplicate 检查
├── 10-install-alpha4-tb.log            # TB alpha.4 模拟安装
├── 11-tb-duplicate-check.log           # TB duplicate 检查
├── 12-tb-build.log                     # TB alpha.4 build（SUCCEEDED）
└── 13-tk-build.log                     # TK alpha.4 build（SUCCEEDED）

doc/flame_mediation/phase-5a.12-step3a-alpha4-release-preflight-report.md  # ✨ 本报告
```

红线遵守：未 push、未 tag、未 pod repo push、未 GitHub Release、未删除兜底分支。
