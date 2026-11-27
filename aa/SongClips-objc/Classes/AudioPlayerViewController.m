/*

 */

#import "AudioPlayerViewController.h"

#import "AppDelegate.h"
#import "AppUtil.h"
#include <AudioToolbox/AudioToolbox.h>

#define kTimerInterval		1.0


// ------------------------------------------------------------------------------------------------------------
static void interruptionListenerCallback ( void	*inUserData, UInt32	interruptionState ) 
{
	// This callback, being outside the implementation block, needs a reference 
	//	to the AudioViewController object. You provide this reference when
	//	initializing the audio session (see the call to AudioSessionInitialize).
	//AudioPlayerViewController *controller = (AudioPlayerViewController *) inUserData;

	ATRACE2(@"interruptionListenerCallback. interruptionState=%d", interruptionState);

	if (interruptionState == kAudioSessionBeginInterruption) 
	{
		ATRACE(@"Interrupted. Stopping playback or recording.");
#if 0
		if (controller.audioRecorder) {
			// if currently recording, stop
			[controller recordOrStop: (id) controller];
		} else if (controller.audioPlayer) {
			// if currently playing, pause
			[controller pausePlayback];
			controller.interruptedOnPlayback = YES;
		}
#endif		
	}
	else if (interruptionState == kAudioSessionEndInterruption )
	//else if ((interruptionState == kAudioSessionEndInterruption) && controller.interruptedOnPlayback)
	{
#if 0
		// if the interruption was removed, and the app had been playing, resume playback
		[controller resumePlayback];
		controller.interruptedOnPlayback = NO;
#endif
	}
}


// ------------------------------------------------------------------------------------------------------------
// ------------------------------------------------------------------------------------------------------------
@implementation AudioPlayerViewController

//@synthesize player;
@synthesize url;
@synthesize fileName;
@synthesize fFileName;
@synthesize fLeft;
@synthesize fRight;
@synthesize fProgress;
@synthesize fStopPlayButton;
//@synthesize fVolume;

// --------------------------------------------------------------------------------------------------------

// --------------------------------------------------------------------------------------------------------
- (IBAction)actionStopPlay:(id)sender
{
	ATRACE2(@"AudioPlayerViewController: Play ");
	ATRACE2(@"AudioPlayerViewController: player=%@ playing=%d duration=%f currentTime=%f", player, player.playing, player.duration, player.currentTime);
	ATRACE2(@" volume=%f currentTime=%f", player.volume, player.currentTime);

	if (player.playing)
	{
		[player stop];
		[fStopPlayButton setTitle: @"Play" forState: UIControlStateNormal];
	}
	else
	{
		[player play];
		[fStopPlayButton setTitle: @"Stop" forState: UIControlStateNormal];
	}
}

// --------------------------------------------------------------------------------------------------------
- (void)viewWillAppear:(BOOL)animated
{
	ATRACE2(@"AudioPlayerViewController: url=%@", url);

	if (! updateTimer) 
	{
		updateTimer = [NSTimer scheduledTimerWithTimeInterval: kTimerInterval 
													   target: self 
													 selector: @selector(timerCheck:)
													 userInfo: nil
													  repeats: YES];
	}
	[fProgress addTarget:self action:@selector(sliderAction:) forControlEvents:UIControlEventValueChanged];

	NSError	*error = nil;
	
	fProgress.value = 0.0;
	fFileName.text = fileName;
	
	player = [[AVAudioPlayer alloc] initWithContentsOfURL: url error: &error];
	//[player initWithContentsOfURL: url error: &error];
	if (error)
	{
		//NSString* str = [NSString stringWithFormat:@"%@ %@ %@", [error localizedDescription]];
		NSString* str = [error localizedDescription];
		[AppUtil showMsg:str title: @"Error Playing Audio"];

		ATRACE2(@"AudioPlayerViewController: player=%@ err=%@", player, [error localizedDescription]);

		player = nil;
	}

	ATRACE2(@"AudioPlayerViewController: player=%@ volume=%f", player, player.volume);

	player.delegate = self;	

	ATRACE2(@"AudioPlayerViewController: player=%@ playing=%d duration=%f currentTime=%f", player, player.playing, player.duration, player.currentTime);
	ATRACE2(@" volume=%f currentTime=%f", player.volume, player.currentTime);

	AudioSessionInitialize ( NULL, NULL, interruptionListenerCallback, (__bridge void *)(self) );
	
	UInt32 cat = kAudioSessionCategory_MediaPlayback;
	AudioSessionSetProperty(kAudioSessionProperty_AudioCategory, sizeof(cat), &cat );

	AudioSessionSetActive (YES);

	[player play];
}

// --------------------------------------------------------------------------------------------------------
- (void)viewWillDisappear:(BOOL)animated
{
	[player stop];

	AudioSessionSetActive (NO);
}

// --------------------------------------------------------------------------------------------------------
- (void)sliderAction:(id)sender
{
	if (player.playing)
		[self actionStopPlay: self];
	player.currentTime = fProgress.value * player.duration;
}

// --------------------------------------------------------------------------------------------------------
- (void) timerCheck:(NSTimer*)theTimer
{
	ATRACE2(@"AudioPlayerViewController: timerCheck:");

	double		ratio = 0.0;
	
	fLeft.text = [AppUtil formatDoubleDuration: player.currentTime];
	
	fRight.text = [AppUtil formatDoubleDuration: player.duration];
	
	if (player.duration > 0.0)
		ratio = player.currentTime / player.duration;
	//fProgress.progress = ratio;
	if (! fProgress.tracking)
	{
		fProgress.value = ratio;
		if (player.playing)
		{
			[fStopPlayButton setTitle: @"Stop" forState: UIControlStateNormal];
		}
		else
		{
			[fStopPlayButton setTitle: @"Play" forState: UIControlStateNormal];
		}
	}
}

// --------------------------------------------------------------------------------------------------------
//  AVAudioPlayerDelegate
- (void)audioPlayerBeginInterruption:(AVAudioPlayer *)mplayer 
{
	AFLOG(@"AudioPlayerViewController: audioPlayerBeginInterruption");
}

- (void)audioPlayerDecodeErrorDidOccur:(AVAudioPlayer *)mplayer 
								 error:(NSError *)error
{
	AFLOG(@"AudioPlayerViewController: audioPlayerDecodeErrorDidOccur error=%@", [error description]);
}

- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)mplayer 
					   successfully:(BOOL)flag 
{
	ATRACE2(@"AudioPlayerViewController: audioPlayerDidFinishPlaying");
}

- (void)audioPlayerEndInterruption:(AVAudioPlayer *)mplayer
{
	AFLOG(@"AudioPlayerViewController: audioPlayerEndInterruption");
}

// --------------------------------------------------------------------------------------------------------
// --------------------------------------------------------------------------------------------------------


@end

