/*
 
 */

#import "ClipCell.h"
#import "AppDefs.h"

@implementation ClipCell

@synthesize	fView;
@synthesize	fNotes;
@synthesize	fStartTime;
@synthesize	fDuration;
@synthesize fCurPos;
@synthesize fImage;

// ----------------------------------------------------------------------------------------------------------

// ----------------------------------------------------------------------------------------------------------
- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
//- (id)initWithFrame:(CGRect)frame reuseIdentifier:(NSString *)reuseIdentifier
{
	//if (self = [super initWithFrame:frame reuseIdentifier:reuseIdentifier]) 
	if ((self = [super initWithStyle:style reuseIdentifier:reuseIdentifier]) )
	{
		// Initialization code
		[self.contentView addSubview:fView];
	}
	ATRACE2(@"ClipCell initWithStyle reuseIdentifier=%@", reuseIdentifier);
	return self;
}


// ----------------------------------------------------------------------------------------------------------
- (void)setSelected:(BOOL)selected animated:(BOOL)animated 
{
	[super setSelected:selected animated:animated];

	// Configure the view for the selected state
}

// ----------------------------------------------------------------------------------------------------------
- (void)layoutSubviews
{	
	ATRACE2(@"ClipCell layoutSubviews");
	[super layoutSubviews];
    CGRect contentRect = [self.contentView bounds];
	fView.frame = contentRect;
}

// ----------------------------------------------------------------------------------------------------------
// ----------------------------------------------------------------------------------------------------------

@end
