//
//  FlameSplashAdImpl.h
//  flame_sdk_ios
//
//  Created by Flame on 2026/1/7.
//

#ifndef FlameSplashAdImpl_h
#define FlameSplashAdImpl_h

#import "FlameSplashAd.h"
#import "FlameSplashAdapterProtocol.h"

@interface FlameSplashAdImpl: NSObject<FlameSplashAd>

@property (nonatomic, weak) UIViewController *viewController;
@property (nonatomic, copy) NSString *placementId;
@property (nonatomic, weak) id<FlameSplashListener> listener;
@property (nonatomic, strong) id<FlameSplashAdapterProtocol> adapter;


- (instancetype)initWithViewController:(UIViewController *)viewController
                           placementId:(NSString *)placementId
                              listener:(id<FlameSplashListener>)listener
                              adapter:(id<FlameSplashAdapterProtocol>)adapter;
@end

#endif /* FlameSplashAdImpl_h */
