/*
 Copyright (C) 2008 John Henry Thompson. All Rights Reserved.
 */

#import <Foundation/Foundation.h>
#import "DD_RemoteSite.h"

@interface DD_RemoteSitesQue : NSObject
{	
	NSMutableArray		*list;	
	NSMutableDictionary *dict;
	
	NSMutableArray		*allowedSites;
	
	NSInteger			nextSiteID;
	
	BOOL				dirty;
}

+ (DD_RemoteSitesQue*)default;

+ (void) releaseStatic;

+ (void) resumeFromDisk;

- (void) saveToDisk;

- (void) syncToFile;

- (void) setSomeRemoteDirty;

- (DD_RemoteSite*) remoteForKey: (NSString*) siteID;

- (DD_RemoteSite*) remoteCreate;

- (DD_RemoteSite*) remoteCreateWithMunchMode: (BOOL) amunchMode;

- (DD_RemoteSite*) remoteCreateAndSave;

- (DD_RemoteSite*) remoteCreateDefault;

- (void) addRemote: (DD_RemoteSite*) dict forKey: (NSString*) siteID;

- (void) addRemoteSave: (DD_RemoteSite*) dict forKey: (NSString*) siteID;

- (void) removeRemoteAtIndex: (NSUInteger) index;

- (void) removeRemote: (DD_RemoteSite*)remote;

- (DD_RemoteSite*) remoteAtIndex: (NSUInteger) index;

- (void) remoteAtIndex: (int) fromIndex moveTo: (int) toIndex;

- (void) assignFreshSiteID:( DD_RemoteSite*)remoteSite1;

- (NSUInteger) indexForSiteID: (NSString*) siteID;

- (NSUInteger) count;

- (DD_RemoteSite*) findRemoteForLocalPath: (NSString*) localPath;

- (DD_RemoteSite*) findRemoteForHostPath: (NSString*) urlString;

- (DD_RemoteSite*) findRemoteForHttpUrl: (NSString*) urlString;

- (DD_RemoteSite*) findRemoteForAccessUrl: (NSString*) accessUrl2;

- (DD_RemoteSite*) findRemoteForAccessUname: (NSString*) accessUname;

- (void) removeAllExcept: (NSString *) siteID;

- (NSString *) assignSiteID;

- (void) flush;

- (void) lowMemoryFlush;

- (void) allowedSitesAddUrl: (NSString *)url;

- (BOOL) allowedSiteUrlAllowed: (NSString *)url;

@end


extern DD_RemoteSitesQue *g_remoteSitesQue;

// --------------------------------------------------------------------------------------------------------
// Array of siteIDs
#define kRemoteSiteIDs			@"kRemoteSiteIDs"

#define kRemoteSitesNextID		@"kRemoteSitesNextID"

#define kRemoteSitesAllowed		@"kRemoteSitesAllowed"


// --------------------------------------------------------------------------------------------------------
// --------------------------------------------------------------------------------------------------------
