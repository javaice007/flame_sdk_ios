# Phase 5A.10 — 方案 D 本地验证阶段总结

> **分支**：`research/thin-core-binary`
> **状态**：本地验证阶段（未发布 / 未 tag / 未 push origin / 未进 Phase 6）
> **最后更新**：2026-06-18

---

## 1. 阶段目标

Phase 5A.10 是「方案 D（两个对外 podspec + 一个内部 core binary）」的本地验证阶段。

**核心目标**：把 Flame SDK 改造为「客户只写一行 pod」的单 pod 接入模式：

```ruby
# TK 客户
pod 'flame_sdk_ios'

# TB 客户
pod 'flame_sdk_ios_tb'
```

接入方 import 保持统一（module name = `flame_sdk_ios`）：

```objc
#import <flame_sdk_ios/flame_sdk_ios.h>
#import <flame_sdk_ios/FlameSdk.h>
```

```swift
import flame_sdk_ios
```

**阶段红线**：不发布、不 tag、不 pod repo push、不 push origin、不进入 Phase 6、不实现 TB Splash/Interstitial/Banner/Native、不删除 backup 分支、不改 SDK 对外 API。

---

## 2. 已完成事项

按子阶段时间顺序：

| 子阶段 | 内容 | 报告 |
|--------|------|------|
| Step 1 | Core Thin Binary 构建验证（176K，零三方符号） | `phase-5a.10-step1-core-build-report.md` |
| Step 2 | 实验插件 podspec + 平台源码插件运行时验证（方案 C，2 pods） | `phase-5a.10-step2-plugin-runtime-report.md` |
| Step 2B | 方案 D 双 podspec + 单内部 core binary（客户单 pod，4 坑全解） | `phase-5a.10-step2b-two-podspec-report.md` |
| Step 3 | 方案 D 正式化落地（正式 podspec + 正式 wrappers + Core variant 文案修复） | `phase-5a.10-step3-formalization-report.md` |
| Step 4 | 正式测试态清理（删除 research/ + 旧 build/{core,tk,tb}） | `phase-5a.10-step4-cleanup-report.md` |
| Step 4B | 构建目录精简（输出从 `build/core_named/` 提升到 `build/` 顶层） | `phase-5a.10-step4b-build-dir-simplify-report.md` |
| Step 4C | 脚本默认变体修复（无参数默认 = core-named，不再误走 tk） | `phase-5a.10-step4c-default-variant-fix-report.md` |
| Step 4D | TB 后台未注册确认记录（取消 74518 深挖，归档为外部后台配置） | `phase-5a.10-step4d-tb-backend-not-ready-note.md` |

**关键里程碑**：

1. **Step 4B**：构建目录精简，正式产物为 `build/flame_sdk_ios_core.xcframework`；
2. **Step 4C**：脚本默认变体改为 `core-named`（无参数执行不再误走旧 tk）；
3. **TK 链路验证**：完整跑通（Splash / Interstitial 加载并展示成功，AnyThink 初始化 0.709s）；
4. **TB 链路验证**：代码链路跑通（`+load → Router → FlameTBProvider → TbRewardAdapter → WindMill`），后台未绑定导致 Reward 未填充；
5. **core-named 产物验证**：176K，零三方污染，22 headers，install_name 正确；
6. **podspec 指向 core-named 产物**：两 podspec 均为 `build/flame_sdk_ios_core.xcframework`。

---

## 3. 关键结论

| 项 | 结论 |
| ---- | ---- |
| thin core binary | 通过（176K，零三方符号） |
| 默认构建变体 | `core-named`（无参数 `./xcFramework_build.sh` 等同） |
| TK Provider plugin 链路 | 通过（+load → Router → FlameTKProvider → AtRewardAdapter → AnyThink） |
| TB Provider plugin 链路 | 代码链路通过（+load → Router → FlameTBProvider → TbRewardAdapter → WindMill） |
| TB Reward 填充 | 待 ToBid 后台绑定后复测（当前返回 800031 AppId 未绑定，非 SDK bug） |
| 是否有 SDK 架构阻塞 | 无 |
| 是否可进入 Phase 5A.10 收口 | 可以 |
| 是否可以发布 | 不在本阶段发布 |

---

## 4. 当前产物

### 4.1 Core binary

```
build/flame_sdk_ios_core.xcframework
```

| 属性 | 值 |
|------|-----|
| 体积 | 176K |
| framework 名 | `flame_sdk_ios_core.framework` |
| binary 名 | `flame_sdk_ios_core` |
| module 名 | `flame_sdk_ios_core` |
| install_name | `@rpath/flame_sdk_ios_core.framework/flame_sdk_ios_core` |
| otool -L | 仅 `@rpath/OpenSSL.framework/OpenSSL` + 4 系统库 |
| nm 三方符号 | 零（AnyThink/WindMill/Sigmob/AdGain/BUAd/CSJ/GDT/KSAd/Baidu/FSUnion/FlameTKProvider/FlameTBProvider/AtRewardAdapter/TbRewardAdapter 全无） |
| Headers | 22（10 公共 API + 12 内部协议） |
| 三方 bundle/metallib | 无 |

### 4.2 正式 podspec

| podspec | s.vendored_frameworks | module_name |
|---------|----------------------|-------------|
| `flame_sdk_ios.podspec` | `build/flame_sdk_ios_core.xcframework` | `flame_sdk_ios` |
| `flame_sdk_ios_tb.podspec` | `build/flame_sdk_ios_core.xcframework` | `flame_sdk_ios`（统一，TB 接入方 import 不变） |

两 podspec 均显式声明 `OpenSSL-Universal ~> 3.6` 依赖（避免真机 dyld crash，Step 2B 坑 4 修复）。

### 4.3 正式 wrappers

```
flame_sdk_ios/wrappers/
├── flame_sdk_ios/         # TK 转发头（10 个）
└── flame_sdk_ios_tb/      # TB 转发头（10 个）
```

转发头将 `#import <flame_sdk_ios/...>` 转发到 `<flame_sdk_ios_core/...>`。

---

## 5. 外部待办

1. **ToBid 后台注册/绑定应用**（运营/平台侧操作，非 SDK 侧）；
2. **TB Reward 后台就绪后复测**（验证 `load → show → reward → close` 全生命周期）；
3. **发布前真实 Demo 集成验证**（远端 podspec 而非 `:path =>` 本地路径）；
4. **Phase 6 发布前 checklist**：
   - 确认 `s.source` 的 zip 包含 `build/flame_sdk_ios_core.xcframework`（build/ 在 gitignore，换机器/CI 需先跑构建脚本）；
   - 确认 `use_frameworks! :linkage => :static` 在接入文档中强调；
   - TB Splash/Interstitial/Banner/Native 实现与否的决策。

---

## 6. 是否进入 Phase 6

**当前不自动进入 Phase 6。**

建议下一步由用户确认：

* **Phase 5A.10 Final 收口**（合并 `research/thin-core-binary` → `feat/tb_adapter`，可选清理 backup/旧 dual-binary）；
* 或 **Phase 6 发布准备**（pod repo push / tag / 远端 Demo 验证）。

Phase 5A.10 本地验证已具备收口条件，但发布决策不在本阶段自动触发。

---

## 附：阶段提交记录（research/thin-core-binary）

```
91054ba docs(thin-core): Phase 5A.10 Step 4C 脚本默认变体修复报告
c85021a fix(thin-core): Phase 5A.10 Step 4C 脚本默认变体改为 core-named
2ee4812 docs(thin-core): Phase 5A.10 Step 4B 构建目录精简报告
2f97fbe chore(thin-core): Phase 5A.10 Step 4B 构建目录精简
5759d2b docs(thin-core): Phase 5A.10 Step 4 正式测试态清理报告
d5eeba6 chore: clean thin-core formalization workspace
4fddaf2 docs(thin-core): Phase 5A.10 Step 3 正式化报告 + 接入说明草案
228f7d2 feat(thin-core): Phase 5A.10 Step 3 — 方案 D 正式化落地
8995484 docs(thin-core): 重写 Step 2B 报告为最终版(含 4 坑全解 + OpenSSL 修复后状态)
198c601 docs(thin-core): 补充方案 D 坑 4(OpenSSL 未 embed TB crash)到报告
ed56814 fix(thin-core): 方案 D podspec 显式声明 OpenSSL 依赖
87ed9e1 fix: restore xcFramework_build.sh executable permission
60223bc feat(thin-core): Phase 5A.10 Step 2B — 方案 D 双 podspec + 单内部 core binary
3d48065 feat(thin-core): Phase 5A.10 Step 2 — 实验插件 podspec + 平台源码插件运行时验证
f4b794b docs(thin-core): Phase 5A.10 Step 1 构建验证报告
4bcecb9 feat(thin-core): Phase 5A.10 Step 1 — Core Thin Binary 构建验证
```

backup 分支 `backup/phase-5a-dual-binary-stable` 保留（旧 dual-binary 兜底）。
