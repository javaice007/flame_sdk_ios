Pod::Spec.new do |s|
  s.name             = 'flame_sdk_ios'
  s.version          = '0.1.0'
  s.summary          = 'Flame iOS Ad SDK'
  s.description      = 'Flame iOS advertising aggregation SDK'
  s.homepage         = 'https://www.adsurge.cn/'
  s.license          = { :type => 'MIT' }
  s.author           = { 'flame' => 'flame@toowe.com' }

  s.source           = {
    :git => 'https://github.com/javaice007/flame_sdk_ios.git',
    :tag => s.version.to_s
  }

  s.platform         = :ios, '13.0'
  s.swift_version    = '5.0'
  s.static_framework = true

  # ✅ Binary SDK
  s.source_files     = [
    'flame_sdk_ios/core/**/*.{h,m}',
    'flame_sdk_ios/utils/**/*.{h,m}',
    'flame_sdk_ios/adapter/**/*.{h,m}',
    'flame_sdk_ios/ads/**/*.{h,m}'
  ]
  s.vendored_frameworks = 'flame_sdk_ios.xcframework'

  # ========= AnyThink Core =========
    s.dependency 'AnyThinkiOS', '6.5.34'
    s.dependency 'OpenSSL-Universal', '1.1.180'
    s.dependency 'AnyThinkMediationAdxSmartdigimktCNAdapter','6.5.41.0'
    s.dependency 'AnyThinkMediationBaiduAdapter','10.022.0'
    s.dependency 'AnyThinkMediationMSAdapter','2.7.10.0.1'
    s.dependency 'AnyThinkMediationKuaiShouAdapter','4.9.20.3.1'
    s.dependency 'AnyThinkMediationSigmobAdapter','4.20.3.0'
    s.dependency 'AnyThinkMediationTTAdapter','7.2.0.0.7'
    s.dependency 'AnyThinkMediationGDTAdapter','4.15.60.7'

    s.pod_target_xcconfig = {
      'IPHONEOS_DEPLOYMENT_TARGET' => '13.0',
      'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'x86_64',
      'SDKROOT' => 'iphoneos',
      'OTHER_LDFLAGS' => '-ObjC',
      'ENABLE_USER_SCRIPT_SANDBOXING' => 'NO'
    }


  # ✅ 广告 SDK 必须
  s.user_target_xcconfig = {
    'OTHER_LDFLAGS' => '-ObjC'
  }
end
