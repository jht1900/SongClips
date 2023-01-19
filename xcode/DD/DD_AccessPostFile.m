/*
 
 Based on https://developer.apple.com/library/ios/#samplecode/SimpleURLConnections/Introduction/Intro.html

 Copyright (C) 2008 John Henry Thompson. All Rights Reserved.
 */

#import "DD_AccessPostFile.h"
#import "DD_AppDefs.h"

#include <sys/socket.h>
#include <CFNetwork/CFNetwork.h>

#import "JSONKit.h"

#import "DD_AppState.h"

#import "DD_Flog.h"

#pragma mark * Utilities

// ----------------------------------------------------------------------------------------------------------
//  CFStream bound pair generates weird log message
//  CFStream bound pair crashers
// This is a drop-in replacement for CFStreamCreateBoundPair that is necessary 
// because the bound pairs are broken on iPhone OS up-to-and-including 
// version 3.0.1 <rdar://problem/7027394> <rdar://problem/7027406>.  It 
// emulates a bound pair by creating a pair of UNIX domain sockets and wrapper 
// each end in a CFSocketStream.  This won't give great performance, but 
// it doesn't crash!
//
static void CFStreamCreateBoundPairCompat(
    CFAllocatorRef      alloc, 
    CFReadStreamRef *   readStreamPtr, 
    CFWriteStreamRef *  writeStreamPtr, 
    CFIndex             transferBufferSize
)
{
    #pragma unused(transferBufferSize)
    int                 err;
    Boolean             success;
    CFReadStreamRef     readStream;
    CFWriteStreamRef    writeStream;
    int                 fds[2];
    
    ASSERTLOG(readStreamPtr != NULL);
    ASSERTLOG(writeStreamPtr != NULL);
    
    readStream = NULL;
    writeStream = NULL;
    
    // Create the UNIX domain socket pair.
    
    err = socketpair(AF_UNIX, SOCK_STREAM, 0, fds);
    if (err == 0) 
	{
        CFStreamCreatePairWithSocket(alloc, fds[0], &readStream,  NULL);
        CFStreamCreatePairWithSocket(alloc, fds[1], NULL, &writeStream);
        
        // If we failed to create one of the streams, ignore them both.
        
        if ( (readStream == NULL) || (writeStream == NULL) ) 
		{
            if (readStream != NULL)
			{
                CFRelease(readStream);
                readStream = NULL;
            }
            if (writeStream != NULL) 
			{
                CFRelease(writeStream);
                writeStream = NULL;
            }
        }
        ASSERTLOG( (readStream == NULL) == (writeStream == NULL) );
        
        // Make sure that the sockets get closed (by us in the case of an error, 
        // or by the stream if we managed to create them successfull).
        
        if (readStream == NULL)
		{
            err = close(fds[0]);
            ASSERTLOG(err == 0);
            err = close(fds[1]);
            ASSERTLOG(err == 0);
        } 
		else 
		{
            success = CFReadStreamSetProperty(readStream, kCFStreamPropertyShouldCloseNativeSocket, kCFBooleanTrue);
            ASSERTLOG(success);
            success = CFWriteStreamSetProperty(writeStream, kCFStreamPropertyShouldCloseNativeSocket, kCFBooleanTrue);
            ASSERTLOG(success);
        }
    }
    *readStreamPtr = readStream;
    *writeStreamPtr = writeStream;
}

// ----------------------------------------------------------------------------------------------------------
// A category on NSStream that provides a nice, Objective-C friendly way to create 
// bound pairs of streams.

@interface NSStream (BoundPairAdditions)
+ (void)createBoundInputStream:(NSInputStream **)inputStreamPtr outputStream:(NSOutputStream **)outputStreamPtr bufferSize:(NSUInteger)bufferSize;
@end

@implementation NSStream (BoundPairAdditions)

+ (void)createBoundInputStream:(NSInputStream **)inputStreamPtr outputStream:(NSOutputStream **)outputStreamPtr bufferSize:(NSUInteger)bufferSize
{
    CFReadStreamRef     readStream;
    CFWriteStreamRef    writeStream;

    ASSERTLOG( (inputStreamPtr != NULL) || (outputStreamPtr != NULL) );

    readStream = NULL;
    writeStream = NULL;

    if (YES) 
	{
        CFStreamCreateBoundPairCompat(
            NULL, 
            ((inputStreamPtr  != nil) ? &readStream : NULL),
            ((outputStreamPtr != nil) ? &writeStream : NULL), 
            (CFIndex) bufferSize
        );
    } 
	else
	{
        CFStreamCreateBoundPair(
            NULL, 
            ((inputStreamPtr  != nil) ? &readStream : NULL),
            ((outputStreamPtr != nil) ? &writeStream : NULL), 
            (CFIndex) bufferSize
        );
    }
    
    if (inputStreamPtr != NULL) 
	{
        //*inputStreamPtr  = NSMakeCollectable(readStream);
        *inputStreamPtr  = (__bridge NSInputStream *)(readStream);
    }
    if (outputStreamPtr != NULL) 
	{
        //*outputStreamPtr = NSMakeCollectable(writeStream);
        *outputStreamPtr = (__bridge NSOutputStream *)(writeStream);
    }
}

@end
        
// ----------------------------------------------------------------------------------------------------------
#pragma mark * PostFile

enum {
    kPostBufferSize = 32768
};

// ----------------------------------------------------------------------------------------------------------
@interface DD_AccessPostFile ()

- (void)_startSend:(NSString *)filePath url: (NSURL*) url;
- (void)_stopSendWithStatus:(NSString *)statusString;

// Properties that don't need to be seen by the outside world.

@property (nonatomic, readonly) BOOL              isSending;
@property (nonatomic, strong)   NSURLConnection * connection;
@property (nonatomic, copy)     NSData *          bodyPrefixData;
@property (nonatomic, strong)   NSInputStream *   fileStream;
@property (nonatomic, copy)     NSData *          bodySuffixData;
@property (nonatomic, strong)   NSOutputStream *  producerStream;
@property (nonatomic, strong)   NSInputStream *   consumerStream;
@property (nonatomic, assign)   const uint8_t *   buffer;
@property (nonatomic, assign)   uint8_t *         bufferOnHeap;
@property (nonatomic, assign)   size_t            bufferOffset;
@property (nonatomic, assign)   size_t            bufferLimit;

@end

@implementation DD_AccessPostFile

@synthesize uploadFilePath;
@synthesize partName;

// ----------------------------------------------------------------------------------------------------------
- (void)dealloc
{
    [self _stopSendWithStatus:@"Stopped"];
	
	
	
}

// ----------------------------------------------------------------------------------------------------------
- (void) sendToAccessServer:(NSURL*)theURL
{
	ATRACE2(@"AccessPostFile: sendToAccessServer theURL=%@ ", theURL);
	
	receivedData = [[NSMutableData alloc] initWithLength:0];
	
	[self _startSend: uploadFilePath url: theURL];
}

// ----------------------------------------------------------------------------------------------------------
// Upload to contentUrl
//
- (BOOL) upLoadFile: (NSString*)filePath // remoteSite: (RemoteSite*)remoteSite1
{
	ATRACE(@"AccessPostFile: upLoadFile filePath=%@ ", filePath);
	
	self.uploadFilePath = filePath;
	
	[self sendOp: @"viewupload" ];
	
	return YES;
}

#pragma mark * Status management

// These methods are used by the core transfer code to update the UI.

// ----------------------------------------------------------------------------------------------------------
- (void)_sendDidStart
{
	//[g_ep_app setActivity: YES];
}

// ----------------------------------------------------------------------------------------------------------
- (void)_updateStatus:(NSString *)statusString
{
#if 0
    ASSERTLOG(statusString != nil);
    self.statusLabel.text = statusString;
#endif
}

// ----------------------------------------------------------------------------------------------------------
- (void)_sendDidStopWithStatus:(NSString *)statusString
{
#if 0
    if (statusString == nil) {
        statusString = @"POST succeeded";
    }
    self.statusLabel.text = statusString;
    self.cancelButton.enabled = NO;
    [self.activityIndicator stopAnimating];
    [[AppDelegate sharedAppDelegate] didStopNetworking];
#endif
	//[g_ep_app setActivity: NO]; 
}

#pragma mark * Core transfer code

// This is the code that actually does the networking.

@synthesize connection      = _connection;
@synthesize bodyPrefixData  = _bodyPrefixData;
@synthesize fileStream      = _fileStream;
@synthesize bodySuffixData  = _bodySuffixData;
@synthesize producerStream  = _producerStream;
@synthesize consumerStream  = _consumerStream;
@synthesize buffer          = _buffer;
@synthesize bufferOnHeap    = _bufferOnHeap;
@synthesize bufferOffset    = _bufferOffset;
@synthesize bufferLimit     = _bufferLimit;

// ----------------------------------------------------------------------------------------------------------
- (BOOL)isSending
{
    return (self.connection != nil);
}

// ----------------------------------------------------------------------------------------------------------
- (NSString *)_generateBoundaryString
{
#if 1
    CFUUIDRef       uuid;
    CFStringRef     uuidStr;
    NSString *      result;
    
    uuid = CFUUIDCreate(NULL);
    ASSERTLOG2(uuid != NULL, nil);
    
    uuidStr = CFUUIDCreateString(NULL, uuid);
    ASSERTLOG2(uuidStr != NULL, nil);
    
    result = [NSString stringWithFormat:@"Boundary-%@", uuidStr];
    
    CFRelease(uuidStr);
    CFRelease(uuid);
    
    return result;
#else
	return @"AaB03x";
#endif
}

// ----------------------------------------------------------------------------------------------------------
- (void)_startSend:(NSString *)filePath url: (NSURL*) url
{
	ATRACE(@"AccessPostFile: _startSend filePath=%@ url=%@", filePath, url);
    //BOOL                    success;
    //NSURL *                 url;
    NSMutableURLRequest *   request;
    NSString *              boundaryStr;
    NSString *              contentType;
    NSString *              bodyPrefixStr;
    NSString *              bodySuffixStr;
    NSNumber *              fileLengthNum;
    unsigned long long      bodyLength;
    
    ASSERTLOG(filePath != nil);
    ASSERTLOG([[NSFileManager defaultManager] fileExistsAtPath:filePath]);
    //ASSERTLOG( [filePath.pathExtension isEqual:@"png"] || [filePath.pathExtension isEqual:@"jpg"] );
    
    ASSERTLOG(self.connection == nil);         // don't tap send twice in a row!
    ASSERTLOG(self.bodyPrefixData == nil);     // ditto
    ASSERTLOG(self.fileStream == nil);         // ditto
    ASSERTLOG(self.bodySuffixData == nil);     // ditto
    ASSERTLOG(self.consumerStream == nil);     // ditto
    ASSERTLOG(self.producerStream == nil);     // ditto
    ASSERTLOG(self.buffer == NULL);            // ditto
    ASSERTLOG(self.bufferOnHeap == NULL);      // ditto

	{
        // Determine the MIME type of the file.
        
        if ( [filePath.pathExtension isEqual:@"png"] ) 
		{
            contentType = @"image/png";
        } 
		else if ( [filePath.pathExtension isEqual:@"jpg"] ) 
		{
            contentType = @"image/jpeg";
        } 
		else if ( [filePath.pathExtension isEqual:@"gif"] )
		{
            contentType = @"image/gif";
        } 
		else 
		{
            contentType = @"text/plain";
			// contentType = @"text/plain; charset=UTF-8";
			//contentType = @"application/octet-stream";
        }

        // Calculate the multipart/form-data body.  For more information about the 
        // format of the prefix and suffix, see:
        //
        // o HTML 4.01 Specification
        //   Forms
        //   <http://www.w3.org/TR/html401/interact/forms.html#h-17.13.4>
        //
        // o RFC 2388 "Returning Values from Forms: multipart/form-data"
        //   <http://www.ietf.org/rfc/rfc2388.txt>
        
        boundaryStr = [self _generateBoundaryString];
        ASSERTLOG(boundaryStr != nil);
		
		if (! partName) partName = @"file";

        bodyPrefixStr = [NSString stringWithFormat:
						 @
						 "--%@\r\n"
						 "Content-Disposition: form-data; name=\"%@\"; filename=\"%@\"\r\n"
						 "Content-Type: %@\r\n"
						 "\r\n",
						 boundaryStr,
						 partName,
						 [filePath lastPathComponent],       // +++ very broken for non-ASCII
						 contentType
						 ];


        bodySuffixStr = [NSString stringWithFormat:
						 @
						 "\r\n"
						 "--%@--\r\n" 
						 ,
						 boundaryStr
						 ];
		
        self.bodyPrefixData = [bodyPrefixStr dataUsingEncoding:NSASCIIStringEncoding];
        ASSERTLOG(self.bodyPrefixData != nil);
        self.bodySuffixData = [bodySuffixStr dataUsingEncoding:NSASCIIStringEncoding];
        ASSERTLOG(self.bodySuffixData != nil);

        fileLengthNum = (NSNumber *) [[[NSFileManager defaultManager] attributesOfItemAtPath:filePath error:NULL] objectForKey:NSFileSize];
        ASSERTLOG( [fileLengthNum isKindOfClass:[NSNumber class]] );

        bodyLength =
              (unsigned long long) [self.bodyPrefixData length]
            + [fileLengthNum unsignedLongLongValue]
            + (unsigned long long) [self.bodySuffixData length];
        
        // Open a stream for the file we're going to send.  We open this stream 
        // straight away because there's no need to delay.
        
        self.fileStream = [NSInputStream inputStreamWithFileAtPath:filePath];
        ASSERTLOG(self.fileStream != nil);
        
        [self.fileStream open];
        
        // Open producer/consumer streams.  We open the producerStream straight 
        // away.  We leave the consumerStream alone; NSURLConnection will deal 
        // with it.
        
        // + (void)createBoundInputStream:(NSInputStream **)inputStreamPtr outputStream:(NSOutputStream **)outputStreamPtr bufferSize:(NSUInteger)bufferSize
        NSInputStream *inputStream = nil;
        NSOutputStream *outputStream = nil;
        
        [NSStream createBoundInputStream:&inputStream  outputStream:&outputStream bufferSize:32768];
        
        self->_consumerStream = inputStream;
        self->_producerStream = outputStream;
        
        ASSERTLOG(self.consumerStream != nil);
        ASSERTLOG(self.producerStream != nil);
        
        self.producerStream.delegate = self;
        [self.producerStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        [self.producerStream open];
        
        // Set up our state to send the body prefix first.
        
        self.buffer      = [self.bodyPrefixData bytes];
        self.bufferLimit = [self.bodyPrefixData length];
        
        // Open a connection for the URL, configured to POST the file.

        request = [NSMutableURLRequest requestWithURL:url];
        ASSERTLOG(request != nil);
        
        [request setHTTPMethod:@"POST"];
        [request setHTTPBodyStream:self.consumerStream];

        [request setValue:[NSString stringWithFormat:@"multipart/form-data; boundary=%@", boundaryStr] forHTTPHeaderField:@"Content-Type"];

		[request setValue:[NSString stringWithFormat:@"%llu", bodyLength] forHTTPHeaderField:@"Content-Length"];
		
		[self applyCredentials: request];

		self.connection = [NSURLConnection connectionWithRequest:request delegate:self];
        ASSERTLOG(self.connection != nil);
        
        // Tell the UI we're sending.
		ATRACE2(@"AccessPostFile: _startSend bodyLength=%llu request=%@", bodyLength, request);
		
        [self _sendDidStart];
    }
}

// ----------------------------------------------------------------------------------------------------------
- (void)_stopSendWithStatus:(NSString *)statusString
{
	ATRACE2(@"AccessPostFile: _stopSendWithStatus statusString=%@", statusString);
    if (self.bufferOnHeap) 
	{
        free(self.bufferOnHeap);
        self.bufferOnHeap = NULL;
    }
    self.buffer = NULL;
    self.bufferOffset = 0;
    self.bufferLimit  = 0;
    if (self.connection != nil) 
	{
        [self.connection cancel];
        self.connection = nil;
    }
    self.bodyPrefixData = nil;
    if (self.producerStream != nil)
	{
        self.producerStream.delegate = nil;
        [self.producerStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        [self.producerStream close];
        self.producerStream = nil;
    }
    self.consumerStream = nil;
    if (self.fileStream != nil)
	{
        [self.fileStream close];
        self.fileStream = nil;
    }
    self.bodySuffixData = nil;
    [self _sendDidStopWithStatus:statusString];
}

// ----------------------------------------------------------------------------------------------------------
- (void)stream:(NSStream *)aStream handleEvent:(NSStreamEvent)eventCode
    // An NSStream delegate callback that's called when events happen on our 
    // network stream.
{
 	ATRACE2(@"AccessPostFile: handleEvent aStream=%@ eventCode=%d", aStream, eventCode);
	#pragma unused(aStream)
    ASSERTLOG(aStream == self.producerStream);

    switch (eventCode) 
	{
        case NSStreamEventOpenCompleted: 
		{
            // NSLog(@"producer stream opened");
 			break;
       } 
        case NSStreamEventHasBytesAvailable: 
		{
            ASSERTLOG(NO);     // should never happen for the output stream
			break;
        } 
        case NSStreamEventHasSpaceAvailable: 
		{
            // Check to see if we've run off the end of our buffer.  If we have, 
            // work out the next buffer of data to send.
            
            if (self.bufferOffset == self.bufferLimit) 
			{
                // See if we're transitioning from the prefix to the file data.
                // If so, allocate a file buffer.
                
                if (self.bodyPrefixData != nil) 
				{
                    self.bodyPrefixData = nil;

                    ASSERTLOG(self.bufferOnHeap == NULL);
                    self.bufferOnHeap = malloc(kPostBufferSize);
                    ASSERTLOG(self.bufferOnHeap != NULL);
                    self.buffer = self.bufferOnHeap;
                    
                    self.bufferOffset = 0;
                    self.bufferLimit  = 0;
                }
                
                // If we still have file data to send, read the next chunk. 
                
                if (self.fileStream != nil) 
				{
                    NSInteger   bytesRead;
                    
                    bytesRead = [self.fileStream read:self.bufferOnHeap maxLength:kPostBufferSize];
                    
                    if (bytesRead == -1) 
					{
                        [self _stopSendWithStatus:@"File read error"];
                    }
					else if (bytesRead != 0) 
					{
                        self.bufferOffset = 0;
                        self.bufferLimit  = bytesRead;
                    } 
					else 
					{
                        // If we hit the end of the file, transition to sending the 
                        // suffix.

                        [self.fileStream close];
                        self.fileStream = nil;
                        
                        ASSERTLOG(self.bufferOnHeap != NULL);
                        free(self.bufferOnHeap);
                        self.bufferOnHeap = NULL;
                        self.buffer       = [self.bodySuffixData bytes];

                        self.bufferOffset = 0;
                        self.bufferLimit  = [self.bodySuffixData length];
                    }
                }
                
                // If we've failed to produce any more data, we close the stream 
                // to indicate to NSURLConnection that we're all done.  We only do 
                // this if producerStream is still valid to avoid running it in the 
                // file read error case.
                
                if ( (self.bufferOffset == self.bufferLimit) && (self.producerStream != nil) )
				{
                    // We set our delegate callback to nil because we don't want to 
                    // be called anymore for this stream.  However, we can't 
                    // remove the stream from the runloop (doing so prevents the 
                    // URL from ever completing) and nor can we nil out our 
                    // stream reference (that causes all sorts of wacky crashes). 
                    //
                    // +++ Need bug numbers for these problems.
                    self.producerStream.delegate = nil;
                    // [self.producerStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
                    [self.producerStream close];
                    // self.producerStream = nil;
                }
            }
            
            // Send the next chunk of data in our buffer.
            
            if (self.bufferOffset != self.bufferLimit) 
			{
                NSInteger   bytesWritten;
                bytesWritten = [self.producerStream write:&self.buffer[self.bufferOffset] maxLength:self.bufferLimit - self.bufferOffset];
                if (bytesWritten <= 0) 
				{
                    [self _stopSendWithStatus:@"Network write error"];
                } 
				else 
				{
                    self.bufferOffset += bytesWritten;
                }
            }
			break;
        } 
        case NSStreamEventErrorOccurred: 
		{
            AFLOG(@"producer stream error %@", [aStream streamError]);
            [self _stopSendWithStatus:@"Stream open error"];
			break;
        } 
        case NSStreamEventEndEncountered: 
		{
            ASSERTLOG(NO);     // should never happen for the output stream
			break;
        } 
        default: 
		{
            ASSERTLOG(NO);
			break;
        } 
    }
}

// ----------------------------------------------------------------------------------------------------------
// A delegate method called by the NSURLConnection when the request/response 
// exchange is complete.  We look at the response to check that the HTTP 
// status code is 2xx.  If it isn't, we fail right now.
- (void)connection:(NSURLConnection *)theConnection didReceiveResponse:(NSURLResponse *)response
{
  	ATRACE2(@"AccessPostFile: didReceiveResponse response=%@", response);
	#pragma unused(theConnection)
    NSHTTPURLResponse * httpResponse;

    ASSERTLOG(theConnection == self.connection);
    
    httpResponse = (NSHTTPURLResponse *) response;
    ASSERTLOG( [httpResponse isKindOfClass:[NSHTTPURLResponse class]] );
    
    if ((httpResponse.statusCode / 100) != 2) 
	{
		AFLOG(@"AccessPostFile HTTP error %zd allHeaderFields=%@", (ssize_t) httpResponse.statusCode, [httpResponse allHeaderFields]);
        [self _stopSendWithStatus:[NSString stringWithFormat:@"HTTP error %zd", (ssize_t) httpResponse.statusCode]];
        
#if 1
        // 2012-04-04 jht: Report failure in post upload
        
        NSInteger statusCode = httpResponse.statusCode;
        NSString *message = [NSString stringWithFormat:@"HTTP error %zd", (ssize_t) statusCode];
        
		//if (silentOnMissingFileError && (statusCode == 404 || statusCode == 403))
		//{
		//	missingFile = YES;
		//	[self connectionDidFinishLoading: connection];
		//	// self is now dead
		//}
		//else 
		{
			[delegate access: self accessErr: message appLink: nil];
			// self is now dead
		}
#endif
    } 
	else 
	{
		
		[super connection:nil didReceiveResponse: response];
    }    
}

// ----------------------------------------------------------------------------------------------------------
// A delegate method called by the NSURLConnection as data arrives. 
- (void)connection:(NSURLConnection *)theConnection didReceiveData:(NSData *)data
{
   	ATRACE2(@"AccessPostFile: didReceiveData data length=%d", [data length]);
	#pragma unused(theConnection)
    #pragma unused(data)

    ASSERTLOG(theConnection == self.connection);

	[super connection:nil didReceiveData: data];

	//[delegate access: self did: @"" anyChange: NO ];
}

// ----------------------------------------------------------------------------------------------------------
// A delegate method called by the NSURLConnection if the connection fails. 
// We shut down the connection and display the failure.  Production quality code 
// would either display or log the actual error.
- (void)connection:(NSURLConnection *)theConnection didFailWithError:(NSError *)error
{
	AFLOG(@"AccessPostFile: didReceiveData error=%@", error);
	#pragma unused(theConnection)
    #pragma unused(error)
    ASSERTLOG(theConnection == self.connection);
    
    [self _stopSendWithStatus:@"Connection failed"];
	
	[super connection:nil didFailWithError:error];
	// self is now dead
	
	//[self processResponse: error ];
}

// ----------------------------------------------------------------------------------------------------------
// A delegate method called by the NSURLConnection when the connection has been 
// done successfully.  We shut down the connection with a nil status, which 
// causes the image to be displayed.
- (void)connectionDidFinishLoading:(NSURLConnection *)theConnection
{
	ATRACE2(@"AccessPostFile: connectionDidFinishLoading ");
    #pragma unused(theConnection)
    ASSERTLOG(theConnection == self.connection);
    
    [self _stopSendWithStatus:nil];

	[super connectionDidFinishLoading:nil ];
	// self is now dead

	//[self processResponse: nil ];
}

// ----------------------------------------------------------------------------------------------------------

@end

// ----------------------------------------------------------------------------------------------------------
// ----------------------------------------------------------------------------------------------------------
