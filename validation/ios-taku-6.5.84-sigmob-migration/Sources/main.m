// P1-R1 迁移验证入口：引用 Flame 公共 API，强制链接 flame 静态产物，
// 触发 FlameTKProvider +load 注册与 AnyThinkSDK 符号解析（仅链接验证，不做真机广告）。
#import <flame_sdk_ios/flame_sdk_ios.h>

int main(int argc, char *argv[]) {
    @autoreleasepool {
        [FlameSdk initWithAppId:@"p1r1-validation"
                         appKey:@"p1r1-validation"
                       callback:nil];
        NSLog(@"TKSigmobConsumer: flame_sdk_ios linked OK (official Sigmob adapter)");
    }
    return 0;
}
