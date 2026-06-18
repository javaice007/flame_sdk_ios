//
//  AtNativeSelfRenderView.h
//  flame_sdk_ios
//
//  Created by Flame on 2026/3/17.
//

// TK 平台源码宏隔离：TB 构建变体下整个文件置空，避免编译期 import AnyThink/TopOn
#if defined(FLAME_BUILD_TK) || (!defined(FLAME_BUILD_TK) && !defined(FLAME_BUILD_TB) && !defined(FLAME_BUILD_CORE))

#import <UIKit/UIKit.h>
#import <AnyThinkSDK/AnyThinkSDK.h>
#import <AnyThinkSDK/ATNativeAdOffer.h>
#import <AnyThinkSDK/ATNativeMaterialProtocol.h>

NS_ASSUME_NONNULL_BEGIN

/// 自渲染原生广告视图
@interface AtNativeSelfRenderView : UIView

/// 图标
@property (nonatomic, strong) UIImageView *iconImageView;
/// 标题
@property (nonatomic, strong) UILabel *titleLabel;
/// 描述文本
@property (nonatomic, strong) UILabel *textLabel;
/// 行动号召按钮文案
@property (nonatomic, strong) UILabel *ctaLabel;
/// 主图
@property (nonatomic, strong) UIImageView *mainImageView;
/// 广告商名称
@property (nonatomic, strong) UILabel *advertiserLabel;
/// 评分
@property (nonatomic, strong) UILabel *ratingLabel;
/// Logo
@property (nonatomic, strong) UIImageView *logoImageView;
/// 关闭按钮
@property (nonatomic, strong) UIButton *dislikeButton;
/// 媒体视图（视频或图片）
@property (nonatomic, strong) UIView *mediaView;

/// 初始化方法
/// @param offer 广告offer对象
- (instancetype)initWithOffer:(ATNativeAdOffer *)offer;

@end

NS_ASSUME_NONNULL_END

#endif // FLAME_BUILD_TK / 默认 TK
