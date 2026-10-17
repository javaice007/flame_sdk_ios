//
//  CustomFeedView.h
//  CJMobileAd_Example
//
//  Created by shanghailingye on 2024/4/10.
//  Copyright © 2024 wade.xiong. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CJMobileAd/CJFeedAdMaterial.h>
#import <CJMobileAd/CJMobileAd.h>

NS_ASSUME_NONNULL_BEGIN

@interface CustomFeedView : UIView

/// 视频配置
@property (nonatomic, strong) CJFeedNaiveConfig *config;

/// 自定义渲染view
/// - Parameter material: 素材
- (instancetype)initWithMaterial:(CJFeedAdMaterial *)material;

@end

NS_ASSUME_NONNULL_END
