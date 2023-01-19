/*
 */

#import <UIKit/UIKit.h>

@interface TitleView : UIView 
{	
	IBOutlet UIView		*fView;
	IBOutlet UILabel	*fTop;
	IBOutlet UILabel	*fBottom;
}

@property (nonatomic, strong) UIView		*fView;
@property (nonatomic, strong) UILabel		*fTop;
@property (nonatomic, strong) UILabel		*fBottom;


@end

// --------------------------------------------------------------------------------------------------------
// --------------------------------------------------------------------------------------------------------
