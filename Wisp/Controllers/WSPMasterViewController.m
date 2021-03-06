//
//  WSPMasterViewController.m
//  Wisp
//
//  Created by Daniel Larsson on 9/14/14.
//  Copyright (c) 2014 Daniel Larsson. All rights reserved.
//

#import "WSPMasterViewController.h"
#import <MailCore/MailCore.h>
#import "FXKeychain.h"
#import "MCTMsgViewController.h"
#import "GTMOAuth2ViewControllerTouch.h"
#import "WSPTableViewCell.h"
#import "CoreDataService.h"
#import "NSDate+DateTools.h"

#define CLIENT_ID \
    @"14179433454-l8qkjo32hi3u77dn3r02tp3dvi81l17b.apps.googleusercontent.com"
#define CLIENT_SECRET @"IYOKIYorn6YULWeF7-rwp7yh"
#define KEYCHAIN_ITEM_NAME @"MailCore OAuth 2.0 Token"

#define NUMBER_OF_MESSAGES_TO_LOAD 10

static NSString *mailCellIdentifier = @"MailCell";
static NSString *inboxInfoIdentifier = @"InboxStatusCell";

@interface WSPMasterViewController ()
@property(nonatomic, strong) NSArray *messages;

@property(nonatomic, strong) MCOIMAPOperation *imapCheckOp;
@property(nonatomic, strong) MCOIMAPSession *imapSession;
@property(nonatomic, strong) MCOIMAPFetchMessagesOperation *imapMessagesFetchOp;

@property(nonatomic) NSInteger totalNumberOfInboxMessages;
@property(nonatomic) BOOL isLoading;
@property(nonatomic, strong) UIActivityIndicatorView *loadMoreActivityView;
@property(nonatomic, strong) NSMutableDictionary *messagePreviews;
@property(nonatomic, strong) CoreDataService *coreDataService;
@end

@implementation WSPMasterViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.navigationController.navigationBar.barStyle = UIBarStyleBlack;
    self.coreDataService = [CoreDataService sharedService];

    // Initialize pull to release.
    self.refreshControl = [[UIRefreshControl alloc] init];
    self.refreshControl.backgroundColor =
        [UIColor colorWithRed:0.235 green:0.240 blue:0.322 alpha:1.000];
    self.refreshControl.tintColor = [UIColor whiteColor];
    [self.refreshControl addTarget:self
                            action:@selector(doReloadData)
                  forControlEvents:UIControlEventValueChanged];

    //[self.tableView registerClass:[MCTTableViewCell class]
    //	   forCellReuseIdentifier:mailCellIdentifier];

    self.loadMoreActivityView = [[UIActivityIndicatorView alloc]
        initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];

    [[NSUserDefaults standardUserDefaults] registerDefaults:@{
        HostnameKey : @"imap.gmail.com"
    }];

    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"OAuth2Enabled"]) {
        [self startOAuth2];
    } else {
        [self startLogin];
    }
}

- (void)doReloadData {
    [self loadLastNMessages:NUMBER_OF_MESSAGES_TO_LOAD];
}

- (void)startLogin {
    NSString *username =
        [[NSUserDefaults standardUserDefaults] objectForKey:UsernameKey];
    NSString *password =
        [[FXKeychain defaultKeychain] objectForKey:PasswordKey];
    NSString *hostname =
        [[NSUserDefaults standardUserDefaults] objectForKey:HostnameKey];

    if (!username.length || !password.length) {
        [self performSelector:@selector(showSettingsViewController:)
                   withObject:nil
                   afterDelay:0.5];
        return;
    }

    [self loadAccountWithUsername:username
                         password:password
                         hostname:hostname
                      oauth2Token:nil];
}

- (void)startOAuth2 {
    GTMOAuth2Authentication *auth = [GTMOAuth2ViewControllerTouch
        authForGoogleFromKeychainForName:KEYCHAIN_ITEM_NAME
                                clientID:CLIENT_ID
                            clientSecret:CLIENT_SECRET];

    if ([auth refreshToken] == nil) {
        WSPMasterViewController *__weak weakSelf = self;
        GTMOAuth2ViewControllerTouch *viewController =
            [GTMOAuth2ViewControllerTouch
                controllerWithScope:@"https://mail.google.com/"
                           clientID:CLIENT_ID
                       clientSecret:CLIENT_SECRET
                   keychainItemName:KEYCHAIN_ITEM_NAME
                  completionHandler:^(GTMOAuth2ViewControllerTouch *
                                          viewController,
                                      GTMOAuth2Authentication *retrievedAuth,
                                      NSError *error) {
                      [weakSelf loadWithAuth:retrievedAuth];
                  }];
        [self.navigationController pushViewController:viewController
                                             animated:YES];
    } else {
        [auth beginTokenFetchWithDelegate:self
                        didFinishSelector:@selector(auth:
                                              finishedRefreshWithFetcher:
                                                                   error:)];
    }
}

- (void)auth:(GTMOAuth2Authentication *)auth
    finishedRefreshWithFetcher:(GTMHTTPFetcher *)fetcher
                         error:(NSError *)error {
    [self loadWithAuth:auth];
}

- (void)loadWithAuth:(GTMOAuth2Authentication *)auth {
    NSString *hostname =
        [[NSUserDefaults standardUserDefaults] objectForKey:HostnameKey];
    [self loadAccountWithUsername:[auth userEmail]
                         password:nil
                         hostname:hostname
                      oauth2Token:[auth accessToken]];
}

- (void)loadAccountWithUsername:(NSString *)username
                       password:(NSString *)password
                       hostname:(NSString *)hostname
                    oauth2Token:(NSString *)oauth2Token {
    self.imapSession = [[MCOIMAPSession alloc] init];
    self.imapSession.hostname = hostname;
    self.imapSession.port = 993;
    self.imapSession.username = username;
    self.imapSession.password = password;
    if (oauth2Token != nil) {
        self.imapSession.OAuth2Token = oauth2Token;
        self.imapSession.authType = MCOAuthTypeXOAuth2;
    }
    self.imapSession.connectionType = MCOConnectionTypeTLS;
    WSPMasterViewController *__weak weakSelf = self;
    self.imapSession.connectionLogger =
        ^(void *connectionID, MCOConnectionLogType type, NSData *data) {
        @synchronized(weakSelf) {
            if (type != MCOConnectionLogTypeSentPrivate) {
                //                NSLog(@"event logged:%p %i withData: %@",
                //                connectionID, type, [[NSString alloc]
                //                initWithData:data
                //                encoding:NSUTF8StringEncoding]);
            }
        }
    };

    // Reset the inbox
    self.messages = nil;
    self.totalNumberOfInboxMessages = -1;
    self.isLoading = NO;
    self.messagePreviews = [NSMutableDictionary dictionary];
    [self.tableView reloadData];

    NSLog(@"checking account");
    self.imapCheckOp = [self.imapSession checkAccountOperation];
    [self.imapCheckOp start:^(NSError *error) {
        WSPMasterViewController *strongSelf = weakSelf;
        NSLog(@"finished checking account.");
        if (error == nil) {
            [strongSelf loadLastNMessages:NUMBER_OF_MESSAGES_TO_LOAD];
        } else {
            NSLog(@"error loading account: %@", error);
        }

        strongSelf.imapCheckOp = nil;
    }];
}

- (void)loadLastNMessages:(NSUInteger)nMessages {
    self.isLoading = YES;

    MCOIMAPMessagesRequestKind requestKind =
        (MCOIMAPMessagesRequestKind)(MCOIMAPMessagesRequestKindHeaders |
                                     MCOIMAPMessagesRequestKindStructure |
                                     MCOIMAPMessagesRequestKindInternalDate |
                                     MCOIMAPMessagesRequestKindHeaderSubject |
                                     MCOIMAPMessagesRequestKindFlags);

    NSString *inboxFolder = @"INBOX";
    MCOIMAPFolderInfoOperation *inboxFolderInfo =
        [self.imapSession folderInfoOperation:inboxFolder];

    [inboxFolderInfo start:^(NSError *error, MCOIMAPFolderInfo *info) {
        BOOL totalNumberOfMessagesDidChange =
            self.totalNumberOfInboxMessages != [info messageCount];

        self.totalNumberOfInboxMessages = [info messageCount];

        NSUInteger numberOfMessagesToLoad =
            MIN(self.totalNumberOfInboxMessages, nMessages);

        if (numberOfMessagesToLoad == 0) {
            self.isLoading = NO;
            return;
        }

        MCORange fetchRange;

        // If total number of messages did not change since last fetch,
        // assume nothing was deleted since our last fetch and just
        // fetch what we don't have
        if (!totalNumberOfMessagesDidChange && self.messages.count) {
            numberOfMessagesToLoad -= self.messages.count;

            fetchRange = MCORangeMake(self.totalNumberOfInboxMessages -
                                          self.messages.count -
                                          (numberOfMessagesToLoad - 1),
                                      (numberOfMessagesToLoad - 1));
        }

        // Else just fetch the last N messages
        else {
            fetchRange = MCORangeMake(
                self.totalNumberOfInboxMessages - (numberOfMessagesToLoad - 1),
                (numberOfMessagesToLoad - 1));
        }

        self.imapMessagesFetchOp = [self.imapSession
            fetchMessagesByNumberOperationWithFolder:inboxFolder
                                         requestKind:requestKind
                                             numbers:[MCOIndexSet
                                                         indexSetWithRange:
                                                             fetchRange]];

        [self.imapMessagesFetchOp setProgress:^(unsigned int progress) {
            NSLog(@"Progress: %u of %lu", progress,
                  (unsigned long)numberOfMessagesToLoad);
        }];

        __weak WSPMasterViewController *weakSelf = self;
        [self.imapMessagesFetchOp start:^(NSError *error, NSArray *messages,
                                          MCOIndexSet *vanishedMessages) {
            WSPMasterViewController *strongSelf = weakSelf;
            NSLog(@"fetched all messages.");

            [self.refreshControl endRefreshing];
            self.isLoading = NO;

            NSSortDescriptor *sort =
                [NSSortDescriptor sortDescriptorWithKey:@"header.date"
                                              ascending:NO];

            NSMutableArray *combinedMessages =
                [NSMutableArray arrayWithArray:messages];
            [combinedMessages addObjectsFromArray:strongSelf.messages];

            strongSelf.messages =
                [combinedMessages sortedArrayUsingDescriptors:@[ sort ]];

            //[self.coreDataService saveEmails:strongSelf.messages];
            [strongSelf.tableView reloadData];
        }];
    }];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    NSLog(@"%s", __PRETTY_FUNCTION__);
}

#pragma mark - Table View

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView
    numberOfRowsInSection:(NSInteger)section {
    if (section == 1) {
        if (self.totalNumberOfInboxMessages >= 0) return 1;

        return 0;
    }

    return self.messages.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    switch (indexPath.section) {
        case 0: {
            WSPTableViewCell *cell =
                [tableView dequeueReusableCellWithIdentifier:mailCellIdentifier
                                                forIndexPath:indexPath];

            if (!cell) {
                cell = [[WSPTableViewCell alloc]
                      initWithStyle:UITableViewCellStyleDefault
                    reuseIdentifier:mailCellIdentifier];
            }
            MCOIMAPMessage *message = self.messages[indexPath.row];

            if (message.flags == 0) {
                cell.backgroundColor = [UIColor colorWithRed:0.894
                                                       green:0.914
                                                        blue:0.973
                                                       alpha:1.000];
            }

            cell.authorLabel.text = message.header.from.displayName;
            cell.titleLabel.text = message.header.subject;
            cell.timestampLabel.text = message.header.date.timeAgoSinceNow;

            cell.authorLabel.font =
                [UIFont fontWithName:@"ProximaNova-Semibold" size:16];
            cell.titleLabel.font =
                [UIFont fontWithName:@"ProximaNova-Regular" size:14];
            cell.timestampLabel.font =
                [UIFont fontWithName:@"ProximaNova-Regular" size:12];
            cell.previewLabel.font =
                [UIFont fontWithName:@"ProximaNova-Regular" size:12];

            NSString *uidKey = [NSString stringWithFormat:@"%d", message.uid];
            NSString *cachedPreview = self.messagePreviews[uidKey];

            if (cachedPreview) {
                cell.previewLabel.text = cachedPreview;
            } else {
                cell.messageRenderingOperation = [self.imapSession
                    plainTextBodyRenderingOperationWithMessage:message
                                                        folder:@"INBOX"];

                [cell.messageRenderingOperation
                    start:^(NSString *plainTextBodyString, NSError *error) {
                        if ([plainTextBodyString hasPrefix:@" "] &&
                            [plainTextBodyString length] > 1) {
                            plainTextBodyString =
                                [plainTextBodyString substringFromIndex:1];
                        }
                        cell.previewLabel.text = plainTextBodyString;
                        cell.messageRenderingOperation = nil;
                        self.messagePreviews[uidKey] = plainTextBodyString;
                    }];
            }
            return cell;
            break;
        }

        case 1: {
            UITableViewCell *cell = [tableView
                dequeueReusableCellWithIdentifier:mailCellIdentifier];

            if (!cell) {
                cell = [[UITableViewCell alloc]
                      initWithStyle:UITableViewCellStyleSubtitle
                    reuseIdentifier:inboxInfoIdentifier];

                cell.textLabel.font =
                    [UIFont fontWithName:@"ProximaNova" size:11];
                cell.textLabel.textAlignment = NSTextAlignmentCenter;
                cell.detailTextLabel.textAlignment = NSTextAlignmentCenter;
            }

            if (self.messages.count < self.totalNumberOfInboxMessages) {
                cell.textLabel.text = [NSString
                    stringWithFormat:@"Load %u more",
                                     MIN(self.totalNumberOfInboxMessages -
                                             self.messages.count,
                                         NUMBER_OF_MESSAGES_TO_LOAD)];
            } else {
                cell.textLabel.text = nil;
            }

            cell.detailTextLabel.text = [NSString
                stringWithFormat:@"%ld message(s)",
                                 (long)self.totalNumberOfInboxMessages];

            cell.accessoryView = self.loadMoreActivityView;

            if (self.isLoading)
                [self.loadMoreActivityView startAnimating];
            else
                [self.loadMoreActivityView stopAnimating];

            return cell;
            break;
        }

        default:
            return nil;
            break;
    }
    return nil;
}

- (void)showSettingsViewController:(id)sender {
    [self.imapMessagesFetchOp cancel];

    WSPSettingsViewController *settingsViewController =
        [[WSPSettingsViewController alloc] initWithNibName:nil bundle:nil];
    settingsViewController.delegate = self;
    UINavigationController *nav = [[UINavigationController alloc]
        initWithRootViewController:settingsViewController];
    [self presentViewController:nav animated:YES completion:nil];
}

- (void)settingsViewControllerFinished:
            (WSPSettingsViewController *)viewController {
    [self dismissViewControllerAnimated:YES completion:nil];

    NSString *username =
        [[NSUserDefaults standardUserDefaults] stringForKey:UsernameKey];
    NSString *password =
        [[FXKeychain defaultKeychain] objectForKey:PasswordKey];
    NSString *hostname =
        [[NSUserDefaults standardUserDefaults] objectForKey:HostnameKey];

    if (![username isEqualToString:self.imapSession.username] ||
        ![password isEqualToString:self.imapSession.password] ||
        ![hostname isEqualToString:self.imapSession.hostname]) {
        self.imapSession = nil;
        [self loadAccountWithUsername:username
                             password:password
                             hostname:hostname
                          oauth2Token:nil];
    }
}

- (void)tableView:(UITableView *)tableView
    didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    switch (indexPath.section) {
        case 0: {
            MCOIMAPMessage *msg = self.messages[indexPath.row];
            MCTMsgViewController *vc = [[MCTMsgViewController alloc] init];
            vc.folder = @"INBOX";
            vc.message = msg;
            vc.session = self.imapSession;
            [self.navigationController pushViewController:vc animated:YES];

            break;
        }

        case 1: {
            UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];

            if (!self.isLoading &&
                self.messages.count < self.totalNumberOfInboxMessages) {
                [self loadLastNMessages:self.messages.count +
                                        NUMBER_OF_MESSAGES_TO_LOAD];
                cell.accessoryView = self.loadMoreActivityView;
                [self.loadMoreActivityView startAnimating];
            }

            [tableView deselectRowAtIndexPath:indexPath animated:YES];
            break;
        }

        default:
            break;
    }
}

@end
