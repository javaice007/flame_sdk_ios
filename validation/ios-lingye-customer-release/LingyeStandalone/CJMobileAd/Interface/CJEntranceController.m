//
//  CJEntranceController.m
//  CJMobileAdDemo
//
//  Created by JJ on 2022/12/1.
//

#import "CJEntranceController.h"
#import "CJMobilePublic.h"
#import "CJEntranceCell.h"
#import "CJEntranceHeaderView.h"
#import <CJMobileAd/CJSceneManager.h>

@interface CJEntranceController ()<UICollectionViewDataSource, UICollectionViewDelegate>

@property (nonatomic, strong) UICollectionView *collectionView;
@property (nonatomic, strong) NSArray *modules;

@end

@implementation CJEntranceController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.modules = @[
        @{@"key": @"基础广告",
          @"values": @[@"开屏",@"插屏",@"Banner",@"激励视频",@"全屏视频",@"信息流", @"自渲染", @"ICON"],
          @"classNames": @[@"SplashVC", @"InterstitialVC", @"BannerVC", @"RewardVideoVC", @"FullscreenVC",@"NativeViewController", @"FeedNativeAdController", @"IConController"]},
        @{@"key": @"场景板块",
          @"values": @[@"星座运势",@"那年今日",@"今日油价",@"性格测试",@"成语答题", @"新闻资讯", @"H5小游戏"],
          @"sceneType": @[@(CJSceneRequestHoroscope), @(CJSceneRequestHistory), @(CJSceneRequestOilPrice), @(CJSceneRequestPersonalityTest), @(CJSceneRequestIdiomGame), @(CJSceneRequestNews), @(CJSceneRequestReferenceGame)]
        }
    ];
    [self setupUI];
}


- (void)setupUI {
    self.title = @"iOS广告对接Demo";
    self.view.backgroundColor = [UIColor whiteColor];
    [self.view addSubview:self.collectionView];
}

#pragma mark lazy load
- (UICollectionView *)collectionView {
    if (!_collectionView) {
        UICollectionViewFlowLayout *flowlayout = [[UICollectionViewFlowLayout alloc] init];
        flowlayout.itemSize = CGSizeMake((jScreenW-8-32)/2, 44);
        flowlayout.scrollDirection = UICollectionViewScrollDirectionVertical;
        flowlayout.minimumLineSpacing = 16;
        flowlayout.minimumInteritemSpacing = 8;
        flowlayout.headerReferenceSize = CGSizeMake(jScreenW, 64);
        _collectionView = [[UICollectionView alloc] initWithFrame:self.view.bounds collectionViewLayout:flowlayout];
        _collectionView.contentInset = UIEdgeInsetsMake(0, 16, 0, 16);
        _collectionView.backgroundColor = [UIColor whiteColor];
        _collectionView.delegate = self;
        _collectionView.dataSource = self;
        [_collectionView registerClass:[CJEntranceHeaderView class] forSupplementaryViewOfKind:UICollectionElementKindSectionHeader withReuseIdentifier:@"CJEntranceHeaderView"];
        [_collectionView registerClass:[CJEntranceCell class] forCellWithReuseIdentifier:@"CJEntranceCell"];
    }
    return _collectionView;
}

- (NSArray *)_modules {
    if (!_modules) {
        _modules = [NSArray new];
    }
    return _modules;
}

#pragma mark UICollectionViewDataSource UICollectionViewDelegate
- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    if ([self.modules[section] valueForKey:@"values"]) {
        NSArray *values = (NSArray *)self.modules[section][@"values"];
        return values.count;
    }
    return 0;
}

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
    return self.modules.count;
}

- (__kindof UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    CJEntranceCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"CJEntranceCell" forIndexPath:indexPath];
    NSString *contentText = (NSString *)self.modules[indexPath.section][@"values"][indexPath.row];
    [cell setText:contentText];
    return cell;
}


- (UICollectionReusableView *)collectionView:(UICollectionView *)collectionView viewForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath {
    if ([kind isEqualToString:UICollectionElementKindSectionHeader] ) {
        CJEntranceHeaderView *header = [collectionView dequeueReusableSupplementaryViewOfKind:kind withReuseIdentifier:@"CJEntranceHeaderView" forIndexPath:indexPath];
        NSString *headerTitle = (NSString *)self.modules[indexPath.section][@"key"];
        [header setTitle:headerTitle];
        return header;
    }
    return [UICollectionReusableView new];
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) {
        NSString *className = self.modules[0][@"classNames"][indexPath.row];
        [self jumpPage:className];
        return;
    }
    CJSceneRequestType scene = [self.modules[1][@"sceneType"][indexPath.row] intValue];
    [self jumpPageToModuleScene:scene];
}

// 基础广告位
- (void)jumpPage:(NSString *)className {
    Class pageClass = NSClassFromString(className);
    if (pageClass) {
        UIViewController *controller = [pageClass new];
        [self.navigationController pushViewController:controller animated:true];
        return;
    }
}

// 场景广告位
- (void)jumpPageToModuleScene:(CJSceneRequestType)scene {
    CJSceneRequest *request = [[CJSceneRequest alloc] init];
    if (scene == CJSceneRequestPersonalityTest) {
        request.spacing = 1;
    }
    if (scene == CJSceneRequestNews) {
        request.readTime = 15;
        request.readCount = 3;
    }
    request.scene = scene;
    // 可自由配置展示广告
    request.interstitialId = intersititialId;
    request.rewardId = rewardVideoId;
    request.nativeTemplateId = nativeId;
    request.rootViewController = self;
    request.rewardVideoEventCallback = ^(CJSceneRewardVideoEventType type, NSDictionary * _Nonnull params) {
        NSString *eventString = @"未知事件";
        switch (type) {
            case CJSceneRewardVideoEventOnShow:
                eventString = @"已经展示(onShow)";
                break;
            case CJSceneRewardVideoEventOnReward:
                eventString = @"已达成奖励(onReward)";
                break;
            case CJSceneRewardVideoEventOnError:
                eventString = @"发生错误(onError)";
                break;
            case CJSceneRewardVideoEventOnClose:
                eventString = @"激励视频关闭(onClose)";
                break;
            case CJSceneRewardVideoEventOnClick:
                eventString = @"激励视频点击(onClick)";
                break;
            default:
                break;
        }
        NSLog(@"eventCallbackWithName:%@ params:%@", eventString, params);
    };
    [CJSceneManager loadAndShowModuleWithSceneRequest:request];
}

@end
