/*
 */

#import <UIKit/UIKit.h>

@interface SongCell : UITableViewCell {
	
	IBOutlet UIView		*fView;
	IBOutlet UILabel	*textLabel;
	IBOutlet UILabel	*detailTextLabel;
	IBOutlet UIImageView	*fImage;

}

@property (nonatomic, strong) UIView		*fView;
@property (nonatomic, strong) UILabel		*textLabel;
@property (nonatomic, strong) UILabel		*detailTextLabel;
@property (nonatomic, strong) UIImageView	*fImage;


@end

// --------------------------------------------------------------------------------------------------------
// --------------------------------------------------------------------------------------------------------
