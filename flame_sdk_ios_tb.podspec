# Flame iOS Ad SDK — TB 客户 podspec
# 适用于 TB 聚合接入。与 flame_sdk_ios 互斥，不能同时接入。
# 客户只需：pod 'flame_sdk_ios_tb'
Pod::Spec.new do |s|
  s.name             = 'flame_sdk_ios_tb'
  s.version          = '1.0.0-alpha.1'
  s.module_name      = 'flame_sdk_ios'
  s.summary          = 'Flame iOS Ad SDK - TB Edition'
  s.description      = 'Flame iOS advertising aggregation SDK. TB edition.'
  s.homepage         = 'https://github.com/javaice007/flame_sdk_ios'
  s.author           = { 'flame' => 'flame@toowe.com' }

  s.source = { :git => 'https://github.com/javaice007/flame_sdk_ios.git', :tag => s.version.to_s }

  s.license = {
    :type => 'Commercial',
    :text => 'Copyright Flame'
  }

  s.ios.deployment_target = '13.0'
  s.swift_version = '5.0'

  # 单二进制（与 flame_sdk_ios podspec 共用同一份）
  s.vendored_frameworks = 'flame_sdk_ios.xcframework'

  # 公共平台核心依赖
  s.dependency 'OpenSSL-Universal', '~> 3.6'
  s.dependency 'AnyThinkiOS', '6.5.71'
  s.dependency 'ToBid-iOS-RC', '5.5.6'

  # 不依赖 TK 广告源适配器（flame_sdk_ios_tk_sigmob_adapter / AnyThinkMediation* / AdGain / FSUnion）

  s.pod_target_xcconfig = {
    'OTHER_LDFLAGS' => '$(inherited) -ObjC'
  }

  s.user_target_xcconfig = {
    'OTHER_LDFLAGS' => '$(inherited) -ObjC'
  }
end
