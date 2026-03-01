//
//  AtInterstitialAdapter.h
//  flame_sdk_ios
//
//  Created by Flame on 2026/1/19.
//

#import <Foundation/Foundation.h>
#import <AnyThinkSDK/AnyThinkSDK.h>
#import "FlameInterstitialAd.h"

NS_ASSUME_NONNULL_BEGIN

@interface AtInterstitialAdapter : NSObject<FlameInterstitialAd, ATInterstitialDelegate>

@property (nonatomic, strong) NSMutableDictionary *localExtra;
@property (nonatomic, weak) UIViewController *viewController;
@property (nonatomic, copy) NSString *atPlacementId;
@property (nonatomic, weak) id<FlameInterstitialListener> listener;


- (instancetype)initWithViewController:(UIViewController *)viewController
                         atPlacementId:(NSString *)atPlacementId
                              listener:(id<FlameInterstitialListener>)listener;

@end

NS_ASSUME_NONNULL_END
