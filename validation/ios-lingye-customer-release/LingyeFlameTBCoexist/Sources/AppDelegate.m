//
//  AppDelegate.m — P0D Host C（TEST_ONLY 共存运行时矩阵）
//  探针（只读透明，method exchange 后必回原实现）：
//    ATAPI startWithAppID:appKey:error: / startWithAppID:appKey:sdkConfigures:error:
//    WindMillAds setupSDKWithAppId:completionHandler: / setupSDKWithAppId:sdkConfigures:completionHandler:
//  序列（env P0D_SEQ）：CASE_A / CASE_B / C1 / C2 / C3 / C4 / REINIT_LI / REINIT_FI / REINIT_MIX1 / REINIT_MIX2
//  Flame 凭证经 env 注入（P0D_FAPPID/P0D_FAPPKEY/P0D_FPLACE），不写入 Git。
//  标记前缀 [P0D-C]。
//
#import "AppDelegate.h"
#import "P0DLingyeTestIDs.h"
#import "P0DNetProbe.h"
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <CJMobileAd/CJMobileAd.h>
#import <flame_sdk_ios/flame_sdk_ios.h>

static NSInteger gTakuInitCalls = 0;
static NSInteger gTobidInitCalls = 0;
static NSString *Env(NSString *k) { return [[NSProcessInfo processInfo].environment objectForKey:k]; }

#pragma mark - 只读探针（+load 安装，调用后继续原实现）

static void P0DLogStack(NSString *tag)
{
    NSArray *syms = [NSThread callStackSymbols];
    NSArray *trim = syms.count > 12 ? [syms subarrayWithRange:NSMakeRange(0, 12)] : syms;
    NSLog(@"[P0D-C] PROBE %@ stack=\n%@", tag, [trim componentsJoinedByString:@"\n"]);
}

@interface P0DProbe : NSObject
@end
@implementation P0DProbe

+ (void)load { /* 探针安装移至 installProbes（didFinishLaunching）*/ }

+ (void)installProbes
{
    Class atapi = NSClassFromString(@"ATAPI");
    if (atapi) {
        SEL orig1 = NSSelectorFromString(@"startWithAppID:appKey:error:");
        SEL orig2 = NSSelectorFromString(@"startWithAppID:appKey:sdkConfigures:error:");
        Method m1 = class_getClassMethod(atapi, orig1);
        Method m2 = class_getClassMethod(atapi, orig2);
        if (m1) {
            Method p1 = class_getClassMethod(self, @selector(p0d_atapi1:appKey:error:));
            method_exchangeImplementations(m1, p1);
        }
        if (m2) {
            Method p2 = class_getClassMethod(self, @selector(p0d_atapi2:appKey:sdkConfigures:error:));
            method_exchangeImplementations(m2, p2);
        }
        NSLog(@"[P0D-C] PROBE_INSTALLED ATAPI(%d,%d)", m1 != NULL, m2 != NULL);
        if (!m1 && atapi) {
            unsigned int n = 0;
            Method *all = class_copyMethodList(object_getClass(atapi), &n);   // 类方法在 meta-class
            NSMutableString *names = [NSMutableString string];
            for (unsigned int i = 0; i < n && i < 25; i++) {
                [names appendFormat:@"%@ ", NSStringFromSelector(method_getName(all[i]))];
            }
            free(all);
            NSLog(@"[P0D-C] PROBE_DIAG ATAPI image=%@ metaMethods(%u)=%@",
                  [NSString stringWithUTF8String:class_getImageName(atapi) ?: "-"], n, names);
        }
    } else {
        NSLog(@"[P0D-C] PROBE ATAPI_CLASS_ABSENT");
    }
    Class wm = NSClassFromString(@"WindMillAds");
    if (wm) {
        Method w1 = class_getClassMethod(wm, NSSelectorFromString(@"setupSDKWithAppId:completionHandler:"));
        Method w2 = class_getClassMethod(wm, NSSelectorFromString(@"setupSDKWithAppId:sdkConfigures:completionHandler:"));
        if (w1) method_exchangeImplementations(w1, class_getClassMethod(self, @selector(p0d_wm1:completionHandler:)));
        if (w2) method_exchangeImplementations(w2, class_getClassMethod(self, @selector(p0d_wm2:sdkConfigures:completionHandler:)));
        NSLog(@"[P0D-C] PROBE_INSTALLED WindMillAds(%d,%d)", w1 != NULL, w2 != NULL);
    }
}

+ (BOOL)p0d_atapi1:(NSString *)appID appKey:(NSString *)appKey error:(NSError **)error
{
    gTakuInitCalls++;
    NSLog(@"[P0D-C] PROBE TAKU_INIT_CALLED appID=%@", appID);
    P0DLogStack(@"TAKU");
    return [self p0d_atapi1:appID appKey:appKey error:error]; // exchange 后此调用即原实现
}

+ (BOOL)p0d_atapi2:(NSString *)appID appKey:(NSString *)appKey sdkConfigures:(NSArray *)cfg error:(NSError **)error
{
    gTakuInitCalls++;
    NSLog(@"[P0D-C] PROBE TAKU_INIT_CALLED(cfg) appID=%@", appID);
    P0DLogStack(@"TAKU");
    return [self p0d_atapi2:appID appKey:appKey sdkConfigures:cfg error:error];
}

+ (void)p0d_wm1:(NSString *)appId completionHandler:(void (^)(BOOL, NSError *))h
{
    gTobidInitCalls++;
    NSLog(@"[P0D-C] PROBE TOBID_INIT_CALLED appId=%@", appId);
    [self p0d_wm1:appId completionHandler:h];
}

+ (void)p0d_wm2:(NSString *)appId sdkConfigures:(NSArray *)cfg completionHandler:(void (^)(BOOL, NSError *))h
{
    gTobidInitCalls++;
    NSLog(@"[P0D-C] PROBE TOBID_INIT_CALLED(cfg) appId=%@", appId);
    [self p0d_wm2:appId sdkConfigures:cfg completionHandler:h];
}

@end

#pragma mark - 序列器

@interface AppDelegate () <FlameCallback, FlameRewardListener, CJRewardVideoAdDelegate>
@property (nonatomic, strong) NSArray<NSString *> *steps;
@property (nonatomic, assign) NSUInteger idx;
@property (nonatomic, assign) BOOL seqFail;
@property (nonatomic, strong) id<FlameRewardAd> rewardAd;
@property (nonatomic, strong) CJRewardVideoAd *cjReward;
@property (nonatomic, copy) void (^adDone)(BOOL);
@property (nonatomic, copy) void (^flameInitDone)(BOOL);
@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    [P0DProbe installProbes];
    [P0DNetProbe install];   // +load 时 AnyThinkSDK 动态框架可能未加载，此处挂探针
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.window.rootViewController = [[UIViewController alloc] init];
    [self.window makeKeyAndVisible];

    NSString *seq = Env(@"P0D_SEQ") ?: @"CASE_A";
    NSDictionary *map = @{
        @"CASE_A":      @[@"LI",@"LA",@"FI",@"FA",@"LA",@"FA"],
        @"CASE_B":      @[@"FI",@"FA",@"LI",@"LA",@"FA",@"LA"],
        @"C1":          @[@"LI",@"LA",@"FI",@"FA"],
        @"C2":          @[@"FI",@"FA",@"LI",@"LA"],
        @"C3":          @[@"LI",@"FI",@"LA",@"FA",@"LA",@"FA"],
        @"C4":          @[@"FI",@"LI",@"FA",@"LA",@"FA",@"LA"],
        @"REINIT_LI":   @[@"LI",@"LI",@"LA"],
        @"REINIT_FI":   @[@"FI",@"FI",@"FA"],
        @"REINIT_MIX1": @[@"LI",@"FI",@"LI",@"LA"],
        @"REINIT_MIX2": @[@"FI",@"LI",@"FI",@"FA"],
        @"C0":           @[@"FI"],            // §16：仅链接，不调 CJ 任何 API
        @"C1":           @[@"CJLOG",@"FI"],   // §16：只 openDebugLog
        @"C2":           @[@"LI",@"FI"],
    };
    self.steps = map[seq] ?: @[@"LI"];
    NSLog(@"[P0D-C] LAUNCH seq=%@ steps=%@ taku=? tobid=?", seq, [self.steps componentsJoinedByString:@","]);
    [self p0dNext];
    return YES;
}

- (void)p0dNext
{
    if (self.idx >= self.steps.count) {
        NSLog(@"[P0D-C] SEQ_RESULT %@ %@ TAKU_TOTAL=%ld TOBID_TOTAL=%ld",
              self.steps.firstObject ?: @"?", self.seqFail ? @"FAIL" : @"PASS",
              (long)gTakuInitCalls, (long)gTobidInitCalls);
        return;
    }
    NSString *s = self.steps[self.idx++];
    NSInteger t0 = gTakuInitCalls, b0 = gTobidInitCalls;
    void (^done)(BOOL) = ^(BOOL ok) {
        NSLog(@"[P0D-C] STEP %@ %@ takuDelta=%ld tobidDelta=%ld",
              s, ok ? @"OK" : @"FAIL", (long)(gTakuInitCalls - t0), (long)(gTobidInitCalls - b0));
        if (!ok) self.seqFail = YES;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self p0dNext];
        });
    };
    if ([s isEqualToString:@"LI"]) [self p0dLingyeInit:done];
    else if ([s isEqualToString:@"CJLOG"]) { [CJADManager openDebugLog]; done(YES); }
    else if ([s isEqualToString:@"FI"]) [self p0dFlameInit:done];
    else if ([s isEqualToString:@"LA"]) [self p0dLingyeReward:done];
    else if ([s isEqualToString:@"FA"]) [self p0dFlameReward:done];
    else done(YES);
}

- (void)p0dLingyeInit:(void (^)(BOOL))done
{
    NSLog(@"[P0D-C] LI_BEGIN");
    [CJADManager openDebugLog];
    [CJADManager configure:P0D_LINGYE_APP_ID completeHandle:^(BOOL success, NSError * _Nullable error) {
        NSLog(@"[P0D-C] LI_RESULT=%d err=%@", success ? 1 : 0, error.localizedDescription ?: @"-");
        done(success);
    }];
}

- (void)p0dFlameInit:(void (^)(BOOL))done
{
    NSLog(@"[P0D-C] FI_BEGIN");
    [FlameSdk setDebug:YES];
    [FlameSdk initWithAppId:Env(@"P0D_FAPPID") appKey:Env(@"P0D_FAPPKEY") callback:self];
    self.flameInitDone = done; // 回调在 FlameCallback 协议里触发
}

- (void)p0dLingyeReward:(void (^)(BOOL))done
{
    NSLog(@"[P0D-C] LA_BEGIN");
    self.adDone = done;
    self.cjReward = [[CJRewardVideoAd alloc] initWithResourceId:P0D_LINGYE_REWARD_ID userId:@"p0d" extend:@""];
    self.cjReward.delegate = self;
    [self.cjReward loadAdData];
}

- (void)p0dFlameReward:(void (^)(BOOL))done
{
    NSLog(@"[P0D-C] FA_BEGIN");
    self.adDone = done;
    self.rewardAd = [FlameSdk createRewardAdWithViewController:self.window.rootViewController
                                                   placementId:Env(@"P0D_FPLACE")
                                                       listener:self];
    [self.rewardAd load];
}

#pragma mark FlameCallback

- (void)success { NSLog(@"[P0D-C] FI_RESULT=1"); if (self.flameInitDone) { void (^d)(BOOL) = self.flameInitDone; self.flameInitDone = nil; d(YES); } }
- (void)fail:(NSString *)code desc:(NSString *)desc
{
    NSLog(@"[P0D-C] FI_RESULT=0 code=%@ desc=%@", code, desc);
    if (self.flameInitDone) { void (^d)(BOOL) = self.flameInitDone; self.flameInitDone = nil; d(NO); }
}

#pragma mark FlameRewardListener

- (void)onAdLoaded
{
    NSLog(@"[P0D-C] FA_LOAD_OK");
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if ([self.rewardAd isReady]) { NSLog(@"[P0D-C] FA_SHOW_BEGIN"); [self.rewardAd show]; }
        else { NSLog(@"[P0D-C] FA_SHOW_SKIP notReady"); if (self.adDone) self.adDone(NO); }
    });
}
- (void)onAdShow { NSLog(@"[P0D-C] FA_SHOW_OK"); }
- (void)onAdClicked { NSLog(@"[P0D-C] FA_CLICKED"); }
- (void)onAdPlayComplete { NSLog(@"[P0D-C] FA_PLAY_COMPLETE"); }
- (void)onAdReward:(NSString *)userId userCustomData:(NSString *)userCustomData transId:(NSString *)transId
{ NSLog(@"[P0D-C] FA_REWARDED"); }
- (void)onAdClosed
{
    NSLog(@"[P0D-C] FA_CLOSED");
    if (self.adDone) { self.adDone(YES); self.adDone = nil; }
}
- (void)onAdError:(NSString *)code desc:(NSString *)desc
{
    NSLog(@"[P0D-C] FA_ERROR code=%@ desc=%@", code, desc);
    if (self.adDone) { self.adDone(NO); self.adDone = nil; }
}

#pragma mark CJRewardVideoAdDelegate

- (void)rewardVideoAdDidLoad:(CJRewardVideoAd *)rewardAd resourceId:(NSString *)resourceId
{
    NSLog(@"[P0D-C] LA_LOAD_OK channel=%@", [rewardAd getAdType] ?: @"-");
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSLog(@"[P0D-C] LA_SHOW_BEGIN");
        [rewardAd showFromRootViewController:self.window.rootViewController];
    });
}
- (void)rewardVideoAdLoadFailed:(CJRewardVideoAd *)rewardAd error:(NSError *)error
{
    NSLog(@"[P0D-C] LA_LOAD_FAIL err=%@", error);
    if (self.adDone) { self.adDone(NO); self.adDone = nil; }
}
- (void)rewardVideoOnRewarded:(CJRewardVideoAd *)rewardAd requestId:(NSString *)requestId
{ NSLog(@"[P0D-C] LA_REWARDED"); }
- (void)rewardVideoAdOnClosed:(CJRewardVideoAd *)rewardAd
{
    NSLog(@"[P0D-C] LA_CLOSED");
    if (self.adDone) { self.adDone(YES); self.adDone = nil; }
}

@end
