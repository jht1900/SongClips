/*

*/

#import "ClipListCtl.h"
#import "ClipCell.h"
#import "ClipEditCtl.h"
#import "AppDefs.h"
#import "AppUtil.h"
#import "TitleView.h"
#import "AppDelegate.h"
#import "InfoViewCtl.h"
#import "AppDelegate.h"
#import "ClipPlayCtl.h"

#define	kSongViewUpdateInterval		(1.0)

@implementation ClipListCtl

static NSString *kCellIdentifier = @"ClipCell";

@synthesize song;				
@synthesize titleView;				

// --------------------------------------------------------------------------------------------------------

// ----------------------------------------------------------------------------------------------------------
// user clicked the "i" button
- (IBAction)infoAction:(id)sender
{
	InfoViewCtl *controller = [[InfoViewCtl alloc] initWithNibName: @"InfoView" bundle: nil];
	
	[[self navigationController] pushViewController:controller animated:YES];
	
	controller.title = [[AppDelegate default] appNameVersion];
	
}

// --------------------------------------------------------------------------------------------------------
// Configures the table view.
- (void) viewDidLoad 
{
    [super viewDidLoad];
	
	songList = [SongList default];
	
	// Obtain a UIButton object and set its background to the UIImage object
	UIButton *buttonView = [[UIButton alloc] initWithFrame: CGRectMake (0, 0, 40, 40)];
	[buttonView setBackgroundImage: [UIImage imageNamed:@"back_arrow.png"] forState: UIControlStateNormal];
	UIBarButtonItem *backButton = [[UIBarButtonItem alloc] initWithCustomView: buttonView];
	[buttonView addTarget:self action:@selector(actionBack:) forControlEvents:UIControlEventTouchUpInside];
    // !!@ 2023 ClipListCtl navigationItem.leftBarButtonItem
    // disabled to show standard left arrow rather than disstorted back arrow image
//	self.navigationItem.leftBarButtonItem = backButton;

	self.titleView = [TitleView alloc];
    NSString *nibName = g_appDelegate.ipadMode? @"TitleView-iPad" : @"TitleView";
	[[NSBundle mainBundle] loadNibNamed:nibName owner:titleView options:nil];
	titleView = [titleView initWithFrame: CGRectMake(0, 0, g_appDelegate.ipadMode? 700 : 300, 40)];
	self.navigationItem.titleView = titleView;
	ATRACE2(@"SongViewCtl: titleView=%@", titleView);

	UIButton* settingsViewButton = [UIButton buttonWithType:UIButtonTypeInfoLight];
	[settingsViewButton addTarget:self action:@selector(infoAction:) forControlEvents:UIControlEventTouchUpInside];
	UIBarButtonItem *infoButton = [[UIBarButtonItem alloc] initWithCustomView:settingsViewButton];
	self.navigationItem.rightBarButtonItem = infoButton;

#if 0
#if APP_LITE | APP_GALLERY
#else
	UIBarButtonItem *customEditButton =	[[[UIBarButtonItem alloc] initWithTitle: @"Edit"
																			style: UIBarButtonItemStylePlain 
																		   target: self 
																		   action: @selector(actionEdit:)] autorelease];	
	
	self.navigationItem.rightBarButtonItem = customEditButton;
#endif
#endif
}

// ----------------------------------------------------------------------------------------------------------
- (void)actionBack: (id)sender
{
	ATRACE(@"SongViewCtl actionBack currentClipIndex=%d", [songList currentClipIndex] );
	
	[[self navigationController] popViewControllerAnimated: YES];
}

// ----------------------------------------------------------------------------------------------------------
- (void) showClipEditorForClipIndex: (int) index
{
#if APP_LITE | APP_GALLERY
#else
	NSString *nibName = (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) ? @"ClipEditCtl-iPad" : @"ClipEditCtl";
	
	ClipEditCtl *ctl = [[ClipEditCtl alloc] initWithNibName: nibName bundle: nil];
	
	ctl.clipIndex = index;
	ctl.song = song;
	ctl.flowToClip = ([songList currentClipIndex] == index);
	[[self navigationController] pushViewController:ctl animated:YES];
	
#endif
}

// ----------------------------------------------------------------------------------------------------------
- (void)actionEdit: (id)sender
{
	ATRACE(@"SongViewCtl actionEdit currentClipIndex=%d", [songList currentClipIndex] );
	
	[self showClipEditorForClipIndex: [songList currentClipIndex] ];
}

// --------------------------------------------------------------------------------------------------------
- (void)viewWillAppear:(BOOL)animated
{
	ATRACE2(@"SongViewCtl viewWillAppear");

	[super viewWillAppear: animated];
	
	[self.tableView reloadData];

	songList.delegate = self;

	currentClipIndex = [song clipIndexForTime: [songList currentTime] ];
	NSIndexPath *indexPath = [NSIndexPath indexPathForRow: currentClipIndex inSection: 0];
	[self.tableView scrollToRowAtIndexPath: indexPath atScrollPosition:UITableViewScrollPositionMiddle animated: animated];

	self.titleView.fTop.text = song.label;
	self.titleView.fBottom.text = [NSString stringWithFormat: @"%d Clips", [song clipCount]];
}

// --------------------------------------------------------------------------------------------------------
- (void) viewDidAppear:(BOOL)animated
{
	ATRACE2(@"SongViewCtl viewDidAppear");
    
    [super viewDidAppear: animated];
    
    if (g_appDelegate.mainViewController.selectReplacementForCurrentSongPending)
    {
        [[self navigationController] popViewControllerAnimated: YES];
    }
}

// --------------------------------------------------------------------------------------------------------
- (void) viewWillDisappear:(BOOL)animated
{
	[super viewWillDisappear: animated];
	
	songList.delegate = nil;
}

// --------------------------------------------------------------------------------------------------------
#pragma mark Table view methods________________________

// To learn about using table views, see the TableViewSuite sample code  
//		and Table View Programming Guide for iPhone OS.

// --------------------------------------------------------------------------------------------------------
- (NSInteger) tableView: (UITableView *) table numberOfRowsInSection: (NSInteger)section 
{
	ATRACE2(@"SongViewCtl song.clipCount=%d", [song clipCount]);
	return [song clipCount];
}

// --------------------------------------------------------------------------------------------------------
- (UITableViewCell *) tableView: (UITableView *) tableView cellForRowAtIndexPath: (NSIndexPath *) indexPath
{
	ClipCell *cell = (ClipCell*)[tableView dequeueReusableCellWithIdentifier: kCellIdentifier];
	
	if (cell == nil) 
	{
		cell = [ClipCell alloc];
		NSString *nibName = g_appDelegate.ipadMode ? @"ClipCell-iPad" : @"ClipCell";
		[[NSBundle mainBundle] loadNibNamed:nibName owner:cell options:nil];
		cell = [cell initWithStyle:UITableViewCellStyleDefault reuseIdentifier:kCellIdentifier];
	}
	
	NSInteger row = [indexPath row];
	
	Clip	*clip = [song clipAtIndex: (int)row ];
	
	if ([clip.notation length] > 0)
	{
		cell.fNotes.text = clip.notation;
		cell.fNotes.textColor = [UIColor blackColor];
	}
	else
	{
		cell.fNotes.text = [NSString stringWithFormat:@"Clip %d of %d", (int)row+1, [song clipCount]];
		cell.fNotes.textColor = [UIColor grayColor];
	}
	
	cell.fStartTime.text = @"";
#if 0
	cell.fStartTime.text = [NSString stringWithFormat: @"%d at %@", row,
								[AppUtil formatDurationUI: clip.startTime ]];
#endif
	
	cell.fDuration.text = [AppUtil formatDurationUI: clip.subDuration ];
	
	if (row == currentClipIndex)
	{
		cell.fView.backgroundColor = [UIColor lightGrayColor];
		cell.fCurPos.text = [AppUtil formatDurationUI: songList.currentTime - clip.startTime];
	}
	else
	{
		cell.fView.backgroundColor = [UIColor whiteColor];
		cell.fCurPos.text = @"";
	}

	ATRACE2(@"SongViewCtl cell.fImage.image=%@", cell.fImage.image);
	
	cell.fImage.image = clip.imageIcon;
	
	cell.accessoryType = UITableViewCellAccessoryNone;
#if 0
#if APP_LITE | APP_GALLERY
	cell.accessoryType = UITableViewCellAccessoryNone;
#else
	cell.accessoryType = UITableViewCellAccessoryDetailDisclosureButton;
#endif
#endif
    
	ATRACE2(@"SongViewCtl cellForRowAtIndexPath cell=%@ clip=%@", clip, cell);

	return cell;
}

// --------------------------------------------------------------------------------------------------------
- (UITableViewCellEditingStyle)tableView:(UITableView *)aTableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath 
{
    // No editing style if not editing or the index path is nil.
    if (self.editing == NO || !indexPath) return UITableViewCellEditingStyleNone;
	// !!@
    return UITableViewCellEditingStyleNone;
}

#if 0
// ----------------------------------------------------------------------------------------------------------
- (void)tableView:(UITableView *)tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath
{
	ATRACE(@"SongViewCtl accessoryButtonTappedForRowWithIndexPath row=%d", indexPath.row);
	
	[tableView deselectRowAtIndexPath: indexPath animated: YES];
	
	NSInteger row = [indexPath row];
	
	[self showClipEditorForClipIndex: row];
}
#endif

// --------------------------------------------------------------------------------------------------------
//	 Bring up ClipView to edit selected clip
- (void) tableView: (UITableView *) tableView didSelectRowAtIndexPath: (NSIndexPath *) indexPath
{	
	[tableView deselectRowAtIndexPath: indexPath animated: YES];

	int row = (int)[indexPath row];

	Clip *clip = [song clipAtIndex: row];
    
	songList.currentTime = clip.startTime;
	
    [songList establishClipForCurrentTime];
    
	if (row == currentClipIndex	&& [songList isPlaying])
	{
		[songList pause];
	}
	else
	{
		[songList play];
	}
    
    [self actionBack: nil];
}

// --------------------------------------------------------------------------------------------------------
#pragma mark Application state management_____________
// Standard methods for managing application state.
- (void)didReceiveMemoryWarning 
{
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
	
	// Release any cached data, images, etc that aren't in use.
}

// --------------------------------------------------------------------------------------------------------
- (void)viewDidUnload 
{
	// Release any retained subviews of the main view.
	// e.g. self.myOutlet = nil;
}

// --------------------------------------------------------------------------------------------------------
- (void) reportSongChange
{
	ATRACE(@"SongViewCtl reportSongChange");
	
	NSTimeInterval	now = [NSDate timeIntervalSinceReferenceDate];
	
	lastTime = now;
	[self.tableView reloadData];
}

// --------------------------------------------------------------------------------------------------------
- (BOOL) isTracking
{
    return NO;
}

// --------------------------------------------------------------------------------------------------------
// Track song. 
- (void)timeReport: (NSTimeInterval) newTime 
{
	int	index = [song clipIndexForTime: newTime];
	NSTimeInterval	now = [NSDate timeIntervalSinceReferenceDate];
	
	ATRACE2(@"SongViewCtl timeReport newTime=%f row=%d", newTime, index);

	if (index != currentClipIndex)
	{
		currentClipIndex = index;
		[self.tableView reloadData];
		lastTime = now;

		//[self.tableView selectRowAtIndexPath: [NSIndexPath indexPathForRow:index inSection:0]  animated: YES scrollPosition: UITableViewScrollPositionNone];

		return;
	}
	if (now - lastTime > kSongViewUpdateInterval)
	{
		ATRACE2(@"SongViewCtl timeReport now=%f lastTime=%f", now, lastTime);
		lastTime = now;
		[self.tableView reloadData];
	}
	
	//- (void)selectRowAtIndexPath:(NSIndexPath *)indexPath animated:(BOOL)animated scrollPosition:(UITableViewScrollPosition)scrollPosition
}

// --------------------------------------------------------------------------------------------------------
// --------------------------------------------------------------------------------------------------------


@end
