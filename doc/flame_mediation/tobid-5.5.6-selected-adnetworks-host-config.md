# ToBid 5.5.6 选定广告源宿主 App 配置说明

**阶段**：Phase 5A.19
**适用范围**：Flame SDK `flame_sdk_ios_tb` 客户（接入 8 个广告源）
**数据来源**：`doc/tobid_doc/sdk集成下载说明/接入代码/SkAdneworkIDs代码.txt`（ToBid 官方）

## 一、本次接入的广告源

按 `Cocoapod引用代码.txt`（ToBid 官方）声明的 8 个 Adapter：

| 广告源 | subspec | 底层 SDK | 版本 |
|---|---|---|---|
| 穿山甲（CSJ） | `ToBid-iOS-RC/CSJAdapter` | Ads-CN/BUAdSDK | 7.6.0.4 |
| 腾讯优量汇（GDT） | `ToBid-iOS-RC/GDTAdapter` | GDTMobSDK | 4.15.90 |
| 百度联盟 | `ToBid-iOS-RC/BaiduAdapter` | BaiduMobAdSDK | 10.050 |
| 快手 | `ToBid-iOS-RC/KSAdapter` | KSAdSDK | 5.4.10.1 |
| Mintegral（国内版） | `ToBid-iOS-RC/MintegralAdapter` | MintegralAdSDK | 7.7.6 |
| 章鱼 | `ToBid-iOS-RC/OctopusAdapter` | OctopusSDK | 2.6.4.29 |
| 美数 | `ToBid-iOS-RC/MSAdAdapter` | MSMobAdSDK/MS | 2.7.18.1 |
| GroMore | `ToBid-iOS-RC/GromoreAdapter` | Ads-CN/BUAdSDK + CSJMediation | 7.6.0.4 |

加上 ToBid Core 自带的 **Sigmob（WindSDK 内置）**，共 9 个广告源需要宿主 App 配置 SKAdNetwork。

**未接入**：
- `BidResultAdapter`（辅助插件，引用代码未声明，最小依赖原则不主动接入）

## 二、SKAdNetworkItems 完整 plist 片段

> ⚠️ **准确表述**：SKAdNetwork 用于归因配置。缺失会降低 iOS 14.5+ 设备的归因准确性，**不一定必然导致 no-fill**，但建议完整配置以保证 eCPM 和填充率。

按 `SkAdneworkIDs代码.txt` 原始声明（已去重 + 全小写 + 格式校验）：

```xml
<key>SKAdNetworkItems</key>
<array>
    <!-- Sigmob（ToBid Core 内置） -->
    <dict>
        <key>SKAdNetworkIdentifier</key>
        <string>58922nb4gd.skadnetwork</string>
    </dict>
    <!-- 穿山甲（CSJ/GroMore 共享） -->
    <dict>
        <key>SKAdNetworkIdentifier</key>
        <string>238da6jt44.skadnetwork</string>
    </dict>
    <dict>
        <key>SKAdNetworkIdentifier</key>
        <string>22mmun2rn5.skadnetwork</string>
    </dict>
    <!-- Mintegral -->
    <dict>
        <key>SKAdNetworkIdentifier</key>
        <string>kbd757ywx3.skadnetwork</string>
    </dict>
    <dict>
        <key>SKAdNetworkIdentifier</key>
        <string>wg4vff78zm.skadnetwork</string>
    </dict>
    <dict>
        <key>SKAdNetworkIdentifier</key>
        <string>737z793b9f.skadnetwork</string>
    </dict>
    <dict>
        <key>SKAdNetworkIdentifier</key>
        <string>ydx93a7ass.skadnetwork</string>
    </dict>
    <dict>
        <key>SKAdNetworkIdentifier</key>
        <string>prcb7njmu6.skadnetwork</string>
    </dict>
    <dict>
        <key>SKAdNetworkIdentifier</key>
        <string>7ug5zh24hu.skadnetwork</string>
    </dict>
    <dict>
        <key>SKAdNetworkIdentifier</key>
        <string>44jx6755aq.skadnetwork</string>
    </dict>
    <dict>
        <key>SKAdNetworkIdentifier</key>
        <string>2u9pt9hc89.skadnetwork</string>
    </dict>
    <dict>
        <key>SKAdNetworkIdentifier</key>
        <string>w9q455wk68.skadnetwork</string>
    </dict>
    <dict>
        <key>SKAdNetworkIdentifier</key>
        <string>yclnxrl5pm.skadnetwork</string>
    </dict>
    <dict>
        <key>SKAdNetworkIdentifier</key>
        <string>tl55sbb4fm.skadnetwork</string>
    </dict>
    <dict>
        <key>SKAdNetworkIdentifier</key>
        <string>8s468mfl3y.skadnetwork</string>
    </dict>
    <dict>
        <key>SKAdNetworkIdentifier</key>
        <string>glqzh8vgby.skadnetwork</string>
    </dict>
    <dict>
        <key>SKAdNetworkIdentifier</key>
        <string>c6k4g5qg8m.skadnetwork</string>
    </dict>
    <dict>
        <key>SKAdNetworkIdentifier</key>
        <string>mlmmfzh3r3.skadnetwork</string>
    </dict>
    <dict>
        <key>SKAdNetworkIdentifier</key>
        <string>4pfyvq9l8r.skadnetwork</string>
    </dict>
    <dict>
        <key>SKAdNetworkIdentifier</key>
        <string>av6w8kgt66.skadnetwork</string>
    </dict>
    <dict>
        <key>SKAdNetworkIdentifier</key>
        <string>6xzpu9s2p8.skadnetwork</string>
    </dict>
    <dict>
        <key>SKAdNetworkIdentifier</key>
        <string>hs6bdukanm.skadnetwork</string>
    </dict>
</array>
```

**ID 来源对照（共 22 个，去重后）**：

| 渠道 | ID 数量 | ID 列表 |
|---|---|---|
| Sigmob | 1 | `58922nb4gd` |
| 穿山甲（CSJ + GroMore 共享）| 2 | `238da6jt44`, `22mmun2rn5` |
| Mintegral | 19 | 见上 plist |

**其他广告源（百度/快手/GDT/章鱼/美数）**：`SkAdneworkIDs代码.txt` 未提供独立 ID。这些渠道目前不要求独立 SKAdNetwork 配置（部分渠道通过 Apple 通用归因，或 ToBid 内部统一上报）。

## 三、ATT（App Tracking Transparency）

iOS 14.5+ 必需：

```xml
<key>NSUserTrackingUsageDescription</key>
<string>我们需要您的许可来提供更相关的广告内容。</string>
```

**ATT 弹窗触发**：App 启动时主动调用 `ATTrackingManager.requestTrackingAuthorization`，建议在 Flame SDK 初始化前调用（未获授权时 eCPM 会显著降低）。

**Flame SDK 不内置 ATT 弹窗**，由宿主 App 负责（App Tracking Transparency 是 Apple 对宿主的要求，不属于 SDK 行为）。

## 四、LSApplicationQueriesSchemes

`SkAdneworkIDs代码.txt` 未要求。ToBid 5.5.6 集成说明未强制 schemes 配置。客户按需添加（如需 deeplink 跳转淘宝/京东等第三方 App）。

## 五、网络权限

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
</dict>
```

部分广告渠道（百度/GDT）使用 http 上报，需要 ATS 放开。

## 六、条件权限（仅在启用对应功能时需要）

| 权限 | 用途 | 何时需要 |
|---|---|---|
| `NSCameraUsageDescription` | 拍摄类广告互动 | 仅部分互动广告素材 |
| `NSPhotoLibraryUsageDescription` | 下载类广告保存图片 | 仅"保存到相册"类广告 |
| `NSLocationWhenInUseUsageDescription` | LBS 定向广告 | 仅定位类广告位 |
| `NSMicrophoneUsageDescription` | 视频录制互动 | 仅视频类互动广告 |
| `NSCalendarsUsageDescription` | 日历提醒类广告 | 仅日历类广告 |

**默认接入不需要上述权限**，只在客户后台开通对应广告位类型时才需要添加。

## 七、客户集成责任

Flame SDK（`flame_sdk_ios_tb`）通过 CocoaPods 接入后，**客户 App 仍需自行配置**：

1. **Info.plist 加 SKAdNetworkItems**（复制上面 22 个 ID）
2. **Info.plist 加 NSUserTrackingUsageDescription**
3. **App 启动调用 ATT 弹窗**（Flame SDK 不内置）
4. **按开通的广告位类型加条件权限**（如 LBS 广告位加定位权限）
5. **App Store Connect 隐私问卷**按实际数据采集情况填写

**Flame SDK 不负责**：
- 修改客户 Info.plist（避免覆盖客户自有配置）
- 调用 ATT 弹窗（Apple 政策要求宿主 App 负责）
- App Store Connect 隐私问卷（按宿主实际采集情况）
