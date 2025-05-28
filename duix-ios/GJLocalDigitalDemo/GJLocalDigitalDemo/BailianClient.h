//
//  BailianClient.h
//  GJLocalDigitalDemo
//
//  Created by 李文浩 on 2025/5/28.
//

#import <Foundation/Foundation.h>

@interface QianwenClient : NSObject

+ (instancetype)sharedInstance;

- (void)chatWithMessage:(NSString *)message
             completion:(void(^)(NSString *response, NSError *error))completion;

@end
