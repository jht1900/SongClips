/*
 Copyright (C) 2008 John Henry Thompson. All Rights Reserved.
 */

#import <Foundation/Foundation.h>
#import <MediaPlayer/MediaPlayer.h>

#import "Song.h"
#import "Cache.h"

#import "PlaybackViewCtl.h"

@protocol SongListWatcher;

// --------------------------------------------------------------------------------------------------------
@interface SongList : NSObject <PlaybackViewCtlDelegate>
{	
	NSMutableArray		*list;	// array of Song*
	int                 nextSongID;
	int                         currentSongIndex;
	NSTimeInterval				clipStartTime;
	NSTimeInterval				lastTimeSync;
	NSTimeInterval				lastCurrentPlayTimeSync;
	NSTimeInterval				timeCurrentTimeSet;
	
	BOOL				missingMediaItem;
	BOOL				missingMediaIsPlaying;
	NSTimeInterval		missingMediaOffsetTime;
	NSTimeInterval		missingMediaCurrentTime;
    
    int                 lastClipIndex;
	NSTimeInterval      lastClipStart;
	NSTimeInterval      lastClipDuration;
    
    BOOL                playModePause;
    NSTimeInterval      playModePauseOffsetTime;
    
    BOOL                seekIssuedDuringPlay;
    NSTimeInterval      seekIssuedDuringPlayTime;
    
	BOOL				userDefSyncNeeded;
    BOOL                playRequested;
    BOOL                previousClipIssued;
	
	BOOL				speed_shift_enabled;
	NSTimeInterval      speed_shift_start_time;
	int					speed_shift_index;
}

@property (nonatomic, weak) id <SongListWatcher>		delegate;

@property (nonatomic, strong) PlaybackViewCtl			*avPlayerCtl;
@property (nonatomic, strong) PlaybackView				*playbackView;
@property (nonatomic, strong) MPMusicPlayerController	*musicPlayer;
@property (nonatomic, strong) NSTimer					*updateTimer;
@property (nonatomic, readonly) Cache					*imageCache;
@property (nonatomic, readonly) Cache					*imageIconCache;

@property (nonatomic, assign) NSTimeInterval			currentTime;
@property (nonatomic, assign) int						playMode;
@property (nonatomic, assign) BOOL						useAVPlayer;
@property (nonatomic, assign) BOOL						dirty;

+ (SongList*)default;

+ (void) releaseStatic;

+ (void) resumeFromDisk;

- (void) setDelegate:(id<SongListWatcher>)delegate view: (PlaybackView*) view;

- (void) clearDelegate;

- (Song*) importSongFromString: (NSString *) str intoSong: (Song*) intoSong;

- (void) saveToDisk;

- (void) createSongForMediaItem: (MPMediaItem*) newMediaItem;

- (void) addMediaItemCollection: (MPMediaItemCollection *) mediaItemCollection;

- (void) removeSongAtIndex: (int) index;

- (void) removeSong: (Song*)song;

- (Song*) songAtIndex: (int) index;

- (void) songAtIndex: (int) fromIndex moveTo: (int) toIndex;

- (int) songCount;

- (void) playSongAt: (int) index;

- (void) play;

- (void) pause;

- (void) setCurrentRate: (float) newRate;

- (void) setClipStartTime: (NSTimeInterval) newTime;

- (Song*) currentSong;

- (int) currentSongIndex;

- (int) currentClipIndex;

- (NSString*) nextSongFileName: (NSString*) preFix;

- (void) reportCurrentTime;

- (void) reportSongChange;

- (void) selectSong: (Song *) newSong;

- (BOOL) isPlaying;

#if APP_KDHANUMAN
- (void) selectSongKD: (Song *) newSong;
#endif

- (void) willResignActive;

- (void) becomeActive;

- (void) nextClip;

- (void) previousClip;

- (void) establishClipForCurrentTime;

- (void) establishClipLastClipIndex: (int) index;

- (BOOL) isVideo;

- (void) speed_shift_monitor: (Song*) song;

@end

// --------------------------------------------------------------------------------------------------------
@protocol SongListWatcher <NSObject>

@optional

- (void) timeReport: (NSTimeInterval) newTime ;

- (void) reportSongChange;

- (BOOL) isTracking;

@end

// --------------------------------------------------------------------------------------------------------

enum
{
	kClipPlayModeNone = 0,
	kClipPlayModeContinue,
    kClipPlayModeRepeat,
    kClipPlayModePause,
    kClipPlayModePauseContinue,
    kClipPlayModePauseRepeat,
};

// --------------------------------------------------------------------------------------------------------
// --------------------------------------------------------------------------------------------------------
