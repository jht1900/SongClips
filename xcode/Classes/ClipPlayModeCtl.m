/*
 
*/


#import "ClipPlayModeCtl.h"
#import "AppDefs.h"
#import "AppUtil.h"
#import "AppDelegate.h"
#import "SongList.h"

@implementation ClipPlayModeCtl

@synthesize delegate;
@synthesize isModal;
@synthesize metaArray;

// --------------------------------------------------------------------------------------------------------

// --------------------------------------------------------------------------------------------------------

#define kRowActionIndex	0
#define kRowTitleIndex	1

enum 
{
	kModeSection = 0,
};

// --------------------------------------------------------------------------------------------------------
// Configures the table view.
- (void) viewDidLoad 
{
    [super viewDidLoad];

    if (! (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad))  {
        // Obtain a UIButton object and set its background to the UIImage object
        UIButton *buttonView = [[UIButton alloc] initWithFrame: CGRectMake (0, 0, 40, 40)];
        [buttonView setBackgroundImage: [UIImage imageNamed:@"back_arrow.png"] forState: UIControlStateNormal];
        UIBarButtonItem *backButton = [[UIBarButtonItem alloc] initWithCustomView: buttonView];
        [buttonView addTarget:self action:@selector(actionBack:) forControlEvents:UIControlEventTouchUpInside];
        self.navigationItem.leftBarButtonItem = backButton;
    }
    
	self.title = @"At end of clip:";
    
    self.contentSizeForViewInPopover = CGSizeMake(300.0, 260.0);

	self.metaArray = @[
						@[
							@[ @(kClipPlayModeContinue), @"Continue" ],
							@[ @(kClipPlayModeRepeat), @"Repeat" ],
                            @[ @(kClipPlayModePause), @"Pause"],
                            @[ @(kClipPlayModePauseContinue), @"Pause then Continue" ],
                            @[ @(kClipPlayModePauseRepeat), @"Pause then Repeat" ]
                        ]
					];
}

// ----------------------------------------------------------------------------------------------------------
- (void)actionBack: (id)sender
{	
    if (isModal) {
        //[self dismissModalViewControllerAnimated:YES];
        [self dismissViewControllerAnimated:YES completion:nil];
    }
    else {
        [[self navigationController] popViewControllerAnimated: YES];
    }
}

// --------------------------------------------------------------------------------------------------------
- (void)viewWillAppear:(BOOL)animated
{
	ATRACE(@"ClipPlayMode  viewWillAppear");
	
	[super viewWillAppear: animated];
	
	[self.tableView reloadData];
	
}

// --------------------------------------------------------------------------------------------------------
#pragma mark Table view methods________________________

// To learn about using table views, see the TableViewSuite sample code  
//		and Table View Programming Guide for iPhone OS.

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
	return 44.0;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
	switch (section) {
		//case kModeSection:
		//	return 26;
	}
	return 8.0;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section
{
	switch (section) {
	}
	return 2.0;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
	switch (section) {
		//case kModeSection:
		//	return @"Clip Play Mode";
	}
	return @" ";
}

// ----------------------------------------------------------------------------------------------------------
- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
	return @" ";
}

// ----------------------------------------------------------------------------------------------------------
// tell our table how many sections or groups it will have (always 1 in our case)
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
	return [metaArray count];
}

// --------------------------------------------------------------------------------------------------------
- (NSInteger) tableView: (UITableView *) table numberOfRowsInSection: (NSInteger)section 
{
	return [metaArray[section] count];
}

// --------------------------------------------------------------------------------------------------------
- (void) gohome
{
    [[self navigationController] popViewControllerAnimated: YES];
    
    [delegate done_ClipPlayModeCtl:self];
}

// --------------------------------------------------------------------------------------------------------
//	 To conform to the Human Interface Guidelines, selections should not be persistent --
//	 deselect the row after it has been selected.
- (void) tableView: (UITableView *) tableView didSelectRowAtIndexPath: (NSIndexPath *) indexPath
{	
	[tableView deselectRowAtIndexPath: indexPath animated: YES];
	
	NSArray *arow = metaArray[[indexPath section]][[indexPath row]];
	int	action = [arow[ kRowActionIndex] intValue];

	ATRACE2(@"ClipPlayMode  didSelectRowAtIndexPath arow=%@ indexPath=%@ action=%d", arow, indexPath, action);

    [SongList default].playMode = action;
    [self.tableView reloadData];

    // - (void)performSelector:(SEL)aSelector withObject:(id)anArgument afterDelay:(NSTimeInterval)delay
    [self performSelector:@selector(gohome) withObject:nil afterDelay:0.25];
}

// --------------------------------------------------------------------------------------------------------
- (UITableViewCell*) cellFor: (NSString*) cellID style: (UITableViewCellStyle) cellStyle tableView: (UITableView *) tableView
{
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier: cellID];
	
	if (cell == nil) 
	{
		cell = [[UITableViewCell alloc] initWithStyle: cellStyle reuseIdentifier: cellID];
	}
	return cell;
}

// --------------------------------------------------------------------------------------------------------
- (UITableViewCell *) tableView: (UITableView *) tableView cellForRowAtIndexPath: (NSIndexPath *) indexPath
{	
	NSArray *arow = metaArray[ [indexPath section]][ [indexPath row]];
	int	action = [arow[ kRowActionIndex] intValue];
	NSString *rowTitle = arow[ kRowTitleIndex] ;
	
	UITableViewCell *cell = nil;
		
	ATRACE2(@"ClipPlayMode  cellForRowAtIndexPath arow=%@ indexPath=%@", arow, indexPath);

	switch (action) {
        default:
			cell = [self cellFor: @"Cell1" style: UITableViewCellStyleDefault tableView: tableView];
			if (! cell) return cell;
            cell.textLabel.text = rowTitle;
			cell.accessoryType = ([SongList default].playMode == action)? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
            // UITableViewCellAccessoryCheckmark
            // UITableViewCellAccessoryNone
			break;
	}
	
	return cell;
}



// --------------------------------------------------------------------------------------------------------
// --------------------------------------------------------------------------------------------------------


@end
