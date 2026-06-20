//
//  FlameCallback.h
//  FlameSDK
//
//  Created by flame.
//  Copyright © 2026 Flame. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 * Flame 基础回调协议
 */
@protocol FlameCallback <NSObject>

@required

/**
 * 成功回调
 */
- (void)success;

/**
 * 失败回调
 * @param code 错误码
 * @param desc 错误描述
 */
- (void)fail:(NSString *)code desc:(NSString *)desc;

@end
