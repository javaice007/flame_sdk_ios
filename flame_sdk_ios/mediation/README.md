# mediation/ — 聚合调度层

本目录是**聚合调度层（Provider 层）**：负责平台注册、平台初始化、决定创建哪个 Adapter。

> 维度说明：本目录是 **Provider 层**（平台注册 + 决定创建哪个 Adapter），
> `adapter/{tk,tb}/` 是 **Adapter 层**（具体广告类型如何 load/show/callback）。
> 同一个平台维度（tk/tb）出现在两个目录是正交分层，不是冗余。

## 根目录（平台中立）

- `FlameMediationProvider.h` — 平台 Provider 协议（声明各广告类型的 Adapter 创建方法）
- `FlameMediationRegistry.h/.m` — 平台注册表（注册可用 Provider）
- `FlameMediationRouter.h/.m` — 当前平台路由器（持有 `currentProvider`）
- `Flame*AdapterProtocol.h` — 各广告类型的**内部 Adapter 协议**：
  - `FlameRewardAdapterProtocol`
  - `FlameSplashAdapterProtocol`
  - `FlameInterstitialAdapterProtocol`
  - `FlameBannerAdapterProtocol`
  - `FlameNativeAdapterProtocol`

## mediation/tk/

TK 平台 Provider 层。

- `FlameTKProvider` — 负责初始化 TK / TopOn / AnyThink 平台，并创建 `At*Adapter`。

## mediation/tb/

TB 平台 Provider 层。

- `FlameTBProvider` — 负责初始化 ToBid / WindMill 平台，并创建 `Tb*Adapter`。

> 当前只实现 Reward，其余广告类型（Splash / Interstitial / Banner / Native）
> 仍返回 `nil`，占位到 Phase 6。

## Provider 与 Adapter 的区别

| 层 | 目录 | 职责 |
|----|------|------|
| Provider | `mediation/{tk,tb}/` | 平台注册、平台初始化、**创建哪个 Adapter** |
| Adapter | `adapter/{tk,tb}/` | **具体广告类型如何 load/show/callback 适配** |

## 当前广告创建链路

```
FlameSdk.create*Ad
  → FlameMediationRouter.currentProvider
  → FlameTKProvider / FlameTBProvider       （Provider 层，在本目录 {tk,tb}/）
  → At*Adapter / TbRewardAdapter            （Adapter 层，在 adapter/{tk,tb}/）
```

平台选择由编译期宏决定（`FLAME_BUILD_TK` / `FLAME_BUILD_TB`，见 `FlameSdk.m`
的 `registerAllProvidersIfNeeded`），运行时 `create*Ad` 方法无平台 if 分支。
