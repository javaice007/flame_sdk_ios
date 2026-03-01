/**
 * @author flame
 */

#import "FlameConfigLocalStorage.h"

static NSString *const SCOPE = @"flame_sdk_conf";
static NSString *const KEY_PT = @"pt";
static NSString *const KEY_APP_ID = @"aId";
static NSString *const KEY_APP_KEY = @"aKey";
static NSString *const KEY_PLACEMENT_MAP = @"pMap";

@interface FlameConfigLocalStorage ()

@property (nonatomic, strong) NSUserDefaults *userDefaults;

@end

@implementation FlameConfigLocalStorage

+ (instancetype)sharedInstance {
    static FlameConfigLocalStorage *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[super allocWithZone:NULL] init];
        // iOS中使用NSUserDefaults模拟SharedPreferences，通过suiteName实现隔离
        instance.userDefaults = [[NSUserDefaults alloc] initWithSuiteName:SCOPE];
    });
    return instance;
}

+ (instancetype)allocWithZone:(struct _NSZone *)zone {
    return [self sharedInstance];
}

- (instancetype)copyWithZone:(NSZone *)zone {
    return self;
}

- (instancetype)init {
    return [FlameConfigLocalStorage sharedInstance];
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

- (void)putWithPt:(NSString *)pt
              aId:(NSString *)aId
             aKey:(NSString *)aKey
             pMap:(NSDictionary<NSString *, NSString *> *)pMap {
    
    // 处理pMap序列化
    NSMutableArray *pairs = [NSMutableArray array];
    [pMap enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *obj, BOOL *stop) {
        [pairs addObject:[NSString stringWithFormat:@"%@=%@", key, obj]];
    }];
    NSString *p = [pairs componentsJoinedByString:@"&"];
    
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
