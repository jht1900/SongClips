/*

*/

#import "Cache.h"
#import "AppDefs.h"

@implementation Cache

@synthesize allowance;

// ----------------------------------------------------------------------------------------------------------
- (id)init
{
	self = [super init];
	if (self)
	{
		dict = [[NSMutableDictionary alloc] init];
	}
	return self;
}


// ----------------------------------------------------------------------------------------------------------

// ----------------------------------------------------------------------------------------------------------
- (void) flushOldest
{
	CacheItem	*citem = nil;
	CacheItem	*minCitem = nil;
	NSUInteger		minStamp = stamp;
	
	ATRACE2(@"Cache: flushOldest");
	
	for (NSString *key in dict)
	{
		citem = [dict objectForKey: key];
		ATRACE2(@"Cache: flushOldest citem=%@ citem.stamp=%d minStamp=%d", citem, citem.stamp, minStamp);
		if (! citem)
			continue;
		if (citem.stamp <= minStamp)
		{
			minStamp = citem.stamp;
			minCitem = citem;
		}
	}
	if (minCitem)
	{
		ATRACE2(@"Cache: flushOldest removing key=%@ item=%@ stamp=%d itemCount=%d", citem.key, citem.item, citem.stamp,itemCount);
		ATRACE(@"Cache: flushOldest removing item=%@ key=%@ stamp=%lu itemCount=%lu", 
							minCitem.item, [minCitem.key lastPathComponent], (unsigned long)minCitem.stamp, (unsigned long)itemCount);

		[dict setValue: nil forKey: minCitem.key];
		
		itemCount--;
	}
	else
	{
		ATRACE(@"Cache: flushOldest minCitem NULL itemCount=%lu", (unsigned long)itemCount);
	}
}


// ----------------------------------------------------------------------------------------------------------
- (void) addItem: (id) newItem key: (NSString *) key
{
	CacheItem	*citem = [[CacheItem alloc] init];
	
	ATRACE2(@"Cache: addItem: newItem=%@ key=%@ itemCount=%d stamp=%d", newItem, key, itemCount, stamp);
	ATRACE(@"Cache: addItem: newItem=%@ key=%@ itemCount=%lu stamp=%lu", newItem, [key lastPathComponent], (unsigned long)itemCount, (unsigned long)stamp);

	stamp++;

	citem.item = newItem;
	citem.key = key;
	citem.stamp = stamp;
	
	itemCount++;
	if (itemCount >= allowance)
	{
		[self flushOldest];
	}
	[dict setValue:citem forKey:key];
}

// ----------------------------------------------------------------------------------------------------------
- (id) findItem: (NSString *) key 
{
	ATRACE2(@"Cache: findItem: key=%@", key);

	stamp++;
	CacheItem *citem = [dict objectForKey: key];
	if (citem)
	{
		ATRACE2(@"Cache: findItem: found item=%@", citem.item);
		citem.stamp = stamp;
		return citem.item;
	}
	return nil;
}

// ----------------------------------------------------------------------------------------------------------
- (void) flushForKey: (NSString *) key
{
	ATRACE(@"Cache: flushForKey: key=%@", key);
	
	CacheItem *citem = [dict objectForKey: key];
	if (citem)
	{
		ATRACE(@"Cache: flushForKey: removing key=%@ item=%@ stamp=%lu", [key lastPathComponent], citem.item, (unsigned long)citem.stamp);
		itemCount--;
		[dict setValue: nil forKey: key];
	}
}

// --------------------------------------------------------------------------------------------------------
// ----------------------------------------------------------------------------------------------------------

@end
