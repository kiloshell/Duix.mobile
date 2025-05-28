//
//  AudioUtil.m
//  GJLocalDigitalDemo
//
//  Created by 李文浩 on 2025/5/28.
//

#import "AudioUtil.h"
#import <AVFoundation/AVFoundation.h>

@interface AudioUtil () <NSURLSessionDataDelegate>

@property (nonatomic, strong) AVAudioEngine *audioEngine;
@property (nonatomic, strong) AVAudioPlayerNode *playerNode;
@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, strong) NSMutableData *audioData;
@property (nonatomic, strong) dispatch_queue_t audioQueue;
@property (nonatomic, assign) BOOL isPlaying;
@property (nonatomic, strong) AVAudioFormat *audioFormat;
@property (nonatomic, assign) BOOL isStreaming;
@property (nonatomic, assign) BOOL isFirstChunk;
@property (nonatomic, assign) NSInteger wavHeaderSize;
@property (nonatomic, assign) NSInteger totalBuffers;
@property (nonatomic, assign) NSInteger completedBuffers;
@property (nonatomic, assign) BOOL isProcessingLastChunk;

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
        self.totalBuffers = 0;
        self.completedBuffers = 0;
        
        // 创建音频格式
        self.audioFormat = [[AVAudioFormat alloc] initWithCommonFormat:AVAudioPCMFormatFloat32
                                                           sampleRate:44100
                                                             channels:1
                                                          interleaved:NO];
        
        // 初始化音频引擎
        self.audioEngine = [[AVAudioEngine alloc] init];
        self.playerNode = [[AVAudioPlayerNode alloc] init];
        [self.audioEngine attachNode:self.playerNode];
        [self.audioEngine connect:self.playerNode to:self.audioEngine.mainMixerNode format:self.audioFormat];
        
        // 启动音频引擎
        NSError *error;
        [self.audioEngine startAndReturnError:&error];
        if (error) {
            NSLog(@"音频引擎启动失败: %@", error);
        }
        
        // 设置 URLSession
        NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
        self.session = [NSURLSession sessionWithConfiguration:config delegate:self delegateQueue:nil];
    }
    return self;
}

- (void)convertTextToSpeech:(NSString *)text completion:(void(^)(BOOL success, NSError *error))completion {
    if (self.isStreaming) return;
    
    self.isStreaming = YES;
    [self.audioData setLength:0];
    self.isFirstChunk = YES;
    self.totalBuffers = 0;
    self.completedBuffers = 0;
    self.isProcessingLastChunk = NO;
    
    // 准备请求参数
    NSDictionary *params = @{
        @"text": text,
        @"reference_id": @"Zhang075-1925967372432748545",
        @"format": @"wav",
        @"streaming": @YES,
        @"use_memory_cache": @"on",
        @"seed": @1
    };
    
    NSURL *url = [NSURL URLWithString:@"http://3.236.225.202:7860/v1/tts"];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = @"POST";
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    
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

- (void)processAudioData:(NSData *)data isLastChunk:(BOOL)isLastChunk {
    if (self.isFirstChunk) {
        if (data.length > self.wavHeaderSize) {
            // 跳过 WAV 文件头
            [self.audioData appendData:[data subdataWithRange:NSMakeRange(self.wavHeaderSize, data.length - self.wavHeaderSize)]];
        } else {
            [self.audioData appendData:data];
        }
        self.isFirstChunk = NO;
    } else {
        [self.audioData appendData:data];
    }
    
    // 当累积足够的数据时进行处理
    NSInteger minBufferSize = 8192;
    while (self.audioData.length >= minBufferSize || (isLastChunk && self.audioData.length > 0)) {
        NSInteger processSize = MIN(self.audioData.length, minBufferSize);
        NSData *processData = [self.audioData subdataWithRange:NSMakeRange(0, processSize)];
        [self.audioData replaceBytesInRange:NSMakeRange(0, processSize) withBytes:NULL length:0];
        
        // 将 PCM 数据转换为 Float32 格式
        NSMutableArray *floatData = [NSMutableArray array];
        const int16_t *samples = (const int16_t *)processData.bytes;
        NSInteger sampleCount = processData.length / sizeof(int16_t);
        
        for (NSInteger i = 0; i < sampleCount; i++) {
            [floatData addObject:@(samples[i] / 32768.0f)];
        }
        
        // 创建音频缓冲区
        AVAudioPCMBuffer *buffer = [[AVAudioPCMBuffer alloc] initWithPCMFormat:self.audioFormat
                                                                frameCapacity:(AVAudioFrameCount)floatData.count];
        buffer.frameLength = buffer.frameCapacity;
        
        // 填充音频数据
        float *channelData = buffer.floatChannelData[0];
        for (NSInteger i = 0; i < floatData.count; i++) {
            channelData[i] = [floatData[i] floatValue];
        }
        
        self.totalBuffers++;
        
        // 将缓冲区添加到播放队列
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.playerNode scheduleBuffer:buffer completionHandler:^{
                dispatch_async(dispatch_get_main_queue(), ^{
                    self.completedBuffers++;
                    NSLog(@"缓冲区播放完成: %ld/%ld", (long)self.completedBuffers, (long)self.totalBuffers);
                    
                    if (self.completedBuffers == self.totalBuffers && self.isProcessingLastChunk) {
                        [self.playerNode stop];
                        NSLog(@"所有音频播放完成");
                        self.totalBuffers = 0;
                        self.completedBuffers = 0;
                    }
                });
            }];
            
            if (!self.playerNode.isPlaying) {
                [self.playerNode play];
                NSLog(@"开始播放音频");
            }
        });
    }
}

- (void)stopPlayback {
    [self.playerNode stop];
    self.isStreaming = NO;
    [self.audioData setLength:0];
    self.isFirstChunk = YES;
    self.isProcessingLastChunk = NO;
    self.totalBuffers = 0;
    self.completedBuffers = 0;
}

#pragma mark - NSURLSessionDataDelegate

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data {
    NSLog(@"接收到音频数据块: %lu 字节", (unsigned long)data.length);
    [self processAudioData:data isLastChunk:NO];
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.audioData.length > 0) {
            self.isProcessingLastChunk = YES;
            [self processAudioData:[NSData data] isLastChunk:YES];
        }
        self.isStreaming = NO;
        
        if (error) {
            NSLog(@"音频流接收失败: %@", error);
        } else {
            NSLog(@"音频流接收完成");
        }
    });
}

@end
