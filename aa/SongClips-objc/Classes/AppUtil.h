/*

*/

#import <UIKit/UIKit.h>

@interface AppUtil : NSObject 
{
}

+ (NSString*)formatRunningTimeUI: (double)num;

+ (NSString*)formatDurationUI: (double)num;

+ (NSString*)formatDurationExport: (double)sec;

+ (NSString*)formatDoubleDuration: (double)num;

+ (NSString*)formatDoubleBytes: (double) num;

+ (NSString*)formatNumber: (SInt64) num;

+ (NSString*)formatDouble: (double) num;

+ (NSString*)formatDate: (NSDate*)date;


+ (BOOL) yesValue: (NSString*)value;

+ (NSArray*)parseKeyValue: (NSString *)param;

+ (int) pathLevel: (NSString *)str;

+ (BOOL) isDirectoryPath: (NSString*)str;

+ (NSString*) deleteLastComponentToDirectory: (NSString*)str;

+ (NSString*) removeFtpSchemeIfPresent: (NSString*)str;

+ (NSString*) addFtpSchemeIfAbsent: (NSString*)str;

+ (NSString*) escapeForURL: (NSString*) str;

+ (NSString*) escapeForPartialURL: (NSString*) str;

+ (BOOL) isMovieExtension: (NSString *)pathExt;

+ (BOOL) isAudioExtension: (NSString *)pathExt;

+ (void)showMsg: (NSString*)msg title:(NSString*)title;

+ (void)showErr: (NSString*)msg;

@end

UIColor* colorFromArray( id arr);

NSArray* colorToArray( UIColor* acolor);

CGFloat Random1(void);

// ----------------------------------------------------------------------------------------------------------
// ----------------------------------------------------------------------------------------------------------
