# ============================================================
# Flame iOS Ad SDK — 单二进制 + TB 广告源依赖实验 podspec（Phase 5A.12）
# ------------------------------------------------------------
# 与 Phase 5A.11 三包方案（Scheme E）不同，这是 Phase 5A.12 单二进制方案：
#   - 一个 flame_sdk_ios.xcframework 同时内置 Flame core + TK Provider/Adapter + TB Provider/Adapter
#   - 同一个 Mach-O 内两个 +load 都会注册（FLAME_PLUGIN_TK + FLAME_PLUGIN_TB）
#   - podspec 无需 source_files / 宏注入（binary 已内置全部代码与符号）
#   - 仅需 -ObjC 让 dyld 在加载 framework 时触发 +load 自动注册
#
# 与 flame_sdk_ios 单二进制 podspec 的唯一区别：广告源依赖。
#   本 podspec：拉 TB 广告源适配器依赖（ToBid-iOS-RC）
#              不拉 TK 广告源适配器依赖（AnyThinkiOS + Mediation + AdGain + FSUnion）
#
# 重要：单二进制同时含 TK 和 TB 平台代码，但 TK 代码不会被激活：
#   - +load 注册 FlameTKProvider 到 Registry（platformCode=tk）
#   - FlameSdk.initSDK 根据 pt（服务端下发）激活对应 Provider
#   - pt=tb 时只激活 FlameTBProvider，FlameTKProvider 闲置但不影响
#   - TK 代码的 AnyThink U 引用在 dylib 加载时由 LC_DYLD_INFO_BIND 解析，
#     但 AnyThinkiOS 未接入时，otool -L 显示的 @rpath/AnyThinkSDK.framework/AnyThinkSDK
#     会在 dyld 加载 flame_sdk_ios.framework 时找不到 → dyld crash！
#
#     这与 TB 侧的 WindMill 不同：WindMill 是 U 引用（dynamic_lookup），
#     不在 otool -L 的 LC_LOAD_DYLIB 里；而 AnyThinkSDK 是 binary 显式链接的动态依赖
#     （在 LC_LOAD_DYLIB），dyld 启动时必须能找到。
#
#     因此 TB podspec 必须仍然声明 AnyThinkiOS，否则 dyld 在加载 flame_sdk_ios.framework
#     时会因为找不到 @rpath/AnyThinkSDK.framework 而崩溃（哪怕 TK 代码不会被调用）。
#     这是单二进制方案的代价：binary 显式链接的动态依赖，无论是否使用，都必须在接入期提供。
#
# 版本：1.0.0-alpha.4-local（Phase 5A.12 单二进制本地实验，不 push GitHub）
#
# 客户接入（Demo 验证用）：
#   use_frameworks! :linkage => :static
#   pod 'flame_sdk_ios_tb', :podspec => '/Users/.../research/podspecs/single_binary/flame_sdk_ios_tb.single_binary.local.podspec'
# ============================================================
Pod::Spec.new do |s|
  s.name             = 'flame_sdk_ios_tb'
  s.version          = '1.0.0-alpha.4-local'
  s.module_name      = 'flame_sdk_ios'
  s.summary          = 'Flame iOS Ad SDK - Single Binary (TB ads deps, local validation)'
  s.description      = 'Flame iOS advertising aggregation SDK, single binary with TK/TB platform code embedded. TB ads deps edition (Phase 5A.12 local validation).'
  s.homepage         = 'https://github.com/javaice007/flame_sdk_ios'
  s.author           = { 'flame' => 'flame@toowe.com' }

  # 本地实验 podspec，source 仅占位
  s.source           = { :git => 'https://github.com/javaice007/flame_sdk_ios', :tag => s.version.to_s }

  s.license = {
    :type => 'Commercial',
    :text => 'Copyright Flame'
  }

  s.ios.deployment_target = '13.0'
  s.swift_version = '5.0'

  # ========= vendored xcframework（与 TK podspec 同一份单二进制）=========
  s.vendored_frameworks = '../../../build/flame_sdk_ios.xcframework'

  # ========= 依赖 =========
  # Flame binary 动态依赖 OpenSSL，必须显式声明
  s.dependency 'OpenSSL-Universal', '~> 3.6'

  # Flame binary 显式链接 AnyThinkSDK（otool -L 可见 @rpath/AnyThinkSDK.framework/AnyThinkSDK），
  # 即使 pt=tb 永不调用 TK 代码，dyld 启动时仍需找到 AnyThinkSDK.framework，否则崩溃。
  # 这是单二进制方案的代价：binary 显式动态依赖必须接入期提供。
  s.dependency 'AnyThinkiOS', '6.5.71'

  # TB 运行时广告源适配器依赖
  s.dependency 'ToBid-iOS-RC', '5.5.6'

  # 红线：不依赖 AnyThinkMediation* / AdGain / FSUnion（TK 广告源适配器不在此 podspec）
  # TK 代码仍存在 binary 内，但 pt=tb 时不会被激活，不影响 TB 链路。

  # ========= xcconfig（与 TK podspec 完全一致）=========
  s.pod_target_xcconfig = {
    'OTHER_LDFLAGS' => '$(inherited) -ObjC'
  }

  s.user_target_xcconfig = {
    'OTHER_LDFLAGS' => '$(inherited) -ObjC'
  }
end
