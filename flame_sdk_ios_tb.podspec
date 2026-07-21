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
  # Phase 5A.19：以用户下载的 ToBid 5.5.6 完整集成包 + 接入代码/Cocoapod引用代码.txt 为依据，
  # 全量接入用户选定的 8 个广告源（完整包有 9 个目录，其中 bidResult 引用代码未声明，作为辅助插件不主动接入）。
  #
  # 所有 Adapter 与 ToBid-iOS-RC 锁定同版本 5.5.6，底层三方 SDK 版本由 ToBid 官方 subspec 统一管理（单一来源）。
  # 不在 Flame podspec 中重复声明底层三方 SDK（如 Ads-CN/GDTMobSDK/KSAdSDK 等）。
  #
  # 引用代码原样：
  #   pod 'ToBid-iOS-RC/CSJAdapter',     '5.5.6'   # 穿山甲
  #   pod 'ToBid-iOS-RC/GDTAdapter',     '5.5.6'   # 腾讯广告
  #   pod 'ToBid-iOS-RC/BaiduAdapter',   '5.5.6'   # 百度联盟
  #   pod 'ToBid-iOS-RC/KSAdapter',      '5.5.6'   # 快手
  #   pod 'ToBid-iOS-RC/MintegralAdapter','5.5.6'  # Mintegral（国内版）
  #   pod 'ToBid-iOS-RC/OctopusAdapter', '5.5.6'   # 章鱼
  #   pod 'ToBid-iOS-RC/MSAdAdapter',    '5.5.6'   # 美数
  #   pod 'ToBid-iOS-RC/GromoreAdapter', '5.5.6'   # Gromore

  # --- 穿山甲（CSJ/Pangle） ---
  # 依赖链：WindMillCSJAdapter.xcframework → Ads-CN/BUAdSDK 7.6.0.4
  s.dependency 'ToBid-iOS-RC/CSJAdapter', '5.5.6'

  # --- 腾讯优量汇（GDT） ---
  # 依赖链：WindMillGDTAdapter.xcframework + Tquic.xcframework → GDTMobSDK 4.15.90
  s.dependency 'ToBid-iOS-RC/GDTAdapter', '5.5.6'

  # --- 百度联盟 ---
  # 依赖链：WindMillBaiduAdapter.xcframework + BaiduMobAdSDK.framework + baidumobadsdk.bundle → BaiduMobAdSDK 10.050
  s.dependency 'ToBid-iOS-RC/BaiduAdapter', '5.5.6'

  # --- 快手 ---
  # 依赖链：WindMillKSAdapter.xcframework + KSAdSDK.xcframework → KSAdSDK 5.4.10.1
  s.dependency 'ToBid-iOS-RC/KSAdapter', '5.5.6'

  # --- Mintegral（汇量科技，国内版） ---
  # 依赖链：WindMillMTGAdapter.xcframework + 8 个 MTGSDK*.xcframework → MintegralAdSDK 7.7.6（7 个 Bid/NewInterstitial 子模块）
  # ⚠️ 已知限制：WindMillMTGAdapter.xcframework 仅含 ios-arm64 slice（缺 simulator slice），
  #    且 ToBid-iOS-RC 5.5.6 podspec 本身声明 EXCLUDED_ARCHS[sdk=iphonesimulator*]=arm64（全局）。
  #    含义：simulator 只能跑 x86_64（Intel 模拟器），Apple Silicon 模拟器需 Rosetta。
  #    真机 iphoneos arm64 不受影响。我们不主动添加额外 EXCLUDED_ARCHS。
  s.dependency 'ToBid-iOS-RC/MintegralAdapter', '5.5.6'

  # --- 章鱼 ---
  # 依赖链：WindMillOctopusAdapter.xcframework + OctAdSDK.xcframework + OctCore.xcframework + bundles → OctopusSDK 2.6.4.29
  s.dependency 'ToBid-iOS-RC/OctopusAdapter', '5.5.6'

  # --- 美数 ---
  # 依赖链：WindMillMSAdAdapter.xcframework + MSAdSDK.xcframework + MSAdMotion.xcframework + MSAdSDK.bundle → MSMobAdSDK/MS 2.7.18.1
  s.dependency 'ToBid-iOS-RC/MSAdAdapter', '5.5.6'

  # --- GroMore（穿山甲 Mediation） ---
  # 依赖链：WindMillGroMoreAdapter.xcframework + CSJMediation.xcframework → Ads-CN/BUAdSDK 7.6.0.4 + Ads-CN/CSJMediation 7.6.0.4
  # 与 CSJAdapter 共享同一 BUAdSDK 7.6.0.4（CocoaPods 自动合并，无 duplicate）。
  # CSJMediation 是独立组件，不与 BUAdSDK 冲突。
  s.dependency 'ToBid-iOS-RC/GromoreAdapter', '5.5.6'

  # --- 未接入说明 ---
  # BidResultAdapter：完整包有 bidResult 目录，但 Cocoopod引用代码.txt 未声明。
  #   作为竞价结果辅助插件，非独立广告网络；引用代码没要求时不主动接入（最小依赖原则）。
  #   客户若需要 Server-to-Server 竞价回传，可自行添加 'ToBid-iOS-RC/BidResultAdapter', '5.5.6'。

  # ========= xcconfig（与 TK podspec 完全一致）=========
  s.pod_target_xcconfig = {
    'OTHER_LDFLAGS' => '$(inherited) -ObjC'
  }

  s.user_target_xcconfig = {
    'OTHER_LDFLAGS' => '$(inherited) -ObjC'
  }
end

