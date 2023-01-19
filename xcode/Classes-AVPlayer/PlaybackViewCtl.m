/*

Based on  AVPlayerDemoPlaybackViewController.h Version: 1.1

*/


#import "PlaybackViewCtl.h"
#import "PlaybackView.h"

#import "AppDefs.h"

/* Asset keys */
NSString * const kTracksKey         = @"tracks";
NSString * const kPlayableKey		= @"playable";

/* PlayerItem keys */
NSString * const kStatusKey         = @"status";

/* AVPlayer keys */
NSString * const kRateKey			= @"rate";
NSString * const kCurrentItemKey	= @"currentItem";

// ----------------------------------------------------------------------------------------------------------
@interface PlaybackViewCtl (Player)
- (void)removePlayerTimeObserver;
- (CMTime)playerItemDuration;
//- (BOOL)isPlaying;
- (void)playerItemDidReachEnd:(NSNotification *)notification ;
- (void)observeValueForKeyPath:(NSString*) path ofObject:(id)object change:(NSDictionary*)change context:(void*)context;
- (void)prepareToPlayAsset:(AVURLAsset *)asset withKeys:(NSArray *)requestedKeys;
@end

static void *PlaybackViewCtlRateObservationContext = &PlaybackViewCtlRateObservationContext;
static void *PlaybackViewCtlStatusObservationContext = &PlaybackViewCtlStatusObservationContext;
static void *PlaybackViewCtlCurrentItemObservationContext = &PlaybackViewCtlCurrentItemObservationContext;

#pragma mark -
// ----------------------------------------------------------------------------------------------------------
@implementation PlaybackViewCtl

@synthesize delegate;
@synthesize mPlayer;
@synthesize mPlayerItem;
@synthesize mPlaybackView;

// ----------------------------------------------------------------------------------------------------------
- (void)dealloc
{
    ATRACE2(@"%p PlaybackViewCtl: dealloc mURL=%@ mPlaybackView=%@", self, mURL, mPlaAVPlayerItemDidPlayToEndTimeNotification
            ybackView);
    ATRACE(@"%p PlaybackViewCtl: dealloc ", self);

	[self removePlayerTimeObserver];
	
	[mPlayer removeObserver:self forKeyPath: kRateKey];
    
	[mPlayer removeObserver:self forKeyPath: kCurrentItemKey];
    
	[mPlayerItem removeObserver:self forKeyPath: kStatusKey ];

    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:AVPlayerItemDidPlayToEndTimeNotification
                                                  object:self.mPlayerItem];

	[mPlayer pause];
	
	
}

// ----------------------------------------------------------------------------------------------------------
- (void)setURL:(NSURL*)URL
{
    ATRACE2(@"%p PlaybackViewCtl: setURL url=%@ mPlaybackView=%@", self, URL, mPlaybackView);

	if (! mPlaybackView)
        return;
	if (mURL != URL) {
		mURL = [URL copy];
        // Create an asset for inspection of a resource referenced by a given URL.
        // Load the values for the asset keys "tracks", "playable".
        AVURLAsset *asset = [AVURLAsset URLAssetWithURL:mURL options:nil];
        NSArray *requestedKeys = [NSArray arrayWithObjects:kTracksKey, kPlayableKey, nil];
        ATRACE(@"%p PlaybackViewCtl: setURL asset=%@ ", self, asset);

        /* Tells the asset to load the values of any of the specified keys that are not already loaded. */
        [asset loadValuesAsynchronouslyForKeys:requestedKeys completionHandler:
         ^{		 
             dispatch_async( dispatch_get_main_queue(), 
                            ^{
                                /* IMPORTANT: Must dispatch to main queue in order to operate on the AVPlayer and AVPlayerItem. */
                                [self prepareToPlayAsset:asset withKeys:requestedKeys];
                            });
         }];
	}
}

// ----------------------------------------------------------------------------------------------------------
- (NSURL*)URL
{
	return mURL;
}

// ----------------------------------------------------------------------------------------------------------
- (void) setPlaybackView: (PlaybackView*) newPlaybackView
{
    ATRACE(@"%p PlaybackViewCtl: setPlaybackView newPlaybackView=%@ _fillMode=%@", self, newPlaybackView, _fillMode);
	
	// AVLayerVideoGravityResize
	// AVLayerVideoGravityResizeAspect
	// AVLayerVideoGravityResizeAspectFill
	_fillMode = AVLayerVideoGravityResizeAspectFill;
	
    self.mPlaybackView = newPlaybackView;
    if (newPlaybackView) {
        /* Set the AVPlayer for which the player layer displays visual output. */
        [mPlaybackView setPlayer:mPlayer];
        
        /* Specifies that the player should preserve the video’s aspect ratio and
         fit the video within the layer’s bounds. */
		if (! _fillMode) {
			ATRACE(@"PlaybackViewCtl: setPlaybackView _fillMode EMPTY ");
			_fillMode = AVLayerVideoGravityResizeAspect;
		}
        [mPlaybackView setVideoFillMode: _fillMode];
    }
    self.URL = nil;
}

// ----------------------------------------------------------------------------------------------------------
- (void)play
{
	/* If we are at the end of the movie, we must seek to the beginning first 
		before starting playback. */
	if (YES == seekToZeroBeforePlay) 
	{
		seekToZeroBeforePlay = NO;
		[mPlayer seekToTime:kCMTimeZero];
	}

	[mPlayer play];
}

// ----------------------------------------------------------------------------------------------------------
- (void)pause
{
	[mPlayer pause];
}

// ----------------------------------------------------------------------------------------------------------
- (float) currentRate
{
	return mPlayer.rate;
}

- (void) setCurrentRate: (float) newRate
{
	ATRACE(@"PlaybackViewCtl: setCurrentRate newRate=%f", newRate);
	
	mPlayer.rate = newRate;
}

// ----------------------------------------------------------------------------------------------------------
- (NSTimeInterval) currentTime
{
    ATRACE2(@"PlaybackViewCtl: currentTime=%f pendingSeek=%d pendingSeekTime=%f", CMTimeGetSeconds([mPlayer currentTime]), pendingSeek, pendingSeekTime);
    
    if (pendingSeek)
        return pendingSeekTime;
    
    return CMTimeGetSeconds([mPlayer currentTime]);
}

// ----------------------------------------------------------------------------------------------------------
- (void) requestSeek
{
    // - (void)seekToTime:(CMTime)time toleranceBefore:(CMTime)toleranceBefore toleranceAfter:(CMTime)toleranceAfter completionHandler:(void (^)(BOOL finished))completionHandler
    // kCMTimeZero

    [mPlayer seekToTime: CMTimeMakeWithSeconds(pendingSeekTime, NSEC_PER_SEC)
         toleranceBefore: kCMTimeZero
         toleranceAfter: kCMTimeZero
      completionHandler: ^(BOOL finished) {
          //pendingSeek = FALSE;
          pendingSeek = !finished;
          
          if (finished)
          {
              dispatch_async( dispatch_get_main_queue(),
                             ^{
                                    [delegate playbackViewCtl: self seekCompleted: pendingSeekTime];
                             } );
          }
      }];
}

// ----------------------------------------------------------------------------------------------------------
- (void) setCurrentTime: (NSTimeInterval) newTime
{
    ATRACE(@"%p PlaybackViewCtl: setCurrentTime=%f ", self, newTime);
    
    pendingSeek = YES;
    pendingSeekTime = newTime;
    
    if (assetReady)
    {
        [self requestSeek];
    }
    
    // - (void)seekToTime:(CMTime)time completionHandler:(void (^)(BOOL finished))completionHandler

}

// ----------------------------------------------------------------------------------------------------------
- (BOOL) isPlaying
{
	//return mRestoreAfterScrubbingRate != 0.f || [mPlayer rate] != 0.f;
    return [mPlayer rate] != 0.0f;
}

// ----------------------------------------------------------------------------------------------------------
- (void) checkForPendingSeek
{
    [mPlayer seekToTime: CMTimeMakeWithSeconds(pendingSeekTime, NSEC_PER_SEC)];
}

// ----------------------------------------------------------------------------------------------------------
/* Requests invocation of a given block during media playback to update the movie scrubber control. */
-(void)initScrubberTimer
{
#if 0
	double interval = .1f;
	
	CMTime playerDuration = [self playerItemDuration];
	if (CMTIME_IS_INVALID(playerDuration)) 
	{
		return;
	} 
	double duration = CMTimeGetSeconds(playerDuration);
	if (isfinite(duration))
	{
		CGFloat width = CGRectGetWidth([mScrubber bounds]);
		interval = 0.5f * duration / width;
	}

	/* Update the scrubber during normal playback. */
	mTimeObserver = [[mPlayer addPeriodicTimeObserverForInterval:CMTimeMakeWithSeconds(interval, NSEC_PER_SEC) 
								queue:NULL /* If you pass NULL, the main queue is used. */
								usingBlock:^(CMTime time) 
                                            {
                                                [self syncScrubber];
                                            }] retain];
#endif

}

// ----------------------------------------------------------------------------------------------------------
/* Set the scrubber based on the player current time. */
- (void)syncScrubber
{
#if 0
	CMTime playerDuration = [self playerItemDuration];
	if (CMTIME_IS_INVALID(playerDuration)) 
	{
		mScrubber.minimumValue = 0.0;
		return;
	} 

	double duration = CMTimeGetSeconds(playerDuration);
	if (isfinite(duration))
	{
		float minValue = [mScrubber minimumValue];
		float maxValue = [mScrubber maximumValue];
		double time = CMTimeGetSeconds([mPlayer currentTime]);
		
		[mScrubber setValue:(maxValue - minValue) * time / duration + minValue];
	}
#endif
}

// ----------------------------------------------------------------------------------------------------------
/* The user is dragging the movie controller thumb to scrub through the movie. */
- (void)beginScrubbing:(id)sender
{
	mRestoreAfterScrubbingRate = [mPlayer rate];
	[mPlayer setRate:0.f];
	
	/* Remove previous timer. */
	[self removePlayerTimeObserver];
}

// ----------------------------------------------------------------------------------------------------------
/* Set the player current time to match the scrubber position. */
- (void)scrub:(id)sender
{
	if ([sender isKindOfClass:[UISlider class]])
	{
		UISlider* slider = sender;
		
		CMTime playerDuration = [self playerItemDuration];
		if (CMTIME_IS_INVALID(playerDuration)) {
			return;
		} 
		
		double duration = CMTimeGetSeconds(playerDuration);
		if (isfinite(duration))
		{
			float minValue = [slider minimumValue];
			float maxValue = [slider maximumValue];
			float value = [slider value];
			
			double time = duration * (value - minValue) / (maxValue - minValue);
			
			[mPlayer seekToTime:CMTimeMakeWithSeconds(time, NSEC_PER_SEC)];
		}
	}
}

// ----------------------------------------------------------------------------------------------------------
/* The user has released the movie thumb control to stop scrubbing through the movie. */
- (void)endScrubbing:(id)sender
{
#if 0
	if (!mTimeObserver)
	{
		CMTime playerDuration = [self playerItemDuration];
		if (CMTIME_IS_INVALID(playerDuration)) 
		{
			return;
		} 
		
		double duration = CMTimeGetSeconds(playerDuration);
		if (isfinite(duration))
		{
			CGFloat width = CGRectGetWidth([mScrubber bounds]);
			double tolerance = 0.5f * duration / width;

			mTimeObserver = [[mPlayer addPeriodicTimeObserverForInterval:CMTimeMakeWithSeconds(tolerance, NSEC_PER_SEC) queue:NULL usingBlock:
			^(CMTime time)
			{
				[self syncScrubber];
			}] retain];
		}
	}

	if (mRestoreAfterScrubbingRate)
	{
		[mPlayer setRate:mRestoreAfterScrubbingRate];
		mRestoreAfterScrubbingRate = 0.f;
	}
#endif
}

// ----------------------------------------------------------------------------------------------------------
- (BOOL)isScrubbing
{
	return mRestoreAfterScrubbingRate != 0.f;
}


@end

// ----------------------------------------------------------------------------------------------------------
@implementation PlaybackViewCtl (Player)

#pragma mark Player Item

// ----------------------------------------------------------------------------------------------------------
/* Called when the player item has played to its end time. */
- (void)playerItemDidReachEnd:(NSNotification *)notification 
{
	/* After the movie has played to its end time, seek back to time zero 
		to play it again. */
	//seekToZeroBeforePlay = YES;
    
    dispatch_async( dispatch_get_main_queue(),
                   ^{
                       [delegate playbackViewCtldidReachEnd: self];
                   } );
}

/* ---------------------------------------------------------
 **  Get the duration for a AVPlayerItem. 
 ** ------------------------------------------------------- */

// ----------------------------------------------------------------------------------------------------------
- (CMTime)playerItemDuration
{
	AVPlayerItem *playerItem = [mPlayer currentItem];
	if (playerItem.status == AVPlayerItemStatusReadyToPlay)
	{
        /* 
         NOTE:
         Because of the dynamic nature of HTTP Live Streaming Media, the best practice 
         for obtaining the duration of an AVPlayerItem object has changed in iOS 4.3. 
         Prior to iOS 4.3, you would obtain the duration of a player item by fetching 
         the value of the duration property of its associated AVAsset object. However, 
         note that for HTTP Live Streaming Media the duration of a player item during 
         any particular playback session may differ from the duration of its asset. For 
         this reason a new key-value observable duration property has been defined on 
         AVPlayerItem.
         
         See the AV Foundation Release Notes for iOS 4.3 for more information.
         */		

		return([playerItem duration]);
	}
	
	return(kCMTimeInvalid);
}


// ----------------------------------------------------------------------------------------------------------
/* Cancels the previously registered time observer. */
-(void)removePlayerTimeObserver
{
	if (mTimeObserver)
	{
		[mPlayer removeTimeObserver:mTimeObserver];
		mTimeObserver = nil;
	}
}

#pragma mark -
#pragma mark Loading the Asset Keys Asynchronously

#pragma mark -
#pragma mark Error Handling - Preparing Assets for Playback Failed

/* --------------------------------------------------------------
 **  Called when an asset fails to prepare for playback for any of
 **  the following reasons:
 ** 
 **  1) values of asset keys did not load successfully, 
 **  2) the asset keys did load successfully, but the asset is not 
 **     playable
 **  3) the item did not become ready to play. 
 ** ----------------------------------------------------------- */

// ----------------------------------------------------------------------------------------------------------
-(void)assetFailedToPrepareForPlayback:(NSError *)error
{
    [self removePlayerTimeObserver];
    [self syncScrubber];
    
    /* Display the error. */
	UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:[error localizedDescription]
														message:[error localizedFailureReason]
													   delegate:nil
											  cancelButtonTitle:@"OK"
											  otherButtonTitles:nil];
	[alertView show];
}


#pragma mark Prepare to play asset, URL

// ----------------------------------------------------------------------------------------------------------
/*
 Invoked at the completion of the loading of the values for all keys on the asset that we require.
 Checks whether loading was successfull and whether the asset is playable.
 If so, sets up an AVPlayerItem and an AVPlayer to play the asset.
 */
- (void)prepareToPlayAsset:(AVURLAsset *)asset withKeys:(NSArray *)requestedKeys
{
    ATRACE(@"%p PlaybackViewCtl: prepareToPlayAsset asset=%@ ", self, asset);

    /* Make sure that the value of each key has loaded successfully. */
	for (NSString *thisKey in requestedKeys)
	{
		NSError *error = nil;
		AVKeyValueStatus keyStatus = [asset statusOfValueForKey:thisKey error:&error];
		if (keyStatus == AVKeyValueStatusFailed)
		{
			[self assetFailedToPrepareForPlayback:error];
			return;
		}
		/* If you are also implementing -[AVAsset cancelLoading], add your code here to bail out properly in the case of cancellation. */
	}
    
    /* Use the AVAsset playable property to detect whether the asset can be played. */
    if (!asset.playable) 
    {
        /* Generate an error describing the failure. */
		NSString *localizedDescription = NSLocalizedString(@"Item cannot be played", @"Item cannot be played description");
		NSString *localizedFailureReason = NSLocalizedString(@"The assets tracks were loaded, but could not be made playable.", @"Item cannot be played failure reason");
		NSDictionary *errorDict = [NSDictionary dictionaryWithObjectsAndKeys:
								   localizedDescription, NSLocalizedDescriptionKey, 
								   localizedFailureReason, NSLocalizedFailureReasonErrorKey, 
								   nil];
		NSError *assetCannotBePlayedError = [NSError errorWithDomain:@"StitchedStreamPlayer" code:0 userInfo:errorDict];
        
        /* Display the error to the user. */
        [self assetFailedToPrepareForPlayback:assetCannotBePlayedError];
        
        return;
    }
	
	/* At this point we're ready to set up for playback of the asset. */
    	
    /* Stop observing our prior AVPlayerItem, if we have one. */
    if (self.mPlayerItem)
    {
        /* Remove existing player item key value observers and notifications. */
        
        [self.mPlayerItem removeObserver:self forKeyPath:kStatusKey];            
		
        [[NSNotificationCenter defaultCenter] removeObserver:self
                                                        name:AVPlayerItemDidPlayToEndTimeNotification
                                                      object:self.mPlayerItem];
    }
	
    /* Create a new instance of AVPlayerItem from the now successfully loaded AVAsset. */
    self.mPlayerItem = [AVPlayerItem playerItemWithAsset:asset];

    ATRACE2(@"PlaybackViewCtl: prepareToPlayAsset self=%@ ", self);
    ATRACE2(@"PlaybackViewCtl: prepareToPlayAsset mPlayerItem=%@ ", mPlayerItem);

    /* Observe the player item "status" key to determine when it is ready to play. */
    [self.mPlayerItem addObserver:self 
                      forKeyPath:kStatusKey 
                         options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
                         context:PlaybackViewCtlStatusObservationContext];
	
    /* When the player item has played to its end time we'll toggle
     the movie controller Pause button to be the Play button */
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(playerItemDidReachEnd:)
                                                 name:AVPlayerItemDidPlayToEndTimeNotification
                                               object:self.mPlayerItem];
	
    seekToZeroBeforePlay = NO;
	
    /* Create new player, if we don't already have one. */
    if (![self player])
    {
        /* Get a new AVPlayer initialized to play the specified player item. */
        [self setPlayer:[AVPlayer playerWithPlayerItem:self.mPlayerItem]];	
		
        /* Observe the AVPlayer "currentItem" property to find out when any 
         AVPlayer replaceCurrentItemWithPlayerItem: replacement will/did 
         occur.*/
        [self.player addObserver:self 
                      forKeyPath:kCurrentItemKey 
                         options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
                         context:PlaybackViewCtlCurrentItemObservationContext];
        
        /* Observe the AVPlayer "rate" property to update the scrubber control. */
        [self.player addObserver:self 
                      forKeyPath:kRateKey 
                         options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
                         context:PlaybackViewCtlRateObservationContext];
    }
    
    /* Make our new AVPlayerItem the AVPlayer's current item. */
    if (self.player.currentItem != self.mPlayerItem)
    {
        /* Replace the player item with a new player item. The item replacement occurs 
         asynchronously; observe the currentItem property to find out when the 
         replacement will/did occur*/
        [[self player] replaceCurrentItemWithPlayerItem:self.mPlayerItem];
        
        //[self syncPlayPauseButtons];
    }
	
    //[self checkForPendingSeek];
    
}

#pragma mark -
#pragma mark Asset Key Value Observing
#pragma mark

#pragma mark Key Value Observer for player rate, currentItem, player item status

/* ---------------------------------------------------------
**  Called when the value at the specified key path relative
**  to the given object has changed. 
**  Adjust the movie play and pause button controls when the 
**  player item "status" value changes. Update the movie 
**  scrubber control when the player item is ready to play.
**  Adjust the movie scrubber control when the player item 
**  "rate" value changes. For updates of the player
**  "currentItem" property, set the AVPlayer for which the 
**  player layer displays visual output.
**  NOTE: this method is invoked on the main queue.
** ------------------------------------------------------- */

// ----------------------------------------------------------------------------------------------------------
- (void)observeValueForKeyPath:(NSString*) path
			ofObject:(id)object 
			change:(NSDictionary*)change 
			context:(void*)context
{
    ATRACE2(@"PlaybackViewCtl: observeValueForKeyPath path=%@ ", path);

    assetReady = YES;
    
	/* AVPlayerItem "status" property value observer. */
	if (context == PlaybackViewCtlStatusObservationContext) {
		//[self syncPlayPauseButtons];

        AVPlayerStatus status = [[change objectForKey:NSKeyValueChangeNewKey] integerValue];

        ATRACE2(@"PlaybackViewCtl: observeValueForKeyPath status=%d ", status);

        switch (status) {
            /* Indicates that the status of the player is not yet known because 
             it has not tried to load new media resources for playback */
            case AVPlayerStatusUnknown: {
#if 0
                [self removePlayerTimeObserver];
                [self syncScrubber];
                
                [self disableScrubber];
                [self disablePlayerButtons];
#endif
            }
            break;
                
            case AVPlayerStatusReadyToPlay: {
                readyToPlay = YES;
#if 0
                /* Once the AVPlayerItem becomes ready to play, i.e.
                 [playerItem status] == AVPlayerItemStatusReadyToPlay,
                 its duration can be fetched from the item. */
                
                [self initScrubberTimer];
                
                [self enableScrubber];
                [self enablePlayerButtons];
#endif
            }
            break;
                
            case AVPlayerStatusFailed: {
                AVPlayerItem *playerItem = (AVPlayerItem *)object;
                [self assetFailedToPrepareForPlayback:playerItem.error];
            }
            break;
        }
	}
	/* AVPlayer "rate" property value observer. */
	else if (context == PlaybackViewCtlRateObservationContext) {
        ATRACE2(@"PlaybackViewCtl: observeValueForKeyPath rate");
	}
	/* AVPlayer "currentItem" property observer. 
        Called when the AVPlayer replaceCurrentItemWithPlayerItem: 
        replacement will/did occur. */
	else if (context == PlaybackViewCtlCurrentItemObservationContext)
	{
        AVPlayerItem *newPlayerItem = [change objectForKey:NSKeyValueChangeNewKey];
        
        ATRACE2(@"PlaybackViewCtl: observeValueForKeyPath newPlayerItem=%@", newPlayerItem);

        /* Is the new player item null? */
        if (newPlayerItem == (id)[NSNull null]) {
#if 0
            [self disablePlayerButtons];
            [self disableScrubber];
#endif
        }
		else { /* Replacement of player currentItem has occurred */
            /* Set the AVPlayer for which the player layer displays visual output. */
            [mPlaybackView setPlayer:mPlayer];
            
            /* Specifies that the player should preserve the video’s aspect ratio and 
             fit the video within the layer’s bounds. */
			if (! _fillMode) {
				ATRACE(@"PlaybackViewCtl: observeValueForKeyPath _fillMode EMPTY ");
				_fillMode = AVLayerVideoGravityResizeAspect;
			}
            [mPlaybackView setVideoFillMode: _fillMode];
        }
	}
	else {
		[super observeValueForKeyPath:path ofObject:object change:change context:context];
	}
    if (readyToPlay && pendingSeek)
    {
        [self requestSeek];
    }
}

// ----------------------------------------------------------------------------------------------------------
// ----------------------------------------------------------------------------------------------------------

@end

