/*
 Copyright (C) 2008 John Henry Thompson. All Rights Reserved.
 */

#import "SongList.h"
#import "AppDelegate.h"
#import "AppDefs.h"

#import "PlaybackViewCtl.h"
#import "PlaybackView.h"

static SongList* default1 = 0;

//#define kTimerInterval		0.1
#define kTimerInterval		0.1

// Check for sync and update currentTime at this interval
#define kSyncUpdateInterval	1.0

#define kPreviousClipRestartWindow  1.0

@implementation SongList

// ----------------------------------------------------------------------------------------------------------
- (void)dealloc
{
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
	[nc removeObserver: self
                  name: MPMusicPlayerControllerNowPlayingItemDidChangeNotification
                object: _musicPlayer];
	[nc removeObserver: self
                  name: MPMusicPlayerControllerPlaybackStateDidChangeNotification
                object: _musicPlayer];
    
	[nc removeObserver: self
                  name: UIApplicationWillResignActiveNotification
                object: nil];
	[nc removeObserver: self
                  name: UIApplicationDidBecomeActiveNotification
                object: nil];
	[_updateTimer invalidate];
}

// ----------------------------------------------------------------------------------------------------------
- (id)init
{
	self = [super init];
	if (self) {
		list = [[NSMutableArray alloc] init];
		
		_imageCache = [[Cache alloc] init] ;
		_imageCache.allowance = kMaxCacheImage;
		
		_imageIconCache = [[Cache alloc] init];
		_imageIconCache.allowance = kMaxCacheImageIcon;
		
		[self setupMusicPlayer];
        
	    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
        [nc addObserver: self
               selector: @selector(willResignActive)
                   name: UIApplicationWillResignActiveNotification
                 object: nil];
        [nc addObserver: self
               selector: @selector(becomeActive)
                   name: UIApplicationDidBecomeActiveNotification
                 object: nil];
		
		ATRACE(@"SongList: init _playMode=%d", _playMode);
    }
	return self;
}

// ----------------------------------------------------------------------------------------------------------
- (void) setDelegate:(id<SongListWatcher>)adelegate view: (PlaybackView*) aview
{
    ATRACE(@"SongList: setDelegate adelegate=%@ aview=%p useAVPlayer=%d", adelegate, aview, _useAVPlayer);

    _delegate = adelegate;
    
    if (_playbackView != aview) {
        _playbackView = aview;
    }
    
    //[avPlayerCtl setPlaybackView: aview];
    
    aview.hidden = !_useAVPlayer;

    [self setupSongForIndex2: currentSongIndex];
}

// ----------------------------------------------------------------------------------------------------------
- (void) clearDelegate
{
    _delegate = nil;
    _playbackView = nil;
    
    [_avPlayerCtl setPlaybackView: nil];
}

// ----------------------------------------------------------------------------------------------------------
- (void) willResignActive
{
    ATRACE(@"SongList: willResignActive dirty=%d userDefSyncNeeded=%d", _dirty, userDefSyncNeeded);

    // clipStartTime will be reported when music player is inactive
    clipStartTime = lastCurrentPlayTimeSync;
    
    [self checkPrefSync];
    if (_dirty) {
        [self saveToDisk];
    }
    
    [_updateTimer invalidate];
    _updateTimer = nil;
}

// ----------------------------------------------------------------------------------------------------------
- (void) becomeActive
{
    ATRACE(@"SongList: becomeActive ");
    
    [self resumeSongSettings];

    _updateTimer = [NSTimer scheduledTimerWithTimeInterval: kTimerInterval
                                                         target: self
                                                       selector: @selector(timerCheck:)
                                                       userInfo: nil
                                                       repeats: YES];
}

// --------------------------------------------------------------------------------------------------------
- (void) saveTimeToPref: (NSTimeInterval)timeToReport
{
    ATRACE2(@"SongList: saveTimeToPref timeToReport=%f", timeToReport);

    lastCurrentPlayTimeSync = timeToReport;
    
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    
    [userDefaults setObject: @(timeToReport) forKey: kSongCurrentTimeKey ];
    
    [userDefaults setObject: @(_playMode) forKey: kSongPlayModeKey ];
        
    userDefSyncNeeded = YES;
}

// --------------------------------------------------------------------------------------------------------
- (void) checkPrefSync
{
    if (userDefSyncNeeded) {
        ATRACE(@"SongList: checkPrefSync synchronize");
        [[NSUserDefaults standardUserDefaults] synchronize];
        
        Song *asong = [self currentSong];
        if (asong && asong.currentPos != lastCurrentPlayTimeSync) {
            asong.currentPos = lastCurrentPlayTimeSync;
            [asong saveToDisk];
        }
        
        userDefSyncNeeded = NO;
    }
}

// ----------------------------------------------------------------------------------------------------------
+ (SongList*)default
{
	if (default1) 
		return default1;
	default1 = [[SongList alloc] init];
	return default1;
}

// ----------------------------------------------------------------------------------------------------------
+ (void) releaseStatic
{
}

// ----------------------------------------------------------------------------------------------------------
- (void) clearRememberedSettings
{
	NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
	[userDefaults removeObjectForKey: kSongCurrentTimeKey ];
	userDefSyncNeeded = YES;
	
	clipStartTime = 0.0;
}

// ----------------------------------------------------------------------------------------------------------
- (void) rememberCurrentTime: (NSTimeInterval)newTime
{
    [self saveTimeToPref: newTime];
	
	timeCurrentTimeSet = [NSDate timeIntervalSinceReferenceDate];
}

// ----------------------------------------------------------------------------------------------------------
- (void) rememberCurrentSongIndex
{
	NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
	
	[userDefaults setObject: @(currentSongIndex) forKey: kSongCurrentIndexKey  ];
	
	userDefSyncNeeded = YES;
}

// ----------------------------------------------------------------------------------------------------------
- (void) reportSongChange
{
	[_delegate reportSongChange];
}

// ----------------------------------------------------------------------------------------------------------
- (void) setupSongForIndex2: (int) index
{
	Song	*song;
	
	if (index >= [self songCount]) {
		ATRACE(@"SongList: setupSongForIndex2: BAD index=%d", index);
		[_musicPlayer stop];
        //[musicPlayer setQueueWithItemCollection: [MPMediaItemCollection collectionWithItems:@[]]];
	}
	else {
		song = [self songAtIndex: index];
        
		ATRACE2(@"SongList: setupSongForIndex2: song=%@ musicPlayer=%@", song, musicPlayer);
		ATRACE2(@"SongList: setupSongForIndex2: song.mediaItem.URL=%@", (NSURL*)[song.mediaItem valueForProperty:MPMediaItemPropertyAssetURL]);
		ATRACE(@"SongList: setupSongForIndex2: song.mediaItem=%p song.url=%@ s_mediaItem_video=%d", song.s_mediaItem, song.s_url, song.s_mediaItem_video);
		
        missingMediaItem = !song.s_mediaItem;
		if (missingMediaItem) {
			// if (song.sourceForLocal && song.partialPath && song.s_url) {
			if (song.sourceForLocal && song.s_url) {
				missingMediaItem = NO;
			}
		}
		if (missingMediaItem) {
			ATRACE(@"SongList: setupSongForIndex2: NO Media for song at index=%d", index);
            _avPlayerCtl.mPlaybackView.hidden = YES;
            _useAVPlayer = NO;
            _avPlayerCtl = nil;
			[_musicPlayer stop];
			//[musicPlayer setQueueWithItemCollection: [MPMediaItemCollection collectionWithItems:@[]]];
		}
		else {
            NSURL *url = song.s_url;
            _useAVPlayer = url != nil;
            if (_useAVPlayer) {
                ATRACE(@"SongList: setupSongForIndex2: useAVPlayer url=%@ old avPlayerCtl=%p", url, _avPlayerCtl);
                
				if (1) {
				//if (! _avPlayerCtl || ! [_avPlayerCtl.URL isEqual: url]) {
                    NSTimeInterval  oldTime  = [_avPlayerCtl currentTime];
                    
                    _avPlayerCtl = [[PlaybackViewCtl alloc] init];
                    
                    ATRACE(@"SongList: setupSongForIndex2: avPlayerCtl=%p oldTime=%f", _avPlayerCtl, oldTime);
                    
                    _avPlayerCtl.delegate = self;
                    
                    [_avPlayerCtl setPlaybackView: _playbackView];
                    
                    [_avPlayerCtl setURL: url];
                    
                    _avPlayerCtl.mPlaybackView.hidden = NO;
                    
                    [_avPlayerCtl setCurrentTime: oldTime];
                }
                else {
                    ATRACE(@"SongList: setupSongForIndex2: CONTINUE avPlayerCtl=%p ", _avPlayerCtl);
                    
                    _avPlayerCtl.mPlaybackView.hidden = NO;
                }
            }
            else if (! [[_musicPlayer nowPlayingItem] isEqual: song.s_mediaItem]) {
                ATRACE(@"SongList: setupSongForIndex2: using musicPlayer NEW mediaItem nowPlayingItem=%@ song.mediaItem=%@ %d",
                       [_musicPlayer nowPlayingItem], song.s_mediaItem, [[_musicPlayer nowPlayingItem] isEqual: song.s_mediaItem]);

                _avPlayerCtl.mPlaybackView.hidden = YES;

                MPMediaItemCollection *itemCol = [MPMediaItemCollection collectionWithItems: @[song.s_mediaItem]];
                
                [_musicPlayer setQueueWithItemCollection: itemCol];
            }
            else {
                ATRACE(@"SongList: setupSongForIndex2: using musicPlayer SAME song.mediaItem=%@ same=%d", song.s_mediaItem, [[_musicPlayer nowPlayingItem] isEqual: song.s_mediaItem]);
                
                _avPlayerCtl.mPlaybackView.hidden = YES;
           }
		}
	}
	
	currentSongIndex = index;

	[self reportSongChange];
}

// ----------------------------------------------------------------------------------------------------------
// Setup to play Song at given index
- (void) setupSongForIndex: (int) index
{
	ATRACE(@"SongList: setupSongForIndex=%d", index);

	[self setupSongForIndex2: index];
	
	[self rememberCurrentSongIndex];
}

// ----------------------------------------------------------------------------------------------------------
// The time we set into the media play may come back rounded down
// so we remember it and return it if requested with short period of been set
- (void) setCurrentTime: (NSTimeInterval) newTime
{
	ATRACE2(@"SongList: setCurrentTime: newTime=%f", newTime);
    
	[self setCurrentTime2: newTime];
    
	[self rememberCurrentTime: newTime];
    
    [self establishSeekTime: newTime];

    //[self establishClipForCurrentTime];
    [self establishClipLastClipIndex: [[self currentSong] clipIndexForTime: newTime]];
}

// ----------------------------------------------------------------------------------------------------------
- (void) resumeSongSettings
{
	NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
	int				newSongIndex = [[userDefaults objectForKey: kSongCurrentIndexKey] intValue];
	NSTimeInterval	newTime = [[userDefaults objectForKey: kSongCurrentTimeKey] floatValue];
    int             newPlayMode = [[userDefaults objectForKey: kSongPlayModeKey] intValue];
	if (newPlayMode == kClipPlayModeNone) newPlayMode = kClipPlayModeRepeat;
	ATRACE(@"SongList: resumeSongSettings: newSongIndex=%d newTime=%f", newSongIndex, newTime);
	
	[self setupSongForIndex2: newSongIndex];
	
	[self setCurrentTime2: newTime];
    
    [self setPlayMode2: newPlayMode];
}

#pragma mark Music notification handlers__________________

// --------------------------------------------------------------------------------------------------------
- (void) handle_NowPlayingItemChanged: (id) notification 
{
	ATRACE(@"SongList: handle_NowPlayingItemChanged currentPlaybackTime=%f ", _musicPlayer.currentPlaybackTime);
	ATRACE2(@"SongList: handle_NowPlayingItemChanged notification=%@ ", notification);
	ATRACE2(@"SongList: handle_NowPlayingItemChanged nowPlayingItem=%@", musicPlayer.nowPlayingItem);
	
	_musicPlayer.repeatMode = MPMusicRepeatModeNone;
}

// --------------------------------------------------------------------------------------------------------
- (void) handle_PlaybackStateChanged: (id) notification 
{
	MPMusicPlaybackState playbackState = [_musicPlayer playbackState];
	
	ATRACE2(@"SongList: handle_PlaybackStateChanged playbackState=%d nowPlayingItem=%@", playbackState, musicPlayer.nowPlayingItem);
	ATRACE(@"SongList: handle_PlaybackStateChanged playbackState=%ld nowPlayingItem=%p lastClipIndex=%d", (long)playbackState, _musicPlayer.nowPlayingItem, lastClipIndex);

	if (playRequested && playbackState != MPMusicPlaybackStatePlaying) {
        ATRACE(@"SongList: handle_PlaybackStateChanged seekIssuedDuringPlay = NO");
        seekIssuedDuringPlay = NO;
    }
	//if (playbackState == MPMusicPlaybackStatePaused)
	//else if (playbackState == MPMusicPlaybackStatePlaying)
	//else if (playbackState == MPMusicPlaybackStateStopped)
}

// --------------------------------------------------------------------------------------------------------
// To learn about notifications, see "Notifications" in Cocoa Fundamentals Guide.
- (void) registerForMediaPlayerNotifications 
{
	NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
	
	[notificationCenter addObserver: self
						   selector: @selector (handle_NowPlayingItemChanged:)
							   name: MPMusicPlayerControllerNowPlayingItemDidChangeNotification
							 object: _musicPlayer];
	
	[notificationCenter addObserver: self
						   selector: @selector (handle_PlaybackStateChanged:)
							   name: MPMusicPlayerControllerPlaybackStateDidChangeNotification
							 object: _musicPlayer];
		
	[_musicPlayer beginGeneratingPlaybackNotifications];
}

// --------------------------------------------------------------------------------------------------------
// Returns whether or not to use the iPod music player instead of the application music player.
- (BOOL) useiPodPlayer 
{
	if ([[NSUserDefaults standardUserDefaults] boolForKey: kPLAYER_TYPE_PREF_KEY]) {
		return YES;		
	}
	else {
		return NO;
	}		
}

// ----------------------------------------------------------------------------------------------------------
- (void) setupMusicPlayer
{
	// Instantiate the music player. If you specied the iPod music player in the Settings app,
	//		honor the current state of the built-in iPod app.
	if ([self useiPodPlayer]) {
		_musicPlayer = [MPMusicPlayerController iPodMusicPlayer];
		if ([_musicPlayer nowPlayingItem]) {
			//[self navigationController].navigationBar.topItem.leftBarButtonItem.enabled = YES;
			// Update the UI to reflect the now-playing item.
			[self handle_NowPlayingItemChanged: nil];
			
			if ([_musicPlayer playbackState] == MPMusicPlaybackStatePaused) {
				//[self navigationController].navigationBar.topItem.leftBarButtonItem = pauseBarButton;
			}
		}
	} 
	else {
		_musicPlayer = [MPMusicPlayerController applicationMusicPlayer];
		// By default, an application music player takes on the shuffle and repeat modes
		//		of the built-in iPod app. Here they are both turned off.
		[_musicPlayer setShuffleMode: MPMusicShuffleModeOff];
		[_musicPlayer setRepeatMode: MPMusicRepeatModeNone];
	}	
	
	[self registerForMediaPlayerNotifications];
    
    //_avPlayerCtl = [[[PlaybackViewCtl alloc] init] autorelease];
}

// ----------------------------------------------------------------------------------------------------------
- (NSArray*) saveToArray
{
	NSMutableArray *arr = [NSMutableArray arrayWithCapacity: [list count]];
	Song *song;
	for (song in list) {
		//[arr addObject: [song saveToDict]];
		[arr addObject: song.s_store_name ];
	}
	ATRACE2(@"SongList: saveToArray: arr=%@", [arr description]);

	return arr;
}

// ----------------------------------------------------------------------------------------------------------
- (void) saveToDisk
{
	ATRACE(@"SongList saveToDisk: dirty=%d count=%d", _dirty, [self songCount]);
	NSString		*documentsDirectory = [AppDelegate localDir];
    NSString		*path = [documentsDirectory stringByAppendingPathComponent: kAppPlistFileName ];
	
	NSDictionary *appDict = @{kNextSongIDKey: @(nextSongID), kSongFileNameArrayKey: [self saveToArray] };

	[appDict writeToFile: path atomically: YES];
	
	_dirty = NO;
}

// ----------------------------------------------------------------------------------------------------------
// Restore SongList for a dictionary
- (void) resumeFromDict: (NSDictionary*) appDict
{
	nextSongID = [appDict[kNextSongIDKey] intValue];
	NSArray			*arr = appDict[kSongFileNameArrayKey ];
	//ATRACE(@"SongList: resumeFromDict dict=%@ count %d ", appDict, [arr count]);
	ATRACE2(@"SongList: resumeFromDict count %d ", [arr count]);

	if (arr) {
		// Create place hold song objects, only fileName is set.
		Song		*newSong;
		NSString	*fileName;
		for (fileName in arr) {
			newSong = [[Song alloc] init];
			newSong.s_store_name = fileName;
			[list addObject: newSong];
		}
	}
}

// ----------------------------------------------------------------------------------------------------------
- (void) addSongFrom: (NSString *)songClipsRef songLabel: (NSString *) songLabel
{
	ATRACE(@"SongList: addSongFrom songClipsRef=%@ songLabel=%@", songClipsRef, songLabel);
	
	Song		*newSong = [[Song alloc] initWithClipsRef: songClipsRef songLabel: songLabel];
	if (newSong) {
		[list addObject: newSong];
		// Finished with this reference to the song
		[self saveToDisk];
	}
}

// ----------------------------------------------------------------------------------------------------------
// Read default from disk
+ (void) resumeFromDisk
{
	ATRACE(@"SongList: resumeFromDisk");

	NSString		*path = [AppDelegate localDir];
	path = [path stringByAppendingPathComponent: kAppPlistFileName ];
	NSDictionary	*appDict;
	// Read in app dict
    if ([[NSFileManager defaultManager] fileExistsAtPath: path]) {
		// Read in app plist .
		appDict = [NSDictionary dictionaryWithContentsOfFile: path];
		if (appDict) {
			[[SongList default] resumeFromDict: appDict];
		}
	}
	[[SongList default] resumeSongSettings];
}

// ----------------------------------------------------------------------------------------------------------
- (Song*) importSongFromString: (NSString *) str intoSong: (Song*) intoSong
{
	ATRACE2(@"SongList: importSongFromString str=%@ intoSong=%@", str, intoSong);
	Song		*newSong;
	
	newSong = intoSong;
	if (! newSong) {
		newSong = [Song alloc];
	}
	newSong = [newSong initFromExportString: str];
	
	if (! intoSong) {
		[list addObject: newSong];
		// Finished with this reference to the song
	}
	[self saveToDisk];
	
	return newSong;
}

// ----------------------------------------------------------------------------------------------------------
- (void) createSongForMediaItem: (MPMediaItem*) newMediaItem
{
	ATRACE(@"SongList: createSongsForNewMedia newMediaItem=%@", newMediaItem);

	Song		*newSong;
    newSong = [[Song alloc] initWithMediaItem: newMediaItem ];
    [list addObject: newSong];

	[self saveToDisk];
}

// ----------------------------------------------------------------------------------------------------------
- (void) createSongsForNewMediaItems: (NSArray*) newMediaItems
{
	ATRACE(@"SongList:createSongsForNewMediaItems newMediaItems=%@", newMediaItems);

	MPMediaItem *mediaItem;
	Song		*newSong;
	
	for (mediaItem in newMediaItems) {
		newSong = [[Song alloc] initWithMediaItem: mediaItem ];
		[list addObject: newSong];
	}

	[self saveToDisk];
}

// ----------------------------------------------------------------------------------------------------------
- (void) addMediaItemCollection: (MPMediaItemCollection *) newMediaItemCollection
{
	ATRACE(@"SongList:addMediaItemCollection newMediaItemCollection=%@", newMediaItemCollection);
	
	NSArray *newMediaItems = [newMediaItemCollection items];
		
	[self createSongsForNewMediaItems: newMediaItems];
}

// ----------------------------------------------------------------------------------------------------------
- (void) removeSongAtIndex: (int) index
{
	ATRACE(@"SongList: removeObjectAtIndex: index=%d\n", index);
	Song *song = list[ index];
	if (song.s_store_name) {
		ATRACE(@"SongList: removeObjectAtIndex: removing directory=%@\n", [song songDirectoryPath]);
		[[NSFileManager defaultManager] removeItemAtPath: [song songDirectoryPath] error:NULL];
	}
	[list removeObjectAtIndex: index];

	if (currentSongIndex == index) {
		ATRACE(@"  STOPPING currentSongIndex=%d\n", currentSongIndex);
		[_musicPlayer stop];
		if (currentSongIndex >= [self songCount])
			currentSongIndex = 0;
		[self clearRememberedSettings];
		[self setupSongForIndex: currentSongIndex];
	}
	else if (currentSongIndex > index) {
		currentSongIndex--;
		[self rememberCurrentSongIndex];
	}
	
	[self saveToDisk];
}

// ----------------------------------------------------------------------------------------------------------
- (void)removeSong:(Song*)dict1
{
	NSUInteger	index = (int)[list indexOfObjectIdenticalTo: dict1];
	ATRACE2(@"SongList: removeObject: dict=%lx index=%d rc=%d\n", dict1, index, [dict1 retainCount]);
	if (index !=  NSNotFound) {
		[self removeSongAtIndex:(int)index];
	}
}

// ----------------------------------------------------------------------------------------------------------
- (Song*) songAtIndex: (int) index
{
	Song *song = list[ index];
	if (! song.title) {
		[song restoreFromDisk];
	}
	return song;
}

// ----------------------------------------------------------------------------------------------------------
- (void) songAtIndex: (int) fromIndex moveTo: (int) toIndex
{
    
    Song *song = list [ fromIndex];

    if (fromIndex < toIndex) toIndex++;

    [list insertObject: song atIndex: toIndex];
    
    if (fromIndex > toIndex) fromIndex++;
    
    [list removeObjectAtIndex: fromIndex];

	[self saveToDisk];
}

// ----------------------------------------------------------------------------------------------------------
- (int) songCount
{
	return (int)[list count];
}

// ----------------------------------------------------------------------------------------------------------
- (Song*) currentSong
{
	if (currentSongIndex < [list count])
		return list[ currentSongIndex];
	return nil;
}

// ----------------------------------------------------------------------------------------------------------
- (int) currentSongIndex
{
	return currentSongIndex;
}

// ----------------------------------------------------------------------------------------------------------
- (int) currentClipIndex
{
	return [[self currentSong] clipIndexForTime: [self currentTime]];
}

// ----------------------------------------------------------------------------------------------------------
- (void) playSongAt: (int) index
{
	[self setupSongForIndex: index];
	
	self.currentTime = 0.0;
	
	[self play];
}

// ----------------------------------------------------------------------------------------------------------
- (void) selectSong: (Song *) newSong
{
	NSUInteger	index = (int)[list indexOfObjectIdenticalTo: newSong];
	ATRACE2(@"SongList: selectSong: newSong=%@ index=%d rc=%d\n", newSong, index, [newSong retainCount]);
	ATRACE(@"SongList: selectSong: newSong=%@ index=%lu title=%@ albumTitle=%@ artist=%@", newSong, (unsigned long)index, newSong.title, newSong.albumTitle, newSong.artist);
	
    [self checkPrefSync];
    
	if (index !=  NSNotFound) {
		[self setupSongForIndex: (int)index];

		ATRACE2(@"SongList: selectSong: newSong.currentPos=%f", newSong.currentPos);
        if (newSong.currentPos < newSong.duration) {
            self.currentTime = newSong.currentPos;
        }
        else {
            self.currentTime = 0;
        }
        clipStartTime = self.currentTime;
	}
}

// ----------------------------------------------------------------------------------------------------------
// Is media playing
- (BOOL) isPlaying
{
    BOOL state;
    
	if (missingMediaItem) {
		state = missingMediaIsPlaying;
    }
    else if (_useAVPlayer) {
        state = [_avPlayerCtl isPlaying];
    }
    else {
        state = _musicPlayer.playbackState == MPMusicPlaybackStatePlaying;
    }
    
    return state;
}

// ----------------------------------------------------------------------------------------------------------
- (void) setCurrentTime2: (NSTimeInterval) newTime
{
	if (missingMediaItem) {
		ATRACE2(@"SongList setCurrentTime2 missingMediaItem isPlaying=%d missingMediaOffsetTime=%f missingMediaCurrentTime=%f",
               missingMediaIsPlaying, missingMediaOffsetTime, missingMediaCurrentTime);
		if (missingMediaIsPlaying) {
			// [NSDate timeIntervalSinceReferenceDate] - missingMediaOffsetTime
			missingMediaOffsetTime = [NSDate timeIntervalSinceReferenceDate] - newTime;
		}
		else {
			missingMediaCurrentTime = newTime;
		}
		clipStartTime = newTime;
		return;
	}
    else if (_useAVPlayer) {
		ATRACE(@"SongList: setCurrentTime2 newTime=%f",newTime);
        [_avPlayerCtl setCurrentTime: newTime];
    }
    else {
        if (_musicPlayer && _musicPlayer.nowPlayingItem == nil) {
            // Play drop current Song, re-establish
            [self setupSongForIndex2: currentSongIndex];
            ATRACE2(@"SongList: setCurrentTime2: currentSongIndex=%d newTime=%f musicPlayer=%@", currentSongIndex, newTime, musicPlayer);
        }
        _musicPlayer.currentPlaybackTime = newTime;
    }
	clipStartTime = newTime;
    
    if (seekIssuedDuringPlay) {
        seekIssuedDuringPlay = NO;
		ATRACE(@"SongList: setCurrentTime2 seekIssuedDuringPlay NO seekIssuedDuringPlayTime=%f", seekIssuedDuringPlayTime);
    }
}

// --------------------------------------------------------------------------------------------------------
// Access current media play back time
- (NSTimeInterval) currentTime
{
    NSTimeInterval timeToReport;

    if (playModePause
            && (_playMode == kClipPlayModePauseContinue
                    || _playMode == kClipPlayModePauseRepeat)
        ) {
        timeToReport = [NSDate timeIntervalSinceReferenceDate] - playModePauseOffsetTime;
    }
    else {
        if (missingMediaItem) {
            ATRACE2(@"SongList currentTime missingMediaItem isPlaying=%d missingMediaOffsetTime=%f missingMediaCurrentTime=%f",
                    missingMediaIsPlaying, missingMediaOffsetTime, missingMediaCurrentTime);
            if (missingMediaIsPlaying)
                return [NSDate timeIntervalSinceReferenceDate] - missingMediaOffsetTime;
            return missingMediaCurrentTime;
        }
        if (_useAVPlayer) {
            timeToReport = [_avPlayerCtl currentTime];
        }
        else {
            timeToReport = _musicPlayer.currentPlaybackTime;
        }
        if (seekIssuedDuringPlay && seekIssuedDuringPlayTime > timeToReport ) {
            // A next clip request sometime will have player report the seek time and then a time slight before that time
            // causing a blip in the clip text and image
            //
            ATRACE2(@"SongList currentTime seekIssuedDuringPlayTime=%f timeToReport=%f lastClipIndex=%d", seekIssuedDuringPlayTime, timeToReport, lastClipIndex);
            timeToReport = seekIssuedDuringPlayTime;
        }
    }
    return timeToReport;
}

// ----------------------------------------------------------------------------------------------------------
- (void) speed_shift_monitor: (Song*) song
{
	if (! speed_shift_enabled)
		return;
	NSArray *slist = song.speed_shift_list;
	if (! slist)
		return;
	if (speed_shift_index < 0 || speed_shift_index >= [slist count])
		speed_shift_index = 0;
	if (speed_shift_index >= [slist count])
		return;
	NSDictionary *entry = slist[speed_shift_index];
	NSTimeInterval duration = [entry[@"duration"] doubleValue];
	if (! duration)
		return;
	NSTimeInterval	now = [NSDate timeIntervalSinceReferenceDate];
	NSTimeInterval	diff = now - speed_shift_start_time;
	if (diff < duration)
		return;
	speed_shift_start_time = now;
	speed_shift_index++;
	float	rate = [entry[@"rate"] floatValue];
	if (! rate)
		return;
	
	ATRACE(@"speed_shift_monitor speed_shift_index=%d rate=%f", speed_shift_index, rate);
	
	[self setCurrentRate: rate];
}

// ----------------------------------------------------------------------------------------------------------
- (void) play
{
	Song	*song = [self currentSong];
	
	if (! song)
		return;
	
	speed_shift_enabled = song.speed_shift_list != nil;
	if (speed_shift_enabled) {
		speed_shift_start_time = [NSDate timeIntervalSinceReferenceDate];
		speed_shift_index = 0;
		[self speed_shift_monitor: song];
	}
	
    if (playModePause && ! [self isPlaying]) {
		ATRACE(@"SongList play playModePause establishNextClip" );

        if (_playMode != kClipPlayModePause) {
            [self establishNextClip];
        }
        playModePause = NO;
    }
	if (missingMediaItem) {
		ATRACE(@"SongList play missingMediaItem isPlaying=%d missingMediaOffsetTime=%f missingMediaCurrentTime=%f",
			   missingMediaIsPlaying, missingMediaOffsetTime, missingMediaCurrentTime);
		if (! missingMediaIsPlaying) {
			missingMediaOffsetTime = [NSDate timeIntervalSinceReferenceDate] - missingMediaCurrentTime;
			missingMediaIsPlaying = YES;
		}
		return;
	}
    else if (_useAVPlayer) {
        [_avPlayerCtl play];
    }
    else {
        if (_musicPlayer.nowPlayingItem == nil) {
            // musicPlayer has dropped current Song, re-establish
            [self setupSongForIndex: currentSongIndex];
            _musicPlayer.currentPlaybackTime = clipStartTime;
        }
        [_musicPlayer play];
    }
    ATRACE(@"SongList play playRequested = YES isPlaying=%d", [self isPlaying]);
    playRequested = YES;
}

// ----------------------------------------------------------------------------------------------------------
- (void) pause
{
    ATRACE(@"SongList: pause.1 currentPlaybackTime=%f", _useAVPlayer? [_avPlayerCtl currentTime]: _musicPlayer.currentPlaybackTime);
	if (missingMediaItem) {
		ATRACE(@"SongList pause missingMediaItem isPlaying=%d missingMediaOffsetTime=%f missingMediaCurrentTime=%f", missingMediaIsPlaying, missingMediaOffsetTime, missingMediaCurrentTime);
		if (missingMediaIsPlaying) {
			missingMediaCurrentTime = [NSDate timeIntervalSinceReferenceDate] - missingMediaOffsetTime;
			missingMediaIsPlaying = NO;
			clipStartTime = missingMediaCurrentTime;
		}
	}
    else if (_useAVPlayer) {
        [_avPlayerCtl pause];
    }
    else {
        // Set currenttime so its remember dropping into pause
        if (_musicPlayer && [_musicPlayer playbackState] == MPMusicPlaybackStatePlaying) {
            ATRACE(@"SongList: pause.2 musicPlayer.currentPlaybackTime=%f", _musicPlayer.currentPlaybackTime);
            clipStartTime = _musicPlayer.currentPlaybackTime;
        }
        [_musicPlayer pause];
    }
    playRequested = NO;
}

// ----------------------------------------------------------------------------------------------------------
- (void) setCurrentRate: (float) newRate
{
	ATRACE(@"SongList setCurrentRate newRate=%f", newRate);
	if (_useAVPlayer) {
		[_avPlayerCtl setCurrentRate: newRate];
	}
}

// ----------------------------------------------------------------------------------------------------------
// Prepare string to use as file name prefix
- (NSString*) safePrefix: (NSString*) preFix
{
	if (! preFix) preFix = @"";
	preFix = [preFix stringByReplacingOccurrencesOfString: @"/" withString: @""];
	preFix = [preFix stringByReplacingOccurrencesOfString: @" " withString: @""];
#define kMaxPrefixLen	32
	if ([preFix length] <= kMaxPrefixLen)
		return preFix;
	else
		return [preFix substringToIndex: kMaxPrefixLen];
}

// ----------------------------------------------------------------------------------------------------------
// Return the next file name for new song
- (NSString*) nextSongFileName: (NSString*) preFix
{
	NSString *nextName = [NSString stringWithFormat: @"%d-%@", nextSongID, [self safePrefix: preFix ]  ];

	nextSongID++;
	
	_dirty = YES;
	//[self saveToDisk];
	
	return nextName;
}

// ----------------------------------------------------------
- (void) setClipStartTime: (NSTimeInterval) newTime
{
	clipStartTime = newTime;
}

// --------------------------------------------------------------------------------------------------------
- (void) establishClipForCurrentTime
{
    [self establishClipLastClipIndex: [self currentClipIndex]];
}

// --------------------------------------------------------------------------------------------------------
- (void) establishClipLastClipIndex: (int) index
{
    ATRACE(@"SongList: establishClipLastClipIndex index=%d", index);
    
    lastClipIndex = index;

    Song *song = [self currentSong];
    
    Clip *clip = [song clipAtIndex: lastClipIndex];
    
    lastClipStart = clip.startTime;
    
    lastClipDuration = clip.subDuration;
	
	double rate = clip.clip_rate;
	if (rate) {
		ATRACE(@"SongList: establishClipLastClipIndex rate=%f", rate);
		[self setCurrentRate: rate];
	}
}

// --------------------------------------------------------------------------------------------------------
- (void) setPlayMode2:(int)new_playMode
{
	ATRACE(@"SongList: setPlayMode2 new_playMode=%d", new_playMode);
	
	_playMode = new_playMode;
    
    playModePause = NO;

    [self establishClipForCurrentTime];

    [self determinePlayMode: [self currentTime]];
}

// --------------------------------------------------------------------------------------------------------
- (void) setPlayMode:(int)new_playMode
{
    [self setPlayMode2: new_playMode];
    
    userDefSyncNeeded = YES;
}

// ----------------------------------------------------------------------------------------------------------
- (void) nextClip
{
	int     index = [self currentClipIndex];
    BOOL    playNeeded = NO;
    
    if (playModePause)  {
        playModePause = NO;
        [self play];
        index = lastClipIndex;
        playNeeded = YES;
    }
	Song		*song = [self currentSong];
	if (! song)
		return;
	if (index >= [song clipCount]-1)
        return;
	NSTimeInterval newTime = [song clipAtIndex: index+1].startTime;

    ATRACE(@"SongList: nextClip index=%d newTime=%f lastClipIndex=%d lastClipStart=%f", index, newTime, lastClipIndex, lastClipStart);

    [self establishClipJumpTime: newTime];

    ATRACE(@"SongList: nextClip lastClipIndex=%d lastClipStart=%f", lastClipIndex, lastClipStart);
    
    if (playNeeded) [self play];
    
    // In pause mode next clip sometimes gets stuck
    [self establishSeekTimeAlways: newTime];
}

// ----------------------------------------------------------------------------------------------------------
- (void) previousClip
{
    if (!playModePause && [self currentTime] > lastClipStart + kPreviousClipRestartWindow) {
        [self setCurrentTime2: lastClipStart];
        return;
    }
	int		index = [self currentClipIndex];
    BOOL    playNeeded = NO;
    if (playModePause) {
        ATRACE(@"SongList: previousClip lastClipIndex=%d ", lastClipIndex);
        playModePause = NO;
        [self play];
        index = lastClipIndex;
        playNeeded = YES;
    }

	Song		*song = [self currentSong];
	if (! song)
		return;
	if (index < 0) {
		return;
	}
	if (index > 0) index = index-1;
	
	NSTimeInterval newTime = [song clipAtIndex: index].startTime;

    ATRACE(@"SongList: previousClip index=%d newTime=%f ", index, newTime);

    [self establishClipJumpTime: newTime];
    
    previousClipIssued = YES;

    if (playNeeded) [self play];
}

// ----------------------------------------------------------------------------------------------------------
- (void) establishClipJumpTime: (NSTimeInterval) newTime
{
    [self setCurrentTime: newTime];

    [_delegate timeReport: newTime];
}

// --------------------------------------------------------------------------------------------------------
- (void) establishSeekTimeAlways: (NSTimeInterval) newTime
{
    ATRACE2(@"SongList: establishSeekTimeAlways newTime=%f ", newTime);
    
    seekIssuedDuringPlay = YES;
    seekIssuedDuringPlayTime = newTime;
}

// --------------------------------------------------------------------------------------------------------
- (void) establishSeekTime: (NSTimeInterval) newTime
{
    if (playRequested) {
        [self establishSeekTimeAlways: newTime];
    }
}

// --------------------------------------------------------------------------------------------------------
- (void) establishNextClip
{
    ATRACE(@"SongList: establishNextClip lastClipIndex=%d lastClipStart=%f lastClipDuration=%f ", lastClipIndex, lastClipStart, lastClipDuration);

    // Establish next clip
    Song *song = [self currentSong];
    int index = lastClipIndex;
    if (index < [song clipCount]-1)
        index++;
    
    Clip *clip = [song clipAtIndex: index];
    
    lastClipIndex = index;
    lastClipStart = clip.startTime;
    lastClipDuration = clip.subDuration;

    ATRACE(@"SongList: establishNextClip lastClipIndex=%d lastClipStart=%f lastClipDuration=%f ", lastClipIndex, lastClipStart, lastClipDuration);
}

// --------------------------------------------------------------------------------------------------------
- (NSTimeInterval) determinePlayMode: (NSTimeInterval) newTime
{
    switch (_playMode) {
        case kClipPlayModeContinue:
			ATRACE2(@"SongList: kClipPlayModeContinue lastClipIndex=%d newTime=%f lastClipStart=%f lastClipDuration=%f ", lastClipIndex, newTime, lastClipStart, lastClipDuration);
			ATRACE2(@"SongList: kClipPlayModeContinue playing=%d", self.isPlaying);
            break;
        case kClipPlayModeRepeat:
            if (newTime >= lastClipStart + lastClipDuration) {
                [self setCurrentTime: lastClipStart];

                newTime = lastClipStart;
                
                [self establishSeekTimeAlways: newTime];

                ATRACE2(@"SongList: kClipPlayModeRepeat lastClipIndex=%d newTime=%f lastClipStart=%f lastClipDuration=%f ", lastClipIndex, newTime, lastClipStart, lastClipDuration);
            }
            break;
        case kClipPlayModePause:
            if (newTime >= lastClipStart + lastClipDuration) {
                ATRACE2(@"SongList: kClipPlayModePause lastClipIndex=%d newTime=%f lastClipStart=%f lastClipDuration=%f ", lastClipIndex, newTime, lastClipStart, lastClipDuration);
                
                [self pause];
                
                playModePause = YES;
            }
            break;
        case kClipPlayModePauseContinue:
            if (! playModePause) {
                if (newTime >= lastClipStart + lastClipDuration) {
                    ATRACE2(@"SongList: kClipPlayModePauseContinue pause ");

                    [self pause];
                    
                    playModePause = YES;
                    
                    playModePauseOffsetTime = [NSDate timeIntervalSinceReferenceDate] - lastClipStart;
                }
            }
            else {
                if (newTime >= lastClipStart + lastClipDuration) {
                    if (lastClipIndex < [[self currentSong] clipCount]-1 ) {
                        [self establishNextClip];
                    }
                    else {
                        [self setCurrentTime: 0];
                    }
                    
                    playModePause = NO;
                    
                    [self play];
                }
            }
            break;
        case kClipPlayModePauseRepeat:
            if (! playModePause) {
                if (newTime >= lastClipStart + lastClipDuration) {
                    ATRACE2(@"SongList: kClipPlayModePauseRepeat PAUSE lastClipIndex=%d newTime=%f lastClipStart=%f lastClipDuration=%f ", lastClipIndex, newTime, lastClipStart, lastClipDuration);

                    [self pause];
                    
                    playModePause = YES;
                    
                    playModePauseOffsetTime = [NSDate timeIntervalSinceReferenceDate] - lastClipStart;
                }
            }
            else {
                if (newTime >= lastClipStart + lastClipDuration) {
                    ATRACE(@"SongList: kClipPlayModePauseRepeat lastClipIndex=%d newTime=%f lastClipStart=%f lastClipDuration=%f ", lastClipIndex, newTime, lastClipStart, lastClipDuration);
                    playModePause = NO;
                    
                    [self setCurrentTime: lastClipStart];
                    //[self establishClipTime: newTime];
                    newTime = lastClipStart;

                    [self play];
                    
                    // Even though we stay play, isPlay not reporting in play when coming out of pause for a beat.
                    ATRACE2(@"SongList: kClipPlayModePauseRepeat isPlaying=%d", [self isPlaying]);
                    
                    [self establishSeekTimeAlways: newTime];
                }
            }
            break;
    }
    
    return newTime;
}

// --------------------------------------------------------------------------------------------------------
- (void) reportCurrentTime
{
	ATRACE2(@"SongList: reportCurrentTime:");
	
    // Inform delegate of current playback time
    NSTimeInterval newTime = [self currentTime];;
    
    ATRACE2(@"SongList: timeToReport=%f clipStartTime=%f playbackState=%d ", newTime, clipStartTime, [musicPlayer playbackState]);
    
    if (! [_delegate isTracking]) {
        newTime = [self determinePlayMode: newTime];
    }

    [_delegate timeReport: newTime];
    
    // On a slow interval...
    // Write to prefs current play back time and sync for other pref updates
    NSTimeInterval	now = [NSDate timeIntervalSinceReferenceDate];
    if (now - lastTimeSync > kSyncUpdateInterval) {
        lastTimeSync = now;
        if (_musicPlayer ) {
            if (newTime != lastCurrentPlayTimeSync) {
                [self saveTimeToPref: newTime];
            }
        }
    }
}
                             

// --------------------------------------------------------------------------------------------------------
// Report play back time to delegate
- (void) timerCheck:(NSTimer*)theTimer
{
	ATRACE2(@"SongList: timerCheck:");
	
	[self reportCurrentTime];
}

// --------------------------------------------------------------------------------------------------------
- (void)playbackViewCtl:(PlaybackViewCtl *)playbackViewCtl seekCompleted:(NSTimeInterval )seekTime
{
	ATRACE(@"SongList: playbackViewCtl seekCompleted=%f seekIssuedDuringPlay=%d seekIssuedDuringPlayTime=%f", seekTime, seekIssuedDuringPlay, seekIssuedDuringPlayTime);
    
    //seekIssuedDuringPlay = NO;
    
}

// --------------------------------------------------------------------------------------------------------
- (void)playbackViewCtldidReachEnd:(PlaybackViewCtl *)playbackViewCtl
{
	ATRACE(@"SongList: playbackViewCtldidReachEnd seekIssuedDuringPlay=%d seekIssuedDuringPlayTime=%f", seekIssuedDuringPlay, seekIssuedDuringPlayTime);
    
    seekIssuedDuringPlay = NO;
    
    if (_playMode == kClipPlayModeRepeat) {
        [self setCurrentTime: lastClipStart];
                
        [self establishSeekTimeAlways: lastClipStart];
        
        [self play];
    }
	else if (_playMode == kClipPlayModeContinue) {

		ATRACE(@"SongList: playbackViewCtldidReachEnd kClipPlayModeContinue");

		[self setCurrentTime: 0];
		
		[self establishSeekTimeAlways: 0];
		
		[self play];
	}
    else if (_playMode == kClipPlayModePauseContinue) {
        
    }
}

// --------------------------------------------------------------------------------------------------------
- (BOOL) isVideo
{
    return _useAVPlayer;
}

// --------------------------------------------------------------------------------------------------------
// ----------------------------------------------------------------------------------------------------------

@end
