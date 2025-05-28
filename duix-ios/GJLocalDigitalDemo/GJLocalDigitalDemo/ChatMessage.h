//
//  ChatMessage.h
//  GJLocalDigitalDemo
//
//  Created by 李文浩 on 2025/5/28.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, ChatMessageType) {
    ChatMessageTypeUser,
    ChatMessageTypeAssistant
};

@interface ChatMessage : NSObject

@property (nonatomic, copy) NSString *content;
@property (nonatomic, assign) ChatMessageType type;
@property (nonatomic, strong) NSDate *timestamp;

+ (instancetype)messageWithContent:(NSString *)content type:(ChatMessageType)type;

@end
