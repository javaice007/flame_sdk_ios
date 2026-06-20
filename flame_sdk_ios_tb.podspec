# ============================================================
# Flame iOS Ad SDK — TB 客户 podspec（Phase 5A.12 single-binary mainline）
# ------------------------------------------------------------
# 单二进制架构：flame_sdk_ios.xcframework 同时内置 Flame core + TK/TB Provider/Adapter 胶水。
#
# 本 podspec（flame_sdk_ios_tb）面向 TB 客户：
#   - 引用同一个 flame_sdk_ios.xcframework（与 flame_sdk_ios.podspec 共用）
#   - 公共平台核心依赖：OpenSSL + AnyThinkiOS + ToBid-iOS-RC（两个 podspec 都声明）
#   - 差异化广告源依赖：当前为空（TB Reward 阶段使用 ToBid-iOS-RC 默认 ToBidSDK 子规范）
#     后续接 TB Splash/Interstitial/Banner/Native 时再加 ToBid-iOS-RC/<Adapter> 子规范
#
# 关键：pod 名是 flame_sdk_ios_tb，但 module name 统一为 flame_sdk_ios。
#   TB 客户接入方代码仍可 `import flame_sdk_ios`（与 TK 客户一致）。
#   pod 名决定客户 Podfile 写什么；module name 决定 import 写什么。
#
# 客户只写一行：
#   pod 'flame_sdk_ios_tb'     # TB 客户（与 flame_sdk_ios 互斥，不能同时接入）
#
# 推荐 Podfile：
#   use_frameworks! :linkage => :static
#   pod 'flame_sdk_ios_tb'
# ============================================================
Pod::Spec.new do |s|
  s.name             = 'flame_sdk_ios_tb'
  s.version          = '1.0.0-alpha.5'
  s.module_name      = 'flame_sdk_ios'
  s.summary          = 'Flame iOS Ad SDK - TB Edition (Single Binary)'
  s.description      = 'Flame iOS advertising aggregation SDK, single binary with TK/TB platform glue embedded. TB ads deps edition.'
  s.homepage         = 'https://github.com/javaice007/flame_sdk_ios'
  s.author           = { 'flame' => 'flame@toowe.com' }

  # GitHub archive zip 默认不剥除顶层版本目录，必须显式 :flatten => true
  s.source = { :git => 'https://github.com/javaice007/flame_sdk_ios.git', :tag => s.version.to_s }

  # 商业 sdk
  s.license = {
    :type => 'Commercial',
    :text => 'Copyright Flame'
  }

  # 平台要求
  s.ios.deployment_target = '13.0'
  s.swift_version = '5.0'

  # ========= 单二进制 vendored xcframework（与 TK podspec 共用同一份）=========
  s.vendored_frameworks = 'flame_sdk_ios.xcframework'

  # ========= 公共平台核心依赖（与 flame_sdk_ios.podspec 一致）=========
  # binary 动态依赖 OpenSSL（otool -L 可见 @rpath/OpenSSL.framework/OpenSSL），必须显式声明。
  s.dependency 'OpenSSL-Universal', '~> 3.6'

  # binary 动态依赖 AnyThinkSDK（otool -L 可见 @rpath/AnyThinkSDK.framework/AnyThinkSDK），必须显式声明。
  # 即使 pt=tb 永不调用 TK 代码，dyld 启动时仍需找到 AnyThinkSDK.framework（LC_LOAD_DYLIB 硬依赖）。
  # 两个 podspec 都声明，作为公共平台核心依赖。
  s.dependency 'AnyThinkiOS', '6.5.71'

  # ToBid-iOS-RC 是 TB 平台核心（WindMillSDK/WindSDK/WindFoundation 静态归档）。
  # binary 内的 TB 胶水（FlameTBProvider/TbRewardAdapter）通过 U 引用 WindMill 符号，
  # pt=tb 调用 FlameTBProvider.initializeWithAppId 时由 ToBid-iOS-RC 解析。
  s.dependency 'ToBid-iOS-RC', '5.5.6'

  # ========= 差异化广告源依赖（TB 专属，当前为空）=========
  # 当前 TB Reward 阶段使用 ToBid-iOS-RC 默认 ToBidSDK 子规范（已含 WindMill 核心）。
  # 后续 Phase 5A.13+ 接 TB Splash/Interstitial/Banner/Native 时，按需增加：
  #   s.dependency 'ToBid-iOS-RC/CSJAdapter', '...'
  #   s.dependency 'ToBid-iOS-RC/GDTAdapter', '...'
  #   ...（ToBid-iOS-RC 的 21 个 Adapter 子规范）

  # 红线：不依赖 AnyThinkMediation* / AdGain / FSUnion（TK 广告源适配器不在此 podspec）

  # ========= xcconfig（与 TK podspec 完全一致）=========
  s.pod_target_xcconfig = {
    'OTHER_LDFLAGS' => '$(inherited) -ObjC'
  }

  s.user_target_xcconfig = {
    'OTHER_LDFLAGS' => '$(inherited) -ObjC'
  }
end
