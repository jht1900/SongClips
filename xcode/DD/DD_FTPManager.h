/*
 Copyright (C) 2008 John Henry Thompson. All Rights Reserved.
 */

#import <Foundation/Foundation.h>

#import "DD_RemoteSite.h"
#import "DD_FileFTP.h"
#import "DD_FTPOp.h"

@protocol DD_FTPManagerDelegate;

// --------------------------------------------------------------------------------------------------------
@interface DD_FTPManager : NSObject <DD_FTPOpDelegate, NSURLConnectionDelegate>
{
	id <DD_FTPManagerDelegate> __unsafe_unretained delegate;
    DD_FTPOp       *ftpop;
	DD_RemoteSite	*remoteSite;
	NSString	*destRoot;	// Need own copy, may change in Local directory listing
	NSString	*path;
	NSError		*lastErr;
	NSString	*lastErrMsg;
	NSString	*downloadFileName;
	NSDate		*downloadFileModDate;
	
	int			state;

	BOOL		remote;
	BOOL		started;
	BOOL		checkForRestartableErrors;
	BOOL		attemptPersistent;
	BOOL		abortImmediately;
	BOOL		silentError;
	BOOL		downloadTrueName;
	BOOL		encodeFile;
	BOOL		skipMissing;

    BOOL                getFileAttributeMode;
    NSDate              *fileModDate;
    SInt64              fileSize;
    
    BOOL                useFilesVars;
    NSMutableDictionary	*filesDict;
    NSString            *filesParamLines;
    NSUInteger			filesScanLocation;
}

@property (nonatomic, unsafe_unretained) id <DD_FTPManagerDelegate> delegate;
@property (nonatomic, strong) DD_FTPOp			*ftpop;
@property (nonatomic, strong) DD_RemoteSite	*remoteSite;
@property (nonatomic, strong) NSString	*destRoot;
@property (nonatomic, strong) NSString	*path;
@property (nonatomic, strong) NSError	*lastErr;
@property (nonatomic, strong) NSString	*lastErrMsg;
@property (nonatomic, strong) NSString	*downloadFileName;
@property (nonatomic, strong) NSDate	*downloadFileModDate;

@property (nonatomic) BOOL				remote;
@property (nonatomic) BOOL				checkForRestartableErrors;
@property (nonatomic) BOOL				attemptPersistent;
@property (nonatomic) BOOL				abortImmediately;
@property (nonatomic) BOOL				silentError;
@property (nonatomic) BOOL				downloadTrueName;
@property (nonatomic) BOOL				encodeFile;

@property (nonatomic) BOOL				skipMissing;

@property (nonatomic, assign) BOOL              getFileAttributeMode;
@property (nonatomic, strong) NSDate            *fileModDate;
@property (nonatomic, assign) SInt64            fileSize;

@property (nonatomic, assign) BOOL              useFilesVars;
@property (nonatomic, strong) NSMutableDictionary	*filesDict;
@property (nonatomic, strong) NSString				*filesParamLines;
@property (nonatomic, assign) NSUInteger			filesScanLocation;

//@property (nonatomic, strong) NSDictionary			*fileListOptions;

@property (nonatomic, assign) int            state;

@property (nonatomic, strong) NSString				*deletePathWhenDone;

- (BOOL) fileTP;

- (int) listDirectory;

- (int) listDirectoryDepthFirst;

- (int) listDirectoryNested;

- (void) listLocalDirectory;

- (NSString *) destPathToStoreFileName: (NSString *)fileName modDate:(NSDate*)modDate;

- (BOOL) downLoadFile: (DD_FileFTP*)sf fileOffset:(SInt64)fileOffset pathHome: (NSString *) pathHome;

- (BOOL) upLoadFile: (NSString*)filePath asFileName: (NSString*) asFilename;

- (void) clear;

- (void) abort;

- (BOOL) operationDoneOK;

- (NSTimeInterval) lapseTime;	// Lapse time since ANY response from server

- (void) reportError;

- (BOOL) restartAbleError;

- (void) copyTo: (DD_FTPManager*) ftp2;

- (DD_FTPManager*) copy;

- (DD_FTPManager*) initWithRemote: (DD_RemoteSite*) remote;

- (BOOL) deleteUnrefLocal;

- (void) setFilesParamLines: (NSString *) param filesScanLocation: (int) offset;

@end

// --------------------------------------------------------------------------------------------------------

@protocol DD_FTPManagerDelegate <NSObject>

@optional

- (void) downLoadFileBytesSoFar: (SInt64)bytesSoFar ;

- (BOOL) listDirectoryFileEntry: (NSString*)cfName 
				   isDirectory: (BOOL)isDirectory 
						  size: (SInt64)size 
						  date: (NSDate*)cfDate
						  path: (NSString *)path
						source: (NSString *)source;

- (void) operationDone;

@end

// --------------------------------------------------------------------------------------------------------


#define kFTPTemp_Contents	@"_siteclone_temp_contents"
#define kFTPTemp_Name		@"_siteclone_temp_name"

// --------------------------------------------------------------------------------------------------------

enum FTPManagerState 
{
	kFTPState_none = 0,
	kFTPState_download,
	kFTPState_listDirectory,
	kFTPState_upload,
	kFTPState_abort,
	kFTPState_failed,
	kFTPState_done
};

#define kFTP_NESTED_DONE		2


// --------------------------------------------------------------------------------------------------------
// --------------------------------------------------------------------------------------------------------


