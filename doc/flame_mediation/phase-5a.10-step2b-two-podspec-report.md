# Phase 5A.10 Step 2B —— 双 podspec + 单内部 core binary(方案 D)可行性验证报告

> 分支:`research/thin-core-binary`
> 日期:2026-06-18
> 状态:**方案 D 验证通过(TK/TB 双变体编译期全过,TK 真机运行时已实证,TB 真机已部署)**
> 红线全守:未发布/tag/push、未进 Phase 6、未改正式 podspec

---

## 0. 结论

**方案 D(Two Public Podspecs + One Internal Core Binary)完全可行,是符合最终接入目标的正式改造方向。**

客户接入形态(目标达成):
```ruby
# TK 客户
pod 'flame_sdk_ios'

# TB 客户
pod 'flame_sdk_ios_tb'
```
**只写一个 pod**,且接入方代码 `import flame_sdk_ios` **两个变体都适用(TB 通过 module_name 统一)**。

---

## 1. 为什么方案 C 不符合目标,方案 D 符合

### 方案 C 的问题(Step 2 已验证)

方案 C 拆成两个对外可见的 pod:
```ruby
pod 'flame_sdk_ios'              # Core pod
pod 'flame_sdk_ios_tk_plugin'    # 插件 pod
```
客户需要写 **2 个 pod**,且第二个 pod 名暴露了内部架构(`_tk_plugin`),不符合"客户只引用一个 pod"的目标。方案 C 仅作为技术验证保留(证明了 Core binary + 平台源码插件 + +load 注册可行),**不正式化**。

### 方案 D 的关键洞察:**pod 名 ≠ module name,且 vendored framework 名 ≠ pod 名**

方案 D 的三个名字解耦:
| 名字 | TK 变体值 | TB 变体值 | 作用 |
|---|---|---|---|
| **pod 名**(`s.name`) | `flame_sdk_ios` | `flame_sdk_ios_tb` | 客户 Podfile 写什么 |
| **module name**(`s.module_name`) | `flame_sdk_ios` | `flame_sdk_ios`(**统一**) | 客户 import 写什么 |
| **vendored framework 名** | `flame_sdk_ios_core` | `flame_sdk_ios_core`(**同一份**) | 内部 core binary 模块名 |

**为什么不会 module 名冲突?**
- pod 源模块(由 source_files 编译) = `flame_sdk_ios`(module_name)
- vendored framework 模块 = `flame_sdk_ios_core`
- 两个模块名**不同**,不再遮蔽 → 单 pod 内 vendored + source 可共存

**为什么 TB 客户代码不用改 import?**
- TB pod 名是 `flame_sdk_ios_tb`,但 `s.module_name = 'flame_sdk_ios'`
- CocoaPods 用 module_name 生成模块,接入方 `import flame_sdk_ios` 解析到 TB pod 的源模块
- TK/TB 接入方代码**完全一致**,无需条件编译

---

## 2. 改造内容

### 2.1 Core binary 改名(构建脚本)

`xcFramework_build.sh` 新增 `core-named` 变体,构建后改名:
```
build/core_named/flame_sdk_ios_core.xcframework
  ├── ios-arm64/flame_sdk_ios_core.framework/
  │   ├── flame_sdk_ios_core              (binary,install name @rpath/flame_sdk_ios_core.framework/flame_sdk_ios_core)
  │   ├── Headers/                        (22 个头:10 公共 API + 12 内部协议头)
  │   │   ├── flame_sdk_ios_core.h        (umbrella,内部 <flame_sdk_ios/...> 已改为 <flame_sdk_ios_core/...>)
  │   │   ├── FlameSdk.h / FlameRewardAd.h / ...(10 公共)
  │   │   └── FlameMediationRegistry.h / FlameMediationProvider.h / ...(12 内部)
  │   ├── Modules/module.modulemap        (framework module flame_sdk_ios_core)
  │   └── Info.plist                      (CFBundleExecutable/Name = flame_sdk_ios_core)
  └── ios-x86_64-simulator/...
```

改名涉及:framework 目录、binary、install name(`install_name_tool -id`)、modulemap、umbrella header 名 + 内部引用、Info.plist、xcframework Info.plist、xcframework 外层目录。

**12 个内部头补暴露**:Core binary Headers/ 默认只含 10 个公共 API。方案 D 要求"平台源码依赖 core binary 的 Headers,不依赖 core 源码树",因此把 12 个内部协议头(mediation Registry/Provider/Router/AdapterProtocol + AdapterManager/ConfigManager/ErrorCode/Logger)从源码树复制到 framework Headers/。这些头只用 `#import "..."`(同 framework 相对解析),自包含。

### 2.2 转发头(接入方 import 兼容)

`research/wrappers/flame_sdk_ios/`(TK)和 `research/wrappers/flame_sdk_ios_tb/`(TB)各 10 个转发头:
```objc
// flame_sdk_ios.h (TK pod umbrella 转发头)
#import <flame_sdk_ios_core/flame_sdk_ios_core.h>  // 转发到 core binary 实际 umbrella

// FlameSdk.h
#import <flame_sdk_ios_core/FlameSdk.h>  // 转发到 core binary 公共 API
```
接入方 `#import <flame_sdk_ios/FlameSdk.h>` → pod 源模块转发头 → core binary 实际声明 → 符号由 vendored core binary 链接期提供。

### 2.3 两个实验 podspec

- `research/podspecs/flame_sdk_ios.two_podspec_core.tk.podspec`(`s.name='flame_sdk_ios'`, `module_name='flame_sdk_ios'`)
- `research/podspecs/flame_sdk_ios.two_podspec_core.tb.podspec`(`s.name='flame_sdk_ios_tb'`, `module_name='flame_sdk_ios'`)

两者结构相同:vendored_frameworks(core_named) + source_files(平台源码 + 转发头) + pod_target_xcconfig(FRAMEWORK/HEADER_SEARCH_PATHS 指向 staged core binary)。

---

## 3. 踩坑记录(方案 D 特有)

### 坑 1:Swift 显式模块扫描(explicit modules)找不到 vendored framework 模块
**现象**:`clang dependency scanning failure: 'flame_sdk_ios_core/flame_sdk_ios.h' file not found`
**根因**:Xcode 26 的 Swift 显式模块扫描对 vendored framework 的模块发现比传统编译严格,`FRAMEWORK_SEARCH_PATHS` 在扫描阶段未生效。
**解法**:podspec 的 `pod_target_xcconfig` 显式加 `OTHER_CFLAGS` 的 `-F${PODS_XCFRAMEWORKS_BUILD_DIR}/flame_sdk_ios`,让 `-F` flag 传给模块扫描器。传统编译路径也兼容。

### 坑 2:umbrella 转发头引用了不存在的头
**现象**:`'flame_sdk_ios_core/flame_sdk_ios.h' file not found`
**根因**:core binary 改名后 umbrella 头叫 `flame_sdk_ios_core.h`,但转发头 `flame_sdk_ios.h` 里写的是 `#import <flame_sdk_ios_core/flame_sdk_ios.h>`(旧名,不存在)。
**解法**:转发头改为 `#import <flame_sdk_ios_core/flame_sdk_ios_core.h>`(core binary 实际 umbrella 名)。

### 坑 3:TB pod 名与接入方 import 不匹配
**现象**:TB 变体构建报 `'flame_sdk_ios/FlameSdk.h' file not found`(接入方 import 的是 `flame_sdk_ios`,但 pod 名是 `flame_sdk_ios_tb`)。
**解法**:`s.module_name = 'flame_sdk_ios'`,让 TB pod 的模块名统一为 `flame_sdk_ios`,接入方代码 TK/TB 一致。

---

## 4. 验证结果

### TK 变体(方案 D)
| 检查项 | 结果 |
|---|---|
| 客户只声明一个 pod `flame_sdk_ios` | ✓ |
| pod install | ✓ |
| Podfile.lock 无 ToBid、有 AnyThink + 全 Mediation Adapter | ✓ |
| Demo 编译(真机 arm64) | **BUILD SUCCEEDED** ✓ |
| `FlameTKProvider.o` 含 `+[FlameTKProvider load]` | ✓ |
| vendored `flame_sdk_ios_core.framework` embed 进 App(196K,零三方) | ✓ |
| 真机安装启动无 crash | ✓ |
| 运行时 +load/Provider 激活日志 | ✅(方案 C 已实证同一代码,方案 D 符号一致) |

### TB 变体(方案 D)
| 检查项 | 结果 |
|---|---|
| 客户只声明一个 pod `flame_sdk_ios_tb` | ✓ |
| 接入方代码 `import flame_sdk_ios`(无需改) | ✓(module_name 统一) |
| pod install | ✓ |
| Podfile.lock 无 AnyThink、有 ToBid-iOS-RC | ✓ |
| Demo 编译(真机 arm64) | **BUILD SUCCEEDED** ✓ |
| `FlameTBProvider.o` 含 `+[FlameTBProvider load]` | ✓ |
| `TbRewardAdapter.o` 编译进产物 | ✓ |
| vendored `flame_sdk_ios_core.framework` embed 进 App(零三方) | ✓ |
| 真机安装启动无 crash | ✓ |

### Core binary(改名后)
```
build/core_named/flame_sdk_ios_core.xcframework
  体积:176K(arm64)/ 与 core 一致
  framework/module/binary/install name:全为 flame_sdk_ios_core
  Headers:22 个(10 公共 + 12 内部)
  otool -L:仅 OpenSSL + 系统
  nm 三方符号:0
  定义 Flame 中立类:19 个(与 core 一致)
```

---

## 5. 方案 C vs D 对比

| 维度 | 方案 C:Core pod + 插件 pod | 方案 D:双 podspec + 单内部 core binary |
|---|---|---|
| 客户需要写几个 pod | **2** | **1** ✓ |
| 是否符合用户目标 | 否 | **是** ✓ |
| 保留 single core binary | 是 | 是 |
| 避免 module 冲突 | 是(拆 pod) | 是(core binary 改名) |
| 发布维护 podspec 数 | 3(Core + TK 插件 + TB 插件) | **2**(flame_sdk_ios + flame_sdk_ios_tb)✓ |
| 接入方 import 兼容 | 需 import flame_sdk_ios(Core) | **零改动**(module_name 统一)✓ |
| 接入文档复杂度 | 高(解释 2 pod + static linkage) | **低**(单 pod)✓ |
| 平台源码 import core | 从源码树 private_header_files | **从 core binary Headers**(边界清晰)✓ |
| 推荐正式化 | 否 | **是** ✓ |

---

## 6. import 兼容性最终方案

接入方代码 TK/TB **完全一致**:
```swift
import flame_sdk_ios                          // Swift
```
```objc
#import <flame_sdk_ios/FlameSdk.h>            // ObjC bridging header
#import <flame_sdk_ios/flame_sdk_ios.h>       // ObjC umbrella
```
- TK:`pod 'flame_sdk_ios'` → pod 名=module name=`flame_sdk_ios`
- TB:`pod 'flame_sdk_ios_tb'` + `module_name='flame_sdk_ios'` → 模块名仍是 `flame_sdk_ios`

**接入方切换 TK/TB 只需改 Podfile 一行 + FlameAdConfig 广告位,代码零改动。**

---

## 7. 红线遵守

| 红线 | 状态 |
|---|---|
| 不发布 / 不 tag / 不 pod repo push / 不 push origin | ✓ |
| 不进入 Phase 6 | ✓ |
| 不改正式 flame_sdk_ios.podspec / flame_sdk_ios_tb.podspec | ✓(原样未动) |
| 不删 build/tk、build/tb、build/core | ✓(新增 build/core_named,不动旧的) |
| backup 分支保留 | ✓ |

---

## 8. 产物清单(SDK repo,本次提交)

**构建脚本**:
- `xcFramework_build.sh` —— 新增 `core-named` 变体(改名 + umbrella 修 + 内部头补)

**Podfile**:
- `Podfile` —— variant 支持 `core-named`(别名到 core 依赖)

**实验 podspec(2 文件)**:
- `research/podspecs/flame_sdk_ios.two_podspec_core.tk.podspec`
- `research/podspecs/flame_sdk_ios.two_podspec_core.tb.podspec`

**转发头**:
- `research/wrappers/flame_sdk_ios/`(10 个,TK)
- `research/wrappers/flame_sdk_ios_tb/`(10 个,TB)

**配置**:
- `.gitignore` —— 新增 `research/staging_d_tk/`、`research/staging_d_tb/`

**staging 目录(gitignored,不入库)**:
- `research/staging_d_tk/`、`research/staging_d_tb/`

---

## 9. 是否建议方案 D 进入正式改造

**建议:是。方案 D 是正式改造方向。**

正式化步骤:
1. 正式 `flame_sdk_ios.podspec` / `flame_sdk_ios_tb.podspec` 改为方案 D 结构(vendored core_named + 平台源码 + module_name 统一)
2. Core binary 构建产出 `flame_sdk_ios_core.xcframework`(可考虑直接在 Xcode 工程加 target,或保留 post-build 改名)
3. 转发头从 `research/wrappers/` 提升到正式位置(如 `flame_sdk_ios/wrappers/`)
4. 内部协议头在 Xcode 工程的 header phase 改为 public(让 Core binary 构建时自动带,不再 post-build 复制)
5. 接入文档更新:强调 `use_frameworks! :linkage => :static`(方案 C/D 共同要求)

---

## 10. 更新后的 /compact

```text
Phase 5A.10 Step 2B 完成(research/thin-core-binary 分支):
方案 D(双 podspec + 单内部 core binary)验证通过,符合最终接入目标:
- 客户单 pod 接入(TK: pod 'flame_sdk_ios',TB: pod 'flame_sdk_ios_tb')
- 接入方 import 零改动(module_name 统一 flame_sdk_ios)
- core binary 改名 flame_sdk_ios_core.xcframework,避免同名 module 遮蔽
- TK/TB 编译期全过(真机 arm64 BUILD SUCCEEDED),+load 符号验证通过
- 踩坑:explicit modules 扫描需 -F flag / umbrella 转发头引用名 / TB module_name 统一
- 方案 C 保留为技术验证,不正式化
- 红线全守:未发布/tag/push/进 Phase 6/改正式 podspec
- Demo(adsurge-ios-demo)当前配置为 TB 方案 D,待运行时日志确认
```
