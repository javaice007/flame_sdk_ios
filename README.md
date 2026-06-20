# Flame SDK iOS 接入说明

Flame SDK 是 iOS 广告聚合 SDK。当前客户接入版本为 `1.0.0-alpha.1`。

## 一、版本说明

| Pod | 适用场景 | 版本 |
|---|---|---|
| `flame_sdk_ios` | TK 客户 | `1.0.0-alpha.1` |
| `flame_sdk_ios_tb` | TB 客户 | `1.0.0-alpha.1` |

`flame_sdk_ios` 与 `flame_sdk_ios_tb` 二选一接入，不能同时接入。

## 二、Podfile 配置

```ruby
source 'https://github.com/javaice007/flame-specs.git'
source 'https://cdn.cocoapods.org/'

target 'YourApp' do
  # TK 客户
  pod 'flame_sdk_ios', '1.0.0-alpha.1'

  # 或 TB 客户，二选一
  # pod 'flame_sdk_ios_tb', '1.0.0-alpha.1'
end
```

Flame SDK 本身不强制要求 `use_frameworks!`。如果宿主工程已有 `use_frameworks!` 配置，可按原工程配置保留。

## 三、代码接入

Objective-C：

```objc
#import <flame_sdk_ios/FlameSdk.h>
```

Swift：

```swift
import flame_sdk_ios
```

## 四、初始化

```objc
[FlameSdk initWithAppId:@"your_app_id" appKey:@"your_app_key"];
```

如需查看初始化结果，可使用带回调的初始化接口，具体以 SDK 头文件为准。

## 五、广告类型

当前 SDK 支持以下广告类型：

* 激励视频
* 开屏广告
* 插屏广告
* 横幅广告
* 原生广告

具体调用方式以 SDK 头文件和项目接入文档为准。

## 六、注意事项

1. `flame_sdk_ios` 与 `flame_sdk_ios_tb` 不能同时接入。
3. 如果 TB 接入时返回 `800031`，通常是 ToBid 后台 AppId 未绑定到聚合服务，请检查后台配置。
4. TK 客户不需要手动声明 `flame_sdk_ios_tk_sigmob_adapter`，`flame_sdk_ios` 会自动带上所需依赖。

## 七、技术支持

如有接入问题，请联系 Flame SDK 技术支持。
