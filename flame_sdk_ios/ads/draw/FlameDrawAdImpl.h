//
//  FlameDrawAdImpl.h
//  flame_sdk_ios
//
//  Created by Flame on 2026/1/27.
//

#import <Foundation/Foundation.h>
#import "FlameDrawAd.h"

NS_ASSUME_NONNULL_BEGIN

@interface FlameDrawAdImpl : NSObject<FlameDrawAd>

@property (nonatomic, weak) UIViewController *viewController;
@property (nonatomic, copy) NSString *placementId;
@property (nonatomic, weak) id<FlameDrawListener> listener;
@property (nonatomic, strong) id<FlameDrawAd> adapter;


- (instancetype)initWithViewController:(UIViewController *)viewController
                           placementId:(NSString *)placementId
                              listener:(id<FlameDrawListener>)listener;
@end

NS_ASSUME_NONNULL_END
