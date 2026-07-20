# Phase 5A.16E：ToBid 腾讯优量汇 GDT Adapter 接入与 Banner 真机验证

> **本阶段性质**：在 `flame_sdk_ios_tb.podspec` 增加 GDT Adapter 依赖（不修改 TbBannerAdapter，不修改公共 API）。CSJ 官方测试位 no-fill 后（Phase 5A.16D），接入腾讯 GDT 作为用户自有 Banner 广告源。
>
> **状态**：静态接入完成，等用户后台配置（腾讯广告 + ToBid + Flame pMap）后真机验证。

---

## 1. 基线

| 项 | 值 |
|---|---|
| SDK 开始 HEAD | `39bc191`（Phase 5A.16D CSJ no-fill 文档） |
| SDK 结束 HEAD | 本阶段 commit（见 §28） |
| Demo HEAD | `11c5958`（Demo 代码零改动） |
| 接入前 TB Podfile.lock | 5 pods（CSJAdapter 已在 5A.16B 接入） |
| 接入后 TB Podfile.lock | 6 pods（+GDTMobSDK 4.15.90） |

---

## 2. CSJ 16D 暂停状态

Phase 5A.16D 已记录 CSJ 官方测试位 no-fill（commit `39bc191`）：
- 链路与 Adapter 实现全部验证正确
- ToBid 官方测试位 `7316148691848522`（穿山甲_横幅广告_模版渲染）当前 no-fill（800110/20001）
- 尺寸已排除根因（402×50 和 320×50 均失败）
- 成功路径未验证

详见 `phase-5a.16d-csj-banner-device-validation-report.md`。

---

## 3. GDTAdapter subspec 审计（§五）

从 `/Users/khj/.cocoapods/repos/trunk/Specs/5/6/4/ToBid-iOS-RC/5.5.6/ToBid-iOS-RC.podspec.json` 确认：

```json
{
  "name": "GDTAdapter",
  "platforms": { "ios": "11.0" },
  "vendored_frameworks": "tobid-sdk-ios-cocoapods-cn/AdNetworks/gdt/*.xcframework",
  "preserve_paths": "tobid-sdk-ios-cocoapods-cn/AdNetworks/gdt/**/*",
  "dependencies": {
    "GDTMobSDK": ["4.15.90"],
    "ToBid-iOS-RC/ToBidSDK": []
  }
}
```

| 项 | 值 |
|---|---|
| 准确 subspec 名称 | `ToBid-iOS-RC/GDTAdapter` ✅ |
| Adapter 版本 | 5.5.6 |
| 底层腾讯 SDK | `GDTMobSDK 4.15.90` |
| 最低 iOS | 11.0（Flame 13.0，兼容） |
| vendored framework | `WindMillGDTAdapter.xcframework`（arm64 + arm64_x86_64-simulator） |
| GDTMobSDK slices | arm64 + x86_64-simulator |
| PrivacyInfo.xcprivacy | ✅ GDTMobSDK.framework 两 slice 均含 |
| 冲突 | ❌ 无（GDTMobSDK 4.15.90 与 TK AnyThinkMediationGDTAdapter 同版本） |

---

## 4. podspec 修改（§六）

`flame_sdk_ios_tb.podspec` 新增 1 依赖：

```ruby
# --- Phase 5A.16E：腾讯优量汇（GDT）广告源 ---
s.dependency 'ToBid-iOS-RC/GDTAdapter', '5.5.6'
```

| 约束 | 状态 |
|---|---|
| 不修改 TbBannerAdapter | ✅ |
| 不修改 Flame Banner 公共 API | ✅ |
| 不修改 Demo | ✅ |
| 不修改 flame_sdk_ios.podspec (TK) | ✅ |
| 不删除 CSJAdapter | ✅（TB 同时含 CSJ + GDT） |
| 不重复声明 GDTMobSDK | ✅（由 ToBid 官方 subspec 管理） |

---

## 5. 依赖树（§七）

TB Podfile.lock PODS 段：

```
- Ads-CN/BUAdSDK (7.6.0.4)                    [CSJ]
- flame_sdk_ios_tb (1.0.0-alpha.4-local):
  - OpenSSL-Universal (~> 3.6)
  - ToBid-iOS-RC (= 5.5.6)
  - ToBid-iOS-RC/CSJAdapter (= 5.5.6)
  - ToBid-iOS-RC/GDTAdapter (= 5.5.6)         [NEW]
- GDTMobSDK (4.15.90)                          [NEW]
- OpenSSL-Universal (3.6.2000)
- ToBid-iOS-RC (5.5.6):
  - ToBid-iOS-RC/ToBidSDK (= 5.5.6)
- ToBid-iOS-RC/CSJAdapter (5.5.6):
  - Ads-CN/BUAdSDK (= 7.6.0.4)
  - ToBid-iOS-RC/ToBidSDK
- ToBid-iOS-RC/GDTAdapter (5.5.6):             [NEW]
  - GDTMobSDK (= 4.15.90)
  - ToBid-iOS-RC/ToBidSDK
- ToBid-iOS-RC/ToBidSDK (5.5.6)
```

**6 pods（5→6，+GDTMobSDK）**。无 AnyThink / TK adapter / SigmobAd-iOS。

---

## 6. 静态产物审计（§八）

| 产物 | 存在 |
|---|---|
| `WindMillGDTAdapter.xcframework` | ✅（arm64 + arm64_x86_64-simulator） |
| `GDTMobSDK.xcframework` | ✅（arm64 + x86_64-simulator） |
| `Tquic.xcframework` | ✅（GDTMobSDK 传递依赖） |
| `GDTMobSDK.framework/PrivacyInfo.xcprivacy` | ✅（两 slice） |
| AnyThinkSDK | ❌ ABSENT ✓ |
| 重复 framework | ❌ 无 |

---

## 7. 构建验证（§九）

| 检查 | 结果 |
|---|---|
| TB iphoneos BUILD | ✅ **SUCCEEDED** |
| error / duplicate symbols | 0 |
| TB simulator BUILD | ⚠️ pre-existing Flame xcframework 缺 arm64 sim slice（与 GDT 无关） |

---

## 8. TK 回归（§十）

| 检查 | 结果 |
|---|---|
| TK clean pod install | ✅ 28 pods |
| `ToBid-iOS-RC/GDTAdapter`（应 ABSENT） | ✅ ABSENT（TK 不拉 TB 的 GDTAdapter） |
| `ToBid-iOS-RC/CSJAdapter`（应 ABSENT） | ✅ ABSENT |
| GDTMobSDK 4.15.90 | ✅ 存在（via TK AnyThinkMediationGDTAdapter，同版本同 pod，无冲突） |
| TK iphoneos BUILD | ✅ **BUILD SUCCEEDED** |
| Demo 恢复 TB | ✅ 6 pods |

---

## 9. 待用户后台配置（§十一/十三）

进入真机验证前需完成：

### 腾讯广告后台
- iOS 应用注册（Bundle ID 匹配 Demo）
- Banner 广告位创建（类型=Banner，尺寸=320×50）
- 广告位 ID（用户腾讯广告位，不是 `q71507861622`——后者是 Flame 对外 ID）
- 测试设备/测试模式

### ToBid 后台
- 启用腾讯广告渠道
- 填写腾讯应用参数
- 创建用户自己的 Banner 聚合广告位
- waterfall 加入腾讯 Banner 广告位（首次验证建议只启用腾讯）
- 尺寸/刷新策略与客户端一致

### Flame 后台
- `q<REDACTED>`（Flame 对外 Banner ID）对应 pt=tb
- pMap.banner 映射到用户自己的 ToBid Banner 聚合 placementId
- 不映射腾讯原始 network placementId
- 不继续使用 CSJ 官方测试位 `7316148691848522`

---

## 10. 真机验证计划（§十三/十四，等后台配置）

用户后台配置完成后，真机 Run（Demo `banner = q<REDACTED>`，pMap 映射到用户 ToBid Banner 聚合位）：

### 必须证明
1. Demo 使用 Flame 对外 ID
2. TbBannerAdapter 获得映射后的 ToBid placementId
3. ToBid 选择腾讯广告源（networkName/networkId/Adapter 类/GDT SDK 回调）
4. GDT Adapter 初始化成功
5. 腾讯 Banner 请求真实发出

### 成功路径
```
load → GDT source → load success → didLoadSuccess → onAdLoaded
→ retrieveAdView → addSubview → exposure → onAdShow
→ refresh（至少一次，复用同一 WindMillBannerView）
→ destroy → re-enter
```

---

## 11. 结论（阶段性）

| 项 | 结果 |
|---|---|
| GDT Adapter 依赖接入 | ✅ |
| TB 构建 | ✅ SUCCEEDED |
| TK 回归 | ✅ 无 GDTAdapter 泄漏 |
| AnyThink 隔离 | ✅ |
| GDT Banner 真实填充 | ✅ 详见 §14 真机验证 |
| 公共 API 是否变化 | ❌ 未变 |
| Demo 调用方式是否变化 | ❌ 未变 |

---

## 12. 下一步

**Phase 5A.16E 真机验证完成（§14）。** 普通 Banner 首次成功展示链路成立。剩余可选验证（自动刷新 / 点击落地页 / destroy 后 re-enter）如未在 Run 中触发，标为「未专项验证」，不影响本阶段结论。

- 不修改 TbBannerAdapter
- 不修改公共 API
- 不接入其他广告源
- 不 push、不 tag、不发布

---

## 13. /compact

Phase 5A.16E 完成：`flame_sdk_ios_tb.podspec` 加 `ToBid-iOS-RC/GDTAdapter 5.5.6`（腾讯优量汇），TB 同时含 CSJ+GDT。GDTAdapter subspec 拉取 `GDTMobSDK 4.15.90`+`WindMillGDTAdapter.xcframework`，无 AnyThink 泄漏。TB clean pod install 6 pods，iphoneos BUILD SUCCEEDED。真机验证：GDT Banner 真实填充成功（load→GDT source→didLoadSuccess→retrieveAdView→addSubview→exposure→onAdShow），WindMillBannerView 返回 402×50 全宽。TK/TB 坐标审计（§15）：container/adView/子 View 几何完全一致，intersectionHeight=0，无重叠无裁切，视觉差异仅为素材模板排版不同。CSJ 官方测试位 no-fill 不阻塞 GDT 验证（成功路径未专项验证）。不修改 TbBannerAdapter/公共 API/Demo 业务布局，未 push/tag/release。

---

## 14. 真机验证（2026-07-20 完成）

### 14.1 验证环境

| 项 | 值 |
|---|---|
| 设备 | 真机（402pt 宽屏） |
| 平台 | TB（`flame_sdk_ios_tb`） |
| Flame appId | `b22375234108`（ToBid 测试应用） |
| Flame Banner placementId（对外） | `q71507861622`（腾讯横幅广告位，用户自有） |
| pMap 映射 | Flame `q71507861622` → ToBid 聚合位 `1261219727399929` → GDT 网络 `1080958885885321` |
| TbBannerAdapter | Phase 5A.16C 实现，本轮未改 |
| Flame 公共 API | 未变化 |
| Demo 调用方式 | 未变化 |

### 14.2 成功链路验证

```
load
 → ToBid 选择 GDT 源（networkId=16, networkName="gdt"）
 → WindMillGDTAdapter 初始化
 → GDTUnifiedBannerView 加载
 → bannerAdViewLoadSuccess:（didLoadSuccess）
 → TbBannerAdapter 设置 frame = adSize（402×50）
 → onAdLoaded
 → Demo 延迟 100ms retrieveAdView()
 → Demo addSubview + 4 边约束
 → bannerAdViewWillExpose: → onAdShow
```

**普通 Banner 首次成功展示链路通过 ✅**。

### 14.3 真实返回尺寸

| 项 | 值 |
|---|---|
| Demo 请求尺寸（load width × height） | 402 × 50（屏幕宽度 × 50） |
| `WindMillBannerView.adSize`（ToBid 返回） | **402 × 50**（全宽，非 320×50） |
| `GDTUnifiedBannerView` 内部子 View bounds | 402 × 50（填满外层） |

> **重要修正**：此前（Phase 5A.16D CSJ 诊断期间）曾一度认为 ToBid Banner 返回 320×50。**真机坐标审计证明 WindMillBannerView 实际返回 402×50 全宽**，GDT 内部子 View 也填满 402×50，无侧边距。

### 14.4 未专项验证（可选）

以下未在本轮 Run 中专门触发，不影响「首次成功展示链路」成立：

- 自动刷新（`bannerAdViewDidAutoRefresh:`）：本轮日志窗口内未观察到周期刷新回调。
- 点击落地页（`bannerAdViewDidClicked:` → `willOpenFullScreen`）：未专项触发。
- destroy 后重新进入（re-enter）：未专项触发。

这些不阻塞 Phase 5A.16E 结论。

---

## 15. TK/TB 底部 Express Banner 坐标审计（2026-07-20）

### 15.1 审计目的

对比 TK（ATBannerView）与 TB（WindMillBannerView）在同一设备、同一页面、同一布局逻辑下的底部 Express Banner 几何参数，判断是否存在：

- A. Banner 与 TabBar 几何重叠（intersection > 0）
- B. 内容被裁切（子 View 越界 / clipsToBounds）
- C. TK/TB container frame 不一致
- D. container 一致但 adView frame 不一致

### 15.2 审计方法

临时注入只读诊断工具 `BannerLayoutDiag`（不修改任何 View 的 frame / constraints / 属性，TK/TB 共用同一逻辑），在 4 个时机各采样一次：

1. `retrieveAdView` 返回后
2. `addSubview` + 4 边约束完成后
3. `layoutIfNeeded` 后
4. 曝光回调时（`onAdShow`）

记录 screenFrame / safeAreaInsets / containerFrameInWindow / adViewFrameInWindow / adViewBounds / clips / superview / 子 View bounds / constraints / tabBarFrameInWindow / intersection / intersectionHeight。

> **审计工具属于临时 instrumentation，验证完成后已从 Demo 移除，不提交。**

### 15.3 最终态对比（取 `on_expose` 阶段）

| 字段 | TK（ATBannerView） | TB（WindMillBannerView） | 一致 |
|---|---|---|---|
| screenFrame | `{0,0,402,874}` | `{0,0,402,874}` | ✅ |
| safeAreaInsets | `{t=62,l=0,b=34,r=0}` | `{t=62,l=0,b=34,r=0}` | ✅ |
| **containerFrameInWindow** | `{0,741,402,50}` | `{0,741,402,50}` | ✅ |
| **adViewFrameInWindow** | `{0,741,402,50}` | `{0,741,402,50}` | ✅ |
| **adViewBounds** | `{0,0,402,50}` | `{0,0,402,50}` | ✅ |
| containerClips | `false` | `false` | ✅ |
| adViewClips | `true` | `false` | ⚠️ 差异（无害） |
| 内部子 View bounds | `[UIView {0,0,402,50}]` | `[GDTUnifiedBannerView {0,0,402,50}]` | ✅ 都填满 |
| adViewZPosition | `0.00` | `0.00` | ✅ |
| adViewSuperview | SwiftUI 容器（UIView） | SwiftUI 容器（UIView） | ✅ |
| **tabBarFrameInWindow** | `{0,791,402,83}` | `{0,791,402,83}` | ✅ |
| **intersection** | `{0,791,402,0}` | `{0,791,402,0}` | ✅ |
| **intersectionHeight** | **`0.0`** | **`0.0`** | ✅ |

### 15.4 判断结论

- **A 类（intersection > 0）**：❌ 不成立。两侧 `intersectionHeight = 0`，Container 底边 791 == TabBar 顶边 791，完美贴边，零重叠。
- **B 类（intersection=0 但裁切）**：❌ 不成立。两侧子 View bounds = 外层 bounds，未越界；adSize 均 402×50；内容高度 50pt == 容器高度 50pt，无压缩。
- **C 类（container frame 不一致）**：❌ 不成立。两侧 `{0,741,402,50}` 完全相同。
- **D 类（adView frame 不一致）**：❌ 不成立。两侧 adView `{0,741,402,50}` 完全相同。

**唯一差异**：`adViewClips`（TK=true / TB=false）。这是底层 SDK（ATBannerView vs WindMillBannerView）自身设置，子 View 未越界，裁与不裁视觉无差别。

### 15.5 最终结论

**TK/TB 底部 Express Banner 几何布局完全一致，无重叠、无裁切。当前布局（`.overlay` + `.frame(height:50)` + `.padding(.bottom,49)` + 4 边 AutoLayout 约束）对 TK 和 TB 均正确，保持原状，不做任何修改。**

不同广告源素材模板（如 GDT "捕鱼大作战狂暴版"双行密排 vs TK "疯狂水世界"单行疏排）造成的视觉密度差异，属于素材本身特性，不属于布局缺陷。

### 15.6 错误判断修正（历史纠偏）

此前基于截图推断的以下判断，经真机坐标审计证明**错误**，予以撤销：

- ❌ "TB Banner 只有 320×50，两侧留白" → 实际 402×50 全宽
- ❌ "TB Banner 与 TabBar 重叠" → 实际 intersectionHeight=0
- ❌ "需要修改底部布局 / safeAreaInset / bottom padding" → 几何无问题，不需要改

**真机坐标证据优先于截图推断。**

---

## 16. 提交策略

| 仓库 | commit | 内容 |
|---|---|---|
| SDK | `5414cf5`（已存在） | `build: add ToBid GDT adapter dependency`（§3-§9 静态接入） |
| SDK | 本轮新增 | `test: validate GDT banner on device`（§14-§15 真机验证 + 坐标审计报告） |
| Demo | 无 commit | 本轮无业务布局修复，临时诊断工具 / TK 测试配置 / activeVariant 重构全部清理，Demo 仅剩用户原有改动 |

**严格排除提交**：BannerLayoutDiag.swift、临时诊断日志、测试 placementId、TK 测试配置、Demo activeVariant 重构、Pods、Podfile.lock、xcworkspace、build、DerivedData、project.pbxproj 无关环境差异。

不 push、不 tag、不发布、不修改远程 specs。
