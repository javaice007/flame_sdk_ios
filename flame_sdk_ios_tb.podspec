Pod::Spec.new do |s|
  s.name             = 'flame_sdk_ios_tb'
  s.version          = '0.1.8.5'
  s.summary          = 'Flame iOS Ad SDK - ToBid Edition'
  s.description      = 'Flame iOS advertising aggregation SDK, ToBid / WindMill edition.'
  s.homepage         = 'https://github.com/javaice007/flame_sdk_ios'
  s.author           = { 'flame' => 'flame@toowe.com' }

  s.source           = {
    :http => "https://github.com/javaice007/flame_sdk_ios/archive/refs/tags/#{s.version}.zip",
  }

  # 商业sdk
  s.license = {
    :type => 'Commercial',
    :text => 'Copyright Flame'
  }

  # 平台要求
  s.ios.deployment_target = '13.0'
  s.swift_version = '5.0'

  # Binary SDK — TB 变体产物（framework/module 名仍为 flame_sdk_ios，接入方 import 不变）
  # 注意：flame_sdk_ios 与 flame_sdk_ios_tb 互斥，不能同时接入
  #
  # 分发模式：自包含二进制包（方案 A）
  #   build/tb/flame_sdk_ios.xcframework 已静态内置 WindMillSDK / WindSDK / WindFoundation
  #   （otool -L 无 WindMill 动态依赖；nm 显示 3621 个 WindMill 符号已链接进二进制）
  #   因此本 podspec 不再声明 ToBid-iOS-RC 依赖，否则下游会再次拉入 ToBid 导致 duplicate class
  s.vendored_frameworks = 'build/tb/flame_sdk_ios.xcframework'

  # ========= 依赖 =========
  # 只保留 OpenSSL（Flame core 加密需要）；ToBid/WindMill 已内置，不再声明
  s.dependency 'OpenSSL-Universal', '~> 3.6'

  # 禁止依赖（红线）：
  #   - 不依赖 flame_sdk_ios（避免带入 TK 依赖）
  #   - 不依赖 ToBid-iOS-RC（已静态内置，声明会导致 duplicate class）
  #   - 不依赖 AnyThinkiOS / AnyThinkMediationSigmobAdapter / SigmobAd-iOS / TK adapter

  # 注意：不要写 s.source_files，因为你不需要向用户分发源代码
  s.pod_target_xcconfig = {
    'OTHER_LDFLAGS' => '-ObjC',
    'DEFINES_MODULE' => 'YES'
  }
end
