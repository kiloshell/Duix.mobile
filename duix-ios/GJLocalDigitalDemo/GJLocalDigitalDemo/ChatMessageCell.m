//
//  ChatMessageCell.m
//  GJLocalDigitalDemo
//
//  Created by 李文浩 on 2025/5/28.
//

#import "ChatMessageCell.h"

@implementation ChatMessageCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        self.backgroundColor = [UIColor clearColor];
        
        _bubbleView = [[UIView alloc] init];
        _bubbleView.layer.cornerRadius = 12;
        [self.contentView addSubview:_bubbleView];
        
        _messageLabel = [[UILabel alloc] init];
        _messageLabel.numberOfLines = 0;
        _messageLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.3];
        _messageLabel.font = [UIFont systemFontOfSize:16];
        [_bubbleView addSubview:_messageLabel];
    }
    return self;
}

- (void)configureWithMessage:(ChatMessage *)message {
    _messageLabel.text = message.content;
    
    if (message.type == ChatMessageTypeUser) {
        _bubbleView.backgroundColor = [UIColor colorWithRed:0.0 green:0.478 blue:1.0 alpha:0.3];
    } else {
        _bubbleView.backgroundColor = [UIColor colorWithRed:0.8 green:0.8 blue:0.8 alpha:0.3];
    }
    
    [self setNeedsLayout];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    CGFloat maxWidth = self.contentView.bounds.size.width * 0.7;
    CGSize textSize = [_messageLabel.text boundingRectWithSize:CGSizeMake(maxWidth - 20, CGFLOAT_MAX)
                                                     options:NSStringDrawingUsesLineFragmentOrigin
                                                  attributes:@{NSFontAttributeName: _messageLabel.font}
                                                     context:nil].size;
    
    CGFloat bubbleWidth = textSize.width + 20;
    CGFloat bubbleHeight = textSize.height + 20;
    
    if (_messageLabel.text.length > 0) {
        _bubbleView.frame = CGRectMake(10, 5, bubbleWidth, bubbleHeight);
        _messageLabel.frame = CGRectMake(10, 10, textSize.width, textSize.height);
    }
}

@end
