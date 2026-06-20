# Flame iOS SDK

Flame iOS 广告聚合 SDK。

## 安装

在 Podfile 中添加：

```ruby
source 'https://github.com/javaice007/flame-specs.git'
source 'https://cdn.cocoapods.org/'

target 'YourApp' do
  # TK 聚合接入
  pod 'flame_sdk_ios', '1.0.0-alpha.5'

  # 或 TB 聚合接入（二选一，不能同时接入）
  # pod 'flame_sdk_ios_tb', '1.0.0-alpha.5'
end
```

执行 `pod install`。

## 使用

```objc
#import <flame_sdk_ios/FlameSdk.h>
```

```swift
import flame_sdk_ios
```

## 说明

- `flame_sdk_ios`：适用于 TK 聚合接入
- `flame_sdk_ios_tb`：适用于 TB 聚合接入
- 两个 pod 互斥，选择其中一个即可
- Flame SDK 本身不强制要求 `use_frameworks!`；如果宿主工程已有 `use_frameworks!` 配置，可按原工程配置保留
- 如需使用 Sigmob 相关广告源，请使用 `flame_sdk_ios 1.0.0-alpha.5` 及以上版本

## 版本

当前版本：`1.0.0-alpha.5`

详见 [CHANGELOG.md](./CHANGELOG.md)。

## License

Commercial. See [LICENSE](./LICENSE).
