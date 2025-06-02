//
//  AudioUtil.m
//  GJLocalDigitalDemo
//
//  Created by 李文浩 on 2025/5/28.
//

#import "AudioUtil.h"
#import <AVFoundation/AVFoundation.h>
#import <GJLocalDigitalSDK/GJLDigitalManager.h>
@interface AudioUtil () <NSURLSessionDataDelegate>

@property (nonatomic, strong) AVAudioFormat *audioFormat;
@property (nonatomic, assign) BOOL isPlaying;
@property (nonatomic, assign) NSInteger wavHeaderSize;
@property (nonatomic, strong) NSString *currentAudioFilePath;

@end

@implementation AudioUtil

+ (instancetype)sharedInstance {
    static AudioUtil *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[AudioUtil alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        self.wavHeaderSize = 44;
        
        // 注册通知
        [[NSNotificationCenter defaultCenter] addObserver:self
                                               selector:@selector(handleSpeakingFinished)
                                                   name:@"GJLDigitalManagerDidFinishSpeaking"
                                                 object:nil];
        
        // 创建音频格式
        self.audioFormat = [[AVAudioFormat alloc] initWithCommonFormat:AVAudioPCMFormatFloat32
                                                           sampleRate:16000
                                                             channels:1
                                                          interleaved:NO];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)convertTextToSpeech:(NSString *)text completion:(void(^)(BOOL success, NSError *error))completion {
    // 准备请求参数
    NSDictionary *params = @{
        @"appkey": @"w2Yuyzd5ZrxSOeo7",
        @"text": text,
        @"token": @"00ce4ec1365b4891b13554a58f470b1b",
        @"format": @"wav"
    };
    
    NSURL *url = [NSURL URLWithString:@"https://nls-gateway-cn-shanghai.aliyuncs.com/stream/v1/tts"];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = @"POST";
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:@"00ce4ec1365b4891b13554a58f470b1b" forHTTPHeaderField:@"X-NLS-Token"];
    
    NSError *error;
    request.HTTPBody = [NSJSONSerialization dataWithJSONObject:params options:0 error:&error];
    
    if (error) {
        if (completion) {
            completion(NO, error);
        }
        return;
    }
    
    // 在后台线程执行网络请求
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSURLResponse *response = nil;
        NSError *requestError = nil;
        NSData *responseData = [NSURLConnection sendSynchronousRequest:request
                                                   returningResponse:&response
                                                               error:&requestError];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (requestError) {
                NSLog(@"音频请求失败: %@", requestError);
                if (completion) {
                    completion(NO, requestError);
                }
                return;
            }
            
            NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
            if (httpResponse.statusCode != 200) {
                NSString *errorMessage = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding];
                NSLog(@"服务器返回错误: %@", errorMessage);
                NSError *error = [NSError errorWithDomain:@"AudioUtil"
                                                   code:httpResponse.statusCode
                                               userInfo:@{NSLocalizedDescriptionKey: errorMessage}];
                if (completion) {
                    completion(NO, error);
                }
                return;
            }
            
            // 保存音频文件
            NSString *filePath = [self saveAudioFile:responseData];
            if (filePath) {
                self.currentAudioFilePath = filePath;
                [[GJLDigitalManager manager] toSpeakWithPath:filePath];
                if (completion) {
                    completion(YES, nil);
                }
            } else {
                NSError *error = [NSError errorWithDomain:@"AudioUtil"
                                                   code:-1
                                               userInfo:@{NSLocalizedDescriptionKey: @"音频文件保存失败"}];
                if (completion) {
                    completion(NO, error);
                }
            }
        });
    });
}

- (NSString *)saveAudioFile:(NSData *)data {
    NSString *documentsPath = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
    NSString *timestamp = [NSString stringWithFormat:@"%ld", (long)[[NSDate date] timeIntervalSince1970]];
    NSString *fileName = [NSString stringWithFormat:@"audio_%@.wav", timestamp];
    NSString *filePath = [documentsPath stringByAppendingPathComponent:fileName];
    
    NSLog(@"保存音频文件到: %@, 大小: %lu", filePath, (unsigned long)data.length);
    
    NSMutableData *wavData = [NSMutableData data];
    [wavData appendData:[self createWavHeaderWithDataLength:data.length]];
    [wavData appendData:data];
    
    NSError *error;
    BOOL success = [wavData writeToFile:filePath options:NSDataWritingAtomic error:&error];
    if (!success) {
        NSLog(@"保存音频文件失败: %@", error);
        return nil;
    }
    
    return filePath;
}

- (NSData *)createWavHeaderWithDataLength:(NSInteger)dataLength {
    NSMutableData *header = [NSMutableData data];
    
    // RIFF 头
    [header appendBytes:"RIFF" length:4];
    uint32_t fileSize = (uint32_t)(dataLength + 36);
    [header appendBytes:&fileSize length:4];
    [header appendBytes:"WAVE" length:4];
    
    // fmt 子块
    [header appendBytes:"fmt " length:4];
    uint32_t fmtSize = 16;
    [header appendBytes:&fmtSize length:4];
    uint16_t audioFormat = 1; // PCM
    [header appendBytes:&audioFormat length:2];
    uint16_t numChannels = 1;
    [header appendBytes:&numChannels length:2];
    uint32_t sampleRate = 16000;
    [header appendBytes:&sampleRate length:4];
    uint32_t byteRate = sampleRate * numChannels * 2;
    [header appendBytes:&byteRate length:4];
    uint16_t blockAlign = numChannels * 2;
    [header appendBytes:&blockAlign length:2];
    uint16_t bitsPerSample = 16;
    [header appendBytes:&bitsPerSample length:2];
    
    // data 子块
    [header appendBytes:"data" length:4];
    uint32_t dataSize = (uint32_t)dataLength;
    [header appendBytes:&dataSize length:4];
    
    return header;
}

- (void)handleSpeakingFinished {
    NSLog(@"音频播放完成");
}

- (void)stopPlayback {
    // 清理当前音频文件
    if (self.currentAudioFilePath) {
        [[NSFileManager defaultManager] removeItemAtPath:self.currentAudioFilePath error:nil];
        self.currentAudioFilePath = nil;
    }
}

@end
