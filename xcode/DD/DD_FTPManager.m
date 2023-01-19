/*
 Copyright (C) 2008 John Henry Thompson. All Rights Reserved.
 */

#import "DD_FTPManager.h"
#import "DD_FileDir.h"
#import "DD_FTPOp.h"
#import "DD_AppState.h"
#import "DD_AppStateInternal.h"
#import "DD_AppUtil.h"

@implementation DD_FTPManager

@synthesize delegate;
@synthesize ftpop;
@synthesize remoteSite;
@synthesize path;
@synthesize destRoot;
@synthesize lastErr;
@synthesize lastErrMsg;
@synthesize downloadFileName;
@synthesize downloadFileModDate;
@synthesize remote;
@synthesize checkForRestartableErrors;
@synthesize attemptPersistent;
@synthesize abortImmediately;
@synthesize silentError;
@synthesize downloadTrueName;
@synthesize encodeFile;
@synthesize skipMissing;
@synthesize getFileAttributeMode;
@synthesize fileModDate;
@synthesize fileSize;

@synthesize useFilesVars;
@synthesize filesDict;
@synthesize filesParamLines;
@synthesize filesScanLocation;

@synthesize state;

// --------------------------------------------------------------------------------------------------------
- (void)dealloc
{
	ATRACE2(@"%p FTPManager: dealloc remoteSite.siteID=%@ accessUrl=%@", self, remoteSite.siteID, remoteSite.accessUrl );
    
    [self clearAcivity];
	
    ftpop.delegate = nil;
    
    //[super dealloc];
}

// --------------------------------------------------------------------------------------------------------
- (void) copyTo: (DD_FTPManager*) ftp2
{
	ftp2.remoteSite = self.remoteSite;
	ftp2.remote = self.remote;
	ftp2.destRoot = self.destRoot;
	ftp2.path = self.path;
	ftp2.downloadTrueName = self.downloadTrueName;
	ftp2.skipMissing = self.skipMissing;
    ftp2.useFilesVars = self.useFilesVars;
    ftp2.filesDict = self.filesDict;
    ftp2.filesParamLines = self.filesParamLines;
    ftp2.filesScanLocation = self.filesScanLocation;
    //ftp2.getFileAttributeMode = self.getFileAttributeMode;
}

// --------------------------------------------------------------------------------------------------------
- (DD_FTPManager*) copy
{
	DD_FTPManager *ftp2 = [DD_FTPManager new];
	
	[self copyTo: ftp2];
	
	return ftp2;
}

// --------------------------------------------------------------------------------------------------------
- (DD_FTPManager*) initWithRemote: (DD_RemoteSite*) remote1
{
	ATRACE2(@"%p FTPManger: initWithRemote:dict: accessUrl=%@ http=%@ urlRoot=%@", self, remote1.accessUrl,  remote1.contentUrl, remote1.ftpurl);
	ATRACE2(@"%p FTPManger: initWithRemote:dict: accessUrl=%@ ", self, remote1.accessUrl);
    
	// ?? self = [self init];
	if (self)
	{
		self.remoteSite = remote1; 
		self.destRoot = remote1.destRoot;
		self.remote = YES;
		self.path = @"/";
	}
	return self;
}

// --------------------------------------------------------------------------------------------------------
- (void)listLocalDirectory
{
	NSString *rootPath = [destRoot stringByAppendingPathComponent: path];
	NSFileManager *fileManager = [NSFileManager defaultManager];
	NSDirectoryEnumerator *direnum = [fileManager enumeratorAtPath:rootPath];
	NSDictionary *fileDict;
	BOOL	isDirectory;
	NSDate	*modDate;
	SInt64	size;
	NSString *fileName;
	NSString *filePath;
	
	while (fileName = [direnum nextObject])
	{
		filePath = [rootPath stringByAppendingPathComponent: fileName];
		fileDict = [fileManager attributesOfItemAtPath: filePath error: nil];
		if (fileDict == nil)
			continue;
		isDirectory = [[fileDict fileType] isEqualToString: NSFileTypeDirectory];
		size = (SInt64)[fileDict fileSize];
		modDate = [fileDict fileModificationDate];
		//fileName = [filePath lastPathComponent];
		
		[delegate listDirectoryFileEntry:fileName isDirectory:isDirectory size:size date:modDate path: path source:nil];
		
		if (isDirectory)
		{
			[direnum skipDescendents];
		}
	}
}

// --------------------------------------------------------------------------------------------------------
// Should we use FTP protocol to list and get data?
- (BOOL) fileTP
{
	return YES;
}

// --------------------------------------------------------------------------------------------------------
- (void) freshFtpop
{
    ftpop.delegate = nil;
    
    ftpop = [DD_FTPOp new];
    
    ftpop.delegate = self;
    ftpop.username = remoteSite.username;
    ftpop.password = remoteSite.password;
    ftpop.attemptPersistent = attemptPersistent;
}

// --------------------------------------------------------------------------------------------------------
// return YES for sucess
- (int)listDirectory
{
	ATRACE(@"FTPManager: listDirectory remote=%d path=%@", remote, path);
	
	state = kFTPState_listDirectory;
	// Clear date to indicate no mod date setting needed after operation completes.
	self.downloadFileModDate = nil;
	// Save name for error display
	self.downloadFileName = [path lastPathComponent];

	if (remote)
	{
		// Silently ignore standin remote site 
		if ([remoteSite.accessUrl length] <= 0)
		{
			ATRACE(@"FTPManager: accessUrl EMPTY");
			[self abort];
			return 0;
		}
		// Check for failed Access log on
		if ([remoteSite.ftpurl length] <= 0)
		{
			[DD_AppUtil showErr: NSLocalizedString(@"Invalid Settings", @"showErr ftp")];
			//state = kFTPState_failed;
			[self abort];
			return 0;
		}
		// Path must end in "/"
		NSString* url = [[DD_AppUtil addFtpSchemeIfAbsent: remoteSite.ftpurl] stringByAppendingString: path];

		url = [url stringByAddingPercentEscapesUsingEncoding: NSUTF8StringEncoding];
		
        [self freshFtpop];
        
        ftpop.host = url;

        BOOL ok = [ftpop directoryListing];
        
		//ftpop = nil;
		//Boolean ok =
		//FTPOpDirectoryListing(self, (__bridge CFStringRef)url, (__bridge CFStringRef)remoteSite.username, (__bridge CFStringRef)remoteSite.password , attemptPersistent);
		
		//AFLOG(@"FTPManger listDirectory url=%@ ref=%lx ok=%d", url, ref, ok);

		return ok;
	}
	else
	{
		[self i_start];
		[self listLocalDirectory];
		[self i_done: YES];
		return YES;
	}
}

// --------------------------------------------------------------------------------------------------------
- (int)listDirectoryDepthFirst
{
	ATRACE(@"FTPManager: listDirectoryDepthFirst remote=%d path=%@", remote, path);
	return [self listDirectory];
}

// --------------------------------------------------------------------------------------------------------
- (int)listDirectoryNested
{
	ATRACE2(@"FTPManager: listDirectoryNested remote=%d path=%@", remote, path);
	return [self listDirectory];
}

// --------------------------------------------------------------------------------------------------------
- (void)i_listDirectoryFileEntry: (NSString*)cfName isDirectory: (BOOL)isDirectory size: (SInt64)size date: (NSDate*)cfDate 
{
	ATRACE2(@"FTPManager: i_listDirectoryFileEntry cfName=%@ path=%@", cfName, path);

	[delegate listDirectoryFileEntry:cfName isDirectory:isDirectory size:size date:cfDate path: path source:nil];
}

// --------------------------------------------------------------------------------------------------------
// Prepare to write file to temp file, save fileName for later resume check
- (NSString *) destPathToStoreFileName: (NSString *)fileName modDate:(NSDate*)modDate
{
	state = kFTPState_download;
	self.downloadFileModDate = modDate;
	self.downloadFileName = fileName;
	
	NSString *destPath = [destRoot stringByAppendingPathComponent: path];

	if (downloadTrueName)
	{
		destPath = [destPath stringByAppendingPathComponent: fileName];
	}
	else
	{
		NSString *destForName = [destPath stringByAppendingPathComponent: kFTPTemp_Name];
		
		[fileName writeToFile: destForName atomically: NO encoding: NSUTF8StringEncoding error:nil];	

		destPath = [destPath stringByAppendingPathComponent: kFTPTemp_Contents];
	}
	
	return destPath;
}

// --------------------------------------------------------------------------------------------------------
// return YES for sucess
- (BOOL) downLoadFile: (DD_FileFTP*)sf fileOffset:(SInt64)fileOffset pathHome: (NSString *) pathHome
{
	ATRACE_DOWNLOAD(@"FTPManager: downLoadFile: fileName=%@ [remoteSite.ftpurl length]=%lu", sf.fileName, (unsigned long)[remoteSite.ftpurl length]);
	
	if ([remoteSite.ftpurl length] <= 0)
		return NO;
	
	NSString *destPath = [self destPathToStoreFileName: sf.fileName modDate:(NSDate*)sf.modDate];
	
	NSURL* destinationFile = [NSURL fileURLWithPath: destPath isDirectory: NO] ;
	
	NSString* url = [[pathHome stringByAppendingPathComponent: path] stringByAppendingPathComponent: sf.fileName];
	url = [[DD_AppUtil addFtpSchemeIfAbsent: remoteSite.ftpurl] stringByAppendingString: url];
	url = [url stringByAddingPercentEscapesUsingEncoding: NSUTF8StringEncoding];

	//FTPOpDownload( self, (__bridge CFStringRef)url, (__bridge CFURLRef)destinationFile, (__bridge CFStringRef)remoteSite.username,
	//			  (__bridge CFStringRef)remoteSite.password , fileOffset, attemptPersistent);
	//return ftpop!=0;

    [self freshFtpop];

    ftpop.host = url;
    
    BOOL ok = [ftpop downloadToUrl: destinationFile fileOffset:fileOffset];
    
    return ok;
}

// --------------------------------------------------------------------------------------------------------
- (BOOL)upLoadFile: (NSString*)filePath asFileName: (NSString*) asFileName
{	
	ATRACE2(@"FTPManager: uploadFile: filePath=%@", filePath);
	
	if ([remoteSite.ftpurl length] <= 0)
		return NO;

	state = kFTPState_upload;
		
	NSURL* fileURL = [NSURL fileURLWithPath: filePath isDirectory: NO] ;
	
	NSString* uploadPath = [[DD_AppUtil addFtpSchemeIfAbsent: remoteSite.ftpurl] stringByAppendingString: path];
	uploadPath = [uploadPath stringByAppendingString: asFileName];
	ATRACE2(@"FTPManager: uploadFile: uploadPath=%@", uploadPath);

	uploadPath = [uploadPath stringByAddingPercentEscapesUsingEncoding: NSUTF8StringEncoding];

	//FTPOpUpload( self, (__bridge CFStringRef)uploadPath, (__bridge CFURLRef)fileURL, (__bridge CFStringRef)remoteSite.username, (__bridge CFStringRef)remoteSite.password );
	//return ftpop!=0;

    [self freshFtpop];

    ftpop.host = uploadPath;
    
    BOOL ok = [ftpop uploadFromUrl: fileURL];
    
    return ok;
}

// --------------------------------------------------------------------------------------------------------
- (NSTimeInterval) lapseTime
{
	//if (! ftpop)
	//	return 0.0;
	//return FTPOpLapseTime(ftpop);
    return [ftpop lapseTime];
}

#pragma mark restartAbleError
// --------------------------------------------------------------------------------------------------------
- (BOOL) restartAbleError
{
	if (! lastErr)
		return NO;
	
	NSInteger	code = [lastErr code];
	NSString *domain = [lastErr domain];
	
	// Socket not connected
	if (code == 57 && [domain isEqualToString: @"NSPOSIXErrorDomain" ])
		return YES;
	
	if (code == 2 && [domain isEqualToString: @"kCFErrorDomainCFNetwork" ])
		return YES;
	
	// secure connection failed
	if (code == -1200 && [domain isEqualToString: @"NSURLErrorDomain" ])
		return YES;
	
	// The request timed out.
	if (code == -1001 && [domain isEqualToString: @"NSURLErrorDomain" ])
		return YES;

	return NO;
}

// --------------------------------------------------------------------------------------------------------
- (void) reportError
{
	if (silentError)
	{
		ATRACE(@"FTPManager reportError: silentError lastErr=%@", [lastErr localizedDescription]);
		return;
	}
	if (lastErrMsg && lastErr)
	{
#if APP_TRACE
		NSString* str = [NSString stringWithFormat:@"%@ %@ domain=%@ code=%ld %@", 
						 lastErrMsg, downloadFileName, [lastErr domain], (long)[lastErr code], [lastErr localizedDescription]];
#else
		NSString* str = [NSString stringWithFormat:@"%@ %@ %@", lastErrMsg, downloadFileName, [lastErr localizedDescription]];
#endif
		NSString *domain = [lastErr domain];
		if ([domain isEqualToString:@"kCFErrorDomainCFNetwork"]
			|| [domain isEqualToString:@"NSPOSIXErrorDomain"])
		{
			[DD_AppUtil showErr: NSLocalizedString(@"No Server Connection", @"showErr ftp error")];
		}
		else
		{
			[DD_AppUtil showErr: str];
		}
		AFLOG(@"FTPManager: reportError err code=%d domain=%@ %@", [lastErr code], domain, str);
	}
	else
	{
		if (lastErrMsg)
		{
			NSString* str = [NSString stringWithFormat:@"%@ %@", lastErrMsg, downloadFileName];
			AFLOG(@"FTPManager: reportError %@", str);
		}
		[DD_AppUtil showErr:NSLocalizedString(@"Server Not Responding", @"Server Not Responding")];
	}
}

// --------------------------------------------------------------------------------------------------------
- (void)i_checkError: (NSError*)err msg:(NSString*)msg
{
	self.lastErr = err;
	self.lastErrMsg = msg;
	ATRACE(@"FTPManager: i_checkError err code=%ld domain=%@ checkForRestartableErrors=%d ftp=%x restartAbleError=%d", 
		   (long)[err code], [err domain], checkForRestartableErrors, (int)self,  [self restartAbleError]);
	if (! (checkForRestartableErrors && [self restartAbleError]))
	{
		[self reportError];
	}
}

// --------------------------------------------------------------------------------------------------------
- (void)i_downLoadFileBytesSoFar: (SInt64)bytesSoFar 
{
	[delegate downLoadFileBytesSoFar: bytesSoFar ];
}

// --------------------------------------------------------------------------------------------------------
- (void)i_start
{
    ATRACE2(@"%p FTPManager i_start", self);
    
    started = YES;
	[g_ep_app setActivity: YES];
}

// --------------------------------------------------------------------------------------------------------
- (void) clearAcivity
{
	if (started)
    {
		[g_ep_app setActivity: NO];
    }
	started = NO;
}

// --------------------------------------------------------------------------------------------------------
- (void)i_done:(BOOL)ok
{
	ATRACE2(@"FTPManger i_done: ok=%d downloadTrueName=%d downloadFileName=%@ downloadFileModDate=%@",
				ok, downloadTrueName, downloadFileName, downloadFileModDate);
	
    ATRACE2(@"FTPManager i_done started=%d", started);

    [self clearAcivity];
	
	if (ok && downloadFileModDate && downloadFileName)
	{
		if ([downloadFileName hasSuffix:@"/"])
		{
			AFLOG(@"FTPManger i_done: BAD downloadFileName=%@", downloadFileName);
			AFLOG(@"		path=%@", path);
			goto exit;
		}
		NSFileManager *fm = [NSFileManager defaultManager];
		NSString *destRootPath = [destRoot stringByAppendingPathComponent: path];
		NSError *err;
		NSString *tempFilePath = [destRootPath stringByAppendingPathComponent: kFTPTemp_Contents];
		NSString *downloadFilePath = [destRootPath stringByAppendingPathComponent: downloadFileName];
		NSString *downloadFilePath2 = nil;
		
		[remoteSite checkForLocalFileRename: &downloadFilePath];
		if (encodeFile)
		{
			downloadFilePath2 = downloadFilePath;
			downloadFilePath = [downloadFilePath stringByAppendingPathExtension: @"encoded"];
		}
		
		ATRACE2(@">> FTPManger i_done: removeItemAtPath downloadFilePath=%@", downloadFilePath);
		if (! downloadTrueName)
		{
			err = nil;
			[fm removeItemAtPath:downloadFilePath error:&err];
			if (err)
			{
				ATRACE2(@"FTPManger i_done: removeItemAtPath err=%@ downloadFilePath=%@", [err localizedDescription], downloadFilePath);
			}
			else 
			{
				ATRACE2(@"FTPManger i_done: removeItemAtPath downloadFilePath=%@",  downloadFilePath);
			}
			err = nil;
			[fm moveItemAtPath:tempFilePath toPath:downloadFilePath error:&err];
			if (err)
			{
				AFLOG(@"FTPManger i_done: moveItemAtPath err=%@ downloadFilePath=%@", [err localizedDescription], downloadFilePath);
				AFLOG(@"		downloadFileName=%@", downloadFileName);
				//NSString* msg = [NSString stringWithFormat:@"Rename temp file failed. %@", [err localizedDescription]];
				//[AppUtil showErr:msg];
			}
		}
		err = nil;
		NSDictionary *attrDict = [NSDictionary dictionaryWithObjectsAndKeys: downloadFileModDate, NSFileModificationDate, nil];
		[fm setAttributes: attrDict ofItemAtPath: downloadFilePath error: &err];
		if (err)
		{
			AFLOG(@"FTPManger i_done: setAttributes err=%@ downloadFilePath=%@", [err localizedDescription], downloadFilePath);
		}

		// Remove temp file that contains the name of the file been downloaded.
		tempFilePath = [destRootPath stringByAppendingPathComponent: kFTPTemp_Name];
		err = nil;
		[fm removeItemAtPath:tempFilePath error:&err];
		
		// Remove possible stray un-encoded file
		if (encodeFile)
		{
			err = nil;
			[fm removeItemAtPath:downloadFilePath2 error:&err];
			ATRACE2(@"FTPManger i_done: removeItemAtPath encoded downloadFilePath2=%@ err=%@",  downloadFilePath2, err);
		}
		
		if ([remoteSite isSkipBackupExtension: [downloadFilePath pathExtension]])
		{
			[DD_AppUtil addSkipBackupAttributeToItemAtPath: downloadFilePath value: YES];
		}
	}
exit:;
	self.downloadFileName = nil;
	self.downloadFileModDate = nil;
	ftpop = nil;
	
	if (ok)
		state = kFTPState_none;
	else
		state = kFTPState_failed;

	if (_deletePathWhenDone)
	{
		[[NSFileManager defaultManager] removeItemAtPath: _deletePathWhenDone error:nil];
	}
	
	[delegate operationDone];
}

// --------------------------------------------------------------------------------------------------------
- (BOOL)operationDoneOK
{
	return !( (state == kFTPState_failed) || (state == kFTPState_abort) );
}

// --------------------------------------------------------------------------------------------------------
- (void) clear
{
	state = kFTPState_none;
}

// --------------------------------------------------------------------------------------------------------
- (void)abort
{
	//AFLOG(@"FTPManager abort: path=%@ ftp=%lx rc=%d ref=%lx", path, self, [self retainCount], ref);
	//AFLOG(@"FTPManager abort: ftp=%lx path=%@ state=%d ref=%lx abortImmediately=%d", self, path, state, ref, abortImmediately);
	ATRACE2(@"	accessUrl=%x %d httpurl=%x %d username=%x %d",
		   accessUrl, [accessUrl retainCount], remoteSite.contentUrl, [remoteSite.contentUrl retainCount], remoteSite.username, [remoteSite.username retainCount]);
    ATRACE(@"%p FTPManger abort started=%d", self, started);
    
    [self clearAcivity];
	
	state = kFTPState_abort;
	self.downloadFileName = nil;
	self.downloadFileModDate = nil;
	
	if (ftpop)
	{
		//void *saveRef = ftpop;
		//ftpop = 0;
		// FTPOpAbort my kill self, don't touch any instance variables after this.
		//FTPOpAbort( saveRef, abortImmediately );
        [ftpop abortImmediately: abortImmediately];
	}
}

// --------------------------------------------------------------------------------------------------------
- (BOOL) deleteUnrefLocal
{
	return YES;
}

// --------------------------------------------------------------------------------------------------------
- (NSMutableDictionary*) filesDict
{
    return useFilesVars? filesDict: remoteSite.filesDict;
}

- (void) setFilesDict: (NSMutableDictionary*) newDict
{
    if (useFilesVars)
    {
        filesDict = newDict;
    }
    else
    {
        remoteSite.filesDict = newDict;
    }
}

// --------------------------------------------------------------------------------------------------------
- (NSString*) filesParamLines
{
    return useFilesVars? filesParamLines: remoteSite.filesParamLines;
}

- (void) setFilesParamLines: (NSString*) newString
{
    ATRACE2(@"%p FTPManger: setFilesParamLines useFilesVars=%d filesParamLines=%p newString=%p", self, useFilesVars, filesParamLines, newString);

    if (useFilesVars)
    {
        filesParamLines = newString;
    }
    else
    {
        remoteSite.filesParamLines = newString;
    }
}

// --------------------------------------------------------------------------------------------------------
- (NSUInteger) filesScanLocation
{
    return useFilesVars? filesScanLocation: remoteSite.filesScanLocation;
}

- (void) filesScanLocation: (NSUInteger) newVal
{
    if (useFilesVars)
    {
        filesScanLocation = newVal;
    }
    else
    {
        remoteSite.filesScanLocation = newVal;
    }
}

// --------------------------------------------------------------------------------------------------------
- (void) setFilesParamLines: (NSString *) param filesScanLocation: (int) offset
{
    if (useFilesVars)
    {
        self.filesParamLines = param;
        self.filesScanLocation = offset;
        self.filesDict = nil;
        
        // Must rebuild all encoded files.
        remoteSite.encodeFileDict = nil;

        ATRACE(@"FTPManger: setFilesParamLines remoteSite=%p remoteSite.encodeFileDict=%p", remoteSite, remoteSite.encodeFileDict);
    }
    else
    {
        [remoteSite prepareForFilesParamUpdate: param offset: offset];
    }
}

// --------------------------------------------------------------------------------------------------------
// --------------------------------------------------------------------------------------------------------

@end
