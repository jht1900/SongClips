//

#import "FirstStopViewCtl.h"
#import "ClipPlayCtl.h"
#import "AppDelegate.h"
#import "Song.h"
#import "SongList.h"
#import "NoSongViewCtl.h"

@implementation FirstStopViewCtl


#pragma mark - View lifecycle

// --------------------------------------------------------------------------------------------------------
- (void)viewDidLoad
{
    [super viewDidLoad];
	
	ATRACE(@"FirstStopViewCtl viewDidLoad");
}

// --------------------------------------------------------------------------------------------------------
- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];

	ATRACE(@"FirstStopViewCtl viewDidDisappear");
}

// --------------------------------------------------------------------------------------------------------
- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;

	ATRACE(@"FirstStopViewCtl viewDidUnload");
}

// --------------------------------------------------------------------------------------------------------
- (void)viewWillAppear:(BOOL)animated
{
	ATRACE(@"FirstStopViewCtl viewWillAppear");
	
	[super viewWillAppear: animated];
}

// --------------------------------------------------------------------------------------------------------
- (void) viewDidAppear: (BOOL)animated
{
	ATRACE(@"FirstStopViewCtl viewDidAppear g_appDelegate.pendingAccessUrlStr=%@", g_appDelegate.pendingAccessUrlStr);
	
	[super viewDidAppear: animated];
	
	noSongViewCtl = nil;
	
	if (g_appDelegate.pendingAccessUrlStr)
	{
		SongListCtl *ctl = [g_appDelegate fetchSongListView];
		
		ATRACE(@"FirstStopViewCtl pendingAccessUrlStr BEFORE pushViewController SongListCtl ctl=%@", ctl);

		ATRACE(@"FirstStopViewCtl pendingAccessUrlStr BEFORE navigationController topViewController =%@", [self navigationController].topViewController);
		
		if ([self navigationController].topViewController != ctl ) {
			[[self navigationController] pushViewController:ctl animated:YES];
		}
		else {
			ATRACE(@"FirstStopViewCtl pendingAccessUrlStr NOT pushViewController ");
		}
		return;
	}
    
    // !!@ 2023 temp
//	if (g_appDelegate.askForSong)
	{
		g_appDelegate.askForSong = NO;
		
		SongListCtl *ctl = [[SongListCtl alloc] initWithNibName: @"SongListView" bundle: nil];

		ATRACE(@"FirstStopViewCtl askForSong SongListCtl ctl=%@", ctl);

		// !!@ Disable auto show of picker on launch
		// ctl.doAdd = YES;
		
		[[self navigationController] pushViewController:ctl animated:YES];
		
		return;
	}
	
	Song *song = [[SongList default] currentSong];
	if (! song)
	{
		NoSongViewCtl *ctl = [[NoSongViewCtl alloc] initWithNibName: @"NoSongViewCtl" bundle: nil];
				
		//[self presentModalViewController: ctl animated: YES];
        [self presentViewController:ctl animated:YES completion:nil];
		
		
		noSongViewCtl = ctl;
	}
	else
	{
		SongListCtl *ctl = [g_appDelegate fetchSongListView];

		ATRACE(@"FirstStopViewCtl Last BEFORE pushViewController SongListCtl ctl=%@", ctl);

		[[self navigationController] pushViewController:ctl animated:YES];
	}
}

// --------------------------------------------------------------------------------------------------------
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

// --------------------------------------------------------------------------------------------------------
- (void) becomeActive
{
	ATRACE(@"FirstStopViewCtl becomeActive g_appDelegate.pendingAccessUrlStr=%@ noSongViewCtl=%@", g_appDelegate.pendingAccessUrlStr, noSongViewCtl);

	// Only do re-focus on song list view if pending clips from url
	//
	if (! g_appDelegate.pendingAccessUrlStr)
		return;
	
	UIViewController *modalView = [self modalViewController];
	if (modalView) {
		ATRACE(@"FirstStopViewCtl becomeActive dismissModal modalView=%@", modalView);
		//[modalView dismissModalViewControllerAnimated: NO];
        [modalView dismissViewControllerAnimated:YES completion:nil];
		return;
	}
	
	// Kick off song list view if already on top 'cause popping and pushing it will not trigger events.
	//
	if ([[self navigationController] topViewController] == g_appDelegate.songListViewCtl)
	{
		[g_appDelegate.songListViewCtl becomeActive];
		return;
	}
	
	// Make sure we are on top
	//
	UIViewController	*aView;
	while (self != (aView = [[self navigationController] topViewController]) ) 
	{
		ATRACE(@"FirstStopViewCtl becomeActive popping top=%@", aView);
		
		modalView = [aView modalViewController];
		if (modalView) {
			ATRACE(@"FirstStopViewCtl becomeActive dismissModal modalView=%@", modalView);
			//[modalView dismissModalViewControllerAnimated: NO];
            [modalView dismissViewControllerAnimated:YES completion:nil];
		}
		[[self navigationController] popViewControllerAnimated:NO];
	}

	SongListCtl *ctl = [g_appDelegate fetchSongListView];

	ATRACE(@"FirstStopViewCtl becomeActive pushing ctl=%@", ctl);

	[[self navigationController] pushViewController:ctl animated:YES];
	
	return;
}

// --------------------------------------------------------------------------------------------------------
// --------------------------------------------------------------------------------------------------------

@end
