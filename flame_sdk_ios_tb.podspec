# ============================================================
# Flame iOS Ad SDK — TB 客户 podspec
# ------------------------------------------------------------
# 静态双线架构（release/ios-dual-line，1.0.1-alpha.2 起）：
# TB 静态产物位于二进制仓库 tb/ 子目录（flame_sdk_ios.xcframework，静态
# framework，ar 归档），内置 Flame core + TB 胶水（FlameTBProvider +
# Tb*Adapter），不含 TK 胶水（零 AnyThink 符号引用）。
#
# 外壳路径说明（1.0.1-alpha.2 修复项）：
#   TB 产物外壳名必须与内部 framework 名（flame_sdk_ios.framework）一致，
#   否则 CocoaPods 会生成 -framework "flame_sdk_ios_tb" 导致客户链接失败
#   （alpha.1 缺陷：闪退已修但无法开箱构建）。与 TK 产物的同名冲突通过
#   tb/ 子目录区分。
#
# 修复背景（TB 客户 1.0.0 闪退根因）：
#   1.0.0 交付的动态 framework 用 -undefined dynamic_lookup 把 8 个
#   WindMill 类符号留成扁平命名空间未定义符号，指望运行期解析；而
#   ToBid（WindMillSDK 等）只有静态归档，dyld 启动期解析不到 → 必崩：
#   DYLD: symbol not found in flat namespace '_OBJC_CLASS_$__TtC11WindMillSDK11WindMillAds'
#   静态产物把解析推迟到客户 App 链接期：WindMill 符号由本 podspec 的
#   ToBid-iOS-RC 静态归档在链接期解析，dyld 阶段无跨库查找，问题根除。
#
# 本 podspec（flame_sdk_ios_tb）面向 TB（ToBid/WindMill）客户。
# TK（TopOn）客户使用 flame_sdk_ios.podspec（1.0.1-alpha.1 起同为静态双线产物），
# 二者互斥不可同时接入。module_name 均为 flame_sdk_ios。
#
# 接入方：
#   pod 'flame_sdk_ios_tb', '1.0.1-alpha.2'
#   import flame_sdk_ios
# ============================================================
Pod::Spec.new do |s|
  s.name             = 'flame_sdk_ios_tb'
  s.version          = '1.0.1-alpha.2'
  s.module_name      = 'flame_sdk_ios'
  s.summary          = 'Flame iOS Ad SDK - TB Edition (Static Dual-Line)'
  s.description      = 'Flame iOS advertising aggregation SDK, static framework with Flame core + TB (ToBid) glue embedded. WindMill symbols resolve at app link time via ToBid-iOS-RC static archives.'
  s.homepage         = 'https://github.com/javaice007/flame_sdk_ios'
  s.author           = { 'flame' => 'flame@toowe.com' }

  # 通过二进制分发仓库 javaice007/flame_sdk_ios 的 Tag 拉取。
  # 1.0.1-alpha.2 起双线均为静态产物：TB 产物在 tb/ 子目录（本 podspec 引用），
  # TK 产物在仓库根目录（flame_sdk_ios.podspec 引用）；1.0.0 Tag 仍是旧的动态
  # 单二进制，仅供历史版本解析。
  s.source = { :git => 'https://github.com/javaice007/flame_sdk_ios.git', :tag => s.version.to_s }

  s.license = {
    :type => 'Commercial',
    :text => 'Copyright Flame'
  }

  s.ios.deployment_target = '13.0'
  s.swift_version = '5.0'

  # ========= TB 静态产物 vendored xcframework（static framework，链接进客户主程序）=========
  # 位于二进制仓库 tb/ 子目录，外壳名与内部 framework 名一致（flame_sdk_ios.framework）。
  s.vendored_frameworks = 'tb/flame_sdk_ios.xcframework'

  # ========= 公共平台核心依赖 =========
  # 静态归档中的 OpenSSL 符号在客户 App 链接期由 OpenSSL-Universal 动态 framework 解析。
  s.dependency 'OpenSSL-Universal', '~> 3.6'

  # ToBid-iOS-RC 是 TB 平台核心（WindMillSDK/WindSDK/WindFoundation 静态归档）。
  # flame 静态归档内的 TB 胶水（FlameTBProvider / Tb*Adapter）对 WindMill 类的
  # 未定义符号全部在这里、于客户 App 链接期解析。
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
  # -ObjC 是静态产物正常工作的必要条件：
  #   1) 强制加载 flame 静态归档的全部 ObjC 成员（否则未被直接引用的
  #      FlameTBProvider 等不会进主程序，+load 不会执行）
  #   2) FlameTBProvider / Tb*Adapter 的 +load 自动注册依赖它触发
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
# 1. 与 TK 产物互斥
#    TB 产物（tb/flame_sdk_ios.xcframework）与 TK 产物（根目录
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
# 3. 红线（TB podspec 不得依赖以下 TK 专属组件）
#    AnyThinkiOS / AnyThinkMediation* / flame_sdk_ios_tk_sigmob_adapter /
#    AdGain / FSUnion / SigmobAd-iOS（独立 Sigmob，会与 ToBid Core WindSDK 冲突）
#    ToBid-iOS-RC 自身内置的 Sigmob/WindSDK 不属于 TK 私有 adapter，保留。
#
# 4. 升级指引
#    客户侧仅需改 Podfile 版本号：
#      pod 'flame_sdk_ios_tb', '1.0.1-alpha.2'
#    无需任何代码改动（module/import/API 均不变）；产物由动态变静态后，
#    flame 将链接进主程序（包内不再有 flame_sdk_ios.framework 动态库）。
#    1.0.1-alpha.1 的 TB 包存在外壳名缺陷（无法开箱构建），请直接用 alpha.2。
# ============================================================================
