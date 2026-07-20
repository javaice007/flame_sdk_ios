# Phase 5A.17A：TK SelfRender Banner 现状审计与 ToBid Native 自渲染映射调研

> **本阶段性质**：只读调研、代码证据整理、映射设计。**不修改业务代码，不创建 Tb SelfRender 代码，不提交未经确认的 commit。**
>
> **最终判断**（**Phase 5A.17B 已修订**）：**方案 E**——Flame 公共 API 保持兼容保留，TB SelfRender Banner 明确返回 unsupported capability 并安全降级，普通 Express Banner 继续正常工作。详见顶部「Phase 5A.17B 决策修订」与本报告 §21E、§25E。
>
> **历史判断（已撤销）**：原 5A.17A 建议方案 B（用 ToBid Native 自渲染桥接模拟 SelfRender）。经复核，强行用独立 Native 广告位模拟 Banner Native Mix 会改变广告位类型、后台配置模型、请求链路、曝光/点击绑定、View 生命周期、客户现有 Banner 语义，得不偿失。撤销方案 B，采用方案 E。

---

## Phase 5A.17B 决策修订（顶部加塞，覆盖原 §21/§25）

### 为什么不用方案 B（ToBid Native 桥接）

1. TK SelfRender Banner 是 AnyThink **Banner Native Mix**——Banner 聚合广告位，`ATBannerView`+`ATNativeBannerView`，向 Flame 返回物料 + RenderSlots，Demo 按现有横幅样式自渲染。
2. ToBid 当前存在普通 Banner（`WindMillBannerView`）、独立 Native 自渲染（`WindMillNativeAdsManager`）、后台"原生渲染横幅"广告样式混用三种形态。
3. **当前 ToBid-iOS-RC 5.5.6 的公开 Header 中，没有发现与 `ATNativeBannerView` 对等的客户端 Banner Native Mix API**。
4. ToBid 后台"原生渲染横幅"是把 Native 广告源混入 Banner 聚合位，由 ToBid 侧完成横幅适配；**不等同于** Flame SelfRender Banner 所需的"返回物料 + RenderSlots + 客户端自定义布局"。
5. 强行用 ToBid Native 聚合位实现 Flame SelfRender Banner 会改变：广告位类型、后台配置模型、请求链路、曝光/点击绑定、View 生命周期、客户现有 Banner 语义。

### 方案 E（采用）

- **公共 API 保持兼容保留**：`FlameBannerAd`、`createSelfRenderBannerAd`、`retrieveMaterials`、`bindMaterialAtIndex:slots:`、`unbindMaterial`、`destroy`、`FlameBannerListener` 全部保留。
- **TB SelfRender 明确降级**：收到 SelfRender 请求时，不创建 `WindMillBannerView`、不创建 `WindMillNativeAdsManager`、不发起任何 ToBid 请求，通过现有 Listener 返回一次 unsupported capability 错误（复用 `ERROR_CODE_UNSUPPORTED_PLATFORM`），输出统一诊断日志 `[TB_SELF_RENDER_UNSUPPORTED]`，安全结束当前生命周期。
- **普通 Express Banner 不受影响**：继续走 `WindMillBannerView` → GDT/CSJ 正常填充。
- **TK SelfRender 保持原样**：`AtBannerAdapter` 不动，AnyThink Banner Native Mix 正常工作。
- **客户体验**：仅切换 Podfile 即可编译运行；TK SelfRender 正常，TB SelfRender 不崩溃、返回明确错误、不重试风暴。

### 关键口径区分（避免误读）

- ❌ "ToBid 完全不支持原生渲染横幅" —— 错误（后台原生渲染横幅存在）
- ✅ "ToBid 当前未提供与 Flame SelfRender Banner 对等的客户端接口" —— 正确

### 后续升级条件

只有 ToBid 未来提供与 Flame RenderSlots/物料模型对等的**客户端 Banner Native Mix API**（类似 `ATNativeBannerView`），才重新评估 TB SelfRender 实现。在此之前的"后台原生渲染横幅"配置能力不构成升级触发条件。

### 实施文档

Phase 5A.17B 实施细节见 `doc/flame_mediation/phase-5a.17b-tb-self-render-unsupported-bridge.md`。

---

## Phase 5A.17A 原始调研内容（事实部分全部保留，仅结论被 5A.17B 修订）

> 以下章节为 5A.17A 调研事实（TK SelfRender 本质、Flame 公共 API、ToBid Native API、GDT Adapter 符号证据）。**事实部分不变**，仅 §21（方案判断）和 §25（5A.17B 前置）被 5A.17B 决策修订覆盖，见顶部「Phase 5A.17B 决策修订」和文末 §21E/§25E。

---

---

## 1. 基线

| 项 | 值 |
|---|---|
| SDK 分支 | `release/ios-dual-line` |
| SDK 开始 HEAD | `dac831a`（Phase 5A.16E.2 GDT 真机验证） |
| SDK 结束 HEAD | 本阶段不创建代码 commit（等用户确认是否创建 docs commit，见 §27） |
| Demo 分支 | `main` |
| Demo HEAD | `11c5958` |
| Demo Pods 当前 | **TB**（flame_sdk_ios_tb + ToBid-iOS-RC 5.5.6 + CSJAdapter + GDTAdapter + GDTMobSDK 4.15.90 + Ads-CN/BUAdSDK 7.6.0.4） |
| AnyThink 版本（podspec 声明） | `AnyThinkiOS 6.5.71`（`flame_sdk_ios.podspec:54`） |
| 本地 AnyThink Header | **不存在**（Demo 当前是 TB，无 AnyThinkSDK）；类名/selector 全部从 `AtBannerAdapter.m` 调用点反推，见 §4/§5 |

---

## 2. 审计方法与证据来源

四条并行只读审计：

| 审计 | 来源 | 结论 |
|---|---|---|
| TK SelfRender 代码审计 | `flame_sdk_ios/ads/banner/` + `flame_sdk_ios/adapter/tk/AtBannerAdapter.{h,m}` + `flame_sdk_ios/core/FlameSdk.m` + Demo `Sources/` | §3-§13 |
| AnyThink 真实 API（无 Header） | 从 `AtBannerAdapter.m` 调用点反推 selector/property | §5 |
| ToBid 5.5.6 Native API | `Pods/ToBid-iOS-RC/.../WindMillSDK.xcframework/.../WindMillSDK.h` | §15 |
| GDT Native 支持 | `nm -gU` + `strings` + Header 审计 `WindMillGDTAdapter.xcframework` + `GDTMobSDK.xcframework` | §17 |

**所有类名/方法签名均以本地代码或本地 Header 为准，不凭记忆/在线文档下结论。**

---

## 3. TK SelfRender Banner 真实本质

### 3.1 判定：**AnyThink Banner 「Native Mix」模式**（选项 A，非 B/C/D/E）

| 候选 | 是否成立 | 证据 |
|---|---|---|
| A. AnyThink Banner 自渲染（Native Mix） | ✅ **是** | `AtBannerAdapter.m:247-251` 调 `retrieveBannerViewForPlacementID:config:nativeMixBannerViewBlock:` |
| B. AnyThink Native 自渲染 | ❌ 否 | `AtBannerAdapter.m` 全文 grep 无 `ATNativeAD` / `ATNativeAdView` / `ATNativeADConfiguration` / `ATNativeADRequest` |
| C. AnyThink Native Express 模板 | ❌ 否 | 同上，且 Express 走的是 `retrieveAdView` 返回 `ATBannerView`（`.m:124`），SelfRender 不走此路 |
| D. Flame 自组装 | ❌ 否 | Flame 只做物料 DTO 转换 + slot 挂载 + 注册 clickableViews，底层对象仍是 AnyThink `ATNativeBannerView` |
| E. 其他 | ❌ 否 | — |

### 3.2 「Banner」是展示形态，但底层 placement 也是 Banner

- **placementId 类型**：AnyThink **Banner** 广告位（`self.atPlacementId` 来自 Flame `bannerSelfRender` 字段，经 pMap 映射后是 AnyThink Banner placement）。
- **load API**：`[ATAdManager sharedManager] loadADWithPlacementID:extra:viewController:delegate:]`（`.m:85-88`）—— 与普通 Express Banner 完全相同的 load 入口，`extra` 里带 `kATAdLoadingExtraBannerAdSizeKey`（`.m:78-79`）。
- **取 View API**：`retrieveBannerViewForPlacementID:config:nativeMixBannerViewBlock:`（`.m:247-251`）—— AnyThink「Banner → Native Mix」专用 retrieval，返回 `ATBannerView` 容器 + 异步回调 `ATNativeBannerView`。
- **「Banner」既是 Flame/Demo 的展示形态名，也是 AnyThink 后台广告位类型名。两者一致。**

### 3.3 最关键证据（单条决定性）

`flame_sdk_ios/adapter/tk/AtBannerAdapter.m:247-251`：

```objc
ATBannerView *bannerView = [[ATAdManager sharedManager]
    retrieveBannerViewForPlacementID:self.atPlacementId
                              config:config
            nativeMixBannerViewBlock:^(ATNativeBannerView *nativeBannerView) {
        capturedNativeBannerView = nativeBannerView;
    }];
```

这是 AnyThink 官方「Native Mix Banner」API：一个 Banner（`ATBannerView`）的素材以 native 风格 `ATNativeBannerView : ATBaseNativeMixView` 暴露，携带 `nativeAdMaterial` 和 `registerClickableViewArray:`。

---

## 4. Flame 公共 SelfRender API（平台无关）

| API | 定义位置 | 签名 |
|---|---|---|
| Render 类型枚举 | `FlameBannerAd.h:19-22` | `FlameBannerRenderTypeExpress = 1` / `FlameBannerRenderTypeSelfRender = 2` |
| 创建（SelfRender） | `FlameSdk.h:114` + `FlameSdk.m:716,752-766` | `+createSelfRenderBannerAdWithPlacementId:listener:` → 工厂 `createBannerAdapterWithPlacementId:renderType:FlameBannerRenderTypeSelfRender:listener:` |
| load | `FlameBannerAd.h:47,51` | `loadWithWidth:height:viewController:` / `loadWithUserId:userCustomData:width:height:viewController:` |
| retrieve View | `FlameBannerAd.h:61` | `retrieveAdView` → `nullable UIView *` |
| **retrieve 物料** | `FlameBannerAd.h:63` | `retrieveMaterials` → `NSArray<FlameBannerAdMaterial *> *` |
| 绑定物料+slots | `FlameBannerAd.h:65` | `bindMaterialAtIndex:slots:` |
| 解绑 | `FlameBannerAd.h:68` | `unbindMaterial` |
| 物料就绪回调 | `FlameBannerAd.h:41` | `onAdMaterialReady:(NSArray<FlameBannerAdMaterial *> *)materials`（SelfRender 专用） |
| destroy | `FlameBannerAd.h:72` | `destroy` |

### 4.1 FlameBannerAdMaterial（纯数据 DTO，平台无关）

`flame_sdk_ios/ads/banner/FlameBannerAdMaterial.h:12-33`：

```
title / desc / ctaText / iconUrl / coverUrl / advertiser /
domain / warning / rating / sponsor / source / hasVideo /
requires* (一系列 BOOL)
```

### 4.2 FlameBannerAdRenderSlots（弱引用 UIView 槽位，平台无关）

`flame_sdk_ios/ads/banner/FlameBannerAdRenderSlots.h:12-21`：

```
containerView (weak)
mediaSlotView (weak)
logoSlotView (weak)
adMarkSlotView (weak)
closeSlotView (weak)
clickableViews (NSArray<UIView *> *)
```

### 4.3 关键事实：**Demo 从不 import AnyThink**

Demo 所有 SelfRender 代码（`SelfRenderBannerManager.swift`、`SelfRenderBannerTestView.swift`、`SelfRenderBannerInline`）只依赖 `FlameBannerAdMaterial` + `FlameBannerAdRenderSlots` + Flame 公共 protocol。**没有任何 `import AnyThinkSDK`**。

---

## 5. AtBannerAdapter SelfRender 分支真实 AnyThink 调用

### 5.1 持有状态（`AtBannerAdapter.h:18-30`）

| 属性 | 类型 | 说明 |
|---|---|---|
| `bannerView` | `ATBannerView *` strong | 容器（Express + SelfRender 共用） |
| `nativeBannerView` | `ATNativeBannerView *` strong | **SelfRender 专用**，Native Mix 对象 |
| `materials` | `NSArray<FlameBannerAdMaterial *> *` | 转换后的 Flame 物料 |
| `managedAssetViews` | `NSArray<UIView *> *` | SDK 管理、挂入 slot 的 view |
| `boundMaterialIndex` / `hasShownPreparedBanner` | 状态位 | 绑定/曝光幂等 |

### 5.2 SelfRender 完整 AnyThink 调用链

| 操作 | 类 | selector / property | file:line |
|---|---|---|---|
| Load（与 Express 共用） | `ATAdManager` | `loadADWithPlacementID:extra:viewController:delegate:` | `.m:85-88` |
| 取容器+Native Mix | `ATAdManager` | `retrieveBannerViewForPlacementID:config:nativeMixBannerViewBlock:` | `.m:247-251` |
| 读物料对象 | `ATNativeBannerView` | `.nativeAdMaterial` → `id<ATNativeMaterialProtocol>` | `.m:287` |
| 物料-文本字段 | `ATNativeMaterialProtocol` | `.title` `.mainText` `.ctaText` `.iconUrl` `.imageUrl` `.advertiser` `.domain` `.warning` `.videoUrl` | `.m:293-300` |
| 物料-KVC 兜底 | `ATNativeMaterialProtocol` | `[nativeAd valueForKey:@"rating"]` `@"source"` | `.m:301-302,354` |
| 媒体资产 view | `ATNativeBannerView` | `.netWorkMediaBackView` `.netWorkMediaView` `.mainImageView` | `.m:312,315,318` |
| Logo 资产 view | `ATNativeBannerView` | `.netWorkOptionView` `.logoImageView` | `.m:322,325` |
| 广告标识 label | `ATNativeBannerView` | `.ADLabel` | `.m:170` |
| 关闭按钮 | `ATNativeBannerView` | `.dislikeButton` | `.m:171` |
| 广告主/域名/警示 label | `ATNativeBannerView` | `.advertiserLabel` `.domainLabel` `.warningLabel` | `.m:305-307` |
| 赞助 label | `ATNativeBannerView` | `.sponsorLabel`（KVC `@"text"`） | `.m:349` |
| 注册点击 view | `ATNativeBannerView` | `registerClickableViewArray:` | `.m:175` |
| 触发展示 | `ATNativeBannerView` | `showAd` | `.m:179` |
| 容器 frame/delegate | `ATBannerView` | `.delegate` `.presentingViewController` `.frame` | `.m:258-262` |
| 销毁容器 | `ATBannerView` | `destroyBanner` | `.m:418` |

### 5.3 retrieveAdView 在 SelfRender 下返回 nil

`AtBannerAdapter.m:110-114`：SelfRender 模式 `retrieveAdView` **返回 nil** 并 log "use retrieveMaterials + bindMaterialAtIndex:slots: instead"。

→ **SelfRender 不通过 retrieveAdView 给 Demo View**，而是通过 `retrieveMaterials` 给物料 + `bindMaterialAtIndex:slots:` 让 Demo 把自己的 UI 槽位交给 SDK，SDK 把内部资产 view（media/logo/adMark/close）挂进槽位。

### 5.4 物料转换（`buildMaterialFromNativeBannerView:` `.m:286-309`）

AnyThink `id<ATNativeMaterialProtocol>` → Flame `FlameBannerAdMaterial`：

```
.title         → material.title
.mainText      → material.desc
.ctaText       → material.ctaText
.iconUrl       → material.iconUrl
.imageUrl      → material.coverUrl
.advertiser    → material.advertiser
.domain        → material.domain
.warning       → material.warning
.videoUrl 非空  → material.hasVideo = YES
```

### 5.5 slot 挂载（`bindMaterialAtIndex:slots:` `.m:142-184`）

| Flame slot | 挂入的 AnyThink view | 来源 |
|---|---|---|
| `mediaSlotView` | `netWorkMediaBackView` / `netWorkMediaView` / `mainImageView` | `.m:311-319` |
| `logoSlotView` | `netWorkOptionView` / `logoImageView` | `.m:321-326` |
| `adMarkSlotView` | `nativeBannerView.ADLabel` | `.m:170` |
| `closeSlotView` | `nativeBannerView.dislikeButton` | `.m:171` |
| `clickableViews` | 透传给 `registerClickableViewArray:`（过滤掉 close/adMark slot） | `.m:174-175,328-345` |

挂载后调 `[self.nativeBannerView showAd]`（`.m:179`）触发曝光——**曝光由 SDK 内部触发，Demo 不调用任何曝光 API**。

### 5.6 destroy（`cleanupPreparedBannerViews` `.m:416-422`）

`unbindMaterial` + `[self.bannerView destroyBanner]` + 置 nil。

### 5.7 stale callback 保护

无显式 stale 守卫（不像 TbBannerAdapter）。靠 `destroy` 时 `nativeBannerView = nil` + delegate 不主动断开（AnyThink 容器 destroy 后不再回调）。

---

## 6. Demo SelfRender 页面审计

### 6.1 Manager（独立，不与 BannerAdManager 共用）

`Sources/Ad/SelfRenderBannerManager.swift:43-187`：

- 创建：`FlameSdk.createSelfRenderBannerAd(withPlacementId:listener:)`（`.swift:119-122`）
- placementId：`FlameAdConfig.PlacementId.bannerSelfRender`（`.swift:109,120-121`），**不是** `banner`、**不是** `native`
- 独立于 `BannerAdManager`（后者走 Express `createBannerAd` + `retrieveAdView`）

### 6.2 Host 自建 UI（SwiftUI）

`SelfRenderBannerTestView.swift:239-284` 的 `materialContent(material:)` + `SelfRenderBannerManager.swift:236-301` 的 `SelfRenderBannerInline.bannerContent`：

- `Text(material.title)` / `Text(material.desc)` / `Text(material.ctaText)`
- `AsyncImage(url: URL(string: material.coverUrl))`
- `AsyncImage(url: URL(string: material.iconUrl))`

→ **Demo 自己渲染标题/描述/CTA/封面/icon**，从 `FlameBannerAdMaterial` 字段取值。

### 6.3 Slot 容器（`SelfRenderBannerSlotContainer` UIViewRepresentable）

`SelfRenderBannerTestView.swift:12-121`：包裹 `BannerSlotContainer: UIView`，4 个透明 slot subview（`mediaView` / `logoView` / `adMarkView` / `closeView`）用 Auto Layout 布局，通过 `onSlotsReady` 回调给上层构造 `FlameBannerAdRenderSlots`。

### 6.4 clickableViews / 曝光 / destroy 责任

| 操作 | 责任方 | 证据 |
|---|---|---|
| clickableViews 设置 | Demo（`slots.clickableViews = [container]`） | `SelfRenderBannerManager.swift:307-309`、`SelfRenderBannerTestView.swift:377-380` |
| 注册 clickable | **SDK**（AtBannerAdapter 调 `registerClickableViewArray:`） | `AtBannerAdapter.m:175` |
| 触发展示 | **SDK**（AtBannerAdapter 调 `[nativeBannerView showAd]`） | `AtBannerAdapter.m:179` |
| 页面退出 destroy | Demo（`.onDisappear { manager.destroy() }`） | `SelfRenderBannerTestView.swift:172-176` |

### 6.5 HomeView 搜索栏下方的广告

`Sources/Views/HomeView.swift:17`：`SelfRenderBannerInline()` 位于 `searchBar`（L15）和 `categoryScrollView`（L18）之间——即 TK 截图搜索栏下方的「美团」广告。

---

## 7. TK 完整调用链

```
Demo SelfRenderBannerManager
  → FlameSdk.createSelfRenderBannerAd(placementId, listener)      [FlameSdk.m:716]
  → FlameBannerAdImpl（持有 id<FlameBannerAdapterProtocol>）
  → FlameTKProvider.createBannerAdapter(renderType=SelfRender)     [FlameTKProvider.m:136-143]
  → AtBannerAdapter（renderType=SelfRender）
  → load → ATAdManager.loadADWithPlacementID(Banner placement)     [AtBannerAdapter.m:85]
  → AnyThink 回调 didFinishLoadingAD                                [.m:224]
  → prepareSelfRenderBanner                                         [.m:237]
  → ATAdManager.retrieveBannerViewForPlacementID:nativeMixBlock     [.m:247]
     ├─ 返回 ATBannerView（容器，strong 持有）
     └─ 异步回调 ATNativeBannerView（Native Mix，strong 持有）
  → 读 nativeBannerView.nativeAdMaterial                           [.m:287]
  → 转换为 FlameBannerAdMaterial[]                                  [.m:286-309]
  → listener.onAdMaterialReady(materials)                          [FlameBannerListener]
  → Demo retrieveMaterials() 拿到物料
  → Demo 自建 SwiftUI UI（title/desc/cta/cover/icon）
  → Demo 构造 FlameBannerAdRenderSlots（container/media/logo/adMark/close/clickableViews）
  → Demo bindMaterialAtIndex:slots:
     → SDK 把 netWorkMediaView 等挂入 mediaSlotView                 [.m:166-172]
     → SDK 调 nativeBannerView.registerClickableViewArray:         [.m:175]
     → SDK 调 nativeBannerView.showAd（触发曝光）                   [.m:179]
  → listener.onAdShow                                              [ATBannerDelegate didShowAd]
  → 页面退出 → manager.destroy()
     → FlameBannerAd.destroy → AtBannerAdapter.destroy
     → unbindMaterial + [bannerView destroyBanner]                 [.m:418]
```

**所有权**：
- `ATBannerView` + `ATNativeBannerView`：**SDK Adapter strong 持有**，destroy 时释放
- FlameBannerAdMaterial：**SDK 创建，Demo 持有副本**
- 槽位 UIView：**Demo 持有**，weak 传给 SDK
- 点击/曝光：**SDK 内部上报**

---

## 8. 「TK 是不是 Native 伪装成 Banner」逐问回答

| 问 | 答 | 证据 |
|---|---|---|
| Q1 底层广告类型是否是 Native？ | **否** | 是 AnyThink **Banner**（`ATAdManager loadADWithPlacementID` + `kATAdLoadingExtraBannerAdSizeKey`） |
| Q2 「Banner」是否仅展示形态名？ | **否**（双重含义） | 既是展示形态名，也是 AnyThink 后台广告位类型名（Banner placement） |
| Q3 是否由聚合平台返回物料，Demo/Flame 自组装 UI？ | **部分** | 平台返回 `ATNativeBannerView`（含 nativeAdMaterial + 资产 view）；Flame 转换物料，**Demo 自建文字/图片 UI**，**SDK 资产 view（media/logo/adMark/close）由 SDK 挂入 Demo slot** |
| Q4 是否必须注册 clickable views 和 Native Ad View 才能曝光/点击/计费？ | **是** | `.m:175` registerClickableViewArray + `.m:179` showAd |
| Q5 是否有模板 Native 和 SelfRender Native 两套模式？ | **否（在 AtBannerAdapter 内）** | AtBannerAdapter 只有 Express Banner + SelfRender Banner（Native Mix）。AnyThink SDK 本身有独立 Native（`ATNativeAD`），但 Flame AtBannerAdapter 不用，由 `AtNativeAdapter` 独立承载（不在本审计范围） |
| Q6 Flame 公共 API 是否已完全屏蔽底层平台差异？ | **是** | Demo 零 AnyThink import，只依赖 FlameBannerAdMaterial + FlameBannerAdRenderSlots + FlameBannerListener |

---

## 9. Flame 数据模型充分性

| Flame 字段 | TK 来源（ATNativeMaterialProtocol） | 是否必填 | 缺失影响 |
|---|---|---|---|
| title | `.title` | 是 | Demo 标题为空 |
| desc | `.mainText` | 否 | Demo 描述为空 |
| ctaText | `.ctaText` | 否 | CTA 按钮文字空 |
| iconUrl | `.iconUrl` | 否 | icon 不显示 |
| coverUrl | `.imageUrl` | 否 | 主图不显示 |
| advertiser | `.advertiser` | 否 | 广告主不显示 |
| domain | `.domain` | 否 | 域名不显示 |
| warning | `.warning` | 否 | 警示不显示 |
| rating | KVC `@"rating"` | 否 | 评分不显示 |
| sponsor | KVC `@"source"` | 否 | 来源不显示 |
| hasVideo | `.videoUrl` 非空 | 否 | 视频标识错误 |

**Flame 模型已足够承载 TK 所有字段，不需要新增字段。**

### 9.1 关键事实

- Flame **只返回物料 DTO（FlameBannerAdMaterial）+ slot 协议（FlameBannerAdRenderSlots）**，不暴露 AnyThink 类型 ✅
- Demo **不依赖 AnyThink 类型** ✅
- 无需修改公共 API ✅

---

## 10. 后台广告位模型与 pMap

### 10.1 TK 当前 SelfRender 使用的后台广告位类型

**AnyThink Banner 广告位**（不是 Native 广告位）。证据：load 走 `loadADWithPlacementID` + `kATAdLoadingExtraBannerAdSizeKey`，取 View 走 `retrieveBannerViewForPlacementID`。

### 10.2 Flame pMap 字段

- `FlameAdConfig.PlacementId.bannerSelfRender`（Demo 配置层）
- `FlameConfigManager.m:337-341` `getPId:` 查 `entity.pIds[flamePlacementId]`（pMap dict）
- `FlameSdk.m:728` 把映射后的 pId 传入 `createBannerAdapterWithPlacementId:renderType:SelfRender`
- **与普通 `banner` 字段独立**（Demo 配置里 `banner` ≠ `bannerSelfRender` ≠ `native`）

### 10.3 TB 后续需要的广告位类型

**ToBid Native 聚合位**（不是 Banner 聚合位）。原因见 §15、§21：ToBid 没有「Native Mix Banner」，自渲染必须走 `WindMillNativeAdsManager` 加载 Native 广告位。

- 不能复用当前普通 Banner 聚合位（`1261219727399929`）
- 需在 ToBid 后台新建 Native 聚合位
- 聚合位下挂 GDT 原生/信息流广告源（networkId=16 已确认支持 Native，见 §17）
- Flame `bannerSelfRender` pMap 字段可复用，但映射目标改为新 Native 聚合位

---

## 11. TK/TB 语义映射表

| Flame/TK 语义 | TK 实现（AnyThink） | ToBid 5.5.6 实现 | 可无损映射 | 处理建议 |
|---|---|---|---|---|
| 创建 | `AtBannerAdapter(renderType=SelfRender)` | TbBannerAdapter SelfRender 分支（新增桥接） | ✅ | 公共 API 不变，Adapter 内分支 |
| placementId | AnyThink Banner 位 | **ToBid Native 聚合位**（不同类型） | ⚠️ 后台需新建 | pMap 映射目标改 Native 位 |
| load | `ATAdManager loadADWithPlacementID` | `WindMillNativeAdsManager initWithRequest: + loadAdDataWithCount:1` | ✅ | Adapter 内调用不同 |
| load success | `ATAdLoadingDelegate didFinishLoadingAD` | `WindMillNativeAdsManagerDelegate nativeAdsManagerSuccessToLoad:` | ✅ | 转 `onAdMaterialReady` |
| load failure | `didFailToLoadAD:error:` | `nativeAdsManager:didFailWithError:` | ✅ | 转 `onAdError` |
| 获取广告模型 | `nativeBannerView.nativeAdMaterial` | ` WindMillNativeAdsManager.getAllNativeAds[0]` | ✅ | Adapter 持有 manager + ad |
| 获取 View | retrieveAdView 返回 nil（SelfRender） | retrieveAdView 返回 nil（SelfRender） | ✅ | 行为一致 |
| title | `nativeAdMaterial.title` | `WindMillNativeAd.title` | ✅ | — |
| desc | `.mainText` | `.desc` | ✅ | — |
| icon | `.iconUrl` | `.iconUrl` | ✅ | — |
| main image | `.imageUrl` | `.imageUrlList[0]` / `.imageModelList` | ✅ | 取首图 |
| image list | （TK 单图为主） | `.imageUrlList`（1=大图，3=组图） | ✅ | TB 支持更丰富 |
| CTA | `.ctaText` | `.callToAction` | ✅ | — |
| logo | `nativeBannerView.netWorkOptionView/logoImageView` | `WindMillNativeAdView.logoView` | ✅ | slot 挂载 |
| dislike | `nativeBannerView.dislikeButton` | `WindMillNativeAdView.dislikeButton` | ✅ | slot 挂载 |
| media/video | `netWorkMediaView/mainImageView` | `WindMillNativeAdView.mediaView/mainImageView/imageViewList` | ✅ | TB 支持视频 |
| bind data | `nativeBannerView` 本身即绑定 | `WindMillNativeAdView.refreshData:(WindMillNativeAd *)` | ✅ | 显式调 refreshData |
| clickable views | `registerClickableViewArray:` | `setClickableViews:` | ✅ | — |
| exposure | `[nativeBannerView showAd]`（SDK 触发） | `nativeAdViewWillExpose:` delegate（refreshData 后自动触发） | ✅ | TB 不需显式 showAd |
| click | `ATBannerDelegate didClick` | `nativeAdViewDidClick:` | ✅ | — |
| close | `didTapCloseButton` + `dislikeButton` | `dislikeWithReason:` + `dislikeButton` | ✅ | — |
| ready | `bannerAdReadyForPlacementID:` | `WindMillNativeAd.ready` / `isAdReady` | ✅ | — |
| retrieve | `retrieveMaterials` + `bindMaterialAtIndex:slots:` | 同 | ✅ | 公共 API 不变 |
| reuse | `unbindMaterial` | `WindMillNativeAdView unregisterDataObject` | ✅ | Adapter 调用 |
| destroy | `[bannerView destroyBanner]` + nil | `unregisterDataObject` + manager/ad/view 置 nil + delegate=nil | ✅ | — |
| stale callback | 无显式守卫 | 应加（参考 TbBannerAdapter 模式） | ✅ | 加 stale 守卫 |

**结论：语义可无损映射。所有 Flame 公共 API 保持不变。**

---

## 12. 概念澄清

| 概念 | 类 |
|---|---|
| 普通 Banner（Express） | TK: `ATBannerView`（retrieveAdView 返回） / TB: `WindMillBannerView` |
| Native 模板广告 | TK: 不在 AtBannerAdapter / TB: `WindMillNativeAdsManager` + `feedADMode == NativeExpress` |
| **Native 自渲染（本阶段目标）** | TK: `ATBannerView` + `ATNativeBannerView`（Native Mix） / **TB: `WindMillNativeAdsManager` + `WindMillNativeAd` + `WindMillNativeAdView`（纯 Native 自渲染）** |
| ToBid 后台「原生渲染横幅」 | 后台流量配置能力，不直接等价 Flame SelfRender API |

**不得用普通 `WindMillBannerView` 冒充 SelfRender**（ToBid 无 Native Mix Banner 类，自渲染必须走 Native 栈）。

---

## 13. TK 是否本质为 Native — 最终回答

| 问 | 答 |
|---|---|
| TK SelfRender Banner 是什么逻辑？ | AnyThink Banner 「Native Mix」：Banner placement 加载，通过 `retrieveBannerViewForPlacementID:nativeMixBannerViewBlock:` 取 `ATNativeBannerView`（含 native 物料 + 资产 view + registerClickableViewArray + showAd） |
| 是否本质也是 Native 自渲染？ | **部分**——物料是 native 风格，但**底层广告位类型是 Banner**，对象是 `ATBannerView` + `ATNativeBannerView`，不是独立 `ATNativeAD` |
| TK 与 ToBid 是否同一种聚合广告模式？ | **聚合层语义同构**（物料/slot/点击/曝光/destroy 一一对应），但**底层实现不同构**（TK = Banner Native Mix；ToBid = 纯 Native self-render） |
| 两者哪里相同？ | Flame 公共 API、物料 DTO、slot 协议、点击注册、曝光触发、destroy 责任、Demo 调用方式 |
| 两者哪里不同？ | 底层广告位类型（Banner vs Native）、底层类（ATBannerView+ATNativeBannerView vs WindMillNativeAdsManager+WindMillNativeAd+WindMillNativeAdView）、后台聚合位类型 |
| 是否能保持 Flame 对外 API 完全一致？ | **能**。所有差异由 Adapter 内部吸收 |
| 下一阶段如何实现？ | 方案 B：TbBannerAdapter SelfRender 分支新增内部桥接层，调 ToBid Native 栈 |

---

## 14. （占位，已合并入 §13）

---

## 15. ToBid 5.5.6 Native 自渲染 API（Header 证据）

Header：`Pods/ToBid-iOS-RC/tobid-sdk-ios-cocoapods-cn/Core/WindMillSDK.xcframework/ios-arm64/WindMillSDK.framework/Headers/WindMillSDK.h`

### 15.1 WindMillNativeAdsManager（loader，`:2181-2202`）

```
@interface WindMillNativeAdsManager : WindMillAd
@property id<WindMillNativeAdsManagerDelegate> delegate;
@property (readonly) NSString *placementId;
@property (readonly) NSDictionary *extra;
@property CGSize adSize;
- (instancetype)initWithRequest:(WindMillAdRequest *)request;
- (void)loadAdDataWithCount:(uint32_t)count;     // 推荐 ≤3
- (NSArray<WindMillNativeAd *> *)getAllNativeAds;
@end
```

注：无 `initWithPlacementId:`，placementId 设在 `WindMillAdRequest.placementId`（`:1372`）。

### 15.2 WindMillNativeAdsManagerDelegate（`:2204-2227`，全 @optional）

- `nativeAdsManagerSuccessToLoad:`
- `nativeAdsManager:didFailWithError:`
- `nativeAdsManagerSuccessAutoToLoad:`
- `nativeAdsManager:didAutoFailWithError:`

### 15.3 WindMillNativeAd（物料模型，`:2011-2057`）

```
@interface WindMillNativeAd : NSObject
@property WindMillAdViewActionConfiguration *configuration;   // setClickableViews 前必须设
@property NSString *title;
@property NSString *desc;
@property NSString *iconUrl;
@property NSString *callToAction;
@property CGFloat rating;
@property NSArray<NSString *> *imageUrlList;       // 1=大图，3=组图
@property NSArray<AWMADImage *> *imageModelList;
@property (readonly) enum WindMillAdn networkId;
@property (readonly) enum WindMillFeedADMode feedADMode;
@property (readonly) enum WindMillNativeAdSlotAdType adType;
@property (readonly) enum WindMillInteractionType interactionType;
@property (readonly) BOOL isVideoAd;
@property AWMADImage *videoCoverImage;              // ks only
@property NSString *videoUrl;                       // ks only
@property (readonly) double videoDuration;
@property NSDictionary<NSString *,NSString *> *saasChannelInfo;
@property WindMillAdInfo *adInfo;
@property (readonly) BOOL ready;
@property (readonly) BOOL isAdReady;
@end
```

**关键**：物料模型本身**不暴露** bind/register/unregister——这些在 `WindMillNativeAdView` 上。

### 15.4 WindMillNativeAdView（容器，`:2088-2138`）

```
@interface WindMillNativeAdView : UIView
@property WindMillNativeAd *nativeAd;
@property (readonly) WindMillAdInfo *adInfo;
@property id<WindMillNativeAdViewDelegate> delegate;
@property (weak) UIViewController *viewController;   // 必设，否则点击无响应
@property (readonly) UIView *mediaView;
@property (readonly) UIView *logoView;
@property (readonly) UIButton *dislikeButton;
@property (readonly) UIImageView *mainImageView;     // 单图
@property (readonly) WindMillNativeAdShakeView *shakeView;
@property (readonly) NSArray<UIImageView *> *imageViewList;   // 3 图
- (void)refreshData:(WindMillNativeAd *)nativeAd;    // 绑定物料
- (void)setMediaViewSize:(CGSize)size;
- (void)setClickableViews:(NSArray<UIView *> *)clickableViews;
- (void)setPlaceholderImage:(UIImage *)image;
- (void)unregisterDataObject;                        // cell 复用/destroy 时解绑
- (void)setProgressViewEnable:(BOOL)enable;
- (void)play;
- (void)setMediaViewMute:(BOOL)mute;
- (void)resume;
- (void)pause;
- (void)stop;
@end
```

### 15.5 WindMillNativeAdViewDelegate（`:2140-2178`，全 @optional）

- `nativeExpressAdViewRenderSuccess:` / `RenderFail:error:`（仅模板）
- `nativeAdViewWillExpose:`（曝光）
- `nativeAdViewDidClick:`（点击）
- `nativeAdDetailViewClosed:` / `WillPresentScreen:`（落地页）
- `nativeAdView:playerStatusChanged:userInfo:`（视频状态）
- `nativeAdView:didUpdatePlaybackTime:totalTime:`（视频进度）
- `nativeAdView:dislikeWithReason:`（dislike，开发者需移除 view）

### 15.6 WindMillFeedADMode 枚举（`:1807-1816`）

```
WindMillFeedADModeSmallImage = 2
WindMillFeedADModeLargeImage = 3
WindMillFeedADModeGroupImage = 4
WindMillFeedADModeNativeExpress = 5    // 仅此为模板渲染
WindMillFeedADModePortraitImage = 6
WindMillFeedADModeVideo = 14
WindMillFeedADModeVideoPortrait = 15
WindMillFeedADModeVideoLandSpace = 16
```

**关键**：**无 `SelfRender` 枚举值**。`feedADMode != NativeExpress` 即自渲染（官方 demo `NativeAdView.swift:70` 据此分支）。

### 15.7 没有 Native Mix Banner 类

完整类清单（`:311-2491`）只有一个 Banner 类 `WindMillBannerView : WindMillAdView`（`:1562`），无 `WindMillNativeBannerAd`、无 `WindMillSelfRenderBanner`、无 Native Mix 变体。`AWMCustomBannerAdapter`（`:376`）是 custom-adapter 桥接协议，非 app-facing view 类。

---

## 16. 自渲染与模板区分

| 模式 | feedADMode | 行为 |
|---|---|---|
| 模板渲染（NativeExpress） | `= 5` | SDK 返回已渲染 view，物料其他属性 nil |
| 自渲染 | `!= 5`（2/3/4/6/14/15/16） | SDK 返回物料数据 + 资产 view，开发者自建 UI |

本地枚举确认（`:1807-1816`），非在线文档推断。

---

## 17. GDT Adapter Native 支持（二进制符号证据）

### 17.1 WindMillGDTAdapter.xcframework 含 Native Adapter 类

`nm -gU Pods/ToBid-iOS-RC/.../gdt/WindMillGDTAdapter.xcframework/ios-arm64/WindMillGDTAdapter.framework/WindMillGDTAdapter`：

```
NativeAdAdapter.o:
  _$s18WindMillGDTAdapter15NativeAdAdapterC04loadE011placementId6adSize9parameterySS_So6CGSizeV0aB3SDK12AWMParameterCtF
    → NativeAdAdapter.loadAd(placementId:adSize:parameter:)
  _$s18WindMillGDTAdapter15NativeAdAdapterC7bidding6params0aB3SDK13TBHBParameterCAF12AWMParameterC_tFTo
    → NativeAdAdapter.bidding(params:)
  _$s18WindMillGDTAdapter15NativeAdAdapterCMa / CMn / CN
    → 类 metadata + ObjC 桥接

NativeAdsManager.o:
  _$s18WindMillGDTAdapter16NativeAdsManagerC6loadAd11placementId6adSize9parameterySS_So6CGSizeV0aB3SDK12AWMParameterCtF
  _$s18WindMillGDTAdapter16NativeAdsManagerC8nativeAdSo010GDTUnifieddH0CSgvgTq
    → 持有 GDTUnifiedNativeAd? (strong typed)

NativeAdData.o:
  _$s18WindMillGDTAdapter12NativeAdDataC06nativeE07optionsACSo010GDTUnifieddeF6ObjectC_SDySSypGtcfC
    → init(GDTUnifiedNativeAdDataObject, options)
  + title / desc / callToAction / imageUrlList / imageModelList / videoCoverImage /
    interactionType / adType / adMode 属性
```

**协议契合**：`l_OBJC_PROTOCOL_REFERENCE_$__TtP11WindMillSDK22AWMCustomNativeAdapter_` —— 该类符合 ToBid 的 `AWMCustomNativeAdapter` 中介协议（与 `AWMCustomBannerAdapter` 同族）。

### 17.2 GDTMobSDK 含 Native 自渲染类

`Pods/GDTMobSDK/GDTFramework/GDTMobSDK.xcframework/ios-arm64/GDTMobSDK.framework/Headers/`：

- `GDTUnifiedNativeAd.h` — `@interface GDTUnifiedNativeAd : NSObject`，`initWithPlacementId:`，`loadAd`，`loadAdWithAdCount:`，`GDTUnifiedNativeAdDelegate` 回调 `NSArray<GDTUnifiedNativeAdDataObject *>`
- `GDTUnifiedNativeAdDataObject.h` — 自渲染物料
- `GDTUnifiedNativeAdView.h` — 自渲染容器
- `GDTNativeExpressAd.h` / `GDTNativeExpressAdView.h` — 模板 native

### 17.3 单一 GDTAdapter subspec 同时支持 Banner + Native

`Pods/Manifest.lock`：

```
- ToBid-iOS-RC/GDTAdapter (5.5.6):
    - GDTMobSDK (= 4.15.90)
    - ToBid-iOS-RC/ToBidSDK
```

**只有一个 GDT 相关 subspec**。`WindMillGDTAdapter.xcframework` 单一二进制包含 BannerAdAdapter + NativeAdAdapter + NativeAdsManager + NativeAdData + FeedAdLoaderListener + Splash/Interstitial/RewardVideo/Config adapters。**无需新增 subspec**。

### 17.4 Slice / PrivacyInfo / 版本

- WindMillGDTAdapter slices：`ios-arm64` + `ios-arm64_x86_64-simulator`（双 slice 齐全）
- GDTMobSDK slices：`ios-arm64` + `ios-x86_64-simulator`（**simulator 仅 x86_64**，Apple Silicon 需 Rosetta——GDT SDK 自身限制，非 Native 支持问题）
- PrivacyInfo.xcprivacy：GDTMobSDK 两 slice 均有；WindMillGDTAdapter 二进制内无（依赖 GDT SDK manifest）
- 版本：`GDTMobSDK 4.15.90` 与 podspec pin 一致，无冲突

### 17.5 结论

**GDT Native 自渲染支持已内建并激活**于当前安装的 `ToBid-iOS-RC/GDTAdapter 5.5.6`，非 Banner-only。

---

## 18. Flame 数据模型 vs TK/ToBid 字段映射

见 §9。Flame `FlameBannerAdMaterial` 字段足够覆盖 TK 所有字段。ToBid `WindMillNativeAd` 字段更丰富（支持视频、组图、竖图），但 Flame 当前字段（title/desc/cta/icon/cover/advertiser/domain/warning/rating/sponsor/hasVideo）能承载核心自渲染需求。

**视频/多图增强**：如需暴露视频/组图，未来可扩展 FlameBannerAdMaterial（本阶段不做）。

---

## 19. （已合并入 §10）

---

## 20. （已合并入 §13）

---

## 21. 方案判断：~~方案 B~~ → **方案 E**（Phase 5A.17B 修订）

### 21E. 修订后的判断（采用）

**方案 E：公共接口兼容保留，TB 明确降级为不支持。**

| 能力 | TK | TB |
|---|---|---|
| 普通 Express Banner | 支持 | 支持 |
| 客户端 SelfRender Banner | 支持（AnyThink Banner Native Mix） | **暂不支持，兼容降级**（返回 unsupported capability 错误） |
| Native 自渲染广告 | Flame AtNativeAdapter 独立承载（不在本审计范围） | ToBid 底层支持（WindMillNativeAdsManager），**但不用于模拟 SelfRender Banner** |
| 后台原生渲染横幅混用 | 由聚合平台配置决定 | ToBid 支持，但不等同于 Flame SelfRender API |

详见顶部「Phase 5A.17B 决策修订」。

### 21.（历史）原方案 B 判断（**已撤销**，仅保留作记录）

~方案 B：公共 API 不变，TB 侧新增内部桥接层（`TbNativeSelfRenderController`），用 `WindMillNativeAdsManager`+`WindMillNativeAd`+`WindMillNativeAdView` 承载 SelfRender 语义。~

**撤销原因**：见顶部「Phase 5A.17B 决策修订」。强行用独立 Native 广告位模拟 Banner Native Mix 会改变广告位类型、后台配置、请求链路、点击/曝光绑定、View 生命周期、客户现有 Banner 语义。

### 21.1 判断依据（对照 §11 方案 A/B/C/D）

| 方案条件 | 本阶段是否满足 |
|---|---|
| A. 完全可无损映射（TK 本质是 Native 自渲染） | ❌ TK 本质是 Banner Native Mix，不是纯 Native |
| **B. 公共 API 不变，需新增内部桥接层** | ✅ **本方案** |
| C. 现有公共模型不足（API 暴露 AnyThink / 必需 mediaView 无法承载 / Demo 强耦合） | ❌ Flame 模型平台无关，Demo 零 AnyThink 依赖 |
| D. ToBid/GDT 5.5.6 不支持目标模式 | ❌ ToBid Native 自渲染完整支持（§15），GDTAdapter 含 Native（§17） |

### 21.2 推荐内部架构

```
TbBannerAdapter（现有，SelfRender 分支当前是占位 no-op）
  └─ [SelfRender 分支新增]
     TbNativeSelfRenderController（新增内部类，不暴露公共 API）
       ├─ WindMillNativeAdsManager（load，delegate）
       ├─ WindMillNativeAd（strong 持有，getAllNativeAds[0]）
       ├─ WindMillNativeAdView（strong 持有，refreshData/setClickableViews/unregisterDataObject）
       └─ 物料转换：WindMillNativeAd → FlameBannerAdMaterial
```

### 21.3 责任划分

- **TbBannerAdapter**：仅做 renderType 分支，SelfRender 委托给 TbNativeSelfRenderController
- **TbNativeSelfRenderController**：持有 ToBid Native 栈，实现 WindMillNativeAdsManagerDelegate + WindMillNativeAdViewDelegate，转 Flame 物料/slot 挂载/clickableViews/曝光/destroy
- **TbBannerAdapter 公共方法 retrieveAdView/retrieveMaterials/bindMaterialAtIndex:slots:/unbindMaterial/destroy**：SelfRender 下全部转发给 Controller

---

## 22. 推荐内部架构（详细）

```objc
// flame_sdk_ios/adapter/tb/TbNativeSelfRenderController.h（新增，内部）
@interface TbNativeSelfRenderController : NSObject <WindMillNativeAdsManagerDelegate, WindMillNativeAdViewDelegate>
@property (nonatomic, strong) WindMillNativeAdsManager *manager;
@property (nonatomic, strong) WindMillNativeAd *nativeAd;
@property (nonatomic, strong) WindMillNativeAdView *nativeAdView;
@property (nonatomic, copy) NSArray<FlameBannerAdMaterial *> *materials;
- (void)loadWithPlacementId:(NSString *)pId adSize:(CGSize)size viewController:(UIViewController *)vc;
- (NSArray<FlameBannerAdMaterial *> *)retrieveMaterials;
- (void)bindMaterialAtIndex:(NSInteger)idx slots:(FlameBannerAdRenderSlots *)slots;
- (void)unbind;
- (void)destroy;
@end

// TbBannerAdapter.m（修改，SelfRender 分支）
- (void)loadWithUserId:... {
    if (renderType == FlameBannerRenderTypeSelfRender) {
        [self.nativeSelfRenderController loadWithPlacementId:...];
    } else {
        // 现有 Express 逻辑不动
    }
}
```

---

## 23. 风险

| 风险 | 等级 | 缓解 |
|---|---|---|
| ToBid 后台未配 Native 聚合位 → 无法真机验证 | 中 | 静态实现 + 链路冒烟（类比 5A.16D CSJ no-fill 处理） |
| WindMillNativeAdView 资产 view 挂入 Flame slot 时机 | 中 | 参考 TK AtBannerAdapter 挂载顺序：refreshData → 挂资产 → setClickableViews → 触发曝光 |
| GDT simulator 仅 x86_64（Apple Silicon 需 Rosetta） | 低 | 真机验证为主（与 5A.16E 一致） |
| 视频/组图素材超出 Flame 当前模型 | 低 | 本阶段只支持图片自渲染，视频留后续 |
| stale callback | 低 | 参考 TbBannerAdapter 模式加 stale 守卫 |

---

## 24. 未确认项

- ToBid 后台 Native 聚合位创建流程（用户操作，不在代码范围）
- Flame pMap `bannerSelfRender` 字段映射到 ToBid Native 位的配置路径（需用户后台确认）
- ToBid Native 自动刷新行为（`nativeAdsManagerSuccessAutoToLoad:`）是否需要 Adapter 层处理
- WindMillNativeAdView 资产 view 的真实尺寸/布局约束（需真机验证）

---

## 25. Phase 5A.17B 前置（**已修订**）

### 25E. 修订后的 5A.17B 内容（采用）

**Phase 5A.17B = 方案 E 兼容降级实现**（非 Native 桥接）：

1. `TbBannerAdapter` SelfRender 分支（当前已有 5A.16C 占位）升级为专业降级：
   - 复用 `ERROR_CODE_UNSUPPORTED_PLATFORM` 错误码
   - 错误描述改为专业口径："当前聚合平台暂不支持开发者自渲染横幅广告"
   - 统一日志前缀 `[TB_SELF_RENDER_UNSUPPORTED]`（含 platform/mediation/sdkVersion/adFormat/renderMode/capability/action/expressBannerAffected/message）
   - 每次 SelfRender load 生命周期只打印一次主日志
   - 异步派发到主线程回调一次 `onAdError`，不重复触发
   - 加 generation/destroyed 守卫，destroy 后迟到 block 不回调
2. `retrieveAdView`（SelfRender 返回 nil）/ `retrieveMaterials`（返回空数组）/ `bindMaterialAtIndex:slots:`（no-op）/ `unbindMaterial`（no-op）/ `destroy`（幂等）行为明确
3. Demo `SelfRenderBannerManager` 为 unsupported capability 错误码加通用不可重试短路（**不判 pt=tk/tb**，基于错误码分类）
4. 普通 Express Banner 完全隔离不受影响
5. TK `AtBannerAdapter` 不动
6. XCFramework 构建 + 符号验证（`TB_SELF_RENDER_UNSUPPORTED` 两 slice 命中）
7. TB/TK Demo 构建回归
8. 文档 + 本地 commit

### 25.（历史）原 5A.17B 内容（**已撤销**）

~可进入 Phase 5A.17B 编码（方案 B），前提：用户确认方案 B；用户在 ToBid 后台新建 Native 聚合位；确认是否实现视频自渲染；确认 Adapter 命名。~

撤销原因：方案 B 已被方案 E 取代，详见顶部「Phase 5A.17B 决策修订」。

---

## 26. 重点检查（用户原问题逐项回答）

1. **TK SelfRender Banner 到底是什么逻辑？** AnyThink Banner Native Mix：Banner placement 加载，`retrieveBannerViewForPlacementID:nativeMixBannerViewBlock:` 取 `ATNativeBannerView`，读 `nativeAdMaterial` 转 Flame 物料，挂资产 view 到 slot，`registerClickableViewArray` + `showAd`。
2. **它是否本质上也是 Native 自渲染？** 部分——物料/资产/点击/曝光语义同构 Native 自渲染，但底层广告位是 Banner，对象是 `ATBannerView`+`ATNativeBannerView`。
3. **TK 与 ToBid 是否属于同一种聚合广告模式？** 聚合层语义同构（Flame 公共 API 一致），底层实现不同构（TK Banner Native Mix vs TB 纯 Native）。
4. **两者哪里相同？** Flame 公共 API、物料 DTO、slot 协议、点击注册、曝光触发、destroy 责任、Demo 调用方式、后台广告位概念（聚合位→广告源）。
5. **两者哪里不同？** 底层广告位类型（Banner vs Native）、底层类（ATBannerView+ATNativeBannerView vs WindMillNativeAdsManager+WindMillNativeAd+WindMillNativeAdView）、ToBid 无 Native Mix Banner 类。
6. **是否能保持 Flame 对外 API 完全一致？** **能**。所有差异由 Adapter 内部吸收，Demo 零改动。
7. **下一阶段应该如何实现？** 方案 B：TbBannerAdapter SelfRender 分支新增内部桥接层 TbNativeSelfRenderController，调 ToBid Native 栈。

---

## 27. Git

| 项 | 状态 |
|---|---|
| 本地 commit | **未创建**（等用户确认） |
| push | 未 push |
| tag | 未 tag |
| release | 未 release |

本阶段产出仅为调研报告（本文件）+ `09_change_log.md` 条目。是否创建 docs commit，等用户确认后再操作。

---

## 28. /compact

Phase 5A.17A 完成（只读调研，未改代码）：TK SelfRender 本质是 AnyThink Banner 「Native Mix」（`ATAdManager retrieveBannerViewForPlacementID:nativeMixBannerViewBlock:` → `ATBannerView`+`ATNativeBannerView`，非纯 Native），Flame 公共 API 平台无关（FlameBannerAdMaterial + FlameBannerAdRenderSlots），Demo 零 AnyThink 依赖。ToBid 5.5.6 Native 自渲染栈完整（WindMillNativeAdsManager→WindMillNativeAd→WindMillNativeAdView），但**无客户端 Banner Native Mix 类**；GDTAdapter 5.5.6 单一 subspec 已含 NativeAdAdapter（符号证据确凿）。**原判断方案 B（用 Native 桥接模拟 SelfRender）已被 Phase 5A.17B 撤销**——强行用独立 Native 广告位模拟会改变广告位类型/后台/链路/生命周期/客户语义。**修订为方案 E**：Flame 公共 API 保持兼容，TB SelfRender 明确返回 unsupported capability（复用 `ERROR_CODE_UNSUPPORTED_PLATFORM`）+ 统一日志 `[TB_SELF_RENDER_UNSUPPORTED]` + 安全降级 + 防重试风暴；普通 Express Banner 与 TK SelfRender 不受影响。后续升级条件：仅当 ToBid 提供对等的客户端 Banner Native Mix API 才重新评估。未修改业务代码/podspec/Demo，未 push/tag/release。
