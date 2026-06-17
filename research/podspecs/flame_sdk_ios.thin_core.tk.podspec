# ============================================================
# 实验性 podspec —— Thin Core + TK 平台源码插件（方案 C：插件独立 pod）
# ------------------------------------------------------------
# ⚠️ 仅 Phase 5A.10 Step 2 实验验证，不是正式发布 podspec。
# ⚠️ 不进 pod repo、不打 tag、不替换 flame_sdk_ios.podspec。
#
# 架构（方案 C：Core 与插件拆为两个 pod）：
#   1. flame_sdk_ios          （research/podspecs/flame_sdk_ios.core.podspec）
#      只放 Core binary，无源码，提供 flame_sdk_ios 模块（Core 公共 API）。
#   2. flame_sdk_ios_tk_plugin（本文件）
#      TK 平台源码（Provider + At*Adapter），dependency 'flame_sdk_ios'，
#      编译期合并进插件 target，+load 自动注册到 Core 的 Registry。
#
# 为什么拆两个 pod？
#   单 pod 同时持有 vendored_frameworks(flame_sdk_ios) + source_files 会触发
#   module 名冲突：源模块遮蔽 vendored framework 模块 → 接入方 import 失败。
#   拆开后 Core binary 模块 = flame_sdk_ios，插件源模块 = flame_sdk_ios_tk_plugin，
#   两者不冲突。接入方 Podfile 同时声明两个 pod 即可。
#
# 头文件策略：
#   Core binary Headers/ 只暴露 10 个公共 API（FlameSdk/FlameRewardAd...），
#   插件源码还需 12 个内部头（mediation 协议 + Core 内部头），由本 pod 的
#   private_header_files 从源码树提供声明（实现已在 Core binary 内，不重编译 .m）。
#
# 宏注入：
#   FLAME_BUILD_TK=1   → TK 平台源码 #if 守卫为真
#   FLAME_PLUGIN_TK=1  → 启用 FlameTKProvider +load 自动注册（仅插件模式）
# ============================================================
Pod::Spec.new do |s|
  s.name             = 'flame_sdk_ios_tk_plugin'
  s.version          = '0.1.8.5-thin-core-exp'
  s.summary          = 'Flame iOS Ad SDK - Thin Core TK Plugin Experiment'
  s.description      = 'Flame iOS Ad SDK, TK platform source plugin for Thin Core (experiment).'
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

  # ========= Core binary（通过依赖拉入）=========
  # 不在本 pod 直接放 vendored_frameworks，而是依赖 flame_sdk_ios pod，
  # 让 Core binary 的 flame_sdk_ios 模块对插件 target 可见。
  s.dependency 'flame_sdk_ios'

  # ========= TK 平台源码插件 =========
  s.source_files = [
    'flame_sdk_ios/mediation/tk/**/*.{h,m}',
    'flame_sdk_ios/adapter/tk/**/*.{h,m}'
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

  # ========= TK 运行时依赖（与正式 flame_sdk_ios.podspec 一致）=========
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

  # ========= 宏注入 + 头文件搜索路径 =========
  # HEADER_SEARCH_PATHS 必须显式声明：private_header_files 跨多个目录（mediation/,
  # core/, adapter/），CocoaPods 默认只为 source_files 所在目录加搜索路径，导致
  # adapter/tk/*.h 里的 #import "FlameRewardAdapterProtocol.h" 找不到 mediation/ 下
  # 的头。这里把三个目录都加入搜索路径。
  # 同时让插件能 import Core binary 的公共头（FlameRewardAd.h 等）：Core vendored
  # framework 的 Headers 在 framework search path 上，PODS_ROOT 指向 staging 根。
  s.pod_target_xcconfig = {
    'OTHER_LDFLAGS' => '$(inherited) -ObjC',
    'OTHER_CFLAGS'  => '$(inherited) -DFLAME_BUILD_TK=1 -DFLAME_PLUGIN_TK=1',
    'HEADER_SEARCH_PATHS' => '$(inherited) "${PODS_TARGET_SRCROOT}/flame_sdk_ios/mediation" "${PODS_TARGET_SRCROOT}/flame_sdk_ios/mediation/tk" "${PODS_TARGET_SRCROOT}/flame_sdk_ios/core" "${PODS_TARGET_SRCROOT}/flame_sdk_ios/adapter" "${PODS_TARGET_SRCROOT}/flame_sdk_ios/adapter/tk" "${PODS_TARGET_SRCROOT}/flame_sdk_ios/ads/reward" "${PODS_TARGET_SRCROOT}/flame_sdk_ios/ads/splash" "${PODS_TARGET_SRCROOT}/flame_sdk_ios/ads/interstitial" "${PODS_TARGET_SRCROOT}/flame_sdk_ios/ads/banner" "${PODS_TARGET_SRCROOT}/flame_sdk_ios/ads/nativate"',
    'DEFINES_MODULE' => 'YES'
  }
end
