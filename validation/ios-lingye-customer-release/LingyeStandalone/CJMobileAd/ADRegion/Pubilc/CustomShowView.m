//
//  CustomShowView.m
//  CJModileAdDemo
//
//  Created by JUN on 2022/3/6.
//

#import "CustomShowView.h"

@interface CustomShowView()

@property (nonatomic, strong) UIButton *loadBtn;

@property (nonatomic, strong) UIButton *showBtn;

@property (nonatomic, strong) UILabel *resultLogLab;

@end
@implementation CustomShowView

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        [self setupUI];
    }
    return self;
}

- (void)setupUI {
    [self addSubview:self.loadBtn];
    [self addSubview:self.showBtn];
    [self addSubview:self.resultLogLab];
    self.loadBtn.frame = CGRectMake(0, 0, 200, 40);
    self.showBtn.frame = CGRectMake(0, 50, 200, 40);
    self.loadBtn.layer.cornerRadius = 8;
    self.showBtn.layer.cornerRadius = 8;
    self.resultLogLab.frame = CGRectMake(0, 100, 200, 500);
}

- (UILabel *)resultLogLab {
    if (!_resultLogLab) {
        _resultLogLab = [[UILabel alloc] init];
        _resultLogLab.hidden = true;
        _resultLogLab.font = [UIFont systemFontOfSize:12];
        _resultLogLab.textColor = [UIColor grayColor];
        _resultLogLab.numberOfLines = 0;
    }
    return _resultLogLab;
}

- (UIButton *)loadBtn {
    if (!_loadBtn) {
        _loadBtn = [[UIButton alloc] init];
        [_loadBtn setTitle:@"load" forState:UIControlStateNormal];
        [_loadBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        _loadBtn.titleLabel.font = [UIFont systemFontOfSize:14];
        _loadBtn.backgroundColor = UIColor.blueColor;
        [_loadBtn addTarget:self action:@selector(loadFunc) forControlEvents:UIControlEventTouchUpInside];
    }
    return _loadBtn;
}

- (UIButton *)showBtn {
    if (!_showBtn) {
        _showBtn = [[UIButton alloc] init];
        [_showBtn setTitle:@"show" forState:UIControlStateNormal];
        [_showBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        _showBtn.titleLabel.font = [UIFont systemFontOfSize:14];
        _showBtn.userInteractionEnabled = false;
        [_showBtn addTarget:self action:@selector(showFunc) forControlEvents:UIControlEventTouchUpInside];
        _showBtn.backgroundColor = [UIColor grayColor];
    }
    return _showBtn;
}

- (void)loadFunc {
    if (self.event) {
        self.event(0);
    }
}

- (void)showFunc {
    if (self.event) {
        self.event(1);
    }
}

- (void)canShowStatus:(BOOL)can errorMsg:(NSString *)msg {
    _showBtn.backgroundColor = can ? [UIColor blueColor] : [UIColor grayColor];
    _showBtn.userInteractionEnabled = can;
    _resultLogLab.hidden = true;
    _resultLogLab.text = @"";
    if (can == false) {
        _resultLogLab.hidden = false;
        _resultLogLab.text = msg;
    }
}

@end
