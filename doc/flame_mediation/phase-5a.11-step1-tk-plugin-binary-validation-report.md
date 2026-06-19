# Phase 5A.11 Step 1：TK Plugin Binary 本地构建与符号验证报告

**日期**: 2026-06-18
**分支**: `research/thin-core-binary`
**HEAD**: `3489d12` (未推进，无新 commit)
**阶段**: 方案 E 实证（仅本地验证，**不发布**）

---

## 0. 执行摘要

本阶段把方案 E（Core Binary + Platform Plugin Binary）从「纸面可行」推进到「TK 插件二进制实证可行」。

**核心结论**：
- ✅ TK plugin binary 本地构建成功（`build/tk/flame_sdk_ios.xcframework`，172K）
- ✅ 二进制纯净度全部通过（7 个期望符号在位，0 个 core 泄漏，0 个三方 SDK 污染，0 个 TB 符号）
- ✅ `+load` 符号存在（`FLAME_PLUGIN_TK` 宏生效）
- ✅ 客户 Pods 不再暴露任何 `.m` 源码（方案 D 的 7 个 → 方案 E 的 0 个）
- ⚠️ Demo 完整 build 未通过——根因是 **CocoaPods `:path` dev pod + vendored xcframework 组合的 staging 限制**，非方案 E 设计缺陷（详见 §9）

**红线遵守情况**：
- ❌ 未发布 alpha.3
- ❌ 未 push / 未 tag
- ❌ 未 pod repo push
- ❌ 未改 github_build 分发仓库
- ❌ 未进入 Phase 6
- ❌ 未实现 TB Splash/Interstitial/Banner/Native
- ❌ 未继续优化 source_files 方案
- ❌ 未把 `s.static_framework = true` 当主线

---

## 1. 当前分支 / HEAD / 发布状态

```
分支: research/thin-core-binary
HEAD: 3489d12 (Phase 5A.10 Step 4D，未推进)
```

- **未发布**：无 alpha.3 tag，无 push，无 pod repo push
- **未改动分发仓库**：github_build/flame_sdk_ios 未触碰
- **工作区改动**（均属本阶段实验，未 commit）：
  - `xcFramework_build.sh`（新增 tk-plugin 变体）
  - `Podfile`（新增 tk-plugin → tk 映射）
  - `research/`（新增实验 podspec + local_pod 验证目录）
  - 其余 `flame_sdk_ios.podspec` / `flame_sdk_ios_tb.podspec` / `project.pbxproj` 为上一阶段 alpha.2 改动

---

## 2. tk-plugin 构建变体实现

### 2.1 设计决策：EXCLUDED_SOURCE_FILE_NAMES（零源码改动）

**问题**：Xcode 16 工程使用 `fileSystemSynchronizedGroups`，默认把 `flame_sdk_ios/` 下所有 `.m` 编进 Sources phase。tk-plugin 二进制只能含平台源码（wrappers + mediation/tk + adapter/tk），不能重复编译 core/ads/utils（它们的符号已存在于 core binary，重复编译会导致接入期 duplicate symbol）。

**方案对比**：

| 方案 | 机制 | 源码改动 | 风险 |
|------|------|----------|------|
| A. 宏守卫 | 给 19 个 core/ads/utils 文件加 `#if !defined(FLAME_BUILD_PLUGIN_TK)` | 19 文件 | 侵入性高，易漏 |
| **B. EXCLUDED_SOURCE_FILE_NAMES**（采用） | xcodebuild build setting 层剔除 | **0** | 纯构建脚本层，干净 |

**采用方案 B**：在 `xcFramework_build.sh` 的 tk-plugin 分支注入：
```bash
EXCLUDED_SOURCE_FILE_NAMES='FlameAppEntity.m FlameConfigManager.m ... (22 个文件)'
OTHER_LDFLAGS='$(inherited) -undefined dynamic_lookup'
GCC_PREPROCESSOR_DEFINITIONS='$(inherited) COCOAPODS=1 FLAME_BUILD_TK=1 FLAME_PLUGIN_TK=1'
```

排除的 22 个 `.m`：core(5) + ads(7) + utils(5) + mediation根(2) + adapter根(1) + tb(2)。

### 2.2 关键修复：`-undefined dynamic_lookup`

首次构建在 link 阶段失败：
```
Undefined symbols for architecture arm64:
  "_OBJC_CLASS_$_FlameAdapterManager", referenced from: FlameTKProvider.o
  "_OBJC_CLASS_$_FlameLogger", referenced from: AtBannerAdapter.o
  "_ERROR_CODE_INVALID_AD_PLACEMENT", referenced from: At*Adapter.o
```

**这是预期的**——这些符号存在于 core binary，tk-plugin 不应重复定义。修复：注入 `-undefined dynamic_lookup`，允许 link 期保留未定义符号，接入期由 core binary 解析。这是标准两 framework 协作的 link 模型。

### 2.3 Headers/Modules 后处理

archive 产出的 framework Headers 为空（因为 publicHeaders 硬编码指向被剔除的 ads/core 路径）。脚本后处理：
- 清空 Headers/，拷入 10 个 wrappers 转发头（FlameSdk.h 等，`#import <flame_sdk_ios_core/...>`）
- 重写 modulemap：`framework module flame_sdk_ios { umbrella header "flame_sdk_ios.h" ... }`

### 2.4 构建结果

```
./xcFramework_build.sh tk-plugin
→ build/tk/flame_sdk_ios.xcframework
  ├── ios-arm64/flame_sdk_ios.framework/flame_sdk_ios  (172K)
  └── ios-x86_64-simulator/flame_sdk_ios.framework/flame_sdk_ios  (124K)
```

**ARCHIVE SUCCEEDED** + xcframework 合并成功 + 符号校验全通过。

---

## 3. TK plugin binary 是否包含 FlameTKProvider / At*Adapter

**✅ 全部在位**（`nm -gU` 检查，ios-arm64 切片）：

| 类 | 符号数 | 状态 |
|----|--------|------|
| FlameTKProvider | 1 | ✅ |
| AtRewardAdapter | 1 | ✅ |
| AtSplashAdapter | 1 | ✅ |
| AtInterstitialAdapter | 1 | ✅ |
| AtBannerAdapter | 1 | ✅ |
| AtNativeAdapter | 1 | ✅ |
| AtNativeSelfRenderView | 1 | ✅ |

---

## 4. TK plugin binary 是否未打入 WindMill / ToBid（TB 符号）

**✅ 零 TB 符号**：
```
nm -gU 检查 FlameTBProvider / TbRewardAdapter / WindMillSDK / WindMillAds → 0 个
```

---

## 5. TK plugin binary 是否未大量打入 AnyThinkMediation / 广告源 SDK

**✅ 零三方广告源 SDK 静态符号**：
```
nm -gU 检查 AdGain / BU / CSJ / BaiduMob / GDTMob / KSAd / FSUnion / Sigmob / Wind → 0 个
```

**otool -L 动态依赖**（仅引用，未静态嵌入）：
```
@rpath/AnyThinkSDK.framework/AnyThinkSDK    ← 运行期由 AnyThinkiOS pod 提供
@rpath/OpenSSL.framework/OpenSSL            ← 运行期由 OpenSSL-Universal pod 提供
+ 系统库（libc++/libresolv/libsqlite3/libxml2/libz/CoreGraphics/Foundation/UIKit/...）
```

**未定义符号**（`nm -u`，接入期解析）：
```
_OBJC_CLASS_$_FlameAdapterManager     ← core binary 提供
_OBJC_CLASS_$_FlameBannerAdMaterial   ← core binary 提供
_OBJC_CLASS_$_FlameLogger             ← core binary 提供
_OBJC_CLASS_$_FlameMediationRegistry  ← core binary 提供
_ERROR_CODE_INVALID_AD_PLACEMENT      ← core binary (FlameErrorCode.m) 提供
_ERROR_CODE_INVALID_PARAM             ← core binary (FlameErrorCode.m) 提供
AT* 引用 ×6                            ← AnyThinkiOS 提供
```

体积佐证：172K（仅 TK 平台胶水层，无三方 SDK 膨胀）。

---

## 6. otool -L 结果

见 §5。核心：**无三方广告 SDK 动态依赖残留**（除 AnyThinkSDK / OpenSSL 这两个构建期 Pod 依赖）。

---

## 7. nm 检查结果汇总

| 检查项 | 方法 | 期望 | 实际 | 状态 |
|--------|------|------|------|------|
| plugin 主体符号 | `nm -gU` grep 7 类 | 各 1 | 各 1 | ✅ |
| core 类泄漏 | `nm -gU` grep 20 core 类 | 0 | 0 | ✅ |
| 三方广告源污染 | `nm -gU` grep 9 SDK | 0 | 0 | ✅ |
| TB 平台符号 | `nm -gU` grep TB | 0 | 0 | ✅ |
| core 未定义引用 | `nm -u` grep Flame | >0 | 4 类 | ✅ |
| AnyThink 未定义引用 | `nm -u` grep AT* | >0 | 6 | ✅ |
| +load 符号 | `nm` grep `+[FlameTKProvider load]` | 存在 | 存在 | ✅ |

---

## 8. 客户 Pods 目录是否还暴露 .m

**✅ 方案 E：0 个 `.m`**（对比方案 D alpha.2 的 7 个）

实验 podspec（`research/local_pod/flame_sdk_ios.podspec`）接入 Demo 后：
```
find Pods -path "*flame_sdk*" \( -name "*.m" -o -name "*.mm" \) → 空
```

方案 D alpha.2 暴露的 7 个文件在方案 E 中全部隐藏：
```
✅ AtInterstitialAdapter.m   ✅ AtNativeAdapter.m
✅ AtRewardAdapter.m         ✅ AtBannerAdapter.m
✅ AtNativeSelfRenderView.m  ✅ AtSplashAdapter.m
✅ FlameTKProvider.m
```

**方案 E 核心目标达成：客户看不到 Provider/Adapter 源码。**

---

## 9. Demo build 验证：发现 CocoaPods `:path` dev pod staging 限制

### 9.1 现象

Demo 切到实验 podspec 后：
- ✅ `pod install` 成功（28 个 pod，含 flame_sdk_ios 1.0.0-alpha.3-local）
- ✅ Pods 目录零 `.m` 源码（§8）
- ✅ flame_sdk_ios pod target 单独 build 成功
- ❌ App target build 失败：`unable to resolve module dependency: 'flame_sdk_ios'`

### 9.2 根因分析

逐步定位到 **CocoaPods `:path` dev pod + vendored xcframework 组合的 staging 限制**：

1. 实验 podspec 声明 `vendored_frameworks = [core.xcframework, tk/flame_sdk_ios.xcframework]`
2. CocoaPods 生成了 `flame_sdk_ios-xcframeworks.sh` staging 脚本（输出到 `${PODS_XCFRAMEWORKS_BUILD_DIR}/flame_sdk_ios/`）
3. 但该脚本 **在 `:path` dev pod 模式下不执行**（pod build 日志无 xcframeworks 脚本运行记录，staging 目录为空）
4. 导致 `flame_sdk_ios_core` 模块在 App 编译期不可见 → bridging header `#import <flame_sdk_ios_core/FlameSdk.h>` 失败

**关键判据**：这不是方案 E 设计缺陷，而是本地 `:path` 验证方式的限制：
- 方案 D alpha.2 通过 **远程 spec**（GitHub release zip）接入时正常工作
- 远程 spec 模式下 CocoaPods 下载源码到 `Pods/flame_sdk_ios/`，vendored framework 处理路径不同
- `:path` dev pod 模式下，vendored xcframework 的 `[CP] Copy XCFrameworks` 脚本阶段不触发

### 9.3 已尝试的修复（均未根治 staging 问题）

| 尝试 | 结果 |
|------|------|
| `user_target_xcconfig` 加 `FRAMEWORK_SEARCH_PATHS` 指向 staging 目录 | staging 目录为空，无效 |
| `source_files` 改为仅 wrappers 头（让模块从源码生成） | 模块生成了，但 `flame_sdk_ios_core` 仍不可见 |
| 直接指向 xcframework slice 路径（绕过 staging） | `flame_sdk_ios_core` 解析了，但 `flame_sdk_ios` 模块本身仍需 staging |
| 先 build pod target 再 build app | pod staging 脚本不运行，framework 不产出 |

### 9.4 结论与后续

**Demo 完整 build 未通过，但根因明确且可规避**：
- 本地 `:path` 验证无法完整跑通 App build（CocoaPods 限制）
- 生产路径（远程 spec + GitHub release）应能正常工作（与 alpha.2 同机制）
- **建议**：Step 2 改为通过**远程 spec** 验证（本地构建 binary → 打 tag → 推 flame-specs → Demo pod install 远程 spec），但这需要发布一个实验性 tag（如 `1.0.0-alpha.3-exp`），需用户授权

---

## 10. public headers 是否可见

**✅ 可见**（framework Headers/ 含 10 个 wrappers 转发头）：
```
FlameSdk.h / flame_sdk_ios.h / FlameBannerAd.h / FlameBannerAdMaterial.h /
FlameBannerAdRenderSlots.h / FlameCallback.h / FlameInterstitialAd.h /
FlameNativeAd.h / FlameRewardAd.h / FlameSplashAd.h
```

接入方 `#import <flame_sdk_ios/FlameSdk.h>` 经转发到 `flame_sdk_ios_core` 模块。

---

## 11. internal headers 是否暴露

**✅ 未暴露**。tk-plugin framework Headers/ 仅含 wrappers 转发头，不含：
- mediation 协议头（FlameMediationRegistry/Provider/Router/Adapter protocols）
- core 内部头（FlameAdapterManager/ConfigManager/ErrorCode/Logger）

这些内部头仅在 core binary 的 Headers/ 中（core-named 后处理时补暴露的 12 个），tk-plugin 不重复暴露。

---

## 12. Demo pod install 是否通过

**✅ 通过**（实验 podspec 接入）：
```
Pod installation complete! There are 2 dependencies from the Podfile and 28 total pods installed.
Installing flame_sdk_ios (1.0.0-alpha.3-local)
```

（SmartdigimktCNSDK 的 LICENSE 读取警告无关，alpha.2 也存在。）

---

## 13. Demo build 是否通过

**❌ 未通过**（详见 §9）。根因：CocoaPods `:path` dev pod 的 vendored xcframework staging 限制，非方案 E 设计缺陷。

---

## 14. 真机 +load 是否通过

**⏸️ 未验证**（依赖 §13 Demo build，未到达运行阶段）。

但二进制层面已确认 `+load` 符号存在（§7），且 `-ObjC` flag 已在 podspec 配置。真机验证需待 Demo build 打通后进行。

---

## 15. TK 广告链路是否通过

**⏸️ 未验证**（依赖 §14）。

---

## 16. 是否建议进入 TB plugin binary 验证

**✅ 建议进入，但有前提**。

TK plugin binary 的**构建侧**已完全验证通过（纯净度、符号、+load、源码隔离）。TB plugin binary 的构建机制与 TK 完全对称（同样的 `EXCLUDED_SOURCE_FILE_NAMES` + `-undefined dynamic_lookup` + `FLAME_BUILD_TB` + `FLAME_PLUGIN_TB`），可低风险推进。

**前提**：先解决 §9 的集成验证路径问题（远程 spec 验证），否则 TB 也会卡在同一 staging 限制上。

---

## 17. 风险点

### 17.1 已识别风险

| 风险 | 等级 | 说明 |
|------|------|------|
| CocoaPods `:path` staging 限制 | 🟡 中 | 本地验证无法完整跑通 App build；生产远程 spec 应规避，但未实证 |
| 双 framework 模块查找 | 🟡 中 | wrappers 转发头 `#import <flame_sdk_ios_core/...>` 需 core 模块在搜索路径；远程 spec 下 CocoaPods 是否自动处理待验证 |
| `+load` 真机执行 | 🟠 中高 | 二进制符号已确认，但真机 dyld 加载 + `-ObjC` 链接 + `__objc_nlclslist` 段保留需真机实证 |
| 静态链接 transitive 依赖 | 🟢 低 | 本阶段保持 `use_frameworks! :linkage => :static`，未引入 `s.static_framework` 复杂度 |
| EXCLUDED_SOURCE_FILE_NAMES 维护 | 🟢 低 | 新增 core/ads/utils 源文件时需同步加入排除列表（可加构建期校验） |

### 17.2 后续验证计划（待用户授权）

1. **Step 2（集成验证）**：改用远程 spec 验证
   - 本地构建 tk-plugin binary → 打实验 tag `1.0.0-alpha.3-exp` → 推 flame-specs → Demo pod install 远程 spec → build + 真机运行
   - 需用户授权「发布实验性 tag」（不进正式版本序列）

2. **Step 3（TB 对称验证）**：新增 `tb-plugin` 构建变体，对称验证 TB plugin binary

3. **Step 4（真机 +load gate）**：真机运行 Demo，确认 `FlameTKProvider +load` 自动注册 + TK 广告链路（Splash/Interstitial 加载）

---

## 18. 本阶段产出物（均未发布）

```
flame_ios_sdk/
├── xcFramework_build.sh                              [修改] 新增 tk-plugin 变体
├── Podfile                                           [修改] 新增 tk-plugin → tk 映射
├── build/
│   ├── flame_sdk_ios_core.xcframework                [既有] core binary（未改动）
│   └── tk/flame_sdk_ios.xcframework                  [新增] TK plugin binary ⭐
├── research/
│   ├── podspecs/
│   │   └── flame_sdk_ios.binary_plugin.tk.podspec    [新增] 实验 podspec（:podspec 模式）
│   └── local_pod/
│       ├── flame_sdk_ios.podspec                     [新增] 实验 podspec（:path 模式）
│       ├── flame_sdk_ios_headers/                    [新增] wrappers 头副本
│       └── build/                                    [新增] xcframework 副本（验证用）
└── doc/flame_mediation/
    └── phase-5a.11-step1-tk-plugin-binary-validation-report.md  [本报告]
```

---

## 19. /compact 要点

**已完成**：TK plugin binary 本地构建实证（构建成功 + 符号纯净 + 源码零暴露 + +load 在位）。
**未完成**：Demo 完整 build（卡在 CocoaPods `:path` staging 限制，非设计缺陷）。
**下一步**：待用户授权后，改用远程 spec 验证集成路径（Step 2），或直接推进 TB plugin binary 构建验证（Step 3）。
**红线**：全部遵守，无发布、无 push、无 tag。
