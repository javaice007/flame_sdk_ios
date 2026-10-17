//
//  CustomCell.m
//  CJModileAdDemo
//
//  Created by JUN on 2022/3/6.
//

#import "CustomCell.h"


@interface CustomCell()

@property (nonatomic,strong) UILabel *testLab;

@end
@implementation CustomCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier{
    if (self = [super initWithStyle:style reuseIdentifier:reuseIdentifier]) {
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        [self setupCell];
    }
    return self;
}

- (void)setupCell{
    self.testLab = [UILabel new];
    self.testLab.textAlignment = NSTextAlignmentCenter;
    self.testLab.textColor = [UIColor whiteColor];
    self.testLab.font = [UIFont boldSystemFontOfSize:12];
    [self.contentView addSubview:self.testLab];
    self.testLab.frame = self.contentView.bounds;
    self.contentView.backgroundColor = [UIColor whiteColor];
    self.testLab.backgroundColor = [UIColor blueColor];
}

- (void)setTitle:(NSString *)title{
    _title = title;
    self.testLab.text = title;
}

- (void)layoutSubviews{
    [super layoutSubviews];
    self.testLab.frame = self.contentView.bounds;
    CGRect frame = self.testLab.frame;
    frame.size.height = 45;
    self.testLab.frame = frame;
}

@end
