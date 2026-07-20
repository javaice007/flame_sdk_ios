# Phase 5A.18B：ToBid Native Template Adapter 实现与静态验证

> **本阶段性质**：实现 `TbNativeAdapter`（Native Template/Express 模式），Native SelfRender 明确降级。**不修改 Flame 公共 API、不修改 Demo 调用方式、不修改 AtNativeAdapter。**
>
> **最终状态**：本地 feature commit（未 push、未 tag、未 release）。真实填充/曝光/点击留 Phase 5A.18C。

---

## 1. 基线与决策

| 项 | 值 |
|---|---|
| 开始 HEAD | `4e0bda6`（Phase 5A.17B） |
| 5A.18A docs commit | `7494748 docs: research TB native template mapping (Phase 5A.18A)` |
| 5A.18B feature commit | 本阶段创建：`feat: add ToBid native template adapter` |
| Demo 5A.18B commit | 独立创建：`fix: skip retry for unsupported native capability` |

### 1.1 范围（严格遵守）

| 能力 | TK | TB 5A.18B 目标 |
|---|---|---|
| Native Template / Express | ✅ 支持（AnyThink 统一 ATNativeAD*） | ✅ **实现**（WindMillNativeAdsManager → feedADMode=NativeExpress → refreshData: + 异步 renderSuccess） |
| Native SelfRender | ✅ 支持 | ⚠️ **暂不实现，明确降级**（`[TB_NATIVE_SELF_RENDER_NOT_IMPLEMENTED]`，原因不是 ToBid 不支持，而是 SDK 桥接未接入） |

---

## 2. 18A 结论与方案修正

Phase 5A.18A 报告已修正口径：方案 A **仅适用于 Native Template / Native Express**。Native SelfRender 被明确排除在 5A.18B 范围外，原因表述为"当前 Flame SDK 的 ToBid Native SelfRender 桥接尚未接入"（**不是**"ToBid 不支持"——ToBid 底层 SelfRender 路径完整）。

---

## 3. 新增文件

### 3.1 `flame_sdk_ios/adapter/tb/TbNativeAdapter.h`

- 与现有 TB Adapter 同目录（`adapter/tb/`，非 spec 建议的 `mediation/tb/adapters/`——与项目实际目录结构保持一致）
- 实现 `<FlameNativeAdapterProtocol>` + `<WindMillNativeAdsManagerDelegate>` + `<WindMillNativeAdViewDelegate>`
- 前向声明 WindMillNativeAdsManager/WindMillNativeAd/WindMillNativeAdView（头文件不 import 第三方 SDK）

### 3.2 `flame_sdk_ios/adapter/tb/TbNativeAdapter.m`

ivars：`_manager` / `_nativeAd` / `_nativeAdView` / `_container` (weak) / `_requestedSize` / 状态标记 `_isLoading`/`_loaded`/`_rendering`/`_rendered`/`_shown`/`_destroyed`/`_selfRenderUnsupportedReported` / `_generation`。

---

## 4. Load 流程（Express 模式）

1. SelfRender 分支提前返回（见 §16）
2. 参数校验：placementId 非空 → viewController 非空 → size 合法（顺序与 AtBannerAdapter/AtNativeAdapter 一致）
3. `cleanupCurrentAd` + `_generation += 1` + `_destroyed = NO`
4. 创建 `WindMillAdRequest`（placementId + 可选 userId）
5. 创建 `WindMillNativeAdsManager(initWithRequest:)` + `delegate = self` + `adSize = requestedSize`
6. `_isLoading = YES; _loaded/_rendering/_rendered/_shown = NO`
7. `[manager loadAdDataWithCount:1]`

**禁止**：load 阶段创建 View / 调 showInContainer / 触发 onAdShow / 用 WindMillBannerView / 并发请求。

---

## 5. Manager load success 回调

`nativeAdsManagerSuccessToLoad:`（`:2210`）：

1. stale 守卫：`nativeAdsManager != _manager` → ignore
2. destroyed 守卫
3. `_isLoading = NO`
4. `ads = [manager getAllNativeAds]`
5. 遍历选第一个 `ad != nil && ad.ready`
6. 无有效广告 → `onAdError(15000, "ToBid Native load returned no valid ad")`
7. **feedADMode 保护**：`selected.feedADMode != WindMillFeedADModeNativeExpress` → `onAdError(14004, "当前 ToBid Native 广告位未返回模板渲染广告，请检查后台渲染模式配置")` ← 不强行渲染 SelfRender
8. 保存 `_nativeAd = selected`；`_loaded = YES`
9. 异步派发到主线程 `onAdLoaded`（generation 守卫）
10. **不在此时触发曝光**（等 Demo 调 showInContainer）

---

## 6. Manager load failure

`nativeAdsManager:didFailWithError:`（`:2216`）：

1. stale + destroyed 守卫
2. `_isLoading = NO; _loaded = NO`
3. 保留 ToBid 错误码 + 描述（`code = "%ld" of error.code`，`desc = error.localizedDescription`）
4. 异步主线程 `onAdError`
5. **不**伪装成 unsupported；**不**内部重试

---

## 7. showInContainer 实现

1. SelfRender 模式：安全 no-op + log（不重复回调）
2. 前置校验：destroyed / container / nativeAd/ready/loaded / 非已 rendering
3. `_container = container` (weak) + 记录 `_containerBoundsAtShow`
4. 清理旧 `_nativeAdView`（若有）
5. 创建 `WindMillNativeAdView(initWithFrame:CGRectMake(0,0,viewWidth,viewHeight))`（宽度优先用 container.bounds.width，回退 requestedSize.width；高度用 requestedSize.height）
6. `delegate = self` + `viewController = self.viewController`
7. `_rendering = YES; _rendered = NO`
8. `[nativeAdView refreshData:_nativeAd]` ← **触发 Native Express 异步模板渲染**

**不得**把 refreshData: 调用成功当作渲染成功。

---

## 8. Native Express 渲染成功

`nativeExpressAdViewRenderSuccess:`（`:2145`）：

1. stale（view 指针）+ destroyed 守卫
2. `_rendering = NO; _rendered = YES`
3. **动态高度处理**（保守，不修改公共 API、不强行拉伸）：
   - 读 `nativeAdView.bounds.size.height` 作为模板真实高度
   - 高度 > 0 用真实值，否则回退 `_requestedSize.height`
   - `nativeAdView.frame = CGRectMake(0, 0, containerWidth, renderHeight)`
   - `[container addSubview:nativeAdView]`
4. **不**在此触发 onAdShow —— 曝光必须来自 `nativeAdViewWillExpose:` 真实回调

### 8.1 动态高度策略（Phase 5A.18B 首版）

- Flame 公共 API 无动态高度通知机制（`showInContainer:` 只传容器，无尺寸回调）
- 不修改公共 API、不强行拉伸
- 首版策略：nativeAdView frame 设为 `containerWidth × 模板真实高度`，加为 container 子视图
- container 自身 frame 由 Demo 管（SwiftUI/AutoLayout），不擅自修改
- 若真实高度超过 container 且会裁切：首版如实暴露，留 5A.18C 真机验证后评估是否需要 Demo 侧调整容器策略

---

## 9. 渲染失败

`nativeExpressAdViewRenderFail:error:`（`:2148`）：

1. stale + destroyed 守卫
2. `_rendering = NO; _rendered = NO`
3. 清理失败的 `_nativeAdView`（unregisterDataObject + removeFromSuperview + nil）
4. `onAdError(code, "ToBid Native 模板渲染失败: ...")` ← 描述明确区分 load 失败 vs 渲染失败
5. **不**自动重新 showInContainer（防止循环）

---

## 10. 曝光/点击/dislike 映射

| ToBid 回调 | 位置 | Flame 映射 |
|---|---|---|
| `nativeAdViewWillExpose:` | `:2151` | `onAdShow`（`_shown` 防重复首次曝光） |
| `nativeAdViewDidClick:` | `:2154` | `onAdClicked` |
| `nativeAdView:dislikeWithReason:` | `:2177` | `onAdClosed` |
| `nativeAdDetailViewClosed:` | `:2157` | 仅日志 |
| `nativeAdDetailViewWillPresentScreen:` | `:2160` | 仅日志 |
| `nativeAdView:playerStatusChanged:userInfo:` | `:2165` | 仅日志（Flame 无视频回调） |
| `nativeAdView:didUpdatePlaybackTime:totalTime:` | `:2173` | 仅日志（debug 级） |

所有回调：stale（view 指针）+ destroyed 守卫。

---

## 11. ready/loading 语义

### isLoading
- manager 请求期间 YES
- manager 回调后 NO
- 模板渲染期间**不**等同 load（内部 `_rendering` 单独标记）

### isReady
- `_destroyed` → NO
- `_renderType != Express` → NO
- `!_loaded || _nativeAd == nil` → NO
- 否则：`return _nativeAd.ready`

**禁止**：manager 创建后直接 ready / onAdLoaded 后永久 ready / destroy 后 ready / SelfRender 降级状态 ready。

---

## 12. 销毁与 stale callback

`destroy`：
1. `_destroyed = YES`
2. `_generation += 1`（失效所有迟到异步块）
3. `cleanupCurrentAd`：nativeAdView delegate=nil + unregisterDataObject + removeFromSuperview + nil；nativeAd=nil；manager delegate=nil + nil
4. 状态全置 NO；listener/viewController/placementId/requestedSize/container 置 nil
5. **不**触发 onAdClosed

所有异步块检查 `_destroyed || _generation != gen`；所有 delegate 回调检查 view/manager 指针 + `_destroyed`。

---

## 13. 统一诊断日志

前缀 `[TB_NATIVE_DIAG]`，涵盖：load / manager success/failure / select ad / feedADMode / showInContainer / render start/success/failure / exposure / click / close/dislike / destroy / stale callback。placementId 不输出到正式文档（已脱敏）。

SelfRender 降级专用前缀 `[TB_NATIVE_SELF_RENDER_NOT_IMPLEMENTED]`（字段：platform/mediation/mediationSdkVersion/adFormat/renderMode/capability/action/expressNativeAffected/message），每次生命周期只打印一次（`_selfRenderUnsupportedReported`）。

---

## 14. SelfRender 降级

当 `_renderType == FlameNativeRenderTypeSelfRender`：

- **不**调用 WindMillNativeAdsManager/WindMillNativeAd/WindMillNativeAdView/GDT Native 请求
- 原因表述："当前 SDK 的 ToBid Native 自渲染能力尚未接入"（**不是**"ToBid 不支持"）
- 复用 `ERROR_CODE_UNSUPPORTED_PLATFORM`（14003）—— Flame 公共错误体系无更贴切的"未实现"码，描述明确说明语义
- 日志 `[TB_NATIVE_SELF_RENDER_NOT_IMPLEMENTED]`，每生命周期一次
- 异步主线程回调一次 `onAdError`，generation 守卫
- `showInContainer:` 安全 no-op（不重复回调）
- `destroy` 幂等

---

## 15. Provider 工厂接入

`FlameTBProvider.m`：

- import `TbNativeAdapter.h`（在 `TbBannerAdapter.h` 后）
- Native 工厂 `return nil` → 改为返回 `[[TbNativeAdapter alloc] initWithViewController:atPlacementId:listener:]`
- 参数与 FlameTKProvider Native 工厂一致
- 不影响 Banner/Reward/Interstitial/Splash 工厂
- 不在 +load 阶段创建 Native manager

---

## 16. 构建验证

### 16.1 XCFramework

```
✅ 双 Archive SUCCEEDED
✅ XCFramework 生成
✅ TbNativeAdapter 符号两 slice 各 2（_OBJC_CLASS_$_ + _OBJC_METACLASS_$_）
✅ TB_NATIVE_DIAG 字符串两 slice 各 34（ASCII 段，全部诊断日志）
✅ TB_NATIVE_SELF_RENDER_NOT_IMPLEMENTED 两 slice 各 1（UTF-16 段，含中文）
✅ ToBid selector refs 编译进 binary：
   nativeAdsManagerSuccessToLoad=3, nativeExpressAdViewRenderSuccess=2,
   getAllNativeAds=2, feedADMode=5, loadAdDataWithCount=2
✅ AnyThink LC_LOAD_WEAK_DYLIB 无回归
✅ TbBannerAdapter / TbSplash / TbInterstitial / TbReward 符号无回归
```

### 16.2 TB Demo

```
✅ clean pod install（6 pods）
✅ iphoneos BUILD SUCCEEDED
✅ AnyThink ABSENT
✅ GDTAdapter/ToBid 依赖不变
✅ 无新增 pod / 无 undefined symbols / 无 duplicate symbols / 无 module 错误
```

### 16.3 TK Demo（临时切 TK 回归）

```
✅ clean pod install（28 pods）
✅ iphoneos BUILD SUCCEEDED
✅ AtNativeAdapter 未修改
✅ ToBid Native 不进入 TK（TbNativeAdapter 不在 TK 编译路径）
✅ BUILD SUCCEEDED
```

### 16.4 Simulator（已知限制）

Flame xcframework simulator slice = x86_64-only（GDT SDK 限制）。**不使用 EXCLUDED_ARCHS 掩盖**，如实记录。

---

## 17. 后台要求

| 项 | 要求 |
|---|---|
| ToBid 聚合位类型 | **Native 聚合位**（不能复用 Banner 位） |
| 渲染模式 | 模板渲染（NativeExpress），后台需配置广告源返回 `feedADMode == NativeExpress` |
| 下挂广告源 | GDT 模板原生（`GDTNativeExpressAd`，已支持）/ CSJ 模板原生（需后台配） |
| Flame pMap 字段 | **复用 `native` 字段**（FlameNative 已有独立 pMap key，不需新增） |
| Demo 配置 | `TB.native = "q..."`（用户填 ToBid Native 聚合位 ID） |
| 当前是否配置 | **未配置**（本阶段不要求真实填充，留 5A.18C） |

---

## 18. 未验证项（留 5A.18C）

- 真机 Native Express 模板填充（需后台配好 Native 聚合位）
- 真机模板 View 展示 + 动态高度在 SwiftUI 容器的实际表现
- 曝光 / 点击 / dislike 真机回调
- 视频广告播放
- destroy 后 re-enter 完整闭环
- 自加载（`nativeAdsManagerSuccessAutoToLoad:`）真机行为

---

## 19. 修改文件

### 19.1 SDK（本阶段 feature commit）

| 文件 | 改动 |
|---|---|
| `flame_sdk_ios/adapter/tb/TbNativeAdapter.h` | 新增（Adapter 头文件 + 前向声明） |
| `flame_sdk_ios/adapter/tb/TbNativeAdapter.m` | 新增（Express 完整 + SelfRender 降级 + generation/stale 守卫 + 动态高度） |
| `flame_sdk_ios/mediation/tb/FlameTBProvider.m` | import TbNativeAdapter.h；Native 工厂 `return nil` → 返回 TbNativeAdapter |

### 19.2 Demo（独立 commit，仅不可重试短路相关）

| 文件 | 改动 |
|---|---|
| `Sources/Ad/NativeAdManager.swift` | onError 加 unsupported/invalid 不可重试短路；新增 NonRetryableErrorCodes 嵌套枚举 |

### 19.3 未改动（红线遵守）

- `FlameNativeAd.h` / `FlameNativeListener` / `FlameNativeRenderType` / `FlameNativeAdapterProtocol`（公共 API 零修改）
- `AtNativeAdapter.{h,m}`（TK Native 不变）
- `FlameTKProvider.m`（TK Provider 不变）
- Demo `NativeAdManager` 业务调用方式不变（只加错误分类短路）
- `flame_sdk_ios.podspec` / `flame_sdk_ios_tb.podspec`（不增减依赖）

---

## 20. Git

| 项 | 状态 |
|---|---|
| docs commit（5A.18A） | `7494748 docs: research TB native template mapping` |
| feature commit（5A.18B SDK） | 本阶段创建：`feat: add ToBid native template adapter` |
| Demo commit（5A.18B） | 独立创建：`fix: skip retry for unsupported native capability`（仅含 NonRetryableErrorCodes + onError 短路，不含用户其他本地修改） |
| push / tag / release | 未 |

### 20.1 严格排除

SDK commit 排除：project.pbxproj 环境差异、.zcode、Pods、Podfile.lock、xcworkspace、build、Archives、测试 placementId、真机日志。

Demo commit 排除：Pods、Podfile.lock、xcworkspace、project.pbxproj 环境差异、测试 placementId、其他用户本地修改（isInitialized/isConfigured 守卫、其他 .swift、Info.plist、Diagnostics、AGENTS.md、err.log 等）。

---

## 21. Phase 5A.18C 前置条件

1. 用户在 ToBid 后台新建 Native 聚合位 + 下挂 GDT/CSJ 模板原生广告源
2. 用户配 `TB.native = "q..."`（ToBid Native 聚合位 ID）+ Flame pMap `native` 字段映射
3. 真机 Run 验证完整链路：load → manager success → feedADMode=NativeExpress → onAdLoaded → showInContainer → refreshData → renderSuccess（含动态高度）→ addSubview → exposure → click → dislike → destroy

如动态高度在真机表现有问题（裁切/约束冲突），单独评估 Demo 容器策略调整，不修改公共 API。

---

## 22. 失败处理回顾（spec §24）

| 失败场景 | 本阶段处理 |
|---|---|
| A. 动态高度无法在现有公共 API 内安全展示 | 首版用 nativeAdView.frame = containerWidth × 模板真实高度；不修改公共 API；真机验证后如有裁切再评估 |
| B. Native Express 返回 SelfRender 模式 | feedADMode 保护 → `onAdError(14004, "未返回模板渲染广告")`，不强行渲染 |
| C. GDTAdapter 模板符号缺失 | 已验证无此问题（`NativeExpressAdsManager` 符号存在） |
| D. Provider 接入导致原广告回归 | TB/TK Demo 构建通过，Banner/Splash/Interstitial/Reward 符号无回归 |
| E. Native SelfRender 需要实现 | 维持明确降级，不在 18B 扩范围 |

---

## 23. 结论

| 问 | 答 |
|---|---|
| Native Template 桥接是否完成 | ✅ 是（静态实现 + 构建/符号验证） |
| Native SelfRender 状态 | ⚠️ 明确降级为"未实现"（非"平台不支持"） |
| 公共 API 是否变化 | ❌ 零修改 |
| Demo 业务调用是否变化 | ❌ 零修改（仅加错误分类短路，独立 commit） |
| 是否可进入 18C | ✅ 是（前提：用户后台配置 Native 聚合位） |

---

## 24. /compact

Phase 5A.18B 完成（未 push/tag/release）：新增 `TbNativeAdapter.{h,m}` 实现 Native Template/Express（WindMillNativeAdsManager → feedADMode=NativeExpress 保护 → WindMillNativeAdView.refreshData: 异步渲染 → renderSuccess 后 addSubview 到 container，动态高度取模板真实值不强行拉伸），Native SelfRender 明确降级为"未实现"（`[TB_NATIVE_SELF_RENDER_NOT_IMPLEMENTED]` + ERROR_CODE_UNSUPPORTED_PLATFORM，原因表述"SDK 桥接尚未接入"非"ToBid 不支持"）。generation + destroyed 守卫阻断迟到异步回调，stale 守卫用 view/manager 指针比对（与现有 TB Adapter 一致）。FlameTBProvider Native 工厂 `return nil` → 返回 TbNativeAdapter。Flame 公共 API / Demo 调用方式 / AtNativeAdapter 零修改。Demo NativeAdManager 加 NonRetryableErrorCodes 平台无关短路（独立 commit）。XCFramework 双 slice 构建成功：TbNativeAdapter 符号 + TB_NATIVE_DIAG(34) + TB_NATIVE_SELF_RENDER_NOT_IMPLEMENTED + ToBid selector refs（nativeAdsManagerSuccessToLoad/getAllNativeAds/feedADMode/loadAdDataWithCount/nativeExpressAdViewRenderSuccess）全部命中；AnyThink LC_LOAD_WEAK_DYLIB 无回归；TbBanner/Splash/Interstitial/Reward 符号无回归。TB Demo 6 pods + TK 临时切 28 pods BUILD SUCCEEDED，已恢复 TB。后台需新建 ToBid Native 聚合位（不能复用 Banner 位），pMap 复用 `native` 字段。真实填充/曝光/点击留 5A.18C。
