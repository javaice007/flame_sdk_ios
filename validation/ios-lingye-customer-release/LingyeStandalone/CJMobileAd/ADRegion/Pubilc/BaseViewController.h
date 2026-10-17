//
//  BaseViewController.h
//  CJModileAdDemo
//
//  Created by CJ on 2022/3/7.
//

#import <UIKit/UIKit.h>
#import "CustomShowView.h"

NS_ASSUME_NONNULL_BEGIN

@interface BaseViewController : UIViewController

@property (nonatomic, strong) CustomShowView *customView;

- (void)setupUI;

@end

NS_ASSUME_NONNULL_END
