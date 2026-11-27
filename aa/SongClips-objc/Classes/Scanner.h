/*
 Copyright (C) 2008 John Henry Thompson. All Rights Reserved.
 */

#import <Foundation/Foundation.h>

@interface Scanner : NSObject
{
	NSScanner		*scanner;
	NSCharacterSet	*nlcs;
	NSCharacterSet	*emptycs;
	
	NSString		*line;
}

+ (Scanner*) scannerWithString: str;

- (BOOL) nextLine;
- (BOOL) hasPrefix: (NSString*) pref toString: (NSString **)pstr;
- (BOOL) hasPrefix: (NSString*) pref toFloatDuration: (NSTimeInterval *)pdur;
- (BOOL) hasPrefix: (NSString*) pref toInt: (int *)pint;
- (BOOL) hasTextBlockPrefix: (NSString*) pref toArray:  (NSMutableArray*)array;
- (NSString*) textUpTo: (NSString *) endTag;
- (BOOL) isAtEnd;
- (NSString*) line;

@end

// --------------------------------------------------------------------------------------------------------
// --------------------------------------------------------------------------------------------------------
