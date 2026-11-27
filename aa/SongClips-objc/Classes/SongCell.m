/*
 
 */

#import "SongCell.h"
#import "AppDefs.h"

@implementation SongCell

@synthesize	fView;
@synthesize	textLabel;
@synthesize	detailTextLabel;
@synthesize fImage;

// ----------------------------------------------------------------------------------------------------------

// ----------------------------------------------------------------------------------------------------------
- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
	if ((self = [super initWithStyle:style reuseIdentifier:reuseIdentifier]) )
	{
		[self.contentView addSubview:fView];
	}
	ATRACE2(@"SongCell initWithStyle reuseIdentifier=%@", reuseIdentifier);
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
	ATRACE2(@"SongCell layoutSubviews");
	[super layoutSubviews];
    CGRect contentRect = [self.contentView bounds];
	fView.frame = contentRect;
}

// ----------------------------------------------------------------------------------------------------------
// ----------------------------------------------------------------------------------------------------------

@end
