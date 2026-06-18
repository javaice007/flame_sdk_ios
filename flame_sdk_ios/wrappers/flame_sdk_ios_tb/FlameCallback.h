// 方案 D 转发头：pod flame_sdk_ios_tb → core binary flame_sdk_ios_core
// 接入方 #import <flame_sdk_ios_tb/FlameCallback.h> 经此转发到 flame_sdk_ios_core 模块。
#import <flame_sdk_ios_core/FlameCallback.h>
