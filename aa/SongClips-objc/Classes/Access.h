/*
 
 */

#import <Foundation/Foundation.h>

@protocol AccessDelegate;

@interface Access : NSObject
{
	id <AccessDelegate> __weak delegate;

	NSURL			*theURL;
	NSMutableData	*receivedData;
	NSString		*accessUrl;
}

@property (nonatomic, weak) id <AccessDelegate> delegate;
//@property (nonatomic, retain) NSString *accessUrl;

-(void)sendOp: (NSString*)urlStr;

@end

// --------------------------------------------------------------------------------------------------------

@protocol AccessDelegate <NSObject>

- (void) access:(Access*)access err:(NSString*)errMsg;

- (void) access:(Access*)access done:(NSData*)result;

@end

