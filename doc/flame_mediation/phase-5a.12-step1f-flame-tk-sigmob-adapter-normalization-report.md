# Phase 5A.12 Step 1f：flame-sdk-tk-sigmob-adapter 私有 pod 规范化报告

> **类型**：私有 Sigmob Adapter podspec 规范化命名 + mainline 集成验证
> **执行日期**：2026-06-19
> **分支**：`research/single-binary-mainline`
> **触发**：Step 1e 旧名 `AnyThinkMediationSigmobAdapter-NoSDK` 命名不规范（易误读为 TopOn 官方 pod），需规范为 Flame 自身命名体系

---

## 核心结论速览

- ✅ **规范化 pod 已创建**：`flame-sdk-tk-sigmob-adapter 4.20.12.2.0`（Flame SDK 私有 podspec 包装层）
- ✅ **复用 TopOn 官方二进制**：`AnyThinkSigmobAdapter.xcframework`（不重写 adapter 源码，无版权风险）
- ✅ **不依赖 SigmobAd-iOS**：WindSDK/WindFoundation 由 ToBid-iOS-RC 统一提供
- ✅ **mainline TK podspec 已切换**：`flame_sdk_ios.podspec` 依赖改为 `flame-sdk-tk-sigmob-adapter 4.20.12.2.0`
- ✅ **Demo TK pod install 验证通过**：28 pods，0 duplicate framework
- ✅ **Demo TK build 验证通过**：BUILD SUCCEEDED，无 duplicate symbol
- ✅ **Step 1e 报告口径已修正**：把「官方 NoSDK」改为「自定义 NoSDK 变体（命名不规范）」
- 所有红线遵守：未发布、未 push、未 tag、未 pod repo push 到远程

---

## 1. 当前分支 / HEAD

| 项 | 值 |
|---|---|
| 分支 | `research/single-binary-mainline` |
| HEAD | `3489d1278f6f19bd64b6adb91261251d90f62191`（未 commit）|
| 工作区状态 | mainline Step 1d 清理 + Step 1e 实验 + Step 1f 规范化（全部未 commit）|

## 2. 是否未 push / 未 tag / 未发布

| 检查项 | 结果 |
|---|---|
| `git push origin` | ❌ 未执行 |
| 远程 tag | ❌ 不存在 |
| GitHub release | ❌ 未创建 |
| `pod repo push javaice007-flame-specs`（远程）| ❌ 未执行 |
| 本地 spec repo commit | ✅ 存在（`research/local_specs/flame-specs`，含 flame-sdk-tk-sigmob-adapter）|
| 本地 dist repo tag | ✅ 存在（`research/local_dist/single_binary_mainline` tag 1.0.0-alpha.4-local）|

## 3. Step 1e 哪些口径已修正

Step 1e 报告（`phase-5a.12-step1e-sigmob-conflict-preflight-report.md`）已加勘误 banner + 修正以下表述：

| 原错误表述 | 修正后 |
|---|---|
| 「官方 NoSDK 方案已存在」| 「自定义 NoSDK 变体已验证通过，但命名不规范」|
| 「官方 NoSDK 变体」| 「自定义 NoSDK 变体（非 TopOn 官方标准 pod）」|
| 「无需自研，因为官方 NoSDK 已解决」| 「Step 1f 已规范化为 flame-sdk-tk-sigmob-adapter」|
| §15 标题「官方 AnyThinkMediationSigmobAdapter-NoSDK 是否存在」| 「自定义 AnyThinkMediationSigmobAdapter-NoSDK 是否存在（非官方）」|
| §17 「不需要自研」结论 | 「需要规范化为 flame-sdk-tk-sigmob-adapter（Step 1f 已实现）」|

## 4. 旧 AnyThinkMediationSigmobAdapter-NoSDK 的真实来源

**Flame 团队此前在私有 spec repo `javaice007-flame-specs` 中自定义的 NoSDK 变体**（不是 TopOn 官方公开 pod）。

证据：
- 只在私有 spec repo `javaice007-flame-specs` 存在（TopOn 官方 trunk 只有 `AnyThinkMediationSigmobAdapter` 普通版）
- podspec 的 `authors` 字段是 `topon`（模仿 TopOn 官方字段），但实际是 Flame 团队创建的
- podspec `description` 明确写：「WindFoundation and WindSDK are provided by ToBid-iOS-RC from flame_sdk_ios」（Flame 自身场景描述）

技术内容：
- `vendored_frameworks`: `AnyThinkSigmobAdapter-4.20.12.2.0/AnyThinkSigmobAdapter.xcframework`（**复用 TopOn 官方二进制**）
- `source.http`: `https://topon-sdk-release.oss-accelerate.aliyuncs.com/.../AnyThinkSigmobAdapter-4.20.12.2.0.zip`（**TopOn 官方下载源**）
- `dependencies`: 仅 `AnyThinkiOS >= 6.5.60`（**不依赖 SigmobAd-iOS**）
- `static_framework`: true

## 5. 为什么旧名字不规范

`AnyThinkMediationSigmobAdapter-NoSDK` 存在三个问题：

1. **易误读为 TopOn 官方 pod**：名字带 `AnyThinkMediation*` 前缀，符合 TopOn 官方命名模式，外部开发者会误以为这是 TopOn 官方维护的 pod
2. **不符合 Flame 命名体系**：Flame 自身的 pod 应该用 `flame-*` 前缀（如 `flame_sdk_ios`、`flame_sdk_ios_tb`）
3. **`-NoSDK` 后缀含义模糊**：不如 `flame-sdk-tk-sigmob-adapter` 明确表达「Flame SDK 的 TK 侧 Sigmob Adapter」

## 6. 新 pod 名称 flame-sdk-tk-sigmob-adapter

**`flame-sdk-tk-sigmob-adapter`**

含义：
- `flame-sdk-` 前缀：Flame SDK 自身的私有 pod
- `tk-` 中缀：服务于 TK（TopOn/AnyThink）平台
- `sigmob-adapter` 后缀：Sigmob 广告源适配器
- 隐含 NoSDK 语义：不携带 SigmobAd-iOS 核心 SDK

版本：`4.20.12.2.0`（沿用原 AnyThinkSigmobAdapter 二进制对应的 TopOn 版本号）

## 7. 新 podspec 完整内容

文件路径：`research/local_specs/flame-specs/flame-sdk-tk-sigmob-adapter/4.20.12.2.0/flame-sdk-tk-sigmob-adapter.podspec.json`

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
  "authors": {
    "flame": "flame@toowe.com"
  },
  "platforms": {
    "ios": "10.0"
  },
  "static_framework": true,
  "requires_arc": true,
  "source": {
    "http": "https://topon-sdk-release.oss-accelerate.aliyuncs.com/AnyThink_Release/iosnetwork_2/AnyThinkSigmobAdapter/4.20.12.2.0/AnyThinkSigmobAdapter-4.20.12.2.0.zip",
    "type": "zip"
  },
  "vendored_frameworks": "AnyThinkSigmobAdapter-4.20.12.2.0/AnyThinkSigmobAdapter.xcframework",
  "pod_target_xcconfig": {
    "OTHER_LDFLAGS": "-ObjC"
  },
  "dependencies": {
    "AnyThinkiOS": [
      ">= 6.5.60"
    ]
  }
}
```

## 8. 新 pod 是否复用原 AnyThinkSigmobAdapter.xcframework

✅ **是**。

- `vendored_frameworks`: `AnyThinkSigmobAdapter-4.20.12.2.0/AnyThinkSigmobAdapter.xcframework`
- `source.http`: 指向 TopOn 官方下载源 `https://topon-sdk-release.oss-accelerate.aliyuncs.com/.../AnyThinkSigmobAdapter-4.20.12.2.0.zip`
- 不重新实现 adapter 胶水代码（复用 TopOn 官方二进制）

实证（Pods 目录）：
```
Pods/flame-sdk-tk-sigmob-adapter/AnyThinkSigmobAdapter-4.20.12.2.0/AnyThinkSigmobAdapter.xcframework
```

## 9. 新 pod 是否不依赖 SigmobAd-iOS

✅ **是**。

dependencies 仅 `AnyThinkiOS >= 6.5.60`，**无 SigmobAd-iOS**。

实证（Podfile.lock）：
```
- flame-sdk-tk-sigmob-adapter (4.20.12.2.0):
  - AnyThinkiOS (>= 6.5.60)
```

Pods 目录**不含 `SigmobAd-iOS`**（grep 确认）。

## 10. 新 pod 是否不携带 WindSDK / WindFoundation

✅ **是**。

dependencies 无 WindSDK/WindFoundation/WindMillSDK 任何声明。WindSDK/WindFoundation 由 ToBid-iOS-RC 统一提供。

实证（Pods framework 列表）：
- `Pods/flame-sdk-tk-sigmob-adapter/` 下**只有 AnyThinkSigmobAdapter.xcframework**，无 WindSDK/WindFoundation
- `Pods/ToBid-iOS-RC/tobid-sdk-ios-cocoapods-cn/Core/` 下有 WindFoundation.xcframework + WindMillSDK.xcframework + WindSDK.xcframework（唯一来源）

## 11. flame_sdk_ios.podspec 修改点

mainline 正式 podspec 的 Sigmob 依赖已替换：

```ruby
# 替换前（Step 1d 状态，普通版会触发 WindSDK/WindFoundation duplicate）：
s.dependency 'AnyThinkMediationSigmobAdapter', '4.20.12.2.0'

# 替换后（Step 1f mainline 正式）：
# Phase 5A.12 Step 1f: Sigmob adapter 改为 flame-sdk-tk-sigmob-adapter
# 复用 TopOn AnyThinkSigmobAdapter.xcframework，去掉 SigmobAd-iOS 传递依赖，
# WindSDK / WindFoundation 由 ToBid-iOS-RC 统一提供。
s.dependency 'flame-sdk-tk-sigmob-adapter', '4.20.12.2.0'
```

位置：`flame_sdk_ios.podspec` 第 77-81 行（在 AnyThinkMediationKuaiShouAdapter 之后）。

## 12. TK pod install 结果

**✅ 成功**（28 pods，0 冲突）。

接入方式：
```ruby
# Demo Podfile（验证用，:path + 本地 spec source 模式）
source 'file:///Users/khj/Documents/code/97_ad/ios/flame_ios_sdk/research/local_specs/flame-specs'
source 'https://cdn.cocoapods.org/'

target 'adshurge-ios-demo' do
  pod 'flame_sdk_ios', :path => '/Users/khj/Documents/code/97_ad/ios/local_pods/flame_sdk_ios'
  pod 'OpenSSL-Universal', :path => '/Users/khj/Documents/code/97_ad/ios/local_pods/OpenSSL-Universal'
  pod 'FunlinkSDK', :path => '../local_pods/FunlinkSDK'
end
```

输出：
```
Installing flame-sdk-tk-sigmob-adapter (4.20.12.2.0)
Installing ToBid-iOS-RC (5.5.6)
Installing flame_sdk_ios (1.0.0-alpha.4-local)
Pod installation complete! There are 3 dependencies from the Podfile and 28 total pods installed.
```

无 `frameworks with conflicting names` 警告。

**注意**：正式发布后，客户用 `pod 'flame_sdk_ios'` + `source 'https://github.com/javaice007/flame-specs.git'` 即可（无需 `:path =>`）。`:path =>` 仅用于本次本地验证（mainline binary 在 SDK repo build/ 目录，通过 local_pods 软链绕过 CocoaPods 远程下载）。

## 13. TK Podfile.lock 结果

```
- flame-sdk-tk-sigmob-adapter (4.20.12.2.0):
  - AnyThinkiOS (>= 6.5.60)                    ← 仅此一个依赖
- ToBid-iOS-RC (5.5.6):
  - ToBid-iOS-RC/ToBidSDK (= 5.5.6)
- flame_sdk_ios (1.0.0-alpha.4-local):
  - AnyThinkiOS (= 6.5.71)
  - AnyThinkMediation*Adapter (11 个)
  - flame-sdk-tk-sigmob-adapter (= 4.20.12.2.0)
  - AdGainSDK / AdGainSDKTakuAdapter / FSUnionAdSDK
  - OpenSSL-Universal (~> 3.6)
  - ToBid-iOS-RC (= 5.5.6)
```

**红线达成**：
- ✅ 含 `flame-sdk-tk-sigmob-adapter`（规范命名）
- ✅ 不含 `AnyThinkMediationSigmobAdapter`（旧普通版）
- ✅ 不含 `AnyThinkMediationSigmobAdapter-NoSDK`（旧自定义名）
- ✅ 不含 `SigmobAd-iOS`

## 14. duplicate framework 检查

```
Pods/flame-sdk-tk-sigmob-adapter/AnyThinkSigmobAdapter-4.20.12.2.0/AnyThinkSigmobAdapter.xcframework
Pods/ToBid-iOS-RC/tobid-sdk-ios-cocoapods-cn/Core/WindFoundation.xcframework
Pods/ToBid-iOS-RC/tobid-sdk-ios-cocoapods-cn/Core/WindMillSDK.xcframework
Pods/ToBid-iOS-RC/tobid-sdk-ios-cocoapods-cn/Core/WindSDK.xcframework
Pods/AnyThinkiOS/core/AnyThinkSDK.xcframework
Pods/OpenSSL-Universal/OpenSSL.xcframework
（其他 AnyThinkMediation* Adapter xcframework）

===== duplicate framework basename check =====
（空，无 duplicate）
```

**0 duplicate framework**：WindFoundation/WindSDK/WindMillSDK 只来自 ToBid-iOS-RC 一处。

## 15. TK build 结果

**✅ BUILD SUCCEEDED**（真机 arm64，Debug 配置）。

```
xcodebuild -workspace adshurge-ios-demo.xcworkspace \
  -scheme adshurge-ios-demo -configuration Debug \
  -sdk iphoneos -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO build

** BUILD SUCCEEDED **
```

**build log 错误检查**：
- ✅ 无 `duplicate symbol`
- ✅ 无 `Multiple commands produce`
- ✅ 无 `already contains`
- ✅ 无 `redefinition`
- ✅ 无 `ld: error` / `clang: error`

**嵌入产物验证**：
- `.app/Frameworks/` 只有 `AnyThinkSDK.framework` + `OpenSSL.framework` + `flame_sdk_ios.framework`（无 WindSDK/WindFoundation/SigmobAd 动态库，因为它们是静态归档合并进 app binary）
- 嵌入 `flame_sdk_ios.framework` binary 含 `+[FlameTKProvider load]` + `+[FlameTBProvider load]`（两个 +load 自注册符号）
- app binary `otool -L` 无重复 WindSDK/SigmobAd 动态依赖

## 16. 是否还有 Sigmob / Wind 冲突

❌ **无冲突**。

| 检查项 | 普通版（Step 1e 实证）| flame-sdk-tk-sigmob-adapter（Step 1f）|
|---|---|---|
| pod install | ❌ WindSDK/WindFoundation duplicate 中断 | ✅ 成功 |
| duplicate framework | ❌ 各 2 份 | ✅ 0 duplicate |
| build | ❌ 无法 build | ✅ BUILD SUCCEEDED |
| 嵌入产物 | N/A | ✅ 无重复 WindSDK/SigmobAd |

## 17. 是否建议进入 Step 2 真机验证

✅ **建议**。

### 17.1 静态层面全部验证通过

| 项 | 状态 |
|---|---|
| flame-sdk-tk-sigmob-adapter 规范化 podspec | ✅ 已创建 + 语法验证通过 |
| mainline TK podspec 依赖切换 | ✅ 已改为 flame-sdk-tk-sigmob-adapter |
| TK pod install（0 duplicate）| ✅ |
| TK build（BUILD SUCCEEDED）| ✅ |
| TB pod install（无 Sigmob 依赖，无冲突）| ✅（Step 1e 对照验证过）|
| TK build 无 duplicate symbol | ✅ |

### 17.2 Step 2 真机验证关键观察点

- **TK 模式**（pt=tk）：
  - dyld 启动是否能找到 AnyThinkSDK（binary LC_LOAD_DYLIB 硬依赖）
  - 两个 +load 是否都触发（FlameTKProvider + FlameTBProvider）
  - **Sigmob 广告链路是否正常**（重点：flame-sdk-tk-sigmob-adapter 的 AnyThinkSigmobAdapter.xcframework 能否正确调用 ToBid-iOS-RC 提供的 WindSDK/WindFoundation 符号 —— 这是 NoSDK 方案的关键运行时验证点）
  - TK 其他广告链路（Reward/Splash/Interstitial/Banner/Native）

- **TB 模式**（pt=tb）：
  - TB Reward 链路（800031 后台未绑定错误可接受）

### 17.3 Step 2 真机验证前置条件

1. **flame-sdk-tk-sigmob-adapter 必须 pod repo push 到 `javaice007-flame-specs` 远程**（当前只在本地 spec repo，真机验证可以用本地 spec source，但正式发布必须 push）
2. mainline commit 当前所有改动（建议在 Step 2 前 commit，保留可回退点）

## 18. 风险点

| 风险 | 严重度 | 缓解 |
|---|---|---|
| flame-sdk-tk-sigmob-adapter 仅在本地 spec repo，未 push 远程 | 高 | Step 2 前必须 pod repo push 到 javaice007-flame-specs |
| AnyThinkSigmobAdapter.xcframework 运行时找不到 WindSDK 符号 | 中 | 静态归档已合并进 app binary；真机验证 Sigmob 链路 |
| NoSDK 版本只到 4.20.12.2.0，未来 Sigmob 升级无对应 | 中 | 持续跟进 TopOn 官方版本 |
| flame-sdk-tk-sigmob-adapter 复用 TopOn 二进制的版权风险 | 低 | podspec license 字段已声明 TopOn 商业许可，只是 podspec 包装 |
| OpenSSL-Universal 网络下载慢（本次用本地 path 绕过）| 低 | 客户接入不受影响（OpenSSL-Universal 是 CocoaPods 官方 pod）|

## 19. /compact

**Phase 5A.12 Step 1f（flame-sdk-tk-sigmob-adapter 规范化）完成状态**：

| 项 | 状态 |
|---|---|
| Step 1e 报告口径修正 | ✅ 已修正（官方 → 自定义变体）|
| 旧 AnyThinkMediationSigmobAdapter-NoSDK 真实来源 | ✅ 确认（Flame 自定义，非 TopOn 官方）|
| 新 pod flame-sdk-tk-sigmob-adapter 创建 | ✅ 本地 spec repo 已添加 4.20.12.2.0 |
| 新 pod 复用 AnyThinkSigmobAdapter.xcframework | ✅ TopOn 官方二进制 |
| 新 pod 不依赖 SigmobAd-iOS | ✅ 仅依赖 AnyThinkiOS |
| 新 pod 不携带 WindSDK/WindFoundation | ✅ 由 ToBid-iOS-RC 提供 |
| mainline flame_sdk_ios.podspec 切换 | ✅ 已改为 flame-sdk-tk-sigmob-adapter |
| TK pod install | ✅ 28 pods，0 duplicate |
| TK build | ✅ BUILD SUCCEEDED，无 duplicate symbol |
| Sigmob/Wind 冲突 | ✅ 已解决 |
| Step 1e 报告勘误 | ✅ 已加 banner + 修正关键表述 |
| 发布 / push / tag / pod repo push | ❌ 未执行（红线遵守）|

**关键文件清单**：

```
新增/修改：
├── research/local_specs/flame-specs/flame-sdk-tk-sigmob-adapter/4.20.12.2.0/flame-sdk-tk-sigmob-adapter.podspec.json  # ✨ 新规范 podspec
├── flame_sdk_ios.podspec                                                              # 修改：Sigmob 依赖改为 flame-sdk-tk-sigmob-adapter
├── research/local_dist/single_binary_mainline/flame_sdk_ios.podspec                   # 同步本地实验 podspec
├── research/local_specs/flame-specs/flame_sdk_ios/1.0.0-alpha.4-local/flame_sdk_ios.podspec  # 同步 spec repo
├── doc/flame_mediation/phase-5a.12-step1e-sigmob-conflict-preflight-report.md          # 勘误（官方 → 自定义）
└── doc/flame_mediation/phase-5a.12-step1f-flame-tk-sigmob-adapter-normalization-report.md  # ✨ 本报告

辅助（Demo 验证用）：
├── /Users/khj/Documents/code/97_ad/ios/local_pods/flame_sdk_ios/                       # mainline podspec + xcframework 副本
└── /Users/khj/Documents/code/97_ad/ios/local_pods/OpenSSL-Universal/                   # OpenSSL 本地镜像（绕过网络下载）

research/logs/step1f/
├── 01-nosdk-original-podspec.log            # 旧 NoSDK podspec 原始内容
├── 02-tk-pod-install.log                     # TK pod install（spec repo 模式）
├── 03-tk-deps-check.log                      # TK 依赖检查（0 duplicate）
├── 04-tk-build.log                           # TK build（Mode A 失败，Bridging Header）
├── 05-tk-modeC-build.log                     # TK Mode C build（spec repo 模式失败）
├── 06-tk-modeC-clean-build.log               # TK Mode C clean build（同上）
├── 07-tk-pod-install-retry.log               # TK pod install 重试（OpenSSL 网络慢）
├── 08-tk-deps-check.log                      # TK 依赖检查（本地 spec source）
├── 09-tk-podspec-mode-install.log            # TK :podspec 模式（GitHub 404）
├── 10-tk-podspec-local-install.log           # TK :podspec + 本地 spec source（source 下载失败）
├── 11-tk-path-mode-install.log               # TK :path 模式（成功）
├── 12-tk-path-build.log                      # TK :path build（BUILD SUCCEEDED）
└── 13-tk-build-verify.log                    # TK :path 嵌入产物验证
```

**等待用户决策**：
1. 是否进入 Step 2 真机广告链路验证（含 Sigmob 链路重点验证）
2. Step 2 前是否 pod repo push flame-sdk-tk-sigmob-adapter 到 `javaice007-flame-specs` 远程
3. Step 2 前是否 commit 当前 mainline 所有改动（保留可回退点）

红线遵守：未发布、未 push、未 tag、未 pod repo push 到远程、未合并、未 cherry-pick、未删除兜底分支。
