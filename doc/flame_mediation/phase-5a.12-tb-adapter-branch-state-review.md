# Phase 5A.12：feat/tb_adapter 分支历史状态盘点报告

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

> **类型**：只读盘点（P0，Phase 5A.12 Step 2 真机验证暂停，先确认 tb_adapter 历史进度）
> **执行日期**：2026-06-19
> **触发**：用户记忆 tb_adapter 分支可能存在「一个 podspec + 一个二进制包 + nosdk 适配器」的早期方案，需确认当时实际做到哪一步
> **方法**：用 git worktree 只读检查 feat/tb_adapter，不切当前主工作区分支，不修改任何文件

---

## 核心结论速览

- ❌ **tb_adapter 分支没有「nosdk 适配器方案」**：全仓库 `nosdk` 关键词只出现 1 次，且与构建变体无关（指 Sigmob 公司的 `AnyThinkMediationSigmobAdapter-NoSDK` Adapter 变体）
- ❌ **tb_adapter 分支没有「一个 podspec + 一个二进制包」**：实际是**双 podspec + 双二进制互斥分发**（TK binary + TB binary，两套独立）
- ✅ **tb_adapter HEAD `086a766`** = 「双二进制互斥分发方案 + TB/ToBid 接入 + splash 回调修复 + 调研报告」（2026-06-17，本地领先 origin 1 commit，未 push）
- ✅ **同时打到 `backup/phase-5a-dual-binary-stable`**（兜底保护分支）
- ✅ **TB 源码已完整**：FlameTBProvider + TbRewardAdapter（业务实现完整，但无 +load 自注册机制）
- ✅ **TK 源码已完整**：FlameTKProvider + 6 At*Adapter（业务实现完整）
- ⚠️ **架构与 Phase 5A.12 完全不同**：tb_adapter 是「TB binary 自包含 WindMill 9.4 MB」，Phase 5A.12 是「单 binary 不打包 WindMill」
- ⚠️ **用户记忆有偏差**：实际历史是 Phase 5A.3→5A.4→5A.5（单包全量，已被替代）→ 双二进制互斥分发（当前 HEAD）

---

## 1. 当前主工作区状态

| 项目 | 值 |
|---|---|
| 主仓库路径 | `/Users/khj/Documents/code/97_ad/ios/flame_ios_sdk` |
| 当前分支 | `research/thin-core-binary`（Phase 5A.10/5A.11/5A.12 主线）|
| HEAD | `3489d1278f6f19bd64b6adb91261251d90f62191`（Phase 5A.10 Step 4D）|
| 工作区状态 | 6 个修改 + research/ + 7 份文档（详见下表）|

### 1.1 主工作区已动过的文件（实证 git status）

| 文件 | 状态 | 来源阶段 |
|---|---|---|
| `Podfile` | M（修改）| Phase 5A.12 加 single-binary 变体 |
| `flame_sdk_ios.podspec` | M | Phase 5A.11 期间 |
| `flame_sdk_ios.xcodeproj/project.pbxproj` | M | Phase 5A.11 期间 |
| `flame_sdk_ios/core/FlameSdk.m` | M | Phase 5A.12 解除 TK/TB 互斥 #error |
| `flame_sdk_ios_tb.podspec` | M | Phase 5A.11 期间 |
| `xcFramework_build.sh` | M | Phase 5A.12 加 single-binary |
| `research/` | ??（新增）| Phase 5A.11/5A.12 实验产物（dist/podspecs/specs/backups/logs）|
| `doc/flame_mediation/Phase_5A.11_*.md`（4 份）| ?? | Phase 5A.11 文档 |
| `doc/flame_mediation/phase-5a.12-*.md`（3 份）| ?? | Phase 5A.12 文档（含本盘点报告）|

**重要**：HEAD `3489d12` 自 Phase 5A.12 开始至今**未变**（没有新 commit）。所有改动都在工作区，未 commit。

### 1.2 已停止的操作（按本次任务红线）

- ❌ 未继续 Phase 5A.12 Step 2 真机验证
- ❌ 未继续修改 Step 1 / Step 1b 文档（Step 1b 只做了只读分析，新建独立报告 `phase-5a.12-step1b-*.md`，未改 Step 1 报告）

## 2. tb_adapter 实际分支名

| 项 | 值 |
|---|---|
| 本地分支 | `feat/tb_adapter` |
| 远程分支 | `origin/feat/tb_adapter`（`d7d7837`）|
| 备份分支 | `backup/phase-5a-dual-binary-stable`（与 feat/tb_adapter HEAD 同点 `086a766`）|
| worktree 检查路径 | `/Users/khj/Documents/code/97_ad/ios/flame_ios_sdk_tb_adapter_inspect`（本次新建，只读）|

**注意**：feat/tb_adapter 本地比 origin 领先 1 commit（`086a766`，未 push）。

## 3. tb_adapter 分支 HEAD

| 项 | 值 |
|---|---|
| HEAD commit | `086a766eab3ac8d86be2aa1184a02af2d080a35c` |
| 标题 | `feat: 双二进制互斥分发方案 + TB/ToBid 接入 + splash 回调修复 + 调研报告` |
| 作者 | 康海军 <khj@mac.local> |
| 日期 | 2026-06-17 22:30:19 +0800 |
| 改动规模 | 71 个文件，+6365/-404 行 |

## 4. tb_adapter 最近 30 条 commit

```
086a766 (HEAD -> feat/tb_adapter, backup/phase-5a-dual-binary-stable) feat: 双二进制互斥分发方案 + TB/ToBid 接入 + splash 回调修复 + 调研报告
d7d7837 (origin/feat/tb_adapter) chore: update project.pbxproj on feat/tb_adapter branch
61c3338 (origin/feat/tk_adapter, feat/tk_adapter) chore: update Podfile.lock for OpenSSL-Universal 3.x upgrade
fc8c768 feat: upgrade OpenSSL-Universal to 3.x (no bitcode), update header paths for 0.1.8.4
4d578e7 fix: remove embedded frameworks from flame_sdk_ios.framework, add bitcode stripping to build script
a078a05 fix: add post-build cleanup to remove .sh and .podspec from framework bundle
4bd1a33 feat: 0.1.8.1 稳定性修复
a26014a feat: 更新 AnyThinkiOS 版本至 6.5.71，调整 podspec 文件以支持动态版本链接
0b35b10 feat: 更新 podspec 文件，提升版本至 0.1.8，修正描述和主页链接
9a4bd34 feat: 更新方案用户状态，调整方案顺序提示
9424dc2 feat:banner self render
750740e feat: 移除视频流广告相关代码，更新广告适配器和接口文档
1d50a60 feat: 优化日志输出，简化广告加载和展示的日志信息，并添加插屏广告对接说明文档,调整插屏广告尺寸为全屏
f7c1bac feat: 更新构建脚本以支持iOS版本和优化库分发设置
7f74138 feat: 添加广告尺寸属性并优化广告加载逻辑
9f597d9 feat: 增强SDK初始化时的回调处理
5555fc6 fix:修复广告回调选择器写法错误
478159b feat: Enhance Flame SDK initialization and callback handling
53ee14b fix: 统一Adapter destroy方法实现
e801020 fix: 修复阶段1核心问题 (P0)
e0040b3 (tag: v0.1.1, origin/main, main) feat: implement Flame iOS SDK v0.1.1
c4fe05f Initial Commit
```

**关键节点**：
- `c4fe05f` Initial Commit
- `e0040b3` v0.1.1 release（打 tag，origin/main）
- `e801020` Phase 1 核心 P0 修复
- `4bd1a33` 0.1.8.1 稳定性修复
- `61c3338` OpenSSL 3.x 升级（feat/tk_adapter 分叉点）
- `d7d7837` project.pbxproj 更新（origin/feat/tb_adapter）
- `086a766` **双二进制互斥分发方案**（当前 HEAD，本地领先）

## 5. 是否存在一个 podspec

❌ **不存在「一个 podspec」方案**。

tb_adapter 有**两个 podspec**：
- `flame_sdk_ios.podspec`（TK 侧）
- `flame_sdk_ios_tb.podspec`（TB 侧）

## 6. 是否存在两个 podspec

✅ **存在两个 podspec**（详见 §5）。

## 7. 是否存在一个 flame_sdk_ios.xcframework

❌ **不存在「一个 flame_sdk_ios.xcframework」**。

tb_adapter 是**两个独立 xcframework**（路径在 podspec 里写死）：
- `build/tk/flame_sdk_ios.xcframework`（TK 侧，276K，仅含 TK 能力）
- `build/tb/flame_sdk_ios.xcframework`（TB 侧，6.9M，**自包含 WindMill 9.4 MB 静态归档**）

**注意**：build/ 目录是构建期产物，**未提交到 git**（commit 086a766 的 71 个文件里没有 build/）。phase-5a.10 报告里提到的体积是当时本地构建出的产物。

## 8. 是否存在 nosdk 构建变体

❌ **不存在 nosdk 构建变体**。

xcFramework_build.sh 只支持两个变体：
- `tk`（默认）
- `tb`

变体解析代码：
```bash
VARIANT="${1:-tk}"
if [ "$VARIANT" != "tk" ] && [ "$VARIANT" != "tb" ]; then
  echo "❌ 未知变体: $VARIANT（仅支持 tk / tb）"
  exit 1
fi
```

## 9. nosdk 当时的含义

**tb_adapter 分支里 `nosdk` 关键词只出现 1 次，且与构建变体无关**：

```bash
$ grep -rniE "nosdk" --include="*.md" --include="*.podspec" --include="*.sh" .
./flame_sdk_ios.podspec:52:  # TK 默认包不使用 AnyThinkMediationSigmobAdapter-NoSDK
```

这是指 **Sigmob 公司提供了一个 `-NoSDK` 后缀的 Adapter pod 变体**（`AnyThinkMediationSigmobAdapter-NoSDK`，不带 SigmobAd-iOS SDK 的适配器版本），与「nosdk 构建变体」「nosdk 适配器方案」**完全无关**。

**结论**：用户记忆中的「nosdk 适配器」实际是这个 Sigmob `-NoSDK` Adapter pod 名后缀，被误记为「nosdk 方案」。

## 10. podspec 是否引用一个二进制包

❌ **不是引用一个二进制包**。两个 podspec 引用**两个不同的二进制包**：

| podspec | vendored_frameworks |
|---|---|
| `flame_sdk_ios.podspec`（TK）| `build/tk/flame_sdk_ios.xcframework` |
| `flame_sdk_ios_tb.podspec`（TB）| `build/tb/flame_sdk_ios.xcframework` |

两个 binary 互斥独立（同 module 名 `flame_sdk_ios` 天然保证不能同时接入）。

## 11. podspec 是否使用 source_files

❌ **两个 podspec 都不使用 source_files**。

TK podspec 注释明确：「注意：不要写 s.source_files，因为你不需要向用户分发源代码」。

TB podspec 同样无 source_files（纯 vendored binary 模式）。

## 12. podspec 拉了哪些依赖

### 12.1 flame_sdk_ios.podspec（TK 侧，15 个依赖）

| # | dependency |
|---|---|
| 1 | `OpenSSL-Universal ~> 3.6` |
| 2 | `AnyThinkiOS 6.5.71` |
| 3 | `AnyThinkMediationAdxSmartdigimktCNAdapter 6.5.72.2.1` |
| 4 | `AnyThinkMediationGromoreAdapter 7.6.0.4.2.0` |
| 5 | `AnyThinkMediationBaiduAdapter 10.050.2.1` |
| 6 | `AnyThinkMediationMSAdapter 2.7.18.1.2.0` |
| 7 | `AnyThinkMediationZYAdapter 2.6.4.29.2.0` |
| 8 | `AnyThinkMediationFunlinkAdapter 2.9.0.1.2.2.0` |
| 9 | `AnyThinkMediationBeiZiAdapter 5.5.0.3.2.0` |
| 10 | `AnyThinkMediationKuaiShouAdapter 5.4.10.1.2.0` |
| 11 | `AnyThinkMediationSigmobAdapter 4.20.12.2.0` |
| 12 | `AnyThinkMediationTTAdapter_Mix 7.6.0.4.2.0` |
| 13 | `AnyThinkMediationGDTAdapter 4.15.90.2.0` |
| 14 | `AdGainSDK 4.2.7.1` + `AdGainSDKTakuAdapter 4.2.7.1` |
| 15 | `FSUnionAdSDK 1.0.8.0` |

**不依赖** ToBid-iOS-RC（注释明确：「TK 默认包不依赖 ToBid-iOS-RC，ToBid 能力由 flame_sdk_ios_tb 提供」）。

### 12.2 flame_sdk_ios_tb.podspec（TB 侧，1 个依赖）

| # | dependency |
|---|---|
| 1 | `OpenSSL-Universal ~> 3.6` |

**只依赖 OpenSSL**！注释明确：「build/tb/flame_sdk_ios.xcframework 已静态内置 WindMillSDK/WindSDK/WindFoundation（3621 个 WindMill 符号已链接进二进制），因此本 podspec 不再声明 ToBid-iOS-RC 依赖，否则下游会再次拉入 ToBid 导致 duplicate class」。

**禁止依赖（红线）**：
- 不依赖 flame_sdk_ios（避免带入 TK 依赖）
- 不依赖 ToBid-iOS-RC（已静态内置，声明会导致 duplicate class）
- 不依赖 AnyThinkiOS / AnyThinkMediation* / TK adapter

## 13. 是否已有 FlameTBProvider

✅ **已有 FlameTBProvider**（完整业务实现）。

- `flame_sdk_ios/mediation/tb/FlameTBProvider.h`（741 bytes）
- `flame_sdk_ios/mediation/tb/FlameTBProvider.m`（4162 bytes）

实现内容：
- `platformCode` 返回 `@"tb"`
- `initializeWithAppId:appKey:callback:` 调用 `[WindMillAds setupSDKWithAppId:appId completionHandler:...]`
- `createRewardAdapterWithViewController:placementId:listener:` 创建 TbRewardAdapter
- Splash/Interstitial/Banner/Native 占位返回 nil（Phase 6 待实现）
- 宏守卫：`#if defined(FLAME_BUILD_TB)`

## 14. 是否已有 TbRewardAdapter

✅ **已有 TbRewardAdapter**（完整业务实现）。

- `flame_sdk_ios/adapter/tb/TbRewardAdapter.h`（1819 bytes）
- `flame_sdk_ios/adapter/tb/TbRewardAdapter.m`（6337 bytes）

实现内容：
- 实现 `FlameRewardAdapterProtocol` + `WindMillRewardVideoAdDelegate`
- 持有 `WindMillRewardVideoAd` 实例
- 13 个 WindMill delegate 方法映射到 FlameRewardListener
- 宏守卫：`#if defined(FLAME_BUILD_TB)`

## 15. 是否已有 nosdk adapter

❌ **不存在 nosdk adapter**。

adapter 目录只有两个子目录：
- `flame_sdk_ios/adapter/tk/`（6 个 At*Adapter + AtNativeSelfRenderView）
- `flame_sdk_ios/adapter/tb/`（1 个 TbRewardAdapter）

没有 `adapter/nosdk/` 或类似目录。

## 16. 是否已有 TK/TB 胶水同包迹象

❌ **没有 TK/TB 胶水同包迹象**。

tb_adapter 是**互斥分发**：
- TK binary（`build/tk/`）只含 TK 胶水（编译期 `FLAME_BUILD_TK=1`，TB 源码被宏守卫置空）
- TB binary（`build/tb/`）只含 TB 胶水（编译期 `FLAME_BUILD_TB=1`，TK 源码被宏守卫置空）

FlameSdk.m 明确禁止同时定义：
```c
#if defined(FLAME_BUILD_TK) && defined(FLAME_BUILD_TB)
#error "FLAME_BUILD_TK and FLAME_BUILD_TB cannot both be defined"
#endif
```

这与 Phase 5A.12 单二进制方案（同时含 TK+TB 胶水）**完全相反**。

## 17. 是否有广告源 SDK 静态污染迹象

⚠️ **TB binary 故意静态打入 WindMill（自包含模式）**，但这不是「污染」，是设计选择。

xcFramework_build.sh 符号校验期望：
- TK binary：**0 个**三方广告源 SDK 符号（ToBid/AdGain/BU/CSJ/Wind/Baidu/GDT/KS/FS/Sigmob）
- TB binary：**含 WindMill 符号**（预期 >0，自包含模式），无 TK/AT* adapter 符号

phase-5a.10 报告确认：「TB 包 6.9M + 3621 个 WindMill 符号」。

**这是 Phase 5A.10 调研的触发原因**：双二进制方案的 TB 包因自包含 WindMill 导致体积膨胀 + 潜在 duplicate class 风险（SigmobAd-iOS 也含 WindSDK/WindFoundation），phase-5a.10 调研 thin core 方案以根除该问题。

## 18. 是否有历史验证报告

✅ **有完整的历史文档**（doc/flame_mediation/ 下）：

| 文档 | 大小 | 内容 |
|---|---|---|
| `tobid_doc/00_README.md` | 3557 B | 文档索引 |
| `tobid_doc/01_current_sdk_context.md` | 11693 B | 当前 SDK 上下文分析 |
| `tobid_doc/02_multi_mediation_architecture.md` | 33666 B | 多聚合架构方案（推荐方案 A 手动注册）|
| `tobid_doc/03_backend_config_and_cache.md` | 8875 B | 后台配置与缓存 |
| `tobid_doc/04_tobid_integration_notes.md` | 12652 B | ToBid 集成笔记 |
| `tobid_doc/05_implementation_plan.md` | 16580 B | 实施计划 |
| `tobid_doc/06_risk_and_rollback.md` | 6452 B | 风险与回滚 |
| `tobid_doc/07_claude_compact_context.md` | 13351 B | Claude compact 上下文 |
| `tobid_doc/08_next_stage_prompt.md` | 10991 B | 下一阶段 prompt |
| `tobid_doc/09_change_log.md` | 48712 B（899 行）| **变更日志（Phase 5A.1～5A.5）** |
| `phase-5a.10-thin-core-binary-research.md` | 555 行 | **Thin Core 可行性调研** |

## 19. 历史验证做到哪一步

### 19.1 Phase 5A.1～5A.5（09_change_log.md 记录）

| Phase | 方案 | 状态 |
|---|---|---|
| Phase 5A.1 | ToBid Reward 运行前代码审查修复 | ✅ 完成 |
| Phase 5A.3 | ToBid 依赖隔离修正（`#ifdef HAS_TOBID`）| ✅ 完成 |
| Phase 5A.4 | 双 xcframework + subspec（`pod 'flame_sdk_ios/ToBid'`）| ✅ 完成，后被替代 |
| **Phase 5A.5** | **单包全量方案**（一个 podspec + 一个 xcframework + 移除 subspec/HAS_TOBID）| ✅ **编译验证通过**，后被替代 |

**Phase 5A.5 单包全量方案**就是用户记忆的「一个 podspec + 一个二进制包」！但当时：
- 编译验证 BUILD SUCCEEDED ✅
- **但未完成真机/后台验证**（待完成验证清单：pt=tk Reward 回归、pt=tb Reward 链路、干净环境 pod install、xcframework 完整构建、App 链接、同名 framework 真机运行）
- 存在 WindFoundation/WindSDK 同名 framework 覆盖风险（SigmobAd-iOS vs ToBid-iOS-RC）

### 19.2 Phase 5A.5 之后（无 change_log 记录）

Phase 5A.5 单包全量方案**之后**改成了双二进制互斥分发（当前 HEAD `086a766`）。这次回退**没有在 09_change_log.md 里记录**（change_log 只到 5A.5）。

回退原因（从 phase-5a.10 报告推断）：单包全量方案的 WindFoundation/WindSDK 同名 framework 覆盖风险无法根除，改用双二进制互斥分发彻底隔离 TK/TB。

### 19.3 Phase 5A.10（调研报告）

phase-5a.10-thin-core-binary-research.md（2026-06-17）是**纯调研**：
- 调研 thin core binary 可行性（结论：可行）
- 推荐分两步走（Step 1 产物切片 + Step 2 Demo 验证）
- **当时未创建 research/thin-core-binary 分支**（报告明确写「本轮纯调研，未执行 git checkout -b」）
- 之后才基于此报告创建 research/thin-core-binary 分支推进实现

### 19.4 当前 HEAD 的验证状态

tb_adapter HEAD `086a766` 的双二进制方案：
- ✅ 源码编译验证通过（commit 已落地）
- ✅ 本地构建产物验证（TK 276K + TB 6.9M，符号校验通过）
- ⚠️ **未真机运行验证**（pod install 网络问题 + 真机运行待完成）
- ❌ **未发布**（未 tag、未 pod repo push、未 GitHub release）

## 20. 与当前 Phase 5A.12 single-binary 目标的匹配度

### 20.1 架构对比

| 维度 | tb_adapter（双二进制互斥）| Phase 5A.12（单二进制）|
|---|---|---|
| 二进制数量 | 2（TK + TB）| 1（同时含 TK/TB）|
| podspec 数量 | 2 | 2 |
| podspec 引用 binary | 各引用各的（互斥）| 都引用同一个 |
| TB binary 是否含 WindMill | ✅ 自包含（9.4 MB 静态打入）| ❌ 不打包（U 引用）|
| Provider 注册机制 | 静态注册（编译期 #if）| +load 自注册（运行期）|
| TK/TB 能否同包 | ❌ 不能（#error 互斥）| ✅ 能（同时编译）|
| FlameSdk.m TK/TB 守卫 | `#error` 禁止同定义 | 已解除（允许同定义）|
| 体积（TK + TB 总量）| 276K + 6.9M = 7.2M | 300K（单包）|

### 20.2 匹配度评估

**匹配度：低（约 30%）**。

可复用部分：
- ✅ TK adapter 6 个完整业务实现（AtBannerAdapter/AtInterstitialAdapter/AtNativeAdapter/AtNativeSelfRenderView/AtRewardAdapter/AtSplashAdapter）
- ✅ TB adapter 1 个完整业务实现（TbRewardAdapter）
- ✅ FlameTKProvider / FlameTBProvider 业务逻辑（initializeWithAppId + create*Adapter）
- ✅ Mediation 骨架（Registry/Router/Provider/5 个 AdapterProtocol）
- ✅ TK podspec 依赖列表（15 个，与 Phase 5A.12 一致）
- ✅ splash 回调映射修复

不可复用部分：
- ❌ 双二进制构建逻辑（Phase 5A.12 需要单二进制构建）
- ❌ TB 自包含 WindMill 模式（Phase 5A.12 改为 U 引用 + podspec 提供）
- ❌ FlameSdk.m TK/TB 互斥 #error（Phase 5A.12 已解除）
- ❌ 静态注册机制（Phase 5A.12 改为 +load 自注册）
- ❌ TB podspec 只依赖 OpenSSL（Phase 5A.12 改为依赖 OpenSSL + AnyThinkiOS + ToBid-iOS-RC）

## 21. 建议复用哪些内容

### 21.1 源码层（高价值，可直接复用）

- `flame_sdk_ios/adapter/tk/*.m`（6 个 TK adapter，业务逻辑成熟）
- `flame_sdk_ios/adapter/tb/TbRewardAdapter.m`（TB Reward 完整实现）
- `flame_sdk_ios/mediation/tk/FlameTKProvider.m`（TK Provider 业务逻辑）
- `flame_sdk_ios/mediation/tb/FlameTBProvider.m`（TB Provider 业务逻辑）
- `flame_sdk_ios/mediation/*.h`（Registry/Router/Provider/AdapterProtocol 协议骨架）
- `flame_sdk_ios/ads/splash/AtSplashAdapter.m` 的回调映射修复（splashDidShow→onAdShow 等）

**注意**：这些源码 research/thin-core-binary 分支**已经全部继承**（Phase 5A.10/5A.11 基于同一棵代码树演进），无需从 tb_adapter cherry-pick。

### 21.2 文档层（参考价值）

- `tobid_doc/02_multi_mediation_architecture.md`（架构设计思路）
- `tobid_doc/09_change_log.md`（Phase 5A.1～5A.5 演进历史，避免重蹈覆辙）
- `phase-5a.10-thin-core-binary-research.md`（Thin Core 可行性论证）

### 21.3 podspec 依赖列表（参考价值）

- TK podspec 的 15 个依赖（与 Phase 5A.12 一致，可直接参考）

## 22. 哪些内容不能直接复用

### 22.1 构建脚本（不能复用）

tb_adapter 的 `xcFramework_build.sh` 只支持 tk/tb 双变体互斥构建，**不支持单二进制构建**。Phase 5A.12 需要的 `single-binary` 变体是 research/thin-core-binary 上新增的，不能从 tb_adapter 复用。

### 22.2 podspec 架构（不能复用）

tb_adapter 的两个 podspec 引用**不同** binary（互斥），Phase 5A.12 需要两个 podspec 引用**同一个** binary。架构完全不同。

### 22.3 FlameSdk.m 守卫逻辑（不能复用）

tb_adapter 的 `#error "FLAME_BUILD_TK and FLAME_BUILD_TB cannot both be defined"` 与 Phase 5A.12 单二进制方案冲突。research/thin-core-binary 已解除此约束。

### 22.4 Provider 注册机制（不能复用）

tb_adapter 是静态注册（编译期 #if 决定一个 binary 注册一个 Provider），Phase 5A.12 需要 +load 自注册（一个 binary 同时注册两个 Provider）。

## 23. 是否建议基于 tb_adapter 新拉分支继续

❌ **不建议**。

理由：
1. tb_adapter 是「双二进制互斥分发」架构，与 Phase 5A.12「单二进制」目标**根本不同**
2. tb_adapter 的 TB binary 自包含 WindMill 9.4 MB，正是 Phase 5A.10/5A.11/5A.12 试图根除的问题
3. research/thin-core-binary 已经继承了 tb_adapter 的所有可用源码（TK/TB adapter + Provider + mediation 骨架），并在此基础上演进到了 Phase 5A.12
4. 基于 tb_adapter 新拉分支会丢失 Phase 5A.10/5A.11/5A.12 的全部成果（thin core / 三包方案 / 单二进制方案）

## 24. 是否建议当前 research/thin-core-binary 继续作为主线

✅ **建议**。

理由：
1. research/thin-core-binary 已继承 tb_adapter 的全部业务源码
2. research/thin-core-binary 已完成 Phase 5A.10（thin core）+ Phase 5A.11（三包方案）+ Phase 5A.12（单二进制方案）
3. research/thin-core-binary 的 Phase 5A.12 单二进制方案已通过 Step 1 验证（构建 + 符号 + Demo TK/TB 双 BUILD SUCCEEDED）
4. tb_adapter 作为「双二进制互斥分发」稳定兜底保留在 `backup/phase-5a-dual-binary-stable` 分支，需要时可回退

### 24.1 主线建议

继续在 research/thin-core-binary 推进 Phase 5A.12：
- 当前阻塞点：Step 1b 复核发现的口径选择（A：TK 也加 ToBid vs B：当前实现）
- 解决口径选择后进入 Step 2 真机验证
- tb_adapter / backup/phase-5a-dual-binary-stable 作为兜底保留，不删除

## 25. /compact

**tb_adapter 分支盘点结论**：

| 项 | 结论 |
|---|---|
| tb_adapter 实际架构 | 双二进制互斥分发（TK 276K + TB 6.9M 自包含 WindMill）|
| 是否有 nosdk 方案 | ❌ 没有（nosdk 关键词只指 Sigmob `-NoSDK` Adapter pod）|
| 是否有单 podspec + 单 binary | ❌ 没有（是双 podspec + 双 binary 互斥）|
| 用户记忆偏差 | 记忆中的「单包全量方案」实际是 Phase 5A.5（已被双二进制替代）|
| Phase 5A.5 单包全量方案 | 曾编译通过，但未真机验证，后被双二进制替代（回退原因：WindFoundation 同名覆盖风险）|
| tb_adapter HEAD 状态 | `086a766`，本地领先 origin 1 commit，未 push，打到 backup/phase-5a-dual-binary-stable |
| TB 源码完整度 | ✅ FlameTBProvider + TbRewardAdapter 完整（业务逻辑成熟）|
| TK 源码完整度 | ✅ FlameTKProvider + 6 At*Adapter 完整 |
| 与 Phase 5A.12 匹配度 | 低（约 30%）：源码可复用，构建/架构/注册机制完全不同 |
| 是否建议基于 tb_adapter 继续 | ❌ 不建议（会丢失 Phase 5A.10/5A.11/5A.12 全部成果）|
| 是否建议 research/thin-core-binary 继续主线 | ✅ 建议（已继承全部源码 + 演进到 Phase 5A.12）|

**关键历史脉络**（纠正用户记忆）：

```
Phase 5A.1  ToBid Reward 代码审查修复
Phase 5A.3  #ifdef HAS_TOBID 条件编译
Phase 5A.4  双 xcframework + subspec
Phase 5A.5  单包全量方案（一个 podspec + 一个 binary）← 用户记忆的来源
            编译通过，但未真机验证，WindFoundation 同名覆盖风险
            ↓ 回退
双二进制互斥分发（tb_adapter HEAD 086a766）← 兜底稳定方案
            TK 276K（不打包 WindMill）+ TB 6.9M（自包含 WindMill）
            ↓ 调研
Phase 5A.10 Thin Core 可行性调研（2026-06-17，纯调研）
            ↓ 创建 research/thin-core-binary 分支
Phase 5A.10 Step 1-4D Thin Core 实现 + 正式化
Phase 5A.11 三包方案（Scheme E：core + tk-plugin + tb-plugin）
Phase 5A.12 单二进制方案（一个 binary 同时含 TK/TB 胶水）← 当前主线
```

**等待用户决策**：
1. 口径选择（Phase 5A.12 Step 1b 遗留：A 还是 B）
2. 口径确认后进入 Step 2 真机验证
3. tb_adapter / backup 分支保留作兜底，不删除

**红线遵守**：未发布、未 push、未 tag、未 pod repo push、未合并、未 cherry-pick、未修改 tb_adapter 分支、未修改主工作区。

**worktree 清理建议**：
- `flame_ios_sdk_tb_adapter_inspect` worktree 可保留供后续查阅，或用 `git -C flame_ios_sdk worktree remove flame_ios_sdk_tb_adapter_inspect` 清理（不影响 tb_adapter 分支本身）
