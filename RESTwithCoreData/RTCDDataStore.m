//
//  RTCDDataStore.m
//  RESTwithCoreData
//
//  Created by Yi Gu on 11/27/12.
//  Copyright (c) 2012 Yi Gu. All rights reserved.
//

#import "RTCDDataStore.h"
#import <Accounts/Accounts.h>
#import <Social/Social.h>
#import <CoreData/CoreData.h>

@interface RTCDDataStore ()
@property (readonly, nonatomic) NSManagedObjectContext *managedObjectContext;
@property (strong, nonatomic) NSDateFormatter *dateFormatter;
@end

@implementation RTCDDataStore
+ (RTCDDataStore *)sharedDataStore {
    static RTCDDataStore *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (id)init {
    self = [super init];
    if (self) {
        self.updating = NO;
        [self managedObjectContext];
        
        NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
        NSLocale *usLocale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US"];
        [dateFormatter setLocale:usLocale];
        [dateFormatter setDateStyle:NSDateFormatterLongStyle];
        [dateFormatter setFormatterBehavior:NSDateFormatterBehavior10_4];

        // see http://unicode.org/reports/tr35/tr35-6.html#Date_Format_Patterns
        [dateFormatter setDateFormat: @"EEE MMM dd HH:mm:ss Z yyyy"];
        self.dateFormatter = dateFormatter;
    }
    return self;
}

#pragma mark - CoreDataの初期化
- (NSManagedObjectContext *)managedObjectContext {
    static NSManagedObjectContext *moc = nil;

    if (moc != nil) {
        return moc;
    }

    // -------- MOCの初期化 ----------

    // 1. ObjectModelをロードする。
    NSURL *modelUrl = [[NSBundle mainBundle] URLForResource:@"TwitterModel" withExtension:@"momd"];
    NSManagedObjectModel *objectModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelUrl];

    // 2. Coordinatorを初期化し、ObjectModelとバインディングする。
    NSPersistentStoreCoordinator *coordinator =
    [[NSPersistentStoreCoordinator alloc]
     initWithManagedObjectModel: objectModel];

    // 3. ローカルストーレージを初期化する。
    NSString *STORE_TYPE = NSSQLiteStoreType;
    NSString *STORE_FILENAME = @"TwitterUpdates.cdcli";

    NSError *error;
    NSURL *documentsDir = [[NSFileManager defaultManager] URLForDirectory:NSDocumentDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:NO error:NULL];
    NSURL *url = [documentsDir URLByAppendingPathComponent:STORE_FILENAME];

    // 4. ストーレージをcoordinatorにバインディングする。
    NSPersistentStore *newStore = [coordinator addPersistentStoreWithType:STORE_TYPE
                                                            configuration:nil URL:url options:nil
                                                                    error:&error];

    if (newStore == nil) {
        NSLog(@"Store Configuration Failure\n%@",
              ([error localizedDescription] != nil) ?
              [error localizedDescription] : @"Unknown Error");
    }
    
    moc = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
    [moc setPersistentStoreCoordinator:coordinator];

    return moc;
}

#pragma mark - Timelineの更新
- (void)fetchUpdateWithAccount:(ACAccount *)account {
    //APIコールの準備
    NSURL *publicTimelineURL = [NSURL URLWithString:@"https://api.twitter.com/1.1/statuses/home_timeline.json"];

    RTCDStatus *latestUpdate = [self latestUpdate];
    NSMutableDictionary *parameters = [NSMutableDictionary dictionaryWithDictionary:@{
        @"count":[@(5) stringValue],
        @"include_entities":[@(NO) stringValue],
    }];
    
    if (latestUpdate) {
        parameters[@"since_id"] = [latestUpdate.statusId stringValue];
    }

    NSLog(@"Request parameters:\n%@", parameters);

    SLRequest *listRequest = [SLRequest requestForServiceType:SLServiceTypeTwitter requestMethod:SLRequestMethodGET URL:publicTimelineURL parameters:parameters];
    listRequest.account = account;

    // Perform the request created above and create a handler block to handle the response.
    // APIをコールして、ブロックで非同期に結果を処理する。
    self.updating = YES;
    [listRequest performRequestWithHandler:^(NSData *responseData, NSHTTPURLResponse *urlResponse, NSError *error) {
        NSString *output;
        if ([urlResponse statusCode] == 200) {

            // Parse the responseData, which we asked to be in JSON format for this request, into an NSDictionary using NSJSONSerialization.

            NSError *jsonParsingError = nil;
            NSArray *publicTimeline = [NSJSONSerialization JSONObjectWithData:responseData options:0 error:&jsonParsingError];
            output = [NSString stringWithFormat:@"HTTP response status: %i\nPublic timeline:\n%@", [urlResponse statusCode], publicTimeline];
            [self updateTimeline:publicTimeline];
        } else {
            output = [NSString stringWithFormat:@"HTTP response status: %i\n%@", [urlResponse statusCode], [NSString stringWithUTF8String:[responseData bytes]]];
        }
        NSLog(@"%@", output);
        self.updating = NO;
    }];
}

- (void)fetchUpdate {
    ACAccountStore *account = [[ACAccountStore alloc] init];
    ACAccountType *accountType = [account accountTypeWithAccountTypeIdentifier:
                                  ACAccountTypeIdentifierTwitter];

    [account requestAccessToAccountsWithType:accountType options:nil
                                  completion:^(BOOL granted, NSError *error) {
        if (granted == YES) {
            NSArray *arrayOfAccounts = [account accountsWithAccountType:accountType];

            if ([arrayOfAccounts count] > 0) {
                ACAccount *twitterAccount = [arrayOfAccounts lastObject];
                //アカウントを取ってから、timelineを更新する。
                [self fetchUpdateWithAccount:(ACAccount *)twitterAccount];
            }
        }
    }];
}

- (RTCDStatus *)latestUpdate {
    NSManagedObjectContext *moc = [self managedObjectContext];
    NSFetchRequest *request = [NSFetchRequest new];
    request.entity = [NSEntityDescription entityForName:@"RTCDStatus" inManagedObjectContext:moc];
    NSSortDescriptor *sortDesc = [NSSortDescriptor sortDescriptorWithKey:@"timestamp" ascending:NO];
    request.sortDescriptors = @[sortDesc];
    request.fetchLimit = 1;

    NSError *error;
    NSArray *result = [moc executeFetchRequest:request error:&error];

    return result.count ? result.lastObject : nil;
}

- (RTCDStatus *)createUpdate{
    NSManagedObjectContext *moc = [self managedObjectContext];
    return [NSEntityDescription insertNewObjectForEntityForName:@"RTCDStatus" inManagedObjectContext:moc];
}

- (void)updateTimeline:(NSArray *)timeline {
    for (id status in [timeline reverseObjectEnumerator]) {
        RTCDStatus *update = [self createUpdate];
        update.timestamp = [self.dateFormatter dateFromString:[status valueForKeyPath:@"created_at"]];
        update.statusId = [status valueForKeyPath:@"id"];
        update.content = [status valueForKeyPath:@"text"];
        update.screenName = [status valueForKeyPath:@"user.screen_name"];
    }
}

// アプリはバックグランドになる時に、saveAllを呼び出し、データーを保存する。
- (void)saveAll {
    NSError *error;
    [self.managedObjectContext save:&error];
    if (error) {
        NSLog(@"Failed to save data:\n%@", [error localizedDescription]);
    }
}
@end
