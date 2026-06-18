# ============================================================
# Flame iOS Ad SDK — TK 正式 podspec（方案 D）
# ------------------------------------------------------------
# Phase 5A.10 Step 3 正式化：两个对外 podspec + 一个内部 core binary。
#
# 客户只写一行：
#   pod 'flame_sdk_ios'        # TK 客户
#   pod 'flame_sdk_ios_tb'     # TB 客户（与 flame_sdk_ios 互斥，不能同时接入）
#
# 接入方 import 保持不变（module name 统一为 flame_sdk_ios）：
#   ObjC:  #import <flame_sdk_ios/flame_sdk_ios.h>
#          #import <flame_sdk_ios/FlameSdk.h>
#   Swift: import flame_sdk_ios
#
# 内部架构：
#   vendored_frameworks = flame_sdk_ios_core.xcframework（发布仓库根目录）
#     - framework/binary/module 名均为 flame_sdk_ios_core
#     - 与 pod 名 flame_sdk_ios 不同 → 不遮蔽，单 pod 可共存
#     - 仅含 Flame core（无 AnyThink/ToBid/WindMill/Sigmob/AdGain 等三方符号）
#   source_files = 正式转发头 + TK 平台源码（FlameTKProvider + At*Adapter）
#     - 转发头将 #import <flame_sdk_ios/...> 转发到 <flame_sdk_ios_core/...>
#     - TK 源码经 pod_target_xcconfig 注入 FLAME_PLUGIN_TK 宏，编译出 +load
#       自动注册 FlameTKProvider 到 FlameMediationRegistry
#
# 推荐 Podfile：
#   use_frameworks! :linkage => :static
#   pod 'flame_sdk_ios', :path => '...' 或远端
# ============================================================
Pod::Spec.new do |s|
  s.name             = 'flame_sdk_ios'
  s.version          = '1.0.0-alpha.2'
  s.module_name      = 'flame_sdk_ios'
  s.summary          = 'Flame iOS Ad SDK - TK Edition'
  s.description      = 'Flame iOS advertising aggregation SDK, TK / TopOn / AnyThink edition (Scheme D: single internal core binary + TK platform source).'
  s.homepage         = 'https://github.com/javaice007/flame_sdk_ios'
  s.author           = { 'flame' => 'flame@toowe.com' }

  # GitHub archive zip 默认不剥除顶层版本目录（cocoapods-downloader 仅对 tgz 默认 flatten），
  # 必须显式 :flatten => true 才能让 podspec 的精确路径匹配到文件。
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

  # ========= 内部 Core Binary（module = flame_sdk_ios_core）=========
  # 零三方符号，仅 OpenSSL + 系统库依赖；TK/TB 平台源码在 pod 源模块中编译。
  # 发布产物路径：flame_sdk_ios_core.xcframework（发布仓库根目录）
  s.vendored_frameworks = 'flame_sdk_ios_core.xcframework'

  # ========= 转发头（对外公共 API，转发到 core binary）=========
  # 接入方 #import <flame_sdk_ios/FlameSdk.h> 经此转发到 <flame_sdk_ios_core/FlameSdk.h>
  s.public_header_files = ['flame_sdk_ios/wrappers/flame_sdk_ios/*.h']

  # ========= 源码（转发头 + TK 平台源码：FlameTKProvider + At*Adapter）=========
  s.source_files = [
    'flame_sdk_ios/wrappers/flame_sdk_ios/*.{h,m,mm}',
    'flame_sdk_ios/mediation/tk/**/*.{h,m,mm}',
    'flame_sdk_ios/adapter/tk/**/*.{h,m,mm}'
  ]

  # TK 内部协议/适配器头为私有（不对外暴露，仅供 pod 内部源码互引用）
  s.private_header_files = [
    'flame_sdk_ios/mediation/tk/**/*.h',
    'flame_sdk_ios/adapter/tk/**/*.h'
  ]

  # ========= 依赖 =========
  # Core binary 动态依赖 OpenSSL（otool -L 显示 @rpath/OpenSSL.framework/OpenSSL），
  # 必须显式声明，否则 App 运行时 dyld 找不到 OpenSSL → crash。
  # TK 靠 AnyThinkiOS 传递依赖能侥幸通过，但显式声明边界更清晰。
  s.dependency 'OpenSSL-Universal', '~> 3.6'

  # TK 运行时依赖（AnyThink 聚合 + 各 Mediation Adapter + AdGain + 飞梭）
  s.dependency 'AnyThinkiOS', '6.5.71'
  # Anythink Kuying Adx SDK (necessary)
  s.dependency 'AnyThinkMediationAdxSmartdigimktCNAdapter', '6.5.72.2.1'
  s.dependency 'AnyThinkMediationGromoreAdapter', '7.6.0.4.2.0'
  s.dependency 'AnyThinkMediationBaiduAdapter', '10.050.2.1'
  s.dependency 'AnyThinkMediationMSAdapter', '2.7.18.1.2.0'
  s.dependency 'AnyThinkMediationZYAdapter', '2.6.4.29.2.0'
  s.dependency 'AnyThinkMediationFunlinkAdapter', '2.9.0.1.2.2.0'
  s.dependency 'AnyThinkMediationBeiZiAdapter', '5.5.0.3.2.0'
  s.dependency 'AnyThinkMediationKuaiShouAdapter', '5.4.10.1.2.0'
  # Sigmob Adapter: TK 默认版使用标准版（含 SigmobAd-iOS）
  s.dependency 'AnyThinkMediationSigmobAdapter', '4.20.12.2.0'
  s.dependency 'AnyThinkMediationTTAdapter_Mix', '7.6.0.4.2.0'
  s.dependency 'AnyThinkMediationGDTAdapter', '4.15.90.2.0'

  # AdGain 广告 SDK + Taku/TopOn 适配器
  s.dependency 'AdGainSDK', '4.2.7.1'
  s.dependency 'AdGainSDKTakuAdapter', '4.2.7.1'

  # 飞梭
  s.dependency 'FSUnionAdSDK', '1.0.8.0'

  # ========= pod_target_xcconfig =========
  # 宏注入 + 模块/头搜索路径（Step 2B 实测成功项）：
  #   - FLAME_BUILD_TK=1 / FLAME_PLUGIN_TK=1：TK 变体代码分支 + FlameTKProvider +load 注册
  #   - -F${PODS_XCFRAMEWORKS_BUILD_DIR}/flame_sdk_ios：Swift 显式模块扫描（clang dependency
  #     scanning）对 vendored framework 解析比传统编译更严格，需显式 -F 指向 staging 后的
  #     flame_sdk_ios_core.framework 所在目录，否则扫描期找不到 <flame_sdk_ios_core/...> 模块
  #   - HEADER_SEARCH_PATHS：pod 内部源码引用 FlameMediationRegistry.h 等内部协议头
  #     （这些头在 vendored core binary Headers/ 中，已通过 Step 2B 补暴露）
  s.pod_target_xcconfig = {
    'OTHER_LDFLAGS' => '$(inherited) -ObjC',
    'OTHER_CFLAGS'  => '$(inherited) -DFLAME_BUILD_TK=1 -DFLAME_PLUGIN_TK=1 -F${PODS_XCFRAMEWORKS_BUILD_DIR}/flame_sdk_ios',
    'OTHER_CPLUSPLUSFLAGS' => '$(inherited) -F${PODS_XCFRAMEWORKS_BUILD_DIR}/flame_sdk_ios',
    'FRAMEWORK_SEARCH_PATHS' => '$(inherited) "${PODS_XCFRAMEWORKS_BUILD_DIR}/flame_sdk_ios"',
    'HEADER_SEARCH_PATHS' => '$(inherited) "${PODS_XCFRAMEWORKS_BUILD_DIR}/flame_sdk_ios/flame_sdk_ios_core.framework/Headers"',
    'DEFINES_MODULE' => 'YES'
  }
end
