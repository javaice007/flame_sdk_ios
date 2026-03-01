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
    NSError *error;
    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
    if (error || !json) return nil;

    FlameAppEntity *entity = [[FlameAppEntity alloc] init];
    entity.pt = json[@"pt"];
    entity.aId = json[@"aId"];
    entity.aKey = json[@"aKey"];
    NSDictionary *pIdsDict = json[@"pIds"];
    if ([pIdsDict isKindOfClass:[NSDictionary class]]) {
        [entity.pIds addEntriesFromDictionary:pIdsDict];
    }
    return entity;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"AppEntity{pt='%@', aId='%@', aKey='%@', pIds=%@}", self.pt, self.aId, self.aKey, self.pIds];
}

@end
