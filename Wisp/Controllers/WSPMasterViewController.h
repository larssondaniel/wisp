//
//  WSPMasterViewController.h
//  Wisp
//
//  Created by Daniel Larsson on 9/14/14.
//  Copyright (c) 2014 Daniel Larsson. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SettingsViewController.h"

@interface WSPMasterViewController : UITableViewController <SettingsViewControllerDelegate>

- (IBAction)showSettingsViewController:(id)sender;

@end
