//
//  ChatViewController.m
//  GJLocalDigitalDemo
//
//  Created by 李文浩 on 2025/5/28.
//

#import "ChatViewController.h"
#import "ChatMessage.h"
#import "ChatMessageCell.h"

@interface ChatViewController () <UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate>

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UITextField *inputField;
@property (nonatomic, strong) UIView *inputContainerView;
@property (nonatomic, strong) NSMutableArray<ChatMessage *> *messages;

@end

@implementation ChatViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];
    self.messages = [NSMutableArray array];
    
    [self setupUI];
}

- (void)setupUI {
    // 设置输入框容器
    self.inputContainerView = [[UIView alloc] init];
    self.inputContainerView.backgroundColor = [UIColor whiteColor];
    [self.view addSubview:self.inputContainerView];
    
    // 设置输入框
    self.inputField = [[UITextField alloc] init];
    self.inputField.placeholder = @"请输入消息...";
    self.inputField.borderStyle = UITextBorderStyleRoundedRect;
    self.inputField.delegate = self;
    [self.inputContainerView addSubview:self.inputField];
    
    // 设置发送按钮
    UIButton *sendButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [sendButton setTitle:@"发送" forState:UIControlStateNormal];
    [sendButton addTarget:self action:@selector(sendMessage) forControlEvents:UIControlEventTouchUpInside];
    [self.inputContainerView addSubview:sendButton];
    
    // 设置表格视图
    self.tableView = [[UITableView alloc] init];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    [self.tableView registerClass:[ChatMessageCell class] forCellReuseIdentifier:@"ChatMessageCell"];
    [self.view addSubview:self.tableView];
    
    // 设置约束
    self.inputContainerView.frame = CGRectMake(0, self.view.bounds.size.height - 60, self.view.bounds.size.width, 60);
    self.inputField.frame = CGRectMake(10, 10, self.view.bounds.size.width - 80, 40);
    sendButton.frame = CGRectMake(self.view.bounds.size.width - 60, 10, 50, 40);
    self.tableView.frame = CGRectMake(0, 0, self.view.bounds.size.width, self.view.bounds.size.height - 60);
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.messages.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    ChatMessageCell *cell = [tableView dequeueReusableCellWithIdentifier:@"ChatMessageCell"];
    [cell configureWithMessage:self.messages[indexPath.row]];
    return cell;
}

#pragma mark - UITextFieldDelegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [self sendMessage];
    return YES;
}

#pragma mark - Actions

- (void)sendMessage {
    if (self.inputField.text.length == 0) return;
    
    // 添加用户消息
    ChatMessage *userMessage = [ChatMessage messageWithContent:self.inputField.text type:ChatMessageTypeUser];
    [self.messages addObject:userMessage];
    
    // 清空输入框
    self.inputField.text = @"";
    
    // 刷新表格
    [self.tableView reloadData];
    
    // 滚动到底部
    [self scrollToBottom];
    
    // 模拟获取回答
    [self getAnswerForMessage:userMessage.content];
}

- (void)getAnswerForMessage:(NSString *)message {
    // TODO: 调用实际的API获取回答
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSString *answer = @"这是一个模拟的回答";
        ChatMessage *assistantMessage = [ChatMessage messageWithContent:answer type:ChatMessageTypeAssistant];
        [self.messages addObject:assistantMessage];
        [self.tableView reloadData];
        [self scrollToBottom];
        
        // 将文字转换为语音并播放
        NSLog(@"准备将文字转换为语音: %@", answer);
    });
}

- (void)scrollToBottom {
    if (self.messages.count > 0) {
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:self.messages.count - 1 inSection:0];
        [self.tableView scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionBottom animated:YES];
    }
}

@end
