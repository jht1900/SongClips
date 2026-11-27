/*

 Copyright (C) 2009 John Henry Thompson.

 2009-08-31 jht Created. Derived from AddMusic example.
*/


#import <UIKit/UIKit.h>

#import "AppDefs.h"
//#import	"Access.h"

@class ClipPlayCtl;
@class FirstStopViewCtl;
@class SongListCtl;

// --------------------------------------------------------------------------------------------------------

//@interface AppDelegate : NSObject <UIApplicationDelegate, AccessDelegate> 
@interface AppDelegate : NSObject <UIApplicationDelegate> 
{
    UIWindow					*window;
	IBOutlet UINavigationController	*navCtl;
	IBOutlet FirstStopViewCtl	*firstStopViewCtl;
	
	ClipPlayCtl		*mainViewController;
	SongListCtl	*songListViewCtl;
	
	NSString						*appName;
	NSString						*appNameVersion;
	int								activityNestedCount;
	
	BOOL							didHandleOpenURL;

	BOOL						ipadMode;

	NSString					*pendingAccessUrlStr;

	BOOL						askForSong;
}

@property (nonatomic, strong) IBOutlet UIWindow				*window;
@property (nonatomic, strong) IBOutlet UINavigationController	*navCtl;
@property (nonatomic, strong) IBOutlet FirstStopViewCtl		*firstStopViewCtl;

@property (nonatomic, strong) ClipPlayCtl		*mainViewController;
@property (nonatomic, strong) SongListCtl	*songListViewCtl;

@property (nonatomic, weak, readonly) NSString	*appName;
@property (nonatomic, weak, readonly) NSString	*appNameVersion;

@property (nonatomic, readonly) BOOL			ipadMode;

@property (nonatomic, strong)	NSString		*pendingAccessUrlStr;

@property (nonatomic, assign) BOOL			askForSong;

+ (AppDelegate*)default;

+ (NSString *) localDir;

- (void)setActivity: (BOOL)newVal;

- (ClipPlayCtl *) fetchClipPlayView;

- (SongListCtl *) fetchSongListView;

- (void) openInBrowser: (NSString *) urlStr;

@end

// --------------------------------------------------------------------------------------------------------

extern AppDelegate *g_appDelegate;

// --------------------------------------------------------------------------------------------------------
// --------------------------------------------------------------------------------------------------------
