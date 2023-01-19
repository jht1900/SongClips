//

#import "NoSongViewCtl.h"
#import "ClipPlayCtl.h"
#import "AppDelegate.h"
#import "Song.h"

@implementation NoSongViewCtl


#pragma mark - View lifecycle

// --------------------------------------------------------------------------------------------------------
- (void)viewDidLoad
{
    [super viewDidLoad];
	
	ATRACE(@"NoSongViewCtl viewDidLoad");
}

// --------------------------------------------------------------------------------------------------------
- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];

	ATRACE(@"NoSongViewCtl viewDidDisappear");
}

// --------------------------------------------------------------------------------------------------------
- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;

	ATRACE(@"NoSongViewCtl viewDidUnload");
}

// --------------------------------------------------------------------------------------------------------
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

// --------------------------------------------------------------------------------------------------------
#pragma mark Actions
- (IBAction) selectSongAction:(id)sender
{
    ATRACE(@"NoSongViewCtl selectSongAction");
    
    g_appDelegate.askForSong = YES;
    
    //[self dismissModalViewControllerAnimated:YES];
    [self dismissViewControllerAnimated:YES completion:nil];

//    // !!@ 2023 temp
//    [self dismissViewControllerAnimated:YES completion:nil];
}

- (IBAction) learnMoreAction:(id)sender
{
	ATRACE(@"NoSongViewCtl learnMoreAction");
	
	[g_appDelegate openInBrowser: kSongClipsWebSite];
}

// --------------------------------------------------------------------------------------------------------
// --------------------------------------------------------------------------------------------------------

@end
