//
//  InterstitialVC.m
//  CJModileAdDemo
//
//  Created by CJ on 2022/3/7.
//

#import "InterstitialVC.h"
#import <CJMobileAd/CJMobileAd.h>
#import "CustomShowView.h"
#import "CJMobilePublic.h"

@interface InterstitialVC ()<CJInterstitialAdDelegate>

@property (nonatomic, strong) CJInterstitialAd *interstitialAd;

@end

@implementation InterstitialVC

@synthesize customView = _customView;

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setupUI];
}

- (void)dealloc
{
    NSLog(@"the page of interstitial delloc");
}

- (void)loadAdData {
    [self.customView canShowStatus:false errorMsg:@""];
    self.interstitialAd = [[CJInterstitialAd alloc] initWithResourceId:intersititialId];
    self.interstitialAd.delegate = self;
    [self.interstitialAd loadAdData];
}

- (void)setupUI {
    self.title = @"InterstitialAd";
    [self.view addSubview:self.customView];
    self.customView.frame = CGRectMake(0, 100, 200, 200);
    self.customView.center = self.view.center;
}

- (void)handleEvent:(NSInteger)eve {
    if (eve == 0) {
        [self loadAdData];
        return;
    }
    [self.interstitialAd showFromRootViewController:self];
}

- (CustomShowView *)customView {
    if (!_customView) {
        _customView = [[CustomShowView alloc] init];
        __weak InterstitialVC *weakSelf = self;
        _customView.event = ^(NSInteger eve) {
            [weakSelf handleEvent:eve];
        };
    }
    return _customView;
}

#pragma mark CJInterstitialAdDelegate
- (void)interstitialAdDidLoad:(CJInterstitialAd *)interstitialAd resourceId:(NSString *)resourceId {
    NSLog(@"load success");
    [self.customView canShowStatus:true errorMsg:@""];
}

- (void)interstitialAdLoadFailed:(CJInterstitialAd *)interstitialAd error:(NSError *)error {
    NSLog(@"load failed of error: %@", error);
    [self.customView canShowStatus:false errorMsg:error.description];
}

- (void)interstitialAdOnClicked:(CJInterstitialAd *)interstitialAd {
    NSLog(@"click on the event");
}

- (void)interstitialAdOnClosed:(CJInterstitialAd *)interstitialAd {
    NSLog(@"close on the event");
    [self.customView canShowStatus:false errorMsg:@""];
}

@end
