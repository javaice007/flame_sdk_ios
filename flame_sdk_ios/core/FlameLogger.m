//
//  FlameLogger.m
//  FlameSDK
//
//  Created by flame.
//  Copyright © 2026 Flame. All rights reserved.
//

#import "FlameLogger.h"

static NSString * const TAG = @"FlameSDK";

@implementation FlameLogger

+ (void)d:(NSString *)msg {
    NSLog(@"[%@] ------------------------- Flame SDK Log -------------------------", TAG);
    NSLog(@"[%@] %@", TAG, msg);
    NSLog(@"[%@] ------------------------- Flame SDK Log -------------------------", TAG);
}

+ (void)i:(NSString *)msg {
    NSLog(@"[%@] ------------------------- Flame SDK Log -------------------------", TAG);
    NSLog(@"[%@] %@", TAG, msg);
    NSLog(@"[%@] ------------------------- Flame SDK Log -------------------------", TAG);
}

+ (void)w:(NSString *)msg {
    NSLog(@"[%@] ------------------------- Flame SDK Log -------------------------", TAG);
    NSLog(@"[%@] %@", TAG, msg);
    NSLog(@"[%@] ------------------------- Flame SDK Log -------------------------", TAG);
}

+ (void)e:(NSString *)msg {
    NSLog(@"[%@] ------------------------- Flame SDK Log -------------------------", TAG);
    NSLog(@"[%@] %@", TAG, msg);
    NSLog(@"[%@] ------------------------- Flame SDK Log -------------------------", TAG);
}

@end
