//
//  ChatMessageCell.h
//  GJLocalDigitalDemo
//
//  Created by 李文浩 on 2025/5/28.
//

#import <UIKit/UIKit.h>
#import "ChatMessage.h"

@interface ChatMessageCell : UITableViewCell

@property (nonatomic, strong) UILabel *messageLabel;
@property (nonatomic, strong) UIView *bubbleView;

- (void)configureWithMessage:(ChatMessage *)message;

@end
