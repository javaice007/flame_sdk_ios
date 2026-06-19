# ============================================================
# Flame iOS Ad SDK — 单二进制 + TK 广告源依赖实验 podspec（Phase 5A.12）
# ------------------------------------------------------------
# 与 Phase 5A.11 三包方案（Scheme E）不同，这是 Phase 5A.12 单二进制方案：
#   - 一个 flame_sdk_ios.xcframework 同时内置 Flame core + TK Provider/Adapter + TB Provider/Adapter
#   - 同一个 Mach-O 内两个 +load 都会注册（FLAME_PLUGIN_TK + FLAME_PLUGIN_TB）
#   - podspec 无需 source_files / 宏注入（binary 已内置全部代码与符号）
#   - 仅需 -ObjC 让 dyld 在加载 framework 时触发 +load 自动注册
#
# 与 flame_sdk_ios_tb 单二进制 podspec 的唯一区别：广告源依赖。
#   本 podspec：拉 TK 广告源适配器依赖（AnyThinkiOS + Mediation + AdGain + FSUnion）
#              不拉 TB 广告源适配器依赖（ToBid-iOS-RC）
#
# 重要：单二进制同时含 TK 和 TB 平台代码，但 TB 代码不会被激活：
#   - +load 注册 FlameTBProvider 到 Registry（platformCode=tb）
#   - FlameSdk.initSDK 根据 pt（服务端下发）激活对应 Provider
#   - pt=tk 时只激活 FlameTKProvider，FlameTBProvider 闲置但不影响
#   - TB 代码的 WindMill U 引用在 dylib 加载时由 LC_DYLD_INFO_BIND 解析，
#     但 ToBid-iOS-RC 未接入时，这些绑定会延迟到方法实际被调用时才解析（lazy binding）。
#     因为 pt=tk 永远不会调用 FlameTBProvider.initializeWithAppId，所以不会触发崩溃。
#
# 版本：1.0.0-alpha.4-local（Phase 5A.12 单二进制本地实验，不 push GitHub）
#
# 客户接入（Demo 验证用）：
#   use_frameworks! :linkage => :static
#   pod 'flame_sdk_ios', :podspec => '/Users/.../research/podspecs/single_binary/flame_sdk_ios.single_binary.local.podspec'
# ============================================================
Pod::Spec.new do |s|
  s.name             = 'flame_sdk_ios'
  s.version          = '1.0.0-alpha.4-local'
  s.module_name      = 'flame_sdk_ios'
  s.summary          = 'Flame iOS Ad SDK - Single Binary (TK ads deps, local validation)'
  s.description      = 'Flame iOS advertising aggregation SDK, single binary with TK/TB platform code embedded. TK ads deps edition (Phase 5A.12 local validation).'
  s.homepage         = 'https://github.com/javaice007/flame_sdk_ios'
  s.author           = { 'flame' => 'flame@toowe.com' }

  # 本地实验 podspec，source 仅占位（实际通过 :podspec => 本地路径接入，不走 git）
  s.source           = { :git => 'https://github.com/javaice007/flame_sdk_ios', :tag => s.version.to_s }

  s.license = {
    :type => 'Commercial',
    :text => 'Copyright Flame'
  }

  s.ios.deployment_target = '13.0'
  s.swift_version = '5.0'

  # ========= vendored xcframework（单二进制，含 TK+TB 平台代码）=========
  # 路径：相对 podspec 文件所在目录，指向 SDK repo build/ 顶层产物
  # podspec 在 research/podspecs/single_binary/，build/ 在 repo 根，所以相对路径是 ../../../build/
  s.vendored_frameworks = '../../../build/flame_sdk_ios.xcframework'

  # ========= 依赖 =========
  # Flame binary 动态依赖 OpenSSL（otool -L 可见 @rpath/OpenSSL.framework/OpenSSL），必须显式声明
  s.dependency 'OpenSSL-Universal', '~> 3.6'

  # Flame binary 动态依赖 AnyThinkSDK（otool -L 可见 @rpath/AnyThinkSDK.framework/AnyThinkSDK），必须显式声明
  s.dependency 'AnyThinkiOS', '6.5.71'

  # TK 运行时广告源适配器依赖（与 alpha.2 / alpha.3 完全一致，确保 TK 功能完整）
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

  # 红线：不依赖 ToBid-iOS-RC（TB 广告源依赖不在此 podspec）
  # 二进制中 FlameTBProvider/TbRewardAdapter 已注册，但 pt=tk 时不会被激活，
  # WindMill U 引用通过 lazy binding 解析，不会因 ToBid 缺失而崩溃。

  # ========= xcconfig =========
  # 单二进制关键：仅 -ObjC，无需宏注入 / 头搜索路径（binary 已内置全部）
  # -ObjC 让 linker 在静态包装阶段保留并触发两个 +load 自动注册
  s.pod_target_xcconfig = {
    'OTHER_LDFLAGS' => '$(inherited) -ObjC'
  }

  s.user_target_xcconfig = {
    'OTHER_LDFLAGS' => '$(inherited) -ObjC'
  }
end
