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

// 请求去重：保存当前进行中的网络任务
@property (atomic, strong) NSURLSessionDataTask *currentTask;
// 请求代际标记：completion 回调时校验是否为当前代
@property (atomic, assign) uint64_t requestGeneration;
// 强持有 callback 直到网络请求完成，防止 block 闭包捕获失效导致野指针
@property (atomic, strong) id<FlameCallback> activeCallback;
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
    // 1. 取消进行中的网络请求
    [self cancelCurrentRequest];

    // 2. 清除 callback 强引用（网络请求已取消，不再需要回调）
    @synchronized (self) {
        self.activeCallback = nil;
    }

    // 3. 清内存态
    @synchronized (self) {
        self.appEntity = nil;
    }

    // 4. 清本地存储
    [[FlameConfigLocalStorage sharedInstance] clear];

    [FlameLogger i:@"FlameConfigManager clearCache finished"];
}

- (void)cancelCurrentRequest {
    @synchronized (self) {
        if (self.currentTask) {
            [self.currentTask cancel];
            self.currentTask = nil;
            self.requestGeneration++;
            // 取消请求的同时清除 callback 引用，因为 callback 不会再被调用
            self.activeCallback = nil;
            [FlameLogger i:@"Previous config request cancelled"];
        }
    }
}

- (void)cancelCurrentRequestAndCallback {
    @synchronized (self) {
        if (self.currentTask) {
            [self.currentTask cancel];
            self.currentTask = nil;
            self.requestGeneration++;
        }
        self.activeCallback = nil;
        [FlameLogger i:@"Current request and callback cancelled"];
    }
}


- (void)updateAppWithAppId:(NSString *)appId appKey:(NSString *)appKey callback:(id<FlameCallback>)callback {
    FlameConfigLocalStorage *storage = [FlameConfigLocalStorage sharedInstance];

    // 1. 先读取本地缓存，判断完整性，但不立即返回 success
    //    缓存完整性必须包含 pt + aId + aKey + pMap
    NSString *cachedPt = [storage getPt];
    NSString *cachedAId = [storage getAId];
    NSString *cachedAKey = [storage getAKey];
    id pMapObj = [storage getPMap];

    NSDictionary *cachedPMap = nil;
    if ([pMapObj isKindOfClass:[NSDictionary class]]) {
        cachedPMap = (NSDictionary *)pMapObj;
    }

    BOOL cacheComplete = (cachedPt.length > 0
                          && cachedAId.length > 0
                          && cachedAKey.length > 0
                          && cachedPMap.count > 0);

    if (cacheComplete) {
        [FlameLogger i:[NSString stringWithFormat:@"Local cache exists (pt=%@), will request remote server first", cachedPt]];
    } else {
        [FlameLogger i:@"No complete local cache, will request remote server"];
    }

    // 2. 发起后台 init 请求（每次冷启动优先请求网络）
    [FlameLogger i:@"load ad from remote server......"];

    // 先取消可能残留的旧请求（必须在 generation 递增之前，因为 cancel 内部也会递增 generation）
    [self cancelCurrentRequest];

    // 请求去重：递增 generation，旧请求的 completion 将被忽略
    uint64_t currentGeneration;
    @synchronized (self) {
        self.requestGeneration++;
        currentGeneration = self.requestGeneration;
    }

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

    // 4. 强持有 callback，防止 block 闭包捕获失效导致野指针
    @synchronized (self) {
        self.activeCallback = callback;
    }

    // 5. JSON POST 请求（capture currentGeneration 用于过滤过期回调）
    //    completion block 不直接捕获 callback 参数，而是通过 self.activeCallback 访问，
    //    确保 UpdateAppCallback 的生命周期由 FlameConfigManager 属性管理，不依赖 block 捕获

    NSURLSessionDataTask *task = [FlameNetworkUtils doPostJson:url
                         jsonBody:jsonParams
                       completion:^(NSDictionary *encryptedData, NSError *error) {

        // 请求去重：如果 generation 不匹配，说明已有新请求发出，忽略本次回调
        uint64_t latestGeneration;
        @synchronized (self) {
            latestGeneration = self.requestGeneration;
        }
        if (currentGeneration != latestGeneration) {
            [FlameLogger i:@"Stale config response ignored (generation mismatch)"];
            return;
        }

        // 响应到达，在锁内原子地提取 callback 并清除所有引用
        // 确保 extract + nil 不会被 clear() 线程插入
        // 直接 IVAR 访问：避免 atomic getter 的 objc_autoreleaseReturnValue
        // 在 Debug 模式下产生延迟 autorelease，导致 pool drain 时 over-release
        id<FlameCallback> cb;
        @synchronized (self) {
            cb = _activeCallback;
            self.currentTask = nil;
            self.activeCallback = nil;
        }
        if (!cb) {
            [FlameLogger i:@"Callback was cleared before completion, skipping"];
            return;
        }

        [FlameLogger i:@"server response received"];
        [FlameLogger i:[NSString stringWithFormat:@"[DIAG] ConfigManager extract done. cb=%p RC=%lu, gen=%llu", (void *)cb, (unsigned long)CFGetRetainCount((__bridge CFTypeRef)cb), currentGeneration]];

        // 网络错误处理
        if (error) {
            [FlameLogger e:[NSString stringWithFormat:@"remote server error=%@", error.localizedDescription]];

            // 网络失败 → fallback 完整缓存
            if (cacheComplete) {
                [FlameLogger w:[NSString stringWithFormat:@"Config request failed, fallback to local cache, pt=%@", cachedPt]];

                FlameAppEntity *cachedEntity = [[FlameAppEntity alloc] init];
                cachedEntity.pt = cachedPt;
                cachedEntity.aId = cachedAId;
                cachedEntity.aKey = cachedAKey;
                [cachedEntity.pIds addEntriesFromDictionary:cachedPMap];

                // 读取可选的 cv 和 cachedAt
                cachedEntity.cv = [storage getCV];
                NSTimeInterval ts = [storage getCachedAt];
                if (ts > 0) {
                    cachedEntity.cachedAt = [NSDate dateWithTimeIntervalSince1970:ts];
                }

                @synchronized (self) {
                    self.appEntity = cachedEntity;
                }

                if (cb) {
                    [cb success];
                }
            } else {
                // 网络失败 + 无完整缓存 → 初始化失败
                [FlameLogger e:@"Config request failed and no complete local cache available"];
                if (cb) {
                    [FlameLogger i:[NSString stringWithFormat:@"[DIAG] About to call callback.fail on %p", (void *)cb]];
                    [cb fail:[@(error.code) stringValue]
                      desc:error.localizedDescription];
                    [FlameLogger i:[NSString stringWithFormat:@"[DIAG] callback.fail returned for %p", (void *)cb]];
                }
            }
            return;
        }

        if (![encryptedData isKindOfClass:[NSDictionary class]]) {
            [FlameLogger e:@"server response is not a valid JSON object"];
            if (cb) {
                [cb fail:@"-1" desc:@"Invalid server response format"];
            }
            return;
        }

        // 类型校验: 确保 data 字段存在且为 NSDictionary，过滤 NSNull
        id dataObj = encryptedData[@"data"];
        if (dataObj == nil || [dataObj isKindOfClass:[NSNull class]]) {
            [FlameLogger e:@"data field is missing or null in server response"];
            if (cb) {
                [cb fail:@"-1" desc:@"data is missing from server response"];
            }
            return;
        }

        if (![dataObj isKindOfClass:[NSDictionary class]]) {
            [FlameLogger e:@"data field is not a valid JSON object"];
            if (cb) {
                [cb fail:@"-1" desc:@"Invalid data format in server response"];
            }
            return;
        }

        NSDictionary *dataDict = (NSDictionary *)dataObj;

        // 类型校验: 确保 edata 字段存在且为 NSString，过滤 NSNull
        id eDataObj = dataDict[@"edata"];
        if (eDataObj == nil || [eDataObj isKindOfClass:[NSNull class]]) {
            if (cb) {
                [cb fail:@"-1"
                  desc:@"edata is missing from server response"];
            }
            return;
        }

        if (![eDataObj isKindOfClass:[NSString class]]) {
            if (cb) {
                [cb fail:@"-1"
                  desc:@"edata is not a valid string in server response"];
            }
            return;
        }

        NSString *eData = (NSString *)eDataObj;
        if (eData.length == 0) {
            if (cb) {
                [cb fail:@"-1"
                  desc:@"edata is empty in server response"];
            }
            return;
        }
        // 5. AES 解密（保持不变）
        NSString *decryptJson = [FlameAesCryptoUtils decrypt:eData rawKey:appKey];
        [FlameLogger i:@"config data decrypted successfully"];

        FlameAppEntity *entity = [FlameAppEntity fromJson:decryptJson];
        if (entity) {
            // 线程安全地更新appEntity，使用 @synchronized
            @synchronized (self) {
                self.appEntity = entity;
            }

            // 网络成功 → 使用最新配置，更新缓存（含 cv 和 cachedAt）
            NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
            [storage putWithPt:entity.pt
                           aId:entity.aId
                          aKey:entity.aKey
                          pMap:entity.pIds
                             cv:entity.cv
                      cachedAt:now];
            entity.cachedAt = [NSDate dateWithTimeIntervalSince1970:now];
            if (cb) {
                [cb success];
            }
        } else {
            if (cb) {
                [cb fail:@"-1" desc:@"Decrypt or Parse failed"];
            }
        }
    }];

    // 存储任务引用，以便 clearCache/cancelCurrentRequest 时可以取消
    @synchronized (self) {
        self.currentTask = task;
    }
}

- (NSString *)getPt {
    return self.appEntity ? self.appEntity.pt : nil;
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
