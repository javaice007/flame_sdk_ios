# ============================================================
# Flame iOS Ad SDK — TB 客户 podspec（Phase 5A.13 Step 1.3 正式纳入弱链接方案）
# ------------------------------------------------------------
# 单二进制架构：flame_sdk_ios.xcframework 同时内置 Flame core + TK/TB Provider/Adapter 胶水。
# Flame binary 对 AnyThinkSDK 使用 LC_LOAD_WEAK_DYLIB（弱链接，xcFramework_build.sh 构建期注入）。
#
# 本 podspec（flame_sdk_ios_tb）面向 TB 客户：
#   - 引用同一个 flame_sdk_ios.xcframework（与 flame_sdk_ios.podspec 共用）
#   - 公共平台核心依赖：OpenSSL + ToBid-iOS-RC（不含 AnyThinkiOS）
#   - 差异化广告源依赖：当前为空（TB Reward 阶段使用 ToBid-iOS-RC 默认 ToBidSDK 子规范）
#     后续接 TB Splash/Interstitial/Banner/Native 时再加 ToBid-iOS-RC/<Adapter> 子规范
#
# 为什么 TB podspec 不带 AnyThinkiOS（Phase 5A.13 Step 1.2B/1.3）：
#   - Flame binary 对 AnyThinkSDK 是弱链接（LC_LOAD_WEAK_DYLIB），缺失时 dyld 跳过
#   - TB App 不需要 AnyThinkSDK.framework，dyld 不加载它
#   - 否则 AnyThinkSDK 进入运行时会触发其内部 ADX 完整性检测弹窗
#     （"AnyThink Adx SDK 重要组件缺失"，AnyThinkiOS 6.5.71 无公开关闭入口）
#   - AnyThinkiOS 由 flame_sdk_ios.podspec（TK）独家带入，TK 客户不受影响
#   - FlameTKProvider.initializeWithAppId 入口加 NSClassFromString(@"ATAPI") 守卫
#     （ATAPI 是 AnyThinkiOS 6.5.71 公开 Header），pt=tk 但 AnyThink 缺失时返回明确错误回调
#
# 关键：pod 名是 flame_sdk_ios_tb，但 module name 统一为 flame_sdk_ios。
#   TB 客户接入方代码仍可 `import flame_sdk_ios`（与 TK 客户一致）。
#   pod 名决定客户 Podfile 写什么；module name 决定 import 写什么。
#
# 客户只写一行：
#   pod 'flame_sdk_ios_tb'     # TB 客户（与 flame_sdk_ios 互斥，不能同时接入）
# ============================================================
Pod::Spec.new do |s|
  s.name             = 'flame_sdk_ios_tb'
  s.version          = '1.0.0-alpha.4-local'
  s.module_name      = 'flame_sdk_ios'
  s.summary          = 'Flame iOS Ad SDK - TB Edition (Single Binary, AnyThink weak-linked)'
  s.description      = 'Flame iOS advertising aggregation SDK, single binary with TK/TB platform glue embedded. TB ads deps edition. AnyThinkSDK weak-linked (not bundled for TB customers).'
  s.homepage         = 'https://github.com/javaice007/flame_sdk_ios'
  s.author           = { 'flame' => 'flame@toowe.com' }

  # GitHub archive zip 默认不剥除顶层版本目录，必须显式 :flatten => true
  s.source           = {
    :http => "https://github.com/javaice007/flame_sdk_ios/archive/refs/tags/#{s.version}.zip",
    :flatten => true,
  }

  # 商业 sdk
  s.license = {
    :type => 'Commercial',
    :text => 'Copyright Flame'
  }

  # 平台要求
  s.ios.deployment_target = '13.0'
  s.swift_version = '5.0'

  # ========= 单二进制 vendored xcframework（与 TK podspec 共用同一份）=========
  s.vendored_frameworks = 'build/flame_sdk_ios.xcframework'

  # ========= TB 公共平台核心依赖（不含 AnyThinkiOS）=========
  # binary 动态依赖 OpenSSL（otool -L 可见 @rpath/OpenSSL.framework/OpenSSL），必须显式声明。
  s.dependency 'OpenSSL-Universal', '~> 3.6'

  # ToBid-iOS-RC 是 TB 平台核心（WindMillSDK/WindSDK/WindFoundation 静态归档）。
  # binary 内的 TB 胶水（FlameTBProvider/TbRewardAdapter）通过 U 引用 WindMill 符号，
  # pt=tb 调用 FlameTBProvider.initializeWithAppId 时由 ToBid-iOS-RC 解析。
  s.dependency 'ToBid-iOS-RC', '5.5.6'

  # 红线（Phase 5A.13 Step 1.3）：TB podspec 不得依赖以下任何 TK 专属组件：
  #   - AnyThinkiOS（AnyThinkSDK 由 TK podspec 独家带入，TB 弱链接缺失即不加载）
  #   - AnyThinkMediation*（TK 广告源适配器）
  #   - flame_sdk_ios_tk_sigmob_adapter（TK 私有 Sigmob 包装层）
  #   - AdGain / FSUnion（TK 广告源 SDK）
  #   - SigmobAd-iOS（独立 Sigmob，会与 ToBid-iOS-RC 内置 WindSDK 冲突）
  # 注意：ToBid-iOS-RC 自身内置的 Sigmob/WindSDK 不属于 TK 私有 adapter，保留。

  # ========= 差异化广告源依赖（TB 专属）=========
  # 当前 TB Reward/Splash/Interstitial 阶段使用 ToBid-iOS-RC 默认 ToBidSDK 子规范（已含 WindMill 核心）。
  # 后续按需增加 ToBid-iOS-RC/<Network>Adapter 子规范（共 21 个可选 Adapter）。

  # --- Phase 5A.16B：CSJ/Pangle（穿山甲）广告源 ---
  # 用途：TB 第一批第三方广告源，主要服务后续 Banner 最小闭环（Sigmob 自身无 Banner 填充）。
  # 集成方式：依赖 ToBid 官方 CSJAdapter 子规范，由 ToBid-iOS-RC 5.5.6 统一管理底层 CSJ SDK 版本。
  # 实际依赖链（已从官方 podspec 确认）：
  #   ToBid-iOS-RC/CSJAdapter 5.5.6
  #     → vendored WindMillCSJAdapter.xcframework
  #     → Ads-CN/BUAdSDK 7.6.0.4（仅 BUAdSDK subspec：BUAdSDK.xcframework + CSJAdSDK.bundle）
  #     → ToBid-iOS-RC/ToBidSDK（已有）
  #   不拉取：BUAdLive-Framework / BUTTSDKFramework / CSJMediation
  #   （BUAdLive 陷阱仅影响 TK 侧 AnyThinkMediation 默认 Ads-CN；TB 经 CSJAdapter 显式选 BUAdSDK subspec 不受影响）
  # 不在 Flame podspec 中重复声明底层 Ads-CN/BUAdSDK/CSJMediation（由 ToBid 官方 subspec 管理，单一来源）。
  # 版本：CSJAdapter 与 ToBid-iOS-RC 锁定同版本 5.5.6；CSJ SDK 版本由 Ads-CN/BUAdSDK subspec pin 为 7.6.0.4。
  s.dependency 'ToBid-iOS-RC/CSJAdapter', '5.5.6'

  # --- Phase 5A.16E：腾讯优量汇（GDT）广告源 ---
  # 用途：CSJ 官方测试位 no-fill 后，接入腾讯 GDT 作为用户自有 Banner 广告源验证。
  # 集成方式：依赖 ToBid 官方 GDTAdapter 子规范，由 ToBid-iOS-RC 5.5.6 统一管理底层 GDT SDK 版本。
  # 实际依赖链（已从官方 podspec 确认）：
  #   ToBid-iOS-RC/GDTAdapter 5.5.6
  #     → vendored WindMillGDTAdapter.xcframework
  #     → GDTMobSDK 4.15.90
  #     → ToBid-iOS-RC/ToBidSDK（已有）
  # GDTMobSDK 4.15.90 与 TK 侧 AnyThinkMediationGDTAdapter 同版本，TK/TB 单独安装时各自解析无冲突。
  # 不在 Flame podspec 中重复声明底层 GDTMobSDK（由 ToBid 官方 subspec 管理，单一来源）。
  s.dependency 'ToBid-iOS-RC/GDTAdapter', '5.5.6'

  # --- 后续批次（Phase 5A.16F+，按需启用，本阶段不接入）---
  #   s.dependency 'ToBid-iOS-RC/MSAdAdapter', '5.5.6'
  #   s.dependency 'ToBid-iOS-RC/OctopusAdapter', '5.5.6'
  #   # Mintegral（注意 WindMillMTGAdapter.xcframework 仅 ios-arm64，缺 simulator slice）
  #   # s.dependency 'ToBid-iOS-RC/MintegralAdapter', '5.5.6'
  #   # GroMore（与 CSJ 二选一，会重复带入 Ads-CN/BUAdSDK）
  #   # s.dependency 'ToBid-iOS-RC/GromoreAdapterLite', '5.5.6'

  # ========= xcconfig（与 TK podspec 完全一致）=========
  s.pod_target_xcconfig = {
    'OTHER_LDFLAGS' => '$(inherited) -ObjC'
  }

  s.user_target_xcconfig = {
    'OTHER_LDFLAGS' => '$(inherited) -ObjC'
  }
end

