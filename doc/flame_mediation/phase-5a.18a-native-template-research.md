# Phase 5A.18A：TK Native Template 与 ToBid Native Express 映射调研

> **本阶段性质**：只读调研，不修改业务代码，不创建 Adapter，不修改 podspec。
>
> **最终判断（5A.18B 范围修正后）**：**方案 A 仅适用于 Native Template / Native Express**——Flame 已有平台无关的 Native 公共 API（`<FlameNativeAd>` + `showInContainer:`），TK Template 模式由 AnyThink 完整渲染 View（与 ToBid Native Express 同构），Demo 零 AnyThink 依赖、零自建 UI，只需新增 `TbNativeAdapter` 桥接 `WindMillNativeAdsManager` 即可。GDTAdapter 5.5.6 已含 `NativeExpressAdsManager`（模板原生支持）。
>
> **范围限定（Phase 5A.18B）**：
> - ✅ Native Template / Native Express：方案 A 完全无损映射，5A.18B 实现
> - ❌ **Native SelfRender**：ToBid 底层支持（WindMillNativeAdsManager 自渲染路径完整），但**当前 Flame SDK 的 ToBid Native SelfRender 桥接尚未接入**，5A.18B 明确降级为"未实现"（非"平台不支持"）
>
> 详见 §18、§21。

---

## 1. 基线

| 项 | 值 |
|---|---|
| SDK 分支 | `release/ios-dual-line` |
| SDK HEAD | `4e0bda6`（Phase 5A.17B TB SelfRender 降级） |
| Demo HEAD | `44f2b7f`（Phase 5A.17B Demo 不可重试短路） |
| Demo Pods 当前 | **TB**（flame_sdk_ios_tb + ToBid-iOS-RC 5.5.6 + CSJAdapter + GDTAdapter + GDTMobSDK 4.15.90 + BUAdSDK 7.6.0.4） |
| 本地 AnyThink Header | **不存在**（Demo 当前是 TB）；类名/selector 全部从 `AtNativeAdapter.m` 调用点反推 |
| 5A.17A/5A.17B 结论前置 | TK SelfRender Banner = AnyThink Banner Native Mix；TB SelfRender Banner 已降级为 unsupported（14003）；普通 Express Banner 两端均工作 |

---

## 2. 概念边界（与 5A.17A 严格区分）

| 概念 | 本阶段定位 | 状态 |
|---|---|---|
| 普通 Banner 模板广告 | TK `ATBannerView` / TB `WindMillBannerView` | ✅ 已完成（5A.16E GDT 真机填充） |
| Banner SelfRender | TK Banner Native Mix / TB 14003 降级 | ✅ 已收口（5A.17B） |
| **Native Template / Native Express** | **本阶段调研目标**（标准原生广告模板渲染） | ⏳ 调研中 |
| Native SelfRender（开发者自布局） | 本阶段仅确认现状，不默认纳入实现范围 | 仅记录 |

**不得**将 Native Template 与 Banner SelfRender 混为一谈。

---

## 3. Flame 公共 Native API 审计（平台无关）

| API | 定义位置 | 签名 |
|---|---|---|
| Native 协议 | `flame_sdk_ios/ads/nativate/FlameNativeAd.h:47-103` | `<FlameNativeAd>`（注：目录名 `nativate` 是历史拼写错误） |
| Render 类型枚举（公开） | `FlameNativeAd.h:13-16` | `FlameNativeRenderTypeSelfRender = 1` / `FlameNativeRenderTypeExpress = 2` |
| Listener 协议 | `FlameNativeAd.h:18-45` | `<FlameNativeListener>`：`onAdLoaded` / `onAdError:desc:` / `onAdShow` / `onAdClicked` / `onAdClosed` |
| 创建入口 | `FlameSdk.h:123-125` + `FlameSdk.m:776-832` | `+createNativeAdWithViewController:placementId:listener:` |
| load | `FlameNativeAd.h` | `loadWithWidth:height:` / `loadWithUserId:userCustomData:width:height:` |
| **show（关键差异）** | `FlameNativeAd.h:83` | `showInContainer:(UIView *)container` ← **Demo 传空白容器，SDK 内部把渲染好的 View 加进去** |
| isLoading / isReady | `FlameNativeAd.h` | 与 Banner 一致 |
| setRenderType | `FlameNativeAd.h` | SelfRender / Express 提示（运行时由物料决定，见 §4） |
| remove / destroy | `FlameNativeAd.h:101` | 与 Banner 一致 |
| 内部 Adapter 协议 | `flame_sdk_ios/mediation/FlameNativeAdapterProtocol.h:20-44` | 镜像公共方法（含 `setRenderType:`） |

### 3.1 关键差异（与 Banner 对比）

| 项 | Banner | Native |
|---|---|---|
| 取 View 方式 | `retrieveAdView` 返回 UIView | **`showInContainer:` 由 SDK 把 View 加到 Demo 传入的容器** |
| 物料 DTO | `FlameBannerAdMaterial` | **无**（Native 不暴露物料） |
| RenderSlots | `FlameBannerAdRenderSlots` | **无**（Native 不需要 Demo 布局） |

### 3.2 Native Express 枚举已存在

`FlameNativeRenderTypeExpress = 2`（`FlameNativeAd.h:15`）—— **Template 模式已经是 Flame 公共 API 的一部分**，不是新增概念。

### 3.3 ⚠️ 公共伞头未导出（小缺口，非阻塞）

`flame_sdk_ios/flame_sdk_ios.h:17-24` 导出 FlameCallback/Splash/Banner/BannerMaterial/BannerRenderSlots/Reward/Interstitial/Sdk，**未导出 `FlameNativeAd.h`**。当前仅靠 `FlameSdk.h:16` 内部 `#import "FlameNativeAd.h"` 传递可达。Demo 可正常 import 是因为 Swift 桥接走 `flame_sdk_ios` 伞头 → `FlameSdk.h` → `FlameNativeAd.h`。**不影响功能，但是一个待修复的小遗漏（可考虑后续单独 commit 加一行 `#import`）**。

---

## 4. TK Native Template 本质（AtNativeAdapter）

### 4.1 Adapter 类与 AnyThink API

| 项 | 值 | 证据 |
|---|---|---|
| Adapter 类 | `AtNativeAdapter : NSObject<FlameNativeAdapterProtocol, ATNativeADDelegate>` | `flame_sdk_ios/adapter/tk/AtNativeAdapter.h:16` |
| AnyThink 类（统一） | `ATAdManager` + `ATNativeAdOffer` + `ATNativeADConfiguration` + `ATNativeADView` + `id<ATNativeMaterialProtocol>` | `AtNativeAdapter.m`（多处） |
| load API | `[ATAdManager.sharedManager loadADWithPlacementID:extra:delegate:]` | `AtNativeAdapter.m:80` |
| 取 offer | `[ATAdManager.sharedManager getNativeAdOfferWithPlacementID:scene:]` | `AtNativeAdapter.m:108` |
| 物料 | `id<ATNativeMaterialProtocol> nativeMaterial = offer.nativeAd` | `AtNativeAdapter.m:152` |

### 4.2 Template vs SelfRender 判定（运行时由物料决定）

**决定性证据** `AtNativeAdapter.m:153`：

```objc
BOOL materialIsExpress = nativeMaterial.isExpressAd || nativeMaterial.nativeAdRenderType == ATNativeAdRenderExpress;
```

→ TK Native 是**双模式**，实际模式由 AnyThink 返回的物料自身决定（`isExpressAd` / `nativeAdRenderType`），不是由 `setRenderType:` 单方面决定。`setRenderType:` 只是 hint，不匹配时 log warning 但仍按物料真实模式渲染（`AtNativeAdapter.m:194-198`）。

### 4.3 模板 View 取得方式（核心结论）

`AtNativeAdapter.m:249-283` 分支：

- **Express 分支（line 250）**：`[offer rendererWithConfiguration:config selfRenderView:nil nativeADView:nativeADView]` —— **View 由 AnyThink 完整渲染**，`selfRenderView` 传 nil。
- **SelfRender 分支（line 252-282）**：构造 SDK 内部 `AtNativeSelfRenderView`（Auto Layout 布局 icon/title/text/cta/mainImage 等），注册 click views，调 `rendererWithConfiguration:selfRenderView:nativeADView:`。

→ **Template 模式下，View 由 AnyThink 完整渲染，Demo/SelfRenderView 不参与 UI 布局**。

### 4.4 addSubview 责任

`AtNativeAdapter.m:285-336`：把 `nativeADView`（或其 `embededAdView`）加到 `showInContainer:` 传入的容器。**由 SDK 完成 addSubview**，Demo 不参与。

### 4.5 独立 AtNativeSelfRenderView

`flame_sdk_ios/adapter/tk/AtNativeSelfRenderView.{h,m}` 存在（`:UIView`），仅用于 SelfRender 分支。Template 模式不用它。

### 4.6 Delegate 回调（ATNativeADDelegate）

`didFailToLoadAD` / `didFinishLoadingAD` / `didClickNativeAdInAdView` / `didShowNativeAdInAdView` / `didEndPlayingVideoInAdView` / `didCloseDetailInAdView` / `didTapCloseButtonInAdView`（`.m:496-544`）—— 映射到 `FlameNativeListener`。

### 4.7 destroy

`AtNativeAdapter.m:469-487`：移除 view、置 nil listener/localExtra/placementId。

---

## 5. Demo Native 页面（零 SDK 依赖、零自建 UI）

### 5.1 文件

| 文件 | 职责 |
|---|---|
| `Sources/Ad/NativeAdManager.swift` | Manager |
| `Sources/Views/NativeAdTestView.swift` | 测试页 |
| `Sources/Components/NativeAdCell.swift` | 信息流 cell（`NovelReaderView.swift:392` 复用） |

### 5.2 调用链（决定性）

```
NativeAdManager
  → FlameSdk.createNativeAdWithViewController(placementId: FlameAdConfig.PlacementId.native, listener)
  → nativeAd.load(width, height)
  → listener.onAdLoaded
  → Demo 创建空白 UIView() 容器
  → nativeAd.show(inContainer: container)    ← 关键：Demo 只传空容器
  → SDK 内部把渲染好的 View 加进 container
  → listener.onAdShow
```

**证据**：
- `NativeAdManager.swift:117` `placementId: FlameAdConfig.PlacementId.native`
- `NativeAdManager.swift:140` `ad.show(inContainer: container)`
- `NativeAdTestView.swift:225, 281` `ad.show(inContainer: container)`
- `NativeAdCell.swift:17-20` 仅构造空容器 UIView()

### 5.3 Demo 不自建 UI

Demo **没有**为 Native 自建任何 UILabel/UIImageView。所有广告 UI 由 SDK 提供（Template 模式由 AnyThink 渲染，SelfRender 模式由 `AtNativeSelfRenderView` 渲染）。

### 5.4 Demo 零 AnyThink import

`adsurge-ios-demo/Sources` 全文 grep 无 `AnyThink` / `WindMill` / `ATNative` import。Demo 完全通过 Flame 抽象解耦。

### 5.5 TK 配置

- `FlameAdConfig.swift:44` `TK.native = "q80657462905"`（TK 广告位）
- `TB.native = ""`（当前空，TB Native 未配置）

---

## 6. TK 完整调用链

```
Demo NativeAdManager
  → FlameSdk.createNativeAdWithViewController(vc, placementId, listener)    [FlameSdk.m:776]
  → FlameNativeAdImpl（持有 id<FlameNativeAdapterProtocol>）
  → FlameTKProvider.createNativeAdapter(viewController, placementId, listener)    [FlameTKProvider.m:147]
  → AtNativeAdapter
  → load → ATAdManager.loadADWithPlacementID(Native placement)    [AtNativeAdapter.m:80]
  → AnyThink 回调 didFinishLoadingAD    [.m:503]
  → Demo 调 showInContainer(container)
  → AtNativeAdapter.showInContainer    [.m:94]
  → getNativeAdOfferWithPlacementID    [.m:108]
  → 读 nativeMaterial.isExpressAd（运行时判 Template/SelfRender）    [.m:153]
  → Express: offer.rendererWithConfiguration(selfRenderView:nil, nativeADView:)    [.m:250]
     AnyThink 完整渲染 View
  → SelfRender: 构造 AtNativeSelfRenderView + 注册点击    [.m:252-282]
  → [container addSubview:nativeADView]    [.m:285-336]
  → ATNativeADDelegate didShowNativeAdInAdView → FlameNativeListener.onAdShow
  → 页面退出 → nativeAd.destroy
```

**所有权**：
- `ATNativeADView` / offer：**SDK Adapter 持有**
- 容器 UIView：**Demo 持有**
- 渲染好的子 View：**SDK 加进容器，Demo 不主动管理**
- 点击/曝光：**AnyThink 内部上报**

---

## 7. ToBid 5.5.6 Native Express API（Header 证据）

Header：`Pods/ToBid-iOS-RC/.../WindMillSDK.xcframework/ios-arm64/WindMillSDK.framework/Headers/WindMillSDK.h`

### 7.1 Native Express 路径（与 SelfRender 共用同一组类）

| 类/方法 | 位置 |
|---|---|
| `WindMillNativeAdsManager` | `:2181-2202`（load `loadAdDataWithCount:` + `getAllNativeAds` + `adSize`） |
| `WindMillNativeAd.feedADMode` | `:2034`（`WindMillFeedADModeNativeExpress = 5` 即模板） |
| `WindMillNativeAdView` | `:2088-2138`（**单一类，双模式数据驱动**） |
| `refreshData:` | `:2113`（绑定物料，**Template 和 SelfRender 共用同一调用**） |
| `nativeExpressAdViewRenderSuccess:` | `:2145`（仅 Template，渲染完成回调） |
| `nativeExpressAdViewRenderFail:error:` | `:2148`（仅 Template，渲染失败回调） |

### 7.2 Template 模式核心契约（Header 注释证据）

`WindMillSDK.h:2033-2034` 注释：
> `WindMillFeedADModeNativeExpress为模版渲染，此时其它属性都为nil`

`WindMillSDK.h:2143` 注释：
> `原生模板广告渲染成功, 此时的 nativeExpressAdView.size.height 根据 size.width 完成了动态更新。`

### 7.3 Template 模式开发流程

1. 创建 `WindMillNativeAdsManager(initWithRequest:)`，`request.placementId = 聚合位`
2. `manager.adSize = CGSizeMake(width, 0)`（宽度指定，高度由模板决定）
3. `manager.loadAdDataWithCount(1)`
4. 回调 `nativeAdsManagerSuccessToLoad:` → `ad = manager.getAllNativeAds()[0]`
5. **判断 `ad.feedADMode == NativeExpress`**
6. 创建 `WindMillNativeAdView(frame: CGRectMake(0,0,width,0))`
7. `adView.viewController = vc` / `adView.delegate = self`
8. `adView.refreshData(ad)`（**Template 模式触发异步渲染**）
9. 等回调 `nativeExpressAdViewRenderSuccess:`（此时 `adView.frame.size.height` 已动态更新）
10. `addSubview(adView)` 并按更新后的 frame 调整容器约束
11. 回调 `nativeAdViewWillExpose:` → `nativeAdViewDidClick:` → `nativeAdDetailViewClosed:` / `dislikeWithReason:`
12. destroy：`adView.unregisterDataObject` + 置 nil + delegate=nil

### 7.4 Template vs SelfRender 真实差异

| 项 | Template（NativeExpress） | SelfRender（其他 feedADMode） |
|---|---|---|
| 物料属性 | 全 nil（`:2033` 注释） | title/desc/iconUrl/callToAction/imageUrlList 等齐备 |
| UI 布局 | **ToBid 完整渲染** | 开发者自建 UILabel/UIImageView 等 |
| refreshData | 触发异步模板渲染 | 仅绑定数据 |
| 渲染回调 | `nativeExpressAdViewRenderSuccess:` / `Fail:` | 无（开发者自己控制） |
| setClickableViews | 不需要（Template 自包含） | 需要 |
| 高度 | 动态（renderSuccess 后 `adView.frame.size.height` 更新） | 开发者自己计算 |
| mediaView/logoView/dislikeButton | 仍可访问但 Template 下一般不用 | 主要使用 |

### 7.5 单一类双模式（无单独 `WindMillNativeExpressAdView`）

Header 全文 grep 无 `WindMillNativeExpressAdView` 类。`WindMillNativeAdView`（`:2088`）单一类，按 `nativeAd.feedADMode` 内部分支。

### 7.6 官方 Demo 证据

`doc/tobid_doc/ToBidDemo官方/Demo_Swift/Demo_Swift/Ads/NativeAd/Views/NativeAdView.swift:68-74`：

```swift
guard nativeAd.feedADMode != .NativeExpress else { return }
setupRenderSelf()  // 仅 SelfRender 才自建 UI
```

→ Template 模式 Demo **直接 return，不自建任何 UI**。

`NativeAdStyle.swift:110-117` `renderExpress` 仅设 size 不布局子 view。`NativeAdViewAdListener.swift:21-29` 在 `renderSuccess` 后调 `NativeAdStyle.layout` 重布局容器。

---

## 8. GDTAdapter Native Express 支持（二进制符号证据）

### 8.1 WindMillGDTAdapter 含 NativeExpress 专用类

`nm -gU Pods/ToBid-iOS-RC/.../gdt/WindMillGDTAdapter.xcframework/ios-arm64/WindMillGDTAdapter.framework/WindMillGDTAdapter`：

```
NativeExpressAdsManager.o:
  _$s18WindMillGDTAdapter23NativeExpressAdsManagerC6loadAd11placementId6adSize9parameterySS_So6CGSizeV0aB3SDK12AWMParameterCtF
    → NativeExpressAdsManager.loadAd(placementId:adSize:parameter:)
  _$s18WindMillGDTAdapter23NativeExpressAdsManagerC04feedfG0So09GDTNativeE2AdCSgpWvd
    → 持有 GDTNativeExpressAd? (strong typed)

FeedAdLoaderListener.o:
  实现 GDTNativeExpressAdDelegete 全部方法：
    nativeExpressAdSuccessToLoad:views:
    nativeExpressAdFailToLoad:error:
    nativeExpressAdViewRenderSuccess:
    nativeExpressAdViewRenderFail:
    nativeExpressAdViewExposure:
    nativeExpressAdViewClicked:
    nativeExpressAdViewClosed:
    nativeExpressAdViewWillPresentScreen:
    nativeExpressAdViewDidDismissScreen:
    ...playerStatusChanged:

NativeAdData.o:
  _$s18WindMillGDTAdapter12NativeAdDataC04feedE0ACSo6UIViewC_tcfCTq
    → init(feedAd: UIView)（Template 路径，包装 GDT 渲染好的 View）
  _$s18WindMillGDTAdapter12NativeAdDataC06nativeE07optionsACSo010GDTUnifieddeF6ObjectC_SDySSypGtcfC
    → init(nativeAd: GDTUnifiedNativeAdDataObject, options:)（SelfRender 路径）
  adMode: AWMMediatedNativeAdMode（区分两路）

__PROTOCOL_GDTNativeExpressAdDelegete
__PROTOCOL_INSTANCE_METHODS_OPT_GDTNativeExpressAdDelegete
  → FeedAdLoaderListener 正式符合 GDTNativeExpressAdDelegete 协议
```

### 8.2 GDTMobSDK 含模板原生类

`Pods/GDTMobSDK/.../Headers/`：

- `GDTNativeExpressAd.h:89` — `@interface GDTNativeExpressAd : NSObject`，`initWithPlacementId:adSize:` / `loadAd:(NSInteger)count` / `GDTNativeExpressAdDelegete` 回调
- `GDTNativeExpressAdView.h:13` — `@interface GDTNativeExpressAdView : UIView <GDTAdProtocol>`（**是 UIView**，已渲染好可直接 addSubview）
- `GDTMobSDK.h:32-34` 伞头显式分组：`//模板信息流` vs `//自渲染`

### 8.3 模板 View 完全由 GDT 渲染

`GDTNativeExpressAdView : UIView`（GDTNativeExpressAdView.h:13），GDT 服务端渲染模板，开发者调 `render` 后等 `nativeExpressAdViewRenderSuccess:` 即可显示。`NativeAdData.feedAd(UIView)` init（nm 符号 `04feedE0ACSo6UIViewC_tcfC`）直接包装该 UIView，`adMode = .NativeExpress` 传给 WindMillSDK。

### 8.4 单一 subspec 覆盖 Banner + Native（Self + Express）

`Pods/Manifest.lock` 只有一个 `ToBid-iOS-RC/GDTAdapter (5.5.6)`。`WindMillGDTAdapter.xcframework` 单一二进制包含：BannerAdAdapter + NativeAdAdapter（self-render）+ **NativeExpressAdsManager（template）** + FeedAdLoaderListener + NativeAdData + ViewCreator + Splash/Interstitial/RewardVideo/Config adapters。**无需新增 subspec**。

### 8.5 Slice / PrivacyInfo / 版本

- WindMillGDTAdapter slices：`ios-arm64` + `ios-arm64_x86_64-simulator`（齐全）
- GDTMobSDK slices：`ios-arm64` + `ios-x86_64-simulator`（simulator 仅 x86_64，Apple Silicon 需 Rosetta——GDT 限制）
- PrivacyInfo.xcprivacy：GDTMobSDK 两 slice 均有；WindMillGDTAdapter 二进制无（依赖 GDT manifest）
- 版本：GDTMobSDK 4.15.90 与 podspec pin 一致，无冲突

### 8.6 结论

**GDT Native Express（模板原生）已内建支持**于当前安装的 5.5.6 GDTAdapter。证据：`WindMillGDTAdapter.NativeExpressAdsManager` + `FeedAdLoaderListener` 符号 + `GDTNativeExpressAdView : UIView` Header。

---

## 9. FlameTBProvider Native 工厂当前返回 nil

`flame_sdk_ios/mediation/tb/FlameTBProvider.m:120-124`：

```objc
- (id<FlameNativeAdapterProtocol>)createNativeAdapterWithViewController:(UIViewController *)viewController
                                                            placementId:(NSString *)placementId
                                                               listener:(id<FlameNativeListener>)listener {
    return nil;  // ← TB Native 未实现，这是 5A.18B 的唯一缺口
}
```

**FlameTBProvider.h:22 已 `#import "FlameNativeAd.h"`**，编译通过。**唯一缺口**是新增 `TbNativeAdapter` 并改工厂返回它。

---

## 10. TK/TB 语义映射表

| Flame/TK 语义 | TK 实现（AnyThink） | ToBid 5.5.6 实现 | 可无损映射 | 风险 |
|---|---|---|---|---|
| create | `AtNativeAdapter` | `TbNativeAdapter`（新增） | ✅ | — |
| placementId | AnyThink Native 位 | ToBid Native 聚合位（后台新建） | ✅ | 后台需配 |
| load | `ATAdManager loadADWithPlacementID` | `WindMillNativeAdsManager initWithRequest:` + `loadAdDataWithCount:1` | ✅ | — |
| load success | `ATNativeADDelegate didFinishLoadingAD` | `nativeAdsManagerSuccessToLoad:` | ✅ | — |
| load failure | `didFailToLoadAD:error:` | `nativeAdsManager:didFailWithError:` | ✅ | — |
| ready | `bannerAdReadyForPlacementID` 等价 | `WindMillNativeAd.ready` / `isAdReady` | ✅ | — |
| **retrieve View** | **无 retrieveAdView（用 showInContainer）** | **同（refreshData + addSubview 由 Adapter 完成）** | ✅ | 语义一致 |
| View 尺寸 | AnyThink 决定（Template） | `renderSuccess` 后动态 `frame.size.height` | ✅ | Adapter 需异步 resize 容器 |
| addSubview | **SDK 完成**（AtNativeAdapter 加进 container） | **Adapter 完成**（TbNativeAdapter 加进 container） | ✅ | — |
| exposure | `ATNativeADDelegate didShowNativeAdInAdView` | `nativeAdViewWillExpose:` | ✅ | — |
| click | `didClickNativeAdInAdView` | `nativeAdViewDidClick:` | ✅ | — |
| close/dislike | `didTapCloseButtonInAdView` | `dislikeWithReason:` + `dislikeButton` | ✅ | — |
| media/video | AnyThink 内部处理 | `mediaView` + `playerStatusChanged` 回调 | ✅ | — |
| destroy | 移除 view + nil 状态 | `unregisterDataObject` + delegate=nil + 置 nil | ✅ | — |
| stale callback | 无显式守卫 | 应加（参考 TbBannerAdapter 模式） | ✅ | 加 stale 守卫 |

**结论：所有 Flame 公共语义可无损映射到 ToBid Native（含 Express 模式）。Demo 零修改，公共 API 零修改。**

---

## 11. 后台和 pMap

### 11.1 TK 当前 Native Template

- Flame 对外广告位：`FlameAdConfig.PlacementId.native`（`q80657462905`，TK）
- 后台类型：**AnyThink Native 广告位**（load 走 `loadADWithPlacementID`，配置走 `ATNativeADConfiguration`）
- pMap 字段：`FlameConfigManager.getPId:` 查 `entity.pIds[native]`（与 banner/bannerSelfRender 独立）

### 11.2 TB 后续需要

| 项 | 要求 |
|---|---|
| ToBid 聚合位类型 | **Native 聚合位**（不能复用 Banner 位） |
| 渲染模式 | 模板渲染（NativeExpress）+ 可选 SelfRender |
| 下挂广告源 | GDT 模板原生（已支持，§8）/ CSJ 模板原生（需后台配） |
| Flame pMap 字段 | **复用 `native` 字段**（不需要新增） |
| Demo 配置 | `TB.native = "q..."`（用户填 ToBid Native 聚合位 ID） |

**不**复用普通 Banner 位；**不**复用 `bannerSelfRender` 字段（Native 是独立广告类型，pMap 字段已存在）。

---

## 12. 判断：**方案 A（完全无损映射）**

### 12.1 判断依据（对照 §12 方案 A/B/C/D/E）

| 方案 | 条件 | 本阶段 |
|---|---|---|
| **A. 完全无损映射** | Flame Native 模板 API 已存在 + TK/TB 语义一致 + Demo 不变 + 公共 API 不变 + 可直接新增 TbNativeAdapter | ✅ **全部满足** |
| B. 公共 API 不变，新增内部桥接层 | 对外语义一致但 ToBid 需内部转换 | 部分（需 Adapter，但属常规实现，不算"桥接层"） |
| C. 现有公共 API 不足 | 缺口需扩展 | ❌ 无缺口 |
| D. ToBid/GDT 不支持 Native Express | 平台不支持 | ❌ 已证据支持 |
| E. 项目无 Native 公共能力 | 需新建公共类型 | ❌ Flame 已有完整 Native API |

### 12.2 方案 A 成立的核心证据

1. **Flame 已有 `<FlameNativeAd>` + `showInContainer:`**（`FlameNativeAd.h:47-103`）—— 公共 API 完整，`showInContainer:` 语义天然适配"SDK 把渲染好的 View 加进 Demo 容器"
2. **TK Template 模式 View 由 AnyThink 完整渲染**（`AtNativeAdapter.m:250` `rendererWithConfiguration:selfRenderView:nil`）—— 与 ToBid Native Express 同构
3. **ToBid Native Express 同样完整渲染 View**（`WindMillSDK.h:2143` 注释 + 官方 demo `NativeAdView.swift:68-74` 跳过 setupRenderSelf）
4. **GDTAdapter 5.5.6 已支持模板原生**（`WindMillGDTAdapter.NativeExpressAdsManager` 符号 + `GDTNativeExpressAdView : UIView` Header）
5. **Demo 零 AnyThink import，零自建 UI**（只 `showInContainer:` 空容器）
6. **FlameTBProvider Native 工厂唯一缺口**：`return nil` → 改为 `return [[TbNativeAdapter alloc] init...]`

---

## 13. 推荐内部架构（方案 A）

```objc
// flame_sdk_ios/adapter/tb/TbNativeAdapter.h（新增）
@interface TbNativeAdapter : NSObject <FlameNativeAdapterProtocol, WindMillNativeAdsManagerDelegate, WindMillNativeAdViewDelegate>
@property (nonatomic, weak) UIViewController *viewController;
@property (nonatomic, copy) NSString *placementId;
@property (nonatomic, weak) id<FlameNativeListener> listener;
@property (nonatomic, assign) FlameNativeRenderType renderType;
- (instancetype)initWithViewController:(UIViewController *)vc
                          atPlacementId:(NSString *)pId
                               listener:(id<FlameNativeListener>)listener;
@end

// flame_sdk_ios/adapter/tb/TbNativeAdapter.m（新增）
// load → WindMillNativeAdsManager + loadAdDataWithCount:1
// didFinishLoading → 持有 WindMillNativeAd，触发 FlameNativeListener.onAdLoaded
// showInContainer: → 创建 WindMillNativeAdView，refreshData:，
//                    feedADMode==NativeExpress 等渲染回调，
//                    SelfRender 等曝光回调，加进 container
// Delegate 回调 → 映射到 FlameNativeListener
// destroy → unregisterDataObject + nil
```

**关键点**：
- 单 Adapter 同时支持 Template（NativeExpress）和 SelfRender（feedADMode 其他值），按 `WindMillNativeAd.feedADMode` 运行时分支，镜像 TK AtNativeAdapter 的设计
- Template 模式：等 `nativeExpressAdViewRenderSuccess:` 后读 `adView.frame.size` 调整容器约束，加进 `showInContainer:` 传入的容器
- SelfRender 模式：本阶段可不实现（参照 5A.17B SelfRender Banner 降级思路），或留后续

### 13.1 FlameTBProvider 工厂改动（最小）

```objc
- (id<FlameNativeAdapterProtocol>)createNativeAdapterWithViewController:...
                                                            placementId:...
                                                               listener:... {
    return [[TbNativeAdapter alloc] initWithViewController:viewController
                                               atPlacementId:placementId
                                                    listener:listener];
}
```

---

## 14. 公共 API 是否变化 / Demo 是否变化

| 项 | 结果 |
|---|---|
| Flame 公共 API | **零修改**（`<FlameNativeAd>` / `<FlameNativeListener>` / `FlameNativeRenderType` / `createNativeAdWithViewController:` 全部复用） |
| Demo 代码 | **零修改**（`NativeAdManager` / `NativeAdTestView` / `NativeAdCell` 调用方式不变；`showInContainer:` 语义天然兼容） |
| Demo 配置 | 用户填 `TB.native = "q..."`（ToBid Native 聚合位 ID） |
| Provider 协议 | **零修改**（`FlameNativeAdapterProtocol` 已存在） |
| podspec | **零修改**（GDTAdapter 单一 subspec 已覆盖 Native Express） |

---

## 15. 风险

| 风险 | 等级 | 缓解 |
|---|---|---|
| ToBid 后台未配 Native 聚合位 → 无法真机验证 | 中 | 静态实现 + 链路冒烟（类比 5A.16D CSJ no-fill） |
| Template 渲染异步 resize 容器时机 | 中 | 严格按官方 demo：`renderSuccess` 后读 `frame.size` 调约束 |
| SelfRender Native（开发者自布局）当前 FlameDemo 不用 | 低 | 本阶段聚焦 Template；SelfRender 留后续或同 5A.17B 降级 |
| GDT simulator 仅 x86_64（Apple Silicon 需 Rosetta） | 低 | 真机验证为主 |
| stale callback | 低 | 参考 TbBannerAdapter 加 stale 守卫 |
| `FlameNativeAd.h` 未在伞头显式导出 | 低 | 不阻塞功能（FlameSdk.h 内部 import）；可后续单独 commit 加一行 |

---

## 16. 未确认项

- ToBid 后台 Native 聚合位创建流程（用户操作）
- GDT Native Express 测试广告位填充情况（需真机）
- CSJ Adapter（`WindMillCSJAdapter`）是否也含 NativeExpress 支持（本阶段未审；当前后台用 GDT 即可）
- Template 模式动态高度在 SwiftUI 容器中的布局细节（Demo 当前 NativeAdCell 用 fixed height）
- 多次 load + 复用 WindMillNativeAdView 的行为（loadAdDataWithCount > 1 场景）

---

## 17. Phase 5A.18B 前置条件

**可进入 Phase 5A.18B 编码**，前提：

1. 用户确认方案 A
2. 用户在 ToBid 后台新建 Native 聚合位（或接受先静态实现、后台配好再真机验证）
3. 确认本阶段是否同时实现 Native SelfRender（建议只做 Template，SelfRender 可后续降级或实现）
4. 确认 Adapter 命名（`TbNativeAdapter` 或其他）

Phase 5A.18B 实现内容（建议）：

1. 新增 `TbNativeAdapter.{h,m}`（Template 模式完整 + SelfRender 占位或降级）
2. 修改 `FlameTBProvider.m` Native 工厂（`return nil` → 返回 `TbNativeAdapter` 实例）
3. XCFramework 构建 + 符号验证（`TbNativeAdapter` / `WindMillNativeAdsManager` 使用符号）
4. TB Demo 构建 + 真机验证（后台配好后）
5. TK 编译回归（不改 TK 代码，确认无影响）
6. 文档 + 本地 commit

---

## 18. （已合并入 §12）

---

## 19. （已合并入 §15）

---

## 20. （已合并入 §16）

---

## 21. 最终判断汇总

| 问 | 答 |
|---|---|
| Flame 当前是否已有 Native 公共 API？ | ✅ 是（`<FlameNativeAd>` + `FlameNativeRenderType` + `createNativeAdWithViewController:`） |
| TK Native Template 底层 API？ | AnyThink 统一 `ATNativeAD*` API，Template 模式由 `nativeMaterial.isExpressAd` 运行时决定，View 由 AnyThink 完整渲染 |
| Demo 当前如何加载展示？ | `FlameSdk.createNativeAd → load → showInContainer:` 传空容器，SDK 内部加渲染好的 View；Demo 零自建 UI、零 AnyThink import |
| ToBid Native Express 能否映射？ | ✅ 能。`WindMillNativeAdsManager → WindMillNativeAd(feedADMode=NativeExpress) → WindMillNativeAdView.refreshData:` + 等 `renderSuccess`，ToBid 完整渲染，与 TK Template 同构 |
| GDTAdapter 是否支持 Native Express？ | ✅ 是。`WindMillGDTAdapter.NativeExpressAdsManager` + `FeedAdLoaderListener`（符号证据）+ `GDTNativeExpressAdView : UIView`（Header） |
| 是否需要新增依赖？ | ❌ 否。单一 `ToBid-iOS-RC/GDTAdapter` subspec 已覆盖 |
| 是否可保持 Flame API + Demo 不变？ | ✅ 是。方案 A 完全无损 |
| 后台需要什么？ | ToBid Native 聚合位 + 下挂 GDT/CSJ 模板原生广告位 + Flame pMap 复用 `native` 字段 |
| 是否可进入 5A.18B？ | ✅ 是（前提：用户确认方案 A + 后台配置或接受先静态实现） |

---

## 22. Git

| 项 | 状态 |
|---|---|
| 本地 commit | **未创建**（等用户确认） |
| push | 未 push |
| tag | 未 tag |
| release | 未 release |

本阶段产出仅为调研报告（本文件）+ `09_change_log.md` 条目。是否创建 docs commit，等用户确认后再操作。

---

## 23. /compact

Phase 5A.18A 完成（只读调研，未改代码）：Flame 已有完整 Native 公共 API（`<FlameNativeAd>` + `<FlameNativeListener>` + `FlameNativeRenderType`（SelfRender/Express）+ `createNativeAdWithViewController:` + `showInContainer:`），Demo 零 AnyThink import、零自建 UI（只传空容器，SDK 加渲染好的 View）。TK Native Template 本质是 AnyThink 统一 `ATNativeAD*` API 运行时按 `nativeMaterial.isExpressAd` 分支（Template 由 AnyThink 完整渲染，SelfRender 用 SDK 内部 `AtNativeSelfRenderView`）。ToBid 5.5.6 Native Express 完整支持（`WindMillNativeAdsManager → WindMillNativeAd(feedADMode=NativeExpress=5) → WindMillNativeAdView.refreshData:` 触发异步渲染，等 `nativeExpressAdViewRenderSuccess:` 后 `frame.size.height` 动态更新；单一类双模式，无单独 NativeExpressAdView）。GDTAdapter 5.5.6 单一 subspec 已含 `NativeExpressAdsManager`+`FeedAdLoaderListener`+`GDTNativeExpressAdView:UIView`（模板原生支持，符号+Header 证据确凿，无需新增依赖）。**FlameTBProvider Native 工厂当前 `return nil`**（5A.18B 唯一缺口）。判断：**方案 A 完全无损映射——但仅适用于 Native Template / Native Express**。Native SelfRender：ToBid 底层支持但 Flame SDK 桥接尚未接入，5A.18B 明确降级（非"平台不支持"）。5A.18B 只需新增 `TbNativeAdapter`（Template 完整 + SelfRender 降级）+ 改 FlameTBProvider 工厂。后台需新建 ToBid Native 聚合位（不能复用 Banner 位），Flame pMap 复用 `native` 字段。未修改业务代码/podspec/Demo/FlameTBProvider，未 push/tag/release。等用户确认方案 + 后台配置后进入 5A.18B。
