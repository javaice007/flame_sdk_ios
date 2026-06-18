//
//  FlameAppEntity.h
//  FlameSDK
//
//  Created by flame.
//  Copyright © 2026 Flame. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface FlameAppEntity : NSObject

@property (nonatomic, copy) NSString *pt;
@property (nonatomic, copy) NSString *aId;
@property (nonatomic, copy) NSString *aKey;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSString *> *pIds;
@property (nonatomic, copy) NSString *cv;
@property (nonatomic, strong) NSDate *cachedAt;

+ (instancetype)fromJson:(NSString *)jsonStr;

@end
