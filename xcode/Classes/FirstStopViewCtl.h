//
// 2011-11-21 jht
//
#import <UIKit/UIKit.h>

#import "NoSongViewCtl.h"

@interface FirstStopViewCtl : UIViewController 
{
	NoSongViewCtl	*noSongViewCtl;		// Weak ref
}

- (void) becomeActive;

@end
