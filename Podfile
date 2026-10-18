# ============================================================
# Podfile — Flame SDK 构建期依赖入口（Phase 5A.12 single-binary mainline）
# ------------------------------------------------------------
# 本分支（research/single-binary-mainline）只支持单二进制构建。
# 不再维护 tk/tb/dual/core/plugin 等变体。
#
# 构建命令：
#   ./xcFramework_build.sh                 # 默认 = single-binary
#   ./xcFramework_build.sh single-binary   # 显式写法
#
# 构建期依赖环境（同时声明 AnyThinkiOS + ToBid-iOS-RC）：
#   - OpenSSL-Universal：Flame core 加密需要
#   - AnyThinkiOS：TK 胶水编译期需要 AnyThinkSDK 头文件（#import <AnyThinkSDK/AnyThinkSDK.h>）
#   - ToBid-iOS-RC：TB 胶水编译期需要 WindMillSDK 头文件（#import <WindMillSDK/WindMillSDK.h>）
#
# 注意：
#   这是 SDK 工程构建期依赖，不是 Demo 接入 Podfile。
#   不要在这里 pod 'flame_sdk_ios' 或 pod 'flame_sdk_ios_tb'。
#
# 链接隔离由 xcFramework_build.sh 处理：
#   - ToBid 静态归档隔离（防止 WindMillSDK 9.4MB 静态合并污染 binary）
#   - 保留 -undefined dynamic_lookup 让 WindMill 符号留为未定义
#   - 保留 AnyThinkSDK 作为动态依赖（MH_DYLIB）
#
# 分发期依赖看：
#   flame_sdk_ios.podspec      （TK 客户，引用同一 binary + TK 广告源适配器）
#   flame_sdk_ios_tb.podspec   （TB 客户，引用同一 binary + TB 广告源适配器）
# ============================================================

platform :ios, '13.0'

source 'https://cdn.cocoapods.org/'
# source 'https://github.com/CocoaPods/Specs.git'

target 'flame_sdk_ios' do
  use_frameworks! :linkage => :static

  # 公共依赖：Flame core 加密
  # 本地镜像绕过 GitHub releases 网络下载慢（构建环境专用，正式发布用 CocoaPods 官方源）
  pod 'OpenSSL-Universal', :path => '/Users/khj/Documents/code/97_ad/ios/local_pods/OpenSSL-Universal'

  # TK 平台核心：Flame TK 胶水（FlameTKProvider + 6 At*Adapter）编译期需要 AnyThinkSDK 头文件
  # 注意：严格边界 —— 这里只放 AnyThink 核心 SDK，不放 AnyThinkMediation*Adapter / AdGain / FSUnion 等
  # 运行时广告源依赖。这些运行时依赖属于 App 接入期，只能出现在 flame_sdk_ios.podspec。
  # 否则 use_frameworks! :linkage => :static 会在 archive 阶段把三方静态框架
  # 合并进 flame_sdk_ios.framework，导致下游接入 duplicate class。
  # （TK adapter 源码已审计：只 import AnyThinkSDK/AnyThinkSDK.h，不直接 import 任何广告源 SDK。）
  pod 'AnyThinkiOS','6.5.71'

  # TB 平台核心：Flame TB 胶水（FlameTBProvider + TbRewardAdapter）编译期需要 WindMillSDK 头文件
  # 注意：ToBid-iOS-RC 内的 WindMillSDK/WindSDK/WindFoundation 都是 static archive（伪装成 framework 的 .a）。
  # 链接隔离由 xcFramework_build.sh 处理（剔除 -framework Wind* + 临时隐藏归档二进制），
  # 防止 WindMill 9.4MB 静态合并污染 flame_sdk_ios.framework binary。
  pod 'ToBid-iOS-RC', '5.5.6'

  target 'flame_sdk_iosTests' do
    # Pods for testing
  end
end

post_install do |installer|
  # Xcode 27.1 构建机临时方案：Pods 目标级 DT=13 被构建图校验拒绝（min 15.0）。
  # 正式 DT13 复建属于 P0F_RELEASE_PREFLIGHT，不在本分支范围。
  installer.target_installation_results.pod_target_installation_results.each do |pod_name, target_installation_result|
    target_installation_result.native_target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0'
    end
  end

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

      # 确保OTHER_LDFLAGS包含-ObjC（让 dyld 加载 binary 时触发 +load 自动注册）
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
  # 注：ToBid Wind* 链接隔离不在 post_install 内做，因为 CocoaPods 1.16.2 在 post_install 之后
  # 会重新写出 xcconfig（覆盖 patch）。改由 xcFramework_build.sh 在 pod install 完成后直接改写 xcconfig。
end
