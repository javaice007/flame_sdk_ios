# Uncomment the next line to define a global platform for your project
# platform :ios, '9.0'
platform :ios, '13.0'

#source 'https://cdn.cocoapods.org/'
source 'https://github.com/CocoaPods/Specs.git'

def tk_pods
  pod 'AnyThinkiOS','6.5.42'
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
end

