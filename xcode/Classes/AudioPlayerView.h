/*

*/
#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

// --------------------------------------------------------------------------------------------------------

@protocol AudioPlayerDelegate;

// --------------------------------------------------------------------------------------------------------
@interface AudioPlayerView : NSObject <AVAudioPlayerDelegate>
{
	id <AudioPlayerDelegate> delegate;

}

@property (nonatomic, assign) id <AudioPlayerDelegate> delegate;

@property (nonatomic, retain)	UISlider				*fScrub;
@property (nonatomic, retain)	IBOutlet UIButton		*playPauseButton;
@property (nonatomic, retain)	IBOutlet UIButton		*loopClipButton;

@property (nonatomic, retain)	IBOutlet UILabel		*fclipnum;
@property (nonatomic, retain)	IBOutlet UILabel		*fduration;
@property (nonatomic, retain)	IBOutlet UILabel		*fduration2;

@property (nonatomic, retain)	IBOutlet UIButton		*showClipsButton;

- (IBAction) playOrPauseMusic: (id) sender;
- (IBAction) nextClipAction: (id) sender;
- (IBAction) previousClipAction: (id) sender;
- (IBAction) loopClipAction: (id) sender;

- (IBAction) showClipsAction: (id) sender;


@end


// --------------------------------------------------------------------------------------------------------

@protocol AudioPlayerDelegate <NSObject>

@optional

- (void) audioDone: (AudioPlayerView*) apc;

- (void) playOrPauseMusic: (AudioPlayerView*) sender;
- (void) nextClipAction: (AudioPlayerView*) sender;
- (void) previousClipAction: (AudioPlayerView*) sender;
- (void) loopClipAction: (AudioPlayerView*) sender;

- (void) showClipsAction: (AudioPlayerView*) sender;

@end


// --------------------------------------------------------------------------------------------------------
