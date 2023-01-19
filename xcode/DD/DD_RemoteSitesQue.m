/*
 Copyright (C) 2008 John Henry Thompson. All Rights Reserved.
 */

#import "DD_RemoteSitesQue.h"
#import "DD_AppState.h"
#import "DD_AppStateInternal.h"
#import "DD_AppUtil.h"
#import "DD_UserDefault.h"
#import "DD_DefProp.h"

static DD_RemoteSitesQue* default1 = 0;

DD_RemoteSitesQue *g_remoteSitesQue;

@implementation DD_RemoteSitesQue

// ----------------------------------------------------------------------------------------------------------
- (id)init
{
	self = [super init];
	if (self)
	{
		list = [NSMutableArray new];
        dict = [NSMutableDictionary new];
        allowedSites = [NSMutableArray new];
	}

	g_remoteSitesQue = self;
	
	return self;
}

// ----------------------------------------------------------------------------------------------------------

// ----------------------------------------------------------------------------------------------------------
+ (DD_RemoteSitesQue*)default
{
	if (default1) 
		return default1;
	default1 = [DD_RemoteSitesQue new];
	return default1;
}

// ----------------------------------------------------------------------------------------------------------
+ (void) releaseStatic
{
}

// ----------------------------------------------------------------------------------------------------------
// Future: write each remote dict to own file.
//
- (void)saveToDisk
{
	NSMutableArray *arr = [NSMutableArray arrayWithCapacity: [list count]];

	ATRACE(@"RemoteSitesQue: saveToDisk count=%lu ", (unsigned long)[list count]);

	for (DD_RemoteSite *remote in list)
	{
		//[arr addObject: [remote asDict]];
		[arr addObject: remote.siteID];
		
		ATRACE2(@"RemoteSitesQue: saveToDisk index=%d remote=0x%x remote.siteID=%@ remote.accessUsername=%@", index, remote, remote.siteID, remote.accessUsername);
		ATRACE2(@"RemoteSitesQue: saveToDisk index=%d remote=0x%x remote.siteID=%@ rc=%d", index, (int) remote, remote.siteID, [remote retainCount]);

		[remote saveToFile];
		//[remote flush];
	}
	
	DD_UserDefault *userDefaults = [DD_UserDefault default];
	
	[userDefaults setObject: arr forKey:kRemoteSiteIDs];

	[userDefaults setObject: [NSNumber numberWithInt: (int)nextSiteID] forKey: kRemoteSitesNextID];
	
	[userDefaults setObject: allowedSites forKey: kRemoteSitesAllowed];

	[userDefaults synchronize];
	
	dirty = NO;
}

// ----------------------------------------------------------------------------------------------------------
- (void) syncToFile
{
	for (DD_RemoteSite *remote in list)
	{
		[remote syncToFile];
	}
}

// ----------------------------------------------------------------------------------------------------------
- (void) setSomeRemoteDirty
{
	dirty = YES;
}

// ----------------------------------------------------------------------------------------------------------
- (void) flush
{
	DD_RemoteSite *remote;
	
	ATRACE2(@"RemoteSitesQue: flush count=%d dirty=%d", [list count], dirty);
	
	if (dirty)
	{
		[self saveToDisk];
		// saveToDisk also does flush
	}
	else
	{
		for (remote in list)
		{
			//[remote flush];
			[remote syncToFile];
		}
	}
}

// ----------------------------------------------------------------------------------------------------------
- (void) lowMemoryFlush
{
	DD_RemoteSite *remote;
	for (remote in list)
	{
		[remote lowMemoryFlush];
	}
}

// ----------------------------------------------------------------------------------------------------------
- (void) initWithArraySiteIDs:(NSArray*)arr
{
	ATRACE2(@"RemoteSitesQue: initWithArraySiteIDs: count=%d", [arr count]);
	ATRACE2(@"RemoteSitesQue: initWithArray: arr=%@", [arr description]);
	
	DD_RemoteSite	*remote;
	
	for (NSString *siteID2 in arr)
	{
		remote = [[DD_RemoteSite alloc] initFromFileWithSiteID: siteID2];
		if (remote)
		{
			[self addRemote: remote forKey: remote.siteID];
		}
		
		ATRACE2(@"RemoteSitesQue: initWithArraySiteIDs index=%d siteID=%@ remote=0x%x rc=%d",
				index, remote.siteID, (int) remote, [remote retainCount]);
		ATRACE2(@"RemoteSitesQue: initWithArraySiteIDs index=%d remote=0x%x remote.siteID=%@ remote.accessUsername=%@", index, remote, remote.siteID, remote.accessUsername);
	}
}

// ----------------------------------------------------------------------------------------------------------
- (void) resumeFromDisk
{
	DD_UserDefault *userDefaults = [DD_UserDefault default];
	
	// Read in next Site id before possible conversions in initWithDict
	NSNumber *num = [userDefaults objectForKey: kRemoteSitesNextID];
	nextSiteID = [num integerValue];

	[allowedSites removeAllObjects];
	NSArray *arr = [userDefaults objectForKey:kRemoteSitesAllowed];
	if (arr)
	{
		allowedSites = [NSMutableArray arrayWithArray: arr];
	}
	ATRACE2(@"RemoteSitesQue: allowedSites count %d ", [allowedSites count]);
	
	[list removeAllObjects];
	
	[dict removeAllObjects];
	
	arr = [userDefaults objectForKey:kRemoteSiteIDs];
	if (arr)
	{
		ATRACE2(@"RemoteSitesQue: resume count %d ", [arr count]);
		[self initWithArraySiteIDs: arr ];
	}
	
	ATRACE2(@"  nextSiteID=%d dirty=%d", nextSiteID, dirty);
	ATRACE2(@"  dict=%@ ", dict);
	
	if (dirty)
	{
		// Write out any conversions.
		[self saveToDisk];
	}
}

// ----------------------------------------------------------------------------------------------------------
+ (void)resumeFromDisk
{
	[[DD_RemoteSitesQue default] resumeFromDisk];
}

// ----------------------------------------------------------------------------------------------------------
- (DD_RemoteSite*) remoteForKey: (NSString*) siteID
{
	return [dict objectForKey: siteID];
}

// ----------------------------------------------------------------------------------------------------------
- (NSString *) assignSiteID
{
	dirty = TRUE;
	
	NSString *siteID = [NSString stringWithFormat:@"site%04ld", (long)nextSiteID];
	
	nextSiteID++;
	
	return siteID;
}

// ----------------------------------------------------------------------------------------------------------
- (DD_RemoteSite*) remoteCreate
{
	return [self remoteCreateWithMunchMode: NO];
}

// ----------------------------------------------------------------------------------------------------------
- (DD_RemoteSite*) remoteCreateWithMunchMode: (BOOL) amunchMode
{
	ATRACE(@"RemoteSitesQue: remoteCreate nextSiteID=%ld", (long)nextSiteID);
	NSString *siteID = [self assignSiteID];
	
	DD_RemoteSite* newRemote = [[DD_RemoteSite alloc] initWithSiteID: siteID munchMode: amunchMode];

	ATRACE2(@"RemoteSitesQue: remoteCreate RemoteSites=0x%x nextSiteID=%d rc=%d", (int) newRemote, nextSiteID, [newRemote retainCount]);

	[self addRemoteSave: newRemote forKey: siteID];
	
	ATRACE2(@"RemoteSitesQue: remoteCreate addRemoteSave RemoteSites=0x%x nextSiteID=%d rc=%d", (int) newRemote, nextSiteID, [newRemote retainCount]);

	return newRemote;
}

// ----------------------------------------------------------------------------------------------------------
- (DD_RemoteSite*) remoteCreateAndSave
{
	DD_RemoteSite *remoteSite1 = [self remoteCreate];
	
	[self saveToDisk];
	
	return remoteSite1;
}

// ----------------------------------------------------------------------------------------------------------
- (DD_RemoteSite*) remoteCreateDefault
{
	DD_RemoteSite *remoteSite1 = [self remoteCreate];
	
	[remoteSite1 initDefault];
		
	[self saveToDisk];
	
	return remoteSite1;
}

// ----------------------------------------------------------------------------------------------------------
- (void) addRemote: (DD_RemoteSite*) dict1 forKey: (NSString*) siteID
{
	[list addObject: dict1];
	[dict setValue: dict1 forKey: siteID];
}

// ----------------------------------------------------------------------------------------------------------
- (void) addRemoteSave: (DD_RemoteSite*) dict1 forKey: (NSString*) siteID
{
	[self addRemote: dict1 forKey: siteID];
	
	[self saveToDisk];
}

// ----------------------------------------------------------------------------------------------------------
- (void) removeRemoteAtIndex: (NSUInteger) index
{
	DD_RemoteSite	*remoteSite1;
	
	remoteSite1 = [list objectAtIndex: index];
	

	NSString *siteID2 = remoteSite1.siteID;

	[list removeObjectAtIndex: index];
	[dict removeObjectForKey: siteID2];
		
	// Clear current remote if it's getting deleted.
	[g_ep_app didDeleteRemote: siteID2 ];
	
	[remoteSite1 deleteLocalSite];

	ATRACE(@"RemoteSitesQue: release RemoteSite=%p siteID=%@ list count=%lu dict count=%lu", remoteSite1, remoteSite1.siteID, (unsigned long)[list count], (unsigned long)[dict count]);
	
	[self saveToDisk];
}

// ----------------------------------------------------------------------------------------------------------
- (void) removeRemote: (DD_RemoteSite*)dict1
{
	NSUInteger	index = [list indexOfObjectIdenticalTo: dict1];

	ATRACE2(@"RemoteSitesQue: removeObject: dict=%lx index=%d rc=%d\n", dict1, index, [dict1 retainCount]);

	if (index !=  NSNotFound)
	{
		[self removeRemoteAtIndex:index];
	}
}

// ----------------------------------------------------------------------------------------------------------
- (void) remoteAtIndex: (int) fromIndex moveTo: (int) toIndex
{
	DD_RemoteSite	*remoteSite1;
	
	remoteSite1 = [list objectAtIndex: fromIndex];
	
    if (fromIndex < toIndex) toIndex++;
	
    [list insertObject: remoteSite1 atIndex: toIndex];
    
    if (fromIndex > toIndex) fromIndex++;
    
    [list removeObjectAtIndex: fromIndex];
	
	[self saveToDisk];
}

// ----------------------------------------------------------------------------------------------------------
- (void) assignFreshSiteID: (DD_RemoteSite*)remoteSite1
{
	NSUInteger	index = [list indexOfObjectIdenticalTo: remoteSite1];
	
	if (index == NSNotFound)
	{
		ATRACE(@"RemoteSitesQue: assignFreshSiteID: FAILED TO FIND remoteSite1 siteID=%@", remoteSite1.siteID);
	}
	
	NSString *oldSiteID = remoteSite1.siteID;
	
	[list removeObjectAtIndex: index];
	[dict removeObjectForKey: oldSiteID];
	
	remoteSite1.siteID = [self assignSiteID];
	
	[self addRemote: remoteSite1 forKey: remoteSite1.siteID];
	
	ATRACE(@"RemoteSitesQue: assignFreshSiteID: oldSiteID=%@ g_ep_app.siteID=%@", oldSiteID, g_ep_app.siteID);

	if ([oldSiteID isEqualToString: g_ep_app.siteID])
	{
		g_ep_app.siteID = remoteSite1.siteID;
		
		DD_UserDefault *userDefaults = [DD_UserDefault default];
		
		[userDefaults setObject:remoteSite1.siteID forKey:kSiteID];
		
		[userDefaults synchronize];
	}

	ATRACE(@"RemoteSitesQue: assignFreshSiteID: oldSiteID=%@ new siteID=%@", oldSiteID, remoteSite1.siteID);

	[self saveToDisk];
}

// ----------------------------------------------------------------------------------------------------------
- (DD_RemoteSite*) remoteAtIndex: (NSUInteger) index
{
	return [list objectAtIndex: index];
}

// ----------------------------------------------------------------------------------------------------------
- (NSUInteger) indexForSiteID: (NSString*) siteID
{
	NSUInteger	index = 0;
	DD_RemoteSite	*remote;
	
	for (remote in list)
	{
		if ([remote.siteID isEqualToString: siteID])
			return index;
		index++;
	}
	return -1;
}

// ----------------------------------------------------------------------------------------------------------
- (NSUInteger) count
{
	return [list count];
}

// ----------------------------------------------------------------------------------------------------------
- (DD_RemoteSite*) findRemoteForLocalPath: (NSString*) localPath
{
	ATRACE2(@"RemoteSitesQue: findRemoteForLocalPath localPath=%@\n", localPath);

	DD_RemoteSite			*remoteSite;

	localPath = [localPath substringFromIndex: 1];
	ATRACE2(@"RemoteSitesQue: trimmmed localPath=%@\n", localPath);

	for (remoteSite in list)
	{
		if ([localPath hasPrefix: remoteSite.siteID])
		{
			ATRACE2(@"RemoteSitesQue: findRemoteForLocalPath FOUND siteID=%@\n", remoteSite.siteID);
			return remoteSite;
		}
	}
	return nil;
}

// ----------------------------------------------------------------------------------------------------------
// Find remote by prefix match on accessurl
- (DD_RemoteSite*) findRemoteForHostPath: (NSString*) hostPath
{
	ATRACE2(@"RemoteSitesQue: findRemoteForHostPath hostPath=%@\n", hostPath);
	
	DD_RemoteSite			*remoteSite;
	NSString			*accessUrl2;
	
	for (remoteSite in list)
	{
		accessUrl2 = remoteSite.accessUrl;
		ATRACE2(@"RemoteSitesQue: accessUrl2=%@\n", accessUrl2);
		if ([accessUrl2 hasPrefix: hostPath])
		{
			ATRACE2(@"RemoteSitesQue: findRemoteForHostPath FOUND accessUrl=%@\n", accessUrl);
			return remoteSite;
		}
	}
	return nil;
}

// ----------------------------------------------------------------------------------------------------------
// Find remote by exact match on contentUrl
- (DD_RemoteSite*) findRemoteForHttpUrl: (NSString*) httpurl
{
	ATRACE(@"RemoteSitesQue: findRemoteForHttpUrl hostPath=%@\n", httpurl);
	
	DD_RemoteSite			*remoteSite;
	NSString			*httpurl2;
	
	for (remoteSite in list)
	{
		httpurl2 = remoteSite.contentUrl;
		ATRACE(@"RemoteSitesQue: httpurl2=%@\n", httpurl2);
		if ([httpurl2 isEqualToString: httpurl])
		{
			ATRACE(@"RemoteSitesQue: findRemoteForHttpUrl FOUND httpurl2=%@\n", httpurl2);
			return remoteSite;
		}
	}
	return nil;
}

// ----------------------------------------------------------------------------------------------------------
// Find remote by exact match on access url
- (DD_RemoteSite*) findRemoteForAccessUrl: (NSString*) accessUrl2
{
	ATRACE2(@"RemoteSitesQue: findAccessForUrl hostPath=%@\n", hostPath);
	
	DD_RemoteSite			*remoteSite;
	NSString			*accessUrl;
	
	for (remoteSite in list)
	{
		accessUrl = remoteSite.accessUrl;
		ATRACE2(@"RemoteSitesQue: accessUrl=%@\n", accessUrl);
		//if ([accessUrl2 hasPrefix: accessUrl])	// version 1.2
		if ([accessUrl2 isEqualToString: accessUrl])
		{
			ATRACE2(@"RemoteSitesQue: findAccessForUrl FOUND accessUrl=%@\n", accessUrl);
			return remoteSite;
		}
	}
	return nil;
}

// ----------------------------------------------------------------------------------------------------------
// Find remote by exact match user name
- (DD_RemoteSite*) findRemoteForAccessUname: (NSString*) accessUname
{
	ATRACE(@"RemoteSitesQue: findRemoteForAccessUname accessUname=%@\n", accessUname);
	DD_RemoteSite   *remoteSite;
	
	for (remoteSite in list)
	{
		if ([remoteSite.accessUsername isEqualToString: accessUname])
		{
			ATRACE(@"RemoteSitesQue: findRemoteForAccessUname FOUND remoteSite=%@\n", remoteSite);
			return remoteSite;
		}
	}
	return nil;
}

// ----------------------------------------------------------------------------------------------------------
- (void) removeAllExcept: (NSString *) siteID
{
	ATRACE(@"RemoteSitesQue: removeAllExcept siteID=%@ count=%lu", siteID, (unsigned long)[self count]);
	DD_RemoteSite		*remoteSite;
	NSInteger		index;
	NSString		*siteID2;
	
	for (index = [self count] - 1; index >= 0; index--)
	{
		remoteSite = [list objectAtIndex: index];
		siteID2 = remoteSite.siteID;
		if ([remoteSite.siteID isEqualToString: siteID])
		{
			ATRACE2(@" skipping: index=%d", index);
			continue;
		}
		ATRACE(@" removing: index=%ld accessUrl2=%@", (long)index, siteID2);
		
		[self removeRemoteAtIndex: index];
	}
}

// ----------------------------------------------------------------------------------------------------------
// aquipt.mobilesiteclone.net/default --> mobilesiteclone.net
// https://siteName --> siteName
//
- (NSString *) allowedSitesTrimUrl:  (NSString *)url
{
	
	return [DD_AppUtil trimSiteUrl: url ];
#if 0
	if ([url hasPrefix: @"http://"])
	{
		url = [url substringFromIndex:7];
	}
	else if ([url hasPrefix: @"https://"])
	{
		url = [url substringFromIndex:8];
	}
	NSRange	range;
	
	// Remove everything after first "/"
	range = [url rangeOfString:@"/"];
	if (range.location != NSNotFound)
		url = [url substringToIndex: range.location];
	
	// Keep last two components
	NSArray		*arr = [url componentsSeparatedByString:@"."];
	int	count = (int)[arr count];
	if (count >= 2)
		return [NSString stringWithFormat:@"%@.%@", [arr objectAtIndex: count-2], [arr objectAtIndex: count-1]];
	else
		return [arr objectAtIndex: 0];
#endif
}

// ----------------------------------------------------------------------------------------------------------
- (void) allowedSitesAddUrl: (NSString *)url
{
//#if	APP_RESTRICTED_SITES
    if (g_ep_app.restrict_sites)
    {
        ATRACE(@"RemoteSitesQue allowedSitesAddUrl url=%@", url);
        url = [self allowedSitesTrimUrl: url];
        NSUInteger index = [allowedSites indexOfObject: url ];
        if (index == NSNotFound)
        {
            ATRACE(@"	adding trimmed url=%@", url);
            [allowedSites addObject: url ];
            
            [self saveToDisk];
        }
    }
//#endif
}

// ----------------------------------------------------------------------------------------------------------
- (BOOL) allowedSiteUrlAllowed: (NSString *)url
{
//#if APP_RESTRICTED_SITES
    if (g_ep_app.restrict_sites)
    {
        ATRACE(@"RemoteSitesQue allowedSiteUrlAllowed url=%@", url);
        url = [self allowedSitesTrimUrl: url];
        NSUInteger index = [allowedSites indexOfObject: url ];
        if (index == NSNotFound)
        {
            ATRACE(@"	REJECTED trimmed url=%@", url);
            return NO;
        }
        ATRACE(@"	ACCEPTED trimmed url=%@", url);
    }
//#endif
	return YES;
}

// --------------------------------------------------------------------------------------------------------
// ----------------------------------------------------------------------------------------------------------

@end
