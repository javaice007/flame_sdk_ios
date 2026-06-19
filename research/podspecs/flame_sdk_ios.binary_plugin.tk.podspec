# ============================================================
# flame_sdk_ios.binary_plugin.tk.podspec
# ------------------------------------------------------------
# Phase 5A.11 Step 1 方案 E 实验性 podspec（本地验证，不发布）
#
# 与正式 flame_sdk_ios.podspec（方案 D）的核心区别：
#   - 方案 D：vendored_frameworks(core) + source_files(TK 平台源码)
#             → source_files 会把 At*Adapter.m / FlameTKProvider.m 暴露给客户 Pods
#   - 方案 E：vendored_frameworks(core) + vendored_frameworks(TK plugin binary)
#             → 双 framework 二进制分发，客户 Pods 看不到任何 .m 源码
#
# 本 podspec 依赖两个本地构建产物：
#   build/flame_sdk_ios_core.xcframework   （core-named 变体产物）
#   build/tk/flame_sdk_ios.xcframework     （tk-plugin 变体产物，含 +load）
#
# 接入方代码不变：
#   #import <flame_sdk_ios/FlameSdk.h>     （经 wrappers 转发到 flame_sdk_ios_core）
#
# 红线：本 podspec 仅用于本地 :path 验证，不进 flame-specs 仓库，不打 tag。
# ============================================================

Pod::Spec.new do |s|
  s.name             = 'flame_sdk_ios'
  s.module_name      = 'flame_sdk_ios'
  s.version          = '1.0.0-alpha.3-local'
  s.summary          = 'Flame iOS Ad SDK - TK Edition (Scheme E: binary plugin, local validation)'
  s.description      = 'Flame iOS advertising aggregation SDK, TK / TopOn / AnyThink edition. '\
                       'Scheme E experimental: core binary + TK plugin binary (no source exposure).'
  s.homepage         = 'https://github.com/javaice007/flame_sdk_ios'
  s.author           = { 'flame' => 'flame@toowe.com' }
  s.license          = { :type => 'Commercial', :file => 'LICENSE' }
  s.ios.deployment_target = '13.0'

  # 本地验证：source 不重要（:path 模式不会下载），留占位
  s.source           = { :path => '.' }

  # ============================================================
  # 方案 E 核心：双 vendored_frameworks
  # ============================================================
  # 1) flame_sdk_ios_core.xcframework：平台中立核心（FlameSdk / Router / Registry /
  #    AdapterManager / ConfigManager / ErrorCode / Logger / 各 *AdImpl / utils / 加密）
  #    module 名 = flame_sdk_ios_core（避免与 plugin 同名遮蔽）
  # 2) tk/flame_sdk_ios.xcframework：TK 平台插件二进制
  #    含 FlameTKProvider（+load 自动注册）+ 6 个 At*Adapter/View
  #    module 名 = flame_sdk_ios（接入方 import 入口）
  #    不含 AnyThink / 广告源 SDK 静态符号（运行期由下方 dependency 提供）
  # ============================================================
  s.vendored_frameworks = [
    'build/flame_sdk_ios_core.xcframework',
    'build/tk/flame_sdk_ios.xcframework'
  ]

  # ============================================================
  # 运行期依赖（与正式 TK podspec 完全一致）
  # ============================================================
  # core 加密需要 OpenSSL；TK plugin 运行期需要 AnyThinkiOS；
  # AnyThink Mediation Adapters + 广告源 SDK 由客户 App 接入期拉取。
  s.dependency 'OpenSSL-Universal', '~> 3.6'

  s.dependency 'AnyThinkiOS', '6.5.71'

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

  # ============================================================
  # xcconfig
  # ============================================================
  # -ObjC：保证 TK plugin framework 中的 FlameTKProvider +load 被链接器保留
  #        （+load 在 __objc_nlclslist 段，需要 -ObjC 才不会被 dead-strip）
  # 方案 E 不再需要 source_files 编译期宏注入（FLAME_PLUGIN_TK 已在构建期 baked-in）。
  s.pod_target_xcconfig = {
    'OTHER_LDFLAGS' => '$(inherited) -ObjC'
  }
  s.user_target_xcconfig = {
    'OTHER_LDFLAGS' => '$(inherited) -ObjC'
  }
end
