//
//  ChatMessage.m
//  GJLocalDigitalDemo
//
//  Created by 李文浩 on 2025/5/28.
//

#import "ChatMessage.h"

@implementation ChatMessage

+ (instancetype)messageWithContent:(NSString *)content type:(ChatMessageType)type {
    ChatMessage *message = [[ChatMessage alloc] init];
    message.content = content;
    message.type = type;
    message.timestamp = [NSDate date];
    return message;
}

@end
