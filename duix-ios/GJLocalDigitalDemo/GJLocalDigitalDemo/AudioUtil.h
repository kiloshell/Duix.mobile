//
//  AudioUtil.h
//  GJLocalDigitalDemo
//
//  Created by 李文浩 on 2025/5/28.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface AudioUtil : NSObject

@property (nonatomic, strong, readonly) NSString *currentAudioFilePath;

+ (instancetype)sharedInstance;

// 将文本转换为音频并播放
- (void)convertTextToSpeech:(NSString *)text completion:(void(^)(BOOL success, NSError *error))completion;

// 停止播放
- (void)stopPlayback;

@end

NS_ASSUME_NONNULL_END
