/*
 Copyright (C) 2008 John Henry Thompson. All Rights Reserved.
 */


#import "DD_UserDefault.h"
#import "DD_AppDefs.h"
#import "DD_AppState.h"
#import "DD_AppStateInternal.h"
#import "DD_AppUtil.h"
#import "DD_RemoteSitesQue.h"

static DD_UserDefault* default1 = 0;

@implementation DD_UserDefault

@synthesize dict;
@synthesize dirty;

// ----------------------------------------------------------------------------------------------------------

// ----------------------------------------------------------------------------------------------------------
- (id)init
{
	self = [super init];
	if (self)
	{
		// self.dict = [NSMutableDictionary dictionaryWithCapacity: 100];
	}
	return self;
}

// ----------------------------------------------------------------------------------------------------------
+ (DD_UserDefault *) default
{
	if (default1) 
		return default1;
	
	default1 = [DD_UserDefault new];
	
	[default1 restoreFromDisk];
	
	return default1;
}

// ----------------------------------------------------------------------------------------------------------
- (NSString *) savePath: (NSString *) path
{
	return [path stringByAppendingPathComponent: @"_udef"];
}

// ----------------------------------------------------------------------------------------------------------
- (NSString *) savePath
{	
	return [self savePath: [DD_AppState localStoreRoot]];
}

// ----------------------------------------------------------------------------------------------------------
//	Library/Caches --> Library/Private Documents
//		_udef
//		_sitemeta
//			site0000
//				_deferred.plist
//				_files2.txt
//				_remote.plist
//				_unzip.plist
//				_viewlog2.txt
//				_viewlog2.plist
//		site0000
//
- (void) checkForPrivateFileConversion
{
	NSString *oldPath = [self savePath: [DD_AppState localStoreRootCache]];
	NSString *newPath = [self savePath];

	NSFileManager	*fm = [NSFileManager defaultManager];
	NSError			*err = nil;
	
	// Move _udef
	//
	if (! [fm fileExistsAtPath: oldPath])
	{
		// No conversion.
		return;
	}
	ATRACE(@"MyUserDefault: checkForPrivateFileConversion");
	ATRACE(@"	oldPath=%@ newPath=%@", oldPath, newPath);
	
	// Create Library/Private Documents
	//
	[fm createDirectoryAtPath: [newPath stringByDeletingLastPathComponent] withIntermediateDirectories: YES attributes:nil error:nil];
	
	[fm moveItemAtPath:oldPath toPath:newPath error:&err];
	ATRACE(@"	err=%@", err);
	
	if (err) 
	{
		AFLOG(@"MyUserDefault: checkForPrivateFileConversion oldPath=%@ newPath=%@ ERROR=%@", oldPath, newPath, [err localizedDescription]);
	}

	// Move _sitemeta
	//
	oldPath = [[oldPath stringByDeletingLastPathComponent] stringByAppendingPathComponent: @"_sitemeta"];
	newPath = [[newPath stringByDeletingLastPathComponent] stringByAppendingPathComponent: @"_sitemeta"];

	[fm moveItemAtPath:oldPath toPath:newPath error:&err];
	if (err) 
	{
		AFLOG(@"MyUserDefault: checkForPrivateFileConversion oldPath=%@ newPath=%@ ERROR=%@", oldPath, newPath, [err localizedDescription]);
		return;
	}
	
	// Read in _udef
	self.dict = [NSMutableDictionary dictionaryWithContentsOfFile: [self savePath]];
	
	// Move individual site contents directory: site0000, site00001, ...
	//
	NSArray *sitesNamesArr = [self objectForKey: kRemoteSiteIDs];
	ATRACE(@"	sitesNamesArr=%@", sitesNamesArr);
	
	NSString *siteName;
	
	for (siteName in sitesNamesArr)
	{
		oldPath = [[oldPath stringByDeletingLastPathComponent] stringByAppendingPathComponent: siteName];
		newPath = [[newPath stringByDeletingLastPathComponent] stringByAppendingPathComponent: siteName];
		
		[fm moveItemAtPath:oldPath toPath:newPath error:&err];
		if (err) 
		{
			AFLOG(@"MyUserDefault: checkForPrivateFileConversion oldPath=%@ newPath=%@ ERROR=%@", oldPath, newPath, [err localizedDescription]);
		}
	}
	
    if (g_ep_app.synthes_ui)
    {
        // Set skip backup for all m4v
        //
        newPath = [newPath stringByDeletingLastPathComponent];
        NSDirectoryEnumerator *direnum = [fm enumeratorAtPath:newPath];
        NSString *fileName;
        NSString *filePath;
        
        while (fileName = [direnum nextObject])
        {
            if ([[fileName lowercaseString] hasSuffix: @".m4v"])
            {
                filePath = [newPath stringByAppendingPathComponent: fileName];
                
                [DD_AppUtil addSkipBackupAttributeToItemAtPath: filePath value: YES];
            }
        }
    }
	
}

// ----------------------------------------------------------------------------------------------------------
- (void) synchronize
{
	if (dirty)
	{
		ATRACE2(@"MyUserDefault: synchronize dirty");
		
		[dict writeToFile: [self savePath] atomically: NO];
		
		dirty = NO;
	}
}

// ----------------------------------------------------------------------------------------------------------
- (void) restoreFromDisk
{
	self.dict = [NSMutableDictionary dictionaryWithContentsOfFile: [self savePath]];
	if (! dict)
	{
		ATRACE(@"MyUserDefault: restoreFromDisk conversion");
		
		self.dict = [NSMutableDictionary dictionaryWithCapacity: 100];
		// Post 2.504 Conversion to Private Documents area
		[self checkForPrivateFileConversion];
	}
	
	ATRACE2(@"MyUserDefault: restoreFromDisk dict=%@", dict);
}

// ----------------------------------------------------------------------------------------------------------
- (void) setObject: (id) obj forKey: (NSString *) key
{
	if (! obj)
	{
		ATRACE(@"MyUserDefault: setObject obj NULL forKey: %@", key);
		return;
	}
	[dict setObject: obj forKey: key];
	dirty = YES;
}

// ----------------------------------------------------------------------------------------------------------
- (void) setBool: (BOOL) it forKey: (NSString *) key
{
	[dict setObject: [NSNumber numberWithBool: it] forKey: key];
}

// ----------------------------------------------------------------------------------------------------------
- (void) setFloat: (float) it forKey: (NSString *) key
{
	[dict setObject: [NSNumber numberWithFloat: it] forKey: key];
}

// ----------------------------------------------------------------------------------------------------------
- (void) setInteger: (NSInteger) it forKey: (NSString *) key
{
	[dict setObject: [NSNumber numberWithInteger: it] forKey: key];
}

// ----------------------------------------------------------------------------------------------------------
- (id) objectForKey: (NSString *) key
{
	ATRACE2(@"MyUserDefault: objectForKey: %@", key);

	return [dict objectForKey: key];
}

// ----------------------------------------------------------------------------------------------------------
- (BOOL) boolForKey: (NSString *) key
{
	return [[dict objectForKey: key] boolValue];
}

// ----------------------------------------------------------------------------------------------------------
- (float) floatForKey: (NSString *) key
{
	return [[dict objectForKey: key] floatValue];
}

// ----------------------------------------------------------------------------------------------------------
- (NSInteger) integerForKey: (NSString *) key
{
	return [[dict objectForKey: key] integerValue];
}

// ----------------------------------------------------------------------------------------------------------
- (void) removeObjectForKey: (NSString *) key
{
	ATRACE2(@"MyUserDefault: removeObjectForKey: %@", key);

	[dict removeObjectForKey: key];
}

// ----------------------------------------------------------------------------------------------------------
// ----------------------------------------------------------------------------------------------------------
@end
