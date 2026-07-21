# ============================================================
# Flame iOS Ad SDK — TB 客户 podspec
# ------------------------------------------------------------
# 单二进制架构：flame_sdk_ios.xcframework 同时内置 Flame core +
# TK/TB Provider/Adapter 胶水，由 pt 字段在运行时动态选择激活。
#
# 本 podspec（flame_sdk_ios_tb）面向 TB（ToBid/WindMill）客户。
# TK（TopOn）客户使用 flame_sdk_ios.podspec，二者互斥不可同时接入。
# 两个 podspec 共用同一份 flame_sdk_ios.xcframework，module_name 均为 flame_sdk_ios。
#
# 接入方：
#   pod 'flame_sdk_ios_tb'
#   import flame_sdk_ios
# ============================================================
Pod::Spec.new do |s|
  s.name             = 'flame_sdk_ios_tb'
  s.version          = '1.0.0'
  s.module_name      = 'flame_sdk_ios'
  s.summary          = 'Flame iOS Ad SDK - TB Edition (Single Binary, AnyThink weak-linked)'
  s.description      = 'Flame iOS advertising aggregation SDK, single binary with TK/TB platform glue embedded. TB ads deps edition. AnyThinkSDK weak-linked (not bundled for TB customers).'
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

  # ========= 单二进制 vendored xcframework（与 TK podspec 共用同一份，位于二进制仓库根目录）=========
  s.vendored_frameworks = 'flame_sdk_ios.xcframework'

  # ========= 公共平台核心依赖 =========
  # binary 动态依赖 OpenSSL（otool -L 可见 @rpath/OpenSSL.framework/OpenSSL）。
  s.dependency 'OpenSSL-Universal', '~> 3.6'

  # ToBid-iOS-RC 是 TB 平台核心（WindMillSDK/WindSDK/WindFoundation 静态归档）。
  # binary 内的 TB 胶水（FlameTBProvider / TbRewardAdapter / TbSplashAdapter /
  # TbInterstitialAdapter / TbBannerAdapter / TbNativeAdapter）通过 U 引用
  # WindMill 符号，pt=tb 时由 ToBid-iOS-RC 解析。
  s.dependency 'ToBid-iOS-RC', '5.5.6'

  # ========= TB 广告源 Adapter（全部 5.5.6）=========
  # Adapter 与底层三方 SDK 版本由 ToBid 官方 subspec 统一管理，Flame podspec
  # 不重复声明底层三方 SDK（单一来源）。
  #
  # Sigmob 由 ToBid Core 内置（WindSDK），无独立 Adapter subspec。

  s.dependency 'ToBid-iOS-RC/CSJAdapter', '5.5.6'        # 穿山甲
  s.dependency 'ToBid-iOS-RC/GDTAdapter', '5.5.6'        # 腾讯优量汇
  s.dependency 'ToBid-iOS-RC/BaiduAdapter', '5.5.6'      # 百度联盟
  s.dependency 'ToBid-iOS-RC/KSAdapter', '5.5.6'         # 快手
  s.dependency 'ToBid-iOS-RC/MintegralAdapter', '5.5.6'  # Mintegral（国内版）
  s.dependency 'ToBid-iOS-RC/OctopusAdapter', '5.5.6'    # 章鱼
  s.dependency 'ToBid-iOS-RC/MSAdAdapter', '5.5.6'       # 美数
  s.dependency 'ToBid-iOS-RC/GromoreAdapter', '5.5.6'    # GroMore（与 CSJ 共享 BUAdSDK）

  # ========= xcconfig =========
  # -ObjC 让 dyld 在加载 framework 时触发 +load 自动注册（FlameTKProvider / FlameTBProvider）。
  s.pod_target_xcconfig = {
    'OTHER_LDFLAGS' => '$(inherited) -ObjC'
  }

  s.user_target_xcconfig = {
    'OTHER_LDFLAGS' => '$(inherited) -ObjC'
  }
end

# ============================================================================
# 附录：长期有效的已知限制与依赖隔离说明
# ----------------------------------------------------------------------------
# 1. AnyThinkSDK 弱链接
#    Flame binary 对 AnyThinkSDK 使用 LC_LOAD_WEAK_DYLIB，缺失时 dyld 跳过加载。
#    TB 客户不接入 AnyThinkiOS，运行时不加载它（避免触发 AnyThinkiOS ADX 完整性
#    检测弹窗）。FlameTKProvider.initializeWithAppId 入口加 NSClassFromString(@"ATAPI")
#    守卫，pt=tk 但 AnyThink 缺失时返回明确错误回调。
#
# 2. Mintegral simulator slice 限制
#    WindMillMTGAdapter.xcframework 仅含 ios-arm64 slice（缺 simulator slice），
#    ToBid-iOS-RC 5.5.6 podspec 自带 EXCLUDED_ARCHS[sdk=iphonesimulator*]=arm64，
#    含义：Apple Silicon Mac simulator 需要 Rosetta；Intel simulator 与真机不受影响。
#    Flame podspec 不额外添加 EXCLUDED_ARCHS。
#
# 3. 红线（TB podspec 不得依赖以下 TK 专属组件）
#    AnyThinkiOS / AnyThinkMediation* / flame_sdk_ios_tk_sigmob_adapter /
#    AdGain / FSUnion / SigmobAd-iOS（独立 Sigmob，会与 ToBid Core WindSDK 冲突）
#    ToBid-iOS-RC 自身内置的 Sigmob/WindSDK 不属于 TK 私有 adapter，保留。
# ============================================================================
