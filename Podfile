# Uncomment the next line to define a global platform for your project
# platform :ios, '9.0'
platform :ios, '13.0'

source 'https://cdn.cocoapods.org/'
# source 'https://github.com/CocoaPods/Specs.git'

def tk_pods
  pod 'AnyThinkiOS','6.5.71'
  pod 'OpenSSL-Universal', '1.1.180'
end

target 'flame_sdk_ios' do
  # Comment the next line if you don't want to use dynamic frameworks
#  use_frameworks!
  use_frameworks! :linkage => :static
  tk_pods
  # Pods for flame_sdk_ios

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
      # 为所有target添加OpenSSL头文件路径
      config.build_settings['HEADER_SEARCH_PATHS'] ||= '$(inherited)'
      config.build_settings['HEADER_SEARCH_PATHS'] << ' ${PODS_ROOT}/OpenSSL-Universal/Frameworks/OpenSSL.xcframework/ios-arm64_arm64e_armv7_armv7s/OpenSSL.framework/Headers'
      config.build_settings['HEADER_SEARCH_PATHS'] << ' ${PODS_ROOT}/OpenSSL-Universal/Frameworks/OpenSSL.xcframework/ios-arm64_i386_x86_64-simulator/OpenSSL.framework/Headers'

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
      config.build_settings['HEADER_SEARCH_PATHS'] << ' ${PODS_ROOT}/OpenSSL-Universal/Frameworks/OpenSSL.xcframework/ios-arm64_arm64e_armv7_armv7s/OpenSSL.framework/Headers'
      config.build_settings['HEADER_SEARCH_PATHS'] << ' ${PODS_ROOT}/OpenSSL-Universal/Frameworks/OpenSSL.xcframework/ios-arm64_i386_x86_64-simulator/OpenSSL.framework/Headers'
    end
  end
end

