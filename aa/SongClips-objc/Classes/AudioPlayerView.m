/*

 */

#import "AudioPlayerView.h"
#import "AppDefs.h"

//#import "EP_AppState.h"
//#import "EP_AppStateInternal.h"
//#import "EP_AppUtil.h"
#include <AudioToolbox/AudioToolbox.h>

#define kTimerInterval		1.0

// ------------------------------------------------------------------------------------------------------------
// ------------------------------------------------------------------------------------------------------------
@implementation AudioPlayerView

@synthesize delegate;

// --------------------------------------------------------------------------------------------------------
- (void)dealloc
{
	
	[super dealloc];
}

// --------------------------------------------------------------------------------------------------------
- (IBAction)actionStopPlay:(id)sender
{
	ATRACE(@"AudioPlayerView: Play ");
	ATRACE2(@"AudioPlayerView: player=%@ playing=%d duration=%f currentTime=%f", player, player.playing, player.duration, player.currentTime);
	ATRACE2(@" volume=%f currentTime=%f", player.volume, player.currentTime);
#if 0
	if (g_ep_app.audioPlayer.playing)
	{
		[g_ep_app.audioPlayer stop];
		[fStopPlayButton setTitle: @"Play" forState: UIControlStateNormal];
	}
	else
	{
		[g_ep_app.audioPlayer play];
		[fStopPlayButton setTitle: @"Stop" forState: UIControlStateNormal];
	}
#endif
}

// --------------------------------------------------------------------------------------------------------
- (IBAction)actionClose:(id)sender
{
	ATRACE(@"AudioPlayerView: Close ");
#if 0

	[g_ep_app audioPlayStop];

	[delegate audioDone: self ];
#endif
}

// --------------------------------------------------------------------------------------------------------
//- (void)viewWillAppear:(BOOL)animated
- (void) start
{
#if 0
	ATRACE(@"AudioPlayerView: start url=%@ fView=%@", url, fView);
	
	//[self addSubview:fView];
	
	if (! updateTimer) 
	{
		updateTimer = [NSTimer scheduledTimerWithTimeInterval: kTimerInterval 
													   target: self 
													 selector: @selector(timerCheck:)
													 userInfo: nil
													  repeats: YES];
	}
	[fProgress addTarget:self action:@selector(sliderAction:) forControlEvents:UIControlEventValueChanged];

	fProgress.value = 0.0;
	fFileName.text = fileName;
	
	[g_ep_app audioPlayURL: url ];
	
	g_ep_app.audioPlayer.delegate = self;
#endif
	
}

// --------------------------------------------------------------------------------------------------------
//- (void)viewWillDisappear:(BOOL)animated
- (void) stop
{
#if 0
	ATRACE(@"AudioPlayerView: stop ");
	
	[g_ep_app audioPlayStop];
#endif
}

// --------------------------------------------------------------------------------------------------------
- (void)sliderAction:(id)sender
{
#if 0
	if (g_ep_app.audioPlayer.playing)
		[self actionStopPlay: self];
	g_ep_app.audioPlayer.currentTime = fProgress.value * g_ep_app.audioPlayer.duration;
#endif
}

// --------------------------------------------------------------------------------------------------------
- (void) timerCheck:(NSTimer*)theTimer
{
	ATRACE2(@"AudioPlayerView: timerCheck: ");
#if 0

	double		ratio = 0.0;
	
	ATRACE2(@"AudioPlayerView: timerCheck: fLeft=%@", fLeft);
	ATRACE2(@"AudioPlayerView: timerCheck: fLeft.text=%@", fLeft.text);

	fLeft.text = [EP_AppUtil formatDoubleDuration: g_ep_app.audioPlayer.currentTime];
	
	fRight.text = [EP_AppUtil formatDoubleDuration: g_ep_app.audioPlayer.duration];
	
	if (g_ep_app.audioPlayer.duration > 0.0)
		ratio = g_ep_app.audioPlayer.currentTime / g_ep_app.audioPlayer.duration;

	if (! fProgress.tracking)
	{
		fProgress.value = ratio;
		if (g_ep_app.audioPlayer.playing)
		{
			[fStopPlayButton setTitle: @"Stop" forState: UIControlStateNormal];
		}
		else
		{
			[fStopPlayButton setTitle: @"Play" forState: UIControlStateNormal];
		}
	}
#endif
}

// --------------------------------------------------------------------------------------------------------
- (IBAction) playOrPauseMusic: (id) sender
{
}

// --------------------------------------------------------------------------------------------------------
- (IBAction) nextClipAction: (id) sender
{
}

// --------------------------------------------------------------------------------------------------------
- (IBAction) previousClipAction: (id) sender
{
}

// --------------------------------------------------------------------------------------------------------
- (IBAction) loopClipAction: (id) sender
{
}

// --------------------------------------------------------------------------------------------------------
- (IBAction) showClipsAction: (id) sender
{
}


// --------------------------------------------------------------------------------------------------------
// --------------------------------------------------------------------------------------------------------


@end

