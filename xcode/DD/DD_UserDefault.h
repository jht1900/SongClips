/*
 Copyright (C) 2008 John Henry Thompson. All Rights Reserved.
 */


#import <UIKit/UIKit.h>

// ----------------------------------------------------------------------------------------------------------

// Entries for remoteSite. filesDict

@interface DD_UserDefault : NSObject
{
	NSMutableDictionary	*dict;
	BOOL				dirty;
}

@property (nonatomic, strong) NSMutableDictionary	*dict;
@property (nonatomic, assign) BOOL					dirty;

+ (DD_UserDefault *) default;

- (void) setObject: (id) obj forKey: (NSString *) key;
- (void) setBool: (BOOL) it forKey: (NSString *) key;
- (void) setFloat: (float) it forKey: (NSString *) key;
- (void) setInteger: (NSInteger) it forKey: (NSString *) key;

- (id) objectForKey: (NSString *) key;
- (BOOL) boolForKey: (NSString *) key;
- (float) floatForKey: (NSString *) key;
- (NSInteger) integerForKey: (NSString *) key;

- (void) removeObjectForKey: (NSString *) key; 

- (void) restoreFromDisk;
- (void) synchronize;

@end

// ----------------------------------------------------------------------------------------------------------
// ----------------------------------------------------------------------------------------------------------
