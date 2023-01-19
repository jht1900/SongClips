/*

*/

#define PLAYER_TYPE_PREF_KEY @"player_type_preference"
#define AUDIO_TYPE_PREF_KEY @"audio_technology_preference"

#import <UIKit/UIKit.h>
#import <MediaPlayer/MediaPlayer.h>
#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>

#import "SongListViewCtl.h"
#import "TitleView.h"

#import "AppDelegate.h"

// --------------------------------------------------------------------------------------------------------

@interface MainViewCtl : UIViewController <SongListWatcher, MPMediaPickerControllerDelegate, AVAudioPlayerDelegate> 
{
	AppDelegate					*applicationDelegate;
	IBOutlet UIBarButtonItem	*artworkItem;
	IBOutlet UILabel			*nowPlayingLabel;
	BOOL						playedMusicOnce;

	AVAudioPlayer				*appSoundPlayer;
	NSURL						*soundFileURL;
	BOOL						interruptedOnPlayback;
	BOOL						playing ;

	IBOutlet UIButton			*playPauseButton;
	
	UIBarButtonItem				*playBarButton;
	UIBarButtonItem				*pauseBarButton;
	MPMusicPlayerController		*musicPlayer;	
	
	IBOutlet UIImageView		*backArtView;
	IBOutlet UILabel			*notes;
	IBOutlet UISlider			*fScrub;
	IBOutlet UIBarButtonItem	*playPauseBtn;
	IBOutlet UIButton			*loopClipButton;
	IBOutlet UIButton			*loopSongButton;
	
	NSTimeInterval			lastTime;
	NSUInteger				lastClipIndex;
	
	TitleView				*titleView;
	
	SongList				*songList;
	
	UIImage					*albumArt;
	
	BOOL					nextShowSongs;
}

// !!@ Dead
@property (nonatomic, retain)	UILabel					*nowPlayingLabel;
@property (readwrite)			BOOL					playedMusicOnce;
@property (nonatomic, retain)	UIBarButtonItem			*playBarButton;
@property (nonatomic, retain)	UIBarButtonItem			*pauseBarButton;
@property (nonatomic, retain)	IBOutlet UIBarButtonItem	*playPauseBtn;
@property (nonatomic, retain)	IBOutlet UISlider			*fScrub;

@property (nonatomic, retain)	MPMusicPlayerController	*musicPlayer;

// Move to own class
@property (nonatomic, retain)	AVAudioPlayer			*appSoundPlayer;
@property (nonatomic, retain)	NSURL					*soundFileURL;
@property (readwrite)			BOOL					interruptedOnPlayback;
@property (readwrite)			BOOL					playing;

@property (nonatomic, retain)	IBOutlet UIButton		*playPauseButton;
@property (nonatomic, retain)	IBOutlet UIButton		*loopClipButton;
@property (nonatomic, retain)	IBOutlet UIButton		*loopSongButton;

@property (nonatomic, retain)	IBOutlet UIImageView	*backArtView;
@property (nonatomic, retain)	IBOutlet UILabel		*notes;

@property (nonatomic, retain)	UIBarButtonItem			*artworkItem;
@property (nonatomic, retain)	TitleView				*titleView;
@property (nonatomic, retain)	UIImage					*albumArt;

@property (nonatomic, assign)	BOOL					nextShowSongs;

- (IBAction) playOrPauseMusic: (id) sender;
- (IBAction) nextClipAction: (id) sender;
- (IBAction) previousClipAction: (id) sender;
- (IBAction) loopClipAction: (id) sender;
- (IBAction) loopSongAction: (id) sender;


- (IBAction) showSongsAction: (id) sender;
- (IBAction) showClipsAction: (id) sender;

- (IBAction) clickImageAction: (id) sender;

- (BOOL) useiPodPlayer;

// --------------------------------------------------------------------------------------------------------
// --------------------------------------------------------------------------------------------------------

@end
