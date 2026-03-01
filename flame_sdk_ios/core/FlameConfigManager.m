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
@end

@implementation FlameConfigManager

+ (instancetype)sharedInstance {
    static FlameConfigManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[FlameConfigManager alloc] init];
    });
    return instance;
}

- (void) clearCache{
    // 1. 清内存态
    self.appEntity = nil;

    // 2. 清本地存储
    FlameConfigLocalStorage *storage = [[FlameConfigLocalStorage alloc] init];
    [storage clear];

    [FlameLogger i:@"FlameConfigManager clearCache finished"];
}


- (void)updateAppWithAppId:(NSString *)appId appKey:(NSString *)appKey callback:(id<FlameCallback>)callback {
    FlameConfigLocalStorage *storage = [[FlameConfigLocalStorage alloc] init];
    NSString *aId = [storage getAId];
    NSString *aKey = [storage getAKey];
    id pMapObj = [storage getPMap];
    
    NSDictionary *pMap = nil;
    if ([pMapObj isKindOfClass:[NSDictionary class]]) {
        pMap = (NSDictionary *)pMapObj;
    }

    if (aId.length > 0 && aKey.length > 0 && pMap.count > 0) {
        [FlameLogger i:@"load ad from local cache......"];
        
        self.appEntity = [[FlameAppEntity alloc] init];
        self.appEntity.aId = aId;
        self.appEntity.aKey = aKey;
        [self.appEntity.pIds addEntriesFromDictionary:pMap];
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
        self.appEntity = [FlameAppEntity fromJson:decryptJson];
        if (self.appEntity) {
            [storage putWithPt:self.appEntity.pt
                           aId:self.appEntity.aId
                          aKey:self.appEntity.aKey
                          pMap:self.appEntity.pIds];
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
    return self.appEntity ? self.appEntity.aId : @"";
}

- (NSString *)getAKey {
    return self.appEntity ? self.appEntity.aKey : @"";
}

- (NSString *)getPId:(NSString *)flamePlacementId {
    return self.appEntity.pIds[flamePlacementId];
}

- (NSString *)getSdkVersion {
    return FLAME_SDK_VERSION;
}

@end
