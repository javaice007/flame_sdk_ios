# Phase 5A.13 Step 1.2 — TB 模式 AnyThink Adx SDK 组件缺失弹窗专项定位报告

## 一、基线

| 项 | 值 |
|---|---|
| SDK 路径 | `/Users/khj/Documents/code/97_ad/ios/flame_ios_sdk` |
| SDK 分支 | `release/ios-dual-line` |
| SDK HEAD | `1abfdae163fb530dfc972c11b420b83d72a5a188` |
| SDK 工作区 | 干净（仅 `research/` 测试目录未跟踪，`OpenSSL.xcconfig`/`project.pbxproj` 既有修改） |
| Demo 路径 | `/Users/khj/Documents/code/97_ad/ios/adsurge-ios-demo` |
| Demo 分支 | `main` |
| Demo HEAD | `c1aa5f4e9a857ab64375bb43da8c17caaa51735c` |
| Demo 工作区 | 本地修改：Podfile（`:path` 接入）、多个 Swift 业务文件 |
| Demo 接入方式 | `pod 'flame_sdk_ios_tb', :path => '../flame_ios_sdk/research/local_dist_tb'` |

## 二、问题复现

| 项 | 值 |
|---|---|
| 弹窗完整文案 | `重要提示：检测到"AnyThink Adx SDK"重要组件缺失，会导致Taku ADX业务无法正常运行，需要在项目中进行引入。如有疑问可联系业务同学确认并处理。感谢配合！` |
| 英文版（同位置） | `Warning: "AnyThink Adx SDK" is missing now, which would make Taku ADX cannot function normally . Highly recommend adding it to the project..` |
| pt | `tb` |
| FlameSdk init | 成功 |
| Router 激活 | TB Provider |
| Reward load | 正常 |

## 三、来源定位（静态 + 动态双重实证）

### 3.1 静态：弹窗字符串所在二进制

| 项 | 值 |
|---|---|
| Framework | `Pods/AnyThinkiOS/core/AnyThinkSDK.xcframework/ios-arm64/AnyThinkSDK.framework/AnyThinkSDK` |
| 字符串偏移 | `0x287fec`（UTF-16LE NSString 常量，位于 `__TEXT` 段） |
| CFString 对象 | `0x2b3c58`（isa/flags/cstr_ptr=0x287fec/length=86） |
| 唯一交叉引用 | `0x16f8b0`（ADRP+ADD 载入 CFString） |

取证命令（Python UTF-16LE 扫描）：

```python
with open(AT_BIN, 'rb') as f: data = f.read()
# '重要组件'.encode('utf-16-le') → 在 0x288020 命中
# 'AnyThink Adx'.encode('utf-16-le') → 在 0x287ffe 命中
```

### 3.2 静态：触发代码路径（反汇编定位）

| 层级 | 类/函数 | IMP/地址 | 作用 |
|------|---------|----------|------|
| 文案 getter | `+[ATURLRequestConfiguration adxIntegratedVerificationErrorText]` | `0x16f844` | 调用 `[ATCommonUtilities ...]` 判断地区，`csel` 返回中/英文版 CFString |
| 文案 UI 类 | `ATAlertViewController`（AnyThink 私有类） | — | 自定义 alert VC |
| 检查器 | `ATAggregatedSDKChecker` | 7 方法（`sharedInstance`/`init`/`startCheckWithKeysTdSds:`/`_checkActionWithInfos:`/`__getAggSDKVersionWithCls:sel:`/`_sendTkWithResults:`/`scanCount`） | 通过 `NSClassFromString` 检测三方 SDK 组件 |
| 检查结果 | `ATAggSDKCheckInfo` | 13 方法 | 单条检测结果（含 existState） |
| 上游触发 | `-[ATAppSettingManager startCheckAggSDK]` | `0x68364` | AnyThink app-setting 请求成功后调用，参数 `@["td_sds","1004678"]` |

### 3.3 动态：真实调用栈（用户真机符号断点取证）

```
UIViewController presentViewController
→ AnyThinkSDK`___lldb_unnamed_symbol_3bea8
→ dispatch main queue
```

关键事实：

- 弹窗对象：`UIAlertController`（title="AnyThink Adx SDK 组件缺失提示"，message=nil，action="确定"）
- 展示者：AnyThinkSDK.framework 内部函数 `___lldb_unnamed_symbol_3bea8`
- 调用方式：`dispatch_async(main_queue, ^{ ... presentViewController ... })`
- **Demo / Flame / ToBid 均不在 present 调用栈中**
- 原始检测入口因异步派发（dispatch_async）已不在当前栈中，无法继续向上回溯

## 四、依赖审计

### 4.1 Demo Podfile 与 Podfile.lock

```ruby
# Podfile（target 块）
pod 'flame_sdk_ios_tb', :path => '../flame_ios_sdk/research/local_dist_tb'
pod 'OpenSSL-Universal', :path => '/Users/khj/Documents/code/97_ad/ios/local_pods/OpenSSL-Universal'
pod 'FunlinkSDK', :path => '../local_pods/FunlinkSDK'
```

Podfile.lock 依赖树：

```
flame_sdk_ios_tb (1.0.0-alpha.4-local)
├── AnyThinkiOS (= 6.5.71)         ← 由 TB podspec 强制带入
├── OpenSSL-Universal (~> 3.6)
└── ToBid-iOS-RC (= 5.5.6)
```

### 4.2 Demo 源码 AnyThink 残留审计

`grep -RniE "AnyThink|ATSDK|ATAPI|Taku|TopOn" Sources/` → **无任何引用**（只有历史 `err.log` 调试日志文件含 TK 测试残留，与业务代码无关）。

### 4.3 Flame 二进制对 AnyThink 的依赖

```
$ otool -L flame_sdk_ios.framework/flame_sdk_ios
...
@rpath/AnyThinkSDK.framework/AnyThinkSDK (compatibility version 1.0.0, current version 1.0.0)
...
```

**LC_LOAD_DYLIB 硬依赖**：单二进制架构既定设计——binary 内含 TK 适配器代码（`FlameTKProvider.m`/`At*Adapter.m`），链接时需解析 `ATAPI`/`ATAdManager` 等符号；podspec 中 `s.dependency 'AnyThinkiOS'` 提供 framework，dyld 启动时无论 pt=tk/tb 都会加载 `AnyThinkSDK.framework`。

### 4.4 Flame 源码 AnyThink 引用清单

| 类别 | 文件 | 引用方式 |
|------|------|----------|
| 公共层 | `adapter/FlameAdapterManager.m` | `#import <AnyThinkSDK/AnyThinkSDK.h>` + `[ATAPI setLogEnabled/integrationChecking/startWithAppID]`（TK init 残留逻辑） |
| TK Provider | `mediation/tk/FlameTKProvider.m` | `#import <AnyThinkSDK/AnyThinkSDK.h>` + 完整 AnyThink init 调用 |
| TK Adapter | `adapter/tk/At{Reward,Interstitial,Banner,Splash,Native,NativeSelfRender}Adapter.{h,m}` | `#import <AnyThinkSDK/AnyThinkSDK.h>` + `ATAdManager`/`ATBannerView`/`ATNativeAdOffer` 等 |

**公共 API 头（`mediation/Flame*AdapterProtocol.h`、`mediation/tk/FlameTKProvider.h`）不引用 AnyThink**（grep 命中的 `ATReward` 是 `FlameRewardAdapter` 子串，非真实引用）。

## 五、Provider 审计

| 项 | 结果 |
|---|---|
| `FlameTKProvider +load` | 仅 `[[FlameTKProvider alloc] init]` + `registerProvider:` + 日志，**不调用 AnyThink init**（源码与注释一致） |
| `FlameTKProvider +load` 是否创建实例 | 是，但 `init` 不调 AnyThink |
| `+load` 是否触发 AnyThink 初始化 | 否 |
| pt=tb 时是否调用 `FlameTKProvider.initializeWithAppId` | 否（Router 只激活 TBProvider） |
| AnyThink 是否被 Flame 主动初始化 | 否（动态栈无 Flame 帧） |

## 六、AnyThink 公开关闭 API 检查

`Pods/AnyThinkiOS/.../Headers/` 全量 grep：

| 关键词 | 结果 |
|---|---|
| `integrationChecking` | `+[ATAPI integrationChecking]` — 公开 API，文档说明"Whether the network platform integration integrity information is normal"，仅打印日志，**非弹窗触发器** |
| `disableCheck`/`skipCheck`/`setCheck`/`closeCheck`/`noCheck` | **无** |
| `setAggregatedSDKCheck`/`setAdxCheck`/`disableADX` | **无** |
| `ATAggregatedSDKChecker`/`ATAlertViewController` | **私有类**，不在公开 Headers |

**结论**：AnyThinkiOS 6.5.71 公开 API 中**未发现关闭 ADX 完整性检测的入口**。

## 七、根因分类（最终）

### C 类：AnyThinkSDK 自身展示（动态实证）

AnyThinkSDK.framework 进入 TB App 运行时后，由其**内部完整性检测逻辑**直接展示 ADX 缺失提示。

**直接证据**：

1. 动态栈：`presentViewController ← AnyThinkSDK(___lldb_unnamed_symbol_3bea8) ← dispatch_main_queue`，无 Flame/Demo/ToBid 帧
2. 静态证据：弹窗字符串、`ATAlertViewController`、`ATAggregatedSDKChecker`、`ATURLRequestConfiguration.adxIntegratedVerificationErrorText` 全部位于 AnyThinkSDK.framework 内部
3. TB podspec 通过 `s.dependency 'AnyThinkiOS'` 强制带入 AnyThinkSDK.framework 到 App `.app/Frameworks/`
4. Flame binary 通过 LC_LOAD_DYLIB 硬依赖 AnyThinkSDK，TB App 启动时 dyld 必然加载它
5. AnyThinkSDK 被加载后，内部完整性检测在某个时机（具体入口因 dispatch_async 异步派发已不可静态回溯）触发 ADX 检测，发现 `AnyThink Adx SDK` 组件缺失即弹窗

**措辞精确性**：

- ✅ 已确认：AnyThinkSDK.framework 自己展示弹窗（动态栈）
- ❌ 未声称：检测一定来自 `+load`（原始入队调用栈因异步派发未保留）
- ❌ 未声称：检测来自 Flame 主动调用（动态栈无 Flame 帧）

## 八、Demo 残留与架构影响

| 项 | 结果 |
|---|---|
| Demo 是否存在 TK/Taku 残留代码 | 否 |
| 是否为 Demo 残留依赖 | 否 |
| 是否为 Flame 误调 TK | 否 |
| 是否为 AnyThink 被动自动检测 | 是（C 类） |
| 是否为 TB podspec 依赖边界错误 | 间接相关（podspec 强制带入 AnyThink，根本是 binary 硬依赖） |

## 九、本次未做修改

本轮仅取证，**未修改任何代码/podspec/配置**。

## 十、后续：进入 Step 1.2B PoC

基于 C 类根因，下一步执行 `phase-5a.13-step1.2b` 可行性 PoC，判断能否在保持单二进制架构下让 TB 包脱离 AnyThinkSDK 运行时依赖。详见 `phase-5a.13-step1.2b-tb-anythink-runtime-isolation-poc-report.md`。
