//
//  FeedNativeAdController.m
//  CJMobileAd_Example
//
//  Created by shanghailingye on 2024/4/11.
//  Copyright © 2024 wade.xiong. All rights reserved.
//

#import "FeedNativeAdController.h"
#import <CJMobileAd/CJMobileAd.h>
#import "CJMobilePublic.h"
#import "CustomFeedView.h"

@interface FeedNativeAdController ()<CJNativeFeedAdDelegate>

@property (nonatomic, strong) CJFeedNativeAd *feedNativeAd;
@property (nonatomic, strong) UIView *feedNativeView;

@end
@implementation FeedNativeAdController

@synthesize customView = _customView;

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setupUI];
}

- (void)handleEvent:(NSInteger)eve {
    if (eve == 0) {
        [self loadFeedNativeAdData];
        return;
    }
    CGRect frame = self.feedNativeView.frame;
    frame.origin.y = 88;
    self.self.feedNativeView.frame = frame;
    [self.view addSubview:self.feedNativeView];
}
- (void)setupUI {
    self.title = @"自渲染";
    [self.view addSubview:self.customView];
    self.customView.frame = CGRectMake(0, 100, 200, 200);
    self.customView.center = self.view.center;
}

- (void)loadFeedNativeAdData {
    self.feedNativeAd = [[CJFeedNativeAd alloc] initWithSlotId:feedNativeId extend:@""];
    self.feedNativeAd.delegate = self;
    [self.feedNativeAd loadFeedAdData];
}

- (CustomShowView *)customView {
    if (!_customView) {
        _customView = [[CustomShowView alloc] init];
        __weak FeedNativeAdController *weakSelf = self;
        _customView.event = ^(NSInteger eve) {
            [weakSelf handleEvent:eve];
        };
    }
    return _customView;
}

#pragma mark CJNativeFeedAdDelegate
- (void)feedNativeMaterialsOnDidLoad:(NSArray<CJFeedAdMaterial *> *)feedAdMaterials {
    NSLog(@"事件:%s", __FUNCTION__);
    if (feedAdMaterials.count > 0 ) {
        // 构造自渲染view
        CustomFeedView *contentView = [[CustomFeedView alloc] initWithMaterial:feedAdMaterials.firstObject];
        // 去绑定第三方内容
        [self.feedNativeAd bindFeedNativeContentView:contentView config:contentView.config currentVC:self];
    }
}

- (void)feedNativeMaterialsOnRenderSuccess:(UIView *)feedNativeView {
    NSLog(@"事件:%s", __FUNCTION__);
    [self.customView canShowStatus:true errorMsg:@""];
    // 渲染成功
    self.feedNativeView = feedNativeView;
}

- (void)feedNativeMaterialsOnShow:(UIView *)feedNativeView {
    NSLog(@"事件:%s", __FUNCTION__);
}

- (void)feedNativeMaterialsOnLoadFailed:(CJFeedNativeAd *)feedAd error:(NSError *)error {
    NSLog(@"事件:%s", __FUNCTION__);
}

- (void)feedNativeMaterialsOnRenderFailed:(CJFeedNativeAd *)feedAd error:(NSError *)error {
    NSLog(@"事件:%s", __FUNCTION__);
}

- (void)feedNativeMaterialsOnClick:(UIView *)feedNativeView {
    NSLog(@"事件:%s", __FUNCTION__);
}

- (void)dealloc
{
    NSLog(@"自渲染页面已经销毁");
}

@end
