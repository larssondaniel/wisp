//
//  WSPSettingsViewController.h
//  Wisp
//
//  Created by Daniel Larsson on 9/14/14.
//  Copyright (c) 2014 Daniel Larsson. All rights reserved.
//

#import <UIKit/UIKit.h>

extern NSString *const UsernameKey;
extern NSString *const PasswordKey;
extern NSString *const HostnameKey;
extern NSString *const FetchFullMessageKey;
extern NSString *const OAuthEnabledKey;

@protocol WSPSettingsViewControllerDelegate;

@interface WSPSettingsViewController : UIViewController

@property(weak, nonatomic) IBOutlet UITextField *emailTextField;
@property(weak, nonatomic) IBOutlet UITextField *passwordTextField;
@property(weak, nonatomic) IBOutlet UITextField *hostnameTextField;
@property(weak, nonatomic) IBOutlet UISwitch *fetchFullMessageSwitch;
@property(weak, nonatomic) IBOutlet UISwitch *useOAuth2Switch;

@property(nonatomic, weak) id<WSPSettingsViewControllerDelegate> delegate;
- (IBAction)done:(id)sender;

@end

@protocol WSPSettingsViewControllerDelegate<NSObject>
- (void)settingsViewControllerFinished:
        (WSPSettingsViewController *)viewController;
@end