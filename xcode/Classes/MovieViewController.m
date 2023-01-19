/*

*/

#import "MovieViewController.h"
#import "AppDelegate.h"


@implementation MovieViewController

#pragma mark Movie Player Routines

// ----------------------------------------------------------------------------------------------------------------
- (void) cleanOut	
{
    // remove movie notifications
	if (mMoviePlayer)
	{
		[[NSNotificationCenter defaultCenter] removeObserver:self
													name:MPMoviePlayerPlaybackDidFinishNotification
                                                  object:mMoviePlayer];
		// free our movie player
	}
	mMoviePlayer = nil;
}

// ----------------------------------------------------------------------------------------------------------------
- (void)dealloc 
{
	ATRACE2(@"MovieViewController: dealloc");

	[self cleanOut];
	
}

// ----------------------------------------------------------------------------------------------------------------
-(void)initMoviePlayerURL: (NSURL*) movieURL
{
	ATRACE2(@"MovieViewController: initMoviePlayerURL movieURL=%@", [movieURL description]);

    mMoviePlayer = [[MPMoviePlayerController alloc] initWithContentURL: movieURL ];
    
    // Register to receive a notification when the movie has finished playing. 
    [[NSNotificationCenter defaultCenter] addObserver:self 
											 selector:@selector(moviePlayBackDidFinish:) 
												 name:MPMoviePlayerPlaybackDidFinishNotification 
											   object:mMoviePlayer];
	
}

// ----------------------------------------------------------------------------------------------------------------
-(void)initMoviePlayer: (NSString*) filePath
{
	ATRACE2(@"MovieViewController: initMoviePlayer filePath=%@", filePath);

	NSURL* movieURL = [NSURL fileURLWithPath: filePath isDirectory: NO] ;

	[self initMoviePlayerURL: movieURL];
}

// ----------------------------------------------------------------------------------------------------------------
//  Notification called when the movie finished preloading.
 - (void) moviePreloadDidFinish:(NSNotification*)notification
 {
	 ATRACE2(@"MovieViewController: moviePreloadDidFinish");
 }

// ----------------------------------------------------------------------------------------------------------------
//  Notification called when the movie finished playing.
- (void) moviePlayBackDidFinish:(NSNotification*)notification
{
	ATRACE2(@"MovieViewController: moviePlayBackDidFinish retainCount=%d", [self retainCount]);

	//[self dealloc];
	[self cleanOut];
}

// ----------------------------------------------------------------------------------------------------------------
//  Notification called when the movie scaling mode has changed.
- (void) movieScalingModeDidChange:(NSNotification*)notification
{
	ATRACE2(@"MovieViewController: movieScalingModeDidChange");
    /* 
    */
}

// ----------------------------------------------------------------------------------------------------------------
- (void)playMovie
{
    [mMoviePlayer play];
}

// ----------------------------------------------------------------------------------------------------------------
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation 
{
    // Return YES for supported orientations
    return YES;
	//return NO;
}

// ----------------------------------------------------------------------------------------------------------------
- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning]; // Releases the view if it doesn't have a superview
    // Low on memory: Release anything that's not essential, such as cached data, or perhaps 
    // unload the movie, etc.
}

// ----------------------------------------------------------------------------------------------------------------
// ----------------------------------------------------------------------------------------------------------------

@end
