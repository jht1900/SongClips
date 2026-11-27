/*

*/

#import <Foundation/Foundation.h>

#import "CacheItem.h"

// --------------------------------------------------------------------------------------------------------
@interface Cache : NSObject
{	
	NSMutableDictionary		*dict;	// of CacheItem 
	NSUInteger				stamp;
	NSUInteger				allowance;
	NSUInteger				itemCount;
}

@property (nonatomic, assign) NSUInteger						allowance;

- (void) addItem: (id) newItem key: (NSString *) key;

- (id) findItem: (NSString *) key ;

- (void) flushForKey: (NSString *) key;

@end


// --------------------------------------------------------------------------------------------------------
// --------------------------------------------------------------------------------------------------------
