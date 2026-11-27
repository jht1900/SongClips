//
// 2011-11-21 jht
//
#import <UIKit/UIKit.h>

@interface MissingViewCtl : UIViewController 
{
    IBOutlet UILabel *songLabel;
    IBOutlet UILabel *albumLabel;
    IBOutlet UILabel *artistLabel;
}

@property (nonatomic, strong) UILabel *songLabel;
@property (nonatomic, strong) UILabel *albumLabel;
@property (nonatomic, strong) UILabel *artistLabel;

- (IBAction)doneTapped:(id)sender;

- (IBAction)searchAction:(id)sender;

- (IBAction)continueAction:(id)sender;

- (IBAction)selectOtherAction:(id)sender;

@end
