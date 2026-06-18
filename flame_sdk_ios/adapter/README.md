# adapter/ — 广告类型适配层

本目录是**广告类型适配层**：把上游平台（AnyThink / WindMill 等）的具体广告对象，
适配成 Flame 内部统一的 `Flame*AdapterProtocol` 协议。

> 维度说明：`mediation/{tk,tb}/` 是 **Provider 层**（平台注册 + 决定创建哪个 Adapter），
> `adapter/{tk,tb}/` 是 **Adapter 层**（具体广告类型如何 load/show/callback）。
> 同一个平台维度（tk/tb）出现在两个目录是正交分层，不是冗余。

## adapter/tk/

存放 TK / TopOn / AnyThink 的广告类型 Adapter：

- `AtRewardAdapter` — 激励视频
- `AtSplashAdapter` — 开屏
- `AtInterstitialAdapter` — 插屏
- `AtBannerAdapter` — 横幅
- `AtNativeAdapter` — 原生（含 `AtNativeSelfRenderView` 自渲染视图）

这些类负责把 AnyThink 的广告对象适配成 Flame 内部统一协议
（`FlameRewardAdapterProtocol` / `FlameSplashAdapterProtocol` 等）。

## adapter/tb/

存放 TB / ToBid / WindMill 的广告类型 Adapter：

- `TbRewardAdapter` — 激励视频（Phase 5A 已实现）

> TB 的 Splash / Interstitial / Banner / Native **尚未实现**，属于后续 Phase 6 范围。
> 当前不在此目录创建占位文件。

## FlameAdapterManager（历史保留类）

`adapter/FlameAdapterManager` 是历史类，**不是当前广告创建入口**。

当前剩余职责：

1. `checkInitialization` / `isInitialized` — 初始化状态守卫（被 `ads/*Impl.m` 调用）
2. `setDebug:` — 调试开关（TK 变体开启 AnyThinkSDK 日志）
3. `initSDKWithAppId:appKey:initListener:` — TK 初始化桥接（被 `FlameTKProvider` 复用）

> 历史的 5 个工厂方法 `createRewardAdapter:` / `createInterstitialAdapter:` /
> `createSplashAdAdapter:` / `createBannerAdapter:` / `createNativeAdapter:` 已删除（零调用死代码）。

## 当前广告创建链路

```
FlameSdk.create*Ad
  → FlameMediationRouter.currentProvider
  → FlameTKProvider / FlameTBProvider       （Provider 层，在 mediation/{tk,tb}/）
  → At*Adapter / TbRewardAdapter            （Adapter 层，在本目录）
```
