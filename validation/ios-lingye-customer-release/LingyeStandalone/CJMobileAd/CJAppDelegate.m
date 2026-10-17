//
//  CJAppDelegate.m
//  CJMobileAd
//
//  Created by wade.xiong on 04/15/2022.
//  Copyright (c) 2022 wade.xiong. All rights reserved.
//
//  P0D Runtime Baseline A（TEST_ONLY 验证驱动）：
//  官方测试媒体 ID 初始化后自动执行 激励 load→show→reward/close 链，
//  全部以 [P0D-A] 前缀 NSLog 输出供 logstream 判定。UI 入口保留。
//

#import "CJAppDelegate.h"
#import <CJMobileAd/CJMobileAd.h>
#import "CJEntranceController.h"
#import "CJMobilePublic.h"

@interface CJAppDelegate () <CJRewardVideoAdDelegate>
@property (nonatomic, strong) CJRewardVideoAd *p0dRewardAd;
@end

@implementation CJAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    CJEntranceController *vc = [[CJEntranceController alloc] init];
    self.window.rootViewController = [[UINavigationController alloc] initWithRootViewController:vc];
    [self.window makeKeyAndVisible];

    NSLog(@"[P0D-A] LAUNCH");
    [CJADManager openDebugLog];
    NSLog(@"[P0D-A] LI_BEGIN");
    [CJADManager configure:appID completeHandle:^(BOOL success, NSError * _Nullable error) {
        NSLog(@"[P0D-A] LI_RESULT=%d err=%@", success ? 1 : 0, error.localizedDescription ?: @"-");
        if (success) {
            [self p0dLoadLingyeReward];
        } else {
            NSLog(@"[P0D-A] SEQ_RESULT BASELINE_A FAIL(init)");
        }
    }];

    return YES;
}

#pragma mark - P0D lingye reward chain

- (void)p0dLoadLingyeReward
{
    NSLog(@"[P0D-A] LA_LOAD_BEGIN");
    self.p0dRewardAd = [[CJRewardVideoAd alloc] initWithResourceId:rewardVideoId userId:@"p0d" extend:@""];
    self.p0dRewardAd.delegate = self;
    [self.p0dRewardAd loadAdData];
}

- (void)rewardVideoAdDidLoad:(CJRewardVideoAd *)rewardAd resourceId:(NSString *)resourceId
{
    NSLog(@"[P0D-A] LA_LOAD_OK channel=%@", [rewardAd getAdType] ?: @"-");
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSLog(@"[P0D-A] LA_SHOW_BEGIN");
        [rewardAd showFromRootViewController:self.window.rootViewController];
    });
}

- (void)rewardVideoAdLoadFailed:(CJRewardVideoAd *)rewardAd error:(NSError *)error
{
    NSLog(@"[P0D-A] LA_LOAD_FAIL err=%@", error);
    NSLog(@"[P0D-A] SEQ_RESULT BASELINE_A FAIL(load)");
}

- (void)rewardVideoOnRewarded:(CJRewardVideoAd *)rewardAd requestId:(NSString *)requestId
{
    NSLog(@"[P0D-A] LA_REWARDED req=%@", requestId ?: @"-");
}

- (void)rewardVideoAdOnClosed:(CJRewardVideoAd *)rewardAd
{
    NSLog(@"[P0D-A] LA_CLOSED");
    NSLog(@"[P0D-A] SEQ_RESULT BASELINE_A PASS(load-show-reward/close)");
}

@end
