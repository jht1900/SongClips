/*
 
 */

#import "Access.h"
#import "AppDefs.h"
#import "AppUtil.h"
#import "AppDelegate.h"

static NSMutableArray *accessQue = 0;
static int	accessActive = 0;

#define kMaxActive		6

@implementation Access

@synthesize delegate;

// ------------------------------------------------------------------------------------
- (BOOL) sendToServer //:(NSURL*)theURL
{
	ATRACE(@"  sendToServer theURL=%@", theURL);
	
	NSString *cred = [NSString stringWithFormat:@"%@:%@", K_dsite_uname, K_dsite_pword];
	NSData *dat = [cred dataUsingEncoding:NSASCIIStringEncoding ];
	cred = [NSString stringWithFormat:@"Basic %@", [dat base64Encoding]];

	// create the NSMutableData instance that will hold the received data 
	receivedData = [[NSMutableData alloc] initWithLength:0];
	
	NSMutableURLRequest *theRequest = [NSMutableURLRequest requestWithURL:theURL
												cachePolicy:NSURLRequestReloadIgnoringLocalCacheData 
											timeoutInterval:60];
	if (cred) {
		[theRequest setValue:cred forHTTPHeaderField:@"Authorization"];
	}

	// Create the connection with the request and start loading the data. 
	// The connection object is owned both by the creator and the loading system. 
	NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:theRequest 
																  delegate:self 
														  startImmediately:YES];
	if (connection == nil) {
		// inform the user that the connection failed 
		//[AppUtil showErr: @"Registration failed to create connection"];
		[delegate access: self err: @"Access failed to create connection"];
		
		return NO;
	}
	else {
		[[AppDelegate default] setActivity: YES];
		
		accessActive++;
		ATRACE(@"		accessQue count=%lu accessActive=%d", (unsigned long)[accessQue count], accessActive);
		
		return YES;
	}
}

// ------------------------------------------------------------------------------------
+ (void) kickQue
{
	ATRACE(@"  kickQue: accessQue count=%lu accessActive=%d", (unsigned long)[accessQue count], accessActive);

	if ([accessQue count] > 0 && accessActive < kMaxActive) {
		Access	*acc1;
		do  {
			acc1 = [accessQue lastObject];
			[accessQue removeLastObject];
		} while (! [acc1 sendToServer] );
	}
	ATRACE(@"  kickQue: RETURN accessQue count=%lu accessActive=%d", (unsigned long)[accessQue count], accessActive);
}

// ------------------------------------------------------------------------------------
+ (void) finishedOne
{
	ATRACE(@"  finishedOne ");
	
	[[AppDelegate default] setActivity: NO];
	
	accessActive--;
	
	[Access kickQue];
}

// ------------------------------------------------------------------------------------
-(void)sendOp: (NSString*)urlStr
{		
	if (! [urlStr hasPrefix:@"http://"])
		urlStr = [@"http://" stringByAppendingString: urlStr];
	
	ATRACE(@"  sendOp: urlStr=%@", urlStr);

	theURL = [NSURL URLWithString:urlStr ];
	
	// [self sendToServer: theURL];
	
	if (! accessQue)
		accessQue = [NSMutableArray array];
	
	[accessQue addObject: self];
	
	[Access	kickQue];
}

// ------------------------------------------------------------------------------------
-(NSString*)extractPossibleHtmlErrorMsg: (NSString*)text
{
	ATRACE(@"extractPossibleHtmlErrorMsg: text=%@", text);

	NSRange range = [text rangeOfString:@"<title>" options: NSCaseInsensitiveSearch];
	if (range.location == NSNotFound )
		return text;
	NSRange range2 = [text rangeOfString:@"</title>" options: NSCaseInsensitiveSearch];
	if (range.location == NSNotFound)
		return text;
	range.location += range.length;
	range.length = range2.location - range.location;
	return [text substringWithRange:range];
}

// ------------------------------------------------------------------------------------
#pragma mark NSURLConnection delegate methods

- (void) connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    // This method is called when the server has determined that it has
	// enough information to create the NSURLResponse. It can be called
	// multiple times, for example in the case of a redirect, so each time
	// we reset the data. 
	
    [receivedData setLength:0];
}


- (void) connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    // Append the new data to the received data. 
    [receivedData appendData:data];
}


- (void) connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    NSString *message = [NSString stringWithFormat:@"%@ %@",
						 [error localizedDescription],
						 [error localizedFailureReason]];

	ATRACE(@"didFailWithError: error=%@", error);

	if (delegate)
		[delegate access: self err: message];
	else
		[AppUtil showMsg: message title:@"Access error"];
	
	
	[Access finishedOne];
}


- (NSCachedURLResponse *) connection:(NSURLConnection *)connection 
				   willCacheResponse:(NSCachedURLResponse *)cachedResponse
{
	// this application does not use a NSURLCache disk or memory cache
    return nil;
}


- (void) connectionDidFinishLoading:(NSURLConnection *)connection
{
	ATRACE(@"connectionDidFinishLoading: receivedData length=%lu", (unsigned long)[receivedData length]);

	if (delegate)
		[delegate access: self done: receivedData ];
	
	
	[Access finishedOne];
}

// ------------------------------------------------------------------
// ------------------------------------------------------------------

@end


