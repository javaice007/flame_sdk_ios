# ============================================================
# Podfile — Flame SDK 构建期依赖入口
# ------------------------------------------------------------
# 默认构建 TK 变体：
#   pod install
#   FLAME_SDK_VARIANT=tk pod install
#
# 构建 TB 变体：
#   FLAME_SDK_VARIANT=tb pod install
#
# 注意：
#   这是 SDK 工程构建期依赖，不是 Demo 接入 Podfile。
#   不要在这里 pod 'flame_sdk_ios' 或 pod 'flame_sdk_ios_tb'。
#
# 分发期依赖看：
#   flame_sdk_ios.podspec      （TK 默认包，外部依赖模式）
#   flame_sdk_ios_tb.podspec   （TB 包，自包含 WindMill 模式）
# ============================================================

variant = ENV.fetch('FLAME_SDK_VARIANT', 'tk').downcase

unless ['tk', 'tb'].include?(variant)
  raise "❌ Invalid FLAME_SDK_VARIANT=#{variant}. Use tk or tb."
end

puts "🔥 Flame SDK build variant: #{variant}"

platform :ios, '13.0'

source 'https://cdn.cocoapods.org/'
# source 'https://github.com/CocoaPods/Specs.git'

target 'flame_sdk_ios' do
  use_frameworks! :linkage => :static

  pod 'OpenSSL-Universal', '~> 3.6'

  if variant == 'tk'
    # TK / TopOn / AnyThink 构建期依赖
    # ⚠️ 严格边界：这里只放 Flame 源码编译直接需要的 AnyThink 核心 SDK。
    #    不要放 AnyThinkMediation*Adapter / AdGain / FSUnion / CSJ / GDT / Sigmob 等运行时广告源依赖。
    #    这些运行时依赖属于 App 接入期，只能出现在 flame_sdk_ios.podspec。
    #    否则 use_frameworks! :linkage => :static 会在 archive 阶段把三方静态框架
    #    合并进 flame_sdk_ios.framework，导致下游接入 duplicate class。
    #    （TK adapter 源码已审计：只 import AnyThinkSDK/AnyThinkSDK.h，不直接 import 任何广告源 SDK。）
    pod 'AnyThinkiOS','6.5.71'
  end

  if variant == 'tb'
    # TB / ToBid 构建期依赖
    # 注意：这里只是 SDK 构建期需要 ToBid 头文件和静态库。
    # flame_sdk_ios_tb.podspec 分发期不能再声明 ToBid-iOS-RC，
    # 因为 build/tb/flame_sdk_ios.xcframework 已经静态内置 WindMill。
    pod 'ToBid-iOS-RC', '5.5.6'
  end

  target 'flame_sdk_iosTests' do
    # Pods for testing
  end
end

post_install do |installer|
  # 🔥 修复 Xcode 15 + BSD realpath 不支持 -m 的问题
  installer.aggregate_targets.each do |aggregate_target|
    support_dir = installer.sandbox.target_support_files_dir(aggregate_target.name)
    script_path = File.join(
      support_dir,
      "Pods-#{aggregate_target.name}-resources.sh"
    )

    if File.exist?(script_path)
      script = File.read(script_path)

      if script.include?("realpath -m")
        puts "🔧 Patching realpath -m in #{script_path}"
        script.gsub!("realpath -m", "realpath")
        File.open(script_path, "w") { |f| f.write(script) }
      end
    end
  end

  # ✅ 添加 OpenSSL 头文件搜索路径
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['HEADER_SEARCH_PATHS'] ||= '$(inherited)'
      config.build_settings['HEADER_SEARCH_PATHS'] << ' ${PODS_ROOT}/OpenSSL-Universal/OpenSSL.xcframework/ios-arm64/OpenSSL.framework/Headers'
      config.build_settings['HEADER_SEARCH_PATHS'] << ' ${PODS_ROOT}/OpenSSL-Universal/OpenSSL.xcframework/ios-arm64_x86_64-simulator/OpenSSL.framework/Headers'

      # 确保OTHER_LDFLAGS包含-ObjC
      config.build_settings['OTHER_LDFLAGS'] ||= '$(inherited)'
      unless config.build_settings['OTHER_LDFLAGS'].include?('-ObjC')
        config.build_settings['OTHER_LDFLAGS'] << ' -ObjC'
      end
    end
  end

  # ✅ 为主工程target也添加配置
  installer.target_installation_results.pod_target_installation_results.each do |pod_name, target_installation_result|
    target_installation_result.native_target.build_configurations.each do |config|
      config.build_settings['HEADER_SEARCH_PATHS'] ||= '$(inherited)'
      config.build_settings['HEADER_SEARCH_PATHS'] << ' ${PODS_ROOT}/OpenSSL-Universal/OpenSSL.xcframework/ios-arm64/OpenSSL.framework/Headers'
      config.build_settings['HEADER_SEARCH_PATHS'] << ' ${PODS_ROOT}/OpenSSL-Universal/OpenSSL.xcframework/ios-arm64_x86_64-simulator/OpenSSL.framework/Headers'
    end
  end
end
