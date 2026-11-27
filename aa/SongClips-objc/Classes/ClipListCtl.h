/*

*/

#import <UIKit/UIKit.h>
#import "Song.h"
#import "SongList.h"
#import "TitleView.h"

// --------------------------------------------------------------------------------------------------------

@interface ClipListCtl : UITableViewController <UITableViewDelegate, SongListWatcher>
{
	Song					*song;
	
	TitleView				*titleView;
	NSTimeInterval			lastTime;
	int				currentClipIndex;
	SongList				*songList;
}

@property (nonatomic, strong) Song			*song;

@property (nonatomic, strong) TitleView		*titleView;

@end

// --------------------------------------------------------------------------------------------------------
// --------------------------------------------------------------------------------------------------------
