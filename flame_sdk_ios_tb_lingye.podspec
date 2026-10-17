# ============================================================
# Flame iOS Ad SDK — 领页客户共存专用 TB 变体 podspec
# ------------------------------------------------------------
# 产品定位（P0D 冻结）：
#   flame_sdk_ios_tb_lingye 仅用于「Flame + CJMobileAd 2.4.32 客户共存」环境，
#   不是标准 flame_sdk_ios_tb 的替代品。标准双线产品保持通用语义不动。
#
# 客户侧完全冻结（CUSTOMER_SIDE_CODE_CHANGE = NO）：
#   CJMobileAd 2.4.32 / HXSDK 5.1.8 / MSMobAdSDKv3 3.0.10.2 / OpenSSL 1.1
#   均不改动；共存适配责任全部由本变体承担（ADAPTATION_OWNER = FLAME_SDK）。
#
# 与标准 flame_sdk_ios_tb 的全部正式差异（仅 dependency boundary）：
#   1. OpenSSL-Universal：~>3.6 → ~>1.1
#      依据 P0C：Flame TB 二进制对 OpenSSL 的未定义引用仅 12 个高层 EVP AES-GCM
#      符号，1.1.2301 全部导出，TEST_ONLY 真机链接 PASS
#      （OPENSSL_1_1_LINK_COMPAT = PASS；runtime 验证见 P0D 验证记录）。
#   2. 移除 ToBid-iOS-RC/MSAdAdapter：
#      客户已有 MSMobAdSDKv3（HXSDK/MS），双方同名 MSAdSDK/MSAdMotion
#      xcframework 会令 pod install 直接失败（P0C 实测 CONFIRMED）。
#      美数由客户既有副本独家承担（LINGYE_MS_OWNER = CUSTOMER_EXISTING_SDK）。
#      —— 服务端须保证不为该客户 TB placement 下发 MS 网络
#      （CUSTOMER_TB_NETWORK_PROFILE_EXCLUDES_MS，Flame 后台配置，非客户操作）。
#   其余（core binary / module / 公共 API / 初始化契约）与标准 TB 完全一致：
#   module_name = flame_sdk_ios，import 与业务代码零变化。
#
# 二进制：与标准 TB 同一份冻结产物（vendored 'tb/flame_sdk_ios.xcframework'，
# 即 1.0.1-alpha.4 冻结 TB binary）。正式发布时由决策层在分发仓库打
# 1.0.1-lingye.1 tag 并翻正 source；当前本地验证版本号：
#   1.0.1-lingye.1-local（正式候选 1.0.1-lingye.1，发布前禁止 push flame-specs）。
#
# 接入方（正式发布后）：
#   pod 'flame_sdk_ios_tb_lingye', '1.0.1-lingye.1'
#   import flame_sdk_ios
# ============================================================
Pod::Spec.new do |s|
  s.name             = 'flame_sdk_ios_tb_lingye'
  s.version          = '1.0.1-lingye.1-local'
  s.module_name      = 'flame_sdk_ios'
  s.summary          = 'Flame iOS Ad SDK - TB Lingye Coexist Edition'
  s.description      = 'Flame advertising aggregation SDK, customer variant for coexistence with CJMobileAd 2.4.32: OpenSSL ~>1.1 compatible, ToBid MSAdAdapter excluded (customer MSMobAdSDKv3 stays the single MS copy). Core binary and public API identical to standard flame_sdk_ios_tb.'
  s.homepage         = 'https://github.com/javaice007/flame_sdk_ios'
  s.author           = { 'flame' => 'flame@toowe.com' }

  # 与标准 TB 同一份冻结二进制：当前指向分发仓库既有 tag 1.0.1-alpha.4 的
  # tb/ 子目录产物（FLAME_CORE_BINARY_CHANGED = NO）。
  s.source = { :git => 'https://github.com/javaice007/flame_sdk_ios.git', :tag => '1.0.1-alpha.4' }

  s.license = {
    :type => 'Commercial',
    :text => 'Copyright Flame'
  }

  s.ios.deployment_target = '13.0'
  s.swift_version = '5.0'

  # ========= TB 静态产物 vendored xcframework（与标准 TB 同一份）=========
  s.vendored_frameworks = 'tb/flame_sdk_ios.xcframework'

  # ========= 客户兼容 OpenSSL（差异点 1）=========
  # 客户 HXSDK/JT 已解析 OpenSSL-Universal ~>1.1；本变体对齐客户现有版本域，
  # App 内保持单一 OpenSSL 副本。Flame TB 二进制仅依赖 12 个高层 EVP 符号
  # （P0C nm 实测），1.1.2301 全部导出。
  s.dependency 'OpenSSL-Universal', '~> 1.1'

  # ========= ToBid 平台核心 ==========
  s.dependency 'ToBid-iOS-RC', '5.5.6'

  # ========= ToBid 广告源 Adapter（差异点 2：无 MSAdAdapter）=========
  s.dependency 'ToBid-iOS-RC/CSJAdapter', '5.5.6'        # 穿山甲
  s.dependency 'ToBid-iOS-RC/GDTAdapter', '5.5.6'        # 腾讯优量汇
  s.dependency 'ToBid-iOS-RC/BaiduAdapter', '5.5.6'      # 百度联盟
  s.dependency 'ToBid-iOS-RC/KSAdapter', '5.5.6'         # 快手
  s.dependency 'ToBid-iOS-RC/MintegralAdapter', '5.5.6'  # Mintegral（国内版）
  s.dependency 'ToBid-iOS-RC/OctopusAdapter', '5.5.6'    # 章鱼
  s.dependency 'ToBid-iOS-RC/GromoreAdapter', '5.5.6'    # GroMore（与 CSJ 共享 BUAdSDK）
  # 说明：刻意不含 ToBid-iOS-RC/MSAdAdapter（美数）——客户 MSMobAdSDKv3 是唯一 MS 副本。
  # 服务端不得给该客户 TB placement 下发 MS 网络。

  # ========= xcconfig（与标准 TB 一致）=========
  s.pod_target_xcconfig = {
    'OTHER_LDFLAGS' => '$(inherited) -ObjC'
  }

  s.user_target_xcconfig = {
    'OTHER_LDFLAGS' => '$(inherited) -ObjC'
  }
end

# ============================================================================
# 附录：边界与已知限制
# ----------------------------------------------------------------------------
# 1. 仅限领页客户共存环境；通用客户继续使用 flame_sdk_ios / flame_sdk_ios_tb。
#    与标准 TB（或 TK）不得同时接入。
# 2. 红线（本变体不含）：AnyThinkiOS / AnyThinkMediation* / TK adapter /
#    AdGain* / FSUnion* / 独立 SigmobAd-iOS / ToBid MSAdAdapter。
# 3. Mintegral 适配器仅 ios-arm64 slice：模拟器构建不可用（与标准 TB 相同限制），
#    开发期需真机。
# 4. OPENSSL_1_1_LINK_COMPAT = PASS（P0C）；OPENSSL_1_1_RUNTIME_COMPAT 以
#    P0D 真机验证记录为准。正式发布前需 iOS13 工具链复建产物。
# ============================================================================
