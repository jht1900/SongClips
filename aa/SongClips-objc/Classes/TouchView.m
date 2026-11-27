/*
 
 */

#import "TouchView.h"
#import "AppDelegate.h"
#import	"ClipPlayCtl.h"

#if 0
@interface TouchView()
// Private Methods
-(void)animateFirstTouchAtPoint:(CGPoint)touchPoint forView:(UIImageView *)theView;
@end
#endif

// --------------------------------------------------------------------------------------------------------
@implementation TouchView

@synthesize mainViewCtl;

// --------------------------------------------------------------------------------------------------------
// Releases necessary resources. 

// --------------------------------------------------------------------------------------------------------
#pragma mark === Touch handling  ===

// Handles the start of a touch
-(void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
	NSUInteger numTaps = [[touches anyObject] tapCount];
	(void) numTaps;
	ATRACE2(@"TouchView: touchesBegan numTaps=%lu count=%lu", (unsigned long)numTaps, (unsigned long)[touches count]);
	
//	NSUInteger touchCount = 0;
//	for (UITouch *touch in touches) {
//		// Send to the dispatch method, which will make sure the appropriate subview is acted upon
//		//[self dispatchFirstTouchAtPoint:[touch locationInView:self] forEvent:nil];
//		touchCount++;  
//	}	
}

#if 0
// Checks to see which view, or views, the point is in and then calls a method to perform the opening animation,
// which  makes the piece slightly larger, as if it is being picked up by the user.
-(void)dispatchFirstTouchAtPoint:(CGPoint)touchPoint forEvent:(UIEvent *)event
{
	if (CGRectContainsPoint([firstPieceView frame], touchPoint)) {
		[self animateFirstTouchAtPoint:touchPoint forView:firstPieceView];
	}	
}
#endif

// --------------------------------------------------------------------------------------------------------
// Handles the continuation of a touch.
-(void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{  
	ATRACE(@"TouchView: touchesMoved count=%lu", (unsigned long)[touches count]);
	
//	NSUInteger touchCount = 0;
//	// Enumerates through all touch objects
//	for (UITouch *touch in touches) {
//		// Send to the dispatch method, which will make sure the appropriate subview is acted upon
//		//[self dispatchTouchEvent:[touch view] toPosition:[touch locationInView:self]];
//		touchCount++;
//	}
}

#if 0
// Checks to see which view, or views, the point is in and then sets the center of each moved view to the new postion.
// If views are directly on top of each other, they move together.
-(void)dispatchTouchEvent:(UIView *)theView toPosition:(CGPoint)position
{
	// Check to see which view, or views,  the point is in and then move to that position.
	if (CGRectContainsPoint([firstPieceView frame], position)) {
		firstPieceView.center = position;
	} 
}
#endif

// --------------------------------------------------------------------------------------------------------
// Handles the end of a touch event.
-(void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
	ATRACE2(@"TouchView: touchesEnded count=%lu", (unsigned long)[touches count]);
	
	// Enumerates through all touch object
//	for (UITouch *touch in touches) {
//		// Sends to the dispatch method, which will make sure the appropriate subview is acted upon
//		// [self dispatchTouchEndEvent:[touch view] toPosition:[touch locationInView:self]];
//	}
	
	[mainViewCtl clickImageAction: nil];
}

#if 0
// --------------------------------------------------------------------------------------------------------
// Checks to see which view, or views,  the point is in and then calls a method to perform the closing animation,
// which is to return the piece to its original size, as if it is being put down by the user.
-(void)dispatchTouchEndEvent:(UIView *)theView toPosition:(CGPoint)position
{   
	// Check to see which view, or views,  the point is in and then animate to that position.
	if (CGRectContainsPoint([firstPieceView frame], position)) {
		[self animateView:firstPieceView toPosition: position];
	} 
	// If one piece obscures another, display a message so the user can move the pieces apart
	if 	(CGPointEqualToPoint(secondPieceView.center, thirdPieceView.center)) {
		touchInstructionsText.text = @"Double tap the background to move the pieces apart.";
		piecesOnTop = YES;
	} else {
		piecesOnTop = NO;
	}
}
#endif

// --------------------------------------------------------------------------------------------------------
-(void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
	ATRACE2(@"TouchView: touchesCancelled count=%lu", (unsigned long)[touches count]);

	// Enumerates through all touch object
//	for (UITouch *touch in touches) {
//		// Sends to the dispatch method, which will make sure the appropriate subview is acted upon
//		//[self dispatchTouchEndEvent:[touch view] toPosition:[touch locationInView:self]];
//	}
}


@end

// --------------------------------------------------------------------------------------------------------
// --------------------------------------------------------------------------------------------------------

