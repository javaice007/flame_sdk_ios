//
//  P0FConsoleViewController.m — Coexist Test Console（人工验收工作台，TEST_ONLY）
//
//  §23：白底、分区明显、按钮大、状态颜色易识别；不做动画/特效。
//  所有状态变化只由 P0FTestCore 事件驱动；不硬编码任何 PASS（§21）。
//

#import "P0FConsoleViewController.h"
#import "P0FTestCore.h"
#import <flame_sdk_ios/flame_sdk_ios.h>

@interface P0FConsoleViewController () <P0FTestListener, UITextViewDelegate>
// zone A
@property (nonatomic, strong) UILabel *configLabel;
@property (nonatomic, strong) UILabel *resolvedLabel;
// last action card
@property (nonatomic, strong) UILabel *lastActionLabel;
// badges
@property (nonatomic, strong) UILabel *lingyeBadge;
@property (nonatomic, strong) UILabel *flameBadge;
// per-ad state lines
@property (nonatomic, strong) UILabel *lingyeSplashStateLabel;
@property (nonatomic, strong) UILabel *lingyeRewardStateLabel;
@property (nonatomic, strong) UILabel *flameSplashStateLabel;
@property (nonatomic, strong) UILabel *flameRewardStateLabel;
// buttons
@property (nonatomic, strong) UIButton *liInitBtn;
@property (nonatomic, strong) UIButton *liSplashLoadBtn;
@property (nonatomic, strong) UIButton *liSplashShowBtn;
@property (nonatomic, strong) UIButton *liRewardLoadBtn;
@property (nonatomic, strong) UIButton *liRewardShowBtn;
@property (nonatomic, strong) UIButton *liResetBtn;
@property (nonatomic, strong) UIButton *fiInitBtn;
@property (nonatomic, strong) UIButton *fiSplashLoadBtn;
@property (nonatomic, strong) UIButton *fiSplashShowBtn;
@property (nonatomic, strong) UIButton *fiRewardLoadBtn;
@property (nonatomic, strong) UIButton *fiRewardShowBtn;
@property (nonatomic, strong) UIButton *fiClearBtn;
@property (nonatomic, strong) UIButton *caseABtn;
@property (nonatomic, strong) UIButton *caseBBtn;
@property (nonatomic, strong) UIButton *clearLogBtn;
@property (nonatomic, strong) UIButton *resetAllBtn;
@property (nonatomic, strong) UIButton *logCopyBtn;
// log panel
@property (nonatomic, strong) UITextView *logView;
// last-action accumulator
@property (nonatomic, copy) NSString *cardKey;
@property (nonatomic, copy) NSString *cardOwner;
@property (nonatomic, copy) NSString *cardType;
@property (nonatomic, copy) NSString *cardResult;
@property (nonatomic, copy) NSString *cardNetwork;
@property (nonatomic, copy) NSString *cardPlacement;
@property (nonatomic, copy) NSString *cardTransId;
@property (nonatomic, copy) NSString *cardRequestId;
@property (nonatomic, copy) NSString *cardLoad;
@property (nonatomic, copy) NSString *cardShow;
@property (nonatomic, copy) NSString *cardReward;
@property (nonatomic, copy) NSString *cardClose;
@property (nonatomic, copy) NSString *cardTime;
// quick-case runner
@property (nonatomic, assign) BOOL caseRunning;
@end

@implementation P0FConsoleViewController

#pragma mark lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];
    LingyeTestController.shared.listener = self;
    FlameTestController.shared.listener = self;
    [self buildUI];
    [self renderAll];
    [self appendLog:[NSString stringWithFormat:@"%@ [CONSOLE] MANUAL_MODE Coexist Test Console ready（人工验收）", [self now]]];
    [self appendLog:[NSString stringWithFormat:@"%@ [CONSOLE] 提示：先点【初始化领页】/【初始化 Flame】，再加载/展示对应广告", [self now]]];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [LingyeTestController.shared setRootViewController:self window:self.view.window];
    [FlameTestController.shared setRootViewController:self window:self.view.window];
}

#pragma mark UI building

// badge 行占位（撑满）
static inline UIView *P0FSpacer(void)
{
    UIView *v = [[UIView alloc] init];
    [v setUserInteractionEnabled:NO];
    return v;
}

- (UILabel *)makeLabel:(CGFloat)size bold:(BOOL)bold color:(UIColor *)color
{
    UILabel *l = [[UILabel alloc] init];
    l.font = [UIFont monospacedSystemFontOfSize:size weight:bold ? UIFontWeightSemibold : UIFontWeightRegular];
    l.textColor = color;
    l.numberOfLines = 0;
    return l;
}

- (UIButton *)makeButton:(NSString *)title action:(SEL)sel color:(UIColor *)color
{
    UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
    [b setTitle:title forState:UIControlStateNormal];
    b.titleLabel.font = [UIFont boldSystemFontOfSize:15];
    [b setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    b.backgroundColor = color;
    b.layer.cornerRadius = 6;
    b.contentEdgeInsets = UIEdgeInsetsMake(12, 8, 12, 8);
    [b addTarget:self action:sel forControlEvents:UIControlEventTouchUpInside];
    return b;
}

- (void)buildUI
{
    UIScrollView *scroll = [[UIScrollView alloc] initWithFrame:self.view.bounds];
    scroll.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:scroll];
    UIStackView *stack = [[UIStackView alloc] init];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 10;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [scroll addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[
        [stack.topAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.topAnchor constant:12],
        [stack.leadingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.leadingAnchor constant:16],
        [stack.trailingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.trailingAnchor constant:-16],
        [stack.bottomAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.bottomAnchor constant:-24],
        [stack.widthAnchor constraintEqualToAnchor:scroll.frameLayoutGuide.widthAnchor constant:-32],
    ]];

    UIView *(^card)(NSString *) = ^(NSString *title) {
        UIView *v = [[UIView alloc] init];
        v.backgroundColor = [UIColor colorWithWhite:0.96 alpha:1];
        v.layer.cornerRadius = 8;
        UIStackView *s = [[UIStackView alloc] init];
        s.axis = UILayoutConstraintAxisVertical;
        s.spacing = 4;
        s.translatesAutoresizingMaskIntoConstraints = NO;
        [v addSubview:s];
        [NSLayoutConstraint activateConstraints:@[
            [s.topAnchor constraintEqualToAnchor:v.topAnchor constant:8],
            [s.leadingAnchor constraintEqualToAnchor:v.leadingAnchor constant:10],
            [s.trailingAnchor constraintEqualToAnchor:v.trailingAnchor constant:-10],
            [s.bottomAnchor constraintEqualToAnchor:v.bottomAnchor constant:-8],
        ]];
        s.tag = 777;
        UILabel *h = [self makeLabel:14 bold:YES color:[UIColor blackColor]];
        h.text = title;
        [s addArrangedSubview:h];
        return v;
    };

    // ── 标题 ──
    UILabel *title = [self makeLabel:20 bold:YES color:[UIColor blackColor]];
    title.text = @"Coexist Test Console";
    UILabel *subtitle = [self makeLabel:12 bold:NO color:[UIColor darkGrayColor]];
    subtitle.text = @"领页 CJMobileAd 2.4.32 × Flame TB（ToBid）共存 · 人工验收工作台";
    [stack addArrangedSubview:title];
    [stack addArrangedSubview:subtitle];

    // ── Zone A 当前配置 ──
    UIView *cfg = card(@"A · 当前配置");
    UIStackView *cfgStack = [cfg viewWithTag:777];
    _configLabel = [self makeLabel:12 bold:NO color:[UIColor blackColor]];
    _resolvedLabel = [self makeLabel:12 bold:YES color:[UIColor colorWithWhite:0.2 alpha:1]];
    [cfgStack addArrangedSubview:_configLabel];
    [cfgStack addArrangedSubview:_resolvedLabel];
    [stack addArrangedSubview:cfg];

    // ── Zone LAST ACTION ──
    UIView *last = card(@"LAST ACTION（最后一次广告结果，可直接截图留证）");
    UIStackView *lastStack = [last viewWithTag:777];
    _lastActionLabel = [self makeLabel:12 bold:NO color:[UIColor blackColor]];
    _lastActionLabel.text = @"（尚未执行任何广告动作）";
    [lastStack addArrangedSubview:_lastActionLabel];
    [stack addArrangedSubview:last];

    // ── Zone B 领页 ──
    UIView *li = card(@"B · 领页控制区（OWNER = LINGYE）");
    UIStackView *liStack = [li viewWithTag:777];
    UIStackView *liBadgeRow = [[UIStackView alloc] init];
    liBadgeRow.axis = UILayoutConstraintAxisHorizontal;
    _lingyeBadge = [self makeBadge];
    [liBadgeRow addArrangedSubview:_lingyeBadge];
    [liBadgeRow addArrangedSubview:P0FSpacer()];
    [liStack addArrangedSubview:liBadgeRow];
    _liInitBtn = [self makeButton:@"初始化领页" action:@selector(liInit:) color:[UIColor colorWithRed:0.2 green:0.45 blue:0.85 alpha:1]];
    _liSplashLoadBtn = [self makeButton:@"加载领页开屏" action:@selector(liSplashLoad:) color:[UIColor colorWithRed:0.35 green:0.55 blue:0.8 alpha:1]];
    _liSplashShowBtn = [self makeButton:@"展示领页开屏" action:@selector(liSplashShow:) color:[UIColor colorWithRed:0.25 green:0.45 blue:0.7 alpha:1]];
    _liRewardLoadBtn = [self makeButton:@"加载领页激励" action:@selector(liRewardLoad:) color:[UIColor colorWithRed:0.2 green:0.45 blue:0.85 alpha:1]];
    _liRewardShowBtn = [self makeButton:@"展示领页激励" action:@selector(liRewardShow:) color:[UIColor colorWithRed:0.25 green:0.45 blue:0.7 alpha:1]];
    _liResetBtn = [self makeButton:@"清理/重置领页状态" action:@selector(liReset:) color:[UIColor grayColor]];
    for (UIButton *b in @[_liInitBtn, _liSplashLoadBtn, _liSplashShowBtn, _liRewardLoadBtn, _liRewardShowBtn, _liResetBtn]) {
        [liStack addArrangedSubview:b];
    }
    _lingyeSplashStateLabel = [self makeLabel:11 bold:NO color:[UIColor darkGrayColor]];
    _lingyeRewardStateLabel = [self makeLabel:11 bold:NO color:[UIColor darkGrayColor]];
    [liStack addArrangedSubview:_lingyeSplashStateLabel];
    [liStack addArrangedSubview:_lingyeRewardStateLabel];
    [stack addArrangedSubview:li];

    // ── Zone C Flame ──
    UIView *fi = card(@"C · Flame 控制区（OWNER = FLAME，MEDIATION = TOBID）");
    UIStackView *fiStack = [fi viewWithTag:777];
    UIStackView *fiBadgeRow = [[UIStackView alloc] init];
    fiBadgeRow.axis = UILayoutConstraintAxisHorizontal;
    _flameBadge = [self makeBadge];
    [fiBadgeRow addArrangedSubview:_flameBadge];
    [fiBadgeRow addArrangedSubview:P0FSpacer()];
    [fiStack addArrangedSubview:fiBadgeRow];
    _fiInitBtn = [self makeButton:@"初始化 Flame" action:@selector(fiInit:) color:[UIColor colorWithRed:0.85 green:0.45 blue:0.2 alpha:1]];
    _fiSplashLoadBtn = [self makeButton:@"加载 Flame 开屏" action:@selector(fiSplashLoad:) color:[UIColor colorWithRed:0.8 green:0.55 blue:0.3 alpha:1]];
    _fiSplashShowBtn = [self makeButton:@"展示 Flame 开屏" action:@selector(fiSplashShow:) color:[UIColor colorWithRed:0.7 green:0.45 blue:0.25 alpha:1]];
    _fiRewardLoadBtn = [self makeButton:@"加载 Flame 激励" action:@selector(fiRewardLoad:) color:[UIColor colorWithRed:0.85 green:0.45 blue:0.2 alpha:1]];
    _fiRewardShowBtn = [self makeButton:@"展示 Flame 激励" action:@selector(fiRewardShow:) color:[UIColor colorWithRed:0.7 green:0.45 blue:0.25 alpha:1]];
    _fiClearBtn = [self makeButton:@"Flame Clear" action:@selector(fiClear:) color:[UIColor grayColor]];
    for (UIButton *b in @[_fiInitBtn, _fiSplashLoadBtn, _fiSplashShowBtn, _fiRewardLoadBtn, _fiRewardShowBtn, _fiClearBtn]) {
        [fiStack addArrangedSubview:b];
    }
    _flameSplashStateLabel = [self makeLabel:11 bold:NO color:[UIColor darkGrayColor]];
    _flameRewardStateLabel = [self makeLabel:11 bold:NO color:[UIColor darkGrayColor]];
    [fiStack addArrangedSubview:_flameSplashStateLabel];
    [fiStack addArrangedSubview:_flameRewardStateLabel];
    [stack addArrangedSubview:fi];

    // ── 快捷 Case（不替代独立按钮）──
    UIView *qc = card(@"快捷 Case（自动按顺序执行，独立按钮仍可用）");
    UIStackView *qcStack = [qc viewWithTag:777];
    _caseABtn = [self makeButton:@"Case A：领页先（LI→LA→FI→FA→LA）" action:@selector(caseA:) color:[UIColor colorWithRed:0.4 green:0.4 blue:0.75 alpha:1]];
    _caseBBtn = [self makeButton:@"Case B：Flame 先（FI→FA→LI→LA→FA）" action:@selector(caseB:) color:[UIColor colorWithRed:0.4 green:0.4 blue:0.75 alpha:1]];
    [qcStack addArrangedSubview:_caseABtn];
    [qcStack addArrangedSubview:_caseBBtn];
    [stack addArrangedSubview:qc];

    // ── 管理 ──
    UIView *mg = card(@"管理");
    UIStackView *mgStack = [mg viewWithTag:777];
    _clearLogBtn = [self makeButton:@"清空日志" action:@selector(clearLog:) color:[UIColor grayColor]];
    _resetAllBtn = [self makeButton:@"重置测试状态" action:@selector(resetAll:) color:[UIColor grayColor]];
    _logCopyBtn = [self makeButton:@"复制当前日志" action:@selector(copyLog:) color:[UIColor grayColor]];
    [mgStack addArrangedSubview:_clearLogBtn];
    [mgStack addArrangedSubview:_resetAllBtn];
    [mgStack addArrangedSubview:_logCopyBtn];
    [stack addArrangedSubview:mg];

    // ── Zone D 日志 ──
    UIView *lg = card(@"D · 日志 / 状态区（runtime 实时）");
    UIStackView *lgStack = [lg viewWithTag:777];
    _logView = [[UITextView alloc] init];
    _logView.font = [UIFont monospacedSystemFontOfSize:10 weight:UIFontWeightRegular];
    _logView.backgroundColor = [UIColor blackColor];
    _logView.textColor = [UIColor colorWithWhite:0.85 alpha:1];
    _logView.editable = NO;
    _logView.layer.cornerRadius = 6;
    [_logView.heightAnchor constraintEqualToConstant:300].active = YES;
    [lgStack addArrangedSubview:_logView];
    [stack addArrangedSubview:lg];

    [self renderAll];
}

// 顶部声明区需要 spacer 辅助（badge 行撑满）
// （见文件前部 P0FSpacer）

- (UILabel *)makeBadge
{
    UILabel *b = [[UILabel alloc] init];
    b.font = [UIFont boldSystemFontOfSize:12];
    b.textAlignment = NSTextAlignmentCenter;
    b.layer.cornerRadius = 4;
    b.clipsToBounds = YES;
    b.text = @"  NOT_INITIALIZED  ";
    b.backgroundColor = [UIColor lightGrayColor];
    b.textColor = [UIColor whiteColor];
    return b;
}

#pragma mark actions（只调 Controller，不直接碰 SDK —— MANUAL_TEST_PATH == AUTOMATED_TEST_PATH）

- (void)liInit:(UIButton *)s { [[LingyeTestController shared] initSDK:nil]; }
- (void)liSplashLoad:(UIButton *)s { [[LingyeTestController shared] loadSplash:nil]; }
- (void)liSplashShow:(UIButton *)s { [[LingyeTestController shared] showSplash:nil]; }
- (void)liRewardLoad:(UIButton *)s { [[LingyeTestController shared] loadReward:nil]; }
- (void)liRewardShow:(UIButton *)s { [[LingyeTestController shared] showReward:nil]; }
- (void)liReset:(UIButton *)s { [[LingyeTestController shared] resetState]; }
- (void)fiInit:(UIButton *)s { [[FlameTestController shared] initSDK:nil]; }
- (void)fiSplashLoad:(UIButton *)s { [[FlameTestController shared] loadSplash:nil]; }
- (void)fiSplashShow:(UIButton *)s { [[FlameTestController shared] showSplash:nil]; }
- (void)fiRewardLoad:(UIButton *)s { [[FlameTestController shared] loadReward:nil]; }
- (void)fiRewardShow:(UIButton *)s { [[FlameTestController shared] showReward:nil]; }
- (void)fiClear:(UIButton *)s { [[FlameTestController shared] clearSDK]; }
- (void)clearLog:(UIButton *)s { self.logView.text = @""; }
- (void)resetAll:(UIButton *)s
{
    [[LingyeTestController shared] resetState];
    [[FlameTestController shared] clearSDK];
}
- (void)copyLog:(UIButton *)s
{
    [UIPasteboard generalPasteboard].string = self.logView.text;
    [self appendLog:[NSString stringWithFormat:@"%@ [CONSOLE] 日志已复制到剪贴板（已脱敏：不含 AppKey/Secret）", [self now]]];
}

- (void)caseA:(UIButton *)s { [self runCase:@[@"LI", @"LA", @"FI", @"FA", @"LA"]]; }
- (void)caseB:(UIButton *)s { [self runCase:@[@"FI", @"FA", @"LI", @"LA", @"FA"]]; }

- (void)runCase:(NSArray<NSString *> *)steps
{
    if (self.caseRunning) return;
    self.caseRunning = YES;
    [self appendLog:[NSString stringWithFormat:@"%@ [CASE] BEGIN %@", [self now], [steps componentsJoinedByString:@"→"]]];
    [self runCaseSteps:steps index:0];
    [self renderAll];
}

- (void)runCaseSteps:(NSArray<NSString *> *)steps index:(NSUInteger)i
{
    if (i >= steps.count) {
        self.caseRunning = NO;
        [self appendLog:[NSString stringWithFormat:@"%@ [CASE] END", [self now]]];
        [self renderAll];
        return;
    }
    __weak typeof(self) w = self;
    NSString *st = steps[i];
    [self appendLog:[NSString stringWithFormat:@"%@ [CASE] STEP %@ BEGIN", [self now], st]];
    P0FAdDone done = ^(BOOL ok, NSString *code, NSString *msg) {
        [w appendLog:[NSString stringWithFormat:@"%@ [CASE] STEP %@ %@", [w now], st,
                      ok ? @"OK" : [NSString stringWithFormat:@"FAIL code=%@ msg=%@", code ?: @"-", msg ?: @"-"]]];
        dispatch_async(dispatch_get_main_queue(), ^{ [w runCaseSteps:steps index:i + 1]; });
    };
    if ([st isEqualToString:@"LI"]) [[LingyeTestController shared] initSDK:done];
    else if ([st isEqualToString:@"FI"]) [[FlameTestController shared] initSDK:done];
    else if ([st isEqualToString:@"LA"]) [[LingyeTestController shared] runRewardFlow:done];
    else if ([st isEqualToString:@"FA"]) [[FlameTestController shared] runRewardFlow:done];
    else { done(YES, nil, nil); }
}

#pragma mark P0FTestListener

- (void)p0fEvent:(P0FAdEvent *)e
{
    [self appendLog:e.line];
    [self updateCard:e];
    [self renderAll];
}

#pragma mark rendering

- (NSString *)now
{
    NSDateFormatter *f = [[NSDateFormatter alloc] init];
    f.dateFormat = @"HH:mm:ss";
    return [f stringFromDate:[NSDate date]];
}

- (void)appendLog:(NSString *)line
{
    if (line.length == 0) return;
    NSMutableString *t = [NSMutableString stringWithString:self.logView.text ?: @""];
    if (t.length) [t appendFormat:@"\n%@", line];
    else [t appendString:line];
    // 截断保护
    NSArray *lines = [t componentsSeparatedByString:@"\n"];
    if (lines.count > 400) {
        lines = [lines subarrayWithRange:NSMakeRange(lines.count - 300, 300)];
        t = [NSMutableString stringWithString:[lines componentsJoinedByString:@"\n"]];
    }
    self.logView.text = t;
    NSRange bottom = NSMakeRange(self.logView.text.length, 0);
    [self.logView scrollRangeToVisible:bottom];
}

- (NSString *)sdkStateText:(P0FSDKState)st
{
    switch (st) {
        case P0FSDKStateNotInitialized: return @"NOT_INITIALIZED";
        case P0FSDKStateInitializing:  return @"INITIALIZING";
        case P0FSDKStateReady:         return @"READY";
        case P0FSDKStateError:         return @"ERROR";
    }
    return @"?";
}

- (UIColor *)sdkStateColor:(P0FSDKState)st
{
    switch (st) {
        case P0FSDKStateNotInitialized: return [UIColor lightGrayColor];
        case P0FSDKStateInitializing:  return [UIColor colorWithRed:0.2 green:0.5 blue:0.9 alpha:1];
        case P0FSDKStateReady:         return [UIColor colorWithRed:0.2 green:0.65 blue:0.3 alpha:1];
        case P0FSDKStateError:         return [UIColor colorWithRed:0.85 green:0.25 blue:0.2 alpha:1];
    }
    return [UIColor grayColor];
}

- (NSString *)adStateText:(P0FAdState)st
{
    switch (st) {
        case P0FAdStateIdle:     return @"IDLE";
        case P0FAdStateLoading:  return @"LOADING";
        case P0FAdStateReady:    return @"READY";
        case P0FAdStateShowing:  return @"SHOWING";
        case P0FAdStateRewarded: return @"REWARDED";
        case P0FAdStateClosed:   return @"CLOSED";
        case P0FAdStateError:    return @"ERROR";
        case P0FAdStateTimeout:  return @"TIMEOUT";
    }
    return @"?";
}

- (void)renderAll
{
    LingyeTestController *L = LingyeTestController.shared;
    FlameTestController *F = FlameTestController.shared;
    P0FAdConfig *cfg = L.config;

    // badges
    self.lingyeBadge.text = [NSString stringWithFormat:@"  %@  ", [self sdkStateText:L.sdkState]];
    self.lingyeBadge.backgroundColor = [self sdkStateColor:L.sdkState];
    self.flameBadge.text = [NSString stringWithFormat:@"  %@  ", [self sdkStateText:F.sdkState]];
    self.flameBadge.backgroundColor = [self sdkStateColor:F.sdkState];

    // zone A config（AppKey 永不展示明文 §17）
    self.configLabel.text = [NSString stringWithFormat:
        @"Lingye SDK: CJMobileAd 2.4.32\n"
         "Flame SDK: flame_sdk_ios_tb_lingye (%@)\n"
         "Flame App ID: %@\n"
         "Flame Reward Placement: %@\n"
         "Flame Splash Placement: %@\n"
         "Lingye Reward ID: %@\n"
         "Lingye Splash ID: %@\n"
         "App Key: ••••••（已配置，不展示）\n"
         "Device: %@ / iOS %@",
        [self flameVersion], cfg.flameAppId.length ? cfg.flameAppId : @"（未配置）",
        cfg.flameRewardPlacement.length ? cfg.flameRewardPlacement : @"（未配置）",
        cfg.flameSplashPlacement.length ? cfg.flameSplashPlacement : @"（未配置）",
        cfg.lingyeRewardId, cfg.lingyeSplashId.length ? cfg.lingyeSplashId : @"（未配置）",
        [UIDevice currentDevice].model, [UIDevice currentDevice].systemVersion];

    // resolved runtime identity（§6：取不到显示 N/A，不伪造）
    NSString *tobidApp = [P0FLogTap shared].resolvedTobidAppId ?: @"N/A";
    self.resolvedLabel.text = [NSString stringWithFormat:
        @"Resolved ToBid App ID: %@\n"
         "Resolved ToBid Placement: %@\n"
         "Network Placement: %@\n"
         "Last Network: %@\n"
         "Last transId: %@",
        tobidApp,
        F.lastTobidPlacement ?: @"N/A",
        F.lastNetworkPlacement ?: @"N/A",
        F.lastRewardNetwork ?: @"N/A",
        F.lastTransId ?: @"N/A"];

    // ad state lines
    self.lingyeSplashStateLabel.text = [NSString stringWithFormat:@"SPLASH: %@ (placement %@)",
        [self adStateText:L.splashState], cfg.lingyeSplashId.length ? cfg.lingyeSplashId : @"未配置→按钮不可用"];
    self.lingyeRewardStateLabel.text = [NSString stringWithFormat:@"REWARD: %@ network=%@ requestId=%@ attempt=#%ld",
        [self adStateText:L.rewardState], L.lastRewardNetwork ?: @"-", L.lastRewardRequestId ?: @"-", (long)L.rewardAttempt];
    self.flameSplashStateLabel.text = [NSString stringWithFormat:@"SPLASH: %@ (placement %@)",
        [self adStateText:F.splashState], cfg.flameSplashPlacement.length ? cfg.flameSplashPlacement : @"未配置→按钮不可用"];
    self.flameRewardStateLabel.text = [NSString stringWithFormat:
        @"REWARD: %@\nNETWORK: %@  TOBID_PLACEMENT: %@  NETWORK_PLACEMENT: %@  TRANS_ID: %@",
        [self adStateText:F.rewardState],
        F.lastRewardNetwork ?: @"N/A", F.lastTobidPlacement ?: @"N/A",
        F.lastNetworkPlacement ?: @"N/A", F.lastTransId ?: @"N/A"];

    // buttons
    self.liInitBtn.enabled = (L.sdkState != P0FSDKStateInitializing);
    BOOL liSplashCfg = cfg.lingyeSplashId.length > 0;
    self.liSplashLoadBtn.enabled = liSplashCfg && L.sdkState == P0FSDKStateReady && L.splashState != P0FAdStateLoading;
    self.liSplashShowBtn.enabled = liSplashCfg && L.splashState == P0FAdStateReady;
    self.liRewardLoadBtn.enabled = L.sdkState == P0FSDKStateReady && L.rewardState != P0FAdStateLoading;
    self.liRewardShowBtn.enabled = L.rewardState == P0FAdStateReady;
    self.fiInitBtn.enabled = (F.sdkState != P0FSDKStateInitializing);
    BOOL fiSplashCfg = cfg.flameSplashPlacement.length > 0;
    self.fiSplashLoadBtn.enabled = fiSplashCfg && F.sdkState == P0FSDKStateReady && F.splashState != P0FAdStateLoading;
    self.fiSplashShowBtn.enabled = fiSplashCfg && F.splashState == P0FAdStateReady;
    self.fiRewardLoadBtn.enabled = F.sdkState == P0FSDKStateReady && F.rewardState != P0FAdStateLoading;
    self.fiRewardShowBtn.enabled = F.rewardState == P0FAdStateReady;
    self.caseABtn.enabled = !self.caseRunning;
    self.caseBBtn.enabled = !self.caseRunning;

    for (UIButton *b in @[self.liSplashLoadBtn, self.liSplashShowBtn, self.fiSplashLoadBtn, self.fiSplashShowBtn]) {
        b.alpha = b.enabled ? 1.0 : 0.4;
    }
    for (UIButton *b in @[self.liInitBtn, self.liRewardLoadBtn, self.liRewardShowBtn,
                          self.fiInitBtn, self.fiRewardLoadBtn, self.fiRewardShowBtn,
                          self.caseABtn, self.caseBBtn]) {
        b.alpha = b.enabled ? 1.0 : 0.4;
    }

    [self renderCard];
}

- (NSString *)flameVersion
{
    @try {
        NSString *v = [[FlameSdk sharedInstance] getVersion];
        return v ?: @"";
    } @catch (NSException *e) {
        return @"";
    }
}

#pragma mark LAST ACTION card（§16）

- (void)updateCard:(P0FAdEvent *)e
{
    BOOL isStart = ([e.action isEqualToString:@"LOAD"] && [e.message isEqualToString:@"START"])
                || ([e.action isEqualToString:@"INIT"] && [e.message isEqualToString:@"START"]);
    NSString *key = [NSString stringWithFormat:@"%@|%@", e.owner, e.kind];
    if (isStart || ![key isEqualToString:self.cardKey]) {
        self.cardKey = key;
        self.cardOwner = e.owner;
        self.cardType = e.kind;
        self.cardResult = @"RUNNING";
        self.cardNetwork = nil;
        self.cardPlacement = nil;
        self.cardTransId = nil;
        self.cardRequestId = nil;
        self.cardLoad = @"-";
        self.cardShow = @"-";
        self.cardReward = @"-";
        self.cardClose = @"-";
        self.cardTime = [self now];
    }
    if ([e.action isEqualToString:@"INIT"]) {
        self.cardResult = e.ok ? @"PASS" : @"FAIL";
    } else if ([e.action isEqualToString:@"LOAD"]) {
        if (e.ok && [e.message isEqualToString:@"READY"]) { self.cardLoad = @"PASS"; self.cardNetwork = e.network ?: self.cardNetwork; self.cardPlacement = e.thirdPlacement ?: self.cardPlacement; }
        else if (!e.ok && ![e.message isEqualToString:@"START"]) { self.cardLoad = [NSString stringWithFormat:@"FAIL(%@)", e.code ?: @"?"]; self.cardResult = @"FAIL"; }
    } else if ([e.action isEqualToString:@"SHOW"]) {
        if ([e.message isEqualToString:@"BEGIN"]) { self.cardShow = @"ING"; }
        else if (e.ok) { self.cardShow = @"PASS"; self.cardNetwork = e.network ?: self.cardNetwork; }
    } else if ([e.action isEqualToString:@"REWARD"]) {
        self.cardReward = @"PASS";
        self.cardTransId = e.transId ?: e.requestId ?: self.cardTransId;
    } else if ([e.action isEqualToString:@"CLOSE"]) {
        self.cardClose = @"PASS";
        if (![self.cardResult isEqualToString:@"FAIL"]
            && [self.cardLoad isEqualToString:@"PASS"]
            && [self.cardShow isEqualToString:@"PASS"]) {
            self.cardResult = @"PASS";
        }
    } else if ([e.action isEqualToString:@"ERROR"] || [e.action isEqualToString:@"TIMEOUT"]) {
        self.cardResult = @"FAIL";
        if ([e.action isEqualToString:@"TIMEOUT"]) self.cardLoad = @"TIMEOUT";
        if (e.network) self.cardNetwork = e.network;
    }
    if (e.requestId.length) self.cardRequestId = e.requestId;
    self.cardTime = [self now];
    [self renderCard];
}

- (void)renderCard
{
    if (!self.cardOwner) return;
    NSString *mediation = [self.cardOwner isEqualToString:P0FOwnerFlame] ? @"TOBID" : @"CJ（领页聚合）";
    NSMutableString *s = [NSMutableString string];
    [s appendFormat:@"OWNER: %@   TYPE: %@   RESULT: %@\n", self.cardOwner, self.cardType, self.cardResult];
    [s appendFormat:@"MEDIATION: %@\n", mediation];
    [s appendFormat:@"NETWORK: %@\n", self.cardNetwork ?: @"N/A"];
    [s appendFormat:@"PLACEMENT: %@\n", self.cardPlacement ?: @"N/A"];
    [s appendFormat:@"LOAD: %@   SHOW: %@   REWARD: %@   CLOSE: %@\n", self.cardLoad, self.cardShow, self.cardReward, self.cardClose];
    if (self.cardTransId)   [s appendFormat:@"TRANS_ID: %@\n", self.cardTransId];
    if (self.cardRequestId) [s appendFormat:@"REQUEST_ID: %@\n", self.cardRequestId];
    [s appendFormat:@"TIME: %@", self.cardTime];
    self.lastActionLabel.text = s;
}

@end
