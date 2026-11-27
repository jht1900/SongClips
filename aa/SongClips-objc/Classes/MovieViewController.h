/*


*/

#import <UIKit/UIKit.h>
#import <MediaPlayer/MediaPlayer.h>


@interface MovieViewController : UIViewController {

    MPMoviePlayerController *mMoviePlayer;
}

-(void)initMoviePlayerURL: (NSURL*) movieURL;

-(void)initMoviePlayer: (NSString*) filePath;

- (void)playMovie;

@end
