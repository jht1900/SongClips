/*

Based on AVPlayerDemoPlaybackView.h Version: 1.1

*/


#import <UIKit/UIKit.h>

@class AVPlayer;

@interface PlaybackView : UIView

@property (nonatomic, strong) AVPlayer* player;

- (void)setPlayer:(AVPlayer*)player;
- (void)setVideoFillMode:(NSString *)fillMode;

@end
