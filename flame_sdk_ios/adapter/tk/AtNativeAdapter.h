//
//  AtNativeAdapter.h
//  flame_sdk_ios
//
//  Created by Flame on 2026/1/23.
//

// TK 平台源码宏隔离：TB 构建变体下整个文件置空，避免编译期 import AnyThink/TopOn
#if defined(FLAME_BUILD_TK) || (!defined(FLAME_BUILD_TK) && !defined(FLAME_BUILD_TB) && !defined(FLAME_BUILD_CORE))

#import <Foundation/Foundation.h>
#import <AnyThinkSDK/AnyThinkSDK.h>
#import "FlameNativeAdapterProtocol.h"
#import "FlameNativeAd.h"

NS_ASSUME_NONNULL_BEGIN

@interface AtNativeAdapter : NSObject<FlameNativeAdapterProtocol, ATNativeADDelegate>

@property (nonatomic, weak) UIViewController *viewController;
@property (nonatomic, strong) NSMutableDictionary *localExtra;
@property (nonatomic, copy) NSString *atPlacementId;
@property (nonatomic, weak) id<FlameNativeListener> listener;
// 强引用当前正在展示的视图，用于状态管理；可能是广告视图本身，也可能是其包装容器
@property (nonatomic, strong) UIView *currentAdView;
// 记录 load 阶段传入的尺寸，show 阶段复用，保证加载与展示一致
@property (nonatomic, assign) CGSize requestedAdSize;
// 调用端设置的首选渲染方式，默认自渲染
@property (nonatomic, assign) FlameNativeRenderType renderType;
// ✅ cachedOffer已移除：offer在showInContainer时才获取，避免浪费缓存

- (instancetype)initWithViewController:(UIViewController *)viewController
                         atPlacementId:(NSString *)atPlacementId
                              listener:(id<FlameNativeListener>)listener;

@end

NS_ASSUME_NONNULL_END

#endif // FLAME_BUILD_TK / 默认 TK
