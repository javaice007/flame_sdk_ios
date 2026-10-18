//
//  P0FTestCore.h — P0F 人工验收 Demo 统一控制层（TEST_ONLY）
//
//  MANUAL_TEST_PATH == AUTOMATED_TEST_PATH：
//  人工 Console 与自动 runner（P0D_SEQ / --auto-sequence）都只经由
//  LingyeTestController / FlameTestController 调用 SDK，禁止两套 wrapper。
//
//  归因字段（network / tobid placement / network placement）全部来自本轮 runtime，
//  来源：P0FLogTap 捕获的 ToBid [onReport] 日志 + SDK 回调参数；
//  拿不到的字段显示 N/A，禁止伪造（§6/§21）。
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// 当前测试动作标签（探针归因用，TEST_ONLY）：emitOwner 漏斗自动更新，形如 FLAME_INIT_LOAD / LINGYE_REWARD_SHOW
extern NSString * volatile P0FCurrentAction;

extern NSString * const P0FOwnerLingye;   // @"LINGYE"
extern NSString * const P0FOwnerFlame;    // @"FLAME"
extern NSString * const P0FKindInit;      // @"INIT"
extern NSString * const P0FKindSplash;    // @"SPLASH"
extern NSString * const P0FKindReward;    // @"REWARD"

typedef NS_ENUM(NSInteger, P0FSDKState) {
    P0FSDKStateNotInitialized,
    P0FSDKStateInitializing,
    P0FSDKStateReady,
    P0FSDKStateError,
};

typedef NS_ENUM(NSInteger, P0FAdState) {
    P0FAdStateIdle,
    P0FAdStateLoading,
    P0FAdStateReady,
    P0FAdStateShowing,
    P0FAdStateRewarded,
    P0FAdStateClosed,
    P0FAdStateError,
    P0FAdStateTimeout,
};

#pragma mark - Event

@interface P0FAdEvent : NSObject
@property (nonatomic, copy) NSString *owner;           // LINGYE / FLAME
@property (nonatomic, copy) NSString *kind;            // INIT / SPLASH / REWARD
@property (nonatomic, copy) NSString *action;          // START / LOAD / SHOW / REWARD / CLOSE / TIMEOUT / RESET / CLEAR / ERROR
@property (nonatomic, assign) BOOL ok;
@property (nonatomic, copy, nullable) NSString *network;
@property (nonatomic, copy, nullable) NSString *flamePlacement;
@property (nonatomic, copy, nullable) NSString *thirdPlacement;
@property (nonatomic, copy, nullable) NSString *transId;
@property (nonatomic, copy, nullable) NSString *requestId;
@property (nonatomic, copy, nullable) NSString *code;
@property (nonatomic, copy, nullable) NSString *message;
@property (nonatomic, assign) NSInteger attempt;
/// 单行日志（已含时间前缀），可直接进日志面板 / NSLog
@property (nonatomic, copy, readonly) NSString *line;
@end

@protocol P0FTestListener <NSObject>
- (void)p0fEvent:(P0FAdEvent *)event;
@end

#pragma mark - Runtime log tap

/// 捕获本进程 stdout/stderr（旁路 dup2+pipe，原样回写，不改变行为），
/// 解析 ToBid [onReport] 与 P0D 探针行，供页面展示真实 runtime identity。
@interface P0FLogTap : NSObject
+ (instancetype)shared;
- (void)start;
/// 最近一次 AdDidShow 报告（JSON 字段 + _ts），可能为 nil
@property (nonatomic, copy, readonly, nullable) NSDictionary *lastAdShowReport;
/// 最近一次 AdDidReady 报告（JSON 字段 + _ts），可能为 nil
@property (nonatomic, copy, readonly, nullable) NSDictionary *lastAdReadyReport;
/// P0D 探针捕获的 WindMill setupSDKWithAppId 实参（Resolved ToBid App ID），可能为 nil
@property (nonatomic, copy, readonly, nullable) NSString *resolvedTobidAppId;
+ (nullable NSString *)networkNameForId:(NSInteger)networkId;
@end

#pragma mark - Config

@interface P0FAdConfig : NSObject
@property (nonatomic, copy) NSString *flameAppId;             // 可为空（未配置）
@property (nonatomic, copy) NSString *flameAppKey;            // 永不进 UI / 日志
@property (nonatomic, copy) NSString *flameRewardPlacement;
@property (nonatomic, copy) NSString *flameSplashPlacement;   // 空字符串=未配置
@property (nonatomic, copy) NSString *lingyeAppId;
@property (nonatomic, copy) NSString *lingyeRewardId;
@property (nonatomic, copy) NSString *lingyeSplashId;         // 空字符串=未配置
+ (instancetype)current;   // env(P0D_F*) 优先，其次 P0FSecretConfig.h（__has_include）
@end

#pragma mark - Controllers（人工/自动共用）

typedef void (^P0FAdDone)(BOOL ok, NSString * _Nullable code, NSString * _Nullable msg);

/// 统一事件出口（TEST_ONLY 基类）：线程收口 + NSLog + listener 派发
@interface P0FBaseController : NSObject
@property (nonatomic, weak, nullable) id<P0FTestListener> listener;
- (P0FAdEvent *)emitOwner:(NSString *)owner kind:(NSString *)kind action:(NSString *)action ok:(BOOL)ok
                  network:(NSString *)network flamePlacement:(NSString *)fp thirdPlacement:(NSString *)tp
                  transId:(NSString *)tid requestId:(NSString *)rid code:(NSString *)code
                  message:(NSString *)msg attempt:(NSInteger)attempt;
- (void)armWatchdog:(NSTimeInterval)sec gen:(NSInteger)gen fire:(dispatch_block_t)fire;
@end

@interface LingyeTestController : P0FBaseController
+ (instancetype)shared;
@property (nonatomic, weak, nullable) id<P0FTestListener> listener;
@property (nonatomic, strong, readonly) P0FAdConfig *config;
@property (nonatomic, assign, readonly) P0FSDKState sdkState;
@property (nonatomic, assign, readonly) P0FAdState rewardState;
@property (nonatomic, assign, readonly) P0FAdState splashState;
@property (nonatomic, assign, readonly) NSInteger rewardAttempt;
@property (nonatomic, copy, readonly, nullable) NSString *lastRewardNetwork;    // getAdType
@property (nonatomic, copy, readonly, nullable) NSString *lastRewardRequestId;
- (void)setRootViewController:(nullable UIViewController *)rootVC window:(nullable UIWindow *)window;
- (void)initSDK:(nullable P0FAdDone)done;
- (void)loadReward:(nullable P0FAdDone)done;
- (void)showReward:(nullable P0FAdDone)done;
- (void)runRewardFlow:(nullable P0FAdDone)done;   // load → 1s → show → closed（= 自动 runner 历史路径）
- (void)loadSplash:(nullable P0FAdDone)done;
- (void)showSplash:(nullable P0FAdDone)done;
- (void)runSplashFlow:(nullable P0FAdDone)done;   // load → ready → show → close（P0F-V2 单击自动流）
- (void)resetState;
@end

@interface FlameTestController : P0FBaseController
+ (instancetype)shared;
@property (nonatomic, weak, nullable) id<P0FTestListener> listener;
@property (nonatomic, strong, readonly) P0FAdConfig *config;
@property (nonatomic, assign, readonly) P0FSDKState sdkState;
@property (nonatomic, assign, readonly) P0FAdState rewardState;
@property (nonatomic, assign, readonly) P0FAdState splashState;
@property (nonatomic, assign, readonly) NSInteger rewardAttempt;   // no-fill 重试计数，成功后归零
@property (nonatomic, copy, readonly) NSString *mediation;         // 恒 @"TOBID"（本变体）
@property (nonatomic, copy, readonly, nullable) NSString *lastRewardNetwork;         // runtime（LogTap）
@property (nonatomic, copy, readonly, nullable) NSString *lastTobidPlacement;        // runtime
@property (nonatomic, copy, readonly, nullable) NSString *lastNetworkPlacement;      // runtime
@property (nonatomic, copy, readonly, nullable) NSString *lastTransId;               // runtime（回调实参）
- (void)setRootViewController:(nullable UIViewController *)rootVC window:(nullable UIWindow *)window;
- (void)initSDK:(nullable P0FAdDone)done;
- (void)clearSDK;
- (void)loadReward:(nullable P0FAdDone)done;
- (void)showReward:(nullable P0FAdDone)done;
- (void)runRewardFlow:(nullable P0FAdDone)done;
- (void)loadSplash:(nullable P0FAdDone)done;
- (void)showSplash:(nullable P0FAdDone)done;
- (void)runSplashFlow:(nullable P0FAdDone)done;   // load → ready → show → close（P0F-V2 单击自动流）
- (void)resetState;
@end

NS_ASSUME_NONNULL_END
