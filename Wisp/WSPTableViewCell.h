//
//  WSPTableViewCell.h
//  Wisp
//
//  Created by Daniel Larsson on 9/14/14.
//  Copyright (c) 2014 Daniel Larsson. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <MailCore/MailCore.h>

@interface WSPTableViewCell : UITableViewCell

@property(nonatomic, strong)
    MCOIMAPMessageRenderingOperation *messageRenderingOperation;
@property(strong, nonatomic) IBOutlet UILabel *authorLabel;
@property(strong, nonatomic) IBOutlet UILabel *titleLabel;
@property(strong, nonatomic) IBOutlet UILabel *previewLabel;
@property(strong, nonatomic) IBOutlet UILabel *timestampLabel;

@end
