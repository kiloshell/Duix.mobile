//
//  BailianClient.m
//  GJLocalDigitalDemo
//
//  Created by 李文浩 on 2025/5/28.
//

#import "BailianClient.h"
//#import <AFNetworking/AFNetworking.h>
#import <AFNetworking.h>

// 请替换为您的实际API Key
#define DASHSCOPE_API_KEY @"sk-b590c8399ade4b6d9af342d091fb3869"
#define QIANWEN_API_URL @"https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions"

@interface QianwenClient ()

@property (nonatomic, strong) AFHTTPSessionManager *sessionManager;
@property (nonatomic, strong) NSMutableArray *messageHistory;

@end

@implementation QianwenClient

+ (instancetype)sharedInstance {
    static QianwenClient *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[QianwenClient alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _sessionManager = [AFHTTPSessionManager manager];
        _sessionManager.requestSerializer = [AFJSONRequestSerializer serializer];
        _sessionManager.responseSerializer = [AFJSONResponseSerializer serializer];
        [_sessionManager.requestSerializer setValue:[NSString stringWithFormat:@"Bearer %@", DASHSCOPE_API_KEY] forHTTPHeaderField:@"Authorization"];
        [_sessionManager.requestSerializer setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
        
        _messageHistory = [NSMutableArray array];
        // 添加系统消息
        [_messageHistory addObject:@{
            @"role": @"system",
            @"content": @"You are a helpful assistant."
        }];
    }
    return self;
}

- (void)chatWithMessage:(NSString *)message
             completion:(void(^)(NSString *response, NSError *error))completion {
    // 添加用户消息到历史记录
    [self.messageHistory addObject:@{
        @"role": @"user",
        @"content": message
    }];
    
    // 构建请求参数
    NSDictionary *parameters = @{
        @"model": @"qwen2.5-0.5b-instruct",
        @"messages": self.messageHistory
    };
    
    // 发送请求
    [self.sessionManager POST:QIANWEN_API_URL
                  parameters:parameters
                     headers:nil
                    progress:nil
                     success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        // 解析响应
        NSDictionary *response = (NSDictionary *)responseObject;
        NSString *responseText = response[@"choices"][0][@"message"][@"content"];
        
        // 添加助手回复到历史记录
        [self.messageHistory addObject:@{
            @"role": @"assistant",
            @"content": responseText
        }];
        
        // 保持历史记录在合理范围内
        if (self.messageHistory.count > 10) {
            NSRange range = NSMakeRange(1, 2); // 保留系统消息，删除最早的一对对话
            [self.messageHistory removeObjectsInRange:range];
        }
        
        if (completion) {
            completion(responseText, nil);
        }
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        if (completion) {
            completion(nil, error);
        }
    }];
}

@end
