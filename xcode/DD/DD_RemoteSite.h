/*
 Copyright (C) 2008 John Henry Thompson. All Rights Reserved.
 */


#import <Foundation/Foundation.h>

// --------------------------------------------------------------------------------------------------------

@interface DD_RemoteSite : NSObject
{
	BOOL	dirty;
	BOOL	metaFolderCreated;
}

@property (nonatomic, strong) NSString			*siteID;
@property (nonatomic, strong) NSString			*site_username;
@property (nonatomic, strong) NSString			*site_password;
@property (nonatomic, strong) NSString			*site_realm;
@property (nonatomic, strong) NSString			*siteLabel;
@property (nonatomic, strong) NSString			*realm;

@property (nonatomic, assign) double                meter_flist_bytes;
@property (nonatomic, assign) double                meter_flist_lapse;

// --------------------------------------------------------------------------------------------------------

- (NSMutableDictionary*) asDict;

- (DD_RemoteSite *) initWithDict: (NSDictionary*)dict;

- (DD_RemoteSite *) initWithSiteID: (NSString *) siteID;

- (DD_RemoteSite *) initFromFileWithSiteID: (NSString *) siteID;

- (void) saveToFile;

- (void) syncToFile;

- (void) setDirty;

//- (void) initDefault;

- (DD_RemoteSite *) assignWithDict: (NSDictionary*)dict;

- (NSString *) destRoot;

- (NSString *) shortenLocalPath: (NSString *)path;

- (void) deleteLocalSite;

- (void) flush;

- (void) lowMemoryFlush;

- (void) loadMeta;

- (NSString *) httpBasicAuthorization;

- (NSString *) httpBasicAuthorizationForUser: (NSString *) uname password: (NSString *) passwd;

//- (NSString *) httpStringForAccessUrl;
//
//- (NSString *) httpStringForPath: (NSString *)path;

- (NSString *) ui_siteLabel;

- (void) preparePlayMovieUrl: (NSURL *) url;

@end


#define K_site_meta_folder	@"_site_meta"

// --------------------------------------------------------------------------------------------------------
// --------------------------------------------------------------------------------------------------------
