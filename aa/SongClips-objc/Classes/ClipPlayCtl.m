/*
 Copyright (C) 2008 John Henry Thompson. All Rights Reserved.
 */

#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>
#import "ClipPlayCtl.h"
#import "SongList.h"
#import "ClipListCtl.h"
#import "SongList.h"
#import "InfoViewCtl.h"
#import "WebViewController.h"
#import "SongListCtl.h"
#import "AppUtil.h"
#import "MissingViewCtl.h"
#import "PlaybackView.h"
#import "ClipEditCtl.h"
#import "ClipPlayModeCtl.h"
#import "AssetBrowserController.h"
#import "DD_FileFTP.h"
#import "DD_HTTPManager.h"
#import "UtilPath.h"

//#define	kClipNoteUpdateInterval		(0.5)
#define	kClipNoteUpdateInterval		(0.2)
#define kClipNoteUpdateInterval_Hold	(1.0)

static NSTimeInterval	g_ClipNoteUpdateInterval = kClipNoteUpdateInterval;

@interface ClipPlayCtl () <DD_HTTPManagerDelegate >
{
}
@end

// --------------------------------------------------------------------------------------------------------

@implementation ClipPlayCtl

// --------------------------------------------------------------------------------------------------------
- (void)dealloc 
{
    access.delegate = nil;
}

// --------------------------------------------------------------------------------------------------------
- (void) httpm_downdload: (DD_HTTPManager *) httpm bytesSoFar: (SInt64)bytesSoFar
{
	ATRACE2(@"ClipPlayCtl downLoadFileBytesSoFar bytesSoFar=%lld", bytesSoFar);
	NSString *msg = [NSString stringWithFormat:@"Downloading %@", [AppUtil formatDoubleBytes: bytesSoFar]];
	_titleView.fTop.text = [httpm downloadFileName];
	_titleView.fBottom.text = msg;
	download_active = YES;
}

- (void) httpm_done: (DD_HTTPManager *) httpm
{
	ATRACE(@"ClipPlayCtl operationDone");
	_titleView.fBottom.text = @"Download done";
	g_ClipNoteUpdateInterval = kClipNoteUpdateInterval_Hold;
	[self performSelector: @selector(download_active_clear) withObject:nil afterDelay:kClipNoteUpdateInterval_Hold];
	//download_active = NO;
}

- (void) download_active_clear
{
	download_active = NO;
	[self showTitle];
}

// --------------------------------------------------------------------------------------------------------
#pragma mark Music control________________________________

- (IBAction) playOrPauseMusic: (id)sender
{	
	playing = ! songList.isPlaying;
	[self reflect_playing];
}

// --------------------------------------------------------------------------------------------------------
- (void) reflect_playing
{
	if (! playing) {
		//[playPauseButton setTitle:@">" forState:UIControlStateNormal];
		[songList pause];
    }
	else {
		//[playPauseButton setTitle:@"||" forState:UIControlStateNormal];
		[songList play];
	}
	_playPauseButton.selected = playing;
}

// --------------------------------------------------------------------------------------------------------
// If the music player was paused, leave it paused. If it was playing, it will continue to
//		play on its own. The music player state is "stopped" only if the previous list of songs
//		had finished or if this is the first time the user has chosen songs after app 
//		launch--in which case, invoke play.
- (void) restorePlaybackState
{
	if (songList.musicPlayer.playbackState == MPMusicPlaybackStateStopped ) {
#if 0
		if (playedMusicOnce == NO) {
			[self setPlayedMusicOnce: YES];
			[musicPlayer play];
		}
#endif
	}

}

#pragma mark Music notification handlers__________________

// --------------------------------------------------------------------------------------------------------
- (void) newBackArt: (UIImage*) newArtworkItem
{
	if (newArtworkItem != _backArtView.image) {
		ATRACE2(@"ClipPlayCtl: newBackArt newArtworkItem=%@ _backArtView.image=%@", newArtworkItem, _backArtView.image);

		[self performTransition];
	
		_backArtView.image = newArtworkItem;
	}
}

// --------------------------------------------------------------------------------------------------------
- (void) updateCurPos
{
	float		factor = _fScrub.value;
	float		pos = lastClipDuration * factor;
	_fduration.text = [AppUtil formatRunningTimeUI: pos ];
}

// --------------------------------------------------------------------------------------------------------
- (void) showClipJump: (BOOL) jump
{
    Song    *song = [songList currentSong];
	_titleView.fBottom.text = [NSString stringWithFormat:@"Editing Clip %d of %d", lastClipIndex+1, [song clipCount]];
	Clip	*clip = [song clipAtIndex: lastClipIndex ];
    ATRACE(@"ClipEditCtl showClip clipIndex=%d startTime=%f", lastClipIndex, clip.startTime );
    
	lastClipStart = clip.startTime;
	lastClipDuration = clip.subDuration;
	_fNotes.text = clip.notation;
	_fclipnum.text = [NSString stringWithFormat:@"Clip %d of %d", lastClipIndex+1, [song clipCount]];
	_fduration2.text = [NSString stringWithFormat:@"Clip %@", [AppUtil formatDurationUI: lastClipDuration ]];
	_fImageView.image = clip.image;
    
	[self updateCurPos];

	[songList setClipStartTime: lastClipStart];
	if (jump) {
		songList.currentTime = lastClipStart;
	}
}

// --------------------------------------------------------------------------------------------------------
- (void) showClipJump
{
    [self showClipJump: YES];
}

// --------------------------------------------------------------------------------------------------------
// Display current, clipIndex, clip settings in UI
- (void) showClip
{
    [self showClipJump: NO];
}

// --------------------------------------------------------------------------------------------------------
- (void) showTitle
{
	// Give time for download status to show
	if (download_active) return;
	
    Song	*song = [songList currentSong] ;
	_titleView.fTop.text = song.label;
    
    if (editMode) {
        int     clipIndex = [songList currentClipIndex];
        _titleView.fBottom.text = [NSString stringWithFormat:@"Editing Clip %d of %d", clipIndex+1, [song clipCount]];
    }
    else {
        _titleView.fBottom.text = [NSString stringWithFormat: @"%@ - %@", song.artist?song.artist: @"", song.albumTitle?song.albumTitle:@""];
    }
}

// --------------------------------------------------------------------------------------------------------
- (void) updateForMediaItem: (MPMediaItem*) currentItem
{
	ATRACE2(@"ClipPlayCtl: updateForMediaItem currentItem=%@ ", currentItem);

	// Assume that there is no artwork for the media item.
	UIImage *artworkImage = nil;
	UIImage *artworkImageForBack = nil;
	
	// Get the artwork from the current media item, if it has artwork.
	MPMediaItemArtwork *artwork = [currentItem valueForProperty: MPMediaItemPropertyArtwork];
	ATRACE(@"ClipPlayCtl: updateForMediaItem artwork=%@ ", artwork);
	
    // Attempt to fix size of icon
    CGFloat dim = 40;
    
	// Obtain a UIImage object from the MPMediaItemArtwork object
	if (artwork) {
//        artworkImage = [artwork imageWithSize: _backArtView.frame.size];
//        artworkImageForBack = artworkImage;
        // !!@ 2023 explict small size of icom artwork image
        artworkImage = [artwork imageWithSize: CGSizeMake(dim, dim)];
        artworkImageForBack =  [artwork imageWithSize: _backArtView.frame.size];
		CGRect rt = [artwork bounds];
		ATRACE(@"ClipPlayCtl: updateForMediaItem artworkImage=%@ bounds=%f %f", artworkImage, rt.size.width, rt.size.height );
		if (rt.size.width <= 0.0 ) {
			artworkImageForBack = [UIImage imageNamed: @"no_artwork.png"];
			artworkImage = [UIImage imageNamed: @"Default-Retina.png"];
		}
	}
	else {
		artworkImageForBack = [UIImage imageNamed: @"no_artwork.png"];
	}
	// Obtain a UIButton object and set its background to the UIImage object
	UIButton *artworkView = [[UIButton alloc] initWithFrame: CGRectMake (0, 0, dim, dim)];
//    [artworkView setBackgroundImage: artworkImageForBack forState: UIControlStateNormal];
    [artworkView setBackgroundImage: artworkImage forState: UIControlStateNormal];

	// Obtain a UIBarButtonItem object and initialize it with the UIButton object
	UIBarButtonItem *newArtworkItem = [[UIBarButtonItem alloc] initWithCustomView: artworkView];
    // !!@ 2023 temp
//    [self setArtworkItem: newArtworkItem];
    // set enables back image! sometimes
    self.artworkItem = newArtworkItem;

	[artworkView addTarget:self action:@selector(showSongsAction:) forControlEvents:UIControlEventTouchUpInside];
	
	// Display the new media item artwork
    // !!@ 2023 temp
//	[self.navigationItem setLeftBarButtonItem: _artworkItem animated: YES];
    // Disable to show left arrow in place of distorted art image
//    self.navigationItem.leftBarButtonItem = _artworkItem;

    [self newBackArt: artworkImageForBack];
//    [self newBackArt: artworkImage];

//    _albumArt = artworkImage;
    _albumArt = artworkImageForBack;

    [self showTitle];
}

// --------------------------------------------------------------------------------------------------------
- (void) noSong
{
	self.navigationItem.leftBarButtonItem = nil;
	_backArtView.image = [UIImage imageNamed:@"Default.png"];
	_titleView.fTop.text = @"";
	_titleView.fBottom.text = @"";
	_notes.text = @"";
	_fScrub.value = 0.0;
	_fclipnum.text = @"";
	_fduration.text = @"";
	_fduration2.text = @"";
}

// --------------------------------------------------------------------------------------------------------
// When the now-playing item changes, update the media item artwork and the now-playing label.
- (void) handle_NowPlayingItemChanged: (id) notification 
{
	ATRACE2(@"ClipPlayCtl: handle_NowPlayingItemChanged notification=%@ ", notification);
	MPMediaItem *currentItem = [songList.musicPlayer nowPlayingItem];
	ATRACE2(@"ClipPlayCtl: handle_NowPlayingItemChanged ");

	if (currentItem) {
		[self updateForMediaItem: currentItem];
	}
	else {
		//[self noSong];
	}
}

// ----------------------------------------------------------------------------------------------------------
// user clicked the "i" button
- (IBAction)infoAction:(id)sender
{
	InfoViewCtl *controller = [[InfoViewCtl alloc] initWithNibName: @"InfoView" bundle: nil];
	[[self navigationController] pushViewController:controller animated:YES];
	
	controller.title = [[AppDelegate default] appNameVersion];
}

// --------------------------------------------------------------------------------------------------------
// Configure the application.
- (void) viewDidLoad
{
	ATRACE(@"ClipPlayCtl: viewDidLoad bounds=%@", NSStringFromCGRect(self.view.bounds));
	ATRACE(@"ClipPlayCtl: viewDidLoad containerView.bounds=%@", NSStringFromCGRect(_containerView.bounds));
	ATRACE2(@"ClipPlayCtl: viewDidLoad fScrub=%@", fScrub);
    [super viewDidLoad];
	
	songList = [SongList default];
	
	_titleView = [TitleView alloc];
    NSString *nibName = g_appDelegate.ipadMode? @"TitleView-iPad" : @"TitleView";
	[[NSBundle mainBundle] loadNibNamed:nibName owner:_titleView options:nil];
	_titleView = [_titleView initWithFrame: CGRectMake(0, 0, g_appDelegate.ipadMode? 688: 240, 40)];
	self.navigationItem.titleView = _titleView;
	ATRACE2(@"ClipPlayCtl: titleView=%@", titleView);

	_customEditButton = [[UIBarButtonItem alloc] initWithTitle: @"Clips"
                                      style: UIBarButtonItemStylePlain
                                     target: self
                                     action: @selector(showClipsListAction:)];
	self.navigationItem.rightBarButtonItem = _customEditButton;
    
	[_fScrub addTarget:self action:@selector(scrubChangeAction:) forControlEvents:UIControlEventValueChanged];
	[_fScrub addTarget:self action:@selector(scrubTouchUpAction:) forControlEvents:UIControlEventTouchUpInside];
	[_fScrub addTarget:self action:@selector(scrubTouchDownAction:) forControlEvents:UIControlEventTouchDown];
}

// --------------------------------------------------------------------------------------------------------
- (IBAction) showClipsListAction: (id)sender
{
	ATRACE(@"ClipPlayCtl: showClipsListAction");
    
	Song *song = [songList currentSong];
	if (song) {
		ClipListCtl *ctl = [[ClipListCtl alloc] initWithNibName: @"SongView" bundle: nil];
		ctl.song = song;
		[[self navigationController] pushViewController:ctl animated:YES];
	}
}

// --------------------------------------------------------------------------------------------------------
- (void)viewWillAppear:(BOOL)animated
{
	ATRACE(@"ClipPlayCtl viewWillAppear");
	
	[super viewWillAppear: animated];
		
	[songList setDelegate: self view: _avplayer];
    
	lastClipIndex = -1;
	
	_fNotes.delegate = self;
}

// --------------------------------------------------------------------------------------------------------
- (void) viewWillDisappear:(BOOL)animated
{
	ATRACE(@"ClipPlayCtl viewWillDisappear");

	[super viewWillDisappear: animated];
	
    //[songList clearDelegate];
}

// --------------------------------------------------------------------------------------------------------
- (void) viewDidAppear: (BOOL)animated
{
	ATRACE(@"ClipPlayCtl viewDidAppear g_appDelegate.pendingAccessUrlStr=%@", g_appDelegate.pendingAccessUrlStr);
	
	[super viewDidAppear: animated];
	
	if (g_appDelegate.pendingAccessUrlStr) {
		NSString *urlStr = g_appDelegate.pendingAccessUrlStr;
		g_appDelegate.pendingAccessUrlStr = nil;
		[self accessUrlStr: urlStr];
		
		ATRACE(@"ClipPlayCtl viewDidAppear AFTER g_appDelegate.pendingAccessUrlStr=%@", g_appDelegate.pendingAccessUrlStr);
		
		return;
	}
	if (_selectReplacementForCurrentSongPending) {
		_selectReplacementForCurrentSongPending = NO;
		[self selectReplacementForCurrentSong];
		return;
	}
	if (_checkSongMissingMediaPending) {
		_checkSongMissingMediaPending = NO;
		[self checkSongMissingMedia];
	}
	Song *song = [songList currentSong];
	if (! song.title && ! _alertView) {
		ATRACE(@"ClipPlayCtl nil song.title=%@", song.title);
		//NSString *msg = [@"Import songclips from " stringByAppendingString: song.clipsSourceRef];
		NSString *msg = song.clipsSourceRef;
		_alertView =  [[UIAlertView alloc] initWithTitle: @"Import SongClips"
								   message: msg
								  delegate: self
						 cancelButtonTitle: @"Cancel" 
						 otherButtonTitles: @"Import", nil];
		[_alertView show];
        return;
	}
    [self refreshView];
}

#pragma mark SongListWatcher delegate____________________________

// --------------------------------------------------------------------------------------------------------
- (void) reportSongChange
{
	ATRACE(@"ClipPlayCtl reportSongChange song=%@", [songList currentSong]);
	
	Song *song = [songList currentSong];
	if (! song) {
		[self noSong];
		return;
	}
	[self updateForMediaItem: song.s_mediaItem];
	
	// Force update
	lastClipIndex = -1;
	[self timeReport: [songList currentTime]];
}

// --------------------------------------------------------------------------------------------------------
- (void) performTransition
{
	// First create a CATransition object to describe the transition
	CATransition *transition = [CATransition animation];

	// Animate over duration in seconds
	transition.duration = 1.0;

	transition.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];

	transition.type = kCATransitionFade;
	
	// Next add it to the containerView's layer. This will perform the transition based on how we change its contents.
	[_containerView.layer addAnimation:transition forKey:nil];
}

// --------------------------------------------------------------------------------------------------------
- (void)reportToScrub: (NSTimeInterval) newTime
{
	double			ratio = 0.0;
	
	// Only if no user not dragging slider:
	if (_fScrub.tracking)
		return;
	
	if (! editMode) {
        if (lastSongDuration > 0.0) {
            ratio = newTime / lastSongDuration;
        }
        _fScrub.value = ratio;
    }
    else {
        ratio = (newTime - lastClipStart);
        if (lastClipDuration > 0.0) {
            ratio = ratio / lastClipDuration;
            
            _fScrub.value = ratio;
            
            [self updateCurPos];
        }
    }
}

// --------------------------------------------------------------------------------------------------------
- (void) playbackStateChanged
{
    if (_playPauseButton.selected != songList.isPlaying) {
        ATRACE(@"ClipPlayCtl playbackStateChanged: playPauseButton.selected=%d songList.isPlaying=%d", _playPauseButton.selected, songList.isPlaying);
    }
	_playPauseButton.selected = songList.isPlaying;
}

// --------------------------------------------------------------------------------------------------------
- (BOOL) isTracking
{
    return _fScrub.tracking;
}

// --------------------------------------------------------------------------------------------------------
// Track song. Show clip notation
- (void)timeReport: (NSTimeInterval) newTime 
{
	ATRACE2(@"ClipPlayCtl timeReport: newTime=%f", newTime);
	int				index = 0;
	NSString		*newNoteText = @"";
	UIImage			*newClipImage = nil;
	Song			*song = [songList currentSong];
	NSTimeInterval	now = [NSDate timeIntervalSinceReferenceDate];
	
	ATRACE2(@"ClipPlayCtl timeReport: song=%@", song);
	
	lastSongDuration = [song duration];
	
	[self reportToScrub: newTime];
	    
	if (song) {
		lastClipCount = [song clipCount];
		index = [song clipIndexForTime: newTime];
		ATRACE2(@"ClipPlayCtl timeReport: index=%d clip=%@", index, clip);
		
		Clip *clip = [song clipAtIndex: index];
		if (clip) {
			newNoteText = clip.notation;
			newClipImage = clip.image;
            lastClipStart = clip.startTime;
			lastClipDuration = clip.subDuration;
		}
		[songList speed_shift_monitor: song];
	}
	else {
		// No current song
		[self noSong];
		return;
	}
	
	if (! _lastSongFileName || ![_lastSongFileName isEqualToString: song.s_store_name]) {
		// Force switch
		lastClipIndex = -2;
	}
	// Only update clip notes if clip has changed AND enough time passed
	ATRACE2(@"ClipPlayCtl timeReport: index=%d lastClipIndex=%d newTime=%f ", index, lastClipIndex, newTime);
	
    BOOL updatedNeeded = index != lastClipIndex;
	if (!updatedNeeded && now - lastTime < g_ClipNoteUpdateInterval)
		return;
	
	g_ClipNoteUpdateInterval = kClipNoteUpdateInterval;
	
	lastTime = now;

	[self playbackStateChanged];

	if (updatedNeeded) {
        ATRACE(@"ClipPlayCtl timeReport: newTime=%f index=%d lastClipIndex=%d", newTime, index, lastClipIndex);

		_lastSongFileName = song.s_store_name;
		lastClipIndex = index;
		
        [songList establishClipLastClipIndex: lastClipIndex];
        
        if (editMode) {
			[self showClip];
        }
        else {
			_notes.text = newNoteText;
			
			if (! newClipImage) {
				newClipImage = _albumArt;
			}
			[self newBackArt: newClipImage];
			
			_fclipnum.text = [NSString stringWithFormat:@"Clip %d of %d", lastClipIndex+1, lastClipCount];
			
			_fduration2.text = [NSString stringWithFormat:@"Song %@", [AppUtil formatDurationUI: song.duration]];
        }
	}
    if (! editMode) {
        _fduration.text = [AppUtil formatRunningTimeUI: songList.currentTime];
    }
    else {
        [self updateCurPos];
    }

	if ( ! songList.isPlaying && ! song.pause_on_load && ! ui_hidden_triggered) {
		[self performSelector: @selector(play_and_ui_hide_needed) withObject:nil afterDelay:1.0];
	}
}

// --------------------------------------------------------------------------------------------------------
- (void) play_and_ui_hide_needed
{
	ATRACE(@"ClipPlayCtl play_and_ui_hide_needed: ui_hidden=%d", ui_hidden);

	if (! ui_hidden) {
		ui_hidden = YES;
		[self reflect_ui_hidden];
	}
	playing = YES;
	[self reflect_playing];
	ui_hidden_triggered = YES;
}

#pragma mark Application state management_____________

// --------------------------------------------------------------------------------------------------------
- (void) didReceiveMemoryWarning
{
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
	
	// Release any cached data, images, etc that aren't in use.
}


// --------------------------------------------------------------------------------------------------------
- (void) viewDidUnload 
{
	// Release any retained subviews of the main view.
	// e.g. _myOutlet = nil;
}

// --------------------------------------------------------------------------------------------------------
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
	return YES;
}

// ----------------------------------------------------------------------------------------------------------
- (void) showClipEditorForClipIndex: (int) index
{
	Song *song = [songList currentSong];
	NSString *nibName = (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) ? @"ClipEditCtl-iPad" : @"ClipEditCtl";
	ClipEditCtl *ctl = [[ClipEditCtl alloc] initWithNibName: nibName bundle: nil];
	ctl.clipIndex = index;
	ctl.song = song;
	ctl.flowToClip = ([songList currentClipIndex] == index);
	[[self navigationController] pushViewController:ctl animated:YES];
}

// --------------------------------------------------------------------------------------------------------
- (IBAction)actionMerge: (id)sender
{
    [self saveActionPending];
    
    Song *song = [songList currentSong];
	[song removeClipAtIndex: lastClipIndex];
	if (lastClipIndex > 0)
		lastClipIndex--;
	
	[self showClipJump];
}

// --------------------------------------------------------------------------------------------------------
- (IBAction)actionSplit: (id)sender
{
    [self saveActionPending];
    
	NSTimeInterval	newSubDuration = songList.currentTime - lastClipStart;
    Song *song = [songList currentSong];
	[song splitClipAtIndex: lastClipIndex newSubDuration: newSubDuration ];
	
	if (lastClipIndex < [song clipCount]-1) {
		lastClipIndex++;
	}
	
	[self showClipJump];
}

// --------------------------------------------------------------------------------------------------------
#pragma mark -
#pragma mark <UITextViewDelegate> Methods

// --------------------------------------------------------------------------------------------------------
- (BOOL)textFieldShouldBeginEditing:(UITextView *)textV
{
	ATRACE(@"ClipEditCtl textFieldShouldBeginEditing" );
	return YES;
}

// --------------------------------------------------------------------------------------------------------
- (void)textViewDidBeginEditing:(UITextView *)textView
{
	ATRACE(@"ClipEditCtl textViewDidBeginEditing" );
    
	// provide my own Save button to dismiss the keyboard
	UIBarButtonItem* saveItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem: UIBarButtonSystemItemDone
                                                  target: self
                                                  action: @selector(saveAction:)];
	self.navigationItem.rightBarButtonItem = saveItem;
	    
    savePending = YES;
}

// --------------------------------------------------------------------------------------------------------
- (void) saveActionPending
{
    if (savePending) {
        [self saveAction: nil];
    }
}

// --------------------------------------------------------------------------------------------------------
- (void)saveAction:(id)sender
{
	ATRACE(@"ClipEditCtl saveAction" );
    
	// finish typing text/dismiss the keyboard by removing it as the first responder
	[_fNotes resignFirstResponder];
	
	self.navigationItem.rightBarButtonItem = _customEditButton;	// this will remove the "save" button
	
	[self saveClip];
    
    savePending = NO;
}

// --------------------------------------------------------------------------------------------------------
// Save info back into clip
- (void) saveClip
{
    Song    *song = [songList currentSong];
	Clip	*clip = [song clipAtIndex: lastClipIndex ];
	clip.notation = _fNotes.text;
	
	[self saveSongToDisk];
    
    savePending = NO;
}

// --------------------------------------------------------------------------------------------------------
- (void) saveSongToDisk
{
    Song    *song = [songList currentSong];
    song.currentPos = [songList currentTime];
    
    [song saveToDisk];
}

// --------------------------------------------------------------------------------------------------------
- (void) refreshView
{
	ATRACE(@"ClipEditCtl refreshView" );

	lastSongDuration = [[songList currentSong] duration];

    _fImageView.hidden = !editMode;
    _fNotesContainer.hidden = !editMode;
    _fNotes.hidden = !editMode;
    _fEditBlock.hidden = !editMode;
    _containerView.hidden = editMode;
    _notes.hidden = editMode;
    _fAddPhoto.hidden = YES;
    
    if (editMode) {
        [self showClip];
        
        if (! songList.isVideo) {
            BOOL hasCamera = [UIImagePickerController isSourceTypeAvailable: UIImagePickerControllerSourceTypeCamera];
            BOOL hasPhotoLib = [UIImagePickerController isSourceTypeAvailable: UIImagePickerControllerSourceTypePhotoLibrary];
            _fCameraButton.hidden = !hasCamera;
            _fPhotoButton.hidden =  !hasPhotoLib;
            _fAddPhoto.hidden = !hasCamera && !hasPhotoLib;
        }
    }
    else {
        [self reportSongChange];
        
        [self showTitle];
    }    
}

// --------------------------------------------------------------------------------------------------------
// Bring up clips for current Song or create Song and show clips
- (IBAction) editClipAction: (id)sender
{
	ATRACE(@"ClipPlayCtl: clipsAction");
    
    editMode = ! editMode;
    
    [self refreshView];
}

// --------------------------------------------------------------------------------------------------------
- (IBAction) showSongsAction: (id) sender
{
	[[self navigationController] popViewControllerAnimated: YES];
	
	//[self showSongsDoAdd: NO];
}

// ----------------------------------------------------------------------------------------------------------
- (void) timeReportFresh: (NSTimeInterval) clipStartTime
{
	ATRACE(@"ClipPlayCtl: timeReportFresh clipStartTime=%f", clipStartTime);

	[songList setCurrentTime: clipStartTime ];

	lastTime = [[NSDate distantPast] timeIntervalSinceReferenceDate];
	lastClipIndex = -1;
	[self timeReport: clipStartTime];
}

// ----------------------------------------------------------------------------------------------------------
- (IBAction) nextClipAction: (id) sender
{
    [self saveActionPending];

    [songList nextClip];
}

// ----------------------------------------------------------------------------------------------------------
- (IBAction) previousClipAction: (id) sender
{
    [self saveActionPending];

    [songList previousClip];
}

// ----------------------------------------------------------------------------------------------------------
- (void)done_ClipPlayModeCtl:(ClipPlayModeCtl *)ctl
{
    [_popOver dismissPopoverAnimated:YES];
}

// ----------------------------------------------------------------------------------------------------------
- (IBAction) loopClipAction: (id) sender
{
#if 1
	ClipPlayModeCtl *ctl = [[ClipPlayModeCtl alloc] initWithNibName: @"ClipPlayModeView" bundle: nil];
	
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        UINavigationController *navCtl = [[UINavigationController alloc] initWithRootViewController:ctl];
        UIPopoverController *popCtl = [[UIPopoverController alloc] initWithContentViewController:navCtl];
        _popOver = popCtl;
        
        ctl.isModal = YES;
        ctl.delegate = self;
        
        //  popOverRect set by verb_actionSheet
        [_popOver presentPopoverFromRect:_loopClipButton.bounds inView: _loopClipButton permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES];
    }
    else {
        [[self navigationController] pushViewController:ctl animated:YES];
	}
#endif
#if 0
	loopClip = ! loopClip;
	ATRACE(@"ClipPlayCtl: loopClipAction loopClip=%d isHighlighted=%d", loopClip, [loopClipButton isHighlighted]);
	if (loopClip) {
		//[loopClipButton setTitle:@"[Loop]" forState:UIControlStateNormal];
	}
	else {
		//[loopClipButton setTitle:@"-Loop-" forState:UIControlStateNormal];
	}
	loopClipButton.highlighted = loopClip;
	loopClipButton.selected = loopClip;
	
	[self setupClipLoop];
#endif
}

// ----------------------------------------------------------------------------------------------------------
- (void) reflect_ui_hidden
{
	[[self navigationController] setNavigationBarHidden: ui_hidden animated: NO];
	if (ui_hidden) [[UIApplication sharedApplication] setStatusBarHidden: ui_hidden withAnimation: UIStatusBarAnimationNone];
	_controls.hidden = ui_hidden;
	_notes.hidden = ui_hidden;
}

// ----------------------------------------------------------------------------------------------------------
- (IBAction) clickImageAction: (id) sender
{
	ATRACE(@"ClipPlayCtl: clickImageAction");
	Song			*song = [songList currentSong];
	NSTimeInterval	newTime = [songList currentTime];
	int             index = -1;
	NSString		*linkRef;
	NSString		*webRef;
    
    // Clicking on image hides/shows ui
    ui_hidden = ! ui_hidden;
	[self reflect_ui_hidden];
	
    ATRACE2(@"  song=%@", song);
	if (song) {
		index = [song clipIndexForTime: newTime];
		ATRACE2(@"   index=%d clip=%@", index, clip);
		Clip *clip = [song clipAtIndex: index];
		if (clip) {
			linkRef = clip.linkRef;
			if (linkRef) {
				[WebViewController showUrlString: linkRef nav: self];
			}
            webRef = clip.webRef;
            if (webRef) {
				[g_appDelegate openInBrowser: webRef];
            }
		}
	}
	else {
		// [self showSongsDoAdd: YES];
	}
}

// --------------------------------------------------------------------------------------------------------
// Slider has changed value
- (void)scrubChangeAction:(id)sender
{
	ATRACE(@"ClipPlayCtl scrubChangeAction fScrub.value=%f", _fScrub.value );
}

// --------------------------------------------------------------------------------------------------------
- (void)scrubTouchDownAction: (id)sender
{
	ATRACE(@"ClipPlayCtl scrubTouchDownAction fScrub.value=%f", _fScrub.value );
	scrubDownSceen = YES;
}

// --------------------------------------------------------------------------------------------------------
- (void)scrubTouchUpAction:(id)sender
{
	ATRACE2(@"ClipPlayCtl scrubTouchUpAction fScrub.value=%f", fScrub.value );
	
	// Only allow one up action, we are getting 2 in normal guesturing
	if (! scrubDownSceen)
		return;
	scrubDownSceen = NO;
	
	// Reposition player from slider
    if (! editMode) {
        NSTimeInterval newTime = lastSongDuration * _fScrub.value;
        songList.currentTime = newTime;
        ATRACE2(@"ClipPlayCtl: scrubChangeAction fScrub.value=%f newTime=%f", fScrub.value, newTime );
    }
	else {
        NSTimeInterval newTime = lastClipStart + lastClipDuration * _fScrub.value;
        songList.currentTime = newTime;
        ATRACE2(@"ClipEditCtl scrubChangeAction fScrub.value=%f newTime=%f", fScrub.value, newTime );
        
        [self updateCurPos];
    }
}

// --------------------------------------------------------------------------------------------------------
- (void) accessUrlStr: (NSString *)urlStr
{
	if (! access) {
		ATRACE(@"ClipPlayCtl: requesting urlStr=%@", urlStr);
		
		access = [[Access alloc] init];
		access.delegate = self;
		[access sendOp: urlStr];

		ATRACE(@"ClipPlayCtl: RETURN requesting urlStr=%@", urlStr);
	}
}

// ----------------------------------------------------------------------------------------------------------
// Done with http request
- (void) accessDone
{
	ATRACE(@"ClipPlayCtl: accessDone ");
	
	access.delegate = nil;
	access = nil;
}

// ----------------------------------------------------------------------------------------------------------
- (void) access:(Access*)access err:(NSString*)errMsg
{
	ATRACE(@"AppDelegate: access errMsg=%@", errMsg);
	
	[self accessDone];
}

// ----------------------------------------------------------------------------------------------------------
- (void) access:(Access*)access done:(NSData*)resultData
{
	ATRACE(@"ClipPlayCtl access done resultData len=%lu", (unsigned long)[resultData length]);
	
	[self accessDone];

	NSString	*str = [[NSString alloc] initWithData: resultData encoding: NSUTF8StringEncoding];
	Song *newSong = [[SongList default] importSongFromString: str intoSong: _importSong];
	
	_importSong = nil;
	
	DD_RemoteSite *remoteSite = [DD_RemoteSite new];
	remoteSite.site_username = K_dsite_uname;
	remoteSite.site_password = K_dsite_pword;
	remoteSite.site_realm = K_dsite_realm;

	if (newSong.init_deferred) {
		NSURL *url = [NSURL URLWithString:newSong.sourceForLocal];
		if (newSong.source_stream) {
			[remoteSite preparePlayMovieUrl: url ];
			newSong.s_url = url;
			ATRACE(@"ClipPlayCtl source_stream newSong.s_url=%@", newSong.s_url);
			[self init_newSong: newSong];
		}
		else {
			[self download_newSong: newSong remoteSite: remoteSite url: url];
		}
	}
	else {
		[self setup_newSong: newSong];
	}
}

// ----------------------------------------------------------------------------------------------------------
- (void) download_forSong: (Song*) newSong
{
	ATRACE(@"ClipPlayCtl download_forSong newSong.s_url=%@", newSong.s_url);
	
	[self self_on_top];
	
	DD_RemoteSite *remoteSite = [DD_RemoteSite new];
	remoteSite.site_username = K_dsite_uname;
	remoteSite.site_password = K_dsite_pword;
	remoteSite.site_realm = K_dsite_realm;

	NSURL *url = [NSURL URLWithString:newSong.sourceForLocal];

	[self download_newSong: newSong remoteSite: remoteSite url: url];
}

// ----------------------------------------------------------------------------------------------------------
- (void) download_newSong: (Song*) newSong remoteSite: (DD_RemoteSite*) remoteSite url: (NSURL *) url
{
	DD_FileFTP *file_tp = [DD_FileFTP new];
	
	NSString *path = [url path];
	if (! path) path = @"failed/failed.m4v";
	
	NSString *fpath = [[@"/" stringByAppendingPathComponent: [newSong store_name]] stringByAppendingPathComponent: K_song_media_file_prefix];
	fpath = [fpath stringByAppendingString: [path lastPathComponent]];
	
	file_tp.source = newSong.sourceForLocal; // http://j4u2.com/songclips/songs/ashtanga-jht-301/clips/0001.m4v
	file_tp.path = [fpath stringByDeletingLastPathComponent];
	file_tp.fileName = [fpath lastPathComponent];
	file_tp.modDate = [NSDate date];
	
	DD_HTTPManager *http_man = [DD_HTTPManager new];
	http_man.destRoot = localStoreRoot();
	http_man.path = file_tp.path;
	http_man.remoteSite = remoteSite;
	http_man.delegate = self;
	
	NSString *localPath = [localStoreRoot() stringByAppendingPathComponent: file_tp.path];
	localPath = [localPath stringByAppendingPathComponent: file_tp.fileName];
	NSString *partialPath = file_tp.path;
	partialPath = [partialPath stringByAppendingPathComponent: file_tp.fileName];
	newSong.s_url = [NSURL fileURLWithPath: localPath];
	newSong.partialPath = partialPath;
	ATRACE(@"ClipPlayCtl access done s_url=%@ localPath=%@	", newSong.s_url, localPath );
	
	__weak __typeof(self) weakSelf = self;
	[http_man downLoadFile:file_tp fileOffset:0 pathHome:@"" doneBlock: ^{
		[weakSelf init_newSong: newSong];
	}];
}

// ----------------------------------------------------------------------------------------------------------
- (void) init_newSong: (Song*) newSong
{
	ATRACE(@"ClipPlayCtl init_newSong newSong.s_url=%@", newSong.s_url);
	newSong.init_deferred = NO;
	[newSong initForLocal];
	[self setup_newSong: newSong];
}

// ----------------------------------------------------------------------------------------------------------
- (void) setup_newSong: (Song*) newSong
{
	[[SongList default] selectSong: newSong];

	// Rewind to begining of song
	[self timeReportFresh: 0.0];
	
	// Pop to the top
	[self self_on_top];
	
//	if (! [self checkSongMissingMedia: newSong] && newSong.clipCount) {
//		[AppUtil showMsg: [NSString stringWithFormat:@"Received %d clips for %@", newSong.clipCount, newSong.title]
//				   title: @"Imported" ];
//	}
}

- (void) self_on_top
{
	// Pop to the top
	while (self != [[self navigationController]  topViewController]) {
		[[self navigationController] popViewControllerAnimated:NO];
	}
}

// ----------------------------------------------------------------------------------------------------------
- (BOOL) checkSongMissingMedia: (Song *) song
{
	ATRACE(@"ClipPlayCtl: checkSongMissingMedia pendingAccessUrlStr=%@", g_appDelegate.pendingAccessUrlStr);
	
	[song queryForMediaItem];
	
	if (song.mediaMissing && song.sourceRef && ! song.mediaMissingShown) {
		song.mediaMissingShown = YES;
		NSString *nibName = g_appDelegate.ipadMode ? @"MissingViewCtl-iPad" : @"MissingViewCtl";
		MissingViewCtl* missingCtl = [[MissingViewCtl alloc] initWithNibName: nibName bundle: nil];
		
		[self presentViewController:missingCtl animated:YES completion:nil];
		return YES;
	}
	else {
		return NO;
	}
}

// ----------------------------------------------------------------------------------------------------------
- (BOOL) checkSongMissingMedia
{
	return [self checkSongMissingMedia: [songList currentSong]];
}

// --------------------------------------------------------------------------------------------------------
- (Song *) currentSong
{
	return songList.currentSong;
}

// --------------------------------------------------------------------------------------------------------
- (void) selectReplacementForCurrentSong
{
	ATRACE(@"ClipPlayCtl: selectReplacementForCurrentSong");

    if (songList.isVideo) {
        AssetBrowserController *browser =
        [[AssetBrowserController alloc] initWithSourceType:AssetBrowserSourceTypeIPodLibrary modalPresentation:NO];
        
        browser.delegate = self;
        browser.forTitle = @"Select Replacement Video";
        
        [[self navigationController] pushViewController:browser animated:YES];
    }
    else {
        MPMediaPickerController *picker = [[MPMediaPickerController alloc] initWithMediaTypes: MPMediaTypeAny];
        ATRACE(@"ClipPlayCtl: MPMediaPickerController picker=%@", picker);
       
        if (! picker) {
            ATRACE(@"ClipPlayCtl: no MPMediaPickerController");
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
		
		[[SongList default] selectSong: song];
		
		[self reportSongChange];
	}
}

// ----------------------------------------------------------------------------------------------------------
- (void)assetBrowser:(AssetBrowserController *)assetBrowser didChooseItem:(AssetBrowserItem *)assetBrowserItem
{
	ATRACE(@"ClipPlayCtl: assetBrowser didChooseItem=%@", assetBrowserItem);
	ATRACE(@"ClipPlayCtl: assetBrowser URL=%@", assetBrowserItem.URL);
	ATRACE(@"ClipPlayCtl: assetBrowser mediaItem=%@", assetBrowserItem.mediaItem);
            
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
		ATRACE(@"ClipPlayCtl: no newMediaItems for currentSong=%@", songList.currentSong);
		return;
	}
	MPMediaItem *mediaItem = newMediaItems[ 0];
	
	ATRACE(@"ClipPlayCtl: applyReplacement currentSong=%@ mediaItem=%@", songList.currentSong, mediaItem);

    [self replaceCurrentSongMedia: mediaItem];
}

// --------------------------------------------------------------------------------------------------------
// Responds to the user tapping done having chosen no music.
- (void) mediaPickerDidCancel: (MPMediaPickerController *) mediaPicker 
{
    [mediaPicker dismissViewControllerAnimated:YES completion:nil];
	
	[[UIApplication sharedApplication] setStatusBarStyle: UIStatusBarStyleBlackOpaque animated:YES];
}

// --------------------------------------------------------------------------------------------------------
- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
	ATRACE(@"ClipPlayCtl clickedButtonAtIndex buttonIndex=%ld", (long)buttonIndex);
	_alertView = nil;
	if (buttonIndex == 1) {
		Song	*song = songList.currentSong;
		NSString *urlStr = song.clipsSourceRef;
		_importSong = song;
		[self accessUrlStr: urlStr];
	}
}

// --------------------------------------------------------------------------------------------------------
- (IBAction)imagePickForType: (UIImagePickerControllerSourceType) type btn: (UIView*) btn
{
	UIImagePickerController	*ctl;
	
	if (! [UIImagePickerController isSourceTypeAvailable: type])
		return;
	ctl = [[UIImagePickerController alloc] init];
	ctl.allowsEditing = YES;
	ctl.delegate = self;
	ctl.sourceType = type;
	if (g_appDelegate.ipadMode) {
		UIPopoverController* aPopover = [[UIPopoverController alloc] initWithContentViewController: ctl];
		[aPopover presentPopoverFromRect: btn.bounds inView: btn
                permittedArrowDirections: UIPopoverArrowDirectionAny
                                animated: YES];
		aPopover.delegate = self;
		_popOver = aPopover;
	}
	else {
		//ctl.allowsImageEditing = YES;
		//[[self navigationController] presentModalViewController:ctl animated:YES];
        [[self navigationController] presentViewController:ctl animated:YES completion:nil];
	}
}

// --------------------------------------------------------------------------------------------------------
- (void)popoverControllerDidDismissPopover:(UIPopoverController *)popoverController
{
	ATRACE(@"ClipEditCtl popoverControllerDidDismissPopover" );
}

// --------------------------------------------------------------------------------------------------------
- (BOOL)popoverControllerShouldDismissPopover:(UIPopoverController *)popoverController
{
	ATRACE(@"ClipEditCtl popoverControllerShouldDismissPopover" );
	return YES;
}

// --------------------------------------------------------------------------------------------------------
- (IBAction)actionPhoto: (id)sender
{
	[self imagePickForType: UIImagePickerControllerSourceTypePhotoLibrary btn: _fPhotoButton];
}

// --------------------------------------------------------------------------------------------------------
- (IBAction)actionCamera: (id)sender
{
	[self imagePickForType: UIImagePickerControllerSourceTypeCamera btn: _fCameraButton];
}

// --------------------------------------------------------------------------------------------------------
- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{
	UIImage		*newImage = [info objectForKey: UIImagePickerControllerEditedImage];
	
	ATRACE(@"ClipEditCtl imagePickerController newImage=%@", newImage );
	
    Song *song = [songList currentSong];
    
	[song saveNewImage: newImage forClipIndex: lastClipIndex];
    
	Clip *clip = [song clipAtIndex: lastClipIndex];
	
	_fImageView.image = clip.image;
	
	//[self dismissModalViewControllerAnimated: YES];
    [self dismissViewControllerAnimated:YES completion:nil];
	
	[_popOver dismissPopoverAnimated: YES];
	_popOver = nil;
}


// --------------------------------------------------------------------------------------------------------
- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker
{
	//[self dismissModalViewControllerAnimated: YES];
    [self dismissViewControllerAnimated:YES completion:nil];
}


// --------------------------------------------------------------------------------------------------------
// --------------------------------------------------------------------------------------------------------




@end
