/*

*/

#import <UIKit/UIKit.h>
#import <MessageUI/MessageUI.h>
#import <MessageUI/MFMailComposeViewController.h>

#import "AssetBrowserController.h"
#import "SongList.h"

// --------------------------------------------------------------------------------------------------------

@interface InfoViewCtl : UITableViewController <
    AssetBrowserControllerDelegate,
    MPMediaPickerControllerDelegate,
    MFMailComposeViewControllerDelegate,
    UITableViewDelegate,
    UIAlertViewDelegate>
{
	NSArray					*metaArray;
	
	int						alertAction;

	SongList				*songList;
}

@property (nonatomic, strong) NSArray	*metaArray;

//- (IBAction) showMediaPicker: (id) sender;

@end

// --------------------------------------------------------------------------------------------------------


// --------------------------------------------------------------------------------------------------------
// --------------------------------------------------------------------------------------------------------
