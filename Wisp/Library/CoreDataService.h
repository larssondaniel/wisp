//
//  CoreDataService.h
//  Wisp
//
//  Created by Daniel Larsson on 2014-09-14.
//  Copyright (c) 2014 Daniel Larsson. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface CoreDataService : NSObject

+ (id)sharedService;

- (IBAction)saveEmails:(NSArray *)emails;
// - (IBAction)findEmail:(id)sender;

@end
