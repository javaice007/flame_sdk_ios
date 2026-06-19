# Phase 5A.12 mainline：单二进制主线方案

> **版本**：v1.0（mainline）
> **分支**：`research/single-binary-mainline`（从 `research/thin-core-binary` 切出）
> **创建日期**：2026-06-19
> **状态**：主线清理完成，构建验证通过，等待真机验证

---

## 1. 为什么新切 research/single-binary-mainline

Phase 5A.12 在 `research/thin-core-binary` 分支推进到 Step 1b 后，发现两个问题：

1. **历史入口混杂**：`research/thin-core-binary` 同时保留了 tk/tb/core/core-named/tk-plugin/tb-plugin/release/single-binary/nosdk/dual 共 10 个构建变体入口。一旦出 bug，很难判断实际走的是哪条路径。
2. **宏体系未清**：`FLAME_BUILD_TK` / `FLAME_BUILD_TB` / `FLAME_PLUGIN_TK` / `FLAME_PLUGIN_TB` / `FLAME_BUILD_CORE` 宏仍然散布在源码 + Podfile + podspec + 构建脚本中，通过宏裁剪决定哪些源码参与编译。

新切 `research/single-binary-mainline` 分支的目的：**只保留单二进制主线，彻底删除历史双包/三包/互斥宏/历史构建入口**。

## 2. 为什么不在 research/thin-core-binary 继续混合推进

`research/thin-core-binary` 是 Phase 5A.10/5A.11/5A.12 的混合分支：
- Phase 5A.10 thin core binary（`build/flame_sdk_ios_core.xcframework`）
- Phase 5A.11 三包方案（core + tk-plugin + tb-plugin）
- Phase 5A.12 single-binary（叠加在原分支上）

三个方案的代码、宏、构建入口、podspec 实验全部混在一起。继续在这个分支推进会让主线越来越难以维护。

新分支彻底清理，只保留 Phase 5A.12 single-binary，代码路径单一清晰。

## 3. 为什么 tb_adapter 只作为兜底

`feat/tb_adapter`（HEAD `086a766`）+ `backup/phase-5a-dual-binary-stable` 保存的是「双二进制互斥分发方案」：
- TK binary（276K，不打包 WindMill）
- TB binary（6.9M，自包含 WindMill 9.4MB 静态归档）

这是经过验证的兜底方案。如果 Phase 5A.12 mainline 真机验证发现无法解决的问题（如 +load 在某些 CocoaPods 版本失效），可以立即回退到双二进制方案。

**保留方式**：不删除分支，不合并，不 cherry-pick。仅作为历史记录与应急兜底。

## 4. 当前分支只保留 single-binary

```
research/single-binary-mainline
├── 构建脚本：xcFramework_build.sh（只支持 single-binary）
├── Podfile：单一依赖环境（OpenSSL + AnyThinkiOS + ToBid-iOS-RC）
├── 源码：TK/TB Provider/Adapter 始终全部编译（无宏隔离）
├── podspec × 2：flame_sdk_ios.podspec + flame_sdk_ios_tb.podspec（同引一个 binary）
└── 产物：build/flame_sdk_ios.xcframework（唯一）
```

## 5. 旧 tk/tb/release/三包构建入口已删除

`xcFramework_build.sh` 重写后：
- ✅ 默认 = single-binary
- ✅ 显式 `./xcFramework_build.sh single-binary`
- ❌ `tk` / `tb` / `core` / `core-named` / `tk-plugin` / `tb-plugin` / `release` / `nosdk` / `dual` 全部拒绝（报错退出）

报错信息：
```
❌ 当前分支只支持 single-binary 构建，不再支持 tk/tb/release/三包/双二进制历史入口。
```

## 6. 旧 TK/TB 互斥宏已删除

源码层删除的宏：
- `FLAME_BUILD_TK` / `FLAME_BUILD_TB` / `FLAME_BUILD_CORE`（构建变体宏）
- `FLAME_PLUGIN_TK` / `FLAME_PLUGIN_TB`（+load 启用宏）
- `HAS_TOBID`（历史遗留）

删除位置：
- `flame_sdk_ios/core/FlameSdk.m`（删除 `#error` 互斥 + `#if` import 分支 + `registerAllProvidersIfNeeded` 宏分支）
- `flame_sdk_ios/adapter/tk/*.h+.m`（12 个文件，删除 `#if defined(FLAME_BUILD_TK)...#endif` 守卫）
- `flame_sdk_ios/adapter/tb/*.h+.m`（2 个文件，删除 `#if defined(FLAME_BUILD_TB)...#endif` 守卫）
- `flame_sdk_ios/adapter/FlameAdapterManager.m`（删除 `#if/#else/#endif` 平台分支）
- `flame_sdk_ios/mediation/tk/FlameTKProvider.h+.m`（2 个文件，删除守卫 + +load 始终启用）
- `flame_sdk_ios/mediation/tb/FlameTBProvider.h+.m`（2 个文件，删除守卫 + +load 始终启用）
- `Podfile`（删除 tk/tb/dual 变体分支）
- `xcFramework_build.sh`（删除 BUILD_MACRO 注入）

## 7. binary 内置 Flame core + TK/TB 胶水

```
flame_sdk_ios.xcframework（300K，MH_DYLIB）
├── Flame SDK 自有 core
│   ├── FlameSdk / FlameLogger / FlameMediationRouter / FlameMediationRegistry
│   ├── FlameAdapterManager / FlameConfigManager / FlameErrorCode / FlameAppEntity
│   ├── FlameBannerAdImpl / FlameInterstitialAdImpl / FlameNativeAdImpl
│   ├── FlameRewardAdImpl / FlameSplashAdImpl
│   └── FlameAesCryptoUtils / FlameConfigLocalStorage / FlameMd5SignatureUtils 等
├── TK 平台胶水（始终编译）
│   ├── FlameTKProvider（+load 自动注册 tk）
│   └── AtRewardAdapter / AtSplashAdapter / AtInterstitialAdapter /
│       AtBannerAdapter / AtNativeAdapter / AtNativeSelfRenderView
└── TB 平台胶水（始终编译）
    ├── FlameTBProvider（+load 自动注册 tb）
    └── TbRewardAdapter
```

## 8. AnyThinkiOS + ToBid-iOS-RC 作为两个 podspec 公共平台核心依赖

两个 podspec 都声明：

```ruby
s.dependency 'OpenSSL-Universal', '~> 3.6'    # 加密基础依赖
s.dependency 'AnyThinkiOS', '6.5.71'           # TK 平台核心（binary LC_LOAD_DYLIB 硬依赖）
s.dependency 'ToBid-iOS-RC', '5.5.6'           # TB 平台核心（WindMill 静态归档）
```

**为什么 AnyThinkiOS 是公共依赖（两个 podspec 都声明）**：
- binary otool -L 显示 `@rpath/AnyThinkSDK.framework/AnyThinkSDK`（LC_LOAD_DYLIB 硬依赖）
- dyld 加载 binary 时必须能找到 AnyThinkSDK.framework
- 即使 TB 客户 pt=tb 永不调用 TK 代码，dyld 启动也需要 AnyThinkSDK 存在
- 因此两个 podspec 都必须声明

**为什么 ToBid-iOS-RC 也作为公共依赖（两个 podspec 都声明）**：
- binary 内的 TB 胶水（FlameTBProvider/TbRewardAdapter）通过 U 引用 WindMill 符号
- pt=tk 时 lazy binding 不解析（不崩），TK 客户技术上不需要 ToBid
- 但为统一口径 + 后续双线并存准备，两个 podspec 都声明 ToBid-iOS-RC
- 代价：TK 客户的 Pods 会多出 ToBid-iOS-RC（~9.4MB WindMill 静态归档，合并进 app binary）

## 9. 广告源 SDK / Adapter 由 podspec 差异化声明

### 9.1 flame_sdk_ios.podspec（TK 客户）

差异化广告源依赖（TK 专属）：
- `AnyThinkMediationAdxSmartdigimktCNAdapter` / `GromoreAdapter` / `BaiduAdapter` / `MSAdapter` / `ZYAdapter` / `FunlinkAdapter` / `BeiZiAdapter` / `KuaiShouAdapter` / `SigmobAdapter` / `TTAdapter_Mix` / `GDTAdapter`（共 11 个 AnyThinkMediation* Adapter）
- `AdGainSDK` + `AdGainSDKTakuAdapter`
- `FSUnionAdSDK`

### 9.2 flame_sdk_ios_tb.podspec（TB 客户）

差异化广告源依赖（TB 专属，当前为空）：
- 当前 TB Reward 阶段使用 ToBid-iOS-RC 默认 ToBidSDK 子规范
- 后续 Phase 5A.13+ 接 TB Splash/Interstitial/Banner/Native 时，按需增加：
  - `ToBid-iOS-RC/CSJAdapter`
  - `ToBid-iOS-RC/GDTAdapter`
  - 等 21 个 ToBid Adapter 子规范

## 10. 后续双线并存不重做 binary，只调整广告源依赖

mainline 单二进制方案的**最大架构红利**：双线并存**不需要重新做二进制包**。

因为单二进制已同时含 TK/TB 平台胶水 + 公共依赖已统一声明。双线并存只需：

```ruby
# flame_sdk_ios_dual.podspec（Phase 5A.14 设想）
s.vendored_frameworks = 'flame_sdk_ios.xcframework'   # 同一份

# 公共依赖（与 TK/TB podspec 一致）
s.dependency 'OpenSSL-Universal', '~> 3.6'
s.dependency 'AnyThinkiOS', '6.5.71'
s.dependency 'ToBid-iOS-RC', '5.5.6'

# 合并 TK + TB 广告源依赖
s.dependency 'AnyThinkMediation*Adapter', '...'
s.dependency 'AdGainSDK', '4.2.7.1'
s.dependency 'FSUnionAdSDK', '1.0.8.0'
# + ToBid-iOS-RC/<Adapter> 子规范（按需）
```

双线并存需处理的工程问题（Phase 5A.14）：
- 依赖版本冲突
- duplicate framework（如 SigmobAd-iOS 与 ToBid-iOS-RC 同源 WindSDK）
- duplicate symbol
- static archive 链接顺序

---

## 附：构建命令

```bash
./xcFramework_build.sh                 # 默认 = single-binary
./xcFramework_build.sh single-binary   # 显式写法（等价默认）
```

两者输出完全相同：`build/flame_sdk_ios.xcframework`

## 附：客户接入示例

TK 客户：
```ruby
# Podfile
use_frameworks! :linkage => :static
pod 'flame_sdk_ios'
```

TB 客户：
```ruby
# Podfile
use_frameworks! :linkage => :static
pod 'flame_sdk_ios_tb'
```

接入方代码（两个客户一致）：
```objc
#import <flame_sdk_ios/FlameSdk.h>

[FlameSdk initWithAppId:@"..." appKey:@"..." callback:self];
```

平台由服务端下发的 `pt=tk` / `pt=tb` 决定，客户端代码完全一致。

---

**红线遵守**：未发布、未 push、未 tag、未 pod repo push、未合并、未 cherry-pick、未删除兜底分支。
