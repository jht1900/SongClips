/*
 Copyright (C) 2008 John Henry Thompson. All Rights Reserved.
 */

#import <Foundation/Foundation.h>
#import <MediaPlayer/MediaPlayer.h>

#import "Clip.h"
#import "Cache.h"

@interface Song : NSObject
{	
	UIImage			*imageIcon;
}

@property (nonatomic, strong) MPMediaItem		*s_mediaItem;
@property (nonatomic, strong) NSURL             *s_url;
@property (nonatomic, strong) NSNumber			*persistentID;
@property (nonatomic, strong) NSString			*sourceForLocal;
@property (nonatomic, strong) NSString			*partialPath;
@property (nonatomic, strong) NSString			*albumTitle;
@property (nonatomic, strong) NSString			*title;
@property (nonatomic, strong) NSString			*artist;
@property (nonatomic, strong) NSString			*label;
@property (nonatomic, strong) NSString			*s_store_name;
@property (nonatomic, strong) NSString			*sourceRef;
@property (nonatomic, strong) NSString			*clipsSourceRef;
@property (nonatomic, strong) NSMutableArray	*clipList;
@property (nonatomic, strong) NSMutableArray	*speed_shift_list;

@property (nonatomic, assign) NSTimeInterval	duration;
@property (nonatomic, assign) NSTimeInterval	currentPos;

@property (nonatomic, assign) int               nextRecordingID;
@property (nonatomic, assign) BOOL				mediaMissing;
@property (nonatomic, assign) BOOL				mediaMissingShown;
@property (nonatomic, assign) BOOL				s_mediaItem_video;
@property (nonatomic, assign) BOOL				init_deferred;
@property (nonatomic, assign) BOOL				pause_on_load;
@property (nonatomic, assign) BOOL				source_stream;


- (Song*) initWithMediaItem: (MPMediaItem*) mediaItem ;

- (Song *) initWithClipsRef: (NSString *)songClipsRef songLabel: (NSString *) songLabel;

- (void) initForLocal;

- (void) restoreFromDisk;

- (void) saveToDisk;

- (Clip*) clipAtIndex: (int) index;

- (void) splitClipAtIndex: (int) index newSubDuration: (NSTimeInterval) newSubDuration;

- (void) removeClipAtIndex: (int) index;

- (int) clipCount;

- (int) clipIndexForTime: (NSTimeInterval) aTime;

- (Clip*) clipForTime: (NSTimeInterval) aTime;

- (NSString *) asExportString;

- (Song*) initFromExportString: (NSString *) str;

- (NSString *) songDirectoryPath;

- (NSString*) nextMediaFileName: (NSString*) suffix;

- (NSString*) pathNameForMediaFileName: (NSString *) mediaFileName;

- (void) saveNewImage: (UIImage*) newImage forClipIndex: (int) clipIndex;

- (Clip*) newClip;

- (Cache*) imageCache;

- (Cache*) imageIconCache;

- (void) removeAllClips;

- (void) makeClips: (int) nclips;

- (void) queryForMediaItem;

- (void) applyReplacement: (MPMediaItem *) mediaItem;

- (UIImage*) imageIcon;

- (NSString *) store_name;

- (NSString *) file_display_size;

@end

// --------------------------------------------------------------------------------------------------------
// --------------------------------------------------------------------------------------------------------
