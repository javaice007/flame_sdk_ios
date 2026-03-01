//
//  FlameSplashAdImpl.h
//  flame_sdk_ios
//
//  Created by Flame on 2026/1/7.
//

#ifndef FlameSplashAdImpl_h
#define FlameSplashAdImpl_h

#import "FlameSplashAd.h"

@interface FlameSplashAdImpl: NSObject<FlameSplashAd>

@property (nonatomic, weak) UIViewController *viewController;
@property (nonatomic, copy) NSString *placementId;
@property (nonatomic, weak) id<FlameSplashListener> listener;
@property (nonatomic, strong) id<FlameSplashAd> adapter;


- (instancetype)initWithViewController:(UIViewController *)viewController
                           placementId:(NSString *)placementId
                              listener:(id<FlameSplashListener>)listener;
@end

#endif /* FlameSplashAdImpl_h */
