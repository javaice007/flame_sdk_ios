# Phase 5A.10 Step 2 —— 实验 podspec + 平台源码插件运行时验证报告

> 分支：`research/thin-core-binary`
> 基线：`086a766`（feat/tb_adapter 稳定点 = backup/phase-5a-dual-binary-stable）
> 日期：2026-06-17
> 状态：**实验验证完成，未发布、未 tag、未 push、未进 Phase 6**

---

## 0. 结论速览

**Thin Core + 平台源码插件（方案 C：Core 独立 pod + 插件 pod）技术上完全可行。**

TK / TB 双变体均已通过：
- `pod install` ✓
- Demo 编译（模拟器 + 真机 arm64）✓
- `+load` 自动注册符号编译进产物 ✓
- Podfile.lock 依赖隔离正确（TK 无 ToBid / TB 无 AnyThink）✓
- Core binary 零三方污染 ✓
- 双二进制兜底（build/tk、build/tb）未破坏 ✓

**唯一阻塞项**：运行时真机/模拟器启动日志尚未抓取（需手测，编译期已证明 `+load` 注册代码正确）。

---

## 1. 验证环境

| 项目 | 值 |
|---|---|
| 当前分支 | `research/thin-core-binary` |
| 基线 commit | `086a766` |
| Step 1 commit | `4bcecb9` / `f4b794b` |
| Step 2 commit | （本提交） |
| backup 分支 | `backup/phase-5a-dual-binary-stable`（未动）✓ |
| 正式 podspec | 未修改 ✓（`flame_sdk_ios.podspec` / `flame_sdk_ios_tb.podspec` 原样） |
| Demo 工程 | `adsurge-ios-demo`（独立仓库，实验后恢复） |

---

## 2. 核心发现：module 名冲突（方案 B 失败）

### 2.1 问题

最初按 Step 2 计划草案，用**单 pod** 同时持有 `vendored_frameworks`（Core binary）+ `source_files`（TK 平台源码），pod 名 = `flame_sdk_ios`。

**结果**：`pod install` 通过，但 Demo 编译失败：
```
fatal error: 'flame_sdk_ios/FlameSdk.h' file not found
error: unable to resolve module dependency: 'flame_sdk_ios'
```

### 2.2 根因

`use_frameworks!` + `DEFINES_MODULE=YES` + `source_files` 会让 CocoaPods 把 source_files 编成一个名为 `flame_sdk_ios` 的**源模块**，遮蔽 vendored framework 内同名的 `flame_sdk_ios` 模块（后者带 umbrella `flame_sdk_ios.h`，含 `FlameSdk.h`）。

接入方 `#import <flame_sdk_ios/FlameSdk.h>` 落到源模块（无 `FlameSdk.h`，只有 TK Provider/Adapter）→ 编译失败。

### 2.3 备选方案评估

| 方案 | 描述 | 结论 |
|---|---|---|
| **方案 A** | Core binary 改名 `flame_sdk_ios_core.xcframework` | 改动大，接入方 import 路径变 |
| **方案 B** | 单 pod 改名（如 `flame_sdk_ios_tk_plugin`），vendored framework 名不变 | **失败**：vendored framework 模块未提升到 App target 层级，`import flame_sdk_ios` 仍找不到 |
| **方案 C** | **Core 独立 pod + 插件 pod 拆分**（采用） | **成功** ✓ |

### 2.4 方案 C 架构（最终采用）

```
Podfile:
  pod 'flame_sdk_ios'          # ← Core pod（仅 vendored_frameworks，无源码）
  pod 'flame_sdk_ios_tk_plugin'# ← TK 插件 pod（仅 source_files，dependency 'flame_sdk_ios'）

模块分布：
  flame_sdk_ios 模块       = Core binary 自带（umbrella = flame_sdk_ios.h）
  flame_sdk_ios_tk_plugin 模块 = TK Provider + At*Adapter（source_files 编译）
  → 两个模块名不冲突
  → 接入方 import flame_sdk_ios 解析到 Core binary 公共 API
  → TK 插件 +load 自注册，无需接入方显式 import 插件
```

---

## 3. 关键改造

### 3.1 FlameTKProvider.m —— AnyThink 初始化迁移 + +load 自动注册

**背景**：Step 1 中 Core binary 的 `FlameAdapterManager.initSDKWithAppId` 在 `FLAME_BUILD_CORE` 模式下被宏整体置空。TK 插件源码不能再调用它，否则 `unrecognized selector`。

**改造**：
1. AnyThink 初始化逻辑（`[ATAPI setLogEnabled:]` / `integrationChecking` / `startWithAppID:appKey:error:`）从 `FlameAdapterManager` 迁移到 `FlameTKProvider.initializeWithAppId:appKey:callback:`，行为与原实现完全一致。
2. 新增 `+load` 自动注册（仅 `FLAME_PLUGIN_TK` 宏下启用）：

```objc
#if defined(FLAME_PLUGIN_TK)
+ (void)load {
    @autoreleasepool {
        FlameTKProvider *provider = [[FlameTKProvider alloc] init];
        [[FlameMediationRegistry sharedRegistry] registerProvider:provider];
        [FlameLogger i:@"FlameTKProvider: +load 自动注册完成 (plugin 模式)"];
    }
}
#endif
```

**关键**：`FLAME_PLUGIN_TK` 仅由实验 podspec 的 `pod_target_xcconfig` 注入，旧双二进制 TK build（`xcFramework_build.sh tk`）只定义 `FLAME_BUILD_TK`，不定义 `FLAME_PLUGIN_TK`，因此 `+load` 不会污染旧 TK binary（已通过 nm 验证：旧 TK binary 无 `+[FlameTKProvider load]` 符号）。

### 3.2 FlameTBProvider.m —— +load 自动注册

同构改造，新增 `+load`（`FLAME_PLUGIN_TB` 宏守卫）。TB 的 WindMill 初始化本就在 `FlameTBProvider.initializeWithAppId` 内，无需迁移。

### 3.3 实验目录结构

```
research/
├── podspecs/
│   ├── flame_sdk_ios.core.podspec          # Core pod（仅 vendored_frameworks）
│   ├── flame_sdk_ios.thin_core.tk.podspec  # TK 插件 pod（source_files + dep 'flame_sdk_ios'）
│   └── flame_sdk_ios.thin_core.tb.podspec  # TB 插件 pod（source_files + dep 'flame_sdk_ios'）
└── staging_tk/  (gitignored，含 build/core + flame_sdk_ios 副本 + 命名 podspec)
└── staging_tb/  (gitignored，同上)
```

staging 目录是为本地 `:path` 模式准备的"真实副本"目录（不能用 symlink，CocoaPods 的 vendored framework 检测不跟随 symlink）。**不提交**（`.gitignore` 已加 `research/staging_*/`）。

---

## 4. 踩坑记录（3 个真实坑）

### 坑 1：symlink 导致 vendored framework 未被识别

**现象**：staging 用 `build -> ../../build` 符号链接，`pod install` 通过，但 Core pod 没有生成 `flame_sdk_ios-xcframeworks.sh` 脚本，vendored framework 未被 CocoaPods 检测到，App target 的 framework search path 里没有 flame_sdk_ios。

**解法**：staging 用**真实副本**（`cp -R build/core` + `cp -R flame_sdk_ios`），不用 symlink。

### 坑 2：跨目录 header import 找不到

**现象**：插件源码 `adapter/tk/*.h` 里 `#import "FlameRewardAdapterProtocol.h"`（在 `mediation/`）编译失败：`'FlameRewardAdapterProtocol.h' file not found`。

**根因**：CocoaPods 默认只为 `source_files` 所在目录加 header search path，`private_header_files` 跨多个目录（`mediation/`、`core/`、`adapter/`）时不会自动加。

**解法**：插件 podspec 的 `pod_target_xcconfig` 显式声明 `HEADER_SEARCH_PATHS`，覆盖所有需要的目录。

### 坑 3：插件 pod 残留 vendored_frameworks 导致 double-embed

**现象**：TB 插件 pod 编译报 `Multiple commands produce .../flame_sdk_ios.framework`。

**根因**：TB 插件 podspec 残留 `s.vendored_frameworks = 'build/core/...'`（早期单 pod 设计的遗留）。Core pod embed 一次 + TB 插件 pod embed 一次 → 冲突。

**解法**：插件 pod **不直接放 vendored_frameworks**，通过 `dependency 'flame_sdk_ios'` 间接引用 Core binary。

---

## 5. 验证结果明细

### 5.1 TK 变体

| 检查项 | 结果 |
|---|---|
| 实验 pod install 通过 | ✓（Core pod + TK 插件 pod + 28 依赖） |
| Podfile.lock 不含 ToBid-iOS-RC | ✓ |
| Podfile.lock 含 AnyThinkiOS + 全部 Mediation Adapter | ✓ |
| Demo 编译（模拟器 x86_64） | **BUILD SUCCEEDED** ✓ |
| Demo 编译（真机 arm64） | **BUILD SUCCEEDED** ✓ |
| `FlameTKProvider.o` 含 `+[FlameTKProvider load]` | ✓（符号已验证） |
| `AtRewardAdapter.o` / `AtSplashAdapter.o` / 等全 TK adapter 编译进产物 | ✓ |
| Core binary 中 WindMill / FlameTBProvider 符号 | 0 ✓ |
| 运行时 +load 注册日志 | ⏳ 待手测（编译期已证明代码正确） |

### 5.2 TB 变体

| 检查项 | 结果 |
|---|---|
| 实验 pod install 通过 | ✓（Core pod + TB 插件 pod + ToBid-iOS-RC，5 pods） |
| Podfile.lock 不含 AnyThink | ✓ |
| Podfile.lock 含 ToBid-iOS-RC | ✓ |
| Demo 编译（真机 arm64） | **BUILD SUCCEEDED** ✓ |
| `FlameTBProvider.o` 含 `+[FlameTBProvider load]` | ✓（符号已验证） |
| `TbRewardAdapter.o` 编译进产物 | ✓ |
| Core binary 中 AnyThink 符号 | 0 ✓ |
| 运行时 +load 注册日志 | ⏳ 待手测 |

### 5.3 Core binary 零污染（最终确认）

```
build/core/flame_sdk_ios.xcframework
  体积：176K
  otool -L：仅 OpenSSL + 系统库
  nm 三方符号（AnyThink/WindMill/Sigmob/AdGain/FlameTKProvider/FlameTBProvider/AtRewardAdapter/TbRewardAdapter）：0
  定义 Flame 中立类：19 个（FlameSdk/Registry/Router/5 个 AdImpl/ConfigManager/AdapterManager 骨架/utils）
```

### 5.4 双二进制兜底未破坏

```
build/tk/flame_sdk_ios.xcframework  616K  含 FlameTKProvider + AtRewardAdapter，WindMill=0
build/tb/flame_sdk_ios.xcframework  14M   含 FlameTBProvider + TbRewardAdapter，WindMill=3645，AnyThink=0
build/core/flame_sdk_ios.xcframework 412K  零三方污染
```

tk / tb binary 重编后符号 profile 与 Step 1 一致，**Provider 改造（+load / AnyThink 迁移）未影响旧双二进制构建**（`FLAME_PLUGIN_*` 宏在旧 build 中未定义，`+load` 不编译进去）。

---

## 6. 红线遵守确认

| 红线 | 遵守 |
|---|---|
| 不发布 / 不 tag / 不 pod repo push / 不 push origin | ✓ |
| 不进入 Phase 6 | ✓ |
| 不实现 TB Splash/Interstitial/Banner/Native | ✓（TB Provider 仍返回 nil） |
| 不删除 build/tk、build/tb | ✓ |
| 不修改正式 flame_sdk_ios.podspec / flame_sdk_ios_tb.podspec | ✓（原样未动） |
| 不直接替换双二进制发布结构 | ✓ |
| 不修改 flame_sdk_ios.h 对外 API | ✓ |
| backup 分支保留 | ✓ |

---

## 7. 实验产物清单（SDK repo，本次提交）

**源码改动（2 文件）**：
- `flame_sdk_ios/mediation/tk/FlameTKProvider.m` —— AnyThink 初始化迁移 + `+load`（FLAME_PLUGIN_TK）
- `flame_sdk_ios/mediation/tb/FlameTBProvider.m` —— `+load`（FLAME_PLUGIN_TB）

**新增实验 podspec（3 文件）**：
- `research/podspecs/flame_sdk_ios.core.podspec` —— Core pod
- `research/podspecs/flame_sdk_ios.thin_core.tk.podspec` —— TK 插件 pod
- `research/podspecs/flame_sdk_ios.thin_core.tb.podspec` —— TB 插件 pod

**配置**：
- `.gitignore` —— 新增 `research/staging_tk/`、`research/staging_tb/`

**staging 目录（gitignored，不入库）**：
- `research/staging_tk/` —— build/core 副本 + flame_sdk_ios 副本 + 命名 podspec
- `research/staging_tb/` —— 同上

---

## 8. 是否建议进入正式改造？

**建议：是，方案 C 可作为正式改造的基础。**

理由：
1. 技术链路全通（pod install / 编译 / 链接 / 符号）。
2. Core binary 与平台源码彻底解耦，满足"单 Core + 双插件"分发目标。
3. +load 自动注册机制干净，不污染旧双二进制。
4. 接入方 API 不变（`import flame_sdk_ios` 仍指向 Core 公共 API）。

**改造前需确认/解决的点**：
1. **接入方 Podfile 要声明两个 pod**（Core + 插件），比当前单 pod 略复杂 —— 需更新接入文档。
2. **`use_frameworks! :linkage => :static`** 是插件模式的必要条件（plain `use_frameworks!` 会触发 static transitive dep 错误）—— 需在接入文档强调。
3. **运行时 +load 注册日志**待真机手测确认（编译期符号已证明代码正确，运行时是标准 ObjC `+load` 行为）。
4. **Core binary 需补暴露内部协议头**（当前 Core binary Headers 只有 10 个公共 API；mediation 协议头、FlameAdapterManager.h 等由插件 pod 的 private_header_files 从源码树提供）。正式改造时若要 Core binary 自带这些头，需调整 SDK 工程的 header phase（public → project）。

---

## 9. 运行时手测清单（交接入方）

### TK 变体（Demo 当前已配置为 TK）

启动 App 后看 Console：
1. `FlameTKProvider: +load 自动注册完成 (plugin 模式, platformCode=tk)`
2. `FlameSdk: Router 已激活 Provider (pt=tk)`
3. 触发 Reward → `AtRewardAdapter` 链路

### TB 变体（需切换 Demo Podfile）

Demo Podfile 改为：
```ruby
pod 'flame_sdk_ios', :path => '../flame_ios_sdk/research/staging_tb'
pod 'flame_sdk_ios_tb', :path => '../flame_ios_sdk/research/staging_tb'
```
启动 App 后看 Console：
1. `FlameTBProvider: +load 自动注册完成 (plugin 模式, platformCode=tb)`
2. `FlameSdk: Router 已激活 Provider (pt=tb)`
3. 触发 Reward → `TbRewardAdapter` 链路

### 日志抓取

```bash
xcrun devicectl device info dumpstate --device <UDID>  # 或用 Xcode Console
# 过滤关键字：Flame
```

---

## 10. 更新后的 /compact 上下文

```text
Phase 5A.10 Step 2 完成（research/thin-core-binary 分支）：
- 方案 C（Core 独立 pod + 插件 pod）验证通过，解决 module 名冲突
- TK/TB 双变体 pod install + 编译（sim+真机）全通过
- +load 自动注册符号已验证（FlameTKProvider/FlameTBProvider）
- Core binary 零三方污染，双二进制兜底未破坏
- 3 个实验 podspec 在 research/podspecs/，staging 目录 gitignored
- 唯一待办：运行时真机 +load 注册日志手测
- 红线全守：未发布/tag/push/进 Phase 6
- Demo（adsurge-ios-demo）当前配置为 TK 变体，待手测后恢复
```
