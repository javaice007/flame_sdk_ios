//
//  CJEntranceHeaderView.m
//  CJMobileAdDemo
//
//  Created by JJ on 2022/12/2.
//

#import "CJEntranceHeaderView.h"
#import "CJMobilePublic.h"

@interface CJEntranceHeaderView()

@property (nonatomic, strong) UIView *lineView;
@property (nonatomic, strong) UILabel *titleLab;

@end

@implementation CJEntranceHeaderView

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        [self setupUI];
    }
    return self;
}

- (void)setTitle:(NSString *)title {
    self.titleLab.text = title;
}

- (void)setupUI {
    [self addSubview:self.lineView];
    [self addSubview:self.titleLab];
    [self.lineView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.mas_equalTo(self).offset(24);
        make.left.mas_equalTo(self);
        make.size.mas_equalTo(CGSizeMake(2, 14));
    }];
    [self.titleLab mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.mas_equalTo(self.lineView.mas_right).offset(8);
        make.centerY.mas_equalTo(self.lineView);
        make.width.mas_lessThanOrEqualTo(200);
        make.height.mas_lessThanOrEqualTo(25);
    }];
}

- (UIView *)lineView {
    if (!_lineView) {
        _lineView = [[UIView alloc] init];
        _lineView.backgroundColor = [UIColor greenColor];
    }
    return _lineView;
}

- (UILabel *)titleLab {
    if (!_titleLab) {
        _titleLab = [[UILabel alloc] init];
        _titleLab.font = [UIFont boldSystemFontOfSize:18];
        _titleLab.textColor = [UIColor blackColor];
    }
    return _titleLab;
}



@end
