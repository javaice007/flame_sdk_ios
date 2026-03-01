//
//  FlameRewardAd.m
//
//  Created by flame.
//  Copyright © 2026 Flame. All rights reserved.
//
#import <Foundation/Foundation.h>
#import "FlameRewardAdImpl.h"
#import "FlameAdapterManager.h"
#import "FlameLogger.h"


@implementation FlameRewardAdImpl

@synthesize viewController = _viewController;
@synthesize placementId = _placementId;
@synthesize listener = _listener;
@synthesize adapter = _adapter;

- (instancetype)initWithViewController:(UIViewController *)viewController
                           placementId:(NSString *)placementId
                              listener:(id<FlameRewardListener>)listener{
    self = [super init];
    if (self) {
        _viewController = viewController;
        _placementId = [placementId copy];
        _listener = listener;
        _adapter = [FlameAdapterManager createRewardAdapter:viewController atPlacementId:placementId listener:listener];
    }
    return self;
}

- (void)load {
    [self loadWithUserId:nil userCustomData:nil];
}

- (void)loadWithUserId:(NSString *)userId userCustomData:(NSString *)userCustomData {
    [FlameAdapterManager checkInitialization];

    if ([self.adapter isLoading]) {
        [FlameLogger i:@"Ad is loading, please do not request again."];
        return;
    }
    
    NSString *logMsg = [NSString stringWithFormat:@"Start loading Reward Ad for PlacementId: %@", self.placementId];
    [FlameLogger i:logMsg];

    [self.adapter loadWithUserId:userId userCustomData:userCustomData];
}

- (BOOL)isReady {
    [FlameAdapterManager checkInitialization];
    return [self.adapter isReady];
}

- (BOOL) isLoading{
    [FlameAdapterManager checkInitialization];
    return [self.adapter isLoading];
}

- (void) destroy{
    [FlameAdapterManager checkInitialization];
    [self.adapter destroy];
}

- (void)show {
    if ([self isReady]) {
        [self.adapter show];
    } else {
        NSString *logMsg = [NSString stringWithFormat:@"Reward Ad is not ready to show for PlacementId: %@", self.placementId];
        [FlameLogger i:logMsg];
    }
}

@end
