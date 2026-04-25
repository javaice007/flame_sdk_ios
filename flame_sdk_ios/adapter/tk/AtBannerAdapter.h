//
//  AtBannerAdapter.h
//  flame_sdk_ios
//
//  Created by Flame on 2026/1/21.
//

#import <Foundation/Foundation.h>
#import <AnyThinkSDK/AnyThinkSDK.h>
#import "FlameBannerAd.h"

NS_ASSUME_NONNULL_BEGIN

@interface AtBannerAdapter : NSObject<FlameBannerAd, ATBannerDelegate>

@property (nonatomic, strong) NSMutableDictionary *localExtra;
@property (nonatomic, copy) NSString *atPlacementId;
@property (nonatomic, weak) id<FlameBannerListener> listener;
@property (nonatomic, assign) CGSize adSize;

- (instancetype)initWithPlacementId:(NSString *)atPlacementId
                           listener:(id<FlameBannerListener>)listener;

@end

NS_ASSUME_NONNULL_END
