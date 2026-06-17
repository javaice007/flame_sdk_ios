//
//  FlameMediationRegistry.m
//  FlameSDK
//
//  Created by flame.
//  Copyright © 2026 Flame. All rights reserved.
//

#import "FlameMediationRegistry.h"
#import "FlameLogger.h"

/// 平台标识字符串常量（可选，用于统一管理）
// static NSString * const kFlamePlatformTK = @"tk";
// static NSString * const kFlamePlatformTB = @"tb";

@interface FlameMediationRegistry ()

/// Provider 注册表，key = platformCode (NSString), value = id<FlameMediationProvider>
@property (nonatomic, strong) NSMutableDictionary<NSString *, id<FlameMediationProvider>> *providers;

@end

@implementation FlameMediationRegistry

#pragma mark - Singleton

+ (instancetype)sharedRegistry {
    static FlameMediationRegistry *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[FlameMediationRegistry alloc] init];
    });
    return instance;
}

- (instancetype)init {
    if (self = [super init]) {
        _providers = [[NSMutableDictionary alloc] init];
    }
    return self;
}

#pragma mark - Register / Unregister

- (void)registerProvider:(id<FlameMediationProvider>)provider {
    if (!provider) {
        [FlameLogger e:@"FlameMediationRegistry: provider 不能为 nil"];
        return;
    }

    NSString *code = [provider platformCode];
    if (!code || code.length == 0) {
        [FlameLogger e:@"FlameMediationRegistry: provider.platformCode 不能为空"];
        return;
    }

    @synchronized (self.providers) {
        id<FlameMediationProvider> existing = self.providers[code];
        if (existing) {
            // 同一 platformCode 重复注册：后注册的覆盖先注册的
            [FlameLogger w:[NSString stringWithFormat:
                @"FlameMediationRegistry: 平台 '%@' 已注册，将被覆盖", code]];
        }
        self.providers[code] = provider;
        [FlameLogger d:[NSString stringWithFormat:
            @"FlameMediationRegistry: 注册平台 '%@'", code]];
    }
}

- (void)unregisterProviderForPlatformCode:(NSString *)platformCode {
    if (!platformCode || platformCode.length == 0) {
        [FlameLogger e:@"FlameMediationRegistry: platformCode 不能为空"];
        return;
    }

    @synchronized (self.providers) {
        [self.providers removeObjectForKey:platformCode];
        [FlameLogger d:[NSString stringWithFormat:
            @"FlameMediationRegistry: 注销平台 '%@'", platformCode]];
    }
}

#pragma mark - Query

- (id<FlameMediationProvider>)providerForPlatformCode:(NSString *)platformCode {
    if (!platformCode || platformCode.length == 0) {
        return nil;
    }

    @synchronized (self.providers) {
        return self.providers[platformCode];
    }
}

- (BOOL)hasProviderForPlatformCode:(NSString *)platformCode {
    if (!platformCode || platformCode.length == 0) {
        return NO;
    }

    @synchronized (self.providers) {
        return self.providers[platformCode] != nil;
    }
}

- (NSArray<NSString *> *)allRegisteredPlatformCodes {
    @synchronized (self.providers) {
        return [self.providers.allKeys copy];
    }
}

#pragma mark - Clear

- (void)clear {
    @synchronized (self.providers) {
        [self.providers removeAllObjects];
        [FlameLogger d:@"FlameMediationRegistry: 已清除所有 Provider"];
    }
}

@end
