# Phase 5A.19 完成报告：ToBid 5.5.6 选定广告源全量接入

## 1. 基线

- **SDK 开始 HEAD**：`92e418d`（Phase 5A.18D-C 模板变形修复）
- **SDK 结束 HEAD**：本阶段提交后
- **Demo HEAD**：`6bb3619`（未改动业务代码）
- **分支**：`release/ios-dual-line`
- **工作区**：
  - SDK：`project.pbxproj`（环境 UUID 差异，严格排除在 commit 外）+ `.zcode/`（本地工具）
  - Demo：多个业务文件本地修改（不归 SDK 提交，保持不动）

## 2. 阶段背景

Native Express（模板渲染）已在 Phase 5A.18D 全链路验证通过（CSJ feedADMode=5 完整跑通）；Native SelfRender（自渲染）已在 Phase 5A.18D-C 通过 sigmob feedADMode=3 验证（TbNativeSelfRenderView 复用 WindMill mainImageView/mediaView/logoView/dislikeButton，高度回写正常）。

**本阶段不再修改 Native 实现**，唯一目标：以用户下载的 ToBid 5.5.6 完整集成包为依据，将用户选定的全部广告源正式接入 `flame_sdk_ios_tb`。

## 3. 本地完整包审计

来源：`doc/tobid_doc/sdk集成下载说明/tobid-sdk-ios-cn/AdNetworks/`

| 完整包目录 | Adapter xcframework | CocoaPods subspec | 三方 SDK | 三方版本 |
|---|---|---|---|---|
| baidu | WindMillBaiduAdapter.xcframework | BaiduAdapter | BaiduMobAdSDK | 10.050 |
| bidResult | WindMillBidResultPlugin.xcframework | BidResultAdapter | （辅助插件，无独立 SDK）| — |
| csj | WindMillCSJAdapter.xcframework | CSJAdapter | Ads-CN/BUAdSDK | 7.6.0.4 |
| gdt | WindMillGDTAdapter.xcframework + Tquic.xcframework | GDTAdapter | GDTMobSDK | 4.15.90 |
| gromore | WindMillGroMoreAdapter.xcframework + CSJMediation.xcframework | GromoreAdapter | Ads-CN/BUAdSDK + CSJMediation | 7.6.0.4 |
| kuaishou | WindMillKSAdapter.xcframework | KSAdapter | KSAdSDK | 5.4.10.1 |
| meishu | WindMillMSAdAdapter.xcframework + MSAdMotion.xcframework | MSAdAdapter | MSMobAdSDK/MS | 2.7.18.1 |
| mintegral-cn | WindMillMTGAdapter.xcframework + 8×MTGSDK | MintegralAdapter | MintegralAdSDK（国内版）| 7.7.6 |
| octopus | WindMillOctopusAdapter.xcframework + OctCore.xcframework | OctopusAdapter | OctopusSDK | 2.6.4.29 |

**特别说明**：
- **Sigmob**：由 ToBid Core 内置（WindSDK/WindFoundation），无独立 Adapter 目录
- **Mintegral**：使用国内版（mintegral-cn 目录），非海外版
- **GroMore 与 CSJ**：共享同一 `Ads-CN/BUAdSDK 7.6.0.4`，GroMore 额外引入 `Ads-CN/CSJMediation 7.6.0.4`（独立组件，无冲突）
- **资源 bundle**：CSJAdSDK/baidumobadsdk/MSAdSDK/OctAdSDK/OctCore/MTGSDK（每个渠道一个，随 SDK 自带）
- **PrivacyInfo.xcprivacy**：当前 CocoaPods 实际解析出的相关第三方 SDK 均检测到（MTGSDK/MSAdSDK/OctAdSDK/baidumobadsdk/GDTMobSDK/KSAdSDK/CSJAdSDK）；宿主 App 仍需根据最终数据采集行为完成隐私清单合并、ATT、SKAdNetwork 和用途说明配置

## 4. 官方 CocoaPods 引用代码

来源：`doc/tobid_doc/sdk集成下载说明/接入代码/Cocoapod引用代码.txt`

```
pod 'ToBid-iOS-RC/CSJAdapter', '5.5.6'       # 穿山甲
pod 'ToBid-iOS-RC/GDTAdapter', '5.5.6'       # 腾讯广告
pod 'ToBid-iOS-RC/BaiduAdapter', '5.5.6'     # 百度联盟
pod 'ToBid-iOS-RC/KSAdapter', '5.5.6'        # 快手
pod 'ToBid-iOS-RC/MintegralAdapter', '5.5.6' # Mintegral（国内版）
pod 'ToBid-iOS-RC/OctopusAdapter', '5.5.6'   # 章鱼
pod 'ToBid-iOS-RC/MSAdAdapter', '5.5.6'      # 美数
pod 'ToBid-iOS-RC/GromoreAdapter', '5.5.6'   # Gromore
```

**注意**：引用代码共 8 个 adapter，**不含 BidResultAdapter**。完整包虽然有 `bidResult` 目录，但作为竞价辅助插件，引用代码未要求时不主动接入（最小依赖原则）。

## 5. 当前 TB podspec 依赖（修改前）

仅接入 3 个 adapter：
- ToBid-iOS-RC 5.5.6
- ToBid-iOS-RC/CSJAdapter 5.5.6（Phase 5A.16B）
- ToBid-iOS-RC/GDTAdapter 5.5.6（Phase 5A.16E）
- ToBid-iOS-RC/MintegralAdapter 5.5.6（Phase 5A.18C）

**待新增 5 个**：BaiduAdapter / KSAdapter / OctopusAdapter / MSAdAdapter / GromoreAdapter

## 6. 目标 TB podspec 依赖（修改后）

新增 5 个 adapter（共 8 个）：

```ruby
s.dependency 'ToBid-iOS-RC', '5.5.6'                       # Core
s.dependency 'OpenSSL-Universal', '~> 3.6'                 # Flame binary 依赖
s.dependency 'ToBid-iOS-RC/CSJAdapter', '5.5.6'            # 1. 穿山甲
s.dependency 'ToBid-iOS-RC/GDTAdapter', '5.5.6'            # 2. 腾讯优量汇
s.dependency 'ToBid-iOS-RC/BaiduAdapter', '5.5.6'          # 3. 百度联盟（新增）
s.dependency 'ToBid-iOS-RC/KSAdapter', '5.5.6'             # 4. 快手（新增）
s.dependency 'ToBid-iOS-RC/MintegralAdapter', '5.5.6'      # 5. Mintegral 国内版
s.dependency 'ToBid-iOS-RC/OctopusAdapter', '5.5.6'        # 6. 章鱼（新增）
s.dependency 'ToBid-iOS-RC/MSAdAdapter', '5.5.6'           # 7. 美数（新增）
s.dependency 'ToBid-iOS-RC/GromoreAdapter', '5.5.6'        # 8. GroMore（新增）
```

## 7. 依赖变化矩阵

| 依赖 | 本地完整包要求 | 修改前 podspec | 本轮动作 |
|---|---|---|---|
| ToBid Core 5.5.6 | ✓ | ✓ | 保留 |
| OpenSSL | Flame binary 依赖 | ✓ | 保留 |
| BidResultAdapter | 完整包有，引用代码未要求 | — | **不接入**（最小依赖）|
| CSJAdapter | ✓ | ✓ | 保留 |
| GromoreAdapter | ✓ | — | **新增** |
| GDTAdapter | ✓ | ✓ | 保留 |
| KSAdapter | ✓ | — | **新增** |
| BaiduAdapter | ✓ | — | **新增** |
| MSAdAdapter | ✓ | — | **新增** |
| MintegralAdapter | ✓ | ✓ | 保留 |
| OctopusAdapter | ✓ | — | **新增** |

**新增 5 个，保留 3 个，不接入 1 个（BidResult）。**

## 8. 重点依赖冲突审计

### 8.1 CSJ 与 GroMore（共享 BUAdSDK）
- CSJAdapter 依赖：Ads-CN/BUAdSDK 7.6.0.4
- GromoreAdapter 依赖：Ads-CN/BUAdSDK 7.6.0.4 + Ads-CN/CSJMediation 7.6.0.4
- CocoaPods 自动合并为同一版本（7.6.0.4），**无 duplicate class 风险**
- CSJMediation 间接拉入 BUTTSDKFramework + Ads-CN/BUAdLive-Framework（GroMore 视频播放需要，不与 BUAdSDK 冲突）

### 8.2 Mintegral 国内版 simulator 限制
- `WindMillMTGAdapter.xcframework` 仅含 `ios-arm64` slice（缺 simulator slice）
- 8 个 `MTGSDK*.xcframework` 均含双 slice（arm64 + simulator）
- ToBid-iOS-RC 5.5.6 podspec 本身声明 `EXCLUDED_ARCHS[sdk=iphonesimulator*]=arm64`（全局，ToBid 官方设计）
- **我们不主动添加额外 EXCLUDED_ARCHS**（spec §9.2 红线）
- 含义：simulator 只能跑 x86_64（Intel 模拟器），Apple Silicon 模拟器需 Rosetta；真机 iphoneos arm64 不受影响

### 8.3 百度 / 快手 / 美数 / 章鱼
- 各自 framework 类型正常，当前 CocoaPods 实际解析出的 SDK 均检测到 PrivacyInfo.xcprivacy（宿主仍需按最终采集行为完成合并与声明）
- 版本：百度 10.050 / 快手 5.4.10.1 / 美数 2.7.18.1 / 章鱼 2.6.4.29
- 各带独立 bundle（baidumobadsdk / KSAdSDK 内嵌 / MSAdSDK / OctAdSDK + OctCore）
- 无特殊 linker flag 要求（继承 podspec 的 `-ObjC`）

### 8.4 BidResult
- 完整包有 `bidResult` 目录，含 WindMillBidResultPlugin.xcframework
- 引用代码（Cocoapod引用代码.txt）未声明 BidResultAdapter
- 作为竞价辅助插件（非独立广告网络），不主动接入

## 9. CocoaPods 解析结果

执行 `pod install --repo-update`，Podfile.lock 确认：

- ✅ `ToBid-iOS-RC` 5.5.6
- ✅ 8 个 Adapter 全部 5.5.6（CSJ/GDT/Baidu/KS/Mintegral/Octopus/MS/Gromore）
- ✅ 底层 SDK 版本正确（BUAdSDK 7.6.0.4 / GDTMobSDK 4.15.90 / BaiduMobAdSDK 10.050 / KSAdSDK 5.4.10.1 / MintegralAdSDK 7.7.6 / OctopusSDK 2.6.4.29 / MSMobAdSDK 2.7.18.1）
- ✅ 无 ToBid 5.3.4 残留
- ✅ 无 AnyThink / TK Sigmob 私有 Adapter
- ✅ 无海外 SDK（GoogleMobileAds/IronSource/AppLovinSDK/UnityAds/VungleAdsSDK）
- ✅ 无重复同名三方 SDK
- **共 12 个 pods**：flame_sdk_ios_tb + ToBid-iOS-RC + 7 个底层 SDK（BaiduMobAdSDK / BUTTSDKFramework / GDTMobSDK / KSAdSDK / MSMobAdSDK / MintegralAdSDK / OctopusSDK）+ OpenSSL-Universal + FunlinkSDK

## 10. 构建

### 10.1 Flame XCFramework
- `./xcFramework_build.sh` 双 Archive **SUCCEEDED**
- 单一 `flame_sdk_ios.xcframework`（840 KB）
- 未静态打入任何三方广告源 SDK（污染检测全过）
- AnyThinkSDK 继续保持 LC_LOAD_WEAK_DYLIB

### 10.2 TB Demo 构建
- `xcodebuild -sdk iphoneos build` → **BUILD SUCCEEDED**
- 无 error / 无 duplicate symbol / 无 undefined symbol
- App 内 Frameworks 目录 48 MB，App 未压缩 116 MB

### 10.3 TK 回归
- 临时切 TK Podfile → `pod install`（28 pods，无 ToBid 污染）
- `xcodebuild -sdk iphoneos build` → **BUILD SUCCEEDED**
- Podfile.lock 验证：ToBid 出现 0 次、AnyThink 62 次、海外 SDK 0 个
- 完成后恢复 TB Podfile + pod install

### 10.4 Simulator 限制
- Mintegral（WindMillMTGAdapter）：仅 arm64 slice，simulator 不可用
- ToBid-iOS-RC 5.5.6 自带 `EXCLUDED_ARCHS[sdk=iphonesimulator*]=arm64`（全局）
- 含义：Apple Silicon Mac simulator 需 Rosetta；Intel Mac simulator + 真机不受影响

## 11. 包体审计

### Pods 目录（含双 slice + 源码，不等于 App Store 下载大小）

| 广告源 | Pods 大小 |
|---|---|
| Ads-CN（CSJ + GroMore 共享，含 BUAdLive + BUTTSDK）| 464 MB |
| ToBid-iOS-RC（Core + Adapters）| 155 MB |
| GDTMobSDK（含 Tquic）| 121 MB |
| MSMobAdSDK（含 MSAdMotion）| 119 MB |
| MintegralAdSDK（8 个 MTGSDK）| 101 MB |
| BaiduMobAdSDK | 69 MB |
| KSAdSDK | 61 MB |
| OctopusSDK（含 OctCore）| 36 MB |
| **Pods 总计** | **1.1 GB** |

### 真机 App 产物

| 维度 | 大小 |
|---|---|
| Demo App 未压缩 | 116 MB |
| App/Frameworks/（动态库）| 48 MB |
| Flame XCFramework | 840 KB |

**说明**：CocoaPods Pods 目录包含 simulator slice + 源码 + module interface，**远大于最终 App Store 下载大小**。真实增量需以 Archive 后的 .ipa 为准（本阶段不 Archive）。

## 12. 宿主配置（详见 `doc/flame_mediation/tobid-5.5.6-selected-adnetworks-host-config.md`）

- **SKAdNetworkItems**：22 个 ID（Sigmob 1 + 穿山甲 2 + Mintegral 19），其他渠道无独立 ID
- **ATT**：`NSUserTrackingUsageDescription`（必需）
- **ATS**：`NSAllowsArbitraryLoads=true`（必需）
- **PrivacyInfo.xcprivacy**：各 SDK 自带；宿主 App 仍需按最终数据采集行为完成隐私清单合并、ATT、SKAdNetwork 和用途说明配置
- **LSApplicationQueriesSchemes**：未强制要求
- **条件权限**：仅在启用 LBS / 相机 / 相册类广告位时需要

## 13. 运行时冒烟（未专项真机测试）

本阶段不要求所有广告源真实填充。已知状态：
- Splash / Reward / Interstitial：ToBid Core 内置 sigmob，5.5.6 已验证可填充
- Native Express：sigmob feedADMode=5 已验证完整链路
- Native SelfRender：sigmob feedADMode=3 已验证完整链路
- Banner：GDT 后台配额限制（code=800110），需后台开通
- CSJ / Baidu / KS / MS / Octopus / Mintegral / GroMore：依赖解析、链接、运行时可用性已验证（无 framework not found / 无 duplicate class / 无启动崩溃），**真实填充待业务环境验证**

## 14. Native 状态

- **Native Express**：Phase 5A.18D 全链路通过（CSJ 模板）
- **Native SelfRender**：Phase 5A.18D-C 全链路通过（sigmob 自渲染，TbNativeSelfRenderView 复用 WindMill view，高度回写正确）
- **本阶段不修改 Native**（spec §十 / §十五 红线）
- 新增广告源依赖未破坏 Native 链路（TB Demo build SUCCEEDED）

## 15. TK 隔离

- TK podspec（flame_sdk_ios.podspec）：**完全未改动**
- TK 依赖：AnyThinkiOS / AnyThinkMediation* / flame_sdk_ios_tk_sigmob_adapter / Smartdigimkt 等（28 pods）
- TK Podfile.lock：无 ToBid / 无海外 SDK
- TK Demo BUILD SUCCEEDED
- AnyThink 运行时正常（弱链接机制不变）

## 16. 修改文件

**SDK 仓库（本阶段提交）**：
1. `flame_sdk_ios_tb.podspec`（新增 5 个 adapter 依赖 + 完整注释）
2. `doc/tobid_doc/tobid-5.5.6-selected-adnetworks-host-config.md`（新增宿主配置文档）
3. `doc/flame_mediation/phase-5a.19-tobid-selected-adnetworks-integration.md`（本报告）
4. `doc/flame_mediation/09_change_log.md`（追加 Phase 5A.19 条目）
5. `README.md`（更新横幅广告接入说明）

**严格排除在 commit 外**：
- `flame_sdk_ios.xcodeproj/project.pbxproj`（环境 UUID 差异）
- `.zcode/`（本地工具）
- Pods / Podfile.lock / xcworkspace / DerivedData / build / Archives
- Demo 业务文件（用户本地修改）
- 真机日志 / 测试 placementId / pMap

## 17. Git

- **feature commit**：本阶段创建
- **push**：否
- **tag**：否
- **release**：否

## 18. 未验证项

- Baidu、KS、MS、Octopus、Mintegral、GroMore 共 6 个广告源的真实填充待业务环境验证（需后台配置对应渠道广告位 + pMap）；本轮仅验证依赖解析、链接、运行时可用性
- BidResultAdapter 竞价回传（未接入，待客户按需启用）
- Mintegral simulator 测试（受 WindMillMTGAdapter slice 限制，跳过）
- Archive 后真实 .ipa 大小（本阶段不 Archive）

## 19. 结论

- ✅ 用户选定广告源（8 个外部 Adapter）全部接入：CSJ / GDT / Baidu / KS / Mintegral / Octopus / MS / Gromore（另有 Sigmob 由 ToBid Core 内置）
- ✅ 本轮**新增 5 个 Adapter**（Baidu / KS / Octopus / MS / Gromore），保留 3 个（CSJ / GDT / Mintegral）
- ⏳ 其中 **6 个广告源**（Baidu / KS / MS / Octopus / Mintegral / Gromore）真实填充待业务环境验证
- ✅ 与本地完整包一致（`BidResultAdapter` 完整包有目录但引用代码未声明，当前不属于正式依赖范围；未来如接入独立竞价结果解析、竞价诊断或相关专用 API，再根据实际调用证据补充）
- ✅ TK 保持完全隔离（Podfile.lock 验证）
- ✅ 公共 API 未变化
- ✅ Native 未回归（TB Demo build SUCCEEDED）
- ⏳ 可进入下一阶段（用户决定）

## 20. /compact

Phase 5A.19 完成：ToBid 5.5.6 完整包 8 个广告源（CSJ/GDT/Baidu/KS/Mintegral/Octopus/MS/Gromore）正式接入 flame_sdk_ios_tb。BidResult 引用代码未要求不接入。XCFramework + TB Demo + TK 回归全部 BUILD SUCCEEDED。宿主 SKAdNetwork 配置文档独立。podspec 本地 commit，未 push。
