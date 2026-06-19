// TK 平台源码宏隔离：TB 构建变体下整个文件置空，避免编译期 import AnyThink/TopOn
//  Author: flame
#import <Foundation/Foundation.h>
#import <AnyThinkSDK/AnyThinkSDK.h>
#import "FlameRewardAd.h"
#import "FlameRewardAdapterProtocol.h"

NS_ASSUME_NONNULL_BEGIN

@interface AtRewardAdapter : NSObject <FlameRewardAdapterProtocol, ATRewardedVideoDelegate>

@property (nonatomic, strong) NSMutableDictionary *localExtra;
@property (nonatomic, weak) UIViewController *viewController;
@property (nonatomic, copy) NSString *atPlacementId;
@property (nonatomic, weak) id<FlameRewardListener> listener;


- (instancetype)initWithViewController:(UIViewController *)viewController
                         atPlacementId:(NSString *)atPlacementId
                              listener:(id<FlameRewardListener>)listener;
@end

NS_ASSUME_NONNULL_END

