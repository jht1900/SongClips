/*
 Copyright (C) 2008 John Henry Thompson. All Rights Reserved.
 */


#import "DD_AppDefs.h"
//#import "DD_FTPManager.h"
//#import "DD_AccessPostFile.h"

#import "DD_RemoteSite.h"

@protocol DD_HTTPManagerDelegate;
@class DD_FileFTP;

// --------------------------------------------------------------------------------------------------------
@interface DD_HTTPManager : NSObject
{
	int			state;
	BOOL		started;
	
	NSString			*destPath2;
//	NSMutableData		*dataToEncode;
	
	SInt64				totalBytesWritten;
	NSTimeInterval		startTime;
	
	void (^doneBlock)(void);
	
#if APP_TRACE_DOWNLOAD
	NSString			*xsource;
#endif
}

// --------------------------------------------------------------------------------------------------------
@property (nonatomic, unsafe_unretained) id <DD_HTTPManagerDelegate> delegate;

@property (nonatomic, assign) BOOL				getFileAttributeMode;
@property (nonatomic, strong) NSDate			*fileModDate;
@property (nonatomic, assign) SInt64			fileSize;

@property (nonatomic, strong) DD_RemoteSite		*remoteSite;
@property (nonatomic, strong) NSString			*destRoot;
@property (nonatomic, strong) NSString			*path;
@property (nonatomic, strong) NSError			*lastErr;
@property (nonatomic, strong) NSString			*lastErrMsg;
@property (nonatomic, strong) NSString			*downloadFileName;
@property (nonatomic, strong) NSDate			*downloadFileModDate;

@property (nonatomic) BOOL						downloadTrueName;
@property (nonatomic) BOOL						checkForRestartableErrors;
@property (nonatomic) BOOL						silentError;

@property (nonatomic, strong) NSURLConnection	*connection;
@property (nonatomic, strong) NSOutputStream	*fileStream;

//@property (nonatomic, strong) DD_AccessPostFile		*accessPostFile;

#if APP_TRACE_DOWNLOAD
@property (nonatomic, retain) NSString			*xsource;
#endif

@property (nonatomic, strong) NSString			*deletePathWhenDone;

// --------------------------------------------------------------------------------------------------------
- (BOOL) downLoadFile: (DD_FileFTP*)sf fileOffset:(SInt64)fileOffset pathHome: (NSString *) pathHome doneBlock: (void (^)(void))doneBlock;

- (BOOL) upLoadFile: (NSString*)filePath asFileName: (NSString*) asFilename;

- (NSString *) localPath;

- (NSString *) partialPath;

@end

// --------------------------------------------------------------------------------------------------------
@protocol DD_HTTPManagerDelegate <NSObject>

@optional

- (void) httpm_downdload: (DD_HTTPManager *) httpm bytesSoFar: (SInt64)bytesSoFar ;

// - (void) downLoadFileBytesSoFar: (SInt64)bytesSoFar ;

- (void) httpm_done: (DD_HTTPManager *) httpm ;

// - (void) operationDone;

//- (BOOL) listDirectoryFileEntry: (NSString*)cfName
//					isDirectory: (BOOL)isDirectory
//						   size: (SInt64)size
//						   date: (NSDate*)cfDate
//						   path: (NSString *)path
//						 source: (NSString *)source;

@end

// --------------------------------------------------------------------------------------------------------

#define kHTTP_Temp_Contents	@"_dice_temp_contents"
#define kHTTP_Temp_Name		@"_dice_temp_name"

enum DD_HTTPManagerState
{
	kHTTPState_none = 0,
	kHTTPState_download,
	kHTTPState_listDirectory,
	kHTTPState_upload,
	kHTTPState_abort,
	kHTTPState_failed,
	kHTTPState_done
};


// --------------------------------------------------------------------------------------------------------
// --------------------------------------------------------------------------------------------------------


