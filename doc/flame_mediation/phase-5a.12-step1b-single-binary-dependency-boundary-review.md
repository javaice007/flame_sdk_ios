# Phase 5A.12 Step 1b：单二进制 + 双平台核心 + 两个 podspec 依赖边界复核

> ⚠️ **勘误（2026-06-19，Phase 5A.12 mainline 切换后）**
>
> 本文档是 Phase 5A.12 研究阶段（research/thin-core-binary 分支）的历史记录。
> 当前主线已切到 **research/single-binary-mainline** 分支，关键口径修正如下：
>
> | 错误口径（本文档原表述）| 正确口径（mainline）|
> |---|---|
> | 「二进制完全内置 TK/TB 平台核心」| ❌ 错误。binary 内置 Flame core + TK/TB Provider/Adapter 胶水；平台核心 SDK（AnyThinkSDK / ToBid/WindMill）由 podspec 公共依赖提供 |
> | 「TB 客户必须接入 AnyThinkSDK 是单二进制代价」| ⚠️ 修正为：两个 podspec 都声明 AnyThinkiOS + ToBid-iOS-RC 作为公共平台核心依赖（不再区分 TK/TB 专属）|
> | 「两个 podspec 差异只在广告源适配器」| ✅ mainline 已实现：公共依赖（OpenSSL+AnyThinkiOS+ToBid-iOS-RC）+ 差异化广告源依赖 |
> | FLAME_BUILD_TK / FLAME_BUILD_TB 宏体系 | ❌ mainline 已完全删除，TK/TB 始终全部编译，平台选择靠运行时 pt 路由 |
>
> 最新主线文档见：`doc/flame_mediation/phase-5a.12-single-binary-mainline.md`
>

> **类型**：P0 复核（Step 1 完成后、Step 2 真机验证前的架构口径锁定）
> **执行日期**：2026-06-19
> **触发**：Step 1 报告对「单二进制是否真的内置 TK/TB 平台核心」描述模糊，需用实证锁定
> **目标**：明确 binary 硬依赖 / podspec 公共依赖 / podspec 差异化依赖的边界，验证两个 podspec 的差异是否真的只在广告源适配器

---

## 核心结论速览

- ✅ **二进制硬动态依赖（LC_LOAD_DYLIB）只有 2 个**：`AnyThinkSDK.framework` + `OpenSSL.framework`
- ✅ **二进制未静态打入任何平台核心**（AnyThink/WindMill 都没有；体积 300K 证明）
- ✅ **Flame 自有胶水全部内置**（9 个 ObjC 类：FlameTKProvider + 6 At*Adapter/View + FlameTBProvider + TbRewardAdapter）
- ⚠️ **当前两个 podspec 的差异不止「广告源适配器」**：TB podspec 多了 `ToBid-iOS-RC`（这是 TB 平台核心，不是广告源适配器）
- ⚠️ **非对称性**：AnyThinkSDK 是 dyld 硬依赖（两个 podspec 都必须拉），ToBid-iOS-RC 是 U 引用（只在 TB 调用时需要）
- ⚠️ **Step 1 报告措辞需修正**：原报告「二进制完全内置 TK/TB 平台核心」不准确，应改为「内置 Flame 自有胶水，平台核心 SDK 由 podspec 公共/差异化依赖提供」

---

## 1. 当前分支 / HEAD

| 项目 | 值 |
|---|---|
| 分支 | `research/thin-core-binary` |
| HEAD | `3489d1278f6f19bd64b6adb91261251d90f62191`（与 Step 1 一致，未变）|
| 工作区状态 | 修改：Podfile / xcFramework_build.sh / flame_sdk_ios.podspec / flame_sdk_ios_tb.podspec / project.pbxproj / FlameSdk.m；新增：research/ 与 doc/flame_mediation/phase-5a.12-* |

## 2. 是否未 push / 未 tag / 未发布

| 检查项 | 结果 |
|---|---|
| `git push origin` | ❌ 未执行 |
| 远程 tag（alpha.3 / alpha.4 / alpha.4-local）| ❌ 不存在 |
| GitHub release | ❌ 未创建 |
| `pod repo push`（javaice007-flame-specs）| ❌ 未执行 |
| 本地 dist repo tag `1.0.0-alpha.4-local` | ✅ 存在（`research/local_dist/single_binary`，0 remotes）|

红线全部遵守。

## 3. 当前 single-binary 产物路径

```
build/flame_sdk_ios.xcframework
├── Info.plist
├── ios-arm64/flame_sdk_ios.framework/flame_sdk_ios        （300K，MH_DYLIB）
└── ios-x86_64-simulator/flame_sdk_ios.framework/flame_sdk_ios
```

## 4. otool -L 完整结果

```
@rpath/flame_sdk_ios.framework/flame_sdk_ios               ← 自身
/usr/lib/libobjc.A.dylib                                   ← 系统
/usr/lib/libc++.1.dylib                                    ← 系统
/usr/lib/libresolv.9.dylib                                 ← 系统
/usr/lib/libsqlite3.dylib                                  ← 系统
/usr/lib/libxml2.2.dylib                                   ← 系统
/usr/lib/libz.1.dylib                                      ← 系统
/System/Library/Frameworks/AVFoundation.framework/...      ← 系统
/System/Library/Frameworks/AdSupport.framework/...         ← 系统
@rpath/AnyThinkSDK.framework/AnyThinkSDK                   ← ⚠️ 三方硬依赖（LC_LOAD_DYLIB）
/System/Library/Frameworks/AudioToolbox.framework/...       ← 系统
/System/Library/Frameworks/CFNetwork.framework/...         ← 系统
... （其余都是系统框架）
@rpath/OpenSSL.framework/OpenSSL                            ← ⚠️ 三方硬依赖（LC_LOAD_DYLIB）
... （其余都是系统框架）
```

**关键结论**：otool -L 的三方 LC_LOAD_DYLIB 只有 2 个：
1. `@rpath/AnyThinkSDK.framework/AnyThinkSDK` —— TK 平台核心
2. `@rpath/OpenSSL.framework/OpenSSL` —— 加密依赖

**WindMill / WindSDK / WindFoundation / ToBid 都不在 otool -L**（不是 dyld 硬依赖）。

## 5. nm 平台符号摘要

### 5.1 Flame 自有胶水（应全部内置，✅ 全部在位）

```
_OBJC_CLASS_$_AtBannerAdapter
_OBJC_CLASS_$_AtInterstitialAdapter
_OBJC_CLASS_$_AtNativeAdapter
_OBJC_CLASS_$_AtNativeSelfRenderView
_OBJC_CLASS_$_AtRewardAdapter
_OBJC_CLASS_$_AtSplashAdapter
_OBJC_CLASS_$_FlameTBProvider
_OBJC_CLASS_$_FlameTKProvider
_OBJC_CLASS_$_TbRewardAdapter
```

共 9 个 ObjC 类（TK 侧 7 个 + TB 侧 2 个）。

### 5.2 平台核心 / 广告源符号检测（应全 0，✅ 全部为 0）

| 检测项 | 结果 |
|---|---|
| AnyThink SDK 定义符号（T/D）| **0**（未静态打入）|
| WindMill / ToBid 定义符号（T/D）| **0**（未静态打入）|
| 广告源 SDK 符号（BU/CSJ/GDT/KS/Baidu/Sigmob/AdGain/FSUnion）| **0**（未静态打入）|

### 5.3 未定义符号（U）—— 运行期由 podspec 依赖提供

| 平台 | U 引用数 | 具体符号 |
|---|---|---|
| AnyThink（TK 核心）| 6 个 ObjC 类 + 8 个 kAT* 常量 | ATAPI, ATAdManager, ATNativeADConfiguration, ATNativeADView, ATNativePrepareInfo, ATShowConfig |
| WindMill（TB 核心）| 3 个 Swift 类 | _TtC11WindMillSDK11WindMillAds, _TtC11WindMillSDK17WindMillAdRequest, _TtC11WindMillSDK21WindMillRewardVideoAd |
| Flame 内部 | **0** | （core 全部内置）|

**关键差异**：
- AnyThink 是 ObjC 类 U 引用 + dyld LC_LOAD_DYLIB（**双重依赖**）
- WindMill 只有 Swift 类 U 引用（**无 LC_LOAD_DYLIB**，纯 dynamic_lookup）

## 6. source leak 检查结果

```bash
find build/flame_sdk_ios.xcframework \( -name "*.m" -o -name "*.mm" \) -print
# （无输出）
```

✅ **0 源码泄漏**。Headers/ 只含 10 个公共 API 头（FlameSdk.h、flame_sdk_ios.h、FlameCallback.h、FlameSplashAd.h、FlameRewardAd.h、FlameInterstitialAd.h、FlameBannerAd.h、FlameBannerAdMaterial.h、FlameBannerAdRenderSlots.h、FlameNativeAd.h）。

## 7. 两个 local podspec 路径

| podspec | 路径 |
|---|---|
| flame_sdk_ios（TK）| `research/local_dist/single_binary/flame_sdk_ios.podspec` |
| flame_sdk_ios_tb（TB）| `research/local_dist/single_binary/flame_sdk_ios_tb.podspec` |
| flame_sdk_ios（TK 备用 :podspec 版）| `research/podspecs/single_binary/flame_sdk_ios.single_binary.local.podspec` |
| flame_sdk_ios_tb（TB 备用 :podspec 版）| `research/podspecs/single_binary/flame_sdk_ios_tb.single_binary.local.podspec` |

两份 podspec 都引用同一个 `flame_sdk_ios.xcframework`，均无 source_files / public_header_files / private_header_files / static_framework（即纯 vendored binary + dependency 模式）。

## 8. 两个 podspec 的 dependency 完整列表

### 8.1 flame_sdk_ios.podspec（TK 侧，15 个依赖）

| # | dependency | 类别（按实证）|
|---|---|---|
| 1 | `OpenSSL-Universal ~> 3.6` | 公共（binary dyld 硬依赖）|
| 2 | `AnyThinkiOS 6.5.71` | 公共（binary dyld 硬依赖）|
| 3 | `AnyThinkMediationAdxSmartdigimktCNAdapter 6.5.72.2.1` | TK 广告源适配器 |
| 4 | `AnyThinkMediationGromoreAdapter 7.6.0.4.2.0` | TK 广告源适配器 |
| 5 | `AnyThinkMediationBaiduAdapter 10.050.2.1` | TK 广告源适配器 |
| 6 | `AnyThinkMediationMSAdapter 2.7.18.1.2.0` | TK 广告源适配器 |
| 7 | `AnyThinkMediationZYAdapter 2.6.4.29.2.0` | TK 广告源适配器 |
| 8 | `AnyThinkMediationFunlinkAdapter 2.9.0.1.2.2.0` | TK 广告源适配器 |
| 9 | `AnyThinkMediationBeiZiAdapter 5.5.0.3.2.0` | TK 广告源适配器 |
| 10 | `AnyThinkMediationKuaiShouAdapter 5.4.10.1.2.0` | TK 广告源适配器 |
| 11 | `AnyThinkMediationSigmobAdapter 4.20.12.2.0` | TK 广告源适配器 |
| 12 | `AnyThinkMediationTTAdapter_Mix 7.6.0.4.2.0` | TK 广告源适配器 |
| 13 | `AnyThinkMediationGDTAdapter 4.15.90.2.0` | TK 广告源适配器 |
| 14 | `AdGainSDK 4.2.7.1` + `AdGainSDKTakuAdapter 4.2.7.1` | TK 广告源 SDK + 适配器 |
| 15 | `FSUnionAdSDK 1.0.8.0` | TK 广告源 SDK |

### 8.2 flame_sdk_ios_tb.podspec（TB 侧，3 个依赖）

| # | dependency | 类别（按实证）|
|---|---|---|
| 1 | `OpenSSL-Universal ~> 3.6` | 公共（binary dyld 硬依赖）|
| 2 | `AnyThinkiOS 6.5.71` | 公共（binary dyld 硬依赖，非 TB 业务需要）|
| 3 | `ToBid-iOS-RC 5.5.6` | TB 平台核心（U 引用，pt=tb 时才解析）|

## 9. 依赖矩阵

> **判断标准**：
> 1. 如果某个库出现在 otool -L 的 LC_LOAD_DYLIB → dyld 硬依赖，podspec 必须保证它存在（否则启动即崩）
> 2. 如果某个库被静态打入 binary → nm -gU 应有定义符号，体积会显著增加
> 3. 如果某个库既不在 LC_LOAD_DYLIB，也没有静态打入 → 只有调用时才需要（U 引用 lazy binding）

| 依赖/能力 | 是否在 flame_sdk_ios.xcframework 内 | flame_sdk_ios.podspec 是否声明 | flame_sdk_ios_tb.podspec 是否声明 | 说明 |
|---|:---:|:---:|:---:|---|
| Flame SDK 自有 core | ✅ 是（core 代码编进同 Mach-O）| ✅ 是（间接，通过 vendored binary）| ✅ 是（间接，通过 vendored binary）| FlameSdk/FlameLogger/FlameMediationRouter 等核心类全部内置，nm -gU 可见；无 Flame 内部 U 引用 |
| TK Provider/Adapter 胶水 | ✅ 是（编译进同 Mach-O）| ✅ 是（间接）| ✅ 是（间接）| FlameTKProvider + 6 At*Adapter/View 共 7 个 ObjC 类内置；TB podspec 接同一 binary 也带这些符号 |
| TB Provider/Adapter 胶水 | ✅ 是（编译进同 Mach-O）| ✅ 是（间接）| ✅ 是（间接）| FlameTBProvider + TbRewardAdapter 共 2 个 ObjC 类内置；TK podspec 接同一 binary 也带这些符号 |
| AnyThinkSDK / TK 核心 | ❌ 否（未静态打入，6 个 U 引用 + LC_LOAD_DYLIB）| ✅ 是（显式声明）| ✅ 是（显式声明）| ⚠️ **dyld 硬依赖**：otool -L 可见 `@rpath/AnyThinkSDK.framework`。两个 podspec 都必须声明，否则 dyld 启动崩溃（即使 pt=tb 不调用 TK 代码） |
| ToBid / WindMill / TB 核心 | ❌ 否（未静态打入，3 个 U 引用，无 LC_LOAD_DYLIB）| ❌ 否（不声明）| ✅ 是（显式声明）| ⚠️ **U 引用 dynamic_lookup**：otool -L 无 WindMill；只在 FlameTBProvider.initializeWithAppId 调用时才解析。TK podspec 不声明是安全的（pt=tk 永不调用 TB 代码） |
| TK 广告源适配器（AnyThinkMediation*）| ❌ 否 | ✅ 是（11 个 Adapter）| ❌ 否 | 纯 TK 业务依赖，由 TK podspec 差异化拉取 |
| TK 广告源 SDK（AdGain / FSUnion）| ❌ 否 | ✅ 是 | ❌ 否 | 纯 TK 业务依赖 |
| TB 广告源适配器 | ❌ 否 | ❌ 否 | ❌ 否（当前不声明）| 当前 TB 只做 Reward，使用 ToBid-iOS-RC 默认 ToBidSDK 子规范；后续若接入 GDT/CSJ 等 TB Adapter，会在 TB podspec 增加 `ToBid-iOS-RC/<Adapter>` 子规范依赖 |
| OpenSSL | ❌ 否（LC_LOAD_DYLIB）| ✅ 是 | ✅ 是 | ⚠️ **dyld 硬依赖**：otool -L 可见 `@rpath/OpenSSL.framework`。两个 podspec 都必须声明 |

## 10. 哪些依赖是 binary 内置

**Binary 内置（编进 flame_sdk_ios.xcframework 的 Mach-O）**：

1. **Flame SDK 自有 core**
   - FlameSdk / FlameLogger / FlameMediationRouter / FlameMediationRegistry / FlameAdapterManager / FlameConfigManager / FlameErrorCode / FlameAppEntity
   - FlameBannerAdImpl / FlameInterstitialAdImpl / FlameNativeAdImpl / FlameRewardAdImpl / FlameSplashAdImpl
   - FlameAesCryptoUtils / FlameConfigLocalStorage / FlameMd5SignatureUtils / FlameNetworkUtils / FlameUrlParamUtil / FlameBannerAdMaterial / FlameBannerAdRenderSlots
   - 体积贡献：约 200K（300K 总量中）

2. **TK Provider/Adapter 胶水**
   - FlameTKProvider + AtRewardAdapter + AtSplashAdapter + AtInterstitialAdapter + AtBannerAdapter + AtNativeAdapter + AtNativeSelfRenderView（7 个 ObjC 类）
   - 体积贡献：约 60K

3. **TB Provider/Adapter 胶水**
   - FlameTBProvider + TbRewardAdapter（2 个 ObjC 类）
   - 体积贡献：约 40K

**Binary 未内置（必须由 podspec 提供）**：

- AnyThinkSDK（LC_LOAD_DYLIB 硬依赖）
- OpenSSL（LC_LOAD_DYLIB 硬依赖）
- ToBid / WindMill（U 引用，按需）
- 所有广告源 SDK 与 Adapter

## 11. 哪些依赖是两个 podspec 公共依赖

**公共依赖（两个 podspec 都声明）**：

| 依赖 | 原因 | 实证 |
|---|---|---|
| `OpenSSL-Universal ~> 3.6` | binary dyld 硬依赖 | otool -L 可见 `@rpath/OpenSSL.framework` |
| `AnyThinkiOS 6.5.71` | binary dyld 硬依赖 | otool -L 可见 `@rpath/AnyThinkSDK.framework` |

**关键**：`AnyThinkiOS` 是公共依赖，**不是 TK 专属**。这是单二进制方案的核心代价 —— 因为构建期 TK 胶水代码 `#import <AnyThinkSDK/AnyThinkSDK.h>`，链接器把 AnyThinkSDK 当作 framework 显式链接（LC_LOAD_DYLIB），TB 客户即使不用 TK 业务也必须接入。

## 12. 哪些依赖是 TK podspec 专属广告源依赖

**TK 专属（只在 flame_sdk_ios.podspec 声明）**：

| 依赖 | 类型 |
|---|---|
| AnyThinkMediationAdxSmartdigimktCNAdapter 6.5.72.2.1 | TK 广告源适配器 |
| AnyThinkMediationGromoreAdapter 7.6.0.4.2.0 | TK 广告源适配器 |
| AnyThinkMediationBaiduAdapter 10.050.2.1 | TK 广告源适配器 |
| AnyThinkMediationMSAdapter 2.7.18.1.2.0 | TK 广告源适配器 |
| AnyThinkMediationZYAdapter 2.6.4.29.2.0 | TK 广告源适配器 |
| AnyThinkMediationFunlinkAdapter 2.9.0.1.2.2.0 | TK 广告源适配器 |
| AnyThinkMediationBeiZiAdapter 5.5.0.3.2.0 | TK 广告源适配器 |
| AnyThinkMediationKuaiShouAdapter 5.4.10.1.2.0 | TK 广告源适配器 |
| AnyThinkMediationSigmobAdapter 4.20.12.2.0 | TK 广告源适配器 |
| AnyThinkMediationTTAdapter_Mix 7.6.0.4.2.0 | TK 广告源适配器 |
| AnyThinkMediationGDTAdapter 4.15.90.2.0 | TK 广告源适配器 |
| AdGainSDK 4.2.7.1 + AdGainSDKTakuAdapter 4.2.7.1 | TK 广告源 SDK + 适配器 |
| FSUnionAdSDK 1.0.8.0 | TK 广告源 SDK |

共 13 个 TK 广告源专属依赖。

## 13. 哪些依赖是 TB podspec 专属广告源依赖

**TB 专属（只在 flame_sdk_ios_tb.podspec 声明）**：

| 依赖 | 类型 | 说明 |
|---|---|---|
| `ToBid-iOS-RC 5.5.6` | ⚠️ **TB 平台核心**（不是广告源适配器）| 这是 TB 业务的聚合 SDK 核心（WindMillSDK/WindSDK/WindFoundation）。当前归类存在歧义，详见 §15 |

**当前 TB podspec 没有声明任何 TB 广告源 Adapter**（如 ToBid-iOS-RC/CSJAdapter、ToBid-iOS-RC/GDTAdapter 等 21 个子规范）。原因：Phase 5A.12 Step 1 TB 只验证 Reward 链路，使用 ToBid 默认 ToBidSDK 子规范；后续 Phase 5A.13+ 若扩展 TB Splash/Interstitial/Banner/Native，需要按需声明 TB Adapter 子规范。

## 14. 当前报告中需要修正的措辞

### 14.1 错误措辞：「二进制完全内置 TK/TB 平台核心」

**Step 1 报告原文**（§11/§12）：
> 「TK 核心是否内置或随二进制可用」/「TB 核心是否内置或随二进制可用」结论模糊

**问题**：让人误以为 AnyThinkSDK/WindMillSDK 已经编进 binary。

**修正后**：
```
单二进制内置 Flame 自有 core + TK/TB Provider/Adapter 胶水层（共 9 个 ObjC 类）；
AnyThinkSDK（TK 核心）作为 dyld 硬依赖，由两个 podspec 公共声明；
ToBid/WindMill（TB 核心）作为 U 引用，由 TB podspec 声明（TK podspec 不需要）；
广告源 SDK 与 Adapter 由 podspec 差异化拉取。
```

### 14.2 错误措辞：「nosdk 语义重定义为不带具体广告源 SDK，但内置 TK/TB 平台核心」

**Step 1 方案文档原文**（§3）：
> 「nosdk = 不带具体广告源 SDK / 广告源 Adapter SDK；但内置 TK/TB 平台 Provider/Adapter 胶水代码」

**问题**：「内置 TK/TB 平台核心」表述模糊（容易被理解为 AnyThinkSDK/WindMillSDK 也内置了）。

**修正后**：
```
nosdk / single-binary 语义：
  不带具体广告源 SDK / 广告源 Adapter SDK
  不带 AnyThinkSDK / WindMillSDK 平台核心 SDK（由 podspec 提供）
  但内置 Flame 自己的 TK/TB Provider/Adapter 胶水代码（编译进同 Mach-O）
```

### 14.3 需要补充说明：TB podspec 的 ToBid-iOS-RC 不是「广告源适配器」

**当前 Step 1 报告**把 ToBid-iOS-RC 笼统归到「TB 广告源依赖」。

**修正后**：明确区分
```
ToBid-iOS-RC = TB 平台核心聚合 SDK（不是广告源适配器）
TB 广告源适配器 = ToBid-iOS-RC 的 21 个 Adapter 子规范（CSJAdapter/GDTAdapter/...）
```

## 15. 当前方案是否符合「一个二进制 + 两个 podspec 只区分广告源依赖」口径

### 15.1 严格判断

**❌ 不完全符合**。

用户期望口径：
```
两个 podspec 都引用同一个 flame_sdk_ios.xcframework
两个 podspec 都具备 TK/TB 平台核心运行所需公共依赖
两个 podspec 的差异只在广告源适配器依赖
```

实际现状：
```
两个 podspec 都引用同一个 flame_sdk_ios.xcframework           ✅ 符合
两个 podspec 都具备 binary dyld 硬依赖（OpenSSL + AnyThink）   ✅ 符合
两个 podspec 的差异：
  - TK podspec 多了 13 个 TK 广告源 SDK + Adapter              ✅ 符合（差异化）
  - TB podspec 多了 1 个 ToBid-iOS-RC（TB 平台核心）           ❌ 不符合（这是平台核心，不是广告源适配器）
```

### 15.2 矛盾点的本质

ToBid-iOS-RC 在分类上有歧义：
- **从架构角色看**：它是 TB 平台核心聚合 SDK（WindMillSDK/WindSDK/WindFoundation 都在里面）
- **从依赖形态看**：它是 U 引用（不是 dyld 硬依赖），只在 TB 业务调用时才需要
- **从用户口径看**：用户希望它是「公共依赖」（两个 podspec 都拉）

如果严格按用户口径「两个 podspec 都具备 TK/TB 平台核心运行所需公共依赖」：
- TB podspec 应该拉 ToBid-iOS-RC（当前 ✅）
- TK podspec 也应该拉 ToBid-iOS-RC（当前 ❌）

但**实际不需要**：
- TK 客户 pt=tk 永不调用 FlameTBProvider.initializeWithAppId
- WindMill U 引用通过 lazy binding，启动时不解析，不接入 ToBid 也不崩
- TK 客户接入 ToBid 会额外带来 9.4 MB WindMill 静态归档体积

### 15.3 两种可选口径

#### 口径 A：严格「差异只在广告源适配器」（用户原始口径）

```
两个 podspec 都拉：OpenSSL + AnyThinkiOS + ToBid-iOS-RC（平台核心公共依赖）
TK podspec 额外：13 个 TK 广告源 SDK + Adapter
TB podspec 额外：0（ToBid 默认子规范已含 Reward 能力；后续 TB Adapter 子规范按需）
```

优点：
- 口径清晰，两个 podspec 差异真的只在广告源适配器
- 双线并存只需合并广告源依赖，平台核心已是公共

缺点：
- TK 客户多接入 9.4 MB ToBid 静态归档（WindMill），但 pt=tk 永不使用
- TK 客户会看到 WindMill SDK 在 Pods 目录（虽不调用，但体积膨胀）

#### 口径 B：按「dyld 硬依赖 vs 业务需要」分类（当前实现）

```
两个 podspec 都拉：OpenSSL + AnyThinkiOS（dyld 硬依赖公共）
TK podspec 额外：13 个 TK 广告源 SDK + Adapter
TB podspec 额外：ToBid-iOS-RC（TB 平台核心，U 引用按需）
```

优点：
- TK 客户不承担 ToBid 体积（更精简）
- 依赖最小化原则

缺点：
- TB podspec 多了 1 个非广告源依赖（ToBid-iOS-RC），与「差异只在广告源适配器」口径有偏差
- 双线并存需要把 ToBid-iOS-RC 从 TB 专属提升为公共

### 15.4 建议口径

**推荐口径 B**（当前实现），但需要在文档中**明确说明**：

```
两个 podspec 的差异：
  - 主要差异：广告源适配器依赖（TK 13 个 vs TB 0 个）
  - 次要差异：TB 平台核心 ToBid-iOS-RC（只在 TB podspec，因为 TK 业务不需要）
  - 公共依赖：OpenSSL + AnyThinkiOS（binary dyld 硬依赖，两个 podspec 都必须拉）
```

如果用户更看重「口径清晰」而非「TK 客户体积最小化」，可以切到口径 A（在 TK podspec 也加 ToBid-iOS-RC 依赖）。**等待用户决策**。

## 16. 如果不符合，需要怎么调整

### 16.1 如果选择口径 A（严格「差异只在广告源适配器」）

修改 `flame_sdk_ios.podspec`，在 TK 侧也加 ToBid-iOS-RC：

```ruby
# flame_sdk_ios.podspec（TK 侧）
s.dependency 'OpenSSL-Universal', '~> 3.6'
s.dependency 'AnyThinkiOS', '6.5.71'
s.dependency 'ToBid-iOS-RC', '5.5.6'              # 新增：平台核心公共依赖
# ... TK 广告源适配器
```

影响：
- TK 客户 Pods 会多出 ToBid-iOS-RC（9.4 MB WindMill 静态归档）
- TK 客户 app binary 体积增加（静态归档合并进主二进制）
- 但口径清晰，两个 podspec 差异真的只在广告源

### 16.2 如果选择口径 B（当前实现）

保持当前两个 podspec 不变，但在文档/注释中明确说明 ToBid-iOS-RC 的特殊角色：

```
flame_sdk_ios_tb.podspec 多了 ToBid-iOS-RC，这不是「广告源适配器」而是「TB 平台核心」。
理由：TK 业务不需要 WindMill（lazy binding 不解析就不崩），所以 TK podspec 不拉。
若后续要双线并存，把 ToBid-iOS-RC 提升为公共依赖即可。
```

### 16.3 推荐

**推荐口径 B（当前实现）**，原因：
1. TK 客户不承担不必要的 9.4 MB 体积
2. 依赖最小化原则（YAGNI）
3. 双线并存的提升成本很低（一个 dependency 声明）
4. 已验证 TK 客户不接 ToBid 不会启动崩（WindMill U 引用 + lazy binding）

但**这是产品决策，建议与用户确认**。

## 17. 是否建议进入真机验证

### 17.1 静态层面已验证项

| 项 | 状态 |
|---|---|
| 单二进制构建 | ✅ |
| 符号纯净性（0 三方静态符号）| ✅ |
| 源码泄漏（0）| ✅ |
| TK Provider/Adapter 胶水内置（7 个）| ✅ |
| TB Provider/Adapter 胶水内置（2 个）| ✅ |
| Binary dyld 硬依赖明确（OpenSSL + AnyThink）| ✅ |
| 两个 podspec 都满足 dyld 硬依赖 | ✅（OpenSSL + AnyThinkiOS 都声明）|
| Demo TK Mode C 真机 BUILD SUCCEEDED | ✅ |
| Demo TB Mode C 真机 BUILD SUCCEEDED | ✅ |
| 嵌入 binary 内 +load 符号在位 | ✅（TK + TB 两个 +load 都在）|

### 17.2 真机验证前必须锁定的项

| 项 | 状态 | 备注 |
|---|---|---|
| binary 硬依赖清单 | ✅ 锁定 | OpenSSL + AnyThink（LC_LOAD_DYLIB）|
| 两个 podspec 是否都满足硬依赖 | ✅ 满足 | 两个 podspec 都声明 OpenSSL + AnyThinkiOS |
| 两个 podspec 的差异是否只在广告源适配器 | ⚠️ 有偏差 | TB 多了 ToBid-iOS-RC 平台核心；详见 §15 |

### 17.3 建议

**可以进入真机验证**，但真机验证前需要先**与用户确认口径选择**（A 还是 B）：

- 若选 **口径 A**：先修改 TK podspec 加 ToBid-iOS-RC，再真机验证
- 若选 **口径 B**：当前两个 podspec 不变，直接真机验证

真机验证关键观察点：
- TK 模式启动：dyld 是否能找到 AnyThinkSDK（otool -L 硬依赖）
- TK 模式启动：WindMill U 引用是否触发 lazy binding 报错（预期不报错，因为 pt=tk 不调用 TB 代码）
- TB 模式启动：dyld 是否能找到 AnyThinkSDK（即使 TB 业务不需要）
- TB 模式启动：ToBid-iOS-RC 是否正确提供 WindMill 符号（800031 后台未绑定错误可接受）

## 18. /compact

**Phase 5A.12 Step 1b 复核结论**：

| 项 | 结论 |
|---|---|
| 二进制硬依赖 | OpenSSL + AnyThink（LC_LOAD_DYLIB）|
| 二进制内置 | Flame core + TK/TB Provider/Adapter 胶水（9 个 ObjC 类）|
| 二进制未内置 | AnyThinkSDK / WindMill / 所有广告源 SDK |
| 两个 podspec 公共依赖 | OpenSSL + AnyThinkiOS |
| TK podspec 专属 | 13 个 TK 广告源 SDK + Adapter |
| TB podspec 专属 | ToBid-iOS-RC（TB 平台核心，不是广告源适配器）|
| 口径符合度 | ⚠️ 不完全符合（TB 多了平台核心依赖，非广告源适配器）|
| 待用户决策 | 口径 A（TK 也加 ToBid，差异真的只在广告源）vs 口径 B（当前实现，TK 不加 ToBid）|
| Step 1 报告需修正措辞 | 「二进制完全内置 TK/TB 平台核心」→「内置 Flame 胶水，平台核心 SDK 由 podspec 提供」|
| 是否可进入真机验证 | ✅ 可以（但建议先确认口径选择）|

**关键文件清单**：

```
doc/flame_mediation/
├── phase-5a.12-single-binary-dual-core-plan.md                # 方案文档（措辞待修正）
├── phase-5a.12-step1-single-binary-dual-core-build-report.md  # Step 1 报告（措辞待修正）
└── phase-5a.12-step1b-single-binary-dependency-boundary-review.md  # 本复核报告

research/local_dist/logs/
├── single-binary-step1b-harddeps.log                          # otool -L / nm 完整实证
├── single-binary-step1b-podspec-deps.log                      # 两个 podspec 依赖列表
└── single-binary-step1b-undefined-refs.log                    # U 引用按平台分类
└── single-binary-step1b-load-path-analysis.log                # +load 路径安全性分析
```

**等待用户决策**：
1. 口径选择（A：TK 也加 ToBid，差异真的只在广告源；B：当前实现，TK 不加 ToBid）
2. 口径确认后，修正 Step 1 报告与方案文档的措辞
3. 然后进入 Step 2 真机验证

**红线遵守**：未发布、未 push、未 tag、未 pod repo push。
