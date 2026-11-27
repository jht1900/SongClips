/*
 Copyright (C) 2008 John Henry Thompson. All Rights Reserved.
 */

#import "UtilPath.h"
#import "DD_AppDefs.h"

// ----------------------------------------------------------------------------------------------------------
NSString* localStoreRootCache()
{
	// User cache folder
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
	NSString *dirPath = paths[0];
	dirPath = [dirPath stringByAppendingString: @"/"];
	ATRACE2(@"EP_AppState: localStoreRootCache=%@", dirPath);
	return dirPath;
}

// ----------------------------------------------------------------------------------------------------------
NSString* localStoreRootPrivate()
{
	NSString *dirPath = localStoreRootCache();
	dirPath = [[[dirPath stringByAppendingString: @"../Private Documents"] stringByStandardizingPath] stringByAppendingString: @"/"];
	ATRACE2(@"EP_AppState: localStoreRootPrivate=%@", dirPath);
	return dirPath;
}

// ----------------------------------------------------------------------------------------------------------
NSString* localStoreRoot()
{
	return localStoreRootPrivate();
}

// ----------------------------------------------------------------------------------------------------------
BOOL addSkipBackupAttributeToItemAtPath( NSString *path, BOOL value)
{
	NSURL *url = [NSURL fileURLWithPath: path];
	BOOL success = [url setResourceValue: @(YES) forKey: NSURLIsExcludedFromBackupKey error: nil];
	return success;
}

// --------------------------------------------------------------------------------------------------------
void createEnclosingDirectory(NSString *destPath)
{
	NSError *err;
	destPath = [destPath stringByDeletingLastPathComponent];
	
	BOOL ok = [[NSFileManager defaultManager] createDirectoryAtPath: destPath withIntermediateDirectories: YES attributes: nil error: &err];
	if (! ok) {
		ATRACE(@"DD_HTTPManager createEnclosingDirectory destPath=%@ err=%@", destPath, err);
	}
}

// ----------------------------------------------------------------------------------------------------------
// ----------------------------------------------------------------------------------------------------------
