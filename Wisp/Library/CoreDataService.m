//
//  CoreDataService.m
//  Wisp
//
//  Created by Daniel Larsson on 2014-09-14.
//  Copyright (c) 2014 Daniel Larsson. All rights reserved.
//

#import "CoreDataService.h"
#import "AppDelegate.h"
#import <MailCore/MailCore.h>

@implementation CoreDataService

+ (id)sharedService {
    static CoreDataService *sharedService = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedService = [[self alloc] init];
    });
    return sharedService;
}

- (IBAction)saveEmails:(NSArray *)emails {
    AppDelegate *appDelegate =
    [[UIApplication sharedApplication] delegate];

    NSManagedObjectContext *context =
    [appDelegate managedObjectContext];

    for (MCOIMAPMessage *email in emails) {
        NSManagedObject *newEmail;
        newEmail = [NSEntityDescription
                      insertNewObjectForEntityForName:@"Emails"
                      inManagedObjectContext:context];
        [newEmail setValue: email.header.subject forKey:@"subject"];
        [newEmail setValue: email.header.from forKey:@"from"];
        [newEmail setValue: email.header.to forKey:@"to"];
        [newEmail setValue: email.header.date forKey:@"date"];
        [newEmail setValue: email.header.messageID forKey:@"messageID"];

        NSError *error;
        [context save:&error];
    }
}

@end
