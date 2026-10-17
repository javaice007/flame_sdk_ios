# 12 · Public API 兼容基线（PUBLIC_API_COMPATIBILITY_BASELINE）

> 只记录现状：现有客户现在看到什么。不含任何未来设计。
> 证据：framework Headers 目录 10 个公共头 + Demo 实际调用（adsurge-ios-demo）。

## 1. Public API Surface 总表

分类标注：STABLE_PUBLIC＝客户在用、语义稳定；PUBLIC_BUT_LEGACY＝公开但属历史遗留；PUBLIC_INTERNALISH＝公开但偏内部用途；NOT_PUBLIC＝非公共（列出仅为划界）。

### INIT / CONFIG（FlameSdk.h）

| API | 签名摘要 | 客户是否直接调用 | 稳定性 | 备注 |
|---|---|---|---|---|
| 初始化（无回调） | `+initWithAppId:appKey:` | 是 | STABLE_PUBLIC | |
| 初始化（带回调） | `+initWithAppId:appKey:callback:` | 是（Demo 用） | STABLE_PUBLIC | 回调 id<FlameCallback>；success=配置+平台初始化成功 |
| 清空缓存/重置 | `+clear` | 是（Demo 每次 init 前） | STABLE_PUBLIC | Failed 后重试必经 |
| debug 开关 | `+setDebug:(BOOL)` | 是 | STABLE_PUBLIC | 只作用于 AnyThink/WindMill 日志 |
| 已初始化查询 | `+isInitialized` | 是 | STABLE_PUBLIC | |
| 初始化校验 | `+checkInitialization` | 内部偏多 | PUBLIC_INTERNALISH | 打日志版本，Impl 层在用 |
| 单例 | `+sharedInstance` | 少 | PUBLIC_INTERNALISH | 版本号是实例方法 |
| 版本号 | `-getVersion` | 可选 | STABLE_PUBLIC | 返回 FLAME_SDK_VERSION 常量（1.0.0），非 Bundle 版本 |
| init 回调协议 | `FlameCallback`：`-success` / `-fail:(NSString*)code desc:(NSString*)desc` | 是 | STABLE_PUBLIC | 字符串错误码 |

### REWARD（FlameRewardAd.h）

| API | 签名摘要 | 客户调用 | 稳定性 |
|---|---|---|---|
| 创建 | `+createRewardAdWithViewController:placementId:listener:` | 是 | STABLE_PUBLIC |
| 加载 | `-load` / `-loadWithUserId:userCustomData:` | 是（带参版） | STABLE_PUBLIC |
| 就绪/加载中 | `-isReady` / `-isLoading` | 是（isReady） | STABLE_PUBLIC（isLoading 在 TB 线恒 NO——语义不一致） |
| 展示 | `-show` | 是 | STABLE_PUBLIC |
| 销毁 | `-destroy` | 是 | STABLE_PUBLIC |
| 监听 | `FlameRewardListener` 7 方法全 @optional | 是（Demo 全实现） | STABLE_PUBLIC |

### SPLASH（FlameSplashAd.h）

| API | 签名摘要 | 备注 |
|---|---|---|
| 创建 | `+createSplashAdWithViewController:placementId:listener:` | |
| 加载 | `-load` / `-loadWithUserId:userCustomData:` | |
| 就绪 | `-isReady` / `-isLoading` | |
| 展示 | `-show:(UIWindow*)window` | **UIWindow 参数（与 Reward/Inter 不同）** |
| 销毁 | `-destroy` | |
| 监听 | `FlameSplashListener` @optional：onAdLoaded/onAdShow/onAdClicked/**onAdReward:userId:userCustomData:**/onAdError/onAdClosed/**onAdShowComplete:userId:userCustomData:**/**onAdLoadTimeout**（splash 特有） |

### INTERSTITIAL（FlameInterstitialAd.h）

| API | 签名摘要 | 备注 |
|---|---|---|
| 创建 | `+createInterstitialAdWithViewController:placementId:listener:` | |
| 加载/就绪/展示/销毁 | `-load` / `-loadWithUserId:` / `-isReady` / `-isLoading` / `-show` / `-destroy` | |
| 监听 | `FlameInterstitialListener` @optional：onAdLoaded/onAdError/onAdClicked/onAdShow/onAdClosed/**onAdReward:(NSString*)placementId userId:… userCustomData:…**（首参是 placementId，与 Reward 的 transId 尾参不同） |

### BANNER（FlameBannerAd.h + Material + RenderSlots）

| API | 签名摘要 | 备注 |
|---|---|---|
| 创建 Express | `+createBannerAdWithPlacementId:listener:` | |
| 创建 SelfRender | `+createSelfRenderBannerAdWithPlacementId:listener:` | TB 线设计内降级 14003 |
| 加载 | `-loadWithWidth:height:viewController:` / `-loadWithUserId:…:width:height:viewController:` | 尺寸+VC 在 load 阶段 |
| 视图获取 | `-(UIView*)retrieveAdView` | Express 模式 |
| 物料 | `-retrieveMaterials` / `-bindMaterialAtIndex:slots:` / `-unbindMaterial` | SelfRender 模式；FlameBannerAdMaterial/RenderSlots 模型 |
| 移除/销毁 | `-remove` / `-destroy` / `-isReady` / `-isLoading` | |
| 监听 | `FlameBannerListener` @optional：onAdLoaded/onAdError/onAdShow/onAdClicked/onAdClosed/**onAdMaterialReady:(NSArray<FlameBannerAdMaterial*>*)** |

### NATIVE（FlameNativeAd.h）

| API | 签名摘要 | 备注 |
|---|---|---|
| 创建 | `+createNativeAdWithViewController:placementId:listener:` | |
| 加载 | `-loadWithWidth:height:` / `-loadWithUserId:…:width:height:` | |
| 展示 | `-showInContainer:(UIView*)container` | |
| 渲染偏好 | `-setRenderType:(FlameNativeRenderType)` | **非绑定 hint**：实际按物料 feedADMode 自动分支，不一致仅日志 |
| 移除/销毁 | `-remove` / `-destroy` / `-isReady` / `-isLoading` | |
| 监听 | `FlameNativeListener`：onAdLoaded/onAdError/onAdShow/onAdClicked/onAdClosed——**无 @optional，全 @required** |

## 2. Host 使用方式基线（Demo 实证）

```
FlameSdk.clear() → setDebug(false) → initWithAppId:appKey:callback:
→ whenReady 后：create*(FlamePlacementId, listener) → load(可带 userId/customData)
→ onLoaded → show（前查 isReady）→ onClosed → destroy/再 load
→ onError → 重试调度（14003/14004/14002 不重试）
```

## 3. 核心契约摘要

- **Placement ID Contract**：宿主只传 **Flame 平台广告位 ID**；映射（pIds: Flame→TopOn/ToBid）由服务端下发 + getPId 完成；**任何公共 API 不收第三方 ID**（THIRD_PARTY_PLACEMENT_ID_EXPOSED = NO）
- **Reward Contract**：onAdReward = 客户端平台回调（无服务端 verify）；TK transId 恒空 / TB customData 恒空；skip 不可感知；无防重
- **Init Contract**：success = 配置成功（远端或缓存回退，不可区分）+ 聚合平台初始化成功；Failed 后必须 clear；回调 TK 事实主线程 / TB 未保证
- **Version Contract**：getVersion = 请求 version = FLAME_SDK_VERSION 常量；发布版本 = podspec + binary repo tag；framework plist "1.0" 漂移
- **Callback Contract**：字符串错误码（14xxx/15000 + 三方透传 + "-1"）；广告回调线程未归一；show 未 ready 静默
- **Known Semantic Gaps**（详见 06/10）：eCPM 无、reward verify 无、TB isLoading 恒 NO、splash/native listener 协议风格不一致、Native listener 全 required
