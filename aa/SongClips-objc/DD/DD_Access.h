/*
 Copyright (C) 2008 John Henry Thompson. All Rights Reserved.
 */

#import <Foundation/Foundation.h>

@class DD_RemoteSite;

@protocol DD_AccessDelegate;

@interface DD_Access : NSObject <NSURLConnectionDelegate>
{		
	NSMutableData		*receivedData;
	
	double					downloadStart;
}

@property (nonatomic, unsafe_unretained) id <DD_AccessDelegate> delegate;

@property (nonatomic, strong) DD_RemoteSite		*remoteSite;

@property (nonatomic, assign) BOOL			silentOnMissingFileError;
@property (nonatomic, assign) BOOL			missingFile;

- (void) sendUrlStr: (NSString*)urlStr;

@end

// --------------------------------------------------------------------------------------------------------

@protocol DD_AccessDelegate <NSObject>

- (void) access:(DD_Access*)access accessErr:(NSString*)errMsg ;

- (void) access:(DD_Access*)access done:(NSData*)result;

@end

// --------------------------------------------------------------------------------------------------------
// --------------------------------------------------------------------------------------------------------
