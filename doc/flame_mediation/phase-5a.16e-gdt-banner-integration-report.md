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
| GDT Banner 真实填充 | ❌ 待用户后台配置 + 真机 Run |
| 公共 API 是否变化 | ❌ 未变 |
| Demo 调用方式是否变化 | ❌ 未变 |

---

## 12. 下一步

**Phase 5A.16E 静态接入完成。等用户完成腾讯广告 + ToBid + Flame pMap 后台配置后，真机 Run 验证 GDT Banner 成功路径。**

- 不修改 TbBannerAdapter
- 不修改公共 API
- 不接入其他广告源
- 不 push、不 tag、不发布

---

## 13. /compact

Phase 5A.16E 静态接入完成：`flame_sdk_ios_tb.podspec` 加 `ToBid-iOS-RC/GDTAdapter 5.5.6`（腾讯优量汇），TB 同时含 CSJ+GDT。GDTAdapter subspec 拉取 `GDTMobSDK 4.15.90`+`WindMillGDTAdapter.xcframework`，无 AnyThink 泄漏，与 TK AnyThinkMediationGDTAdapter 同版本无冲突。TB clean pod install 6 pods（+GDTMobSDK），iphoneos BUILD SUCCEEDED，GDT artifacts（GDTMobSDK+Tquic+WindMillGDTAdapter+PrivacyInfo）齐备。TK 28 pods BUILD SUCCEEDED 不引入 ToBid GDTAdapter。CSJ 官方测试位 no-fill 不阻塞 GDT 验证。等用户后台配置（腾讯广告位+ToBid 聚合位+Flame pMap）后真机 Run 验证 GDT Banner 成功路径。不修改 TbBannerAdapter/公共 API/Demo，未 push/tag/release。
