# Changelog

## 1.0.1-alpha.1

- **修复 P0 严重问题：公开 Pod 1.0.0 接入即启动闪退。** 1.0.0 的动态 framework 对 ToBid 的
  8 个 WindMill 类符号使用扁平命名空间延迟解析，而 ToBid 仅有静态归档，App 启动时 dyld
  解析不到（`symbol not found in flat namespace '_OBJC_CLASS_$__TtC11WindMillSDK11WindMillAds'`），
  TK/TB 双线均受影响。请所有 1.0.0 用户立即升级。
- 发布形态由"单二进制（动态）"切换为**静态双线产物**：`flame_sdk_ios.xcframework`（TK 线）
  与 `flame_sdk_ios_tb.xcframework`（TB 线）均为静态 framework，链接进客户主程序，
  全部跨平台符号在 App 链接期解析，dyld 阶段无跨库查找。
- TK 产物不再包含 ToBid 胶水（零 WindMill 符号引用）；TB 产物不再包含 TopOn 胶水
  （零 AnyThink 符号引用）。
- 客户升级仅需修改 Podfile 版本号，module/import/API 完全不变。
- 平台核心依赖版本不变（AnyThinkiOS 6.5.71 / ToBid-iOS-RC 5.5.6 / OpenSSL-Universal ~> 3.6）。

## 1.0.0-alpha.1

- 发布 iOS SDK 1.0.0-alpha.1 客户接入版本。
- 提供 TK / TB 两种接入方式，二选一接入。
- 统一接入 module name：`flame_sdk_ios`。
- TK 客户通过 `flame_sdk_ios` 接入。
- TB 客户通过 `flame_sdk_ios_tb` 接入。
- Flame SDK 本身不强制要求 `use_frameworks!`。
