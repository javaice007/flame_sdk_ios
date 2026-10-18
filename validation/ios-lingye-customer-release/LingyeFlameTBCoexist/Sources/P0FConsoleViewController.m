//
//  P0FConsoleViewController.m — Coexist Test Console（P0F-V2 极简人工验收工作台，TEST_ONLY）
//
//  §2/§4/§23：两排六主按钮，单击自动 load→show；
//    第一排 [LY初始化][LY开屏][LY激励]，第二排 [FL初始化][FL开屏][FL激励]；
//  LAST ACTION 卡直接显示 OWNER/TYPE/RESULT/NETWORK/PLACEMENT/ERROR（§19）；
//  配置详情与辅助按钮折叠进「调试工具」（§5）。
//

#import "P0FConsoleViewController.h"
#import "P0FTestCore.h"
#import <flame_sdk_ios/flame_sdk_ios.h>

@interface P0FConsoleViewController () <P0FTestListener>
// 主界面
@property (nonatomic, strong) UILabel *lingyeBadge;
@property (nonatomic, strong) UILabel *flameBadge;
@property (nonatomic, strong) UILabel *lingyeStateLabel;
@property (nonatomic, strong) UILabel *flameStateLabel;
@property (nonatomic, strong) UIButton *liInitBtn;
@property (nonatomic, strong) UIButton *liSplashBtn;
@property (nonatomic, strong) UIButton *liRewardBtn;
@property (nonatomic, strong) UIButton *fiInitBtn;
@property (nonatomic, strong) UIButton *fiSplashBtn;
@property (nonatomic, strong) UIButton *fiRewardBtn;
@property (nonatomic, strong) UILabel *lastActionLabel;
@property (nonatomic, strong) UITextView *logView;
// 调试工具（折叠）
@property (nonatomic, strong) UIButton *debugToggleBtn;
@property (nonatomic, strong) UIStackView *debugStack;
@property (nonatomic, strong) UILabel *configLabel;
@property (nonatomic, strong) UILabel *resolvedLabel;
@property (nonatomic, strong) UIButton *fiClearBtn;
@property (nonatomic, strong) UIButton *resetAllBtn;
@property (nonatomic, strong) UIButton *clearLogBtn;
@property (nonatomic, strong) UIButton *logCopyBtn;
@property (nonatomic, strong) UIButton *caseABtn;
@property (nonatomic, strong) UIButton *caseBBtn;
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
@property (nonatomic, copy) NSString *cardCode;
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
    [self appendLog:[NSString stringWithFormat:@"%@ [CONSOLE] MANUAL_MODE 极简工作台 ready（单击=自动 load→show）", [self now]]];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [LingyeTestController.shared setRootViewController:self window:self.view.window];
    [FlameTestController.shared setRootViewController:self window:self.view.window];
}

#pragma mark UI building

- (NSString *)now
{
    NSDateFormatter *f = [[NSDateFormatter alloc] init];
    f.dateFormat = @"HH:mm:ss";
    return [f stringFromDate:[NSDate date]];
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
    b.titleLabel.font = [UIFont boldSystemFontOfSize:17];
    [b setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    b.backgroundColor = color;
    b.layer.cornerRadius = 8;
    b.contentEdgeInsets = UIEdgeInsetsMake(14, 8, 14, 8);
    [b addTarget:self action:sel forControlEvents:UIControlEventTouchUpInside];
    return b;
}

static inline UIView *P0FSpacer(void)
{
    UIView *v = [[UIView alloc] init];
    [v setUserInteractionEnabled:NO];
    return v;
}

- (UILabel *)makeBadge
{
    UILabel *b = [[UILabel alloc] init];
    b.font = [UIFont boldSystemFontOfSize:13];
    b.textAlignment = NSTextAlignmentCenter;
    b.layer.cornerRadius = 4;
    b.clipsToBounds = YES;
    b.text = @"  NOT_INITIALIZED  ";
    b.backgroundColor = [UIColor lightGrayColor];
    b.textColor = [UIColor whiteColor];
    return b;
}

- (void)buildUI
{
    UIScrollView *scroll = [[UIScrollView alloc] initWithFrame:self.view.bounds];
    scroll.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:scroll];
    UIStackView *stack = [[UIStackView alloc] init];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 12;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [scroll addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[
        [stack.topAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.topAnchor constant:14],
        [stack.leadingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.leadingAnchor constant:14],
        [stack.trailingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.trailingAnchor constant:-14],
        [stack.bottomAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.bottomAnchor constant:-24],
        [stack.widthAnchor constraintEqualToAnchor:scroll.frameLayoutGuide.widthAnchor constant:-28],
    ]];

    UILabel *title = [self makeLabel:19 bold:YES color:[UIColor blackColor]];
    title.text = @"Coexist Test Console";
    [stack addArrangedSubview:title];

    // ── 第一排：领页 ──
    UIStackView *lyHead = [[UIStackView alloc] init];
    lyHead.axis = UILayoutConstraintAxisHorizontal;
    UILabel *lyTag = [self makeLabel:14 bold:YES color:[UIColor blackColor]];
    lyTag.text = @"领页 (LY)";
    _lingyeBadge = [self makeBadge];
    [lyHead addArrangedSubview:lyTag];
    [lyHead addArrangedSubview:_lingyeBadge];
    [lyHead addArrangedSubview:P0FSpacer()];
    [stack addArrangedSubview:lyHead];

    UIStackView *row1 = [[UIStackView alloc] init];
    row1.axis = UILayoutConstraintAxisHorizontal;
    row1.spacing = 8;
    row1.distribution = UIStackViewDistributionFillEqually;
    _liInitBtn   = [self makeButton:@"LY初始化" action:@selector(liInit:) color:[UIColor colorWithRed:0.2 green:0.45 blue:0.85 alpha:1]];
    _liSplashBtn = [self makeButton:@"LY开屏" action:@selector(liSplash:) color:[UIColor colorWithRed:0.3 green:0.55 blue:0.85 alpha:1]];
    _liRewardBtn = [self makeButton:@"LY激励" action:@selector(liReward:) color:[UIColor colorWithRed:0.4 green:0.5 blue:0.9 alpha:1]];
    [row1 addArrangedSubview:_liInitBtn];
    [row1 addArrangedSubview:_liSplashBtn];
    [row1 addArrangedSubview:_liRewardBtn];
    [stack addArrangedSubview:row1];

    _lingyeStateLabel = [self makeLabel:11 bold:NO color:[UIColor darkGrayColor]];
    [stack addArrangedSubview:_lingyeStateLabel];

    // ── 第二排：Flame ──
    UIStackView *flHead = [[UIStackView alloc] init];
    flHead.axis = UILayoutConstraintAxisHorizontal;
    UILabel *flTag = [self makeLabel:14 bold:YES color:[UIColor blackColor]];
    flTag.text = @"Flame (FL · ToBid)";
    _flameBadge = [self makeBadge];
    [flHead addArrangedSubview:flTag];
    [flHead addArrangedSubview:_flameBadge];
    [flHead addArrangedSubview:P0FSpacer()];
    [stack addArrangedSubview:flHead];

    UIStackView *row2 = [[UIStackView alloc] init];
    row2.axis = UILayoutConstraintAxisHorizontal;
    row2.spacing = 8;
    row2.distribution = UIStackViewDistributionFillEqually;
    _fiInitBtn   = [self makeButton:@"FL初始化" action:@selector(fiInit:) color:[UIColor colorWithRed:0.85 green:0.45 blue:0.2 alpha:1]];
    _fiSplashBtn = [self makeButton:@"FL开屏" action:@selector(fiSplash:) color:[UIColor colorWithRed:0.87 green:0.55 blue:0.3 alpha:1]];
    _fiRewardBtn = [self makeButton:@"FL激励" action:@selector(fiReward:) color:[UIColor colorWithRed:0.9 green:0.6 blue:0.35 alpha:1]];
    [row2 addArrangedSubview:_fiInitBtn];
    [row2 addArrangedSubview:_fiSplashBtn];
    [row2 addArrangedSubview:_fiRewardBtn];
    [stack addArrangedSubview:row2];

    _flameStateLabel = [self makeLabel:11 bold:NO color:[UIColor darkGrayColor]];
    [stack addArrangedSubview:_flameStateLabel];

    // ── LAST ACTION ──
    UIView *last = [[UIView alloc] init];
    last.backgroundColor = [UIColor colorWithWhite:0.95 alpha:1];
    last.layer.cornerRadius = 8;
    _lastActionLabel = [self makeLabel:12 bold:NO color:[UIColor blackColor]];
    _lastActionLabel.text = @"LAST ACTION\n（尚未执行任何广告动作）";
    _lastActionLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [last addSubview:_lastActionLabel];
    [NSLayoutConstraint activateConstraints:@[
        [_lastActionLabel.topAnchor constraintEqualToAnchor:last.topAnchor constant:8],
        [_lastActionLabel.leadingAnchor constraintEqualToAnchor:last.leadingAnchor constant:10],
        [_lastActionLabel.trailingAnchor constraintEqualToAnchor:last.trailingAnchor constant:-10],
        [_lastActionLabel.bottomAnchor constraintEqualToAnchor:last.bottomAnchor constant:-8],
    ]];
    [stack addArrangedSubview:last];

    // ── 小日志区 ──
    _logView = [[UITextView alloc] init];
    _logView.font = [UIFont monospacedSystemFontOfSize:9 weight:UIFontWeightRegular];
    _logView.backgroundColor = [UIColor blackColor];
    _logView.textColor = [UIColor colorWithWhite:0.85 alpha:1];
    _logView.editable = NO;
    _logView.layer.cornerRadius = 6;
    _logView.translatesAutoresizingMaskIntoConstraints = NO;
    [_logView.heightAnchor constraintEqualToConstant:120].active = YES;
    [stack addArrangedSubview:_logView];

    // ── 调试工具（折叠区，§5 辅助按钮降级）──
    _debugToggleBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [_debugToggleBtn setTitle:@"▼ 调试工具（配置/清空/复制/重置/Case）" forState:UIControlStateNormal];
    _debugToggleBtn.titleLabel.font = [UIFont systemFontOfSize:13];
    [_debugToggleBtn setTitleColor:[UIColor darkGrayColor] forState:UIControlStateNormal];
    [_debugToggleBtn addTarget:self action:@selector(toggleDebug:) forControlEvents:UIControlEventTouchUpInside];
    [stack addArrangedSubview:_debugToggleBtn];

    _debugStack = [[UIStackView alloc] init];
    _debugStack.axis = UILayoutConstraintAxisVertical;
    _debugStack.spacing = 8;
    _debugStack.hidden = YES;
    _configLabel = [self makeLabel:11 bold:NO color:[UIColor blackColor]];
    _resolvedLabel = [self makeLabel:11 bold:YES color:[UIColor colorWithWhite:0.25 alpha:1]];
    _fiClearBtn  = [self makeButton:@"Flame Clear" action:@selector(fiClear:) color:[UIColor grayColor]];
    _resetAllBtn = [self makeButton:@"重置测试状态" action:@selector(resetAll:) color:[UIColor grayColor]];
    _clearLogBtn = [self makeButton:@"清空日志" action:@selector(clearLog:) color:[UIColor grayColor]];
    _logCopyBtn  = [self makeButton:@"复制当前日志（已脱敏）" action:@selector(copyLog:) color:[UIColor grayColor]];
    _caseABtn = [self makeButton:@"Case A：领页先（自动序列）" action:@selector(caseA:) color:[UIColor colorWithRed:0.4 green:0.4 blue:0.75 alpha:1]];
    _caseBBtn = [self makeButton:@"Case B：Flame 先（自动序列）" action:@selector(caseB:) color:[UIColor colorWithRed:0.4 green:0.4 blue:0.75 alpha:1]];
    for (UIView *v in @[_configLabel, _resolvedLabel, _fiClearBtn, _resetAllBtn, _clearLogBtn, _logCopyBtn, _caseABtn, _caseBBtn]) {
        v.translatesAutoresizingMaskIntoConstraints = NO;
        [_debugStack addArrangedSubview:v];
    }
    [stack addArrangedSubview:_debugStack];

    [self renderAll];
}

- (void)toggleDebug:(UIButton *)s
{
    self.debugStack.hidden = !self.debugStack.hidden;
    [s setTitle:self.debugStack.hidden ? @"▼ 调试工具（配置/清空/复制/重置/Case）" : @"▲ 收起调试工具"
       forState:UIControlStateNormal];
}

#pragma mark actions（只调 Controller —— MANUAL_TEST_PATH == AUTOMATED_TEST_PATH）

- (void)liInit:(UIButton *)s { [[LingyeTestController shared] initSDK:nil]; }
- (void)liSplash:(UIButton *)s { [[LingyeTestController shared] runSplashFlow:nil]; }
- (void)liReward:(UIButton *)s { [[LingyeTestController shared] runRewardFlow:nil]; }
- (void)fiInit:(UIButton *)s { [[FlameTestController shared] initSDK:nil]; }
- (void)fiSplash:(UIButton *)s { [[FlameTestController shared] runSplashFlow:nil]; }
- (void)fiReward:(UIButton *)s { [[FlameTestController shared] runRewardFlow:nil]; }
- (void)fiClear:(UIButton *)s { [[FlameTestController shared] clearSDK]; }
- (void)resetAll:(UIButton *)s
{
    [[LingyeTestController shared] resetState];
    [[FlameTestController shared] clearSDK];
}
- (void)clearLog:(UIButton *)s { self.logView.text = @""; }
- (void)copyLog:(UIButton *)s
{
    [UIPasteboard generalPasteboard].string = self.logView.text;
    [self appendLog:[NSString stringWithFormat:@"%@ [CONSOLE] 日志已复制（已脱敏）", [self now]]];
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
    else if ([st isEqualToString:@"LA"] || [st isEqualToString:@"LR"]) [[LingyeTestController shared] runRewardFlow:done];
    else if ([st isEqualToString:@"FA"] || [st isEqualToString:@"FR"]) [[FlameTestController shared] runRewardFlow:done];
    else if ([st isEqualToString:@"LS"]) [[LingyeTestController shared] runSplashFlow:done];
    else if ([st isEqualToString:@"FS"]) [[FlameTestController shared] runSplashFlow:done];
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

- (void)appendLog:(NSString *)line
{
    if (line.length == 0) return;
    NSMutableString *t = [NSMutableString stringWithString:self.logView.text ?: @""];
    if (t.length) [t appendFormat:@"\n%@", line];
    else [t appendString:line];
    NSArray *lines = [t componentsSeparatedByString:@"\n"];
    if (lines.count > 250) {
        lines = [lines subarrayWithRange:NSMakeRange(lines.count - 200, 200)];
        t = [NSMutableString stringWithString:[lines componentsJoinedByString:@"\n"]];
    }
    self.logView.text = t;
    [self.logView scrollRangeToVisible:NSMakeRange(self.logView.text.length, 0)];
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
        case P0FAdStateClosed:   return @"PASS";
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

    self.lingyeBadge.text = [NSString stringWithFormat:@"  %@  ", [self sdkStateText:L.sdkState]];
    self.lingyeBadge.backgroundColor = [self sdkStateColor:L.sdkState];
    self.flameBadge.text = [NSString stringWithFormat:@"  %@  ", [self sdkStateText:F.sdkState]];
    self.flameBadge.backgroundColor = [self sdkStateColor:F.sdkState];

    // §18 单击自动流状态行
    self.lingyeStateLabel.text = [NSString stringWithFormat:@"开屏: %@   激励: %@   network=%@",
        [self adStateText:L.splashState], [self adStateText:L.rewardState], L.lastRewardNetwork ?: @"-"];
    self.flameStateLabel.text = [NSString stringWithFormat:@"开屏: %@   激励: %@   network=%@ tobid=%@",
        [self adStateText:F.splashState], [self adStateText:F.rewardState],
        F.lastRewardNetwork ?: @"N/A", F.lastTobidPlacement ?: @"N/A"];

    // 主按钮（§2 六按钮）
    self.liInitBtn.enabled = (L.sdkState != P0FSDKStateInitializing);
    self.liSplashBtn.enabled = L.sdkState == P0FSDKStateReady && L.splashState != P0FAdStateLoading && L.splashState != P0FAdStateShowing;
    self.liRewardBtn.enabled = L.sdkState == P0FSDKStateReady && L.rewardState != P0FAdStateLoading && L.rewardState != P0FAdStateShowing;
    self.fiInitBtn.enabled = (F.sdkState != P0FSDKStateInitializing);
    self.fiSplashBtn.enabled = F.sdkState == P0FSDKStateReady && F.splashState != P0FAdStateLoading && F.splashState != P0FAdStateShowing;
    self.fiRewardBtn.enabled = F.sdkState == P0FSDKStateReady && F.rewardState != P0FAdStateLoading && F.rewardState != P0FAdStateShowing;
    self.caseABtn.enabled = !self.caseRunning;
    self.caseBBtn.enabled = !self.caseRunning;
    for (UIButton *b in @[self.liInitBtn, self.liSplashBtn, self.liRewardBtn,
                          self.fiInitBtn, self.fiSplashBtn, self.fiRewardBtn,
                          self.caseABtn, self.caseBBtn]) {
        b.alpha = b.enabled ? 1.0 : 0.35;
    }

    // 折叠区：配置详情（AppKey 永不展示 §17）
    self.configLabel.text = [NSString stringWithFormat:
        @"Lingye SDK: CJMobileAd 2.4.32 | Flame: flame_sdk_ios_tb_lingye (%@)\n"
         "Flame AppID: %@ | Reward: %@ | Splash: %@\n"
         "App Key: ••••••（已配置，不展示） | %@ / iOS %@",
        [self flameVersion],
        cfg.flameAppId.length ? cfg.flameAppId : @"（未配置）",
        cfg.flameRewardPlacement.length ? cfg.flameRewardPlacement : @"（未配置）",
        cfg.flameSplashPlacement.length ? cfg.flameSplashPlacement : @"（未配置）",
        [UIDevice currentDevice].model, [UIDevice currentDevice].systemVersion];
    self.resolvedLabel.text = [NSString stringWithFormat:
        @"Resolved ToBid AppID: %@ | ToBid Placement: %@ | NetworkPlacement: %@ | transId: %@",
        [P0FLogTap shared].resolvedTobidAppId ?: @"N/A",
        F.lastTobidPlacement ?: @"N/A", F.lastNetworkPlacement ?: @"N/A", F.lastTransId ?: @"N/A"];

    [self renderCard];
}

- (NSString *)flameVersion
{
    @try { return [[FlameSdk sharedInstance] getVersion] ?: @""; }
    @catch (NSException *e) { return @""; }
}

#pragma mark LAST ACTION card（§16/§19）

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
        self.cardCode = nil;
        self.cardLoad = @"-";
        self.cardShow = @"-";
        self.cardReward = @"-";
        self.cardClose = @"-";
        self.cardTime = [self now];
    }
    if ([e.action isEqualToString:@"INIT"]) {
        self.cardResult = e.ok ? @"PASS" : @"FAIL";
    } else if ([e.action isEqualToString:@"LOAD"]) {
        if (e.ok && [e.message isEqualToString:@"READY"]) {
            self.cardLoad = @"PASS";
            self.cardNetwork = e.network ?: self.cardNetwork;
            self.cardPlacement = e.thirdPlacement ?: self.cardPlacement;
        } else if (!e.ok && ![e.message isEqualToString:@"START"]) {
            self.cardLoad = [NSString stringWithFormat:@"FAIL(%@)", e.code ?: @"?"];
            self.cardResult = @"FAIL";
        }
    } else if ([e.action isEqualToString:@"SHOW"]) {
        if ([e.message isEqualToString:@"BEGIN"]) { self.cardShow = @"ING"; }
        else if (e.ok) { self.cardShow = @"PASS"; self.cardNetwork = e.network ?: self.cardNetwork; self.cardPlacement = e.thirdPlacement ?: self.cardPlacement; }
    } else if ([e.action isEqualToString:@"REWARD"]) {
        self.cardReward = @"PASS";
        self.cardTransId = e.transId ?: e.requestId ?: self.cardTransId;
    } else if ([e.action isEqualToString:@"CLOSE"]) {
        self.cardClose = @"PASS";
        BOOL rewardOK = [self.cardReward isEqualToString:@"PASS"] || [self.cardType isEqualToString:P0FKindSplash];
        if (![self.cardResult isEqualToString:@"FAIL"] && rewardOK
            && [self.cardLoad isEqualToString:@"PASS"] && [self.cardShow isEqualToString:@"PASS"]) {
            self.cardResult = @"PASS";
        }
    } else if ([e.action isEqualToString:@"ERROR"] || [e.action isEqualToString:@"TIMEOUT"]) {
        self.cardResult = @"FAIL";
        if ([e.action isEqualToString:@"TIMEOUT"]) self.cardLoad = @"TIMEOUT";
        self.cardCode = e.code;
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
    [s appendFormat:@"LAST ACTION\nOWNER: %@   TYPE: %@   RESULT: %@\n", self.cardOwner, self.cardType, self.cardResult];
    [s appendFormat:@"MEDIATION: %@\n", mediation];
    [s appendFormat:@"NETWORK: %@\n", self.cardNetwork ?: @"N/A"];
    [s appendFormat:@"PLACEMENT: %@\n", self.cardPlacement ?: @"N/A"];
    [s appendFormat:@"LOAD: %@  SHOW: %@  REWARD: %@  CLOSE: %@\n", self.cardLoad, self.cardShow, self.cardReward, self.cardClose];
    if (self.cardCode.length)     [s appendFormat:@"ERROR: code=%@\n", self.cardCode];
    if (self.cardTransId)         [s appendFormat:@"TRANS_ID: %@\n", self.cardTransId];
    if (self.cardRequestId.length && ![self.cardRequestId isEqualToString:@"-"]) [s appendFormat:@"REQUEST_ID: %@\n", self.cardRequestId];
    [s appendFormat:@"TIME: %@", self.cardTime];
    self.lastActionLabel.text = s;
}

@end
