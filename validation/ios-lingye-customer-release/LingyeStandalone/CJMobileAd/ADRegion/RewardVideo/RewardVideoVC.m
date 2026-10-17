//
//  RewardVideoVC.m
//  CJModileAdDemo
//
//  Created by JUN on 2022/3/6.
//

#import "RewardVideoVC.h"
#import "CustomShowView.h"
#import <CJMobileAd/CJMobileAd.h>
#import "CJMobilePublic.h"

@interface RewardVideoVC ()<CJRewardVideoAdDelegate>

@property (nonatomic, strong) CJRewardVideoAd *rewardVideoAd;

@end

@implementation RewardVideoVC

@synthesize customView = _customView;

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setupUI];
}

- (void)dealloc
{
    NSLog(@"the page of rewardVideo delloc");
}

- (void)loadAdData {
    [self.customView canShowStatus:false errorMsg:@""];
    self.rewardVideoAd = [[CJRewardVideoAd alloc] initWithResourceId:rewardVideoId userId:@"123" extend:@""];
    self.rewardVideoAd.delegate = self;
    [self.rewardVideoAd loadAdData];
}

- (void)setupUI {
    self.title = @"RewardVideoAd";
    [self.view addSubview:self.customView];
    self.customView.frame = CGRectMake(0, 100, 200, 200);
    self.customView.center = self.view.center;
}

- (void)handleEvent:(NSInteger)eve {
    if (eve == 0) {
        [self loadAdData];
        return;
    }
    [self.rewardVideoAd showFromRootViewController:self];
}

- (CustomShowView *)customView {
    if (!_customView) {
        _customView = [[CustomShowView alloc] init];
        __weak RewardVideoVC *weakSelf = self;
        _customView.event = ^(NSInteger eve) {
            [weakSelf handleEvent:eve];
        };
    }
    return _customView;
}

#pragma mark CJRewardVideoAdDelegate
- (void)rewardVideoOnRewarded:(CJRewardVideoAd *)rewardAd requestId:(NSString *)requestId {
    if (requestId && ![requestId isEqualToString:@""]) {
        NSLog(@"the incentive validation callback succeeded");
    }
}

- (void)rewardVideoAdDidLoad:(CJRewardVideoAd *)rewardAd resourceId:(NSString *)resourceId {
    NSLog(@"load success");
    NSString *channel = [rewardAd getAdType];
    NSLog(@"channel====%@", channel);
    [self.customView canShowStatus:true errorMsg:@""];
//    [rewardAd showFromRootViewController:self];
}

- (void)rewardVideoAdLoadFailed:(CJRewardVideoAd *)rewardAd error:(NSError *)error {
    NSLog(@"load failed of error: %@", error);
    [self.customView canShowStatus:false errorMsg:error.description];
}

- (void)rewardVideoAdOnClicked:(CJRewardVideoAd *)rewardAd {
    NSLog(@"click on the event");
}

- (void)rewardVideoAdOnClosed:(CJRewardVideoAd *)rewardAd {
    NSLog(@"close on the event");
    [self.customView canShowStatus:false errorMsg:@""];
    
}


@end
