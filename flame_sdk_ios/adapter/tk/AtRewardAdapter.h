//  Author: flame
#import <Foundation/Foundation.h>
#import <AnyThinkSDK/AnyThinkSDK.h>
#import "FlameRewardAd.h"

@interface AtRewardAdapter : NSObject <FlameRewardAd, ATRewardedVideoDelegate>

@property (nonatomic, strong) NSMutableDictionary *localExtra;
@property (nonatomic, weak) UIViewController *viewController;
@property (nonatomic, copy) NSString *atPlacementId;
@property (nonatomic, weak) id<FlameRewardListener> listener;


- (instancetype)initWithViewController:(UIViewController *)viewController
                         atPlacementId:(NSString *)atPlacementId
                              listener:(id<FlameRewardListener>)listener;
@end
