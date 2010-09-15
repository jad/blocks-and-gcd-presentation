#import "Event.h"

#import "Person.h"

@implementation Event 

@dynamic timeStamp;
@dynamic people;

@end

@implementation Event (PersonHelpers)

- (void)addLotsOfPeople
{
    NSManagedObjectContext * moc = [self managedObjectContext];
    for (NSUInteger i = 0; i < 5000; ++i) {
        Person * person =
            [NSEntityDescription insertNewObjectForEntityForName:@"Person"
                                          inManagedObjectContext:moc];
        [person setName:[NSString stringWithFormat:@"Person %u", i]];
        [person setEvent:self];
    }
}

@end
