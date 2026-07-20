# Flame iOS SDK 变更日志

> 本文件记录 Flame iOS SDK 的关键架构变更与发布里程碑。
> 详细阶段报告见同目录 `phase-*.md`。

---

## Phase 5A.16（进行中）— TB 第三方广告源接入

### Phase 5A.18A：TK Native Template 与 ToBid Native Express 映射调研（本次 docs commit）

**变更类型**：仅文档（SDK 业务代码零改动，Demo 代码零改动）

**核心结论（方案 A — 完全无损映射，仅适用于 Native Template / Native Express）**：

> **范围限定**：方案 A 仅适用于 Native Template / Native Express。**Native SelfRender**：ToBid 底层支持（WindMillNativeAdsManager 自渲染路径完整），但当前 Flame SDK 的 ToBid Native SelfRender 桥接尚未接入，5A.18B 明确降级为"未实现"（非"平台不支持"）。

1. **Flame 已有完整 Native 公共 API**：`<FlameNativeAd>` + `<FlameNativeListener>` + `FlameNativeRenderType`（SelfRender=1 / Express=2）+ `createNativeAdWithViewController:placementId:listener:`（`FlameSdk.h:123`）。关键：Native 用 `showInContainer:(UIView *)container`——Demo 传空容器，**SDK 内部把渲染好的 View 加进去**（与 Banner 的 `retrieveAdView` 不同）。`flame_sdk_ios/ads/nativate/FlameNativeAd.h:47-103`。
2. **TK Native Template 本质**：AnyThink 统一 `ATNativeAD*` API（`ATAdManager loadADWithPlacementID` + `getNativeAdOfferWithPlacementID`），运行时按 `nativeMaterial.isExpressAd` 分支（`AtNativeAdapter.m:153`）——Template 模式 View **由 AnyThink 完整渲染**（`rendererWithConfiguration:selfRenderView:nil`），SelfRender 模式用 SDK 内部 `AtNativeSelfRenderView`。双模式数据驱动，非类驱动。
3. **Demo 零 AnyThink import、零自建 UI**：`NativeAdManager.swift` / `NativeAdTestView.swift` / `NativeAdCell.swift` 只调 `ad.show(inContainer: container)` 传空 UIView 容器，SDK 完成 addSubview。无 UILabel/UIImageView 自建。
4. **ToBid 5.5.6 Native Express 完整支持**：`WindMillNativeAdsManager → WindMillNativeAd(feedADMode=NativeExpress=5) → WindMillNativeAdView.refreshData:` 触发异步模板渲染，等 `nativeExpressAdViewRenderSuccess:` 后 `frame.size.height` 动态更新（`WindMillSDK.h:2143` 注释）。**Template 模式物料属性全 nil**（`:2033`），ToBid 完整渲染 View，开发者只需 addSubview + resize 容器。单一 `WindMillNativeAdView` 类按 feedADMode 分支（无单独 NativeExpressAdView 类）。
5. **GDTAdapter 5.5.6 已含模板原生支持**：`WindMillGDTAdapter.NativeExpressAdsManager`（nm 符号 `loadAd(placementId:adSize:parameter:)`）+ `FeedAdLoaderListener`（符合 `GDTNativeExpressAdDelegete`）+ `NativeAdData.feedAd(UIView)` init + `GDTNativeExpressAdView : UIView`（GDTMobSDK Header）。**单一 `ToBid-iOS-RC/GDTAdapter` subspec 同时覆盖 Banner + Native SelfRender + Native Express**，无需新增 subspec。
6. **FlameTBProvider Native 工厂当前 `return nil`**（`FlameTBProvider.m:120-124`）—— 这是 5A.18B 的**唯一缺口**，改为返回新增 `TbNativeAdapter` 即可。

**方案 A 判断（仅 Native Template/Express）**：Flame 公共 API 零修改、Demo 零修改、Provider 协议零修改、podspec 零修改。只需：
- 新增 `TbNativeAdapter.{h,m}`（Template 模式完整 + SelfRender 明确降级为"未实现"）
- 改 `FlameTBProvider.m` Native 工厂 `return nil` → 返回 `TbNativeAdapter` 实例

**TK/TB 语义映射（仅 Template/Express）**：Flame Native 公共语义（create/load/show/destroy/click/exposure/video）可无损映射到 ToBid Native Express。详见报告 §10 映射表。

**后台要求**：TB 需在 ToBid 新建 **Native 聚合位**（不能复用 Banner 位），下挂 GDT/CSJ 模板原生广告源；Flame pMap **复用现有 `native` 字段**（不需要新增）；Demo 配 `TB.native = "q..."`。

**红线遵守**：未新增 TbNativeAdapter / 未修改 FlameTBProvider / 未修改公共 API / 未修改 Demo / 未修改 podspec / 未增加广告源 / 未升级 ToBid/GDT / 未配置测试 placementId / 未修改后台 / 未 push / 未 tag / 未 release。

详见 `doc/flame_mediation/phase-5a.18a-native-template-research.md`。

---

### Phase 5A.17B：TB SelfRender Banner 兼容降级（本次 feature commit）

**变更类型**：SDK 内部 Adapter 行为升级（`TbBannerAdapter` SelfRender 分支）+ Demo 错误处理增强。**Flame 公共 API 零改动。**

**决策**：撤销 5A.17A 原方案 B（用 ToBid Native 桥接模拟 SelfRender，会改变广告位类型/后台/链路/生命周期/客户语义），采用**方案 E**——公共 API 兼容保留，TB SelfRender 明确降级为 unsupported capability。

**核心改动**：

1. **`flame_sdk_ios/adapter/tb/TbBannerAdapter.m`**（SelfRender 分支升级）：
   - 新增 `_destroyed` / `_selfRenderUnsupportedReported` ivar
   - `load` SelfRender 分支：不创建任何 ToBid 对象（无 `WindMillBannerView` / 无 `WindMillNativeAdsManager`），不发起请求；异步派发到主线程回调一次 `onAdError:ERROR_CODE_UNSUPPORTED_PLATFORM desc:@"当前聚合平台暂不支持开发者自渲染横幅广告"`；用 `__weak self` + `_destroyed` 守卫阻断 destroy 后迟到回调
   - 统一诊断日志 `[TB_SELF_RENDER_UNSUPPORTED]`（platform/mediation/sdkVersion/adFormat/renderMode/capability/action/fallback/expressBannerAffected/message），每次生命周期只打印一次（`_selfRenderUnsupportedReported`）
   - `retrieveAdView` SelfRender 返回 nil；`retrieveMaterials` 返回空数组；`bind/unbind` 安全 no-op；`destroy` 设置 `_destroyed = YES`
2. **`flame_sdk_ios/adapter/tb/TbBannerAdapter.h`**：头注释从"5A.16C 占位"更新为"5A.17B 方案 E 降级说明"
3. **Demo `Sources/Ad/SelfRenderBannerManager.swift`**（独立 commit）：
   - `onError` 加 `NonRetryableErrorCodes.isNonRetryable(code)` 短路（14003/14004/14002），不进入 5 次重试循环
   - 新增嵌套 `NonRetryableErrorCodes` 枚举（基于 Flame 公开错误码，**不判 pt=tk/tb、不 import 三方 SDK**）

**复用错误码**：`ERROR_CODE_UNSUPPORTED_PLATFORM`（14003，"不支持的聚合平台"），不新增公共枚举。

**隔离保证**：普通 Express Banner 分支（L93-180）代码未改，SelfRender 降级状态不污染 bannerView/placementId/loading/ready/listener/destroy/auto-refresh。

**符号验证**（Python UTF-16 检查，因字符串含中文字符嵌入 `__TEXT/__ustring` 段）：
- `TB_SELF_RENDER_UNSUPPORTED` UTF-16：两 slice 各 1 ✅
- `当前聚合平台` UTF-16：两 slice 各 2（日志 + 错误描述）✅
- `TbNativeSelfRenderController` 符号：0（未创建）✅
- `WindMillNativeAdsManager` 直接使用：0（未调用）✅
- `TbBannerAdapter` / `TB_BANNER_DIAG` / `TB_REWARD_DIAG` / `TB_SPLASH_DIAG` / `TK_PLATFORM_REQUIRES_ANYTHINK` / AnyThink LC_LOAD_WEAK_DYLIB：全部无回归 ✅

**构建**：XCFramework 双 Archive SUCCEEDED；TB Demo 6 pods BUILD SUCCEEDED；TK Demo 临时切 28 pods BUILD SUCCEEDED（AtBannerAdapter 不变，已恢复 Demo 到 TB）。

**能力矩阵更新**：
| 能力 | TK | TB |
|---|---|---|
| 普通 Express Banner | 支持 | 支持（GDT 真机填充已验证） |
| 客户端 SelfRender Banner | 支持（AnyThink Banner Native Mix） | 暂不支持，兼容降级（14003 + 日志 + 不重试） |

**红线遵守**：未修改 AtBannerAdapter / Flame 公共协议 / FlameErrorCode 公共枚举 / podspec / FlameTBProvider；未增加广告源；未升级版本；未 push/tag/release。Demo 改动为独立 commit，不提交测试 placementId / Pods / Podfile.lock / project.pbxproj 环境差异。

**后续升级条件**：仅当 ToBid 提供与 Flame RenderSlots/物料模型对等的**客户端** Banner Native Mix API（类似 `ATNativeBannerView`），才重新评估 TB SelfRender 实现。后台"原生渲染横幅"配置能力不构成升级触发条件。

详见 `doc/flame_mediation/phase-5a.17b-tb-self-render-unsupported-bridge.md`。

---

### Phase 5A.17A：TK SelfRender Banner 现状审计与 ToBid Native 映射调研（docs commit `aaa09e3`）

**变更类型**：仅文档（SDK 业务代码零改动，Demo 代码零改动）

**核心事实（5A.17A 调研结论，全部保留）**：

1. **TK SelfRender 本质**：AnyThink Banner 「Native Mix」——不是纯 Native。证据：`AtBannerAdapter.m:247-251` 调 `retrieveBannerViewForPlacementID:config:nativeMixBannerViewBlock:`，返回 `ATBannerView` 容器 + 异步回调 `ATNativeBannerView`（含 `nativeAdMaterial`、资产 view、`registerClickableViewArray:`、`showAd`）。底层广告位类型是 Banner。
2. **Flame 公共 API 平台无关**：`FlameBannerAdMaterial` + `FlameBannerAdRenderSlots` + `FlameBannerListener`，Demo 零 AnyThink 依赖。
3. **ToBid 5.5.6 Native 自渲染栈完整**：`WindMillNativeAdsManager`→`WindMillNativeAd`→`WindMillNativeAdView`（refreshData/setClickableViews/unregisterDataObject，feedADMode!=NativeExpress 即自渲染）。
4. **ToBid 无客户端 Banner Native Mix 类**：只有普通 `WindMillBannerView`，无 `ATNativeBannerView` 对等 API。
5. **GDTAdapter 5.5.6 已含 Native 支持**：`WindMillGDTAdapter.NativeAdAdapter` 符号证据确凿，单一 subspec 覆盖 Banner+Native。

**最终判断（Phase 5A.17B 已修订）**：~~原方案 B（用 ToBid Native 桥接模拟 SelfRender）~~ → **方案 E**（公共 API 兼容保留，TB SelfRender 明确降级为不支持）。

**撤销方案 B 的原因**：强行用独立 Native 广告位模拟 Banner Native Mix 会改变广告位类型、后台配置模型、请求链路、曝光/点击绑定、View 生命周期、客户现有 Banner 语义。ToBid 后台"原生渲染横幅"是把 Native 广告源混入 Banner 聚合位的后台能力，不等同于 Flame SelfRender Banner 所需的"返回物料 + RenderSlots + 客户端自定义布局"。

**方案 E（采用）**：Flame 公共 API 全部保留；TB 收到 SelfRender 请求时不创建任何 ToBid 对象、不发起请求，通过现有 Listener 返回一次 unsupported capability 错误（复用 `ERROR_CODE_UNSUPPORTED_PLATFORM`）+ 统一日志 `[TB_SELF_RENDER_UNSUPPORTED]` + 安全降级 + 防重试风暴；普通 Express Banner 与 TK SelfRender 不受影响。

**后续升级条件**：仅当 ToBid 未来提供与 Flame RenderSlots/物料模型对等的**客户端 Banner Native Mix API**（类似 `ATNativeBannerView`），才重新评估 TB SelfRender 实现。后台"原生渲染横幅"配置能力不构成升级触发条件。

**红线遵守**：未修改 TbBannerAdapter / 未修改 AtBannerAdapter / 未修改 Flame 公共协议 / 未修改 Demo / 未修改后台 / 未增加广告源 / 未修改 podspec / 未升级 ToBid/GDT / 未创建试验性 UI / 未 push / 未 tag / 未 release。

详见 `doc/flame_mediation/phase-5a.17a-self-render-banner-research.md`（顶部「Phase 5A.17B 决策修订」+ §21E/§25E）。

---

### Phase 5A.16E.2：GDT Banner 真机验证 + TK/TB 坐标审计（本次 test commit）

**变更类型**：仅文档（SDK 业务代码零改动，Demo 代码零改动）

**核心结论**：

1. **GDT Banner 真机真实填充成功**：用户配置腾讯广告位 `q71507861622` + ToBid 聚合位 `1261219727399929` + Flame pMap 后，完整链路验证通过：
   ```
   load → ToBid 选 GDT 源（networkId=16）→ WindMillGDTAdapter 初始化
   → GDTUnifiedBannerView 加载 → bannerAdViewLoadSuccess:（didLoadSuccess）
   → TbBannerAdapter 设 frame=adSize → onAdLoaded
   → Demo 延迟 100ms retrieveAdView → addSubview + 4 边约束
   → bannerAdViewWillExpose: → onAdShow
   ```
2. **真实返回尺寸**：`WindMillBannerView.adSize` = **402×50 全宽**（非此前误判的 320×50），GDT 内部子 View `GDTUnifiedBannerView` 也填满 402×50，无侧边距。
3. **TK/TB 坐标审计**：临时注入只读诊断工具 `BannerLayoutDiag`（TK/TB 共用同一逻辑），在 retrieve/addSubview/layoutIfNeeded/on_expose 4 个时机采样。最终态（on_expose）：
   - screenFrame 两边均 `{0,0,402,874}`
   - containerFrameInWindow 两边均 `{0,741,402,50}`
   - adViewFrameInWindow 两边均 `{0,741,402,50}`
   - 内部子 View bounds 两边均 `{0,0,402,50}`
   - tabBarFrameInWindow 两边均 `{0,791,402,83}`
   - **intersectionHeight 两边均 0**（Container 底边 791 == TabBar 顶边 791，零重叠）
   - 唯一差异：adViewClips（TK=true / TB=false），子 View 未越界，无视觉影响
4. **判断结论**：TK/TB 底部 Express Banner 几何布局完全一致，无重叠、无裁切。当前布局（`.overlay` + `.frame(height:50)` + `.padding(.bottom,49)` + 4 边约束）对 TK/TB 均正确，**不做任何修改**。视觉差异仅为素材模板排版不同（如 GDT 双行密排 vs TK 单行疏排），非布局缺陷。

**历史判断纠偏**（真机坐标证据优先于截图推断）：
- ❌ 撤销 "TB Banner 只有 320×50，两侧留白" → 实际 402×50 全宽
- ❌ 撤销 "TB Banner 与 TabBar 重叠" → 实际 intersectionHeight=0
- ❌ 撤销 "需要修改底部布局 / safeAreaInset / bottom padding" → 几何无问题，不需要改

**未专项验证（可选，不阻塞结论）**：自动刷新（`bannerAdViewDidAutoRefresh:`）、点击落地页（`bannerAdViewDidClicked:`→`willOpenFullScreen`）、destroy 后 re-enter。

**红线遵守**：未修改 TbBannerAdapter / 未修改 AtBannerAdapter / 未修改 Flame 公共 API / 未改 Demo 业务布局 / 未加 TK/TB 布局分支 / 未拉伸广告素材 / 临时诊断工具已从 Demo 移除（不提交）/ 未 push / 未 tag / 未发布。

详见 `doc/flame_mediation/phase-5a.16e-gdt-banner-integration-report.md` §14（真机验证）+ §15（坐标审计）。

---

### Phase 5A.16E：腾讯优量汇 GDT Adapter 接入（SDK build commit `5414cf5`）

**变更类型**：TB podspec 依赖新增（非破坏性，SDK 业务代码零改动，Demo 代码零改动）

**起因**：Phase 5A.16D CSJ 官方测试位 no-fill（800110/20001），接入腾讯 GDT 作为用户自有 Banner 广告源。

**核心改动**：

| 文件 | 改动 | 目的 |
|------|------|------|
| `flame_sdk_ios_tb.podspec`（修改） | +1 依赖 `s.dependency 'ToBid-iOS-RC/GDTAdapter', '5.5.6'` | 引入腾讯优量汇（GDT）广告源，服务 Banner 验证（CSJ 测试位 no-fill 后的备选） |

**实现要点**：
- TB 包同时含 CSJ + GDT（不删除 CSJAdapter）
- GDTAdapter subspec 拉取 `GDTMobSDK 4.15.90` + `WindMillGDTAdapter.xcframework`
- GDTMobSDK 4.15.90 与 TK AnyThinkMediationGDTAdapter 同版本，无冲突
- 不修改 TbBannerAdapter（ToBid 自动选广告源，TbBannerAdapter 不感知 CSJ/GDT）
- 不修改 Flame Banner 公共 API / Demo / flame_sdk_ios.podspec (TK)

**验证**：

| 项 | 结果 |
|---|---|
| TB clean pod install | ✅ 6 pods（5→6，+GDTMobSDK 4.15.90） |
| TB iphoneos BUILD | ✅ SUCCEEDED |
| GDT artifacts（WindMillGDTAdapter + GDTMobSDK + Tquic + PrivacyInfo） | ✅ 齐备 |
| AnyThink 泄漏 | ✅ 无（AnyThinkiOS ABSENT） |
| TK clean pod install 回归 | ✅ 28 pods（不引入 ToBid GDTAdapter），BUILD SUCCEEDED |
| GDT Banner 真实填充 | ❌ 待用户后台配置（腾讯广告位 + ToBid 聚合位 + Flame pMap） |

**红线遵守**：未修改 TbBannerAdapter / 未修改 Flame Banner 公共 API / 未修改 Demo / 未修改 TK podspec / 未删除 CSJAdapter / 未接入其他广告源 / 未升级 ToBid 5.5.6 / 未 push / 未 tag / 未发布 / 未提交 Demo 临时配置 / project.pbxproj。

---

### Phase 5A.16D：CSJ Banner 真机填充验证（commit `39bc191`，进行中 — no-fill 阻塞）

**变更类型**：仅文档（SDK 业务代码零改动，Demo 代码零改动）

**状态**：链路与 Adapter 实现全部验证正确，但 CSJ 后台返回 no-fill。成功路径未验证。

**已验证（真机日志 2026-07-20 11:48）**：
- 两层 placementId 映射：Flame `q<REDACTED>` → pMap → ToBid 聚合 `7316148691848522`（不是同一层级）
- CSJ 渠道选中：ToBid `networkId=13`（WindMillAdnCSJ）
- WindMillCSJAdapter + BUAdSDK 7.6.0.4 初始化成功
- CSJ Banner 请求真实发出（`AdDidLoadStart networkId:13`）
- no-fill 错误链路完整：CSJ `nativeExpressBannerAdView:didLoadFailWithError:` → ToBid `800110/20001` → TbBannerAdapter `didFailToLoad` → Flame `onAdError` → Demo
- Adapter 不内部重试（destroy 后转 Demo）；Demo RetryScheduler 2s/4s 退避重试（1/5、2/5）
- 原 Splash/Interstitial/Reward 无回归
- 无 AnyThink 弹窗 / 无 dyld/selector 崩溃

**未验证（成功路径）**：load success / retrieveAdView / addSubview / adSize / 曝光 / 自动刷新 / 点击 / destroy / re-enter

**阻塞**：ToBid 官方测试位 `7316148691848522`（穿山甲_横幅广告_模版渲染，App ID 16990）当前 no-fill（800110/20001）。**尺寸已排除根因**：402×50 和 320×50 两次 Run 均返回相同错误。测试位属于 ToBid 官方（network placementId `948459823` 是官方测试位内部穿山甲 code ID），不需用户核查自己的后台。已整理诊断清单（App ID/placementId/networkId/SDK 版本/load_id/时间/错误码）等反馈 ToBid 技术支持确认测试位状态和要求尺寸。

**观察项**：BUAdSDK 内部 SQLite 迁移警告（duplicate column / db_save_error），未致崩溃或阻断请求，尚未取得官方结论。

**红线遵守**：未修改 TbBannerAdapter / 未增加 Adapter 重试 / 未修改公共 API / 未接入其他广告源 / 未 push / 未 tag / 未发布 / 暂未创建最终 commit（等 fill 后统一）。

---

### Phase 5A.16C：ToBid Banner Adapter 实现（commit `e5ff1ad`）

**变更类型**：新增广告类型适配器（非破坏性，SDK 公共 API + Demo 代码零改动）

**核心改动**：

| 文件 | 改动 | 目的 |
|------|------|------|
| `flame_sdk_ios/adapter/tb/TbBannerAdapter.{h,m}`（新增） | 实现 `FlameBannerAdapterProtocol` + `WindMillBannerViewDelegate`（10 方法，Express 完整 + SelfRender 占位） | TB 横幅（普通 Banner）接入 |
| `flame_sdk_ios/mediation/tb/FlameTBProvider.m`（修改） | Banner 工厂：占位 `return nil` → 创建 adapter | 打通 Router → Provider → Adapter 链路 |

**实现要点**（参考 AtBannerAdapter Express + WindMillBannerView 特化）：
- `loadAdData`（WindMill Banner 专用加载方法，非 Reward/Interstitial/Splash 的 loadAd）
- `initWithRequest:expectSize:`（camelCase，非 snake_case）
- `isAdValid` 作为 ready 判断（WindMill 无 isAdReady）
- `retrieveAdView` 返回 strong 持有的 WindMillBannerView（Demo 自己 addSubview + AutoLayout）
- auto-refresh 由 ToBid 后台控制（Adapter 不加 Timer）
- 首次失败不内部重试（与 TK AtBannerAdapter 一致；Demo RetryScheduler 负责）
- destroy 靠 `delegate=nil + removeFromSuperview + bannerView=nil`（WindMill 无 destroy 方法）
- stale callback 守卫（每个回调判断 `bannerAdView == self.bannerView`）
- 10 个 `WindMillBannerViewDelegate` 方法全实现（selector label 按头文件原样）
- `[TB_BANNER_DIAG]` 诊断日志全覆盖
- SelfRender 模式占位（本阶段不实现，红线 #11）
- project.pbxproj 零改动（PBXFileSystemSynchronizedRootGroup 自动同步）

**验证**：

| 项 | 结果 |
|---|---|
| XCFramework 构建 | ✅ BUILD EXIT 0，binary 324K→344K（+20K），两 slice 符号齐全 |
| AnyThinkSDK weak link 断言 | ✅ 无回归（两 slice LC_LOAD_WEAK_DYLIB） |
| TB 真机（iphoneos）BUILD | ✅ SUCCEEDED |
| TB 模拟器 BUILD | ❌ FAILED（pre-existing Flame xcframework 缺 arm64 sim slice，与 Banner 无关） |
| TbBannerAdapter 符号进 Flame framework | ✅ 两 slice |
| WindMillBannerView + BUNativeExpressBannerView 进 App dylib | ✅（CSJ Banner 链路完整） |
| TK clean pod install 回归 | ✅ 28 pods（不引入 ToBid CSJAdapter），BUILD SUCCEEDED |
| CSJ Banner 真实填充 | ❌ 未验证（Phase 5A.16D，需后台 + pMap + Demo Info.plist SKAdNetwork） |
| Demo 代码改动 | ❌ 零改动 |

**红线遵守**：未 push / 未 tag / 未发布 / 未改 Flame 对外 Banner API / 未加 TB 专属公共 Banner 类 / 未让 Demo import WindMillBannerView 或判断 pt / 未改 AtBannerAdapter / 未改 FlameTKProvider / 未改 Reward/Interstitial/Splash / 未处理 SelfRenderBanner / 未重引入 AnyThinkiOS / 未升级 ToBid 5.5.6 / 未升级 Ads-CN 7.6.0.4 / 未调私有 API / 未 Hook / 未写死 320×50 / 未新增 auto-refresh Timer / Adapter 未内部重试 / 未提交 project.pbxproj 环境差异 / Demo 代码零改动 / 测试 placementId / Pods / Podfile.lock。

---

### Phase 5A.16B：CSJ/Pangle 广告源最小依赖接入（commit `7f5acf0`）

**变更类型**：TB podspec 依赖新增（非破坏性，SDK 业务代码零改动）

**核心改动**：

| 文件 | 改动 | 目的 |
|------|------|------|
| `flame_sdk_ios_tb.podspec`（修改） | +1 依赖 `s.dependency 'ToBid-iOS-RC/CSJAdapter', '5.5.6'` | 引入 CSJ/Pangle（穿山甲）广告源，服务后续 Banner 最小闭环（Sigmob 自身无 Banner 填充） |

**实现要点**：
- 仅增加 CSJ，不增加其他网络（GDT/MS/Octopus/Baidu/KS/Mintegral/GroMore/BidResult 均不接入）
- 不在 Flame podspec 重复声明底层 Ads-CN/BUAdSDK/CSJMediation（由 ToBid 官方 CSJAdapter subspec 管理，单一来源）
- 不创建 TbBannerAdapter / 不修改 Banner 工厂 / 不修改 Banner 公共协议
- 不修改 Reward/Interstitial/Splash Adapter

**官方依赖链**（从 ToBid-iOS-RC 5.5.6 podspec 确认）：
```
ToBid-iOS-RC/CSJAdapter 5.5.6
  → vendored WindMillCSJAdapter.xcframework
  → Ads-CN/BUAdSDK 7.6.0.4（BUAdSDK.xcframework + CSJAdSDK.bundle）
  → ToBid-iOS-RC/ToBidSDK
```
**不拉取** BUAdLive-Framework / BUTTSDKFramework / CSJMediation（CSJAdapter 显式选 `Ads-CN/BUAdSDK` subspec，绕过 Ads-CN 默认 subspec 的 BUAdLive 陷阱）。

**验证**：

| 项 | 结果 |
|---|---|
| TB clean pod install | ✅ 5 pods（4→5，+Ads-CN/BUAdSDK 7.6.0.4） |
| TB 真机（iphoneos）BUILD | ✅ SUCCEEDED |
| TB 模拟器 BUILD | ❌ FAILED（pre-existing：Flame xcframework 缺 arm64 simulator slice，与 CSJ 无关；CSJ SDK 支持 arm64 sim） |
| CSJ Adapter 符号进 App | ✅ BUNativeExpressBannerView / WindMillCSJAdapter / WindMillBannerView 均在 debug dylib |
| AnyThink 弱链接无回归 | ✅ LC_LOAD_WEAK_DYLIB 保持 |
| AnyThink/TK adapter/SigmobAd-iOS 泄漏 | ✅ 全部 ABSENT |
| TK clean pod install 回归 | ✅ 28 pods（不拉 ToBid CSJAdapter），BUILD SUCCEEDED |
| TB App 启动冒烟 | ✅ 通过（pt=tb/无 AnyThink 弹窗/无 dyld/无 selector/无 duplicate class/CSJ 未触发符合预期/主页面正常） |
| 原 Splash/Interstitial/Reward 回归 | ✅ 通过（Splash skip+close 幂等 / Interstitial 完整 close-loop / Reward 两轮闭环 cachedVC=0x0 时动态 presenter 修复生效） |
| Banner Adapter | ❌ 未实现（Phase 5A.16C） |

**体积**：Pods 138M→553M（+415M，含双 slice）；App ~130M。

**SKAdNetwork**：CSJ 10+ 个 ID 待 Phase 5A.16C/D 加 Demo Info.plist（本阶段不修改 Demo）。

**红线遵守**：未 push / 未 tag / 未发布 / 未创建 TbBannerAdapter / 未修改 Banner 工厂 / 未修改 Banner 公共协议 / 未修改 Reward/Interstitial/Splash / 未升级 ToBid 5.5.6 / 未升级 CSJ SDK / 未改版本号 / 未改远程 flame-specs / 未把第三方 SDK 打进 flame_sdk_ios.xcframework / 未手工声明 Ads-CN/BUAdSDK/BUAdLive/CSJMediation / 未提交 Pods/Podfile.lock/xcworkspace/project.pbxproj 环境差异 / Demo 代码零改动。

---

### Phase 5A.16A：ToBid 第三方广告源交付包审计（commit `3b5326d`，仅文档）

只读审计 + 集成方案设计。审计 `doc/tobid_doc` 9 个广告源（CSJ/GDT/Baidu/KS/Mintegral/MS/Octopus/GroMore + bidResult），Banner 候选 6 家（CSJ/GDT/GroMore/Mintegral/MS/Octopus），Baidu/KS/Sigmob 不支持 Banner。详见 `phase-5a.16a-tb-ad-network-integration-audit.md`。

---

## Phase 5A.15（完成）— TB 开屏广告接入

### Phase 5A.15.1：验收补齐 + 文档收口（本次 SDK docs commit）

**变更类型**：仅文档变更（SDK 业务代码零改动）

**起因**：Phase 5A.15（commit `0d13dd5`）初版报告中 R3 独立冷启动、Reward 完整回归、TK 编译回归三项均未完成（分别写"未单独执行/留待后续/留待后续"）。Phase 5A.15.1 补齐这三项验收。

**三项补齐结果**：

| 项 | 结果 |
|---|---|
| Splash R3 独立冷启动 | ✅ 通过（完全杀进程重启，pt=tb，load/show/willPresent/didPresent/skip+close 完整链路，finishOnce 二次拦截生效，无 AnyThink 弹窗/黑屏/重复展示，主页面正常） |
| Splash 三次独立冷启动 | ✅ 全部通过（R1 倒计时关闭 + R2/R3 skip/close 幂等，finishOnce 守卫二次拦截均生效） |
| Reward 完整展示回归 | ✅ 通过（两轮闭环 load/show/willVisible/didVisible/didClose/next-load/next-didLoad，presenter/vcWindow 非空，thread=1；cachedVC=0x0 时动态 presenter 修复仍生效；奖励回调本轮未出现，非阻塞） |
| TK 干净编译回归 | ✅ 通过（28 pods + BUILD SUCCEEDED + AnyThinkSDK.framework 进入 App + flame_sdk_ios.framework 进入 App + Flame binary 保持 LC_LOAD_WEAK_DYLIB + TK guard 已编入；本轮未重新执行 TK 真机初始化，guard 真机未触发沿用 Phase 5A.13 Step 1.3 结论） |
| AnyThink 隔离 | ✅ 无回归（TK podspec 带入嵌入 / Flame binary 保持 weak / TB podspec 不带入） |
| 公共 API | ❌ 未变 |

**关键表述修正（按 Phase 5A.15.1 v2 §6/§10.4）**：
- ❌ 不写"TK 构建中 AnyThink 强加载"；✅ "TK podspec 负责将 AnyThinkSDK.framework 带入并嵌入 App；Flame binary 对 AnyThinkSDK 仍保持 LC_LOAD_WEAK_DYLIB。"
- ❌ 不写"二进制有 guard 字符串，因此本轮 guard 未触发"；✅ "TK guard 已编入二进制；本轮未重新执行 TK 真机初始化。Phase 5A.13 Step 1.3 的 TK 真机验证中 ATAPI 守卫通过，未出现 TK_PLATFORM_REQUIRES_ANYTHINK。"
- ❌ 不写"下一条 ad 地址必须不同"；✅ 以 adapter 轮次 + load created + isCurrent 为准。
- ❌ 不写"R2 关闭后预热 load 等于 R3 独立冷启动"；✅ R3 已执行真正的独立冷启动（杀进程重启）。

**红线遵守**：未 push / 未 tag / 未发布 / 未改 SDK 业务代码 / 未改 TbSplashAdapter/TbRewardAdapter/TbInterstitialAdapter / 未改公共 API / 未重引入 AnyThinkiOS / 未升级版本 / 未改版本号 / 未提交 project.pbxproj 环境差异 / Pods / Podfile.lock / xcworkspace / 测试 placementId / 真机日志。

**结论**：Phase 5A.15 正式完成。下一阶段（TB Banner）存在待沟通问题，未进入 Phase 5A.16，未创建或修改 Banner Adapter。

---

### Phase 5A.15：TB 开屏 Adapter 接入（commit `0d13dd5`）

**变更类型**：新增广告类型适配器（非破坏性）

**核心改动**：

| 文件 | 改动 | 目的 |
|------|------|------|
| `flame_sdk_ios/adapter/tb/TbSplashAdapter.{h,m}`（新增） | 实现 `FlameSplashAdapterProtocol` + `WindMillSplashAdDelegate`（14 方法） | TB 开屏接入 |
| `flame_sdk_ios/mediation/tb/FlameTBProvider.m`（修改） | 工厂接入：`createSplashAdapter...` 占位 `return nil` → 创建 adapter | 打通 Router → Provider → Adapter 链路 |
| `doc/flame_mediation/phase-5a.14-tb-interstitial-implementation-report.md`（修改，§3 前置） | 异常场景口径收紧 + R3 内存复用说明 | 5A.15 前置修正 |

**实现要点**（复用 TbRewardAdapter/TbInterstitialAdapter 已验证模式 + Splash 特化）：

- 加载方法 **`loadAd`**（不是 Reward/Interstitial 的 `loadAdData`）
- 展示方法 **`showAdInWindow:window withBottomView:nil`**（取 `UIWindow*`，不是 `showAdFromRootViewController:`）
- show 参数来自协议 `show:(UIWindow *)window`（Demo LaunchScreenWindow / keyWindow），**不需要** `flame_topViewController()`
- **`finishOnceWithReason:` 幂等**：ToBid 的 `onSplashAdSkiped:` + `onSplashAdClosed:` 收敛到一次 `onAdClosed`（click 不视为 close）
- stale callback 守卫（每个回调判断 `splashAd == self.splashAd`）
- 14 个 `WindMillSplashAdDelegate` 方法全实现（WindMill 拼写错误 `Skiped`/`WillClosed`/`AdDidAutoLoad` 严格保留）
- `[TB_SPLASH_DIAG]` 诊断日志全覆盖
- Xcode 工程：`PBXFileSystemSynchronizedRootGroup` 自动识别新文件，**project.pbxproj 零改动**

**验证（基于 Demo 本地 TB 配置 + `flame_sdk_ios_tb 1.0.0-alpha.4-local`）**：

| 项 | 结果 |
|---|---|
| XCFramework 构建 | ✅ BUILD EXIT 0，binary 320K→324K（+4K），两 slice 符号齐全 |
| AnyThinkSDK weak link 断言 | ✅ 无回归（两 slice LC_LOAD_WEAK_DYLIB，真机无 ADX 弹窗） |
| 真机 R1 倒计时关闭完整闭环 | ✅ load/show/willPresent/didPresent(didVisible)/[6s]/willClose/didClose/finish(reason=close)/onAdClosed |
| **真机 R2 skip+close 幂等** | ✅ **专项验证通过**：Sigmob 先 `onSplashAdSkiped` 后 `onSplashAdClosed`，finishOnce 守卫正确拦下第二次（日志 `finish already done: reason=close`），业务 onAdClosed 只通知一次 |
| 异常场景 | ⚠️ 仅 skip/close 幂等真机实测通过；未就绪 show / 重复 show / stale callback 为代码实现 + 静态审计 |
| Reward 完整回归 | ⚠️ 仅加载回归通过（沿用 5A.14.1 状态，未倒退） |
| TK 编译回归 | ⚠️ 本轮未执行（改动未触及 TK 侧，风险低，留待下阶段冒烟） |

**红线遵守**：未 push / 未 tag / 未发布 / 未改公共 API / 未加第二套公共 Splash 类 / 未重引入 AnyThinkiOS / 未加 ADX / 未调私有 API / 未 Hook/swizzle / 未用固定延时掩盖 Window 问题 / 未改 Reward/Interstitial Adapter / 未升级版本 / 未改版本号 / 未提交 project.pbxproj 环境差异 / Demo 代码零改动 / 测试 placementId / Pods / Podfile.lock。

---

## Phase 5A.14（进行中）— TB 插屏广告接入

### Phase 5A.14.1：验收口径修正 + Demo 预加载时机修正（本次 SDK docs commit）

**变更类型**：仅文档变更（SDK 代码零改动）

**起因**：Phase 5A.14 初版（`f97e746`）在 Demo `InterstitialAdManager.onShow` 立即触发 `load()` 的情况下做真机验证，整段日志 **0 个 didClose**，但报告误将"load/show/visible 通过"写成"3 轮全闭环"，并把 Reward 的 load/didLoad 写成"回归通过"。

**Demo 修正（Demo 仓库 `11c5958`，独立本地 commit）**：

- `InterstitialAdManager.onShow` 不再调用 `load()`，仅置 `isReady=false` 并通知展示成功
- `onClosed` 中清空当前 `interstitialAd` 后再 `load()` 下一条（对齐 `RewardVideoAdManager` 已验证模式）

**修正后真机结果（基于 Demo `11c5958`）**：

| 项 | 结果 |
|---|---|
| R1 完整闭环 | ✅ load/show/willVisible/didVisible/**didClose**/next-load |
| R2 完整闭环（ad ≠ R1） | ✅ load/show/didVisible/**didClose**/next-load；cachedVC=0x0 时动态 presenter 仍生效 |
| R3 load success | ✅ R2 关闭后立即自动加载成功（循环未断）|
| AnyThink ADX 弹窗（全程）| ❌ 未出现 |
| Reward 回归 | ⚠️ **仅加载回归通过**（load/didLoad 正常，未实测 show/close，不写"完整回归通过"） |
| 异常场景 | 连续 show / load 中再 load 已实测；未就绪 show / stale callback 仅代码实现 + 静态审计 |

**SDK 报告修订（本次 docs commit）**：

- §8 新增"修正后真机验证"章节（R1/R2/R3 真实地址与事件）
- §9/§10 标注旧版数据"已被 §8 取代"，保留以记录历史
- §11 异常场景按"实现 / 静态审计 / 真机实测"三档区分
- §12 Reward 回归改为"仅加载回归通过"
- §13 责任边界按真实结果表述，不绝对断言 SDK 无缺陷

**红线遵守**：未 push / 未 tag / 未发布 / 未改公共 API / 未重引入 AnyThinkiOS / 未调私有 API / 未 Hook / 未升级版本 / 未提交 project.pbxproj 环境差异 / Demo 测试配置 / Pods / Podfile.lock。

---

### Phase 5A.14 初版：TB 插屏 Adapter 接入（commit `f97e746`，验收口径已在 5A.14.1 修正）

**变更类型**：新增广告类型适配器（非破坏性）

**核心改动**：

| 文件 | 改动 | 目的 |
|------|------|------|
| `flame_sdk_ios/adapter/tb/TbInterstitialAdapter.{h,m}`（新增） | 实现 `FlameInterstitialAdapterProtocol` + `WindMillIntersititialAdDelegate` | TB 插屏接入 |
| `flame_sdk_ios/mediation/tb/FlameTBProvider.m`（修改） | 工厂接入：`createInterstitialAdapter...` 占位 `return nil` → 创建 adapter | 打通 Router → Provider → Adapter 链路 |

**实现要点**（复用 TbRewardAdapter 已验证模式）：

- `flame_topViewController()` 动态获取 presenter（解决关闭后重载的 VC 失效，与 Reward 同修复）
- stale callback 守卫（每个回调判断 `intersititialAd == self.intersititialAd`）
- 11 个 `WindMillIntersititialAdDelegate` 方法全实现（WindMill 类名拼写错误 `Intersititial` 严格保留）
- `[TB_INTERSTITIAL_DIAG]` 诊断日志全覆盖
- Xcode 工程：`PBXFileSystemSynchronizedRootGroup` 自动识别新文件，**project.pbxproj 零改动**

**验证（Phase 5A.14.1 修正后口径）**：

| 项 | 结果 |
|---|---|
| XCFramework 构建 | BUILD EXIT 0，binary 300K→320K（+20K） |
| AnyThinkSDK weak link 断言 | ✅ 无回归 |
| 真机插屏 R1/R2 完整关闭闭环 | ✅ load/show/willVisible/didVisible/didClose/next-load |
| 真机插屏 R3 load success | ✅ |
| 动态 presenter 修复（R2 cachedVC=0x0） | ✅ 持续生效 |
| Reward 加载回归 | ✅ load/didLoad 正常 |
| Reward 完整回归（show/close） | ⚠️ 未实测 |
| TK 编译回归 | ✅ BUILD SUCCEEDED（单一二进制双线共享） |
| 公共 API | ❌ 未变 |

---

## Phase 5A.13（已完成）— AnyThink 弱链接方案正式纳入

### Step 1.3：正式化与 TK 真机冒烟验收（本次 commit）

**变更类型**：架构依赖边界正式化（非破坏性）

**核心改动**：

| 文件 | 改动 | 目的 |
|------|------|------|
| `flame_sdk_ios_tb.podspec` | 移除 `s.dependency 'AnyThinkiOS', '6.5.71'` | TB 客户不再携带 AnyThinkSDK.framework，消除 ADX 弹窗 |
| `flame_sdk_ios.podspec` | `flame-sdk-tk-sigmob-adapter` → `flame_sdk_ios_tk_sigmob_adapter`（hyphen→underscore） | 旧版 TK podspec 使用了错误的 Sigmob Adapter 依赖名；使用该版本 spec 安装时可能导致依赖解析失败。本阶段已修正为实际存在的 underscore 形式（与 flame-specs 实际发布的 spec 名一致） |
| `flame_sdk_ios.podspec` 注释 | 补充说明 binary 已弱链接，AnyThinkiOS 由 TK podspec 独家带入 | 文档清晰化 |

**前置（c40e4fe 已完成，Step 1.2B PoC）**：

| 文件 | 改动 | 目的 |
|------|------|------|
| `xcFramework_build.sh` | 新增 AnyThinkSDK 弱链接 patch（-framework → -weak_framework，幂等 + fail-fast + 后置 otool 双断言） | binary 对 AnyThinkSDK 改为 LC_LOAD_WEAK_DYLIB |
| `flame_sdk_ios/mediation/tk/FlameTKProvider.m` | `initializeWithAppId:` 入口加 `NSClassFromString(@"ATAPI")` 守卫 | pt=tk 但 AnyThink 缺失时返回明确错误回调（TK_PLATFORM_REQUIRES_ANYTHINK），不崩溃不 silent fallback |

**验证**：

| 项 | 结果 |
|---|---|
| SDK 构建（含 otool 弱链接双断言） | BUILD EXIT 0 ✅ |
| TB 真机冷启动 3/3 无 ADX 弹窗 | ✅（Step 1.2B 已验证，3/3） |
| TB Reward 3 轮闭环 | ✅（Step 1.2B 已验证，load/show/visible/reward/close/next-load） |
| TK 真机冒烟 | ✅（Step 1.3，全广告位正常加载，无 TK_PLATFORM_REQUIRES_ANYTHINK） |
| TK App Frameworks 含 AnyThinkSDK.framework + SmartdigimktSDK.framework | ✅ |
| TB App Frameworks 不含 AnyThinkSDK.framework | ✅ |
| Flame binary LC_LOAD_WEAK_DYLIB | ✅ |
| 公共 API 未变 | ✅ |
| 单一 XCFramework（不拆 TK/TB 二进制） | ✅ |

**红线遵守**：

- ❌ 未 push / 未 tag / 未发布
- ❌ 未修改远程 flame-specs
- ❌ 未调用 AnyThink 私有 API（仅 `NSClassFromString(@"ATAPI")`，ATAPI 是 AnyThinkiOS 6.5.71 公开 Header）
- ❌ 未增加 AnyThink ADX 组件
- ❌ 未修改后台 pt 路由
- ❌ 未升级 AnyThink/ToBid/Sigmob 版本
- ❌ 未修改版本号（仍为 1.0.0-alpha.4-local）

**业务影响**：

- **TB 客户**：消除 "AnyThink Adx SDK 重要组件缺失" 弹窗（此前每次冷启动必现）
- **TK 客户**：修复 sigmob adapter 依赖名 bug（此前 `pod install` 直接报 spec 找不到）
- **双线客户**：公共 API 不变，无需改动接入代码

**新增非阻塞问题（登记，不在本 commit 处理）**：

- TB Reward 奖励回调后 3 次 NSURLErrorDomain -1002（`?sdkVersion=5.5.6&appId=16990`）
- 高概率推断来源：Sigmob WindSDK S2S 奖励回调上报（rvCallbackURL 为空）
- 详见 `phase-5a.13-step1.2b-tb-anythink-runtime-isolation-poc-report.md` "附" 章节

---

## Phase 5A.12（已完成）— 单二进制架构 + 双 podspec 发布

详见：
- `phase-5a.12-single-binary-mainline.md`
- `phase-5a.12-step3d-release-docs-and-customer-guide-cleanup-report.md`

核心：
- 一个 `flame_sdk_ios.xcframework`（300K）同时内置 TK/TB 胶水
- 两个 podspec：`flame_sdk_ios`（TK）/ `flame_sdk_ios_tb`（TB）
- +load 自动注册（FlameTKProvider / FlameTBProvider）
- FlameMediationRouter 按服务端 pt 激活对应 Provider
- 发布 1.0.0-alpha.1（远程 flame-specs）

---

## Phase 5A.11（已完成）— 三包方案（已被 5A.12 单二进制取代）

## Phase 5A.10（已完成）— thin core 调研（已被 5A.12 单二进制取代）
