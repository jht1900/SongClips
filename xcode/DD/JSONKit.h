/*
 Copyright (C) 2008 John Henry Thompson. All Rights Reserved.
 */

#import <Foundation/Foundation.h>

// --------------------------------------------------------------------------------------------------------

@interface NSString (JSONKitDeserializing)
- (id)objectFromJSONString;
- (id)mutableObjectFromJSONString;
@end

@interface NSArray (JSONKitSerializing)
- (NSString *)JSONString;
@end

@interface NSDictionary (JSONKitSerializing)
- (NSString *)JSONString;
@end



// --------------------------------------------------------------------------------------------------------
// --------------------------------------------------------------------------------------------------------
