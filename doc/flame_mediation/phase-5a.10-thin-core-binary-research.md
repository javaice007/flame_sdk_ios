# 单 Core Thin Binary 分发方案可行性调研报告

> **阶段**：Phase 5A.10（仅调研，不发布、不 tag、不 pod repo push、不进入 Phase 6）
> **分支**：`feat/tb_adapter`（实验分支为 `research/thin-core-binary`，本轮未实际创建，仅出报告）
> **日期**：2026-06-17
> **当前稳定兜底**：双二进制方案（`build/tk` + `build/tb`），已打 `backup/phase-5a-dual-binary-stable` 保护分支

---

## 0. TL;DR（结论先行）

| 维度 | 结论 |
|---|---|
| 技术可行性 | **可行**。Core 与平台源码边界天然清晰，无逆向依赖。 |
| 是否能避免 AnyThink / ToBid / WindMill 二进制污染 | **能**。Core 构建期只要不引入 AnyThink/ToBid 即可零三方符号。 |
| 是否能避免 Sigmob / WindSDK duplicate class | **能**（根因消除：Core 不再静态内置任何广告 SDK）。 |
| 是否需要改对外 API | **不需要**。`FlameSdk.h` / `flame_sdk_ios.h` 全平台中立，0 改动。 |
| 是否影响老用户 `pod 'flame_sdk_ios'` | **不影响**（podspec 行为可等价保持）。 |
| Provider 注册机制推荐 | **`+load` 自动注册**（首选），`NSClassFromString` 作为防御性兜底。 |
| 主要工作量 | 中等（≈1.5～2 人日，含构建脚本与双 podspec 验证）。 |
| 是否推荐进入实现 | **推荐**，但**分两步走**：先做最小可验证切片（Step 1～3），跑通 Demo 再决定是否替换双二进制。 |

---

## 1. 当前稳定方案保护情况

### 1.1 已落实的保护

| 项 | 状态 | 说明 |
|---|---|---|
| `git status` | 已确认 | feat/tb_adapter 上 41 个文件改动，未提交（含 TK/TB 双源码、双 podspec、splash 修复、文档）。 |
| 备份分支 | **已创建** | `backup/phase-5a-dual-binary-stable` → `d7d7837`（与 feat/tb_adapter HEAD 同点）。 |
| 双二进制产物 | 保留 | `build/tk/flame_sdk_ios.xcframework`（276K）+ `build/tb/flame_sdk_ios.xcframework`（6.9M）均在。 |
| 双 podspec | 保留 | `flame_sdk_ios.podspec`（TK 外部依赖模式）+ `flame_sdk_ios_tb.podspec`（TB 自包含 WindMill 模式）。 |
| 调研分支 | 未创建 | 本轮纯调研，未执行 `git checkout -b research/thin-core-binary`，未改任何文件。 |

### 1.2 保护原则遵守

- 未发布、未 tag、未 pod repo push。
- 未删除 `build/tk`、`build/tb`、任一 podspec。
- 未进入 Phase 6，未实现 TB Splash/Interstitial/Banner/Native。
- 所有结论基于只读分析（读源码、读缓存 podspec、`otool`/`nm` 已有产物）。

---

## 2. ToBid-iOS-RC 本地内容确认结果（关键结论）

### 2.1 数据来源

直接读取本地 CocoaPods 缓存的官方 podspec：
`~/Library/Caches/CocoaPods/Pods/Specs/Release/ToBid-iOS-RC/5.5.6-81b90.podspec.json`

### 2.2 核心字段

```json
{
  "name": "ToBid-iOS-RC",
  "version": "5.5.6",
  "default_subspecs": "ToBidSDK",
  "subspecs": [
    {
      "name": "ToBidSDK",
      "vendored_frameworks": ["tobid-sdk-ios-cocoapods-cn/Core/*.xcframework"]
    },
    { "name": "CSJAdapter",     "dependencies": { "Ads-CN/BUAdSDK": ["7.6.0.4"], "ToBid-iOS-RC/ToBidSDK": [] } },
    { "name": "GDTAdapter",     "dependencies": { "GDTMobSDK": ["4.15.90"],      "ToBid-iOS-RC/ToBidSDK": [] } },
    { "name": "KSAdapter",      "dependencies": { "KSAdSDK": ["5.4.10.1"],       "ToBid-iOS-RC/ToBidSDK": [] } },
    { "name": "BaiduAdapter",   "dependencies": { "BaiduMobAdSDK": ["10.050"],   "ToBid-iOS-RC/ToBidSDK": [] } },
    ... (共 22 个 Adapter subspec)
  ]
}
```

### 2.3 结论（直接回答问题 1）

| 问题 | 结论 |
|---|---|
| ToBid-iOS-RC 是否包含 `WindMillSDK.xcframework` | **是**（默认 `ToBidSDK` subspec 即 `Core/*.xcframework`） |
| ToBid-iOS-RC 是否包含 `WindSDK.xcframework` | **是**（同上） |
| ToBid-iOS-RC 是否包含 `WindFoundation.xcframework` | **是**（同上） |
| ToBid-iOS-RC 是核心包还是已带 Wind 二进制 | **核心包本身就带 Wind 三件套**。`default_subspecs=ToBidSDK` 意味着**即使不写任何 subspec**，`pod 'ToBid-iOS-RC'` 也会拉入 WindMillSDK + WindSDK + WindFoundation。各 `*Adapter` subspec 是可选的（只带 WindMill*Adapter 包装 + 底层广告 SDK）。 |

### 2.4 对 Core binary 的决定性影响

> **如果 Core binary 构建期引入了 ToBid-iOS-RC（任何形式），Core 就不再是 thin core。**
> 因为 `use_frameworks! :linkage => :static` 会在 archive 阶段把 `Core/*.xcframework`（WindMill 等）静态合并进 `flame_sdk_ios.framework`，这与当前 TB 产物 6.9M + 3621 个 WindMill 符号的现象完全一致。

因此：**Core 构建期的 Podfile 必须只含 `OpenSSL-Universal`，绝不能含 AnyThink / ToBid。**

---

## 3. 当前三方 SDK import 审计结果

### 3.1 逐目录审计（真实代码 import，已剔除注释噪音）

| 目录 | 真实三方 import 数 | 详情 |
|---|---|---|
| `core/` | **0** | FlameSdk.m 中 "1" 的匹配项是注释字符串 "TB / ToBid / WindMill"，非代码。 |
| `ads/` | **0** | banner/interstitial/nativate/reward/splash 全部 0 三方 import。 |
| `utils/` | **0** | AES/MD5/Network/UrlParam/ConfigLocalStorage 全部 0。 |
| `mediation/`（根，协议/Registry/Router/AdapterProtocol） | **0** | 纯 Foundation/UIKit + Flame 自有协议头。 |
| `mediation/tk/` | **0** | FlameTKProvider 不直接 import AnyThink，初始化委托给 FlameAdapterManager。 |
| `mediation/tb/` | **1** | `FlameTBProvider.m:14 #import <WindMillSDK/WindMillSDK.h>` |
| `adapter/`（根，FlameAdapterManager） | **1（已守卫）** | `FlameAdapterManager.m:24 #import <AnyThinkSDK/AnyThinkSDK.h>`，外层 `#if FLAME_BUILD_TK` 包裹。 |
| `adapter/tk/` | **9** | 5 个 At*Adapter + AtNativeSelfRenderView，全部 `#import <AnyThinkSDK/...>`。 |
| `adapter/tb/` | **1** | `TbRewardAdapter.m:14 #import <WindMillSDK/WindMillSDK.h>`。 |

### 3.2 关键判断（直接回答问题 2）

> **Core binary 构建期完全可以不引入 AnyThink / ToBid。**
> 因为 `core/` + `ads/` + `utils/` + `mediation/`（根）四个目录**零三方 import**，编译期不需要任何三方头文件。
> Flame 自有代码与三方 SDK 的唯一耦合点全部集中在 `adapter/tk`、`adapter/tb`、`mediation/tb`，以及 `adapter/FlameAdapterManager` 的 TK 守卫段——这些都不进 Core。

---

## 4. Core binary 文件边界

### 4.1 应包含清单（进 Core）

```
flame_sdk_ios/flame_sdk_ios.h            （伞头）
flame_sdk_ios/core/**                    （FlameSdk / ConfigManager / AppEntity / ErrorCode / Logger / Callback）
flame_sdk_ios/ads/**                     （5 类广告 Impl + 公共 .h）
flame_sdk_ios/utils/**                   （AES/MD5/Network/UrlParam/ConfigLocalStorage）
flame_sdk_ios/mediation/FlameMediationProvider.h
flame_sdk_ios/mediation/FlameMediationRegistry.{h,m}
flame_sdk_ios/mediation/FlameMediationRouter.{h,m}
flame_sdk_ios/mediation/Flame*AdapterProtocol.h   （5 个协议头）
flame_sdk_ios/adapter/FlameAdapterManager.{h,m}   （见第 5 节，需轻量改造）
```

### 4.2 应排除清单（不进 Core，作为平台 source_files）

```
flame_sdk_ios/mediation/tk/**            （FlameTKProvider）
flame_sdk_ios/mediation/tb/**            （FlameTBProvider）
flame_sdk_ios/adapter/tk/**              （5 个 At*Adapter + AtNativeSelfRenderView）
flame_sdk_ios/adapter/tb/**              （TbRewardAdapter）
```

### 4.3 边界正确性证明（无逆向依赖）

调用方向（编译期依赖箭头）：

```
接入方 App
   │  import <flame_sdk_ios/FlameSdk.h>（公共 API，平台中立）
   ▼
Core binary（FlameSdk / ads / utils / mediation 根 / FlameAdapterManager）
   │  运行时通过 FlameMediationRouter.currentProvider（id<FlameMediationProvider>）
   │  反向调用平台 Provider（协议调用，非编译期依赖）
   ▼
平台源码（source_files 编译进 App）
   FlameTKProvider → At*Adapter → AnyThinkSDK
   FlameTBProvider → TbRewardAdapter → WindMillSDK
```

**关键点**：Core 不 `#import` 任何具体 Provider 类（当前 FlameSdk.m 的 `#import "FlameTKProvider.h"` 是唯一破口，第 6 节给方案）。平台源码反过来 `#import` Core 暴露的协议头（`FlameMediationProvider.h`、`Flame*AdapterProtocol.h`）——这是单向依赖，**符合 thin core 几何**。

---

## 5. FlameAdapterManager 对 thin core 的影响（直接回答问题 3）

### 5.1 现状

`FlameAdapterManager.{h,m}` 位于 `adapter/` 根目录，承担三类职责：

| 职责 | 是否平台中立 | 三方依赖 |
|---|---|---|
| `+sharedInstance` / `+isInitialized` / `+checkInitialization` | **中立** | 0（委托 `[FlameSdk isInitialized]`） |
| `+setDebug:` | 中立（壳） | TK 段调 `[ATAPI setLogEnabled:]`，TB 段仅打日志 |
| `+initSDKWithAppId:appKey:initListener:` | **TK 专属** | 调 `[ATAPI sharedInstance] startWithAppID:appKey:error:]` |

### 5.2 为什么必须留在 Core

`ads/*Impl.m`（splash/interstitial/...）在 5 处调用 `[FlameAdapterManager checkInitialization]`。如果 FlameAdapterManager 移出 Core，Core 的 ads 层就编译不过。

### 5.3 当前 AnyThink import 的守卫情况

```objc
// FlameAdapterManager.m:24
#if defined(FLAME_BUILD_TK) || (!defined(FLAME_BUILD_TK) && !defined(FLAME_BUILD_TB))
#import <AnyThinkSDK/AnyThinkSDK.h>
#endif
```

**问题**：在 thin core 模式下，Core 构建时**两个宏都不定义**（既不是 TK 也不是 TB），按现有逻辑 `(!defined(TK) && !defined(TB))` 为真 → **会触发 AnyThink import**，编译失败。

### 5.4 改造方案（轻量，≈30 行）

把 TK 专属的 `initSDKWithAppId:` 与 `setDebug` 的 TK 分支**整体迁到 FlameTKProvider**（本就属于 TK 平台职责），FlameAdapterManager 仅保留中立骨架：

```objc
// 改造后 FlameAdapterManager.m（Core 版，纯中立）
#import "FlameAdapterManager.h"
#import "FlameSdk.h"          // checkInitialization 委托源
@implementation FlameAdapterManager
+ (instancetype)sharedInstance { ... }      // 保留（历史 API 兼容）
+ (BOOL)isInitialized { return [FlameSdk isInitialized]; }
+ (BOOL)checkInitialization { return [FlameSdk checkInitialization]; }
+ (void)setDebug:(BOOL)isDebug { /* 平台中立：仅转发日志，实际开关由 Provider 处理 */ }
// initSDKWithAppId: 删除（改由 FlameTKProvider.initializeWithAppId: 直接调 ATAPI）
@end
```

```objc
// FlameTKProvider.m（承接 TK 初始化）
#import <AnyThinkSDK/AnyThinkSDK.h>   // 仅 TK source_files 编译，不进 Core
- (void)initializeWithAppId:appKey:callback: {
    [ATAPI setLogEnabled:YES];
    [ATAPI integrationChecking];
    NSError *err = nil;
    [[ATAPI sharedInstance] startWithAppID:appId appKey:appKey error:&err];
    // ... 回调
}
```

### 5.5 兼容性影响

- `+initSDKWithAppId:appKey:initListener:` 是**历史内部 API**，不在 `flame_sdk_ios.h` 伞头里，接入方不可见 → 删除安全。
- 对外 `+setDebug:` 签名保留（接入方通过 `[FlameSdk setDebug:]` 调，底层走 FlameAdapterManager）。

> **结论：FlameAdapterManager 不阻碍 thin core，只需把 TK 初始化段迁到 TK Provider（≈30 行）。**

---

## 6. Provider 注册机制候选方案对比（直接回答问题 6）

### 6.1 当前机制的问题

当前 `FlameSdk.m:31,35` 直接 `#import "FlameTKProvider.h"` / `"FlameTBProvider.h"`，并在 `registerAllProvidersIfNeeded`（line 350）用 `#if FLAME_BUILD_TK` 编译期选择。**这会让 Core binary 编译期硬依赖具体 Provider 类**，破坏 thin core。

### 6.2 三方案对比

| 维度 | A. `+load` 自动注册 | B. `__attribute__((constructor))` | C. `NSClassFromString` 延迟注册 |
|---|---|---|---|
| Core 是否 import Provider 类 | **否**（完全解耦） | **否** | **否** |
| 注册时机 | main 前，类加载时 | main 前，dyld 阶段 | FlameSdk 初始化时（首次需要 Provider） |
| 是否需要 `-ObjC` | 需要（保证 +load 执行） | 不强依赖（constructor 由 dyld 自动跑） | 不需要（主动 NSClassFromString） |
| CocoaPods 静态库可靠性 | **高**（`-ObjC` 已在 podspec 配置） | 高 | 高 |
| 实现复杂度 | 低（3 行/Provider） | 低 | 中（需硬编码类名 + 容错） |
| 可读性 / 可调试 | **最好**（栈帧清晰） | 一般（C 函数，栈帧不直观） | 一般（字符串类名易写错） |
| 多 Provider 扩展 | 各自 +load，天然并行 | 同上 | 需维护类名表 |
| 失败模式 | 类未链接 → 静默不注册（可日志） | 同 A | 类名拼错 → nil，可日志 |

### 6.3 关键技术验证

- **Registry 单例可否在 `+load` 调用？**
  `FlameMediationRegistry.sharedRegistry` 用 `dispatch_once`，`init` 仅分配 `NSMutableDictionary`，**无逆向依赖、无 Foundation 未就绪风险** → **安全**。
- **`+load` 是否一定被链接？**
  podspec 已配 `OTHER_LDFLAGS => '-ObjC'`（两个 podspec 均有），保证 ObjC category 与 `+load` 所在对象文件被链接 → **可靠**。
- **FlameTKProvider `+load` 会触发 AnyThink 链接吗？**
  不会。`+load` 方法体只调 `[[FlameMediationRegistry sharedRegistry] registerProvider:[[FlameTKProvider alloc] init]]`，`alloc/init` 不触发 AnyThink 代码（AnyThink 仅在 `initializeWithAppId:` 被调时才执行）。**Provider 注册与三方 SDK 链接解耦。**

### 6.4 推荐：方案 A（`+load`）为主 + 方案 C 作防御性兜底

```objc
// FlameTKProvider.m（TK source_files）
+ (void)load {
    [[FlameMediationRegistry sharedRegistry] registerProvider:[self new]];
    [FlameLogger i:@"FlameTKProvider 自动注册（+load）"];
}
```

```objc
// FlameSdk.m（Core）—— registerAllProvidersIfNeeded 改造
+ (void)registerAllProvidersIfNeeded {
    // 不再 #import 具体 Provider，改为兜底扫描
    // 正常情况下 +load 已注册；此处仅做防御性 NSClassFromString 兜底
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSDictionary<NSString*,NSString*> *knownProviders = @{
            @"tk": @"FlameTKProvider",
            @"tb": @"FlameTBProvider"
        };
        // 仅当某平台未注册时尝试反射兜底（+load 失败的保险）
        for (NSString *pt in knownProviders) {
            if (![[FlameMediationRegistry sharedRegistry] hasProviderForPlatformCode:pt]) {
                Class cls = NSClassFromString(knownProviders[pt]);
                if (cls && [cls conformsToProtocol:@protocol(FlameMediationProvider)]) {
                    [[FlameMediationRegistry sharedRegistry] registerProvider:[cls new]];
                }
            }
        }
    });
}
```

> 注：方案 C 的硬编码类名只在**兜底分支**出现，正常路径走 `+load`。即使类未链接，兜底也只会得到 nil 并跳过，不影响 Core 中立性。

### 6.5 `+load` 时序风险补充

`+load` 在 main 之前执行，此时 `FlameLogger` 若依赖某些运行时状态需谨慎。当前 `FlameLogger` 是薄封装（`NSLog`/`printf`），main 前调用安全。若未来 FlameLogger 引入 UIKit/网络依赖，需把 `+load` 内日志降级为 `NSLog`。

---

## 7. vendored_frameworks + source_files 可行性（直接回答问题 7、8、9）

### 7.1 CocoaPods 原生支持

CocoaPods 完全支持同一 podspec 同时声明 `vendored_frameworks` 与 `source_files`，这是业界二进制 + 源码混合分发的**标准模式**（参考 `FirebaseAnalytics`、`Bugly` 等均如此）。

### 7.2 实验性 podspec 骨架（不落盘，仅设计）

```ruby
# research/flame_sdk_ios.thin_core.tk.podspec（设计稿，本轮不创建）
Pod::Spec.new do |s|
  s.name = 'flame_sdk_ios'
  s.version = '0.1.8.6-research'

  # Core 二进制（平台中立，不含任何三方 SDK）
  s.vendored_frameworks = 'build/core/flame_sdk_ios.xcframework'

  # TK 平台源码（编译进接入方 App）
  s.source_files =
    'flame_sdk_ios/mediation/tk/**/*.{h,m}',
    'flame_sdk_ios/adapter/tk/**/*.{h,m}'
  s.public_header_files =
    'flame_sdk_ios/mediation/tk/FlameTKProvider.h'   # 按需

  # Core 暴露给平台源码的协议头（让 source_files 能 import）
  s.private_header_files =
    'flame_sdk_ios/mediation/FlameMediationProvider.h',
    'flame_sdk_ios/mediation/Flame*AdapterProtocol.h'

  # 运行时依赖
  s.dependency 'OpenSSL-Universal', '~> 3.6'
  s.dependency 'AnyThinkiOS', '6.5.71'
  # ... 其他 TK 广告源依赖

  s.pod_target_xcconfig = { 'OTHER_LDFLAGS' => '-ObjC', 'DEFINES_MODULE' => 'YES' }
end
```

### 7.3 关键问题逐条回答

| 问题 | 回答 |
|---|---|
| `vendored_frameworks` + `source_files` 是否可共存 | **可以**。CocoaPods 会把 vendored_frameworks 作为链接输入，source_files 作为编译输入，二者正交。 |
| source_files 编译出的 Provider/Adapter 能否 import Core 头 | **能**，前提是 Core 的协议头通过 `public_header_files` / `private_header_files` 暴露。由于 Core 是 xcframework（带 Headers/），source_files 可直接 `#import <flame_sdk_ios/FlameMediationProvider.h>`。 |
| Core 的协议头是否需要暴露给平台源码 | **需要**。`FlameMediationProvider.h`、`Flame*AdapterProtocol.h`、`FlameRewardAd.h` 等 5 个广告公共协议头必须进 Core 的 Headers/，让平台源码可见。 |
| TK/TB 平台源码是否应放 source_files 而非打进 xcframework | **是**。这是 thin core 的核心收益：平台源码与三方 SDK 的编译期绑定发生在**接入方 App**，不发生在 Core 构建期。 |
| 两个 podspec 是否能引用同一个 Core xcframework | **能**。`s.vendored_frameworks = 'build/core/flame_sdk_ios.xcframework'` 在两个 podspec 中指向同一文件路径，CocoaPods 不会冲突（因为两个 pod 互斥，不会同时安装）。 |

### 7.4 module 名一致性

两个 podspec 的 vendored_frameworks module 名都是 `flame_sdk_ios`，接入方 `import <flame_sdk_ios/FlameSdk.h>` 不变。**与当前双二进制方案的 module 策略完全一致**，无新增风险。

---

## 8. 是否需要目录迁移（直接回答问题 11）

### 8.1 两种方式对比

| 方式 | 风险 | 收益 |
|---|---|---|
| **物理迁移**到 `platform_sources/{tk,tb}/` | 中（需改 pbxproj、build script、import 路径） | 目录语义清晰，podspec source_files glob 简单 |
| **保持目录不动**，仅用 podspec/build script 文件清单控制 | **低**（pbxproj 不动，import 路径不变） | podspec 的 source_files glob 需精确枚举 |

### 8.2 推荐：保持目录不动

理由：
1. 当前 `adapter/tk`、`adapter/tb`、`mediation/tk`、`mediation/tb` 命名已清晰表达平台归属，物理迁移是**为改而改**。
2. pbxproj 已经稳定（刚提交 `d7d7837 chore: update project.pbxproj`），再动容易引入回归。
3. podspec 的 `source_files` 完全可以用 `'flame_sdk_ios/adapter/tk/**/*.{h,m}'` 精确枚举，效果等同。

> 仅当后续团队规模扩大、平台插件数量增多（≥3 个平台）时，再考虑物理迁移到 `platform_sources/`。

---

## 9. 对外 API / 兼容性矩阵（直接回答问题 10、12、13、14）

| 问题 | 回答 | 证据 |
|---|---|---|
| 是否会改变对外 API | **不会** | `FlameSdk.h` 全平台中立；`createSplash/Reward/Interstitial/Banner/Native` 签名不变；公共协议（`FlameSplashAd` 等）不变。 |
| 是否需要修改 `flame_sdk_ios.h` | **不需要** | 伞头当前只 import `FlameCallback/Splash/Banner/Reward/Interstitial/Sdk`，全部在 Core，无平台类。 |
| 是否影响老用户 `pod 'flame_sdk_ios'` | **不影响** | podspec 名、module 名、公共 API 三重不变；老用户升级后业务代码 0 改动。 |
| TB 老用户 `pod 'flame_sdk_ios_tb'` | 同样不影响（若采用 thin core，TB podspec 行为等价：拉 Core binary + TB source_files + ToBid-iOS-RC 依赖）。 |

---

## 10. 污染 / duplicate class 根治分析（直接回答问题 15、16）

### 10.1 当前双二进制方案的残留风险

- TK 包：构建期已剔除广告源 SDK 污染（构建脚本 line 141-163 已校验），但 **AnyThinkSDK 仍是外部依赖**（`otool -L` 显示 `@rpath/AnyThinkSDK.framework`），下游若误装 Sigmob 版本仍可能冲突。
- TB 包：**WindMill 已静态内置**（6.9M + 3621 符号），podspec 显式禁止再声明 ToBid-iOS-RC。这是"打补丁"式解决，根因未除。

### 10.2 Thin Core 如何根治

| 风险 | Thin Core 处理 |
|---|---|
| AnyThink 污染 Core | Core 构建期 Podfile 无 AnyThink → Core 二进制 0 个 AT 符号（`otool -L` 不含 AnyThink）。 |
| WindMill 污染 Core | Core 构建期 Podfile 无 ToBid → Core 二进制 0 个 WindMill 符号。 |
| Sigmob duplicate class | TK 平台源码编译时由接入方 App 拉 Sigmob，**与 Core 解耦**；不再有"Core 内置 vs App 再拉"的冲突。 |
| WindSDK duplicate class | TB 平台源码编译时由接入方 App 拉 ToBid-iOS-RC（默认带 WindSDK），Core 不内置 → 无 duplicate。 |

### 10.3 Thin Core 预期产物特征（设计验证标准）

```
build/core/flame_sdk_ios.xcframework/ios-arm64/flame_sdk_ios.framework/flame_sdk_ios
  - 体积：≈ 250K～350K（与当前 TK 276K 同量级，Core 比 TK 略大因含 Registry/Router）
  - otool -L：不含 @rpath/AnyThinkSDK，不含 @rpath/WindMillSDK
  - nm -gU：0 个 AT* / WindMill* / Wind* / Sigmob / BUAd / CSJ / GDT 符号
  - framework 内：无三方 bundle / metallib / 资源
```

---

## 11. 预计改造工作量（直接回答问题 17）

| 任务 | 工作量 | 风险 |
|---|---|---|
| ① FlameAdapterManager 拆分（TK init 迁 Provider） | 0.3 人日 | 低（已有清晰边界） |
| ② FlameSdk.m `registerAllProvidersIfNeeded` 改 `+load` + 兜底 | 0.2 人日 | 低 |
| ③ TK/TB Provider 加 `+load` 方法 | 0.1 人日 | 低 |
| ④ 移除 FlameSdk.m 对 Provider 类的直接 import | 0.1 人日 | 低 |
| ⑤ 新增 `xcFramework_build.sh core` 子命令（Core Podfile：仅 OpenSSL） | 0.3 人日 | 中（需调通 archive） |
| ⑥ Core 产物符号校验脚本扩展 | 0.2 人日 | 低 |
| ⑦ 双实验 podspec（thin_core.tk / thin_core.tb） | 0.2 人日 | 低 |
| ⑧ Demo 双 variant 接入验证（TK + TB 各跑一遍） | 0.5 人日 | 中（TB 需验证 WindMill 运行时拉入） |
| **合计** | **≈ 1.9 人日** | 整体中等可控 |

---

## 12. 是否推荐进入实现（直接回答问题 18）

### 12.1 推荐：**有条件推进，分两步走**

**Step 1（最小可验证切片，≈0.7 人日）**：仅做任务 ①②③④⑤⑥，产出 `build/core/flame_sdk_ios.xcframework`，用 `otool`/`nm` 证明 Core 零三方符号。**此步不碰 podspec、不碰 Demo**，风险最低，能最快证伪/证实可行性。

**Step 2（端到端验证，≈1.2 人日）**：仅在 Step 1 符号校验通过后，做任务 ⑦⑧，用 Demo TK + TB 双 variant 跑通运行时。

### 12.2 与当前双二进制方案的关系

- **不替换**：Step 1/2 全程保留 `build/tk`、`build/tb`、双 podspec 作为兜底。
- **并行验证**：thin core 跑通后，再单独决策是否切换为默认分发模式。
- 若 Step 2 发现运行时问题（如 `+load` 在某 CocoaPods 版本失效），可立即回退双二进制，**零业务影响**。

---

## 13. 最小实现计划（直接回答问题 19）

> **前置条件**：在 `research/thin-core-binary` 分支进行；保留 `backup/phase-5a-dual-binary-stable`。

### Step 1：Core 产物切片（不改 podspec、不碰 Demo）

1. **新增 Core 构建配置**
   - `xcFramework_build.sh` 增加 `core` 子命令：
     - Podfile 仅 `pod 'OpenSSL-Universal', '~> 3.6'`
     - xcodebuild 不注入 `FLAME_BUILD_TK`/`FLAME_BUILD_TB`（两个宏都不定义）
     - 产物输出 `build/core/flame_sdk_ios.xcframework`

2. **代码改造（仅 4 处，可原子提交）**
   - `FlameAdapterManager.m`：删除 `#if FLAME_BUILD_TK` 包裹的 AnyThink import 与 `initSDKWithAppId:`，保留中立骨架。
   - `FlameTKProvider.m`：承接 `initSDKWithAppId:` 逻辑（直接调 ATAPI）。
   - `FlameTKProvider.m` / `FlameTBProvider.m`：各加 `+load` 注册。
   - `FlameSdk.m`：删除 `#import "FlameTKProvider.h"`/`"FlameTBProvider.h"`；`registerAllProvidersIfNeeded` 改为 `NSClassFromString` 兜底。

3. **Core 符号校验（必须全过）**
   ```bash
   CORE_BIN="build/core/flame_sdk_ios.xcframework/ios-arm64/flame_sdk_ios.framework/flame_sdk_ios"
   du -h "$CORE_BIN"                                      # 期望 ~300K
   otool -L "$CORE_BIN" | grep -iE "AnyThink|WindMill|ToBid|Sigmob"   # 期望空
   nm -gU "$CORE_BIN" | grep -E "_OBJC_CLASS_\\\$_(AT|WindMill|Wind|Sigmob)" | head  # 期望空
   ```

### Step 2：端到端 Demo 验证（仅 Step 1 全过后）

4. **实验 podspec**（落盘 `research/` 目录，不动正式 podspec）
   - `flame_sdk_ios.thin_core.tk.podspec`：Core binary + TK source_files + AnyThink 依赖
   - `flame_sdk_ios.thin_core.tb.podspec`：Core binary + TB source_files + ToBid 依赖

5. **Demo 双 variant 接入**
   - TK：`pod 'flame_sdk_ios', :podspec => '...thin_core.tk.podspec'` → 验证 pt=tk 激活、5 类广告可用、无 duplicate class。
   - TB：`pod 'flame_sdk_ios_tb', :podspec => '...thin_core.tb.podspec'` → 验证 pt=tb 激活、WindMill 运行时拉入、无 dyld symbol not found。

6. **决策点**
   - 两 variant 均 OK → 进入替换决策（单独评审，不在本阶段）。
   - 任一失败 → 回退，记录阻塞点（见第 14 节）。

---

## 14. 若不推荐的阻塞点（直接回答问题 20）

本轮**未发现硬阻塞**，但列出需在 Step 1/2 重点验证的潜在风险点：

| 潜在阻塞 | 触发条件 | 应对 |
|---|---|---|
| `+load` 在某些 CocoaPods 静态链接配置下未执行 | 极少见（-ObjC 已配） | 方案 C 兜底已内置；若仍失败，改用 `__attribute__((constructor))`。 |
| Core xcframework 的 Headers/ 未包含平台源码需要的协议头 | podspec header 配置遗漏 | Step 2 ⑦ 精确配置 `public_header_files`/`private_header_files`。 |
| TB 平台源码编译时 WindMill 头找不到 | ToBid-iOS-RC 头搜索路径问题 | TB 实验 podspec 显式配 `HEADER_SEARCH_PATHS`。 |
| FlameAdapterManager 拆分后 TK 初始化行为微变 | ATAPI 调用时序变化 | Step 2 ⑤ TK Demo 回归 5 类广告初始化。 |

---

## 15. 问题清单逐条回答（汇总，对应第十二节 14 问）

| # | 问题 | 回答 |
|---|---|---|
| 1 | ToBid-iOS-RC 是否包含 WindMillSDK/WindSDK/WindFoundation | **是**，默认 `ToBidSDK` subspec 即 Core/*.xcframework（见第 2 节） |
| 2 | Core binary 构建期是否可完全不引入 AnyThink/ToBid | **可以**，core/ads/utils/mediation 根 0 三方 import（见第 3 节） |
| 3 | FlameAdapterManager 是否阻碍 thin core | **不阻碍**，TK init 迁 Provider 即可（见第 5 节） |
| 4 | At*Adapter / TbRewardAdapter 是否必须移出 Core | **必须**（三方 import 集中于此，见第 3、4 节） |
| 5 | FlameTKProvider / FlameTBProvider 是否必须移出 Core | **必须**（FlameSdk.m 直接 import 是破口，见第 6 节） |
| 6 | Provider 自动注册推荐机制 | **`+load` 为主 + `NSClassFromString` 兜底**（见第 6 节） |
| 7 | CocoaPods 是否支持同一 podspec vendored_frameworks + source_files | **支持**（标准模式，见第 7 节） |
| 8 | 两个 podspec 是否能引用同一 Core xcframework | **能**（互斥安装，路径共享，见第 7.3 节） |
| 9 | TK/TB 平台源码作为 source_files 是否能访问 Core 协议 | **能**（Core Headers/ 暴露协议头，见第 7.3 节） |
| 10 | 是否会改变对外 API | **不会**（见第 9 节） |
| 11 | 是否需要修改 flame_sdk_ios.h | **不需要**（见第 9 节） |
| 12 | 是否会影响老用户 pod 'flame_sdk_ios' | **不会**（见第 9 节） |
| 13 | 是否能彻底避免 Sigmob/WindSDK duplicate class | **能**（根因消除，见第 10 节） |
| 14 | 是否比当前双二进制更值得推进 | **值得**，分两步走，保留兜底（见第 12 节） |

---

## 16. 更新后的 /compact 摘要

```
Phase 5A.10 完成：单 Core Thin Binary 分发方案可行性调研（仅调研，未发布/未 tag/未进 Phase 6）。

【已落实保护】
- backup/phase-5a-dual-binary-stable 分支已建（→ d7d7837，与 feat/tb_adapter HEAD 同点）。
- build/tk（276K）、build/tb（6.9M）双二进制保留；双 podspec 保留；调研未改任何文件。

【关键调研结论】
1. ToBid-iOS-RC 5.5.6 default_subspecs=ToBidSDK，默认即拉 WindMillSDK+WindSDK+WindFoundation（Core/*.xcframework）。
   → Core 构建期绝不能引入 ToBid-iOS-RC，否则不再 thin。
2. 三方 import 审计：core/ads/utils/mediation 根 = 0；耦合全在 adapter/tk(9)、adapter/tb(1)、mediation/tb(1)、FlameAdapterManager(TK 守卫段)。
   → Core 构建期 Podfile 仅 OpenSSL 即可零三方符号。
3. FlameAdapterManager 须留 Core（ads/*Impl.m 依赖 checkInitialization），但需把 TK init 段迁 FlameTKProvider（≈30 行）。
4. Provider 注册推荐 +load 自动注册（podspec 已配 -ObjC，可靠）+ NSClassFromString 兜底；FlameSdk.m 删除对 Provider 类的直接 import。
5. CocoaPods 原生支持 vendored_frameworks + source_files 共存；两 podspec 可共享同一 Core xcframework。
6. 对外 API / flame_sdk_ios.h / 老用户 pod 'flame_sdk_ios' 三重不变。

【推荐】有条件推进，两步走：
- Step 1（≈0.7 人日）：Core 产物切片 + otool/nm 符号校验，不碰 podspec/Demo。
- Step 2（≈1.2 人日）：实验 podspec + Demo TK/TB 双 variant 运行时验证。
全程保留双二进制兜底，thin core 跑通后再单独决策是否替换。

【阻塞点】无硬阻塞；重点验证 +load 链接可靠性、Core Headers 协议头暴露、TB WindMill 头搜索路径。

【未完成/未做】
- 未创建 research/thin-core-binary 分支（纯调研）。
- 未实现任何代码改造。
- 未发布 0.1.8.5/0.1.8.6，未进 Phase 6。
- AtInterstitialAdapter.m 的 didRevenue→onAdReward bug（与 splash 同模式）仍未修，待用户指示。

报告落盘：doc/flame_mediation/phase-5a.10-thin-core-binary-research.md
```

---

**调研结束。未发布、未 tag、未 pod repo push、未进入 Phase 6、未删除双二进制兜底。等待用户决策是否进入 Step 1 实现。**
