# Phase 5A.12 Step 1d：single-binary mainline 分支清理报告

> **类型**：主线分支切换 + 历史入口清理 + 构建验证
> **执行日期**：2026-06-19
> **新分支**：`research/single-binary-mainline`（从 `research/thin-core-binary` 切出）
> **状态**：清理完成，构建通过，等待真机验证

---

## 核心结论速览

- ✅ **新分支 `research/single-binary-mainline` 已创建**（未 push）
- ✅ **构建脚本只支持 single-binary**：`tk`/`tb`/`release`/`core`/`plugin`/`nosdk`/`dual` 全部拒绝
- ✅ **宏体系完全删除**：19 个源码文件的 `FLAME_BUILD_*` / `FLAME_PLUGIN_*` 守卫全部清除
- ✅ **构建产物唯一**：只有 `build/flame_sdk_ios.xcframework`（无 tk/tb/core 子目录）
- ✅ **二进制体积 300K**，TK/TB 胶水 9 个符号全在
- ✅ **+load 自注册符号在位**（FlameTKProvider + FlameTBProvider）
- ✅ **三方广告源污染 0**（AdGain/BU/CSJ/WindMill 等全部未静态打入）
- ✅ **源码泄漏 0**（无 .m/.mm）
- ✅ **4 份历史文档已加勘误 banner**（指向 mainline 新口径）
- 所有红线遵守：未 push、未 tag、未发布、未合并、未 cherry-pick、未删除兜底分支

---

## 1. 新分支名

`research/single-binary-mainline`

## 2. 创建前分支 / HEAD

| 项 | 值 |
|---|---|
| 分支 | `research/thin-core-binary` |
| HEAD | `3489d1278f6f19bd64b6adb91261251d90f62191` |
| 工作区状态 | 6 个修改 + research/ + 7 份文档（Phase 5A.11/5A.12 实验产物）|

## 3. 创建后分支 / HEAD

| 项 | 值 |
|---|---|
| 分支 | `research/single-binary-mainline`（新）|
| HEAD | `3489d1278f6f19bd64b6adb91261251d90f62191`（与切出前一致，未 commit）|
| 工作区状态 | 所有改动一并带到新分支（未 commit）|

## 4. 是否未 push / 未 tag / 未发布

| 检查项 | 结果 |
|---|---|
| `git push origin` | ❌ 未执行 |
| 远程 tag | ❌ 不存在 |
| GitHub release | ❌ 未创建 |
| `pod repo push` | ❌ 未执行 |
| 本地分支 | ✅ 已创建（仅本地）|

## 5. 为什么新分支只保留 single-binary

详见 `phase-5a.12-single-binary-mainline.md` §1-2。核心原因：
1. `research/thin-core-binary` 混杂了 Phase 5A.10/5A.11/5A.12 三套方案的入口、宏、podspec 实验
2. 一旦出 bug，难以判断实际走的是 single-binary、双二进制、三包插件还是旧宏分支
3. 新分支彻底清理，只保留单二进制主线，代码路径单一清晰

## 6. 为什么删除历史 tk/tb/release/三包构建入口

历史入口在新分支已废弃，理由：
- `tk` / `tb`：双二进制互斥分发，已被 Phase 5A.12 单二进制替代（保留在 `backup/phase-5a-dual-binary-stable`）
- `release`：Phase 5A.11 三包方案，已被 Phase 5A.12 单二进制替代（保留在 `research/thin-core-binary`）
- `core` / `core-named`：Phase 5A.10 thin core，已被 Phase 5A.12 单二进制替代
- `tk-plugin` / `tb-plugin`：Phase 5A.11 插件方案，已被 Phase 5A.12 单二进制替代
- `nosdk` / `dual`：曾作为 single-binary 别名/Podfile 内部映射，统一为 `single-binary`

## 7. 为什么删除旧 TK/TB 互斥宏

旧宏体系的问题：
- `FLAME_BUILD_TK` / `FLAME_BUILD_TB` 让 TK/TB 源码互斥编译（同一 Mach-O 不能同时含）
- `FLAME_PLUGIN_TK` / `FLAME_PLUGIN_TB` 启用 +load 自注册（但依赖构建期注入）
- 与 Phase 5A.12「单 binary 同时含 TK/TB」目标根本冲突

新规则：**平台选择不再靠编译宏，完全靠运行时 pt 路由**。
- 编译期：TK/TB Provider/Adapter 胶水始终全部编进同一个 Mach-O
- 运行期：Router 根据服务端下发的 pt=tk / pt=tb 激活对应 Provider
- Provider 注册：+load 自动完成（dyld 加载 binary 时触发）

## 8. 当前 build 脚本支持的唯一目标

```bash
./xcFramework_build.sh                 # 默认 = single-binary
./xcFramework_build.sh single-binary   # 显式写法（等价默认）
```

两者输出完全相同：`build/flame_sdk_ios.xcframework`

旧参数（`tk`/`tb`/`core`/`release` 等）会报错退出：
```
❌ 当前分支只支持 single-binary 构建，不再支持 tk/tb/release/三包/双二进制历史入口。
```

## 9. 当前默认构建是否就是 single-binary

✅ 是。无参数调用 `./xcFramework_build.sh` 默认走 single-binary 路径。

## 10. 是否还残留 build/tk / build/tb / flame_sdk_ios_core

❌ 无残留。

| 检查项 | 结果 |
|---|---|
| 源码/Podfile/podspec/script 中 `build/tk` 引用 | ✅ 无 |
| 源码/Podfile/podspec/script 中 `build/tb` 引用 | ✅ 无 |
| 源码/Podfile/podspec/script 中 `flame_sdk_ios_core` 引用 | ✅ 无 |
| 实际构建产物 `build/` 子目录 | ✅ 只有 `flame_sdk_ios.xcframework` |
| `wrappers/` 转发头目录 | ✅ 已删除（Phase 5A.10/5A.11 thin-core 残留）|

## 11. 是否还残留 FLAME_BUILD_TK / FLAME_BUILD_TB / HAS_TOBID

❌ 无残留（仅注释中提及"不再使用"，非实际代码）。

| 宏 | 源码 | Podfile | podspec | 构建脚本 |
|---|---|---|---|---|
| `FLAME_BUILD_TK` | ✅ 已删 | ✅ 已删 | ✅ 已删 | ✅ 已删 |
| `FLAME_BUILD_TB` | ✅ 已删 | ✅ 已删 | ✅ 已删 | ✅ 已删 |
| `FLAME_BUILD_CORE` | ✅ 已删 | ✅ 已删 | ✅ 已删 | ✅ 已删 |
| `FLAME_PLUGIN_TK` | ✅ 已删 | ✅ 已删 | ✅ 已删 | ✅ 已删 |
| `FLAME_PLUGIN_TB` | ✅ 已删 | ✅ 已删 | ✅ 已删 | ✅ 已删 |
| `HAS_TOBID` | ✅ 已删 | ✅ 已删 | ✅ 已删 | ✅ 已删 |

## 12. 两个 podspec 是否都引用同一个 binary

✅ 是。

| podspec | vendored_frameworks |
|---|---|
| `flame_sdk_ios.podspec` | `build/flame_sdk_ios.xcframework` |
| `flame_sdk_ios_tb.podspec` | `build/flame_sdk_ios.xcframework`（同一份）|

## 13. 两个 podspec 是否都声明公共平台核心依赖

✅ 是。两个 podspec 都声明：

```ruby
s.dependency 'OpenSSL-Universal', '~> 3.6'    # 加密基础依赖
s.dependency 'AnyThinkiOS', '6.5.71'           # TK 平台核心（binary LC_LOAD_DYLIB 硬依赖）
s.dependency 'ToBid-iOS-RC', '5.5.6'           # TB 平台核心（WindMill 静态归档）
```

理由：
- OpenSSL：binary 动态依赖（otool -L 可见）
- AnyThinkiOS：binary 动态依赖（otool -L 可见 `@rpath/AnyThinkSDK.framework`）
- ToBid-iOS-RC：统一口径 + 双线并存准备（TB 胶水的 WindMill U 引用虽 lazy binding，但作为公共依赖统一声明）

## 14. 差异化广告源依赖清单

### flame_sdk_ios.podspec（TK 专属）

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

### flame_sdk_ios_tb.podspec（TB 专属）

当前为空（TB Reward 阶段使用 ToBid-iOS-RC 默认 ToBidSDK 子规范）。

后续 Phase 5A.13+ 接 TB Splash/Interstitial/Banner/Native 时，按需增加 ToBid-iOS-RC 的 21 个 Adapter 子规范。

## 15. 构建产物路径

```
build/flame_sdk_ios.xcframework/
├── Info.plist
├── ios-arm64/flame_sdk_ios.framework/
│   ├── flame_sdk_ios              （binary，300K，MH_DYLIB）
│   ├── Info.plist
│   ├── Modules/module.modulemap
│   └── Headers/                   （10 个公共 API）
└── ios-x86_64-simulator/flame_sdk_ios.framework/
    └── （同上结构）
```

**唯一产物**：无 `build/tk/`、无 `build/tb/`、无 `build/flame_sdk_ios_core.xcframework`。

## 16. 二进制体积

| 切片 | 体积 |
|---|---|
| ios-arm64 | **300K** |
| ios-x86_64-simulator | ~300K |

对比：
- 三包方案（Phase 5A.11）：core 176K + tk plugin 172K + tb plugin 76K = 424K 总量
- mainline 单二进制：**300K**（少 124K，因 core 不重复）

## 17. otool -L 摘要

```
@rpath/flame_sdk_ios.framework/flame_sdk_ios        ← 自身
@rpath/AnyThinkSDK.framework/AnyThinkSDK            ← TK 平台核心（LC_LOAD_DYLIB 硬依赖）
@rpath/OpenSSL.framework/OpenSSL                     ← 加密依赖（LC_LOAD_DYLIB）
（其余为系统框架）
```

**关键**：
- ✅ 无 `flame_sdk_ios_core.framework`（core 已编进同一 Mach-O）
- ✅ 无 `WindMill` / `WindSDK` / `WindFoundation` 动态依赖（静态归档已隔离）

## 18. TK/TB 胶水符号检查

✅ 全部在位（9 个 ObjC 类）：

| 平台 | 类 | 数量 |
|---|---|---|
| TK | FlameTKProvider | 1 |
| TK | AtRewardAdapter | 1 |
| TK | AtSplashAdapter | 1 |
| TK | AtInterstitialAdapter | 1 |
| TK | AtBannerAdapter | 1 |
| TK | AtNativeAdapter | 1 |
| TK | AtNativeSelfRenderView | 1 |
| TB | FlameTBProvider | 1 |
| TB | TbRewardAdapter | 1 |

**+load 自注册符号**：
- `+[FlameTKProvider load]` ✅ 在位
- `+[FlameTBProvider load]` ✅ 在位

## 19. 广告源静态污染检查

✅ **全部为 0**：

| 检测项 | 结果 |
|---|---|
| 三方广告源 SDK 静态符号（AdGain/BU/CSJ/Baidu/GDT/KS/FS/Sigmob）| **0** |
| ToBid/WindMill 实现符号（WindMillSDK/WindMillAds/WindFoundation）| **0** |
| AnyThink AT* 静态定义符号 | **0**（动态依赖正确）|

## 20. 源码泄漏检查

✅ **0 泄漏**：

```bash
find build/flame_sdk_ios.xcframework \( -name "*.m" -o -name "*.mm" \) -print
# （无输出）
```

Headers/ 只含 10 个公共 API 头。

## 21. 是否建议进入真机验证

✅ **建议进入真机验证**（Step 2）。

### 21.1 静态层面已全部验证

| 项 | 状态 |
|---|---|
| 单二进制构建 | ✅ 双 ARCHIVE SUCCEEDED |
| 产物路径唯一 | ✅ 只有 flame_sdk_ios.xcframework |
| 符号纯净性 | ✅ 0 三方静态符号 |
| 源码泄漏 | ✅ 0 |
| TK 平台胶水 | ✅ 7 个符号全在 |
| TB 平台胶水 | ✅ 2 个符号全在 |
| +load 自注册 | ✅ 两个 Provider 都有 |
| 二进制硬依赖明确 | ✅ AnyThinkSDK + OpenSSL |
| 两个 podspec 都满足硬依赖 | ✅ |
| 两个 podspec 公共依赖一致 | ✅ OpenSSL + AnyThinkiOS + ToBid-iOS-RC |
| 两个 podspec 差异只在广告源 | ✅ |

### 21.2 真机验证关键观察点

- TK 模式启动：dyld 能否找到 AnyThinkSDK
- TK 模式启动：两个 +load 是否都触发（FlameTKProvider + FlameTBProvider）
- TK 模式：pt=tk 时 TK Reward/Splash/Interstitial/Banner/Native 链路
- TB 模式启动：dyld 能否找到 AnyThinkSDK（即使 TB 业务不用）
- TB 模式：pt=tb 时 TB Reward 链路（800031 后台未绑定错误可接受）

## 22. 风险点

| 风险 | 严重度 | 缓解 |
|---|---|---|
| TK 客户接入 ToBid-iOS-RC 多 9.4MB 体积 | 中 | 公共依赖统一口径的代价；后续可优化（如口径 B：TK 不接 ToBid）|
| +load 在某些 CocoaPods 版本未触发 | 低 | registerAllProvidersIfNeeded 已加防御性兜底（检查 hasProviderForPlatformCode）|
| WindMill 静态归档隔离失败（污染 binary）| 中 | xcFramework_build.sh 两步隔离（xcconfig patch + 临时隐藏归档二进制）|
| TB Adapter 子规范未声明（只 Reward）| 低 | Phase 5A.13+ 按需增加 |

## 23. /compact

**Phase 5A.12 Step 1d（mainline 切换）完成状态**：

| 项 | 状态 |
|---|---|
| 新分支 `research/single-binary-mainline` | ✅ 已创建（未 push）|
| xcFramework_build.sh 只支持 single-binary | ✅ |
| Podfile 单一依赖环境 | ✅ |
| 19 个源码文件宏守卫清除 | ✅ |
| FlameSdk.m TK/TB 互斥 #error 删除 | ✅ |
| FlameAdapterManager.m #endif 残留修复 | ✅ |
| wrappers/ 转发头目录删除 | ✅ |
| 两个 podspec 同引一个 binary + 公共依赖 | ✅ |
| 构建产物唯一（flame_sdk_ios.xcframework）| ✅ |
| 二进制 300K + 0 污染 + 0 泄漏 | ✅ |
| TK/TB 胶水 9 个符号全在 | ✅ |
| +load 自注册符号在位 | ✅ |
| 4 份历史文档加勘误 banner | ✅ |
| 主线文档 phase-5a.12-single-binary-mainline.md | ✅ |
| 发布 / push / tag / pod repo push | ❌ 未执行（红线遵守）|

**关键文件清单**：

```
doc/flame_mediation/
├── phase-5a.12-single-binary-mainline.md                       # ✨ 新主线文档
├── phase-5a.12-step1d-single-binary-mainline-cleanup-report.md # ✨ 本清理报告
├── phase-5a.12-single-binary-dual-core-plan.md                 # （历史，已加勘误 banner）
├── phase-5a.12-step1-single-binary-dual-core-build-report.md   # （历史，已加勘误 banner）
├── phase-5a.12-step1b-single-binary-dependency-boundary-review.md # （历史，已加勘误 banner）
└── phase-5a.12-tb-adapter-branch-state-review.md               # （历史，已加勘误 banner）

代码改动（未 commit）：
├── xcFramework_build.sh                # 重写：只支持 single-binary
├── Podfile                             # 重写：单一依赖环境
├── flame_sdk_ios.podspec               # 重写：公共依赖 + TK 广告源
├── flame_sdk_ios_tb.podspec            # 重写：公共依赖（TB 广告源暂空）
├── flame_sdk_ios/core/FlameSdk.m       # 删除 #error + 宏 import + 重写 registerAllProvidersIfNeeded
├── flame_sdk_ios/adapter/FlameAdapterManager.m  # 删除 #if/#else/#endif 宏分支
├── flame_sdk_ios/adapter/tk/*.h+.m (12 files)    # 删除 FLAME_BUILD_TK 守卫
├── flame_sdk_ios/adapter/tb/*.h+.m (2 files)     # 删除 FLAME_BUILD_TB 守卫
├── flame_sdk_ios/mediation/tk/FlameTKProvider.h+.m  # 删除守卫 + +load 始终启用
└── flame_sdk_ios/mediation/tb/FlameTBProvider.h+.m  # 删除守卫 + +load 始终启用

删除：
└── flame_sdk_ios/wrappers/             # 整个目录（Phase 5A.10/5A.11 thin-core 转发头残留）

构建产物：
└── build/flame_sdk_ios.xcframework     # 唯一（300K）

research/local_dist/logs/
├── single-binary-mainline-build-2.log       # 构建日志（初次全通过）
├── single-binary-mainline-build-3.log       # 构建日志（删 wrappers 后重构）
├── single-binary-mainline-verify.log        # 完整符号验证
└── single-binary-mainline-cleanup-check-2.log # 旧逻辑清理验证
```

**Step 1d 完成，等待 Step 2 真机验证指令。**

红线遵守：未发布、未 push、未 tag、未 pod repo push、未合并、未 cherry-pick、未删除 tb_adapter / backup 兜底分支。
