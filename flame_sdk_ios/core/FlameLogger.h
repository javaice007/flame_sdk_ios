//
//  FlameLogger.h
//  FlameSDK
//
//  Created by flame.
//  Copyright © 2026 Flame. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface FlameLogger : NSObject

/**
 * 调试日志
 * @param msg 日志内容
 */
+ (void)d:(NSString *)msg;

/**
 * 信息日志
 * @param msg 日志内容
 */
+ (void)i:(NSString *)msg;

/**
 * 警告日志
 * @param msg 日志内容
 */
+ (void)w:(NSString *)msg;

/**
 * 错误日志
 * @param msg 日志内容
 */
+ (void)e:(NSString *)msg;

@end
