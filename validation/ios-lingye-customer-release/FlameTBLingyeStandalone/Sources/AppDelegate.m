//
//  AppDelegate.m — P0D Runtime Baseline B（TEST_ONLY）
//  Flame TB 客户变体（flame_sdk_ios_tb_lingye）真机基线：
//  Flame init（OpenSSL 1.1 下 /sdk/init + AES-GCM 配置解密）→ Reward load → show → reward/close。
//  凭证经启动环境变量注入（P0D_FAPPID / P0D_FAPPKEY / P0D_FPLACE），不写入 Git。
//  标记前缀 [P0D-B]。
//
#import "AppDelegate.h"
#import <flame_sdk_ios/flame_sdk_ios.h>

static NSString *Env(NSString *k) { return [[NSProcessInfo processInfo].environment objectForKey:k]; }

@interface AppDelegate () <FlameCallback, FlameRewardListener>
@property (nonatomic, strong) id<FlameRewardAd> rewardAd;
@property (nonatomic, assign) BOOL loadOk, showOk, rewardedOrClosed;
@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.window.rootViewController = [[UIViewController alloc] init];
    [self.window makeKeyAndVisible];

    NSString *appId = Env(@"P0D_FAPPID");
    NSString *appKey = Env(@"P0D_FAPPKEY");
    NSLog(@"[P0D-B] LAUNCH cred=%@", appId.length > 0 ? @"injected" : @"MISSING");

    [FlameSdk setDebug:YES];
    NSLog(@"[P0D-B] FI_BEGIN");
    [FlameSdk initWithAppId:appId appKey:appKey callback:self];
    return YES;
}

#pragma mark FlameCallback（init）

- (void)success
{
    NSLog(@"[P0D-B] FI_RESULT=1");
    NSLog(@"[P0D-B] OPENSSL_1_1_RUNTIME_INIT=OK（配置拉取+AES-GCM 解密+ToBid init 全链成功）");
    [self p0dLoadReward];
}

- (void)fail:(NSString *)code desc:(NSString *)desc
{
    NSLog(@"[P0D-B] FI_RESULT=0 code=%@ desc=%@", code, desc);
    NSLog(@"[P0D-B] SEQ_RESULT BASELINE_B FAIL(init)");
}

#pragma mark reward chain

- (void)p0dLoadReward
{
    NSLog(@"[P0D-B] FA_LOAD_BEGIN");
    self.rewardAd = [FlameSdk createRewardAdWithViewController:self.window.rootViewController
                                                   placementId:Env(@"P0D_FPLACE")
                                                       listener:self];
    [self.rewardAd load];
}

- (void)onAdLoaded
{
    self.loadOk = YES;
    NSLog(@"[P0D-B] FA_LOAD_OK");
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if ([self.rewardAd isReady]) {
            NSLog(@"[P0D-B] FA_SHOW_BEGIN");
            [self.rewardAd show];
        } else {
            NSLog(@"[P0D-B] FA_SHOW_SKIP notReady");
            NSLog(@"[P0D-B] SEQ_RESULT BASELINE_B FAIL(notReady)");
        }
    });
}

- (void)onAdShow { self.showOk = YES; NSLog(@"[P0D-B] FA_SHOW_OK"); }
- (void)onAdClicked { NSLog(@"[P0D-B] FA_CLICKED"); }
- (void)onAdPlayComplete { NSLog(@"[P0D-B] FA_PLAY_COMPLETE"); }

- (void)onAdReward:(NSString *)userId userCustomData:(NSString *)userCustomData transId:(NSString *)transId
{
    self.rewardedOrClosed = YES;
    NSLog(@"[P0D-B] FA_REWARDED");
}

- (void)onAdClosed
{
    NSLog(@"[P0D-B] FA_CLOSED load=%d show=%d reward=%d", self.loadOk, self.showOk, self.rewardedOrClosed);
    NSLog(@"[P0D-B] SEQ_RESULT BASELINE_B %@", (self.loadOk && self.showOk) ? @"PASS(load-show-close)" : @"FAIL");
}

- (void)onAdError:(NSString *)code desc:(NSString *)desc
{
    NSLog(@"[P0D-B] FA_ERROR code=%@ desc=%@", code, desc);
    NSLog(@"[P0D-B] SEQ_RESULT BASELINE_B FAIL(adError)");
}

@end
