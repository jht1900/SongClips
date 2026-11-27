/*

 
*/

#import <Foundation/Foundation.h>
#import "MainViewCtl.h"
#import "SongList.h"
#import "SongViewCtl.h"
#import "SongList.h"
#import "InfoViewCtl.h"
#import "WebViewController.h"

#define	kClipNoteUpdateInterval		(1.0)

// --------------------------------------------------------------------------------------------------------
#pragma mark Audio session callbacks_______________________

// Audio session callback function for responding to audio route changes. If playing 
//		back application audio when the headset is unplugged, this callback pauses 
//		playback and displays an alert that allows the user to resume or stop playback.
void audioRouteChangeListenerCallback (
   void                      *inUserData,
   AudioSessionPropertyID    inPropertyID,
   UInt32                    inPropertyValueSize,
   const void                *inPropertyValue
) 
{
	
	// ensure that this callback was invoked for the correct property change
	if (inPropertyID != kAudioSessionProperty_AudioRouteChange) return;

	// This callback, being outside the implementation block, needs a reference to the
	//		MainViewCtl object, which it receives in the inUserData parameter.
	//		You provide this reference when registering this callback (see the call to 
	//		AudioSessionAddPropertyListener).
	MainViewCtl *controller = (MainViewCtl *) inUserData;


	// Determines the reason for the route change, to ensure that it is not
	//		because of a category change.
	CFDictionaryRef	routeChangeDictionary = inPropertyValue;
	
	CFNumberRef routeChangeReasonRef =
						CFDictionaryGetValue (
							routeChangeDictionary,
							CFSTR (kAudioSession_AudioRouteChangeKey_Reason)
						);

	SInt32 routeChangeReason;
	
	CFNumberGetValue (
		routeChangeReasonRef,
		kCFNumberSInt32Type,
		&routeChangeReason
	);
	
	if ( routeChangeReason != kAudioSessionRouteChangeReason_CategoryChange) 
	{
		if ([controller.appSoundPlayer isPlaying]) 
		{
			CFStringRef newAudioRoute;
			UInt32 propertySize = sizeof (CFStringRef);
			
			AudioSessionGetProperty (
				kAudioSessionProperty_AudioRoute,
				&propertySize,
				&newAudioRoute
			);
			
			CFComparisonResult newDeviceIsSpeaker =	CFStringCompare (
														newAudioRoute,
														(CFStringRef) @"Speaker",
														0
													);
													
			if (newDeviceIsSpeaker == kCFCompareEqualTo) 
			{
				[controller.appSoundPlayer pause];
				NSLog (@"New audio route is %@.", newAudioRoute);

				UIAlertView *routeChangeAlertView = 
						[[UIAlertView alloc]	initWithTitle: NSLocalizedString (@"Playback Paused", @"Title for audio hardware route-changed alert view")
													  message: NSLocalizedString (@"Audio output was changed", @"Explanation for route-changed alert view")
													 delegate: controller
											cancelButtonTitle: NSLocalizedString (@"StopPlaybackAfterRouteChange", @"Stop button title")
											otherButtonTitles: NSLocalizedString (@"ResumePlaybackAfterRouteChange", @"Play button title"), nil];
				[routeChangeAlertView show];
				// release takes place in alertView:clickedButtonAtIndex: method
			
			}
			else 
			{
				NSLog (@"New audio route is %@.", newAudioRoute);
			}
		}
		else
		{
			NSLog (@"Audio route change while stopped.");
		}
	} 
	else 
	{
		NSLog (@"Audio category change.");
	}
}


// --------------------------------------------------------------------------------------------------------


@implementation MainViewCtl

@synthesize artworkItem;				// the now-playing media item's artwork image, displayed in the Navigation bar
@synthesize playBarButton;				// the button for invoking Play on the music player
@synthesize pauseBarButton;				// the button for invoking Pause on the music player
@synthesize musicPlayer;				// the music player, which plays media items from the iPod library
@synthesize nowPlayingLabel;			// descriptive text shown on the main screen about the now-playing media item
@synthesize appSoundPlayer;				// An AVAudioPlayer object for playing application sound
@synthesize soundFileURL;				// The path to the application sound
@synthesize interruptedOnPlayback;		// A flag indicating whether or not the application was interrupted during 
										//		application audio playback
@synthesize playedMusicOnce;			// A flag indicating if the user has played iPod library music at least one time
										//		since application launch.
@synthesize playing;					// An application that responds to interruptions must keep track of its playing/
										//		not-playing state.
@synthesize playPauseButton;
@synthesize loopClipButton;
@synthesize loopSongButton;

@synthesize backArtView;
@synthesize notes;
@synthesize fScrub;
@synthesize playPauseBtn;

@synthesize titleView;
@synthesize albumArt;

@synthesize nextShowSongs;

// --------------------------------------------------------------------------------------------------------
- (void)dealloc 
{
	/*
	 // This sample doesn't use libray change notifications; this code is here to show how
	 //		it's done if you need it.
	 [[NSNotificationCenter defaultCenter] removeObserver: self
	 name: MPMediaLibraryDidChangeNotification
	 object: musicPlayer];
	 
	 [[MPMediaLibrary defaultMediaLibrary] endGeneratingLibraryChangeNotifications];
	 
	 */
	[[NSNotificationCenter defaultCenter] removeObserver: self
													name: MPMusicPlayerControllerNowPlayingItemDidChangeNotification
												  object: musicPlayer];
	
	[[NSNotificationCenter defaultCenter] removeObserver: self
													name: MPMusicPlayerControllerPlaybackStateDidChangeNotification
												  object: musicPlayer];
	
	[musicPlayer endGeneratingPlaybackNotifications];
	[musicPlayer				release];
	
	[artworkItem				release]; 
	[nowPlayingLabel			release];
	[pauseBarButton				release];
	[playBarButton				release];
	[soundFileURL				release];
	
	[playPauseButton			release];
	[loopClipButton			release];
	[loopSongButton			release];
	
	[backArtView				release];
	[notes						release];
	[fScrub						release];
	[playPauseBtn				release];
	[titleView					release];
	[albumArt					release];
	
    [super dealloc];
}

// --------------------------------------------------------------------------------------------------------
#pragma mark Music control________________________________

// A toggle control for playing or pausing iPod library music playback, invoked
//		when the user taps the 'playBarButton' in the Navigation bar. 
- (IBAction) playOrPauseMusic: (id)sender
{
	MPMusicPlaybackState playbackState = [musicPlayer playbackState];

	if (playbackState == MPMusicPlaybackStatePlaying) 
	{
		[playPauseButton setTitle:@">" forState:UIControlStateNormal];
		[songList pause];
	}
	else // if (playbackState == MPMusicPlaybackStateStopped || playbackState == MPMusicPlaybackStatePaused)
	{
		[playPauseButton setTitle:@"||" forState:UIControlStateNormal];
		[songList play];
	} 
}

#if 0
// --------------------------------------------------------------------------------------------------------
- (IBAction) addSongAction: (id) sender
{
	MPMediaPickerController *picker =
	[[MPMediaPickerController alloc] initWithMediaTypes: MPMediaTypeMusic];
	
	picker.delegate						= self;
	picker.allowsPickingMultipleItems	= YES;
	picker.prompt						= NSLocalizedString (@"Add songs to play", "Prompt in media item picker");
	
	// The media item picker uses the default UI style, so it needs a default-style
	//		status bar to match it visually
	[[UIApplication sharedApplication] setStatusBarStyle: UIStatusBarStyleDefault animated: YES];
#if 1
	[[self navigationController] presentModalViewController: picker animated: YES];
#else
	[self presentModalViewController: picker animated: YES];
#endif
	[picker release];
}
#endif

// --------------------------------------------------------------------------------------------------------
// If the music player was paused, leave it paused. If it was playing, it will continue to
//		play on its own. The music player state is "stopped" only if the previous list of songs
//		had finished or if this is the first time the user has chosen songs after app 
//		launch--in which case, invoke play.
- (void) restorePlaybackState
{
	//if (musicPlayer.playbackState == MPMusicPlaybackStateStopped && userMediaItemCollection)
	if (musicPlayer.playbackState == MPMusicPlaybackStateStopped )
	{
		//[addOrShowMusicButton	setTitle: NSLocalizedString (@"Show Music", @"Alternate title for 'Add Music' button, after user has chosen some music")
		//						forState: UIControlStateNormal];
		
		if (playedMusicOnce == NO)
		{
			[self setPlayedMusicOnce: YES];
			[musicPlayer play];
		}
	}

}

// --------------------------------------------------------------------------------------------------------
#pragma mark Media item picker delegate methods________

// Invoked when the user taps the Done button in the media item picker after having chosen
//		one or more media items to play.
- (void) mediaPicker: (MPMediaPickerController *) mediaPicker didPickMediaItems: (MPMediaItemCollection *) mediaItemCollection 
{
  
	// Dismiss the media item picker.
	[self dismissModalViewControllerAnimated: YES];
	
	[songList addMediaItemCollection: mediaItemCollection ];
	
	// Apply the chosen songs to the music player's queue.
	//[self updatePlayerQueueWithMediaCollection ];

	[[UIApplication sharedApplication] setStatusBarStyle: UIStatusBarStyleBlackOpaque animated: YES];
}

// --------------------------------------------------------------------------------------------------------
// Invoked when the user taps the Done button in the media item picker having chosen zero
//		media items to play
- (void) mediaPickerDidCancel: (MPMediaPickerController *) mediaPicker 
{
	[self dismissModalViewControllerAnimated: YES];
	
	[[UIApplication sharedApplication] setStatusBarStyle: UIStatusBarStyleBlackOpaque animated: YES];
}

#pragma mark Music notification handlers__________________

// --------------------------------------------------------------------------------------------------------
- (void) updateForMediaItem: (MPMediaItem*) currentItem
{
	ATRACE2(@"MainViewCtl: updateForMediaItem currentItem=%@ ", currentItem);

	// Assume that there is no artwork for the media item.
	UIImage *artworkImage = nil;
	
	// Get the artwork from the current media item, if it has artwork.
	MPMediaItemArtwork *artwork = [currentItem valueForProperty: MPMediaItemPropertyArtwork];
	
	// Obtain a UIImage object from the MPMediaItemArtwork object
	if (artwork) 
	{
		artworkImage = [artwork imageWithSize: self.backArtView.frame.size];
		ATRACE2(@"MainViewCtl: updateForMediaItem artworkImage=%@ ", artworkImage);
	}
	// Obtain a UIButton object and set its background to the UIImage object
	UIButton *artworkView = [[[UIButton alloc] initWithFrame: CGRectMake (0, 0, 40, 40)] autorelease];
	//UIButton *artworkView = [[UIButton alloc] initWithFrame: CGRectMake (0, 0, 40, 40)];
	[artworkView setBackgroundImage: artworkImage forState: UIControlStateNormal];
	
	// Obtain a UIBarButtonItem object and initialize it with the UIButton object
	UIBarButtonItem *newArtworkItem = [[[UIBarButtonItem alloc] initWithCustomView: artworkView] autorelease];
	//UIBarButtonItem *newArtworkItem = [[UIBarButtonItem alloc] initWithCustomView: artworkView];
	[self setArtworkItem: newArtworkItem];

	[artworkView addTarget:self action:@selector(showClipsAction:) forControlEvents:UIControlEventTouchUpInside];
	//[artworkView addTarget:self action:@selector(showSongsAction:) forControlEvents:UIControlEventTouchUpInside];

	// !!@@ ??
	// [artworkView release];
	
	//[artworkItem setEnabled: YES];
	
	// Display the new media item artwork
	[self.navigationItem setLeftBarButtonItem: artworkItem animated: YES];
	
	self.backArtView.image = artworkImage;
	
	self.albumArt = artworkImage;
	
	Song	*song = [songList currentSong] ;
	ATRACE2(@"MainViewCtl: song=%@ ", song);
	self.titleView.fTop.text = song.label;
	self.titleView.fBottom.text = [NSString stringWithFormat: @"%@ - %@", song.artist, song.albumTitle];
	ATRACE2(@"MainViewCtl: titleView.fTop.text=%@ ", titleView.fTop.text);
}

// --------------------------------------------------------------------------------------------------------
// When the now-playing item changes, update the media item artwork and the now-playing label.
- (void) handle_NowPlayingItemChanged: (id) notification 
{
	ATRACE2(@"MainViewCtl: handle_NowPlayingItemChanged notification=%@ ", notification);
	MPMediaItem *currentItem = [musicPlayer nowPlayingItem];
	
	ATRACE2(@"MainViewCtl: handle_NowPlayingItemChanged ");

	if (currentItem)
	{
		[self updateForMediaItem: currentItem];
	}
}

// --------------------------------------------------------------------------------------------------------
// When the playback state changes, set the play/pause button in the Navigation bar
//		appropriately.
- (void) handle_PlaybackStateChanged: (id) notification 
{
	MPMusicPlaybackState playbackState = [musicPlayer playbackState];

	ATRACE2(@"MainViewCtl: handle_PlaybackStateChanged playbackState=%d ", playbackState);
	
	if (playbackState == MPMusicPlaybackStatePaused) 
	{
		[playPauseButton setTitle:@">" forState:UIControlStateNormal];
	}
	else
	{
		[playPauseButton setTitle:@"||" forState:UIControlStateNormal];
	}
}

// --------------------------------------------------------------------------------------------------------
- (void) handle_iPodLibraryChanged: (id) notification 
{
	// Implement this method to update cached collections of media items when the 
	// user performs a sync while your application is running. This sample performs 
	// no explicit media queries, so there is nothing to update.
	
	ATRACE(@"MainViewCtl: handle_iPodLibraryChanged notification=%@ ", notification);
}

#pragma mark Application playback control_________________

// --------------------------------------------------------------------------------------------------------
// delegate method for the audio route change alert view; follows the protocol specified
//	in the UIAlertViewDelegate protocol.
- (void) alertView: routeChangeAlertView clickedButtonAtIndex: buttonIndex 
{
	if ((NSInteger) buttonIndex == 1)
	{
		[appSoundPlayer play];
	} 
	else 
	{
		[appSoundPlayer setCurrentTime: 0];
		//[appSoundButton setEnabled: YES];
	}
	
	[routeChangeAlertView release];			
}

#pragma mark AV Foundation delegate methods____________

// --------------------------------------------------------------------------------------------------------
- (void) audioPlayerDidFinishPlaying: (AVAudioPlayer *) appSoundPlayer successfully: (BOOL) flag 
{
	playing = NO;
	//[appSoundButton setEnabled: YES];
}

// --------------------------------------------------------------------------------------------------------
- (void) audioPlayerBeginInterruption: player
{
	ATRACE(@"Interrupted. The system has stopped audio playback.");
	
	if (playing) 
	{
		[appSoundPlayer pause];
		playing = NO;
		interruptedOnPlayback = YES;
	}
}

// --------------------------------------------------------------------------------------------------------
- (void) audioPlayerEndInterruption: player 
{
	ATRACE(@"Interruption ended. Resuming audio playback.");
	
	// Reactivates the audio session, whether or not audio was playing
	//		when the interruption arrived.
	[[AVAudioSession sharedInstance] setActive: YES error: nil];
	
	if (interruptedOnPlayback) 
	{
		[appSoundPlayer prepareToPlay];
		[appSoundPlayer play];
		playing = YES;
		interruptedOnPlayback = NO;
	}
}

#pragma mark Application setup____________________________

#if TARGET_IPHONE_SIMULATOR
#warning *** Simulator mode: iPod library access works only when running on a device.
#endif

// --------------------------------------------------------------------------------------------------------
- (void) setupApplicationAudio 
{
#if 0
	// Gets the file system path to the sound to play.
	NSString *soundFilePath = [[NSBundle mainBundle]	pathForResource:	@"sound"
														ofType:				@"caf"];

	// Converts the sound's file path to an NSURL object
	if (soundFilePath)
	{
		NSURL *newURL = [[NSURL alloc] initFileURLWithPath: soundFilePath];
		self.soundFileURL = newURL;
		[newURL release];
	}
	// Registers this class as the delegate of the audio session.
	[[AVAudioSession sharedInstance] setDelegate: self];
	
	// The AmbientSound category allows application audio to mix with Media Player
	// audio. The category also indicates that application audio should stop playing 
	// if the Ring/Siilent switch is set to "silent" or the screen locks.
	[[AVAudioSession sharedInstance] setCategory: AVAudioSessionCategoryAmbient error: nil];

	// Registers the audio route change listener callback function
	AudioSessionAddPropertyListener (
		kAudioSessionProperty_AudioRouteChange,
		audioRouteChangeListenerCallback,
		self
	);

	// Activates the audio session.
	[[AVAudioSession sharedInstance] setActive: YES error: nil];

	// Instantiates the AVAudioPlayer object, initializing it with the sound
	AVAudioPlayer *newPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL: soundFileURL error: nil];
	self.appSoundPlayer = newPlayer;
	[newPlayer release];
	
	// "Preparing to play" attaches to the audio hardware and ensures that playback
	//		starts quickly when the user taps Play
	[appSoundPlayer prepareToPlay];
	[appSoundPlayer setVolume: 1.0];
	[appSoundPlayer setDelegate: self];
#endif
}


// --------------------------------------------------------------------------------------------------------
// To learn about notifications, see "Notifications" in Cocoa Fundamentals Guide.
- (void) registerForMediaPlayerNotifications 
{
	NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];

	[notificationCenter addObserver: self
						   selector: @selector (handle_NowPlayingItemChanged:)
							   name: MPMusicPlayerControllerNowPlayingItemDidChangeNotification
							 object: musicPlayer];
	
	[notificationCenter addObserver: self
						   selector: @selector (handle_PlaybackStateChanged:)
							   name: MPMusicPlayerControllerPlaybackStateDidChangeNotification
							 object: musicPlayer];

/*
	// This sample doesn't use libray change notifications; this code is here to show how
	//		it's done if you need it.
	[notificationCenter addObserver: self
						   selector: @selector (handle_iPodLibraryChanged:)
							   name: MPMediaLibraryDidChangeNotification
							 object: musicPlayer];
	
	[[MPMediaLibrary defaultMediaLibrary] beginGeneratingLibraryChangeNotifications];
*/

	[musicPlayer beginGeneratingPlaybackNotifications];
}


// To learn about the Settings bundle and user preferences, see User Defaults Programming Topics
//		for Cocoa and "The Settings Bundle" in iPhone Application Programming Guide 

// --------------------------------------------------------------------------------------------------------
// Returns whether or not to use the iPod music player instead of the application music player.
- (BOOL) useiPodPlayer 
{
	if ([[NSUserDefaults standardUserDefaults] boolForKey: PLAYER_TYPE_PREF_KEY])
	{
		return YES;		
	}
	else 
	{
		return NO;
	}		
}

// ----------------------------------------------------------------------------------------------------------
// user clicked the "i" button
- (IBAction)infoAction:(id)sender
{
	InfoViewCtl *controller = [[InfoViewCtl alloc] initWithNibName: @"InfoView" bundle: nil];
	
	[[self navigationController] pushViewController:controller animated:YES];
	
	controller.title = [[AppDelegate default] appName];
	
	[controller release];
}

// --------------------------------------------------------------------------------------------------------
// Configure the application.
- (void) viewDidLoad
{
	ATRACE(@"MainViewCtl: viewDidLoad");
    [super viewDidLoad];
	
	songList = [SongList default];
	
	//self.title = @"ClipSong";
	
	// create a custom navigation bar button and set it to always say "Back"
	UIBarButtonItem *temporaryBarButtonItem = [[[UIBarButtonItem alloc] init] autorelease];
	temporaryBarButtonItem.title = @"Back";
	self.navigationItem.backBarButtonItem = temporaryBarButtonItem;
	
	self.titleView = [[TitleView alloc] autorelease];
	[[NSBundle mainBundle] loadNibNamed:@"TitleView" owner:titleView options:nil];
	[titleView initWithFrame: CGRectMake(0, 0, 240, 40)];
	self.navigationItem.titleView = self.titleView;
	ATRACE2(@"MainViewCtl: titleView=%@", titleView);

	UIButton* settingsViewButton = [UIButton buttonWithType:UIButtonTypeInfoLight];
	[settingsViewButton addTarget:self action:@selector(infoAction:) forControlEvents:UIControlEventTouchUpInside];
	UIBarButtonItem *infoButton = [[[UIBarButtonItem alloc] initWithCustomView:settingsViewButton] autorelease];
	self.navigationItem.rightBarButtonItem = infoButton;

#if 0
	[self setupApplicationAudio];
	
	[self setPlayedMusicOnce: NO];
#endif
	
	// Instantiate the music player. If you specied the iPod music player in the Settings app,
	//		honor the current state of the built-in iPod app.
	if ([self useiPodPlayer]) 
	{
		[self setMusicPlayer: [MPMusicPlayerController iPodMusicPlayer]];
		
		if ([musicPlayer nowPlayingItem])
		{
			//[self navigationController].navigationBar.topItem.leftBarButtonItem.enabled = YES;
			
			// Update the UI to reflect the now-playing item. 
			[self handle_NowPlayingItemChanged: nil];
			
			if ([musicPlayer playbackState] == MPMusicPlaybackStatePaused)
			{
				//[self navigationController].navigationBar.topItem.leftBarButtonItem = pauseBarButton;
			}
		}
	} 
	else 
	{
		[self setMusicPlayer: [MPMusicPlayerController applicationMusicPlayer]];
		
		// By default, an application music player takes on the shuffle and repeat modes
		//		of the built-in iPod app. Here they are both turned off.
		[musicPlayer setShuffleMode: MPMusicShuffleModeOff];
		[musicPlayer setRepeatMode: MPMusicRepeatModeNone];
	}	

	[self registerForMediaPlayerNotifications];

	[songList setMusicPlayer: musicPlayer];
}

// --------------------------------------------------------------------------------------------------------
- (void)viewWillAppear:(BOOL)animated
{
	ATRACE2(@"MainViewCtl viewWillAppear");
	
	[super viewWillAppear: animated];
		
	songList.delegate = self;
	
	lastClipIndex = -1;
	
	[self reportSongChange];
}

// --------------------------------------------------------------------------------------------------------
- (void) viewWillDisappear:(BOOL)animated
{
	ATRACE(@"MainViewCtl viewWillDisappear");

	[super viewWillDisappear: animated];
	
	songList.delegate = nil;
}

// --------------------------------------------------------------------------------------------------------
- (void) viewDidAppear: (BOOL)animated
{
	ATRACE(@"MainViewCtl viewDidAppear");
	
	[super viewDidAppear: animated];
	
	if (nextShowSongs)
	{
		nextShowSongs = NO;
		[self showSongsAction: nil];
	}
}

#pragma mark SongListWatcher delegate____________________________

// --------------------------------------------------------------------------------------------------------
- (void) reportSongChange
{
	ATRACE(@"MainViewCtl reportSongChange");
	
	Song *song = [songList currentSong];
	if (! song)
		return;
	
	[self updateForMediaItem: song.mediaItem];
	
	// Force update
	lastClipIndex = -1;
	[self timeReport: [songList currentTime]];
}

// --------------------------------------------------------------------------------------------------------
// Track song. Show clip notation
- (void)timeReport: (NSTimeInterval) newTime 
{
	ATRACE2(@"MainViewCtl timeReport: newTime=%f", newTime);
	NSUInteger		index = -1;
	NSString		*newNoteText = @"";
	UIImage			*newClipImage = nil;
	Song			*song = [songList currentSong];
	NSTimeInterval	now = [NSDate timeIntervalSinceReferenceDate];
	
	ATRACE2(@"MainViewCtl timeReport: song=%@", song);
	if (song)
	{
		index = [song clipIndexForTime: newTime];
		ATRACE2(@"MainViewCtl timeReport: index=%d clip=%@", index, clip);
		
		Clip *clip = [song clipAtIndex: index];
		if (clip)
		{
			newNoteText = clip.notation;
			newClipImage = clip.image;
			//newClipImage = [song imageForClipIndex: index];
		}
	}
	
	// Only update clip notes if clip has changed AND enought time passed
	ATRACE2(@"MainViewCtl timeReport: index=%d lastClipIndex=%d newTime=%f ", index, lastClipIndex, newTime);
	
	if (index == lastClipIndex)
		return;
	if (now - lastTime < kClipNoteUpdateInterval)
		return;
	lastClipIndex = index;
	lastTime = now;
	
	notes.text = newNoteText;
	ATRACE2(@"MainViewCtl timeReport: newTime=%f index=%d", newTime, index);
	
	if (newClipImage)
	{
		if (0)
		{
			#define	ANIMATION_DURATION_SECONDS	1.0
			UIViewAnimationTransition transition = UIViewAnimationTransitionFlipFromRight;
			[UIView beginAnimations: nil context: NULL];
			[UIView setAnimationDuration: ANIMATION_DURATION_SECONDS];
			[UIView setAnimationTransition: transition forView: self.backArtView cache: NO];
		}
		
		self.backArtView.image = newClipImage;
		
		if (0)
		{
			[UIView commitAnimations];	
		}
	}
	else
	{
		self.backArtView.image = albumArt;
	}
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
	// e.g. self.myOutlet = nil;
}

// --------------------------------------------------------------------------------------------------------
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
	return YES;
}

// --------------------------------------------------------------------------------------------------------
// Bring up clips for current Song or create Song and show clips
- (IBAction) showClipsAction: (id)sender
{
	ATRACE(@"MainViewCtl: clipsAction");
	
	//NSUInteger index = [songList currentSongIndex];
	
	Song *song = [songList currentSong];
	
	if (song)
	{
		//[songList playSongAt: index];
		
		SongViewCtl *ctl = [[SongViewCtl alloc] initWithNibName: @"SongView" bundle: nil];
		
		ctl.song = song;
		[[self navigationController] pushViewController:ctl animated:YES];
		
		[ctl release];
	}
}

// --------------------------------------------------------------------------------------------------------
- (IBAction) showSongsAction: (id) sender
{
	SongListViewCtl *controller = [[SongListViewCtl alloc] initWithNibName: @"SongListView" bundle: nil];
	//controller.delegate = self;
	
	[[self navigationController] pushViewController:controller animated:YES];
	
	[controller release];
}

// ----------------------------------------------------------------------------------------------------------
- (IBAction) nextClipAction: (id) sender
{
	NSUInteger	index = [songList currentClipIndex];
	Song		*song = [songList currentSong];

	ATRACE(@"MainViewCtl: nextClipAction index=%d", index);
	
	if (! song)
		return;
	if (index >= [song clipCount]-1)
	{
		// !!@ next song
		return;
	}
	NSTimeInterval clipStartTime = [song clipAtIndex: index+1].startTime;
	
	[songList setCurrentTime: clipStartTime ];
	
	lastClipIndex = -1;
	[self timeReport: clipStartTime];
}

// ----------------------------------------------------------------------------------------------------------
- (IBAction) previousClipAction: (id) sender
{
	NSUInteger	index = [songList currentClipIndex];
	Song		*song = [songList currentSong];
	
	ATRACE(@"MainViewCtl: previousClipAction index=%d", index);
	
	if (! song)
		return;
	
	if (index <= 0)
	{
		// !!@ previous song
		return;
	}
	NSTimeInterval clipStartTime = [song clipAtIndex: index-1].startTime;
	
	[songList setCurrentTime: clipStartTime ];
	
	lastClipIndex = -1;
	[self timeReport: clipStartTime];
}

// ----------------------------------------------------------------------------------------------------------
- (IBAction) loopClipAction: (id) sender
{
}

// ----------------------------------------------------------------------------------------------------------
- (IBAction) loopSongAction: (id) sender
{
}

// ----------------------------------------------------------------------------------------------------------
- (IBAction) clickImageAction: (id) sender
{
	ATRACE(@"MainViewCtl: clickImageAction");
	
	Song			*song = [songList currentSong];
	NSTimeInterval	newTime = [songList currentTime];
	NSUInteger		index = -1;
	NSString		*linkRef;
	
	ATRACE2(@"  song=%@", song);
	if (song)
	{
		index = [song clipIndexForTime: newTime];
		ATRACE2(@"   index=%d clip=%@", index, clip);
		
		Clip *clip = [song clipAtIndex: index];
		if (clip)
		{
			linkRef = clip.linkRef;
			if (linkRef)
			{
				[WebViewController showUrlString: linkRef nav: self];
			}
		}
	}
}

// --------------------------------------------------------------------------------------------------------
// --------------------------------------------------------------------------------------------------------




@end
