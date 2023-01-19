/*

Based on  AVPlayerDemoPlaybackViewController.h Version: 1.1

*/


#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

@class PlaybackView;

@protocol PlaybackViewCtlDelegate;

// ----------------------------------------------------------------------------------------------------------
@interface PlaybackViewCtl : NSObject
{
	id <PlaybackViewCtlDelegate> __weak delegate;

	PlaybackView            *mPlaybackView;
	
	float                   mRestoreAfterScrubbingRate;
	BOOL                    seekToZeroBeforePlay;
	id                      mTimeObserver;

	NSURL                   *mURL;
    
	AVPlayer                *mPlayer;
    AVPlayerItem            *mPlayerItem;
    
    BOOL                    pendingSeek;
    NSTimeInterval          pendingSeekTime;
    
    BOOL                    assetReady;
    BOOL                    readyToPlay;
}

@property (nonatomic, weak) id <PlaybackViewCtlDelegate> delegate;

@property (nonatomic, copy) NSURL				*URL;
@property (readwrite, strong, setter=setPlayer:, getter=player) AVPlayer* mPlayer;
@property (strong) AVPlayerItem					*mPlayerItem;
@property (nonatomic, strong) PlaybackView		*mPlaybackView;

@property (nonatomic, strong) NSString			*fillMode;

- (void) play;
- (void) pause;
- (NSTimeInterval) currentTime;
- (void) setCurrentTime: (NSTimeInterval) newTime;
- (BOOL) isPlaying;
- (void) setPlaybackView: (PlaybackView*) newPlaybackView;

- (float) currentRate;
- (void) setCurrentRate: (float) newRate;

@end


// ----------------------------------------------------------------------------------------------------------
@protocol PlaybackViewCtlDelegate <NSObject>

@optional

- (void)playbackViewCtl:(PlaybackViewCtl *)playbackViewCtl seekCompleted:(NSTimeInterval )seekTime;

- (void)playbackViewCtldidReachEnd:(PlaybackViewCtl *)playbackViewCtl;

@end

// ----------------------------------------------------------------------------------------------------------
// ----------------------------------------------------------------------------------------------------------
