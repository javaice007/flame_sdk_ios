# ============================================================
# flame_sdk_ios.podspec（方案 E 本地验证版）
# ------------------------------------------------------------
# Phase 5A.11 Step 1 方案 E 实验性 podspec（本地 :path 验证，不发布）
#
# 与方案 D（alpha.2）的关键区别：
#   方案 D source_files = wrappers + mediation/tk/** + adapter/tk/**
#     → 把 At*Adapter.m / FlameTKProvider.m 编进客户 Pods（源码暴露）
#
#   方案 E source_files = 仅 wrappers/*.h（纯头转发，无 .m 实现）
#     + vendored_frameworks = core binary + tk plugin binary
#     → flame_sdk_ios 模块由 wrappers 头编译生成（接入方 import 入口）
#     → TK 实现（FlameTKProvider/At*Adapter）来自 tk plugin binary（无源码暴露）
#
# 这样既保留了"模块从源码生成"（解决 bridging header 模块查找问题），
# 又实现了"TK 实现不暴露源码"（方案 E 核心目标）。
#
# 红线：本 podspec 仅用于本地 :path 验证，不进 flame-specs 仓库，不打 tag。
# ============================================================

Pod::Spec.new do |s|
  s.name             = 'flame_sdk_ios'
  s.module_name      = 'flame_sdk_ios'
  s.version          = '1.0.0-alpha.3-local'
  s.summary          = 'Flame iOS Ad SDK - TK Edition (Scheme E: binary plugin, local validation)'
  s.description      = 'Flame iOS advertising aggregation SDK, TK / TopOn / AnyThink edition. '\
                       'Scheme E experimental: core binary + TK plugin binary (no source exposure).'
  s.homepage         = 'https://github.com/javaice007/flame_sdk_ios'
  s.author           = { 'flame' => 'flame@toowe.com' }
  s.ios.deployment_target = '13.0'

  s.source           = { :git => 'https://github.com/javaice007/flame_sdk_ios.git' }

  # ============================================================
  # 双 vendored_frameworks（经 build 符号链接访问）
  # ============================================================
  # 1) flame_sdk_ios_core.xcframework：平台中立核心
  #    module 名 = flame_sdk_ios_core（避免与外层 pod 同名 module 遮蔽）
  # 2) tk/flame_sdk_ios.xcframework：TK 平台插件二进制
  #    含 FlameTKProvider（+load 自动注册）+ 6 个 At*Adapter/View
  #    module 名也是 flame_sdk_ios，但此 framework 的 Headers 不会被用作
  #    pod 模块头（pod 模块由下方 source_files 的 wrappers 头生成）。
  #    该 framework 仅提供 link 期符号 + 运行期 +load 注册。
  # ============================================================
  s.vendored_frameworks = [
    'build/flame_sdk_ios_core.xcframework',
    'build/tk/flame_sdk_ios.xcframework'
  ]

  # ============================================================
  # source_files：仅 wrappers 转发头（纯头，无 .m）
  # ------------------------------------------------------------
  # 这是方案 E 与方案 D 的关键差异点：
  #   - wrappers/*.h 全部是单行 #import <flame_sdk_ios_core/...> 转发头
  #   - 它们被编译为 flame_sdk_ios 模块的公共头（解决 Swift/bridging header 模块查找）
  #   - 不含任何 .m 实现 → At*Adapter / FlameTKProvider 源码不暴露给客户
  #   - TK 实现符号由 vendored tk plugin framework 在 link 期提供
  # ============================================================
  s.source_files = 'flame_sdk_ios_headers/*.{h}'
  s.public_header_files = 'flame_sdk_ios_headers/*.{h}'

  # ============================================================
  # 运行期依赖（与正式 TK podspec 完全一致）
  # ============================================================
  s.dependency 'OpenSSL-Universal', '~> 3.6'

  s.dependency 'AnyThinkiOS', '6.5.71'

  s.dependency 'AnyThinkMediationAdxSmartdigimktCNAdapter', '6.5.72.2.1'
  s.dependency 'AnyThinkMediationGromoreAdapter', '7.6.0.4.2.0'
  s.dependency 'AnyThinkMediationBaiduAdapter', '10.050.2.1'
  s.dependency 'AnyThinkMediationMSAdapter', '2.7.18.1.2.0'
  s.dependency 'AnyThinkMediationZYAdapter', '2.6.4.29.2.0'
  s.dependency 'AnyThinkMediationFunlinkAdapter', '2.9.0.1.2.2.0'
  s.dependency 'AnyThinkMediationBeiZiAdapter', '5.5.0.3.2.0'
  s.dependency 'AnyThinkMediationKuaiShouAdapter', '5.4.10.1.2.0'
  s.dependency 'AnyThinkMediationSigmobAdapter', '4.20.12.2.0'
  s.dependency 'AnyThinkMediationTTAdapter_Mix', '7.6.0.4.2.0'
  s.dependency 'AnyThinkMediationGDTAdapter', '4.15.90.2.0'

  s.dependency 'AdGainSDK', '4.2.7.1'
  s.dependency 'AdGainSDKTakuAdapter', '4.2.7.1'

  s.dependency 'FSUnionAdSDK', '1.0.8.0'

  # -ObjC：保证 TK plugin framework 中 FlameTKProvider +load 不被 dead-strip
  #
  # FRAMEWORK_SEARCH_PATHS：
  #   方案 E 双 framework 的核心集成难点 —— wrappers 转发头 #import <flame_sdk_ios_core/...>，
  #   接入方 App 编译 bridging header / Swift module 时需要找到 flame_sdk_ios_core 模块。
  #   CocoaPods 把 vendored framework 放在 pod source root 的 build/ 下，
  #   staging 到 XCFrameworkIntermediates 发生在 pod 构建期，但 Swift bridging header
  #   扫描早于 pod 构建（chicken-and-egg）。因此直接把 xcframework slice 路径加入搜索路径。
  #   （PODS_TARGET_SRCROOT 指向 research/local_pod，build/ 在其下）
  s.pod_target_xcconfig = {
    'OTHER_LDFLAGS' => '$(inherited) -ObjC',
    'FRAMEWORK_SEARCH_PATHS' => '$(inherited) ${PODS_ROOT}/../../flame_ios_sdk/research/local_pod/build/flame_sdk_ios_core.xcframework/ios-arm64 ${PODS_ROOT}/../../flame_ios_sdk/research/local_pod/build/flame_sdk_ios_core.xcframework/ios-x86_64-simulator'
  }
  s.user_target_xcconfig = {
    'OTHER_LDFLAGS' => '$(inherited) -ObjC',
    'FRAMEWORK_SEARCH_PATHS' => '$(inherited) ${PODS_ROOT}/../../flame_ios_sdk/research/local_pod/build/flame_sdk_ios_core.xcframework/ios-arm64 ${PODS_ROOT}/../../flame_ios_sdk/research/local_pod/build/flame_sdk_ios_core.xcframework/ios-x86_64-simulator'
  }
end
