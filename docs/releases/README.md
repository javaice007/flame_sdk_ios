# Flame iOS SDK 版本索引

> 本文件维护 Flame iOS SDK 的发布版本索引。每个版本对应同目录下一个 `<version>.md` 快照文件。

| 版本号 | 发布日期 | 版本性质 | Git Tag | 主要更新 | 详情 |
|---|---|---|---|---|---|
| **1.0.1-alpha.4** | 2026-08-31 | 发奖修复修正版（按 Taku 官方文档） | `1.0.1-alpha.4` | transId 只回传平台真实交易号（TK＝展示唯一ID kATADDelegateExtraIDKey；TB＝ToBid transId），平台未回传为空串、不本地伪造；移除无文档依据的 third_trans_id 与 thirdTransId 混用；TK userCustomData 补写 MediaExtraKey 服务端回传通道；双线来源诊断日志 | [1.0.1-alpha.4.md](./1.0.1-alpha.4.md) |
| 1.0.1-alpha.3 | 2026-08-31 | **发奖回调修复版** | `1.0.1-alpha.3` | TK 线 transId 恒空修复（localExtra key 只读不写）；TB 线 userCustomData 恒空修复 + userId/transId 兜底；产物结构与依赖不变 | [1.0.1-alpha.3.md](./1.0.1-alpha.3.md) |
| 1.0.1-alpha.2 | 2026-08-26 | P0 修复预发布版 | `1.0.1-alpha.2` | 修复 TB 包打包缺陷（xcframework 外壳名与内部 framework 名不一致导致客户无法开箱构建）；TB 产物迁至 tb/ 子目录；双线版本 1.0.1-alpha.2 | [1.0.1-alpha.2.md](./1.0.1-alpha.2.md) |
| 1.0.1-alpha.1 | 2026-08-26 | P0 修复预发布版（**TB 包已废弃**：真机不闪退但打包缺陷无法开箱构建；TK 包验证通过） | `1.0.1-alpha.1` | 修复公开 Pod 1.0.0 接入即 dyld 闪退；TK/TB 双线切换静态产物 | [1.0.1-alpha.1.md](./1.0.1-alpha.1.md) |
| 1.0.0 | 2026-07-21 | 正式稳定版（**已废弃**：接入即闪退，勿用） | `1.0.0` | TK/TB 双线正式版；单二进制（动态）；后被证实动态产物对 ToBid 静态归档符号解析方式有致命缺陷 | [1.0.0.md](./1.0.0.md) |
| 1.0.0-alpha.2 | 2026-07-21 | 预发布验证版 | `1.0.0-alpha.2` | TK/TB 双线预发布验证；ToBid 5.5.6 广告源扩展（8 个 Adapter）；Native Express/SelfRender 双路径真机通过；AnyThink 弱链接 + TB 隔离 | [1.0.0-alpha.2.md](./1.0.0-alpha.2.md) |

## 后续版本规划

（暂无）

## 历史版本

- **1.0.0-alpha.1**：单二进制架构首次发布（Phase 5A.12 mainline，远程 flame-specs）；详见阶段报告 `doc/flame_mediation/phase-5a.12-*.md`。本仓库 `docs/releases/` 不追溯补建该版本快照。
- **1.0.0-alpha.4-local / 1.0.0-alpha.4**：研发期本地版本号（Phase 5A.12 Step 3 系列实验），**未对外发布**；1.0.0-alpha.2 已统一替换为正式预发布版本号。| **1.1.1** | 2026-10-29 | 正式稳定版（Bugfix：百度开屏图文崩溃修复） | `1.1.1` | TK 百度 Adapter 10.061.2.0→10.070.2.0（Core 6.5.84 不变）；TB ToBid 5.10.1→5.10.3 官方全套（百度 10.070）；公共 API 零差异；双线真机百度开屏 25+ 轮零崩溃 | [1.1.1.md](./1.1.1.md) |
| 1.1.0 | 2026-10-20 | 正式稳定版（双线大版本升级） | `1.1.0` | TK Taku 6.5.84 全矩阵 + 官方 Sigmob Adapter；TB ToBid-iOS 5.10.1 全矩阵 + JuTui/AdScope/Kuying 新增；双线静态产物 | [1.1.0.md](./1.1.0.md) |

