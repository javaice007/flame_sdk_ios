//
//  CustomShowView.h
//  CJModileAdDemo
//
//  Created by JUN on 2022/3/6.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface CustomShowView : UIView

@property (nonatomic, copy) void (^event)(NSInteger);

- (void)canShowStatus:(BOOL)can errorMsg:(NSString *)msg;

@end

NS_ASSUME_NONNULL_END
