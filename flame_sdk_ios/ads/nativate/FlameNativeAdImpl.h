//
//  FlameNativeAdImpl.h
//  flame_sdk_ios
//
//  Created by Flame on 2026/1/23.
//

#import <Foundation/Foundation.h>
#import "FlameNativeAd.h"
#import "FlameNativeAdapterProtocol.h"

NS_ASSUME_NONNULL_BEGIN

@interface FlameNativeAdImpl : NSObject<FlameNativeAd>

@property (nonatomic, weak) UIViewController *viewController;
@property (nonatomic, copy) NSString *placementId;
@property (nonatomic, weak) id<FlameNativeListener> listener;
@property (nonatomic, strong) id<FlameNativeAdapterProtocol> adapter;
@property (nonatomic, assign) FlameNativeRenderType renderType;


- (instancetype)initWithViewController:(UIViewController *)viewController
                           placementId:(NSString *)placementId
                              listener:(id<FlameNativeListener>)listener
                              adapter:(id<FlameNativeAdapterProtocol>)adapter;

@end

NS_ASSUME_NONNULL_END
