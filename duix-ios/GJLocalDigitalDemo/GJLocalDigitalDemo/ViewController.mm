//
//  ViewController.m
//  GJLocalDigitalDemo
//
//  Created by guiji on 2023/12/12.
//

#import "ViewController.h"
#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

#import "HttpClient.h"
#import "SVProgressHUD.h"
#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <Security/Security.h>
#import <GJLocalDigitalSDK/GJLocalDigitalSDK.h>

//#import <CoreTelephony/CTCellularData.h>
#import "GJCheckNetwork.h"
#import "SSZipArchive.h"
#import "GJDownWavTool.h"
#import "GYAccess.h"
#import "ChatMessage.h"
#import "ChatMessageCell.h"
#import "BailianClient.h"
#import "AudioUtil.h"



//
//基础模型 git 地址下载较慢，请下载后自己管理加速
#define BASEMODELURL   @"https://github.com/GuijiAI/duix.ai/releases/download/v1.0.0/gj_dh_res.zip"
//////数字人模型 git 地址下载较慢，请下载后自己管理加速
#define DIGITALMODELURL @"https://github.com/GuijiAI/duix.ai/releases/download/v1.0.0/bendi3_20240518.zip"


@interface ViewController ()<GJDownWavToolDelegate, UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate, NSURLSessionDataDelegate>
@property(nonatomic,strong)UIView *showView;
@property(nonatomic,strong)NSString * basePath;
@property(nonatomic,strong)NSString * digitalPath;
@property (nonatomic, assign) BOOL isRequest;


//答案数组
@property (nonatomic, strong) NSMutableArray *answerArr;

//录音中
@property (nonatomic, assign) BOOL recording;


//多个音频开始和结束 当前播放音频状态 0 结束 1播放中
@property (nonatomic, assign) NSInteger playCurrentState;

//// 单个音频 0结束播放  1开始播放 2播放中 3播放暂停
//@property (nonatomic, assign) NSInteger playState;

/*
 * playAudioIndex 播放到第几个音频
 */
@property(nonatomic,assign)NSInteger playAudioIndex;




@property (nonatomic, strong)UILabel * questionLabel;

@property (nonatomic, strong)UILabel * answerLabel;


@property (nonatomic, strong) UIImageView * imageView;

@property (nonatomic, assign) BOOL isStop;

@property (nonatomic, strong) NSString *qaSessionId;

@property (nonatomic, strong) UIButton *chatButton;

@property (nonatomic, strong) UIView *chatView;
@property (nonatomic, strong) UITableView *chatTableView;
@property (nonatomic, strong) UITextField *chatInputField;
@property (nonatomic, strong) UIView *chatInputContainerView;
@property (nonatomic, strong) NSMutableArray<ChatMessage *> *chatMessages;
@property (nonatomic, strong) UIButton *closeChatButton;
@property (nonatomic, strong) ChatMessage *currentStreamingMessage;
@property (nonatomic, strong) NSMutableString *streamingBuffer;
@property (nonatomic, strong) NSMutableString *sentenceBuffer;
@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, strong) NSTimer *typingTimer;
@property (nonatomic, strong) NSMutableData *responseData;
@property (nonatomic, strong) NSMutableArray *ttsQueue;
@property (nonatomic, strong) NSMutableArray *audioQueue;
@property (nonatomic, assign) BOOL isPlayingTTS;
@property (nonatomic, assign) BOOL isGeneratingTTS;
@end

@implementation ViewController
-(UIView*)showView
{
    if(nil==_showView)
    {
        _showView=[[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height)];
        _showView.backgroundColor=[UIColor clearColor];
    }
    return _showView;
}
-(UIImageView*)imageView
{
    if(nil==_imageView)
    {
        _imageView=[[UIImageView alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height)];
        NSString *bgpath =[NSString stringWithFormat:@"%@/%@",[[NSBundle mainBundle] bundlePath],@"bg2.jpg"];
        _imageView.contentMode=UIViewContentModeScaleAspectFill;
        _imageView.image=[UIImage imageWithContentsOfFile:bgpath];
        
    }
    return _imageView;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor=[UIColor greenColor];
    
    [self.view addSubview:self.imageView];
    [self.view addSubview:self.showView];
    [self.view addSubview:self.questionLabel];
    [self.view addSubview:self.answerLabel];
    
    // 添加聊天按钮
    self.chatButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.chatButton setTitle:@"对话" forState:UIControlStateNormal];
    [self.chatButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.chatButton.backgroundColor = [UIColor colorWithRed:0.0 green:0.478 blue:1.0 alpha:1.0];
    self.chatButton.layer.cornerRadius = 5;
    [self.chatButton addTarget:self action:@selector(toggleChat) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.chatButton];
    
    // 设置按钮位置
    self.chatButton.frame = CGRectMake(self.view.bounds.size.width - 80, 140, 60, 40);
    
    // 初始化聊天相关视图
    [self setupChatView];
    
    UIButton * startbtn=[UIButton buttonWithType:UIButtonTypeCustom];
    startbtn.frame=CGRectMake(40, self.view.frame.size.height-100, 40, 40);
    [startbtn setTitle:@"开始" forState:UIControlStateNormal];
    [startbtn setTitleColor:[UIColor redColor] forState:UIControlStateNormal];
    [startbtn addTarget:self action:@selector(toStart) forControlEvents:UIControlEventTouchDown];
    [self.view addSubview:startbtn];
    
    UIButton * playbtn=[UIButton buttonWithType:UIButtonTypeCustom];
    playbtn.frame=CGRectMake(CGRectGetMaxX(startbtn.frame)+20, self.view.frame.size.height-100, 40, 40);
    [playbtn setTitle:@"播放" forState:UIControlStateNormal];
    [playbtn setTitleColor:[UIColor redColor] forState:UIControlStateNormal];
    [playbtn addTarget:self action:@selector(toRecord) forControlEvents:UIControlEventTouchDown];
    [self.view addSubview:playbtn];
    
    
//    UIButton * stopPlaybtn=[UIButton buttonWithType:UIButtonTypeCustom];
//    stopPlaybtn.frame=CGRectMake(CGRectGetMaxX(playbtn.frame)+20, self.view.frame.size.height-100, 40, 40);
//    [stopPlaybtn setTitle:@"停止" forState:UIControlStateNormal];
//    [stopPlaybtn setTitleColor:[UIColor redColor] forState:UIControlStateNormal];
//    [stopPlaybtn addTarget:self action:@selector(toPlay) forControlEvents:UIControlEventTouchDown];
//    [self.view addSubview:stopPlaybtn];

    UIButton * stopbtn=[UIButton buttonWithType:UIButtonTypeCustom];
    stopbtn.frame=CGRectMake(CGRectGetMaxX(playbtn.frame)+20, self.view.frame.size.height-100, 40, 40);
    [stopbtn setTitle:@"结束" forState:UIControlStateNormal];
    [stopbtn setTitleColor:[UIColor redColor] forState:UIControlStateNormal];
    [stopbtn addTarget:self action:@selector(toStop) forControlEvents:UIControlEventTouchDown];
    [self.view addSubview:stopbtn];

    [[GJCheckNetwork manager] getWifiState];
    __weak typeof(self)weakSelf = self;
    [GJCheckNetwork manager].on_net = ^(NetType state) {
        if (state == Net_WWAN
            || state == Net_WiFi) {
            if (!weakSelf.isRequest) {
                weakSelf.isRequest = YES;
                //注意有网络是初始化
                [weakSelf initALL];
                [weakSelf isDownModel];
            }
        }
    };
   



  
    

//    // 添加聊天按钮
//    self.chatButton = [UIButton buttonWithType:UIButtonTypeSystem];
//    [self.chatButton setTitle:@"对话" forState:UIControlStateNormal];
//    [self.chatButton addTarget:self action:@selector(openChat) forControlEvents:UIControlEventTouchUpInside];
//    [self.view addSubview:self.chatButton];
//
//    // 设置按钮位置
//    self.chatButton.frame = CGRectMake(self.view.bounds.size.width - 80, 40, 60, 40);

    // 初始化流式处理相关的属性
    self.streamingBuffer = [NSMutableString string];
    self.sentenceBuffer = [NSMutableString string];
    self.ttsQueue = [NSMutableArray array];
    self.audioQueue = [NSMutableArray array];
    self.isPlayingTTS = NO;
    self.isGeneratingTTS = NO;
    NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
    self.session = [NSURLSession sessionWithConfiguration:config];
    
    // 注册通知
    [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(handleSpeakingFinished)
                                               name:@"GJLDigitalManagerDidFinishSpeaking"
                                             object:nil];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)handleSpeakingFinished {
    self.isPlayingTTS = NO;
    // 延迟一小段时间再播放下一个，确保前一个音频完全结束
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self playNextTTS];
    });
}

- (void)playNextTTS {
    if (self.isPlayingTTS || self.audioQueue.count == 0) {
        return;
    }
    
    NSString *nextAudioPath = self.audioQueue.firstObject;
    [self.audioQueue removeObjectAtIndex:0];
    
    self.isPlayingTTS = YES;
    [[GJLDigitalManager manager] toSpeakWithPath:nextAudioPath];
}

- (void)generateNextTTS {
    if (self.isGeneratingTTS || self.ttsQueue.count == 0) {
        return;
    }
    
    NSString *nextSentence = self.ttsQueue.firstObject;
    [self.ttsQueue removeObjectAtIndex:0];
    
    self.isGeneratingTTS = YES;
    [[AudioUtil sharedInstance] convertTextToSpeech:nextSentence completion:^(BOOL success, NSError *error) {
        if (success) {
            // 音频生成成功，添加到播放队列
            [self.audioQueue addObject:[AudioUtil sharedInstance].currentAudioFilePath];
            // 如果当前没有在播放，开始播放
            if (!self.isPlayingTTS) {
                [self playNextTTS];
            }
        } else {
            NSLog(@"音频转换失败: %@", error);
        }
        self.isGeneratingTTS = NO;
        // 继续生成下一个音频
        [self generateNextTTS];
    }];
}

- (void)appendStreamingContent:(NSString *)content {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.streamingBuffer appendString:content];
        [self.sentenceBuffer appendString:content];
        self.currentStreamingMessage.content = [self.streamingBuffer copy];
        
        // 尝试提取完整句子
        NSString *sentence = [self extractCompleteSentence:self.sentenceBuffer];
        if (sentence) {
            NSLog(@"新生成的句子：%@", sentence);
            // 将句子添加到 TTS 生成队列
            [self.ttsQueue addObject:sentence];
            // 开始生成音频
            [self generateNextTTS];
        }
        
        // 更新界面显示
        [self.chatTableView reloadData];
        [self scrollChatToBottom];
    });
}

- (void)finishStreaming {
    dispatch_async(dispatch_get_main_queue(), ^{
        // 处理剩余的文本
        if (self.sentenceBuffer.length > 0) {
            NSString *remainingText = [self.sentenceBuffer copy];
            [self.sentenceBuffer setString:@""];
            
            // 将剩余文本添加到 TTS 生成队列
            [self.ttsQueue addObject:remainingText];
            [self generateNextTTS];
        }
        
        self.currentStreamingMessage = nil;
        [self.streamingBuffer setString:@""];
    });
}

-(void)initALL
{
    //注意有网络是初始化ASR

    //初始化下载音频
    [[GJDownWavTool sharedTool] initCachesPath];
    [GJDownWavTool sharedTool].delegate = self;
    
    //初始化数字人回调和音频回调
    [self toDigitalBlock];
}
-(void)toShowquestion
{
    self.questionLabel.hidden=!self.questionLabel.hidden;
    self.answerLabel.hidden=!self.answerLabel.hidden;
}




- (void)downloadWithModel:(GJLDigitalAnswerModel *)answerModel {
    
    [[GJDownWavTool sharedTool] downWavWithModel:answerModel];
    
}

- (void)downloadFinish:(GJLDigitalAnswerModel *)answerModel finish:(BOOL)finish {
    

  
        NSInteger index = [self.answerArr indexOfObject:answerModel];
        if (finish) {
            if (index == self.playAudioIndex&&self.playCurrentState ==0) {
    
//
                [self toSpeakWithPath:answerModel];
            }
        } else {
            if (index == self.playAudioIndex&&self.playCurrentState ==0) {
                //如果要播就直接结束到下一个
                NSLog(@"播放问题---下载失败，播放下一条--%@",answerModel.filePath);
                
                [self moviePlayDidEnd];
            }
        }
 
}
-(void)toSpeakWithPath:(GJLDigitalAnswerModel*)answerModel
{
    //
    if(self.playAudioIndex==0)
    {
        //开始动作（一段文字包含多个音频，第一个音频开始时设置）
         [[GJLDigitalManager manager] toRandomMotion];
         [[GJLDigitalManager manager] toStartMotion];
    }
    self.playCurrentState = 1;
    [[GJLDigitalManager manager] toSpeakWithPath:answerModel.localPath];
    if(answerModel.answer.length>0)
    {
        dispatch_async(dispatch_get_main_queue(), ^{
         //   DLog(@"表示一次任务生命周期结束，可以开始新的识别");
            NSLog(@"answerModel.answer:%@",answerModel.answer);
            self.answerLabel.text=[answerModel.answer stringByReplacingOccurrencesOfString:@"\n" withString:@""];
        });
        
    }
}
- (void)moviePlayDidEnd
{
    self.playAudioIndex ++;

    self.playCurrentState = 0;
    NSLog(@" self.playAudioIndex :%ld", self.playAudioIndex );
  
    if (self.answerArr.count > self.playAudioIndex) {
     
      
            GJLDigitalAnswerModel *answerModel = [self.answerArr objectAtIndex:self.playAudioIndex];
            if (answerModel.localPath.length == 0 && answerModel.download) {
                NSLog(@"error=====moviePlayDidEnd--下载失败了");
                [self moviePlayDidEnd];
            } else {
                [self playWithModel:answerModel];
            }
      
    }
    else
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.questionLabel.text=@"";
            self.answerLabel.text=@"";
        });
            [[GJLDigitalManager manager] toSopMotion:NO];
       
    }
}
- (void)playWithModel:(GJLDigitalAnswerModel *)answerModel {

    //    DLog(@"播放playUrl==%ld=播放==%@\n本地路径=%@",self.playState,answerModel.filePath,answerModel.localPath);
    if (self.recording ) {
        return;
    }
    __weak typeof(self)weakSelf = self;
    if (answerModel.localPath.length > 0) {

        [self toSpeakWithPath:answerModel];
    
    
    }
}
- (NSMutableArray *)answerArr {
    
    if (nil == _answerArr) {
        _answerArr = [NSMutableArray array];
    }
    return _answerArr;
}
-(void)isDownModel
{
    NSString *unzipPath = [self getHistoryCachePath:@"unZipCache"];
    NSString * baseName=[[BASEMODELURL lastPathComponent] stringByDeletingPathExtension];
    self.basePath=[NSString stringWithFormat:@"%@/%@",unzipPath,baseName];
    
    NSString * digitalName=[[DIGITALMODELURL lastPathComponent] stringByDeletingPathExtension];
    self.digitalPath=[NSString stringWithFormat:@"%@/%@",unzipPath,digitalName];
    NSFileManager * fileManger=[NSFileManager defaultManager];
    if((![fileManger fileExistsAtPath:self.basePath])&&(![fileManger fileExistsAtPath:self.digitalPath]))
    {
        //下载基础模型和数字人模型
        [self toDownBaseModelAndDigital];

    }
   else if (![fileManger fileExistsAtPath:self.digitalPath])
    {
        //数字人模型
        [SVProgressHUD show];
        [SVProgressHUD setDefaultMaskType:SVProgressHUDMaskTypeBlack];
        [self toDownDigitalModel];
    }
    

}
//下载基础模型----不同的数字人模型使用同一个基础模型
-(void)toDownBaseModelAndDigital
{
    [SVProgressHUD show];
    [SVProgressHUD setDefaultMaskType:SVProgressHUDMaskTypeBlack];
    __weak typeof(self)weakSelf = self;
    NSString *zipPath = [self getHistoryCachePath:@"ZipCache"];
    //下载基础模型
    [[HttpClient manager] downloadWithURL:BASEMODELURL savePathURL:[NSURL fileURLWithPath:zipPath] pathExtension:nil progress:^(NSProgress * progress) {
        double down_progress=(double)progress.completedUnitCount/(double)progress.totalUnitCount*0.5;
        [SVProgressHUD showProgress:down_progress status:@"正在下载基础模型"];
    } success:^(NSURLResponse *response, NSURL *filePath) {
        NSLog(@"filePath:%@",filePath);
        
        [weakSelf toUnzip:filePath.absoluteString];
        //下载数字人模型
        [weakSelf  toDownDigitalModel];
  
    } fail:^(NSError *error) {
        [SVProgressHUD showErrorWithStatus:error.localizedDescription];
    }];
}
-(void)toUnzip:(NSString*)filePath
{
    filePath=[filePath stringByReplacingOccurrencesOfString:@"file://" withString:@""];
    NSString *unzipPath = [self getHistoryCachePath:@"unZipCache"];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),^{
        [SSZipArchive unzipFileAtPath:filePath toDestination:unzipPath progressHandler:^(NSString * _Nonnull entry, unz_file_info zipInfo, long entryNumber, long total) {
            
        } completionHandler:^(NSString * _Nonnull path, BOOL succeeded, NSError * _Nullable error) {
            NSLog(@"path:%@,%d",path,succeeded);
        
        }];
    });
 
 
}
//下载数字人模型
-(void)toDownDigitalModel
{
    __weak typeof(self)weakSelf = self;
    NSString *zipPath = [self getHistoryCachePath:@"ZipCache"];
    [[HttpClient manager] downloadWithURL:DIGITALMODELURL savePathURL:[NSURL fileURLWithPath:zipPath] pathExtension:nil progress:^(NSProgress * progress) {
        double down_progress=0.5+(double)progress.completedUnitCount/(double)progress.totalUnitCount*0.5;
        [SVProgressHUD showProgress:down_progress status:@"正在下载数字人模型"];
    } success:^(NSURLResponse *response, NSURL *filePath) {
        NSLog(@"filePath:%@",filePath);
        [weakSelf toUnzip:filePath.absoluteString];
        [SVProgressHUD showSuccessWithStatus:@"下载成功"];
    } fail:^(NSError *error) {
        [SVProgressHUD showErrorWithStatus:error.localizedDescription];
    }];
}
-(void)toStart
{
    __weak typeof(self)weakSelf = self;
    //授权
    self.isStop=NO;
    // 设置背景透明，去除水印
    [GJLDigitalManager manager].backType = 0;
 
    NSInteger result = [[GJLDigitalManager manager] initBaseModel:weakSelf.basePath digitalModel:self.digitalPath showView:weakSelf.showView];
    if(result==1)
    {
        //开始
        [[GJLDigitalManager manager] toStart:^(BOOL isSuccess, NSString *errorMsg) {
            if(!isSuccess)
            {
                [SVProgressHUD showInfoWithStatus:errorMsg];
            }
        }];
    }
}


//播放音频
-(void)toRecord
{
//    [[GJLDigitalManager manager] toRandomMotion];
//    [[GJLDigitalManager manager] toStartMotion];
     NSString * filepath=[[NSBundle mainBundle] pathForResource:@"3.wav" ofType:nil];
     [[GJLDigitalManager manager] toSpeakWithPath:filepath];


    
}

#pragma mark ------------回调----------------
-(void)toDigitalBlock
{
    
    __weak typeof(self)weakSelf = self;
    [GJLDigitalManager manager].playFailed = ^(NSInteger code, NSString *errorMsg) {

            [SVProgressHUD showInfoWithStatus:errorMsg];

      
    };
    [GJLDigitalManager manager].audioPlayEnd = ^{
        [weakSelf moviePlayDidEnd];

     
    };
    
    [GJLDigitalManager manager].audioPlayProgress = ^(float current, float total) {
        
    };
 
}

#pragma mark ------------结束所有----------------
-(void)toStop
{
    self.isStop=YES;


    //停止绘制
    [[GJLDigitalManager manager] toStop];
}

-(NSString *)getHistoryCachePath:(NSString*)pathName
{
    NSString* folderPath =[[self getFInalPath] stringByAppendingPathComponent:pathName];
    //创建文件管理器
    NSFileManager *fileManager = [NSFileManager defaultManager];
    //判断temp文件夹是否存在
    BOOL fileExists = [fileManager fileExistsAtPath:folderPath];
    //如果不存在说创建,因为下载时,不会自动创建文件夹
    if (!fileExists)
    {
        [fileManager createDirectoryAtPath:folderPath withIntermediateDirectories:YES attributes:nil error:nil];
    }
    return folderPath;
}

- (NSString *)getFInalPath
{
    NSString* folderPath =[[NSHomeDirectory() stringByAppendingPathComponent:@"Library"] stringByAppendingPathComponent:@"GJCache"];
    //创建文件管理器
    NSFileManager *fileManager = [NSFileManager defaultManager];
    //判断temp文件夹是否存在
    BOOL fileExists = [fileManager fileExistsAtPath:folderPath];
    //如果不存在说创建,因为下载时,不会自动创建文件夹
    if (!fileExists) {
        [fileManager createDirectoryAtPath:folderPath withIntermediateDirectories:YES attributes:nil error:nil];
    }
    
    return folderPath;
}

-(UILabel*)questionLabel
{
    if(nil==_questionLabel)
    {
        _questionLabel=[[UILabel alloc] initWithFrame:CGRectMake(0, self.view.frame.size.height-220, self.view.frame.size.width-40, 40)];
        _questionLabel.backgroundColor=[UIColor redColor];
        _questionLabel.numberOfLines=0;
        _questionLabel.textColor=[UIColor whiteColor];
        _questionLabel.font=[UIFont systemFontOfSize:12];
        _questionLabel.textAlignment=NSTextAlignmentLeft;
        _questionLabel.hidden=YES;
    }
    return _questionLabel;
}
-(UILabel*)answerLabel
{
    if(nil==_answerLabel)
    {
        _answerLabel=[[UILabel alloc] initWithFrame:CGRectMake(40, self.view.frame.size.height-160, self.view.frame.size.width-40, 40)];
        _answerLabel.backgroundColor=[UIColor redColor];
        _answerLabel.numberOfLines=0;
        _answerLabel.textColor=[UIColor whiteColor];
        _answerLabel.font=[UIFont systemFontOfSize:12];
        _answerLabel.textAlignment=NSTextAlignmentLeft;
        _answerLabel.hidden=YES;
    }
    return _answerLabel;
}

- (void)toggleChat {
    NSLog(@"Toggle chat view"); // 添加日志
    if (self.chatView.hidden) {
        // 显示聊天视图
        self.chatView.hidden = NO;
        [self.chatInputField becomeFirstResponder]; // 显示键盘
    } else {
        // 隐藏聊天视图
        self.chatView.hidden = YES;
        [self.chatInputField resignFirstResponder]; // 隐藏键盘
    }
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.chatMessages.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    ChatMessageCell *cell = [tableView dequeueReusableCellWithIdentifier:@"ChatMessageCell"];
    [cell configureWithMessage:self.chatMessages[indexPath.row]];
    return cell;
}

#pragma mark - UITextFieldDelegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [self sendChatMessage];
    return YES;
}

#pragma mark - Actions

- (void)sendChatMessage {
    if (self.chatInputField.text.length == 0) return;
    
    // 添加用户消息
    ChatMessage *userMessage = [ChatMessage messageWithContent:self.chatInputField.text type:ChatMessageTypeUser];
    [self.chatMessages addObject:userMessage];
    
    // 清空输入框
    self.chatInputField.text = @"";
    
    // 刷新表格
    [self.chatTableView reloadData];
    
    // 滚动到底部
    [self scrollChatToBottom];
    
    // 模拟获取回答
    [self getAnswerForMessage:userMessage.content];
}

- (void)getAnswerForMessage:(NSString *)message {
    [SVProgressHUD showWithStatus:@"正在思考..."];
    
    // 创建并添加助手消息
    ChatMessage *assistantMessage = [ChatMessage messageWithContent:@"" type:ChatMessageTypeAssistant];
    [self.chatMessages addObject:assistantMessage];
    self.currentStreamingMessage = assistantMessage;
    [self.chatTableView reloadData];
    [self scrollChatToBottom];
    
    // 准备请求参数
    NSDictionary *params = @{
        @"model": @"qwen2.5-0.5b-instruct",
        @"messages": @[
            @{@"role": @"system", @"content": @"You are a helpful assistant."},
            @{@"role": @"user", @"content": message}
        ],
        @"stream": @YES
    };
    
    NSURL *url = [NSURL URLWithString:@"https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions"];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = @"POST";
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:@"Bearer sk-b590c8399ade4b6d9af342d091fb3869" forHTTPHeaderField:@"Authorization"];
    
    NSError *error;
    request.HTTPBody = [NSJSONSerialization dataWithJSONObject:params options:0 error:&error];
    
    if (error) {
        [SVProgressHUD dismiss];
        [SVProgressHUD showErrorWithStatus:@"请求参数序列化失败"];
        return;
    }
    
    self.responseData = [NSMutableData data];
    NSURLSessionDataTask *task = [self.session dataTaskWithRequest:request];
    task.delegate = self;
    [task resume];
}

#pragma mark - NSURLSessionDataDelegate

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data {
    [self.responseData appendData:data];
    
    // 收到第一个数据时关闭 loading
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dispatch_async(dispatch_get_main_queue(), ^{
            [SVProgressHUD dismiss];
        });
    });
    
    NSString *responseString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    NSArray *lines = [responseString componentsSeparatedByString:@"\n"];
    
    for (NSString *line in lines) {
        if ([line hasPrefix:@"data: "]) {
            NSString *jsonStr = [line substringFromIndex:6];
            if ([jsonStr isEqualToString:@"[DONE]"]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self finishStreaming];
                });
                break;
            }
            
            NSData *jsonData = [jsonStr dataUsingEncoding:NSUTF8StringEncoding];
            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:nil];
            
            NSString *content = json[@"choices"][0][@"delta"][@"content"];
            if (content) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self appendStreamingContent:content];
                });
            }
        }
    }
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    dispatch_async(dispatch_get_main_queue(), ^{
        [SVProgressHUD dismiss];
        
        if (error) {
            [SVProgressHUD showErrorWithStatus:error.localizedDescription];
            return;
        }
    });
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler {
    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
    if (httpResponse.statusCode != 200) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [SVProgressHUD dismiss];
            [SVProgressHUD showErrorWithStatus:[NSString stringWithFormat:@"服务器返回错误: %ld", (long)httpResponse.statusCode]];
        });
        completionHandler(NSURLSessionResponseCancel);
        return;
    }
    completionHandler(NSURLSessionResponseAllow);
}

- (BOOL)isCompleteSentence:(NSString *)text {
    // 检查是否包含句子结束符号
    NSCharacterSet *sentenceEndings = [NSCharacterSet characterSetWithCharactersInString:@"。！？.!?"];
    NSRange range = [text rangeOfCharacterFromSet:sentenceEndings];
    return range.location != NSNotFound;
}

- (NSString *)extractCompleteSentence:(NSString *)text {
    NSCharacterSet *sentenceEndings = [NSCharacterSet characterSetWithCharactersInString:@"。！？.!?"];
    NSRange range = [text rangeOfCharacterFromSet:sentenceEndings];
    
    if (range.location != NSNotFound) {
        // 找到标点符号，返回标点符号及其之前的内容
        NSRange sentenceRange = NSMakeRange(0, range.location + 1);
        NSString *sentence = [text substringWithRange:sentenceRange];
        
        // 将剩余内容放回 sentenceBuffer
        NSString *remainingText = [text substringFromIndex:range.location + 1];
        [self.sentenceBuffer setString:remainingText];
        
        return sentence;
    }
    
    return nil;
}

- (void)scrollChatToBottom {
    if (self.chatMessages.count > 0) {
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:self.chatMessages.count - 1 inSection:0];
        [self.chatTableView scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionBottom animated:YES];
    }
}

- (void)setupChatView {
    // 创建聊天视图
    self.chatView = [[UIView alloc] initWithFrame:self.view.bounds];
    self.chatView.backgroundColor = [UIColor colorWithWhite:0 alpha:0.7];
    self.chatView.hidden = YES;
    [self.view addSubview:self.chatView];
    
    // 添加关闭按钮
    self.closeChatButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.closeChatButton setTitle:@"关闭" forState:UIControlStateNormal];
    [self.closeChatButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.closeChatButton.backgroundColor = [UIColor colorWithRed:0.0 green:0.478 blue:1.0 alpha:1.0];
    self.closeChatButton.layer.cornerRadius = 5;
    [self.closeChatButton addTarget:self action:@selector(toggleChat) forControlEvents:UIControlEventTouchUpInside];
    [self.chatView addSubview:self.closeChatButton];
    self.closeChatButton.frame = CGRectMake(self.view.bounds.size.width - 80, 140, 60, 40);
    
    // 设置输入框容器
    self.chatInputContainerView = [[UIView alloc] init];
    self.chatInputContainerView.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.9];
    [self.chatView addSubview:self.chatInputContainerView];
    
    // 设置输入框
    self.chatInputField = [[UITextField alloc] init];
    self.chatInputField.placeholder = @"请输入消息...";
    self.chatInputField.borderStyle = UITextBorderStyleRoundedRect;
    self.chatInputField.delegate = self;
    [self.chatInputContainerView addSubview:self.chatInputField];
    
    // 设置发送按钮
    UIButton *sendButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [sendButton setTitle:@"发送" forState:UIControlStateNormal];
    [sendButton addTarget:self action:@selector(sendChatMessage) forControlEvents:UIControlEventTouchUpInside];
    [self.chatInputContainerView addSubview:sendButton];
    
    // 设置表格视图
    self.chatTableView = [[UITableView alloc] init];
    self.chatTableView.delegate = self;
    self.chatTableView.dataSource = self;
    self.chatTableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.chatTableView.backgroundColor = [UIColor clearColor];
    [self.chatTableView registerClass:[ChatMessageCell class] forCellReuseIdentifier:@"ChatMessageCell"];
    [self.chatView addSubview:self.chatTableView];
    
    // 初始化消息数组
    self.chatMessages = [NSMutableArray array];
    
    // 设置约束
    self.chatInputContainerView.frame = CGRectMake(0, self.view.bounds.size.height - 60, self.view.bounds.size.width, 60);
    self.chatInputField.frame = CGRectMake(10, 10, self.view.bounds.size.width - 80, 40);
    sendButton.frame = CGRectMake(self.view.bounds.size.width - 60, 10, 50, 40);
    self.chatTableView.frame = CGRectMake(0, 100, self.view.bounds.size.width, self.view.bounds.size.height - 160);
}

@end
