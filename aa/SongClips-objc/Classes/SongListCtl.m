/*
 Copyright (C) 2008 John Henry Thompson. All Rights Reserved.
 */

#import "SongListCtl.h"
#import "SongList.h"
#import "AppDefs.h"
#import "ClipListCtl.h"
#import "ClipPlayCtl.h"
#import "SongCell.h"
#import "AppUtil.h"

#import "DD_Access.h"
#import "DD_RemoteSite.h"
#import "DD_HTTPManager.h"
#import "DD_FileFTP.h"
#import "UtilPath.h"

@interface SongListCtl () <DD_AccessDelegate, DD_HTTPManagerDelegate> {

}
@end

@implementation SongListCtl

// --------------------------------------------------------------------------------------------------------
// Create a song from the paste board
- (void) pasteAction
{
	ATRACE(@"SongListViewCtl: pasteAction");
	
	UIPasteboard	*pasteBoard = [UIPasteboard generalPasteboard];
	NSString		*str = [pasteBoard string];
	
	Song *newSong = [[SongList default] importSongFromString: str intoSong: nil];

#if APP_DD_TEST_ACCESS && APP_TRACE
	if (newSong.clipCount <= 0) {
		DD_RemoteSite	*remote = [DD_RemoteSite new];
		DD_Access		*access = [DD_Access new];
		access.remoteSite = remote;
		access.delegate = self;
		[access sendUrlStr: @"https://mobilesiteclone.net/songclips/dice/mov/test.txt"];
	}
#endif
#if APP_DD_TEST && APP_TRACE
	if (newSong.clipCount <= 0) {
		DD_FileFTP *file_tp = [DD_FileFTP new];
		DD_HTTPManager *http_man = [DD_HTTPManager new];
		file_tp.source = @"http://mobilesiteclone.net/songclips/dice/mov/IMG_6574-rotate-qt.m4v";
		file_tp.path = @"mov/";
		file_tp.fileName = @"IMG_6574-rotate-qt.m4v";
		file_tp.modDate = [NSDate date];
		http_man.destRoot = localStoreRoot();
		http_man.delegate = self;
		http_man.path = file_tp.path;
		[http_man downLoadFile:file_tp fileOffset:0 pathHome:@"" doneBlock: nil];
		
		NSString *localPath = [http_man localPath];
		newSong.s_url = [NSURL fileURLWithPath: localPath];
		newSong.sourceForLocal = file_tp.source;
		newSong.partialPath = [http_man partialPath];
		newSong.duration = 13.0;
		
		[newSong initForLocal];
	}
#endif
	
	[AppUtil showMsg: [NSString stringWithFormat:@"Pasted %d clips for %@", newSong.clipCount, newSong.label]
			   title: @"Paste" ];
	
	[[SongList default] selectSong: newSong];
	
	[self.tableView reloadData];
}

// --------------------------------------------------------------------------------------------------------
- (void) access:(DD_Access*)access accessErr:(NSString*)errMsg
{
	ATRACE(@"SongListViewCtl access accessErr=%@", errMsg);
}

- (void) access:(DD_Access*)access done:(NSData*)result
{
	ATRACE(@"SongListViewCtl access result len=%lu", (unsigned long)[result length]);
	
//	NSString *str = [[NSString alloc] initWithData:result encoding:NSUTF8StringEncoding];
	
	ATRACE(@"SongListViewCtl str=%@", [[NSString alloc] initWithData:result encoding:NSUTF8StringEncoding]);
}

// --------------------------------------------------------------------------------------------------------
- (void) httpm_downdload: (DD_HTTPManager *) httpm bytesSoFar: (SInt64)bytesSoFar 
//- (void) downLoadFileBytesSoFar: (SInt64)bytesSoFar
{
	ATRACE2(@"SongListViewCtl downLoadFileBytesSoFar bytesSoFar=%lld", bytesSoFar);
}

- (void) httpm_done: (DD_HTTPManager *) httpm
{
	ATRACE(@"SongListViewCtl operationDone");
}

// --------------------------------------------------------------------------------------------------------
// Configures the table view.
- (void) viewDidLoad 
{
    [super viewDidLoad];

    ATRACE(@"SongListViewCtl viewDidLoad");

	_songList = [SongList default];
		
#if 0
	// create a custom navigation bar button and set it to always say "Back"
	UIBarButtonItem *temporaryBarButtonItem = [[[UIBarButtonItem alloc] init] autorelease];
	temporaryBarButtonItem.title = @"Back";
	self.navigationItem.backBarButtonItem = temporaryBarButtonItem;
#endif
	// Obtain a UIButton object and set its background to the UIImage object
	UIButton *buttonView = [[UIButton alloc] initWithFrame: CGRectMake (0, 0, 40, 40)];
	[buttonView setBackgroundImage: [UIImage imageNamed:@"icon_48.png"] forState: UIControlStateNormal];
	
	// Obtain a UIBarButtonItem object and initialize it with the UIButton object
	UIBarButtonItem *backButton = [[UIBarButtonItem alloc] initWithCustomView: buttonView];
	
	[buttonView addTarget:self action:@selector(actionOptions:) forControlEvents:UIControlEventTouchUpInside];
	
	self.navigationItem.leftBarButtonItem = backButton;
	
#if APP_GALLERY
#else
	// Allow editing 
	self.navigationItem.rightBarButtonItem = self.editButtonItem;
#endif
	
	self.title = [g_appDelegate appNameVersion];
}

// ----------------------------------------------------------------------------------------------------------
- (void) clearButtonIndices
{
    openSiteButtonIndex = -2;
	addMusicButtonIndex = -2;
	addVideoButtonIndex = -2;
	addPasteButtonIndex = -2;
}

// ----------------------------------------------------------------------------------------------------------
- (void)actionOptions: (id)sender
{
	ATRACE(@"SongListViewCtl actionOptions ENTER");
	
	if (_actionSheet) {
		ATRACE(@"SongListViewCtl actionOptions RETURNING actionSheet=%@", _actionSheet);
        // !!@ 2023 temp actionOptions
//        _actionSheet = nil;
		 return;
	}
    [self clearButtonIndices];
	
    openSiteButtonIndex = 0;
    NSArray *items1 = @[@"SongClips Website", @"Cancel"];
    _actionSheet = [EP_JGActionSheet actionSheetWithSections:
                   @[[EP_JGActionSheetSection
                      sectionWithTitle:nil message:nil
                      buttonTitles:items1
                      buttonStyle:JGActionSheetButtonStyleBlue+JGActionSheetButtonStyleOptionFlushLeft]
                     ]];
    _actionSheet.delegate = self;
    _actionSheet.insets = UIEdgeInsetsMake(20.0f, 0.0f, 0.0f, 0.0f);
    __weak __typeof(self) weakSelf = self;
    [_actionSheet setOutsidePressBlock:^(EP_JGActionSheet *sheet) {
        [sheet dismissAnimated:NO];
    }];
    [_actionSheet setButtonPressedBlock:^(EP_JGActionSheet *sheet, NSIndexPath *indexPath) {
        [sheet dismissAnimated:NO];
        NSUInteger index = [indexPath indexAtPosition:1];
        [weakSelf actionSheet_clickedButtonAtIndex:(int)index];
    }];
    if (g_appDelegate.ipadMode) {
        UIBarButtonItem *but = self.navigationItem.leftBarButtonItem;
        [_actionSheet showFromRect:but.customView.bounds forView:but.customView inView:self.view animated:APP_ACTIONSHEET_ANIM];
        //[actionSheet showFromRect:self.navigationItem.leftBarButtonItem forView:self.view inView:self.view animated:APP_ACTIONSHEET_ANIM];
        // self.navigationItem.leftBarButtonItem
        ATRACE(@"SongListViewCtl self.navigationItem.leftBarButtonItem=%@", self.navigationItem.leftBarButtonItem);
        ATRACE(@"SongListViewCtl self.navigationItem.leftBarButtonItem.customView=%@", self.navigationItem.leftBarButtonItem.customView);
    }
    else {
        ATRACE(@"SongListViewCtl actionOptions view=%@", self.view );
        [_actionSheet showInView:self.view animated:APP_ACTIONSHEET_ANIM];
    }
}

// ----------------------------------------------------------------------------------------------------------
- (void)actionSheetWillDismiss:(EP_JGActionSheet *)aactionSheet
{
    ATRACE2(@"SongListViewCtl sheet %p will dismiss", aactionSheet);
    _actionSheet = nil;
}

// ----------------------------------------------------------------------------------------------------------
- (void)actionAddOptions
{
	ATRACE(@"SongListViewCtl actionAddOptions");
	
	if (_actionSheet) {
		ATRACE(@"SongListViewCtl: RETURNING actionSheet=%@", _actionSheet);
		return;
	}
    [self clearButtonIndices];
	
    addMusicButtonIndex = 0;
    addVideoButtonIndex = 1;
    addPasteButtonIndex = 2;
	addSiteButtonIndex = 3;
    NSArray *items1 = @[@"Add from Music Library", @"Add from Video Library", @"Add by Pasting", @"Add from Site"];
    _actionSheet = [EP_JGActionSheet actionSheetWithSections:
                   @[[EP_JGActionSheetSection
                      sectionWithTitle:nil message:nil
                      buttonTitles:items1
                      buttonStyle:JGActionSheetButtonStyleBlue+JGActionSheetButtonStyleOptionFlushLeft]
                      ]];
    _actionSheet.delegate = self;
    _actionSheet.insets = UIEdgeInsetsMake(20.0f, 0.0f, 0.0f, 0.0f);
    __weak __typeof(self) weakSelf = self;
        [_actionSheet setOutsidePressBlock:^(EP_JGActionSheet *sheet) {
            [sheet dismissAnimated:NO];
        }];
    [_actionSheet setButtonPressedBlock:^(EP_JGActionSheet *sheet, NSIndexPath *indexPath) {
        [sheet dismissAnimated:NO];
        NSUInteger index = [indexPath indexAtPosition:1];
        [weakSelf actionSheet_clickedButtonAtIndex:(int)index];
    }];
    if (g_appDelegate.ipadMode) {
        [_actionSheet showFromRect:addOptionRect forView:self.view inView:self.view animated:APP_ACTIONSHEET_ANIM];
    }
    else {
        [_actionSheet showInView:self.view animated:APP_ACTIONSHEET_ANIM];
		//- (void)showFromPoint:(CGPoint)point inView:(UIView *)view arrowDirection:(JGActionSheetArrowDirection)arrowDirection animated:(BOOL)animated {
		// - (void)showFromPoint:(CGPoint)point inView:(UIView *)view arrowDirection:(JGActionSheetArrowDirection)arrowDirection animated:(BOOL)animated;
		// JGActionSheetArrowDirectionBottom
//		CGPoint point;
//		point.x = self.view.bounds.size.width / 2;
//		point.y = self.view.bounds.size.height / 2;
//		ATRACE(@"SongListViewCtl: point.x=%f point.y=%f", point.x, point.y);
//		ATRACE(@"SongListViewCtl: self.view=%@", self.view);
//		[_actionSheet showFromPoint:point inView:self.view arrowDirection:JGActionSheetArrowDirectionBottom  animated:APP_ACTIONSHEET_ANIM];
    }
}

// ----------------------------------------------------------------------------------------------------------
//- (void)actionSheet: (UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
- (void)actionSheet_clickedButtonAtIndex:(NSInteger)buttonIndex
{
    ATRACE(@"SongListViewCtl: actionSheet buttonIndex=%ld", (long)buttonIndex);
    
    self.actionSheet = nil;
    
    if (buttonIndex == openSiteButtonIndex) {
        [g_appDelegate openInBrowser: kSongClipsWebSite];
    }
    else if (buttonIndex == addMusicButtonIndex) {
        [self showMediaPicker];
    }
    else if (buttonIndex == addVideoButtonIndex) {
        [self addVideoAction];
    }
    else if (buttonIndex == addPasteButtonIndex) {
        [self pasteAction];
    }
	else if (buttonIndex == addSiteButtonIndex) {
		[g_appDelegate openInBrowser: kSongClipsWebSite];
	}
}


// ----------------------------------------------------------------------------------------------------------
- (void) selectCreatedSong
{
    int index = [_songList songCount] - 1;
    
    ATRACE(@"selectCreatedSong: index=%d", index);
    
    if (index < 0) {
        return;
    }
    [_songList selectSong: [_songList songAtIndex: index]];
    
    [self.tableView reloadData];
    
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow: index inSection: 0];
    
    [self.tableView selectRowAtIndexPath: indexPath animated: YES scrollPosition:UITableViewScrollPositionMiddle];
    
    self.selectIndexPath = indexPath;
}

// ----------------------------------------------------------------------------------------------------------
- (void)assetBrowser:(AssetBrowserController *)assetBrowser didChooseItem:(AssetBrowserItem *)assetBrowserItem
{
	ATRACE(@"SongListViewCtl: assetBrowser didChooseItem=%@", assetBrowserItem);
	ATRACE(@"SongListViewCtl: assetBrowser URL=%@", assetBrowserItem.URL);
	ATRACE(@"SongListViewCtl: assetBrowser mediaItem=%@", assetBrowserItem.mediaItem);

    [_songList createSongForMediaItem: assetBrowserItem.mediaItem];
    
    [[self navigationController] popViewControllerAnimated: YES];
    
    [self selectCreatedSong];
}

// ----------------------------------------------------------------------------------------------------------
- (void)assetBrowserDidCancel:(AssetBrowserController *)assetBrowser
{
	ATRACE(@"SongListViewCtl: assetBrowserDidCancel %@", assetBrowser);
}

// ----------------------------------------------------------------------------------------------------------
- (void) addVideoAction
{
    AssetBrowserController *browser =
        [[AssetBrowserController alloc] initWithSourceType:AssetBrowserSourceTypeIPodLibrary modalPresentation:NO];
    
	browser.delegate = self;
    browser.forTitle = @"Select New Video";
    
    [[self navigationController] pushViewController:browser animated:YES];
}

// --------------------------------------------------------------------------------------------------------
- (void)viewWillAppear:(BOOL)animated
{
	ATRACE2(@"SongViewCtl viewWillAppear");
	
	[super viewWillAppear: animated];
	
	[self.tableView reloadData];
	
	//[SongList default].delegate = self;
	
	if (_selectIndexPath)
		[self.tableView deselectRowAtIndexPath: _selectIndexPath animated: YES];

	if ( [_songList currentSong] != nil) {
		int currentSongIndex = [_songList currentSongIndex];

        ATRACE(@"SongViewCtl viewWillAppear currentSongIndex=%d", currentSongIndex);

        NSIndexPath *indexPath = [NSIndexPath indexPathForRow: currentSongIndex inSection: 0];

		[self.tableView selectRowAtIndexPath: indexPath animated: animated scrollPosition:UITableViewScrollPositionMiddle];
		
		self.selectIndexPath = indexPath;
	}
}

// --------------------------------------------------------------------------------------------------------
- (void)viewDidAppear:(BOOL)animated
{
	ATRACE2(@"SongViewCtl viewDidAppear");

	if (g_appDelegate.pendingAccessUrlStr) {
		ClipPlayCtl *ctl = [g_appDelegate fetchClipPlayView];
		
		[[self navigationController] pushViewController:ctl animated:YES];
		
		return;
	}
	if (_doAdd) {
		_doAdd = NO;
		[self showMediaPicker];
	}
}

// --------------------------------------------------------------------------------------------------------
- (void) becomeActive
{
	ATRACE2(@"SongViewCtl becomeActive g_appDelegate.pendingAccessUrlStr=%@", g_appDelegate.pendingAccessUrlStr);

    if (g_appDelegate.pendingAccessUrlStr) {
		ClipPlayCtl *ctl = [g_appDelegate fetchClipPlayView];
		
		[[self navigationController] pushViewController:ctl animated:YES];
		
		return;
	}
}

// --------------------------------------------------------------------------------------------------------
- (void) accessUrlStr: (NSString *)urlStr
{
	ATRACE(@"SongViewCtl accessUrlStr");

	// Make sure we are on top
	while (self != [[self navigationController] topViewController]) {
		ATRACE(@"SongViewCtl accessUrlStr popping");
		[[self navigationController] popViewControllerAnimated:NO];
	}
	
	// Pass url on to main view 
	g_appDelegate.pendingAccessUrlStr = urlStr;
	
	ClipPlayCtl *ctl = [g_appDelegate fetchClipPlayView];
	
	[[self navigationController] pushViewController:ctl animated:YES];
}

// --------------------------------------------------------------------------------------------------------
// Configures and displays the media item picker.
- (void) showMediaPicker
{
	[_songList pause];
	
	MPMediaPickerController *picker = [[MPMediaPickerController alloc] initWithMediaTypes: MPMediaTypeAny]; 
    ATRACE(@"SongViewCtl: MPMediaPickerController picker=%@", picker);

	if (! picker) {
		ATRACE(@"SongViewCtl: no MPMediaPickerController");
		return;
	}
	picker.delegate						= self;
	picker.allowsPickingMultipleItems	= NO;
	picker.prompt						= NSLocalizedString (@"AddSongsPrompt", @"Prompt to user to choose some songs to play");
	
	[[UIApplication sharedApplication] setStatusBarStyle: UIStatusBarStyleDefault animated:YES];

    [self presentViewController: picker animated: YES completion:nil];
}

// --------------------------------------------------------------------------------------------------------
// Responds to the user tapping Done after choosing music.
- (void) mediaPicker: (MPMediaPickerController *) mediaPicker didPickMediaItems: (MPMediaItemCollection *) mediaItemCollection 
{  
    [mediaPicker dismissViewControllerAnimated: YES completion:nil];
	
	[_songList addMediaItemCollection: mediaItemCollection];
	
	[[UIApplication sharedApplication] setStatusBarStyle: UIStatusBarStyleBlackOpaque animated:YES];

    [self selectCreatedSong];
}

// --------------------------------------------------------------------------------------------------------
// Responds to the user tapping done having chosen no music.
- (void) mediaPickerDidCancel: (MPMediaPickerController *) mediaPicker 
{
	//[self dismissModalViewControllerAnimated: YES];
    [mediaPicker dismissViewControllerAnimated: YES completion:nil];

	[[UIApplication sharedApplication] setStatusBarStyle: UIStatusBarStyleBlackOpaque animated:YES];
}

// --------------------------------------------------------------------------------------------------------
// All table rows but the very last correspond to song entry
- (BOOL) isSongRow: (NSInteger) row
{
	return row < [_songList songCount];
}

// --------------------------------------------------------------------------------------------------------
#pragma mark Table view methods________________________

// To learn about using table views, see the TableViewSuite sample code  
//		and Table View Programming Guide for iPhone OS.

// --------------------------------------------------------------------------------------------------------
- (NSInteger) tableView: (UITableView *) table numberOfRowsInSection: (NSInteger)section 
{
	return [_songList songCount] + 1;
}

// --------------------------------------------------------------------------------------------------------
- (UITableViewCell *) tableView: (UITableView *) tableView cellForRowAtIndexPath: (NSIndexPath *) indexPath
{
	NSInteger				row = [indexPath row];
	NSString				*cellID = @"SongCell";
	UITableViewCellStyle	cellStyle = UITableViewCellStyleSubtitle;
	
	if (! [self isSongRow: row]) {
		cellID = @"SongAddCell";
		cellStyle = UITableViewCellStyleDefault;
		UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier: cellID];
		if (cell == nil) {
			cell = [[UITableViewCell alloc] initWithStyle: cellStyle   reuseIdentifier: cellID];
		}
		cell.textLabel.text = @"Add from iPod Library...";
		//cell.textLabel.textColor = [UIColor greenColor];
		cell.textLabel.textColor = [UIColor colorWithRed:4.0/255.0 green:143.0/255. blue:1.0/255.0 alpha:1.0];
		cell.detailTextLabel.text = @"";
		cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
		
		return cell;
	}
	else
	{
		SongCell *cell = (SongCell*)[tableView dequeueReusableCellWithIdentifier: cellID];
		if (cell == nil) {
			cell = [SongCell alloc];
			NSString *nibName = g_appDelegate.ipadMode ? @"SongCell-iPad" : @"SongCell";
			[[NSBundle mainBundle] loadNibNamed:nibName owner:cell options:nil];
			cell = [cell initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellID];
		}
		if ([self isSongRow: row]) {
			Song *song = [_songList songAtIndex: (int)row];
			if (song) {
				cell.textLabel.text = song.label;
				cell.textLabel.textColor = [UIColor blackColor];
				cell.detailTextLabel.text = [NSString stringWithFormat: @"%@ - %@", 
											 song.albumTitle? song.albumTitle: @"", 
											 song.artist?song.artist: @"" ];
				cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
				if (self.editing)
					cell.accessoryType = UITableViewCellAccessoryNone;
				cell.fImage.image = song.imageIcon;
			}
		}
		return cell;
	}
}

// --------------------------------------------------------------------------------------------------------
- (UITableViewCellEditingStyle)tableView:(UITableView *)aTableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath 
{
    // No editing style if not editing or the index path is nil.
    if (self.editing == NO || !indexPath)
		return UITableViewCellEditingStyleNone;
	NSInteger row = [indexPath row];
	if ([self isSongRow: row])
		return UITableViewCellEditingStyleDelete;
	else
		return UITableViewCellEditingStyleInsert;
}

// --------------------------------------------------------------------------------------------------------
- (NSIndexPath *)tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	ATRACE(@"SongListViewCtl willSelectRowAtIndexPath row=%ld ", (long)indexPath.row);
	if (_selectIndexPath)
	{
		ATRACE(@"SongListViewCtl selectIndexPath.row=%ld", (long)_selectIndexPath.row);
		//[self.tableView deselectRowAtIndexPath: selectIndexPath animated: YES];
	}
	return indexPath;
}

// --------------------------------------------------------------------------------------------------------
//	 To conform to the Human Interface Guidelines, selections should not be persistent --
//	 deselect the row after it has been selected.
- (void) tableView: (UITableView *) tableView didSelectRowAtIndexPath: (NSIndexPath *) indexPath
{	
	ATRACE(@"SongListViewCtl didSelectRowAtIndexPath row=%ld", (long)indexPath.row);

	NSInteger row = [indexPath row];
	
	if ([self isSongRow: row]) {
		self.selectIndexPath = indexPath;
		BOOL wasPlaying = [_songList isPlaying];
		Song *song = [_songList songAtIndex: (int)row];
		[_songList selectSong: song];
		if (wasPlaying) {
			[_songList play];
		}
		if (! tableView.editing) {
			ClipPlayCtl *ctl = [g_appDelegate fetchClipPlayView];
			[[self navigationController] pushViewController:ctl animated:YES];
		}
	}
	else {
        addOptionRect = [tableView rectForRowAtIndexPath: indexPath];
        [self actionAddOptions];
		//[self showMediaPicker];
	}
}

// ----------------------------------------------------------------------------------------------------------
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
    return [self isSongRow: indexPath.row];
}

// ----------------------------------------------------------------------------------------------------------
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath
{
	ATRACE(@"SongListViewCtl moveRowAtIndexPath fromIndexPath=%ld toIndexPath=%ld", (long)fromIndexPath.row, (long)toIndexPath.row);
    
    if ([self isSongRow: fromIndexPath.row] && [self isSongRow: toIndexPath.row])  {
        [_songList songAtIndex: (int)fromIndexPath.row moveTo: (int)toIndexPath.row ];
    }
    
    [self.tableView reloadData];
}

#if 0
// ----------------------------------------------------------------------------------------------------------
- (NSIndexPath *)tableView:(UITableView *)tableView targetIndexPathForMoveFromRowAtIndexPath:(NSIndexPath *)sourceIndexPath
       toProposedIndexPath:(NSIndexPath *)proposedDestinationIndexPath
{
	ATRACE(@"SongListViewCtl targetIndexPathForMoveFromRowAtIndexPath=%d proposedDestinationIndexPath=%d", sourceIndexPath.row, proposedDestinationIndexPath.row);

    if ([self isSongRow: proposedDestinationIndexPath.row])
        return proposedDestinationIndexPath;
    return [NSIndexPath indexPathWithIndex: sourceIndexPath.row];
}
#endif

// ----------------------------------------------------------------------------------------------------------
- (void)setEditing: (BOOL)editing animated:(BOOL)animated 
{
    [super setEditing:editing animated:animated];
	[self.tableView setEditing:editing animated:animated];
}

// ----------------------------------------------------------------------------------------------------------
// Update the data model according to edit actions delete or insert.
- (void)tableView: (UITableView *)aTableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle  
	forRowAtIndexPath:(NSIndexPath *)indexPath 
{
	int		row = (int)indexPath.row;
	ATRACE(@" SongListViewCtl: commitEditingStyle row=%d", row);
	
	if (editingStyle == UITableViewCellEditingStyleDelete) {
		[_songList removeSongAtIndex: row];
				
		[aTableView deleteRowsAtIndexPaths: [NSArray arrayWithObject:indexPath] withRowAnimation: UITableViewRowAnimationFade];
	}
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
// --------------------------------------------------------------------------------------------------------


@end
