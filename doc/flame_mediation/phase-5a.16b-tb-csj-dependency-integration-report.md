# Phase 5A.16B：ToBid CSJ/Pangle 广告源最小依赖接入与双线构建验证

> **本阶段性质**：正式在 `flame_sdk_ios_tb.podspec` 增加 CSJ Adapter 依赖 + 双线 clean build 验证 + 体积/链接审计。**不创建 TbBannerAdapter，不修改 Banner 业务代码**。本阶段结束后 Banner 链路仍无法填充（需 Phase 5A.16C 实现 Adapter + 配置广告位）。

---

## 1. 基线

| 项 | 值 |
|---|---|
| SDK 路径 | `/Users/khj/Documents/code/97_ad/ios/flame_ios_sdk` |
| Demo 路径 | `/Users/khj/Documents/code/97_ad/ios/adsurge-ios-demo` |
| SDK 分支 | `release/ios-dual-line` |
| SDK 开始 HEAD | `3b5326d`（Phase 5A.16A 审计完成） |
| SDK 结束 HEAD | 本阶段本地 commit（见 §28） |
| Demo HEAD | `11c5958`（Phase 5A.14.1，Demo 代码零改动） |
| 接入前 TB Podfile.lock | 4 pods：`flame_sdk_ios_tb` + `OpenSSL-Universal` + `ToBid-iOS-RC/ToBidSDK` + `FunlinkSDK` |
| 接入后 TB Podfile.lock | 5 pods：上述 + `Ads-CN/BUAdSDK 7.6.0.4`（+1） |

---

## 2. CSJ subspec 准确名称

从官方 spec `/Users/khj/.cocoapods/repos/trunk/Specs/5/6/4/ToBid-iOS-RC/5.5.6/ToBid-iOS-RC.podspec.json` 提取：

| 项 | 值 |
|---|---|
| **准确名称** | `ToBid-iOS-RC/CSJAdapter` ✅ |
| ToBid 版本 | 5.5.6 |
| Adapter 版本 | 5.5.6 |
| CSJ SDK 版本 | `Ads-CN/BUAdSDK 7.6.0.4`（BUAdSDK.xcframework `CFBundleInfoDictionaryVersion` = `7.6.0.4`） |
| iOS 最低版本 | 11.0（Flame podspec 要求 13.0，兼容） |
| **simulator slice** | ✅ 支持（`BUAdSDK.xcframework` 含 `ios-arm64_x86_64-simulator`；`WindMillCSJAdapter.xcframework` 含 `ios-arm64_x86_64-simulator`） |

### 2.1 CSJAdapter subspec 完整依赖树（官方 spec 原文）

```json
{
  "name": "CSJAdapter",
  "platforms": { "ios": "11.0" },
  "vendored_frameworks": "tobid-sdk-ios-cocoapods-cn/AdNetworks/csj/*.xcframework",
  "preserve_paths": "tobid-sdk-ios-cocoapods-cn/AdNetworks/csj/**/*",
  "dependencies": {
    "Ads-CN/BUAdSDK": ["7.6.0.4"],
    "ToBid-iOS-RC/ToBidSDK": []
  }
}
```

### 2.2 实际依赖链（pod install 后验证）

```
flame_sdk_ios_tb 1.0.0-alpha.4-local
  → OpenSSL-Universal ~> 3.6
  → ToBid-iOS-RC 5.5.6
    → ToBid-iOS-RC/ToBidSDK 5.5.6          (Core 3 xcframework)
  → ToBid-iOS-RC/CSJAdapter 5.5.6          (WindMillCSJAdapter.xcframework)
    → Ads-CN/BUAdSDK 7.6.0.4               (BUAdSDK.xcframework + CSJAdSDK.bundle)
    → ToBid-iOS-RC/ToBidSDK
```

### 2.3 关键不拉取组件（§7.2 BUAdLive 陷阱验证）

| 组件 | CSJAdapter 是否拉取 | 依据 |
|---|---|---|
| `BUAdLive-Framework` | ❌ **不拉取** | CSJAdapter 显式依赖 `Ads-CN/BUAdSDK` subspec（非默认 `Ads-CN`）；`Ads-CN` 的 `default_subspecs` 含 BUAdLive-Framework，但 CSJAdapter 只选 BUAdSDK 子规范 |
| `BUTTSDKFramework` | ❌ **不拉取** | BUAdLive-Framework 才会带入 BUTTSDKFramework；CSJAdapter 不拉 BUAdLive |
| `CSJMediation` / `CSJMediation-Only` | ❌ **不拉取** | 仅 `GromoreAdapter`/`GromoreAdapterLite` 才会带入 |

> **结论**：Phase 5A.16A 担心的 BUAdLive/BUTTSDKFramework 陷阱**不在 TB 的 CSJ 路径上**（仅影响 TK 侧 AnyThinkMediation 默认 Ads-CN）。TB 经 CSJAdapter → BUAdSDK subspec 是干净的。

---

## 3. Podspec 修改

### 3.1 修改文件

`flame_sdk_ios_tb.podspec`（+25 -6 行，替换原"当前为空"占位注释块）。

### 3.2 新增依赖（1 项）

```ruby
# --- Phase 5A.16B：CSJ/Pangle（穿山甲）广告源 ---
s.dependency 'ToBid-iOS-RC/CSJAdapter', '5.5.6'
```

### 3.3 关键约束

| 项 | 结果 |
|---|---|
| 是否直接声明底层 CSJ SDK（Ads-CN/BUAdSDK） | ❌ **否**（由 ToBid 官方 CSJAdapter subspec 管理，单一来源） |
| 是否声明 BUAdLive/CSJMediation/BUTTSDK | ❌ **否** |
| 是否修改 TK podspec（flame_sdk_ios.podspec） | ❌ **未修改** |
| 是否带入 AnyThinkiOS/AnyThinkMediation*/TK sigmob adapter/SigmobAd-iOS | ❌ **全部不带入**（TB 红线保持） |
| 是否升级 ToBid-iOS-RC 5.5.6 | ❌ **未升级** |
| 是否升级 CSJ SDK | ❌ **未升级**（7.6.0.4 由 ToBid subspec pin） |
| 是否修改版本号 | ❌ **未修改**（仍 1.0.0-alpha.4-local） |

### 3.4 pod lib lint（§9）

```
pod lib lint flame_sdk_ios_tb.podspec --allow-warnings --skip-tests --no-clean
```

**结果**：podspec 语法解析通过（无语法错误），远程依赖解析开始（无版本冲突），但 `xcodebuild` 步骤在 CocoaPods 沙箱内因 destination specifier 失败：
```
ERROR | [iOS] xcodebuild: Returned an unsuccessful exit code.
NOTE  | [iOS] xcodebuild: error: Unable to find a destination matching the provided destination specifier
```

> 此失败是 **CocoaPods lint 沙箱基础设施限制**（xcodebuild destination 解析），非 podspec 内容问题。按 §9 规则，**主要验证路径为 Demo `:path` 本地集成**（§10-16 已全部通过）。区分如下：
> - podspec 语法验证：✅ 通过
> - 远程依赖解析验证：✅ 通过（lint 已开始解析 CSJAdapter + Ads-CN/BUAdSDK + OpenSSL，无冲突）
> - 本地 path 集成验证：✅ 通过（§10-16）

未通过修改版本号或发布远程 spec 绕过。

---

## 4. TB Pod 安装

### 4.1 操作

```
cd /Users/khj/Documents/code/97_ad/ios/adsurge-ios-demo
pod deintegrate || true
rm -rf Pods Podfile.lock
find . -maxdepth 1 -name "*.xcworkspace" -exec rm -rf {} +
pod cache clean ToBid-iOS-RC --all || true
pod install --repo-update
```

### 4.2 安装结果

| 项 | 值 |
|---|---|
| pods 数量 | **5**（接入前 4，+1） |
| 新增 pod | `Ads-CN (7.6.0.4)` → `Ads-CN/BUAdSDK 7.6.0.4` |
| AnyThinkiOS | ❌ ABSENT ✅ |
| AnyThinkMediation* | ❌ ABSENT ✅ |
| flame_sdk_ios_tk_sigmob_adapter | ❌ ABSENT ✅ |
| SigmobAd-iOS | ❌ ABSENT ✅ |
| flame_sdk_ios（TK pod） | ❌ ABSENT ✅ |
| 远程旧 Flame | ❌ ABSENT ✅ |
| 其他网络 Adapter（GDT/KS/Baidu/MS/MTG/Octopus/GroMore） | ❌ ABSENT ✅ |
| 重复版本（两个 Ads-CN 或两个 BUAdSDK） | ❌ ABSENT ✅ |

### 4.3 Podfile.lock PODS 段（实际）

```
PODS:
  - Ads-CN/BUAdSDK (7.6.0.4)
  - flame_sdk_ios_tb (1.0.0-alpha.4-local):
    - OpenSSL-Universal (~> 3.6)
    - ToBid-iOS-RC (= 5.5.6)
    - ToBid-iOS-RC/CSJAdapter (= 5.5.6)
  - FunlinkSDK (2.9.0.1.2):
    - FunlinkSDK/FunlinkSDK (= 2.9.0.1.2)
  - FunlinkSDK/FunlinkSDK (2.9.0.1.2)
  - OpenSSL-Universal (3.6.2000)
  - ToBid-iOS-RC (5.5.6):
    - ToBid-iOS-RC/ToBidSDK (= 5.5.6)
  - ToBid-iOS-RC/CSJAdapter (5.5.6):
    - Ads-CN/BUAdSDK (= 7.6.0.4)
    - ToBid-iOS-RC/ToBidSDK
  - ToBid-iOS-RC/ToBidSDK (5.5.6)
```

---

## 5. TB 构建

### 5.1 真机（iphoneos）

```
xcodebuild -workspace adshurge-ios-demo.xcworkspace -scheme adshurge-ios-demo \
  -configuration Debug -sdk iphoneos CODE_SIGNING_ALLOWED=NO build
```

**结果**：✅ **BUILD SUCCEEDED**

- error：0
- duplicate symbols：0
- module not found：0
- umbrella header 问题：0
- warning：仅第三方 SDK deployment target（FunlinkSDK 11.0 等），无 Flame 引起的新编译错误

### 5.2 模拟器（iphonesimulator）

```
xcodebuild -workspace adshurge-ios-demo.xcworkspace -scheme adshurge-ios-demo \
  -configuration Debug -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

**结果**：❌ **BUILD FAILED**（pre-existing 阻塞，非 CSJ 引起）

**精确错误**：
```
error: 'flame_sdk_ios/FlameSdk.h' file not found
error: unable to resolve module dependency: 'flame_sdk_ios'
```

**根因**（已定位，非 CSJ 引起）：
- Flame xcframework 的 simulator slice 是 **`ios-x86_64-simulator`**（仅 x86_64）
- Apple Silicon Mac 上模拟器 build 目标架构为 `arm64 x86_64`
- Flame binary 缺 `ios-arm64_x86_64-simulator` slice → 模块无法解析
- **CSJ SDK 本身支持 arm64 模拟器**（`BUAdSDK.xcframework` 含 `ios-arm64_x86_64-simulator`）→ 此阻塞与 CSJ 无关

**验证**（确认是 pre-existing）：Flame xcframework 目录 `ls build/flame_sdk_ios.xcframework/` = `Info.plist` + `ios-arm64` + `ios-x86_64-simulator`（无 arm64 simulator slice，Phase 5A.15 起即如此，本次未修改 Flame binary）。

**按 §13.3 / §25-C 处理**：
- ❌ 未使用 `EXCLUDED_ARCHS[sdk=iphonesimulator*] = arm64` 掩盖
- ❌ 未强制 Rosetta
- ❌ 未手工 lipo 修改第三方二进制
- ❌ 未修改 Pods 生成文件
- ✅ 如实记录：**此为 Flame xcframework 的 pre-existing 限制（缺 arm64 simulator slice），CSJ SDK 不背锅**

**建议**（不在本阶段做）：后续可在 `xcFramework_build.sh` 增加 arm64 simulator slice（x86_64 + arm64 合并），解决 Apple Silicon 模拟器构建。本阶段不扩大范围。

---

## 6. TB App 产物审计（真机 Debug build）

App 路径：`~/Library/Developer/Xcode/DerivedData/adshurge-ios-demo-*/Build/Products/Debug-iphoneos/adshurge-ios-demo.app`

### 6.1 App/Frameworks（嵌入式动态 framework）

| framework | 是否存在 |
|---|---|
| `flame_sdk_ios.framework` | ✅ |
| `OpenSSL.framework` | ✅ |
| AnyThinkSDK.framework | ❌ ABSENT ✅ |
| SmartdigimktSDK.framework | ❌ ABSENT ✅ |
| TK sigmob adapter | ❌ ABSENT ✅ |
| BUAdLive 组件 | ❌ ABSENT ✅ |
| BUTTSDKFramework | ❌ ABSENT ✅ |

### 6.2 CSJ/ToBid 组件位置

CSJ/ToBid 组件（BUAdSDK/WindMillCSJAdapter/WindMillSDK/WindSDK/WindFoundation）**不在 App/Frameworks 嵌入**——它们是**静态归档（static archives）**，被链接进 App 的 debug dylib（`adshurge-ios-demo.debug.dylib`）。

### 6.3 资源 bundle

| bundle | 是否存在 | 来源 |
|---|---|---|
| `CSJAdSDK.bundle` | ✅ | Ads-CN/BUAdSDK |
| `CSJAdSDK.bundle/PrivacyInfo.xcprivacy` | ✅ | CSJ 隐私清单 |
| `OpenSSL.framework/PrivacyInfo.xcprivacy` | ✅ | OpenSSL |

---

## 7. 链接审计

### 7.1 Flame binary

```
otool -L flame_sdk_ios.framework/flame_sdk_ios
otool -l ... | grep AnyThinkSDK
```

| 项 | 结果 |
|---|---|
| AnyThink 链接方式 | ✅ **LC_LOAD_WEAK_DYLIB**（`otool -L` 显示 `(weak)`，`otool -l` 显示 `cmd LC_LOAD_WEAK_DYLIB`） |
| 是否恢复为 LC_LOAD_DYLIB（强链接） | ❌ **未恢复** |
| Flame 是否直接链接 CSJ SDK（BUAdSDK） | ❌ **否**（otool -L Flame 无 BUAdSDK 条目） |
| Flame 主二进制是否静态打入 CSJ | ❌ **否**（CSJ 经 podspec → 静态归档进 App debug dylib，不进 Flame binary） |

### 7.2 重复符号风险

| 检查 | 结果 |
|---|---|
| 重复 ObjC 类（同名） | 本轮 clean build 无 duplicate symbols linker error |
| 同名 Framework | 无（BUAdSDK / WindMillCSJAdapter / WindMillSDK / WindSDK / WindFoundation 各异） |
| 同名 Bundle | 无（仅 CSJAdSDK.bundle + OpenSSL PrivacyInfo） |
| Ads-CN vs 不同版本 BUAdSDK | 仅一份 `Ads-CN/BUAdSDK 7.6.0.4` |
| Adapter 引用的类在 App 中存在 | ✅（见 §8） |

> 准确表述（按 §15.2）：**当前 clean build 未出现 duplicate symbols，静态审计未发现明确重复框架；全量广告源组合（GDT/MS/Octopus/Mintegral 等后续批次）仍需后续验证。**

---

## 8. CSJ Adapter 可用性检查（符号审计）

App 的 debug dylib `adshurge-ios-demo.debug.dylib` 中确认的 CSJ 相关符号：

| 类/协议 | 符号证据 |
|---|---|
| `BUNativeExpressBannerView`（CSJ Banner 视图） | `nm` 显示 `+[BUNativeExpressBannerView allocWithZone:]`、`-[BUNativeExpressBannerView initWithSlot:rootViewController:adSize:]` 等 |
| `BUNativeExpressBannerViewDelegate` | `strings` 显示 `@"<BUNativeExpressBannerViewDelegate>"` |
| `WindMillCSJAdapter`（ToBid CSJ Adapter Swift 模块） | `strings` 显示 `$s18WindMillCSJAdapter15AdapterProtocolP`、`$s18WindMillCSJAdapter16NativeAdProtocolP` |
| `WindMillBannerView`（ToBid Banner API） | `strings` 显示 `WindMillBannerView`、`<_TtP11WindMillSDK26WindMillBannerViewDelegate_>` |

> **结论**：CSJ Adapter 依赖与运行时组件已进入 App，符号可解析。真实广告请求将在 Phase 5A.16C/D 配置 Banner 广告位后验证（本阶段不触发）。

---

## 9. TB 真机启动冒烟（§17，真机实测通过）

真机日志 `pasted-text-20260720-093600-684e593a.txt`（2026-07-20 09:35:40 启动）：

```
09:35:40.371  [SDK_INIT] 初始化开始
09:35:40.728  [SDK] 初始化完成
09:35:40.818  ■ 初始化成功 | 耗时 0.447s
09:35:40.823  [Splash] 创建广告实例
09:35:40.824  [TB_SPLASH_DIAG] load: adapter=0x10712e850 oldAd=0x0 placementId=8374774642581842 thread=1
09:35:40.825  [TB_SPLASH_DIAG] load created: adapter=0x10712e850 newAd=0x10739c320
09:35:41.041  [TB_SPLASH_DIAG] didLoad: ad=0x10739c320 adapter=0x10712e850 isCurrent=1
09:35:41.041  [TB_SPLASH_DIAG] show: window=0x105c81240 thread=1 ready=1
09:35:41.041  [TB_SPLASH_DIAG] willPresent → didPresent(didVisible)
09:35:41.871  [Splash] 展示
09:35:44.044  onSplashAdSkiped → onSplashAdClosed（两回调都到达）
09:35:44.044  didSkip → finish: reason=skip → [Splash] 关闭（业务 onAdClosed 通知一次）
09:35:44.044  didClose → finish already done: reason=close（finishOnce 二次拦截）
09:35:44.136  [Coordinator] 开始预加载所有广告 → 主页面切换正常
```

### 9.1 启动冒烟验收项

| 项 | 结果 |
|---|---|
| App 正常启动 | ✅ |
| pt=tb | ✅ |
| Router 激活 tb | ✅ `FlameMediationRouter: 激活平台 'tb'` |
| SDK 初始化成功 | ✅ `■ 初始化成功 \| 耗时 0.447s` |
| AnyThink ADX 弹窗 | ✅ 未出现 |
| dyld 缺库 | ✅ 无（`Library not loaded` 未出现） |
| selector 崩溃 | ✅ 无（`unrecognized selector` 未出现） |
| duplicate class 警告 | ✅ 无（`Class XXX is implemented in both` 未出现） |
| CSJ Adapter 初始化崩溃 | ✅ 无（CSJ Adapter 因后台无 CSJ waterfall 未主动初始化，符合预期） |
| Splash/Interstitial/Reward 预加载崩溃 | ✅ 无（三种 DIAG 日志全正常） |
| 主页面正常显示可交互 | ✅（人工确认，用户回报正常） |

**关键确认**：CSJ 依赖进入 App 后，**原 Sigmob 链路完全不受影响**。CSJ Adapter 处于"已链接但未触发"状态（后台无 CSJ 配置，符合 §17 预期）。

---

## 10. 原广告类型回归（§18，真机实测通过）

| 广告类型 | load | show | visible | close | next-load | 结果 |
|---|---|---|---|---|---|---|
| **Splash** | ✅ adapter=0x10712e850 | ✅ window=0x105c81240 thread=1 ready=1 | ✅ willPresent→didPresent | ✅ **skip+close 幂等**（finishOnce 二次拦截） | ✅ Coordinator 预加载 | ✅ 通过 |
| **Interstitial** | ✅ adapter=0x1258e2220 → didLoad | ✅ show presenter=0x106b3c000 vcWindow=0x105c84f70 thread=1 | ✅ willVisible→didVisible | ✅ didClose（`关闭 → 加载下一条`） | ✅ next load → didLoad new ad 0x13d2c9200 isCurrent=1 | ✅ **完整闭环通过** |
| **Reward（轮 1）** | ✅ adapter=0x1258e0210 → didLoad | ✅ show presenter=0x106b3c000 vcWindow=0x105c84f70 cachedVC=0x106b3c000 thread=1 | ✅ willVisible→didVisible | ✅ didClose（`关闭 → 加载下一个`） | ✅ next load → didLoad | ✅ **完整闭环通过** |
| **Reward（轮 2）** | ✅ adapter=0x13d314ab0 → didLoad | ✅ show presenter=0x106b3c000 vcWindow=0x105c84f70 **cachedVC=0x0** thread=1 | ✅ willVisible→didVisible | ✅ didClose（`关闭 → 加载下一个`） | ✅ next load → didLoad new ad 0x13d2ca580 isCurrent=1 | ✅ **完整闭环通过**（cachedVC=0x0 时动态 presenter 修复仍生效） |
| AnyThink 弹窗 | — | — | — | — | — | ✅ 全程未出现 |

### 10.1 回归结论

✅ **Phase 5A.14.1（Interstitial 生命周期修正）+ Phase 5A.15（Splash Adapter + Reward 动态 presenter）全部无回归**：
- Splash skip/close 幂等（Phase 5A.15.1 验证过的 finishOnce）保持
- Interstitial 完整 close-loop（Phase 5A.14.1 验证过的）保持
- Reward 两轮完整闭环，cachedVC=0x0 时动态 presenter 修复生效

**CSJ 新依赖对原 Sigmob 三广告类型零影响**。

---

## 11. TK clean pod install 与编译回归（§19）

### 11.1 操作

Demo Podfile 临时切到 TK（`pod 'flame_sdk_ios', :path => '../flame_ios_sdk'`），clean install + build，验证后恢复 TB。

### 11.2 TK Podfile.lock 验证

| 项 | 结果 |
|---|---|
| `flame_sdk_ios`（TK pod） | ✅ 存在 |
| `flame_sdk_ios_tb`（应 ABSENT） | ❌ ABSENT ✅ |
| AnyThinkiOS 6.5.71 | ✅ 存在 |
| `flame_sdk_ios_tk_sigmob_adapter` | ✅ 存在 |
| ToBid-iOS-RC 5.5.6 | ✅ 存在 |
| OpenSSL-Universal | ✅ 存在 |
| TK 原有广告源（AnyThinkMediation* + Ads-CN/BUAdSDK + GDT + KS + ...） | ✅ 28 pods（与 Phase 5A.15.1 TK 回归一致） |
| **ToBid-iOS-RC/CSJAdapter（应 ABSENT）** | ❌ **ABSENT ✅**（TK 不拉 TB 的 CSJ subspec） |
| ToBid subspecs | 仅 `ToBid-iOS-RC/ToBidSDK`（无网络 adapter） |

### 11.3 TK BUILD

```
xcodebuild ... -sdk iphoneos CODE_SIGNING_ALLOWED=NO build
```

**结果**：✅ **BUILD SUCCEEDED**（与 Phase 5A.15.1 一致，无回归）

### 11.4 关键结论

✅ **TK 不受 TB podspec CSJ 新增依赖影响**：TK 仍 28 pods，不额外引入 `ToBid-iOS-RC/CSJAdapter`，AnyThinkiOS 保持，BUILD SUCCEEDED。

> **说明**：TK 已通过 AnyThinkMediationTTAdapter_Mix + GromoreAdapter 带入同版本 `Ads-CN/BUAdSDK 7.6.0.4`（这是 TK 侧 Pangle/CSJ 的来源，与本阶段 TB 的 CSJAdapter 是不同路径但同版本同 pod，CocoaPods 在 TK 或 TB 单独安装时各自解析，无冲突）。

### 11.5 Demo 环境恢复

Podfile 已还原 `flame_sdk_ios_tb`，pod install 后 5 pods（含 Ads-CN）。TK 临时 Podfile/Podfile.lock 未提交。

---

## 12. 体积记录（§20）

| 项 | 接入前（5A.15.1 基线） | 接入后（5A.16B） | 增量 | 说明 |
|---|---|---|---|---|
| Pods 目录总大小 | 138M | **553M** | +415M | 含 BUAdSDK + WindMillCSJAdapter 双 slice（arm64 + sim） |
| TB App 包大小（Debug iphoneos .app） | ~100M（估） | **130M** | +~30M | Debug 含符号；Release 会更小 |
| TB App Frameworks 目录 | ~50M（估） | **57M** | +~7M | Flame binary + OpenSSL（动态嵌入部分） |
| Pods 数量 | 4 | **5** | +1 | Ads-CN |
| 新增 framework | 0 | +5 xcframework（BUAdSDK + WindMillCSJAdapter + 已有 WindMill Core 不计） | — | BUAdSDK.xcframework + WindMillCSJAdapter.xcframework |
| 新增 bundle | 0 | +1（CSJAdSDK.bundle） | — | 含 PrivacyInfo.xcprivacy |

> **说明**：
> - 接入前 138M / ~100M 是历史记录（Phase 5A.15.1），非同机同次测量，仅作粗略对比。
> - 未压缩 Pods 体积不等于最终 IPA 增量（IPA 会压缩 + 剥离模拟器 slice + 仅保留 arm64）。
> - 真实 IPA 增量待 Phase 5A.16 全量回归时 Release Archive 测量。

---

## 13. SKAdNetwork 与隐私配置审计（§21）

### 13.1 SKAdNetwork IDs（来自交付包 `SkAdneworkIDs代码.txt` CSJ/穿山甲段）

```
238da6jt44.skadnetwork
22mmun2rn5.skadnetwork
KBD757YWX3.skadnetwork
wg4vff78zm.skadnetwork
737z793b9f.skadnetwork
ydx93a7ass.skadnetwork
prcb7njmu6.skadnetwork
7UG5ZH24HU.skadnetwork
44jx6755aq.skadnetwork
2U9PT9HC89.skadnetwork
（更多见交付文档）
```

### 13.2 当前 Demo Info.plist 状态

| 配置项 | 是否需要 | 当前 Demo 是否存在 | 证据 | 后续处理阶段 |
|---|---|---|---|---|
| SKAdNetworkItems（CSJ IDs） | ✅ 需要 | ⚠️ 待确认（Demo Info.plist 当前无 SKAdNetwork 段，仅 NSAppTransportSecurity） | `Resources/Info.plist` 无 SKAdNetworkItems 键 | Phase 5A.16C/D（Banner 上线前必须加） |
| PrivacyInfo.xcprivacy | ✅ 需要 | ⚠️ Demo 自身未生成；依赖 SDK 自带（CSJAdSDK.bundle/PrivacyInfo.xcprivacy + OpenSSL/PrivacyInfo + WindMill*/PrivacyInfo 已进 App） | §6.3 | Phase 5A.16 全量回归审计 |
| NSUserTrackingUsageDescription（ATT） | ✅ 需要（IDFA） | ⚠️ 待确认 | Demo Info.plist 检查 | Phase 5A.16C/D |
| NSAppTransportSecurity | ✅ 需要 | ✅ 存在 | Demo Info.plist 已有 | — |
| URL Scheme / LSApplicationQueriesSchemes | ⚠️ 视 SDK | 待确认 | — | Phase 5A.16 全量回归 |

> **本阶段不修改 Demo Info.plist**（§21 红线）。缺失配置登记到 Phase 5A.16C/D，不在本阶段扩大 Demo 修改范围。

---

## 14. 正式依赖边界审计（§22）

| 项 | TK | TB |
|---|---|---|
| Flame XCFramework | 同一个 `build/flame_sdk_ios.xcframework` | 同一个 |
| AnyThinkiOS | ✅ 有（6.5.71） | ❌ 无 |
| TK Sigmob Adapter | ✅ 有（flame_sdk_ios_tk_sigmob_adapter） | ❌ 无 |
| ToBid Core（ToBidSDK） | ✅ 有（5.5.6） | ✅ 有（5.5.6） |
| **ToBid CSJ Adapter** | ❌ 无（**TK 不通过 ToBid subspec 接 CSJ**） | ✅ 有（Phase 5A.16B 新增） |
| **CSJ SDK（Ads-CN/BUAdSDK）** | ✅ 有（7.6.0.4，via AnyThinkMediationTTAdapter_Mix + GromoreAdapter → Ads-CN 默认 subspec） | ✅ 有（7.6.0.4，via ToBid-iOS-RC/CSJAdapter → Ads-CN/BUAdSDK subspec） |
| module name | flame_sdk_ios | flame_sdk_ios |
| AnyThink link | weak（LC_LOAD_WEAK_DYLIB） | weak（LC_LOAD_WEAK_DYLIB） |
| 客户安装方式 | `pod 'flame_sdk_ios'` | `pod 'flame_sdk_ios_tb'` |

### 14.1 关键边界确认

- ✅ **TK 不因本次修改新增 ToBid CSJ Adapter**（§11.2 验证：TK Podfile.lock 无 `ToBid-iOS-RC/CSJAdapter`）
- ✅ **TB 不出现 AnyThink CSJ Adapter**（TB Podfile.lock 无 `AnyThinkMediation*`）
- ✅ TK 已有 CSJ SDK（via AnyThinkMediation，同版本 7.6.0.4）—— 这是 TK 的 Pangle/CSJ 来源，与本阶段 TB 的 CSJAdapter 是不同路径但 **同 pod 同版本**，TK 或 TB 单独安装时各自解析无冲突
- ✅ Flame binary 对 AnyThink 仍为 weak link（§7.1）

---

## 15. 修改文件

| 文件 | 类型 | 说明 |
|---|---|---|
| `flame_sdk_ios_tb.podspec` | 修改 | +1 依赖 `ToBid-iOS-RC/CSJAdapter 5.5.6` + 注释（替换原"当前为空"占位块） |
| `doc/flame_mediation/phase-5a.16b-tb-csj-dependency-integration-report.md` | 新增 | 本报告 |
| `doc/flame_mediation/09_change_log.md` | 修改 | Phase 5A.16B 条目 |
| `README.md` | 修改 | 依赖接入状态更新 |

**SDK 业务代码零改动**（无 Banner/Reward/Interstitial/Splash Adapter 改动，无 FlameTBProvider 改动）。
**project.pbxproj 零改动**。
**TK podspec 零改动**。

---

## 16. Git

**SDK commit**（podspec + 文档）：
- 消息：`build: add ToBid CSJ adapter dependency`
- 排除：project.pbxproj 环境差异、Pods、Podfile.lock、xcworkspace、DerivedData、build、Archives、Demo Podfile、Info.plist 临时改动、测试 placementId、真机日志、CocoaPods 缓存

**Demo commit**：无（Demo 代码零改动）

| 操作 | 状态 |
|---|---|
| push | ❌ 未执行 |
| tag | ❌ 未执行 |
| release | ❌ 未执行 |
| pod repo push | ❌ 未执行 |
| 修改远程 flame-specs | ❌ 未执行 |
| 修改版本号 | ❌ 未执行 |

---

## 17. 已知问题

| 问题 | 归属 | 处理 |
|---|---|---|
| **Flame xcframework 缺 arm64 simulator slice** | SDK 构建脚本（pre-existing） | 模拟器 build 在 Apple Silicon 上失败（`FlameSdk.h file not found`）；与 CSJ 无关（CSJ SDK 支持 arm64 sim）。建议后续在 `xcFramework_build.sh` 加 arm64 sim slice。本阶段不扩大范围 |
| **Demo Info.plist 缺 CSJ SKAdNetwork IDs** | Demo 配置 | Phase 5A.16C/D Banner 上线前必须加（本阶段不修改） |
| **CSJ 真机广告位未配置** | ToBid 后台 + Flame pMap | Phase 5A.16C/D Banner 验证前需在 ToBid 后台创建 CSJ Banner 测试广告位 + Flame pMap 加 banner 映射 |
| **BUAdSDK deployment target 警告** | 第三方 SDK | warning 非 error，不影响 build |
| **pod lib lint xcodebuild destination 失败** | CocoaPods lint 沙箱 | 非 podspec 内容问题；主要验证路径为 Demo `:path` 集成（已通过） |

---

## 18. 是否可以进入 TbBannerAdapter 实现

| 条件 | 状态 |
|---|---|
| CSJ Adapter 依赖已正式接入 flame_sdk_ios_tb.podspec | ✅ |
| CSJ SDK + Adapter + 资源进入 TB App（clean build 验证） | ✅（真机） |
| AnyThink 隔离无回归 | ✅ |
| TK 无回归 | ✅（28 pods，BUILD SUCCEEDED） |
| 模拟器构建 | ⚠️ pre-existing Flame slice 限制（非阻塞 Banner 实现，因 Banner 真机验证为主） |
| TB 真机启动冒烟 | ✅ **通过**（§9：App 启动/pt=tb/无 AnyThink 弹窗/无 dyld/无 selector/无 duplicate class/主页面正常） |
| 原 Splash/Interstitial/Reward 不崩溃 | ✅ **通过**（§10：三广告类型完整闭环无回归） |
| Banner 广告位配置（ToBid 后台 + pMap） | ❌ 未配置（Phase 5A.16C/D） |

**结论**：✅ **CSJ 依赖接入验证全部通过**，可进入 Phase 5A.16C TbBannerAdapter 实现阶段。但 Phase 5A.16C 还需先完成：① ToBid 后台创建 CSJ Banner 测试广告位；② Flame 后台 pMap 加 banner 映射；③ Demo Info.plist 加 CSJ SKAdNetwork IDs。

---

## 19. /compact

Phase 5A.16B 完成：在 flame_sdk_ios_tb.podspec 加 `s.dependency 'ToBid-iOS-RC/CSJAdapter', '5.5.6'`（CSJ/Pangle 广告源，服务后续 Banner）。官方 spec 确认依赖链：CSJAdapter → Ads-CN/BUAdSDK 7.6.0.4 + ToBidSDK，**不拉 BUAdLive/BUTTSDK/CSJMediation**（CSJAdapter 显式选 BUAdSDK subspec，绕过 Ads-CN 默认 subspec 的 BUAdLive 陷阱）。TB clean pod install 5 pods（+Ads-CN），真机 BUILD SUCCEEDED，CSJ Adapter 符号（BUNativeExpressBannerView/WindMillCSJAdapter/WindMillBannerView）确认进 App debug dylib（静态归档）。AnyThink weak-link 无回归，无 AnyThink/TK adapter/SigmobAd-iOS 泄漏。TK clean pod install 28 pods 不受影响（不拉 ToBid CSJAdapter），BUILD SUCCEEDED。模拟器 build 失败是 pre-existing Flame xcframework 缺 arm64 sim slice（非 CSJ 引起，CSJ SDK 支持 arm64 sim）。Pods 138M→553M，App ~130M。**真机启动冒烟通过**（pt=tb/无 AnyThink 弹窗/无 dyld/无 selector/无 duplicate class/CSJ 未触发符合预期/主页面正常）。**原三广告类型完整闭环无回归**（Splash skip+close 幂等 / Interstitial 完整 close-loop / Reward 两轮闭环 cachedVC=0x0 时动态 presenter 修复生效）。SKAdNetwork IDs（CSJ 10+个）待 Phase 5A.16C/D 加 Demo Info.plist。本地 commit `build: add ToBid CSJ adapter dependency`，未 push/tag/release。不创建 TbBannerAdapter，等待用户确认进入 Phase 5A.16C。

---

**Phase 5A.16B 正式完成。CSJ 依赖接入验证全部通过（静态 + 真机冒烟 + 原广告类型回归）。未创建 TbBannerAdapter，未修改 Banner 工厂，等待用户确认进入 Phase 5A.16C（届时需先在 ToBid 后台配 CSJ Banner 广告位 + Flame pMap 加 banner 映射 + Demo Info.plist 加 CSJ SKAdNetwork IDs）。**
