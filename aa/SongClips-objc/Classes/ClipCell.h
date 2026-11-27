/*
 */

#import <UIKit/UIKit.h>

@interface ClipCell : UITableViewCell {
	
	IBOutlet UIView		*fView;
	IBOutlet UILabel	*fNotes;
	IBOutlet UILabel	*fStartTime;
	IBOutlet UILabel	*fDuration;
	IBOutlet UILabel	*fCurPos;
	IBOutlet UIImageView	*fImage;

}

@property (nonatomic, strong) UIView		*fView;
@property (nonatomic, strong) UILabel		*fNotes;
@property (nonatomic, strong) UILabel		*fStartTime;
@property (nonatomic, strong) UILabel		*fDuration;
@property (nonatomic, strong) UILabel		*fCurPos;
@property (nonatomic, strong) UIImageView	*fImage;


@end

// --------------------------------------------------------------------------------------------------------
// --------------------------------------------------------------------------------------------------------
