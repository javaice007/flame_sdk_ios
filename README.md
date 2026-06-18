# FlameSDK iOS 对接说明

> **版本**：`1.0.0-alpha.1`（Thin Core Alpha）
> **架构**：方案 D — 两个对外 podspec + 一个内部 core binary
> **最后更新**：2026-06-18

---

## 概览

| 项目 | 内容 |
|------|------|
| SDK 版本 | `1.0.0-alpha.1` |
| 最低部署版本 | iOS 13.0 |
| 语言 | Objective-C（Swift 通过 import 调用） |
| 集成方式 | CocoaPods |
| Pod 源 | `https://github.com/javaice007/flame-specs.git` |

Flame SDK 提供两个互斥的 pod，**客户只接入一个**：

| 客户类型 | Podfile 写法 | 适用场景 |
|---------|-------------|---------|
| TK 客户（TopOn / AnyThink 聚合） | `pod 'flame_sdk_ios', '1.0.0-alpha.1'` | 默认场景，含 AnyThink + 全 Mediation + AdGain + 飞梭 |
| TB 客户（ToBid / WindMill） | `pod 'flame_sdk_ios_tb', '1.0.0-alpha.1'` | ToBid 接入，当前仅 Reward 可用，其他广告类型为后续 Phase 6 |

> ⚠️ **不能同时接入** `flame_sdk_ios` 和 `flame_sdk_ios_tb`，两者模块名均为 `flame_sdk_ios`，同时接入会冲突。

---

## 一、集成配置

### 1.1 CocoaPods 安装

在 `Podfile` 中配置以下内容（以 TK 客户为例，TB 客户把 pod 名换成 `flame_sdk_ios_tb`）：

```ruby
platform :ios, '13.0'

source 'https://github.com/javaice007/flame-specs.git'
source 'https://cdn.cocoapods.org/'

target 'YourApp' do
  # ⚠️ 必须 static linkage：pod 内 source_files 依赖静态 vendored framework
  # （AnyThinkMediation*Adapter / ToBid WindMill），plain use_frameworks! 会触发
  # "transitive dependencies include statically linked binaries" 错误。
  use_frameworks! :linkage => :static

  pod 'flame_sdk_ios', '1.0.0-alpha.1'
end

# Xcode 16 兼容性修复
post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['ENABLE_USER_SCRIPT_SANDBOXING'] = 'NO'
    end
  end
end
```

执行安装：

```bash
pod install
```

### 1.2 import 写法（TK / TB 完全一致）

虽然两个 pod 名不同，但 module name 统一为 `flame_sdk_ios`，接入方代码无需因选 TB 而改 import：

```objc
// ObjC
#import <flame_sdk_ios/flame_sdk_ios.h>
#import <flame_sdk_ios/FlameSdk.h>
#import <flame_sdk_ios/FlameRewardAd.h>
```

```swift
// Swift
import flame_sdk_ios
```

> 客户无需关心转发头细节（`flame_sdk_ios/wrappers/flame_sdk_ios/` 或 `flame_sdk_ios/wrappers/flame_sdk_ios_tb/`），按上面写法即可。

### 1.3 Swift 项目 Bridging Header

在 Xcode 中创建 Bridging Header 文件（如 `AppName-Bridging-Header.h`），并在 Build Settings 中配置 `SWIFT_OBJC_BRIDGING_HEADER`：

```objc
#ifndef AppName_Bridging_Header_h
#define AppName_Bridging_Header_h

#import <flame_sdk_ios/FlameSdk.h>

#endif
```

### 1.4 Info.plist 配置

允许广告网络进行 HTTP 请求（ATS 豁免）：

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
</dict>
```

SKAdNetwork IDs 与 LSApplicationQueriesSchemes 配置请参考 Flame ADX 后台获取最新列表（与历史版本一致，本次 alpha 不变更）。

---

## 二、初始化与广告加载

```objc
// 1. 初始化（TK / TB 统一入口，SDK 自动识别平台）
[FlameSdk initSDKWithAppId:@"your_app_id"
                     appKey:@"your_app_key"
                 completion:^(BOOL success, NSError *error) {
    // ...
}];

// 2. 加载激励视频（TK / TB 均可用）
FlameRewardAd *reward = [FlameSdk createRewardAdWithViewController:self
                                                       placementId:@"your_placement_id"];
```

> TB 变体当前仅 Reward 可用；Splash / Interstitial / Banner / Native 的 TB 实现为后续 Phase 6，
> 当前调用会返回 nil 占位。

各广告格式的 API 与回调协议与历史版本（0.1.8.x）保持一致：
- Banner（Express / SelfRender）
- Interstitial
- Reward Video
- Splash
- Native

详细 API 与 Placement ID 测试值请联系 Flame 业务侧获取。

---

## 三、OpenSSL 依赖说明（客户无需手动处理）

Flame core binary（`flame_sdk_ios_core.framework`）是动态 framework，依赖：

```
@rpath/OpenSSL.framework/OpenSSL
```

两个 podspec 均已显式声明：

```ruby
s.dependency 'OpenSSL-Universal', '~> 3.6'
```

客户 `pod install` 后 OpenSSL.framework 会自动内嵌进 App 的 `Frameworks/` 目录，**无需手动添加**。
若不显式声明，真机启动会 crash：

```
dyld: Library not loaded: @rpath/OpenSSL.framework/OpenSSL
```

---

## 四、内部架构（仅供理解，客户无需关心）

```
pod 'flame_sdk_ios' (TK 客户)
├── vendored_frameworks: flame_sdk_ios_core.xcframework
│   └── module = flame_sdk_ios_core（零三方符号，仅 OpenSSL + 系统库）
├── source_files:
│   ├── flame_sdk_ios/wrappers/flame_sdk_ios/*.h  → 转发到 <flame_sdk_ios_core/...>
│   ├── flame_sdk_ios/mediation/tk/*.m             → FlameTKProvider (+load 自动注册)
│   └── flame_sdk_ios/adapter/tk/*.m               → AtRewardAdapter 等
└── dependencies: OpenSSL + AnyThinkiOS + 全 Mediation + AdGain + 飞梭

pod 'flame_sdk_ios_tb' (TB 客户)
├── vendored_frameworks: 同一份 core binary
├── source_files:
│   ├── flame_sdk_ios/wrappers/flame_sdk_ios_tb/*.h → 转发到 <flame_sdk_ios_core/...>
│   ├── flame_sdk_ios/mediation/tb/*.m               → FlameTBProvider (+load 自动注册)
│   └── flame_sdk_ios/adapter/tb/*.m                 → TbRewardAdapter
└── dependencies: OpenSSL + ToBid-iOS-RC
```

平台 Provider（FlameTKProvider / FlameTBProvider）通过 `+load` 自动注册到 `FlameMediationRegistry`，
SDK 内部根据平台类型激活对应 Provider，客户无需手动选择平台。

---

## 五、常见问题

### Q1: 报错 `transitive dependencies include statically linked binaries`
A: Podfile 缺少 `use_frameworks! :linkage => :static`，加上即可。

### Q2: 报错 `dyld: Library not loaded: @rpath/OpenSSL.framework/OpenSSL`
A: podspec 未声明 OpenSSL 依赖。正常情况下 SDK podspec 已自动包含，无需手动加；
若版本异常可手动在 Podfile 补 `pod 'OpenSSL-Universal', '~> 3.6'`。

### Q3: 同时接入 `flame_sdk_ios` 和 `flame_sdk_ios_tb` 会怎样？
A: 两者 module name 均为 `flame_sdk_ios`，会冲突。请只接入一个。

### Q4: TB 能用 Banner / Splash / Interstitial / Native 吗？
A: 当前（Phase 5A）TB 仅 Reward 可用，其他为后续 Phase 6。

### Q5: ToBid Reward 报错 `code 800031 AppId 没有绑定到 ToBid 聚合服务`
A: 属于 ToBid 后台配置问题，应用尚未在 ToBid 后台注册或绑定。请联系 ToBid 业务侧完成应用绑定后重试，
SDK 代码链路正常（能正常走到 WindMill 与 ToBid 后台错误回调）。

### Q6: Xcode 16 构建报错（Script Sandboxing）
A: 在 `Podfile` 的 `post_install` hook 中设置 `ENABLE_USER_SCRIPT_SANDBOXING = 'NO'`（参考第一节配置）。
