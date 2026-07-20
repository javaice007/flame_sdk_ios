# Flame iOS SDK

Flame iOS SDK 是广告聚合 SDK，当前支持 **TK（TopOn）** 和 **ToBid** 双线维护。

## 版本信息

- **SDK 版本**: 1.0.0-alpha.1
- **最低支持**: iOS 13.0+
- **开发语言**: Objective-C

## 目录结构

```
flame_sdk_ios/
├── core/               # SDK 初始化、配置管理、公共实体
├── mediation/          # 聚合层抽象与 TK / ToBid 双线分发逻辑
│   ├── FlameMediationRegistry   # Provider 注册中心
│   ├── FlameMediationRouter     # 平台路由（按 pt 激活）
│   ├── tk/                      # TK Provider（TopOn）
│   └── tb/                      # ToBid Provider（WindMill）
├── adapter/            # 第三方平台适配层
│   ├── FlameAdapterManager      # 适配器管理
│   ├── tk/                      # TK 适配器（激励/开屏/插屏/横幅/原生）
│   └── tb/                      # ToBid 适配器（激励视频）
├── ads/                # 广告类型封装
│   ├── reward/                 # 激励视频
│   ├── splash/                 # 开屏广告
│   ├── interstitial/           # 插屏广告
│   ├── banner/                 # 横幅广告
│   └── nativate/               # 原生广告（历史目录命名，当前保持兼容）
├── utils/              # 日志、网络、加密、本地缓存等工具能力
└── flame_sdk_ios.h    # 对外统一头文件
```

## 当前发布形态

| 组成 | 说明 |
|---|---|
| `flame_sdk_ios.xcframework` | 唯一二进制包，TK 和 ToBid 共用 |
| `flame_sdk_ios.podspec` | TK 客户 podspec |
| `flame_sdk_ios_tb.podspec` | ToBid 客户 podspec |
| `flame_sdk_ios_tk_sigmob_adapter` | TK 侧 Sigmob 适配器（TK 客户自动带出，不需手动声明）|

TK 和 ToBid 两条线共用同一个二进制包，通过不同 podspec 区分广告源依赖。

## TK 与 ToBid 的区别

| 维度 | TK 版本（`flame_sdk_ios`）| ToBid 版本（`flame_sdk_ios_tb`）|
|---|---|---|
| 聚合平台 | TopOn (AnyThink) | ToBid (WindMill) |
| TK 广告源依赖 | ✅ 含（AnyThinkMediation* / AdGain / FSUnion）| ❌ 不含 |
| Sigmob 适配器 | ✅ 自动带出 | ❌ 不含 |
| 广告类型 | 激励视频 / 开屏 / 插屏 / 横幅 / 原生 | 激励视频（其他待接入）|
| module name | `flame_sdk_ios` | `flame_sdk_ios`（一致）|

两条线可以独立接入、独立验证、独立演进。`flame_sdk_ios` 与 `flame_sdk_ios_tb` **互斥**，不能同时接入。

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

## 当前验证状态

| 验证项 | TK | ToBid |
|---|---|---|
| pod install | ✅ 通过（28 pods，含 AnyThinkiOS + ADX adapter） | ✅ 通过（4 pods，不含 AnyThinkiOS） |
| 编译验证 | ✅ BUILD SUCCEEDED | ✅ BUILD SUCCEEDED |
| 真机启动 | ✅ 通过（Phase 5A.13 Step 1.3，全广告位正常加载） | ✅ 通过（Phase 5A.13 Step 1.2B，冷启动 3/3 无 ADX 弹窗） |
| 激励视频业务验证 | ✅ TK 广告链路正常 | ✅ TB Reward 3 轮闭环（load/show/visible/reward/close/next-load） |
| Sigmob 广告链路 | ✅ 通过（flame_sdk_ios_tk_sigmob_adapter） | —（ToBid 内置 Sigmob） |
| ToBid 后台 AppId 绑定 | — | ✅ 已配置（appId=b22375234108） |
| AnyThinkSDK 运行时隔离 | ✅ TK App 强加载（含 ADX，不弹窗） | ✅ TB App 不加载（弱链接 + podspec 不带入，不弹窗） |

**说明**：

- `1.0.0-alpha.1` 已发布到远程 flame-specs（Phase 5A.12）。
- Phase 5A.13 完成两项关键修复（本地 commit，未发布）：
  - **TB Reward 关闭后重载失败修复**（commit `1abfdae`）：`show()` 阶段动态获取 presenter，避免使用 `load()` 时缓存的失效 UIViewController。
  - **AnyThinkSDK 弱链接方案**（commit `c40e4fe` + Step 1.3）：Flame binary 对 AnyThinkSDK 改为 LC_LOAD_WEAK_DYLIB，TB podspec 移除 AnyThinkiOS 依赖，消除 TB App 冷启动 "AnyThink Adx SDK 重要组件缺失" 弹窗；TK podspec 独家带入 AnyThinkiOS，TK 客户不受影响。
- Phase 5A.14 完成 TB 插屏接入（本地 commit `f97e746`，未发布）：新增 `TbInterstitialAdapter`，复用 Reward 已验证模式（动态 presenter + stale callback 守卫）。
- Phase 5A.14.1 修正验收口径（本地 docs commit，未发布）：修正 Demo 预加载时机后，R1/R2 真机完整关闭闭环（load/show/visible/**didClose**/next-load），R3 load success；Reward 仅加载回归通过。
- Phase 5A.15 完成 TB 开屏接入（本地 commit `0d13dd5`，未发布）：新增 `TbSplashAdapter`，复用已验证模式（stale callback 守卫 + `[TB_SPLASH_DIAG]` 日志）+ Splash 特化（`loadAd` / `showAdInWindow:withBottomView:` / `finishOnceWithReason:` 幂等）。
- Phase 5A.15.1 验收补齐（本地 docs commit，未发布）：**Splash 三次独立冷启动通过**（R1 倒计时关闭 + R2/R3 skip/close 幂等，finishOnce 二次拦截均生效）；**Reward 完整展示回归通过**（两轮闭环 load/show/didVisible/didClose/next-load，presenter/vcWindow 非空）；**TK 干净编译回归通过**（28 pods + BUILD SUCCEEDED + AnyThinkSDK 进入 App + Flame binary 保持 LC_LOAD_WEAK_DYLIB）。
- Phase 5A.16A 广告源审计（本地 docs commit `3b5326d`，未发布）：审计 ToBid 第三方广告源交付包，Banner 候选 6 家（CSJ/GDT/GroMore/Mintegral/MS/Octopus），推荐 CSJ 作首批。详见 `doc/flame_mediation/phase-5a.16a-tb-ad-network-integration-audit.md`。
- Phase 5A.16B CSJ 依赖接入（本地 build commit，未发布）：`flame_sdk_ios_tb.podspec` 加 `ToBid-iOS-RC/CSJAdapter 5.5.6`（CSJ/Pangle，服务后续 Banner）。TB clean pod install 5 pods，真机 BUILD SUCCEEDED，CSJ Adapter 符号进 App；AnyThink weak-link 无回归；TK clean build 28 pods 不受影响。**Banner Adapter 尚未实现**（Phase 5A.16C）。

## 广告类型

| 广告类型 | TK | ToBid |
|---|---|---|
| 激励视频 | ✅ | ✅ |
| 开屏广告 | ✅ | ✅（Phase 5A.15.1，三次独立冷启动 + skip/close 幂等 + Reward 完整回归 + TK 编译回归） |
| 插屏广告 | ✅ | ✅（Phase 5A.14.1，真机 R1/R2 完整关闭闭环验证） |
| 横幅广告 | ✅ | ⏳ 待接入 |
| 原生广告 | ✅ | ⏳ 待接入 |

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

## 技术支持

如有接入问题，请联系 Flame SDK 技术支持。
