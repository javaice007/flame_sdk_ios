# Phase 5A.18D-B 验收报告：TB Native 物料驱动双渲染对齐（补齐版）

> 本报告由 Phase 5A.19 之后的只读审计产生，汇总 commit `43c964a` / `d14b8e3` / `92e418d` 三个 feature/fix commit 的实际实现，并对照 Phase 5A.18D-B spec（§3-§23）逐项核验。
> 本报告**不重新开发、不合并历史 commit、不改业务代码**，仅补齐 spec §26 要求的正式验收文档。

---

## 1. 基线

- **开始 HEAD**（5A.18D-B 实施前）：`c586895`（Phase 5A.18D-A 调研 docs commit）
- **本阶段三个实现 commit**：
  - `43c964a` feat: align ToBid native rendering with TK behavior (Phase 5A.18D-B)
  - `d14b8e3` fix: align TbNativeSelfRenderView with official ToBid self-render pattern（5A.18D-C 架构修复）
  - `92e418d` fix: ToBid native template (Express) deformation caused by full-screen height（模板变形修复）
- **后续 commit**：`7459485` feat: add selected ToBid ad network adapters (Phase 5A.19)
- **当前 HEAD**：`7459485`（未 push）
- **分支**：`release/ios-dual-line`
- **工作区**：
  - `flame_sdk_ios.xcodeproj/project.pbxproj`（环境 UUID 差异，严格排除在 commit 外）
  - `.zcode/`（本地工具，未跟踪）

---

## 2. TK 对齐

| 对齐项 | TK 行为 | TB 实际实现（5A.18D-B/C）| 一致性 |
|---|---|---|---|
| `renderType` 语义 | 非绑定 hint，仅日志标签 | 保存为偏好，不参与请求/展示路由 | ✅ 一致 |
| 实际模式依据 | `nativeMaterial.isExpressAd` | `_nativeAd.feedADMode == NativeExpress` | ✅ 一致（字段名不同，语义相同）|
| mismatch 行为 | 仅 warning，不拒绝 | `[TB_NATIVE_RENDER_MODE_FALLBACK]` warning，不拒绝 | ✅ 一致 |
| 是否完全一致 | — | — | ✅ 完全一致 |

**代码证据**：
- `TbNativeAdapter.m:192` `BOOL actualIsExpress = (_nativeAd.feedADMode == WindMillFeedADModeNativeExpress);`
- `TbNativeAdapter.m:195-205` mismatch 时输出 fallback warning，不调用 onAdError
- `TbNativeAdapter.m:144-149` `isReady` 移除 renderType 判断

---

## 3. Load

| Load 行为 | spec 要求 | 实际实现 | 验证 |
|---|---|---|---|
| 是否统一请求 | 任意 renderType 都发请求 | ✅ `loadWithUserId:...` 不拦截 SelfRender | 代码确认 |
| SelfRender 是否仍拦截 | 不再返回 14003 | ✅ 拦截逻辑已撤销（注释 line 82-83 说明）| 代码确认 |
| feedADMode 是否严格拒绝 | 不强校验 ==5 | ✅ switch 接受 8 个已知 mode（2/3/4/5/6/14/15/16），仅 unknown 报错 | 代码确认（line 366-388）|
| onAdLoaded 回调 | load 成功后回调一次 | ✅ generation + dispatch_async 主线程 + stale 守卫 | 代码确认 |

---

## 4. 自动分支

`showInContainer:` 按物料自动分支（代码 `TbNativeAdapter.m:192-228`）：

| preferred（hint）| actual（feedADMode）| 最终行为 | warning | 实测验证 |
|---|---|---|---|---|
| SelfRender | SelfRender | SelfRender | 无 | — |
| SelfRender | NativeExpress | Express | ✅ FALLBACK | — |
| Express | NativeExpress | Express | 无 | ✅ CSJ 模板真机（用户确认"不变形了"）|
| Express | SelfRender | SelfRender | ✅ FALLBACK | ✅ sigmob 自渲染真机（用户确认"广告可见，布局正常"）|

---

## 5. SelfRender View

- **文件**：
  - `flame_sdk_ios/adapter/tb/TbNativeSelfRenderView.h`（SDK 内部头，不进 public headers）
  - `flame_sdk_ios/adapter/tb/TbNativeSelfRenderView.m`
- **根 View**：`WindMillNativeAdView`（`TbNativeAdapter.m:215`）
- **子控件层级**：
  ```
  WindMillNativeAdView
  └── TbNativeSelfRenderView
      ├── mainMediaView（WindMill mainImageView 或 mediaView，reparent）
      ├── groupImageViews（WindMill imageViewList，reparent）
      ├── iconImageView（自建 + NSURLSession）
      ├── titleLabel（自建）
      ├── descLabel（自建）
      ├── ratingLabel（自建）
      ├── ctaButton（自建）
      ├── logoView（WindMill 提供，reparent）
      └── dislikeButton（WindMill 提供，reparent）
  ```
- **字段映射**：

  | TK Material | TK 控件 | ToBid 字段/API | TB 控件 | 缺口 |
  |---|---|---|---|---|
  | title | titleLabel | WindMillNativeAd.title | _titleLabel | 无 |
  | desc/body | textLabel | WindMillNativeAd.desc | _descLabel | 无 |
  | icon | iconImageView | WindMillNativeAd.iconUrl | _iconImageView（NSURLSession）| 无 |
  | mainImage | mainImageView | WindMillNativeAdView.mainImageView | reparent | 无 |
  | groupImage | (TK 无) | WindMillNativeAdView.imageViewList | reparent + 横排 | 无 |
  | video | mediaView | WindMillNativeAdView.mediaView | reparent | 未真机验证 |
  | cta | ctaLabel | WindMillNativeAd.callToAction | _ctaButton | 无 |
  | advertiser | advertiserLabel | (WindMillNativeAd 无) | 不显示 | WindMill 不提供 |
  | rating | ratingLabel | WindMillNativeAd.rating | _ratingLabel | 无 |
  | logo | logoImageView | WindMillNativeAdView.logoView | reparent | 无 |
  | dislike | dislikeButton | WindMillNativeAdView.dislikeButton | reparent | 无 |

- **图片**：icon 走 NSURLSession 最小实现；主图复用 WindMill mainImageView（不重复下载）
- **mediaView**：视频走 WindMill mediaView（不开发 AVPlayer）；**未真机验证**（spec §七 视频模式留待后续）
- **clickableViews**：自建 icon/title/desc/cta + WindMill mainMediaView/groupImageViews/dislikeButton（不过滤 nil image）

---

## 6. 回调

| 事件 | 实际回调 | spec 要求 | 验证 |
|---|---|---|---|
| loaded | `onAdLoaded`（load 成功，dispatch_async 主线程）| 一次 | ✅ 代码 + 真机日志 `[原生测试] page 0 加载成功` |
| show | `onAdShow`（`nativeAdViewWillExpose:` 回调内）| 首次曝光一次 | ✅ 代码（line 553-554）|
| click | `onAdClicked`（`nativeAdViewDidClick:` 回调内）| 按真实回调 | ✅ 代码（line 571-572）|
| close | `onAdClosed`（dislike 回调内）| 一次 | ✅ 代码（line 590 注释）|
| error | `onAdError:desc:`（manager fail / render fail / no valid ad / unknown feedADMode）| 全场景覆盖 | ✅ 代码 |

---

## 7. fallback

- **日志格式**：`[TB_NATIVE_RENDER_MODE_FALLBACK] preferredRenderMode=%@ | actualFeedADMode=%u | actualRenderMode=%@ | action=render_actual_material | message="请求渲染偏好与实际物料模式不一致，已按物料能力渲染"`
- **是否报错**：否（仅 warning，不调 onAdError）✅
- **生命周期幂等**：`_fallbackReported` 守卫，每个广告生命周期最多一次 ✅
- **14003（Native 路径）**：已撤销（注释 line 82-83 说明，代码无 SelfRender 拦截）✅
- **14004（fallback 场景）**：已移除（不用于 preferred=Express + actual=SelfRender）✅
- **14003/14004 残留**：14003 仅保留在 `TbBannerAdapter`（Banner SelfRender 隔离）；14004 字符串残留在 Interstitial/Splash，语义是"placementId empty"，与 fallback 无关 ✅

---

## 8. 生命周期

| 项 | 实际实现 | 验证 |
|---|---|---|
| generation | `_generation += 1`（destroy 时），异步块捕获并在执行前比对 | ✅ 代码（destroy + load 异步块）|
| stale 守卫 | delegate 回调内 `nativeAdView != _nativeAdView` / `manager != _manager` 比对 | ✅ 代码（各回调入口）|
| destroy | destroyed=YES / generation+1 / cleanupCurrentAd / unregisterDataObject / delegate=nil / removeFromSuperview / 状态清零 / listener=nil | ✅ 代码（line 305-326）|
| re-enter | 重新创建 manager/nativeAdView/selfRenderView，不复用旧对象 | ✅ 代码（showInContainer 入口清理 + load 入口清理）|

---

## 9. Express 真机

- **placement**：sigmob Native Express（实际 ToBid placementId `1619313335657755`，对应 Flame Demo TB.native）
- **feedADMode**：5（NativeExpress）
- **链路**：setRenderType(.express) → load → `[sigmob] NativeAdAdapter.init` → `nativeAdsManagerSuccess` → onAdLoaded → showInContainer → refreshData → `nativeExpressAdViewRenderSuccess` → addSubview → `nativeAdViewWillExpose` → onAdShow
- **变形修复**：commit `92e418d` 解决（`_manager.adSize.height = 0`，initialFrame Express 分支用 100，renderHeight 兜底用 width*0.75）
- **用户确认**：原话"我已经测过了 不变形了"
- **未单独验证**：destroy/re-enter、前后台切换、无重复曝光（spec §二十 A 要求，但本轮无新真机日志；代码路径与之前一致）

---

## 10. SelfRender 真机

- **广告源**：sigmob 自渲染（Flame Demo TB.native = `q55921206210`，ToBid 内部 placementId `5756789376418096`）
- **feedADMode**：3（LargeImage）
- **页面元素**（用户确认"广告可见，布局正常"）：
  - 主图（WindMill mainImageView，hasMainImage=1）
  - title / desc / cta / icon / logo / dislike
- **链路**（日志完整）：
  ```
  load: adSize={402, 0} (requestedSize={402, 280})
  [sigmob] NativeAdAdapter.init
  ad selected: feedADMode=3 ready=1 isVideoAd=0
  showInContainer: feedADMode=3 actualIsExpress=0
  selfRender reparentMediaViews: mainMediaView=0x... dislikeButton=0x... feedADMode=3
  selfRender setup: clickableViews=6 realHeight=347.6 hasMainImage=1 hasDislike=1
  ```
- **关键指标**：realHeight=347.6（高度回写成功，不再是 874）；clickableViews=6（不再过滤 nil image）
- **未单独验证**：dislike 关闭交互、destroy/re-enter、前后台切换（spec §二十 B 要求，本轮无新真机日志）

---

## 11. 回归

| 项 | 状态 | 证据 |
|---|---|---|
| Splash | ✅ 无回归 | 5A.19 真机日志：splash `[sigmob] onSplashAdDidLoad` → onAdShow → onAdClosed 完整链路 |
| Reward | ✅ 无回归 | 5A.19 真机日志：`rewardVideoAdDidLoad` → RewardVideo 加载成功 |
| Interstitial | ✅ 无回归 | 5A.19 真机日志：`intersititialAdDidLoad` → 展示 → 关闭 |
| Banner Express | ✅ 无回归 | TbBannerAdapter 未改；Banner GDT 后台配额限制（800110）非 SDK 问题 |
| Banner SelfRender | ✅ 隔离保留 | 14003 降级行为仍在 TbBannerAdapter（spec §四红线遵守）|
| Native Express | ✅ 真机验证 | 见 §9 |
| Native SelfRender fallback | ✅ 真机验证 | 见 §10 |
| TK Native | ✅ 无修改 | AtNativeAdapter / AtNativeSelfRenderView 文件未改（5A.19 TK 回归 BUILD SUCCEEDED）|
| TK/TB 隔离 | ✅ 通过 | TK Podfile.lock：ToBid 出现 0 次，AnyThink 62 次 |

---

## 12. 构建

- **Flame XCFramework**：✅ 双 Archive SUCCEEDED，840 KB，符号校验通过，无三方污染
- **iphoneos**：✅ TB Demo BUILD SUCCEEDED
- **simulator**：⚠️ WindMillMTGAdapter 缺 simulator slice（Mintegral 限制，非本阶段引入；ToBid 5.5.6 podspec 自带 EXCLUDED_ARCHS[sdk=iphonesimulator*]=arm64，未额外添加）
- **TB Demo**：✅ BUILD SUCCEEDED
- **TK Demo**：✅ BUILD SUCCEEDED（回归）
- **duplicate symbols**：✅ 无
- **undefined symbols**：✅ 无
- **AnyThink weak-link**：✅ LC_LOAD_WEAK_DYLIB 保留
- **TbNativeSelfRenderView 双 slice 符号**：✅
- **Express 现有符号**：✅ 无回归
- **fallback 日志字符串**：✅ `TB_NATIVE_RENDER_MODE_FALLBACK` 在两 slice 各 1
- **无测试 ID 进入二进制**：✅（podspec 排除测试 placementId）

---

## 13. 修改文件（本阶段 3 个 commit 实际改动）

**`43c964a`（5A.18D-B）**：
- `flame_sdk_ios/adapter/tb/TbNativeAdapter.m`（物料驱动 + fallback warning + 移除 14003/14004）
- `flame_sdk_ios/adapter/tb/TbNativeSelfRenderView.h`（新增）
- `flame_sdk_ios/adapter/tb/TbNativeSelfRenderView.m`（新增）
- `doc/flame_mediation/09_change_log.md`
- `doc/flame_mediation/phase-5a.18d-b-tb-native-dual-render-implementation.md`（阶段报告）
- `README.md`

**`d14b8e3`（5A.18D-C 架构修复）**：
- `flame_sdk_ios/adapter/tb/TbNativeSelfRenderView.h`（重写：加 nativeAdView + onLayoutChanged）
- `flame_sdk_ios/adapter/tb/TbNativeSelfRenderView.m`（重写：复用 WindMill view + 高度回写）
- `flame_sdk_ios/adapter/tb/TbNativeAdapter.m`（setupSelfRenderInContainer 改造）
- `doc/flame_mediation/09_change_log.md`
- `doc/flame_mediation/phase-5a.18d-c-tb-native-layout-fix.md`

**`92e418d`（模板变形修复）**：
- `flame_sdk_ios/adapter/tb/TbNativeAdapter.m`（adSize height=0 + initialFrame 分支 + renderHeight 兜底）

**红线遵守**：
- 未改 Flame 公共 API（FlameNativeAd / FlameNativeRenderType / FlameNativeListener / FlameNativeAdapterProtocol）
- 未改 FlameTKProvider / AtNativeAdapter / AtNativeSelfRenderView
- 未改 TK podspec / TB podspec 广告源依赖
- 未改 Splash / Reward / Interstitial / Banner Adapter
- 未改 Demo 业务调用
- 未改 SDK 版本号

---

## 14. Git

- **feature commit（5A.18D-B 实现）**：`43c964a`
- **fix commit（5A.18D-C 架构修复）**：`d14b8e3`
- **fix commit（模板变形修复）**：`92e418d`
- **后续 commit（5A.19 广告源接入）**：`7459485`
- **push**：否
- **tag**：否
- **release**：否
- **历史重写**：无（未 squash / 未 reset / 未 rebase）

---

## 15. 结论

- **TB Native 是否与 TK 一致**：✅ 完全一致（renderType hint 语义 + 物料驱动 + mismatch fallback）
- **公共 API 是否变化**：✅ 未变化
- **Demo 是否变化**：✅ 业务代码未变（仅 setRenderType 调用保留，注释更新）
- **Express 是否保持成功**：✅ CSJ 模板真机不变形
- **SelfRender 是否真机成功**：✅ sigmob LargeImage 自渲染真机可见 + 布局正常
- **是否可进入最终发布阶段**：⚠️ 业务实现可发布；发布前需完成 podspec 注释精简（Phase 5A.19 收口时已记为独立专项任务）

---

## 16. 未验证项 / 已知缺口

### 真机未验证（spec §二十要求但本轮无新日志）
- Express + SelfRender 的 **destroy/re-enter 闭环**
- SelfRender 的 **dislike 关闭交互**
- **前后台切换** 无重复曝光
- **无旧图回调**（异步图片竞争）

### 代码缺口（spec §十三要求，当前实现不完整）
- **`loadImageWithURL:` 缺 generation/destroyed 校验**：icon 图片下载完成回调内只做 error/data 校验，未比对 `_generation` 或 self 是否已 destroy。虽然 `cleanup` 会取消进行中的 task，但极端竞态下仍可能在 destroy 后触发 `setNeedsLayout`。**不影响主流程，但不符合 spec §十三"generation 校验 + 当前 View 身份校验 + destroy 后不更新"严格要求**。

### 功能未真机验证
- **视频 mediaView**（spec §七 视频模式）：代码已实现 reparent mediaView 路径，但无真机 feedADMode=14/15/16 物料验证
- **SmallImage / PortraitImage / GroupImage 布局**：代码已分支（`mediaHeightForWidth:`），仅 LargeImage 真机验证
- **14004 字符串残留在 Interstitial/Splash**：语义是 "placementId empty"（非 fallback 场景），与 spec §十八"不用于 fallback"要求不冲突，但建议后续统一错误码命名

---

## 17. /compact

Phase 5A.18D-B 验收补齐：3 个 commit（43c964a/d14b8e3/92e418d）已完成 TB Native 物料驱动双渲染对齐，Express + SelfRender 双真机链路通过。fallback warning、14003/14004 移除、回调映射、destroy 生命周期均符合 spec。已知缺口：NSURLSession icon 回调缺 generation 校验（不影响主流程）；视频/SmallImage/PortraitImage/GroupImage 布局代码已实现但未真机验证。
