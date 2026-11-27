/*
 
*/


#import "InfoViewCtl.h"
#import "AppDefs.h"
#import "SongList.h"
#import "AppUtil.h"
#import "AppDelegate.h"
#import "ClipPlayCtl.h"
#import "ClipListCtl.h"

@implementation InfoViewCtl

@synthesize metaArray;

#define kMakeClipDelta		10

// --------------------------------------------------------------------------------------------------------
- (void) downloadForCurrentSong
{
	ATRACE(@"InfoViewCtl: downloadForCurrentSong");
	
	ClipPlayCtl *ctl = [g_appDelegate fetchClipPlayView];
	
	Song	*song = songList.currentSong;
	
	song.source_stream = NO;
	
	[ctl download_forSong: song];
}

// --------------------------------------------------------------------------------------------------------
//- (void) showCurrentClips
//{
//	Song			*song = [[SongList default] currentSong];
//	if (! song)
//		return;
//	
//	ClipListCtl *ctl = [[ClipListCtl alloc] initWithNibName: @"SongView" bundle: nil];
//	
//	ctl.song = song;
//	[[self navigationController] pushViewController:ctl animated:YES];
//	
//}

// --------------------------------------------------------------------------------------------------------
enum
{
	k_removeAllClips,
	k_makeNClips,
};

// --------------------------------------------------------------------------------------------------------
- (void) removeAllClips
{
    UIAlertView *alert =  [[UIAlertView alloc] initWithTitle:@"Remove All Clips" 
													 message:@"" 
													delegate:self
										   cancelButtonTitle:@"Cancel" 
										   otherButtonTitles:@"Remove", nil];
	
	alertAction = k_removeAllClips;

    [alert show];
	
}

// --------------------------------------------------------------------------------------------------------
- (int) nclipMake
{
	Song			*song = [[SongList default] currentSong];
	if ([song clipCount] <=1 )
		return kMakeClipDelta;
	return [song clipCount] + kMakeClipDelta;
}

// --------------------------------------------------------------------------------------------------------
- (void) makeNClips
{
	Song			*song = [[SongList default] currentSong];
	if (! song)
		return;
	int nclips = [self nclipMake];
	NSString *msg = [NSString stringWithFormat:@"Make %d clips", nclips];
	
    UIAlertView *alert =  [[UIAlertView alloc] initWithTitle:msg 
													 message:@"" 
													delegate:self
										   cancelButtonTitle:@"Cancel" 
										   otherButtonTitles:@"Make", nil];
	
	alertAction = k_makeNClips;
	
    [alert show];
	
}

// ----------------------------------------------------------------------------------------------------------
// UIAlertView delegate
- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex
{
	ATRACE2(@"MainViewCtl:alertView didDismissWithButtonIndex=%d", buttonIndex);
	if (buttonIndex == 1) {
		Song			*song = [[SongList default] currentSong];
		int				nclips = [self nclipMake];
		switch (alertAction) {
			case k_removeAllClips:
				[song removeAllClips];
				break;
			case k_makeNClips:
				[song makeClips: nclips];
				break;
		}
		[self.tableView reloadData];
	}
}

// --------------------------------------------------------------------------------------------------------
- (void) songsAction
{	
	SongListCtl *controller = [[SongListCtl alloc] initWithNibName: @"SongListView" bundle: nil];

	ATRACE(@"InfoViewCtl songsAction SongListCtl controller=%@", controller);

	[[self navigationController] pushViewController:controller animated:YES];
}

// --------------------------------------------------------------------------------------------------------
// Put the current song on the paste board
- (void) copyAction
{
	ATRACE(@"InfoViewCtl: copyAction");
	
	UIPasteboard	*pasteBoard = [UIPasteboard generalPasteboard];
	NSString		*str = nil;
	Song			*song = [[SongList default] currentSong];
	
	ATRACE2(@"InfoViewCtl timeReport: song=%@", song);
	if (song) {
		str = [song asExportString];
		pasteBoard.string = str;
		
		[AppUtil showMsg: [NSString stringWithFormat:@"Copied %d clips for %@", song.clipCount, song.title]
					   title: @"Copy" ];
	}
	ATRACE2(@"	copy str=%@", str);
}

// --------------------------------------------------------------------------------------------------------
// Create a song from the paste board
- (void) pasteAction
{
	ATRACE(@"InfoViewCtl: pasteAction");
	
	UIPasteboard	*pasteBoard = [UIPasteboard generalPasteboard];
	NSString		*str = [pasteBoard string];
	
	Song *newSong = [[SongList default] importSongFromString: str intoSong: nil];
	
	[AppUtil showMsg: [NSString stringWithFormat:@"Pasted %d clips for %@", newSong.clipCount, newSong.title]
			   title: @"Paste" ];

	[[SongList default] selectSong: newSong];
	
	[[self navigationController] popViewControllerAnimated:YES];
}

// --------------------------------------------------------------------------------------------------------
- (void) emailAction
{
	ATRACE(@"InfoViewCtl: emailAction");
	
	Song			*song = [[SongList default] currentSong];
	if (! song) {
		// !!@ Alert
		ATRACE(@"InfoViewCtl: No song");
		return;
	}
	NSString *messageBody = [song asExportString];
	NSString *subject = [NSString stringWithFormat:@"%@ for %@ (%d clips)", [AppDelegate default].appName, song.label, song.clipCount];
	
	if (! [MFMailComposeViewController canSendMail]) {
		// !!@ Disable email option
		ATRACE(@"InfoViewCtl: No sendMail");
		return;
	}
	
	MFMailComposeViewController	*ctl = [[MFMailComposeViewController alloc] init];
	ctl.mailComposeDelegate = self;
	
	[ctl setMessageBody:messageBody  isHTML: NO];
	[ctl setSubject: subject];
	
    //[[self navigationController] presentModalViewController:ctl animated:YES];
    [[self navigationController] presentViewController:ctl animated:YES completion:nil];
	
}

// --------------------------------------------------------------------------------------------------------
// MFMailComposeViewControllerDelegate 
- (void)mailComposeController:(MFMailComposeViewController*)controller 
		  didFinishWithResult:(MFMailComposeResult)result
						error:(NSError*)error
{
	// MFMailComposeResultFailed
	ATRACE(@"InfoViewCtl didFinishWithResult result=%d error=%@", result, error);
	
	if ( result == MFMailComposeResultFailed ) {
		// !!@ Alert
		AFLOG(@"InfoViewCtl didFinishWithResult FAILURE result=%d error=%@", result, error);
	}
//	[self dismissModalViewControllerAnimated: YES];
    [self dismissViewControllerAnimated:YES completion:nil];
}

// --------------------------------------------------------------------------------------------------------

#define ARRAY_BEGIN [NSArray arrayWithObjects:
#define ARRAY_END nil ]

// --------------------------------------------------------------------------------------------------------

#define kRowActionIndex	0
#define kRowTitleIndex	1

enum
{
	kSongsAction,
	
	kSongHead,
	kSongAlbum,
	kSongArtist,
	kSongInfo,
	kSongInfo2,
	
	kRemoveAll,
	kMakeNClips,

	kCopyAction,
	kPasteAction,
	kEmailAction,
	
	
	kSongAbout,
	
//	kPlayRecAction,
//	kPhotoAction,
};

enum 
{
	//kSongsSection = 0,
	kSongSection = 0,
	kEditSection,
	kAboutSection,
	//kOptionsSection
};


#define kSongsTitle		@"Songs"

#define kCopyTitle		@"Copy"

#define kPasteTitle		@"Paste"

#define kEmailTitle		@"Email"

#define kPhotoTitle		@"Show Photos"

#define kPlayRecTitle	@"Play Recordings"

#define kSongClipsUpgrageTitle	@"Upgrade to SongClips"

#define kSongsAboutTitle	@"SongClips Website"

// --------------------------------------------------------------------------------------------------------
// Configures the table view.
- (void) viewDidLoad 
{
    [super viewDidLoad];
	
    songList = [SongList default];

    // Obtain a UIButton object and set its background to the UIImage object
	UIButton *buttonView = [[UIButton alloc] initWithFrame: CGRectMake (0, 0, 40, 40)];
	[buttonView setBackgroundImage: [UIImage imageNamed:@"back_arrow.png"] forState: UIControlStateNormal];
	
	// Obtain a UIBarButtonItem object and initialize it with the UIButton object
	UIBarButtonItem *backButton = [[UIBarButtonItem alloc] initWithCustomView: buttonView];
	
	[buttonView addTarget:self action:@selector(actionBack:) forControlEvents:UIControlEventTouchUpInside];
    
	self.navigationItem.leftBarButtonItem = backButton;

	self.title = @"Info";

	self.metaArray = @[
						@[
							@[ @(kSongHead), @"" ],
							@[ @(kSongAlbum), @"", ],
							@[ @(kSongArtist), @"" ],
							@[ @(kSongInfo), @"" ],
							@[ @(kSongInfo2), @"" ]
                        ],
						@[
							@[ @(kCopyAction), kCopyTitle ],
							@[ @(kEmailAction), kEmailTitle ]
						],
						@[
							@[ @(kSongAbout), kSongsAboutTitle ]
						]
					];
}

// ----------------------------------------------------------------------------------------------------------
- (void)actionBack: (id)sender
{	
	[[self navigationController] popViewControllerAnimated: YES];
}

// --------------------------------------------------------------------------------------------------------
- (void)viewWillAppear:(BOOL)animated
{
	ATRACE(@"InfoViewCtl viewWillAppear");
	
	[super viewWillAppear: animated];
	
	[self.tableView reloadData];
}

// --------------------------------------------------------------------------------------------------------
- (void) selectReplacementForCurrentSong
{
	ATRACE(@"InfoViewCtl: selectReplacementForCurrentSong");

    if (songList.isVideo) {
        AssetBrowserController *browser =
        [[AssetBrowserController alloc] initWithSourceType:AssetBrowserSourceTypeIPodLibrary modalPresentation:NO];
        
        browser.delegate = self;
        browser.forTitle = @"Select Replacement Video";
        
        [[self navigationController] pushViewController:browser animated:YES];
    }
    else {
        MPMediaPickerController *picker = [[MPMediaPickerController alloc] initWithMediaTypes: MPMediaTypeAny];
        // MPMediaTypeAny]; // MPMediaTypeAnyAudio];
        ATRACE(@"InfoViewCtl: MPMediaPickerController picker=%@", picker);
        if (! picker) {
            ATRACE(@"InfoViewCtl: no MPMediaPickerController");
            return;
        }
        picker.delegate						= self;
        picker.allowsPickingMultipleItems	= NO;
        picker.prompt						= @"Select Replacement";
        
        [[UIApplication sharedApplication] setStatusBarStyle: UIStatusBarStyleDefault animated:YES];
        
        [self presentViewController:picker animated:YES completion:nil];
    }
}

// ----------------------------------------------------------------------------------------------------------
- (void) replaceCurrentSongMedia: (MPMediaItem *) newMediaItem
{
	Song	*song = songList.currentSong;
	if (song && newMediaItem) {
		[song applyReplacement: newMediaItem];
		
		[song saveToDisk];
		
		[songList selectSong: song];
		
        [self.tableView reloadData];
	}
}

// ----------------------------------------------------------------------------------------------------------
- (void)assetBrowser:(AssetBrowserController *)assetBrowser didChooseItem:(AssetBrowserItem *)assetBrowserItem
{
	ATRACE(@"InfoViewCtl: assetBrowser didChooseItem=%@", assetBrowserItem);
	ATRACE(@"InfoViewCtl: assetBrowser URL=%@", assetBrowserItem.URL);
	ATRACE(@"InfoViewCtl: assetBrowser mediaItem=%@", assetBrowserItem.mediaItem);
    
    [[self navigationController] popViewControllerAnimated: YES];
    
    [self replaceCurrentSongMedia: assetBrowserItem.mediaItem];
}

// ----------------------------------------------------------------------------------------------------------
- (void)assetBrowserDidCancel:(AssetBrowserController *)assetBrowser
{
	ATRACE(@"ClipPlayCtl: assetBrowserDidCancel %@", assetBrowser);
}

// --------------------------------------------------------------------------------------------------------
// Responds to the user tapping Done after choosing music.
- (void) mediaPicker: (MPMediaPickerController *) mediaPicker didPickMediaItems: (MPMediaItemCollection *) mediaItemCollection
{
    [mediaPicker dismissViewControllerAnimated:YES completion:nil];
    
	[[UIApplication sharedApplication] setStatusBarStyle: UIStatusBarStyleBlackOpaque animated:YES];
	
	NSArray *newMediaItems = [mediaItemCollection items];
	if ([newMediaItems count] < 1) {
		ATRACE2(@"InfoViewCtl: no newMediaItems for song=%@", song);
		return;
	}
	MPMediaItem *mediaItem = newMediaItems[ 0];
	
	ATRACE2(@"InfoViewCtl: applyReplacement song=%@ mediaItem=%@", song, mediaItem);
    
    [self replaceCurrentSongMedia: mediaItem];
}

// --------------------------------------------------------------------------------------------------------
// Responds to the user tapping done having chosen no music.
- (void) mediaPickerDidCancel: (MPMediaPickerController *) mediaPicker
{
	//[self dismissModalViewControllerAnimated: YES];
    [mediaPicker dismissViewControllerAnimated:YES completion:nil];
	
	[[UIApplication sharedApplication] setStatusBarStyle: UIStatusBarStyleBlackOpaque animated:YES];
}

// --------------------------------------------------------------------------------------------------------
#pragma mark Table view methods________________________

// To learn about using table views, see the TableViewSuite sample code  
//		and Table View Programming Guide for iPhone OS.

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
	return 44.0;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
	switch (section) {
		case kSongSection:
			return 26;
		case kAboutSection:
			return 8.0;
	}
	return 8.0;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section
{
	switch (section) {
		//case kSongsSection:
		//	return 8.0;
	}
	return 2.0;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
	switch (section) {
		case kSongSection:
			return [NSString stringWithFormat:@"Clips For: %@", songList.currentSong.label];;
	}
	return @" ";
}

// ----------------------------------------------------------------------------------------------------------
- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
	return @" ";
}

// ----------------------------------------------------------------------------------------------------------
// tell our table how many sections or groups it will have (always 1 in our case)
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
	return [metaArray count];
}

// --------------------------------------------------------------------------------------------------------
- (NSInteger) tableView: (UITableView *) table numberOfRowsInSection: (NSInteger)section 
{
	return [metaArray[ section] count];
}

// --------------------------------------------------------------------------------------------------------
//	 To conform to the Human Interface Guidelines, selections should not be persistent --
//	 deselect the row after it has been selected.
- (void) tableView: (UITableView *) tableView didSelectRowAtIndexPath: (NSIndexPath *) indexPath
{	
	[tableView deselectRowAtIndexPath: indexPath animated: YES];
	
	NSArray *arow = metaArray[ [indexPath section]][ [indexPath row]];
	int	action = [arow[ kRowActionIndex] intValue];
	ATRACE2(@"InfoViewCtl didSelectRowAtIndexPath arow=%@ indexPath=%@ action=%d", arow, indexPath, action);
	switch (action) {
		case kSongHead:
            [self selectReplacementForCurrentSong];
			break;
		case kRemoveAll:
			[self removeAllClips];
			break;
		case kMakeNClips:
			[self makeNClips];
			break;
		case kSongsAction:
			[self songsAction];
			break;
		case kCopyAction:
			[self copyAction];
			break;
		case kPasteAction:
			[self pasteAction];
			break;
		case kEmailAction:
			[self emailAction];
			break;
		case kSongAbout:
			[g_appDelegate openInBrowser: kSongClipsWebSite];
			break;
		case kSongInfo:
			ATRACE2(@"InfoViewCtl didSelectRowAtIndexPath kSongInfo arow=%@ indexPath=%@ action=%d", arow, indexPath, action);
			[self downloadForCurrentSong];
			break;
	}
}

// --------------------------------------------------------------------------------------------------------
- (UITableViewCell*) cellFor: (NSString*) cellID style: (UITableViewCellStyle) cellStyle tableView: (UITableView *) tableView
{
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier: cellID];
	if (cell == nil)  {
		cell = [[UITableViewCell alloc] initWithStyle: cellStyle reuseIdentifier: cellID];
	}
	return cell;
}

// --------------------------------------------------------------------------------------------------------
- (UITableViewCell *) tableView: (UITableView *) tableView cellForRowAtIndexPath: (NSIndexPath *) indexPath
{	
	NSArray *arow = metaArray[[indexPath section]][[indexPath row]];
	int	action = [arow[kRowActionIndex] intValue];
	UITableViewCell *cell = nil;
	Song	*song = [songList currentSong];
	ATRACE2(@"InfoViewCtl cellForRowAtIndexPath arow=%@ indexPath=%@", arow, indexPath);
	switch (action) {
		case kSongHead:
			cell = [self cellFor: @"Cell-kSong" style: UITableViewCellStyleSubtitle tableView: tableView];
			if (! cell) return cell;
			if (song) {
				cell.textLabel.text = song.title;
				//cell.detailTextLabel.text = [NSString stringWithFormat:@"%d clips", [song clipCount]];
				cell.detailTextLabel.text = songList.isVideo? @"Title (video)" : @"Title (music)";
				cell.textLabel.textColor = [UIColor colorWithRed:4.0/255.0 green:143.0/255. blue:1.0/255.0 alpha:1.0];
			}
			else {
				cell.textLabel.text = @"No Media";
				cell.detailTextLabel.text = @"";
				cell.textLabel.textColor = [UIColor blackColor];
			}
			cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
			//cell.accessoryType = UITableViewCellAccessoryNone;
			break;
			
		case kSongAlbum:
			cell = [self cellFor: @"Cell-kSongAlbum" style: UITableViewCellStyleSubtitle tableView: tableView];
			if (! cell) return cell;
			if (song) {
				//cell.textLabel.text = [NSString stringWithFormat:@"Album: %@", [song albumTitle]];
				cell.textLabel.text = [song albumTitle];
				cell.detailTextLabel.text = @"Album";
				//cell.detailTextLabel.text = [NSString stringWithFormat:@"%d clips", [song clipCount]];
				//cell.textLabel.textColor = [UIColor colorWithRed:4.0/255.0 green:143.0/255. blue:1.0/255.0 alpha:1.0];
			}
			cell.accessoryType = UITableViewCellAccessoryNone;
			break;
			
		case kSongArtist:
			cell = [self cellFor: @"Cell-kSongArtist" style: UITableViewCellStyleSubtitle tableView: tableView];
			if (! cell) return cell;
			if (song) {
				cell.textLabel.text = [song artist];
				cell.detailTextLabel.text = @"Artist";
			}
			cell.accessoryType = UITableViewCellAccessoryNone;
			break;

		case kSongInfo:
			cell = [self cellFor: @"Cell-kSongInfo" style: UITableViewCellStyleSubtitle tableView: tableView];
			if (! cell) return cell;
			if (song) {
				cell.textLabel.text = [song sourceForLocal];
				cell.detailTextLabel.text = song.source_stream ? @"Stream" : @"";
			}
			cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
			break;

		case kSongInfo2:
			cell = [self cellFor: @"Cell-kSongInfo2" style: UITableViewCellStyleSubtitle tableView: tableView];
			if (! cell) return cell;
			if (song) {
				cell.textLabel.text = [song partialPath];
				cell.detailTextLabel.text = [song file_display_size];
			}
			cell.accessoryType = UITableViewCellAccessoryNone;
			break;

		case kMakeNClips:
		{
			cell = [self cellFor: @"Cell-kMakeNClips" style: UITableViewCellStyleDefault tableView: tableView];
			if (! cell) return cell;
			Song	*song = [[SongList default] currentSong];
			if (song) {
				cell.textLabel.text = [NSString stringWithFormat:@"Make %d clips", [self nclipMake]];
			}
			else {
				cell.textLabel.text = @"";
			}
			cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
		}
			break;
		case kRemoveAll:
		case kSongsAction:
		default:
		{
			cell = [self cellFor: @"Cell4" style: UITableViewCellStyleDefault tableView: tableView];
			if (! cell) return cell;
			cell.textLabel.text = arow [kRowTitleIndex];
			cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
		}
			break;
	}
	
	return cell;
}

// --------------------------------------------------------------------------------------------------------
// --------------------------------------------------------------------------------------------------------


@end
