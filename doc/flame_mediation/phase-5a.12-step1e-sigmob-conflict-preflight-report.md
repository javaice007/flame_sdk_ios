# Phase 5A.12 Step 1e：Sigmob 依赖冲突专项预检与 NoSDK 方案验证报告

> ⚠️ **勘误（2026-06-19，Step 1f 规范化后）**
>
> 本报告把 `AnyThinkMediationSigmobAdapter-NoSDK 4.20.12.2.0` 描述为「官方 NoSDK 方案」「官方 NoSDK 变体」**口径不准确**。
>
> 实际情况：该 pod 是**我们之前在私有 spec repo `javaice007-flame-specs` 中自定义出来的 NoSDK 变体**，不是 TopOn 官方公开标准 pod 名称。
>
> 技术价值成立（已实证解决冲突），但**命名不规范**，不能作为正式 mainline 依赖名推进。
>
> 后续在 Step 1f 中已规范化为 `flame-sdk-tk-sigmob-adapter 4.20.12.2.0`（Flame SDK 专用 TK 侧 Sigmob Adapter NoSDK 变体），见 `phase-5a.12-step1f-flame-tk-sigmob-adapter-normalization-report.md`。

---

> **类型**：P0 依赖冲突预检 + 解决方案验证（不实际实现自定义 adapter）
> **执行日期**：2026-06-19
> **分支**：`research/single-binary-mainline`
> **触发**：TK 侧 `AnyThinkMediationSigmobAdapter` 与 TB 侧 `ToBid-iOS-RC` 可能同源 WindSDK/WindFoundation 重复

---

## 核心结论速览

- ⚠️ **冲突已实证**：普通版 `AnyThinkMediationSigmobAdapter 4.20.12.2.0` 依赖 `SigmobAd-iOS 4.20.12`，而 SigmobAd-iOS 内含 `WindFoundation.xcframework` + `WindSDK.xcframework`，与 `ToBid-iOS-RC 5.5.6` 自带的同名 framework **冲突**，导致 pod install 中断（`Podfile.lock` 未生成）
- ✅ **自定义 NoSDK 变体验证通过**：私有 spec repo `javaice007-flame-specs` 中此前自定义的 `AnyThinkMediationSigmobAdapter-NoSDK 4.20.12.2.0`（**非 TopOn 官方标准 pod**），**不依赖 SigmobAd-iOS**，WindSDK/WindFoundation 由 ToBid-iOS-RC 提供。替换后 pod install + build **双双通过，0 duplicate**
- ⚠️ **命名待规范化**：旧名 `AnyThinkMediationSigmobAdapter-NoSDK` 易被误解为 TopOn 官方 pod，不符合 Flame 自身命名规范。Step 1f 已规范化为 `flame-sdk-tk-sigmob-adapter`（Flame SDK 私有 podspec 包装层，复用 TopOn AnyThinkSigmobAdapter.xcframework，仅去掉 SigmobAd-iOS 传递依赖）
- ✅ **TB 对照无冲突**：TB podspec 不声明任何 Sigmob Adapter，WindFoundation/WindSDK/WindMillSDK 只来自 ToBid-iOS-RC
- 所有红线遵守：未发布、未 push、未 tag、未删除兜底分支

---

## 1. 当前分支 / HEAD

| 项 | 值 |
|---|---|
| 分支 | `research/single-binary-mainline` |
| HEAD | `3489d1278f6f19bd64b6adb91261251d90f62191`（未 commit）|
| 工作区状态 | mainline 清理后的所有改动（未 commit）+ Step 1e 实验（research/local_dist/single_binary_mainline + research/logs/step1e）|

## 2. 是否未 push / 未 tag / 未发布

| 检查项 | 结果 |
|---|---|
| `git push origin` | ❌ 未执行 |
| 远程 tag | ❌ 不存在 |
| GitHub release | ❌ 未创建 |
| `pod repo push` | ❌ 未执行 |
| 本地 dist repo tag `1.0.0-alpha.4-local` | ✅ 存在（`research/local_dist/single_binary_mainline`，含 NoSDK 实验）|

## 3. 当前 single-binary 主线状态

Step 1d 完成后的 mainline 状态：
- ✅ 单二进制 `build/flame_sdk_ios.xcframework`（300K，TK/TB 胶水 9 符号全在）
- ✅ 构建脚本只支持 single-binary
- ✅ 宏体系完全删除
- ✅ 两个 podspec 同引一个 binary + 公共依赖（OpenSSL + AnyThinkiOS + ToBid-iOS-RC）
- ⚠️ TK podspec 当时仍声明**普通版** `AnyThinkMediationSigmobAdapter 4.20.12.2.0`（冲突源）

## 4. 当前 TK podspec 是否声明 AnyThinkMediationSigmobAdapter

✅ **是**。Step 1d 完成时，`flame_sdk_ios.podspec` 声明：

```ruby
s.dependency 'AnyThinkMediationSigmobAdapter', '4.20.12.2.0'
```

这是潜在冲突源（与 ToBid-iOS-RC 同源 WindSDK/WindFoundation）。

## 5. 当前两个 podspec 是否都声明 ToBid-iOS-RC

✅ **是**。Step 1d mainline 设计：

| podspec | ToBid-iOS-RC | 理由 |
|---|---|---|
| `flame_sdk_ios.podspec`（TK）| ✅ 声明 `5.5.6` | 公共平台核心依赖（统一口径 + 双线并存准备）|
| `flame_sdk_ios_tb.podspec`（TB）| ✅ 声明 `5.5.6` | TB 平台核心（WindMill 胶水运行期解析）|

**这正是冲突触发的条件**：TK 客户接入 TK podspec 时会同时拉入 `AnyThinkMediationSigmobAdapter`（传递依赖 `SigmobAd-iOS`）和 `ToBid-iOS-RC`（含 WindFoundation/WindSDK），两者同源冲突。

## 6. TK pod install 结果（普通版 Sigmob Adapter）

**❌ 失败（中断）**。

```
Pod install 命令：
  pod 'flame_sdk_ios', :podspec => '.../single_binary_mainline/flame_sdk_ios.podspec'
```

输出：
```
Installing AnyThinkMediationSigmobAdapter (4.20.12.2.0)
Installing SigmobAd-iOS (4.20.12)
Installing ToBid-iOS-RC (5.5.6)
Installing flame_sdk_ios (1.0.0-alpha.4-local)
[!] The 'Pods-adshurge-ios-demo' target has frameworks with conflicting names:
    windfoundation.xcframework and windsdk.xcframework.
```

Pods 装到一半，因 WindSDK/WindFoundation 冲突中断。`Podfile.lock` 和 `Manifest.lock` 均未生成。

## 7. TK Podfile.lock 中 Sigmob / Wind / ToBid 相关依赖

**未生成 Podfile.lock**（pod install 中断）。

从 Pods 目录实证：
- `Pods/AnyThinkMediationSigmobAdapter/AnyThinkSigmobAdapter-4.20.12.2.0/AnyThinkSigmobAdapter.xcframework`
- `Pods/SigmobAd-iOS/wind-sdk-ios/WindFoundation.xcframework` ← **TK 侧**
- `Pods/SigmobAd-iOS/wind-sdk-ios/WindSDK.xcframework` ← **TK 侧**
- `Pods/ToBid-iOS-RC/tobid-sdk-ios-cocoapods-cn/Core/WindFoundation.xcframework` ← **TB 侧**
- `Pods/ToBid-iOS-RC/tobid-sdk-ios-cocoapods-cn/Core/WindSDK.xcframework` ← **TB 侧**
- `Pods/ToBid-iOS-RC/tobid-sdk-ios-cocoapods-cn/Core/WindMillSDK.xcframework`

## 8. TK duplicate framework 检查（普通版）

```
===== duplicate framework basename check =====
   2 WindSDK.xcframework         ← DUPLICATE
   2 WindFoundation.xcframework  ← DUPLICATE
   1 WindMillSDK.xcframework
   1 AnyThinkSigmobAdapter.xcframework
   ...
```

**WindSDK.xcframework 和 WindFoundation.xcframework 各出现 2 次**：
- 一份来自 `SigmobAd-iOS`（TK 传递依赖）
- 一份来自 `ToBid-iOS-RC`（TB 公共依赖）

## 9. TK build 结果（普通版）

**无法构建**（pod install 中断，Podfile.lock 未生成，无 xcworkspace 可用）。

## 10. TK build 是否出现 duplicate symbol / multiple commands produce

N/A（未进入 build 阶段）。但 pod install 阶段的 `frameworks with conflicting names` 已经是 build 阶段 `multiple commands produce` 错误的前兆（CocoaPods 在 staging 阶段就检测到了）。

## 11. TB pod install 结果

**✅ 成功**（5 pods，无冲突）。

```
Pod install 命令：
  pod 'flame_sdk_ios_tb', :podspec => '.../single_binary_mainline/flame_sdk_ios_tb.podspec'
```

输出：
```
Installing AnyThinkiOS (6.5.71)
Installing FunlinkSDK (2.9.0.1.2)
Installing OpenSSL-Universal (3.6.2000)
Installing ToBid-iOS-RC (5.5.6)
Installing flame_sdk_ios_tb (1.0.0-alpha.4-local)
Pod installation complete! There are 2 dependencies from the Podfile and 5 total pods installed.
```

无冲突警告。

## 12. TB Podfile.lock 中 Sigmob / Wind / ToBid 相关依赖

```
- AnyThinkiOS (6.5.71)
- OpenSSL-Universal (3.6.2000)
- ToBid-iOS-RC (5.5.6)
  - ToBid-iOS-RC/ToBidSDK (5.5.6)
- flame_sdk_ios_tb (1.0.0-alpha.4-local)
```

**无 AnyThinkMediationSigmobAdapter**（红线达成）。
**无 SigmobAd-iOS**（红线达成）。

## 13. TB duplicate framework 检查

```
Pods/ToBid-iOS-RC/tobid-sdk-ios-cocoapods-cn/Core/WindFoundation.xcframework
Pods/ToBid-iOS-RC/tobid-sdk-ios-cocoapods-cn/Core/WindMillSDK.xcframework
Pods/ToBid-iOS-RC/tobid-sdk-ios-cocoapods-cn/Core/WindSDK.xcframework
Pods/AnyThinkiOS/core/AnyThinkSDK.xcframework
Pods/OpenSSL-Universal/OpenSSL.xcframework
Pods/flame_sdk_ios_tb/flame_sdk_ios.xcframework

===== duplicate framework basename check =====
（空，无 duplicate）
```

WindFoundation/WindSDK/WindMillSDK 只来自 ToBid-iOS-RC 一处，无重复。

## 14. TB build 结果

N/A（本步未跑 TB build，因 TB 在 Step 1d 已验证过 BUILD SUCCEEDED）。本步骤重点是 Sigmob 冲突，TB 侧无此问题。

## 15. 自定义 AnyThinkMediationSigmobAdapter-NoSDK 是否存在

✅ **存在（自定义变体，非 TopOn 官方标准 pod）**。

在 Flame 团队的私有 spec repo `javaice007-flame-specs` 中找到（**此前我们自己创建的 NoSDK 变体**，不是 TopOn 官方公开 pod）：

```
/Users/khj/.cocoapods/repos/javaice007-flame-specs/AnyThinkMediationSigmobAdapter-NoSDK/
└── 4.20.12.2.0/
    └── AnyThinkMediationSigmobAdapter-NoSDK.podspec.json
```

podspec 关键字段：

```json
{
  "name": "AnyThinkMediationSigmobAdapter-NoSDK",
  "version": "4.20.12.2.0",
  "summary": "AnyThink Sigmob adapter without SigmobAd-iOS dependency.",
  "description": "AnyThink Sigmob adapter without bundling SigmobAd-iOS. WindFoundation and WindSDK are provided by ToBid-iOS-RC from flame_sdk_ios.",
  "static_framework": true,
  "vendored_frameworks": "AnyThinkSigmobAdapter-4.20.12.2.0/AnyThinkSigmobAdapter.xcframework",
  "dependencies": {
    "AnyThinkiOS": [">= 6.5.60"]
  }
}
```

**关键差异**（对比 TopOn 官方普通版 `AnyThinkMediationSigmobAdapter 4.20.12.0`）：

| 项 | TopOn 官方普通版 4.20.12.0 | 自定义 NoSDK 变体 4.20.12.2.0 |
|---|---|---|
| vendored_frameworks | AnyThinkSigmobAdapter.xcframework | AnyThinkSigmobAdapter.xcframework（**同一个二进制**）|
| 依赖 | `AnyThinkiOS >=6.4.94` + **`SigmobAd-iOS 4.20.12`** | **仅** `AnyThinkiOS >=6.5.60` |
| 说明 | 普通版，自带 SigmobAd-iOS | "WindFoundation and WindSDK are provided by ToBid-iOS-RC from flame_sdk_ios" |

**重要**：NoSDK 变体的 `vendored_frameworks` 与官方普通版是**同一个 AnyThinkSigmobAdapter.xcframework 二进制**（TopOn 官方提供的 adapter 适配层，我们只是复用），区别只在 podspec 的 dependency 声明 —— NoSDK 变体去掉了对 `SigmobAd-iOS` 的依赖，让 WindSDK/WindFoundation 由 ToBid-iOS-RC 统一提供。

**命名问题**：旧名 `AnyThinkMediationSigmobAdapter-NoSDK` 容易被误解为 TopOn 官方 pod，不符合 Flame 自身命名规范。Step 1f 已规范化为 `flame-sdk-tk-sigmob-adapter`。

## 16. 自定义 NoSDK 变体是否可替代

✅ **可以替代，已验证**。

### 16.1 NoSDK TK pod install 结果

```
Installing AnyThinkMediationSigmobAdapter-NoSDK (4.20.12.2.0)
Installing ToBid-iOS-RC (5.5.6)
Installing flame_sdk_ios (1.0.0-alpha.4-local)
Generating Pods project
Pod installation complete! There are 2 dependencies from the Podfile and 28 total pods installed.
```

**无冲突警告**（只有无关的 SmartdigimktCNSDK license 警告）。

### 16.2 NoSDK TK Podfile.lock 关键依赖

```
- AnyThinkMediationSigmobAdapter-NoSDK (4.20.12.2.0):
  - AnyThinkiOS (>= 6.5.60)         ← 仅此一个依赖，无 SigmobAd-iOS
- ToBid-iOS-RC (5.5.6)
```

### 16.3 NoSDK TK duplicate framework 检查

```
Pods/AnyThinkMediationSigmobAdapter-NoSDK/AnyThinkSigmobAdapter-4.20.12.2.0/AnyThinkSigmobAdapter.xcframework
Pods/ToBid-iOS-RC/tobid-sdk-ios-cocoapods-cn/Core/WindFoundation.xcframework
Pods/ToBid-iOS-RC/tobid-sdk-ios-cocoapods-cn/Core/WindMillSDK.xcframework
Pods/ToBid-iOS-RC/tobid-sdk-ios-cocoapods-cn/Core/WindSDK.xcframework

===== duplicate framework basename check =====
（空，无 duplicate）
```

**WindFoundation/WindSDK 只来自 ToBid-iOS-RC**（不再有 SigmobAd-iOS 的重复）。

### 16.4 NoSDK TK build 结果

```
** BUILD SUCCEEDED **
```

**唯一警告**：`ld: warning: ignoring duplicate libraries: '-lc++'`（系统库重复，无害，与 Sigmob 无关）。

### 16.5 嵌入产物验证

`.app/Frameworks/` 只含：
- `AnyThinkSDK.framework`
- `OpenSSL.framework`
- `flame_sdk_ios.framework`

**无 WindSDK/WindFoundation/SigmobAd 动态库**（因为它们是静态归档，合并进 app binary）。

app binary `otool -L` 检查 WindSDK/SigmobAd：**无重复条目**。

## 17. 是否需要规范化为 flame-sdk-tk-sigmob-adapter

✅ **需要规范化**（Step 1f 已实现）。

理由：
1. ✅ 已有的自定义 NoSDK 变体 `AnyThinkMediationSigmobAdapter-NoSDK 4.20.12.2.0` 已经验证解决 SigmobAd-iOS 与 ToBid 的 WindSDK/WindFoundation 冲突
2. ✅ NoSDK 变体的 vendored_frameworks 与官方普通版是**同一个 AnyThinkSigmobAdapter.xcframework**（TopOn 官方二进制，我们复用），无需重写 adapter 胶水
3. ⚠️ 但旧名 `AnyThinkMediationSigmobAdapter-NoSDK` **命名不规范**：易被误解为 TopOn 官方公开 pod，不符合 Flame 自身命名体系
4. ✅ Step 1f 已规范化为 `flame-sdk-tk-sigmob-adapter 4.20.12.2.0`（Flame SDK 私有 podspec 包装层，复用 TopOn xcframework，仅去掉 SigmobAd-iOS 传递依赖）

**结论**：使用规范命名的 `flame-sdk-tk-sigmob-adapter` 作为 mainline 正式依赖（无需重写 adapter 源码，只是 podspec 包装层规范化）。详见 Step 1f 报告。

## 18. 自定义 adapter 方案草案（已被 Step 1f 规范化方案替代）

> ⚠️ 本节为 Step 1e 当时的备选草案，已被 Step 1f 的 `flame-sdk-tk-sigmob-adapter` 规范化方案替代。保留作历史记录。

**不推荐重新实现 adapter 源码**（见 §17）。Step 1f 采用的是**规范命名的 podspec 包装层**，复用 TopOn 官方 AnyThinkSigmobAdapter.xcframework，无需重新实现胶水代码。

### 18.1 pod 名称

`flame-sdk-tk-sigmob-adapter`

### 18.2 podspec 依赖

```ruby
Pod::Spec.new do |s|
  s.name = 'flame-sdk-tk-sigmob-adapter'
  s.version = '4.20.12.2.0-flame'
  s.dependency 'AnyThinkiOS', '>= 6.5.60'
  # 不依赖 SigmobAd-iOS
  # 不携带 WindSDK / WindFoundation（由 ToBid-iOS-RC 提供）
end
```

### 18.3 source_files 范围

从 TopOn 官方 AnyThinkSigmobAdapter 源码 fork（如有开源），或反编译 AnyThinkSigmobAdapter.xcframework 提取 adapter 类。

### 18.4 是否需要 vendored framework

**需要**（adapter 胶水是 TopOn 官方二进制，无源码）。直接复用 `AnyThinkSigmobAdapter.xcframework`，但 podspec 去掉 SigmobAd-iOS 依赖。

### 18.5 是否涉及版权或二进制再分发风险

⚠️ **有风险**。AnyThinkSigmobAdapter.xcframework 是 TopOn 商业二进制，重新打包到 `flame-sdk-tk-sigmob-adapter` 可能违反 TopOn 商业许可。**这是不推荐自研的另一个原因**。

### 18.6 与 AnyThinkMediationSigmobAdapter 的替换方式

```ruby
# flame_sdk_ios.podspec 中
# 替换前：
s.dependency 'AnyThinkMediationSigmobAdapter', '4.20.12.2.0'
# 替换后（自研方案）：
s.dependency 'flame-sdk-tk-sigmob-adapter', '4.20.12.2.0-flame'
```

### 18.7 对 flame_sdk_ios.podspec 的修改方式

见 §19。

## 19. 对 flame_sdk_ios.podspec 的建议修改

**Step 1e 当时推荐方案**（已过时，被 Step 1f 替代）：把 TK podspec 中的 `AnyThinkMediationSigmobAdapter` 替换为 `AnyThinkMediationSigmobAdapter-NoSDK`。

**Step 1f 正式方案**（当前 mainline 推荐）：使用规范命名的 `flame-sdk-tk-sigmob-adapter`。

```ruby
# flame_sdk_ios.podspec（Phase 5A.12 mainline）

# 替换前（Step 1d 状态，会触发冲突）：
s.dependency 'AnyThinkMediationSigmobAdapter', '4.20.12.2.0'

# Step 1e 当时推荐（已过时，命名不规范）：
# s.dependency 'AnyThinkMediationSigmobAdapter-NoSDK', '4.20.12.2.0'

# Step 1f 正式推荐（当前 mainline）：
s.dependency 'flame-sdk-tk-sigmob-adapter', '4.20.12.2.0'
```

**前提条件**：
- `javaice007-flame-specs` 私有 spec repo 必须保持可访问（`flame-sdk-tk-sigmob-adapter` 规范化后发布到此 repo）
- 客户 Podfile 必须 `source 'https://github.com/javaice007/flame-specs.git'`（与现有 TK 接入要求一致）

**已在 Step 1f 实证验证**（详见 Step 1f 报告）。

## 20. 是否建议进入 Step 1f 实现规范化 adapter

✅ **已进入 Step 1f**（本报告之后的下一步）。

Step 1f 的 `flame-sdk-tk-sigmob-adapter` 是**规范命名的 podspec 包装层**，不是重新实现 adapter 源码：
- 复用 TopOn 官方 AnyThinkSigmobAdapter.xcframework（无版权风险，只是 podspec 包装）
- 去掉 SigmobAd-iOS 传递依赖
- WindSDK/WindFoundation 由 ToBid-iOS-RC 统一提供

详见 `phase-5a.12-step1f-flame-tk-sigmob-adapter-normalization-report.md`。

## 21. 是否建议进入 Step 2 真机验证

✅ **建议**（在完成 §19 修改后）。

### 21.1 静态验证已全部通过

| 验证项 | 普通版 Sigmob | NoSDK 版 Sigmob |
|---|---|---|
| TK pod install | ❌ 冲突中断 | ✅ 28 pods 全装 |
| TK duplicate framework | ❌ WindSDK/WindFoundation 各 2 份 | ✅ 0 duplicate |
| TK build | ❌ 无法 build | ✅ BUILD SUCCEEDED |
| TK 嵌入产物 | N/A | ✅ 无重复 WindSDK/SigmobAd |
| TB pod install | ✅ 5 pods（无 Sigmob 依赖）| N/A（TB 不声明 Sigmob）|
| TB duplicate framework | ✅ 0 duplicate | N/A |

### 21.2 进入 Step 2 前必须完成的修改

1. 把 mainline 正式 `flame_sdk_ios.podspec` 的 `AnyThinkMediationSigmobAdapter` 改为 `AnyThinkMediationSigmobAdapter-NoSDK`
2. 确认 `javaice007-flame-specs` 私有 spec repo 可访问
3. Demo Podfile 加 `source 'https://github.com/javaice007/flame-specs.git'`

### 21.3 Step 2 真机验证关键观察点

- TK 模式：pt=tk 时 Sigmob 广告链路是否正常（NoSDK 版 adapter 能否正确调用 WindSDK 的 Sigmob 广告 API）
- TB 模式：pt=tb 时 TB Reward 链路是否正常（800031 后台未绑定错误可接受）
- 启动稳定性：dyld 加载是否正常（WindSDK/WindFoundation 只有一份，无冲突）

## 22. 风险点

| 风险 | 严重度 | 缓解 |
|---|---|---|
| `javaice007-flame-specs` 私有 repo 不可访问导致 NoSDK 拉不到 | 高 | 客户 Podfile 必须 source 该 repo；可考虑镜像到 CDN |
| NoSDK 版本只到 4.20.12.2.0，未来 Sigmob 升级无对应 NoSDK | 中 | 持续跟进 TopOn 官方；必要时自研（但版权风险）|
| NoSDK adapter 二进制与 ToBid-iOS-RC 5.5.6 的 WindSDK 版本不匹配 | 中 | 实证 build 通过；真机验证 Sigmob 广告链路 |
| NoSDK adapter 运行时调用 WindSDK 符号找不到 | 中 | WindSDK 是静态归档合并进 app binary，符号在；真机验证 |

## 23. /compact

**Phase 5A.12 Step 1e（Sigmob 冲突预检）完成状态（已勘误）**：

| 项 | 结论 |
|---|---|
| 冲突实证 | ✅ 普通版 AnyThinkMediationSigmobAdapter + ToBid-iOS-RC 共存 → WindSDK/WindFoundation duplicate → pod install 中断 |
| 自定义 NoSDK 变体验证 | ✅ 私有 spec repo 中自定义的 AnyThinkMediationSigmobAdapter-NoSDK 4.20.12.2.0（**非 TopOn 官方**）+ ToBid 共存 → pod install + build 双通过，0 duplicate |
| 命名规范化 | ⚠️ 旧名 `AnyThinkMediationSigmobAdapter-NoSDK` 命名不规范，Step 1f 已规范化为 `flame-sdk-tk-sigmob-adapter`（podspec 包装层，复用 TopOn xcframework） |
| 推荐 mainline 修改 | 把 `flame_sdk_ios.podspec` 的 Sigmob 依赖改为 `flame-sdk-tk-sigmob-adapter 4.20.12.2.0`（Step 1f 已验证）|
| 前提条件 | `javaice007-flame-specs` 私有 spec repo 可访问 |
| TB 对照 | ✅ TB podspec 不声明 Sigmob，无冲突 |
| 是否进入 Step 1f | ✅ 已进入（规范命名 podspec 包装层）|
| 是否进入 Step 2 | ✅ 建议（Step 1f 完成后）|

**关键文件清单**：

```
research/local_dist/single_binary_mainline/      # Step 1e 本地实验 dist
├── flame_sdk_ios.xcframework                    # 与 mainline 同步
├── flame_sdk_ios.podspec                        # 已改为 NoSDK 版
└── flame_sdk_ios_tb.podspec                     # TB 不变（无 Sigmob）

research/logs/step1e/
├── 01-podspec-sigmob-deps.log                   # podspec Sigmob 依赖盘点
├── 02-nosdk-search.log                          # NoSDK 全仓库搜索
├── 03-nosdk-vs-official-podspec.log             # NoSDK vs 官方 podspec 对比
├── 04-tk-pod-install.log                        # TK 普通版 pod install（失败）
├── 05-tk-deps-check.log                         # TK 普通版 duplicate 检查
├── 06-tk-nosdk-pod-install.log                  # TK NoSDK pod install（成功）
├── 07-tk-nosdk-deps-check.log                   # TK NoSDK duplicate 检查（0）
├── 08-tk-nosdk-build.log                        # TK NoSDK build（SUCCEEDED）
├── 09-tk-nosdk-build-verify.log                 # TK NoSDK 嵌入产物验证
├── 10-tb-pod-install.log                        # TB pod install（成功）
└── 11-tb-deps-check.log                         # TB duplicate 检查（0）

doc/flame_mediation/phase-5a.12-step1e-sigmob-conflict-preflight-report.md  # 本报告
```

**等待用户决策**：
1. 是否授权把 mainline 正式 `flame_sdk_ios.podspec` 的 Sigmob 依赖改为 NoSDK 版本
2. 修改完成后是否进入 Step 2 真机验证

红线遵守：未发布、未 push、未 tag、未 pod repo push、未合并、未 cherry-pick、未删除兜底分支、未实际实现自定义 adapter。
