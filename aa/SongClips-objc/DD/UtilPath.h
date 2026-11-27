/*
 Copyright (C) 2008 John Henry Thompson. All Rights Reserved.
 */

#import <Foundation/Foundation.h>

NSString* localStoreRootCache();

NSString* localStoreRootPrivate();

NSString* localStoreRoot();

BOOL addSkipBackupAttributeToItemAtPath( NSString *path, BOOL value);

void createEnclosingDirectory(NSString *destPath);

// ----------------------------------------------------------------------------------------------------------
// ----------------------------------------------------------------------------------------------------------
