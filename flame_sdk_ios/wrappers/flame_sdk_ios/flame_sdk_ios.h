// 方案 D 转发头（pod umbrella）：flame_sdk_ios → core binary flame_sdk_ios_core
// 接入方 #import <flame_sdk_ios/flame_sdk_ios.h> 经此转发到 core binary 的 umbrella。
// 注意：core binary 的 umbrella 头已改名为 flame_sdk_ios_core.h（方案 D 改名要求）。
#import <flame_sdk_ios_core/flame_sdk_ios_core.h>
