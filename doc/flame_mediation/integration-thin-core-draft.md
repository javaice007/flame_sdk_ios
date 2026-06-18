# Flame iOS SDK 接入说明（方案 D · Thin Core 草案）

> **状态**：草案（Phase 5A.10 Step 3 正式化本地验证完成，未发布）
> **适用版本**：`flame_sdk_ios` / `flame_sdk_ios_tb` ≥ 0.1.8.5
> **架构**：方案 D — 两个对外 podspec + 一个内部 core binary
> **最后更新**：2026-06-18

---

## 1. 选哪个 pod？

Flame SDK 提供两个互斥的 pod，**客户只接入一个**：

| 客户类型 | Podfile 写法 | 适用场景 |
|---------|-------------|---------|
| TK 客户（TopOn / AnyThink 聚合） | `pod 'flame_sdk_ios'` | 默认场景，含 AnyThink + 全 Mediation + AdGain + 飞梭 |
| TB 客户（ToBid / WindMill） | `pod 'flame_sdk_ios_tb'` | ToBid 接入，当前仅 Reward 可用，其他广告类型为后续 Phase 6 |

```ruby
# TK 客户
target 'YourApp' do
  use_frameworks! :linkage => :static
  pod 'flame_sdk_ios'
end

# TB 客户
target 'YourApp' do
  use_frameworks! :linkage => :static
  pod 'flame_sdk_ios_tb'
end
```

> ⚠️ **不能同时接入** `flame_sdk_ios` 和 `flame_sdk_ios_tb`，两者模块名冲突会导致编译失败。

---

## 2. import 写法（TK / TB 完全一致）

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

> 转发头位于 `flame_sdk_ios/wrappers/flame_sdk_ios/`（TK）或 `flame_sdk_ios/wrappers/flame_sdk_ios_tb/`（TB），
> 内部转发到 `<flame_sdk_ios_core/...>`（内部 core binary 模块）。客户无需关心此细节，按上面写法即可。

---

## 3. 推荐 Podfile 配置

```ruby
platform :ios, '13.0'

source 'https://github.com/javaice007/flame-specs.git'
source 'https://cdn.cocoapods.org/'

target 'YourApp' do
  # ⚠️ 必须 static linkage：pod 内 source_files 依赖静态 vendored framework
  # （AnyThinkMediation*Adapter / ToBid WindMill），plain use_frameworks! 会触发
  # "transitive dependencies include statically linked binaries" 错误。
  use_frameworks! :linkage => :static

  pod 'flame_sdk_ios'  # 或 'flame_sdk_ios_tb'
end
```

---

## 4. OpenSSL 依赖说明（客户无需手动处理）

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

## 5. 初始化与广告加载

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

---

## 6. 内部架构（仅供理解，客户无需关心）

```
pod 'flame_sdk_ios' (TK 客户)
├── vendored_frameworks: build/core_named/flame_sdk_ios_core.xcframework
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

## 7. 常见问题

### Q1: 报错 `transitive dependencies include statically linked binaries`
A: Podfile 缺少 `use_frameworks! :linkage => :static`，加上即可。

### Q2: 报错 `dyld: Library not loaded: @rpath/OpenSSL.framework/OpenSSL`
A: podspec 未声明 OpenSSL 依赖。客户应在 Podfile 显式补 `pod 'OpenSSL-Universal', '~> 3.6'`
（正常情况下 SDK podspec 已自动包含，无需手动加）。

### Q3: 同时接入 `flame_sdk_ios` 和 `flame_sdk_ios_tb` 会怎样？
A: 两者 module name 均为 `flame_sdk_ios`，会冲突。请只接入一个。

### Q4: TB 能用 Banner / Splash / Interstitial / Native 吗？
A: 当前（Phase 5A）TB 仅 Reward 可用，其他为后续 Phase 6。
