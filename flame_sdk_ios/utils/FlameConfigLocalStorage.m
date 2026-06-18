/**
 * @author flame
 */

#import "FlameConfigLocalStorage.h"

static NSString *const SCOPE = @"flame_sdk_conf";
static NSString *const KEY_PT = @"pt";
static NSString *const KEY_APP_ID = @"aId";
static NSString *const KEY_APP_KEY = @"aKey";
static NSString *const KEY_PLACEMENT_MAP = @"pMap";
static NSString *const KEY_CV = @"cv";
static NSString *const KEY_CACHED_AT = @"cachedAt";

@interface FlameConfigLocalStorage ()

@property (nonatomic, strong) NSUserDefaults *userDefaults;

@end

@implementation FlameConfigLocalStorage

+ (instancetype)sharedInstance {
    static FlameConfigLocalStorage *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // 直接调用父类的 allocWithZone: 避免递归
        instance = [[super allocWithZone:NULL] init];
    });
    return instance;
}

// 移除复杂的单例防护，简化实现

- (instancetype)init {
    self = [super init];
    if (self) {
        // iOS中使用NSUserDefaults模拟SharedPreferences，通过suiteName实现隔离
        self.userDefaults = [[NSUserDefaults alloc] initWithSuiteName:SCOPE];
    }
    return self;
}

- (NSString *)getPt {
    return [self.userDefaults stringForKey:KEY_PT];
}

- (NSString *)getAId {
    return [self.userDefaults stringForKey:KEY_APP_ID];
}

- (NSString *)getAKey {
    return [self.userDefaults stringForKey:KEY_APP_KEY];
}

- (NSDictionary<NSString *, NSString *> *)getPMap {
    NSString *json = [self.userDefaults stringForKey:KEY_PLACEMENT_MAP];
    if (!json) {
        return nil;
    }
    
    NSMutableDictionary *map = [NSMutableDictionary dictionary];
    NSArray *entries = [json componentsSeparatedByString:@"&"];
    for (NSString *entry in entries) {
        NSArray *keyValue = [entry componentsSeparatedByString:@"="];
        if (keyValue.count == 2) {
            [map setObject:keyValue[1] forKey:keyValue[0]];
        }
    }
    return [map copy];
}

- (NSString *)getCV {
    return [self.userDefaults stringForKey:KEY_CV];
}

- (NSTimeInterval)getCachedAt {
    return [self.userDefaults doubleForKey:KEY_CACHED_AT];
}

- (void)putWithPt:(NSString *)pt
              aId:(NSString *)aId
             aKey:(NSString *)aKey
             pMap:(NSDictionary<NSString *, NSString *> *)pMap {

    [self putWithPt:pt aId:aId aKey:aKey pMap:pMap cv:nil cachedAt:0];
}

- (void)putWithPt:(NSString *)pt
              aId:(NSString *)aId
             aKey:(NSString *)aKey
             pMap:(NSDictionary<NSString *, NSString *> *)pMap
                cv:(NSString *)cv
         cachedAt:(NSTimeInterval)cachedAt {

    // 处理pMap序列化
    NSString *p = nil;
    if (pMap && pMap.count > 0) {
        NSMutableArray *pairs = [NSMutableArray array];
        [pMap enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *obj, BOOL *stop) {
            [pairs addObject:[NSString stringWithFormat:@"%@=%@", key, obj]];
        }];
        p = [pairs componentsJoinedByString:@"&"];
    }

    if (pt && pt.length > 0) {
        [self.userDefaults setObject:pt forKey:KEY_PT];
    }
    if (aId && aId.length > 0) {
        [self.userDefaults setObject:aId forKey:KEY_APP_ID];
    }
    if (aKey && aKey.length > 0) {
        [self.userDefaults setObject:aKey forKey:KEY_APP_KEY];
    }
    if (p && p.length > 0) {
        [self.userDefaults setObject:p forKey:KEY_PLACEMENT_MAP];
    }
    if (cv && cv.length > 0) {
        [self.userDefaults setObject:cv forKey:KEY_CV];
    } else {
        [self.userDefaults removeObjectForKey:KEY_CV];
    }
    if (cachedAt > 0) {
        [self.userDefaults setDouble:cachedAt forKey:KEY_CACHED_AT];
    } else {
        [self.userDefaults removeObjectForKey:KEY_CACHED_AT];
    }

    [self.userDefaults synchronize];
}

- (void)clear {
    NSDictionary *dict = [self.userDefaults dictionaryRepresentation];
    for (id key in dict) {
        [self.userDefaults removeObjectForKey:key];
    }
    [self.userDefaults synchronize];
}

@end
