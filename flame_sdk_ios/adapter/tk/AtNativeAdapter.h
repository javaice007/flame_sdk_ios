//
//  AtNativeAdapter.h
//  flame_sdk_ios
//
//  Created by Flame on 2026/1/23.
//

#import <Foundation/Foundation.h>
#import <AnyThinkSDK/AnyThinkSDK.h>
#import "FlameNativeAd.h"

NS_ASSUME_NONNULL_BEGIN

@interface AtNativeAdapter : NSObject<FlameNativeAd, ATNativeADDelegate>

@property (nonatomic, weak) UIViewController *viewController;
@property (nonatomic, strong) NSMutableDictionary *localExtra;
@property (nonatomic, copy) NSString *atPlacementId;
@property (nonatomic, weak) id<FlameNativeListener> listener;
// 强引用当前正在展示的广告视图，用于状态管理
@property (nonatomic, strong) ATNativeADView *currentAdView;
// 记录 load 阶段传入的尺寸，show 阶段复用，保证加载与展示一致
@property (nonatomic, assign) CGSize requestedAdSize;
// ✅ cachedOffer已移除：offer在showInContainer时才获取，避免浪费缓存

- (instancetype)initWithViewController:(UIViewController *)viewController
                         atPlacementId:(NSString *)atPlacementId
                              listener:(id<FlameNativeListener>)listener;

@end

NS_ASSUME_NONNULL_END
