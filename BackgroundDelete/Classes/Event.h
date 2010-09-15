#import <CoreData/CoreData.h>

@class Person;

@interface Event :  NSManagedObject  
{
}

@property (nonatomic, retain) NSDate * timeStamp;
@property (nonatomic, retain) NSSet* people;

@end


@interface Event (CoreDataGeneratedAccessors)
- (void)addPeopleObject:(Person *)value;
- (void)removePeopleObject:(Person *)value;
- (void)addPeople:(NSSet *)value;
- (void)removePeople:(NSSet *)value;

@end


@interface Event (PersonHelpers)
- (void)addLotsOfPeople;
@end
