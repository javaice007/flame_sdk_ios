# Phase 5A.10 Step 4D — TB 后台未注册确认记录

> **分支**：`research/thin-core-binary`
> **状态**：结论记录（未修改代码 / 未改构建脚本 / 未改 podspec / 未发布 / 未 tag / 未 push origin / 未进 Phase 6）
> **日期**：2026-06-18

---

## 1. 背景

Phase 5A.10 方案 D 本地验证阶段，TB 变体真机运行后观察到：

* TK 链路已完整跑通（Splash / Interstitial 加载并展示成功，详见 Step 4 运行日志分析）；
* TB 代码链路已跑通（`+load → Router → FlameTBProvider → TbRewardAdapter → WindMill`）；
* TB Reward 加载时 ToBid 后台返回业务错误：

  ```
  ERROR | ToBid | strategyDidError:
  {"code":800031, "subCode":"106",
   "message":"API请求出现错误+code:500409+message:AppId没有绑定到ToBid聚合服务,请核对请求的AppId:74518"}
  ```

* 该问题曾准备作为 Step 4D 深挖 `74518` 来源；
* 经确认，**这是 ToBid 后台应用未注册/未绑定导致的业务校验失败，不是 SDK bug**。

本记录正式取消 Step 4D 的 `74518` 来源深挖任务，归档为「外部后台配置未完成」结论。

---

## 2. 当前 TB 链路状态

从真机日志（`log.log`）逐项确认 TB 代码链路全部正常：

| 链路节点 | 日志证据 | 状态 |
|---------|---------|------|
| `FlameTBProvider +load` 自动注册 | `FlameTBProvider: +load 自动注册完成 (plugin 模式, platformCode=tb)` | ✅ |
| `FlameMediationRegistry` 注册平台 `tb` | `FlameMediationRegistry: 注册平台 'tb'` | ✅ |
| `FlameMediationRouter` 激活 `tb` | `FlameMediationRouter: 激活平台 'tb'` / `Router 已激活 Provider (pt=tb)` | ✅ |
| FlameTBProvider 初始化 | `■ 初始化成功 \| 耗时 0.742s` | ✅ |
| TbRewardAdapter 被正确调用 | `[RewardVideo] 开始加载` → `FlameTBProvider` → `Start loading Reward Ad` | ✅ |
| WindMill 初始化 | `WindMillRewardVideoAdManager.init` / `WindMillRewardVideoAd.init` | ✅ |
| Reward 请求进入 ToBid 后台 | `strategyDidRequest: {"load_id":"..."}` | ✅ |
| ToBid 后台返回业务错误 | `strategyDidError: code 800031` | ⚠️ 外部后台配置 |

附加健康度检查：

* 无 crash；
* 无 dyld（OpenSSL.framework 已正确 embed，Step 2B 坑 4 修复生效）；
* 无 duplicate class（TK/TB 互斥，符号边界清晰）；
* Reward 请求成功送达 ToBid 后台并收到业务错误响应（说明网络层、签名、协议均正常）。

---

## 3. 失败原因归类

| 现象 | 归因 |
| ---- | ---- |
| `AppId没有绑定到ToBid聚合服务` | ToBid 后台应用尚未注册/绑定 |
| `74518` 出现在 ToBid 报错中 | 平台内部参数/转化层结果，不对接入方暴露，**不再追查来源** |
| Reward 加载失败 | 外部后台配置未完成，不是 SDK 链路异常 |

---

## 4. 是否需要 SDK 修改

**结论：不需要修改 SDK。**

理由：

1. TB Provider 已正确注册（`+load` 自动注册到 FlameMediationRegistry）；
2. Router 已正确激活 TB（`pt=tb` 激活 FlameTBProvider）；
3. Reward 已正确进入 TbRewardAdapter（不是 AtRewardAdapter）；
4. WindMill 已正常初始化（`WindMillRewardVideoAdManager.init` / `WindMillRewardVideoAd.init`）；
5. 错误来自 ToBid 后台业务校验（`code 800031`，AppId 未绑定），不是 SDK 抛出的异常；
6. 后台绑定完成后可直接复测，无需改代码。

---

## 5. 是否阻塞方案 D

**结论：不阻塞 Phase 5A.10 方案 D 本地验证收口。**

需明确标注的边界：

* 不代表 TB Reward 已完成真实填充验证；
* TB Reward 真实填充需等待 ToBid 后台应用注册/绑定完成；
* 后续 Phase 6 或发布前需补一轮 TB 后台就绪后的 Reward 复测。

---

## 6. 后续待办

1. ToBid 后台注册/绑定应用（外部运营/平台侧操作）；
2. 确认内部 ToBid AppId 与转化层配置一致；
3. 复测 TB Reward 加载；
4. 验证 Reward `load → show → reward → close` 全生命周期；
5. 确认日志无 SDK crash / dyld / duplicate class。

---

## 7. 当前阶段限制

本记录为纯文档归档，未做任何工程改动：

* 未修改代码；
* 未修改构建脚本（`xcFramework_build.sh`）；
* 未修改 podspec（`flame_sdk_ios.podspec` / `flame_sdk_ios_tb.podspec`）；
* 未执行构建；
* 未发布；
* 未 tag；
* 未 push origin；
* 未进入 Phase 6。
