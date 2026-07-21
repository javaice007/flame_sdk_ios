# Phase 5A.18D-A：TK Native 双渲染模式真实行为与 TB 对齐方案调研

> **本阶段性质**：只读调研，禁止直接编码。**目的**：澄清 TK 端 `FlameNativeRenderType` 的真实语义，找出 TB 与 TK 行为差异，设计对齐方案。
>
> **最终判断**：TK 端 `renderType` 是**非绑定 hint**——请求阶段完全不使用，show 阶段**始终以物料 `isExpressAd` 为准**自动分支；TB 当前严格按 `renderType` 分流（SelfRender→14003 / Express 非 NativeExpress→14004），与 TK 行为不一致。对齐方案：**方案 A（统一按物料自动分支）**——详见 §6。

---

## 1. 基线

| 项 | 值 |
|---|---|
| SDK HEAD | `811f430`（Phase 5A.18C.1 Mintegral Adapter 接入） |
| Demo HEAD | `6bb3619`（Phase 5A.18B NativeAdManager 不可重试短路） |
| TB 当前行为 | SelfRender（=1）→ 14003 降级；Express（=2）+ feedADMode≠5 → 14004 |
| 本地 AnyThink Header | **可用**（`Pods/AnyThinkiOS/.../AnyThinkSDK.xcframework/.../Headers/`） |
| 本轮 5A.18C 真机结果 | GDT 返回 feedADMode=3（自渲染 LargeImage）；CSJ/Mintegral 测试位 800110 |

---

## 2. 核心结论（最高优先级）

### 2.1 TK 端 `FlameNativeRenderType` 是**非绑定 hint**

| 维度 | TK 实际行为 |
|---|---|
| 请求阶段使用 renderType | **否**——load 调用与 renderType 完全无关（同 placementId / 同 extra / 同 API） |
| 展示阶段决定渲染模式 | **以物料 `isExpressAd` 为准**（`AtNativeAdapter.m:153`），caller 的 `renderType` 仅作日志标签 |
| renderType 与物料不一致 | 仅 log warning（`AtNativeAdapter.m:194-198`），不返回错误、不重 load、按物料渲染 |
| 公共头注释背书 | `FlameNativeAd.h:88` 显式："如果后台实际返回的素材类型与设置不一致, SDK 会自动降级到素材支持的渲染方式" |
| 最终渲染模式决定时机 | **show 阶段**（`showInContainer:`），不是请求阶段 |

### 2.2 TB 与 TK 行为差异（不一致）

| 场景 | TK 行为 | TB 当前行为（5A.18B） | 是否一致 |
|---|---|---|---|
| `renderType=Express`，物料是模板 | 走 Express（`rendererWithConfiguration:selfRenderView:nil`） | feedADMode=5 → 走 Express | ✅ 一致 |
| `renderType=Express`，物料是自渲染 | **按物料走 SelfRender**（无视 caller 偏好）+ log warning | feedADMode≠5 → **14004 错误**，不渲染 | ❌ **不一致** |
| `renderType=SelfRender`，物料是模板 | **按物料走 Express** + log warning | **load 阶段直接 14003**，不发请求 | ❌ **不一致** |
| `renderType=SelfRender`，物料是自渲染 | 按 SelfRender 渲染 | load 阶段 14003 | ❌ **不一致** |

**问题核心**：TB 在 5A.18B 设计了**严格分流**（renderType 决定一切），但 TK 实际是**物料驱动**（renderType 只是 hint）。这导致：
- Demo 显式传 `setRenderType(.express)` 后，GDT 返回 feedADMode=3（自渲染物料），TB 直接 14004 报错；**而 TK 同样场景会按自渲染渲染成功**
- 这也是为什么 5A.18C 真机验证始终走不到 showInContainer 链路——不是后台配错，是 TB 不接受非 NativeExpress 物料

---

## 3. renderType 到底控制什么（逐项回答）

### 3.1 参数传递链

```
Demo → FlameNativeAd.setRenderType:           [FlameNativeAd.h:91]
     → FlameNativeAdImpl.setRenderType:       [FlameNativeAdImpl.m:82-87]
       - 存到 self._renderType
       - 转发 [self.adapter setRenderType:renderType]
     → AtNativeAdapter.setRenderType:         [AtNativeAdapter.m:465-467]
       - 仅存到 _renderType（auto-synthesized ivar）
```

- 默认值：`FlameNativeRenderTypeSelfRender`（=1，`FlameNativeAdImpl.m:29` + `AtNativeAdapter.m:25`）
- 设置时机：Demo `load()` 中创建实例后立即设置（`NativeAdManager.swift:143`）
- load 前必须设置：**否**（不设置时用默认 SelfRender）
- load 后修改是否有效：**是**（`showInContainer:` 时读 `self.renderType`，但仅作 hint）

### 3.2 TK 请求阶段是否使用 renderType

**否**。证据（`AtNativeAdapter.m:36-81` load 方法体）：

```objc
// L80：load 调用与 renderType 无关
[[ATAdManager sharedManager] loadADWithPlacementID:self.atPlacementId
                                             extra:self.localExtra
                                          delegate:self];
```

检查 `self.localExtra` 组装（L60-77）：
- `kATAdLoadingExtraUserIDKey`（仅当 userId 非空）
- `kATAdLoadingExtraUserDataKeywordKey`（仅当 userCustomData 非空）
- `kATExtraInfoNativeAdSizeKey`（CGSize）
- `kATNativeAdSizeToFitKey = @(YES)`

**renderType 没有写入 extra**。全文 grep `kATExtraInfoNativeAdTypeKey`（AnyThink 唯一区分模板/自渲染的 extra key）= **0 引用**。且该 key 本身是 **GDT-only**（`ATAdManager+Native.h:51`）。

AnyThink 只暴露**一个统一 native load 入口**：`[ATAdManager loadADWithPlacementID:extra:delegate:]`（`ATAdManager.h:62-64`），没有 `ATNativeExpressAd` 或单独的模板 loader。

### 3.3 TK 展示阶段如何决定渲染模式

**物料 `isExpressAd` 优先于 Flame renderType**。证据（`AtNativeAdapter.m:152-155`，`showInContainer:` 内）：

```objc
id<ATNativeMaterialProtocol> nativeMaterial = offer.nativeAd;
BOOL materialIsExpress = nativeMaterial.isExpressAd || nativeMaterial.nativeAdRenderType == ATNativeAdRenderExpress;
BOOL preferExpress = self.renderType == FlameNativeRenderTypeExpress;
BOOL isExpressAd = materialIsExpress;   // ← 决定性：只看物料
```

**`isExpressAd` 是唯一驱动分支的变量**。`preferExpress` 仅用于日志标签（L182/186/196/325），**从不参与控制流**。

不一致时（L194-198）：
```objc
if (preferExpress != materialIsExpress) {
    [FlameLogger w:@"[AtNativeAdapter] Render type mismatch. preferred=%@, actualMaterial=%@. Rendering will follow actual material type."];
}
```
→ 仅 warning，**无 early return、无错误回调、无重 load**。物料赢。

### 3.4 renderType 不一致时 TK 如何处理

按物料自动分支，仅 log warning（见 §3.3）。具体：

- `renderType=SelfRender` + 物料 Express → 走 Express 分支（`rendererWithConfiguration:selfRenderView:nil`，AnyThink 完整渲染）
- `renderType=Express` + 物料 SelfRender → 走 SelfRender 分支（构造 `AtNativeSelfRenderView`，注册 click，调 renderer）

### 3.5 TK SelfRender 完整 View 结构

`AtNativeSelfRenderView : UIView`（`AtNativeSelfRenderView.h:17`）。详见 §4。

### 3.6 TK Express 完整模板 View 行为

`AtNativeAdapter.m:249-250`（Express 分支）：
```objc
[offer rendererWithConfiguration:config selfRenderView:nil nativeADView:nativeADView];
```
View 由 AnyThink 完整渲染，caller 传 `selfRenderView:nil`。

### 3.7 TB 应严格按参数分流，还是按返回物料自动兼容

**按返回物料自动兼容**（与 TK 一致）。详见 §6 方案 A。

### 3.8 公共 API 零修改前提下让 TB 与 TK 一致

可行。详见 §6。

---

## 4. TK SelfRender 完整审计

### 4.1 类与生命周期

- `AtNativeSelfRenderView : UIView`（`AtNativeSelfRenderView.h:17`），无 superclass/protocol
- init：`- initWithOffer:(ATNativeAdOffer *)offer`（`.h:42`），impl `.m:13-20` 调 `[super initWithFrame:CGRectZero]` + `setupUIWithOffer:`
- 无 destroy/dealloc/cleanup 方法（生命周期由 Adapter 管）

### 4.2 物料字段绑定（`setupUIWithOffer:` `.m:22-105`）

| Flame 字段 | AnyThink 来源 | UI 元素 |
|---|---|---|
| icon | `nativeAd.icon` / `iconUrl` | iconImageView |
| title | `nativeAd.title` | titleLabel |
| desc | `nativeAd.mainText` | textLabel |
| ctaText | `nativeAd.ctaText`（默认"了解更多"） | ctaLabel |
| coverUrl | `nativeAd.mainImage` / `imageUrl` | mainImageView |
| advertiser | `nativeAd.advertiser` | advertiserLabel |
| rating | `nativeAd.rating`（NSNumber） | ratingLabel |
| logo | `nativeAd.logo` | logoImageView |
| (无) | mediaView 由 Adapter 注入（`setMediaView:` `.m:157-166`） | mediaView |

### 4.3 布局

- **Manual frame-based**（`layoutSubviews` `.m:107-155`），非 Auto Layout
- padding=12.0，垂直栈：icon 行（icon+title/rating/advertiser+dislike top-right）→ 描述 → 媒体/mainImage 16:9 → CTA(height=44) → logo 右下
- `intrinsicContentSize`（`.m:168-184`）计算匹配高度

### 4.4 点击/曝光/destroy 责任

| 操作 | 责任方 | 证据 |
|---|---|---|
| registerClickableViews | **Adapter**（`AtNativeAdapter.m:267`，clickableViewArray=icon/title/text/cta/mainImage） | 不是 SelfRenderView 自己 |
| prepareWithNativePrepareInfo | Adapter（`.m:281`） | 字段：textLabel/advertiserLabel/titleLabel/ratingLabel/iconImageView/mainImageView/logoImageView/ctaLabel/dislikeButton/mediaView（L270-279） |
| 触发渲染/曝光 | Adapter 调 `[offer rendererWithConfiguration:selfRenderView:nativeADView:]`（`.m:282`）→ AnyThink 内部曝光 | `didShowNativeAdInAdView:` 回调 `.m:516` |
| destroy | Adapter（`.m:469-487`）；SelfRenderView 无 destroy | remove removeFromSuperview + nil listener/localExtra/placementId |

---

## 5. TB 当前严格分流点（5A.18B 实现）

`flame_sdk_ios/adapter/tb/TbNativeAdapter.m`：

| 分流点 | 行号 | 当前行为 |
|---|---|---|
| setRenderType | L59-61 | 存 `_renderType` + log |
| load 阶段 SelfRender 拦截 | L79-110 | `_renderType == SelfRender` → 立即 14003 + `[TB_NATIVE_SELF_RENDER_NOT_IMPLEMENTED]`，**不发请求** |
| isReady 严格判断 | L175 | `_renderType != Express` → 直接 return NO |
| showInContainer SelfRender no-op | L182-184 | SelfRender → 安全 no-op（不渲染） |
| Express 下 feedADMode 校验 | L305-313 | `selected.feedADMode != NativeExpress` → 14004，**不渲染** |

**关键差异**：
- TB 把 `renderType` 当成**请求时强约束**（SelfRender 直接拒绝请求）
- TB 把 `feedADMode` 当成**展示时强约束**（非 NativeExpress 直接拒绝渲染）
- TK 两者都是**非约束 hint**，物料驱动

---

## 6. TB 与 TK 行为对齐方案

### 6.1 方案 A（推荐）：TB 统一按物料自动分支

**设计**：TB 完全放弃"按 renderType 分流"，改为"按实际物料 feedADMode 自动分支"——与 TK 的 isExpressAd 自动分支同构。

#### 6.1.1 改动点

| 位置 | 当前 | 改为 |
|---|---|---|
| `TbNativeAdapter.m` load 阶段 SelfRender 拦截（L79-110） | renderType=SelfRender → 14003，不发请求 | **移除拦截**——load 始终发请求（与 TK 一致，renderType 仅存为 hint） |
| `TbNativeAdapter.m` Express 下 feedADMode 校验（L305-313） | feedADMode≠NativeExpress → 14004 | **移除严格校验**——保留物料，记录 feedADMode |
| `TbNativeAdapter.m` showInContainer（L182-184 + L218-237） | SelfRender no-op；Express 统一 refreshData | **按 feedADMode 分支**：NativeExpress(5) → refreshData 等 renderSuccess；非 5 → 按自渲染处理（目前不支持则降级，但不阻塞 load） |
| `[TB_NATIVE_SELF_RENDER_NOT_IMPLEMENTED]` 日志 | load 时即触发 | **仅在 showInContainer 遇到自渲染物料且 SDK 不支持时触发**（后置） |

#### 6.1.2 关键设计：TB SelfRender 物料的处理

当前 TB 没有 `TbNativeSelfRenderView`（类似 TK 的 `AtNativeSelfRenderView`），无法渲染自渲染物料。两个子选项：

**选项 A1（最小改动）**：
- load 阶段始终发请求（移除 SelfRender 拦截）
- showInContainer 时按 feedADMode 分支：
  - NativeExpress(5) → 完整模板渲染（现有逻辑）
  - 非 5 → 返回明确错误（如"当前 SDK 的 ToBid Native 自渲染能力尚未接入"），**不阻塞 load**
- 效果：Demo 可以正常 `onAdLoaded`，然后 show 时才知道能不能渲染。**与 TK 行为不完全一致**（TK 能渲染自渲染，TB 不能）

**选项 A2（完整对齐，需新增 TbNativeSelfRenderView）**：
- 新增 `TbNativeSelfRenderView : UIView`（镜像 TK 的 `AtNativeSelfRenderView`），从 `WindMillNativeAd` 物料（title/desc/iconUrl/callToAction/imageUrlList/rating）自建 UI
- showInContainer 时按 feedADMode 分支：
  - NativeExpress(5) → 模板渲染
  - 非 5 → 用 `TbNativeSelfRenderView` 渲染（读物料字段 + setClickableViews + 等 `nativeAdViewWillExpose:`）
- 效果：**与 TK 完全一致**（任意物料都能渲染）

#### 6.1.3 推荐选择

**选项 A2**——这是与 TK 真正"做成一样"的唯一方式。理由：
1. 用户明确要求"TB 做成和 TK 一样"
2. GDT 真机返回的就是 feedADMode=3（自渲染），A2 能让 GDT 真机直接走通
3. ToBid Native 自渲染 API 完整（5A.17A 已审计）：`WindMillNativeAdsManager` → `WindMillNativeAd`（title/desc/iconUrl/callToAction/imageUrlList）→ `WindMillNativeAdView.refreshData:` + `setClickableViews:` + 等 `nativeAdViewWillExpose:`
4. 无需新增依赖（GDTAdapter 已含 Native 支持）

### 6.2 方案 B（备选）：TB 保持严格分流，但放宽 feedADMode 校验

**设计**：保持"按 renderType 分流"，但 Express 模式下接受任意 feedADMode（不限于 NativeExpress），按物料自动选模板/自渲染路径。

问题：与 TK 的"renderType 完全不参与控制流"仍有差异，且 SelfRender 入口仍 14003，不是真正"和 TK 一样"。

### 6.3 方案 C（不推荐）：维持现状

不改 TB。承认 TB 与 TK 行为不一致，文档化差异。

---

## 7. 方案 A2 实施前置（Phase 5A.18D-B）

如确认方案 A2，5A.18D-B 需要实现：

1. **新增 `TbNativeSelfRenderView.{h,m}`**（镜像 `AtNativeSelfRenderView`）：
   - 从 `WindMillNativeAd` 读 title/desc/iconUrl/callToAction/imageUrlList/rating/advertiser
   - Manual frame 布局（或 AutoLayout，与 TK 风格一致）
   - 提供 clickableViews 给 Adapter 注册
2. **改 `TbNativeAdapter.m`**：
   - 移除 load 阶段 SelfRender 拦截（renderType 不再阻塞请求）
   - 移除 feedADMode 严格校验
   - showInContainer 按 `_nativeAd.feedADMode` 分支：
     - `== NativeExpress(5)` → 现有模板路径（refreshData + 等 renderSuccess）
     - `!= NativeExpress(5)` → 创建 `TbNativeSelfRenderView`，refreshData 绑定物料，setClickableViews，等 `nativeAdViewWillExpose:`
   - isReady 改为：`_nativeAd != nil && _nativeAd.ready && !_destroyed`（不依赖 renderType）
3. **Demo `NativeAdManager.swift`**：移除 `setRenderType(.express)`（renderType 不再重要；保留默认 SelfRender 或不调用均可，行为一致）
4. XCFramework 构建 + 符号验证（`TbNativeSelfRenderView` / 移除 `TB_NATIVE_SELF_RENDER_NOT_IMPLEMENTED`）
5. TB/TK Demo 构建回归
6. 真机验证：GDT（feedADMode=3）应能走自渲染路径并展示

### 7.1 风险

| 风险 | 等级 | 缓解 |
|---|---|---|
| `TbNativeSelfRenderView` 布局与 TK 不完全一致 | 低（Demo 容器层适配） | 参考 TK AtNativeSelfRenderView frame 计算 |
| 自渲染曝光/点击上报时机 | 中 | 严格按 ToBid 官方：refreshData 后等 `nativeAdViewWillExpose:`（不是 addSubview 即曝光） |
| 图片下载（iconUrl/imageUrlList） | 中 | SelfRenderView 内部用 SDWebImage/AsyncImage 或手动 NSURLSession（参考 Demo 已有 AsyncImage） |
| 视频 mediaView（自渲染模式） | 低 | 本阶段只支持图片自渲染，视频留后续 |

---

## 8. 公共 API 是否需要变化

**不需要**。所有改动在 `TbNativeAdapter` + 新增 `TbNativeSelfRenderView`（SDK 内部），Flame 公共 API（`FlameNativeAd` / `FlameNativeListener` / `FlameNativeRenderType` / `showInContainer:`）零修改。Demo 调用方式零修改（甚至可以移除 `setRenderType(.express)` 调用）。

---

## 9. 与 5A.18A/5A.18B 的口径修正

| 文档 | 原口径 | 修正为 |
|---|---|---|
| 5A.18A §3.2 "TK 是双模式（Template 或 SelfRender），运行时由 AnyThink 的 `nativeMaterial.isExpressAd` 选择" | 正确 | 保持 |
| 5A.18B "Native SelfRender 明确降级" | 在 5A.18B 范围内合理 | 5A.18D-A 后修正：**SelfRender 物料不应降级，应实现自渲染**（方案 A2） |
| 5A.18B feedADMode 严格校验（≠5 即 14004） | 在 5A.18B 范围内合理 | 5A.18D-A 后修正：**feedADMode 不应作为强约束**，应按物料自动分支（方案 A2） |
| `TB_NATIVE_SELF_RENDER_NOT_IMPLEMENTED` 日志 | 表述"SDK 桥接尚未接入" | 5A.18D-B 实现后移除 |

---

## 10. 用户原问题逐项回答

| 问 | 答 |
|---|---|
| 1. TK 是否真正按 FlameNativeRenderType 强制请求模板或自渲染？ | **否**——请求阶段完全不使用 renderType（同 placementId/extra/API） |
| 2. TK 是否根据实际返回物料 isExpressAd 自动选择渲染方式？ | **是**——`AtNativeAdapter.m:153` `isExpressAd = materialIsExpress`，物料决定一切 |
| 3. 请求模式和实际返回模式不一致时，TK 如何处理？ | **按物料渲染** + log warning，无错误无重 load（`AtNativeAdapter.m:194-198`） |
| 4. TK SelfRender 完整 View 结构？ | `AtNativeSelfRenderView : UIView`，manual frame 布局，从 nativeMaterial 读 8 个字段，Adapter 负责注册点击/曝光/destroy（详见 §4） |
| 5. TK Express 完整模板 View 行为？ | `rendererWithConfiguration:selfRenderView:nil`，AnyThink 完整渲染（详见 §3.6） |
| 6. TB 应严格按参数分流，还是按返回物料自动兼容？ | **按返回物料自动兼容**（方案 A），与 TK 一致 |
| 7. 如何在公共 API 零修改前提下让 TB 与 TK 行为一致？ | **方案 A2**：新增 `TbNativeSelfRenderView`，TbNativeAdapter 移除严格分流按 feedADMode 自动分支（详见 §6/§7） |

---

## 11. /compact

Phase 5A.18D-A 完成（只读调研，未改代码）：TK 端 `FlameNativeRenderType` 是**非绑定 hint**——请求阶段完全不使用（同 placementId/extra/API），show 阶段**始终以物料 `nativeMaterial.isExpressAd` 为准**自动分支（`AtNativeAdapter.m:153 isExpressAd = materialIsExpress`），caller 的 renderType 仅作日志标签；不一致时仅 log warning，按物料渲染（公共头 `FlameNativeAd.h:88` 背书："SDK 会自动降级到素材支持的渲染方式"）。**TK SelfRender**：`AtNativeSelfRenderView : UIView` manual frame 布局，读 8 个物料字段，Adapter 负责注册点击/曝光/destroy。**TB 当前严格分流**（SelfRender→14003；Express+feedADMode≠5→14004），与 TK 行为不一致——这是 5A.18C 真机验证始终走不到 showInContainer 的根因（GDT 返回 feedADMode=3 自渲染，TB 直接 14004）。**对齐方案 A2**：新增 `TbNativeSelfRenderView`（镜像 TK），TbNativeAdapter 移除严格分流，按 `_nativeAd.feedADMode` 自动分支（NativeExpress→模板；非 5→自渲染），公共 API 零修改，Demo 可移除 setRenderType。GDT 真机返回的 feedADMode=3 自渲染物料即可走通。未修改业务代码/公共 API/Demo/podspec，未 push/tag/release。等用户确认方案后进入 5A.18D-B。
