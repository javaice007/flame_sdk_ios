# Flame iOS SDK 变更日志

> 本文件记录 Flame iOS SDK 的关键架构变更与发布里程碑。
> 详细阶段报告见同目录 `phase-*.md`。

---

## Phase 5A.13（进行中）— AnyThink 弱链接方案正式纳入

### Step 1.3：正式化与 TK 真机冒烟验收（本次 commit）

**变更类型**：架构依赖边界正式化（非破坏性）

**核心改动**：

| 文件 | 改动 | 目的 |
|------|------|------|
| `flame_sdk_ios_tb.podspec` | 移除 `s.dependency 'AnyThinkiOS', '6.5.71'` | TB 客户不再携带 AnyThinkSDK.framework，消除 ADX 弹窗 |
| `flame_sdk_ios.podspec` | `flame-sdk-tk-sigmob-adapter` → `flame_sdk_ios_tk_sigmob_adapter`（hyphen→underscore） | 旧版 TK podspec 使用了错误的 Sigmob Adapter 依赖名；使用该版本 spec 安装时可能导致依赖解析失败。本阶段已修正为实际存在的 underscore 形式（与 flame-specs 实际发布的 spec 名一致） |
| `flame_sdk_ios.podspec` 注释 | 补充说明 binary 已弱链接，AnyThinkiOS 由 TK podspec 独家带入 | 文档清晰化 |

**前置（c40e4fe 已完成，Step 1.2B PoC）**：

| 文件 | 改动 | 目的 |
|------|------|------|
| `xcFramework_build.sh` | 新增 AnyThinkSDK 弱链接 patch（-framework → -weak_framework，幂等 + fail-fast + 后置 otool 双断言） | binary 对 AnyThinkSDK 改为 LC_LOAD_WEAK_DYLIB |
| `flame_sdk_ios/mediation/tk/FlameTKProvider.m` | `initializeWithAppId:` 入口加 `NSClassFromString(@"ATAPI")` 守卫 | pt=tk 但 AnyThink 缺失时返回明确错误回调（TK_PLATFORM_REQUIRES_ANYTHINK），不崩溃不 silent fallback |

**验证**：

| 项 | 结果 |
|---|---|
| SDK 构建（含 otool 弱链接双断言） | BUILD EXIT 0 ✅ |
| TB 真机冷启动 3/3 无 ADX 弹窗 | ✅（Step 1.2B 已验证，3/3） |
| TB Reward 3 轮闭环 | ✅（Step 1.2B 已验证，load/show/visible/reward/close/next-load） |
| TK 真机冒烟 | ✅（Step 1.3，全广告位正常加载，无 TK_PLATFORM_REQUIRES_ANYTHINK） |
| TK App Frameworks 含 AnyThinkSDK.framework + SmartdigimktSDK.framework | ✅ |
| TB App Frameworks 不含 AnyThinkSDK.framework | ✅ |
| Flame binary LC_LOAD_WEAK_DYLIB | ✅ |
| 公共 API 未变 | ✅ |
| 单一 XCFramework（不拆 TK/TB 二进制） | ✅ |

**红线遵守**：

- ❌ 未 push / 未 tag / 未发布
- ❌ 未修改远程 flame-specs
- ❌ 未调用 AnyThink 私有 API（仅 `NSClassFromString(@"ATAPI")`，ATAPI 是 AnyThinkiOS 6.5.71 公开 Header）
- ❌ 未增加 AnyThink ADX 组件
- ❌ 未修改后台 pt 路由
- ❌ 未升级 AnyThink/ToBid/Sigmob 版本
- ❌ 未修改版本号（仍为 1.0.0-alpha.4-local）

**业务影响**：

- **TB 客户**：消除 "AnyThink Adx SDK 重要组件缺失" 弹窗（此前每次冷启动必现）
- **TK 客户**：修复 sigmob adapter 依赖名 bug（此前 `pod install` 直接报 spec 找不到）
- **双线客户**：公共 API 不变，无需改动接入代码

**新增非阻塞问题（登记，不在本 commit 处理）**：

- TB Reward 奖励回调后 3 次 NSURLErrorDomain -1002（`?sdkVersion=5.5.6&appId=16990`）
- 高概率推断来源：Sigmob WindSDK S2S 奖励回调上报（rvCallbackURL 为空）
- 详见 `phase-5a.13-step1.2b-tb-anythink-runtime-isolation-poc-report.md` "附" 章节

---

## Phase 5A.12（已完成）— 单二进制架构 + 双 podspec 发布

详见：
- `phase-5a.12-single-binary-mainline.md`
- `phase-5a.12-step3d-release-docs-and-customer-guide-cleanup-report.md`

核心：
- 一个 `flame_sdk_ios.xcframework`（300K）同时内置 TK/TB 胶水
- 两个 podspec：`flame_sdk_ios`（TK）/ `flame_sdk_ios_tb`（TB）
- +load 自动注册（FlameTKProvider / FlameTBProvider）
- FlameMediationRouter 按服务端 pt 激活对应 Provider
- 发布 1.0.0-alpha.1（远程 flame-specs）

---

## Phase 5A.11（已完成）— 三包方案（已被 5A.12 单二进制取代）

## Phase 5A.10（已完成）— thin core 调研（已被 5A.12 单二进制取代）
