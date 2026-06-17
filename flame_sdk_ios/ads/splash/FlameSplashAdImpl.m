//
//  FlameSplashAdImpl.m
//  flame_sdk_ios
//
//  Created by Flame on 2026/1/20.
//

#import <Foundation/Foundation.h>
#import "FlameSplashAdImpl.h"
#import "FlameAdapterManager.h"
#import "FlameLogger.h"


@implementation FlameSplashAdImpl

@synthesize viewController = _viewController;
@synthesize placementId = _placementId;
@synthesize listener = _listener;
@synthesize adapter = _adapter;

- (instancetype)initWithViewController:(UIViewController *)viewController
                           placementId:(NSString *)placementId
                              listener:(id<FlameSplashListener>)listener
                              adapter:(id<FlameSplashAdapterProtocol>)adapter{
    self = [super init];
    if (self) {
        _viewController = viewController;
        _placementId = [placementId copy];
        _listener = listener;
        _adapter = adapter;
    }
    return self;
}

- (void)load {
    [self loadWithUserId:nil userCustomData:nil];
}

- (void)loadWithUserId:(NSString *)userId userCustomData:(NSString *)userCustomData {
    if (![FlameAdapterManager checkInitialization]) return;

    if ([self.adapter isLoading]) {
        [FlameLogger i:@"Ad is loading, please do not request again."];
        return;
    }
    
    [FlameLogger i:@"Start loading Splash Ad"];

    [self.adapter loadWithUserId:userId userCustomData:userCustomData];
}

- (BOOL)isReady {
    if (![FlameAdapterManager checkInitialization]) return NO;
    return [self.adapter isReady];
}

- (BOOL) isLoading{
    if (![FlameAdapterManager checkInitialization]) return NO;
    return [self.adapter isLoading];
}

- (void) destroy{
    if (![FlameAdapterManager checkInitialization]) return;
    [self.adapter destroy];
}

- (void)show:(UIWindow *)window {
    if ([self isReady]) {
        [self.adapter show:window];
    } else {
        [FlameLogger i:@"Splash Ad is not ready to show"];
    }
}

@end
