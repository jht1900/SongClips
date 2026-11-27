//

#import "MissingViewCtl.h"
#import "ClipPlayCtl.h"
#import "AppDelegate.h"
#import "Song.h"

@implementation MissingViewCtl

@synthesize songLabel;
@synthesize albumLabel;
@synthesize artistLabel;

// --------------------------------------------------------------------------------------------------------

#if 0
// --------------------------------------------------------------------------------------------------------
- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

// --------------------------------------------------------------------------------------------------------
- (void)didReceiveMemoryWarning
{
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

#endif

#pragma mark - View lifecycle

// --------------------------------------------------------------------------------------------------------
- (void)viewDidLoad
{
    [super viewDidLoad];
	
	Song	*song = g_appDelegate.mainViewController.currentSong;
	
	songLabel.text = song.title;
	
	albumLabel.text = song.albumTitle;
	
	artistLabel.text = song.artist;
}

// --------------------------------------------------------------------------------------------------------
- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
}

// --------------------------------------------------------------------------------------------------------
- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

// --------------------------------------------------------------------------------------------------------
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

// --------------------------------------------------------------------------------------------------------
#pragma mark Actions
- (IBAction)doneTapped:(id)sender 
{
    //[self dismissModalViewControllerAnimated:YES];
    [self dismissViewControllerAnimated:YES completion:nil];
}

// --------------------------------------------------------------------------------------------------------
- (IBAction)searchAction:(id)sender
{
    //[self dismissModalViewControllerAnimated:YES];
    [self dismissViewControllerAnimated:YES completion:nil];

	Song	*song = g_appDelegate.mainViewController.currentSong;
	
	if (song.sourceRef)
	{
		[g_appDelegate openInBrowser: song.sourceRef];
	}
}

// --------------------------------------------------------------------------------------------------------
- (IBAction)continueAction:(id)sender
{
    //[self dismissModalViewControllerAnimated:YES];
    [self dismissViewControllerAnimated:YES completion:nil];
	
}

// --------------------------------------------------------------------------------------------------------
- (IBAction)selectOtherAction:(id)sender
{
    //[self dismissModalViewControllerAnimated:YES];
    [self dismissViewControllerAnimated:YES completion:nil];
	
	g_appDelegate.mainViewController.selectReplacementForCurrentSongPending = YES;
}

// --------------------------------------------------------------------------------------------------------
// --------------------------------------------------------------------------------------------------------

@end
