#import <CoreData/CoreData.h>

@class Event;

@interface Person :  NSManagedObject  
{
}

@property (nonatomic, retain) NSString * name;
@property (nonatomic, retain) Event * event;

@end



