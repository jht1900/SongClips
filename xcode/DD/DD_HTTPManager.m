/*
 Copyright (C) 2008 John Henry Thompson. All Rights Reserved.
 */

#import "DD_HTTPManager.h"
//#import "DD_FileDir.h"
//#import "DD_AppState.h"
//#import "DD_AppStateInternal.h"
//#import "DD_AppUtil.h"
//#import "DD_FileHTTP.h"
//#import "JSONKit.h"

#import "DD_FileFTP.h"
#import "UtilApp.h"
#import "UtilPath.h"

// --------------------------------------------------------------------------------------------------------
@implementation DD_HTTPManager

#if APP_TRACE_DOWNLOAD
@synthesize	xsource;
#endif

// --------------------------------------------------------------------------------------------------------
- (void) cleanUp
{
	ATRACE2(@"DD_HTTPManager cleanUp ");
		
	[_connection cancel];
	_connection = nil;
	
	[_fileStream close];
	_fileStream = nil;
	
	startTime = 0;
}

// --------------------------------------------------------------------------------------------------------
- (void)dealloc
{
	ATRACE(@"%p DD_HTTPManager: dealloc remoteSite.siteID=%@ destPath2=%@", self, _remoteSite.siteID, destPath2 );
	
	[self cleanUp];
	
//	accessPostFile.delegate = nil;
}


// --------------------------------------------------------------------------------------------------------
- (void) noteEvent
{
	startTime = [NSDate timeIntervalSinceReferenceDate];
}

// --------------------------------------------------------------------------------------------------------
// return YES for sucess
- (BOOL) downLoadFile: (DD_FileFTP*)sf fileOffset:(SInt64)fileOffset pathHome: (NSString *) pathHome doneBlock: (void (^)(void))a_doneBlock
{	
//	protectDataFile = NO;
//	encodeFile = NO;
    NSString *destPath = nil;
//	NSString *ext = [sf.fileName pathExtension];

	ATRACE(@"DD_HTTPManager: downLoadFile sf=%@", sf);
	
	doneBlock = a_doneBlock;
	
    if (_getFileAttributeMode)
    {
        ATRACE2(@"DD_HTTPManager: getFileAttributeMode skipStreaming");
        goto skipStreaming;
    }

	//ATRACE_DOWNLOAD2(@"DD_HTTPManager: downLoadFile: [self fileTP]=%d", [self fileTP]);
//	if ([self fileTP])
//	{
//		return [super downLoadFile:sf fileOffset:fileOffset pathHome: pathHome];
//	}
//	ATRACE_DOWNLOAD2(@"DD_HTTPManager: downLoadFile: fileName=%@ path=%@ modDate=%@", sf.fileName, path, [sf.modDate description]);
//	ATRACE2(@"DD_HTTPManager: downLoadFile: fileName=%@ size=%qi offset=%qi getFileAttributeMode=%d", sf.fileName, sf.size, fileOffset, getFileAttributeMode);
	
	destPath = [self destPathToStoreFileName: sf.fileName modDate:sf.modDate];
	
	ATRACE2(@"DD_HTTPManager: remoteSite.encodeExt=%@ destPath=%@", remoteSite.encodeExt, destPath);
	ATRACE2(@"DD_HTTPManager: remoteSite.protect_dirs=%@", remoteSite.protect_dirs);
	
//	if (remoteSite.reset_exts && ! remoteSite.reset_ext_update_seen && [remoteSite isResetExt: ext])
//	{
//		remoteSite.reset_ext_update_seen = YES;
//		
//		ATRACE(@"DD_HTTPManager: reset_ext_update_seen sf.fileName=%@ siteID=%@", sf.fileName, remoteSite.siteID);
//	}
	
//    // APP_PROTECT_STREAM
//    if (remoteSite.protectExt)
//        protectDataFile = [remoteSite isProtectExt: ext];
//    if (! protectDataFile && remoteSite.protect_dirs)
//        protectDataFile = [remoteSite isProtectedPath: path];
//    
//	if ( (remoteSite.encodeFiles
//			&& ((encodeFile = [remoteSite isEncodeFile: [path stringByAppendingPathComponent: sf.fileName]]))
//          )
//		|| (remoteSite.encodeExt 
//			&& ((encodeFile = [remoteSite isEncodeExtension: ext]))
//            && ((encodeFile = ![remoteSite isEncodeExcludeDir: path]))
//            )
//		)
//	{
//		// Download and stored in encoded format
//		ATRACE2(@"DD_HTTPManager: dataToEncode sf.fileName=%@ protectDataFile=%d", sf.fileName, protectDataFile);
//		
//		self.fileStream = nil;
//		self.destPath2 = destPath;
//		self.dataToEncode = [NSMutableData dataWithCapacity: 100];
//	}
//	else
	{
		// Normal download - stream data to file
		BOOL append = (fileOffset > 0);
        
        // APP_PROTECT_STREAM
//		if (protectDataFile)
//        {
//            ATRACE2(@"DD_HTTPManager: protectDataFile sf.fileName=%@ destPath=%@", sf.fileName, [remoteSite shortenLocalPath: destPath]);
//            
//            // NSDictionary *attrDict = [NSDictionary dictionaryWithObject:NSFileProtectionComplete forKey:NSFileProtectionKey];
//            NSDictionary *attrDict = @{NSFileProtectionKey: [remoteSite fileProtection]};
//            BOOL ok;
//            NSError *err = nil;
//            if (append)
//            {
//                // Already streaming to file set attributes now. ?? Attributes should aready be set
//                ok = [[NSFileManager defaultManager] setAttributes: attrDict ofItemAtPath:destPath error:&err ];
//            }
//            else
//            {
//                // We are streaming into a protected file, create and set attributes now.
//                append = YES;
//                ok = [[NSFileManager defaultManager] createFileAtPath:destPath contents:[NSData data] attributes:attrDict ];
//            }
//            if (! ok)
//            {
//                AFLOG(@"DD_HTTPManager: downLoadFile: failed to protect file %@ err=%@", sf.fileName, err);
//            }
//        }

		createEnclosingDirectory(destPath);
		
		[_fileStream close];
		self.fileStream = [NSOutputStream outputStreamToFileAtPath:destPath append:append];
		
		ATRACE2(@"DD_HTTPManager: fileStream=%@ destPath=%@", fileStream, destPath);
		
		if (! _fileStream)
		{
			ATRACE(@"DD_HTTPManager: NSOutputStream failed dest=%@", destPath);
			return NO;
		}
		ATRACE2(@"DD_HTTPManager: fileStream=%@", fileStream);
		[_fileStream open];
	}
	
skipStreaming:;
	// Open a connection for the URL.
	NSString	*source = sf.source;
	NSURL		*url;
	NSString	*cred = nil;
	
	if ([source length] > 0)
	{
		// absolute http address source specified. Derive from dest
		url = [NSURL URLWithString: source];
		
		ATRACE2(@"DD_HTTPManager: downLoadFile fileName=%@ source=%@ url=%@", sf.fileName, source, url);
//		ATRACE_DOWNLOAD2(@"DD_HTTPManager: downLoadFile fileName=%@ source=%@ url=%@", sf.fileName, source, url);
//		ATRACE_DOWNLOAD2(@"DD_HTTPManager: downLoadFile fileName=%@ source  url=%@", sf.fileName, url);
		//ATRACE_DOWNLOAD2(@"DD_HTTPManager: url path=%@", sf.fileName, source, [url path]);
		
		// Extract the optional user name and password
		NSString *user = [url user];
		NSString *passwd = [url password];
		ATRACE2(@"DD_HTTPManager: downLoadFile user=%@ passwd=%@", user, passwd);
		
		if ([user length] > 0)
		{
			cred = [_remoteSite httpBasicAuthorizationForUser: user password: passwd];
		}
		else 
		{
//			ATRACE_DOWNLOAD2(@"DD_HTTPManager: downLoadFile cred reused check");
			// No user name in url, attempt to get user name/password from site then contenturl
			cred = [_remoteSite httpBasicAuthorization];
//			if (! [source hasPrefix: [remoteSite httpStringforContentUrl]])
//			{
//				// Don't share credentials if not in same content domain.
//				ATRACE_DOWNLOAD2(@"DD_HTTPManager: downLoadFile cred reused NOT httpStringforContentUrl=%@", [remoteSite httpStringforContentUrl]);
//				cred = nil;
//			}
		}
	}
	else 
	{
		// !!@ NO source
		// No absolute http address source specified. Derive from dest
//		source = [[pathHome stringByAppendingPathComponent: _path] stringByAppendingPathComponent: sf.fileName];
//
//		url = [NSURL URLWithString: [_remoteSite httpStringForPath: source] ];
//		
//		cred = [_remoteSite httpBasicAuthorization];
//		
//		ATRACE2(@"DD_HTTPManager: downLoadFile source=%@ cred=%@", source, cred);
	}
#if APP_TRACE_DOWNLOAD
	self.xsource = source;
#endif

    ATRACE(@"DD_HTTPManager: fileName=%@ %@", sf.fileName, source);

    //NSURLRequest *theRequest = [NSURLRequest requestWithURL:url];
	NSMutableURLRequest *theRequest = [NSMutableURLRequest requestWithURL:url
															  cachePolicy:NSURLRequestReloadIgnoringLocalCacheData 
														  timeoutInterval:60];
	if (cred) {
		[theRequest setValue:cred forHTTPHeaderField:@"Authorization"];
	}
    if (_getFileAttributeMode) {
		NSString *rangeStr = [NSString stringWithFormat:@"bytes=0-0"];
		[theRequest setValue:rangeStr forHTTPHeaderField:@"Range"];
		ATRACE(@"DD_HTTPManager: downLoadFile: getFileAttributeMode rangeStr=%@ fileName=%@", rangeStr, sf.fileName);
    }
	else if (fileOffset)
	{
		//- (void)setValue:(NSString *)value forHTTPHeaderField:(NSString *)field
		NSString *rangeStr = [NSString stringWithFormat:@"bytes=%qi-", fileOffset];
		[theRequest setValue:rangeStr forHTTPHeaderField:@"Range"];
		ATRACE(@"DD_HTTPManager: downLoadFile: rangeStr=%@ fileName=%@", rangeStr, sf.fileName);
	}
	
	[_connection cancel];
	_connection = [[NSURLConnection alloc] initWithRequest:theRequest
												 delegate:self 
										 startImmediately:YES];
	if (_connection == nil) {
		// inform the user that the connection failed 
		ATRACE(@"DD_HTTPManager: downLoadFile FAILED fileName=%@", sf.fileName);
		
		[_fileStream close];
		_fileStream = nil;
		
		return NO;
	}
	
	totalBytesWritten = 0;
	
	[self noteEvent];
	
	[self i_start];
	
	return YES;
}

// --------------------------------------------------------------------------------------------------------
// Prepare to write file to temp file, save fileName for later resume check
- (NSString *) destPathToStoreFileName: (NSString *)fileName modDate:(NSDate*)modDate
{
	state = kHTTPState_download;
	_downloadFileModDate = modDate;
	_downloadFileName = fileName;
	
	NSString *destPath = [_destRoot stringByAppendingPathComponent: _path];
	
	if (_downloadTrueName) {
		destPath = [destPath stringByAppendingPathComponent: fileName];
	}
	else {
		NSString *destForName = [destPath stringByAppendingPathComponent: kHTTP_Temp_Name];
		
		[fileName writeToFile: destForName atomically: NO encoding: NSUTF8StringEncoding error:nil];
		
		destPath = [destPath stringByAppendingPathComponent: kHTTP_Temp_Contents];
	}
	
	ATRACE(@"DD_HTTPManager: destPathToStoreFileName _destRoot=%@ destPath=%@", _destRoot,  destPath);
	
	return destPath;
}

// --------------------------------------------------------------------------------------------------------
- (NSString *) localPath
{
	NSString *localPath = [_destRoot stringByAppendingPathComponent: _path];
	localPath = [localPath stringByAppendingPathComponent: _downloadFileName];
	ATRACE(@"DD_HTTPManager: localPath=%@", localPath);
	return localPath;
}

// --------------------------------------------------------------------------------------------------------
- (NSString *) partialPath
{
	NSString *partialPath = _path;
	partialPath = [partialPath stringByAppendingPathComponent: _downloadFileName];
	ATRACE(@"DD_HTTPManager: partialPath=%@", partialPath);
	return partialPath;
}

// --------------------------------------------------------------------------------------------------------
//static NSDateFormatter *dateFormatter = nil;

// --------------------------------------------------------------------------------------------------------
// A delegate method called by the NSURLConnection when the request/response 
// exchange is complete.  We look at the response to check that the HTTP 
// status code is 2xx and that the Content-Type is acceptable.  If these checks 
// fail, we give up on the transfer.
//
- (void)connection:(NSURLConnection *)theConnection didReceiveResponse:(NSURLResponse *)response
{
	ATRACE2(@"DD_HTTPManager: didReceiveResponse: response=%@", response);
    NSHTTPURLResponse * httpResponse;
	
	[self noteEvent];
	
    httpResponse = (NSHTTPURLResponse *) response;
    //ASSERTLOG( [httpResponse isKindOfClass:[NSHTTPURLResponse class]] );
    
	BOOL	ok = (httpResponse.statusCode / 100) == 2;
	
    if (ok) {
		// File ok
        if (_getFileAttributeMode) {
            NSDictionary *headers = [httpResponse allHeaderFields];
            ATRACE(@"DD_HTTPManager: didReceiveResponse fileName=%@ headers=%@", _downloadFileName, headers);
            NSString	*strVal = [headers objectForKey:@"Last-Modified"];
            if (strVal) {
                ATRACE(@"DD_HTTPManager: didReceiveResponse: Last-Modified strVal=%@", strVal);
                NSDateFormatter *dateFormatter = [NSDateFormatter new];
                [dateFormatter setDateFormat:@"EEE, dd MMM yyyy HH:mm:ss zzz"];
                _fileModDate = [dateFormatter dateFromString:strVal];
                ATRACE(@"DD_HTTPManager: didReceiveResponse downloadFileModDate=%@ fileModDate=%@", _downloadFileModDate, _fileModDate);
            }
            // "Content-Range" = "bytes 0-0/2599";
            strVal = [headers objectForKey:@"Content-Range"];
            if (strVal) {
                ATRACE(@"DD_HTTPManager: didReceiveResponse: Content-Range strVal='%@'", strVal);
                NSArray *arr = [strVal componentsSeparatedByString: @"/"];
                if ([arr count] >= 2) {
                    self.fileSize = [arr[1] longLongValue];
                }
            }
            [_connection cancel];
            [self cleanUp];
            [self i_done: YES];
        }
	}
	else {
		// Get file failed.
        NSString *msg = [NSString stringWithFormat:@"HTTP error %zd", (ssize_t) httpResponse.statusCode];
		ATRACE(@"DD_HTTPManager download err=%@ url=%@", msg, [[response URL] description]);
		[_connection cancel];
		[self cleanUp];
		if (httpResponse.statusCode == 404) {
			// Silently ignore missing files. @files may be out of date
			//
			ATRACE(@"DD_HTTPManager download Silently ignore err=%@ url=%@", msg, [[response URL] description]);
			[self i_done: YES];
		}
		else  {
			NSError *err = [[NSError alloc] initWithDomain:@"http" code:httpResponse.statusCode userInfo:nil];
			[self i_checkError: err msg: msg];
			[self i_done: NO];
		}
    } 
}

// --------------------------------------------------------------------------------------------------------
// A delegate method called by the NSURLConnection as data arrives.  We just 
// write the data to the file.
//
- (void)connection:(NSURLConnection *)theConnection didReceiveData:(NSData *)data
{
	ATRACE2(@"DD_HTTPManager: didReceiveData: data length=%d fileStream=%@", [data length], _fileStream);
    NSInteger       bytesWrittenSoFar;
    NSInteger       dataLength;
    const uint8_t	*dataBytes;
    NSInteger       bytesWritten;

	[self noteEvent];

	if (! _fileStream) {
//		if (dataToEncode) {
//			// Keep data tobe encoded in memory until written to disk
//			[dataToEncode appendData: data];
//			bytesWrittenSoFar = [data length];
//			ATRACE2(@"DD_HTTPManager dataToEncode file=%@ length=%d data lenth=%d", downloadFileName, [dataToEncode length], [data length]);
//		}
//		else {
			ATRACE(@"DD_HTTPManager: fileStream NULL");
			return;
//		}
	}
	else  {
		dataLength = [data length];
		dataBytes  = [data bytes];
		bytesWrittenSoFar = 0;
		do {
			bytesWritten = [_fileStream write:&dataBytes[bytesWrittenSoFar] maxLength:dataLength - bytesWrittenSoFar];
			ATRACE2(@"	 bytesWritten=%d bytesWrittenSoFar=%d", bytesWritten, bytesWrittenSoFar);
			if (bytesWritten == -1) {
				ATRACE(@"DD_HTTPManager download File write error file=%@ path=%@", _downloadFileName, _path);
				ATRACE(@"	bytesWritten=%ld bytesWrittenSoFar=%ld dataLength=%ld", (long)bytesWritten, (long)bytesWrittenSoFar, (long)dataLength);
				// ATRACE_DOWNLOAD(@"	xsource=%@", xsource);
				[self i_checkError: nil msg:@"HTTP Download file write error"];
				[self i_done: NO];
				[self cleanUp];
				return;
				break;
			} 
			else  {
				bytesWrittenSoFar += bytesWritten;
			}
		} while (bytesWrittenSoFar < dataLength);
	}

	totalBytesWritten += bytesWrittenSoFar;
	
	[self i_downLoadFileBytesSoFar: totalBytesWritten];
}

// --------------------------------------------------------------------------------------------------------
- (void)connection:(NSURLConnection *)theConnection didFailWithError:(NSError *)error
{
	AFLOG(@"DD_HTTPManager: HTTP download error=%@ fileName=%@", error, _downloadFileName);
	
    [self i_checkError: error msg:@"HTTP download"];
	
	[self cleanUp];
	
    [self i_done: NO];
	
}

// --------------------------------------------------------------------------------------------------------
- (void)connectionDidFinishLoading:(NSURLConnection *)theConnection
{
	ATRACE2(@"DD_HTTPManager: connectionDidFinishLoading fileName=%@", downloadFileName);
	ATRACE(@"DD_HTTPManager: totalBytesWritten=%qi", totalBytesWritten);
	
	// Must do clean up before calling i_done
	[self cleanUp];
	
    [self i_done: YES];
}

// ------------------------------------------------------------------------------------
// MUST return nil or severe memory leak.
//
- (NSCachedURLResponse *) connection:(NSURLConnection *)connection 
				   willCacheResponse:(NSCachedURLResponse *)cachedResponse
{
	// this application does not use a NSURLCache disk or memory cache
    return nil;
}

// --------------------------------------------------------------------------------------------------------
- (BOOL)upLoadFile: (NSString*)filePath asFileName: (NSString*) asFileName
{
//	ATRACE2(@"DD_HTTPManager: uploadFile: filePath=%@ asFileName=%@ self.filesParamLines=%lx", filePath, asFileName, self.filesParamLines );
//	ATRACE2(@"DD_HTTPManager: accessPostFile SETUP remote.contentUrl=%@ accessUrl=%@", remoteSite.contentUrl, remoteSite.accessUrl);
//
//	accessPostFile.delegate = nil;
//	accessPostFile = [DD_AccessPostFile new];
//	accessPostFile.delegate = self;
//	accessPostFile.remoteSite = remoteSite;
//	accessPostFile.dontSendUitems = YES;
//	accessPostFile.destContentUrl = ! remoteSite.sendViewlogToSite;
//	
//	return [accessPostFile upLoadFile: filePath ];
	return NO;
}

// --------------------------------------------------------------------------------------------------------
- (BOOL) restartAbleError
{
	// !!@ need to real restatable http error status codes
	if ([_lastErr code] == 200 && [[_lastErr domain] isEqualToString:@"http" ])
		return YES;
	//return [super restartAbleError];
	if (! _lastErr)
		return NO;
	NSInteger	code = [_lastErr code];
	NSString *domain = [_lastErr domain];
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
- (NSTimeInterval) lapseTime
{
	if (startTime == 0)
		return 0;
	return [NSDate timeIntervalSinceReferenceDate] - startTime;
}

// --------------------------------------------------------------------------------------------------------
- (void)abort
{
	ATRACE2(@"DD_HTTPManager abort ");
//	if (! [self fileTP])
	{
		[_connection cancel];
		[self cleanUp];
	}
	
	//[super abort];
	[self clearAcivity];
	
	state = kHTTPState_abort;
	self.downloadFileName = nil;
	self.downloadFileModDate = nil;
}

// ------------------------------------------------------------------------------------
#pragma mark Access delegate methods

// Report an error during access check
//- (void) access:(DD_Access*)accessx accessErr:(NSString*)errMsg appLink: (NSString *)appLink
//{
//	AFLOG(@"DD_HTTPManager access err=%@", errMsg);
//	
//	accessPostFile.delegate = nil;
//	accessPostFile = nil;
//	
//	[g_ep_app showMsg: remoteSite.accessUrlForMsg	title: errMsg appLink: appLink];
//
//	// Must do clean up before calling i_done
//	[self cleanUp];
//    [self i_done: NO];
//}
//
//- (void) access:(DD_Access*)accessx did:(NSString*)didValue anyChange: (BOOL) anyChange
//{
//	ATRACE(@"DD_HTTPManager access did=%@ ", didValue);
//	
//	accessPostFile.delegate = nil;
//	accessPostFile = nil;
//
//	// Must do clean up before calling i_done
//	[self cleanUp];
//    [self i_done: YES];
//}

// 2011-09-26 Align with Access.m
// Following code from: http://stackoverflow.com/questions/2679944/objective-c-ssl-synchronous-connection

// ------------------------------------------------------------------------------------
- (BOOL)connection:(NSURLConnection *)connection 
canAuthenticateAgainstProtectionSpace:(NSURLProtectionSpace *)protectionSpace 
{
	ATRACE2(@"Access canAuthenticateAgainstProtectionSpace authenticationMethod=%@", protectionSpace.authenticationMethod);
    
    return [protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust];  
}  

// ------------------------------------------------------------------------------------
- (void)connection:(NSURLConnection *)connection 
didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge 
{
	ATRACE2(@"Access didReceiveAuthenticationChallenge challenge=%@ previousFailureCount=%d", challenge, [challenge previousFailureCount]);
    
    [challenge.sender useCredential:[NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust] 
		 forAuthenticationChallenge:challenge];  
}

// --------------------------------------------------------------------------------------------------------
- (void) reportError
{
	if (_silentError) {
		ATRACE(@"DD_HTTPManager reportError: silentError lastErr=%@", [_lastErr localizedDescription]);
		return;
	}
	if (_lastErrMsg && _lastErr) {
#if APP_TRACE
		NSString* str = [NSString stringWithFormat:@"%@ %@ domain=%@ code=%ld %@",
						 _lastErrMsg, _downloadFileName, [_lastErr domain], (long)[_lastErr code], [_lastErr localizedDescription]];
#else
		NSString* str = [NSString stringWithFormat:@"%@ %@ %@", _lastErrMsg, _downloadFileName, [_lastErr localizedDescription]];
#endif
		NSString *domain = [_lastErr domain];
		if ([domain isEqualToString:@"kCFErrorDomainCFNetwork"]
			|| [domain isEqualToString:@"NSPOSIXErrorDomain"]) {
			// [EP_AppUtil showErr: NSLocalizedString(@"No Server Connection", @"showErr ftp error")];
			AFLOG(@"DD_HTTPManager: No Server Connection");
		}
		else {
			// [EP_AppUtil showErr: str];
		}
		AFLOG(@"DD_HTTPManager: reportError err code=%ld domain=%@ %@", (long)[_lastErr code], domain, str);
	}
	else {
		if (_lastErrMsg) {
			NSString* str = [NSString stringWithFormat:@"%@ %@", _lastErrMsg, _downloadFileName];
			AFLOG(@"DD_HTTPManager: reportError %@", str);
		}
		// [EP_AppUtil showErr:NSLocalizedString(@"Server Not Responding", @"Server Not Responding")];
		AFLOG(@"DD_HTTPManager: Server Not Responding");
	}
}

// --------------------------------------------------------------------------------------------------------
- (void)i_checkError: (NSError*)err msg:(NSString*)msg
{
	_lastErr = err;
	_lastErrMsg = msg;
	ATRACE(@"DD_HTTPManager: i_checkError err code=%ld domain=%@ checkForRestartableErrors=%d ftp=%p restartAbleError=%d",
		   (long)[err code], [err domain], _checkForRestartableErrors, self,  [self restartAbleError]);
	if (! (_checkForRestartableErrors && [self restartAbleError])) {
		[self reportError];
	}
}

// --------------------------------------------------------------------------------------------------------
- (void)i_downLoadFileBytesSoFar: (SInt64)bytesSoFar
{
	//[_delegate downLoadFileBytesSoFar: bytesSoFar ];
	[_delegate httpm_downdload: self  bytesSoFar: bytesSoFar ];
}

// --------------------------------------------------------------------------------------------------------
- (void)i_start
{
	ATRACE2(@"%p DD_HTTPManager i_start", self);
	started = YES;
	setActivity(YES);
}

// --------------------------------------------------------------------------------------------------------
- (void) clearAcivity
{
	if (started) {
		setActivity(NO);
	}
	started = NO;
}

// --------------------------------------------------------------------------------------------------------
- (void)i_done:(BOOL)ok
{
	ATRACE2(@"DD_HTTPManager i_done: ok=%d downloadTrueName=%d downloadFileName=%@ downloadFileModDate=%@",
			ok, downloadTrueName, downloadFileName, downloadFileModDate);
	
	ATRACE2(@"DD_HTTPManager i_done started=%d", started);
	
	[self clearAcivity];
	
	if (ok && _downloadFileModDate && _downloadFileName) {
		if ([_downloadFileName hasSuffix:@"/"]) {
			AFLOG(@"DD_HTTPManager i_done: BAD downloadFileName=%@", _downloadFileName);
			AFLOG(@"		path=%@", _path);
			goto exit;
		}
		NSFileManager *fm = [NSFileManager defaultManager];
		NSString *destRootPath = [_destRoot stringByAppendingPathComponent: _path];
		NSError *err;
		NSString *tempFilePath = [destRootPath stringByAppendingPathComponent: kHTTP_Temp_Contents];
		NSString *downloadFilePath = [destRootPath stringByAppendingPathComponent: _downloadFileName];
//		NSString *downloadFilePath2 = nil;
		
//		[_remoteSite checkForLocalFileRename: &downloadFilePath];
//		if (encodeFile)
//		{
//			downloadFilePath2 = downloadFilePath;
//			downloadFilePath = [downloadFilePath stringByAppendingPathExtension: @"encoded"];
//		}
		ATRACE2(@">> DD_HTTPManager i_done: removeItemAtPath downloadFilePath=%@", downloadFilePath);
		if (! _downloadTrueName) {
			err = nil;
			[fm removeItemAtPath:downloadFilePath error:&err];
			if (err) {
				ATRACE2(@"DD_HTTPManager i_done: removeItemAtPath err=%@ downloadFilePath=%@", [err localizedDescription], downloadFilePath);
			}
			else {
				ATRACE2(@"DD_HTTPManager i_done: removeItemAtPath downloadFilePath=%@",  downloadFilePath);
			}
			err = nil;
			[fm moveItemAtPath:tempFilePath toPath:downloadFilePath error:&err];
			if (err) {
				AFLOG(@"DD_HTTPManager i_done: moveItemAtPath err=%@ downloadFilePath=%@", [err localizedDescription], downloadFilePath);
				AFLOG(@"		downloadFileName=%@", _downloadFileName);
				//NSString* msg = [NSString stringWithFormat:@"Rename temp file failed. %@", [err localizedDescription]];
				//[AppUtil showErr:msg];
			}
		}
		err = nil;
		NSDictionary *attrDict = [NSDictionary dictionaryWithObjectsAndKeys: _downloadFileModDate, NSFileModificationDate, nil];
		[fm setAttributes: attrDict ofItemAtPath: downloadFilePath error: &err];
		if (err) {
			AFLOG(@"DD_HTTPManager i_done: setAttributes err=%@ downloadFilePath=%@", [err localizedDescription], downloadFilePath);
		}
		// Remove temp file that contains the name of the file been downloaded.
		tempFilePath = [destRootPath stringByAppendingPathComponent: kHTTP_Temp_Name];
		err = nil;
		[fm removeItemAtPath:tempFilePath error:&err];
		
		// Remove possible stray un-encoded file
//		if (encodeFile) {
//			err = nil;
//			[fm removeItemAtPath:downloadFilePath2 error:&err];
//			ATRACE2(@"FTPManger i_done: removeItemAtPath encoded downloadFilePath2=%@ err=%@",  downloadFilePath2, err);
//		}
//		if ([remoteSite isSkipBackupExtension: [downloadFilePath pathExtension]]) {
//			[DD_AppUtil addSkipBackupAttributeToItemAtPath: downloadFilePath value: YES];
//		}
	}
exit:;
	_downloadFileName = nil;
	_downloadFileModDate = nil;
//	ftpop = nil;
	
	if (ok)
		state = kHTTPState_none;
	else
		state = kHTTPState_failed;
	
	if (_deletePathWhenDone) {
		[[NSFileManager defaultManager] removeItemAtPath: _deletePathWhenDone error:nil];
	}
	
	ATRACE(@"DD_HTTPManager operationDone totalBytesWritten=%lld", totalBytesWritten);

	[_delegate httpm_done: self];
	
	//[_delegate operationDone];
	
	if (doneBlock) doneBlock();
}

// --------------------------------------------------------------------------------------------------------
// --------------------------------------------------------------------------------------------------------

@end
