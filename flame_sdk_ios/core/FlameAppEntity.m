//
//  FlameAppEntity.m
//  FlameSDK
//
//  Created by flame.
//

#import "FlameAppEntity.h"

@implementation FlameAppEntity

- (instancetype)init {
    self = [super init];
    if (self) {
        _pIds = [NSMutableDictionary dictionary];
    }
    return self;
}

+ (instancetype)fromJson:(NSString *)jsonStr {
    if (!jsonStr) return nil;
    NSData *data = [jsonStr dataUsingEncoding:NSUTF8StringEncoding];
    if (!data) return nil;
    NSError *error;
    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
    if (error || !json || ![json isKindOfClass:[NSDictionary class]]) return nil;

    FlameAppEntity *entity = [[FlameAppEntity alloc] init];

    // 类型校验 + NSNull 过滤
    id ptObj = json[@"pt"];
    entity.pt = ([ptObj isKindOfClass:[NSString class]] && ![ptObj isKindOfClass:[NSNull class]]) ? (NSString *)ptObj : nil;

    id aIdObj = json[@"aId"];
    entity.aId = ([aIdObj isKindOfClass:[NSString class]] && ![aIdObj isKindOfClass:[NSNull class]]) ? (NSString *)aIdObj : nil;

    id aKeyObj = json[@"aKey"];
    entity.aKey = ([aKeyObj isKindOfClass:[NSString class]] && ![aKeyObj isKindOfClass:[NSNull class]]) ? (NSString *)aKeyObj : nil;

    NSDictionary *pIdsDict = json[@"pIds"];
    if ([pIdsDict isKindOfClass:[NSDictionary class]]) {
        // 过滤 NSNull 值
        NSMutableDictionary *safePIds = [NSMutableDictionary dictionary];
        [pIdsDict enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
            if ([obj isKindOfClass:[NSString class]] && ![obj isKindOfClass:[NSNull class]]) {
                safePIds[key] = obj;
            }
        }];
        [entity.pIds addEntriesFromDictionary:safePIds];
    }

    // cv 为可选字段
    id cvObj = json[@"cv"];
    entity.cv = ([cvObj isKindOfClass:[NSString class]] && ![cvObj isKindOfClass:[NSNull class]]) ? (NSString *)cvObj : nil;

    // cachedAt 不从网络 JSON 解析，仅在缓存构建时写入

    return entity;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"AppEntity{pt='%@', aId='%@', aKey='%@', pIds=%@, cv='%@', cachedAt=%@}",
            self.pt, self.aId, self.aKey, self.pIds, self.cv, self.cachedAt];
}

@end
