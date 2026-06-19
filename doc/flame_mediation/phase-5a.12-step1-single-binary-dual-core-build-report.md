# Phase 5A.12 Step 1 阶段报告：单二进制构建 + Demo 验证

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

> **方案**：Single Binary with TK/TB Platform Code Embedded
> **阶段**：单二进制构建就绪 + Demo TK/TB 双双 BUILD SUCCEEDED
> **执行日期**：2026-06-19
> **执行环境**：macOS Darwin 25.4.0 arm64 + Xcode + CocoaPods 1.16.2

---

## 核心结论速览

- ✅ **单二进制构建成功**：`build/flame_sdk_ios.xcframework`（300K，MH_DYLIB，含 TK/TB 两侧平台代码）
- ✅ **符号纯净性 0 污染**：0 个三方广告源 SDK 静态符号、0 个 ToBid/WindMill 实现符号
- ✅ **0 源码泄漏**：xcframework 内无任何 `.m`/`.mm`
- ✅ **Demo TK 验证通过**：Mode C 真机 BUILD SUCCEEDED，双 +load 符号在位
- ✅ **Demo TB 验证通过**：Mode C 真机 BUILD SUCCEEDED，双 +load 符号在位
- ⚠️ **单二进制方案代价**：TB 客户必须接入 AnyThinkSDK（3.5 MB），因为 binary 显式动态依赖
- 所有红线遵守：未发布、未 push、未 tag 远程、未 pod repo push

---

## 1. 当前分支 / HEAD

| 项目 | 值 |
|---|---|
| 分支 | `research/thin-core-binary` |
| HEAD | `3489d1278f6f19bd64b6adb91261251d90f62191`（未变）|
| 远程 | `origin = https://gitee.com/toowe-admin/flame_ios_sdk.git`（gitee，非 javaice007 GitHub）|
| 工作区状态 | 修改：Podfile / xcFramework_build.sh / flame_sdk_ios.podspec / flame_sdk_ios_tb.podspec / flame_sdk_ios.xcodeproj/project.pbxproj / flame_sdk_ios/core/FlameSdk.m；新增：research/ 与 doc/flame_mediation/phase-5a.12-* |

## 2. 是否未 push / 未 tag / 未发布

| 检查项 | 结果 |
|---|---|
| `git push origin` | ❌ 未执行 |
| 远程 tag（alpha.3 / alpha.4 / alpha.4-local）| ❌ 不存在 |
| GitHub release | ❌ 未创建 |
| `pod repo push`（javaice007-flame-specs）| ❌ 未执行 |
| 本地 dist repo tag `1.0.0-alpha.4-local` | ✅ 存在（`research/local_dist/single_binary`，0 remotes 配置）|
| 本地 spec repo commit | ✅ 存在（`research/local_specs/flame-specs`，本地 git，未 push 远程）|

## 3. 是否暂停 Phase 5A.11 Step 3

✅ **已暂停**。Phase 5A.11 Step 3 已完成本地模拟远程 spec/tag 集成验证（TK/TB Mode A+C 双通过），不发布 alpha.3。

Phase 5A.11 三包方案报告全部保留：

```
doc/flame_mediation/Phase_5A.11_方案E_二进制插件分发调研报告.md
doc/flame_mediation/phase-5a.11-step1-tk-plugin-binary-validation-report.md
doc/flame_mediation/phase-5a.11-step2-tb-plugin-and-release-build-report.md
doc/flame_mediation/phase-5a.11-step3-local-spec-integration-validation-report.md
```

## 4. 是否保留三包方案报告

✅ **全部保留**。三包产物也保留：

```
build/flame_sdk_ios_core.xcframework  （Phase 5A.10/5A.11）
build/tk/flame_sdk_ios.xcframework    （Phase 5A.11）
build/tb/flame_sdk_ios.xcframework    （Phase 5A.11）
build/flame_sdk_ios.xcframework       （Phase 5A.12 单二进制，新）
```

`./xcFramework_build.sh release` 仍可构建三包；`./xcFramework_build.sh single-binary` 构建单包。两者完全独立。

## 5. single-binary / nosdk 构建命令

```bash
./xcFramework_build.sh single-binary
# 等价别名：
./xcFramework_build.sh nosdk
```

输出路径：`build/flame_sdk_ios.xcframework`（build/ 顶层，无子目录，与 core-named 风格一致）

构建逻辑要点：
- **宏注入**：`FLAME_BUILD_TK=1 FLAME_BUILD_TB=1 FLAME_PLUGIN_TK=1 FLAME_PLUGIN_TB=1`
- **不做 EXCLUDED_SOURCE_FILE_NAMES**（与 tk-plugin/tb-plugin 相反，单包要全部源码）
- **不做 `-framework flame_sdk_ios_core`**（core 代码直接编进同一 Mach-O）
- **ToBid 静态归档隔离**（复用 tb-plugin 的 xcconfig patch + 临时隐藏归档二进制逻辑）
- **中间 xcarchive 清理**：`./Archives/single_binary/`（独立目录，与 core_named 互不干扰）

## 6. 输出路径

```
build/flame_sdk_ios.xcframework/
├── Info.plist
├── ios-arm64/
│   └── flame_sdk_ios.framework/
│       ├── flame_sdk_ios              （binary，300K）
│       ├── Info.plist
│       ├── Modules/
│       │   └── module.modulemap       （framework module flame_sdk_ios { umbrella header ... }）
│       └── Headers/                   （10 个公共 API：FlameSdk.h + flame_sdk_ios.h + 8 个广告类型头）
└── ios-x86_64-simulator/
    └── flame_sdk_ios.framework/
        └── （同上结构）
```

## 7. 二进制体积

| 切片 | 大小 |
|---|---|
| `ios-arm64/flame_sdk_ios.framework/flame_sdk_ios` | **300K** |
| `ios-x86_64-simulator/flame_sdk_ios.framework/flame_sdk_ios` | ~300K（universal）|

**对比三包方案**：
- 三包总量：core 176K + tk plugin 172K + tb plugin 76K = **424K**
- 单包：**300K**（少了 124K，因为不重复 core 代码）

## 8. otool -L 结果

```
build/flame_sdk_ios.xcframework/ios-arm64/flame_sdk_ios.framework/flame_sdk_ios:
	@rpath/flame_sdk_ios.framework/flame_sdk_ios      ← 自身
	/usr/lib/libobjc.A.dylib
	/usr/lib/libc++.1.dylib
	/usr/lib/libresolv.9.dylib
	/usr/lib/libsqlite3.dylib
	/usr/lib/libxml2.2.dylib
	/usr/lib/libz.1.dylib
	/System/Library/Frameworks/AVFoundation.framework/AVFoundation
	... （系统框架）
	@rpath/AnyThinkSDK.framework/AnyThinkSDK           ← TK 动态依赖（MH_DYLIB，无法静态合并）
	... （更多系统框架）
	@rpath/OpenSSL.framework/OpenSSL                    ← core 加密依赖
	... （其余系统框架）
```

**关键**：
- ✅ 无 `flame_sdk_ios_core.framework`（core 代码已编进同一 Mach-O）
- ✅ 无 `WindMill` / `WindSDK` / `WindFoundation` 动态依赖（静态归档已隔离）
- ✅ AnyThinkSDK 是预期动态依赖（MH_DYLIB，运行期由消费方提供）

## 9. TK Provider / Adapter 符号是否在位

✅ **全部在位**：

| 符号 | 数量 |
|---|---|
| `_OBJC_CLASS_$_FlameTKProvider` | 1 |
| `_OBJC_CLASS_$_AtRewardAdapter` | 1 |
| `_OBJC_CLASS_$_AtSplashAdapter` | 1 |
| `_OBJC_CLASS_$_AtInterstitialAdapter` | 1 |
| `_OBJC_CLASS_$_AtBannerAdapter` | 1 |
| `_OBJC_CLASS_$_AtNativeAdapter` | 1 |
| `_OBJC_CLASS_$_AtNativeSelfRenderView` | 1 |

## 10. TB Provider / Adapter 符号是否在位

✅ **全部在位**：

| 符号 | 数量 |
|---|---|
| `_OBJC_CLASS_$_FlameTBProvider` | 1 |
| `_OBJC_CLASS_$_TbRewardAdapter` | 1 |

## 11. TK 核心是否内置或随二进制可用

**部分内置**：
- ✅ **Flame 自己的 TK 胶水代码已内置**（FlameTKProvider + 6 At*Adapter/View，编译进同一 Mach-O）
- ❌ **AnyThinkSDK 平台核心未内置**（MH_DYLIB 动态库，技术上无法静态合并）
- 运行期：AnyThinkSDK 由 flame_sdk_ios.podspec dependency 提供（`s.dependency 'AnyThinkiOS', '6.5.71'`）

**实证**：
- `otool -L` 显示 `@rpath/AnyThinkSDK.framework/AnyThinkSDK`
- `nm -u` 显示 6 个 AT* 未定义引用（运行期由 AnyThinkiOS 提供）

## 12. TB 核心是否内置或随二进制可用

**部分内置**：
- ✅ **Flame 自己的 TB 胶水代码已内置**（FlameTBProvider + TbRewardAdapter，编译进同一 Mach-O）
- ❌ **WindMillSDK 平台核心未内置**（静态归档，技术上可链接但选择不链接以避免污染）
- 运行期：ToBid-iOS-RC 由 flame_sdk_ios_tb.podspec dependency 提供（`s.dependency 'ToBid-iOS-RC', '5.5.6'`）

**实证**：
- `otool -L` 无 WindMill 动态依赖（静态归档已隔离）
- `nm -u` 显示 3 个 WindMill 未定义引用（运行期由 ToBid-iOS-RC pod 提供）
- WindMill 在接入期作为静态 archive 合并进消费方 app binary（CocoaPods 默认行为）

## 13. 广告源适配器是否未打入

✅ **全部未打入**：

| 检查项 | 结果 |
|---|---|
| 三方广告源 SDK 静态符号（AdGain/BU/CSJ/Baidu/GDT/KS/FS/Sigmob）| **0** |
| ToBid/WindMill 实现符号（WindMillSDK/WindMillAds/WindFoundation）| **0** |

广告源 SDK 与 Adapter 通过 podspec dependency 在接入期由消费方提供。

## 14. .m / .mm 是否未暴露

✅ **0 泄漏**：

```bash
find build/flame_sdk_ios.xcframework \( -name "*.m" -o -name "*.mm" \) -print
# （无输出）
```

Headers/ 只含 10 个公共 API（FlameSdk.h、flame_sdk_ios.h、FlameCallback.h、FlameSplashAd.h、FlameRewardAd.h、FlameInterstitialAd.h、FlameBannerAd.h、FlameBannerAdMaterial.h、FlameBannerAdRenderSlots.h、FlameNativeAd.h）。

## 15. 两个 podspec 草案

### 15.1 flame_sdk_ios.podspec（TK 侧）

```ruby
Pod::Spec.new do |s|
  s.name             = 'flame_sdk_ios'
  s.version          = '1.0.0-alpha.4-local'
  s.module_name      = 'flame_sdk_ios'
  s.vendored_frameworks = 'flame_sdk_ios.xcframework'

  s.dependency 'OpenSSL-Universal', '~> 3.6'
  s.dependency 'AnyThinkiOS', '6.5.71'
  s.dependency 'AnyThinkMediationAdxSmartdigimktCNAdapter', '6.5.72.2.1'
  # ... 共 11 个 AnyThinkMediation*Adapter
  s.dependency 'AdGainSDK', '4.2.7.1'
  s.dependency 'AdGainSDKTakuAdapter', '4.2.7.1'
  s.dependency 'FSUnionAdSDK', '1.0.8.0'

  s.pod_target_xcconfig = { 'OTHER_LDFLAGS' => '$(inherited) -ObjC' }
  s.user_target_xcconfig = { 'OTHER_LDFLAGS' => '$(inherited) -ObjC' }
end
```

### 15.2 flame_sdk_ios_tb.podspec（TB 侧）

```ruby
Pod::Spec.new do |s|
  s.name             = 'flame_sdk_ios_tb'
  s.version          = '1.0.0-alpha.4-local'
  s.module_name      = 'flame_sdk_ios'           # 与 TK 一致（接入方 import 不变）
  s.vendored_frameworks = 'flame_sdk_ios.xcframework'   # 同一份单二进制

  s.dependency 'OpenSSL-Universal', '~> 3.6'
  s.dependency 'AnyThinkiOS', '6.5.71'           # ⚠️ 必须声明（见 §6）
  s.dependency 'ToBid-iOS-RC', '5.5.6'

  s.pod_target_xcconfig = { 'OTHER_LDFLAGS' => '$(inherited) -ObjC' }
  s.user_target_xcconfig = { 'OTHER_LDFLAGS' => '$(inherited) -ObjC' }
end
```

文件路径：
- `research/local_dist/single_binary/flame_sdk_ios.podspec`
- `research/local_dist/single_binary/flame_sdk_ios_tb.podspec`
- 同时备份在 `research/podspecs/single_binary/`（用 `:podspec =>` 接入的备用方案）

## 16. TK podspec 依赖树

Podfile.lock 实证（Demo TK Mode C 接入后）：

```
flame_sdk_ios (1.0.0-alpha.4-local):
  - AnyThinkiOS (= 6.5.71)
  - AnyThinkMediationAdxSmartdigimktCNAdapter (= 6.5.72.2.1)
  - AnyThinkMediationBaiduAdapter (= 10.050.2.1)
  - AnyThinkMediationBeiZiAdapter (= 5.5.0.3.2.0)
  - AnyThinkMediationFunlinkAdapter (= 2.9.0.1.2.2.0)
  - AnyThinkMediationGDTAdapter (= 4.15.90.2.0)
  - AnyThinkMediationGromoreAdapter (= 7.6.0.4.2.0)
  - AnyThinkMediationKuaiShouAdapter (= 5.4.10.1.2.0)
  - AnyThinkMediationMSAdapter (= 2.7.18.1.2.0)
  - AnyThinkMediationSigmobAdapter (= 4.20.12.2.0)
  - AnyThinkMediationTTAdapter_Mix (= 7.6.0.4.2.0)
  - AnyThinkMediationZYAdapter (= 2.6.4.29.2.0)
  - OpenSSL-Universal (~> 3.6)
```

**总共 28 pods**（含传递依赖：BaiduMobAdSDK、BeiZiSDK、GDTMobSDK、KSAdSDK、MSMobAdSDK、SigmobAd-iOS、SmartdigimktCNSDK、AdGainSDK、AdGainSDKTakuAdapter、FSUnionAdSDK、BUTTSDKFramework、OctopusSDK、OpenSSL-Universal、AnyThinkiOS、AnyThinkMediation*Adapter、flame_sdk_ios、FunlinkSDK）

**红线达成**：不依赖 ToBid / WindMill。

## 17. TB podspec 依赖树

Podfile.lock 实证（Demo TB Mode C 接入后）：

```
flame_sdk_ios_tb (1.0.0-alpha.4-local):
  - AnyThinkiOS (= 6.5.71)           # 必须声明（binary 显式动态依赖）
  - OpenSSL-Universal (~> 3.6)
  - ToBid-iOS-RC (= 5.5.6)
```

**总共 5 pods**（OpenSSL-Universal、AnyThinkiOS、ToBid-iOS-RC、FunlinkSDK、flame_sdk_ios_tb）

**红线达成**：不依赖 AnyThinkMediation* / AdGain / FSUnion / CSJ / GDT / KS / Baidu / Sigmob。

## 18. Provider +load 是否安全

✅ **全部安全**：

| 检查项 | 结果 |
|---|---|
| `+[FlameTKProvider load]` 符号 | ✅ 存在（1 个）|
| `+[FlameTBProvider load]` 符号 | ✅ 存在（1 个）|
| +load 函数体引用三方 SDK | ✅ **0**（只调 registerProvider: + 日志）|
| AnyThink 初始化位置 | ✅ `initializeWithAppId:appKey:callback:`（延迟调用）|
| WindMill 初始化位置 | ✅ `initializeWithAppId:appKey:callback:`（延迟调用）|
| platformCode 返回值 | ✅ 静态字符串常量（@"tk" / @"tb"），不依赖三方 SDK |

### 18.1 +load 函数体（实证）

```objc
// FlameTKProvider.m
+ (void)load {
    @autoreleasepool {
        FlameTKProvider *provider = [[FlameTKProvider alloc] init];
        [[FlameMediationRegistry sharedRegistry] registerProvider:provider];
        [FlameLogger i:[NSString stringWithFormat:@"FlameTKProvider: +load 自动注册完成..."]];
    }
}

// FlameTBProvider.m
+ (void)load {
    @autoreleasepool {
        FlameTBProvider *provider = [[FlameTBProvider alloc] init];
        [[FlameMediationRegistry sharedRegistry] registerProvider:provider];
        [FlameLogger i:[NSString stringWithFormat:@"FlameTBProvider: +load 自动注册完成..."]];
    }
}
```

**关键**：
- +load 只调 `registerProvider:`（NSMutableDictionary 字典写入 + 日志）
- 不调用 `[ATAPI sharedInstance]` / `[WindMillAds setupSDKWithAppId:]` 等三方 SDK API
- 三方 SDK 初始化在 `initializeWithAppId:` 内（Router 激活后才调用）
- 即使 TK podspec 不带 ToBid / TB podspec 不带 AnyThinkiOS，+load 也不会崩溃

### 18.2 单二进制模式下的 registerAllProvidersIfNeeded 跳过

FlameSdk.m 在 `FLAME_BUILD_TK + FLAME_BUILD_TB` 同时定义时跳过内部 Provider 实例化：

```objc
+ (void)registerAllProvidersIfNeeded {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
#if (defined(FLAME_BUILD_TK) && defined(FLAME_BUILD_TB))
        // 单二进制：跳过，依赖 FlameTKProvider/FlameTBProvider 的 +load 自动注册
        [FlameLogger i:@"FlameSdk: 单二进制模式，Provider 由 +load 自动注册"];
#else
        // （legacy TK-only / TB-only 分支）
#endif
    });
}
```

避免与 +load 重复注册（registerProvider 会覆盖 +load 注册的实例）。

## 19. 是否建议进入 Demo 真机验证

✅ **建议进入 Step 2 真机运行验证**。

### 19.1 Demo 静态验证已通过

| 验证 | TK podspec | TB podspec |
|---|---|---|
| pod install | ✅ 28 pods | ✅ 5 pods |
| Mode C 真机 BUILD SUCCEEDED | ✅ | ✅ |
| flame_sdk_ios.framework 嵌入 `.app/Frameworks/` | ✅ | ✅ |
| `+[FlameTKProvider load]` 符号在嵌入 binary 内 | ✅ | ✅（单二进制同时含）|
| `+[FlameTBProvider load]` 符号在嵌入 binary 内 | ✅（单二进制同时含）| ✅ |
| TK 平台符号在嵌入 binary 内 | ✅ 3 个 | ✅ 2 个（单二进制同时含）|
| TB 平台符号在嵌入 binary 内 | ✅ 2 个（单二进制同时含）| ✅ |

### 19.2 Step 2 真机运行验证项

- [ ] Xcode Run + 真机 + 观察 console 日志
- [ ] 验证 `FlameTKProvider: +load 自动注册完成` 在 TK 模式启动时打印
- [ ] 验证 `FlameTBProvider: +load 自动注册完成` 在 TB 模式启动时打印
- [ ] 验证 `FlameSdk: 单二进制模式，Provider 由 +load 自动注册` 打印
- [ ] TK 模式下：调用 Reward/Splash/Interstitial/Banner/Native 链路，确认 TK 广告正常
- [ ] TB 模式下：调用 Reward 链路，确认 TB 广告正常（800031 后台未绑定错误可接受，不算 SDK 失败）

## 20. 后续双线并存的处理建议

### 20.1 单二进制方案的架构红利

```
单二进制已同时含 TK/TB 代码 → 双线并存无需重新构建
```

只需合并 podspec 依赖：

```ruby
# flame_sdk_ios_dual.podspec（Phase 5A.14 设想）
s.vendored_frameworks = 'flame_sdk_ios.xcframework'   # 同一份

# 同时拉 TK 和 TB 广告源依赖
s.dependency 'OpenSSL-Universal', '~> 3.6'
s.dependency 'AnyThinkiOS', '6.5.71'
s.dependency 'AnyThinkMediation*Adapter', '...'
s.dependency 'AdGainSDK', '4.2.7.1'
s.dependency 'FSUnionAdSDK', '1.0.8.0'
s.dependency 'ToBid-iOS-RC', '5.5.6'
```

### 20.2 双线并存需处理的工程问题

1. **依赖版本冲突**：AnyThinkMediation* 与 ToBid-iOS-RC 是否有共同依赖冲突
2. **duplicate framework**：SigmobAd-iOS 是否被 TK 与 TB 同时依赖（同源 WindSDK）
3. **duplicate symbol**：WindMill 静态归档与 SigmobAd-iOS 的 WindSDK 可能产生符号冲突
4. **static archive 链接顺序**：链接顺序敏感，可能需 `-force_load` 或调整顺序
5. **Router 仍按 pt 激活**：双线并存下两个 Provider 都注册，按服务端 pt 激活对应一个

### 20.3 Phase 5A.14 不在本阶段范围

Phase 5A.12 只验证单 podspec（TK 或 TB 二选一）接入。双线并存留待后续阶段。

## 21. /compact

**Phase 5A.12 Step 1 完成状态汇总**：

| 项 | 状态 |
|---|---|
| 实验现场保护 | ✅ 备份至 `research/backups/phase-5a.11-before-5a.12-*` |
| 单二进制构建命令 | ✅ `./xcFramework_build.sh single-binary`（或 `nosdk`）|
| 单二进制产物 | ✅ `build/flame_sdk_ios.xcframework`（300K）|
| 符号纯净性 | ✅ 0 污染 / 0 源码泄漏 |
| TK 平台 7 符号 | ✅ 全部在位 |
| TB 平台 2 符号 | ✅ 全部在位 |
| +load 安全性 | ✅ 不调三方 SDK，初始化延迟 |
| Demo TK 验证 | ✅ Mode C 真机 BUILD SUCCEEDED |
| Demo TB 验证 | ✅ Mode C 真机 BUILD SUCCEEDED |
| 方案文档 | ✅ `phase-5a.12-single-binary-dual-core-plan.md` |
| 本阶段报告 | ✅ 本文 |
| 发布 / push / tag / pod repo push | ❌ 未执行（红线遵守）|

**Step 2 建议**：真机运行验证 +load 触发 + 广告链路（TK Reward/Splash/Interstitial/Banner/Native，TB Reward）。

**关键文件清单**：

```
doc/flame_mediation/
├── phase-5a.12-single-binary-dual-core-plan.md                # 方案文档
└── phase-5a.12-step1-single-binary-dual-core-build-report.md  # 本报告

research/
├── backups/                                                    # Phase 5A.11 备份
│   ├── phase-5a.11-before-5a.12-status.txt
│   ├── phase-5a.11-before-5a.12.diff
│   └── phase-5a.11-before-5a.12-all-files.txt
├── podspecs/single_binary/                                    # :podspec 备用 podspec
│   ├── flame_sdk_ios.single_binary.local.podspec
│   └── flame_sdk_ios_tb.single_binary.local.podspec
├── local_dist/
│   ├── single_binary/                                          # 本地 dist repo（git tag 1.0.0-alpha.4-local）
│   │   ├── flame_sdk_ios.xcframework
│   │   ├── flame_sdk_ios.podspec
│   │   └── flame_sdk_ios_tb.podspec
│   └── logs/                                                   # 构建与验证日志
│       ├── single-binary-build-2.log
│       ├── single-binary-symbol-check.log
│       ├── single-binary-load-safety.log
│       ├── single-binary-tk-device-build.log
│       ├── single-binary-tk-embed-check.log
│       ├── single-binary-tb-device-build.log
│       └── single-binary-tb-embed-check.log
└── local_specs/flame-specs/                                    # 本地 spec repo
    ├── flame_sdk_ios/1.0.0-alpha.4-local/flame_sdk_ios.podspec
    └── flame_sdk_ios_tb/1.0.0-alpha.4-local/flame_sdk_ios_tb.podspec

build/
└── flame_sdk_ios.xcframework                                   # 单二进制产物（300K）

# 代码改动（未 commit）
flame_sdk_ios/core/FlameSdk.m                                   # 解除 TK/TB 互斥 #error + 单包 registerAll 分支
Podfile                                                          # 新增 single-binary 变体
xcFramework_build.sh                                            # 新增 single-binary 构建逻辑
```

**Step 1 完成，等待 Step 2 真机验证指令。**
