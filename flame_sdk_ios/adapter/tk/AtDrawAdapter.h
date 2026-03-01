//
//  AtDrawAdapter.h
//  flame_sdk_ios
//
//  Created by Flame on 2026/1/25.
//

#import <Foundation/Foundation.h>
#import <AnyThinkSDK/AnyThinkSDK.h>
#import "FlameDrawAd.h"

NS_ASSUME_NONNULL_BEGIN

@interface AtDrawAdapter : NSObject<FlameDrawAd, ATMediaVideoDelegate>

@property (nonatomic, strong) NSMutableDictionary *localExtra;
@property (nonatomic, copy) NSString *atPlacementId;
@property (nonatomic, weak) id<FlameDrawListener> listener;

@property (nonatomic, strong) UIView *videoView;
@property (nonatomic, weak) UIViewController *viewController;
@property (nonatomic, strong) ATMediaVideoOffer *offer;

- (instancetype)initWithViewController:(UIViewController *)viewController
                         atPlacementId:(NSString *)atPlacementId
                              listener:(id<FlameDrawListener>)listener;

@end

NS_ASSUME_NONNULL_END
