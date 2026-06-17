# ============================================================
# 实验性 podspec —— Thin Core Binary（方案 C：Core 独立 pod）
# ------------------------------------------------------------
# ⚠️ 仅 Phase 5A.10 Step 2 实验验证，不是正式发布 podspec。
#
# 作用：
#   只承载 build/core/flame_sdk_ios.xcframework，不编译任何源码。
#   pod 名 = vendored framework 名 = flame_sdk_ios，因此接入方
#   import flame_sdk_ios 解析到 Core binary 自带的 flame_sdk_ios 模块。
#
# 为什么 TK/TB 插件 podspec 不能直接放 vendored_frameworks？
#   若 TK 插件 pod（含 source_files）同时持有同名 vendored framework，
#   use_frameworks! + DEFINES_MODULE=YES 会用源码编出同名源模块，遮蔽
#   vendored framework 模块 → #import <flame_sdk_ios/FlameSdk.h> 失败。
#   因此 Core 必须独立成 pod，插件 pod 通过 dependency 'flame_sdk_ios' 引用它，
#   让 Core binary 的 flame_sdk_ios 模块对插件 target 和接入方 App 都可见。
# ============================================================
Pod::Spec.new do |s|
  s.name             = 'flame_sdk_ios'
  s.version          = '0.1.8.5-thin-core-exp'
  s.summary          = 'Flame iOS Ad SDK - Thin Core (experiment)'
  s.description      = 'Flame iOS Ad SDK, platform-neutral Thin Core binary (experiment).'
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

  # 只放 Core binary，不编译任何源码 —— 让 vendored framework 自带的 flame_sdk_ios
  # 模块（umbrella = flame_sdk_ios.h）成为本 pod 的对外模块。
  s.vendored_frameworks = 'build/core/flame_sdk_ios.xcframework'

  # Core binary 只动态依赖 OpenSSL；平台源码依赖由插件 pod 各自声明。
  s.dependency 'OpenSSL-Universal', '~> 3.6'

  # 注意：不写 source_files / private_header_files，避免触发源模块。
  # 插件 pod 通过 dependency 'flame_sdk_ios' 拉入 Core binary 后，
  # Core binary 的 Headers/ 在插件 target 的 framework search path 上可见，
  # 插件源码可 import Core 公共头；私有协议头由插件 pod 自己的 private_header_files 提供。
  s.pod_target_xcconfig = {
    'OTHER_LDFLAGS' => '$(inherited) -ObjC',
    'DEFINES_MODULE' => 'YES'
  }
end
