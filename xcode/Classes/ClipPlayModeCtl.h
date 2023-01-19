/*

*/

#import <UIKit/UIKit.h>

@class ClipPlayModeCtl;

// Delegate protocol for communicating popover results back to root
@protocol ClipPlayModeCtlDelegate <NSObject>
- (void)done_ClipPlayModeCtl:(ClipPlayModeCtl *)ctl ;
@end

// --------------------------------------------------------------------------------------------------------

@interface ClipPlayModeCtl : UITableViewController <UITableViewDelegate> 
{
    id <ClipPlayModeCtlDelegate> __weak delegate;          // our delegate

	NSArray     *metaArray;
}
@property (nonatomic, weak) id <ClipPlayModeCtlDelegate> delegate;
@property (nonatomic, assign) BOOL      isModal;
@property (nonatomic, strong) NSArray	*metaArray;

@end

// --------------------------------------------------------------------------------------------------------
// --------------------------------------------------------------------------------------------------------
