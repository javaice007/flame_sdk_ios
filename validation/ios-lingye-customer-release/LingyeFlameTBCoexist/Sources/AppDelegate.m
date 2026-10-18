//
//  AppDelegate.m — P0F Coexist Test Console 宿主（TEST_ONLY）
//
//  §18：默认 MANUAL_MODE（Coexist Test Console 人工验收工作台）。
//  仅当显式 TEST_ONLY 入口存在时才进入自动模式：
//    env P0D_SEQ=CASE_A|CASE_B|C0|C1|C2|C3|C4|REINIT_LI|REINIT_FI|REINIT_MIX1|REINIT_MIX2
//    或 launch arg：--auto-sequence CASE_A
//  §19：人工与自动共用 LingyeTestController / FlameTestController（P0FTestCore），
//       禁止两套 SDK wrapper。
//  探针（只读透明，调用后必回原实现）：
//    ATAPI startWithAppID:appKey:(sdkConfigures:)error:
//    WindMillAds setupSDKWithAppId:(sdkConfigures:)completionHandler:
//  Flame 凭证：env(P0D_FAPPID/P0D_FAPPKEY/P0D_FPLACE) → P0FSecretConfig.h（gitignored）。
//  标记前缀：自动模式 [P0D-C]（历史矩阵 Gate 兼容）；统一事件日志 [P0F]。
//
#import "AppDelegate.h"
#import "P0DLingyeTestIDs.h"
#import "P0DNetProbe.h"
#import "P0FTestCore.h"
#import "P0FConsoleViewController.h"
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <AppTrackingTransparency/AppTrackingTransparency.h>
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
    return [self p0d_atapi1:appID appKey:appKey error:error]; // exchange 后此调用即原实现
}

+ (BOOL)p0d_atapi2:(NSString *)appID appKey:(NSString *)appKey sdkConfigures:(NSArray *)cfg error:(NSError **)error
{
    gTakuInitCalls++;
    NSLog(@"[P0D-C] PROBE TAKU_INIT_CALLED(cfg) appID=%@", appID);
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

#pragma mark - 自动模式状态屏（§18：runner 保留；与手动共用 Controller）

@interface P0FAutoRunnerVC : UIViewController <P0FTestListener, UITextViewDelegate>
@property (nonatomic, copy) NSString *seq;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UITextView *logView;
- (instancetype)initWithSeq:(NSString *)seq;
@end

@implementation P0FAutoRunnerVC

- (instancetype)initWithSeq:(NSString *)seq
{
    self = [super init];
    _seq = seq;
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];
    _statusLabel = [[UILabel alloc] init];
    _statusLabel.font = [UIFont boldSystemFontOfSize:16];
    _statusLabel.text = [NSString stringWithFormat:@"AUTO MODE（TEST_ONLY） seq=%@", _seq];
    _statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _logView = [[UITextView alloc] init];
    _logView.font = [UIFont monospacedSystemFontOfSize:11 weight:UIFontWeightRegular];
    _logView.backgroundColor = [UIColor blackColor];
    _logView.textColor = [UIColor whiteColor];
    _logView.editable = NO;
    _logView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:_statusLabel];
    [self.view addSubview:_logView];
    [NSLayoutConstraint activateConstraints:@[
        [_statusLabel.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:12],
        [_statusLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16],
        [_logView.topAnchor constraintEqualToAnchor:_statusLabel.bottomAnchor constant:8],
        [_logView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:12],
        [_logView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-12],
        [_logView.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-12],
    ]];
}

- (void)appendLine:(NSString *)s
{
    dispatch_async(dispatch_get_main_queue(), ^{
        self.logView.text = [self.logView.text stringByAppendingFormat:@"%@\n", s];
        [self.logView scrollRangeToVisible:NSMakeRange(self.logView.text.length, 0)];
    });
}

// 历史矩阵 Gate 标记：事件 → [P0D-C] 行（与 P0E 时代格式一致）
- (void)p0fEvent:(P0FAdEvent *)e
{
    BOOL flame = [e.owner isEqualToString:P0FOwnerFlame];
    NSString *rewardTag = flame ? @"FA" : @"LA";
    if ([e.kind isEqualToString:P0FKindReward]) {
        if ([e.action isEqualToString:@"LOAD"]) {
            if ([e.message isEqualToString:@"READY"])
                NSLog(@"[P0D-C] %@_LOAD_OK channel=%@", rewardTag, e.network ?: @"-");
            else if (e.ok && [e.message isEqualToString:@"START"]) { }
            else if (!e.ok && ![e.message isEqualToString:@"START"])
                NSLog(@"[P0D-C] %@_LOAD_FAIL code=%@ desc=%@", rewardTag, e.code ?: @"-", e.message ?: @"-");
        } else if ([e.action isEqualToString:@"SHOW"]) {
            if ([e.message isEqualToString:@"BEGIN"]) NSLog(@"[P0D-C] %@_SHOW_BEGIN", rewardTag);
            else if (e.ok) NSLog(@"[P0D-C] %@_SHOW_OK", rewardTag);
        } else if ([e.action isEqualToString:@"REWARD"]) {
            NSLog(@"[P0D-C] %@_REWARDED transId=%@ requestId=%@", rewardTag, e.transId ?: @"-", e.requestId ?: @"-");
        } else if ([e.action isEqualToString:@"CLOSE"]) {
            NSLog(@"[P0D-C] %@_CLOSED", rewardTag);
        } else if ([e.action isEqualToString:@"ERROR"] || [e.action isEqualToString:@"TIMEOUT"]) {
            NSLog(@"[P0D-C] %@_ERROR code=%@ desc=%@", rewardTag, e.code ?: @"-", e.message ?: @"-");
        }
    }
}

@end

#pragma mark - AppDelegate

@interface AppDelegate () <UIApplicationDelegate>
@property (nonatomic, strong) NSArray<NSString *> *steps;
@property (nonatomic, assign) NSUInteger idx;
@property (nonatomic, assign) BOOL seqFail;
@property (nonatomic, assign) BOOL seqStarted;
@property (nonatomic, strong) P0FAutoRunnerVC *autoVC;
@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    [P0DProbe installProbes];
    [P0DNetProbe install];   // +load 时 AnyThinkSDK 动态框架可能未加载，此处挂探针
    [[P0FLogTap shared] start];

    NSString *seq = Env(@"P0D_SEQ");
    if (!seq) {
        // TEST_ONLY launch arg 入口：--auto-sequence CASE_A / --auto-sequence=CASE_A
        NSArray *args = NSProcessInfo.processInfo.arguments;
        for (NSUInteger i = 0; i < args.count; i++) {
            NSString *a = args[i];
            if ([a isEqualToString:@"--auto-sequence"] && i + 1 < args.count) { seq = args[i + 1]; break; }
            if ([a hasPrefix:@"--auto-sequence="]) { seq = [a substringFromIndex:@"--auto-sequence=".length]; break; }
        }
    }

    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    if (seq) {
        NSDictionary *map = @{
            @"CASE_A":      @[@"LI",@"LA",@"FI",@"FA",@"LA",@"FA"],
            @"CASE_B":      @[@"FI",@"FA",@"LI",@"LA",@"FA",@"LA"],
            // §16 历史语义：旧字典字面量 C1/C2 重复键后值生效（C1=[CJLOG,FI]、C2=[LI,FI]），此处保持等效
            @"C1":          @[@"CJLOG",@"FI"],
            @"C2":          @[@"LI",@"FI"],
            @"C3":          @[@"LI",@"FI",@"LA",@"FA",@"LA",@"FA"],
            @"C4":          @[@"FI",@"LI",@"FA",@"LA",@"FA",@"LA"],
            @"REINIT_LI":   @[@"LI",@"LI",@"LA"],
            @"REINIT_FI":   @[@"FI",@"FI",@"FA"],
            @"REINIT_MIX1": @[@"LI",@"FI",@"LI",@"LA"],
            @"REINIT_MIX2": @[@"FI",@"LI",@"FI",@"FA"],
            @"C0":          @[@"FI"],            // §16：仅链接，不调 CJ 任何 API
            @"C1_FULL":     @[@"LI",@"LA",@"FI",@"FA"],  // P0D §早期组合（保留入口）
            @"C2_FULL":     @[@"FI",@"FA",@"LI",@"LA"],
        };
        self.steps = map[seq] ?: @[@"LI"];
        self.autoVC = [[P0FAutoRunnerVC alloc] initWithSeq:seq];
        LingyeTestController.shared.listener = self.autoVC;
        FlameTestController.shared.listener = self.autoVC;
        self.window.rootViewController = self.autoVC;
        NSLog(@"[P0D-C] LAUNCH seq=%@ steps=%@ taku=? tobid=?", seq, [self.steps componentsJoinedByString:@","]);
    } else {
        P0FConsoleViewController *console = [[P0FConsoleViewController alloc] init];
        self.window.rootViewController = console;
        NSLog(@"[P0F] MANUAL_MODE Coexist Test Console（默认人工模式；自动回归需 --auto-sequence <SEQ> 或 env P0D_SEQ）");
    }
    [self.window makeKeyAndVisible];
    [LingyeTestController.shared setRootViewController:self.window.rootViewController window:self.window];
    [FlameTestController.shared setRootViewController:self.window.rootViewController window:self.window];

    // ATT（Sigmob 对 IDFA 敏感）；自动模式等授权回调或 8s 超时后启动序列
    if (@available(iOS 14.0, *)) {
        [ATTrackingManager requestTrackingAuthorizationWithCompletionHandler:^(ATTrackingManagerAuthorizationStatus st) {
            NSLog(@"[P0F] ATT_RESULT=%ld", (long)st);
            if (seq) dispatch_async(dispatch_get_main_queue(), ^{ [self p0dStartOnce]; });
        }];
        if (seq) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(8 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                if (!self.seqStarted) { NSLog(@"[P0F] ATT_TIMEOUT proceed"); [self p0dStartOnce]; }
            });
        }
    } else if (seq) {
        [self p0dStartOnce];
    }
    return YES;
}

- (void)p0dStartOnce
{
    if (self.seqStarted) return;
    self.seqStarted = YES;
    [self p0dNext];
}

#pragma mark - 自动序列器（§18 保留；§19 与手动共用 Controller）

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
    if ([s isEqualToString:@"LI"]) {
        NSLog(@"[P0D-C] LI_BEGIN");
        [[LingyeTestController shared] initSDK:^(BOOL ok, NSString *code, NSString *msg) {
            NSLog(@"[P0D-C] LI_RESULT=%d err=%@", ok ? 1 : 0, ok ? @"-" : [NSString stringWithFormat:@"%@/%@", code ?: @"-", msg ?: @"-"]);
            done(ok);
        }];
    }
    else if ([s isEqualToString:@"CJLOG"]) { [CJADManager openDebugLog]; done(YES); }
    else if ([s isEqualToString:@"FI"]) {
        NSLog(@"[P0D-C] FI_BEGIN");
        [[FlameTestController shared] initSDK:^(BOOL ok, NSString *code, NSString *msg) {
            NSLog(@"[P0D-C] FI_RESULT=%d code=%@ desc=%@", ok ? 1 : 0, code ?: @"-", msg ?: @"-");
            done(ok);
        }];
    }
    else if ([s isEqualToString:@"LA"]) {
        NSLog(@"[P0D-C] LA_BEGIN");
        [[LingyeTestController shared] runRewardFlow:^(BOOL ok, NSString *code, NSString *msg) { done(ok); }];
    }
    else if ([s isEqualToString:@"FA"]) {
        NSLog(@"[P0D-C] FA_BEGIN");
        [[FlameTestController shared] runRewardFlow:^(BOOL ok, NSString *code, NSString *msg) { done(ok); }];
    }
    else done(YES);
}

@end
