//
//  FlameConfigManager.m
//  FlameSDK
//
//  Created by flame.
//

#import "FlameConfigManager.h"
#import "FlameAppEntity.h"
#import "FlameConfigLocalStorage.h"
#import "FlameLogger.h"
#import "FlameUrlParamUtil.h"
#import "FlameMd5SignatureUtils.h"
#import "FlameNetworkUtils.h"
#import "FlameAesCryptoUtils.h"

static NSString * const FLAME_SDK_VERSION = @"1.0.0";

@interface FlameConfigManager ()
@property (atomic, strong) FlameAppEntity *appEntity; // 使用 atomic 保证线程安全
@end

@implementation FlameConfigManager

+ (instancetype)sharedInstance {
    static FlameConfigManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // 直接调用父类的 allocWithZone: 避免递归
        instance = [[super allocWithZone:NULL] init];
    });
    return instance;
}

// 移除 allocWithZone: 重写，避免递归问题
// 如果外部代码直接使用 [[FlameConfigManager alloc] init]，会创建新实例
// 但这是可以接受的，因为我们在文档中明确要求使用 sharedInstance

- (instancetype)init {
    self = [super init];
    if (self) {
        // 初始化代码
    }
    return self;
}

- (void) clearCache{
    // 使用 @synchronized 保护临界区，简单可靠
    @synchronized (self) {
        // 1. 清内存态
        self.appEntity = nil;
    }

    // 2. 清本地存储
    [[FlameConfigLocalStorage sharedInstance] clear];

    [FlameLogger i:@"FlameConfigManager clearCache finished"];
}


- (void)updateAppWithAppId:(NSString *)appId appKey:(NSString *)appKey callback:(id<FlameCallback>)callback {
    FlameConfigLocalStorage *storage = [FlameConfigLocalStorage sharedInstance];
    NSString *aId = [storage getAId];
    NSString *aKey = [storage getAKey];
    id pMapObj = [storage getPMap];
    
    NSDictionary *pMap = nil;
    if ([pMapObj isKindOfClass:[NSDictionary class]]) {
        pMap = (NSDictionary *)pMapObj;
    }

    if (aId.length > 0 && aKey.length > 0 && pMap.count > 0) {
        [FlameLogger i:@"load ad from local cache......"];

        @synchronized (self) {
            self.appEntity = [[FlameAppEntity alloc] init];
            self.appEntity.aId = aId;
            self.appEntity.aKey = aKey;
            [self.appEntity.pIds addEntriesFromDictionary:pMap];
        }
        if (callback) [callback success];
        return;
    }
    
    [FlameLogger i:@"load ad from remote server......"];
    
    NSString *url = @"https://api.adsurge.cn/api/v1/sdk/init";
    // 1. 业务参数
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    params[@"appId"] = appId;
    params[@"version"] = FLAME_SDK_VERSION;
    params[@"timestamp"] = @((long long)([[NSDate date] timeIntervalSince1970] * 1000));
    // 2. 生成签名（签名逻辑保持不变）
    NSString *sign = [FlameMd5SignatureUtils signWithParams:params appKey:appKey];
    // 3. JSON 参数（新增 sign 字段）
    NSMutableDictionary *jsonParams = [params mutableCopy];
    jsonParams[@"sign"] = sign;
//    [FlameLogger i:[NSString stringWithFormat:@"request json params = %@", jsonParams]];
    
    // 4. JSON POST 请求
    [FlameNetworkUtils doPostJson:url
                         jsonBody:jsonParams
                       completion:^(NSDictionary *encryptedData, NSError *error) {
        [FlameLogger i:[NSString stringWithFormat:@"server response = %@", encryptedData]];
        if (error) {
            [FlameLogger e:[NSString stringWithFormat:@"remote server error=%@", error.localizedDescription]];
            if (callback) {
                [callback fail:[@(error.code) stringValue]
                          desc:error.localizedDescription];
            }
            return;
        }
        NSDictionary *dataDict = encryptedData[@"data"];
        NSString *eData = dataDict[@"edata"];
        if (eData == nil || eData.length == 0) {
            if (callback) {
                [callback fail:@"-1"
                          desc:@"edata is missing from server response"];
            }
            return;
        }
        // 5. AES 解密（保持不变）
        NSString *decryptJson = [FlameAesCryptoUtils decrypt:eData rawKey:appKey];
        [FlameLogger i:[NSString stringWithFormat:@"decrypt json = %@", decryptJson]];

        FlameAppEntity *entity = [FlameAppEntity fromJson:decryptJson];
        if (entity) {
            // 线程安全地更新appEntity，使用 @synchronized
            @synchronized (self) {
                self.appEntity = entity;
            }

            [storage putWithPt:entity.pt
                           aId:entity.aId
                          aKey:entity.aKey
                          pMap:entity.pIds];
            if (callback) {
                [callback success];
            }
        } else {
            if (callback) {
                [callback fail:@"-1" desc:@"Decrypt or Parse failed"];
            }
        }
    }];
}

- (NSString *)getAId {
    // atomic 属性本身已经是线程安全的，直接读取即可
    return self.appEntity ? self.appEntity.aId : @"";
}

- (NSString *)getAKey {
    // atomic 属性本身已经是线程安全的，直接读取即可
    return self.appEntity ? self.appEntity.aKey : @"";
}

- (NSString *)getPId:(NSString *)flamePlacementId {
    // 使用局部变量避免多次访问 atomic 属性
    FlameAppEntity *entity = self.appEntity;
    return entity.pIds[flamePlacementId];
}

- (NSString *)getSdkVersion {
    return FLAME_SDK_VERSION;
}

@end
