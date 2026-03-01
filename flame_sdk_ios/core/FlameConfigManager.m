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
@property (nonatomic, strong) FlameAppEntity *appEntity;
@property (nonatomic, strong) dispatch_queue_t syncQueue; // 同步队列，保护线程安全
@end

@implementation FlameConfigManager

+ (instancetype)sharedInstance {
    static FlameConfigManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[super allocWithZone:NULL] init];
        // 创建串行队列保护共享数据
        instance.syncQueue = dispatch_queue_create("com.flame.config.sync", DISPATCH_QUEUE_SERIAL);
    });
    return instance;
}

+ (instancetype)allocWithZone:(struct _NSZone *)zone {
    return [self sharedInstance];
}

- (instancetype)copyWithZone:(NSZone *)zone {
    return self;
}

- (void) clearCache{
    dispatch_sync(self.syncQueue, ^{
        // 1. 清内存态
        self.appEntity = nil;
    });

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

        dispatch_sync(self.syncQueue, ^{
            self.appEntity = [[FlameAppEntity alloc] init];
            self.appEntity.aId = aId;
            self.appEntity.aKey = aKey;
            [self.appEntity.pIds addEntriesFromDictionary:pMap];
        });
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
            // 线程安全地更新appEntity
            dispatch_sync(self.syncQueue, ^{
                self.appEntity = entity;
            });

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
    __block NSString *result;
    dispatch_sync(self.syncQueue, ^{
        result = self.appEntity ? self.appEntity.aId : @"";
    });
    return result;
}

- (NSString *)getAKey {
    __block NSString *result;
    dispatch_sync(self.syncQueue, ^{
        result = self.appEntity ? self.appEntity.aKey : @"";
    });
    return result;
}

- (NSString *)getPId:(NSString *)flamePlacementId {
    __block NSString *result;
    dispatch_sync(self.syncQueue, ^{
        result = self.appEntity.pIds[flamePlacementId];
    });
    return result;
}

- (NSString *)getSdkVersion {
    return FLAME_SDK_VERSION;
}

@end
