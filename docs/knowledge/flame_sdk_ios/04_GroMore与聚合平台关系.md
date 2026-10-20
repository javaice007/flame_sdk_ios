# 04 · GroMore 与聚合平台关系

> 硬约束事实：**现有 Flame Ads SDK 没有 Direct GroMore。**
> `CURRENT_DIRECT_GROMORE = NONE`
>
> **2026-10-20 P2-TK 更新（当前事实）**：TK 已升级到 Taku 稳定版 Core **6.5.84** 全矩阵
> （TTAdapter_Mix / GromoreAdapter 均为 7.8.0.5.2.1，共享同一套 Ads-CN/BUAdSDK 7.8.0.5）；
> TK 的 Sigmob 使用 Taku 官方原生 `AnyThinkMediationSigmobAdapter 5.1.3.2.0`，
> **TK 已不再依赖 ToBid**。历史私有 spec `flame_sdk_ios_tk_sigmob_adapter` 仅存在于
> 2026-10-20 之前的历史版本（1.0.0～1.0.2），已退役，见 doc 26。

## 架构事实

Flame 的广告一级聚合平台只有两家，运行期由服务端下发 `pt` 字段二选一：

| 线 | pt | 平台 SDK | 版本 | GroMore 到达路径 |
|---|---|---|---|---|
| TK | "tk" | TopOn / AnyThink（AnyThinkiOS） | **6.5.84**（P2-TK，Taku 稳定版） | `AnyThinkMediationGromoreAdapter` **7.8.0.5.2.1**（TK podspec dependency） |
| TB | "tb" | ToBid / WindMill（ToBid-iOS-RC） | 5.5.6 | `ToBid-iOS-RC/GromoreAdapter` **5.5.6**（与 CSJ 共享 BUAdSDK 7.6.0.4） |

- GroMore 是两线的**间接广告源**：Flame 源码（grep `GroMore|Pangle|穿山甲|BUAdSDK|CSJ`）仅命中注释，**零直接 API 调用**
- Flame 不配置/不初始化 GroMore：GroMore 账号在 TopOn / ToBid 后台瀑布流配置，其 SDK 由聚合平台按需初始化
- Flame 对**聚合平台**有 Adapter（At*/Tb* 共 12 个），对**广告源（含 GroMore）无 Adapter 层**——广告源适配由 TopOn/ToBid 官方 adapter 完成

## 平台选择机制（当前交付架构：两个独立生产包）

- Flame 公共源码保留 Provider/Registry/Router 抽象：`FlameTKProvider` 与 `FlameTBProvider`
  仍以 `+load` 向 `FlameMediationRegistry` 注册 "tk"/"tb"，`FlameMediationRouter` 按服务端 `pt` 激活；
  这是**代码结构**层面的共享设计，不代表交付形态是共包。
- 生产交付已拆为两个独立产品包：TK 根目录 `flame_sdk_ios.xcframework` **只含 TK 胶水**
  （零 WindMill 符号），TB `tb/flame_sdk_ios.xcframework` **只含 TB 胶水**（零 AnyThink 符号）；
  两个 podspec（`flame_sdk_ios` / `flame_sdk_ios_tb`）互斥，module 同名不可同时接入。
- 因此不存在"一个客户生产包同时携带 TK + TB 胶水"的正式交付方式；跨线符号隔离由构建期
  `EXCLUDED_SOURCE_FILE_NAMES` 与产物符号断言保证（见 doc 26/27/28）。

### 历史（仅存档）

早期曾以"单二进制"同时内置 TK/TB 胶水：1.0.0 为动态 framework（对 AnyThinkSDK 弱链接、
对 WindMill 用 `-undefined dynamic_lookup`），1.0.1-alpha.x 起改为静态全量编入。共包形态
导致 TB 客户 dyld 解析 WindMill 符号失败（1.0.0 闪退根因）以及 TK/TB 的 WindSDK 依赖冲突
（私有 Sigmob spec 的由来，见 doc 26）。该形态自 1.0.1-alpha.2 起被静态双线双包取代。

## 两条线的广告源清单（podspec 事实，2026-10-20 P2-TK 现状）

- **TK 线 13 源（Core 6.5.84）**：AnyThinkMediation AdxSmartdigimktCN 6.5.90.2.1 / **Gromore 7.8.0.5.2.1** /
  Baidu 10.061.2.0 / MS 3.0.15.0.2.0 / ZY 2.6.10.7.2.0 / Funlink 2.9.0.3.3.2.0 / BeiZi 5.5.6.0.2.0 /
  KuaiShou 5.9.10.1.2.0 / **Sigmob 官方原生 5.1.3.2.0** / TTAdapter_Mix 7.8.0.5.2.1 / GDT 4.16.10.2.0
  + AdGainSDK(+Taku adapter) 4.2.7.1 + FSUnionAdSDK 1.0.8.0（AdGain/FSUnion 为单独集成，非 Taku 下载中心范围，版本冻结）
- **TB 线 8 源**（全部 5.5.6 subspec）：CSJ(穿山甲) / **Gromore** / GDT(优量汇) / Baidu / KS(快手) / Mintegral(国内) / Octopus(章鱼) / MSAd(美数)；Sigmob 由 ToBid Core 内置
- TK/TB 两个 pod 互斥，不可同时接入；module_name 均为 `flame_sdk_ios`，import 一致

### 历史（仅存档，勿用于现有接入）

TK/TB 曾共用"单生产二进制"（1.0.0 动态、1.0.1 起静态双线同仓同 tag）。共包时代 TK 的 Sigmob
曾使用 Flame 私有 spec `flame_sdk_ios_tk_sigmob_adapter 4.20.12.2.0`：vendored TopOn 官方
AnyThinkSigmobAdapter 二进制、去掉 SigmobAd-iOS 传递依赖，WindSDK/WindFoundation 改从
ToBid-iOS-RC 5.5.6 借用，以规避同名 framework 冲突。TK/TB 拆分独立生产包后该前提消失，
P1-R1 已退役私有 spec；现存历史版本（1.0.0～1.0.2）仍可在 flame-specs 解析，但**不属于现行架构**。
详见 doc 26。
