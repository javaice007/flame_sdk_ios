Pod::Spec.new do |s|
  s.name             = 'flame_sdk_ios'
  s.version          = '0.1.4'
  s.summary          = 'Flame iOS Ad SDK'
  s.description      = 'Flame iOS advertising aggregation SDK'
  s.homepage         = 'https://github.com/javaice007/flame_sdk_ios'
  s.author           = { 'flame' => 'flame@toowe.com' }

  s.source           = {
    :http => 'https://github.com/javaice007/flame_sdk_ios/archive/refs/tags/0.1.4.zip'
  }

  # 商业sdk
  s.license = {
    :type => 'Commercial',
    :text => 'Copyright Flame'
  }

  # 3. 平台要求
  s.ios.deployment_target = '12.0'
  s.swift_version = '5.0'

  # ✅ Binary SDK
  s.vendored_frameworks = '**/flame_sdk_ios.xcframework'

  # ========= AD Core =========
  s.dependency 'OpenSSL-Universal', '1.1.180'
  
  s.dependency 'AnyThinkiOS','6.5.42'
  #Anythink Kuying Adx SDK(necessary)
  s.dependency 'AnyThinkMediationAdxSmartdigimktCNAdapter','6.5.45.0'
  s.dependency 'AnyThinkMediationGromoreAdapter','7.4.0.0.0'
  s.dependency 'AnyThinkMediationBaiduAdapter','10.032.1'
  #Baidu--4.80 SDK,podfile文件顶部增加 source 'https://github.com/CocoaPods/Specs.git'
  s.dependency 'AnyThinkMediationMSAdapter','2.7.13.3.2'
  s.dependency 'AnyThinkMediationZYAdapter','2.5.9.28.2'
  s.dependency 'AnyThinkMediationBeiZiAdapter','5.0.0.2.0'
  s.dependency 'AnyThinkMediationKuaiShouAdapter','4.12.20.1.0'
  s.dependency 'AnyThinkMediationSigmobAdapter','4.20.7.0'
  s.dependency 'AnyThinkMediationTTAdapter_Mix','7.4.0.0.0'
  s.dependency 'AnyThinkMediationGDTAdapter','4.15.70.1'
  
  # 注意：不要写 s.source_files，因为你不需要向用户分发源代码
  s.pod_target_xcconfig = {
    'OTHER_LDFLAGS' => '-ObjC',
    'DEFINES_MODULE' => 'YES'
  }
end
