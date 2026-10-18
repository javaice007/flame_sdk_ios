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
    // ── Taku Probe v2（§19-20）：AnyThink 6.5.60 无 startWithAppID:*。
    //    采用「保存原 IMP + C 函数 setImplementation」：不经 selector 查找/转发
    //    （method exchange + 尾调自身选择器在异类接收者上会 doesNotRecognizeSelector→SIGABRT，
    //     已由 10:37 崩溃 103938.ips 实证）。只记录（时间/线程/动作标签/调用栈）后回原实现。
    if (atapi) {
        [P0DProbe installTakuProbe:atapi selName:@"handleAppLaunch" tag:@"handleAppLaunch"
                          hook:(IMP)P0DHLaunchHook origStore:&gOrigHLaunch];
        [P0DProbe installTakuProbe:atapi selName:@"tryCheckADXConfigIfNeeded" tag:@"tryCheckADXConfigIfNeeded"
                          hook:(IMP)P0DTryADXHook origStore:&gOrigTryADX];
    }
    Class atmgr = NSClassFromString(@"ATAdManager");
    if (atmgr) {
        [P0DProbe installTakuProbe:atmgr selName:@"sharedManager" tag:@"ATAdManager sharedManager"
                          hook:(IMP)P0DSharedMgrHook origStore:&gOrigSharedMgr];
    }
}

// ── Taku v2 C hooks（self/_cmd 之外的超寄存器实参原样留在寄存器，不影响形式签名）──
static IMP gOrigHLaunch;
static IMP gOrigTryADX;
static IMP gOrigSharedMgr;

static void P0DTakuLog(NSString *sel)
{
    NSLog(@"[P0D-C] PROBE TAKU_CALL sel=%@ thread=%@ action=%@",
          sel, [NSThread currentThread], P0FCurrentAction);
    P0DLogStack(@"TAKU_V2");
}

static void P0DHLaunchHook(id self, SEL _cmd)
{
    P0DTakuLog(@"handleAppLaunch");
    ((void (*)(id, SEL))gOrigHLaunch)(self, _cmd);
}

static void P0DTryADXHook(id self, SEL _cmd)
{
    P0DTakuLog(@"tryCheckADXConfigIfNeeded");
    ((void (*)(id, SEL))gOrigTryADX)(self, _cmd);
}

static id P0DSharedMgrHook(id self, SEL _cmd)
{
    P0DTakuLog(@"ATAdManager sharedManager");
    return ((id (*)(id, SEL))gOrigSharedMgr)(self, _cmd);
}

+ (void)installTakuProbe:(Class)cls selName:(NSString *)selName tag:(NSString *)tag
                    hook:(IMP)hook origStore:(IMP *)origStore
{
    Method m = class_getClassMethod(cls, NSSelectorFromString(selName));
    if (!m) { NSLog(@"[P0D-C] PROBE_V2 SKIP %@ (method absent)", tag); return; }
    *origStore = method_getImplementation(m);
    method_setImplementation(m, hook);
    NSLog(@"[P0D-C] PROBE_INSTALLED V2 %@ argc=%ld (imp-hook)", tag, (long)(method_getNumberOfArguments(m) - 2));
}

// ── 迟装 WindMill 探针（§16 ToBid ownership）：didFinishLaunching 时 WindMillAds 尚不在运行时
//    （所有历史轮次 PROBE_INSTALLED WindMillAds 均缺失，ToBid 管理器懒加载）。FI 完成后重试。──
static IMP gOrigWMSetup1;
static IMP gOrigWMSetup2;

static void P0DWMSetup1Hook(id self, SEL _cmd, id appId, id handler)
{
    gTobidInitCalls++;
    NSLog(@"[P0D-C] PROBE TOBID_SETUP %@ appId=%@ action=%@", NSStringFromSelector(_cmd), appId, P0FCurrentAction);
    ((void (*)(id, SEL, id, id))gOrigWMSetup1)(self, _cmd, appId, handler);
}

static void P0DWMSetup2Hook(id self, SEL _cmd, id appId, id cfg, id handler)
{
    gTobidInitCalls++;
    NSLog(@"[P0D-C] PROBE TOBID_SETUP %@ appId=%@ action=%@", NSStringFromSelector(_cmd), appId, P0FCurrentAction);
    ((void (*)(id, SEL, id, id, id))gOrigWMSetup2)(self, _cmd, appId, cfg, handler);
}

+ (void)lateInstallWindMillProbe
{
    Class wm = NSClassFromString(@"WindMillAds");
    NSLog(@"[P0D-C] PROBE_LATE WindMillAds=%@ (action=%@)", wm, P0FCurrentAction);
    if (!wm) {
        unsigned int n = 0;
        Class *list = objc_copyClassList(&n);
        NSMutableString *hits = [NSMutableString string];
        for (unsigned int i = 0; i < n; i++) {
            const char *name = class_getName(list[i]);
            if (strstr(name, "WindMill") || strstr(name, "WindAD") || strstr(name, "ToBid")) {
                [hits appendFormat:@"%@ ", @(name)];
            }
        }
        free(list);
        NSLog(@"[P0D-C] PROBE_LATE WindClasses=%@", hits);
        return;
    }
    Method m1 = class_getClassMethod(wm, NSSelectorFromString(@"setupSDKWithAppId:completionHandler:"));
    Method m2 = class_getClassMethod(wm, NSSelectorFromString(@"setupSDKWithAppId:sdkConfigures:completionHandler:"));
    if (m1) { gOrigWMSetup1 = method_getImplementation(m1); method_setImplementation(m1, (IMP)P0DWMSetup1Hook); }
    if (m2) { gOrigWMSetup2 = method_getImplementation(m2); method_setImplementation(m2, (IMP)P0DWMSetup2Hook); }
    NSLog(@"[P0D-C] PROBE_LATE INSTALLED WindMill setup hooks (%d,%d)", m1 != NULL, m2 != NULL);
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
    NSLog(@"[P0D-C] PROBE TOBID_INIT_CALLED(cfg) appId=%@ action=%@", appId, P0FCurrentAction);
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

#pragma mark - 开屏位探测盒（TEST_ONLY：只观察 load 结果，不 show）

@interface P0FSplashProbeBox : NSObject <FlameSplashListener>
@property (nonatomic, copy) void (^onResult)(BOOL ok, NSString *code, NSString *desc);
@property (nonatomic, assign) BOOL finished;
- (void)finishWith:(BOOL)ok code:(NSString *)code desc:(NSString *)desc;
@end
@implementation P0FSplashProbeBox
- (void)finishWith:(BOOL)ok code:(NSString *)code desc:(NSString *)desc
{
    if (self.finished) return;
    self.finished = YES;
    if (self.onResult) { void (^c)(BOOL, NSString *, NSString *) = self.onResult; self.onResult = nil; c(ok, code, desc); }
}
- (void)onAdLoaded { [self finishWith:YES code:nil desc:nil]; }
- (void)onAdShow { }
- (void)onAdClicked { }
- (void)onAdReward:(NSString *)userId userCustomData:(NSString *)userCustomData { }
- (void)onAdClosed { }
- (void)onAdShowComplete:(NSString *)userId userCustomData:(NSString *)userCustomData { }
- (void)onAdLoadTimeout { [self finishWith:NO code:@"TIMEOUT" desc:@"onAdLoadTimeout"]; }
- (void)onAdError:(NSString *)code desc:(NSString *)desc { [self finishWith:NO code:code desc:desc]; }
@end

#pragma mark - AppDelegate

@interface AppDelegate () <UIApplicationDelegate>
@property (nonatomic, strong) NSArray<NSString *> *steps;
@property (nonatomic, assign) NSUInteger idx;
@property (nonatomic, assign) BOOL seqFail;
@property (nonatomic, assign) BOOL seqStarted;
@property (nonatomic, strong) P0FAutoRunnerVC *autoVC;
@property (nonatomic, strong) NSArray<NSString *> *splashProbeIDs;
@property (nonatomic, assign) NSUInteger splashProbeIdx;
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
            @"REINIT_R3":   @[@"FI",@"FCLR",@"FI",@"FA"],          // §18 R3：FI→clear→FI→FA
            @"REINIT_R4":   @[@"LI",@"FI",@"FCLR",@"FI",@"LA",@"FA"], // §18 R4：跨 SDK clear 回归
            // ── P0F-V2：Splash 主矩阵（§6/§10/§17）──
            @"SPLASH_LY":   @[@"LI",@"LS"],            // LY splash standalone
            @"SPLASH_FL":   @[@"FI",@"FS"],            // FL splash standalone
            @"CASE_A_S":    @[@"LI",@"LS",@"FI",@"FS",@"LS",@"FS"],
            @"CASE_B_S":    @[@"FI",@"FS",@"LI",@"LS",@"FS",@"LS"],
            @"C1_S":        @[@"LI",@"LS",@"FI",@"FS"],
            @"C2_S":        @[@"FI",@"FS",@"LI",@"LS"],
            @"C3_S":        @[@"LI",@"FI",@"LS",@"FS",@"LS",@"FS"],
            @"C4_S":        @[@"FI",@"LI",@"FS",@"LS",@"FS",@"LS"],
            @"REINIT_S1":   @[@"LI",@"LI",@"LS"],
            @"REINIT_S2":   @[@"FI",@"FI",@"FS"],
            @"REINIT_S3":   @[@"FI",@"FCLR",@"FI",@"FS"],
            @"REINIT_S4":   @[@"LI",@"FI",@"FCLR",@"FI",@"LS",@"FS"],
            @"SMOKE_LR":    @[@"LI",@"LR"],            // §12 Reward smoke（一次性）
            @"SMOKE_FR":    @[@"FI",@"FR"],
            @"SPLASH_PROBE":@[@"FI",@"FSPROBE"],       // 探测 8 个未知 q-ID 哪个是开屏位
            @"C0":          @[@"FI"],            // §16：仅链接，不调 CJ 任何 API
            @"C1_FULL":     @[@"LI",@"LA",@"FI",@"FA"],  // P0D §早期组合（保留入口）
            @"C2_FULL":     @[@"FI",@"FA",@"LI",@"LA"],
        };
        self.steps = map[seq] ?: @[@"LI"];
        // §13：ENV 只确认 key 存在，不打印值（AppKey 永不打印）
        NSLog(@"[P0D-C] ENV_KEYS_PRESENT P0D_FAPPID=%@ P0D_FAPPKEY=%@ P0D_FPLACE=%@（值不打印）",
              Env(@"P0D_FAPPID").length ? @"present" : @"MISSING",
              Env(@"P0D_FAPPKEY").length ? @"present" : @"MISSING",
              Env(@"P0D_FPLACE").length ? @"present" : @"MISSING");
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
            [P0DProbe lateInstallWindMillProbe];
            done(ok);
        }];
    }
    else if ([s isEqualToString:@"LA"] || [s isEqualToString:@"LR"]) {
        NSLog(@"[P0D-C] %@_BEGIN", s);
        [[LingyeTestController shared] runRewardFlow:^(BOOL ok, NSString *code, NSString *msg) { done(ok); }];
    }
    else if ([s isEqualToString:@"FA"] || [s isEqualToString:@"FR"]) {
        [self p0dRunFAWithRetry:done];
    }
    else if ([s isEqualToString:@"LS"]) {
        [self p0dRunSplashWithRetry:NO done:done];   // Lingye splash
    }
    else if ([s isEqualToString:@"FS"]) {
        [self p0dRunSplashWithRetry:YES done:done];  // Flame splash
    }
    else if ([s isEqualToString:@"FSPROBE"]) {
        [self p0dRunFlameSplashProbe:done];
    }
    else if ([s isEqualToString:@"FCLR"]) {
        NSLog(@"[P0D-C] FCLR_BEGIN");
        [[FlameTestController shared] clearSDK];
        NSLog(@"[P0D-C] FCLR_DONE");
        done(YES);
    }
    else done(YES);
}

// §9：开屏 load 失败仅自动重试 1 次（间隔 6s）
- (void)p0dRunSplashWithRetry:(BOOL)flame done:(void (^)(BOOL))done
{
    NSLog(@"[P0D-C] %@_BEGIN", flame ? @"FS" : @"LS");
    __block NSInteger attempt = 0;
    __block void (^runOnce)(void) = nil;
    runOnce = ^{
        attempt++;
        NSLog(@"[P0D-C] %@_ATTEMPT #%d", flame ? @"FS" : @"LS", (int)attempt);
        P0FAdDone flow = ^(BOOL ok, NSString *code, NSString *msg) {
            if (!ok && attempt == 1) {
                NSLog(@"[P0D-C] %@_LOAD_FAIL retry-after-6s code=%@", flame ? @"FS" : @"LS", code ?: @"-");
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(6 * NSEC_PER_SEC)),
                               dispatch_get_main_queue(), runOnce);
            } else {
                runOnce = nil;
                done(ok);
            }
        };
        if (flame) [[FlameTestController shared] runSplashFlow:flow];
        else [[LingyeTestController shared] runSplashFlow:flow];
    };
    runOnce();
}

// ── Flame 开屏位探测：对 8 个未知 q-ID 逐一 load splash（TEST_ONLY，只读不改后台）──
- (void)p0dRunFlameSplashProbe:(void (^)(BOOL))done
{
    if (!self.splashProbeIDs) {
        self.splashProbeIDs = @[@"q36508625734", @"q37305276475", @"q39142205000", @"q44128606635",
                                @"q55921206210", @"q71507861622", @"q76977734904", @"q82857633975"];
        self.splashProbeIdx = 0;
    }
    [self probeNextSplashID:done];
}

- (void)probeNextSplashID:(void (^)(BOOL))done
{
    if (self.splashProbeIdx >= self.splashProbeIDs.count) {
        NSLog(@"[P0D-C] SPLASH_PROBE_DONE");
        self.splashProbeIDs = nil;
        self.splashProbeIdx = 0;
        done(YES);
        return;
    }
    __weak typeof(self) w = self;
    NSString *pid = self.splashProbeIDs[self.splashProbeIdx];
    NSLog(@"[P0D-C] SPLASH_PROBE %@ BEGIN", pid);
    P0FSplashProbeBox *box = [[P0FSplashProbeBox alloc] init];
    id<FlameSplashAd> ad = [FlameSdk createSplashAdWithViewController:self.window.rootViewController
                                                          placementId:pid listener:box];
    box.onResult = ^(BOOL ok, NSString *code, NSString *desc) {
        NSLog(@"[P0D-C] SPLASH_PROBE_RESULT pid=%@ %@ code=%@ desc=%@",
              pid, ok ? @"LOADED<<< 开屏位命中" : @"fail", code ?: @"-", desc ?: @"-");
        [ad destroy];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            w.splashProbeIdx++;
            [w probeNextSplashID:done];
        });
    };
    // 12s 看门狗
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(12 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (!box.finished) {
            NSLog(@"[P0D-C] SPLASH_PROBE_RESULT pid=%@ timeout", pid);
            [box finishWith:NO code:@"TIMEOUT" desc:@"12s watchdog"];
        }
    });
    [ad load];
}

// §17：FA load→800110 仅自动重试 1 次（间隔 6s），禁止死循环；统计经日志 FA_ATTEMPT/FA_NO_FILL
- (void)p0dRunFAWithRetry:(void (^)(BOOL))done
{
    NSLog(@"[P0D-C] FA_BEGIN");
    __block NSInteger attempt = 0;
    __block void (^runOnce)(void) = nil;
    __weak typeof(self) w = self;
    runOnce = ^{
        attempt++;
        NSLog(@"[P0D-C] FA_ATTEMPT #%d", (int)attempt);
        [[FlameTestController shared] runRewardFlow:^(BOOL ok, NSString *code, NSString *msg) {
            if (!ok && attempt == 1 && [code isEqualToString:@"800110"]) {
                NSLog(@"[P0D-C] FA_NO_FILL retry-after-6s");
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(6 * NSEC_PER_SEC)),
                               dispatch_get_main_queue(), runOnce);
            } else {
                runOnce = nil;
                done(ok);
            }
        }];
    };
    runOnce();
}

@end
