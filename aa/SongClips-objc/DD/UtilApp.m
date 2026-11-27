/*
 Copyright (C) 2008 John Henry Thompson. All Rights Reserved.
 */

#import "UtilApp.h"
#import "DD_AppDefs.h"

static int activityNestedCount = 0;
static int lockScreenNestedCount = 0;

// ----------------------------------------------------------------------------------------------------------
// YES to turn on busy indicator, allow for nesting.
void setActivity (BOOL newVal)
{
	ATRACE2(@"UtilApp.h: setActivity newVal=%d activityNestedCount=%d", newVal, activityNestedCount);
	
	if (newVal) {
		activityNestedCount++;
		if (activityNestedCount >= 1) {
			[UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
		}
	}
	else {
		activityNestedCount--;
		if (activityNestedCount <= 0) {
			[UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
		}
	}
}

// ----------------------------------------------------------------------------------------------------------
// YES to disable screen locking (sleep), allow for nesting.
void disableScreenLock (BOOL newVal)
{
	ATRACE2(@"UtilApp.h: disableScreenLock newVal=%d", newVal);
	if (newVal) {
		lockScreenNestedCount++;
		if (lockScreenNestedCount >= 1) {
			ATRACE2(@" idleTimerDisabled = YES lockScreenNestedCount=%d", lockScreenNestedCount);
			[UIApplication sharedApplication].idleTimerDisabled = YES;
		}
	}
	else {
		lockScreenNestedCount--;
		if (lockScreenNestedCount <= 0) {
			ATRACE2(@" idleTimerDisabled = NO lockScreenNestedCount=%d", lockScreenNestedCount);
			[UIApplication sharedApplication].idleTimerDisabled = NO;
		}
	}
}

// ----------------------------------------------------------------------------------------------------------
void show_alert(NSString* msg, NSString* title)
{
	ATRACE(@"UtilApp.h: show_alert msg=%@ title=%@",msg,title);
	UIAlertView *alert =
	[[UIAlertView alloc] initWithTitle:title
							   message:msg
							  delegate:nil
					 cancelButtonTitle:@"OK"
					 otherButtonTitles:nil];
	[alert show];
}

// ----------------------------------------------------------------------------------------------------------
void show_alert_error(NSString *format, ... )
{
	va_list arguments;
	
	va_start(arguments, format);
	
	NSString *msg = (NSString*)CFBridgingRelease(CFStringCreateWithFormatAndArguments(kCFAllocatorDefault,NULL,(CFStringRef)format, arguments));
	
	show_alert( msg, @"Error@!");
	
	va_end(arguments);
}

// ----------------------------------------------------------------------------------------------------------
// ----------------------------------------------------------------------------------------------------------
