# ============================================================
# Flame iOS Ad SDK — TB 正式 podspec（方案 D）
# ------------------------------------------------------------
# Phase 5A.10 Step 3 正式化：两个对外 podspec + 一个内部 core binary。
#
# 客户只写一行：
#   pod 'flame_sdk_ios_tb'     # TB 客户（与 flame_sdk_ios 互斥，不能同时接入）
#
# 关键：pod 名是 flame_sdk_ios_tb，但 module name 统一为 flame_sdk_ios。
#   这样 TB 客户接入方代码仍可 `import flame_sdk_ios`（与 TK 客户一致），
#   无需因 pod 名是 flame_sdk_ios_tb 而改 import。
#   pod 名决定客户 Podfile 写什么；module name 决定 import 写什么。
#
# 内部架构（与 TK podspec 对称）：
#   vendored_frameworks = flame_sdk_ios_core.xcframework（发布仓库根目录，同一份 core binary）
#   source_files = 正式转发头 + TB 平台源码（FlameTBProvider + TbRewardAdapter）
#     - 转发头将 #import <flame_sdk_ios/...> 转发到 <flame_sdk_ios_core/...>
#     - TB 源码注入 FLAME_PLUGIN_TB 宏，编译出 +load 自动注册 FlameTBProvider
#
# 红线：
#   - 不依赖 AnyThinkiOS / AnyThinkMediation* / SigmobAd-iOS（这些是 TK 专属）
#   - 不依赖 flame_sdk_ios（避免带入 TK 依赖）
#   - 必须显式依赖 OpenSSL（core binary 动态依赖，否则真机 dyld crash）
#
# 推荐 Podfile：
#   use_frameworks! :linkage => :static
#   pod 'flame_sdk_ios_tb', :path => '...' 或远端
# ============================================================
Pod::Spec.new do |s|
  s.name             = 'flame_sdk_ios_tb'
  s.version          = '1.0.0-alpha.1'
  s.module_name      = 'flame_sdk_ios'
  s.summary          = 'Flame iOS Ad SDK - ToBid Edition'
  s.description      = 'Flame iOS advertising aggregation SDK, ToBid / WindMill edition (Scheme D: single internal core binary + TB platform source).'
  s.homepage         = 'https://github.com/javaice007/flame_sdk_ios'
  s.author           = { 'flame' => 'flame@toowe.com' }

  s.source           = {
    :http => "https://github.com/javaice007/flame_sdk_ios/archive/refs/tags/#{s.version}.zip",
  }

  # 商业 sdk
  s.license = {
    :type => 'Commercial',
    :text => 'Copyright Flame'
  }

  # 平台要求
  s.ios.deployment_target = '13.0'
  s.swift_version = '5.0'

  # ========= 内部 Core Binary（与 TK podspec 共用同一份）=========
  # 零三方符号，仅 OpenSSL + 系统库依赖。
  # 发布产物路径：flame_sdk_ios_core.xcframework（发布仓库根目录）
  s.vendored_frameworks = 'flame_sdk_ios_core.xcframework'

  # ========= 转发头（对外公共 API，转发到 core binary）=========
  # 接入方 #import <flame_sdk_ios/FlameSdk.h> 经此转发到 <flame_sdk_ios_core/FlameSdk.h>
  # （module_name 统一为 flame_sdk_ios，转发头目录虽叫 flame_sdk_ios_tb，
  #   但接入方 import 走的是 module name，不受目录名影响）
  s.public_header_files = ['flame_sdk_ios/wrappers/flame_sdk_ios_tb/*.h']

  # ========= 源码（转发头 + TB 平台源码：FlameTBProvider + TbRewardAdapter）=========
  # Phase 5A：TB 仅实现 Reward；Splash/Interstitial/Banner/Native 仍为 nil 占位（后续 Phase 6）
  s.source_files = [
    'flame_sdk_ios/wrappers/flame_sdk_ios_tb/*.{h,m,mm}',
    'flame_sdk_ios/mediation/tb/**/*.{h,m,mm}',
    'flame_sdk_ios/adapter/tb/**/*.{h,m,mm}'
  ]

  # TB 内部协议/适配器头为私有
  s.private_header_files = [
    'flame_sdk_ios/mediation/tb/**/*.h',
    'flame_sdk_ios/adapter/tb/**/*.h'
  ]

  # ========= 依赖 =========
  # Core binary 动态依赖 OpenSSL，必须显式声明（TB 只有 ToBid，不靠 AnyThink 传递）。
  s.dependency 'OpenSSL-Universal', '~> 3.6'

  # TB 运行时依赖：WindMill 不在 binary 内，需声明 ToBid-iOS-RC 供 TB 源码编译/运行。
  s.dependency 'ToBid-iOS-RC', '5.5.6'

  # 红线：不依赖 AnyThinkiOS / AnyThinkMediationSigmobAdapter / SigmobAd-iOS / TK adapter

  # ========= pod_target_xcconfig（与 TK podspec 对称，仅宏不同）=========
  # 注意：-F 路径是 ${PODS_XCFRAMEWORKS_BUILD_DIR}/flame_sdk_ios（不是 flame_sdk_ios_tb），
  # 因为 CocoaPods 把 vendored framework 统一 staging 到 PODS_XCFRAMEWORKS_BUILD_DIR 下的
  # pod name 子目录；TB pod name 是 flame_sdk_ios_tb，所以 staging 目录也是这个名字。
  # （Step 2B 实测：TB 的 staging 目录是 flame_sdk_ios_tb/，故 -F 指向它）
  s.pod_target_xcconfig = {
    'OTHER_LDFLAGS' => '$(inherited) -ObjC',
    'OTHER_CFLAGS'  => '$(inherited) -DFLAME_BUILD_TB=1 -DFLAME_PLUGIN_TB=1 -F${PODS_XCFRAMEWORKS_BUILD_DIR}/flame_sdk_ios_tb',
    'OTHER_CPLUSPLUSFLAGS' => '$(inherited) -F${PODS_XCFRAMEWORKS_BUILD_DIR}/flame_sdk_ios_tb',
    'FRAMEWORK_SEARCH_PATHS' => '$(inherited) "${PODS_XCFRAMEWORKS_BUILD_DIR}/flame_sdk_ios_tb"',
    'HEADER_SEARCH_PATHS' => '$(inherited) "${PODS_XCFRAMEWORKS_BUILD_DIR}/flame_sdk_ios_tb/flame_sdk_ios_core.framework/Headers"',
    'DEFINES_MODULE' => 'YES'
  }
end
