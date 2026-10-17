//
//  IConController.m
//  CJMobileAd_Example
//
//  Created by shanghailingye on 2026/4/28.
//  Copyright © 2026 wade.xiong. All rights reserved.
//

#import "IConController.h"
#import <CJMobileAd/CJMobileAd.h>
#import "CJMobilePublic.h"
#import "CustomShowView.h"

@interface IConController()<CJServiceAdDelegate>

@property (nonatomic, strong) CJServiceAd *serviceAd;
@property (nonatomic, strong) UIView *iconContentView;

@end

@implementation IConController

@synthesize customView = _customView;

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setupUI];
    NSLog(@"------%@", [UIApplication sharedApplication].keyWindow.rootViewController);
}

- (void)dealloc
{
//    animationParameters
    NSLog(@"事件:%s", __FUNCTION__);
}

- (void)loadAdData {
    [self.customView canShowStatus:false errorMsg:@""];
    self.serviceAd = [[CJServiceAd alloc] initWithSlotId:iconId size:CGSizeMake(46, 46) refreshTime:20 rootViewController:self];
    self.serviceAd.isShowClose = true;
    self.serviceAd.delegate = self;
    [self.serviceAd loadAdData];
}

- (void)setupUI {
    self.title = @"SplashAd";
    [self.view addSubview:self.customView];
    self.customView.frame = CGRectMake(0, 100, 200, 200);
    self.customView.center = self.view.center;
}

- (void)handleEvent:(NSInteger)eve {
    if (eve == 0) {
        NSLog(@"事件:%s", __FUNCTION__);
        [self loadAdData];
        return;
    }
}

- (CustomShowView *)customView {
    if (!_customView) {
        _customView = [[CustomShowView alloc] init];
        __weak IConController *weakSelf = self;
        _customView.event = ^(NSInteger eve) {
            [weakSelf handleEvent:eve];
        };
    }
    return _customView;
}

#pragma mark CJSplashAdDelegate
- (void)iconExpressAdDidLoad:(id)serviceAd views:(UIView *)serviceView {
    NSLog(@"事件:%s", __FUNCTION__);
    serviceView.backgroundColor = jRGBA(255, 255, 255, 0);
    self.iconContentView = serviceView;
    [self.view addSubview:serviceView];
    serviceView.center = self.view.center;
}

- (void)iconExpressAdOnShow:(id)serviceView {
    NSLog(@"事件:%s", __FUNCTION__);
}

- (void)iconExpressAdLoadFailed:(id)serviceAd error:(NSError *)error {
    NSLog(@"事件:%s", __FUNCTION__);
    [self.customView canShowStatus:false errorMsg:error.description];
}

- (void)iconExpressAdOnClicked:(id)serviceAd {
    NSLog(@"事件:%s", __FUNCTION__);
}

- (void)iconExpressAdOnClosed:(id)serviceAd {
    NSLog(@"事件:%s", __FUNCTION__);
    [self.iconContentView removeFromSuperview];
    self.iconContentView = nil;
}


@end



