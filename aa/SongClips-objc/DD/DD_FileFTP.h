/*
 Copyright (C) 2008 John Henry Thompson. All Rights Reserved.
 */

#import <Foundation/Foundation.h>

@interface DD_FileFTP : NSObject
{
//	NSString	*path;
//	NSString	*fileName;
//	NSString	*source;
//	NSDate		*modDate;
//	SInt64		size;
//	NSInteger	childIndex;
    struct
	{
        unsigned int isDirectory:1;
        unsigned int isCurrent:1;
        unsigned int isDeferred:1;
    } flags;
}

@property (nonatomic, strong) NSString	*path;
@property (nonatomic, strong) NSString	*fileName;
@property (nonatomic, strong) NSString	*source;
@property (nonatomic, strong) NSDate	*modDate;
//@property (nonatomic, assign) NSInteger			childIndex;
@property (nonatomic, assign) SInt64			size;
@property (nonatomic, assign) unsigned int		isDirectory;
@property (nonatomic, assign) unsigned int		isCurrent;
@property (nonatomic, assign) unsigned int		isDeferred;

@end
