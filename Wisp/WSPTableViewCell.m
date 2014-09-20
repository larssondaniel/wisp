//
//  MCTTableViewCell.m
//  Wisp
//
//  Created by Daniel Larsson on 9/14/14.
//  Copyright (c) 2014 Daniel Larsson. All rights reserved.
//

#import "WSPTableViewCell.h"

@implementation WSPTableViewCell

- (id)initWithStyle:(UITableViewCellStyle)style
    reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:UITableViewCellStyleSubtitle
                reuseIdentifier:reuseIdentifier];
    return self;
}

- (void)prepareForReuse {
    [self.messageRenderingOperation cancel];
    // self.previewLabel.text = @" ";
}

@end
