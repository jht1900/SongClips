/*

 */

#import "ClipEditCtl.h"
#import "SongList.h"

#import "AppDefs.h"
#import "AppUtil.h"
#import "AppDelegate.h"

#import "ClipListCtl.h"

#import "ClipPlayModeCtl.h"

#define kTimerInterval		0.5



@implementation ClipEditCtl

@synthesize songList;
@synthesize song;
@synthesize clipIndex;
@synthesize flowToClip;
@synthesize	soundRecorder;
@synthesize soundFileURL;
@synthesize	soundPlayer;

@synthesize fImageView;
@synthesize fNotes;
@synthesize fStartTime;
@synthesize fCurPos;
@synthesize fDuration;
@synthesize fScrub;
@synthesize fRecordDuration;
@synthesize fLoopSwitch;
@synthesize fPlayButton;
@synthesize fRecordButton;
@synthesize fReviewButton;
@synthesize fCameraButton;
@synthesize fPhotoButton;

@synthesize loopClipButton;
@synthesize fAddPhoto;

@synthesize popOver;

// --------------------------------------------------------------------------------------------------------

// --------------------------------------------------------------------------------------------------------
- (void) viewDidLoad 
{
    [super viewDidLoad];
	
	songList = [SongList default];

	fCameraButton.hidden = YES;
	fPhotoButton.hidden =  YES;

	BOOL hasCamera = [UIImagePickerController isSourceTypeAvailable: UIImagePickerControllerSourceTypeCamera];
	BOOL hasPhotoLib = [UIImagePickerController isSourceTypeAvailable: UIImagePickerControllerSourceTypePhotoLibrary];

	fCameraButton.hidden = !hasCamera;
	fPhotoButton.hidden =  !hasPhotoLib;
	fAddPhoto.hidden = !hasCamera && !hasPhotoLib;
	
	// Obtain a UIButton object and set its background to the UIImage object
	UIButton *buttonView = [[UIButton alloc] initWithFrame: CGRectMake (0, 0, 40, 40)];
	[buttonView setBackgroundImage: [UIImage imageNamed:@"back_arrow.png"] forState: UIControlStateNormal];
    
	UIBarButtonItem *backButton = [[UIBarButtonItem alloc] initWithCustomView: buttonView];
	[buttonView addTarget:self action:@selector(actionBack:) forControlEvents:UIControlEventTouchUpInside];
	self.navigationItem.leftBarButtonItem = backButton;

    UIBarButtonItem *customEditButton =
    [[UIBarButtonItem alloc] initWithTitle: @"Clips"
                                      style: UIBarButtonItemStylePlain
                                     target: self
                                     action: @selector(showClipsListAction:)];
	self.navigationItem.rightBarButtonItem = customEditButton;
    
}

// --------------------------------------------------------------------------------------------------------
- (IBAction) showClipsListAction: (id)sender
{
	ATRACE(@"ClipPlayCtl: showClipsListAction");

    ClipListCtl *ctl = [[ClipListCtl alloc] initWithNibName: @"SongView" bundle: nil];
    
    ctl.song = song;
    [[self navigationController] pushViewController:ctl animated:YES];
    
}

// ----------------------------------------------------------------------------------------------------------
- (IBAction) actionClips: (id)sender
{
	ATRACE(@"ClipEditCtl actionClips " );
    
    [self actionBack: nil];
}

// ----------------------------------------------------------------------------------------------------------
- (void)actionBack: (id)sender
{
	ATRACE(@"ClipEditCtl actionBack " );
	
	[[self navigationController] popViewControllerAnimated: YES];
}

// --------------------------------------------------------------------------------------------------------
// Save info back into clip
- (void) saveClip
{
	Clip	*clip = [song clipAtIndex: clipIndex ];

	clip.notation = self.fNotes.text;
	
	[self saveSongToDisk];
    
    savePending = NO;
}

// --------------------------------------------------------------------------------------------------------
- (void) updateCurPos
{
	float		factor = fScrub.value;
	float		pos = duration * factor;
	
	self.fCurPos.text = [AppUtil formatDurationUI: pos ];
}

// --------------------------------------------------------------------------------------------------------
- (void) showRecordingDuration
{
	Clip	*clip = [song clipAtIndex: clipIndex ];
	fRecordDuration.text = [AppUtil formatDoubleDuration: clip.recordingDuration];
}

// --------------------------------------------------------------------------------------------------------
// Display current, clipIndex, clip settings in UI
- (void) showClip
{
	self.title = [NSString stringWithFormat:@"Edit Clip %d of %d", clipIndex+1, [song clipCount]];
	
	Clip	*clip = [song clipAtIndex: clipIndex ];

    ATRACE(@"ClipEditCtl showClip clipIndex=%d startTime=%f", clipIndex, clip.startTime );

	startTime = clip.startTime;
	duration = clip.subDuration;
	
	self.fNotes.text = clip.notation;
	
	self.fStartTime.text = [NSString stringWithFormat:@"clip %d of %d", clipIndex+1, [song clipCount]];
	
	self.fDuration.text = [AppUtil formatDurationUI: duration ];
	
	self.fImageView.image = clip.image;

	fRecordDuration.text = [AppUtil formatDoubleDuration: clip.recordingDuration];
	
	[self updateCurPos];
	
	[songList setClipStartTime: startTime];
	if (! flowToClip)
	{
		songList.currentTime = startTime;
	}
	flowToClip = NO;
}

// --------------------------------------------------------------------------------------------------------
- (void) viewWillAppear:(BOOL)animated
{
	ATRACE(@"ClipEditCtl viewWillAppear clipIndex=%d song=%@", clipIndex, song );
	[super viewWillAppear: animated];

	loop = NO;
	
    if (clipIndex < 0)
    {
        flowToClip = YES;
        clipIndex = [songList currentClipIndex];
    }

	[self showClip];
	
	[self.fScrub addTarget:self action:@selector(scrubChangeAction:) forControlEvents:UIControlEventValueChanged];
	[self.fScrub addTarget:self action:@selector(scrubTouchUpAction:) forControlEvents:UIControlEventTouchUpInside];
	[self.fScrub addTarget:self action:@selector(scrubTouchDownAction:) forControlEvents:UIControlEventTouchDown];

	self.fNotes.delegate = self;

	[songList setDelegate: self view: avplayer];
    
}

// --------------------------------------------------------------------------------------------------------
- (void) viewWillDisappear:(BOOL)animated
{
	[super viewWillDisappear: animated];
	
    [songList clearDelegate];

    [self saveActionPending];
    
    // Indicate clipIndex should be restored:
    clipIndex = -1;
}

// --------------------------------------------------------------------------------------------------------
- (IBAction)actionPlay: (id)sender
{
	if (songList.isPlaying)
	{
		[songList pause];
	}
	else
	{
		[songList play];
	}
	fPlayButton.selected = songList.isPlaying;
}

// --------------------------------------------------------------------------------------------------------
- (IBAction)actionSplit: (id)sender
{
    [self saveActionPending];

	NSTimeInterval	newSubDuration = songList.currentTime - startTime;
	
	[song splitClipAtIndex: clipIndex newSubDuration: newSubDuration ];
	
	if (clipIndex < [song clipCount]-1)
	{
		clipIndex++;
	}
	
	[self showClip];
}

// --------------------------------------------------------------------------------------------------------
- (IBAction)actionMerge: (id)sender
{
    [self saveActionPending];

	[song removeClipAtIndex: clipIndex];
	
	if (clipIndex > 0)
		clipIndex--;
	
	[self showClip];
}

// --------------------------------------------------------------------------------------------------------
- (IBAction)actionPrevious: (id)sender
{
    [self saveActionPending];
    
	if (clipIndex > 0)
	{
		clipIndex--;
	}
	// Previous always restarts from beging of clip
	[self showClip];
}

// --------------------------------------------------------------------------------------------------------
- (IBAction)actionNext: (id)sender
{
    [self saveActionPending];

	if (clipIndex < [song clipCount]-1)
	{
		clipIndex++;
		[self showClip];
	}
	// If At last clip, don't disturb play back
}

// ----------------------------------------------------------------------------------------------------------
- (void)done_ClipPlayModeCtl:(ClipPlayModeCtl *)ctl
{
    [popOver dismissPopoverAnimated:YES];
}

// --------------------------------------------------------------------------------------------------------
- (IBAction) loopClipAction: (id) sender
{
#if 1
	ClipPlayModeCtl *ctl = [[ClipPlayModeCtl alloc] initWithNibName: @"ClipPlayModeView" bundle: nil];
	
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
    {
        UINavigationController *navCtl = [[UINavigationController alloc] initWithRootViewController:ctl];
        UIPopoverController *popCtl = [[UIPopoverController alloc] initWithContentViewController:navCtl];
        self.popOver = popCtl;
        
        ctl.isModal = YES;
        ctl.delegate = self;
        
        //  popOverRect set by verb_actionSheet
        [popOver presentPopoverFromRect:loopClipButton.bounds inView: loopClipButton permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES];
    }
    else
    {
        [[self navigationController] pushViewController:ctl animated:YES];
	}
    
#else
	loop = ! loop;
	loopClipButton.highlighted = loop;
	loopClipButton.selected = loop;
#endif
}

// --------------------------------------------------------------------------------------------------------
// Loop switch has changed value
- (void)loopSwitchAction:(id)sender
{
	ATRACE(@"ClipEditCtl loopSwitchAction fLoopSwitch=%d", fLoopSwitch.on );
	
	loop = self.fLoopSwitch.on;
}

// --------------------------------------------------------------------------------------------------------
// Slider has changed value
- (void)scrubChangeAction:(id)sender
{
	ATRACE2(@"ClipEditCtl scrubChangeAction fScrub.value=%f", fScrub.value );

	[self updateCurPos];
}

// --------------------------------------------------------------------------------------------------------
- (void)scrubTouchDownAction: (id)sender
{
	ATRACE(@"ClipEditCtl scrubTouchDownAction fScrub.value=%f", fScrub.value );
	scrubDownSceen = YES;
}

// --------------------------------------------------------------------------------------------------------
- (void)scrubTouchUpAction:(id)sender
{
	ATRACE(@"ClipEditCtl scrubTouchUpAction fScrub.value=%f", fScrub.value );
	
	// Only allow one up action, we are getting 2 in normal guesturing
	if (! scrubDownSceen)
		return;
	scrubDownSceen = NO;
	
	// Reposition player from slider
	NSTimeInterval newTime = startTime + duration * fScrub.value;
	
	songList.currentTime = newTime;
	
	ATRACE2(@"ClipEditCtl scrubChangeAction fScrub.value=%f newTime=%f", fScrub.value, newTime );
	
	[self updateCurPos];
}

#pragma mark SongListWatcher delegate____________________________

// --------------------------------------------------------------------------------------------------------
- (void) reportSongChange
{
	ATRACE2(@"ClipEditCtl reportSongChange song=%@", song );
	
	Song *newSong = [[SongList default] currentSong];
	
	if (newSong != song)
	{
		ATRACE(@"ClipEditCtl reportSongChange DIFF newSong=%@", newSong );
		return;
	}
	NSTimeInterval currentSongTime = [[SongList default] currentTime];
    
	int newClipIndex = [song clipIndexForTime: currentSongTime];
	
	ATRACE2(@"ClipEditCtl reportSongChange currentSongTime=%f clipIndex=%d clipIndex=%d", currentSongTime, newClipIndex, clipIndex);
		
	if (newClipIndex != clipIndex)
	{
		clipIndex = newClipIndex;
        
        flowToClip = YES;
        
		[self showClip];
	}
}

- (void) monitorTime
{
	ATRACE2(@"ClipView: monitorTime:");
	
	if (recording && soundRecorder)
	{
		fRecordDuration.text = [AppUtil formatDoubleDuration: soundRecorder.currentTime];
		// Track current time for duration.
		Clip	*clip = [song clipAtIndex: clipIndex ];
		clip.recordingDuration = soundRecorder.currentTime;
	}
	else if (playing && soundPlayer)
	{
		fRecordDuration.text = [AppUtil formatDoubleDuration: soundPlayer.currentTime];
	}
	else
	{
		[self showRecordingDuration];
	}
}

// --------------------------------------------------------------------------------------------------------
- (BOOL) isTracking
{
    return fScrub.tracking;
}

// --------------------------------------------------------------------------------------------------------
// Track slide to play time. 
- (void)timeReport: (NSTimeInterval) newTime 
{
    if (recordingInited)
    {
        [self monitorTime];
    }
    
	double		ratio = 0.0;
	BOOL isPlaying = songList.isPlaying;

	if (fScrub.tracking)
		return;
	
	// Only if no user not dragging slider:
	
	{
		ratio = (newTime - startTime);
		if (duration > 0.0)
		{
			ratio = ratio / duration;
			fScrub.value = ratio;
			[self updateCurPos];
		}
	}
	
    [self reportSongChange];
#if 0
	if (isPlaying)
	{
		if (newTime >= startTime + duration)
		{
			// Play to end of clilp
			if (loop)
			{
				// Lopp back to begining of clip
				songList.currentTime = startTime;
			}
			else
			{
				// Flow to next clip
				flowToClip = YES;
				[self actionNext: nil];
				flowToClip = NO;
			}
		}
		else if (newTime < startTime - 1.0)
		{
			// We are before the current clip. 
			[self reportSongChange];
		}
	}
#endif
    
	fPlayButton.selected = isPlaying;
}

// --------------------------------------------------------------------------------------------------------
#pragma mark -
#pragma mark <UITextViewDelegate> Methods

// --------------------------------------------------------------------------------------------------------
- (BOOL)textFieldShouldBeginEditing:(UITextView *)textV
{
	ATRACE(@"ClipEditCtl textFieldShouldBeginEditing" );
	return YES;
}

// --------------------------------------------------------------------------------------------------------
- (void)textViewDidBeginEditing:(UITextView *)textView
{
	ATRACE(@"ClipEditCtl textViewDidBeginEditing" );

	// provide my own Save button to dismiss the keyboard
	UIBarButtonItem* saveItem = 
		[[UIBarButtonItem alloc] initWithBarButtonSystemItem: UIBarButtonSystemItemDone 
													  target: self 
													  action:@selector(saveAction:)];
	self.navigationItem.rightBarButtonItem = saveItem;
	
    
    savePending = YES;
}

// --------------------------------------------------------------------------------------------------------
- (void) saveActionPending
{
    if (savePending)
    {
        [self saveAction: nil];
    }
}

// --------------------------------------------------------------------------------------------------------
- (void)saveAction:(id)sender
{
	ATRACE(@"ClipEditCtl saveAction" );

	// finish typing text/dismiss the keyboard by removing it as the first responder
	[self.fNotes resignFirstResponder];
	
	self.navigationItem.rightBarButtonItem = nil;	// this will remove the "save" button
	
	[self saveClip];

    savePending = NO;
}


// --------------------------------------------------------------------------------------------------------
// Commit changes
- (void)textFieldDidEndEditing:(UITextView *)textV
{
	ATRACE(@"ClipEditCtl textFieldDidEndEditing" );
	[textV resignFirstResponder];

}

#if 0
// --------------------------------------------------------------------------------------------------------
// Return closes text editing
- (BOOL)textFieldShouldReturn:(UITextView *)textV
{
	[textField resignFirstResponder];
	return YES;
}
#endif

// --------------------------------------------------------------------------------------------------------
- (IBAction)imagePickForType: (UIImagePickerControllerSourceType) type btn: (UIView*) btn
{
	UIImagePickerController	*ctl;
	
	
	if (! [UIImagePickerController isSourceTypeAvailable: type])
		return;
	
	// UIPopoverController
	
	ctl = [[UIImagePickerController alloc] init];
	ctl.allowsEditing = YES;
	ctl.delegate = self;
	ctl.sourceType = type;

	if (g_appDelegate.ipadMode)
	{
		UIPopoverController* aPopover = [[UIPopoverController alloc] initWithContentViewController: ctl]; 
		
		[aPopover presentPopoverFromRect: btn.bounds inView: btn 
						 permittedArrowDirections: UIPopoverArrowDirectionAny 
										 animated: YES];
		aPopover.delegate = self;
		
		self.popOver = aPopover;
	}
	else
	{
		//ctl.allowsImageEditing = YES;
		
		//[[self navigationController] presentModalViewController:ctl animated:YES];
        [[self navigationController] presentViewController:ctl animated:YES completion:nil];
		
	}
}

// --------------------------------------------------------------------------------------------------------
- (void)popoverControllerDidDismissPopover:(UIPopoverController *)popoverController
{
	ATRACE(@"ClipEditCtl popoverControllerDidDismissPopover" );
}

// --------------------------------------------------------------------------------------------------------
- (BOOL)popoverControllerShouldDismissPopover:(UIPopoverController *)popoverController
{
	ATRACE(@"ClipEditCtl popoverControllerShouldDismissPopover" );
	return YES;
}

// --------------------------------------------------------------------------------------------------------
- (IBAction)actionPhoto: (id)sender
{
	[self imagePickForType: UIImagePickerControllerSourceTypePhotoLibrary btn: fPhotoButton];
}

// --------------------------------------------------------------------------------------------------------
- (IBAction)actionCamera: (id)sender
{
	[self imagePickForType: UIImagePickerControllerSourceTypeCamera btn: fCameraButton];
}

// --------------------------------------------------------------------------------------------------------
- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{
	UIImage		*newImage = [info objectForKey: UIImagePickerControllerEditedImage];
	
	ATRACE(@"ClipEditCtl imagePickerController newImage=%@", newImage );
	
	[song saveNewImage: newImage forClipIndex: clipIndex];

	Clip *clip = [song clipAtIndex: clipIndex];
	
	self.fImageView.image = clip.image;
	
	//[self dismissModalViewControllerAnimated: YES];
    [self dismissViewControllerAnimated:YES completion:nil];
	
	[popOver dismissPopoverAnimated: YES];
	self.popOver = nil;
}


// --------------------------------------------------------------------------------------------------------
- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker
{
	//[self dismissModalViewControllerAnimated: YES];
    [self dismissViewControllerAnimated:YES completion:nil];
}

// --------------------------------------------------------------------------------------------------------
- (void) setRecording: (BOOL) newState
{
	recording = newState;
	if (! recording)
	{
		[fRecordButton setTitle: @"Record" forState: UIControlStateNormal];
	}
	else
	{
		[fRecordButton setTitle: @"Stop" forState: UIControlStateNormal];
	}
}

#if 0
// --------------------------------------------------------------------------------------------------------
// Setup timer to report recording  / playback time
- (void) prepareTimer
{
	if (! updateTimer)
	{
		updateTimer = [NSTimer scheduledTimerWithTimeInterval: kTimerInterval 
													   target: self 
													 selector: @selector(timerCheck:)
													 userInfo: nil
													  repeats: YES];
	}
}
#endif

// --------------------------------------------------------------------------------------------------------
- (void) saveSongToDisk
{
    song.currentPos = [songList currentTime];
    
    [song saveToDisk];    
}

// --------------------------------------------------------------------------------------------------------
// Prepare filename for sound recording
- (void) prepareSoundFileURL
{	
	Clip	*clip = [song clipAtIndex: clipIndex ];

	if ([clip.recordingFileName length] <= 0)
	{
		clip.recordingFileName = [song nextMediaFileName: @"sound.caf"];
		
		// Save now and after recording is complete incase record fails and sound is store on disk
		// sound file will re-used when re-recorded.
		[self saveSongToDisk];
	}
	NSString *soundFilePath = [song pathNameForMediaFileName: clip.recordingFileName];
	
	ATRACE(@"ClipEditCtl prepareSoundFileURL soundFilePath=%@", soundFilePath );

	NSURL *newURL = [[NSURL alloc] initFileURLWithPath: soundFilePath];
	self.soundFileURL = newURL;
}

// --------------------------------------------------------------------------------------------------------
- (IBAction)actionRecord: (id)sender
{
	ATRACE(@"ClipEditCtl actionRecord soundRecorder=%@", soundRecorder );
	ATRACE(@"ClipEditCtl actionRecord      currentTime=%f", soundRecorder.currentTime );
	
	//[self prepareTimer];
	
	self.soundPlayer = nil;
	
	if (! recordingInited)
	{
		[self prepareSoundFileURL];

#define SESSION		1
#if SESSION
		AVAudioSession *audioSession = [AVAudioSession sharedInstance];
		audioSession.delegate = self;
		// - (BOOL)setCategory:(NSString*)theCategory error:(NSError**)outError
		// NSError *error = nil;
		//BOOL ok = [audioSession setCategory:AVAudioSessionCategoryRecord  error: &error];
		//ATRACE(@"ClipEditCtl setCategory error=%@ ok=%d", error, ok);
		[audioSession setActive: YES error: nil];
#endif
		recording = NO;
		playing = NO;
		recordingInited = YES;
		
		ATRACE(@"ClipEditCtl actionRecord soundFileURL=%@", soundFileURL );
	}
	
    if (recording) 
	{
        [soundRecorder stop];
        self.soundRecorder = nil;
		
		[self setRecording: NO];

		NSError *error = nil;
		BOOL ok = [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryAmbient  error: &error];
		(void) ok;
		ATRACE(@"ClipEditCtl setCategory AVAudioSessionCategoryAmbient error=%@ ok=%d", error, ok);
    } 
	else 
	{
 		NSError *error = nil;
		BOOL ok = [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryRecord  error: &error];
		(void) ok;
		ATRACE(@"ClipEditCtl setCategory AVAudioSessionCategoryRecord error=%@ ok=%d", error, ok);
		
        NSDictionary *recordSettings =
			[NSDictionary dictionaryWithObjectsAndKeys:
				 [NSNumber numberWithFloat: 44100.0],                 AVSampleRateKey,
				 [NSNumber numberWithInt: kAudioFormatAppleLossless], AVFormatIDKey,
				 [NSNumber numberWithInt: 1],                         AVNumberOfChannelsKey,
				 [NSNumber numberWithInt: AVAudioQualityMax],         AVEncoderAudioQualityKey,
				 nil];
		
        AVAudioRecorder *newRecorder = [[AVAudioRecorder alloc] initWithURL: soundFileURL
                                                                   settings: recordSettings
                                                                      error: nil];
        self.soundRecorder = newRecorder;
		
        soundRecorder.delegate = self;
        [soundRecorder prepareToRecord];
        [soundRecorder record];
		
		[self setRecording: YES];
    }
	ATRACE(@"ClipEditCtl actionRecord recording=%d soundRecorder=%@ ", recording, soundRecorder );
}

// --------------------------------------------------------------------------------------------------------
//AVAudioRecorderDelegate	

// --------------------------------------------------------------------------------------------------------
- (void)audioRecorderDidFinishRecording:(AVAudioRecorder *)recorder successfully:(BOOL)ok
{
	ATRACE(@"ClipEditCtl audioRecorderDidFinishRecording flag=%d", ok );
	
	if (ok)
	{
		//Clip	*clip = [song clipAtIndex: clipIndex ];
		
		// Current time shoudl be duration
		// Its not!
		//clip.recordingDuration = soundRecorder.currentTime;
		//ATRACE(@"ClipEditCtl audioRecorderDidFinishRecording clip.recordingDuration=%f", clip.recordingDuration );
		
		// Update clip changes to disk
		[self saveSongToDisk];
	}
	
	[self setRecording: NO];
}

// --------------------------------------------------------------------------------------------------------
- (void)audioRecorderEncodeErrorDidOccur:(AVAudioRecorder *)recorder error:(NSError *)error
{
	ATRACE(@"ClipEditCtl audioRecorderEncodeErrorDidOccur error=%@", error );
	[self setRecording: NO];
}

- (void)audioRecorderBeginInterruption:(AVAudioRecorder *)recorder
{
	ATRACE(@"ClipEditCtl audioRecorderBeginInterruption " );
}

// --------------------------------------------------------------------------------------------------------
- (void)audioRecorderEndInterruption:(AVAudioRecorder *)recorder
{
	ATRACE(@"ClipEditCtl audioRecorderEndInterruption " );
}

// --------------------------------------------------------------------------------------------------------
- (void) setPlaying: (BOOL) newState
{
	playing = newState;
	if (! playing)
	{
		[fReviewButton setTitle: @"Review" forState: UIControlStateNormal];
	}
	else
	{
		[fReviewButton setTitle: @"Stop" forState: UIControlStateNormal];
	}
}

// --------------------------------------------------------------------------------------------------------
- (IBAction)actionReview: (id)sender
{
	ATRACE2(@"ClipEditCtl actionReview soundFileURL=%@", soundFileURL );
	ATRACE(@"ClipEditCtl actionReview soundPlayer=%@", soundPlayer );
	ATRACE(@"ClipEditCtl actionReview      duration=%f", soundPlayer.duration );
	ATRACE(@"ClipEditCtl actionReview      currentTime=%f", soundPlayer.currentTime );

	//[self prepareTimer];

	if (! soundPlayer || !playingInited)
	{
		[self prepareSoundFileURL];
		
		// Instantiates the AVAudioPlayer object, initializing it with the sound
		AVAudioPlayer *newPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL: soundFileURL error: nil];
		self.soundPlayer = newPlayer;
		
		// "Preparing to play" attaches to the audio hardware and ensures that playback
		//		starts quickly when the user taps Play
		[soundPlayer prepareToPlay];
		[soundPlayer setVolume: 1.0];
		[soundPlayer setDelegate: self];
		
		playingInited = YES;
	}
	if (playing)
	{
		ATRACE(@"ClipEditCtl actionReview soundPlayer=%@ stop", soundPlayer );
		[soundPlayer stop];
		[self setPlaying: NO];
	}
	else
	{
		ATRACE(@"ClipEditCtl actionReview soundPlayer=%@ play", soundPlayer );
		[soundPlayer play];
		[self setPlaying: YES];
	}
}

// --------------------------------------------------------------------------------------------------------
- (void)audioPlayerBeginInterruption:(AVAudioPlayer *)player
{
	ATRACE(@"ClipView: audioPlayerBeginInterruption. The system has stopped audio playback.");
	
	if (playing) 
	{
		[soundPlayer pause];
		[self setPlaying: NO];
		interruptedOnPlayback = YES;
	}
}

// --------------------------------------------------------------------------------------------------------
- (void)audioPlayerEndInterruption:(AVAudioPlayer *)player
{
	ATRACE(@"ClipEditCtl audioPlayerEndInterruption. Resuming audio playback.");
	
	// Reactivates the audio session, whether or not audio was playing
	//		when the interruption arrived.
	[[AVAudioSession sharedInstance] setActive: YES error: nil];
	
	if (interruptedOnPlayback) 
	{
		[soundPlayer prepareToPlay];
		[soundPlayer play];
		[self setPlaying: YES];
		interruptedOnPlayback = NO;
	}
}

// --------------------------------------------------------------------------------------------------------
- (void) audioPlayerDidFinishPlaying: (AVAudioPlayer *) player successfully: (BOOL) flag 
{
	ATRACE(@"ClipEditCtl audioPlayerDidFinishPlaying. flag=%d", flag);
	[self setPlaying: NO];
	soundPlayer.currentTime = 0;
}


// --------------------------------------------------------------------------------------------------------
// --------------------------------------------------------------------------------------------------------


@end

