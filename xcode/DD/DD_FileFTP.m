/*
 Copyright (C) 2008 John Henry Thompson. All Rights Reserved.
 */

#import "DD_FileFTP.h"

@implementation DD_FileFTP

//@synthesize path;
//@synthesize fileName;
//@synthesize source;
//@synthesize size;
//@synthesize modDate;
//@synthesize childIndex;

// ----------------------------------------------------------------------------------------------------------

// ----------------------------------------------------------------------------------------------------------
- (unsigned int) isDirectory
{
	return flags.isDirectory;
}

- (void) setIsDirectory: (unsigned int) val
{
	flags.isDirectory = val;
}

// ----------------------------------------------------------------------------------------------------------
- (unsigned int) isCurrent
{
	return flags.isCurrent;
}

- (void) setIsCurrent: (unsigned int) val
{
	flags.isCurrent = val;
}

// ----------------------------------------------------------------------------------------------------------
- (unsigned int) isDeferred
{
	return flags.isDeferred;
}

- (void) setIsDeferred: (unsigned int) val
{
	flags.isDeferred = val;
}


// ----------------------------------------------------------------------------------------------------------
// ----------------------------------------------------------------------------------------------------------

@end
