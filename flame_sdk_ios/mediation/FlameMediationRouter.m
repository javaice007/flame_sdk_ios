//
//  FlameMediationRouter.m
//  FlameSDK
//
//  Created by flame.
//  Copyright © 2026 Flame. All rights reserved.
//

#import "FlameMediationRouter.h"
#import "FlameLogger.h"

@interface FlameMediationRouter ()

/// 当前激活的 Provider（strong 持有，避免提前释放）
@property (nonatomic, strong) id<FlameMediationProvider> currentProviderInternal;

/// 当前平台标识
@property (nonatomic, copy) NSString *currentPlatformCodeInternal;

@end

@implementation FlameMediationRouter

#pragma mark - Singleton

+ (instancetype)sharedRouter {
    static FlameMediationRouter *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[FlameMediationRouter alloc] init];
    });
    return instance;
}

- (instancetype)init {
    if (self = [super init]) {
        _currentProviderInternal = nil;
        _currentPlatformCodeInternal = nil;
    }
    return self;
}

#pragma mark - Activate

- (void)activateProvider:(id<FlameMediationProvider>)provider {
    if (!provider) {
        [FlameLogger e:@"FlameMediationRouter: provider 不能为 nil"];
        return;
    }

    NSString *code = [provider platformCode];
    if (!code || code.length == 0) {
        [FlameLogger e:@"FlameMediationRouter: provider.platformCode 不能为空"];
        return;
    }

    @synchronized (self) {
        _currentProviderInternal = provider;
        _currentPlatformCodeInternal = [code copy];
        [FlameLogger d:[NSString stringWithFormat:
            @"FlameMediationRouter: 激活平台 '%@'", code]];
    }
}

#pragma mark - Query

- (id<FlameMediationProvider>)currentProvider {
    @synchronized (self) {
        return _currentProviderInternal;
    }
}

- (NSString *)currentPlatformCode {
    @synchronized (self) {
        return _currentPlatformCodeInternal;
    }
}

- (BOOL)hasActiveProvider {
    @synchronized (self) {
        return _currentProviderInternal != nil;
    }
}

#pragma mark - Clear

- (void)clear {
    @synchronized (self) {
        _currentProviderInternal = nil;
        _currentPlatformCodeInternal = nil;
        [FlameLogger d:@"FlameMediationRouter: 已重置"];
    }
}

@end
