//
//  FlameBannerAdImpl.m
//  flame_sdk_ios
//
//  Created by Flame on 2026/1/21.
//

#import <Foundation/Foundation.h>
#import "FlameBannerAdImpl.h"
#import "FlameBannerAdRenderSlots.h"
#import "FlameAdapterManager.h"
#import "FlameLogger.h"

@interface FlameBannerAdImpl ()

@property (nonatomic, assign, readwrite) FlameBannerRenderType renderType;

@end

@implementation FlameBannerAdImpl

@synthesize placementId = _placementId;
@synthesize listener = _listener;
@synthesize adapter = _adapter;

- (instancetype)initWithPlacementId:(NSString *)placementId
                         renderType:(FlameBannerRenderType)renderType
                           listener:(id<FlameBannerListener>)listener
                           adapter:(id<FlameBannerAdapterProtocol>)adapter {
    self = [super init];
    if (self) {
        _placementId = [placementId copy];
        _listener = listener;
        _renderType = renderType;
        _adapter = adapter;
    }
    return self;
}

- (void)loadWithWidth:(CGFloat)width
               height:(CGFloat)height
       viewController:(UIViewController *)viewController {
    [self loadWithUserId:nil
          userCustomData:nil
                   width:width
                  height:height
          viewController:viewController];
}

- (void)loadWithUserId:(NSString *)userId
        userCustomData:(NSString *)userCustomData
                 width:(CGFloat)width
                height:(CGFloat)height
        viewController:(UIViewController *)viewController {
    if (![FlameAdapterManager checkInitialization]) return;

    if ([self.adapter isLoading]) {
        [FlameLogger i:@"Ad is loading, please do not request again."];
        return;
    }

    [FlameLogger i:@"Start loading banner Ad"];
    [self.adapter loadWithUserId:userId
                  userCustomData:userCustomData
                           width:width
                          height:height
                  viewController:viewController];
}

- (BOOL)isLoading {
    if (![FlameAdapterManager checkInitialization]) return NO;
    return [self.adapter isLoading];
}

- (BOOL)isReady {
    if (![FlameAdapterManager checkInitialization]) return NO;
    return [self.adapter isReady];
}

- (UIView *)retrieveAdView {
    if ([self isReady]) {
        [FlameLogger i:@"Show Banner Ad"];
        UIView *adView = [self.adapter retrieveAdView];
        if (adView) {
            return adView;
        }
        [FlameLogger i:@"Banner Ad is ready but retrieved a nil view."];
    }

    [FlameLogger i:@"Banner Ad is not ready or failed to load."];
    return nil;
}

- (NSArray<FlameBannerAdMaterial *> *)retrieveMaterials {
    return [self.adapter retrieveMaterials];
}

- (void)bindMaterialAtIndex:(NSInteger)index
                      slots:(FlameBannerAdRenderSlots *)slots {
    [self.adapter bindMaterialAtIndex:index slots:slots];
}

- (void)unbindMaterial {
    [self.adapter unbindMaterial];
}

- (void)remove {
    if (![FlameAdapterManager checkInitialization]) return;
    [self.adapter remove];
}

- (void)destroy {
    if (![FlameAdapterManager checkInitialization]) return;
    [self.adapter destroy];
}

@end
