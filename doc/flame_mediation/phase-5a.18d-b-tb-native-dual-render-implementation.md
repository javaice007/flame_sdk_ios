# Phase 5A.18D-B：TB Native 物料驱动双渲染对齐实现

> **本阶段性质**：将 TB Native 从"按请求参数强制分流"改为与 TK 相同的"按实际物料自动渲染"——新增 `TbNativeSelfRenderView`，`TbNativeAdapter` 按 `feedADMode` 自动分支。
>
> **最终状态**：本地 feature commit（未 push、未 tag、未 release）。GDT 真机验证待用户 Run（feedADMode=3 应走通自渲染路径）。

---

## 1. 基线与决策

| 项 | 值 |
|---|---|
| 开始 HEAD | `811f430`（Phase 5A.18C.1 Mintegral Adapter） |
| 5A.18D-A docs commit | `c586895 docs: research TK native dual-render and TB alignment` |
| 5A.18D-B feature commit | 本阶段创建：`feat: align ToBid native rendering with TK behavior` |

### 1.1 范围

| 能力 | 5A.18B（旧） | 5A.18D-B（新） |
|---|---|---|
| Native Template/Express | ✅ 模板渲染（feedADMode=5） | ✅ 保持 |
| Native SelfRender | ❌ 14003 降级 | ✅ **实现**（feedADMode≠5 自动走 TbNativeSelfRenderView） |
| renderType 语义 | 强约束（SelfRender 直接拦截） | **hint**（请求不分流，show 按物料自动分支，与 TK 一致） |

---

## 2. 18D-A 调研结论（驱动本阶段）

详见 `phase-5a.18d-a-tk-native-dual-render-research.md`：

1. TK 端 `FlameNativeRenderType` 是**非绑定 hint**——请求阶段完全不使用，show 阶段以物料 `isExpressAd` 为准
2. 不一致时仅 log warning（不返回错误、不重 load、按物料渲染）
3. TB 5A.18B 严格分流（SelfRender→14003；Express+feedADMode≠5→14004）与 TK 不一致，是 5A.18C 真机验证失败的根因
4. 公共头 `FlameNativeAd.h:88` 已背书"SDK 会自动降级到素材支持的渲染方式"

---

## 3. 核心改动

### 3.1 新增 `flame_sdk_ios/adapter/tb/TbNativeSelfRenderView.{h,m}`

- 与 TK `AtNativeSelfRenderView` 角色镜像，从 `WindMillNativeAd` 物料自建 UI
- Manual Frame 布局（参考 TK `AtNativeSelfRenderView.m:107-155`）
- 支持的 feedADMode：SmallImage(2) / LargeImage(3) / GroupImage(4) / PortraitImage(6)
- 异步下载图片（NSURLSession，不引入第三方库，参考 TK `loadImageWithURL:imageView:`）
- 提供 `clickableViews` 供 Adapter 注册（只含实际可见控件）
- `cleanup` 取消图片请求 + 移除子控件（destroy 时调用）
- 不自行上报曝光和点击（由 Adapter 经 `WindMillNativeAdView` 触发）

### 3.2 改造 `flame_sdk_ios/adapter/tb/TbNativeAdapter.m`

| 改动点 | 5A.18B（旧） | 5A.18D-B（新） |
|---|---|---|
| load 阶段 SelfRender 拦截 | `renderType==SelfRender` → 14003 + 不发请求 | **移除**——所有 renderType 统一请求 |
| load success feedADMode 校验 | ≠NativeExpress → 14004 | **移除严格校验**——switch 接受所有已知 feedADMode，仅未知报 14002 |
| isReady | 依赖 `_renderType==Express` | **移除 renderType 判断**（只看 `_nativeAd.ready && _loaded && !_destroyed`） |
| showInContainer SelfRender | 安全 no-op | **按 feedADMode 自动分支**（NativeExpress→模板；非 5→TbNativeSelfRenderView） |
| 模式不一致 | 无 | **新增 `[TB_NATIVE_RENDER_MODE_FALLBACK]` warning**（仅日志，不影响渲染） |
| `_selfRenderUnsupportedReported` ivar | 用于 14003 幂等 | **改为 `_fallbackReported`**（warning 幂等） |
| destroy 清理 | 无 `_selfRenderView` | **新增 `_selfRenderView.cleanup`** |

### 3.3 不改动（红线遵守）

- `FlameNativeAd` / `FlameNativeListener` / `FlameNativeRenderType` / `FlameNativeAdapterProtocol`（公共 API 零修改）
- `AtNativeAdapter` / `AtNativeSelfRenderView` / `FlameTKProvider`（TK 不变）
- Demo `NativeAdManager` 业务调用（保留 `setRenderType(.express)`，仍作偏好提示）
- `TbBannerAdapter`（Banner SelfRender 14003 降级不变）
- podspec（不增减依赖）

---

## 4. renderType hint 行为（与 TK 一致）

| Flame renderType hint | ToBid 实际物料 | TB 最终行为 |
|---|---|---|
| SelfRender | SelfRender | ✅ SelfRender（TbNativeSelfRenderView） |
| SelfRender | NativeExpress | ✅ Express，+ `[TB_NATIVE_RENDER_MODE_FALLBACK]` warning |
| Express | NativeExpress | ✅ Express |
| Express | SelfRender | ✅ SelfRender，+ warning |

---

## 5. feedADMode 分类（核对自本地 Header WindMillSDK.h:1807-1816）

| feedADMode | 值 | 分类 | 处理 |
|---|---|---|---|
| SmallImage | 2 | SelfRender 图片 | TbNativeSelfRenderView（小图高度 120） |
| LargeImage | 3 | SelfRender 图片 | TbNativeSelfRenderView（16:9 主图） |
| GroupImage | 4 | SelfRender 图片 | TbNativeSelfRenderView（本阶段只展示首图） |
| NativeExpress | 5 | Express 模板 | WindMillNativeAdView.refreshData + 等 renderSuccess |
| PortraitImage | 6 | SelfRender 图片 | TbNativeSelfRenderView（3:4 主图） |
| Video / VideoPortrait / VideoLandSpace | 14/15/16 | SelfRender 视频 | TbNativeSelfRenderView（本阶段不自研播放器，视频真实填充留后续） |
| 其他（未知） | — | — | 返回 `ERROR_CODE_INVALID_PARAM`(14002) "Unsupported native feedADMode" |

---

## 6. 物料字段映射表

编码前已重新核对本地 `WindMillSDK.h:2011-2057`：

| Flame/TK 概念 | AtNativeSelfRenderView 控件 | WindMillNativeAd 字段（Header） | TbNativeSelfRenderView 控件 |
|---|---|---|---|
| title | titleLabel | `title` (NSString?) | _titleLabel |
| desc | textLabel | `desc` (NSString?) | _descLabel |
| icon | iconImageView | `iconUrl` (NSString?) | _iconImageView（异步下载） |
| main image | mainImageView | `imageUrlList[0]` | _mainImageView（异步下载） |
| group image | (TK 无) | `imageUrlList`（1=大图, 3=组图） | _mainImageView（本阶段首图） |
| CTA | ctaLabel | `callToAction` (NSString?) | _ctaButton |
| advertiser | advertiserLabel | **WindMillNativeAd 无此字段** | 不显示 |
| media/video | mediaView（注入） | `WindMillNativeAdView.mediaView`（readonly，ToBid 创建） | 由 Adapter 判断是否挂载（本阶段 SelfRender 路径不挂 mediaView） |
| ad logo | logoImageView | `WindMillNativeAdView.logoView`（readonly） | 由 Adapter 加到 nativeAdView（不在 SelfRenderView 内） |
| dislike | dislikeButton | `WindMillNativeAdView.dislikeButton`（readonly） | 由 Adapter 加到 clickableViews（不在 SelfRenderView 内） |
| rating | ratingLabel | `rating` (CGFloat) | _ratingLabel |

**空字段处理**：title/desc/icon 空则隐藏对应控件；无主图且无 mediaView → SelfRenderView 标记 main image hidden，Adapter 检查是否需要 mediaView fallback（本阶段不实现 mediaView fallback，记录为缺口）。

---

## 7. showInContainer 自动分支

```objc
- (void)showInContainer:(UIView *)container {
    // 前置校验（不依赖 renderType）
    // 清理旧 view
    // 创建 WindMillNativeAdView

    BOOL actualIsExpress = (_nativeAd.feedADMode == WindMillFeedADModeNativeExpress);

    // 模式不一致 warning（仅日志，幂等）
    if (preferExpress != actualIsExpress && !_fallbackReported) {
        _fallbackReported = YES;
        [FlameLogger w:@"[TB_NATIVE_RENDER_MODE_FALLBACK] ..."];
    }

    if (actualIsExpress) {
        // 模板渲染：refreshData + 等 nativeExpressAdViewRenderSuccess
        _rendering = YES;
        [_nativeAdView refreshData:_nativeAd];
    } else {
        // 自渲染：TbNativeSelfRenderView
        [self setupSelfRenderInContainer:container viewWidth:viewWidth];
    }
}
```

`setupSelfRenderInContainer:` 流程：
1. 创建 `TbNativeSelfRenderView`（从 `_nativeAd` 读物料）
2. addSubview 到 `_nativeAdView`（SelfRenderView 的 layoutSubviews 会算真实高度）
3. `[_nativeAdView refreshData:_nativeAd]`（绑定物料，必须）
4. `[_nativeAdView setClickableViews:clickables]`（SelfRenderView 提供 + dislikeButton）
5. `[_container addSubview:_nativeAdView]`
6. layoutIfNeeded（触发布局）
7. **不触发 onAdShow**——等 `nativeAdViewWillExpose:` 真实回调

---

## 8. clickableViews

`TbNativeSelfRenderView.clickableViews` 返回实际可见控件：
- mainImageView（有 image 才加）
- iconImageView（有 image 才加）
- titleLabel（有 text 才加）
- descLabel（有 text 才加）
- ctaButton（始终）

Adapter 追加 `_nativeAdView.dislikeButton`（若存在），然后调 `setClickableViews:`。

**禁止**：不注册隐藏控件 / nil / 重复注册；不用手势替代；destroy 时解绑。

---

## 9. 曝光/点击/关闭映射（Express + SelfRender 共用）

| ToBid 回调 | Flame 映射 | 说明 |
|---|---|---|
| `nativeAdViewWillExpose:` | `onAdShow` | `_shown` 防重复首次曝光 |
| `nativeAdViewDidClick:` | `onAdClicked` | 按真实次数 |
| `dislikeWithReason:` | `onAdClosed` | dislike → close |
| `nativeExpressAdViewRenderSuccess/Fail:` | （仅 Express） | SelfRender 路径不触发 |

**addSubview ≠ 曝光**；**图片下载完成 ≠ 曝光**。曝光只来自 ToBid 真实回调。

---

## 10. ready/loading/destroy 语义

### isLoading
- manager 请求期间 YES
- manager 回调后 NO

### isReady（移除 renderType 判断）
```objc
- (BOOL)isReady {
    if (_destroyed) return NO;
    if (!_loaded || _nativeAd == nil) return NO;
    return _nativeAd.ready;
}
```

### destroy
1. `_destroyed = YES`
2. `_generation += 1`（失效迟到异步块）
3. `cleanupCurrentAd`（含 `_selfRenderView.cleanup`）
4. 状态全置 NO（含 `_fallbackReported`）
5. 不触发 `onAdClosed`

---

## 11. 旧错误码处理

### 14003（ERROR_CODE_UNSUPPORTED_PLATFORM）
- **Native 链路不再返回**（已移除 SelfRender 拦截）
- Banner SelfRender 的 14003 降级**不变**（TbBannerAdapter 未改）
- 公共错误码 + Demo `NonRetryableErrorCodes` 兼容项保留

### 14004（ERROR_CODE_INVALID_AD_PLACEMENT）
- **不再用于"请求 Express 但返回 SelfRender"的正常 fallback**
- 仅在"广告位映射无效"（load 阶段 placementId 校验）时使用

### 14002（ERROR_CODE_INVALID_PARAM）
- 用于"未知 feedADMode"（防御性，不强行渲染）

---

## 12. 构建验证

### 12.1 XCFramework

```
✅ 双 Archive SUCCEEDED
✅ TbNativeSelfRenderView 符号两 slice 各 2
✅ TbNativeAdapter 符号两 slice 各 2（无回归）
✅ TB_NATIVE_SELF_RENDER_NOT_IMPLEMENTED UTF-16 = 0（已从 Native 移除）
✅ TB_NATIVE_RENDER_MODE_FALLBACK UTF-16 两 slice 各 1（新增 warning 日志）
✅ TB_NATIVE_DIAG ASCII 两 slice 各 35（含自渲染路径日志）
✅ TB_SELF_RENDER_UNSUPPORTED UTF-16 = 1（Banner 降级日志，未改）
✅ TB_BANNER_DIAG / TbBannerAdapter 符号无回归
✅ AnyThink LC_LOAD_WEAK_DYLIB 无回归
```

### 12.2 TB Demo

```
✅ clean pod install（7 pods，含 MintegralAdSDK）
✅ iphoneos BUILD SUCCEEDED
✅ AnyThink ABSENT
✅ 无 undefined/duplicate symbols
```

### 12.3 TK Demo 回归

```
✅ clean pod install（28 pods）
✅ iphoneos BUILD SUCCEEDED
✅ AtNativeAdapter 未修改
✅ TbNativeSelfRenderView 不进 TK（TK 编译路径无此文件）
✅ AnyThink 正常
```

### 12.4 Simulator（已知限制）

- Flame xcframework simulator slice = x86_64-only（GDT SDK + WindMillMTGAdapter 限制）
- 本轮真机验证为主，**不使用 EXCLUDED_ARCHS 掩盖**

---

## 13. Express 回归

- 代码完全保留（`_rendering`/`_rendered`/`nativeExpressAdViewRenderSuccess/Fail:`）
- no-fill 透传（800110 原样保留，不伪装）
- feedADMode=5 分支代码保留
- **不写"Express 真机成功展示"**（CSJ/Mintegral 测试位 no-fill）

---

## 14. Mintegral Adapter 处置建议

5A.18C.1 为 Native Express 跨源验证临时接入 MintegralAdapter（`811f430`）。本轮 5A.18D-B 改用 GDT 自渲染路径（feedADMode=3）验证，不再依赖 Mintegral。

| 方案 | 适用 |
|---|---|
| M1：保留 | 首版需要 Mintegral 广告源 |
| M2：移除 | 仅用于本轮 Native Express 测试 |

**不自动决定**，等用户选择。当前保留在 podspec 中（`811f430` commit 不动）。

---

## 15. 未验证项（留真机）

- GDT（feedADMode=3 LargeImage）真机自渲染展示：主图/标题/描述/CTA 实际显示
- clickableViews 注册后真实点击行为
- `nativeAdViewWillExpose:` → `onAdShow` 回调
- dislike → `onAdClosed`
- destroy → re-enter 完整闭环
- 图片异步下载在真机网络环境下的表现
- Express 模板真机展示（仍 no-fill）

---

## 16. 修改文件清单

### 16.1 SDK（本阶段 feature commit）

| 文件 | 改动 |
|---|---|
| `flame_sdk_ios/adapter/tb/TbNativeSelfRenderView.h` | 新增（SelfRender View 头文件） |
| `flame_sdk_ios/adapter/tb/TbNativeSelfRenderView.m` | 新增（manual frame + 图片下载 + cleanup） |
| `flame_sdk_ios/adapter/tb/TbNativeAdapter.m` | 改造（移除 load 拦截 + feedADMode 严格校验；showInContainer 自动分支；isReady 移除 renderType；新增 fallback warning；destroy 清理 SelfRenderView） |

### 16.2 未改动（红线）

- Flame 公共 API（FlameNativeAd / FlameNativeListener / FlameNativeRenderType / FlameNativeAdapterProtocol）
- AtNativeAdapter / AtNativeSelfRenderView / FlameTKProvider
- Demo NativeAdManager 业务调用
- TbBannerAdapter（Banner SelfRender 14003 不变）
- podspec

---

## 17. Phase 5A.18D-C 前置（真机验证）

1. 用户后台将 `pMap.native` 映射回 **GDT Native 聚合位**（之前用的 `3869961934258901`，返回 feedADMode=3 LargeImage）
2. 真机 Run（装上 5A.18D-B 新构建）
3. 进入「原生广告」测试页，Demo 仍传 `setRenderType(.express)`（验证 fallback warning）
4. 期望日志：
```
[TB_NATIVE_DIAG] setRenderType: 2
[TB_NATIVE_DIAG] load: placementId=3869961934258901 ...
（GDT NativeAdAdapter init）
[TB_NATIVE_DIAG] managerSuccessToLoad
[TB_NATIVE_DIAG] ad selected: feedADMode=3 ready=1
→ onAdLoaded
[TB_NATIVE_DIAG] showInContainer: ... actualIsExpress=0
[TB_NATIVE_RENDER_MODE_FALLBACK] preferredRenderMode=express | actualFeedADMode=3 | actualRenderMode=self_render | action=render_actual_material
[TB_NATIVE_DIAG] selfRender setup: selfRenderView=... clickableViews=N
→ onAdShow（来自 nativeAdViewWillExpose）
```

页面实际看到：主图 + 标题 + 描述 + CTA + 广告标识，可点击。

---

## 18. 结论

| 问 | 答 |
|---|---|
| TB Native 是否与 TK 行为一致 | ✅ **是**（renderType=hint，物料驱动自动分支，不一致仅 warning） |
| 公共 API 是否变化 | ❌ 零修改 |
| Demo 业务调用是否变化 | ❌ 零修改（保留 setRenderType 调用） |
| Native SelfRender 是否真机成功 | ⏳ 待 5A.18D-C Run（GDT feedADMode=3 应走通） |
| Native Express 状态 | 🚧 代码保留，真机展示待填充 |
| Banner SelfRender 14003 是否不变 | ✅ 是（TbBannerAdapter 未改） |

---

## 19. /compact

Phase 5A.18D-B 完成：TB Native 从"按 renderType 强制分流"改为与 TK 相同的"物料驱动自动渲染"。新增 `TbNativeSelfRenderView.{h,m}`（镜像 TK AtNativeSelfRenderView，从 WindMillNativeAd 读 title/desc/iconUrl/imageUrlList/callToAction/rating，manual frame 布局，NSURLSession 异步下载图片，提供 clickableViews + cleanup）。改造 TbNativeAdapter：(1) 移除 load 阶段 SelfRender 拦截 + 14003（所有 renderType 统一请求 WindMillNativeAdsManager）；(2) 移除 Express 下 feedADMode 严格校验（switch 接受所有已知 feedADMode，仅未知报 14002）；(3) isReady 移除 renderType 判断（只看 nativeAd.ready）；(4) showInContainer 按 `_nativeAd.feedADMode` 自动分支（NativeExpress→模板 refreshData+renderSuccess；非 5→TbNativeSelfRenderView）；(5) 新增 `[TB_NATIVE_RENDER_MODE_FALLBACK]` warning 日志（偏好与实际不一致时仅记录，不影响渲染，与 TK 同构）；(6) destroy 清理 `_selfRenderView.cleanup`。FeedADMode 分类：SmallImage/LargeImage/GroupImage/PortraitImage→SelfRender 图片；Video 系列→本阶段不自研播放器（mediaView 留后续）；未知→14002。Flame 公共 API 零修改，Demo 零修改（保留 setRenderType(.express) 偏好），AtNativeAdapter/TbBannerAdapter 不变。Banner SelfRender 14003 降级保留（隔离）。XCFramework 双 slice 构建成功：TbNativeSelfRenderView 符号 + TB_NATIVE_RENDER_MODE_FALLBACK（UTF-16）；TB_NATIVE_SELF_RENDER_NOT_IMPLEMENTED 已从 Native 移除（=0）；Banner TB_SELF_RENDER_UNSUPPORTED 保留（=1）；AnyThink LC_LOAD_WEAK_DYLIB 无回归。TB Demo 7 pods + TK 28 pods BUILD SUCCEEDED。未 push/tag/release。等用户后台 pMap.native 切回 GDT（feedADMode=3）真机验证自渲染路径。
