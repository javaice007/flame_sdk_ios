//
//  FlameRewardAdImpl.h
//  flame_sdk_ios
//
//  Created by Flame on 2026/1/7.
//

#ifndef FlameRewardAdImpl_h
#define FlameRewardAdImpl_h

#import "FlameRewardAd.h"

@interface FlameRewardAdImpl: NSObject<FlameRewardAd>

@property (nonatomic, weak) UIViewController *viewController;
@property (nonatomic, copy) NSString *placementId;
@property (nonatomic, weak) id<FlameRewardListener> listener;
@property (nonatomic, strong) id<FlameRewardAd> adapter;


- (instancetype)initWithViewController:(UIViewController *)viewController
                           placementId:(NSString *)placementId
                              listener:(id<FlameRewardListener>)listener;
@end

#endif /* FlameRewardAdImpl_h */
