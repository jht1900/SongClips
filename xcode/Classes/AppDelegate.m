/*

 Copyright (C) 2009 John Henry Thompson.
 2009-08-31 jht	Created. Derived from AddMusic example.

*/


#import "AppDelegate.h"
#import "ClipPlayCtl.h"
#import "SongList.h"
#import "AppUtil.h"
#import "FirstStopViewCtl.h"
#import "SongListCtl.h"
#import "UtilPath.h"

@implementation AppDelegate

@synthesize window;
@synthesize	navCtl;

@synthesize firstStopViewCtl;

@synthesize	mainViewController;
@synthesize songListViewCtl;

@synthesize ipadMode;

@synthesize pendingAccessUrlStr;

@synthesize askForSong;

AppDelegate *g_appDelegate;

// ----------------------------------------------------------------------------------------------------------
- (id)init
{
	// for encode/decode
	//srandom( (long) [[NSDate date] timeIntervalSinceReferenceDate] );
	if ((self = [super init])) {
		ipadMode = UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad;
	}
	g_appDelegate = self;
	return self;
}

// ----------------------------------------------------------------------------------------------------------
- (void) applicationDidFinishLaunching: (UIApplication *) application 
{
	//[window addSubview: navCtl.view];
	ATRACE(@"AppDelegate: applicationDidFinishLaunching mainScreen].bounds=%@", NSStringFromCGRect([UIScreen mainScreen].bounds));
    
    window.frame = [UIScreen mainScreen].bounds;
	        
    [self.window setRootViewController:navCtl];

    [window makeKeyAndVisible];

	self.navCtl.navigationBar.barStyle = UIBarStyleBlack;
	
	self.navCtl.navigationBar.translucent = NO;

	[SongList resumeFromDisk];

	didHandleOpenURL = NO;
	// Schedule -delayedStart on the next cycle of the event loop to give the 
    // application:handleOpenURL: delegate method an opportunity to handle an incoming URL.
    [self performSelector:@selector(delayedStart) withObject:nil afterDelay:0.0];
}

// ----------------------------------------------------------------------------------------------------------
- (void)applicationDidBecomeActive:(UIApplication *)application
{
	ATRACE(@"AppDelegate: applicationDidBecomeActive firstStopViewCtl=%@", firstStopViewCtl);
    
    //[[SongList default] becomeActive];

	[firstStopViewCtl becomeActive];
}

// ----------------------------------------------------------------------------------------------------------
- (void)applicationWillResignActive:(UIApplication *)application
{
	ATRACE(@"AppDelegate: applicationWillResignActive");
    
    //[[SongList default] willResignActive];
}

// ----------------------------------------------------------------------------------------------------------
- (void)applicationWillTerminate:(UIApplication *)application
{
	ATRACE(@"AppDelegate: applicationWillTerminate");
}

// ----------------------------------------------------------------------------------------------------------
- (void)applicationDidReceiveMemoryWarning:(UIApplication *)application
{
	// low on memory: do whatever you can to reduce your memory foot print here
	ATRACE(@"AppDelegate: MEMORY WARNING");
}

// ----------------------------------------------------------------------------------------------------------
- (void)applicationDidEnterBackground:(UIApplication *)application
{
	ATRACE(@"AppDelegate: applicationDidEnterBackground");
	
	[[SongList default] currentSong].mediaMissingShown = NO;
}

// ----------------------------------------------------------------------------------------------------------
- (void)applicationWillEnterForeground:(UIApplication *)application
{	
	ATRACE(@"AppDelegate: applicationWillEnterForeground");
}

// ----------------------------------------------------------------------------------------------------------
- (BOOL)application:(UIApplication *)application handleOpenURL:(NSURL *)url
{
	ATRACE(@"AppDelegate: handleOpenURL url=%@ mainViewController=%@", url, mainViewController);
	didHandleOpenURL = YES;
	
	NSString* urlStr = [url absoluteString];
	
	// Strip of scheme
	if ([urlStr hasPrefix: kOurScheme])
		urlStr = [urlStr substringFromIndex: [kOurScheme length]];
	else if ([urlStr hasPrefix: kOurScheme2])
		urlStr = [urlStr substringFromIndex: [kOurScheme2 length]];
	
	self.pendingAccessUrlStr = urlStr;
	
	return YES; // We serviced the url
}

// ----------------------------------------------------------------------------------------------------------
- (void)delayedStart
{
	ATRACE(@"AppDelegate: delayedStart didHandleOpenURL=%d", didHandleOpenURL);
	if (! didHandleOpenURL) {
		//[self readAppSettings];
	}
}

// ----------------------------------------------------------------------------------------------------------
+ (NSString *) localDir
{
	return localStoreRoot();
}

// ----------------------------------------------------------------------------------------------------------
+ (AppDelegate*) default
{
	return (AppDelegate *)[[UIApplication sharedApplication] delegate];
}

// ----------------------------------------------------------------------------------------------------------
- (NSDictionary *)appInfo
{
	return  [[NSBundle mainBundle] infoDictionary];
}

// ----------------------------------------------------------------------------------------------------------
- (NSString *)appName
{
	if (! appName) {
		appName = [[self appInfo] objectForKey: @"CFBundleName"];
	}
	return appName;
}

// ----------------------------------------------------------------------------------------------------------
- (NSString *)appNameVersion
{
	if (! appNameVersion) {
		appNameVersion = [NSString stringWithFormat:@"%@ %@", 
                   [[self appInfo] objectForKey: @"CFBundleName"], 
                   [[self appInfo] objectForKey: @"CFBundleVersion"]];
	}
	return appNameVersion;
}

// ----------------------------------------------------------------------------------------------------------
// YES to turn on busy indicator, allow for nesting.
- (void)setActivity: (BOOL)newVal
{
	ATRACE(@"AppDelegate setActivity: newVal=%d activityNestedCount=%d", newVal, activityNestedCount);
	if (newVal) {
		activityNestedCount++;
		if (activityNestedCount >= 1)
		{
			[UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
		}
	}
	else {
		activityNestedCount--;
		if (activityNestedCount <= 0)
		{
			[UIApplication sharedApplication].networkActivityIndicatorVisible = NO;		
		}
	}
}

// ----------------------------------------------------------------------------------------------------------
- (ClipPlayCtl *) fetchClipPlayView
{
	ClipPlayCtl *ctl = self.mainViewController;
	if (! ctl) {
		NSString *nibName = g_appDelegate.ipadMode? @"ClipPlayCtl-iPad": @"ClipPlayCtl";
		
		ctl = [[ClipPlayCtl alloc] initWithNibName:nibName bundle: nil];
		
		self.mainViewController = ctl;
	}
	
	ctl.checkSongMissingMediaPending = YES;
	
	return ctl;
}

// ----------------------------------------------------------------------------------------------------------
- (SongListCtl *) fetchSongListView
{
	//SongListCtl *ctl = self.songListViewCtl;
	SongListCtl *ctl = nil; // SongListCtl is always created to avoid pushing same instance on stack twice
	if (! ctl) {
		ctl = [[SongListCtl alloc] initWithNibName: @"SongListView" bundle: nil];
		
		self.songListViewCtl = ctl;
	}
	return ctl;
}

// ----------------------------------------------------------------------------------------------------------
- (void) openInBrowser: (NSString *) urlStr
{
	if (! urlStr) {
		ATRACE(@"AppDelegate: null urlStr=%@ ", urlStr);
		return;
	}
	NSURL *url = [NSURL URLWithString: urlStr];
	if (url) {
		[[UIApplication sharedApplication] openURL:url];
	}
	else {
		ATRACE(@"MainViewCtl: webRef FAILED urlStr=%@ ", urlStr);
	}
}


// ----------------------------------------------------------------------------------------------------------
// ----------------------------------------------------------------------------------------------------------

@end
