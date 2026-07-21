# ============================================================
# Flame iOS Ad SDK — TK 客户 podspec
# ------------------------------------------------------------
# 单二进制架构：flame_sdk_ios.xcframework 同时内置 Flame core +
# TK/TB Provider/Adapter 胶水，由 pt 字段在运行时动态选择激活。
#
# 本 podspec（flame_sdk_ios）面向 TK（TopOn/AnyThink）客户。
# TB（ToBid）客户使用 flame_sdk_ios_tb.podspec，二者互斥不可同时接入。
# 两个 podspec 共用同一份 flame_sdk_ios.xcframework，module_name 均为 flame_sdk_ios。
#
# 接入方：
#   pod 'flame_sdk_ios'
#   import flame_sdk_ios
# ============================================================
Pod::Spec.new do |s|
  s.name             = 'flame_sdk_ios'
  s.version          = '1.0.0-alpha.2'
  s.module_name      = 'flame_sdk_ios'
  s.summary          = 'Flame iOS Ad SDK - TK Edition (Single Binary)'
  s.description      = 'Flame iOS advertising aggregation SDK, single binary with TK/TB platform glue embedded. TK ads deps edition.'
  s.homepage         = 'https://github.com/javaice007/flame_sdk_ios'
  s.author           = { 'flame' => 'flame@toowe.com' }

  # 通过二进制分发仓库 javaice007/flame_sdk_ios 的 Tag 拉取，
  # TK/TB 两个 podspec 共用同一 Tag 和同一份 flame_sdk_ios.xcframework。
  s.source = { :git => 'https://github.com/javaice007/flame_sdk_ios.git', :tag => s.version.to_s }

  s.license = {
    :type => 'Commercial',
    :text => 'Copyright Flame'
  }

  s.ios.deployment_target = '13.0'
  s.swift_version = '5.0'

  # ========= 单二进制 vendored xcframework =========
  # 与 flame_sdk_ios_tb.podspec 共用同一份 binary，位于二进制仓库根目录。
  s.vendored_frameworks = 'flame_sdk_ios.xcframework'

  # ========= 公共平台核心依赖 =========
  # binary 动态依赖 OpenSSL（otool -L 可见 @rpath/OpenSSL.framework/OpenSSL）。
  s.dependency 'OpenSSL-Universal', '~> 3.6'

  # AnyThinkiOS 仅由 TK podspec 带入；binary 对 AnyThinkSDK 使用 LC_LOAD_WEAK_DYLIB，
  # TB 客户不接入 AnyThinkiOS，dyld 跳过加载即可。
  s.dependency 'AnyThinkiOS', '6.5.71'

  # ToBid-iOS-RC 是 TB 平台核心；TK podspec 同样声明，因为 binary 内含 TB 胶水
  # 符号引用，pt=tb 时由 ToBid-iOS-RC 解析；pt=tk 时不会触发。
  s.dependency 'ToBid-iOS-RC', '5.5.6'

  # ========= TK 广告源 Adapter + 底层 SDK =========
  s.dependency 'AnyThinkMediationAdxSmartdigimktCNAdapter', '6.5.72.2.1'
  s.dependency 'AnyThinkMediationGromoreAdapter', '7.6.0.4.2.0'
  s.dependency 'AnyThinkMediationBaiduAdapter', '10.050.2.1'
  s.dependency 'AnyThinkMediationMSAdapter', '2.7.18.1.2.0'
  s.dependency 'AnyThinkMediationZYAdapter', '2.6.4.29.2.0'
  s.dependency 'AnyThinkMediationFunlinkAdapter', '2.9.0.1.2.2.0'
  s.dependency 'AnyThinkMediationBeiZiAdapter', '5.5.0.3.2.0'
  s.dependency 'AnyThinkMediationKuaiShouAdapter', '5.4.10.1.2.0'
  # Flame 私有 spec：复用 TopOn AnyThinkSigmobAdapter.xcframework，去掉 SigmobAd-iOS
  # 传递依赖，WindSDK/WindFoundation 由 ToBid-iOS-RC 统一提供，避免同名 framework 冲突。
  s.dependency 'flame_sdk_ios_tk_sigmob_adapter', '4.20.12.2.0'
  s.dependency 'AnyThinkMediationTTAdapter_Mix', '7.6.0.4.2.0'
  s.dependency 'AnyThinkMediationGDTAdapter', '4.15.90.2.0'
  s.dependency 'AdGainSDK', '4.2.7.1'
  s.dependency 'AdGainSDKTakuAdapter', '4.2.7.1'
  s.dependency 'FSUnionAdSDK', '1.0.8.0'

  # ========= xcconfig =========
  # -ObjC 让 dyld 在加载 framework 时触发 +load 自动注册（FlameTKProvider / FlameTBProvider）。
  s.pod_target_xcconfig = {
    'OTHER_LDFLAGS' => '$(inherited) -ObjC'
  }

  s.user_target_xcconfig = {
    'OTHER_LDFLAGS' => '$(inherited) -ObjC'
  }
end
