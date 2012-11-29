//
//  RTCDStatus.h
//  RESTwithCoreData
//
//  Created by Yi Gu on 11/28/12.
//  Copyright (c) 2012 Yi Gu. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>


@interface RTCDStatus : NSManagedObject

@property (nonatomic, retain) NSString * screenName;
@property (nonatomic, retain) NSString * content;
@property (nonatomic, retain) NSDate * timestamp;
@property (nonatomic, retain) NSNumber * statusId;

@end
