/*

File: WebViewController.m
Abstract: The view controller for hosting the UIWebView feature of this sample.
Version: 1.7
Copyright (C) 2008 Apple Inc. All Rights Reserved.

*/

#import "WebViewController.h"
#import "AppDelegate.h"
#import "AppUtil.h"
#import "AppDelegate.h"
#import "MovieViewController.h"
#import "AudioPlayerViewController.h"

@implementation WebViewController

//@synthesize navigationController;
@synthesize externalLaunch;
@synthesize someError;

// ----------------------------------------------------------------------------------------------------------
- (id)init
{
	self = [super init];
	if (self)
	{
		self.externalLaunch = NO;
	}
	return self;
}

// ----------------------------------------------------------------------------------------------------------
- (void)dealloc
{
	if (activity)
		[g_appDelegate setActivity: NO];

	//[urlField release];
	//[navigationController release];
	
}

// ----------------------------------------------------------------------------------------------------------
+ (void) showUrlString: (NSString*) urlStr nav:(id)nav 
{
	ATRACE(@"WebViewController: showUrlString urlStr=%@", urlStr);

	if (! [urlStr hasPrefix:@"http://"])
		urlStr = [@"http://" stringByAppendingString: urlStr];
	
	WebViewController *webViewController = [[WebViewController alloc] init];
	
	[[nav navigationController] pushViewController:webViewController animated:YES];
	
	webViewController.title = [urlStr lastPathComponent];
	
	NSURL *url = [NSURL URLWithString: urlStr];
	
	ATRACE(@"WebViewController: showUrlString url=%@", url);
	
	[webViewController loadURL: url];
	
}
	
// ----------------------------------------------------------------------------------------------------------
+ (void)showResource: (NSString *)resourceName title:(NSString*)title nav:(id)nav externalLaunch: (BOOL)ext
{
	WebViewController *webViewController = [[WebViewController alloc] init];
	
	[[nav navigationController] pushViewController:webViewController animated:YES];
	
	webViewController.title = title;
	webViewController.externalLaunch = ext;
	
	NSBundle *bundle = [NSBundle mainBundle];
	NSString *appInfoPath = [bundle pathForResource:resourceName ofType:@"html"];
	
	[webViewController loadFile: appInfoPath];
	
}

// ----------------------------------------------------------------------------------------------------------
- (void)loadView
{
	UIBarButtonItem *webSiteButton = 
		[[UIBarButtonItem alloc] initWithTitle: @"Safari" 
										  style:UIBarButtonItemStylePlain 
										 target: self 
										 action:@selector(actionSafari:) ];
	self.navigationItem.rightBarButtonItem = webSiteButton;

	// the base view for this view controller
	CGRect rect = [[UIScreen mainScreen] bounds];
	ATRACE2(@"WebViewController: loadView rect x=%f y=%f w=%f h=%f", rect.origin.x, rect.origin.y, rect.size.width, rect.size.height );

	//UIView *contentView = [[UIView alloc] initWithFrame:[[UIScreen mainScreen] applicationFrame]];
	UIView *contentView = [[UIView alloc] initWithFrame:rect];
	contentView.backgroundColor = [UIColor whiteColor];
	
	// important for view orientation rotation
	contentView.autoresizesSubviews = YES;
	contentView.autoresizingMask = (UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight);	
	
	self.view = contentView;
	

	myWebView = [[UIWebView alloc] initWithFrame:rect];
	myWebView.backgroundColor = [UIColor whiteColor];
	myWebView.scalesPageToFit = YES;
	myWebView.autoresizingMask = (UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight);
	myWebView.delegate = self;
	[self.view addSubview: myWebView];
#if 0
	backButton =  
		[[UIBarButtonItem alloc] initWithTitle:@"Back"
										 style: UIBarButtonItemStylePlain 
										target: self 
										action: @selector(actionBack:)];	

	ATRACE2(@"WebViewController: myWebView.canGoBack=%d backButton=%@", myWebView.canGoBack, backButton);
#endif
}

// ----------------------------------------------------------------------------------------------------------
- (void)actionSafari: (id)sender
{
	ATRACE(@"WebViewController actionSafari");
	NSURLRequest	*request = [myWebView request];
	NSURL			*url = [request URL];

	[g_appDelegate openInBrowser: [url absoluteString] ];
}

// ----------------------------------------------------------------------------------------------------------
- (void)actionBack: (id)sender;
{
	ATRACE2(@"WebViewController actionBack: sender=%@", [sender description]);
	[myWebView goBack];
}


// ----------------------------------------------------------------------------------------------------------
- (void) loadURL: (NSURL*)url
{
	ATRACE(@"WebViewController loadURL url=%@", url);
	
	[myWebView loadRequest:[NSURLRequest requestWithURL:url]];
}

// ----------------------------------------------------------------------------------------------------------
- (void) loadFile: (NSString*)filePath
{
	ATRACE(@"WebViewController loadFile filePath=%@", filePath);
	//filePath = [filePath stringByAddingPercentEscapesUsingEncoding: NSUTF8StringEncoding];
	NSURL* url = [NSURL fileURLWithPath: filePath isDirectory: NO] ;

	[self loadURL: url ];
}

// ----------------------------------------------------------------------------------------------------------
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
	// we support rotation in this view controller
	return YES;
}

// ----------------------------------------------------------------------------------------------------------
// this helps dismiss the keyboard when the "Done" button is clicked
- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
	[textField resignFirstResponder];
	[myWebView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:[textField text]]]];
	
	return YES;
}

// ----------------------------------------------------------------------------------------------------------
- (void) setActivity: (BOOL) state
{
	activity = state;
	[g_appDelegate setActivity: state];
}

#pragma mark UIWebView delegate methods

// ----------------------------------------------------------------------------------------------------------
- (void)webViewDidStartLoad:(UIWebView *)webView
{
	// starting the load, show the activity indicator in the status bar
	//[UIApplication sharedApplication].isNetworkActivityIndicatorVisible = YES;
	[self setActivity: YES];
}

// ----------------------------------------------------------------------------------------------------------
- (void)webViewDidFinishLoad:(UIWebView *)webView
{
	// finished loading, hide the activity indicator in the status bar
	//[UIApplication sharedApplication].isNetworkActivityIndicatorVisible = NO;
	[self setActivity: NO];
	ATRACE2(@"WebViewController: myWebView.canGoBack=%d backButton=%@", myWebView.canGoBack, backButton);
}

// ----------------------------------------------------------------------------------------------------------
- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error
{
	ATRACE(@"WebViewController: didFailLoadWithError error=%@", error);

	// load error, hide the activity indicator in the status bar
	[self setActivity: NO];

	// report the error inside the webview
	NSString* errorString = 
		[NSString stringWithFormat:
			@"<html><center><font size=+5 color='red'>An error occurred:<br>%@</font></center></html>",
			error.localizedDescription];
	[myWebView loadHTMLString:errorString baseURL:nil];
	
	self.someError = YES;
}

// ----------------------------------------------------------------------------------------------------------
- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType
{
	NSURL *url = [request URL];
	NSString *path = [url path];	// path with be blank sometimes even if in url
	NSString *scheme = [url scheme];

	ATRACE2(@"webView: shouldStartLoadWithRequest: %@ ", [request description]);
	ATRACE2(@"webView: url: '%@'", [url description]);
	
	NSString *pathExt = [path pathExtension];
	
	if ([AppUtil isMovieExtension: pathExt ])
	{
		MovieViewController *movieViewController = [[MovieViewController alloc] init];
		[movieViewController initMoviePlayerURL: url];
		[movieViewController playMovie];
		
		return NO;		
	}
	if ([AppUtil isAudioExtension: pathExt ])
	{
		AudioPlayerViewController *audiovc = [[AudioPlayerViewController alloc] init];
		audiovc.url = url;
		audiovc.fileName = [path lastPathComponent];
		[[self navigationController] pushViewController:audiovc animated:YES];
		
		return NO;		
	}
	if ([scheme isEqualToString: @"file"])
	{
		return YES;
	}

	return YES;
}

// ----------------------------------------------------------------------------------------------------------
+ (void) showAboutOn: (UINavigationController*) navc
{
	ATRACE(@"webView: doAbout" );
}

// ----------------------------------------------------------------------------------------------------------
// ----------------------------------------------------------------------------------------------------------

@end

