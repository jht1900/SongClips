/*
 Copyright (C) 2008 John Henry Thompson. All Rights Reserved.
 */

#import <UIKit/UIKit.h>
#import "Access.h"

@class Song;

@interface Clip : NSObject <AccessDelegate>
{
//@public
//	Song			*__weak song;
//	NSMutableArray	*texts;
//	NSString		*notation;
//	NSTimeInterval	subDuration;
//	NSTimeInterval	startTime;
//	NSString		*recordingFileName;
//	NSTimeInterval	recordingDuration;
//	NSString		*imageFileName;
//	NSString		*imageRef;
//	NSString		*linkRef;
//	NSString        *webRef;
	
	Access			*access;
}

@property (nonatomic, weak) Song					*song;
@property (nonatomic, strong) NSMutableArray		*texts;
@property (nonatomic, strong) NSString				*notation;
@property (nonatomic, strong) NSString				*recordingFileName;
@property (nonatomic, strong) NSString				*imageFileName;
@property (nonatomic, strong) NSString				*imageRef;
@property (nonatomic, strong) NSString				*linkRef;
@property (nonatomic, strong) NSString				*webRef;
@property (nonatomic, assign) NSTimeInterval		recordingDuration;
@property (nonatomic, assign) NSTimeInterval		subDuration;
@property (nonatomic, assign) NSTimeInterval		startTime;
@property (nonatomic, assign) double				clip_rate;


@property (weak, nonatomic, readonly) UIImage				*image;
@property (weak, nonatomic, readonly) UIImage				*imageIcon;

- (void) removeMediaFiles;

- (void) saveNewImage: (UIImage*) newImage;

- (UIImage*) imageIcon;

- (UIImage*) image;

- (NSDictionary *) asDict;

- (void) initFromDict: (NSDictionary *) dict;

@end

// --------------------------------------------------------------------------------------------------------
// --------------------------------------------------------------------------------------------------------
