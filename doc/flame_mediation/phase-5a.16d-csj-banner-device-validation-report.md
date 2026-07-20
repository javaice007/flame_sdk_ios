# Phase 5A.16D：CSJ Banner 后台配置、真机填充与完整生命周期验收

> **本阶段状态**：**进行中（首次请求与 no-fill 阻塞）**。链路与 Adapter 实现已验证，CSJ 渠道被正确选中并真实请求，但 CSJ 后台返回 `no ads`（`800110` / `20001`）。成功路径（load success → retrieveAdView → addSubview → exposure → refresh → click → destroy → re-enter）尚未验证。等待用户核查 CSJ/ToBid 后台配置 + 尺寸后重新 Run。
>
> **口径**：本报告如实记录已验证项与未验证项，不写"Phase 5A.16D 已完成"或"Banner 完整接入已通过"。

---

## 1. 基线

| 项 | 值 |
|---|---|
| SDK 开始 HEAD | `e5ff1ad`（Phase 5A.16C Banner Adapter 实现） |
| SDK 结束 HEAD | 本阶段**未创建 commit**（报告先行，等 fill 后统一收口） |
| Demo HEAD | `11c5958`（Demo 代码零改动） |
| Demo 本地临时配置 | `FlameAdConfig.PlacementId.banner = "q<REDACTED>"`（不提交） |
| Demo 本地 Info.plist | +21 CSJ SKAdNetworkItems + NSUserTrackingUsageDescription（不提交） |
| TB Podfile.lock | 5 pods（flame_sdk_ios_tb + ToBid-iOS-RC/CSJAdapter + Ads-CN/BUAdSDK + OpenSSL + FunlinkSDK） |
| 真机日志 | `pasted-text-20260720-114846-7901cf34.txt`（2026-07-20 11:48:31 启动） |

---

## 2. 5A.16C 口径修正（已落地）

Phase 5A.16C 报告已修正（见该报告 §20/§33）：
- AnyThink 隔离 → "静态依赖隔离 + LC_LOAD_WEAK_DYLIB 无回归；运行时无 ADX 弹窗将在 Phase 5A.16D 真机验证"
- TB BUILD → "iphoneos 设备目标 BUILD SUCCEEDED；尚未等同于 Banner 真机运行验证"
- SelfRenderBanner 仅为现有协议占位，不属于 5A.16C/16D 验收范围

---

## 3. 两层 placementId 映射（§11，已验证）

本阶段**首次取得 Banner 链路的两层 placementId 分离证据**：

| 层级 | 值 | 日志证据 |
|---|---|---|
| **Demo / Flame 对外** | `q<REDACTED>` | Demo `FlameAdConfig.PlacementId.banner` |
| **Flame pMap 映射后**（ToBid 聚合 ID） | `7316148691848522` | `[TB_BANNER_DIAG] load: placementId=7316148691848522` |
| **CSJ 网络 placement** | `948459823` | ToBid `template[1].dispatch [7316148691848522] - 13-948459823` |

**确认**：
- pMap 映射生效（`q<REDACTED>` → `7316148691848522`，两者不同层级）
- `TbBannerAdapter` 只看到映射后的 ToBid ID（`self.placementId = 7316148691848522`）
- ToBid 内部再分发到 CSJ 网络 placement `948459823`

> 满足任务要求：Demo/Flame 请求的是 `q<REDACTED>`，`[TB_BANNER_DIAG]` 中实际传给 ToBid 的是映射后的 `7316148691848522`，两者不是同一层级。

---

## 4. CSJ 来源证据（§11.1，已验证）

ToBid 日志明确证明 CSJ 渠道被选中：

```
11:48:35:035 | ToBid | template[1].dispatch [7316148691848522] - 13-948459823
11:48:35:035 | ToBid | initializeAdapterBefore: 13, version: 7.6.0.4
11:48:35:035 | ToBid | initializeAdapterSuccess: 13, version: 7.6.0.4
11:48:35:035 | ToBid | [CSJ] | [Object] | BannerAdAdapter[3953133325600364403].init
11:48:35:035 | ToBid | [onReport] AdDidLoadStart: {"networkId":13,"placementId":"7316148691848522","networkPlacementId":"948459823",...}
```

- `networkId: 13` = `WindMillAdnCSJ`（CSJ/Pangle/穿山甲）
- `WindMillCSJAdapter` 初始化成功（`BannerAdAdapter.init`）
- `BUAdSDK 7.6.0.4` 初始化成功（`initializeAdapterSuccess: 13, version: 7.6.0.4`）
- CSJ Banner 请求真实发出（`AdDidLoadStart`）

**不是其他广告源填充**（不是 Sigmob networkId=9），**是真实的 CSJ 请求**。

---

## 5. no-fill 错误链路（§11，已验证完整回调映射）

```
11:48:35:035 | ToBid | [CSJ] | nativeExpressBannerAdView(_:didLoadFailWithError:)
11:48:35:035 | ToBid | [1]onTemplateDidCallbackError[7316148691848522]: {"code":800110,"message":"无广告返回，各adn的详细错误信息请在广告平台相关报表查看"}
11:48:35:035 | ToBid | [onReport] AdDidLoadFailed: 13-948459823, error: {"code":20001,"message":"no ads"}
[FlameSDK] [TB_BANNER_DIAG] didFailToLoad: banner=0x14cf52300 isCurrent=1 code=800110 desc=无广告返回，各adn的详细错误信息请在广告平台相关报表查看
[Banner] 11:48:35.968 错误: 800110 无广告返回，各adn的详细错误信息请在广告平台相关报表查看
```

**完整链路验证**（Phase 5A.16C 实现的回调映射首次真机触发）：
- CSJ BUAdSDK 回调 `nativeExpressBannerAdView:didLoadFailWithError:` →
- ToBid `onTemplateDidCallbackError` →
- `TbBannerAdapter` `bannerAdViewFailedToLoad:error:`（stale 守卫通过，isCurrent=1）→
- `[TB_BANNER_DIAG] didFailToLoad` →
- `FlameBannerListener onAdError:desc:`（code=`800110`，desc=ToBid 错误信息）→
- Demo `[Banner] 错误: 800110`

> **回调映射正确**：error code 透传 ToBid 的 `800110`（业务层错误码），不是 NSError.code。这证明 `TbBannerAdapter.m` 的 `bannerAdViewFailedToLoad:error:` 实现正确（code=`%ld` of error.code，但 ToBid 在 `onTemplateDidCallbackError` 中已封装为 `800110` 字符串）。

### 5.1 错误码含义（不臆断根因）
- `800110`（ToBid 业务层）："无广告返回，各 adn 的详细错误信息请在广告平台相关报表查看"
- `20001`（ToBid 内部）："no ads"
- **根因待后台核查**：可能是广告位未审核 / 白名单缺失 / Bundle ID 不匹配 / waterfall 配置 / 尺寸不一致 / 流量策略。本报告不臆断，列为待核查项（§10）。

---

## 6. Adapter 不重试 + Demo RetryScheduler（§11.2，已验证）

```
[FlameSDK] [TB_BANNER_DIAG] destroy: adapter=0x14d540e10 banner=0x14cf52300 hasSuperview=0
[Banner] 11:48:35.969 2s 后重试 (1/5)
...
[FlameSDK] [TB_BANNER_DIAG] destroy: adapter=0x14eaaf0c0 banner=0x14eecc280 hasSuperview=0
[Banner] 11:48:38.278 4s 后重试 (2/5)
```

**验证**：
- Adapter 收到 `didFailToLoad` 后**直接 destroy**（不内部重试，与 TK AtBannerAdapter 一致）
- Demo `RetryScheduler` 接管：第 1 次重试 2s 后，第 2 次 4s 后（指数退避，maxRetry=5）
- **无双重重试**（Adapter + Demo）
- 每次重试创建新 Adapter（`0x14d540e10` → `0x14eaaf0c0`）+ 新 WindMillBannerView（`0x14cf52300` → `0x14eecc280`）

---

## 7. 尺寸核对（§13，已诊断 — 尺寸非根因）

### 7.1 第一次 Run：expectSize={402, 50}（屏幕宽）
- Demo 用 `UIScreen.main.bounds.width`（iPhone 14/15 Pro = 402pt）× 50
- 日志：`expectSize={402, 50}`
- 结果：CSJ `800110` no-fill

### 7.2 第二次 Run：expectSize={320, 50}（CSJ 标准）
- Demo 本地临时改为 `width: 320`（CSJ 标准 Banner 尺寸）+ SwiftUI overlay `.frame(width: 320, height: 50)` 居中
- 日志：`expectSize={320, 50}`（确认尺寸调整生效）
- 结果：**仍 CSJ `800110` no-fill**（`BannerAdAdapter` init → `AdDidLoadStart networkId:13` → `onTemplateDidCallbackError code:800110` → `AdDidLoadFailed 20001 no ads`）

### 7.3 尺寸诊断结论
**尺寸不是 no-fill 的根因**：320×50 和 402×50 两次都返回相同的 `800110 / 20001 no ads`。CSJ 渠道被正确选中（networkId=13），WindMillCSJAdapter + BUAdSDK 7.6.0.4 初始化成功，请求真实发出，错误来自 CSJ 服务端（不是本地尺寸校验失败）。

### 7.4 后续尺寸处理
- Demo 本地临时保留 320×50（CSJ 标准，更接近后台配置）
- 不修改 SDK
- 不提交 Demo 临时尺寸配置
- 待 ToBid 技术支持确认测试位状态后决定最终尺寸

---

## 8. BUAdSDK SQLite 警告（§六）

```
duplicate column name: trackID in "ALTER TABLE buapplograptortrackermodel ADD COLUMN trackID TEXT;"
db_save_error: create table:buapplograptortrackermodel
duplicate column name: trackID in "ALTER TABLE bustatsraptortrackermodel ADD COLUMN trackID TEXT;"
db_save_error: create table:bustatsraptortrackermodel
duplicate column name: status in "ALTER TABLE meta_req_record ADD COLUMN status INTEGER DEFAULT 0;"
db_save_error: create table:meta_req_record
```

**中性表述**：BUAdSDK（CSJ SDK）内部 SQLite 表结构迁移警告（`buapplograptortrackermodel` / `bustatsraptortrackermodel` / `meta_req_record` 三张表 ALTER TABLE 时报 duplicate column）。当前**未导致崩溃或阻断请求**（CSJ 请求正常发出，no-fill 是后台返回而非本地错误）。**尚未取得官方结论，不表述为已知且完全无影响的问题**，列为观察项。

---

## 9. 已验证项（本阶段）

| 项 | 状态 | 证据 |
|---|---|---|
| pt=tb / Router 激活 tb | ✅ | `FlameMediationRouter: 激活平台 'tb'` |
| SDK 初始化成功 | ✅ | `■ 初始化成功 \| 耗时 0.362s` |
| 无 AnyThink ADX 弹窗 | ✅ | 日志全程无弹窗 |
| 无 dyld 缺库 | ✅ | 无 `Library not loaded` |
| 无 selector 崩溃 | ✅ | 无 `unrecognized selector` |
| 无 duplicate class 警告 | ✅ | 无 `Class XXX is implemented in both` |
| **两层 placementId 映射** | ✅ | `q<REDACTED>` → `7316148691848522`（pMap） |
| **CSJ 来源（networkId=13）** | ✅ | `template[1].dispatch ... - 13-948459823` |
| **WindMillCSJAdapter 初始化** | ✅ | `[CSJ] BannerAdAdapter.init` |
| **BUAdSDK 7.6.0.4 初始化** | ✅ | `initializeAdapterSuccess: 13` |
| **CSJ Banner 请求发出** | ✅ | `AdDidLoadStart networkId:13` |
| **WindMillBannerView 创建** | ✅ | `load created: newBanner=...` |
| **no-fill 错误链路完整** | ✅ | CSJ → ToBid → TbBannerAdapter → Flame → Demo |
| **stale 守卫工作正常** | ✅ | `isCurrent=1`（当前对象） |
| **Adapter 不内部重试** | ✅ | destroy 后由 Demo 重试 |
| **Demo RetryScheduler 唯一重试** | ✅ | `2s 后重试 (1/5)` → `4s 后重试 (2/5)` |
| **原 Splash/Interstitial/Reward 不崩溃** | ✅ | 三者 didLoad isCurrent=1 正常 |

---

## 10. 未验证项（成功路径，等 fill 后验证）

| 项 | 状态 | 说明 |
|---|---|---|
| `bannerAdViewLoadSuccess` | ❌ 未验证 | CSJ no-fill，未触发 |
| `retrieveAdView` 返回有效 View | ❌ 未验证 | 依赖 load success |
| Demo addSubview | ❌ 未验证 | 依赖 retrieveAdView |
| adSize / frame | ❌ 未验证 | 依赖 load success |
| 曝光（`bannerAdViewWillExpose`） | ❌ 未验证 | §27 停止条件 #6：有 load 才有曝光 |
| 自动刷新 | ❌ 未验证 | 依赖 load success + 后台刷新配置 |
| 点击 | ❌ 未验证 | 依赖展示 |
| destroy（成功路径） | ❌ 未验证 | 当前 destroy 走的是失败路径 |
| re-enter 重新加载 | ❌ 未验证 | 依赖成功路径 |
| 成功路径下内存/生命周期 | ❌ 未验证 | 依赖成功路径 |

---

## 11. 当前阻塞项

| 阻塞 | 归属 | 处理 |
|---|---|---|
| **CSJ no-fill（800110 / 20001）** | ToBid 官方测试位 | 尺寸已排除（320×50 与 402×50 均失败）。等 ToBid 技术支持确认测试位状态 |

> **重要澄清**：`7316148691848522` 是 **ToBid 官方 iOS 集成测试广告位**（名称"穿山甲_横幅广告_模版渲染"，ToBid App ID 16990），**不是我们自己后台创建的聚合位**。日志中的 network placementId `948459823` 是 ToBid 官方测试位内部关联的穿山甲测试 code ID，不属于我们的穿山甲账号。因此不要求用户核查自己的 CSJ 渠道/广告位/Bundle ID/waterfall/白名单。

---

## 12. ToBid 技术支持反馈清单（等平台方确认测试位状态）

尺寸已排除（320×50 仍 no-fill），当前判定为 **ToBid 官方测试位 no-fill**。反馈 ToBid 技术支持的信息：

| 项 | 值 |
|---|---|
| ToBid App ID | `16990` |
| ToBid 聚合 placementId | `7316148691848522`（穿山甲_横幅广告_模版渲染） |
| network placementId | `948459823`（穿山甲测试 code ID，官方测试位内部关联） |
| networkId | `13`（WindMillAdnCSJ / CSJ / Pangle） |
| ToBid SDK 版本 | ToBid-iOS-RC 5.5.6 |
| CSJ SDK 版本 | Ads-CN/BUAdSDK 7.6.0.4 |
| WindMillCSJAdapter 版本 | 5.5.6 |
| expectSize | `{320, 50}`（CSJ 标准 Banner） |
| 错误码 | ToBid `800110`（"无广告返回"）/ `20001`（"no ads"） |
| CSJ 回调 | `nativeExpressBannerAdView(_:didLoadFailWithError:)` |
| 测试 1（expectSize={402,50}） | 2026-07-20 11:48:35 CST，load_id `5AB01D0F-220C-411E-BE61-A01261ADB86F` |
| 测试 2（expectSize={320,50}） | 2026-07-20 12:05:12 CST，load_id `78742827-D180-4951-AF7B-FDA0F18A9B0E` |
| 设备 | 真机 iPhone（arm64），iOS（具体型号待用户补充） |
| CSJ 初始化 | ✅ 成功（`initializeAdapterSuccess: 13, version: 7.6.0.4`） |
| WindMillCSJAdapter 初始化 | ✅ 成功（`BannerAdAdapter.init`） |
| 预期反馈 | 测试位 `7316148691848522` 当前是否可用？要求尺寸？是否需要测试模式？ |

**不要求用户核查自己的后台**（测试位属于 ToBid 官方）。

---

## 13. 下一步（等用户核查后）

用户核查后台 + 尺寸调整后，重新 Run，预期取得：
```
[TB_BANNER_DIAG] didLoadSuccess: banner=... adSize={?,?} isCurrent=1
[Banner] 加载成功
[TB_BANNER_DIAG] retrieveAdView: banner=... adSize=... thread=1
[Banner] 展示（addSubview + exposure）
[TB_BANNER_DIAG] willExpose → onAdShow
（如后台启用刷新）[TB_BANNER_DIAG] didAutoRefresh
（destroy/re-enter 生命周期）
```

全部成功路径验证后，统一更新本报告 + 创建 `test: validate CSJ banner on device` commit。

---

## 14. SKAdNetwork / ATT / PrivacyInfo（§7，已配置）

| 配置项 | 状态 |
|---|---|
| CSJ SKAdNetworkItems（21 个） | ✅ Demo Info.plist 本地临时已加（不提交） |
| NSUserTrackingUsageDescription（ATT） | ✅ Demo Info.plist 本地临时已加（不提交） |
| PrivacyInfo.xcprivacy | ✅ CSJAdSDK.bundle/PrivacyInfo.xcprivacy 已进 App（Phase 5A.16B 验证） |
| 正式是否提交 Demo 仓库 | ⚠️ 留待 Phase 5A.16D 收口时决定 |

---

## 15. 异常场景（§19，三档口径）

| 场景 | 代码实现 | 真机实测 |
|---|---|---|
| CSJ no-fill | ✅ `bannerAdViewFailedToLoad:error:` → onAdError | ✅ **真机触发**（800110 链路完整） |
| Adapter 失败不重试 | ✅ destroy 后转 Demo | ✅ **真机验证**（2s/4s 重试 1/5、2/5） |
| Demo RetryScheduler 唯一重试 | ✅ | ✅ **真机验证** |
| placementId 空 | ✅ 代码实现 | ⚠️ 未专项触发（pMap 映射正常） |
| size 非法 | ✅ 代码实现 | ⚠️ 未专项触发 |
| viewController 空 | ✅ 代码实现 | ⚠️ 未专项触发 |
| load success | ✅ 代码实现 | ❌ 未验证（CSJ no-fill） |
| retrieveAdView | ✅ 代码实现 | ❌ 未验证 |
| 曝光 | ✅ 代码实现 | ❌ 未验证 |
| 自动刷新 | ✅ 代码实现 | ❌ 未验证 |
| destroy（成功路径） | ✅ 代码实现 | ❌ 未验证 |
| stale callback | ✅ 代码实现 | ⚠️ 未触发（isCurrent 全 1） |

---

## 16. 原广告类型回归（§20，已验证）

| 广告类型 | 状态 | 证据 |
|---|---|---|
| Splash | ✅ 完整闭环（skip+close 幂等） | `[TB_SPLASH_DIAG] load→didLoad→show→didPresent→didSkip→finish(skip)→didClose→finish already done` |
| Interstitial | ✅ load/didLoad 正常 | `[TB_INTERSTITIAL_DIAG] didLoad isCurrent=1` + `[Interstitial] 加载成功` |
| Reward | ✅ load/didLoad 正常 | `[TB_REWARD_DIAG] didLoad isCurrent=1` + `[RewardVideo] 加载成功` |
| AnyThink 弹窗 | ✅ 未出现 | 全程无弹窗 |

**Banner 改动未影响原广告类型**。

---

## 17. 结论（阶段性）

| 项 | 结果 |
|---|---|
| 公共 API 是否变化 | ❌ 未变 |
| Demo 调用方式是否变化 | ❌ 未变（Demo 代码零改动） |
| **两层 placementId 映射** | ✅ 验证通过（`q<REDACTED>` → `7316148691848522`） |
| **CSJ 渠道选中** | ✅ 验证通过（networkId=13） |
| **CSJ Adapter + BUAdSDK 初始化** | ✅ 验证通过 |
| **CSJ Banner 请求发出** | ✅ 验证通过 |
| **no-fill 错误链路完整** | ✅ 验证通过（回调映射正确） |
| **Adapter 不重试 + Demo RetryScheduler** | ✅ 验证通过 |
| **原广告类型回归** | ✅ 验证通过 |
| **CSJ Banner 真实填充** | ❌ 未取得（no-fill，等后台核查） |
| **load success → exposure → refresh → destroy** | ❌ 未验证（依赖 fill） |
| **尺寸一致性** | ⚠️ 待核对（402×50 vs 后台） |
| **Phase 5A.16D 是否完成** | ❌ **未完成**（等 fill 后继续） |

---

## 18. 下一步明确

**Phase 5A.16D 暂停。等待用户完成 CSJ/ToBid 后台核查 + 尺寸核对后重新 Run。**

- 本阶段**不修改 TbBannerAdapter**（实现已验证正确）
- **不增加 Adapter 重试**（与 TK 一致）
- **不修改公共 API**
- **不接入其他广告源**
- **不 push、不 tag、不发布**
- **暂不创建 Phase 5A.16D 最终收口 commit**（等 fill 后统一）

取得真实 fill 后继续验证：load success → retrieveAdView → addSubview → exposure → auto refresh → destroy → re-enter，全部完成后统一更新报告 + commit。

---

## 19. /compact

Phase 5A.16D 进行中（首次请求与 no-fill 阻塞）：链路与 Adapter 实现全部验证正确——Flame 对外 ID `q<REDACTED>` 经 pMap 映射为 ToBid 聚合 `7316148691848522`，ToBid 选中 CSJ（networkId=13），WindMillCSJAdapter + BUAdSDK 7.6.0.4 初始化成功，CSJ Banner 请求真实发出。CSJ 返回 no-fill（800110/20001），错误链路完整（CSJ→ToBid→TbBannerAdapter→Flame→Demo），Adapter 不内部重试，Demo RetryScheduler 2s/4s 退避重试（1/5、2/5）。原 Splash/Interstitial/Reward 无回归。成功路径（load success/retrieveAdView/addSubview/exposure/refresh/destroy）尚未验证。**尺寸已排除根因**：402×50 和 320×50 两次 Run 均返回相同 800110，确认不是尺寸问题。`7316148691848522` 是 ToBid 官方测试位（穿山甲_横幅广告_模版渲染，App ID 16990），`948459823` 是官方测试位内部穿山甲测试 code ID，不属于用户账号。阻塞：ToBid 官方测试位当前 no-fill，已整理诊断清单（App ID/placementId/networkId/SDK 版本/load_id/时间/错误码）等反馈 ToBid 技术支持确认测试位状态。不修改 SDK，不创建最终 commit，等平台方确认。
