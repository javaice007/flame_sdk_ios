//
//  CustomFeedView.m
//  CJMobileAd_Example
//
//  Created by shanghailingye on 2024/4/10.
//  Copyright © 2024 wade.xiong. All rights reserved.
//

#import "CustomFeedView.h"
#import <SDWebImage/SDWebImage.h>
#import <Masonry/Masonry.h>

@interface CustomFeedView()

@property (nonatomic, strong) CJFeedAdMaterial *feedMateral;

/// 标题
@property (nonatomic, strong) UILabel *titleLabel;
/// 描述
@property (nonatomic, strong) UILabel *descLabel;
/// icon
@property (nonatomic, strong) UIImageView *iconImageView;
/// 大图
@property (nonatomic, strong) UIImageView *imageView;
/// close按钮
@property (nonatomic, strong) UIButton *clickButton;
@property (nonatomic, strong) UIButton *CTAButton;


/// 三图模式
@property (nonatomic, strong) UIImageView *leftImageView;
@property (nonatomic, strong) UIImageView *midImageView;
@property (nonatomic, strong) UIImageView *rightImageView;

@end

@implementation CustomFeedView

- (instancetype)initWithMaterial:(CJFeedAdMaterial *)material {
    if (self = [super init]) {
        self.feedMateral = material;
        [self setupUI];
        if (material.materialType == CJMaterialTypeSingle) {
            [self setupBigImageMode];
        }
        if (material.materialType == CJMaterialTypeVideo) {
            [self setupVideoMode];
        }
    }
    return self;
}

- (void)setupUI {
    [self addSubview:self.titleLabel];
    [self addSubview:self.descLabel];
    [self addSubview:self.iconImageView];
    [self addSubview:self.imageView];
    [self addSubview:self.clickButton];
    [self addSubview:self.CTAButton];
    [self addSubview:self.leftImageView];
    [self addSubview:self.midImageView];
    [self addSubview:self.rightImageView];
}

- (void)setupVideoMode {
    CGFloat width = [UIScreen mainScreen].bounds.size.width - 16;
    self.backgroundColor = [UIColor grayColor];
    self.iconImageView.frame = CGRectMake(8, 8, 60, 60);
    self.titleLabel.frame = CGRectMake(76, 8, 200, 30);
    self.titleLabel.text = self.feedMateral.title;
    self.descLabel.text = self.feedMateral.desc;
    self.descLabel.frame = CGRectMake(8, 76, width, 30);
    [self.descLabel sizeToFit];
    
    [self.clickButton sizeToFit];
    self.clickButton.frame = (CGRect) {
        .origin.x = width + 8 - self.clickButton.frame.size.width,
        .origin.y = 8,
        .size = self.clickButton.frame.size
    };
    [self.iconImageView sd_setImageWithURL:[NSURL URLWithString:self.feedMateral.iconImage.imageURL] placeholderImage:nil];
    CGFloat imageRate = self.feedMateral.mediaUrlList.firstObject.width / (CGFloat)self.feedMateral.mediaUrlList.firstObject.height;
//    self.config.videoFrame = CGRectMake(8, 114, [UIScreen mainScreen].bounds.size.width-16, ([UIScreen mainScreen].bounds.size.width-16)/imageRate);
//    self.config.logoPistion = CGPointMake(200, 8);
    self.frame = CGRectMake(0, 0, [UIScreen mainScreen].bounds.size.width, 114 + ([UIScreen mainScreen].bounds.size.width)/imageRate + 24);
}

- (void)setupBigImageMode {
    self.titleLabel.text = self.feedMateral.title;
    self.descLabel.text = self.feedMateral.desc;
    NSURL *iconURL = [NSURL URLWithString:self.feedMateral.iconImage.imageURL];
    [self.iconImageView sd_setImageWithURL:iconURL placeholderImage:nil];
    
    if (self.feedMateral.materialType == CJMaterialTypeAtlas) {
        self.imageView.hidden = YES;
        self.leftImageView.hidden = NO;
        self.midImageView.hidden = NO;
        self.rightImageView.hidden = NO;
    } else {
        self.imageView.hidden = NO;
        self.leftImageView.hidden = YES;
        self.midImageView.hidden = YES;
        self.rightImageView.hidden = YES;
    }
    CGFloat imageRate = 16.0 / 9;
    if (self.feedMateral.mediaUrlList.count > 0) {
        imageRate = self.feedMateral.mediaUrlList.firstObject.width / (CGFloat)self.feedMateral.mediaUrlList.firstObject.height;
    }
    CGFloat width = [UIScreen mainScreen].bounds.size.width - 16;
    self.backgroundColor = [UIColor grayColor];
    self.iconImageView.frame = CGRectMake(8, 8, 60, 60);
    self.CTAButton.frame = CGRectMake(width - 100, 8, 100, 44);
    self.titleLabel.frame = CGRectMake(76, 8, 250, 30);
    self.descLabel.frame = CGRectMake(8, 76, width, 30);
    CGFloat imageWidth = width;
    self.imageView.frame = CGRectMake(8, 114, imageWidth, imageWidth / imageRate);
   
    [self.imageView sd_setImageWithURL:[NSURL URLWithString:self.feedMateral.mediaUrlList.firstObject.imageURL] placeholderImage:nil];
    self.frame = CGRectMake(0, 0, [UIScreen mainScreen].bounds.size.width, 122 + imageWidth / imageRate);
    [self.clickButton sizeToFit];
    self.clickButton.frame = (CGRect) {
        .origin.x = width - 8 - self.clickButton.frame.size.width,
        .origin.y = 8,
        .size = self.clickButton.frame.size
    };
}


- (CGFloat)cellHeightWithUnifiedNativeAdDataObject
{
    CGFloat height = 0;
    CGFloat imageRate = 228 / 150.0; // 三小图默认比例
    if (self.feedMateral.mediaUrlList.count > 0) {
        imageRate = self.feedMateral.mediaUrlList.firstObject.width / (CGFloat)self.feedMateral.mediaUrlList.firstObject.height;
    }
    CGFloat width = [UIScreen mainScreen].bounds.size.width - 16;
    CGFloat imageWidth = (width - 16) / 3;
    height = 92 + imageWidth / imageRate;
    return height;
}


#pragma mark - proerty getter
- (UILabel *)titleLabel
{
    if (!_titleLabel) {
        _titleLabel = [[UILabel alloc] init];
        _titleLabel.accessibilityIdentifier = @"titleLabel_id";
    }
    return _titleLabel;
}

- (UIImageView *)imageView
{
    if (!_imageView) {
        _imageView = [[UIImageView alloc] init];
        _imageView.accessibilityIdentifier = @"imageView_id";
        _imageView.layer.cornerRadius = 2;
    }
    return _imageView;
}

- (UILabel *)descLabel
{
    if (!_descLabel) {
        _descLabel = [[UILabel alloc] init];
        _descLabel.accessibilityIdentifier = @"descLabel_id";
    }
    return _descLabel;
}

- (UIButton *)clickButton
{
    if (!_clickButton) {
        _clickButton = [[UIButton alloc] init];
        _clickButton.accessibilityIdentifier = @"clickButton_id";
        _clickButton.backgroundColor = [UIColor blueColor];
    }
    return _clickButton;
}

- (UIImageView *)iconImageView
{
    if (!_iconImageView) {
        _iconImageView = [[UIImageView alloc] init];
        _iconImageView.accessibilityIdentifier = @"iconImageView_id";
    }
    return _iconImageView;
}

- (UIImageView *)leftImageView
{
    if (!_leftImageView) {
        _leftImageView = [[UIImageView alloc] init];
        _leftImageView.accessibilityIdentifier = @"leftImageView_id";
    }
    return _leftImageView;
}

- (UIImageView *)midImageView
{
    if (!_midImageView) {
        _midImageView = [[UIImageView alloc] init];
        _midImageView.accessibilityIdentifier = @"midImageView_id";
    }
    return _midImageView;
}

- (UIImageView *)rightImageView
{
    if (!_rightImageView) {
        _rightImageView = [[UIImageView alloc] init];
        _rightImageView.accessibilityIdentifier = @"rightImageView_id";
    }
    return _rightImageView;
}

- (UIButton *)CTAButton {
    if (!_CTAButton) {
        _CTAButton = [[UIButton alloc] init];
        _CTAButton.accessibilityIdentifier = @"CTAButton_id";
    }
    
    return _CTAButton;
}
//
//- (CJFeedNaiveConfig *)config {
//    if (!_config) {
//        _config = [[CJFeedNaiveConfig alloc] init];
//        _config.ismute = true;
//    }
//    return _config;
//}

@end
