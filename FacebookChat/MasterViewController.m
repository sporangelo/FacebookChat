//
//  MasterViewController.m
//  FacebookChat
//
//  Created by Kanybek Momukeyev on 1/17/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "MasterViewController.h"
#import "ChatViewController.h"
#import "EGOImageView.h"
#import "TDBadgedCell.h"
#import "Conversation.h"
#import "Message.h"
#import "XMPP.h"

@implementation MasterViewController

@synthesize detailViewController = _detailViewController;
@synthesize fetchedResultsController = __fetchedResultsController;
@synthesize managedObjectContext = __managedObjectContext;


- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        self.title = NSLocalizedString(@"Friends", @"Friends");
    }
    return self;
}
							
- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self 
                                                    name:@"facebookAuthorized" 
                                                  object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self 
                                                    name:@"messageCome" 
                                                  object:nil];
    [_detailViewController release];
    [__fetchedResultsController release];
    [__managedObjectContext release];
    [super dealloc];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

#pragma mark - View lifecycle

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    NSError *error = nil;
	if (![[self fetchedResultsController] performFetch:&error]) {
		
		NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
		abort();
	}	
    [self.tableView reloadData];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(apiGraphFriends) name:@"facebookAuthorized" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(messageReceived:)
                                                 name:@"messageCome" object:nil];
    
    NSError *error = nil;
	if (![[self fetchedResultsController] performFetch:&error]) {
		
		NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
		abort();
	}	
}


- (void)viewDidUnload
{
    [super viewDidUnload];
}


#pragma mark - Facebook API Calls

- (void)apiGraphFriends {
    AppDelegate *delegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    [[delegate facebook] requestWithGraphPath:@"me/friends" andDelegate:self];
}


#pragma mark - FBRequestDelegate Methods

- (void)request:(FBRequest *)request didLoad:(id)result {
    

    if ([result isKindOfClass:[NSArray class]] && ([result count] > 0)) {
        result = [result objectAtIndex:0];
    }
    

    NSArray *resultData = [result objectForKey:@"data"];
    
    // ok, here one moment.
    // There are facebook friends, we should create conversation to them, if our conversation is empty.
    // if our conversation is not emty, then what ?

    NSArray *array = [__fetchedResultsController fetchedObjects];
    
    if([array count] == 0) {
        // our local cached conversation is empty.
        for (NSDictionary *facebookData in resultData) {
            
            NSString *name = [[facebookData objectForKey:@"name"] copy];
            NSString *frienId = [[facebookData objectForKey:@"id"] copy];
            
            Conversation *conversation = (Conversation *)[NSEntityDescription
                                                          insertNewObjectForEntityForName:@"Conversation"
                                                          inManagedObjectContext:self.managedObjectContext];
            conversation.facebookId = frienId;
            conversation.facebookName = name;
            
            conversation.badgeNumber = [NSNumber numberWithInt:0];
            
            [name release];
            [frienId release];
        }
        
        NSError *error;
        if (![self.managedObjectContext save:&error]) { 
            // TODO: Handle the error appropriately.
            NSLog(@"Mass message creation error %@, %@", error, [error userInfo]);
        }

    }else if ([array count] == [resultData count]) {
        // our local cached conversation same as facebook friends.
    }else if([array count] > [resultData count]) {
        // our local cached conversation less than facebook friends.
        // here unwanted facebook friend removed, so we should
        // delete him, from our local cache.
        
        // algorithm:
        // (1) find, which facebook friend is removed.
        // (2) delete him, and save cache.
        
    }else if([array count] < [resultData count]) {
        // our local cached conversation greater than facebook friends.
        // here new facebook friend added, so we should add him,
        // to our local cache.
        
        // algorithm:
        // (1) find, which facebook friend is added.
        // (2) add him, and save cache.
    }    
    
    [self.tableView reloadData];
}

#pragma mark Private methods

- (void)messageReceived:(NSNotification*)textMessage {
    
    XMPPMessage *message = textMessage.object;        
    if([message isChatMessageWithBody]) {
        
        NSString *adressString = [NSString stringWithFormat:@"%@",[message fromStr]];
        NSString *newStr = [adressString substringWithRange:NSMakeRange(1, [adressString length]-1)];
        NSString *facebookID = [NSString stringWithFormat:@"%@",[[newStr componentsSeparatedByString:@"@"] objectAtIndex:0]];
       
        NSLog(@"FACEBOOK_ID:%@",facebookID);
        
        Conversation *conversation = [[self findConversationWithId:facebookID] retain];
        
        Message *msg = (Message *)[NSEntityDescription
                                   insertNewObjectForEntityForName:@"Message"
                                   inManagedObjectContext:conversation.managedObjectContext];
        
        msg.text = [NSString stringWithFormat:@"%@",[[message elementForName:@"body"] stringValue]];
        msg.sentDate = [NSDate date];
        // message did come, this will be on left
        msg.messageStatus = TRUE;
        
        // increase badge number.
        int badgeNumber = [conversation.badgeNumber intValue];
        badgeNumber++;
        conversation.badgeNumber = [NSNumber numberWithInt:badgeNumber];
        
        [conversation addMessagesObject:msg];        
        NSError *error;
        if (![conversation.managedObjectContext save:&error]) { 
            // TODO: Handle the error appropriately.
            NSLog(@"Mass message creation error %@, %@", error, [error userInfo]);
        }
        
        [conversation release];
        [self.tableView reloadData];
    }
}

- (Conversation*)findConversationWithId:(NSString*)facebookId {
    for(Conversation *conversation in [__fetchedResultsController fetchedObjects]) {
        if([conversation.facebookId isEqualToString:facebookId]) {
            return  conversation;
        }
    }
    return nil;
}


#pragma mark UItableView Delegate

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return [[self.fetchedResultsController sections] count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    id <NSFetchedResultsSectionInfo> sectionInfo = [[self.fetchedResultsController sections] objectAtIndex:section];
    return [sectionInfo numberOfObjects];
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"Cell";
    TDBadgedCell *cell = [[[TDBadgedCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier] autorelease];
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;

    Conversation *conv = (Conversation *)[__fetchedResultsController objectAtIndexPath:indexPath];    
    cell.textLabel.text = [NSString stringWithFormat:@" %@",conv.facebookName];
    cell.textLabel.font = [UIFont boldSystemFontOfSize:12.0];
    
    // for badges
    if([conv.badgeNumber intValue] != 0) {
        cell.badgeString = [NSString stringWithFormat:@"%d", [conv.badgeNumber intValue]];
        cell.badgeColor = [UIColor colorWithRed:0.197 green:0.592 blue:0.219 alpha:1.000];
        cell.badge.radius = 9;
    }
    
    EGOImageView *imageView = [[EGOImageView alloc] initWithPlaceholderImage:nil];
    NSString *url = [[NSString alloc] 
                     initWithFormat:@"https://graph.facebook.com/%@/picture",conv.facebookId];
    NSURL *imageUrl = [NSURL URLWithString:url];
    [url release];
    [imageView setImageURL:imageUrl];
    cell.imageView.image = imageView.image;
    [imageView release];

    //[self configureCell:cell atIndexPath:indexPath];
    return cell;
}

// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the specified item to be editable.
    return NO;
}


- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the managed object for the given index path
        NSManagedObjectContext *context = [self.fetchedResultsController managedObjectContext];
        [context deleteObject:[self.fetchedResultsController objectAtIndexPath:indexPath]];
        
        // Save the context.
        NSError *error = nil;
        if (![context save:&error]) {
            /*
             Replace this implementation with code to handle the error appropriately.
             
             abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development. 
             */
            NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
            abort();
        }
    }   
}

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
    // The table view should not be re-orderable.
    return NO;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{    
    Conversation *conv = (Conversation *)[__fetchedResultsController objectAtIndexPath:indexPath];    
    ChatViewController *chatViewController = [[ChatViewController alloc] init];
    chatViewController.conversation = conv;

    [self.navigationController pushViewController:chatViewController animated:YES];
    [chatViewController release];
}


#pragma mark - Fetched results controller

- (NSFetchedResultsController *)fetchedResultsController
{
    if (__fetchedResultsController != nil) {
        return __fetchedResultsController;
    }
    
    // Set up the fetched results controller.
    // Create the fetch request for the entity.
    NSFetchRequest *fetchRequest = [[[NSFetchRequest alloc] init] autorelease];
    // Edit the entity name as appropriate.
    NSEntityDescription *entity = [NSEntityDescription entityForName:@"Conversation" inManagedObjectContext:self.managedObjectContext];
    [fetchRequest setEntity:entity];
    
    // Set the batch size to a suitable number.
    [fetchRequest setFetchBatchSize:20];
    
    // Edit the sort key as appropriate.
    NSSortDescriptor *sortDescriptor = [[[NSSortDescriptor alloc] initWithKey:@"facebookName" ascending:NO] autorelease];
    NSArray *sortDescriptors = [NSArray arrayWithObjects:sortDescriptor, nil];
    
    [fetchRequest setSortDescriptors:sortDescriptors];
    
    // Edit the section name key path and cache name if appropriate.
    // nil for section name key path means "no sections".
    NSFetchedResultsController *aFetchedResultsController = [[[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest managedObjectContext:self.managedObjectContext sectionNameKeyPath:nil cacheName:@"Master"] autorelease];
    aFetchedResultsController.delegate = self;
    self.fetchedResultsController = aFetchedResultsController;
    
	NSError *error = nil;
	if (![self.fetchedResultsController performFetch:&error]) {
	    /*
	     Replace this implementation with code to handle the error appropriately.

	     abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development. 
	     */
	    NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
	    abort();
	}
    
    return __fetchedResultsController;
}    

- (void)controllerWillChangeContent:(NSFetchedResultsController *)controller
{
    [self.tableView beginUpdates];
}

- (void)controller:(NSFetchedResultsController *)controller didChangeSection:(id <NSFetchedResultsSectionInfo>)sectionInfo
           atIndex:(NSUInteger)sectionIndex forChangeType:(NSFetchedResultsChangeType)type
{
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
      newIndexPath:(NSIndexPath *)newIndexPath
{
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

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller
{
    [self.tableView endUpdates];
}

/*
// Implementing the above methods to update the table view in response to individual changes may have performance implications if a large number of changes are made simultaneously. If this proves to be an issue, you can instead just implement controllerDidChangeContent: which notifies the delegate that all section and object changes have been processed. 
 
 - (void)controllerDidChangeContent:(NSFetchedResultsController *)controller
{
    // In the simplest, most efficient, case, reload the table view.
    [self.tableView reloadData];
}
 */

- (void)configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath
{
    //NSManagedObject *managedObject = [self.fetchedResultsController objectAtIndexPath:indexPath];
    //cell.textLabel.text = [[managedObject valueForKey:@"timeStamp"] description];
}

/*
- (void)insertNewObject
{
    // Create a new instance of the entity managed by the fetched results controller.
    NSManagedObjectContext *context = [self.fetchedResultsController managedObjectContext];
    NSEntityDescription *entity = [[self.fetchedResultsController fetchRequest] entity];
    NSManagedObject *newManagedObject = [NSEntityDescription insertNewObjectForEntityForName:@"Conversation" inManagedObjectContext:context];
    
    // If appropriate, configure the new managed object.
    // Normally you should use accessor methods, but using KVC here avoids the need to add a custom class to the template.
    //[newManagedObject setValue:[NSDate date] forKey:@"timeStamp"];
    
    // Save the context.
    NSError *error = nil;
    if (![context save:&error]) {
        
         Replace this implementation with code to handle the error appropriately.
         
         abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development. 
 
        NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
        abort();
    }
}
*/
@end
