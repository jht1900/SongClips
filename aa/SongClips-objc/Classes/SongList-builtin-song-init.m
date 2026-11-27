/*

*/

#import "SongList.h"
#import "AppDelegate.h"
#import "AppDefs.h"

@interface SongList (Private)
- (void) setupMusicPlayer;
@end

static SongList* default1 = 0;

//#define kTimerInterval		0.1
#define kTimerInterval		0.1

#define kTimeDelayReportCurrentTime 0.2

// Check for sync and update currentTime at this interval
#define kSyncUpdateInterval	1.0

@implementation SongList

@synthesize musicPlayer;
@synthesize updateTimer;
@synthesize delegate;
@synthesize	dirty;
@synthesize imageCache;
@synthesize imageIconCache;

// ----------------------------------------------------------------------------------------------------------
- (id)init
{
	self = [super init];
	if (self)
	{
		list = [[NSMutableArray alloc] init];
		
		imageCache = [[Cache alloc] init] ;
		imageCache.allowance = kMaxCacheImage;
		
		imageIconCache = [[Cache alloc] init];
		imageIconCache.allowance = kMaxCacheImageIcon;
		
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
    }
	return self;
}

// ----------------------------------------------------------------------------------------------------------
- (void)dealloc
{
	[list release];

    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
	[nc removeObserver: self
                  name: MPMusicPlayerControllerNowPlayingItemDidChangeNotification
                object: musicPlayer];
	[nc removeObserver: self
                  name: MPMusicPlayerControllerPlaybackStateDidChangeNotification
                object: musicPlayer];
    
	[nc removeObserver: self
                  name: UIApplicationWillResignActiveNotification
                object: nil];
	[nc removeObserver: self
                  name: UIApplicationDidBecomeActiveNotification
                object: nil];

	[musicPlayer release];
	
	[updateTimer invalidate];
	[updateTimer release];
	
	[imageCache release];
	
	[imageIconCache release];
	
    [super dealloc];
}

// ----------------------------------------------------------------------------------------------------------
- (void) willResignActive
{
    ATRACE(@"SongList: willResignActive dirty=%d userDefSyncNeeded=%d", dirty, userDefSyncNeeded);

    // clipStartTime will be reported when music player is inactive
    clipStartTime = lastCurrentPlayTimeSync;
    
    [self checkPrefSync];
    if (dirty)
    {
        [self saveToDisk];
    }
    
    [updateTimer invalidate];
    self.updateTimer = nil;
}

// ----------------------------------------------------------------------------------------------------------
- (void) becomeActive
{
    ATRACE(@"SongList: becomeActive ");
    
    [self resumeSongSettings];

    self.updateTimer = [NSTimer scheduledTimerWithTimeInterval: kTimerInterval
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
    
    [userDefaults setObject: [NSNumber numberWithFloat: timeToReport ] forKey: kSongCurrentTimeKey ];
    
    userDefSyncNeeded = YES;
}

// --------------------------------------------------------------------------------------------------------
- (void) checkPrefSync
{
    if (userDefSyncNeeded)
    {
        ATRACE(@"SongList: checkPrefSync synchronize");
        [[NSUserDefaults standardUserDefaults] synchronize];
        
        Song *asong = [self currentSong];
        if (asong && asong.currentPos != lastCurrentPlayTimeSync)
        {
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
	if (default1) 
		[default1 release];
}

// ----------------------------------------------------------
// Is media playing
- (BOOL) isPlaying
{
	if (noMediaItem)
		return noMediaIsPlaying;
	return musicPlayer.playbackState == MPMusicPlaybackStatePlaying;
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
#if 0
	NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
	[userDefaults setObject: [NSNumber numberWithFloat: newTime] forKey: kSongCurrentTimeKey ];
	userDefSyncNeeded = YES;
#endif
    
	timeCurrentTimeSet = [NSDate timeIntervalSinceReferenceDate];
}

// ----------------------------------------------------------------------------------------------------------
- (void) rememberCurrentSongIndex
{
	NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
	
	[userDefaults setObject: [NSNumber numberWithInt: currentPlayingIndex] forKey: kSongCurrentIndexKey  ];
	
	userDefSyncNeeded = YES;
}

// ----------------------------------------------------------------------------------------------------------
- (void) reportSongChange
{
	[delegate reportSongChange];
}

// ----------------------------------------------------------------------------------------------------------
- (void) setupSongForIndex2: (NSUInteger) index
{
	Song	*song;
	
	if (index >= [self songCount])
	{
		ATRACE(@"SongList: setupSongForIndex2: BAD index=%d", index);
		[musicPlayer stop];
		[musicPlayer setQueueWithItemCollection: nil];
	}
	else
	{
		song = [self songAtIndex: index];
		ATRACE2(@"SongList: setupSongForIndex2: song=%@ musicPlayer=%@", song, musicPlayer);
        
		ATRACE(@"SongList: setupSongForIndex2: song.mediaItem.URL=%@", (NSURL*)[song.mediaItem valueForProperty:MPMediaItemPropertyAssetURL]);
		
		if ( song.mediaItem)
		{
			noMediaItem = NO;
			MPMediaItemCollection *itemCol = [MPMediaItemCollection collectionWithItems: [NSArray arrayWithObject: song.mediaItem]];
			
			[musicPlayer setQueueWithItemCollection: itemCol];
		}
		else
		{
			noMediaItem = YES;
			ATRACE(@"SongList: setupSongForIndex2: NO Media for song at index=%d", index);
			[musicPlayer stop];
			[musicPlayer setQueueWithItemCollection: nil];
		}
	}
	
	currentPlayingIndex = index;

	[self reportSongChange];
}

// ----------------------------------------------------------------------------------------------------------
// Setup to play Song at given index
- (void) setupSongForIndex: (NSUInteger) index
{
	[self setupSongForIndex2: index];
	
	[self rememberCurrentSongIndex];
}

// ----------------------------------------------------------------------------------------------------------
- (void) setCurrentTime2: (NSTimeInterval) newTime
{
	if (noMediaItem)
	{
		ATRACE(@"SongList setCurrentTime2 noMediaItem isPlaying=%d noMediaOffsetTime=%f noMediaCurrentTime=%f",
				noMediaIsPlaying, noMediaOffsetTime, noMediaCurrentTime);
		if (noMediaIsPlaying)
		{
			// [NSDate timeIntervalSinceReferenceDate] - noMediaOffsetTime
			noMediaOffsetTime = [NSDate timeIntervalSinceReferenceDate] - newTime;
		}
		else
		{
			noMediaCurrentTime = newTime;
		}
		clipStartTime = newTime;
		return;
	}
	if (musicPlayer && musicPlayer.nowPlayingItem == nil)
	{
		// Play drop current Song, re-establish
		[self setupSongForIndex2: currentPlayingIndex];
		ATRACE2(@"SongList: setCurrentTime2: currentPlayingIndex=%d newTime=%f musicPlayer=%@", currentPlayingIndex, newTime, musicPlayer);
	}
	musicPlayer.currentPlaybackTime = newTime;
	clipStartTime = newTime;
}

// ----------------------------------------------------------------------------------------------------------
// The time we set into the media play may come back rounded down
// so we remember it and return it if requested with short period of been set
- (void) setCurrentTime: (NSTimeInterval) newTime
{
	[self setCurrentTime2: newTime];
	[self rememberCurrentTime: newTime];
}

// --------------------------------------------------------------------------------------------------------
// Access current media play back time
- (NSTimeInterval) currentTime
{
	if (noMediaItem)
	{
		ATRACE2(@"SongList currentTime noMediaItem isPlaying=%d noMediaOffsetTime=%f noMediaCurrentTime=%f",
			   noMediaIsPlaying, noMediaOffsetTime, noMediaCurrentTime);
		if (noMediaIsPlaying)
			return [NSDate timeIntervalSinceReferenceDate] - noMediaOffsetTime;
		return noMediaCurrentTime;
	}
	NSTimeInterval timeToReport = musicPlayer.currentPlaybackTime;
    // MPMusicPlaybackStateStopped MPMusicPlaybackStatePaused
	//if ([musicPlayer playbackState] != MPMusicPlaybackStatePlaying)
    if ([musicPlayer playbackState] == MPMusicPlaybackStateStopped ||
        [musicPlayer playbackState] == MPMusicPlaybackStatePaused)
	{
		ATRACE2(@"SongList currentTime playbackState=%d currentPlaybackTime - clipStartTime = %f",
				[musicPlayer playbackState], musicPlayer.currentPlaybackTime - clipStartTime);
		timeToReport = clipStartTime;
	}
#if 0
	else if ([NSDate timeIntervalSinceReferenceDate] - timeCurrentTimeSet < kTimeDelayReportCurrentTime)
	{
		ATRACE(@"SongList timeCurrentTimeSet clipStartTime = %f", clipStartTime);
		timeToReport = clipStartTime;
	}
#endif
	return timeToReport;
}

// ----------------------------------------------------------------------------------------------------------
- (void) resumeSongSettings
{
	NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];

	NSUInteger newSongIndex = [[userDefaults objectForKey: kSongCurrentIndexKey] intValue];
	
	NSTimeInterval newTime = [[userDefaults objectForKey: kSongCurrentTimeKey] floatValue];
	
	ATRACE(@"SongList: resumeSongSettings: newSongIndex=%d newTime=%f", newSongIndex, newTime);
	
	[self setupSongForIndex2: newSongIndex];
	
	[self setCurrentTime2: newTime];
}

#pragma mark Music notification handlers__________________

// --------------------------------------------------------------------------------------------------------
- (void) handle_NowPlayingItemChanged: (id) notification 
{
	ATRACE(@"SongList: handle_NowPlayingItemChanged notification=%@ ", notification);
	ATRACE2(@"SongList: handle_NowPlayingItemChanged nowPlayingItem=%@", musicPlayer.nowPlayingItem);
	
	musicPlayer.repeatMode = MPMusicRepeatModeOne;
}

// --------------------------------------------------------------------------------------------------------
- (void) handle_PlaybackStateChanged: (id) notification 
{
	MPMusicPlaybackState playbackState = [musicPlayer playbackState];
	
	ATRACE(@"SongList: handle_PlaybackStateChanged playbackState=%d nowPlayingItem=%@", playbackState, musicPlayer.nowPlayingItem);
	
	if (playbackState == MPMusicPlaybackStatePaused) 
	{
	} 
	else if (playbackState == MPMusicPlaybackStatePlaying) 
	{
	} 
	else if (playbackState == MPMusicPlaybackStateStopped) 
	{
	}
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
		
	[musicPlayer beginGeneratingPlaybackNotifications];
}

// --------------------------------------------------------------------------------------------------------
// Returns whether or not to use the iPod music player instead of the application music player.
- (BOOL) useiPodPlayer 
{
	if ([[NSUserDefaults standardUserDefaults] boolForKey: kPLAYER_TYPE_PREF_KEY])
	{
		return YES;		
	}
	else 
	{
		return NO;
	}		
}

// ----------------------------------------------------------------------------------------------------------
- (void) setupMusicPlayer
{
	// Instantiate the music player. If you specied the iPod music player in the Settings app,
	//		honor the current state of the built-in iPod app.
	if ([self useiPodPlayer]) 
	{
		self.musicPlayer = [MPMusicPlayerController iPodMusicPlayer];
		
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
		self.musicPlayer = [MPMusicPlayerController applicationMusicPlayer];
		
		// By default, an application music player takes on the shuffle and repeat modes
		//		of the built-in iPod app. Here they are both turned off.
		[musicPlayer setShuffleMode: MPMusicShuffleModeOff];
		[musicPlayer setRepeatMode: MPMusicRepeatModeNone];
	}	
	
	[self registerForMediaPlayerNotifications];
}

#if 0
// ----------------------------------------------------------------------------------------------------------
- (void) setMusicPlayer: (MPMusicPlayerController*) mp
{
	ATRACE2(@"SongList: setMusicPlayer: mp=%@", mp);

	musicPlayer = mp;
	
	[self registerForMediaPlayerNotifications];
}
#endif

// ----------------------------------------------------------------------------------------------------------
- (NSArray*) saveToArray
{
	NSMutableArray *arr = [NSMutableArray arrayWithCapacity: [list count]];
	Song *song;
	
	for (song in list)
	{
		//[arr addObject: [song saveToDict]];
		[arr addObject: song.fileName ];
	}

	ATRACE2(@"SongList: saveToArray: arr=%@", [arr description]);

	return arr;
}

// ----------------------------------------------------------------------------------------------------------
- (void) saveToDisk
{
	ATRACE(@"SongList saveToDisk: dirty=%d count=%d", dirty, [self songCount]);
	
	//if (! dirty)
	//	return;
	
	NSString		*documentsDirectory = [AppDelegate localDir];
    NSString		*path = [documentsDirectory stringByAppendingPathComponent: kAppPlistFileName ];
	
	NSDictionary *appDict = 
		[NSDictionary dictionaryWithObjectsAndKeys: 
			[NSNumber numberWithInt: nextSongID], kNextSongIDKey,
			[self saveToArray], kSongFileNameArrayKey,
			nil];

	[appDict writeToFile: path atomically: YES];
	
	dirty = NO;
}

// ----------------------------------------------------------------------------------------------------------
// Restore SongList for a dictionary
- (void) resumeFromDict: (NSDictionary*) appDict
{
	nextSongID = [[appDict objectForKey: kNextSongIDKey] intValue];
	NSArray			*arr = [appDict objectForKey: kSongFileNameArrayKey ];

	//ATRACE(@"SongList: resumeFromDict dict=%@ count %d ", appDict, [arr count]);
	ATRACE2(@"SongList: resumeFromDict count %d ", [arr count]);

	if (arr)
	{
		// Create place hold song objects, only fileName is set.
		Song		*newSong;
		NSString	*fileName;
		for (fileName in arr)
		{
			newSong = [[Song alloc] init];
			
			newSong.fileName = fileName;
			
			[list addObject: newSong];
			
			[newSong release];
		}
	}
}

// ----------------------------------------------------------------------------------------------------------
- (void) addSongFrom: (NSString *)songClipsRef songLabel: (NSString *) songLabel
{
	ATRACE(@"SongList: addSongFrom songClipsRef=%@ songLabel=%@", songClipsRef, songLabel);
	
	Song		*newSong;
	
	newSong = [[Song alloc] initWithClipsRef: songClipsRef songLabel: songLabel];
	
	if (newSong)
	{
		[list addObject: newSong];
		
		// Finished with this reference to the song
		[newSong release];
		
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
    if ([[NSFileManager defaultManager] fileExistsAtPath: path])
	{
		// Read in app plist .
		appDict = [NSDictionary dictionaryWithContentsOfFile: path];
		if (appDict)
		{
			[[SongList default] resumeFromDict: appDict];
		}
	}
#if APP_KDHANUMAN
	else
	{
		// No app plist. Create default song
		NSString *filePath  = [[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:@"Hallelujah-Chalisa-clips2.txt"];
		NSString *str = [NSString stringWithContentsOfFile: filePath encoding:NSUTF8StringEncoding  error: nil];
		
		ATRACE(@"SongList: resumeFromDisk str length=%d", [str length]);

		if (str)
		{
			Song *newSong = [[SongList default] importSongFromString: str intoSong: nil;
			
			[[SongList default] selectSongKD: newSong];
		}
	}
#endif
#if APP_GALLERY2
	else
	{
		NSMutableArray	*arr = [NSMutableArray arrayWithCapacity: 10];
		[arr addObject: [NSArray arrayWithObjects: 
						 @"www.j4u2.com/songclips/songs/Krishna-Das/Baba-Hanuman-clips.txt", @"Baba Hanuman", nil]];
		[arr addObject: [NSArray arrayWithObjects: 
						 @"www.j4u2.com/songclips/songs/Krishna-Das/Baba-Hanuman-img-clips.txt", @"Baba Hanuman (with images)", nil]];
		[arr addObject: [NSArray arrayWithObjects: 
						 @"www.j4u2.com/songclips/songs/Krishna-Das/Hallelujah-Chalisa-clips.txt", @"Hallelujah Chalisa (Flow Of Grace)", nil]];
		[arr addObject: [NSArray arrayWithObjects: 
						 @"www.j4u2.com/songclips/songs/Krishna-Das/Hallelujah-Chalisa-clips2.txt", @"Hallelujah Chalisa (Flow of Grace)", nil]];
		[arr addObject: [NSArray arrayWithObjects: 
						 @"www.j4u2.com/songclips/songs/Krishna-Das/Hanuman-Chaleesa-img-clips.txt", @"Hanuman Chaleesa (with Images and English)", nil]];
		[arr addObject: [NSArray arrayWithObjects: 
						 @"www.j4u2.com/songclips/songs/Krishna-Das/Hanuman-Puja-clips.txt", @"Hanuman Puja", nil]];
		[arr addObject: [NSArray arrayWithObjects: 
						 @"www.j4u2.com/songclips/songs/Patanjali/book1-clips.txt", @"Patanjali's Yoga Sutra Book 1", nil]];
		[arr addObject: [NSArray arrayWithObjects: 
						 @"www.j4u2.com/songclips/songs/Patanjali/book2-clips.txt", @"Patanjali's Yoga Sutra Book 2", nil]];
		[arr addObject: [NSArray arrayWithObjects: 
						 @"www.j4u2.com/songclips/songs/ashtanga-info/open-clip.txt", @"The Ashtanga Yoga Mantra", nil]];
		NSArray			*arr2;
		NSString		*songRef;
		NSString		*songLabel;
		for (arr2 in arr)
		{
			songRef = [arr2 objectAtIndex: 0];
			songLabel = [arr2 objectAtIndex: 1];
			[[SongList default] addSongFrom: songRef songLabel: songLabel];
		}
	}
#endif
#if APP_GALLERY
	 else
	 {
		 NSMutableArray	*arr = [NSMutableArray arrayWithCapacity: 10];
		 [arr addObject: @"/clips/Baba-Hanuman-clips.txt" ];
		 [arr addObject: @"/clips/Baba-Hanuman-img-clips.txt" ];
		 [arr addObject: @"/clips/Hallelujah-Chalisa-clips.txt" ];
		 [arr addObject: @"/clips/Hallelujah-Chalisa-clips2.txt" ];
		 [arr addObject: @"/clips/Hanuman-Chaleesa-img-clips.txt" ];
		 [arr addObject: @"/clips/Hanuman-Puja-clips.txt" ];
		 [arr addObject: @"/clips/Hanuman-Puja-eng-clips.txt" ];
		 [arr addObject: @"/clips/book1-clips.txt" ];
		 [arr addObject: @"/clips/book2-clips.txt" ];
		 [arr addObject: @"/clips/open-clip.txt" ];
		 NSString		*songRef;
		 for (songRef in arr)
		 {
			 NSString *filePath  = [[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:songRef];
			 NSString *str = [NSString stringWithContentsOfFile: filePath encoding:NSUTF8StringEncoding  error: nil];
			 
			 ATRACE(@"SongList: resumeFromDisk songRef=%@ str length=%d", songRef, [str length]);
			 
			 if (str)
			 {
				 Song *newSong = [[SongList default] importSongFromString: str intoSong: nil];
				 
				 //[[SongList default] selectSongKD: newSong];
			}
		 }
	 }
#endif
	
	[[SongList default] resumeSongSettings];
}

#if APP_KDHANUMAN
// ----------------------------------------------------------------------------------------------------------
- (void) selectSongKD: (Song *) newSong;
{
	[newSong initKD];
	
	[self selectSong: newSong];
}
#endif

// ----------------------------------------------------------------------------------------------------------
- (Song*) importSongFromString: (NSString *) str intoSong: (Song*) intoSong
{
	ATRACE2(@"SongList: importSongFromString str=%@ intoSong=%@", str, intoSong);
	Song		*newSong;
	
	newSong = intoSong;
	if (! newSong)
	{
		newSong = [Song alloc];
	}
	newSong = [newSong initFromExportString: str];
	
	if (! intoSong)
	{
		[list addObject: newSong];
		
		// Finished with this reference to the song
		[newSong release];
	}
	
	[self saveToDisk];
	
	return newSong;
}

// ----------------------------------------------------------------------------------------------------------
- (void) createSongsForNewMediaItems: (NSArray*) newMediaItems
{
	ATRACE(@"SongList:createSongsForNewMediaItems newMediaItems=%@", newMediaItems);

	MPMediaItem *mediaItem;
	Song		*newSong;
	
	for (mediaItem in newMediaItems)
	{
		newSong = [[Song alloc] initWithMediaItem: mediaItem ];
		
		[list addObject: newSong];
		
		[newSong release];
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
- (void) removeSongAtIndex: (NSUInteger) index
{
	ATRACE(@"SongList: removeObjectAtIndex: index=%d\n", index);
	Song *song = [list objectAtIndex: index];
	if (song.fileName)
	{
		ATRACE(@"SongList: removeObjectAtIndex: removing directory=%@\n", [song songDirectoryPath]);
		[[NSFileManager defaultManager] removeItemAtPath: [song songDirectoryPath] error:NULL];
	}
	[list removeObjectAtIndex: index];

	if (currentPlayingIndex == index)
	{
		ATRACE(@"  STOPPING currentPlayingIndex=%d\n", currentPlayingIndex);
		[musicPlayer stop];
		if (currentPlayingIndex >= [self songCount])
			currentPlayingIndex = 0;
		[self clearRememberedSettings];
		[self setupSongForIndex: currentPlayingIndex];
	}
	else if (currentPlayingIndex > index)
	{
		currentPlayingIndex--;
		[self rememberCurrentSongIndex];
	}
	
	[self saveToDisk];
}

// ----------------------------------------------------------------------------------------------------------
- (void)removeSong:(Song*)dict1
{
	NSUInteger	index = [list indexOfObjectIdenticalTo: dict1];
	
	ATRACE2(@"SongList: removeObject: dict=%lx index=%d rc=%d\n", dict1, index, [dict1 retainCount]);
	
	if (index !=  NSNotFound)
	{
		[self removeSongAtIndex:index];
	}
}

// ----------------------------------------------------------------------------------------------------------
- (Song*) songAtIndex: (NSUInteger) index
{
	Song *song = [list objectAtIndex: index];
	if (! song.title)
	{
		[song restoreFromDisk];
	}
	return song;
}

// ----------------------------------------------------------------------------------------------------------
- (NSUInteger) songCount
{
	return [list count];
}

// ----------------------------------------------------------------------------------------------------------
- (Song*) currentSong
{
	if (currentPlayingIndex < [list count])
		return [list objectAtIndex: currentPlayingIndex];
	return nil;
}

// ----------------------------------------------------------------------------------------------------------
- (NSUInteger) currentSongIndex
{
	return currentPlayingIndex;
}

// ----------------------------------------------------------------------------------------------------------
- (NSUInteger) currentClipIndex
{
	return [[self currentSong] clipIndexForTime: [self currentTime]];
}

// ----------------------------------------------------------------------------------------------------------
- (void) playSongAt: (NSUInteger) index
{
	[self setupSongForIndex: index];
	
	self.currentTime = 0.0;
	
	[self play];
}

// ----------------------------------------------------------------------------------------------------------
- (void) selectSong: (Song *) newSong
{
	NSUInteger	index = [list indexOfObjectIdenticalTo: newSong];
	
	ATRACE(@"SongList: selectSong: newSong=%@ index=%d rc=%d\n", newSong, index, [newSong retainCount]);
	
    [self checkPrefSync];
    
	if (index !=  NSNotFound)
	{
		[self setupSongForIndex: index];
        
        ATRACE(@"SongList: selectSong: newSong.currentPos=%f\n", newSong.currentPos);

        self.currentTime = newSong.currentPos;
        
        clipStartTime = self.currentTime;
	}
}

// ----------------------------------------------------------------------------------------------------------
- (void) play
{
	if (! [self currentSong])
		return;
	
	if (noMediaItem)
	{
		ATRACE(@"SongList play noMediaItem isPlaying=%d noMediaOffsetTime=%f noMediaCurrentTime=%f",
			   noMediaIsPlaying, noMediaOffsetTime, noMediaCurrentTime);
		if (! noMediaIsPlaying)
		{
			noMediaOffsetTime = [NSDate timeIntervalSinceReferenceDate] - noMediaCurrentTime;
			noMediaIsPlaying = YES;
		}
		return;
	}
	if (musicPlayer.nowPlayingItem == nil)
	{
		// musicPlayer has dropped current Song, re-establish
		[self setupSongForIndex: currentPlayingIndex];
		musicPlayer.currentPlaybackTime = clipStartTime;
	}
	[musicPlayer play];
}

// ----------------------------------------------------------------------------------------------------------
- (void) pause
{
	if (noMediaItem)
	{
		ATRACE(@"SongList pause noMediaItem isPlaying=%d noMediaOffsetTime=%f noMediaCurrentTime=%f",
			   noMediaIsPlaying, noMediaOffsetTime, noMediaCurrentTime);
		if (noMediaIsPlaying)
		{
			noMediaCurrentTime = [NSDate timeIntervalSinceReferenceDate] - noMediaOffsetTime;
			noMediaIsPlaying = NO;
			clipStartTime = noMediaCurrentTime;
		}
		return;
	}
	// Set currenttime so its remember dropping into pause
	if (musicPlayer && [musicPlayer playbackState] == MPMusicPlaybackStatePlaying)
	{
		ATRACE(@"SongList: pause musicPlayer.currentPlaybackTime=%f", musicPlayer.currentPlaybackTime);
		clipStartTime = musicPlayer.currentPlaybackTime;
	}
	[musicPlayer pause];
}

// ----------------------------------------------------------------------------------------------------------
// Prepare string to use as file name prefix
- (NSString*) safePrefix: (NSString*) preFix
{
	preFix = [preFix stringByReplacingOccurrencesOfString: @"/" withString: @""];
	preFix = [preFix stringByReplacingOccurrencesOfString: @" " withString: @""];
#define kMaxPrefixLen	8
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
	
	dirty = YES;
	//[self saveToDisk];
	
	return nextName;
}

// ----------------------------------------------------------
- (void) setClipStartTime: (NSTimeInterval) newTime
{
	clipStartTime = newTime;
}
                             
// --------------------------------------------------------------------------------------------------------
- (void) reportCurrentTime
{
	ATRACE2(@"SongList: reportCurrentTime:");
	
	//if (delegate)
	{
		// Inform delete of current playback time
		NSTimeInterval timeToReport = [self currentTime];;
		//MPMusicPlaybackState pstate = [musicPlayer playbackState];
		
		ATRACE2(@"SongList: timeToReport=%f clipStartTime=%f playbackState=%d ", 
				timeToReport, clipStartTime, [musicPlayer playbackState]);
		
		//if (pstate != MPMusicPlaybackStatePlaying)
		if (! [self isPlaying])
		{
			ATRACE2(@"SongList musicPlayer.currentPlaybackTime - clipStartTime = %f", 
					musicPlayer.currentPlaybackTime - clipStartTime);
			timeToReport = clipStartTime;
		}
		[delegate timeReport: timeToReport];
		
		// On a slow interval...
		// Write to prefs current play back time and sync for other pref updates
		NSTimeInterval	now = [NSDate timeIntervalSinceReferenceDate];
		if (now - lastTimeSync > kSyncUpdateInterval)
		{
			lastTimeSync = now;
			if (musicPlayer )
			{
				if (timeToReport != lastCurrentPlayTimeSync)
				{
                    [self saveTimeToPref: timeToReport];
				}
			}
            //[self checkPrefSync];
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
// ----------------------------------------------------------------------------------------------------------

@end
