//
//  RTCDViewController.m
//  RESTwithCoreData
//
//  Created by Yi Gu on 11/27/12.
//  Copyright (c) 2012 Yi Gu. All rights reserved.
//

#import "RTCDViewController.h"
#import "RTCDDataStore.h"

@interface RTCDViewController () <NSFetchedResultsControllerDelegate>
@property (strong, nonatomic) NSFetchedResultsController *fetchResultController;
@property (readonly, nonatomic) UITableView *tableView;
@end

@implementation RTCDViewController

- (void)dealloc {
    [[RTCDDataStore sharedDataStore] removeObserver:self forKeyPath:@"updating"];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    RTCDDataStore *dataStroe = [RTCDDataStore sharedDataStore];    

    [self configureFetchController];
    self.refreshControl = [[UIRefreshControl alloc] init];
    [self.refreshControl addTarget:self action:@selector(fetchUpdate:) forControlEvents:UIControlEventValueChanged];
    [self.tableView registerClass:[UITableViewCell self] forCellReuseIdentifier:@"cell"];

    [dataStroe addObserver:self forKeyPath:@"updating" options:NSKeyValueObservingOptionNew context:NULL];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - tableView & its data source
- (UITableView *)tableView {
    return (UITableView *)self.view;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self.fetchResultController.fetchedObjects count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *reuseIdentifier = @"cell";
    UITableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:reuseIdentifier forIndexPath:indexPath];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuseIdentifier];
    }
    RTCDStatus *data = [self.fetchResultController objectAtIndexPath:indexPath];
    cell.textLabel.text = data.content;
    return cell;
}

#pragma mark - FetchedObjectsControllerの設定とデリゲート
- (void)configureFetchController {
    NSManagedObjectContext *moc = [[RTCDDataStore sharedDataStore] managedObjectContext];
    NSFetchRequest *fetchRequest = nil;
    fetchRequest = [NSFetchRequest fetchRequestWithEntityName:@"RTCDStatus"];
    NSSortDescriptor *sort = [[NSSortDescriptor alloc] initWithKey:@"timestamp" ascending:NO];
    [fetchRequest setSortDescriptors:[NSArray arrayWithObject:sort]];
    fetchRequest.fetchLimit = 5;
    NSFetchedResultsController *frc = nil;
    frc = [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest
                                              managedObjectContext:moc
                                                sectionNameKeyPath:nil
                                                         cacheName:@"Master"];
    self.fetchResultController = frc;
    [self.fetchResultController setDelegate:self];
    NSError *error = nil;
    NSAssert([self.fetchResultController performFetch:&error],
             @"Unresolved error %@\n%@", [error localizedDescription], [error userInfo]);
}

- (void)controllerWillChangeContent:(NSFetchedResultsController *)controller {
    [self.tableView beginUpdates];
}

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller {
    [self.tableView endUpdates];
}

- (void)controller:(NSFetchedResultsController *)controller
  didChangeSection:(id<NSFetchedResultsSectionInfo>)sectionInfo
           atIndex:(NSUInteger)sectionIndex
     forChangeType:(NSFetchedResultsChangeType)type {
    NSIndexSet *indexSet = [NSIndexSet indexSetWithIndex:sectionIndex];
    switch (type) {
        case NSFetchedResultsChangeDelete:
            [self.tableView deleteSections:indexSet withRowAnimation:UITableViewRowAnimationAutomatic];
            break;
        case NSFetchedResultsChangeInsert:
            [self.tableView insertSections:indexSet withRowAnimation:UITableViewRowAnimationAutomatic];
            break;

        default:
            break;
    }
}

- (void)controller:(NSFetchedResultsController *)controller didChangeObject:(id)anObject atIndexPath:(NSIndexPath *)indexPath forChangeType:(NSFetchedResultsChangeType)type newIndexPath:(NSIndexPath *)newIndexPath {
    NSArray *newArray = [NSArray arrayWithObject:newIndexPath ? newIndexPath : [NSIndexPath indexPathForRow:0 inSection:0]];
    NSArray *oldArray = [NSArray arrayWithObject:indexPath ? indexPath : [NSIndexPath indexPathForRow:0 inSection:0]];

    NSLog(@"Insert at indexPath:%d", [newIndexPath row]);
    NSLog(@"Status ID:%@", [anObject valueForKeyPath:@"statusId"]);
    NSLog(@"Timestamp:%@", [anObject valueForKeyPath:@"timestamp"]);
    switch(type) {
        case NSFetchedResultsChangeInsert:
            
            [[self tableView] insertRowsAtIndexPaths:newArray
                                    withRowAnimation:UITableViewRowAnimationFade];
            break;
        case NSFetchedResultsChangeDelete:
            [[self tableView] deleteRowsAtIndexPaths:oldArray
                                    withRowAnimation:UITableViewRowAnimationFade];
            break;
        case NSFetchedResultsChangeUpdate: {
            [self.tableView reloadRowsAtIndexPaths:newArray withRowAnimation:UITableViewRowAnimationFade];
            break;
        }
        case NSFetchedResultsChangeMove:
            [[self tableView] deleteRowsAtIndexPaths:oldArray
                                    withRowAnimation:UITableViewRowAnimationFade];
            [[self tableView] insertRowsAtIndexPaths:newArray
                                    withRowAnimation:UITableViewRowAnimationFade];
             break;
        }
}

#pragma mark - 最新のデータを取得、更新
- (IBAction)fetchUpdate:(id)sender {
    NSLog(@"%@", NSStringFromSelector(_cmd));
    [[RTCDDataStore sharedDataStore] fetchUpdate];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    NSNumber *updating = change[NSKeyValueChangeNewKey];
    if (![updating boolValue]) {
        [self.refreshControl endRefreshing];
    }
}
@end
