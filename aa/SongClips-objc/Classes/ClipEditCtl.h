/*

*/

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>

#import "SongList.h"
#import "ClipPlayModeCtl.h"

@class PlaybackView;

// --------------------------------------------------------------------------------------------------------

@interface ClipEditCtl : UIViewController <UITextViewDelegate, 
											SongListWatcher, 
                                            ClipPlayModeCtlDelegate,
											AVAudioPlayerDelegate,
											AVAudioRecorderDelegate,
											AVAudioSessionDelegate,
											UINavigationControllerDelegate, 
											UIImagePickerControllerDelegate,
											UIPopoverControllerDelegate>
{
	SongList					*__weak songList;
	Song						*song;
	int                         clipIndex;
	BOOL						flowToClip;
	
	IBOutlet UIImageView		*fImageView;
	IBOutlet UITextView			*fNotes;
	
	IBOutlet UILabel			*fStartTime;			// fclipnum
	IBOutlet UILabel			*fCurPos;				// fduration
	IBOutlet UILabel			*fDuration;				// fduration2
	
	IBOutlet UISlider			*fScrub;
	IBOutlet UIButton			*fPlayButton;
	
	IBOutlet UIButton			*fCameraButton;
	IBOutlet UIButton			*fPhotoButton;
	IBOutlet UIButton			*loopClipButton;
	
	IBOutlet UISwitch			*fLoopSwitch;
	IBOutlet UIButton			*fRecordButton;
	IBOutlet UIButton			*fReviewButton;
	IBOutlet UILabel			*fRecordDuration;

	IBOutlet UIView				*fAddPhoto;

    IBOutlet PlaybackView	*avplayer;

	NSTimeInterval				duration;
	NSTimeInterval				startTime;
	BOOL						loop;
	BOOL						scrubDownSceen;

	AVAudioRecorder				*soundRecorder;
	AVAudioPlayer				*soundPlayer;
	NSURL						*soundFileURL;
	BOOL						recordingInited;
	BOOL						recording;
	BOOL						playingInited;
	BOOL						playing;
	BOOL						interruptedOnPlayback;

	BOOL						savePending;
}

@property (nonatomic, weak) SongList  *songList;
@property (nonatomic) int               clipIndex;
@property (nonatomic) BOOL              flowToClip;

@property (nonatomic, strong) Song              *song;
@property (nonatomic, strong) AVAudioRecorder   *soundRecorder;
@property (nonatomic, strong) AVAudioPlayer     *soundPlayer;
@property (nonatomic, strong) NSURL             *soundFileURL;

@property (nonatomic, strong) UIImageView		*fImageView;
@property (nonatomic, strong) UITextView		*fNotes;
@property (nonatomic, strong) UILabel			*fStartTime;
@property (nonatomic, strong) UILabel			*fCurPos;
@property (nonatomic, strong) UILabel			*fDuration;
@property (nonatomic, strong) UISlider			*fScrub;
@property (nonatomic, strong) UILabel			*fRecordDuration;
@property (nonatomic, strong) UISwitch			*fLoopSwitch;
@property (nonatomic, strong) UIButton			*fPlayButton;
@property (nonatomic, strong) UIButton			*fRecordButton;
@property (nonatomic, strong) UIButton			*fReviewButton;
@property (nonatomic, strong) UIButton			*fCameraButton;
@property (nonatomic, strong) UIButton			*fPhotoButton;

@property (nonatomic, strong) UIButton			*loopClipButton;

@property (nonatomic, strong) UIView				*fAddPhoto;

@property (nonatomic, strong) UIPopoverController   *popOver;

- (IBAction)actionPlay: (id)sender;
- (IBAction)actionSplit: (id)sender;
- (IBAction)actionMerge: (id)sender;
- (IBAction)actionRecord: (id)sender;
- (IBAction)actionReview: (id)sender;
- (IBAction)actionPrevious: (id)sender;
- (IBAction)actionNext: (id)sender;
- (IBAction)actionPhoto: (id)sender;
- (IBAction)actionCamera: (id)sender;

- (IBAction) loopClipAction: (id) sender;
- (IBAction) actionClips: (id)sender;

@end

// --------------------------------------------------------------------------------------------------------
// --------------------------------------------------------------------------------------------------------
