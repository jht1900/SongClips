/*

*/

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

@interface AudioPlayerViewController : UIViewController <AVAudioPlayerDelegate>
{
	AVAudioPlayer				*player;
	NSURL						*url;
	NSString					*fileName;
	
	IBOutlet UILabel			*fFileName;
	IBOutlet UILabel			*fLeft;
	IBOutlet UILabel			*fRight;
	IBOutlet UISlider			*fProgress;
	IBOutlet UIButton			*fStopPlayButton;
	//IBOutlet UIProgressView		*fVolume;

	NSTimer						*updateTimer;
}

//@property (nonatomic, retain) AVAudioPlayer		*player;
@property (nonatomic, strong) NSURL				*url;
@property (nonatomic, strong) NSString			*fileName;

@property (nonatomic, strong) UILabel			*fFileName;
@property (nonatomic, strong) UILabel			*fLeft;
@property (nonatomic, strong) UILabel			*fRight;
@property (nonatomic, strong) UISlider			*fProgress;
@property (nonatomic, strong) UIButton			*fStopPlayButton;
//@property (nonatomic, retain) UIProgressView	*fVolume;


- (IBAction)actionStopPlay:(id)sender;

//- (IBAction)actionPlay:(id)sender;

@end

