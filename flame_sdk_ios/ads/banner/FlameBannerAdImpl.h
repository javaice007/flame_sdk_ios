//
//  FlameBannerAdImpl.h
//  flame_sdk_ios
//
//  Created by Flame on 2026/1/21.
//

#import <Foundation/Foundation.h>
#import "FlameBannerAd.h"
#import "FlameBannerAdapterProtocol.h"

NS_ASSUME_NONNULL_BEGIN

@interface FlameBannerAdImpl : NSObject<FlameBannerAd>

@property (nonatomic, copy) NSString *placementId;
@property (nonatomic, weak) id<FlameBannerListener> listener;
@property (nonatomic, strong) id<FlameBannerAdapterProtocol> adapter;
@property (nonatomic, assign, readonly) FlameBannerRenderType renderType;

- (instancetype)initWithPlacementId:(NSString *)placementId
                         renderType:(FlameBannerRenderType)renderType
                           listener:(id<FlameBannerListener>)listener
                           adapter:(id<FlameBannerAdapterProtocol>)adapter;

@end

NS_ASSUME_NONNULL_END
