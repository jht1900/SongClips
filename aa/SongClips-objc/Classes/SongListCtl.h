/*
 Copyright (C) 2008 John Henry Thompson. All Rights Reserved.
 */

#import "SongList.h"
#import <MediaPlayer/MediaPlayer.h>
#import "AssetBrowserController.h"
#import "EP_JGActionSheet.h"

// --------------------------------------------------------------------------------------------------------

@interface SongListCtl : UITableViewController 
	<MPMediaPickerControllerDelegate, 
	UITableViewDelegate,
	EP_JGActionSheetDelegate,
    AssetBrowserControllerDelegate>
{
	int					openSiteButtonIndex;
	int					addMusicButtonIndex;
	int					addVideoButtonIndex;
	int					addPasteButtonIndex;
	int					addSiteButtonIndex;
    CGRect              addOptionRect;
}

@property (nonatomic, weak) SongList			*songList;
@property (nonatomic, strong) NSIndexPath		*selectIndexPath;
@property (nonatomic, strong) EP_JGActionSheet	*actionSheet;
@property (nonatomic, assign) BOOL				doAdd;

- (void) showMediaPicker;

- (void) accessUrlStr: (NSString *)urlStr;

- (void) becomeActive;

@end

// --------------------------------------------------------------------------------------------------------


// --------------------------------------------------------------------------------------------------------
// --------------------------------------------------------------------------------------------------------
