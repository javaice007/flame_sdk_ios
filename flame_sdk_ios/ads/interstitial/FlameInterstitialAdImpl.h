//
//  FlameInterstitialAdImpl.h
//  flame_sdk_ios
//
//  Created by Flame on 2026/1/19.
//

#import <Foundation/Foundation.h>
#import "FlameInterstitialAd.h"

NS_ASSUME_NONNULL_BEGIN

@interface FlameInterstitialAdImpl: NSObject<FlameInterstitialAd>

@property (nonatomic, weak) UIViewController *viewController;
@property (nonatomic, copy) NSString *placementId;
@property (nonatomic, weak) id<FlameInterstitialListener> listener;
@property (nonatomic, strong) id<FlameInterstitialAd> adapter;


- (instancetype)initWithViewController:(UIViewController *)viewController
                           placementId:(NSString *)placementId
                              listener:(id<FlameInterstitialListener>)listener;
@end

NS_ASSUME_NONNULL_END
