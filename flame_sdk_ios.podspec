# ============================================================
# Flame iOS Ad SDK — TK 客户 podspec
# ------------------------------------------------------------
# 静态双线架构（release/ios-dual-line，1.0.1-alpha.2 起）：
# flame_sdk_ios.xcframework 为【静态 framework】（ar 归档），
# 内置 Flame core + TK 胶水（FlameTKProvider + At*Adapter），
# 不含 TB 胶水（零 WindMill 符号引用）。
#
# 修复背景（TK 客户 1.0.0 闪退根因，与 TB 线同源）：
#   1.0.0 交付的动态单二进制用 -undefined dynamic_lookup 把 TB 胶水的
#   8 个 WindMill 类符号留成扁平命名空间未定义符号，而 ToBid 只有静态
#   归档，客户 App 启动时 dyld 解析不到 → 必崩：
#   DYLD: symbol not found in flat namespace '_OBJC_CLASS_$__TtC11WindMillSDK11WindMillAds'
#   静态双线 TK 产物不再包含 TB 胶水，WindMill 引用随之消失；
#   AnyThink 符号在客户 App 链接期由 AnyThinkSDK.framework 解析。
#
# 本 podspec（flame_sdk_ios）面向 TK（TopOn/AnyThink）客户。
# TB（ToBid）客户使用 flame_sdk_ios_tb.podspec，二者互斥不可同时接入。
# module_name 均为 flame_sdk_ios。
#
# 接入方：
#   pod 'flame_sdk_ios', '1.0.1-alpha.3'
#   import flame_sdk_ios
# ============================================================
Pod::Spec.new do |s|
  s.name             = 'flame_sdk_ios'
  s.version          = '1.0.1-alpha.3'
  s.module_name      = 'flame_sdk_ios'
  s.summary          = 'Flame iOS Ad SDK - TK Edition (Static Dual-Line)'
  s.description      = 'Flame iOS advertising aggregation SDK, static framework with Flame core + TK (TopOn/AnyThink) glue embedded. AnyThink symbols resolve at app link time via AnyThinkSDK.framework.'
  s.homepage         = 'https://github.com/javaice007/flame_sdk_ios'
  s.author           = { 'flame' => 'flame@toowe.com' }

  # 通过二进制分发仓库 javaice007/flame_sdk_ios 的 Tag 拉取。
  # 1.0.1-alpha.2 起双线均为静态产物：本 podspec 引用仓库根目录的
  # flame_sdk_ios.xcframework（静态）；TB 产物在 tb/ 子目录
  # （1.0.0 Tag 仍是旧的动态单二进制，仅供历史版本解析）。
  s.source = { :git => 'https://github.com/javaice007/flame_sdk_ios.git', :tag => s.version.to_s }

  s.license = {
    :type => 'Commercial',
    :text => 'Copyright Flame'
  }

  s.ios.deployment_target = '13.0'
  s.swift_version = '5.0'

  # ========= TK 静态产物 vendored xcframework（static framework，链接进客户主程序）=========
  s.vendored_frameworks = 'flame_sdk_ios.xcframework'

  # ========= 公共平台核心依赖 =========
  # 静态归档中的 OpenSSL 符号在客户 App 链接期由 OpenSSL-Universal 动态 framework 解析。
  s.dependency 'OpenSSL-Universal', '~> 3.6'

  # AnyThinkSDK 为 TK 平台核心：flame 静态归档内的 TK 胶水（FlameTKProvider +
  # At*Adapter + FlameAdapterManager 遗留 init）对 AT* 类的未定义符号，
  # 全部在客户 App 链接期由 AnyThinkSDK.framework（AnyThinkiOS pod 带入）解析。
  s.dependency 'AnyThinkiOS', '6.5.71'

  # ToBid-iOS-RC 为 flame_sdk_ios_tk_sigmob_adapter 提供 WindSDK/WindFoundation
  # （同名 framework 统一来源，避免与 SigmobAd-iOS 冲突）。1.0.1-alpha.1 起
  # flame 本体（静态 TK 产物）不再含任何 WindMill 符号引用，此依赖与 flame
  # 本体解耦，仅为下游 sigmob adapter 服务。
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
  # -ObjC 是静态产物正常工作的必要条件：
  #   1) 强制加载 flame 静态归档的全部 ObjC 成员（否则未被直接引用的
  #      FlameTKProvider 等不会进主程序，+load 不会执行）
  #   2) FlameTKProvider / At*Adapter 的 +load 自动注册依赖它触发
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
# 1. 与 TB 产物互斥
#    TK 产物（根目录 flame_sdk_ios.xcframework）与 TB 产物（tb/ 子目录
#    flame_sdk_ios.xcframework）自 1.0.1-alpha.2 起均为静态产物
#    （module 同名 flame_sdk_ios），不可同时接入。
#    （历史：1.0.0 曾以 LC_LOAD_WEAK_DYLIB 弱链接 AnyThinkSDK 的动态单二进制
#    分发，因 WindMill 扁平命名空间符号无法解析导致 TK/TB 客户启动必崩，
#    1.0.1-alpha.1 起双线均改为静态双线产物，弱链接机制退役。）
#
# 2. Mintegral simulator slice 限制
#    WindMillMTGAdapter.xcframework 仅含 ios-arm64 slice（缺 simulator slice），
#    ToBid-iOS-RC 5.5.6 podspec 自带 EXCLUDED_ARCHS[sdk=iphonesimulator*]=arm64，
#    含义：Apple Silicon Mac simulator 需要 Rosetta；Intel simulator 与真机不受影响。
#    Flame podspec 不额外添加 EXCLUDED_ARCHS。
#
# 3. 升级指引
#    客户侧仅需改 Podfile 版本号：
#      pod 'flame_sdk_ios', '1.0.1-alpha.3'
#    无需任何代码改动（module/import/API 均不变）；产物由动态变静态后，
#    flame 将链接进主程序（包内不再有 flame_sdk_ios.framework 动态库）。
#    1.0.1-alpha.3 同时修复发奖回调 transId 恒空（localExtra key 只读不写）。
# ============================================================================
