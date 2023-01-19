/*

File: WebViewController.h
Abstract: The view controller for hosting the UIWebView feature of this sample.
Version: 1.7
Copyright (C) 2008 Apple Inc. All Rights Reserved.

*/

#import <UIKit/UIKit.h>

@interface WebViewController : UIViewController <UITextFieldDelegate, UIWebViewDelegate>
{
	UIWebView	*myWebView;
	//UITextField *urlField;
	
	UIBarButtonItem *backButton;

	//IBOutlet UINavigationController	*navigationController;
	
	BOOL			externalLaunch;
	BOOL			disableAbout;
	BOOL			someError;
	BOOL			activity;
}

//@property (nonatomic, retain) UINavigationController *navigationController;
@property (nonatomic, assign) BOOL			externalLaunch;
@property (nonatomic, assign) BOOL			someError;

+ (void) showUrlString: (NSString*) url nav:(id)nav;

+ (void) showResource: (NSString *)resourceName title:(NSString*)title nav:(id)nav externalLaunch: (BOOL)ext;

- (void) loadURL: (NSURL*)url;

- (void) loadFile: (NSString*)filePath;

+ (void) showAboutOn: (UINavigationController*) navc;

@end
