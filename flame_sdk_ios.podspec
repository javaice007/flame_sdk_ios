Pod::Spec.new do |s|
  s.name             = 'flame_sdk_ios'
  s.version          = '0.1.1'
  s.summary          = 'Flame iOS Ad SDK'
  s.description      = 'Flame iOS advertising aggregation SDK'
  s.homepage         = 'https://github.com/your_org/flame_sdk_ios'
  s.author           = { 'flame' => 'flame@toowe.com' }

  s.source           = {
    :http => 'https://github.com/javaice007/flame_sdk_ios/archive/refs/tags/0.1.0.zip'
  }

  # 商业sdk
  s.license = {
    :type => 'Commercial',
    :text => 'Copyright Flame'
  }

  # 3. 平台要求
  s.ios.deployment_target = '12.0'

  # ✅ Binary SDK
  s.vendored_frameworks = '**/flame_sdk_ios.xcframework'

  # ========= AnyThink Core =========
  s.dependency 'AnyThinkiOS','6.5.42'
  s.dependency 'OpenSSL-Universal', '1.1.180'
  s.dependency 'AnyThinkMediationAdxSmartdigimktCNAdapter','6.5.42.1'
  s.dependency 'AnyThinkMediationBaiduAdapter','10.032.0'
  s.dependency 'AnyThinkMediationMSAdapter','2.7.13.3.0'
  s.dependency 'AnyThinkMediationKuaiShouAdapter','4.12.20.1.0'
  s.dependency 'AnyThinkMediationSigmobAdapter','4.20.7.0'
  s.dependency 'AnyThinkMediationTTAdapter','7.4.0.0.0'
  s.dependency 'AnyThinkMediationGDTAdapter','4.15.70.0'
  
  # 注意：不要写 s.source_files，因为你不需要向用户分发源代码
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.user_target_xcconfig = { 'OTHER_LDFLAGS' => '-ObjC' }
end
