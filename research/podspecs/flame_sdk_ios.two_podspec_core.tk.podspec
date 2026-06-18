# ============================================================
# 方案 D 实验 podspec —— TK（Two Public Podspecs + One Internal Core Binary）
# ------------------------------------------------------------
# ⚠️ 仅 Phase 5A.10 Step 2B 实验，不是正式发布 podspec。
#
# 目标：客户只写一行 pod 'flame_sdk_ios'
#   vendored_frameworks = build/core_named/flame_sdk_ios_core.xcframework（module=flame_sdk_ios_core）
#   source_files = TK 平台源码 + 转发头（pod 源模块=flame_sdk_ios）
#   两模块名不同 → 不遮蔽，单 pod 可共存
# ============================================================
Pod::Spec.new do |s|
  s.name             = 'flame_sdk_ios'
  s.version          = '0.1.8.6-two-podspec-exp'
  s.module_name      = 'flame_sdk_ios'
  s.summary          = 'Flame iOS Ad SDK - Two Podspec TK Experiment'
  s.description      = 'Flame iOS Ad SDK, single internal core binary + TK platform source (experiment).'
  s.homepage         = 'https://github.com/javaice007/flame_sdk_ios'
  s.author           = { 'flame' => 'flame@toowe.com' }

  s.source           = {
    :http => "https://github.com/javaice007/flame_sdk_ios/archive/refs/tags/#{s.version}.zip"
  }

  s.license = { :type => 'Commercial', :text => 'Copyright Flame' }
  s.ios.deployment_target = '13.0'
  s.swift_version = '5.0'

  # 内部 Core Binary（module = flame_sdk_ios_core，与 pod 名不同 → 不遮蔽）
  s.vendored_frameworks = 'build/core_named/flame_sdk_ios_core.xcframework'

  # 转发头：接入方 #import <flame_sdk_ios/FlameSdk.h> 经此转发到 <flame_sdk_ios_core/FlameSdk.h>
  s.public_header_files = ['research/wrappers/flame_sdk_ios/*.h']

  # TK 平台源码 + 转发头
  s.source_files = [
    'research/wrappers/flame_sdk_ios/*.{h,m}',
    'flame_sdk_ios/mediation/tk/**/*.{h,m}',
    'flame_sdk_ios/adapter/tk/**/*.{h,m}'
  ]

  # TK 运行时依赖（与正式 flame_sdk_ios.podspec 一致）
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

  # 宏注入 + 内部协议头搜索路径（从 vendored core binary Headers 解析）
  # 关键：Swift 显式模块扫描(clang dependency scanning)对 vendored framework 的
  # 解析比传统编译更严格。需要显式 -F 指向 staging 后的 flame_sdk_ios_core.framework
  # 所在目录，否则扫描期找不到 <flame_sdk_ios_core/...> 模块。
  s.pod_target_xcconfig = {
    'OTHER_LDFLAGS' => '$(inherited) -ObjC',
    'OTHER_CFLAGS'  => '$(inherited) -DFLAME_BUILD_TK=1 -DFLAME_PLUGIN_TK=1 -F${PODS_XCFRAMEWORKS_BUILD_DIR}/flame_sdk_ios',
    'OTHER_CPLUSPLUSFLAGS' => '$(inherited) -F${PODS_XCFRAMEWORKS_BUILD_DIR}/flame_sdk_ios',
    # FRAMEWORK_SEARCH_PATHS: 让 pod 编译期能找到 vendored flame_sdk_ios_core 模块
    'FRAMEWORK_SEARCH_PATHS' => '$(inherited) "${PODS_XCFRAMEWORKS_BUILD_DIR}/flame_sdk_ios"',
    # HEADER_SEARCH_PATHS: 内部协议头（#import "FlameMediationRegistry.h" 等）
    'HEADER_SEARCH_PATHS' => '$(inherited) "${PODS_XCFRAMEWORKS_BUILD_DIR}/flame_sdk_ios/flame_sdk_ios_core.framework/Headers"',
    'DEFINES_MODULE' => 'YES'
  }
end
