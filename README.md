# Flame iOS SDK

Flame iOS SDK 是广告聚合 SDK，当前支持 **TK（TopOn）** 和 **ToBid** 双线维护。

## 当前版本

`1.0.0-alpha.1`

## 发布形态

当前采用 **1 个二进制 SDK 包 + 多个 podspec** 的发布模型：

| 组成 | 说明 |
|---|---|
| `flame_sdk_ios.xcframework` | 唯一二进制包，TK 和 ToBid 共用 |
| `flame_sdk_ios.podspec` | TK 客户 podspec |
| `flame_sdk_ios_tb.podspec` | ToBid 客户 podspec |
| `flame_sdk_ios_tk_sigmob_adapter` | TK 侧 Sigmob 适配器（TK 客户自动带出，不需手动声明）|

## 客户接入方式

```ruby
source 'https://github.com/javaice007/flame-specs.git'
source 'https://cdn.cocoapods.org/'

target 'YourApp' do
  # TK 客户
  pod 'flame_sdk_ios', '1.0.0-alpha.1'

  # ToBid 客户，二选一
  # pod 'flame_sdk_ios_tb', '1.0.0-alpha.1'
end
```

接入代码（TK / ToBid 一致）：

```objc
#import <flame_sdk_ios/FlameSdk.h>
```

```swift
import flame_sdk_ios
```

```objc
[FlameSdk initWithAppId:@"your_app_id" appKey:@"your_app_key"];
```

Flame SDK 本身不强制要求 `use_frameworks!`。如果宿主工程已有 `use_frameworks!` 配置，可按原工程配置保留。

## TK 与 ToBid 的区别

| 维度 | TK 版本（`flame_sdk_ios`）| ToBid 版本（`flame_sdk_ios_tb`）|
|---|---|---|
| 聚合平台 | TopOn (AnyThink) | ToBid (WindMill) |
| TK 广告源依赖 | ✅ 含（AnyThinkMediation* / AdGain / FSUnion）| ❌ 不含 |
| Sigmob 适配器 | ✅ 自动带出 | ❌ 不含 |
| 广告类型 | 激励视频 / 开屏 / 插屏 / 横幅 / 原生 | 激励视频（其他待接入）|
| module name | `flame_sdk_ios` | `flame_sdk_ios`（一致）|

两条线可以独立接入、独立验证、独立演进。`flame_sdk_ios` 与 `flame_sdk_ios_tb` **互斥**，不能同时接入。

## 当前验证状态

| 验证项 | TK | ToBid |
|---|---|---|
| pod install | ✅ 通过 | ✅ 通过 |
| 编译验证 | ✅ BUILD SUCCEEDED | ✅ BUILD SUCCEEDED |
| 真机启动 | ✅ 通过 | ✅ 通过 |
| Sigmob 广告链路 | ✅ 已验证可调用 | — |
| 真实广告位业务验证 | ⏳ 待持续验证 | ⏳ 待验证 |
| ToBid 后台 AppId 绑定 | — | ⏳ 待配置（当前返回 800031）|

**说明**：`1.0.0-alpha.1` 已完成 SDK 接入和编译验证。ToBid 当前还没有正式应用接入，真实广告位、广告请求、展示、点击、回调尚未完成业务验证。

## 注意事项

1. `flame_sdk_ios` 与 `flame_sdk_ios_tb` 不能同时接入。
2. 如果 ToBid 接入时返回 `800031`，通常是 ToBid 后台 AppId 未绑定到聚合服务，请检查后台配置。
3. TK 客户不需要手动声明 `flame_sdk_ios_tk_sigmob_adapter`，`flame_sdk_ios` 会自动带上所需依赖。

## 发布规范

后续版本发布必须遵循以下规范：

- 发布前必须执行 `./scripts/preflight_release.sh <version>`，校验通过后才允许发布。
- alpha 版本号格式：`1.0.0-alpha.1`、`1.0.0-alpha.2`、`1.0.0-alpha.3` ...
- 禁止裸 `1.0.0-alpha`（无序号）。
- 禁止跳号、覆盖、重复发布。

详见 [CHANGELOG.md](./CHANGELOG.md)。

## License

Commercial. See [LICENSE](./LICENSE).
