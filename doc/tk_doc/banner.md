横幅广告
1. 集成建议
1.1 宽高设置
宽高设置需要与在Taku后台配置的宽高比一致，并根据实际效果进行调整。
1.2 自动刷新
默认情况下不开启，可以在Taku后台的广告位高级设置中配置刷新时间开启或者禁止刷新。
横幅广告的View必须添加到窗口并可见，才会触发自动刷新。
如果广告平台有提供自动刷新功能，则建议关闭广告平台的自动刷新，只需要用Taku提供的自动刷新，避免因为冲突而导致一些不可预知的问题。
开启自动刷新功能后，将ATBannerView添加到布局中，并保证其处于可见状态后调用一次loadADWithPlacementID:方法，之后的展示和刷新都会由SDK自动执行。
1.4 示例代码
详细示例代码请参考：Demo 中 BannerVC.m
1.5 ⚠️ 版本迭代说明
V6.4.39以上版本（包括V6.4.39），支持load 加载广告时传入控制器对象，来适配部分广告平台要求的加载控制器与展示控制器必须匹配的要求。若您因为一些原因不能适配传入控制器对象，可能导致这些广告平台展示后点击无效的问题。如果您需要适配，请配套使用以下API，传入相同的控制器对象：

objc
复制代码
/// 加载横幅广告
/// @param placementID 广告位ID
/// @param extra 额外参数
/// @param viewController 目标控制器，例如Banner点击后弹出的窗体会使用这个控制器，您需要对其进行引用，SDK内部是弱引用
/// @param delegate 代理对象
- (void)loadADWithPlacementID:(NSString *)placementID
                        extra:(NSDictionary *)extra
               viewController:(UIViewController *)viewController
                     delegate:(id<ATAdLoadingDelegate>)delegate;

/// 检查横幅广告是否就绪
/// @param placementID 广告位ID
/// @param showViewController 传入加载方法-[ATAdManager loadADWithPlacementID:extra:viewController:delegate:]中的控制器相同的对象
- (BOOL)bannerAdReadyForPlacementID:(NSString *)placementID showViewController:(UIViewController *)showViewController;

/// 获取BannerView对象用于展示
/// @param placementID 广告位ID
/// @param ATShowConfig config 配置对象，若加载loadADWithPlacementID传入了viewController，那么这里需要传入相同的对象
/// @param nativeMixBannerViewBlock 自定义横幅广告用，返回组件用于自定义布局
- (nullable ATBannerView *)retrieveBannerViewForPlacementID:(NSString *)placementID
                                                     config:(ATShowConfig *)config
                                     nativeMixBannerViewBlock:(nullable NativeMixBannerViewBlock)nativeMixBannerViewBlock;
2. 加载广告
不同平台的横幅广告有一定规则限制：

等比例缩放规则：例如后台配置的横幅广告尺寸为640*100，为了能填充完屏幕宽，计算高度H = (屏幕宽 *100)/640；那么填充后的大小为为：CGSizeMake(屏幕宽, H);
固定尺寸规则：在后台配置中选定固定尺寸，代码中也设置相同固定尺寸
自适应规则：仅部分广告平台支持，同时需要在后台选择非固定尺寸样式，代码详见Demo中方法示例 - [AdLoadConfigTool banner_loadExtraConfigAppendAdmob:loadConfigDict]
此步骤的extra字典中支持传入相关配置广告的参数与您的自定义参数，您可以在这里查看更多关于extra参数的说明。
objc
复制代码
//导入头文件
#import <AnyThinkBanner/AnyThinkBanner.h>

@interface BannerVC () <ATBannerDelegate>

@property (nonatomic, strong) ATBannerView *bannerView;
@property (nonatomic, assign) BOOL hasLoaded; // 广告加载状态标识

@end

@implementation BannerVC

//广告位ID
#define BannerPlacementID @"b680a1e7874fce"

//场景ID，可选，可在后台生成。没有可传入空字符串
#define BannerSceneID @""

//请注意，banner size需要和后台配置的比例一致
#define BannerSize CGSizeMake(320, 50)

#pragma mark - Load Ad 加载广告
/// 加载广告 
- (void)loadAd {
 
    [self showLog:kLocalizeStr(@"点击了加载广告")];
      
    NSMutableDictionary * loadConfigDict = [NSMutableDictionary dictionary];
    
    /*
     注意不同平台的横幅广告有一定限制，例如配置的横幅广告640*100，为了能填充完屏幕宽，计算高度H = (屏幕宽 *100)/640；那么在load的extra的size为（屏幕宽：H）。
     
     Note that banner ads on different platforms have certain restrictions. For example, the configured banner AD is 640*100. In order to fill the screen width, the height H = (screen width *100)/640 is calculated. Then the extra size of the load is (screen width: H).
     */
    [loadConfigDict setValue:[NSValue valueWithCGSize:BannerSize] forKey:kATAdLoadingExtraBannerAdSizeKey];
    
    //设置自定义参数
    [loadConfigDict setValue:@"media_val_BannerVC" forKey:kATAdLoadingExtraMediaExtraKey];
 
    //开始加载
    [[ATAdManager sharedManager] loadADWithPlacementID:BannerPlacementID extra:loadConfigDict delegate:self];
}

#pragma mark - 广告位代理回调
/// 广告位加载完成
/// - Parameter placementID: 广告位ID
- (void)didFinishLoadingADWithPlacementID:(NSString *)placementID {
     self.hasLoaded = YES;
 }
 
/// 广告位加载失败
/// - Parameters:
///   - placementID: 广告位ID
///   - error: 错误信息
- (void)didFailToLoadADWithPlacementID:(NSString *)placementID error:(NSError *)error { 
     self.hasLoaded = NO;
}
3. 展示广告
统计场景到达率，呈现在后台的 数据报表 -> 漏斗分析报表 -> 到达广告场景 ，在展示广告前调用。

objc
复制代码
#pragma mark - Show Ad 展示广告
/// 展示广告
- (void)showAd {
    
    //场景统计功能，呈现在后台的 数据报表 -> 漏斗分析报表 -> 到达广告场景 ，在展示广告前调用。可选接入
    [[ATAdManager sharedManager] entryBannerScenarioWithPlacementID:BannerPlacementID scene:BannerSceneID];

    //检查是否有就绪
    if (![[ATAdManager sharedManager] bannerAdReadyForPlacementID:BannerPlacementID]) {
        [self loadAd];
        return;
    }
    
    //展示配置，Scene传入后台的场景ID，没有可传入空字符串，showCustomExt参数可传入自定义参数字符串
    ATShowConfig *config = [[ATShowConfig alloc] initWithScene:BannerSceneID showCustomExt:@"testShowCustomExt"];
 
    //展示广告
    ATBannerView *bannerView = [[ATAdManager sharedManager] retrieveBannerViewForPlacementID:BannerPlacementID config:config];
    if (bannerView != nil) {
        //赋值
        bannerView.delegate = self;
        bannerView.presentingViewController = self;
        bannerView.translatesAutoresizingMaskIntoConstraints = NO;
        [self.view addSubview:bannerView];
        self.bannerView = bannerView;
        
        //布局
        [self.bannerView mas_makeConstraints:^(MASConstraintMaker *make) {
            make.centerX.mas_equalTo(self.view);
            make.height.equalTo(@(BannerSize.height));
            make.width.equalTo(@(BannerSize.width));
            make.top.equalTo(self.textView.mas_bottom).offset(5);
        }];
    }
}

/// 获得展示收益
/// - Parameters:
///   - placementID: 广告位ID
///   - extra: 额外信息字典
- (void)didRevenueForPlacementID:(NSString *)placementID extra:(NSDictionary *)extra { 
}
 
/// 关闭按钮点击(当用户点击横幅上关闭按钮的情形)
/// - Parameters:
///   - bannerView: 横幅广告视图对象
///   - placementID: 广告位ID
///   - extra: 额外信息字典
- (void)bannerView:(ATBannerView *)bannerView didTapCloseButtonWithPlacementID:(NSString *)placementID extra:(NSDictionary *)extra { 
    // 收到点击关闭按钮回调,移除bannerView
    [self removeAd];
}

/// 横幅广告已展示
/// - Parameters:
///   - bannerView: 横幅广告视图对象
///   - placementID: 广告位ID
///   - extra: 额外信息字典
- (void)bannerView:(ATBannerView *)bannerView didShowAdWithPlacementID:(NSString *)placementID extra:(NSDictionary *)extra { 
}

/// 横幅广告被点击
/// - Parameters:
///   - bannerView: 横幅广告视图对象
///   - placementID: 广告位ID
///   - extra: 额外信息字典
- (void)bannerView:(ATBannerView *)bannerView didClickWithPlacementID:(NSString *)placementID extra:(NSDictionary *)extra{ 
}

/// 横幅广告已自动刷新
/// - Parameters:
///   - bannerView: 横幅广告视图对象
///   - placementID: 广告位ID
///   - extra: 额外信息字典
- (void)bannerView:(ATBannerView *)bannerView didAutoRefreshWithPlacement:(NSString *)placementID extra:(NSDictionary *)extra { 
}

/// 横幅广告自动刷新失败
/// - Parameters:
///   - bannerView: 横幅广告视图对象
///   - placementID: 广告位ID
///   - error: 错误信息
- (void)bannerView:(ATBannerView *)bannerView failedToAutoRefreshWithPlacementID:(NSString *)placementID error:(NSError *)error { 
}
 
/// 横幅广告已打开或跳转深链接页面
/// - Parameters:
///   - bannerView: 横幅广告视图对象
///   - placementID:  广告位ID
///   - extra: 额外信息
///   - success: 是否成功
- (void)bannerView:(ATBannerView *)bannerView didDeepLinkOrJumpForPlacementID:(NSString *)placementID extra:(NSDictionary *)extra result:(BOOL)success { 
}
4. 销毁广告
objc
复制代码
#pragma mark - 销毁广告
- (void)removeAd { 
    [self.bannerView destroyBanner];
    [self.bannerView removeFromSuperview];
    self.bannerView = nil;
    self.hasLoaded = NO;
}
5. API说明
类名/文件名	简介
ATAdManager
广告的基础操作类，包括广告加载、过滤广告、场景统计、比价工具等功能。
ATAdManager (Banner)
针对横幅广告的操作拓展，提供广告展示、检查缓存、检查广告是否就绪、场景统计等功能，其中有Extra键的定义。
ATAdLoadingDelegate
广告的基础代理回调声明，包括广告位与广告源级别的加载成功或失败回调、竞价广告源的竞价结束与竞价失败回调以及获取展示收益回调等。
ATBannerDelegate
针对横幅广告类型的代理回调，包括展示、点击和关闭等。
ATSDKGlobalSetting
通用设置类，提供形如清除广告内存中的缓存、自定义流量分组设置、测试模式、设置第三方广告SDK相关信息等功能，还声明了一些通用的属性。



## 自定义横幅广告
1. 说明
使用横幅广告位配置原生广告。

请前往这里查看本功能的支持范围

2. 如何使用
1. 管理后台创建横幅广告位，并添加或编辑支持广告样式混用的广告源


2. 如果后台选择由Taku渲染(SDK渲染)，此时UI元素无法自行设置布局，您需要正确指定banner容器大小即可，无需修改代码，可跳过以下步骤。


3. 如果后台选择自渲染，需要额外集成代码，请先阅读本注意事项后再进行代码对接。

若您后台配置采用自渲染方案，请注意以下几点：

拿到UI元素自行配置布局，调用展示若没有触发show回调，则表示您渲染的UI元素不够，或是布局存在问题，导致广告平台判定为无效展示，您需要根据实际情况调整以满足广告平台要求。

没在代码实现自渲染返回广告View，则会默认用SDK内置的布局样式进行渲染。

有在代码设置自渲染返回广告View时，则广告背景默认是全透明。

对下图的mainImageView或mediaView的处理，它们的布局是一致的，当mediaView有值时，布局mediaView并显示在最上方。

4.建议渲染的元素与图例说明如下：

广告元素有些必须渲染，有些则是可选渲染，详情请参考本篇末尾
广告元素字段不一定有值，使用前需要判空


3. 示例代码
请注意，自渲染的布局不要超出后台选择 banner 的尺寸，否则会导致无法响应点击事件！

objc
复制代码
#import <Masonry/Masonry.h>

- (void)showBanner {
    // 展示前判断广告是否准备好
    if ([[ATAdManager sharedManager] bannerAdReadyForPlacementID:@"your banner placementID"]) {
         // 移除可能存在的旧BannerView
        NSInteger tag = 3333;
        [[self.view viewWithTag:tag] removeFromSuperview];
         //Retrieve banner view
        
        ATShowConfig *showConfig = ATShowConfig.new; 
        //若没有场景配置，使用默认场景可传入空字符串
        showConfig.scene = @"your scene id"; 
        //展示时透传参数
        showConfig.showCustomExt = @"testShowCustomExt"; 
        __weak __typeof(self)weakSelf = self; 
        
        ATBannerView *bannerView = [[ATAdManager sharedManager] retrieveBannerViewForPlacementID:@"your banner ad id" 
                                                                config:showConfig 
                                                                nativeMixBannerViewBlock:^(ATNativeBannerView * _Nonnull nativeBannerView) { 
                                                                //Taku后台选择自渲染时，由您进行ATNativeBannerView的约束设置 ，选择Taku渲染则不会回调
                                                                        [weakSelf developerSlefRender:nativeBannerView]; 
                                                               }];
        
        if (bannerView != nil) {
            bannerView.delegate = self;
            bannerView.presentingViewController = self;
            bannerView.translatesAutoresizingMaskIntoConstraints = NO;
            bannerView.tag = tag;
            [self.view addSubview:bannerView];
            //Layour banner
            [self.view addConstraint:[NSLayoutConstraint constraintWithItem:self.view attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:bannerView attribute:NSLayoutAttributeCenterX multiplier:1.0f constant:.0f]];
            [self.view addConstraint:[NSLayoutConstraint constraintWithItem:bannerView attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeTop multiplier:1.0f constant:CGRectGetHeight([UIApplication sharedApplication].statusBarFrame) + CGRectGetHeight(self.navigationController.navigationBar.frame)]];
            [self.view addConstraint:[NSLayoutConstraint constraintWithItem:bannerView attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1.0f constant:_adSize.width]];
            [self.view addConstraint:[NSLayoutConstraint constraintWithItem:bannerView attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1.0f constant:_adSize.height]];
        } else {
        NSLog(@"Banner ad's not ready for placementID:%@", @"your banner placementID");
    }
}
 
 - (void)developerSlefRender:(ATNativeBannerView *)nativeBannerView {
    
    // 只渲染部分作为示例
    [nativeBannerView mas_remakeConstraints:^(MASConstraintMaker *make) {
        make.width.mas_equalTo(350);
        make.height.mas_equalTo(150);
        make.center.mas_equalTo(nativeBannerView.superview);
    }];
    
    [nativeBannerView.textLabel mas_remakeConstraints:^(MASConstraintMaker *make) {
        make.left.mas_equalTo(nativeBannerView);
        make.right.mas_equalTo(nativeBannerView);
        make.height.mas_equalTo(30);
        make.bottom.mas_equalTo(nativeBannerView.mas_bottom).offset(-5);
    }];

    [nativeBannerView.titleLabel mas_remakeConstraints:^(MASConstraintMaker *make) {
        make.left.mas_equalTo(nativeBannerView);
        make.right.mas_equalTo(nativeBannerView);
        make.height.mas_equalTo(30);
        make.bottom.mas_equalTo(nativeBannerView.textLabel.mas_top).offset(-5);
    }];

    //布局默认"广告"logo
    [nativeBannerView.adLabel mas_remakeConstraints:^(MASConstraintMaker *make) {
        make.top.mas_equalTo(nativeBannerView);
        make.right.mas_equalTo(nativeBannerView);
        make.height.mas_equalTo(30);
        make.width.mas_equalTo(50);
    }];
    
    // 获取广告平台logo原始对象，可能获取到"广告"字样的视图，这是因为部分平台的 logo 对象获取失败了。
    id networkLogoView = nativeBannerView.netWorkOptionView;
    // SDK>= 6.4.92 布局广告平台的logo,可能无法正确获取，或者其内容不符合预期，因此需要判断。请注意仍然不能保证平台的logo正常显示，因此建议至少兜底显示adLabel对象
    if (networkLogoView && ([networkLogoView isKindOfClass:UIImageView.class]) && ((UIImageView *)networkLogoView).image) {
        nativeBannerView.adLabel.hidden = YES;
        
        [nativeBannerView.netWorkOptionView mas_remakeConstraints:^(MASConstraintMaker *make) {
            make.top.mas_equalTo(nativeBannerView);
            make.right.mas_equalTo(nativeBannerView);
            make.height.mas_equalTo(30);
            make.width.mas_equalTo(50);
        }];
        
        [nativeBannerView bringSubviewToFront:nativeBannerView.netWorkOptionView];
    }
  
    // 添加点击注册控件
    NSMutableArray *regisArray = [NSMutableArray array];
    if (nativeBannerView.textLabel) {
        [regisArray addObject:nativeBannerView.textLabel];
    }
    
    if (nativeBannerView.titleLabel) {
        [regisArray addObject:nativeBannerView.titleLabel];
    }
    [nativeBannerView registerClickableViewArray:regisArray];
}
4. UI元素列表
对于建议渲染的组件，如果您选择不渲染，需要确认该广告平台的展示曝光回调是否正常触发。

API元素	类型	是否渲染	渲染要求说明
titleLabel (对应title)	UILabel	建议渲染	广告标题，建议显示
textLabel (对应mainText)	UILabel	可选	广告描述文字，根据UI空间决定
ctaLabel (对应ctaText)	UILabel	可选	行动号召按钮文字
advertiserLabel (对应advertiser)	UILabel	条件必选	使用Yandex平台时必须渲染
iconImageView (对应iconUrl/icon)	UIImageView	建议渲染	广告图标，建议显示
logoImageView	UIImageView	条件必选	6.4.92版本以上改用netWorkOptionView，请参考netWorkOptionView字段说明
mainImageView (对应imageUrl/mainImage)	UIImageView	建议渲染	不渲染需确认展示曝光回调
adImageView	UIImageView	建议渲染	广告"Ad"标识图片
ratingLabel (对应rating)	UILabel	可选	评分信息
sponsorLabel	UILabel	可选	赞助商信息
domainLabel (对应domain)	UILabel	条件必选	仅Yandex平台必须渲染
warningLabel (对应warning)	UILabel	条件必选	仅Yandex平台必须渲染
dislikeButton	UIButton	建议渲染	通用关闭按钮，建议保留
netWorkMediaView (对应videoUrl)	UIView	建议渲染	视频广告时建议添加，不渲染需确认展示曝光回调
netWorkMediaBackView	UIView	可选	媒体视图的背景，当没有MediaView和主图mainImageView时，才会创建这个视图
netWorkOptionView	UIView	建议渲染	广告平台logo视图，如果不为空，建议渲染，同时不建议隐藏adLabel，因为即使本字段有值也可能没有图片
adLabel	UILabel	默认渲染	"广告"字样标识，用于兜底无法获取广告平台 logo 图片或者 logo view 对象的情况，不建议隐藏