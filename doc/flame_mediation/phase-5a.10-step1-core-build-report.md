# Phase 5A.10 Step 1 — Core Thin Binary 构建验证报告

> **阶段**：Phase 5A.10 Step 1（仅构建验证，不进 Step 2 / 不发布 / 不 tag / 不 push）
> **分支**：`research/thin-core-binary`（基于 `feat/tb_adapter` 的 `086a766`）
> **日期**：2026-06-17
> **结论**：✅ **Core Thin Binary 构建成功，零三方广告 SDK 污染，原双二进制兜底未破坏。**

---

## 0. TL;DR

| 验证项 | 结果 |
|---|---|
| Core 构建是否成功 | ✅ `ARCHIVE SUCCEEDED`，产物 `build/core/flame_sdk_ios.xcframework` |
| Core binary 体积 | **176K**（对比 TK 276K / TB 6.9M） |
| otool -L 三方动态依赖 | ✅ 仅 OpenSSL + 系统库，**无 AnyThink/WindMill/ToBid** |
| nm 三方符号 | ✅ **全部 0**（AnyThink/WindMill/广告源/平台Provider/Adapter） |
| framework 内三方资源 | ✅ 无 bundle/metallib |
| Podfile.lock | ✅ 仅 OpenSSL-Universal |
| TK 回归 | ✅ 276K，WindMill=0，含 FlameTKProvider/AtRewardAdapter |
| TB 回归 | ✅ 6.9M，WindMill=3621，AnyThink=0，含 FlameTBProvider/TbRewardAdapter |
| 是否建议进入 Step 2 | ✅ **建议**（无阻塞点） |

---

## 1. 当前分支与保护状态

| 项 | 值 |
|---|---|
| 当前分支 | `research/thin-core-binary` |
| HEAD commit | `4bcecb9`（Phase 5A.10 Step 1 提交） |
| 基线 commit | `086a766`（feat/tb_adapter 稳定点，Step 1 由此分叉） |
| `backup/phase-5a-dual-binary-stable` | ✅ 存在，指向 `086a766`（含全部双二进制稳定改动） |
| 是否创建 research 分支 | ✅ 已创建 `research/thin-core-binary`，所有实验在此分支 |

```
research/thin-core-binary  4bcecb9  Step 1（本阶段）
                           └─ 086a766  feat/tb_adapter 稳定基线
                                         = backup/phase-5a-dual-binary-stable
```

---

## 2. 修改了哪些文件（19 个，单 commit `4bcecb9`）

### 宏守卫机械替换（16 文件，每文件 +1 个 `&& !defined(FLAME_BUILD_CORE)` 条件）

TK-fallback 守卫统一改造：
```objc
// 改造前
#if defined(FLAME_BUILD_TK) || (!defined(FLAME_BUILD_TK) && !defined(FLAME_BUILD_TB))
// 改造后
#if defined(FLAME_BUILD_TK) || (!defined(FLAME_BUILD_TK) && !defined(FLAME_BUILD_TB) && !defined(FLAME_BUILD_CORE))
```

| 文件 | 改动点 |
|---|---|
| `core/FlameSdk.m` | Provider import 守卫 + registerAllProvidersIfNeeded 守卫 + 注释更新 |
| `adapter/FlameAdapterManager.m` | AnyThink import / initSDKWithAppId / setDebug TK 分支守卫 + 注释更新 |
| `adapter/tk/AtBannerAdapter.{h,m}` | TK-fallback 守卫 |
| `adapter/tk/AtInterstitialAdapter.{h,m}` | TK-fallback 守卫 |
| `adapter/tk/AtNativeAdapter.{h,m}` | TK-fallback 守卫 |
| `adapter/tk/AtNativeSelfRenderView.{h,m}` | TK-fallback 守卫 |
| `adapter/tk/AtRewardAdapter.{h,m}` | TK-fallback 守卫 |
| `adapter/tk/AtSplashAdapter.{h,m}` | TK-fallback 守卫 |
| `mediation/tk/FlameTKProvider.{h,m}` | TK-fallback 守卫 |

**未改动**：`adapter/tb/*`、`mediation/tb/*`（守卫为 `#if defined(FLAME_BUILD_TB)`，core 下天然跳过）。

### 工程配置（3 文件）

| 文件 | 改动 |
|---|---|
| `Podfile` | 新增 `core` 变体（仅 OpenSSL），variant 校验加入 `'core'` |
| `xcFramework_build.sh` | 新增 `core` 参数（注入 `FLAME_BUILD_CORE=1`，输出 `build/core/`），符号校验增加 CORE 分支（最严格） |
| `flame_sdk_ios.xcodeproj/project.pbxproj` | **仅 CocoaPods 生成的 UUID 变化**（pod install 副产物，无源文件引用变化） |

> ⚠️ pbxproj 的 diff 经核查：全部是 `[CP] Check Pods Manifest.lock`、`[CP] Embed Pods Frameworks`、`Pods_flame_sdk_ios.framework` 等 Pods 集成引用的 UUID 重新生成，**无任何 `.m`/`.h` 源文件引用变化**。这是 `pod deintegrate` + `pod install` 的标准行为，不影响正确性。

---

## 3. 关键设计决策：为何用 `&& !defined(FLAME_BUILD_CORE)` 而非重写守卫

现有守卫语义："TK 代码在 TK 构建或源码开发（两宏都未定义）时编译"。

引入 CORE 后的语义需求：
| 构建场景 | TK 宏 | TB 宏 | CORE 宏 | TK 代码是否编译 |
|---|---|---|---|---|
| TK 构建 | ✓ | | | ✅ 编译 |
| TB 构建 | | ✓ | | ❌ 跳过（TB 已定义） |
| **CORE 构建** | | | ✓ | ❌ **必须跳过**（否则 import AnyThink 失败） |
| 源码开发 | | | | ✅ 编译（保留默认，不破坏开发流） |

最小改动方案：在 TK-fallback 条件末尾追加 `&& !defined(FLAME_BUILD_CORE)`。
- CORE 构建时 fallback 条件为 false → TK 代码跳过 ✅
- 源码开发时三宏都未定义 → fallback 仍为 true → TK 代码编译（默认行为不变）✅
- TK 构建时 `defined(FLAME_BUILD_TK)` 为 true → 无论 CORE 子句都编译 ✅

**优点**：机械替换、零逻辑重构、回归风险最低。

---

## 4. FlameSdk.m 解耦验证（直接回答规范第 9 点）

### 改造前
```objc
#import "FlameTKProvider.h"   // 无守卫，所有变体都 import
#import "FlameTBProvider.h"
```

### 改造后（line 34-39）
```objc
#if defined(FLAME_BUILD_TK) || (!defined(FLAME_BUILD_TK) && !defined(FLAME_BUILD_TB) && !defined(FLAME_BUILD_CORE))
#import "FlameTKProvider.h"
#endif

#if defined(FLAME_BUILD_TB)
#import "FlameTBProvider.h"
#endif
```

### registerAllProvidersIfNeeded（CORE 模式行为）
```objc
+ (void)registerAllProvidersIfNeeded {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // CORE 变体：此处不注册任何内置 Provider。
        //   Core binary 不含 TK/TB 平台源码，Provider 由 Step 2 的平台源码插件
        //   在接入方 App 编译时自动注册。Core 单独运行时 create*Ad 走
        //   Router.currentProvider=nil 分支返回 "No active provider" 错误，符合预期。
#if defined(FLAME_BUILD_TK) || (... && !defined(FLAME_BUILD_CORE))
        FlameTKProvider *tkProvider = ...;
#endif
#if defined(FLAME_BUILD_TB)
        FlameTBProvider *tbProvider = ...;
#endif
    });
}
```

### 验证结论
- ✅ CORE 模式下不 import FlameTKProvider/FlameTBProvider
- ✅ CORE 模式下不注册任何 Provider
- ✅ create*Ad 仍走 Router.currentProvider（无 provider 时返回 unsupported 错误）
- ✅ 不在 create*Ad 写平台 if

---

## 5. FlameAdapterManager 处理（直接回答规范第 10 点）

| 检查项 | 结果 |
|---|---|
| Core 模式下是否 import AnyThink | ✅ 否（import 被 CORE 守卫排除，line 23） |
| Core 模式下是否调用 AnyThink 初始化 | ✅ 否（initSDKWithAppId 整段在 TK 守卫内，line 55-105） |
| checkInitialization / isInitialized / setDebug 是否保留 | ✅ 保留（中立骨架始终编译） |
| 是否移动 / 重命名 FlameAdapterManager | ✅ 否（位置与名称不变） |

Core 模式下 FlameAdapterManager 退化为纯中立骨架：
```objc
+ (BOOL)isInitialized { return [FlameSdk isInitialized]; }
+ (BOOL)checkInitialization { return [FlameSdk checkInitialization]; }
+ (void)setDebug:(BOOL)isDebug { /* 平台中立：实际开关由 Provider 处理 */ }
```

---

## 6. Core 构建验证结果

### 6.1 构建命令
```bash
$ ./xcFramework_build.sh core
🔥 Flame SDK build variant: core
📦 pod install（FLAME_SDK_VARIANT=core）...
📦 正在归档真机（FLAME_BUILD_CORE=1）...
** ARCHIVE SUCCEEDED **
📦 正在归档模拟器（FLAME_BUILD_CORE=1）...
** ARCHIVE SUCCEEDED **
🛠️ 合并 XCFramework...
xcframework successfully written out to: build/core/flame_sdk_ios.xcframework
🔍 符号校验（core 变体）...
   二进制体积: 176K
```

### 6.2 Podfile.lock 依赖检查（直接回答规范第 16 点）
```
$ grep -E "AnyThinkiOS|ToBid-iOS-RC|SigmobAd-iOS|AnyThinkMediation|AdGainSDK|FSUnionAdSDK" Podfile.lock
（无输出）

$ grep -E "^  - |^DEPENDENCIES" Podfile.lock
  - OpenSSL-Universal (3.6.2000)
DEPENDENCIES:
  - OpenSSL-Universal (~> 3.6)
```
✅ **Podfile.lock 仅含 OpenSSL-Universal**，无任何三方广告 SDK。

---

## 7. Core 二进制污染检查（直接回答规范第 12-15 点）

### 7.1 体积（直接回答第 12 点）
```
Core: 176K   build/core/flame_sdk_ios.xcframework/ios-arm64/flame_sdk_ios.framework/flame_sdk_ios
```
对比：TK 276K / TB 6.9M。Core 是 TB 的 **2.5%**。

### 7.2 otool -L 动态依赖（直接回答第 13 点）
```
@rpath/flame_sdk_ios.framework/flame_sdk_ios
@rpath/OpenSSL.framework/OpenSSL
/System/Library/Frameworks/Foundation.framework/Foundation
/usr/lib/libobjc.A.dylib
/usr/lib/libSystem.B.dylib
/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation
```
✅ **仅 6 项依赖：自身 + OpenSSL + 4 个系统库**。无 AnyThink / WindMill / ToBid / Sigmob。

### 7.3 nm 三方符号检查（直接回答第 14 点）

| 符号类别 | 计数 | 预期 |
|---|---|---|
| AnyThink (`_OBJC_CLASS_$_AT*` / `AnyThink` / `ATAPI`) | **0** | 0 |
| WindMill / Wind / WindFoundation / WindSDK | **0** | 0 |
| 广告源 (Baidu/GDT/KS/FSUnion/Sigmob/AdGain/BU/CSJ) | **0** | 0 |
| 平台 Provider/Adapter (FlameTKProvider/FlameTBProvider/At*Adapter/TbRewardAdapter) | **0** | 0 |

✅ **全部为 0**。Core binary 不含任何三方广告 SDK 符号。

### 7.4 Core binary 应含的 Flame 平台中立类（功能完整性确认）
```
✅ FlameSdk
✅ FlameConfigManager
✅ FlameMediationRegistry
✅ FlameMediationRouter
✅ FlameSplashAdImpl
✅ FlameRewardAdImpl
✅ FlameInterstitialAdImpl
✅ FlameBannerAdImpl
✅ FlameNativeAdImpl
✅ FlameAdapterManager
```
✅ 10 个核心中立类全部在位，Core 功能完整。

### 7.5 framework 内三方资源（直接回答第 15 点）
```
$ find build/core/flame_sdk_ios.xcframework -maxdepth 3 \( -name "*.bundle" -o -name "*.metallib" \) -print
（无输出）
```
✅ 无三方 bundle / metallib。

---

## 8. TK/TB 回归验证（直接回答规范第 17-19 点）

### 8.1 TK 回归
```bash
$ ./xcFramework_build.sh tk
** ARCHIVE SUCCEEDED **
   二进制体积: 276K
```
| 检查项 | 结果 | 预期 |
|---|---|---|
| WindMill 污染 | 0 | 0 ✅ |
| FlameTBProvider/TbRewardAdapter | 0 | 0 ✅ |
| FlameTKProvider | 1 | >0 ✅ |
| AtRewardAdapter | 1 | >0 ✅ |
| otool AnyThink | `@rpath/AnyThinkSDK.framework/AnyThinkSDK`（外部依赖，正常） | 存在 ✅ |

✅ **TK 构建未破坏**。守卫改造不影响 TK（`defined(FLAME_BUILD_TK)` 为 true，CORE 子句无关）。

### 8.2 TB 回归
```bash
$ ./xcFramework_build.sh tb
** ARCHIVE SUCCEEDED **
   二进制体积: 6.9M
✅ TB 二进制含 3621 个 ToBid WindMill 符号（预期 >0，自包含模式）
✅ TB 二进制无 TK / AT* adapter 符号
✅ TB 二进制无 AnyThink AT* 符号
```
| 检查项 | 结果 | 预期 |
|---|---|---|
| WindMill | 3621 | >0 ✅ |
| AnyThink AT* | 0 | 0 ✅ |
| FlameTKProvider/At*Adapter | 0 | 0 ✅ |
| FlameTBProvider | 1 | >0 ✅ |
| TbRewardAdapter | 1 | >0 ✅ |

✅ **TB 构建未破坏**。TB 文件守卫 `#if defined(FLAME_BUILD_TB)` 未改动，core 改造对其零影响。

### 8.3 三变体体积对比
```
Core: 176K    （平台中立，0 三方符号）
TK:   276K    （+ AnyThink 外部依赖引用）
TB:   6.9M    （+ WindMill 静态内置 3621 符号）
```

### 8.4 兜底方案完整性
```
$ ls -d build/core build/tk build/tb
build/core build/tb build/tk
```
✅ 三个产物均在，原双二进制兜底（build/tk + build/tb）完整保留。

---

## 9. 规范问题逐条回答（直接回答第 20-24 点）

| # | 问题 | 回答 |
|---|---|---|
| 20 | 是否未改 podspec | ✅ 未改（flame_sdk_ios.podspec / flame_sdk_ios_tb.podspec 均未动） |
| 21 | 是否未改 Demo | ✅ 未改（Demo 接入完全未碰） |
| 22 | 是否未发布 / 未 tag / 未 push | ✅ 均未做（仅本地 research 分支 commit，未 push origin） |
| 23 | 是否建议进入 Step 2 | ✅ **建议**（见第 10 节） |
| 24 | 阻塞点 | **无**（见第 11 节） |

---

## 10. 是否建议进入 Step 2（直接回答第 23 点）

### ✅ 建议

Step 1 已用 `otool` / `nm` / `du` / `find` 四重证据证明：
1. Core binary 可构建（176K）
2. Core binary 零三方广告 SDK 符号
3. Core binary 功能完整（10 个中立类在位）
4. 原双二进制兜底未破坏（TK 276K / TB 6.9M 均回归通过）

### Step 2 预期内容（本阶段不执行，仅规划）
- 创建实验 podspec（`research/flame_sdk_ios.thin_core.tk.podspec` / `thin_core.tb.podspec`）
- vendored_frameworks 指向 `build/core/flame_sdk_ios.xcframework`
- source_files 指向 TK/TB 平台源码
- Demo TK/TB 双 variant 运行时验证

---

## 11. 阻塞点（直接回答第 24 点）

**无硬阻塞。** Step 1 全部验证通过。

潜在关注点（非阻塞，Step 2 需验证）：
| 关注点 | 说明 | 应对 |
|---|---|---|
| Core binary 单独运行无 Provider | 预期行为（Core 不含平台源码） | Step 2 通过 podspec source_files 注入平台源码后解决 |
| pbxproj UUID churn | pod install 副产物，无源码引用变化 | 已核查，无影响；若要彻底干净可考虑 `git checkout pbxproj` 后重新 install，但非必要 |

---

## 12. 更新后的 /compact

```
Phase 5A.10 Step 1 完成：Core Thin Binary 构建验证成功（research/thin-core-binary 分支）。

【分支与保护】
- research/thin-core-binary @ 4bcecb9（Step 1 单 commit），基于 feat/tb_adapter @ 086a766。
- backup/phase-5a-dual-binary-stable @ 086a766（双二进制稳定兜底，未动）。
- 未 push origin、未 tag、未发布、未进 Phase 6。

【改动（19 文件）】
- 宏守卫机械替换：16 文件的 TK-fallback 守卫追加 && !defined(FLAME_BUILD_CORE)。
  影响范围：core/FlameSdk.m, adapter/FlameAdapterManager.m, adapter/tk/* (6 文件×.h.m),
  mediation/tk/FlameTKProvider.{h,m}。TB 文件守卫 #if defined(FLAME_BUILD_TB) 未改。
- FlameSdk.m：CORE 模式不 import Provider、不注册 Provider，create*Ad 仍走 Router。
- FlameAdapterManager.m：CORE 模式退化为中立骨架（AnyThink 段被守卫排除）。
- Podfile：新增 core 变体（仅 OpenSSL）。
- xcFramework_build.sh：新增 core 参数（FLAME_BUILD_CORE=1 → build/core/）+ CORE 符号校验。

【Core 验证结果】
- 构建：ARCHIVE SUCCEEDED。
- 体积：176K（对比 TK 276K / TB 6.9M）。
- otool -L：仅 OpenSSL + 系统库，无 AnyThink/WindMill/ToBid。
- nm 三方符号：全部 0（AnyThink/WindMill/广告源/Provider/Adapter）。
- framework 内：无 bundle/metallib。
- Podfile.lock：仅 OpenSSL-Universal。
- 10 个中立类（FlameSdk/ConfigManager/Registry/Router/5×AdImpl/AdapterManager）均在。

【TK/TB 回归】
- TK：276K，WindMill=0，含 FlameTKProvider/AtRewardAdapter，AnyThink 外部依赖正常。
- TB：6.9M，WindMill=3621，AnyThink=0，含 FlameTBProvider/TbRewardAdapter。
- build/tk + build/tb 完整保留。

【结论】Step 1 通过，建议进入 Step 2（实验 podspec + Demo 运行时验证），无阻塞点。

【Step 1 报告】doc/flame_mediation/phase-5a.10-step1-core-build-report.md
【调研报告】doc/flame_mediation/phase-5a.10-thin-core-binary-research.md
```

---

**Step 1 完成。未发布、未 tag、未 push、未进 Step 2 / Phase 6。等待用户决策。**
