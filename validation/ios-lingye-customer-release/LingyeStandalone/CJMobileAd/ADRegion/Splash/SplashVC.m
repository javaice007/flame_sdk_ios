//
//  SplashVC.m
//  CJModileAdDemo
//
//  Created by CJ on 2022/3/7.
//

#import "SplashVC.h"
#import <CJMobileAd/CJMobileAd.h>
#import "CustomShowView.h"
#import "CJMobilePublic.h"

@interface SplashVC ()<CJSplashAdDelegate>

@property (nonatomic, strong) CJSplashAd *splashAd;

@end

@implementation SplashVC

@synthesize customView = _customView;

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setupUI];
}

- (void)dealloc
{
    NSLog(@"the page of splash delloc");
}

- (void)loadAdData {
    [self.customView canShowStatus:false errorMsg:@""];
    self.splashAd = [[CJSplashAd alloc] initWithResourceId:splashId rootViewController:self customLogoView:[UIView new]];
    self.splashAd.delegate = self;
    [self.splashAd loadAdData];
}

- (void)setupUI {
    self.title = @"SplashAd";
    [self.view addSubview:self.customView];
    self.customView.frame = CGRectMake(0, 100, 200, 200);
    self.customView.center = self.view.center;
}

- (void)handleEvent:(NSInteger)eve {
    if (eve == 0) {
        [self loadAdData];
        return;
    }
    [self.splashAd showSplashAdToWindow:[UIApplication sharedApplication].keyWindow];
}

- (CustomShowView *)customView {
    if (!_customView) {
        _customView = [[CustomShowView alloc] init];
        __weak SplashVC *weakSelf = self;
        _customView.event = ^(NSInteger eve) {
            [weakSelf handleEvent:eve];
        };
    }
    return _customView;
}

#pragma mark CJSplashAdDelegate
- (void)splashAdDidLoad:(CJSplashAd *)splashAd resourceId:(NSString *)resourceId {
    NSLog(@"load success");
    [self.customView canShowStatus:true errorMsg:@""];
}

- (void)splashAdLoadFailed:(CJSplashAd *)splashAd error:(NSError *)error {
    NSLog(@"load failed of error: %@",error);
    [self.customView canShowStatus:false errorMsg:error.description];
}

- (void)splashAdOnClicked:(CJSplashAd *)splashAd {
    NSLog(@"click on the event");
}

- (void)splashAdOnClosed:(CJSplashAd *)splashAd {
    NSLog(@"close on the event");
    [self.customView canShowStatus:false errorMsg:@""];
}

@end
