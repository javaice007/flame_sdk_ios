//
//  FlameRewardAdImpl.h
//  flame_sdk_ios
//
//  Created by Flame on 2026/1/7.
//

#ifndef FlameRewardAdImpl_h
#define FlameRewardAdImpl_h

#import "FlameRewardAd.h"
#import "FlameRewardAdapterProtocol.h"

@interface FlameRewardAdImpl: NSObject<FlameRewardAd>

@property (nonatomic, weak) UIViewController *viewController;
@property (nonatomic, copy) NSString *placementId;
@property (nonatomic, weak) id<FlameRewardListener> listener;
@property (nonatomic, strong) id<FlameRewardAdapterProtocol> adapter;

/**
 * 内部初始化方法：接收预创建的适配器
 * @param viewController 视图控制器
 * @param placementId Flame 广告位 ID
 * @param listener 回调监听器
 * @param adapter 预创建的内部适配器（由 FlameSdk 通过 Router → Provider 获取）
 */
- (instancetype)initWithViewController:(UIViewController *)viewController
                           placementId:(NSString *)placementId
                              listener:(id<FlameRewardListener>)listener
                              adapter:(id<FlameRewardAdapterProtocol>)adapter;

@end

#endif /* FlameRewardAdImpl_h */
