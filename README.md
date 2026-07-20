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
- Phase 5A.16B CSJ 依赖接入（本地 build commit，未发布）：`flame_sdk_ios_tb.podspec` 加 `ToBid-iOS-RC/CSJAdapter 5.5.6`（CSJ/Pangle，服务后续 Banner）。TB clean pod install 5 pods，真机 BUILD SUCCEEDED，CSJ Adapter 符号进 App；AnyThink weak-link 无回归；TK clean build 28 pods 不受影响。
- Phase 5A.16C Banner Adapter 实现（本地 feat commit，未发布）：新增 `TbBannerAdapter`（Express 模式完整 + SelfRender 占位），接入 FlameTBProvider Banner 工厂。复用 AtBannerAdapter Express 模式 + WindMillBannerView 特化（`loadAdData` / `expectSize:` / `isAdValid` / strong 持有 + retrieveAdView 返回 / auto-refresh 由 ToBid 后台控制 / 首次失败不内部重试与 TK 一致）。XCFramework 构建成功，TbBannerAdapter + TB_BANNER_DIAG 两 slice 命中，TB 真机 BUILD SUCCEEDED，TK 28 pods 无回归。
- Phase 5A.16D CSJ Banner 真机验证（进行中，commit `39bc191`）：链路验证通过（两层 placementId 映射、CSJ networkId=13 选中、BUAdSDK 7.6.0.4 初始化、CSJ 请求发出、no-fill 错误链路完整 CSJ→ToBid→Adapter→Demo、Adapter 不重试+Demo RetryScheduler）。**尺寸已排除根因**（402×50 与 320×50 均返回 800110）；ToBid 官方测试位当前 no-fill，成功路径待平台方确认。
- Phase 5A.16E 腾讯 GDT Adapter 接入（本地 build commit `5414cf5` + 真机验证 commit `dac831a`，未发布）：`flame_sdk_ios_tb.podspec` 加 `ToBid-iOS-RC/GDTAdapter 5.5.6`（GDTMobSDK 4.15.90），TB 同时含 CSJ+GDT。TB 6 pods BUILD SUCCEEDED，TK 28 pods 不受影响。**GDT Banner 真机真实填充成功**：用户配置腾讯广告位 + ToBid 聚合位 + Flame pMap 后，完整链路验证通过（load→GDT source→didLoadSuccess→retrieveAdView→addSubview→exposure→onAdShow），`WindMillBannerView.adSize` 实际返回 402×50 全宽。**TK/TB 坐标审计**：container/adView/子 View 几何完全一致（`{0,741,402,50}`），TabBar `{0,791,402,83}`，intersectionHeight=0，无重叠无裁切，视觉差异仅为素材模板排版不同，布局无需改动。详见 `doc/flame_mediation/phase-5a.16e-gdt-banner-integration-report.md` §14-§15。
- Phase 5A.17A TK SelfRender Banner 调研（本地 docs commit `aaa09e3`，未发布）：审计确认 TK SelfRender 本质是 AnyThink Banner 「Native Mix」（非纯 Native），Flame 公共 API 平台无关，ToBid 5.5.6 Native 自渲染栈完整但**无对等的客户端 Banner Native Mix 类**。原方案 B（用 ToBid Native 桥接模拟）**已撤销**——强行用独立 Native 广告位模拟会改变广告位类型/后台/链路/生命周期/客户语义。**修订为方案 E**。详见 `doc/flame_mediation/phase-5a.17a-self-render-banner-research.md`。
- Phase 5A.17B TB SelfRender 兼容降级（本地 feature commit，未发布）：方案 E 实施——Flame 公共 API 全部保留，TB SelfRender 明确返回 `ERROR_CODE_UNSUPPORTED_PLATFORM`（14003）+ 统一日志 `[TB_SELF_RENDER_UNSUPPORTED]` + 安全降级（不创建任何 ToBid 对象、不发起请求、异步派发一次回调 + `_destroyed` 守卫）。Demo `SelfRenderBannerManager` 新增 `NonRetryableErrorCodes`（14003/14004/14002）**平台无关**短路，避免重试风暴（不判 pt、不 import 三方 SDK）。XCFramework 双 slice 构建成功，TB 6 pods + TK 28 pods BUILD SUCCEEDED，普通 Express Banner 完全隔离不受影响。后续升级条件：仅当 ToBid 提供对等的客户端 Banner Native Mix API 才重新评估。详见 `doc/flame_mediation/phase-5a.17b-tb-self-render-unsupported-bridge.md`。
- Phase 5A.18A TK Native Template 调研（本地 docs commit `7494748`，未发布）：审计确认 Flame 已有完整 Native 公共 API（`<FlameNativeAd>` + `showInContainer:`，Demo 零 AnyThink import、零自建 UI）；TK Native Template 本质是 AnyThink 统一 `ATNativeAD*` API 运行时按 `isExpressAd` 分支（Template 由 AnyThink 完整渲染）；ToBid 5.5.6 Native Express 完整支持（单一 `WindMillNativeAdView` 类按 `feedADMode` 双模式）；GDTAdapter 5.5.6 单一 subspec 已含 `NativeExpressAdsManager`+`FeedAdLoaderListener`。判断：**方案 A 完全无损映射（仅 Native Template/Express）**。详见 `doc/flame_mediation/phase-5a.18a-native-template-research.md`。
- Phase 5A.18B TB Native Template Adapter 实现（本地 feature commit，未发布）：新增 `TbNativeAdapter.{h,m}`（`adapter/tb/`，与现有 TB Adapter 同目录）——Express 模式完整实现（`WindMillNativeAdsManager loadAdDataWithCount:1` → `feedADMode==NativeExpress` 保护 → `WindMillNativeAdView.refreshData:` 异步模板渲染 → `nativeExpressAdViewRenderSuccess:` 后按模板真实高度 addSubview 到 `showInContainer:` 传入的容器，不强行拉伸；generation + destroyed + stale 三重守卫），Native SelfRender 明确降级（`[TB_NATIVE_SELF_RENDER_NOT_IMPLEMENTED]` + `ERROR_CODE_UNSUPPORTED_PLATFORM`，描述"SDK 桥接尚未接入"非"ToBid 不支持"）。`FlameTBProvider.m` Native 工厂 `return nil` → 返回 `TbNativeAdapter`。Flame 公共 API / Demo 调用方式 / AtNativeAdapter 零修改。Demo `NativeAdManager` 加 `NonRetryableErrorCodes` 平台无关短路（独立 commit）。XCFramework 双 slice 构建成功：`TbNativeAdapter` 符号 + `TB_NATIVE_DIAG` + `TB_NATIVE_SELF_RENDER_NOT_IMPLEMENTED` + ToBid selector refs 全部命中；AnyThink LC_LOAD_WEAK_DYLIB 无回归；TbBanner/Splash/Interstitial/Reward 符号无回归。TB Demo 6 pods + TK 临时切 28 pods BUILD SUCCEEDED，已恢复 TB。GDT Native 真机填充与完整展示留 Phase 5A.18C。详见 `doc/flame_mediation/phase-5a.18b-tb-native-template-implementation-report.md`。

## 广告类型

| 广告类型 | TK | ToBid |
|---|---|---|
| 激励视频 | ✅ | ✅ |
| 开屏广告 | ✅ | ✅（Phase 5A.15.1，三次独立冷启动 + skip/close 幂等 + Reward 完整回归 + TK 编译回归） |
| 插屏广告 | ✅ | ✅（Phase 5A.14.1，真机 R1/R2 完整关闭闭环验证） |
| 横幅广告（Express） | ✅ | ✅（Phase 5A.16E，GDT 真机真实填充 + TK/TB 坐标审计通过，402×50 全宽无重叠） |
| 横幅广告（SelfRender） | ✅（AnyThink Banner Native Mix） | ⚠️ **暂不支持，兼容降级**（Phase 5A.17B 方案 E：返回 `ERROR_CODE_UNSUPPORTED_PLATFORM` + `[TB_SELF_RENDER_UNSUPPORTED]` 日志，不崩溃不重试；普通 Express Banner 不受影响） |
| 原生广告（Template/Express） | ✅ | 🚧 Adapter 已实现（Phase 5A.18B，构建通过）；GDT Native Express 真机填充待 Phase 5A.18C |
| 原生广告（SelfRender） | ✅ | ⚠️ **暂不支持，兼容降级**（Phase 5A.18B：返回 `ERROR_CODE_UNSUPPORTED_PLATFORM` + `[TB_NATIVE_SELF_RENDER_NOT_IMPLEMENTED]` 日志，原因"SDK 桥接尚未接入"非"ToBid 不支持"） |

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
