/*
 Copyright (C) 2008 John Henry Thompson. All Rights Reserved.
 */


#import "DD_RemoteSite.h"
#import "DD_AppDefs.h"
#import "UtilPath.h"

// ----------------------------------------------------------------------------------------------------------
@implementation DD_RemoteSite

#define K_siteID				@"K_siteID"
#define K_site_username			@"K_site_username"
#define K_site_password			@"K_site_password"
#define K_siteLabel				@"K_siteLabel"
#define K_meter_flist_bytes		@"K_meter_flist_bytes"
#define K_meter_flist_lapse		@"K_meter_flist_lapse"

// ----------------------------------------------------------------------------------------------------------
- (void)dealloc
{
	ATRACE(@"%p RemoteSite: dealloc siteID=%@", self, _siteID);
}

// ----------------------------------------------------------------------------------------------------------
- (NSMutableDictionary*) asDict
{
	NSMutableDictionary *dict =
		[NSMutableDictionary dictionaryWithDictionary:
			@{K_meter_flist_bytes: @(_meter_flist_bytes),
			K_meter_flist_lapse: @(_meter_flist_lapse)} ];
	
	[dict setValue: _siteID forKey:				K_siteID];
	[dict setValue: _site_username forKey:		K_site_username];
	[dict setValue: _site_password forKey:		K_site_password];
	[dict setValue: _siteLabel		forKey:		K_siteLabel];

    return dict;
}

// ----------------------------------------------------------------------------------------------------------
- (DD_RemoteSite *) initWithDict: (NSDictionary*)dict
{
	id ob;
	ATRACE2(@"%p RemoteSite: initWithDict siteID=%@ kAccessUrlKey=%@", self, [dict objectForKey: kSiteID], [dict objectForKey: kAccessUrlKey]);

	if ((ob = [dict objectForKey: K_siteID])) _siteID = ob;
	if ((ob = [dict objectForKey: K_site_username])) _site_username = ob;
	if ((ob = [dict objectForKey: K_site_password])) _site_password = ob;
	if ((ob = [dict objectForKey: K_siteLabel])) _siteLabel = ob ;

	if (! _siteID) {
		AFLOG(@"0x%x RemoteSite: initWithDict no siteID", (int)self);
		// _siteID = [[DD_RemoteSitesQue default] assignSiteID];
		// No conversion post version 2.5
	}

	ATRACE(@"%p RemoteSite: initWithDictsiteID=%@ ", self, _siteID);

	return self;
}

// ----------------------------------------------------------------------------------------------------------
- (DD_RemoteSite *) initWithSiteID: (NSString *) siteID1
{
	_siteID = siteID1;

	return self;
}

// ----------------------------------------------------------------------------------------------------------
- (NSString*) localStoreRoot
{
	return localStoreRoot();
}

// ----------------------------------------------------------------------------------------------------------
- (NSString *) destRoot
{
	return [[self localStoreRoot] stringByAppendingString: _siteID];
}

// ----------------------------------------------------------------------------------------------------------
- (NSString *) siteMetaPath
{
	return [NSString stringWithFormat:@"%@%@/%@/", localStoreRoot(), K_site_meta_folder, _siteID];
}

// ----------------------------------------------------------------------------------------------------------
- (void) siteMetaPathCreate
{
    ATRACE2(@"RemoteSite: siteMetaPathCreate metaFolderCreated=%d", metaFolderCreated);

	if (metaFolderCreated)
		return;
	metaFolderCreated = YES;
	NSString		*dir = [self siteMetaPath];
	NSError			*err;
    NSFileManager   *fileMan = [NSFileManager defaultManager];
	if (! [fileMan fileExistsAtPath:dir]) {
		ATRACE(@"RemoteSite: siteMetaPathCreate createDirectoryAtPath dir=%@", dir);
		BOOL ok = [fileMan createDirectoryAtPath: dir withIntermediateDirectories: YES attributes: nil error: &err];
		if (! ok) {
			AFLOG(@"Create directory failed %@ %@", dir, [err localizedDescription]);
		}
	}
	else {
		ATRACE(@"RemoteSite: siteMetaPathCreate fileExistsAtPath dir=%@", dir);
	}
}

// ----------------------------------------------------------------------------------------------------------
- (NSString *) remoteSitePath
{
	return [[self siteMetaPath] stringByAppendingPathComponent: @"_remote.plist" ];
}

// ----------------------------------------------------------------------------------------------------------
- (DD_RemoteSite *) initFromFileWithSiteID: (NSString *) siteIDx
{
	ATRACE2(@"RemoteSite: initFromFileWithSiteID siteIDx=%@", siteIDx);
	
	self.siteID = siteIDx;
	
	NSPropertyListFormat	format;
	NSError					*error = nil;
	NSDictionary			*asDict = nil;
	
	NSData					*rawData = [NSData dataWithContentsOfFile: [self remoteSitePath]];
	if (! rawData)
		goto err;
	asDict =
		[NSPropertyListSerialization propertyListWithData: rawData
												  options: NSPropertyListImmutable
												   format: &format
													error: &error];
	if (! asDict) {
	err:;
		AFLOG(@"RemoteSite: Failed to read siteID=%@ error=%@", siteIDx, error);
	}
	if (! asDict) {
		return nil;
	}
	metaFolderCreated = YES;

	return [self initWithDict: asDict];
}

// ----------------------------------------------------------------------------------------------------------
- (void) saveToFile
{
	ATRACE(@"%p RemoteSite: saveToFile siteID=%@ dirty=%d", self, _siteID, dirty);
	
	[self siteMetaPathCreate];

	NSDictionary *asDict = [self asDict];

	// dataWithPropertyList BUG
	// asDict is NSMutableDictionary which appears to cause bug in dataWithPropertyList
    asDict = [NSDictionary dictionaryWithDictionary: asDict];

	NSError *err = nil;
	NSData *rawData = 
		[NSPropertyListSerialization dataWithPropertyList: asDict
												   format: NSPropertyListBinaryFormat_v1_0
												  options: 0
													error: &err];
	if (! rawData) 
	{
		AFLOG(@"RemoteSite: Failed to write siteID=%@ error=%@", _siteID, err);
		return;
	}
	
	[rawData writeToFile: [self remoteSitePath] atomically: NO];
	
	[self flush];
}

// ----------------------------------------------------------------------------------------------------------
- (void) syncToFile
{
	if (dirty) [self saveToFile];
	else [self flush];
	
	dirty = NO;
}

// ----------------------------------------------------------------------------------------------------------
- (void) setDirty
{
	dirty = YES;
}

// ----------------------------------------------------------------------------------------------------------
// Assign keys from dict to self.
// Delete old locals file if localInBackup changed.
//
- (DD_RemoteSite *) assignWithDict: (NSDictionary*)dict
{
	ATRACE2(@"RemoteSite: assignWithDict dict=%@", dict);

	return [self initWithDict: dict];
}

// ----------------------------------------------------------------------------------------------------------
- (void) deleteLocalSite
{
//	NSString	*filePath = [self destRoot];
//
//	[g_ep_app performSelector:@selector(deleteFilePath:) withObject:filePath afterDelay:0.0];
//    
//	[g_ep_app performSelector:@selector(deleteFilePathSilent:) withObject:[self siteMetaPath] afterDelay:0.0];
}


//
// Operations on site meta data
//
// ----------------------------------------------------------------------------------------------------------
- (void) loadMeta
{
	ATRACE2(@"RemoteSite loadMeta viewlogLinkDict count=%d", [viewlogLinkDict count]);
		
//	if (! uitemsDict)
//	{
//		self.uitemsDict = [self readEncodedFromFile: [self uitemsPath]];
//		if (! uitemsDict)
//		{
//			// Try for old format.
//			self.uitemsDict = [NSMutableDictionary dictionaryWithContentsOfFile: [self uitemsPath]];
//			if (uitemsDict)
//			{
//				[[NSFileManager defaultManager] removeItemAtPath: [self uitemsPath] error:nil];
//				uitemsDirty = YES;
//			}
//		}
//	}
}

// ----------------------------------------------------------------------------------------------------------
// Read encoded dictionary/array from file. Path has its extension replaced with ec.
//
- (id) readEncodedFromFile: (NSString *) path
{
	NSData					*rawData = [NSData dataWithContentsOfFile: path];
	if (! rawData) {
		ATRACE2(@"RemoteSite: readEncodedFromFile siteID=%@ path=%@ rawData=%@", siteID, path, rawData);
		return nil;
	}
	// NSPropertyListImmutabl // NSPropertyListMutableContainer // NSPropertyListMutableContainersAndLeaves
	NSPropertyListFormat	format;
	NSError *error = nil;
	return [NSPropertyListSerialization propertyListWithData: rawData
													 options: NSPropertyListMutableContainers
													  format: &format
													   error: &error];
}

// ----------------------------------------------------------------------------------------------------------
- (void) writeEncodedDict: (id) dict toFile: (NSString *) path
{
	// dataWithPropertyList BUG
	// Get immutable copy for the 8-ball OS
    dict = [NSDictionary dictionaryWithDictionary: dict];
	[self writeEncodedObj: dict toFile:path];
}

// ----------------------------------------------------------------------------------------------------------
- (void) writeEncodedArray: (id) arr toFile: (NSString *) path
{
	// dataWithPropertyList BUG
    arr = [NSArray arrayWithArray: arr];
	[self writeEncodedObj: arr toFile:path];
}

// ----------------------------------------------------------------------------------------------------------
// Write the encoded format for object to the file path.
//
- (void) writeEncodedObj: (id) object toFile: (NSString *) path
{
	NSError *err = nil;
	// 	[NSPropertyListSerialization dataFromPropertyList: object format: NSPropertyListBinaryFormat_v1_0 errorDescription: &error];
	// + (NSData *)dataWithPropertyList:(id)plist format:(NSPropertyListFormat)format options:(NSPropertyListWriteOptions)opt error:(NSError **)error
	NSData *rawData =
	[NSPropertyListSerialization dataWithPropertyList: object
											   format: NSPropertyListBinaryFormat_v1_0
											  options: 0
												error: &err];
	if (! rawData) {
		AFLOG(@"RemoteSite: Failed to writeEncoded siteID=%@ path=%@ error=%@", _siteID, path, err);
		return;
	}
	[rawData writeToFile: path atomically: NO];
}

// ----------------------------------------------------------------------------------------------------------
- (void) flush
{
	ATRACE2(@"RemoteSite flush viewlogDirty=%d viewlogLinkDict count=%d", viewlogDirty, [viewlogLinkDict count]);
	ATRACE2(@"RemoteSite flush filesParamLinesDirty=%d storeFileList=%d", filesParamLinesDirty, storeFileList);
//	if (uitemsDirty) {
//		ATRACE(@"RemoteSite flush uitemsDirty");
//		//[uitemsDict writeToFile: [self uitemsPath] atomically: YES];
//		[self writeEncodedDict: uitemsDict toFile:[self uitemsPath]];
//		uitemsDirty = NO;
//	}
}

// ----------------------------------------------------------------------------------------------------------
- (void) lowMemoryFlush
{
	ATRACE2(@"0x%x RemoteSite: lowMemoryFlush localWebView=%@", self, localWebView);

}

// ----------------------------------------------------------------------------------------------------------
// Return path shorted to our root directory. Return "" if outside of our root.
- (NSString *) shortenLocalPath: (NSString *)path notValue: (NSString *) path2
{
	NSString *destr = [self destRoot];
    ATRACE2(@"RemoteSite shortenLocalPath %d path=%@", (int)[path length], path);
    ATRACE2(@"RemoteSite shortenLocalPath %d destr=%@", (int)[destr length], destr);
	if ([path hasPrefix: destr])
		return [path substringFromIndex: [destr length]];
    return path2;
}

// ----------------------------------------------------------------------------------------------------------
- (NSString *) shortenLocalPathMaybe: (NSString *)path 
{
	return [self shortenLocalPath: path notValue: path];
}

// ----------------------------------------------------------------------------------------------------------
- (NSString *) shortenLocalPath: (NSString *)path
{
	return [self shortenLocalPath: path notValue: @""];
}

// ----------------------------------------------------------------------------------------------------------
- (NSString *) httpBasicAuthorizationForUser: (NSString *) uname password: (NSString *) passwd
{
	NSString *cred = [NSString stringWithFormat:@"%@:%@", uname, passwd];
	NSData *dat = [cred dataUsingEncoding:NSASCIIStringEncoding ];
	return [NSString stringWithFormat:@"Basic %@", [dat base64Encoding]];
}

// ----------------------------------------------------------------------------------------------------------
- (NSString *) httpBasicAuthorization
{
	ATRACE2(@"RemoteSite httpBasicAuthorization unames0=%@ passwds0=%@", unames[0], passwds[0]);
	NSString *cred = nil;
	NSString *uname = _site_username ;
	NSString *passwd = _site_password ;
	if ([uname length] > 0) {
		if (! passwd)
			passwd = @"";
		ATRACE(@"RemoteSite httpBasicAuthorization uname=%@ passwd=%@", uname, passwd);
		cred = [self httpBasicAuthorizationForUser: uname password:passwd];
	}
	return cred;
}

// ----------------------------------------------------------------------------------------------------------
- (void) preparePlayMovieUrl: (NSURL *) url
{
	ATRACE(@"RemoteSite preparePlayMovieUrl url=%@", url);
	
	NSString *scheme = [url scheme];
	if ([scheme isEqualToString: @"file"]) {
		return;
	}
	NSString *host = [url host];
	int		port = [[url port] intValue];
	
	NSURLCredential *credential = 
		[[NSURLCredential alloc] initWithUser: _site_username
									 password: _site_password
								  persistence: NSURLCredentialPersistenceForSession];
	
	NSURLProtectionSpace *protectionSpace = 
		[[NSURLProtectionSpace alloc] initWithHost: host
										  port: port
									  protocol: scheme
										 realm: _site_realm // @"Protected Resource" // nil
							  authenticationMethod: NSURLAuthenticationMethodHTTPDigest];
	[[NSURLCredentialStorage sharedCredentialStorage] setDefaultCredential: credential
														forProtectionSpace: protectionSpace];
	ATRACE(@"RemoteSite preparePlayMovieUrl credential=%@ protectionSpace=%@", credential, protectionSpace);
}

// ----------------------------------------------------------------------------------------------------------
//- (DD_FTPManager *) createTransferManager
//{
//	DD_FTPManager *ftp = nil;
//	
//	ATRACE2(@"RemoteSite createTransferManager ProtocolTypeHTTP%@ siteID=%@", protocolType==ProtocolTypeHTTP? @"": @"S", siteID);
//	ftp = [DD_HTTPManager alloc];
//
//	return [ftp initWithRemote: self]; 
//}

// ----------------------------------------------------------------------------------------------------------
- (NSString *) ui_siteLabel
{
	if ([_siteLabel length] > 0)
		return _siteLabel;
	return @"noname";
}

// ----------------------------------------------------------------------------------------------------------
// ----------------------------------------------------------------------------------------------------------

@end


