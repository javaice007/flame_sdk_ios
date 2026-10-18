//
//  P0FTestCore.m — 统一控制层实现（TEST_ONLY）
//

#import "P0FTestCore.h"
#import "P0DLingyeTestIDs.h"
#import <flame_sdk_ios/flame_sdk_ios.h>
#import <CJMobileAd/CJMobileAd.h>

#if __has_include("P0FSecretConfig.h")
#import "P0FSecretConfig.h"
#endif

NSString * const P0FOwnerLingye = @"LINGYE";
NSString * const P0FOwnerFlame  = @"FLAME";
NSString * const P0FKindInit    = @"INIT";
NSString * const P0FKindSplash  = @"SPLASH";
NSString * const P0FKindReward  = @"REWARD";

static NSString *P0FEnv(NSString *k) { return [[NSProcessInfo processInfo].environment objectForKey:k]; }

static NSString *P0FNow(void)
{
    NSDateFormatter *f = [[NSDateFormatter alloc] init];
    f.dateFormat = @"HH:mm:ss";
    return [f stringFromDate:[NSDate date]];
}

@implementation P0FAdEvent

- (NSString *)line
{
    NSString *prefix = [NSString stringWithFormat:@"%@-%@", self.owner, self.kind];
    if ([self.kind isEqualToString:P0FKindInit]) prefix = self.owner;
    NSMutableString *s = [NSMutableString stringWithFormat:@"%@ [%@] %@ %@", P0FNow(), prefix, self.action, self.ok ? @"PASS" : @"FAIL"];
    if (self.network)        [s appendFormat:@" network=%@", self.network];
    if (self.flamePlacement) [s appendFormat:@" flamePlacement=%@", self.flamePlacement];
    if (self.thirdPlacement) [s appendFormat:@" thirdPlacement=%@", self.thirdPlacement];
    if (self.transId)        [s appendFormat:@" transId=%@", self.transId];
    if (self.requestId)      [s appendFormat:@" requestId=%@", self.requestId];
    if (self.attempt > 0)    [s appendFormat:@" attempt=#%ld", (long)self.attempt];
    if (self.code)           [s appendFormat:@" code=%@", self.code];
    if (self.message.length) [s appendFormat:@" message=%@", self.message];
    return s;
}

@end

#pragma mark - P0FLogTap

static int gOrigStdOut = -1;
static int gOrigStdErr = -1;
static BOOL gTapStarted = NO;

@interface P0FLogTap ()
- (void)parseLine:(NSString *)line;
@end

@implementation P0FLogTap {
    NSDictionary *_lastAdShowReport;
    NSDictionary *_lastAdReadyReport;
    NSString *_resolvedTobidAppId;
}

+ (instancetype)shared
{
    static P0FLogTap *s;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ s = [[P0FLogTap alloc] init]; });
    return s;
}

- (void)start
{
    @synchronized ([P0FLogTap class]) {
        if (gTapStarted) return;
        gTapStarted = YES;
    }
    [self tapFD:STDOUT_FILENO savedTo:&gOrigStdOut];
    [self tapFD:STDERR_FILENO savedTo:&gOrigStdErr];
    NSLog(@"[P0F] LOGTAP started (stdout+stderr captured, original fds preserved)");
}

- (void)tapFD:(int)fd savedTo:(int *)saved
{
    int p[2];
    if (pipe(p) != 0) return;
    *saved = dup(fd);
    if (*saved < 0) { close(p[0]); close(p[1]); return; }
    dup2(p[1], fd);
    close(p[1]);
    int readFD = p[0];
    int origFD = *saved;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        NSMutableData *buf = [NSMutableData data];
        uint8_t chunk[8192];
        ssize_t n;
        NSData *nl = [NSData dataWithBytes:"\n" length:1];
        while ((n = read(readFD, chunk, sizeof(chunk))) > 0) {
            [buf appendBytes:chunk length:(NSUInteger)n];
            NSRange r;
            while ((r = [buf rangeOfData:nl options:0 range:NSMakeRange(0, buf.length)]).location != NSNotFound) {
                NSData *lineData = [buf subdataWithRange:NSMakeRange(0, r.location)];
                [buf replaceBytesInRange:NSMakeRange(0, r.location + 1) withBytes:NULL length:0];
                NSString *line = [[NSString alloc] initWithData:lineData encoding:NSUTF8StringEncoding];
                if (!line) line = [[NSString alloc] initWithData:lineData encoding:NSISOLatin1StringEncoding];
                // 原样回写原始 fd（写原始 fd 不会回流 pipe，无递归；Xcode/Console 仍可见）
                if (origFD >= 0 && line) {
                    const char *bytes = line.UTF8String ?: "";
                    write(origFD, bytes, strlen(bytes));
                    write(origFD, "\n", 1);
                }
                [[P0FLogTap shared] parseLine:line ?: @""];
            }
            if (buf.length > (NSUInteger)1 << 20) [buf setLength:0];
        }
    });
}

- (NSDictionary *)lastAdShowReport  { @synchronized (self) { return _lastAdShowReport; } }
- (NSDictionary *)lastAdReadyReport { @synchronized (self) { return _lastAdReadyReport; } }
- (NSString *)resolvedTobidAppId    { @synchronized (self) { return _resolvedTobidAppId; } }

- (void)parseLine:(NSString *)line
{
    if (line.length == 0) return;
    NSString *tag = nil;
    if ([line containsString:@"[onReport] AdDidShow:"]) tag = @"show";
    else if ([line containsString:@"[onReport] AdDidReady:"]) tag = @"ready";
    else if ([line containsString:@"TOBID_INIT_CALLED appId="]) {
        NSRange r = [line rangeOfString:@"TOBID_INIT_CALLED appId="];
        NSString *rest = [line substringFromIndex:NSMaxRange(r)];
        NSString *appId = [[rest componentsSeparatedByCharactersInSet:
                            [NSCharacterSet whitespaceAndNewlineCharacterSet]] firstObject];
        if (appId.length) {
            @synchronized (self) { _resolvedTobidAppId = appId; }
        }
        return;
    } else {
        return;
    }
    NSRange first = [line rangeOfString:@"{"];
    NSRange last = [line rangeOfString:@"}" options:NSBackwardsSearch];
    if (first.location == NSNotFound || last.location == NSNotFound || last.location <= first.location) return;
    NSString *json = [line substringWithRange:NSMakeRange(first.location, NSMaxRange(last) - first.location)];
    NSData *d = [json dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *obj = d ? [NSJSONSerialization JSONObjectWithData:d options:0 error:NULL] : nil;
    if (![obj isKindOfClass:[NSDictionary class]]) return;
    NSMutableDictionary *m = [obj mutableCopy];
    m[@"_ts"] = @([[NSDate date] timeIntervalSince1970]);
    if ([tag isEqualToString:@"show"]) {
        @synchronized (self) { _lastAdShowReport = m; }
    } else {
        @synchronized (self) { _lastAdReadyReport = m; }
    }
}

+ (NSString *)networkNameForId:(NSInteger)networkId
{
    static NSDictionary<NSNumber *, NSString *> *map;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        // P0E 运行时日志取证过的 ToBid networkId 映射
        map = @{ @22 : @"csj", @16 : @"gdt", @19 : @"ks", @21 : @"baidu", @9 : @"sigmob" };
    });
    return map[@(networkId)] ?: [NSString stringWithFormat:@"network_%ld", (long)networkId];
}

@end

#pragma mark - Config

@implementation P0FAdConfig

+ (instancetype)current
{
    static P0FAdConfig *s;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        s = [[P0FAdConfig alloc] init];
        s.flameAppId  = P0FEnv(@"P0D_FAPPID")  ?: @"";
        s.flameAppKey = P0FEnv(@"P0D_FAPPKEY") ?: @"";
        s.flameRewardPlacement = P0FEnv(@"P0D_FPLACE") ?: @"";
        s.flameSplashPlacement = @"";
        s.lingyeSplashId       = @"";
#if __has_include("P0FSecretConfig.h")
        if (!s.flameAppId.length)           s.flameAppId           = P0F_FLAME_APP_ID;
        if (!s.flameAppKey.length)          s.flameAppKey          = P0F_FLAME_APP_KEY;
        if (!s.flameRewardPlacement.length) s.flameRewardPlacement = P0F_FLAME_REWARD_PLACEMENT;
        s.flameSplashPlacement = P0F_FLAME_SPLASH_PLACEMENT ?: @"";
        s.lingyeSplashId       = P0F_LINGYE_SPLASH_ID ?: @"";
#endif
        s.lingyeAppId    = P0D_LINGYE_APP_ID;
        s.lingyeRewardId = P0D_LINGYE_REWARD_ID;
    });
    return s;
}

@end

#pragma mark - P0FBaseController

@implementation P0FBaseController

- (P0FAdEvent *)emitOwner:(NSString *)owner kind:(NSString *)kind action:(NSString *)action ok:(BOOL)ok
                  network:(NSString *)network flamePlacement:(NSString *)fp thirdPlacement:(NSString *)tp
                  transId:(NSString *)tid requestId:(NSString *)rid code:(NSString *)code
                  message:(NSString *)msg attempt:(NSInteger)attempt
{
    if (![NSThread isMainThread]) {
        __block P0FAdEvent *e;
        dispatch_sync(dispatch_get_main_queue(), ^{
            e = [self emitOwner:owner kind:kind action:action ok:ok network:network flamePlacement:fp
                 thirdPlacement:tp transId:tid requestId:rid code:code message:msg attempt:attempt];
        });
        return e;
    }
    P0FAdEvent *ev = [[P0FAdEvent alloc] init];
    ev.owner = owner; ev.kind = kind; ev.action = action; ev.ok = ok;
    ev.network = network; ev.flamePlacement = fp; ev.thirdPlacement = tp;
    ev.transId = tid; ev.requestId = rid; ev.code = code; ev.message = msg; ev.attempt = attempt;
    NSLog(@"[P0F] %@", ev.line);
    id<P0FTestListener> l = [(id)self listener];
    if (l) [l p0fEvent:ev];
    return ev;
}

- (void)armWatchdog:(NSTimeInterval)sec gen:(NSInteger)gen fire:(dispatch_block_t)fire
{
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(sec * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), fire);
}

@end

#pragma mark - LingyeTestController

@interface LingyeTestController () <CJRewardVideoAdDelegate, CJSplashAdDelegate>
@property (nonatomic, strong) P0FAdConfig *config;
@property (nonatomic, assign) P0FSDKState sdkState;
@property (nonatomic, assign) P0FAdState rewardState;
@property (nonatomic, assign) P0FAdState splashState;
@property (nonatomic, assign) NSInteger rewardAttempt;
@property (nonatomic, copy) NSString *lastRewardNetwork;
@property (nonatomic, copy) NSString *lastRewardRequestId;
@property (nonatomic, weak) UIViewController *rootVC;
@property (nonatomic, weak) UIWindow *window;
@property (nonatomic, strong) CJRewardVideoAd *rewardAd;
@property (nonatomic, strong) CJSplashAd *splashAd;
@property (nonatomic, copy) P0FAdDone initDone;
@property (nonatomic, copy) P0FAdDone loadDone;
@property (nonatomic, copy) P0FAdDone showDone;
@property (nonatomic, copy) P0FAdDone splashLoadDone;
@property (nonatomic, copy) P0FAdDone splashShowDone;
@property (nonatomic, assign) NSInteger gen;
@end

@implementation LingyeTestController

+ (instancetype)shared
{
    static LingyeTestController *s;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ s = [[LingyeTestController alloc] init]; });
    return s;
}

- (instancetype)init
{
    self = [super init];
    _config = [P0FAdConfig current];
    _sdkState = P0FSDKStateNotInitialized;
    _rewardState = P0FAdStateIdle;
    _splashState = P0FAdStateIdle;
    return self;
}

- (void)setRootViewController:(UIViewController *)rootVC window:(UIWindow *)window
{
    _rootVC = rootVC;
    _window = window;
}

- (P0FAdEvent *)ev:(NSString *)kind action:(NSString *)action ok:(BOOL)ok
           network:(NSString *)network thirdPlacement:(NSString *)tp
          requestId:(NSString *)rid code:(NSString *)code message:(NSString *)msg attempt:(NSInteger)attempt
{
    return [self emitOwner:P0FOwnerLingye kind:kind action:action ok:ok network:network
            flamePlacement:nil thirdPlacement:tp transId:nil requestId:rid
                      code:code message:msg attempt:attempt];
}

#pragma mark init

- (void)initSDK:(P0FAdDone)done
{
    if (self.sdkState == P0FSDKStateInitializing) {
        if (done) done(NO, @"BUSY", @"init already in flight");
        return;
    }
    self.sdkState = P0FSDKStateInitializing;
    self.gen++;
    NSInteger gen = self.gen;
    self.initDone = done;
    [self ev:P0FKindInit action:@"INIT" ok:YES network:nil thirdPlacement:nil requestId:nil code:nil message:@"START" attempt:0];
    [self armWatchdog:30 gen:gen fire:^{
        if (gen == self.gen && self.sdkState == P0FSDKStateInitializing) {
            self.sdkState = P0FSDKStateError;
            [self ev:P0FKindInit action:@"TIMEOUT" ok:NO network:nil thirdPlacement:nil requestId:nil code:@"TIMEOUT" message:@"init no callback in 30s" attempt:0];
            if (self.initDone) { P0FAdDone d = self.initDone; self.initDone = nil; d(NO, @"TIMEOUT", @"init no callback in 30s"); }
        }
    }];
    [CJADManager openDebugLog];
    __weak typeof(self) w = self;
    [CJADManager configure:self.config.lingyeAppId completeHandle:^(BOOL success, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [w onInitResult:success error:error gen:gen];
        });
    }];
}

- (void)onInitResult:(BOOL)success error:(NSError *)error gen:(NSInteger)gen
{
    if (gen != self.gen || self.sdkState != P0FSDKStateInitializing) return;
    if (success) {
        self.sdkState = P0FSDKStateReady;
        [self ev:P0FKindInit action:@"INIT" ok:YES network:nil thirdPlacement:nil requestId:nil code:nil message:@"PASS" attempt:0];
    } else {
        self.sdkState = P0FSDKStateError;
        [self ev:P0FKindInit action:@"ERROR" ok:NO network:nil thirdPlacement:nil requestId:nil
            code:[NSString stringWithFormat:@"%ld", (long)error.code]
          message:error.localizedDescription attempt:0];
    }
    P0FAdDone d = self.initDone;
    self.initDone = nil;
    if (d) d(success, success ? nil : [NSString stringWithFormat:@"%ld", (long)error.code],
             success ? nil : error.localizedDescription);
}

#pragma mark reward

- (void)loadReward:(P0FAdDone)done
{
    if (self.sdkState != P0FSDKStateReady) {
        if (done) done(NO, @"NOT_INIT", @"Lingye SDK not ready");
        return;
    }
    if (self.rewardState == P0FAdStateLoading) {
        if (done) done(NO, @"BUSY", @"reward load already in flight");
        return;
    }
    self.gen++;
    NSInteger gen = self.gen;
    self.rewardAttempt++;
    self.rewardState = P0FAdStateLoading;
    self.loadDone = done;
    [self ev:P0FKindReward action:@"LOAD" ok:YES network:nil thirdPlacement:nil requestId:nil code:nil message:@"START" attempt:self.rewardAttempt];
    [self armWatchdog:45 gen:gen fire:^{
        if (gen == self.gen && self.rewardState == P0FAdStateLoading) {
            self.rewardState = P0FAdStateTimeout;
            [self ev:P0FKindReward action:@"TIMEOUT" ok:NO network:nil thirdPlacement:nil requestId:nil code:@"TIMEOUT" message:@"load no callback in 45s" attempt:self.rewardAttempt];
            if (self.loadDone) { P0FAdDone d = self.loadDone; self.loadDone = nil; d(NO, @"TIMEOUT", @"load timeout"); }
        }
    }];
    CJRewardVideoAd *ad = [[CJRewardVideoAd alloc] initWithResourceId:self.config.lingyeRewardId userId:@"p0f" extend:@""];
    ad.delegate = self;
    self.rewardAd = ad;
    [ad loadAdData];
}

- (void)showReward:(P0FAdDone)done
{
    if (self.rewardState != P0FAdStateReady || !self.rewardAd) {
        if (done) done(NO, @"NOT_READY", @"reward not loaded");
        return;
    }
    self.rewardState = P0FAdStateShowing;
    self.showDone = done;
    [self ev:P0FKindReward action:@"SHOW" ok:NO network:nil thirdPlacement:nil requestId:nil code:nil message:@"BEGIN" attempt:self.rewardAttempt];
    [self.rewardAd showFromRootViewController:self.rootVC];
}

- (void)runRewardFlow:(P0FAdDone)done
{
    __weak typeof(self) w = self;
    [self loadReward:^(BOOL ok, NSString *code, NSString *msg) {
        if (!ok) { if (done) done(NO, code, msg); return; }
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [w showReward:done];
        });
    }];
}

#pragma mark CJRewardVideoAdDelegate

- (void)rewardVideoAdDidLoad:(CJRewardVideoAd *)rewardAd resourceId:(NSString *)resourceId
{
    if (self.rewardState != P0FAdStateLoading) return;
    self.rewardState = P0FAdStateReady;
    self.lastRewardNetwork = [rewardAd getAdType] ?: @"-";
    self.lastRewardRequestId = @"-";  // requestId 仅 rewardVideoOnRewarded 回调提供
    [self ev:P0FKindReward action:@"LOAD" ok:YES network:self.lastRewardNetwork
          thirdPlacement:resourceId requestId:self.lastRewardRequestId code:nil message:@"READY" attempt:self.rewardAttempt];
    P0FAdDone d = self.loadDone;
    self.loadDone = nil;
    if (d) d(YES, nil, nil);
}

- (void)rewardVideoAdLoadFailed:(CJRewardVideoAd *)rewardAd error:(NSError *)error
{
    if (self.rewardState != P0FAdStateLoading) return;
    self.rewardState = P0FAdStateError;
    NSString *code = [NSString stringWithFormat:@"%ld", (long)error.code];
    [self ev:P0FKindReward action:@"ERROR" ok:NO network:nil thirdPlacement:nil requestId:nil code:code message:error.localizedDescription attempt:self.rewardAttempt];
    P0FAdDone d = self.loadDone;
    self.loadDone = nil;
    if (d) d(NO, code, error.localizedDescription);
}

- (void)rewardVideoAdOnShow:(CJRewardVideoAd *)rewardAd
{
    if (self.rewardState != P0FAdStateShowing) return;
    [self ev:P0FKindReward action:@"SHOW" ok:YES network:[rewardAd getAdType]
          thirdPlacement:nil requestId:self.lastRewardRequestId code:nil message:nil attempt:self.rewardAttempt];
}

- (void)rewardVideoOnRewarded:(CJRewardVideoAd *)rewardAd requestId:(NSString *)requestId
{
    self.rewardState = P0FAdStateRewarded;
    if (requestId.length) self.lastRewardRequestId = requestId;
    [self ev:P0FKindReward action:@"REWARD" ok:YES network:[rewardAd getAdType]
          thirdPlacement:nil requestId:requestId code:nil message:nil attempt:self.rewardAttempt];
}

- (void)rewardVideoAdOnClosed:(CJRewardVideoAd *)rewardAd
{
    if (self.rewardState != P0FAdStateShowing && self.rewardState != P0FAdStateRewarded) return;
    self.rewardState = P0FAdStateClosed;
    [self ev:P0FKindReward action:@"CLOSE" ok:YES network:[rewardAd getAdType]
          thirdPlacement:nil requestId:self.lastRewardRequestId code:nil message:nil attempt:self.rewardAttempt];
    P0FAdDone d = self.showDone;
    self.showDone = nil;
    if (d) d(YES, nil, nil);
}

#pragma mark splash

- (void)loadSplash:(P0FAdDone)done
{
    if (self.config.lingyeSplashId.length == 0) {
        if (done) done(NO, @"NO_PLACEMENT", @"未配置领页开屏广告位ID（P0F_LINGYE_SPLASH_ID）");
        return;
    }
    if (self.sdkState != P0FSDKStateReady) {
        if (done) done(NO, @"NOT_INIT", @"Lingye SDK not ready");
        return;
    }
    if (self.splashState == P0FAdStateLoading) {
        if (done) done(NO, @"BUSY", @"splash load already in flight");
        return;
    }
    self.gen++;
    NSInteger gen = self.gen;
    self.splashState = P0FAdStateLoading;
    self.splashLoadDone = done;
    [self ev:P0FKindSplash action:@"LOAD" ok:YES network:nil thirdPlacement:nil requestId:nil code:nil message:@"START" attempt:0];
    [self armWatchdog:30 gen:gen fire:^{
        if (gen == self.gen && self.splashState == P0FAdStateLoading) {
            self.splashState = P0FAdStateTimeout;
            [self ev:P0FKindSplash action:@"TIMEOUT" ok:NO network:nil thirdPlacement:nil requestId:nil code:@"TIMEOUT" message:@"load no callback in 30s" attempt:0];
            if (self.splashLoadDone) { P0FAdDone d = self.splashLoadDone; self.splashLoadDone = nil; d(NO, @"TIMEOUT", @"splash load timeout"); }
        }
    }];
    UIView *logo = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 1, 1)];
    CJSplashAd *ad = [[CJSplashAd alloc] initWithResourceId:self.config.lingyeSplashId
                                         rootViewController:self.rootVC ?: [[UIViewController alloc] init]
                                             customLogoView:logo];
    ad.delegate = self;
    self.splashAd = ad;
    [ad loadAdData];
}

- (void)showSplash:(P0FAdDone)done
{
    if (self.splashState != P0FAdStateReady || !self.splashAd) {
        if (done) done(NO, @"NOT_READY", @"splash not loaded");
        return;
    }
    if (!self.window) {
        if (done) done(NO, @"NO_WINDOW", @"window unavailable");
        return;
    }
    self.splashState = P0FAdStateShowing;
    self.splashShowDone = done;
    [self ev:P0FKindSplash action:@"SHOW" ok:NO network:nil thirdPlacement:nil requestId:nil code:nil message:@"BEGIN" attempt:0];
    [self.splashAd showSplashAdToWindow:self.window];
}

#pragma mark CJSplashAdDelegate

- (void)splashAdDidLoad:(CJSplashAd *)splashAd resourceId:(NSString *)resourceId
{
    if (self.splashState != P0FAdStateLoading) return;
    self.splashState = P0FAdStateReady;
    [self ev:P0FKindSplash action:@"LOAD" ok:YES network:[splashAd getAdType]
          thirdPlacement:resourceId requestId:[splashAd getRequestId] code:nil message:@"READY" attempt:0];
    P0FAdDone d = self.splashLoadDone;
    self.splashLoadDone = nil;
    if (d) d(YES, nil, nil);
}

- (void)splashAdLoadFailed:(CJSplashAd *)splashAd error:(NSError *)error
{
    if (self.splashState != P0FAdStateLoading) return;
    self.splashState = P0FAdStateError;
    NSString *code = [NSString stringWithFormat:@"%ld", (long)error.code];
    [self ev:P0FKindSplash action:@"ERROR" ok:NO network:nil thirdPlacement:nil requestId:nil code:code message:error.localizedDescription attempt:0];
    P0FAdDone d = self.splashLoadDone;
    self.splashLoadDone = nil;
    if (d) d(NO, code, error.localizedDescription);
}

- (void)splashAdOnShow:(CJSplashAd *)splashAd
{
    if (self.splashState != P0FAdStateShowing) return;
    [self ev:P0FKindSplash action:@"SHOW" ok:YES network:[splashAd getAdType]
          thirdPlacement:nil requestId:[splashAd getRequestId] code:nil message:nil attempt:0];
}

- (void)splashAdOnClosed:(CJSplashAd *)splashAd
{
    if (self.splashState != P0FAdStateShowing) return;
    self.splashState = P0FAdStateClosed;
    [self ev:P0FKindSplash action:@"CLOSE" ok:YES network:[splashAd getAdType]
          thirdPlacement:nil requestId:[splashAd getRequestId] code:nil message:nil attempt:0];
    P0FAdDone d = self.splashShowDone;
    self.splashShowDone = nil;
    if (d) d(YES, nil, nil);
}

#pragma mark reset

- (void)resetState
{
    self.gen++;
    self.rewardAd = nil;
    self.splashAd = nil;
    self.rewardState = P0FAdStateIdle;
    self.splashState = P0FAdStateIdle;
    self.sdkState = P0FSDKStateNotInitialized;
    self.rewardAttempt = 0;
    self.lastRewardNetwork = nil;
    self.lastRewardRequestId = nil;
    self.initDone = nil; self.loadDone = nil; self.showDone = nil;
    self.splashLoadDone = nil; self.splashShowDone = nil;
    [self ev:P0FKindInit action:@"RESET" ok:YES network:nil thirdPlacement:nil requestId:nil code:nil message:@"state cleared" attempt:0];
}

@end

#pragma mark - Flame listener boxes（Reward 与 Splash 协议方法同名，必须分对象）

// box → controller 转发方法前置声明（实现见 FlameTestController 区段）
@interface FlameTestController ()
- (void)rewardOnAdLoaded;
- (void)rewardOnAdShow;
- (void)rewardOnAdClicked;
- (void)rewardOnPlayComplete;
- (void)rewardOnRewardTransId:(NSString *)transId;
- (void)rewardOnClosed;
- (void)rewardOnError:(NSString *)code desc:(NSString *)desc;
- (void)splashOnLoaded:(BOOL)ok code:(NSString *)code desc:(NSString *)desc;
- (void)splashOnShow;
- (void)splashOnShowError:(NSString *)code desc:(NSString *)desc;
- (void)splashOnClosed;
@end

@interface P0FFlameRewardBox : NSObject <FlameRewardListener>
@property (nonatomic, weak) FlameTestController *c;
@end
@implementation P0FFlameRewardBox
- (void)onAdLoaded { [self.c rewardOnAdLoaded]; }
- (void)onAdShow { [self.c rewardOnAdShow]; }
- (void)onAdClicked { [self.c rewardOnAdClicked]; }
- (void)onAdPlayComplete { [self.c rewardOnPlayComplete]; }
- (void)onAdReward:(NSString *)userId userCustomData:(NSString *)userCustomData transId:(NSString *)transId
{ [self.c rewardOnRewardTransId:transId]; }
- (void)onAdClosed { [self.c rewardOnClosed]; }
- (void)onAdError:(NSString *)code desc:(NSString *)desc { [self.c rewardOnError:code desc:desc]; }
@end

@interface P0FFlameSplashBox : NSObject <FlameSplashListener>
@property (nonatomic, weak) FlameTestController *c;
@end
@implementation P0FFlameSplashBox
- (void)onAdLoaded { [self.c splashOnLoaded:YES code:nil desc:nil]; }
- (void)onAdShow { [self.c splashOnShow]; }
- (void)onAdClicked { }
- (void)onAdReward:(NSString *)userId userCustomData:(NSString *)userCustomData { }
- (void)onAdClosed { [self.c splashOnClosed]; }
- (void)onAdShowComplete:(NSString *)userId userCustomData:(NSString *)userCustomData { }
- (void)onAdLoadTimeout { [self.c splashOnLoaded:NO code:@"TIMEOUT" desc:@"splash load timeout (onAdLoadTimeout)"]; }
- (void)onAdError:(NSString *)code desc:(NSString *)desc
{
    if ([self.c splashState] == P0FAdStateLoading) [self.c splashOnLoaded:NO code:code desc:desc];
    else [self.c splashOnShowError:code desc:desc];
}
@end

#pragma mark - FlameTestController

@interface FlameTestController () <FlameCallback>
@property (nonatomic, strong) P0FAdConfig *config;
@property (nonatomic, assign) P0FSDKState sdkState;
@property (nonatomic, assign) P0FAdState rewardState;
@property (nonatomic, assign) P0FAdState splashState;
@property (nonatomic, assign) NSInteger rewardAttempt;
@property (nonatomic, copy) NSString *lastRewardNetwork;
@property (nonatomic, copy) NSString *lastTobidPlacement;
@property (nonatomic, copy) NSString *lastNetworkPlacement;
@property (nonatomic, copy) NSString *lastTransId;
@property (nonatomic, weak) UIViewController *rootVC;
@property (nonatomic, weak) UIWindow *window;
@property (nonatomic, strong) id<FlameRewardAd> rewardAd;
@property (nonatomic, strong) id<FlameSplashAd> splashAd;
@property (nonatomic, strong) P0FFlameRewardBox *rewardBox;
@property (nonatomic, strong) P0FFlameSplashBox *splashBox;
@property (nonatomic, copy) P0FAdDone initDone;
@property (nonatomic, copy) P0FAdDone loadDone;
@property (nonatomic, copy) P0FAdDone showDone;
@property (nonatomic, copy) P0FAdDone splashLoadDone;
@property (nonatomic, copy) P0FAdDone splashShowDone;
@property (nonatomic, assign) NSInteger gen;
@end

@implementation FlameTestController

+ (instancetype)shared
{
    static FlameTestController *s;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ s = [[FlameTestController alloc] init]; });
    return s;
}

- (instancetype)init
{
    self = [super init];
    _config = [P0FAdConfig current];
    _sdkState = P0FSDKStateNotInitialized;
    _rewardState = P0FAdStateIdle;
    _splashState = P0FAdStateIdle;
    _mediation = @"TOBID";
    _rewardBox = [[P0FFlameRewardBox alloc] init];
    _splashBox = [[P0FFlameSplashBox alloc] init];
    _rewardBox.c = self;
    _splashBox.c = self;
    return self;
}

- (void)setRootViewController:(UIViewController *)rootVC window:(UIWindow *)window
{
    _rootVC = rootVC;
    _window = window;
}

- (P0FAdEvent *)ev:(NSString *)kind action:(NSString *)action ok:(BOOL)ok
           network:(NSString *)network flamePlacement:(NSString *)fp thirdPlacement:(NSString *)tp
            transId:(NSString *)tid code:(NSString *)code message:(NSString *)msg attempt:(NSInteger)attempt
{
    return [self emitOwner:P0FOwnerFlame kind:kind action:action ok:ok network:network
            flamePlacement:fp thirdPlacement:tp transId:tid requestId:nil
                      code:code message:msg attempt:attempt];
}

/// 从 LogTap 拉取最近的 ToBid runtime 报告（120s 内视为本轮有效）
- (NSDictionary *)freshReport:(BOOL)show
{
    NSDictionary *r = show ? [P0FLogTap shared].lastAdShowReport : [P0FLogTap shared].lastAdReadyReport;
    NSNumber *ts = r[@"_ts"];
    if (r && ts && ([[NSDate date] timeIntervalSince1970] - ts.doubleValue) < 120) return r;
    return nil;
}

- (void)absorbReport:(NSDictionary *)rep
{
    if (!rep) return;
    NSString *name = rep[@"networkName"];
    if (!name.length) {
        NSNumber *nid = rep[@"networkId"];
        if (nid) name = [P0FLogTap networkNameForId:nid.integerValue];
    }
    if (name.length) self.lastRewardNetwork = name;
    NSString *pid = rep[@"placementId"];
    if ([pid isKindOfClass:[NSString class]] && pid.length) self.lastTobidPlacement = pid;
    NSString *npid = rep[@"networkPlacementId"];
    if ([npid isKindOfClass:[NSString class]] && npid.length) self.lastNetworkPlacement = npid;
}

#pragma mark init

- (void)initSDK:(P0FAdDone)done
{
    if (self.config.flameAppId.length == 0 || self.config.flameAppKey.length == 0) {
        if (done) done(NO, @"14005", @"未配置 Flame AppID/AppKey（P0FSecretConfig.h 或 env）");
        return;
    }
    if (self.sdkState == P0FSDKStateInitializing) {
        if (done) done(NO, @"BUSY", @"init already in flight");
        return;
    }
    self.sdkState = P0FSDKStateInitializing;
    self.gen++;
    NSInteger gen = self.gen;
    self.initDone = done;
    [self ev:P0FKindInit action:@"INIT" ok:YES network:nil flamePlacement:nil thirdPlacement:nil transId:nil code:nil message:@"START" attempt:0];
    [self armWatchdog:30 gen:gen fire:^{
        if (gen == self.gen && self.sdkState == P0FSDKStateInitializing) {
            self.sdkState = P0FSDKStateError;
            [self ev:P0FKindInit action:@"TIMEOUT" ok:NO network:nil flamePlacement:nil thirdPlacement:nil transId:nil code:@"TIMEOUT" message:@"init no callback in 30s" attempt:0];
            if (self.initDone) { P0FAdDone d = self.initDone; self.initDone = nil; d(NO, @"TIMEOUT", @"init timeout"); }
        }
    }];
    [FlameSdk setDebug:YES];
    [FlameSdk initWithAppId:self.config.flameAppId appKey:self.config.flameAppKey callback:self];
}

- (void)success   // FlameCallback（TB 线主线程无保证，这里收口）
{
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.sdkState != P0FSDKStateInitializing) return;
        self.sdkState = P0FSDKStateReady;
        [self ev:P0FKindInit action:@"INIT" ok:YES network:nil flamePlacement:nil thirdPlacement:nil transId:nil code:nil message:@"PASS pt=tb" attempt:0];
        P0FAdDone d = self.initDone;
        self.initDone = nil;
        if (d) d(YES, nil, nil);
    });
}

- (void)fail:(NSString *)code desc:(NSString *)desc   // FlameCallback
{
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.sdkState != P0FSDKStateInitializing) return;
        self.sdkState = P0FSDKStateError;
        [self ev:P0FKindInit action:@"ERROR" ok:NO network:nil flamePlacement:nil thirdPlacement:nil transId:nil code:code message:desc attempt:0];
        P0FAdDone d = self.initDone;
        self.initDone = nil;
        if (d) d(NO, code, desc);
    });
}

- (void)clearSDK
{
    self.gen++;
    [FlameSdk clear];
    [self resetState];
}

#pragma mark reward

- (void)loadReward:(P0FAdDone)done
{
    if (self.sdkState != P0FSDKStateReady) {
        if (done) done(NO, @"14000", @"SDK not initialized");
        return;
    }
    if (self.rewardState == P0FAdStateLoading) {
        if (done) done(NO, @"BUSY", @"reward load already in flight");
        return;
    }
    self.gen++;
    NSInteger gen = self.gen;
    self.rewardAttempt++;
    self.rewardState = P0FAdStateLoading;
    self.loadDone = done;
    [self ev:P0FKindReward action:@"LOAD" ok:YES network:nil flamePlacement:self.config.flameRewardPlacement
              thirdPlacement:nil transId:nil code:nil message:@"START" attempt:self.rewardAttempt];
    [self armWatchdog:45 gen:gen fire:^{
        if (gen == self.gen && self.rewardState == P0FAdStateLoading) {
            self.rewardState = P0FAdStateTimeout;
            [self ev:P0FKindReward action:@"TIMEOUT" ok:NO network:nil flamePlacement:self.config.flameRewardPlacement thirdPlacement:nil transId:nil code:@"TIMEOUT" message:@"load no callback in 45s" attempt:self.rewardAttempt];
            if (self.loadDone) { P0FAdDone d = self.loadDone; self.loadDone = nil; d(NO, @"TIMEOUT", @"load timeout"); }
        }
    }];
    [self.rewardAd destroy];
    self.rewardAd = nil;
    __weak typeof(self) w = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        w.rewardAd = [FlameSdk createRewardAdWithViewController:w.rootVC ?: [[UIViewController alloc] init]
                                                    placementId:w.config.flameRewardPlacement
                                                       listener:w.rewardBox];
        [w.rewardAd load];
    });
}

- (void)showReward:(P0FAdDone)done
{
    if (self.rewardState != P0FAdStateReady || !self.rewardAd) {
        if (done) done(NO, @"14004", @"reward not loaded / not ready");
        return;
    }
    if (![self.rewardAd isReady]) {
        if (done) done(NO, @"14004", @"isReady=NO");
        return;
    }
    self.rewardState = P0FAdStateShowing;
    self.showDone = done;
    [self ev:P0FKindReward action:@"SHOW" ok:NO network:nil flamePlacement:self.config.flameRewardPlacement
              thirdPlacement:nil transId:nil code:nil message:@"BEGIN" attempt:self.rewardAttempt];
    [self.rewardAd show];
}

- (void)runRewardFlow:(P0FAdDone)done
{
    __weak typeof(self) w = self;
    [self loadReward:^(BOOL ok, NSString *code, NSString *msg) {
        if (!ok) { if (done) done(NO, code, msg); return; }
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [w showReward:done];
        });
    }];
}

#pragma mark reward callbacks（由 P0FFlameRewardBox 转发）

- (void)rewardOnAdLoaded
{
    if (self.rewardState != P0FAdStateLoading) return;
    self.rewardState = P0FAdStateReady;
    [self absorbReport:[self freshReport:NO]];
    [self ev:P0FKindReward action:@"LOAD" ok:YES network:self.lastRewardNetwork ?: @"N/A"
          flamePlacement:self.config.flameRewardPlacement thirdPlacement:self.lastTobidPlacement ?: @"N/A"
                 transId:nil code:nil message:@"READY" attempt:self.rewardAttempt];
    P0FAdDone d = self.loadDone;
    self.loadDone = nil;
    if (d) d(YES, nil, nil);
}

- (void)rewardOnAdShow
{
    [self absorbReport:[self freshReport:YES]];
    // 成功展示后重置 no-fill 重试计数（下一个新请求从 #1 开始）
    self.rewardAttempt = 0;
    [self ev:P0FKindReward action:@"SHOW" ok:YES network:self.lastRewardNetwork ?: @"N/A"
          flamePlacement:self.config.flameRewardPlacement thirdPlacement:self.lastTobidPlacement ?: @"N/A"
                 transId:nil code:nil message:nil attempt:self.rewardAttempt];
}

- (void)rewardOnAdClicked
{
    [self ev:P0FKindReward action:@"CLICK" ok:YES network:nil flamePlacement:nil thirdPlacement:nil transId:nil code:nil message:nil attempt:0];
}

- (void)rewardOnPlayComplete
{
    [self ev:P0FKindReward action:@"PLAY_COMPLETE" ok:YES network:nil flamePlacement:nil thirdPlacement:nil transId:nil code:nil message:nil attempt:0];
}

- (void)rewardOnRewardTransId:(NSString *)transId
{
    self.rewardState = P0FAdStateRewarded;
    self.lastTransId = transId;
    [self ev:P0FKindReward action:@"REWARD" ok:YES network:nil flamePlacement:self.config.flameRewardPlacement
              thirdPlacement:nil transId:transId ?: @"N/A" code:nil message:nil attempt:self.rewardAttempt];
}

- (void)rewardOnClosed
{
    if (self.rewardState != P0FAdStateShowing && self.rewardState != P0FAdStateRewarded) return;
    self.rewardState = P0FAdStateClosed;
    [self ev:P0FKindReward action:@"CLOSE" ok:YES network:nil flamePlacement:nil thirdPlacement:nil transId:nil code:nil message:nil attempt:self.rewardAttempt];
    P0FAdDone d = self.showDone;
    self.showDone = nil;
    if (d) d(YES, nil, nil);
}

- (void)rewardOnError:(NSString *)code desc:(NSString *)desc
{
    P0FAdState prev = self.rewardState;
    if (prev == P0FAdStateLoading) {
        self.rewardState = P0FAdStateError;
        [self ev:P0FKindReward action:@"ERROR" ok:NO network:nil flamePlacement:self.config.flameRewardPlacement
                  thirdPlacement:nil transId:nil code:code message:desc attempt:self.rewardAttempt];
        P0FAdDone d = self.loadDone;
        self.loadDone = nil;
        if (d) d(NO, code, desc);
    } else if (prev == P0FAdStateShowing) {
        self.rewardState = P0FAdStateError;
        [self ev:P0FKindReward action:@"ERROR" ok:NO network:nil flamePlacement:nil thirdPlacement:nil transId:nil code:code message:desc attempt:self.rewardAttempt];
        P0FAdDone d = self.showDone;
        self.showDone = nil;
        if (d) d(NO, code, desc);
    }
}

#pragma mark splash

- (void)loadSplash:(P0FAdDone)done
{
    if (self.config.flameSplashPlacement.length == 0) {
        if (done) done(NO, @"NO_PLACEMENT", @"未配置 Flame 开屏广告位ID（P0F_FLAME_SPLASH_PLACEMENT）");
        return;
    }
    if (self.sdkState != P0FSDKStateReady) {
        if (done) done(NO, @"14000", @"SDK not initialized");
        return;
    }
    if (self.splashState == P0FAdStateLoading) {
        if (done) done(NO, @"BUSY", @"splash load already in flight");
        return;
    }
    self.gen++;
    NSInteger gen = self.gen;
    self.splashState = P0FAdStateLoading;
    self.splashLoadDone = done;
    [self ev:P0FKindSplash action:@"LOAD" ok:YES network:nil flamePlacement:self.config.flameSplashPlacement
              thirdPlacement:nil transId:nil code:nil message:@"START" attempt:0];
    [self armWatchdog:20 gen:gen fire:^{
        if (gen == self.gen && self.splashState == P0FAdStateLoading) {
            self.splashState = P0FAdStateTimeout;
            [self ev:P0FKindSplash action:@"TIMEOUT" ok:NO network:nil flamePlacement:self.config.flameSplashPlacement thirdPlacement:nil transId:nil code:@"TIMEOUT" message:@"load no callback in 20s" attempt:0];
            if (self.splashLoadDone) { P0FAdDone d = self.splashLoadDone; self.splashLoadDone = nil; d(NO, @"TIMEOUT", @"splash load timeout"); }
        }
    }];
    [self.splashAd destroy];
    self.splashAd = nil;
    __weak typeof(self) w = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        w.splashAd = [FlameSdk createSplashAdWithViewController:w.rootVC ?: [[UIViewController alloc] init]
                                                    placementId:w.config.flameSplashPlacement
                                                       listener:w.splashBox];
        [w.splashAd load];
    });
}

- (void)showSplash:(P0FAdDone)done
{
    if (self.splashState != P0FAdStateReady || !self.splashAd) {
        if (done) done(NO, @"14004", @"splash not loaded / not ready");
        return;
    }
    if (!self.window) {
        if (done) done(NO, @"NO_WINDOW", @"window unavailable");
        return;
    }
    self.splashState = P0FAdStateShowing;
    self.splashShowDone = done;
    [self ev:P0FKindSplash action:@"SHOW" ok:NO network:nil flamePlacement:self.config.flameSplashPlacement
              thirdPlacement:nil transId:nil code:nil message:@"BEGIN" attempt:0];
    [self.splashAd show:self.window];
}

#pragma mark splash callbacks（由 P0FFlameSplashBox 转发）

- (void)splashOnLoaded:(BOOL)ok code:(NSString *)code desc:(NSString *)desc
{
    if (self.splashState != P0FAdStateLoading) return;
    if (ok) {
        self.splashState = P0FAdStateReady;
        [self ev:P0FKindSplash action:@"LOAD" ok:YES network:nil flamePlacement:self.config.flameSplashPlacement
                  thirdPlacement:nil transId:nil code:nil message:@"READY" attempt:0];
        P0FAdDone d = self.splashLoadDone;
        self.splashLoadDone = nil;
        if (d) d(YES, nil, nil);
    } else {
        self.splashState = P0FAdStateError;
        [self ev:P0FKindSplash action:@"ERROR" ok:NO network:nil flamePlacement:self.config.flameSplashPlacement
                  thirdPlacement:nil transId:nil code:code message:desc attempt:0];
        P0FAdDone d = self.splashLoadDone;
        self.splashLoadDone = nil;
        if (d) d(NO, code, desc);
    }
}

- (void)splashOnShow
{
    if (self.splashState != P0FAdStateShowing) return;
    [self ev:P0FKindSplash action:@"SHOW" ok:YES network:nil flamePlacement:self.config.flameSplashPlacement
              thirdPlacement:nil transId:nil code:nil message:nil attempt:0];
}

- (void)splashOnShowError:(NSString *)code desc:(NSString *)desc
{
    if (self.splashState != P0FAdStateShowing) return;
    self.splashState = P0FAdStateError;
    [self ev:P0FKindSplash action:@"ERROR" ok:NO network:nil flamePlacement:self.config.flameSplashPlacement
              thirdPlacement:nil transId:nil code:code message:desc attempt:0];
    P0FAdDone d = self.splashShowDone;
    self.splashShowDone = nil;
    if (d) d(NO, code, desc);
}

- (void)splashOnClosed
{
    if (self.splashState != P0FAdStateShowing) return;
    self.splashState = P0FAdStateClosed;
    [self ev:P0FKindSplash action:@"CLOSE" ok:YES network:nil flamePlacement:nil thirdPlacement:nil transId:nil code:nil message:nil attempt:0];
    P0FAdDone d = self.splashShowDone;
    self.splashShowDone = nil;
    if (d) d(YES, nil, nil);
}

#pragma mark reset

- (void)resetState
{
    self.gen++;
    [self.rewardAd destroy];
    self.rewardAd = nil;
    [self.splashAd destroy];
    self.splashAd = nil;
    self.rewardState = P0FAdStateIdle;
    self.splashState = P0FAdStateIdle;
    self.sdkState = P0FSDKStateNotInitialized;
    self.rewardAttempt = 0;
    self.lastRewardNetwork = nil;
    self.lastTobidPlacement = nil;
    self.lastNetworkPlacement = nil;
    self.lastTransId = nil;
    self.initDone = nil; self.loadDone = nil; self.showDone = nil;
    self.splashLoadDone = nil; self.splashShowDone = nil;
    [self ev:P0FKindInit action:@"RESET" ok:YES network:nil flamePlacement:nil thirdPlacement:nil transId:nil code:nil message:@"state cleared" attempt:0];
}

@end
