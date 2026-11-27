/*
 
 Songs can be divied into clips.
 
 */

#import <Foundation/Foundation.h>

@interface CacheItem : NSObject
{
	NSString			*key;
	id					item;
	NSUInteger			stamp;
}

@property (nonatomic, strong) NSString				*key;
@property (nonatomic, strong) id					item;
@property (nonatomic, assign) NSUInteger			stamp;

@end

// --------------------------------------------------------------------------------------------------------
// --------------------------------------------------------------------------------------------------------
