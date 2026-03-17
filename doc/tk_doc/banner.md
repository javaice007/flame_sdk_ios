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