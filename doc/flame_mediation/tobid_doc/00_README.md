# Flame iOS SDK 多聚合平台可扩展架构文档

> 本文档集位于 `doc/flame_mediation/tobid_doc/`，覆盖 Flame iOS SDK 从"仅支持 TopOn"到"多聚合平台可扩展架构"的完整改造设计与实施计划。ToBid 是第一个新增平台。

## 文档索引

| 编号 | 文件名 | 内容 |
|------|--------|------|
| 00 | [README.md](./00_README.md) | 本文件，文档索引与概述 |
| 01 | [current_sdk_context.md](./01_current_sdk_context.md) | 当前 SDK 接入现状分析（TK 接入方式、初始化链路、后台配置） |
| 02 | [multi_mediation_architecture.md](./02_multi_mediation_architecture.md) | 多聚合平台可扩展架构设计（核心） |
| 03 | [backend_config_and_cache.md](./03_backend_config_and_cache.md) | 后台配置结构与缓存策略设计 |
| 04 | [tobid_integration_notes.md](./04_tobid_integration_notes.md) | ToBid 接入专项笔记 |
| 05 | [implementation_plan.md](./05_implementation_plan.md) | 分阶段实施计划与文件清单 |
| 06 | [risk_and_rollback.md](./06_risk_and_rollback.md) | 风险评估与回滚方案 |
| 07 | [claude_compact_context.md](./07_claude_compact_context.md) | Claude AI 紧凑上下文（用于跨会话恢复） |
| 08 | [next_stage_prompt.md](./08_next_stage_prompt.md) | 下一阶段 Prompt（用于开启新会话继续实施） |
| 09 | [change_log.md](./09_change_log.md) | 变更日志 |

## 目录结构说明

```
doc/flame_mediation/
  tobid_doc/              <-- 当前阶段文档（TK → TB 架构改造）
  csj_doc/                <-- 未来：穿山甲接入
  gdt_doc/                <-- 未来：优量汇接入
  sigmob_doc/             <-- 未来：Sigmob 接入
  common_architecture/    <-- 未来：跨平台共用架构文档
```

## 核心设计原则

1. **对外 API 不变** — 接入方 App 不感知底层使用哪个聚合平台
2. **mediation 内部类不暴露** — `FlameMediationProvider`、`FlameMediationRegistry`、`FlameMediationRouter`、`FlameTKProvider`、`FlameTBProvider` 等均属于 SDK 内部实现，不导入 `flame_sdk_ios.h` 伞头文件，不对接入方 App 公开
3. **平台数量不写死** — 不是 tk/tb 双分支，而是 Provider + Registry 可扩展架构；Registry key 使用 `NSString *platformCode`（如 `@"tk"`、`@"tb"`），不使用 `NS_ENUM` 限制平台数量
4. **Impl 层零 if-else** — `FlameRewardAdImpl` 等不包含任何平台判断逻辑
5. **新增平台最小改动** — 新增平台 = 新 Provider + 新 Adapter + 一行注册
6. **Provider 注册在统一入口** — Provider 注册发生在 `registerAllProviders` / Registry bootstrap 中，不在 `create*Ad` 中注册；广告创建链路只通过 Router 获取当前 Provider
7. **TK 代码轻量封装** — 现有 TopOn 适配器保留，仅加 Provider 壳
8. **缓存网络优先** — 每次冷启动 `init` 优先请求后台配置；网络成功则更新缓存；网络失败则 fallback 使用本地缓存（如完整）；不采用 24 小时 TTL 作为主刷新策略
9. **当前阶段不实现广告位级平台路由** — 只做 App 级平台路由，`pIds` 只支持 `Dict<String, String>`

## 状态

- [x] 现状分析完成
- [x] 架构设计完成
- [ ] 代码实施
- [ ] 测试验证

## 参考资源

- 现有 TK 对接文档: `doc/tk_doc/`
- ToBid 官方资料: `doc/tobid_doc/` (ToBidDemo官方、sdk集成下载说明) — 注意此 `doc/tobid_doc/` 是 ToBid 官方资料目录，与架构文档目录 `doc/flame_mediation/tobid_doc/` 无关
- Flame SDK 对接说明: `doc/flame_doc/`
