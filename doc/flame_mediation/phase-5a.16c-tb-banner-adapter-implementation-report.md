# Phase 5A.16C：ToBid Banner Adapter 实现与静态构建验证

> **本阶段性质**：新增 `TbBannerAdapter`（仅 Express 模式）+ 接入 FlameTBProvider Banner 工厂 + 静态构建验证。**不实现 SelfRenderBanner，不修改 Demo，不要求 CSJ Banner 真实填充**。真实 Banner 闭环（fill/show/refresh/click/destroy）留给 Phase 5A.16D。
>
> 验收口径：区分 **实现（代码）** / **静态审计** / **真机实测** 三档。Banner 当前处于"已实现 + 已构建 + 已链接入 App，但未触发真实填充"状态（Demo `banner = ""` → `BannerAdManager.load()` 因 `isConfigured` 守卫跳过）。

---

## 1. 基线

| 项 | 值 |
|---|---|
| SDK 路径 | `/Users/khj/Documents/code/97_ad/ios/flame_ios_sdk` |
| Demo 路径 | `/Users/khj/Documents/code/97_ad/ios/adsurge-ios-demo` |
| SDK 分支 | `release/ios-dual-line` |
| SDK 开始 HEAD | `7f5acf0`（Phase 5A.16B CSJ 依赖接入完成） |
| SDK 结束 HEAD | 本阶段本地 commit（见 §35） |
| Demo HEAD | `11c5958`（Phase 5A.14.1，**Demo 代码零改动**） |
| 接入前 TB Podfile.lock | 5 pods（含 `ToBid-iOS-RC/CSJAdapter 5.5.6` + `Ads-CN/BUAdSDK 7.6.0.4`） |
| 接入后 TB Podfile.lock | 同 5 pods（未改 podspec 依赖，仅新增 SDK 内部 Adapter） |

---

## 2. Flame Banner 公共 API（§7 审计）

### 2.1 `FlameBannerRenderType` 枚举（`FlameBannerAd.h:19-22`）
```objc
typedef NS_ENUM(NSInteger, FlameBannerRenderType) {
    FlameBannerRenderTypeExpress = 1,    // 模板渲染（SDK 返回预渲染视图）
    FlameBannerRenderTypeSelfRender = 2, // 自渲染（开发者消费素材并绑定插槽）
};
```
**本阶段只实现 Express**（SelfRender 留待后续，红线 #11）。

### 2.2 `FlameBannerListener` 协议（`FlameBannerAd.h:27-43`，全部 @optional）
| 方法 | 语义 |
|---|---|
| `onAdLoaded` | 加载成功 |
| `onAdError:desc:` | 错误 |
| `onAdShow` | 展示（曝光） |
| `onAdClicked` | 点击 |
| `onAdClosed` | 关闭 |
| `onAdMaterialReady:` | 素材就绪（SelfRender 专用） |

**没有 refresh 回调、没有 size-change 回调**。

### 2.3 `FlameBannerAdapterProtocol`（内部协议，`FlameBannerAdapterProtocol.h:24-55`，全部 @required）
与公共 `FlameBannerAd` 协议 1:1 镜像：
- `loadWithWidth:height:viewController:` / `loadWithUserId:userCustomData:width:height:viewController:`
- `isReady` / `isLoading`
- **`retrieveAdView`**（返回 `nullable UIView *`，**Adapter 不 addSubview，Demo 自己挂**）
- `retrieveMaterials` / `bindMaterialAtIndex:slots:` / `unbindMaterial`（SelfRender 专用）
- `remove`（软移除）/ `destroy`

### 2.4 `FlameSdk.createBannerAdWithPlacementId:listener:`（`FlameSdk.h:105-107`）
```objc
+ (id<FlameBannerAd>)createBannerAdWithPlacementId:(NSString *)placementId
                                          listener:(id<FlameBannerListener>)listener;
```
只传 `placementId` + `listener`，无 viewController / 容器 / 尺寸（这些在 `load` 时传）。内部 `FlameSdk.m:651` 调 `provider createBannerAdapterWithPlacementId:renderType:FlameBannerRenderTypeExpress:listener:`。

---

## 3. TK `AtBannerAdapter`（参考，不改）

`flame_sdk_ios/adapter/tk/AtBannerAdapter.{h,m}`：
- Express 模式：`retrieveAdView` 每次从 AnyThink `ATAdManager` retrieve 新 `ATBannerView`，**Adapter 不 strong 持有**（`self.bannerView` 仅 SelfRender 时赋值）
- SelfRender 模式：Adapter strong 持有 `ATBannerView` + `ATNativeBannerView`，通过 `bindMaterialAtIndex:slots:` 把子素材 `addSubview` 到 Demo 提供的 slot 容器
- `load`：校验顺序 placement → viewController → size，塞 `localExtra[kATAdLoadingExtraBannerAdSizeKey]`，调 `ATAdManager loadADWithPlacementID:extra:viewController:delegate:`
- `destroy`：`cleanupPreparedBannerViews`（`unbindMaterial` + `[self.bannerView destroyBanner]` + nil）+ nil listener/viewController/adSize
- **无 Flame-side auto-refresh Timer**（AnyThink 内部刷新）
- **无首次失败重试**（直接 `notifyError` 转发）
- 错误码：load 校验用 `FlameErrorCode` 常量（`ERROR_CODE_INVALID_AD_PLACEMENT` / `ERROR_CODE_INVALID_PARAM`），NSError 转发用 `%ld`
- 日志前缀：`[AtBannerAdapter]`（无 `[TK_BANNER_DIAG]`）

---

## 4. Demo `BannerAdManager`（参考，不改）

`adsurge-ios-demo/Sources/Ad/BannerAdManager.swift`：
- `FlameSdk.createBannerAd(withPlacementId:listener:)` → `load(withUserId:..., width: screenWidth, height: 50, viewController: topViewController())`
- `onAdLoaded` 后**延迟 100ms** 调 `bannerAd.retrieveAdView()`，拿到 UIView 存 `@Published var adView`
- SwiftUI `BannerAdView` (UIViewRepresentable) 监听 `adView`，`addSubview` 到自己的容器 UIView + 4 边 AutoLayout 约束
- **Demo 自己管理 view 挂载与 AutoLayout**（Flame 只通过 `retrieveAdView` 返回 view）
- `onClosed` → `destroy` + 60s 后 `reloadDelayed`
- `onError` → `RetryScheduler(maxRetry: 5)` 指数退避重试（**Demo 是唯一重试责任方**）
- **无 Demo 侧 refresh Timer**（只 onClosed 60s reload + onError retry）
- 当前 `FlameAdConfig.PlacementId.banner = ""`（TB 未配置）→ `isConfigured` 守卫跳过 load

---

## 5. 完整调用链

```
业务页面 MainTabView
→ BannerAdManager.load()
→ FlameSdk.createBannerAd(withPlacementId:listener:)      [FlameSdk.m:651]
→ FlameMediationRouter.currentProvider
→ FlameTBProvider.createBannerAdapterWithPlacementId:renderType:listener:  [FlameTBProvider.m:108]
→ TbBannerAdapter (新增)
→ loadWithWidth:height:viewController:
→ WindMillBannerView + loadAdData                         [ToBid]
→ bannerAdViewLoadSuccess: 回调
→ TbBannerAdapter.onAdLoaded → Demo
→ Demo 100ms 后 retrieveAdView() → TbBannerAdapter 返回 strong 持有的 WindMillBannerView
→ Demo addSubview 到自己的 UIViewRepresentable 容器
```

### View 所有权
- **Adapter**：strong 持有 `WindMillBannerView`（长生命周期，auto-refresh 依赖此实例）
- **Demo**：通过 `retrieveAdView()` 拿到 UIView 后**自己 addSubview + AutoLayout**，SwiftUI `Coordinator.currentAdView` weak 引用去重
- **destroy 责任**：Demo 调 `bannerAd.destroy()` → Adapter `delegate=nil + removeFromSuperview + bannerView=nil`；Demo 自己也清 `adView = nil`

---

## 6. ToBid 5.5.6 Banner API（§8 审计，WindMillSDK.h:1560-1640）

### 6.1 `WindMillBannerView : WindMillAdView : UIView`（**它本身就是 UIView**）

属性：
- `placementId`（readonly，由 request 设置）
- `delegate`（weak，`WindMillBannerViewDelegate`）
- `viewController`（weak，**必需**，用于点击跳转落地页）
- `animated`（BOOL，动画开关，默认 YES）
- `adSize`（CGSize readonly，load/refresh 成功后才能读）
- `adInfo`（readonly）
- `isAdValid`（BOOL readonly，填充后才有意义）
- `getCacheAdInfoList`

方法：
- `initWithRequest:` / `initWithRequest:expectSize:`（注意 **camelCase `expectSize:`**，非 snake_case）
- `loadAdData`（**不是** `loadAd`）
- **无 destroy 方法**（teardown 靠 `delegate=nil + removeFromSuperview + 释放强引用`）

### 6.2 `WindMillAdRequest`（与 Reward/Interstitial/Splash 同 builder）
- `placementId`（必传）
- `userId`（可选）
- **无 size 字段**（尺寸只能通过 `initWithRequest:expectSize:` 传）

### 6.3 `WindMillBannerViewDelegate`（10 方法，全 @optional，selector label 按头文件原样）
| 方法 | 语义 |
|---|---|
| `bannerAdViewLoadSuccess:` | 加载成功（首次 + 就绪信号） |
| `bannerAdViewFailedToLoad:error:` | 加载失败（label `error:`） |
| `bannerAdViewDidAutoRefresh:` | 自动刷新成功 |
| `bannerView:failedToAutoRefreshWithError:` | 自动刷新失败（第一参数 `bannerView:`，第二 `failedToAutoRefreshWithError:`） |
| `bannerAdViewWillExpose:` | 即将曝光 |
| `bannerAdViewDidClicked:` | 点击 |
| `bannerAdViewWillOpenFullScreen:` / `bannerAdViewCloseFullScreen:` | 落地页开/关 |
| `bannerAdViewWillLeaveApplication:` | 离开 App |
| `bannerAdViewDidRemoved:` | 广告视图被移除 |

### 6.4 官方文档关键规则（已 WebFetch `sdkdoc.sigmob.com/tobid/21024/`）
- **首次 load 失败不自动重试**，需开发者手动 `loadAdData`
- **首次成功后**，refresh 失败 SDK 自动重试
- `expectSize` 必须与后台媒体平台配置尺寸一致
- `viewController` 必须设置
- auto-refresh 由后台控制，`loadAdData` 一次后自动刷新

---

## 7. 回调映射表（§9）

| Flame (`FlameBannerListener`) | TK (`ATBannerDelegate`) | ToBid (`WindMillBannerViewDelegate`) | TB 处理 |
|---|---|---|---|
| `onAdLoaded` | `didFinishLoadingADWithPlacementID:` | `bannerAdViewLoadSuccess:` | stale 守卫 → 设置 frame=adSize → `onAdLoaded` |
| `onAdError:desc:` | `didFailToLoadADWithPlacementID:error:` | `bannerAdViewFailedToLoad:error:` | stale 守卫 → code=`%ld`，desc=localizedDescription |
| `onAdShow` | `didShowAd` | `bannerAdViewWillExpose:` | stale 守卫 → `onAdShow` |
| `onAdClicked` | `didClick` | `bannerAdViewDidClicked:` | stale 守卫 → `onAdClicked` |
| `onAdClosed` | `didTapCloseButton` | `bannerAdViewDidRemoved:` | stale 守卫 → `onAdClosed` |
| —（仅日志） | （无） | `bannerAdViewDidAutoRefresh:` | log + 更新 frame=adSize（不冒充 `onAdLoaded`） |
| —（仅日志） | （无） | `bannerView:failedToAutoRefreshWithError:` | log（不重试，不通知业务） |
| —（仅日志） | （无） | `bannerAdViewWillOpenFullScreen:` / `CloseFullScreen:` / `WillLeaveApplication:` | log |
| —（SelfRender 专用） | `prepareSelfRenderBanner` | （无） | Express: `retrieveMaterials` 返回空数组 |
| —（SelfRender 专用） | `bindMaterialAtIndex:slots:` | （无） | Express: no-op + log |
| —（SelfRender 专用） | `unbindMaterial` | （无） | Express: no-op |
| `remove` | log（view 由上层管理） | （无） | log（与 TK Express 一致） |

> **不伪造 Flame 没有的回调**：refresh success/failure、willOpenFullScreen 等只做内部状态更新 + `[TB_BANNER_DIAG]` 日志。

---

## 8. TbBannerAdapter 实现（§10/§11）

### 8.1 文件
| 文件 | 类型 | 说明 |
|---|---|---|
| `flame_sdk_ios/adapter/tb/TbBannerAdapter.h`（新增） | — | 镜像 AtBannerAdapter.h init 签名，前向声明 WindMillBannerView/Delegate |
| `flame_sdk_ios/adapter/tb/TbBannerAdapter.m`（新增） | — | FlameBannerAdapterProtocol + WindMillBannerViewDelegate（10 方法）|
| `flame_sdk_ios/mediation/tb/FlameTBProvider.m`（修改） | +1 import、占位 nil → 创建 adapter | 工厂接入 |

### 8.2 与 Reward/Interstitial/Splash 的本质差异（与 TK AtBannerAdapter Express 一致）
| 维度 | Reward/Interstitial/Splash | **Banner** |
|---|---|---|
| 生命周期 | 一次性全屏广告（close 后销毁） | **长生命周期 UIView**（auto-refresh 依赖此实例） |
| View 暴露 | 无（内部 present） | **`retrieveAdView` 返回 strong 持有的 WindMillBannerView**，Demo 自己 addSubview |
| 加载方法 | `loadAd` / `loadAdData`（Splash/Reward/Interstitial） | **`loadAdData`**（WindMill Banner 专用） |
| ready 判断 | `isAdReady` | **`isAdValid`**（WindMill 无 isAdReady） |
| destroy | `delegate=nil + ad=nil` | **`delegate=nil + removeFromSuperview + bannerView=nil`**（官方文档无 destroy 方法） |
| auto-refresh | 无 | **ToBid 后台控制**（Adapter 不加 Timer，红线 #26/#27） |
| 失败重试 | 无 | **Adapter 不重试**（与 TK 一致；Demo RetryScheduler 负责） |

### 8.3 stale callback 守卫
每个回调：`if (bannerAdView != self.bannerView) { log "stale callback ignored"; return; }`（指针身份判断：每次 load 清旧 delegate + 新建对象，旧对象迟到回调必失败）

### 8.4 SelfRender 模式处理（Phase 5A.16C 不实现，红线 #11）
- `load` 入口：SelfRender → log 警告 + `onAdError:ERROR_CODE_UNSUPPORTED_PLATFORM`
- `retrieveMaterials`：返回空数组
- `bindMaterialAtIndex:slots:` / `unbindMaterial`：no-op + log

---

## 9. 尺寸策略（§12）

| 项 | 策略 |
|---|---|
| 尺寸来源 | Flame `loadWithWidth:height:` 传入（Demo 用 `UIScreen.main.bounds.width × 50`） |
| `expectSize` | 透传到 `initWithRequest:expectSize:`（必须与后台配置一致，否则渲染变形） |
| `adSize` 更新 | `bannerAdViewLoadSuccess:` / `bannerAdViewDidAutoRefresh:` 中读 `bannerView.adSize` 更新 frame（不用 `self.adSize` 期望值） |
| **是否写死 320×50** | ❌ **否**（仅 Demo 测试配置 + 报告首测尺寸；Adapter 用传入的 width×height） |

---

## 10. ViewController 策略（§13）

`loadWithWidth:height:viewController:` 入口校验 viewController 非空 → 存 `self.viewController` → 设置 `self.bannerView.viewController = viewController`（ToBid 官方文档要求，用于点击跳转落地页）。

viewController 为空 → `onAdError:ERROR_CODE_INVALID_PARAM desc:@"viewController is required"`（与 AtBannerAdapter 一致）。

---

## 11. View 挂载策略（§11.3）

- **Adapter strong 持有 `WindMillBannerView`**（长生命周期，不能像 TK Express 那样每次 retrieve 新建）
- `retrieveAdView` 返回 `self.bannerView`（isAdValid 时）
- **Demo 自己 addSubview + 4 边 AutoLayout**（Flame 不碰 view hierarchy）
- 无循环引用：listener/viewController 均 weak，bannerView 的 delegate 是 Adapter（但 delegate 属性也是 weak）

---

## 12. 生命周期（§11）

| 阶段 | 处理 |
|---|---|
| `load` 入口 | 校验 → 清旧（`delegate=nil + removeFromSuperview + bannerView=nil`）→ `_isLoading=YES; _loaded=NO;` → 新建 WindMillBannerView → `loadAdData` |
| `bannerAdViewLoadSuccess:` | stale 守卫 → `_isLoading=NO; _loaded=YES;` → 更新 frame=adSize → `onAdLoaded` |
| `bannerAdViewFailedToLoad:error:` | stale 守卫 → `_isLoading=NO;` → `onAdError:` |
| `bannerAdViewDidAutoRefresh:` | stale 守卫 → 更新 frame=adSize → log（不通知业务） |
| `bannerView:failedToAutoRefreshWithError:` | stale 守卫 → log（不重试，不通知业务） |
| `destroy` | `delegate=nil + removeFromSuperview + bannerView=nil` + `_isLoading=NO; _loaded=NO;` + nil listener/viewController/adSize |

---

## 13. 自动刷新策略（§14）

| 项 | 策略 |
|---|---|
| 责任方 | **ToBid SDK/后台**（Adapter 不新增 Timer，红线 #26/#27） |
| Flame Timer | ❌ 无 |
| Demo Timer | ❌ 无（Demo 只 onClosed 60s reload + onError retry） |
| 首次失败重试 | ❌ **Adapter 不重试**（与 TK 一致；Demo RetryScheduler 负责） |
| refresh failure | log + ToBid SDK 自身处理（首次成功后 refresh 失败 SDK 自动重试） |

> **重试责任方说明**：Demo `BannerAdManager` 已有 `RetryScheduler(maxRetry:5)` 负责首次 load 失败重试（与 TK AtBannerAdapter 一致——TK 也不内部重试）。Adapter 直接 `onAdError` 转发，Demo 收到后重建整个 Banner 并重试。避免双重重试（§30-C）。

---

## 14. 错误映射（§16）

沿用 AtBannerAdapter 的混合策略：
| 场景 | code | desc |
|---|---|---|
| placementId 空 | `ERROR_CODE_INVALID_AD_PLACEMENT` | `Invalid mapping for placementId` |
| viewController 空 | `ERROR_CODE_INVALID_PARAM` | `viewController is required` |
| size 非法（≤0/NaN/Inf） | `ERROR_CODE_INVALID_PARAM` | `Invalid ad size: %.2f x %.2f` |
| SelfRender 模式 | `ERROR_CODE_UNSUPPORTED_PLATFORM` | `ToBid Banner SelfRender not implemented yet` |
| 加载失败（NSError） | `%ld` of error.code | `error.localizedDescription ?: @"ToBid Banner load failed"` |

未新增公共错误枚举（沿用 `FlameErrorCode.h` 既有常量）。

---

## 15. 诊断日志（§17）

统一前缀 `[TB_BANNER_DIAG]`（24 条，两 slice 命中）：
- load / load created / retrieveAdView / destroy
- didLoadSuccess / didFailToLoad / didAutoRefresh / didFailToAutoRefresh
- willExpose / didClicked / didRemoved
- willOpenFullScreen / closeFullScreen / willLeaveApplication
- stale callback ignored
- SelfRender not supported / Express mode no-op（bindMaterial/unbindMaterial/remove）

日志不含 appKey/token/secret/完整后台响应/未脱敏 placementId。

---

## 16. Provider 工厂接入（§18）

`FlameTBProvider.m`：
- 新增 `#import "TbBannerAdapter.h"`
- 占位 `return nil` 改为：
  ```objc
  TbBannerAdapter *adapter = [[TbBannerAdapter alloc] initWithPlacementId:placementId
                                                               renderType:renderType
                                                                 listener:listener];
  return adapter;
  ```
- **Native 工厂保持 `return nil`**
- **不动** +load 注册、Router 语义、Reward/Splash/Interstitial 工厂

---

## 17. XCFramework 构建（§21）

`./xcFramework_build.sh`：

| 检查 | 结果 |
|---|---|
| 双 Archive | ✅ ARCHIVE SUCCEEDED |
| XCFramework 生成 | ✅ |
| AnyThink weak patch | ✅ 幂等通过 |
| 二进制体积 | 324K → **344K**（+20K，TbBannerAdapter） |

### 17.1 符号校验（两 slice）
| 符号 | sim | device |
|---|---|---|
| `TbBannerAdapter` (NEW) | ✅ `_OBJC_CLASS_$_TbBannerAdapter` | ✅ |
| `TbRewardAdapter` / `TbInterstitialAdapter` / `TbSplashAdapter`（回归） | ✅ | ✅ |
| `FlameTBProvider` / `FlameTKProvider` | ✅ | ✅ |

### 17.2 诊断字符串（两 slice）
| 字符串 | sim | device |
|---|---|---|
| `TB_BANNER_DIAG` (NEW) | ✅ 24 条 | ✅ 24 条 |
| `TB_REWARD_DIAG`（回归） | ✅ 11 条 | ✅ 11 条 |
| `TB_INTERSTITIAL_DIAG`（回归） | ✅ 20 条 | ✅ 20 条 |
| `TB_SPLASH_DIAG`（回归） | ✅ 23 条 | ✅ 23 条 |
| `TK_PLATFORM_REQUIRES_ANYTHINK`（回归） | ✅ | ✅ |

---

## 18. AnyThink weak 断言（无回归，两 slice）
| 检查 | 结果 |
|---|---|
| `otool -L` AnyThinkSDK | ✅ `(weak)` 标记 |
| `otool -l` LC command | ✅ `LC_LOAD_WEAK_DYLIB` |

---

## 19. TB pod install（§22，5 pods）
| pod | 版本 |
|---|---|
| `flame_sdk_ios_tb` | 1.0.0-alpha.4-local |
| `ToBid-iOS-RC` | 5.5.6（含 `ToBidSDK` + `CSJAdapter` subspec） |
| `Ads-CN/BUAdSDK` | 7.6.0.4 |
| `OpenSSL-Universal` | 3.6.2000 |
| `FunlinkSDK` | 2.9.0.1.2 |

**无 AnyThinkiOS / TK adapter / SigmobAd-iOS**。

---

## 20. iphoneos BUILD（§23.1）

> **口径修正（Phase 5A.16D §5）**：iphoneos 设备目标 BUILD SUCCEEDED **尚未等同于 Banner 真机运行验证**。本节仅证明编译/链接通过，真实 CSJ Banner 填充/展示/刷新/点击/销毁闭环留待 Phase 5A.16D 真机实测。

```
xcodebuild -workspace ... -configuration Debug -sdk iphoneos CODE_SIGNING_ALLOWED=NO build
```
**结果**：✅ **BUILD SUCCEEDED**

- error：0
- duplicate symbols：0
- TbBannerAdapter 编译通过
- WindMillBannerView Header 解析通过
- delegate selector 全部匹配
- public API 无变化

---

## 21. iphonesimulator BUILD（§23.2，pre-existing 失败）

**结果**：❌ BUILD FAILED（**pre-existing**：Flame xcframework 缺 arm64 simulator slice，与 Banner 无关）

**精确错误**：
```
error: 'flame_sdk_ios/FlameSdk.h' file not found
error: unable to resolve module dependency: 'flame_sdk_ios'
```

**根因**：Flame xcframework simulator slice 是 `ios-x86_64-simulator`（仅 x86_64），Apple Silicon 模拟器目标 `arm64 x86_64` → Flame 模块无法解析。**Banner 编译无错误**（error 输出中无 `TbBanner` / `WindMillBanner` 匹配）。

**按 §23.2 / §30-C 红线**：
- ❌ 未用 EXCLUDED_ARCHS / Rosetta / 修改第三方 binary
- ✅ 如实记录 pre-existing 限制

---

## 22. App 产物审计（§24，真机 Debug build）

| 检查 | 结果 |
|---|---|
| `flame_sdk_ios.framework` | ✅ 存在 |
| `OpenSSL.framework` | ✅ 存在 |
| `CSJAdSDK.bundle` | ✅ 存在（含 PrivacyInfo.xcprivacy） |
| AnyThinkSDK.framework | ✅ ABSENT |
| SmartdigimktSDK | ✅ ABSENT |
| TK Adapter | ✅ ABSENT |
| 重复 Framework | ✅ 无 |

### 22.1 符号审计（App debug dylib + Flame framework）
| 符号 | 位置 | 结果 |
|---|---|---|
| `TbBannerAdapter` (+ metaclass) | Flame framework binary | ✅（运行时经 Router→FlameTBProvider 调用） |
| `WindMillBannerView` | App debug dylib | ✅（ToBid 核心，静态链接） |
| `BUNativeExpressBannerView` | App debug dylib | ✅（CSJ Banner view，静态链接） |
| `WindMillCSJAdapter` | App debug dylib | ✅（ToBid CSJ Adapter） |
| `TB_BANNER_DIAG` 字符串 | Flame framework binary | ✅ 24 条 |

### 22.2 链接审计
| 检查 | 结果 |
|---|---|
| Flame binary AnyThink | ✅ LC_LOAD_WEAK_DYLIB（无回归） |
| Flame 直接链接 BUAdSDK | ❌ **否**（CSJ 经 podspec → 静态归档进 App，不进 Flame） |
| module name | ✅ `flame_sdk_ios`（不变） |

> 当前 clean build 未出现 duplicate symbols，静态审计未发现明确重复框架；全量广告源组合仍需后续验证。

---

## 23. 请求级冒烟（§25，本阶段不要求真实填充）

**当前状态**：Demo `FlameAdConfig.PlacementId.banner = ""`（TB 未配置）→ `BannerAdManager.load()` 因 `isConfigured` 守卫跳过 → `TbBannerAdapter` 处于"已链接但未触发"状态。

按 §25 场景 A（后台未配 CSJ Banner）：
- ✅ Adapter 和构建已完成
- ⚠️ 真实 CSJ Banner 填充等待 Phase 5A.16D 后台配置

**不伪造 load success**。

> 如用户已在 ToBid 后台配 CSJ Banner 广告位 + Flame pMap + Demo 本地临时填 banner placementId，可做请求级冒烟（观察 `[TB_BANNER_DIAG] load → load created → bannerAdViewLoadSuccess/FailedToLoad`）。完整 addSubview → exposure → refresh → click → destroy 闭环属 Phase 5A.16D。

---

## 24. 异常场景静态验证（§26）

| 场景 | 代码实现 | 静态审计 | 真机实测 |
|---|---|---|---|
| placementId 空 | ✅ `ERROR_CODE_INVALID_AD_PLACEMENT` | ✅ 通过 | ⚠️ 未专项触发（banner="" 时 Demo load 跳过） |
| size 非法（≤0/NaN/Inf） | ✅ `ERROR_CODE_INVALID_PARAM` | ✅ 通过 | ⚠️ 未专项触发 |
| viewController 空 | ✅ `ERROR_CODE_INVALID_PARAM` | ✅ 通过 | ⚠️ 未专项触发 |
| destroy 后迟到回调 | ✅ stale 守卫 | ✅ 通过 | ⚠️ 未专项触发 |
| 重复 load | ✅ 清旧 banner（delegate=nil + removeFromSuperview + nil） | ✅ 通过 | ⚠️ 未专项触发 |
| refresh failure | ✅ log（不重试，不通知业务） | ✅ 通过 | ⚠️ 未专项触发 |
| **首次失败重试** | ⚠️ **Adapter 不重试**（与 TK 一致；Demo RetryScheduler 负责） | ✅ 通过 | ⚠️ 未专项触发 |
| SelfRender 模式 | ✅ `ERROR_CODE_UNSUPPORTED_PLATFORM`（Phase 5A.16C 不实现） | ✅ 通过 | — |

---

## 25. 原广告类型回归（§27，待用户 Run 后确认）

| 广告类型 | 状态 |
|---|---|
| Splash load | ⚠️ 待用户 Run（banner="" 不影响 Splash/Reward/Interstitial） |
| Interstitial load | ⚠️ 待用户 Run |
| Reward load | ⚠️ 待用户 Run |
| AnyThink 弹窗 | ⚠️ 待用户 Run（应不出现） |

> 本轮未修改共享 Banner 公共类/协议（只新增 adapter + 改 TB 工厂），原广告类型不受影响。

---

## 26. TK 编译回归（§27 TK 段）

| 检查 | 结果 |
|---|---|
| TK clean pod install | ✅ 28 pods |
| `flame_sdk_ios`（TK） | ✅ 存在 |
| `flame_sdk_ios_tb`（应 ABSENT） | ✅ ABSENT |
| AnyThinkiOS 6.5.71 | ✅ 存在 |
| **`ToBid-iOS-RC/CSJAdapter`（应 ABSENT）** | ✅ **ABSENT**（TK 不因 TB Banner 改动引入 CSJAdapter） |
| iphoneos BUILD | ✅ **BUILD SUCCEEDED** |
| Demo 恢复 TB | ✅ 5 pods |

**TK 无回归**：Banner Adapter 是新增文件 + TB 工厂改动，TK 编译路径不受影响（TK 仍 28 pods，BUILD SUCCEEDED）。

---

## 27. SKAdNetwork / Privacy 审计（§20）

| 配置项 | 需要与否 | Demo 当前 | 后续处理 |
|---|---|---|---|
| CSJ SKAdNetworkItems | ✅ 需要 | ⚠️ 缺 | Phase 5A.16D（Banner 真机填充前必须加 Demo Info.plist） |
| PrivacyInfo.xcprivacy | ✅ 需要 | ✅ CSJAdSDK.bundle 自带 | — |
| ATT (NSUserTrackingUsageDescription) | ✅ 需要 | ⚠️ 待确认 | Phase 5A.16D |
| ATS | ✅ 需要 | ✅ 已有 | — |

**本阶段不修改 Demo Info.plist**（§20 红线）。

---

## 28. CSJ 依赖边界（§22 表）

| 项 | TK | TB |
|---|---|---|
| Flame XCFramework | 同一个 | 同一个 |
| AnyThinkiOS | ✅ 有 | ❌ 无 |
| TK Sigmob Adapter | ✅ 有 | ❌ 无 |
| ToBid Core | ✅ 有 | ✅ 有 |
| ToBid CSJ Adapter | ❌ 无 | ✅ 有 |
| CSJ SDK (Ads-CN/BUAdSDK) | ✅ 有（via AnyThinkMediation） | ✅ 有（via ToBid CSJAdapter） |
| module name | flame_sdk_ios | flame_sdk_ios |
| AnyThink link | weak | weak |
| **TbBannerAdapter** | ❌ 无（TK 用 AtBannerAdapter） | ✅ 有（Phase 5A.16C 新增） |

---

## 29. 修改文件（§34）

| 文件 | 类型 | 说明 |
|---|---|---|
| `flame_sdk_ios/adapter/tb/TbBannerAdapter.h` | 新增 | 镜像 AtBannerAdapter.h |
| `flame_sdk_ios/adapter/tb/TbBannerAdapter.m` | 新增 | FlameBannerAdapterProtocol + WindMillBannerViewDelegate（10 方法，Express 实现 + SelfRender no-op） |
| `flame_sdk_ios/mediation/tb/FlameTBProvider.m` | 修改 | +1 import、Banner 占位 nil → 创建 adapter |
| `doc/flame_mediation/phase-5a.16c-tb-banner-adapter-implementation-report.md` | 新增 | 本报告 |
| `doc/flame_mediation/09_change_log.md` | 修改 | Phase 5A.16C 条目 |
| `README.md` | 修改 | 横幅 ToBid 行注释更新 |

**SDK 业务代码零改动**（无 Reward/Interstitial/Splash/AtBannerAdapter/FlameTKProvider 改动，无 Flame 公共 API 改动）。
**Demo 代码零改动**。
**project.pbxproj 零改动**（PBXFileSystemSynchronizedRootGroup）。

---

## 30. 已知问题

| 问题 | 归属 | 处理 |
|---|---|---|
| Flame xcframework 缺 arm64 simulator slice | SDK 构建脚本（pre-existing） | 模拟器 build 在 Apple Silicon 失败（与 Banner 无关）；建议后续 xcFramework_build.sh 加 arm64 sim slice |
| Demo Info.plist 缺 CSJ SKAdNetwork IDs | Demo 配置 | Phase 5A.16D Banner 真机填充前必须加 |
| ToBid 后台 CSJ Banner 广告位未配置 | ToBid 后台 | Phase 5A.16D |
| Flame pMap 无 banner 映射 | Flame 后台 | Phase 5A.16D |
| Demo `banner = ""` | Demo 配置 | Phase 5A.16D 本地临时填入测试 placementId |
| TbBannerAdapter 真机未触发 | SDK 验证项 | 依赖 Phase 5A.16D 后台 + pMap + Demo 配置 |

---

## 31. Phase 5A.16D 前置条件

进入 Phase 5A.16D 前需完成：
1. ToBid 后台开通 CSJ 渠道 + 创建 Banner 测试广告位
2. Flame 后台 pMap 加 banner placementId 映射
3. Demo Info.plist 加 CSJ SKAdNetwork IDs（10+ 个）
4. Demo 本地临时填 banner placementId（不提交）
5. ATT 配置（如需 IDFA）

Phase 5A.16D 验证内容：load → fill → addSubview → exposure → refresh → click → close → destroy 完整闭环。

---

## 32. Git

**SDK commit**（adapter + provider + 文档）：
- 消息：`feat: add ToBid banner adapter`
- 排除：project.pbxproj 环境差异、Pods、Podfile.lock、xcworkspace、DerivedData、build、Archives、Demo placementId、Demo Info.plist 临时 SKAdNetwork、真机日志

**Demo commit**：无（Demo 代码零改动）

| 操作 | 状态 |
|---|---|
| push | ❌ 未执行 |
| tag | ❌ 未执行 |
| release | ❌ 未执行 |
| pod repo push | ❌ 未执行 |
| 修改远程 flame-specs | ❌ 未执行 |
| 修改版本号 | ❌ 未执行 |

---

## 33. 结论

| 项 | 结果 |
|---|---|
| 公共 API 是否变化 | ❌ 未变（FlameBannerListener / FlameBannerAd / FlameBannerAdapterProtocol 零改动） |
| Demo 调用方式是否变化 | ❌ 未变（Demo 代码零改动） |
| 单一 XCFramework | ✅ 保持 |
| AnyThink 隔离 | ✅ 静态依赖隔离 + LC_LOAD_WEAK_DYLIB 无回归；运行时无 ADX 弹窗将在 Phase 5A.16D 真机验证 |
| **TbBannerAdapter 是否实现** | ✅ 实现（Express 模式完整，SelfRender 占位） |
| FlameTBProvider Banner 工厂接入 | ✅ |
| XCFramework 构建 | ✅ 两 slice 符号 + diag 齐全 |
| TB iphoneos BUILD | ✅ SUCCEEDED（编译/链接通过；不等同于 Banner 真机运行验证，见 §20 口径修正） |
| TK 编译回归 | ✅ 28 pods BUILD SUCCEEDED（无 CSJAdapter 泄漏） |
| 模拟器构建 | ⚠️ pre-existing Flame slice 限制（与 Banner 无关） |
| CSJ Banner 真机填充 | ❌ 未验证（Phase 5A.16D） |
| **是否可以进入 Phase 5A.16D** | ✅ 可以（Adapter 已实现 + 构建通过；5A.16D 需先配后台 + pMap + Demo Info.plist） |

---

## 34. 下一阶段

**Phase 5A.16C 完成后停止。TbBannerAdapter 已实现但真实 CSJ Banner 填充、展示、刷新、点击和销毁闭环尚未验收。等待用户确认后台广告位和 pMap 配置后进入 Phase 5A.16D。**

---

## 35. /compact

Phase 5A.16C 完成：新增 `TbBannerAdapter.{h,m}`（Express 模式完整实现 + SelfRender 占位），接入 FlameTBProvider Banner 工厂。关键差异已落实：`loadAdData`（非 loadAd）、`initWithRequest:expectSize:`（camelCase）、`isAdValid`（非 isAdReady）、`retrieveAdView` 返回 strong 持有的 WindMillBannerView（Demo 自己 addSubview）、auto-refresh 由 ToBid 后台控制（Adapter 不加 Timer）、首次失败不内部重试（与 TK 一致，Demo RetryScheduler 负责）、destroy 靠 delegate=nil+removeFromSuperview+nil（WindMill 无 destroy 方法）。XCFramework 构建成功，TbBannerAdapter 符号 + TB_BANNER_DIAG（24 条）两 slice 命中，AnyThink weak-link 无回归。TB 真机 BUILD SUCCEEDED，App 含 WindMillBannerView+BUNativeExpressBannerView+WindMillCSJAdapter 符号。TK 28 pods BUILD SUCCEEDED 不受影响。模拟器 build 失败是 pre-existing Flame slice 限制（与 Banner 无关）。Demo `banner=""` → Adapter 已链接但未触发（真实填充待 5A.16D）。本地 commit `feat: add ToBid banner adapter`，未 push/tag/release。
