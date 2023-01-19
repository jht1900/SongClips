/*
 
 */

#import "TitleView.h"
#import "AppDefs.h"

@implementation TitleView

@synthesize	fView;
@synthesize	fTop;
@synthesize	fBottom;

// ----------------------------------------------------------------------------------------------------------

// ----------------------------------------------------------------------------------------------------------
- (id)initWithFrame:(CGRect)frame 
{
	ATRACE2(@"TitleView initWithFrame");
	if (self = [super initWithFrame: frame ]) 
	{
		// Initialization code
		[self addSubview:fView];
	}
	return self;
}

// ----------------------------------------------------------------------------------------------------------
- (void)layoutSubviews
{	
	ATRACE2(@"TitleView layoutSubviews");
	[super layoutSubviews];
	fView.frame = [self bounds];
}

// ----------------------------------------------------------------------------------------------------------
// ----------------------------------------------------------------------------------------------------------

@end
