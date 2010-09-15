#import "RootViewController.h"
#import "Event.h"
#import "Person.h"

@interface RootViewController ()
- (void)configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath;

@property (nonatomic, retain) UIView * backgroundView;
@property (nonatomic, retain) UIProgressView * progressView;

- (void)initializeProgressView;
- (void)displayProgressView;
- (void)hideProgressView;
@end


@implementation RootViewController

@synthesize fetchedResultsController=fetchedResultsController_, managedObjectContext=managedObjectContext_;

@synthesize backgroundView, progressView;


#pragma mark -
#pragma mark View lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];

    // Set up the edit and add buttons.
    self.navigationItem.leftBarButtonItem = self.editButtonItem;
    
    UIBarButtonItem *addButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(insertNewObject)];
    self.navigationItem.rightBarButtonItem = addButton;
    [addButton release];

    [self initializeProgressView];
    background_queue = dispatch_queue_create("com.highorderbit.bgdelete", NULL);
}


// Implement viewWillAppear: to do additional setup before the view is presented.
- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
}

- (void)configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath
{
    NSManagedObject *managedObject = [self.fetchedResultsController objectAtIndexPath:indexPath];
    cell.textLabel.text = [[managedObject valueForKey:@"timeStamp"] description];
}


#pragma mark -
#pragma mark Add a new object

- (void)insertNewObject {
    // Create a new instance of the entity managed by the fetched results controller.
    NSManagedObjectContext *context = [self.fetchedResultsController managedObjectContext];
    NSEntityDescription *entity = [[self.fetchedResultsController fetchRequest] entity];
    Event *newManagedObject = [NSEntityDescription insertNewObjectForEntityForName:[entity name] inManagedObjectContext:context];

    // If appropriate, configure the new managed object.
    [newManagedObject setValue:[NSDate date] forKey:@"timeStamp"];

    [newManagedObject addLotsOfPeople];
    
    // Save the context.
    NSError *error = nil;
    if (![context save:&error]) {
        /*
         Replace this implementation with code to handle the error appropriately.
         
         abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development. If it is not possible to recover from the error, display an alert panel that instructs the user to quit the application by pressing the Home button.
         */
        NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
        abort();
    }
}


#pragma mark -
#pragma mark Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return [[self.fetchedResultsController sections] count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    id <NSFetchedResultsSectionInfo> sectionInfo = [[self.fetchedResultsController sections] objectAtIndex:section];
    return [sectionInfo numberOfObjects];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    static NSString *CellIdentifier = @"Cell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier] autorelease];
    }

    [self configureCell:cell atIndexPath:indexPath];
    
    return cell;
}

- (void)tableView:(UITableView *)tableView
    commitEditingStyle:(UITableViewCellEditingStyle)editingStyle
     forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        [self displayProgressView];

        Event * event = [self.fetchedResultsController objectAtIndexPath:indexPath];
        NSManagedObjectID * objId = [event objectID];

        NSManagedObjectContext * mainMoc = [self.fetchedResultsController managedObjectContext];
        NSPersistentStoreCoordinator * psc = [mainMoc persistentStoreCoordinator];

        NSNotificationCenter * nc = [NSNotificationCenter defaultCenter];
        id notificationObserver =
        [nc addObserverForName:NSManagedObjectContextDidSaveNotification
                        object:nil
                         queue:[NSOperationQueue mainQueue]
                    usingBlock:^(NSNotification * note) {
                        [mainMoc mergeChangesFromContextDidSaveNotification:note];
                    }];
        [notificationObserver retain];  // must be retained until unregistered

        dispatch_async(background_queue, ^{
            NSManagedObjectContext * asyncMoc = [[NSManagedObjectContext alloc] init];
            [asyncMoc setPersistentStoreCoordinator:psc];

            Event * e = (Event *) [asyncMoc objectWithID:objId];

            NSUInteger total = [[e people] count];
            NSSet * people = [[e people] copy];
            NSUInteger i = 0;
            for (Person * person in people) {
                [asyncMoc deleteObject:person];
                float progress = (float) ++i / total;
                NSLog(@"Deleted person %ld (%.0f%% complete)", i, progress * 100);
                dispatch_async(dispatch_get_main_queue(), ^{
                    [[self progressView] setProgress:progress];
                });
            }
            [people release], people = nil;;
            [asyncMoc deleteObject:e];

            NSError * error = nil;
            if (![asyncMoc save:&error])
                NSLog(@"Failed to save async moc: %@: %@", error, [error userInfo]);
            [asyncMoc release];

            dispatch_async(dispatch_get_main_queue(),  ^{
                [self hideProgressView];
                [nc removeObserver:notificationObserver];
                [notificationObserver release];
            });
        });
    }
}

#pragma mark -
#pragma mark Fetched results controller

- (NSFetchedResultsController *)fetchedResultsController {
    
    if (fetchedResultsController_ != nil) {
        return fetchedResultsController_;
    }
    
    /*
     Set up the fetched results controller.
    */
    // Create the fetch request for the entity.
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    // Edit the entity name as appropriate.
    NSEntityDescription *entity = [NSEntityDescription entityForName:@"Event" inManagedObjectContext:self.managedObjectContext];
    [fetchRequest setEntity:entity];
    
    // Set the batch size to a suitable number.
    [fetchRequest setFetchBatchSize:20];
    
    // Edit the sort key as appropriate.
    NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"timeStamp" ascending:NO];
    NSArray *sortDescriptors = [[NSArray alloc] initWithObjects:sortDescriptor, nil];
    
    [fetchRequest setSortDescriptors:sortDescriptors];
    
    // Edit the section name key path and cache name if appropriate.
    // nil for section name key path means "no sections".
    NSFetchedResultsController *aFetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest managedObjectContext:self.managedObjectContext sectionNameKeyPath:nil cacheName:@"Root"];
    aFetchedResultsController.delegate = self;
    self.fetchedResultsController = aFetchedResultsController;
    
    [aFetchedResultsController release];
    [fetchRequest release];
    [sortDescriptor release];
    [sortDescriptors release];
    
    NSError *error = nil;
    if (![fetchedResultsController_ performFetch:&error]) {
        /*
         Replace this implementation with code to handle the error appropriately.
         
         abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development. If it is not possible to recover from the error, display an alert panel that instructs the user to quit the application by pressing the Home button.
         */
        NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
        abort();
    }
    
    return fetchedResultsController_;
}    


#pragma mark -
#pragma mark Fetched results controller delegate


- (void)controllerWillChangeContent:(NSFetchedResultsController *)controller {
    NSLog(@"Beginning updates.");
    [self.tableView beginUpdates];
}


- (void)controller:(NSFetchedResultsController *)controller didChangeSection:(id <NSFetchedResultsSectionInfo>)sectionInfo
           atIndex:(NSUInteger)sectionIndex forChangeType:(NSFetchedResultsChangeType)type {
    
    switch(type) {
        case NSFetchedResultsChangeInsert:
            [self.tableView insertSections:[NSIndexSet indexSetWithIndex:sectionIndex] withRowAnimation:UITableViewRowAnimationFade];
            break;
            
        case NSFetchedResultsChangeDelete:
            [self.tableView deleteSections:[NSIndexSet indexSetWithIndex:sectionIndex] withRowAnimation:UITableViewRowAnimationFade];
            break;
    }
}


- (void)controller:(NSFetchedResultsController *)controller didChangeObject:(id)anObject
       atIndexPath:(NSIndexPath *)indexPath forChangeType:(NSFetchedResultsChangeType)type
      newIndexPath:(NSIndexPath *)newIndexPath {
    
    UITableView *tableView = self.tableView;
    
    switch(type) {
            
        case NSFetchedResultsChangeInsert:
            [tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:newIndexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;
            
        case NSFetchedResultsChangeDelete:
            [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;
            
        case NSFetchedResultsChangeUpdate:
            [self configureCell:[tableView cellForRowAtIndexPath:indexPath] atIndexPath:indexPath];
            break;
            
        case NSFetchedResultsChangeMove:
            [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationFade];
            [tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:newIndexPath]withRowAnimation:UITableViewRowAnimationFade];
            break;
    }
}


- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller {
    [self.tableView endUpdates];
}

- (void)dealloc {
    [fetchedResultsController_ release];
    [managedObjectContext_ release];
    [super dealloc];
}

#pragma mark -
#pragma mark Progress view

- (void)initializeProgressView
{
    UIView * parentView = [[self navigationController] view];

    CGRect parentFrame = [parentView frame];
    UIView * bgView = [[UIView alloc] initWithFrame:parentFrame];
    [bgView setBackgroundColor:[UIColor clearColor]];
    [self setBackgroundView:bgView];
    [bgView release];

    UIProgressView * progView =
        [[UIProgressView alloc]
        initWithProgressViewStyle:UIProgressViewStyleDefault];
    CGRect progFrame = [progView frame];
    progFrame.size.width = (NSInteger) (2 * parentFrame.size.width) / 3;
    progFrame.size.height = ceil(progFrame.size.height * 2);
    progFrame.origin.x =
        (NSInteger) (parentFrame.size.width - progFrame.size.width) / 2;
    progFrame.origin.y =
        (NSInteger) (parentFrame.size.height - progFrame.size.width) / 2;
    [progView setFrame:progFrame];
    [progView setAlpha:0];
    [[self backgroundView] addSubview:progView];
    [self setProgressView:progView];
    [progView release];
}


- (void)displayProgressView
{
    [[[self navigationController] view] addSubview:[self backgroundView]];

    [[UIApplication sharedApplication]
        setStatusBarStyle:UIStatusBarStyleBlackTranslucent animated:YES];

    [UIView animateWithDuration:0.3 animations:^{
        UIColor * bgColor =
            [[UIColor blackColor] colorWithAlphaComponent:0.8];
        [[self backgroundView] setBackgroundColor:bgColor];
        [[self progressView] setAlpha:1];
    }];
}

- (void)hideProgressView
{
    [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleDefault
                                                animated:YES];
    
        [UIView animateWithDuration:0.3
                         animations:^{
                             [[self backgroundView] setBackgroundColor:[UIColor clearColor]];
                             [[self progressView] setAlpha:0];
                         }
                         completion:^(BOOL finished){
                             [[self backgroundView] removeFromSuperview];
                         } ];
}

@end

