# Changelog

## 1.0.0-alpha.1 - 2026-06-18

### Added
- Thin Core 架构：两个对外 podspec 共用一个 `flame_sdk_ios_core.xcframework`。
- 新增 `flame_sdk_ios_tb` ToBid / WindMill 变体。
- TK / TB 均通过 `+load` 自动注册 Provider（FlameTKProvider / FlameTBProvider）。
- TK 变体支持现有 AnyThink / TopOn 广告链路（Banner / Interstitial / Reward / Splash / Native）。
- TB 变体当前支持 Reward 链路。

### Changed
- 分发结构从纯二进制调整为 core binary + 平台源码插件。
- 接入方 import 统一为 `flame_sdk_ios`（pod 名 `flame_sdk_ios_tb` 的 module name 也是 `flame_sdk_ios`）。
- core binary 改名为 `flame_sdk_ios_core`（pod 名 / module 名 / binary 名解耦）。

### Notes
- 该版本为 alpha 版本，用于生产环境验证。
- TB Reward 真实填充需等待 ToBid 后台应用绑定完成（`code 800031` 属于后台配置问题）。
- TB Splash / Interstitial / Banner / Native 尚未实现，后续 Phase 6 补齐。
