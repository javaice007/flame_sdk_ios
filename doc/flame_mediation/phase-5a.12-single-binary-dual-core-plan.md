# Phase 5A.12 方案：单二进制包 + TK/TB 平台代码同 Mach-O 内置

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

> **版本**：v1.0
> **创建**：2026-06-19
> **状态**：方案已设计 + 构建已验证（Step 1 通过）
> **前置阶段**：Phase 5A.11 三包方案（Scheme E）暂停（不发布 alpha.3）

---

## 1. 为什么暂停三包方案

Phase 5A.11 三包方案（Scheme E）技术上完整，已通过 Step 3 本地模拟远程 spec/tag 集成验证（TK/TB 在 Mode A + Mode C 下双双 BUILD SUCCEEDED），但存在**架构选择层面的取舍**：

| 维度 | 三包方案（Scheme E） | 单二进制方案（Phase 5A.12） |
|---|---|---|
| 二进制数量 | 3（core + tk-plugin + tb-plugin）| 1（同时含 TK/TB 平台代码）|
| 客户接入复杂度 | vendored_frameworks 列 2 个 | vendored_frameworks 列 1 个 |
| 双线并存 | 需要构建 4 包（core + tk + tb + dual）| 只需调整 podspec 依赖（无需新二进制）|
| TB 客户额外负担 | 0（plugin 不显式链接 AnyThink）| 3.5 MB（binary 显式链接 AnyThinkSDK）|
| 二进制分发运维 | 3 个产物路径，3 套校验 | 1 个产物路径，1 套校验 |

**决策**：Phase 5A.11 暂停（产物 + 报告保留），转入 Phase 5A.12 单二进制方案。

---

## 2. 新的单二进制目标

```
build/flame_sdk_ios.xcframework  （唯一对外二进制）
```

该二进制**一个 Mach-O 同时内置**：

1. Flame SDK 自有核心代码（core/ads/utils）
2. FlameMediationRegistry / FlameMediationRouter / AdapterManager 公共路由层
3. FlameTKProvider + AtRewardAdapter + AtSplashAdapter + AtInterstitialAdapter + AtBannerAdapter + AtNativeAdapter + AtNativeSelfRenderView
4. FlameTBProvider + TbRewardAdapter

该二进制**不内置**：

1. TK 平台核心 SDK（AnyThinkSDK 动态库）
2. TB 平台核心 SDK（ToBid / WindMillSDK / WindSDK / WindFoundation）
3. 任何广告源 SDK 与 Adapter（CSJ/GDT/KS/Baidu/Sigmob/AdGain/FSUnion 等）
4. 任何 `.m` / `.mm` 源码

**重要**：Phase 5A.12 的「单二进制包」**不是「自包含一切」**，而是「单 Mach-O 内置 Flame 自己的全部代码（含 TK/TB 两侧 Provider/Adapter 胶水），平台核心 + 广告源 SDK 仍由 podspec dependency 在接入期提供」。

---

## 3. nosdk 语义重定义

Phase 5A.12 的 `nosdk` 变体（`./xcFramework_build.sh nosdk`，等同于 `single-binary`）**不是「不带 TK/TB 平台核心」**，而是：

```
不带具体广告源 SDK / 广告源 Adapter SDK
但内置 TK/TB 平台 Provider/Adapter 胶水代码
```

即：单二进制同时含 TK 和 TB 的 Flame 胶水代码（Provider + Adapter），但**不打包** AnyThinkSDK / WindMillSDK / 任何广告源 SDK。

后续文档统一使用 **single-binary** 表述，避免与 Phase 5A.10 之前的 nosdk（旧 TK 自包含）混淆。

---

## 4. TK/TB 平台核心形态实证（决定「内置」边界的关键）

### 4.1 TK 平台核心（AnyThinkiOS 6.5.71）

| 检查项 | 实证 |
|---|---|
| podspec `static_framework` | 显式 `false` |
| AnyThinkSDK.framework 形态 | `Mach-O 64-bit dynamically linked shared library`（MH_DYLIB）|
| 大小 | 3.5 MB（arm64 切片）|
| 是否含广告源 Adapter | ❌ 不含（podspec 只有 AnyThinkSDK 一个子规范，无任何 dependency）|

**结论**：AnyThinkSDK 是真动态库，**技术上不可能合并进 flame binary**（MH_DYLIB 无法静态链接）。运行期必须由消费方提供。

### 4.2 TB 平台核心（ToBid-iOS-RC 5.5.6）

| 检查项 | 实证 |
|---|---|
| podspec `static_framework` | 字段缺省（默认 false，但实物实为静态归档）|
| WindMillSDK.framework 形态 | `current ar archive`（静态归档伪装成 framework）|
| WindSDK / WindFoundation 形态 | 同上（均 `current ar archive`）|
| WindMillSDK 大小 | 9.4 MB（arm64 切片）|
| 是否含广告源 Adapter | ❌ 不含（默认子规范 `ToBidSDK` 仅 vendored `Core/*.xcframework`，21 个广告源 Adapter 都是独立子规范）|

**结论**：WindMillSDK/WindSDK/WindFoundation 是静态归档，技术上**可以**链接进 flame binary，但会触发三包方案已识别的红线（`-ObjC` 在 archive 期自动加载 3000+ 符号导致 9.4 MB 污染 + 接入期 duplicate symbol）。**Phase 5A.12 选择不内置**，作为 podspec dependency 运行期由消费方提供。

### 4.3 单二进制方案对「内置」的精确定义

```
「内置 TK/TB 核心」= flame binary 内置 Flame 自己的 Provider/Adapter 胶水代码
                    （FlameTKProvider/At*Adapter + FlameTBProvider/TbRewardAdapter）
                    
不等于「内置 AnyThinkSDK / WindMillSDK 平台核心」
       （这些作为 podspec dependency 运行期由消费方提供）
```

---

## 5. 两个 podspec 的正确职责

两个 podspec 都引用**同一个 vendored xcframework**：

```ruby
s.vendored_frameworks = 'flame_sdk_ios.xcframework'
```

差异**只在广告源适配器依赖**：

### 5.1 flame_sdk_ios.podspec（TK 客户）

```ruby
s.name             = 'flame_sdk_ios'
s.module_name      = 'flame_sdk_ios'
s.vendored_frameworks = 'flame_sdk_ios.xcframework'

# TK 广告源依赖
s.dependency 'OpenSSL-Universal', '~> 3.6'           # core binary 动态依赖
s.dependency 'AnyThinkiOS', '6.5.71'                  # binary 动态依赖 + TK 聚合核心
s.dependency 'AnyThinkMediation*Adapter', '...'       # 11 个 TK Mediation Adapter
s.dependency 'AdGainSDK', '4.2.7.1'                   # AdGain 广告 SDK + 适配器
s.dependency 'FSUnionAdSDK', '1.0.8.0'                # 飞梭

# 不依赖 ToBid-iOS-RC（TB 广告源依赖不在此 podspec）
```

### 5.2 flame_sdk_ios_tb.podspec（TB 客户）

```ruby
s.name             = 'flame_sdk_ios_tb'
s.module_name      = 'flame_sdk_ios'                  # module 名保持 flame_sdk_ios（接入方 import 不变）
s.vendored_frameworks = 'flame_sdk_ios.xcframework'   # 同一份单二进制

# TB 广告源依赖
s.dependency 'OpenSSL-Universal', '~> 3.6'
s.dependency 'AnyThinkiOS', '6.5.71'                  # ⚠️ 必须声明（见 §6）
s.dependency 'ToBid-iOS-RC', '5.5.6'                  # TB 聚合核心（WindMillSDK 静态归档）

# 不依赖 AnyThinkMediation* / AdGain / FSUnion（TK 广告源适配器不在此 podspec）
```

---

## 6. ⚠️ 单二进制方案的核心代价：TB 客户必须接入 AnyThinkiOS

这是单二进制方案对比三包方案的**唯一显著代价**：

### 6.1 原因

单二进制 otool -L 显示：

```
@rpath/flame_sdk_ios.framework/flame_sdk_ios
@rpath/AnyThinkSDK.framework/AnyThinkSDK    ← LC_LOAD_DYLIB 显式动态依赖
@rpath/OpenSSL.framework/OpenSSL
```

AnyThinkSDK 出现在 `LC_LOAD_DYLIB`（不是 `LC_LINKER_OPTION` 也不是 U 引用 dynamic_lookup），因为构建期 `flame_sdk_ios_core.xcframework` 的 TK 代码（AtRewardAdapter 等）`#import <AnyThinkSDK/AnyThinkSDK.h>` 后，链接器把 AnyThinkSDK 当作 framework 显式链接（`-framework AnyThinkSDK`）。

### 6.2 后果

dyld 在加载 `flame_sdk_ios.framework` 时**必须**能找到 `@rpath/AnyThinkSDK.framework`，否则启动崩溃。**即使 pt=tb 永远不调用 TK 代码**，dyld 也会因为找不到 AnyThinkSDK 而崩溃。

### 6.3 对比三包方案

| 方案 | TB 客户接入 AnyThinkSDK | TB 客户额外体积 |
|---|---|---|
| 三包方案（Scheme E） | ❌ 不需要（tb-plugin binary 不显式链接 AnyThink）| 0 MB |
| 单二进制方案（Phase 5A.12）| ✅ 必须接入 | 3.5 MB（AnyThinkSDK dylib）|

### 6.4 对比 WindMill（为何不要求 TK 客户接入 ToBid）

WindMill 是 U 引用（dynamic_lookup），不在 otool -L 的 LC_LOAD_DYLIB 里：

```
nm -u flame_sdk_ios | grep WindMill
  _OBJC_CLASS_$_WindMillRewardVideoAd
  _OBJC_CLASS_$_WindMillRewardInfo
  ...
```

这些 U 引用通过 lazy binding 解析，**只在方法被实际调用时才解析**。pt=tk 永远不会调用 `FlameTBProvider.initializeWithAppId`，所以 WindMill 符号永远不会被解析，**即使 ToBid-iOS-RC 不存在也不会崩溃**。

### 6.5 客户体验结论

| 客户类型 | 需要接入的 pod | 二进制体积 |
|---|---|---|
| TK 客户（flame_sdk_ios）| flame_sdk_ios + AnyThinkiOS + 11 Mediation + AdGain + FSUnion | ~正常（无额外）|
| TB 客户（flame_sdk_ios_tb）| flame_sdk_ios_tb + AnyThinkiOS（必须）+ ToBid-iOS-RC | 多 3.5 MB AnyThinkSDK |

---

## 7. 为什么 podspec 只区分广告源依赖（不区分 binary）

因为单二进制**已经同时含 TK 和 TB 平台代码**。两个 podspec 的差异只在：

```
TK podspec：拉 TK 广告源适配器依赖（让 TK 链路能运行）
TB podspec：拉 TB 广告源适配器依赖（让 TB 链路能运行）
```

二进制本身完全相同（同一份 `flame_sdk_ios.xcframework`），平台切换通过：

1. **+load 自动注册**：dyld 加载 binary 时，FlameTKProvider 和 FlameTBProvider 的 +load 都触发，两个 Provider 都注册到 FlameMediationRegistry
2. **服务端 pt 字段**：FlameSdk.initSDK 根据服务端下发的 `pt`（tk 或 tb）激活对应 Provider
3. **延迟初始化**：只有被激活的 Provider 才会调用 `initializeWithAppId`，进而调用对应平台 SDK 的初始化 API

---

## 8. 后续双线并存如何处理

Phase 5A.12 单二进制方案的**最大架构红利**：双线并存**不需要重新做二进制包**。

### 8.1 双线并存场景

某些客户可能希望「同一个 App 同时支持 TK 和 TB」（例如 AB 测试、按广告位切换平台）。

### 8.2 三包方案下的双线并存

需要构建 4 个产物（core + tk-plugin + tb-plugin + dual-plugin），4 套校验，4 套 podspec，运维复杂。

### 8.3 单二进制方案下的双线并存

```
单二进制已同时含 TK/TB 代码
→ 只需合并 podspec 依赖
```

合并后的 podspec（假设叫 `flame_sdk_ios_dual`）：

```ruby
s.vendored_frameworks = 'flame_sdk_ios.xcframework'   # 同一份

# 同时拉 TK 和 TB 广告源依赖
s.dependency 'OpenSSL-Universal', '~> 3.6'
s.dependency 'AnyThinkiOS', '6.5.71'
s.dependency 'AnyThinkMediation*Adapter', '...'       # TK Mediation
s.dependency 'AdGainSDK', '4.2.7.1'
s.dependency 'FSUnionAdSDK', '1.0.8.0'
s.dependency 'ToBid-iOS-RC', '5.5.6'                  # TB 核心
```

### 8.4 双线并存需要处理的工程问题

1. **依赖版本冲突**：AnyThinkMediation* 与 ToBid-iOS-RC 是否有共同依赖版本冲突
2. **duplicate framework**：是否有 SDK 被 TK 和 TB 同时依赖（如 SigmobAd-iOS）
3. **duplicate symbol**：WindMill 静态归档与 SigmobAd-iOS（WindSDK 同源）可能产生符号冲突
4. **static archive 链接顺序**：链接顺序敏感，可能需要 `-force_load` 或调整顺序
5. **Router 仍按 pt 激活**：双线并存下，App 启动时两个 Provider 都注册，根据服务端 pt 激活对应一个

### 8.5 双线并存不在 Phase 5A.12 范围

Phase 5A.12 只验证单 podspec（TK 或 TB 二选一）的接入。双线并存是 Phase 5A.13 或更后阶段的工作。

---

## 9. 风险与验证计划

### 9.1 已识别风险

| 风险 | 严重度 | 缓解 |
|---|---|---|
| TB 客户必须接入 AnyThinkSDK（3.5 MB 额外）| 中 | podspec 显式声明 + 文档说明 |
| WindMill 静态归档污染（构建期 -ObjC 自动加载）| 高 | xcFramework_build.sh 隔离逻辑（剔除 -framework Wind* + 临时隐藏归档二进制）|
| FlameSdk.m 中 TK/TB 互斥 #error | 高 | 已解除（Phase 5A.12 改为允许同时定义）|
| `registerAllProvidersIfNeeded` 与 +load 重复注册 | 低 | 单二进制模式下跳过内部实例化，依赖 +load |

### 9.2 验证矩阵

| 验证维度 | Step 1（已完成）| Step 2（待）| Step 3（待）|
|---|---|---|---|
| 单二进制构建 | ✅ flame_sdk_ios.xcframework（300K）| - | - |
| 符号纯净性 | ✅ 0 污染 + 0 源码泄漏| - | - |
| Demo TK 接入 | ✅ Mode C 真机 BUILD SUCCEEDED | - | - |
| Demo TB 接入 | ✅ Mode C 真机 BUILD SUCCEEDED | - | - |
| +load 触发 | 符号层验证 ✅ | 真机运行验证（Xcode Run + console）| - |
| TK 广告链路 | - | 真机调用 Reward/Splash 验证| - |
| TB 广告链路 | - | 真机调用 Reward 验证（800031 可接受）| - |
| alpha.4 正式发布 | - | - | 远程 spec/tag + GitHub release |

### 9.3 真机 +load 验证（Step 2 推荐）

```bash
# 真机运行后观察 console：
# 期望 TK 模式日志：
#   FlameTKProvider: +load 自动注册完成 (plugin 模式, platformCode=tk)
#   FlameTBProvider: +load 自动注册完成 (plugin 模式, platformCode=tb)  ← 单二进制同时注册
#   FlameMediationRegistry: 注册平台 'tk'
#   FlameMediationRegistry: 注册平台 'tb'
#   FlameSdk: 单二进制模式，Provider 由 +load 自动注册
```

---

## 10. 对 Phase 5A.11 的兼容性

Phase 5A.12 完全**向后兼容** Phase 5A.11：

- 三包方案的所有产物保留：`build/flame_sdk_ios_core.xcframework`、`build/tk/flame_sdk_ios.xcframework`、`build/tb/flame_sdk_ios.xcframework`
- 三包方案的所有报告保留：`Phase_5A.11_方案E_二进制插件分发调研报告.md`、`phase-5a.11-step1/2/3-*.md`
- `./xcFramework_build.sh release` 仍构建三包
- `./xcFramework_build.sh single-binary`（新）构建单包

后续可根据实测对比（体积、客户反馈、运维成本）决定主线方案。

---

## 11. 与后续 Phase 的衔接

| Phase | 内容 | 依赖 Phase 5A.12 |
|---|---|---|
| 5A.12 Step 1 | 单二进制构建 + Demo 验证 | （本文档）|
| 5A.12 Step 2 | 真机 +load 触发验证 + 广告链路验证 | ✅ Step 1 通过 |
| 5A.12 Step 3 | alpha.4 正式发布（GitHub release + pod repo push）| ✅ Step 2 通过 |
| 5A.13 | TB 其他广告类型（Splash/Interstitial/Banner/Native）| ✅ alpha.4 发布 |
| 5A.14 | 双线并存 podspec + 依赖冲突处理 | ✅ alpha.4 发布 |

---

## 12. 结论

Phase 5A.12 单二进制方案**架构上更简洁**（1 个产物 vs 3 个产物），**双线并存演进路径更平滑**（无需重新构建），代价是 **TB 客户必须额外接入 3.5 MB AnyThinkSDK**（dyld 显式动态依赖）。

Step 1 验证已全部通过（构建 + 符号 + Demo TK/TB 双双 BUILD SUCCEEDED），可以进入 Step 2 真机运行验证。
