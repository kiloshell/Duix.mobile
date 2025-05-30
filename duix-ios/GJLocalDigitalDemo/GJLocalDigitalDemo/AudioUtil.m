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

@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, strong) NSMutableData *audioData;
@property (nonatomic, strong) dispatch_queue_t audioQueue;
@property (nonatomic, assign) BOOL isPlaying;
@property (nonatomic, strong) AVAudioFormat *audioFormat;
@property (nonatomic, assign) BOOL isStreaming;
@property (nonatomic, assign) BOOL isFirstChunk;
@property (nonatomic, assign) NSInteger wavHeaderSize;
@property (nonatomic, strong) NSMutableArray *audioChunks;
@property (nonatomic, strong) NSString *currentAudioFilePath;
@property (nonatomic, assign) NSInteger chunkIndex;
@property (nonatomic, assign) NSInteger currentPlayIndex;
@property (nonatomic, strong) NSTimer *playTimer;

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
        self.audioData = [NSMutableData data];
        self.audioQueue = dispatch_queue_create("com.audio.streaming", DISPATCH_QUEUE_SERIAL);
        self.isFirstChunk = YES;
        self.wavHeaderSize = 44;
        self.audioChunks = [NSMutableArray array];
        self.chunkIndex = 0;
        self.currentPlayIndex = 0;
        
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
        
        // 设置 URLSession
        NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
        self.session = [NSURLSession sessionWithConfiguration:config delegate:self delegateQueue:nil];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self.playTimer invalidate];
    self.playTimer = nil;
}

- (void)convertTextToSpeech:(NSString *)text completion:(void(^)(BOOL success, NSError *error))completion {
    if (self.isStreaming) return;
    
    self.isStreaming = YES;
    [self.audioData setLength:0];
    self.isFirstChunk = YES;
    
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
    
    NSURLSessionDataTask *task = [self.session dataTaskWithRequest:request];
    [task resume];
}

- (NSString *)saveAudioChunk:(NSData *)data {
    NSString *documentsPath = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
    NSString *fileName = [NSString stringWithFormat:@"audio_chunk_%ld.wav", (long)self.chunkIndex++];
    NSString *filePath = [documentsPath stringByAppendingPathComponent:fileName];
    
    NSLog(@"保存音频块到: %@, 大小: %lu", filePath, (unsigned long)data.length);
    
    NSMutableData *wavData = [NSMutableData data];
    
    // 为每个块添加 WAV 头
    [wavData appendData:[self createWavHeaderWithDataLength:data.length]];
    [wavData appendData:data];
    
    NSError *error;
    BOOL success = [wavData writeToFile:filePath options:NSDataWritingAtomic error:&error];
    if (!success) {
        NSLog(@"保存音频块失败: %@", error);
        return nil;
    }
    
    // 验证文件是否保存成功
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:filePath]) {
        NSLog(@"错误：音频块文件未成功保存: %@", filePath);
        return nil;
    }
    
    NSDictionary *attributes = [fileManager attributesOfItemAtPath:filePath error:nil];
    NSNumber *fileSize = [attributes objectForKey:NSFileSize];
    NSLog(@"音频块保存成功，大小: %@ 字节", fileSize);
    
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

- (void)processAudioData:(NSData *)data isLastChunk:(BOOL)isLastChunk {
    NSLog(@"处理音频数据块，大小: %lu, 是否最后一块: %d", (unsigned long)data.length, isLastChunk);
    
    NSString *filePath = [self saveAudioChunk:data];
    if (filePath) {
        [self.audioChunks addObject:filePath];
        NSLog(@"成功添加音频块到列表，当前块数: %lu", (unsigned long)self.audioChunks.count);
        
        // 如果是第一个块，开始播放
        if (self.audioChunks.count == 1) {
            [self playNextChunk];
        }
    } else {
        NSLog(@"警告：音频块保存失败");
    }
}

- (void)playNextChunk {
    if (self.currentPlayIndex >= self.audioChunks.count) {
        NSLog(@"所有音频块播放完成");
        self.currentPlayIndex = 0;
        return;
    }
    
    NSString *filePath = self.audioChunks[self.currentPlayIndex];
    NSLog(@"播放音频块 %ld: %@", (long)self.currentPlayIndex, filePath);
    
    // 检查文件是否存在
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:filePath]) {
        NSLog(@"错误：音频文件不存在: %@", filePath);
        self.currentPlayIndex++;
        return;
    }
    
    // 检查文件大小
    NSDictionary *attributes = [fileManager attributesOfItemAtPath:filePath error:nil];
    NSNumber *fileSize = [attributes objectForKey:NSFileSize];
    if ([fileSize unsignedLongLongValue] == 0) {
        NSLog(@"错误：音频文件大小为0: %@", filePath);
        self.currentPlayIndex++;
        return;
    }
    
    [[GJLDigitalManager manager] toSpeakWithPath:filePath];
}

- (void)handleSpeakingFinished {
    NSLog(@"音频块 %ld 播放完成，准备播放下一个", (long)self.currentPlayIndex);
    self.currentPlayIndex++;
    [self playNextChunk];
}

- (void)stopPlayback {
    [self.playTimer invalidate];
    self.playTimer = nil;
    
    self.isStreaming = NO;
    [self.audioData setLength:0];
    self.isFirstChunk = YES;
    self.chunkIndex = 0;
    self.currentPlayIndex = 0;
    
    // 清理临时文件
    for (NSString *filePath in self.audioChunks) {
        [[NSFileManager defaultManager] removeItemAtPath:filePath error:nil];
    }
    [self.audioChunks removeAllObjects];
}

#pragma mark - NSURLSessionDataDelegate

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data {
    NSLog(@"接收到音频数据块: %lu 字节", (unsigned long)data.length);
    [self processAudioData:data isLastChunk:NO];
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (error) {
            NSLog(@"音频流接收失败: %@", error);
        } else {
            NSLog(@"音频流接收完成");
            
            // 获取文档目录
            NSString *documentsPath = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
            if (!documentsPath) {
                NSLog(@"错误：无法获取文档目录");
                return;
            }
            
            NSString *finalFilePath = [documentsPath stringByAppendingPathComponent:@"final_audio.wav"];
            NSLog(@"准备播放文件: %@", finalFilePath);
            
            // 验证文件是否存在
            NSFileManager *fileManager = [NSFileManager defaultManager];
            if (![fileManager fileExistsAtPath:finalFilePath]) {
                NSLog(@"错误：音频文件不存在: %@", finalFilePath);
                return;
            }
            
            // 验证文件大小
            NSDictionary *attributes = [fileManager attributesOfItemAtPath:finalFilePath error:nil];
            NSNumber *fileSize = [attributes objectForKey:NSFileSize];
            NSLog(@"音频文件大小: %@ 字节", fileSize);
            
            if ([fileSize unsignedLongLongValue] == 0) {
                NSLog(@"错误：音频文件大小为0");
                return;
            }
            
            
        }
    });
}

@end
