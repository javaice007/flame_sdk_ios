# ============================================================
# 方案 D 实验 podspec —— TB（Two Public Podspecs + One Internal Core Binary）
# ------------------------------------------------------------
# ⚠️ 仅 Phase 5A.10 Step 2B 实验，不是正式发布 podspec。
#
# 目标：客户只写一行 pod 'flame_sdk_ios_tb'
#   vendored_frameworks = build/core_named/flame_sdk_ios_core.xcframework（module=flame_sdk_ios_core）
#   source_files = TB 平台源码（FlameTBProvider + TbRewardAdapter）+ 转发头（pod 源模块=flame_sdk_ios_tb）
#   两模块名不同 → 不遮蔽，单 pod 可共存
# ============================================================
Pod::Spec.new do |s|
  s.name             = 'flame_sdk_ios_tb'
  s.version          = '0.1.8.6-two-podspec-exp'
  # 关键：module name 统一为 flame_sdk_ios（与 pod 名不同）。
  # 这样 TB 客户接入方代码仍可 `import flame_sdk_ios`（与 TK 客户一致），
  # 无需因 pod 名是 flame_sdk_ios_tb 而改 import。
  # pod 名(flame_sdk_ios_tb)决定客户 Podfile 写什么；module name(flame_sdk_ios)决定 import 写什么。
  s.module_name      = 'flame_sdk_ios'
  s.summary          = 'Flame iOS Ad SDK - Two Podspec TB Experiment'
  s.description      = 'Flame iOS Ad SDK, single internal core binary + TB platform source (experiment).'
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

  # 转发头：接入方 #import <flame_sdk_ios_tb/FlameSdk.h> 经此转发到 <flame_sdk_ios_core/FlameSdk.h>
  s.public_header_files = ['research/wrappers/flame_sdk_ios_tb/*.h']

  # TB 平台源码（Phase 5A：只 Reward）+ 转发头
  s.source_files = [
    'research/wrappers/flame_sdk_ios_tb/*.{h,m}',
    'flame_sdk_ios/mediation/tb/**/*.{h,m}',
    'flame_sdk_ios/adapter/tb/**/*.{h,m}'
  ]

  # Core binary 动态依赖 OpenSSL（otool -L 显示 @rpath/OpenSSL.framework/OpenSSL），
  # 必须显式声明，否则 App 运行时 dyld 找不到 OpenSSL → crash。
  # TK podspec 靠 AnyThinkiOS 传递依赖 OpenSSL 能侥幸通过；TB 只有 ToBid，必须显式声明。
  s.dependency 'OpenSSL-Universal', '~> 3.6'

  # TB 运行时依赖：WindMill 不在 binary 内，需声明 ToBid-iOS-RC 供 TB 源码编译/运行
  s.dependency 'ToBid-iOS-RC', '5.5.6'

  # 宏注入 + 头搜索路径（同 TK podspec）
  s.pod_target_xcconfig = {
    'OTHER_LDFLAGS' => '$(inherited) -ObjC',
    'OTHER_CFLAGS'  => '$(inherited) -DFLAME_BUILD_TB=1 -DFLAME_PLUGIN_TB=1 -F${PODS_XCFRAMEWORKS_BUILD_DIR}/flame_sdk_ios',
    'OTHER_CPLUSPLUSFLAGS' => '$(inherited) -F${PODS_XCFRAMEWORKS_BUILD_DIR}/flame_sdk_ios',
    'FRAMEWORK_SEARCH_PATHS' => '$(inherited) "${PODS_XCFRAMEWORKS_BUILD_DIR}/flame_sdk_ios"',
    'HEADER_SEARCH_PATHS' => '$(inherited) "${PODS_XCFRAMEWORKS_BUILD_DIR}/flame_sdk_ios/flame_sdk_ios_core.framework/Headers"',
    'DEFINES_MODULE' => 'YES'
  }
end
