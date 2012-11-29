//
//  RTCDDataStore.h
//  RESTwithCoreData
//
//  Created by Yi Gu on 11/27/12.
//  Copyright (c) 2012 Yi Gu. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RTCDStatus.h"

@interface RTCDDataStore : NSObject
@property (assign, nonatomic, getter = isUpdating) BOOL updating;

+ (RTCDDataStore *)sharedDataStore;
- (NSManagedObjectContext *)managedObjectContext;

- (void)saveAll;
- (void)fetchUpdate;
@end
