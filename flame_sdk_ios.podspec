# ============================================================
# Flame iOS Ad SDK — TK 客户 podspec（Phase 5A.12 single-binary mainline）
# ------------------------------------------------------------
# 单二进制架构：flame_sdk_ios.xcframework 同时内置 Flame core + TK/TB Provider/Adapter 胶水。
#
# 本 podspec（flame_sdk_ios）面向 TK 客户：
#   - 引用同一个 flame_sdk_ios.xcframework（与 flame_sdk_ios_tb.podspec 共用）
#   - 公共平台核心依赖：OpenSSL + AnyThinkiOS + ToBid-iOS-RC（两个 podspec 都声明）
#   - 差异化广告源依赖：TK 广告源 SDK + Adapter（AnyThinkMediation* / AdGain / FSUnion）
#
# 接入方 import 保持不变（module name = flame_sdk_ios）：
#   ObjC:  #import <flame_sdk_ios/flame_sdk_ios.h>
#          #import <flame_sdk_ios/FlameSdk.h>
#   Swift: import flame_sdk_ios
#
# 客户只写一行：
#   pod 'flame_sdk_ios'        # TK 客户
#
# 推荐 Podfile：
#   use_frameworks! :linkage => :static
#   pod 'flame_sdk_ios'
# ============================================================
Pod::Spec.new do |s|
  s.name             = 'flame_sdk_ios'
  s.version          = '1.0.0-alpha.5'
  s.module_name      = 'flame_sdk_ios'
  s.summary          = 'Flame iOS Ad SDK - TK Edition (Single Binary)'
  s.description      = 'Flame iOS advertising aggregation SDK, single binary with TK/TB platform glue embedded. TK ads deps edition.'
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

  # ========= 单二进制 vendored xcframework =========
  # 一个 Mach-O 同时含 Flame core + TK Provider/Adapter + TB Provider/Adapter 胶水。
  # 两个 podspec（flame_sdk_ios / flame_sdk_ios_tb）共用同一份 binary。
  s.vendored_frameworks = 'flame_sdk_ios.xcframework'

  # ========= 公共平台核心依赖（与 flame_sdk_ios_tb.podspec 一致）=========
  # binary 动态依赖 OpenSSL（otool -L 可见 @rpath/OpenSSL.framework/OpenSSL），必须显式声明。
  s.dependency 'OpenSSL-Universal', '~> 3.6'

  # binary 动态依赖 AnyThinkSDK（otool -L 可见 @rpath/AnyThinkSDK.framework/AnyThinkSDK），必须显式声明。
  # AnyThinkSDK 是 TK 平台核心（MH_DYLIB），两个 podspec 都声明（TB 客户也需要，因为 binary 显式链接）。
  s.dependency 'AnyThinkiOS', '6.5.71'

  # ToBid-iOS-RC 是 TB 平台核心（WindMillSDK/WindSDK/WindFoundation 静态归档）。
  # binary 内的 TB 胶水（FlameTBProvider/TbRewardAdapter）通过 U 引用 WindMill 符号，
  # pt=tk 时永不会被调用（lazy binding 不解析即不崩），但作为公共平台核心依赖统一声明，
  # 为后续双线并存做准备（两个 podspec 都声明，差异只在广告源适配器）。
  s.dependency 'ToBid-iOS-RC', '5.5.6'

  # ========= 差异化广告源依赖（TK 专属）=========
  # TK 运行时广告源适配器（AnyThinkMediation*）+ 广告源 SDK（AdGain / FSUnion）
  s.dependency 'AnyThinkMediationAdxSmartdigimktCNAdapter', '6.5.72.2.1'
  s.dependency 'AnyThinkMediationGromoreAdapter', '7.6.0.4.2.0'
  s.dependency 'AnyThinkMediationBaiduAdapter', '10.050.2.1'
  s.dependency 'AnyThinkMediationMSAdapter', '2.7.18.1.2.0'
  s.dependency 'AnyThinkMediationZYAdapter', '2.6.4.29.2.0'
  s.dependency 'AnyThinkMediationFunlinkAdapter', '2.9.0.1.2.2.0'
  s.dependency 'AnyThinkMediationBeiZiAdapter', '5.5.0.3.2.0'
  s.dependency 'AnyThinkMediationKuaiShouAdapter', '5.4.10.1.2.0'
  # Phase 5A.12 Step 1f: Sigmob adapter 改为 flame_sdk_ios_tk_sigmob_adapter（与 flame_sdk_ios 命名风格统一）
  # 复用 TopOn AnyThinkSigmobAdapter.xcframework，去掉 SigmobAd-iOS 传递依赖，
  # WindSDK / WindFoundation 由 ToBid-iOS-RC 统一提供，避免与 ToBid-iOS-RC 的同名 framework 冲突。
  # 此 pod 当前在私有 spec repo javaice007-flame-specs 提供（pod repo push 后；本地实验在 research/local_specs）。
  s.dependency 'flame_sdk_ios_tk_sigmob_adapter', '4.20.12.2.0'
  s.dependency 'AnyThinkMediationTTAdapter_Mix', '7.6.0.4.2.0'
  s.dependency 'AnyThinkMediationGDTAdapter', '4.15.90.2.0'

  # AdGain 广告 SDK + Taku/TopOn 适配器
  s.dependency 'AdGainSDK', '4.2.7.1'
  s.dependency 'AdGainSDKTakuAdapter', '4.2.7.1'

  # 飞梭
  s.dependency 'FSUnionAdSDK', '1.0.8.0'

  # ========= xcconfig =========
  # 单二进制关键：仅 -ObjC，无需宏注入 / 头搜索路径（binary 已内置全部代码与符号）。
  # -ObjC 让 dyld 在加载 framework 时触发两个 +load 自动注册（FlameTKProvider + FlameTBProvider）。
  s.pod_target_xcconfig = {
    'OTHER_LDFLAGS' => '$(inherited) -ObjC'
  }

  s.user_target_xcconfig = {
    'OTHER_LDFLAGS' => '$(inherited) -ObjC'
  }
end
