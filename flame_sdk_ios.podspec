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
#   pod 'flame_sdk_ios', '1.0.1-alpha.4'
#   import flame_sdk_ios
# ============================================================
Pod::Spec.new do |s|
  s.name             = 'flame_sdk_ios'
  s.version          = '1.0.2'
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
  # P2-TK：Taku 官方稳定版 6.5.84（不用 TakuBeta 6.5.90）。
  s.dependency 'AnyThinkiOS', '6.5.84'

  # Taku 官方原生 Sigmob Adapter（P1-R1 起退役私有兼容 spec）。
  # 历史：flame_sdk_ios_tk_sigmob_adapter（4.20.12.2.0，Flame 私有 spec）是 TK/TB
  # 共用同一生产包时代为解决 WindSDK/WindFoundation 同名依赖冲突引入的 workaround
  # ——它 vendored TopOn 官方 AnyThinkSigmobAdapter 二进制但去掉 SigmobAd-iOS
  # 传递依赖，借用 ToBid-iOS-RC 5.5.6 的 WindSDK/WindFoundation（该 ToBid 依赖
  # 已随本迁移一并移除）。TK/TB 拆分为独立生产包后该前提不复存在，TK 恢复
  # Taku 官方 Adapter + SigmobAd-iOS 5.1.3（自带 wind-sdk-ios 的
  # WindSDK/WindFoundation），不再依赖 ToBid。详见 docs/knowledge/flame_sdk_ios/26。
  s.dependency 'AnyThinkMediationSigmobAdapter', '5.1.3.2.0'

  # ========= TK 广告源 Adapter + 底层 SDK =========
  # 版本矩阵来源：Taku 官方 iOS 下载中心（项目负责人按 Flame TK 广告源选择后生成），
  # P2-TK 冻结，全部精确锁定（禁止 ~> / >= / 自行改版）。
  # 穿山甲与 GroMore 必须成套：TTAdapter_Mix 与 GromoreAdapter 同为 7.8.0.5.2.1，
  # 共享同一套 Ads-CN/BUAdSDK 7.8.0.5 + CSJMediation-Only 7.8.0.5（单份 Pangle）。
  s.dependency 'AnyThinkMediationAdxSmartdigimktCNAdapter', '6.5.90.2.1'
  s.dependency 'AnyThinkMediationGromoreAdapter', '7.8.0.5.2.1'
  s.dependency 'AnyThinkMediationBaiduAdapter', '10.061.2.0'
  s.dependency 'AnyThinkMediationMSAdapter', '3.0.15.0.2.0'
  s.dependency 'AnyThinkMediationZYAdapter', '2.6.10.7.2.0'
  s.dependency 'AnyThinkMediationFunlinkAdapter', '2.9.0.3.3.2.0'
  s.dependency 'AnyThinkMediationBeiZiAdapter', '5.5.6.0.2.0'
  s.dependency 'AnyThinkMediationKuaiShouAdapter', '5.9.10.1.2.0'
  s.dependency 'AnyThinkMediationTTAdapter_Mix', '7.8.0.5.2.1'
  s.dependency 'AnyThinkMediationGDTAdapter', '4.16.10.2.0'
  # AdGain / FSUnion：单独集成，不属于 Taku 下载中心升级范围，本阶段冻结当前版本
  # （KEEP_CURRENT_OUT_OF_TAKU_SCOPE：不删除、不升级、不改接入方式）。
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
# 2. simulator slice 限制（EXCLUDED_ARCHS[sdk=iphonesimulator*]=arm64）
#    TK：SigmobAd-iOS 5.1.3（wind-sdk-ios）podspec 自带
#    EXCLUDED_ARCHS[sdk=iphonesimulator*]=arm64 —— Apple Silicon Mac simulator
#    需要 Rosetta；真机不受影响。Flame podspec 不额外添加 EXCLUDED_ARCHS。
#    （TB 包侧历史事实：WindMillMTGAdapter.xcframework 仅含 ios-arm64 slice，
#    ToBid-iOS-RC 5.5.6 podspec 同样自带该 EXCLUDED_ARCHS——属 TB 依赖，
#    自 P1-R1 起不再是 TK 依赖。）
#
# 3. 升级指引
#    客户侧仅需改 Podfile 版本号：
#      pod 'flame_sdk_ios', '1.0.1-alpha.4'
#    无需任何代码改动（module/import/API 均不变）；产物由动态变静态后，
#    flame 将链接进主程序（包内不再有 flame_sdk_ios.framework 动态库）。
#    1.0.1-alpha.4 同时修复发奖回调 transId 恒空（localExtra key 只读不写）。
# ============================================================================
