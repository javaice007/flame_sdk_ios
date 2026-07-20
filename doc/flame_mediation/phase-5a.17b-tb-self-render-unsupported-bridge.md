# Phase 5A.17B：TB SelfRender Banner 兼容桥接与不支持降级处理

> **本阶段性质**：方案 E 实施——Flame 公共 API 保持兼容，TB SelfRender Banner 明确返回 unsupported capability 并安全降级。
>
> **基线**：SDK HEAD `aaa09e3`（Phase 5A.17A docs commit）
> **决策依据**：详见 `phase-5a.17a-self-render-banner-research.md` 顶部「Phase 5A.17B 决策修订」
> **最终状态**：本地 feature commit（未 push、未 tag、未 release）

---

## 1. 决策变更（撤销方案 B，采用方案 E）

### 1.1 原计划（已撤销）

原 5A.17A 建议方案 B：`TbBannerAdapter SelfRender 分支 → TbNativeSelfRenderController → WindMillNativeAdsManager → WindMillNativeAd → WindMillNativeAdView`，用 ToBid Native 自渲染模拟 Flame SelfRender Banner。

### 1.2 撤销原因

1. TK SelfRender Banner 是 AnyThink **Banner Native Mix**（Banner 聚合位 + `ATBannerView` + `ATNativeBannerView`）。
2. ToBid 5.5.6 **公开 Header 中没有对等的客户端 Banner Native Mix API**——只有普通 `WindMillBannerView` 和独立 Native 自渲染栈。
3. ToBid 后台"原生渲染横幅"是把 Native 广告源混入 Banner 聚合位的后台能力，**不等同于** Flame SelfRender Banner 所需的"返回物料 + RenderSlots + 客户端自定义布局"。
4. 强行用 ToBid Native 聚合位实现 Flame SelfRender Banner 会改变：广告位类型、后台配置模型、请求链路、曝光/点击绑定、View 生命周期、客户现有 Banner 语义。

### 1.3 方案 E（采用）

- **Flame 公共 API 保持兼容保留**：`FlameBannerAd` / `createSelfRenderBannerAd` / `retrieveMaterials` / `bindMaterialAtIndex:slots:` / `unbindMaterial` / `destroy` / `FlameBannerListener` 全部不动。
- **TB SelfRender 明确降级**：收到 SelfRender 请求时，不创建 `WindMillBannerView`、不创建 `WindMillNativeAdsManager`、不发起任何 ToBid 请求，通过现有 Listener 返回一次 unsupported capability 错误（复用 `ERROR_CODE_UNSUPPORTED_PLATFORM` = 14003），输出统一诊断日志 `[TB_SELF_RENDER_UNSUPPORTED]`，安全结束当前生命周期。
- **普通 Express Banner 不受影响**：继续走 `WindMillBannerView` → GDT/CSJ 正常填充。
- **TK SelfRender 保持原样**：`AtBannerAdapter` 不动，AnyThink Banner Native Mix 正常工作。

### 1.4 关键口径区分（避免误读）

- ❌ "ToBid 完全不支持原生渲染横幅"——错误（后台原生渲染横幅存在，ToBid Native 自渲染 API 也存在）
- ✅ "ToBid 当前未提供与 Flame SelfRender Banner 对等的**客户端** Banner Native Mix 接口"——正确

---

## 2. 错误码（复用现有，不新增公共枚举）

| Flame 错误码 | 值 | 含义 | 本阶段用途 |
|---|---|---|---|
| `ERROR_CODE_UNSUPPORTED_PLATFORM` | 14003 | 不支持的聚合平台 | **复用**——表示 TB 聚合平台当前不支持 SelfRender Banner 客户端能力 |

错误描述（中文，专业口径）：

```
当前聚合平台暂不支持开发者自渲染横幅广告
```

**禁止**的错误描述（避免误读为具体广告源问题）：
- 腾讯广告不支持 / GDT 不支持 / 穿山甲不支持
- 广告位无填充 / 网络错误
- ToBid 完全不支持原生广告 / 原生渲染横幅

---

## 3. 统一诊断日志

### 3.1 前缀与字段

```
[TB_SELF_RENDER_UNSUPPORTED] platform=tb | mediation=ToBid | mediationSdkVersion=5.5.6 | adFormat=banner | renderMode=self_render | capability=unsupported | action=skip_request | fallback=none | expressBannerAffected=false | message="当前聚合平台暂不支持开发者自渲染横幅广告"
```

### 3.2 输出规则

- 每次 SelfRender load 生命周期**只打印一次**主诊断日志（`_selfRenderUnsupportedReported` 标记防止 retrieve/bind 反复刷屏）
- placementId 不输出（避免泄露）
- 不输出 AppKey / Secret / Token
- 普通 Express Banner **不打印**该日志
- TK **不打印**该日志（代码在 TbBannerAdapter 内，TK 走 AtBannerAdapter）

### 3.3 二进制符号验证

字符串嵌入位置：`__TEXT/__ustring` 段（UTF-16，因含中文字符）。Python 验证：

```
UTF-16 'TB_SELF_RENDER_UNSUPPORTED' matches: 1 (arm64) + 1 (sim)
UTF-16 '当前聚合平台' matches: 2 (日志 + 错误描述)
```

`strings` 工具默认只扫 ASCII，所以 grep `TB_SELF_RENDER_UNSUPPORTED` 返回 0 是误报；实际嵌入正确。

---

## 4. TbBannerAdapter SelfRender 行为

### 4.1 load（`TbBannerAdapter.m:52-91`）

当 `renderType == FlameBannerRenderTypeSelfRender`：

1. 设置 `_isLoading = NO; _loaded = NO`
2. 若 `_selfRenderUnsupportedReported == NO`：置 YES + 输出 `[TB_SELF_RENDER_UNSUPPORTED]` 主日志
3. **异步派发到主线程**回调一次 `onAdError:ERROR_CODE_UNSUPPORTED_PLATFORM desc:@"当前聚合平台暂不支持开发者自渲染横幅广告"`（避免 load 方法内同步回调导致业务方状态未就绪）
4. 用 `__weak self` + `_destroyed` 守卫：destroy 后迟到的 block 不再回调业务
5. 不创建 `WindMillBannerView`
6. 不创建 `WindMillNativeAdsManager`
7. 不发起任何 ToBid 请求
8. 不触发 `onAdLoaded` / `onAdShow` / `onAdClosed`

### 4.2 retrieveAdView

SelfRender 模式直接 `return nil`（不创建假 View，不返回 WindMillBannerView，不返回 WindMillNativeAdView）。

### 4.3 retrieveMaterials

返回空数组 `@[]`（不创建假物料；Express 模式同样返回空数组，与 AtBannerAdapter Express 一致）。

### 4.4 bindMaterialAtIndex:slots:

安全 no-op（不修改 RenderSlots，不添加 UIView，不注册点击，不触发曝光，不重复错误回调）。

### 4.5 unbindMaterial

幂等 no-op。

### 4.6 destroy

- 设置 `_destroyed = YES`（阻断迟到的异步 unsupported 回调 block）
- 清理 bannerView（若有）
- 置 nil listener/viewController/adSize
- 不触发 close

### 4.7 普通 Express Banner 完全隔离

SelfRender unsupported 状态不污染 Express 分支的 `bannerView` / `placementId` / `loading` / `ready` / `listener` / `generation` / `destroy` / auto refresh。Express 分支代码（L93-180）未改动。

---

## 5. 重试控制（Demo 侧，平台无关）

### 5.1 问题

`SelfRenderBannerManager.handleError()`（`SelfRenderBannerManager.swift:182-196`）对所有 `onAdError` 自动重试 5 次（指数退避）。如果 unsupported capability 进入重试循环，会产生 5 次无意义的 unsupported → retry → unsupported 风暴。

### 5.2 方案（平台无关，不判 pt）

在 `SelfRenderBannerManager.swift` 新增嵌套枚举 `NonRetryableErrorCodes`：

```swift
enum NonRetryableErrorCodes {
    static let unsupportedPlatform = "14003"  // ERROR_CODE_UNSUPPORTED_PLATFORM
    static let invalidPlacement = "14004"     // ERROR_CODE_INVALID_AD_PLACEMENT
    static let invalidParam = "14002"         // ERROR_CODE_INVALID_PARAM

    private static let set: Set<String> = [unsupportedPlatform, invalidPlacement, invalidParam]

    static func isNonRetryable(_ code: String) -> Bool {
        return set.contains(code)
    }
}
```

在 `onError` 回调里短路：

```swift
listener.onError = { [weak self] code, desc in
    DispatchQueue.main.async {
        self?.errorMessage = "\(code): \(desc)"
        if Self.NonRetryableErrorCodes.isNonRetryable(code) {
            FlameLogger.log("SelfRenderBanner", "不可重试错误（\(code)），终止重试")
            self?.bannerAd?.destroy()
            self?.bannerAd = nil
            self?.material = nil
            self?.isLoading = false
            return
        }
        self?.handleError()  // 原重试逻辑
    }
}
```

### 5.3 设计原则（严格遵守）

- **只基于 Flame 公开错误码语义判断**（14003/14004/14002）
- **不判 `pt=tk/tb`**
- **不 import 任何三方 SDK**（不 import ToBid / AnyThink）
- TK/TB 共用同一逻辑
- 网络/no-fill 等可恢复错误继续按原规则重试

---

## 6. 修改文件清单

### 6.1 SDK 仓库（本阶段 feature commit）

| 文件 | 改动 |
|---|---|
| `flame_sdk_ios/adapter/tb/TbBannerAdapter.h` | 更新头注释（SelfRender 从 5A.16C 占位改为 5A.17B 方案 E 降级说明） |
| `flame_sdk_ios/adapter/tb/TbBannerAdapter.m` | 新增 `_destroyed` / `_selfRenderUnsupportedReported` ivar；SelfRender load 分支升级为专业降级（统一日志 + 异步派发 + generation 守卫 + 复用 ERROR_CODE_UNSUPPORTED_PLATFORM）；retrieveAdView/retrieveMaterials/bind/unbind 行为明确 no-op；destroy 加 `_destroyed = YES` |

### 6.2 Demo 仓库（本阶段独立 commit）

| 文件 | 改动 |
|---|---|
| `Sources/Ad/SelfRenderBannerManager.swift` | `onError` 加 unsupported/invalid 不可重试短路；新增 `NonRetryableErrorCodes` 嵌套枚举 |

### 6.3 未改动（红线遵守）

- `AtBannerAdapter.{h,m}`（TK SelfRender 保持原样）
- `FlameBannerAd.h` / `FlameBannerAdMaterial.h` / `FlameBannerAdRenderSlots.h` / `FlameBannerAdapterProtocol.h`（公共 API 不变）
- `FlameErrorCode.{h,m}`（复用现有 `ERROR_CODE_UNSUPPORTED_PLATFORM`，不新增公共枚举）
- `flame_sdk_ios.podspec` / `flame_sdk_ios_tb.podspec`（不增减依赖）
- `FlameTBProvider.m`（工厂逻辑不变）
- TK Demo 代码（仅临时切 TK 验证编译，已恢复 TB）

---

## 7. 构建验证

### 7.1 XCFramework

```
✅ 双 Archive SUCCEEDED
✅ XCFramework 生成
✅ AnyThink LC_LOAD_WEAK_DYLIB（无回归）
✅ TB_SELF_RENDER_UNSUPPORTED 字符串嵌入 __TEXT/__ustring（UTF-16，两 slice 各 1）
✅ '当前聚合平台' UTF-16 嵌入（两 slice 各 2）
✅ TbNativeSelfRenderController 符号 = 0（未创建）
✅ WindMillNativeAdsManager 直接使用符号 = 0（未调用）
✅ TbBannerAdapter 符号存在（两 slice）
✅ TB_BANNER_DIAG / TB_REWARD_DIAG / TB_SPLASH_DIAG / TK_PLATFORM_REQUIRES_ANYTHINK 无回归
```

### 7.2 TB Demo

```
✅ clean pod install（6 pods: flame_sdk_ios_tb + ToBid-iOS-RC + CSJAdapter + GDTAdapter + BUAdSDK + GDTMobSDK）
✅ iphoneos BUILD SUCCEEDED
✅ AnyThink ABSENT
✅ GDT/ToBid 依赖不变
✅ 无新增 pod
```

### 7.3 TK Demo（临时切 TK 回归）

```
✅ clean pod install（28 pods: flame_sdk_ios + AnyThinkiOS 6.5.71 + 全套 AnyThinkMediation）
✅ iphoneos BUILD SUCCEEDED
✅ AtBannerAdapter 未修改
✅ SelfRender API 仍可编译
✅ TB unsupported 逻辑不进入 TK（TbBannerAdapter 不在 TK 编译路径）
✅ ToBid GDT Adapter 不进入 TK
```

### 7.4 模拟器（已知限制，不归因本阶段）

预存的 Flame xcframework simulator slice 为 x86_64-only（GDTMobSDK 限制），Apple Silicon 需 Rosetta。**不使用 EXCLUDED_ARCHS 掩盖**，如实记录。

---

## 8. 能力矩阵

| 能力 | TK | TB |
|---|---|---|
| 普通 Express Banner | ✅ 支持 | ✅ 支持（GDT 真机填充已验证，Phase 5A.16E） |
| 客户端 SelfRender Banner | ✅ 支持（AnyThink Banner Native Mix） | ⚠️ **暂不支持，兼容降级**（返回 unsupported capability 错误 + 统一日志） |
| Native 自渲染广告（独立） | Flame AtNativeAdapter 承载（不在本阶段范围） | ToBid 底层支持（WindMillNativeAdsManager），**但不用于模拟 SelfRender Banner** |
| 后台原生渲染横幅混用 | 由聚合平台配置决定 | ToBid 支持，但不等同于 Flame SelfRender API |

---

## 9. 客户影响

| 场景 | 行为 |
|---|---|
| 客户从 TK 切换到 TB（仅改 Podfile） | 业务代码无需修改，正常编译运行 |
| TK SelfRender Banner | 正常加载和渲染 |
| TB SelfRender Banner 请求 | 不崩溃；收到一次明确 unsupported 错误；打印一次 `[TB_SELF_RENDER_UNSUPPORTED]` 日志；不重试风暴 |
| TB 普通 Express Banner | 正常加载和显示（不受 SelfRender 降级影响） |
| 客户根据错误隐藏 SelfRender 区域 | 可基于错误码 14003 判断（通用，不判平台） |
| 客户保留 SelfRender 占位 | 也安全（SDK 返回空物料，Demo 自行处理空态） |

---

## 10. 后续升级条件

**只有以下条件全部满足**，才重新评估 TB SelfRender Banner 实现：

1. ToBid 未来提供与 Flame RenderSlots/物料模型对等的**客户端** Banner Native Mix API（类似 AnyThink `ATNativeBannerView`）
2. 该 API 能返回物料数据 + 资产 View + 支持 registerClickableViews + 由客户端布局

**不构成升级触发条件**：
- ToBid 后台"原生渲染横幅"配置能力（这是后台流量混用，不是客户端 API）
- ToBid 独立 Native 自渲染 API（已存在，但用独立 Native 广告位模拟 Banner 会改变语义，不采纳）

---

## 11. 未专项验证（可选，不阻塞）

本阶段为静态实现 + 构建验证。以下未在本轮真机触发，不影响"降级逻辑成立"的结论（代码路径明确，符号验证通过，构建通过）：

- TB SelfRender load 真机触发 `[TB_SELF_RENDER_UNSUPPORTED]` 日志输出
- TB SelfRender 收到 onAdError(14003) 后 Demo `NonRetryableErrorCodes` 短路生效
- 普通 Express Banner 在 SelfRender 降级后仍正常加载（隔离性）

如需真机验证，用户 Run TB Demo 进入"自渲染 Banner"页面即可观察。

---

## 12. Git

| 项 | 状态 |
|---|---|
| SDK docs commit（5A.17A） | `aaa09e3 docs: research TB self-render banner capability (Phase 5A.17A)` |
| SDK feature commit（5A.17B） | 本阶段创建：`feat: add TB self-render banner fallback` |
| Demo commit（5A.17B） | 本阶段创建：`fix: skip retry for unsupported ad capability` |
| push | 未 push |
| tag | 未 tag |
| release | 未 release |

### 12.1 严格排除

SDK commit 排除：`project.pbxproj` 环境差异、`.zcode`、Pods、Podfile.lock、xcworkspace、build、Archives、测试 placementId、真机日志、Demo 配置。

Demo commit 排除：Pods、Podfile.lock、xcworkspace、project.pbxproj 环境差异、测试 placementId、`err.log`、`Sources/Diagnostics/`（用户本地新增目录）、`AGENTS.md`、`xcshareddata`。

---

## 13. /compact

Phase 5A.17B 完成（方案 E 兼容降级，未 push/tag/release）：撤销原方案 B（用 ToBid Native 桥接模拟 SelfRender，会改变广告位类型/后台/链路/生命周期/客户语义），采用方案 E——Flame 公共 API 全部保留，TB SelfRender 明确降级。`TbBannerAdapter` SelfRender load 分支：不创建任何 ToBid 对象，异步派发一次 `onAdError(14003, "当前聚合平台暂不支持开发者自渲染横幅广告")` + 统一日志 `[TB_SELF_RENDER_UNSUPPORTED]`（含 platform/mediation/sdkVersion/adFormat/renderMode/capability/action/message），`_selfRenderUnsupportedReported` 防刷屏，`_destroyed` 守卫阻断 destroy 后迟到回调；retrieveAdView/retrieveMaterials 返回 nil/空，bind/unbind/destroy 安全 no-op。Demo `SelfRenderBannerManager` 新增 `NonRetryableErrorCodes`（14003/14004/14002）平台无关短路，避免重试风暴，不判 pt。XCFramework 双 slice 构建成功，`TB_SELF_RENDER_UNSUPPORTED` 嵌入 `__TEXT/__ustring`（UTF-16，因含中文），未创建 TbNativeSelfRenderController/WindMillNativeAdsManager 直接使用。TB Demo 6 pods BUILD SUCCEEDED，TK 临时切 28 pods BUILD SUCCEEDED（AtBannerAdapter 不变），已恢复 TB。普通 Express Banner 完全隔离不受影响。后续升级条件：仅当 ToBid 提供对等的客户端 Banner Native Mix API 才重新评估。
