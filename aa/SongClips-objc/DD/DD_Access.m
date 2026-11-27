/*
 Copyright (C) 2008 John Henry Thompson. All Rights Reserved.
 */

#import "DD_Access.h"
#import "DD_AppDefs.h"
#import "DD_RemoteSite.h"

@implementation DD_Access

// ------------------------------------------------------------------------------------
- (void) applyCredentials: (NSMutableURLRequest *) theRequest
{
	NSString *cred;
	cred = [_remoteSite httpBasicAuthorization];
	ATRACE2(@"Access sendToAccessServer service_path=%@ service_uname=%@ service_passwd=%@ cred=%@", service_path, service_uname, service_passwd, cred);
	if (cred) {
		ATRACE2(@"Access sendToAccessServer cred=%@", cred);
		[theRequest setValue:cred forHTTPHeaderField:@"Authorization"];
	}
}

// ------------------------------------------------------------------------------------
- (void) sendToAccessServer:(NSURL*)theURL
{
	downloadStart = [NSDate timeIntervalSinceReferenceDate];
	
	_missingFile = NO;
	
	// create the NSMutableData instance that will hold the received data 
	receivedData = [[NSMutableData alloc] initWithLength:0];
	
	NSMutableURLRequest *theRequest = [NSMutableURLRequest requestWithURL:theURL
												cachePolicy:NSURLRequestReloadIgnoringLocalCacheData 
											timeoutInterval:60];
	
	[self applyCredentials: theRequest];
	
	// Create the connection with the request and start loading the data.
	// The connection object is owned both by the creator and the loading system.
	//
	NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:theRequest
																  delegate:self
														  startImmediately:NO];
	
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		NSRunLoop *loop = [NSRunLoop currentRunLoop];
		[connection scheduleInRunLoop:loop forMode:NSRunLoopCommonModes];
		[connection start];
		[loop run]; // make sure that you have a running run-loop.
	});
	if (connection == nil)  {
		// inform the user that the connection failed 
		[_delegate access: self accessErr: @"Access failed to create connection" ];
	}
}

// ------------------------------------------------------------------------------------
- (void) sendUrlStr: (NSString*)urlStr 
{
	NSURL* theURL = [NSURL URLWithString:urlStr ];
	
	[self sendToAccessServer: theURL];
}

// ------------------------------------------------------------------------------------
-(NSString*)extractPossibleHtmlErrorMsg: (NSString*)text
{
	ATRACE(@"extractPossibleHtmlErrorMsg: text=%@", text);

	NSRange range = [text rangeOfString:@"<title>" options: NSCaseInsensitiveSearch];
	if (range.location == NSNotFound )
		return text;
	NSRange range2 = [text rangeOfString:@"</title>" options: NSCaseInsensitiveSearch];
	if (range2.location == NSNotFound)
		return text;
	range.location += range.length;
	range.length = range2.location - range.location;
	return [text substringWithRange:range];
}

// ------------------------------------------------------------------------------------
#pragma mark NSURLConnection delegate methods

// This method is called when the server has determined that it has
// enough information to create the NSURLResponse. It can be called
// multiple times, for example in the case of a redirect, so each time
// we reset the data. 
//
- (void) connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    [receivedData setLength:0];

    NSHTTPURLResponse * httpResponse = (NSHTTPURLResponse *) response;
    NSInteger statusCode = httpResponse.statusCode;
	
    if ((statusCode / 100) != 2)  {
        NSString *message = [NSString stringWithFormat:@"HTTP error %zd", (ssize_t) statusCode];
		ATRACE2(@"Access didReceiveResponse message=%@ accessUrl=%@", message, _remoteSite.accessUrl);
		[connection cancel];
		if (_silentOnMissingFileError && (statusCode == 404 || statusCode == 403)) {
			_missingFile = YES;
			[self connectionDidFinishLoading: connection];
			// self is now dead
		}
		else  {
			[_delegate access: self accessErr: message];
			// self is now dead
		}
	}
}

// ------------------------------------------------------------------------------------
- (void) connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    // Append the new data to the received data. 
    [receivedData appendData:data];
}

// ------------------------------------------------------------------------------------
- (void) connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
	NSString *localDesc = [error localizedDescription];
	NSString *localFail = [error localizedFailureReason];
	
    NSString *message = [NSString stringWithFormat:@"%@ %@", localDesc, localFail];

	AFLOG(@"Access didFailWithError error=%@ message=%@", error, message);

	if (! localDesc || ! localFail
		|| (error.code == 22 && [error.domain isEqualToString:@"NSPOSIXErrorDomain"]))
		message = NSLocalizedString(@"Cannot Establish Connection",@"connection failure message: Cannot Establish Connection");
	
	[_delegate access: self accessErr: message ];
}

// ------------------------------------------------------------------------------------
- (NSCachedURLResponse *) connection:(NSURLConnection *)connection 
				   willCacheResponse:(NSCachedURLResponse *)cachedResponse
{
	// this application does not use a NSURLCache disk or memory cache
    return nil;
}

// ------------------------------------------------------------------------------------
- (void) connectionDidFinishLoading:(NSURLConnection *)connection
{
	ATRACE(@"Access connectionDidFinishLoading receivedData=%p len=%lu ", receivedData, (unsigned long)[receivedData length]);
	
	_remoteSite.meter_flist_bytes += [receivedData length];
	_remoteSite.meter_flist_lapse += [NSDate timeIntervalSinceReferenceDate] - downloadStart;
	
	[_delegate access: self done: receivedData ];
}

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


// ------------------------------------------------------------------------------------
// ------------------------------------------------------------------------------------

@end


