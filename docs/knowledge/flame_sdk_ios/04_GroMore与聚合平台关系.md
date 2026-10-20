# 04 · GroMore 与聚合平台关系

> 硬约束事实：**现有 Flame Ads SDK 没有 Direct GroMore。**
> `CURRENT_DIRECT_GROMORE = NONE`

> **2026-10-20 P1-R1 更新**：下文"TK 线 13+ 源"中的「私有 Sigmob（flame_sdk_ios_tk_sigmob_adapter）」
> 已退役，TK 改用 Taku 官方原生 `AnyThinkMediationSigmobAdapter 5.1.3.2.0`（自带 SigmobAd-iOS 5.1.3），
> TK podspec 的 ToBid-iOS-RC 依赖同步移除。历史背景见 doc 26。其余源清单不变。

## 架构事实

Flame 的广告一级聚合平台只有两家，运行期由服务端下发 `pt` 字段二选一：

| 线 | pt | 平台 SDK | 版本 | GroMore 到达路径 |
|---|---|---|---|---|
| TK | "tk" | TopOn / AnyThink（AnyThinkiOS） | 6.5.71 | `AnyThinkMediationGromoreAdapter` **7.6.0.4.2.0**（TK podspec dependency） |
| TB | "tb" | ToBid / WindMill（ToBid-iOS-RC） | 5.5.6 | `ToBid-iOS-RC/GromoreAdapter` **5.5.6**（与 CSJ 共享 BUAdSDK 7.6.0.4） |

- GroMore 是两线的**间接广告源**：Flame 源码（grep `GroMore|Pangle|穿山甲|BUAdSDK|CSJ`）仅命中注释，**零直接 API 调用**
- Flame 不配置/不初始化 GroMore：GroMore 账号在 TopOn / ToBid 后台瀑布流配置，其 SDK 由聚合平台按需初始化
- Flame 对**聚合平台**有 Adapter（At*/Tb* 共 12 个），对**广告源（含 GroMore）无 Adapter 层**——广告源适配由 TopOn/ToBid 官方 adapter 完成

## 平台选择机制

- 单二进制同时内置 TK/TB 胶水；`FlameTKProvider`/`FlameTBProvider` 的 `+load` 在 dyld 加载时向 `FlameMediationRegistry` 注册 "tk"/"tb"
- init 配置拉取成功后按 `pt` 从 Registry 取 Provider，`FlameMediationRouter` 激活；只有被激活的 Provider 才 `initializeWithAppId`
- Mach-O 隔离：AnyThinkSDK 弱链接（TB 客户不加载，避免 ADX 完整性弹窗）+ WindMill 静态归档隔离（U 引用 lazy binding）

## 两条线的广告源清单（podspec 事实）

- **TK 线 13+ 源**：AnyThinkMediation AdxSmartdigimktCN / **Gromore** / Baidu / MS / ZY / Funlink / BeiZi / KuaiShou / 私有 Sigmob（flame_sdk_ios_tk_sigmob_adapter 4.20.12.2.0，去 SigmobAd-iOS 传递依赖防 WindSDK 冲突）/ TTAdapter_Mix / GDT + AdGainSDK(+Taku) + FSUnionAdSDK
- **TB 线 8 源**（全部 5.5.6 subspec）：CSJ(穿山甲) / **Gromore** / GDT(优量汇) / Baidu / KS(快手) / Mintegral(国内) / Octopus(章鱼) / MSAd(美数)；Sigmob 由 ToBid Core 内置
- TK/TB 两个 pod 互斥，不可同时接入；module_name 均为 `flame_sdk_ios`，import 一致
