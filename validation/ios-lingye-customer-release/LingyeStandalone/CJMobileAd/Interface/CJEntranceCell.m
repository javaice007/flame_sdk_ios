//
//  CJEntranceCell.m
//  CJMobileAdDemo
//
//  Created by JJ on 2022/12/1.
//

#import "CJEntranceCell.h"

@interface CJEntranceCell()

@property (nonatomic, strong) UILabel *contentLabel;

@end
@implementation CJEntranceCell


- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        [self setupCell];
    }
    return self;
}

- (void)setText:(NSString *)text {
    self.contentLabel.text = text;
}


- (void)setupCell {
    self.contentView.layer.cornerRadius = 12;
    self.contentView.clipsToBounds = true;
    [self.contentView addSubview:self.contentLabel];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    self.contentLabel.frame = self.contentView.bounds;
}


- (UIColor *)getRandomColor {
    return [UIColor colorWithRed:((float)arc4random_uniform(256) / 255.0) green:((float)arc4random_uniform(256) / 255.0) blue:((float)arc4random_uniform(256) / 255.0) alpha:1.0];;
}

- (UILabel *)contentLabel {
    if (!_contentLabel) {
        _contentLabel = [[UILabel alloc] init];
//        _contentLabel.layer.cornerRadius = 12;
        _contentLabel.text = @"原生模版";
        _contentLabel.backgroundColor = [self getRandomColor];
        _contentLabel.font = [UIFont boldSystemFontOfSize:20];
        _contentLabel.textAlignment = NSTextAlignmentCenter;
        _contentLabel.textColor = [UIColor whiteColor];
    }
    return  _contentLabel;
}



@end
