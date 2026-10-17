//
//  NativeViewController.m
//  CJModileAdDemo
//
//  Created by CJ on 2022/3/7.
//

#import "NativeViewController.h"
#import <CJMobileAd/CJMobileAd.h>
#import "CJMobilePublic.h"

@interface NativeViewController ()<CJNativeAdDelegate, UITableViewDelegate, UITableViewDataSource>

@property (nonatomic, strong) CJNativeAd *nativeAd;

@property (nonatomic, strong) UITableView *tableView;

@property (nonatomic, strong) NSMutableArray <UIView *>*nativeAdViews;

@end

@implementation NativeViewController

@synthesize customView = _customView;

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setupUI];
}

- (void)dealloc
{
    NSLog(@"the page of native delloc");
}

- (void)setupUI {
    self.title = @"Native";
    [self.view addSubview:self.customView];
    [self.view addSubview:self.tableView];
    self.customView.frame = CGRectMake(0, 100, 200, 200);
    self.customView.center = self.view.center;
    self.tableView.frame = self.view.bounds;
}

- (void)loadAdData {
    self.nativeAd = [[CJNativeAd alloc] initWithSlotId:nativeId size:CGSizeMake([UIScreen mainScreen].bounds.size.width, 0) rootViewController:self];
    self.nativeAd.delegate = self;
    [self.nativeAd loadAdData:3];
}

- (void)handleEvent:(NSInteger)eve {
    if (eve == 0) {
        [self loadAdData];
        return;
    }
    self.tableView.hidden = false;
    [self.tableView reloadData];
}

- (CustomShowView *)customView {
    if (!_customView) {
        _customView = [[CustomShowView alloc] init];
        __weak NativeViewController *weakSelf = self;
        _customView.event = ^(NSInteger eve) {
            [weakSelf handleEvent:eve];
        };
    }
    return _customView;
}

- (NSMutableArray<UIView *> *)nativeAdViews {
    if (!_nativeAdViews) {
        _nativeAdViews = [NSMutableArray new];
    }
    return _nativeAdViews;
}


- (UITableView *)tableView {
    if (!_tableView) {
        _tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
        _tableView.delegate = self;
        _tableView.dataSource = self;
        _tableView.hidden = true;
        _tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
        [_tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:UITableViewCell.description];
    }
    return _tableView;
}


#pragma mark delegate datasource
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.nativeAdViews.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:UITableViewCell.description];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    [cell.contentView addSubview:self.nativeAdViews[indexPath.row]];
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return self.nativeAdViews[indexPath.row].frame.size.height;
}

#pragma mark CJNativeAdDelegate
- (void)nativeExpressAdDidLoad:(id)nativeExpressAd views:(NSArray *)nativeExpressViews {
    NSLog(@"load success");
    [self.customView canShowStatus:true errorMsg:@""];
    [self.nativeAdViews addObjectsFromArray:nativeExpressViews];
}

- (void)nativeExpressAdDidRender:(id)nativeExpressView {
    NSLog(@"render success");
    if ([self.nativeAdViews containsObject:nativeExpressView]) {
        [self.tableView reloadData];
    }
}

- (void)nativeExpressAdLoadFailed:(id)nativeExpressAd error:(NSError *)error {
    NSLog(@"Failed to load or render of error: %@", error);
    [self.customView canShowStatus:false errorMsg:error.description];
}

- (void)nativeExpressAdOnClicked:(id)nativeExpressView {
    NSLog(@"click on the event");
}

- (void)nativeExpressAdOnClosed:(id)nativeExpressView {
    NSLog(@"close on the event");
    if ([self.nativeAdViews containsObject:nativeExpressView]) {
        [nativeExpressView removeFromSuperview];
        [self.nativeAdViews removeObject:nativeExpressView];
        [self.tableView reloadData];
    }
}

@end
