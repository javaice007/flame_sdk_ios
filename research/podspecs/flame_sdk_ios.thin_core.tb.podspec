# ============================================================
# 实验性 podspec —— Thin Core + TB 平台源码插件
# ------------------------------------------------------------
# ⚠️ 仅 Phase 5A.10 Step 2 实验验证，不是正式发布 podspec。
# ⚠️ 不进 pod repo、不打 tag、不替换 flame_sdk_ios_tb.podspec。
#
# 设计目标：
#   vendored_frameworks = build/core/flame_sdk_ios.xcframework（同一份 Core）
#   source_files        = TB 平台源码（FlameTBProvider + TbRewardAdapter）
#
# 头文件策略同 TK podspec：Core binary 不暴露的内部头在此作为 private_header_files
# 提供，只给声明、不重新编译实现（实现已在 Core binary 内）。
#
# 依赖说明（与正式 flame_sdk_ios_tb.podspec 的关键差异）：
#   正式 TB 包是「自包含」模式 —— build/tb binary 已静态内置 WindMill（3621 符号），
#   因此正式 podspec 不再声明 ToBid-iOS-RC，否则 duplicate class。
#   而本实验是「Thin Core + 源码插件」模式 —— Core binary 不含 WindMill，
#   TB 插件源码（FlameTBProvider.m / TbRewardAdapter.m）需要 import
#   <WindMillSDK/WindMillSDK.h> 才能编译，因此必须声明 ToBid-iOS-RC 依赖，
#   让 WindMill 在接入方 App 运行时动态/静态提供。这是两种模式的核心区别。
#
# 宏注入：
#   FLAME_BUILD_TB=1   → TB 平台源码 #if 守卫为真
#   FLAME_PLUGIN_TB=1  → FlameTBProvider +load 自动注册启用
# ============================================================
Pod::Spec.new do |s|
  s.name             = 'flame_sdk_ios_tb'
  s.version          = '0.1.8.5-thin-core-exp'
  s.summary          = 'Flame iOS Ad SDK - Thin Core TB Experiment'
  s.description      = 'Flame iOS Ad SDK, Thin Core + TB platform source plugin (experiment).'
  s.homepage         = 'https://github.com/javaice007/flame_sdk_ios'
  s.author           = { 'flame' => 'flame@toowe.com' }

  s.source           = {
    :http => "https://github.com/javaice007/flame_sdk_ios/archive/refs/tags/#{s.version}.zip"
  }

  s.license = {
    :type => 'Commercial',
    :text => 'Copyright Flame'
  }

  s.ios.deployment_target = '13.0'
  s.swift_version = '5.0'

  # ========= TB 平台源码插件 =========
  # Phase 5A：只编译 Reward（Splash/Interstitial/Banner/Native 返回 nil，Phase 6 补齐）
  # 注意：本 pod 不直接放 vendored_frameworks（Core binary 由 flame_sdk_ios pod 提供，
  # 通过下方 dependency 'flame_sdk_ios' 拉入）。若本 pod 也声明 vendored_frameworks，
  # 会与 Core pod 同时 embed 同一份 flame_sdk_ios.framework → Multiple commands produce。
  s.source_files = [
    'flame_sdk_ios/mediation/tb/**/*.{h,m}',
    'flame_sdk_ios/adapter/tb/**/*.{h,m}'
  ]

  # ========= 内部头（声明供插件 import，实现已在 Core binary）=========
  s.private_header_files = [
    'flame_sdk_ios/mediation/FlameMediationProvider.h',
    'flame_sdk_ios/mediation/FlameMediationRegistry.h',
    'flame_sdk_ios/mediation/FlameMediationRouter.h',
    'flame_sdk_ios/mediation/FlameRewardAdapterProtocol.h',
    'flame_sdk_ios/mediation/FlameSplashAdapterProtocol.h',
    'flame_sdk_ios/mediation/FlameInterstitialAdapterProtocol.h',
    'flame_sdk_ios/mediation/FlameBannerAdapterProtocol.h',
    'flame_sdk_ios/mediation/FlameNativeAdapterProtocol.h',
    'flame_sdk_ios/core/FlameErrorCode.h',
    'flame_sdk_ios/core/FlameLogger.h',
    'flame_sdk_ios/core/FlameConfigManager.h',
    'flame_sdk_ios/adapter/FlameAdapterManager.h'
  ]

  # ========= Core binary（通过依赖拉入）=========
  # 不在本 pod 直接放 vendored_frameworks，而是依赖 flame_sdk_ios pod，
  # 让 Core binary 的 flame_sdk_ios 模块对插件 target 可见（与 TK 插件同构）。
  s.dependency 'flame_sdk_ios'

  # ========= 依赖 =========
  s.dependency 'OpenSSL-Universal', '~> 3.6'
  # Thin Core 模式：WindMill 不在 binary 内，需声明 ToBid-iOS-RC 供 TB 源码编译/运行
  s.dependency 'ToBid-iOS-RC', '5.5.6'

  # 禁止依赖（红线）：
  #   - 不依赖 AnyThinkiOS / AnyThinkMediation* / TK adapter
  #   - 不依赖 flame_sdk_ios（避免带入 TK）

  s.pod_target_xcconfig = {
    'OTHER_LDFLAGS' => '$(inherited) -ObjC',
    'OTHER_CFLAGS'  => '$(inherited) -DFLAME_BUILD_TB=1 -DFLAME_PLUGIN_TB=1',
    'HEADER_SEARCH_PATHS' => '$(inherited) "${PODS_TARGET_SRCROOT}/flame_sdk_ios/mediation" "${PODS_TARGET_SRCROOT}/flame_sdk_ios/mediation/tb" "${PODS_TARGET_SRCROOT}/flame_sdk_ios/core" "${PODS_TARGET_SRCROOT}/flame_sdk_ios/adapter" "${PODS_TARGET_SRCROOT}/flame_sdk_ios/adapter/tb" "${PODS_TARGET_SRCROOT}/flame_sdk_ios/ads/reward" "${PODS_TARGET_SRCROOT}/flame_sdk_ios/ads/splash" "${PODS_TARGET_SRCROOT}/flame_sdk_ios/ads/interstitial" "${PODS_TARGET_SRCROOT}/flame_sdk_ios/ads/banner" "${PODS_TARGET_SRCROOT}/flame_sdk_ios/ads/nativate"',
    'DEFINES_MODULE' => 'YES'
  }
end
