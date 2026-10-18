//
//  FlameBannerAdRenderSlots.h
//  flame_sdk_ios
//
//  Created by Flame on 2026/5/10.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface FlameBannerAdRenderSlots : NSObject

@property (nonatomic, weak) UIView *containerView;
@property (nonatomic, weak, nullable) UIView *mediaSlotView;
@property (nonatomic, weak, nullable) UIView *logoSlotView;
@property (nonatomic, weak, nullable) UIView *adMarkSlotView;
@property (nonatomic, weak, nullable) UIView *closeSlotView;
@property (nonatomic, copy) NSArray<UIView *> *clickableViews;

@end

NS_ASSUME_NONNULL_END
