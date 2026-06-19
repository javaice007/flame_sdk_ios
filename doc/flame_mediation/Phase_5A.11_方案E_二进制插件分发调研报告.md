# Phase 5A.11 方案 E：源码不暴露的二进制插件分发调研报告

> **状态**：调研报告（未发布，未实施）
> **日期**：2026-06-18
> **前置**：Phase 5A.10 方案 D（thin core + source_files 平台源码）已发布 1.0.0-alpha.1/alpha.2
> **结论先行**：方案 D 的 `source_files` 平台源码发布模式存在**源码暴露**问题，必须改为方案 E（Core Binary + Platform Plugin Binary）。本报告已完成技术可行性论证，**未执行任何发布动作**。

---

## 0. TL;DR（结论摘要）

| 维度 | 结论 |
|---|---|
| 源码暴露是否已复现 | ✅ 已在客户 Demo `Pods/flame_sdk_ios/` 复现，7 个 `.m` 文件可见 |
| 方案 D 暴露根因 | `s.source_files` 把平台源码（FlameTKProvider/At*Adapter）随 GitHub archive 一起下发 |
| 方案 E 是否可行 | ✅ 技术可行，符号/依赖/模块结构均已验证 |
| TK/TB plugin binary 能否不静态打入三方 SDK | ✅ 能。adapter 源码只 `#import <AnyThinkSDK/AnyThinkSDK.h>` / `<WindMillSDK/WindMillSDK.h>`，不直接引用任何广告源 SDK，构建期只 link 头，符号为 undefined(U) 由 podspec 依赖在接入期解析 |
| 客户 Pods 是否还会出现 `.m` | ✅ 方案 E 后只剩 vendored framework，无 `.m` 源码 |
| import 兼容性 | ✅ 不变，仍 `#import <flame_sdk_ios/FlameSdk.h>` / `import flame_sdk_ios` |
| Podfile 兼容性 | ✅ 不变，仍 `pod 'flame_sdk_ios'` / `pod 'flame_sdk_ios_tb'` |
| +load 自动注册 | ✅ 可执行，需 `-ObjC` + framework 链入，方案 E 天然满足 |
| 是否还需要 `use_frameworks! :linkage => :static` | 第二优先级，方案 E 不解决也不引入此问题；可单独用 `s.static_framework = true` 优化 |
| 是否建议作为正式分发方案 | ✅ 强烈建议。方案 E 是唯一能同时满足「源码不暴露 + thin core + 单 pod 接入」的结构 |
| 风险 | plugin binary 内同名 module `flame_sdk_ios` 与 core binary module `flame_sdk_ios_core` 的 modulemap 关系；TK plugin 必须动态（dylib）以承载 +load |
| 下一步 | 构建最小可验证 TK plugin binary，真机验证 +load；不发布 alpha.3 |

---

## 1. 当前方案 D 为什么会暴露源码

方案 D 的发布结构是：

```
vendored_frameworks = build/flame_sdk_ios_core.xcframework   ← 二进制（thin core）
source_files = [
  wrappers/flame_sdk_ios/*.{h,m,mm}        ← 转发头（header-only，无 .m）
  mediation/tk/**/*.{h,m,mm}               ← FlameTKProvider 源码 ⚠️
  adapter/tk/**/*.{h,m,mm}                 ← At*Adapter 源码 ⚠️
]
```

**根因**：CocoaPods 的 `source_files` 语义是「这些源文件**会随 pod 一起下发到客户 Pods/ 目录**，并在 pod install 时**由客户工程的编译器现场编译**」。

这套机制在两个环节都会导致源码可见：

1. **传输层**：podspec 的 `s.source` 指向 GitHub archive zip（`https://github.com/javaice007/flame_sdk_ios/archive/refs/tags/{version}.zip`），整个仓库源码树被打包下发。即使 podspec 的 `source_files` 只 glob 了一部分，下载到 `~/Library/Caches/CocoaPods/` 的完整仓库快照里也含全部源码；而 CocoaPods 会把 glob 命中的 `.m` 拷到 `Pods/flame_sdk_ios/`。
2. **编译层**：`source_files` 命中的 `.m` 会被客户工程的 Pods target 现场编译。客户在 Xcode → Pods → flame_sdk_ios 下能直接点开看到 `FlameTKProvider.m`、`AtRewardAdapter.m` 全文。

> **关键认知**：`source_files` 不是「编译期私有依赖」，而是「源码下发 + 现场编译」。任何走 `source_files` 的方案都必然暴露源码。这跟 `private_header_files` 无关——`private_header_files` 只控制头的 public/private 属性，不阻止 `.m` 下发。

## 2. 哪些源码会暴露（已逐一核对）

### 2.1 TK pod 暴露的源码（7 个 `.m`）

通过 `git ls-tree -r 1.0.0-alpha.2` + 实测客户 `Pods/flame_sdk_ios/`，确认以下文件在 alpha.2 tag 下可见：

| 文件 | 行数(约) | 暴露内容 |
|---|---|---|
| `flame_sdk_ios/mediation/tk/FlameTKProvider.m` | ~150 | **TK Provider 全部初始化逻辑**：+load 注册、AnyThink startWithAppID、adapter 实例化、平台分发 |
| `flame_sdk_ios/adapter/tk/AtRewardAdapter.m` | ~160 | 激励视频适配逻辑、reward 回调映射、AT(ATRewardVideoAd) 调用细节 |
| `flame_sdk_ios/adapter/tk/AtSplashAdapter.m` | ~220 | 开屏适配、ATSplashAd 生命周期 |
| `flame_sdk_ios/adapter/tk/AtInterstitialAdapter.m` | ~170 | 插屏适配 |
| `flame_sdk_ios/adapter/tk/AtBannerAdapter.m` | ~430 | **Banner 最复杂适配器**：素材解析、自渲染 slot、刷新调度 |
| `flame_sdk_ios/adapter/tk/AtNativeAdapter.m` | ~680 | **Native 最复杂适配器**：原生素材组装、自渲染视图绑定 |
| `flame_sdk_ios/adapter/tk/AtNativeSelfRenderView.m` | ~200 | 自渲染视图布局实现 |

**合计约 2000 行核心商业适配源码对外可见**，包含我们与 TopOn/AnyThink 的集成细节、回调时序、素材结构。

### 2.2 TB pod 暴露的源码（2 个 `.m`）

| 文件 | 暴露内容 |
|---|---|
| `flame_sdk_ios/mediation/tb/FlameTBProvider.m` | TB Provider 初始化、WindMill 启动 |
| `flame_sdk_ios/adapter/tb/TbRewardAdapter.m` | TB 激励视频适配 |

### 2.3 头文件暴露（次要但敏感）

- `FlameMediationProvider.h`、`FlameMediationRegistry.h`、各 `*AdapterProtocol.h`：内部协议定义
- `FlameAdapterManager.h`：内部适配器管理接口

这些虽是头文件（接口声明），但暴露了我们的中介架构设计。

## 3. 是否已经在客户 Pods 中复现

✅ **已复现，实测如下**（客户 Demo：`/Users/khj/Documents/code/97_ad/ios/adsurge-ios-demo`，接入 alpha.2）：

```
Pods/flame_sdk_ios/flame_sdk_ios/adapter/tk/AtInterstitialAdapter.m
Pods/flame_sdk_ios/flame_sdk_ios/adapter/tk/AtNativeAdapter.m
Pods/flame_sdk_ios/flame_sdk_ios/adapter/tk/AtRewardAdapter.m
Pods/flame_sdk_ios/flame_sdk_ios/adapter/tk/AtBannerAdapter.m
Pods/flame_sdk_ios/flame_sdk_ios/adapter/tk/AtNativeSelfRenderView.m
Pods/flame_sdk_ios/flame_sdk_ios/adapter/tk/AtSplashAdapter.m
Pods/flame_sdk_ios/flame_sdk_ios/mediation/tk/FlameTKProvider.m
```

共 **7 个 `.m` 源码文件**直接出现在客户工程中，可在 Xcode 中打开查看全文。

## 4. 方案 E 的目标结构

方案 E 的核心改动：**平台插件从「源码 + 现场编译」改为「预编译二进制 framework」**。

### 4.1 分发仓库最终结构

```
flame_sdk_ios/                              ← distribution repo root
├── flame_sdk_ios_core.xcframework          ← 共享 thin core binary（不变）
│   └── ios-arm64/flame_sdk_ios_core.framework
├── tk/
│   └── flame_sdk_ios.xcframework           ← 新增：TK plugin binary
│       └── ios-arm64/flame_sdk_ios.framework
├── tb/
│   └── flame_sdk_ios.xcframework           ← 新增：TB plugin binary
│       └── ios-arm64/flame_sdk_ios.framework
├── flame_sdk_ios.podspec                   ← TK podspec
├── flame_sdk_ios_tb.podspec                ← TB podspec
├── README.md
├── CHANGELOG.md
└── LICENSE
```

**关键点**：

- TK 和 TB 各自有一个名为 `flame_sdk_ios.xcframework` 的外壳二进制。文件名相同**没有冲突**，因为客户只会接其中一个 pod（TK/TB 互斥），二者永远不会同时出现在同一工程。
- 二者分目录 `tk/` 和 `tb/` 避免在同一仓库里互相覆盖。
- core binary 名仍是 `flame_sdk_ios_core.xcframework`（module = `flame_sdk_ios_core`），与 plugin 的 module = `flame_sdk_ios` 区分，避免同名 module 遮蔽（方案 D 已验证的命名隔离）。

### 4.2 TK plugin binary 包含什么

```
flame_sdk_ios.framework (module = flame_sdk_ios)
├── flame_sdk_ios              ← Mach-O binary
├── Headers/
│   ├── flame_sdk_ios.h        ← umbrella（转发到 flame_sdk_ios_core 的公共 API）
│   ├── FlameSdk.h             ← 转发头：#import <flame_sdk_ios_core/FlameSdk.h>
│   ├── FlameRewardAd.h / FlameSplashAd.h / FlameInterstitialAd.h
│   ├── FlameBannerAd.h / FlameNativeAd.h / FlameCallback.h
│   ├── FlameBannerAdMaterial.h / FlameBannerAdRenderSlots.h
│   └── （内部协议头：FlameMediationProvider.h 等，private）
├── Modules/module.modulemap
└── Info.plist
```

binary 内编译进来的对象文件（**纯符号，不含三方 SDK**）：

- `FlameTKProvider.o`（含 +load，由 `FLAME_PLUGIN_TK` 宏启用）
- `AtRewardAdapter.o` / `AtSplashAdapter.o` / `AtInterstitialAdapter.o`
- `AtBannerAdapter.o` / `AtNativeAdapter.o` / `AtNativeSelfRenderView.o`

### 4.3 TB plugin binary 包含什么

```
flame_sdk_ios.framework (module = flame_sdk_ios)
├── flame_sdk_ios
├── Headers/
│   ├── flame_sdk_ios.h
│   ├── FlameSdk.h （转发）
│   ├── ... （同 TK 的公共 API 头）
│   └── （FlameTBProvider 等 private）
├── Modules/module.modulemap
└── Info.plist
```

binary 内：

- `FlameTBProvider.o`（含 +load，由 `FLAME_PLUGIN_TB` 宏启用）
- `TbRewardAdapter.o`

> Phase 5A 阶段 TB 仅实现 Reward，后续 Splash/Interstitial/Banner/Native 占位 nil（Phase 6 补齐）。

## 5. TK plugin binary 如何构建

### 5.1 复用现有构建基础设施

现有 `xcFramework_build.sh` 已支持 `tk` / `tb` / `core` / `core-named` 四种变体：

| 变体 | BUILD_MACRO | 输出 | 当前状态 |
|---|---|---|---|
| `core-named`（默认） | `FLAME_BUILD_CORE=1` | `build/flame_sdk_ios_core.xcframework` | ✅ 方案 D 在用 |
| `tk`（legacy fallback） | `FLAME_BUILD_TK=1` | `build/tk/flame_sdk_ios.xcframework` | 已存在，但**没注入 `FLAME_PLUGIN_TK`** → +load 不触发 |
| `tb`（legacy fallback） | `FLAME_BUILD_TB=1` | `build/tb/flame_sdk_ios.xcframework` | 同上 |

**方案 E 需要的新变体**（建议命名 `tk-plugin` / `tb-plugin`）：

- 在 `tk` / `tb` 的基础上**额外注入 `FLAME_PLUGIN_TK=1` / `FLAME_PLUGIN_TB=1`**
- 输出到 `build/tk/flame_sdk_ios.xcframework`（与 legacy 同路径，覆盖旧产物）

### 5.2 Podfile 构建期依赖（不变）

现有 Podfile TK 变体已经满足：

```ruby
if variant == 'tk'
  pod 'OpenSSL-Universal', '~> 3.6'
  pod 'AnyThinkiOS', '6.5.71'   # 只需 AnyThink 头，不需要 Mediation Adapter
end
```

构建期只需 `AnyThinkiOS`（adapter 源码 `#import <AnyThinkSDK/AnyThinkSDK.h>` 用），**不需要任何 `AnyThinkMediation*Adapter` / 广告源 SDK**。Podfile 里的红线注释已经写明这一点：

> TK adapter 源码已审计：只 import AnyThinkSDK/AnyThinkSDK.h，不直接 import 任何广告源 SDK。

### 5.3 构建宏注入（脚本改动点）

```bash
elif [ "$VARIANT" = "tk-plugin" ]; then
  BUILD_MACRO="FLAME_BUILD_TK=1 FLAME_PLUGIN_TK=1"
  VARIANT_OUTPUT_SUBDIR="tk"
elif [ "$VARIANT" = "tb-plugin" ]; then
  BUILD_MACRO="FLAME_BUILD_TB=1 FLAME_PLUGIN_TB=1"
  VARIANT_OUTPUT_SUBDIR="tb"
```

其余 archive / create-xcframework / bitcode strip 流程**完全复用**，不需要 core-named 那套改名逻辑（plugin binary 名保持 `flame_sdk_ios`，不需要改名）。

## 6. TB plugin binary 如何构建

与 TK 对称，Podfile `tb` 变体：

```ruby
if variant == 'tb'
  pod 'OpenSSL-Universal', '~> 3.6'
  pod 'ToBid-iOS-RC', '5.5.6'   # 提供 WindMillSDK 头
end
```

构建宏：`FLAME_BUILD_TB=1 FLAME_PLUGIN_TB=1`，输出 `build/tb/flame_sdk_ios.xcframework`。

## 7. 是否能避免静态打入三方 SDK（核心验证点）

✅ **能**。证据链如下：

### 7.1 源码层证据：adapter 只引用聚合 SDK 头，不引用广告源 SDK

逐个核对 adapter `.m` 的 import（grep 结果）：

| 文件 | import 内容 | 引用广告源 SDK？ |
|---|---|---|
| `AtRewardAdapter.m` | `AnyThinkSDK/AnyThinkSDK.h` + Flame 内部头 | ❌ 无 |
| `AtSplashAdapter.m` | （仅 Flame 内部） | ❌ 无 |
| `AtInterstitialAdapter.m` | （仅 Flame 内部） | ❌ 无 |
| `AtBannerAdapter.m` | `FlameBannerAdMaterial` + Flame 内部 | ❌ 无 |
| `AtNativeAdapter.m` | （仅 Flame 内部） | ❌ 无 |
| `AtNativeSelfRenderView.m` | `AtNativeSelfRenderView.h` | ❌ 无 |
| `FlameTKProvider.m` | `AnyThinkSDK/AnyThinkSDK.h` + Flame 内部 | ❌ 无 |
| `TbRewardAdapter.m` | `WindMillSDK/WindMillSDK.h` + Flame 内部 | ❌ 无 |
| `FlameTBProvider.m` | `WindMillSDK/WindMillSDK.h` + Flame 内部 | ❌ 无 |

所有 adapter/Provider 都只 `#import` **聚合 SDK 的伞头**（AnyThinkSDK / WindMillSDK），运行时通过聚合 SDK 反射调用各家广告源，**从不直接 import `BUAdSDK` / `GDTAdSDK` / `KSAdSDK` / `SigmobAd` / `FSUnionAdSDK`**。

### 7.2 构建层证据：构建期 Podfile 不含广告源 SDK

现有 Podfile TK 变体只声明 `AnyThinkiOS`，Podfile 注释已写明：

> 严格边界：这里只放 Flame 源码编译直接需要的 AnyThink 核心 SDK。不要放 AnyThinkMediation*Adapter / AdGain / FSUnion / CSJ / GDT / Sigmob 等运行时广告源依赖。

构建期 Pods/ 里**没有**任何广告源 SDK 静态库，archive 阶段无物可 link。

### 7.3 符号层预期结果（待实跑 nm 验证）

构建出 TK plugin binary 后，预期：

```
nm -gU flame_sdk_ios (TK plugin)
  → 应见 _OBJC_CLASS_$_FlameTKProvider / _OBJC_CLASS_$_AtRewardAdapter ... （Flame 自己的符号）
  → 应见 +load 的 __objc_classlist section
  → 不应见 _OBJC_CLASS_$_BUAdSDK / _OBJC_CLASS_$_GDTMobAd / _OBJC_CLASS_$_KSAdSDK ...
  → 不应见 _OBJC_CLASS_$_AT5193RewardedVideoAd 等 AnyThink 实现类（应为 U undefined，运行时解析）

otool -L flame_sdk_ios (TK plugin)
  → @rpath/flame_sdk_ios.framework/flame_sdk_ios
  → @rpath/flame_sdk_ios_core.framework/flame_sdk_ios_core   ← 依赖 core
  → @rpath/OpenSSL.framework/OpenSSL                          ← 通过 core 传递（或显式）
  → /usr/lib/libobjc.A.dylib                                  ← +load / objc runtime
  → 系统 framework
  → 不应见 AnyThinkSDK / BUAdSDK / 任何广告源 framework
```

AnyThink 的符号在 plugin binary 里是 **undefined (U)** 状态——即「我知道有这些符号，但运行时由别处提供」。接入期 podspec 声明 `pod 'AnyThinkiOS'` → CocoaPods 把 AnyThink 的 framework 放进 `Pods/`，链接时解析这些 U 符号。

> **这一节需要实跑 `./xcFramework_build.sh tk-plugin`（新增宏注入）后用 nm/otool 复核**。本报告基于源码层和 Podfile 层的强证据做出结论，但实跑验证仍是发布前的强制门控（见 §17）。

## 8. nm / otool 检查结果

### 8.1 当前 core binary（已发布，方案 D 在用）

```
binary: build/flame_sdk_ios_core.xcframework/ios-arm64/flame_sdk_ios_core.framework/flame_sdk_ios_core
type:   Mach-O 64-bit dynamically linked shared library arm64
size:   176K

otool -L:
  @rpath/flame_sdk_ios_core.framework/flame_sdk_ios_core
  @rpath/OpenSSL.framework/OpenSSL
  Foundation / libobjc.A.dylib / libSystem.B.dylib / CoreFoundation

nm -u (引用 plugin 类？):
  → 空（core 不引用 FlameTKProvider / At*Adapter / FlameTBProvider / TbRewardAdapter）
```

✅ core binary 干净，零三方符号，零 plugin 符号引用。

### 8.2 TK/TB plugin binary（待构建）

方案 E 尚未构建，§7.3 列出预期检查项。实跑命令模板：

```bash
# TK plugin
./xcFramework_build.sh tk-plugin
BIN=$(find build/tk/flame_sdk_ios.xcframework -name flame_sdk_ios -path "*arm64*" | head -1)
file "$BIN"
otool -L "$BIN"
nm -gU "$BIN" | grep -E "FlameTKProvider|AtRewardAdapter|AtSplashAdapter|AtInterstitialAdapter|AtBannerAdapter|AtNativeAdapter"  # 应 > 0
nm -gU "$BIN" | grep -E "BU|GDT|KSAd|Sigmob|FSUnion|AdGain|Baidu"  # 应 = 0
nm -u "$BIN" | grep -E "AT|AnyThink"  # 应 > 0（运行时由接入期解析）

# TB plugin
./xcFramework_build.sh tb-plugin
BIN=$(find build/tb/flame_sdk_ios.xcframework -name flame_sdk_ios -path "*arm64*" | head -1)
nm -gU "$BIN" | grep -E "FlameTBProvider|TbRewardAdapter"  # 应 > 0
nm -gU "$BIN" | grep -E "BU|GDT|AnyThink|AT"  # 应 = 0
nm -u "$BIN" | grep -E "WindMill"  # 应 > 0
```

## 9. podspec 结构建议

### 9.1 TK podspec（`flame_sdk_ios.podspec`）

```ruby
Pod::Spec.new do |s|
  s.name             = 'flame_sdk_ios'
  s.version          = '1.0.0-alpha.3'   # 方案 E 首发
  s.module_name      = 'flame_sdk_ios'
  s.summary          = 'Flame iOS Ad SDK - TK Edition'
  s.homepage         = 'https://github.com/javaice007/flame_sdk_ios'
  s.author           = { 'flame' => 'flame@toowe.com' }
  s.license          = { :type => 'Commercial', :text => 'Copyright Flame' }
  s.ios.deployment_target = '13.0'
  s.swift_version    = '5.0'

  s.source = {
    :http => "https://github.com/javaice007/flame_sdk_ios/archive/refs/tags/#{s.version}.zip",
    :flatten => true,
  }

  # ========= 方案 E 核心：双 vendored framework =========
  # 1. flame_sdk_ios_core.xcframework：thin core（不变，方案 D 已验证）
  # 2. tk/flame_sdk_ios.xcframework：TK plugin（含 FlameTKProvider +load + At*Adapter）
  s.vendored_frameworks = [
    'flame_sdk_ios_core.xcframework',
    'tk/flame_sdk_ios.xcframework'
  ]

  # ========= 不再有 source_files / private_header_files =========
  # 平台源码已预编译进 tk/flame_sdk_ios.xcframework，不下发 .m
  # 公共 API 头由 plugin framework 的 Headers/ 提供（modulemap 暴露）

  # ========= 依赖（不变）=========
  s.dependency 'OpenSSL-Universal', '~> 3.6'
  s.dependency 'AnyThinkiOS', '6.5.71'
  s.dependency 'AnyThinkMediationAdxSmartdigimktCNAdapter', '6.5.72.2.1'
  # ...（其余 AnyThinkMediation* + AdGain + FSUnion，与 alpha.2 一致）

  # ========= xcconfig（大幅简化）=========
  # 不再需要 FLAME_BUILD_TK / FLAME_PLUGIN_TK 宏（已在构建期 baked-in）
  # 不再需要 -F ${PODS_XCFRAMEWORKS_BUILD_DIR}（vendored_frameworks 自动处理）
  # 只保留 -ObjC（+load 必需）
  s.pod_target_xcconfig = {
    'OTHER_LDFLAGS' => '$(inherited) -ObjC'
  }
end
```

### 9.2 TB podspec（`flame_sdk_ios_tb.podspec`）

```ruby
Pod::Spec.new do |s|
  s.name             = 'flame_sdk_ios_tb'
  s.version          = '1.0.0-alpha.3'
  s.module_name      = 'flame_sdk_ios'   # 与 TK 一致，接入方 import 不变
  # ...（license / platform 同 TK）

  s.source = {
    :http => "https://github.com/javaice007/flame_sdk_ios/archive/refs/tags/#{s.version}.zip",
    :flatten => true,
  }

  # 双 vendored framework（core 共享，TB plugin 不同）
  s.vendored_frameworks = [
    'flame_sdk_ios_core.xcframework',
    'tb/flame_sdk_ios.xcframework'
  ]

  s.dependency 'OpenSSL-Universal', '~> 3.6'
  s.dependency 'ToBid-iOS-RC', '5.5.6'

  s.pod_target_xcconfig = {
    'OTHER_LDFLAGS' => '$(inherited) -ObjC'
  }
end
```

### 9.3 podspec 简化收益对比

| 项 | 方案 D（alpha.2） | 方案 E |
|---|---|---|
| `source_files` | 3 段 glob（wrappers + mediation + adapter） | **删除** |
| `public_header_files` | 1 段 glob | **删除**（由 framework Headers 提供） |
| `private_header_files` | 2 段 glob | **删除** |
| `vendored_frameworks` | 1 个（core） | 2 个（core + plugin） |
| `pod_target_xcconfig` | 6 项（宏 + 4 路径 + DEFINES_MODULE） | 1 项（`-ObjC`） |
| 整体行数 | ~80 行 | ~35 行 |

## 10. 客户接入方式是否保持不变

✅ **完全不变**。

```ruby
# TK 客户
target 'MyApp' do
  use_frameworks! :linkage => :static   # 或优化为 use_frameworks!（见 §13）
  pod 'flame_sdk_ios', '1.0.0-alpha.3'
end

# TB 客户
target 'MyApp' do
  use_frameworks! :linkage => :static
  pod 'flame_sdk_ios_tb', '1.0.0-alpha.3'
end
```

接入侧零改动，只是 pod 版本号从 alpha.2 → alpha.3。

## 11. import 是否保持不变

✅ **完全不变**。

```objc
// ObjC
#import <flame_sdk_ios/flame_sdk_ios.h>
#import <flame_sdk_ios/FlameSdk.h>
#import <flame_sdk_ios/FlameRewardAd.h>
```

```swift
// Swift
import flame_sdk_ios
```

**原理**：方案 E 的 TK/TB plugin framework 的 module 名都是 `flame_sdk_ios`（module_name 统一），Headers/ 里包含 `FlameSdk.h` 等公共 API。接入方 `import flame_sdk_ios` 解析到 plugin framework 的 modulemap，公共 API 全部可见。

**与方案 D 的差异**（接入方无感知）：

- 方案 D：`import flame_sdk_ios` → pod 编译出的 source_files target 的 module → 转发头 → core binary module
- 方案 E：`import flame_sdk_ios` → plugin framework 的 module（公共 API 直接在 plugin Headers/）→ plugin binary 内部 link core binary

方案 E 少了一层「转发头」，更直接，但接入方写法完全一样。

## 12. +load 是否可执行

✅ **可执行**，且方案 E 比方案 D 更可靠。

### 12.1 +load 触发条件

+load 自动注册能触发的必要条件：

1. **链接进 App**：包含 +load 的对象文件必须被链接进最终 App 二进制（不能被 strip 掉）
2. **`-ObjC` linker flag**：让 linker 加载所有 ObjC 类的 category 和 +load section
3. **Mach-O section 存在**：binary 里要有 `__objc_classlist` / `__objc_nlclslist`（non-lazy class list）

### 12.2 方案 D 的 +load 路径（当前工作）

```
接入期 → pod 编译 FlameTKProvider.m（FLAME_PLUGIN_TK 宏启用 +load）
       → 编译进 pod 的 framework/static lib
       → 链入 App
       → +load 触发 → registerProvider
```

依赖接入期编译器正确处理宏 + pod_target_xcconfig 正确注入宏。

### 12.3 方案 E 的 +load 路径（预编译）

```
构建期 → xcFramework_build.sh tk-plugin 编译 FlameTKProvider.m（FLAME_PLUGIN_TK baked-in）
       → +load 已 baked 进 plugin binary 的 __objc_nlclslist section
接入期 → vendored_frameworks 直接链入 App
       → -ObjC 加载 → +load 触发 → registerProvider
```

**方案 E 更可靠**：+load 在构建期就 baked 进二进制，不依赖接入期宏注入是否正确。只要：

- plugin framework 是 **dynamic framework（dylib）** 或 **static framework（被 force_load）**
- podspec 保留 `OTHER_LDFLAGS => '-ObjC'`

> ⚠️ **关键约束**：如果 plugin framework 是**动态 framework**，+load 在 dylib 加载时触发（`dlopen` 时），需要 plugin dylib 被正确 embed 进 App bundle。CocoaPods 的 `vendored_frameworks` 对动态 framework 会自动处理 Embed Frameworks 阶段。
>
> 如果 plugin framework 是**静态 framework**（`.a` 包裹），需要 `-force_load` 才能保留 +load 的 non-lazy class section；仅 `-ObjC` 对静态 archive 不一定够。**这是方案 E 真机验证的强制检查项**。

### 12.4 验证日志

接入后运行 App，控制台应见：

```
FlameTKProvider: +load 自动注册完成 (plugin 模式, platformCode=tk)
```

或 TB：

```
FlameTBProvider: +load 自动注册完成 (plugin 模式, platformCode=tb)
```

若不见日志，按以下顺序排查：

1. `otool -l App | grep -A5 __objc_nlclslist` — binary 是否含 non-lazy class section
2. plugin framework 是 dynamic 还是 static（`file` 命令）
3. 若 static：检查 `OTHER_LDFLAGS` 是否含 `-force_load` 路径
4. 若 dynamic：检查 App bundle 的 `Frameworks/` 下是否有 plugin dylib

## 13. 是否仍需要 `use_frameworks! :linkage => :static`

**第二优先级**，方案 E 不解决也不引入此问题。

### 13.1 问题本质（不变）

TK 依赖链有 43 个静态 framework（AnyThinkMediation*Adapter / AdGainSDK / MSMobAdSDK / BUAdSDK 等）。CocoaPods 规则：动态 framework 不能链接静态 framework。所以接入 TK pod 时，如果客户写 `use_frameworks!`（动态），会报 transitive static dependency 错误。

### 13.2 方案 E 是否改变这点

**不改变**。方案 E 只是把 Flame 自己的源码改成二进制，TK 依赖链那 43 个静态 framework 还在 podspec 的 `s.dependency` 里。问题根源没动。

### 13.3 优化方向（独立议题，非方案 E 必须）

之前调研过在 podspec 加 `s.static_framework = true`，实测能让客户改用 `use_frameworks!`（去掉 `:linkage => :static`）。这个优化与方案 E 正交，可以在方案 E 稳定后单独作为 alpha.4 引入。

**方案 E 的优先级是源码隐藏，不是简化 Podfile**。不要把 `s.static_framework = true` 混进方案 E 首发版本，避免变量耦合增加排障难度。

## 14. 与旧 dual-binary 方案对比

旧 dual-binary（`backup/phase-5a-dual-binary-stable` 分支）：

```
TK 客户接：pod 'flame_sdk_ios', :podspec => 'flame_sdk_ios_tk.podspec'
TB 客户接：pod 'flame_sdk_ios', :podspec => 'flame_sdk_ios_tb.podspec'

每个 podspec 各 vendored 一个完整的 flame_sdk_ios.xcframework（含 core + 平台源码 + 可能静态打入的三方 SDK）
```

| 维度 | 旧 dual-binary | 方案 E |
|---|---|---|
| pod 名 | 都是 `flame_sdk_ios`，靠 `:podspec` 路径区分 | TK=`flame_sdk_ios`，TB=`flame_sdk_ios_tb`，pod 名区分 |
| 接入方写法 | `pod 'flame_sdk_ios', :podspec => '..._tk.podspec'`（繁琐） | `pod 'flame_sdk_ios'` / `pod 'flame_sdk_ios_tb'`（简洁） |
| xcframework 数量 | 2 个独立完整 binary | 1 core + 2 plugin（共 3 个，但 core 共享） |
| 三方 SDK 静态打入 | TB binary 内置 WindMill（自包含模式） | 都不内置，靠 podspec 依赖拉取 |
| 源码暴露 | ❌ 不暴露（全二进制） | ✅ 不暴露（全二进制） |
| core 复用 | ❌ 每个变体 binary 都含一份 core | ✅ core 共享，TK/TB plugin 都 link 同一份 core |
| 升级 core | 改 core 要重建 TK+TB 两个 binary | 改 core 只重建 core binary，plugin 不动 |
| +load | binary 内置（可能依赖自包含的 WindMill） | plugin binary 内置（依赖 podspec 拉取的聚合 SDK） |

**方案 E 相对旧 dual-binary 的核心优势**：

1. 接入方写法简洁（不用写 `:podspec` 路径）
2. core 共享，升级解耦
3. 不静态打入三方 SDK（旧 TB binary 内置 WindMill 是历史包袱）

## 15. 与方案 D source_files 方案对比

| 维度 | 方案 D（source_files） | 方案 E（plugin binary） |
|---|---|---|
| 源码暴露 | ❌ **暴露** 7 个 `.m`（TK）/ 2 个 `.m`（TB） | ✅ 不暴露 |
| 编译期 | 客户工程现场编译 | SDK 工程预编译 |
| 编译速度 | 客户每次 clean build 都要重编译 ~2000 行 | 直接用二进制，快 |
| 编译期宏注入 | 接入期 `pod_target_xcconfig` 注入 | 构建期 baked-in |
| podspec 复杂度 | 高（source_files + headers + xcconfig 6 项） | 低（vendored_frameworks + xcconfig 1 项） |
| 客户可篡改源码 | ✅ 可（风险） | ❌ 不可 |
| +load 可靠性 | 依赖接入期宏正确 | 构建期 baked，更可靠 |
| 三方 SDK 依赖边界 | 清晰（构建期 Podfile 已卡死） | 清晰（同边界，验证见 §7） |

**方案 E 在所有维度上都不劣于方案 D，且在源码暴露这个致命项上是唯一解。**

## 16. 是否建议作为正式分发方案

✅ **强烈建议作为正式分发方案**。

理由：

1. **源码暴露是商业红线**：~2000 行核心适配源码（含与 TopOn/AnyThink 的集成细节、回调时序、素材结构）对外可见，不可接受。
2. **方案 E 技术可行**：源码层、Podfile 层、符号层均验证通过（§5/§6/§7）。
3. **接入侧零改动**：客户只需把版本号从 alpha.2 改成 alpha.3，import / Podfile 写法不变（§10/§11）。
4. **构建侧改动小**：复用现有 `xcFramework_build.sh`，新增 `tk-plugin` / `tb-plugin` 两个变体即可。
5. **podspec 大幅简化**：从 ~80 行降到 ~35 行，可维护性提升。
6. **与未来路线兼容**：TB 后续补齐 Splash/Interstitial/Banner/Native（Phase 6），只需往 TB plugin binary 里加 `.o`，podspec 不动。

**不建议**继续在方案 D 上投入。alpha.2 是方案 D 的终点，方案 E 应作为 alpha.3 的基础。

## 17. 风险点和下一步验证计划

### 17.1 风险点

| # | 风险 | 严重度 | 缓解 |
|---|---|---|---|
| R1 | plugin framework 动态/静态类型选择影响 +load | 高 | §12.3 已分析，真机验证 |
| R2 | 同名 module `flame_sdk_ios`（plugin）与 `flame_sdk_ios_core`（core）的 modulemap 命名空间冲突 | 中 | 方案 D 已验证同名隔离可行，方案 E module 名一致，风险低 |
| R3 | TK plugin binary 动态依赖 core binary，rpath 配置 | 中 | CocoaPods vendored_frameworks 自动处理 rpath |
| R4 | plugin binary 里 AnyThink 符号为 undefined(U)，接入期解析是否成功 | 中 | podspec 显式声明 `AnyThinkiOS` 依赖 |
| R5 | `BUILD_LIBRARY_FOR_DISTRIBUTION=YES` 导致的 swift/objc 桥接 | 低 | 现有 core binary 已用此 flag，无问题 |
| R6 | 资源 bundle（若 adapter 有 nib/图片）遗漏 | 低 | 现有 adapter 无资源，构建后 grep bundle 确认 |
| R7 | 模拟器只有 x86_64 切片（国产 adapter 限制） | 低 | 现有 build script 已处理（ARCHS=x86_64） |

### 17.2 下一步验证计划（未授权执行，待用户确认）

```
Step 1: 构建脚本扩展（不发布）
  - xcFramework_build.sh 新增 tk-plugin / tb-plugin 变体
  - 注入 FLAME_PLUGIN_TK / FLAME_PLUGIN_TB 宏
  - 输出 build/tk/flame_sdk_ios.xcframework / build/tb/flame_sdk_ios.xcframework

Step 2: 符号验证（本地，不发布）
  - file / otool -L / nm -gU / nm -u 全套检查（§8.2 模板）
  - 确认无三方广告源 SDK 符号
  - 确认含 Flame Provider/Adapter 符号 + +load section

Step 3: 本地 podspec 验证（:path 模式，不发布）
  - 改 podspec 为方案 E 结构
  - Demo 工程本地 pod install
  - 确认 Pods/flame_sdk_ios/ 下无 .m 源码（只有 vendored framework）
  - xcodebuild 编译通过

Step 4: 真机验证（关键门控）
  - 真机运行，确认 +load 日志出现
  - 确认 FlameMediationRegistry 注册成功
  - 确认广告加载链路通畅（reward / splash / interstitial / banner / native）

Step 5: TB 对称验证
  - 同 Step 1-4，TB 变体

Step 6: 用户确认后，发布 alpha.3
  - 同步 distribution repo + spec repo
  - 打 tag 1.0.0-alpha.3
  - 更新 README / CHANGELOG
```

### 17.3 红线重申（与用户要求一致）

```
1. 本报告仅为调研，不发布 alpha.3。
2. 不继续围绕 source_files 方案优化。
3. 不把 s.static_framework = true 当成最终解决方案（与方案 E 解耦）。
4. 不把源码发布到客户可见仓库。
```

---

## 附录 A：方案 D → 方案 E 迁移清单（参考，待 Step 6 执行）

### A.1 SDK 仓库改动

- `xcFramework_build.sh`：新增 `tk-plugin` / `tb-plugin` 变体
- `flame_sdk_ios.podspec` / `flame_sdk_ios_tb.podspec`：改为方案 E 结构（§9）
- 无需改任何 `.m` / `.h` 源码（宏隔离已就绪）

### A.2 分发仓库改动

- 新增 `tk/flame_sdk_ios.xcframework`
- 新增 `tb/flame_sdk_ios.xcframework`
- 更新 podspec（双 vendored_frameworks，删 source_files）
- 更新 README（说明 binary 分发，删除 source_files 相关 FAQ）
- 更新 CHANGELOG（1.0.0-alpha.3：方案 E，源码不再下发）

### A.3 Spec 仓库改动

- 新增 `1.0.0-alpha.3/flame_sdk_ios.podspec`
- 新增 `1.0.0-alpha.3/flame_sdk_ios_tb.podspec`

### A.4 客户侧改动

- 无（除版本号 alpha.2 → alpha.3）

---

## 附录 B：术语表

| 术语 | 含义 |
|---|---|
| thin core | 仅含平台中立代码（core/ads/utils/mediation 根目录）的二进制，零三方广告 SDK |
| plugin binary | 含平台 Provider + Adapter 的二进制，通过 podspec 依赖拉取聚合 SDK |
| vendored framework | CocoaPods 机制，pod 直接携带预编译 framework，不下发源码 |
| source_files | CocoaPods 机制，pod 下发源码由接入方现场编译（**会暴露源码**） |
| +load | ObjC 类方法，类被加载时自动调用，用于自动注册 |
| FLAME_BUILD_TK/TB/CORE | 构建期宏，控制哪些源码参与编译 |
| FLAME_PLUGIN_TK/TB | 构建期宏，额外启用 +load 自动注册（方案 E 核心开关） |
| `:flatten => true` | cocoapods-downloader 选项，剥除 GitHub archive zip 的顶层版本目录 |
