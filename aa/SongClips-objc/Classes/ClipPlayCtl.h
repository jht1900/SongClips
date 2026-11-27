/*
 Copyright (C) 2008 John Henry Thompson. All Rights Reserved.
 */

#import <UIKit/UIKit.h>
#import <MediaPlayer/MediaPlayer.h>
#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>

#import "SongListCtl.h"
#import "TitleView.h"
#import "AppDelegate.h"
#import	"Access.h"
#import "ClipPlayModeCtl.h"
#import "AssetBrowserController.h"

@class PlaybackView;

// --------------------------------------------------------------------------------------------------------

@interface ClipPlayCtl : UIViewController <
	SongListWatcher,
	ClipPlayModeCtlDelegate,
	AssetBrowserControllerDelegate,
	AccessDelegate,
	MPMediaPickerControllerDelegate, 
	AVAudioPlayerDelegate, 	UIActionSheetDelegate,
	MPMediaPickerControllerDelegate,
	UIAlertViewDelegate,
	UITextViewDelegate,
	UINavigationControllerDelegate,
	UIImagePickerControllerDelegate,
	UIPopoverControllerDelegate
>
{
	SongList				*songList;
	Access					*access;

	int						lastSongIndex;
	int						lastClipIndex;
	NSTimeInterval			lastTime;
	NSTimeInterval			lastClipStart;
	NSTimeInterval			lastClipDuration;
	int						lastClipCount;
	NSTimeInterval			lastSongDuration;
	
	BOOL					loopClip;
	BOOL					loopSong;
	BOOL					scrubDownSceen;
	BOOL					playing;
	BOOL					showSongShown;
	BOOL					editMode;
	BOOL					savePending;
	BOOL					ui_hidden;
	BOOL					ui_hidden_triggered;
	BOOL					download_active;
}

@property (nonatomic, strong) IBOutlet PlaybackView		*avplayer;
@property (nonatomic, strong) IBOutlet UISlider			*fScrub;
@property (nonatomic, strong) IBOutlet UIButton			*playPauseButton;
@property (nonatomic, strong) IBOutlet UIButton			*loopClipButton;
@property (nonatomic, strong) IBOutlet UILabel			*fclipnum;
@property (nonatomic, strong) IBOutlet UILabel			*fduration;
@property (nonatomic, strong) IBOutlet UILabel			*fduration2;
@property (nonatomic, strong) IBOutlet UIBarButtonItem	*artworkItem;
@property (nonatomic, strong) IBOutlet UIImageView		*backArtView;
@property (nonatomic, strong) IBOutlet UITextView		*notes;
@property (nonatomic, strong) IBOutlet UIView			*containerView;
@property (nonatomic, strong) IBOutlet UIView			*controls;
@property (nonatomic, strong) IBOutlet UIImageView		*fImageView;
@property (nonatomic, strong) IBOutlet UIView			*fNotesContainer;
@property (nonatomic, strong) IBOutlet UITextView		*fNotes;
@property (nonatomic, strong) IBOutlet UIView			*fAddPhoto;
@property (nonatomic, strong) IBOutlet UIView			*fEditBlock;
@property (nonatomic, strong) IBOutlet UIButton			*fCameraButton;
@property (nonatomic, strong) IBOutlet UIButton			*fPhotoButton;

@property (nonatomic, strong) UIBarButtonItem		*customEditButton;
@property (nonatomic, strong) TitleView				*titleView;
@property (nonatomic, strong) UIImage				*albumArt;
@property (nonatomic, strong) UIPopoverController   *popOver;
@property (nonatomic, strong) UIActionSheet			*actionSheet;
@property (nonatomic, strong) UIAlertView			*alertView;

@property (nonatomic, strong) NSString				*lastSongFileName;
@property (nonatomic, strong) Song					*importSong;

@property (nonatomic, assign) BOOL					selectReplacementForCurrentSongPending;
@property (nonatomic, assign) BOOL					checkSongMissingMediaPending;


- (IBAction) playOrPauseMusic: (id) sender;
- (IBAction) nextClipAction: (id) sender;
- (IBAction) previousClipAction: (id) sender;
- (IBAction) loopClipAction: (id) sender;
- (IBAction) showSongsAction: (id) sender;
- (IBAction) editClipAction: (id) sender;
- (IBAction) clickImageAction: (id) sender;
- (IBAction) actionMerge: (id)sender;
- (IBAction) actionSplit: (id)sender;
- (IBAction) actionPhoto: (id)sender;
- (IBAction) actionCamera: (id)sender;

- (void) accessUrlStr: (NSString *)urlStr;

- (BOOL) checkSongMissingMedia;

- (Song *) currentSong;

- (void) selectReplacementForCurrentSong;

- (void) download_forSong: (Song*) newSong;

// --------------------------------------------------------------------------------------------------------
// --------------------------------------------------------------------------------------------------------

@end
