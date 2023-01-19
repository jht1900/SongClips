/*
 Copyright (C) 2008 John Henry Thompson. All Rights Reserved.
 */

#import "Song.h"
#import "Clip.h"
#import "SongList.h"
#import "AppDefs.h"
#import "AppUtil.h"
#import "AppDelegate.h"
#import "Scanner.h"
#import "UtilPath.h"
#import "JSONKit.h"

// ------------------------------------------------------------------------------------
// Per Song

#define kPresistentIDKey	@"persistentID"
#define kUrl                @"url"
#define kAlbumTitleKey		@"albumTitle"
#define kTitleKey			@"title"
#define kArtistKey			@"artist"
#define kDurationKey		@"duration"
#define kCurrentPosKey		@"position"
#define kLabelKey			@"label"
#define kFileNameKey		@"fileName"
#define kNextRecordingIDKey	@"nextRecordingID"
#define kSourceRefKey       @"sourceRef"
#define kClipsSourceRef		@"clipsSourceRef"
#define kClipListKey		@"cliplist"

#define K_sourceForLocal	@"K_sourceForLocal"
#define K_partialPath		@"K_partialPath"
#define K_s_mediaItem_video	@"K_s_mediaItem_video"
#define K_source_stream		@"K_source_stream"
#define K_speed_shift_list	@"K_speed_shift_list"

// ------------------------------------------------------------------------------------

@implementation Song

// ------------------------------------------------------------------------------------
- (void)dealloc
{
	for (Clip *clip in _clipList) {
		clip.song = nil;
	}
}

// ------------------------------------------------------------------------------------
- (NSString *) file_display_size
{
	// partialPath
	NSString *localPath = _partialPath;
	if (_partialPath) {
		localPath = [localStoreRoot() stringByAppendingString: localPath];
		NSDictionary *finfo = [[NSFileManager defaultManager] attributesOfItemAtPath: localPath error:nil];
		if (finfo) {
			unsigned long long fileSize = [finfo fileSize];
			return [AppUtil formatDoubleBytes: fileSize];
		}
	}
	return @"";
}

// ------------------------------------------------------------------------------------
- (Clip*) newClip
{
	Clip *clip = [[Clip alloc] init];
	clip.song = self;
	return clip;
}

// ------------------------------------------------------------------------------------
// Init the default clip with spans the entire song
- (void) initClipList
{
	_clipList = [NSMutableArray arrayWithCapacity: 1];
	Clip *clip = [self newClip];
	clip.notation = _title;
	clip.subDuration = _duration;
	clip.startTime = 0.0;
	clip.recordingDuration = 0.0;
	[_clipList addObject: clip];
	ATRACE2(@"Song: initClipList: clipList=%@", clipList);
}

// ------------------------------------------------------------------------------------
- (void) initForLocal
{
	if (! _title) _title = [_partialPath lastPathComponent];
	_albumTitle = _title;
	_label = _title;
	
	if (! _clipList) [self initClipList];
	
	[self freshSave];
}

// ------------------------------------------------------------------------------------
// Take an export string and re-create Song
- (Song*) initFromExportString: (NSString *) str
{
	if ([str hasPrefix:@"{"]) {
		self = [self parseFromJSON: str];
	}
	else {
		self = [self parseFromExportString: str];
		if (self) {
			[self findMediaItem];
		}
	}
	[self freshSave];
	return self;
}

// ------------------------------------------------------------------------------------
- (Song*) parseFromJSON: (NSString*) str
{
	ATRACE(@"parseFromJSON str=%@", str);

	NSDictionary *dict = [str objectFromJSONString];
	if (! dict) {
		ATRACE(@"parseFromJSON failed! str=%@", str);
		return self;
	}
	_init_deferred = YES;
	_title = dict[@"title"];
	_duration = [dict[@"duration"] floatValue];
	_sourceForLocal = dict[@"source_url"];
	_pause_on_load = [dict[@"pause_on_load"] boolValue];
	_source_stream = [dict[@"source_stream"] boolValue];
	_speed_shift_list = dict[@"speed_shift_list"];

	NSArray *newClipList = dict[@"clip_list"];
	if (newClipList) {
		NSTimeInterval newClipStartTime = 0;
		_clipList = [NSMutableArray arrayWithCapacity: [newClipList count]];
		for (NSDictionary *sourceClip in newClipList) {
			
			Clip *aClip = [self newClip];
			aClip.notation = sourceClip[@"title"];
			aClip.subDuration = [sourceClip[@"duration"] doubleValue];
			aClip.clip_rate = [sourceClip[@"rate"] doubleValue];
			aClip.startTime = newClipStartTime;
			
			[_clipList addObject: aClip];

			ATRACE(@"parseFromJSON aClip startTime=%f subDuration=%f clip_rate=%f ", aClip.startTime, aClip.subDuration, aClip.clip_rate);

			newClipStartTime += aClip.subDuration;
		}
	}
	
	return self;
}

// ------------------------------------------------------------------------------------
- (NSString *) store_name
{
	if (! _s_store_name) {
		NSString *prefix = _label;
		if (! prefix) prefix = _title;
		_s_store_name = [[SongList default] nextSongFileName: prefix];
	}
	return _s_store_name;
}

// ------------------------------------------------------------------------------------
// Assign fileName and save song
- (void) freshSave
{
	// Assign _s_store_name
	(void) [self store_name];

	[self saveToDisk];
	
	// SongList must save to make sure it's array is up to date
	[[SongList default] saveToDisk];
}

// ------------------------------------------------------------------------------------
- (void) applyReplacement: (MPMediaItem *) newMediaItem
{
	_s_mediaItem = newMediaItem;
	_persistentID = [newMediaItem valueForProperty: MPMediaItemPropertyPersistentID];
	_albumTitle = [newMediaItem valueForProperty: MPMediaItemPropertyAlbumTitle];
	_title = [newMediaItem valueForProperty: MPMediaItemPropertyTitle];
	_artist = [newMediaItem valueForProperty: MPMediaItemPropertyArtist];
	_duration = [[newMediaItem valueForProperty: MPMediaItemPropertyPlaybackDuration] floatValue];
	_s_mediaItem_video = ([[_s_mediaItem valueForProperty: MPMediaItemPropertyMediaType] intValue]&MPMediaTypeAnyVideo)!=0;
	if (_s_mediaItem_video) {
        _s_url = (NSURL*)[_s_mediaItem valueForProperty:MPMediaItemPropertyAssetURL];
    }
	_mediaMissing = NO;
	ATRACE(@"Song: applyReplacement: persistentID=%@ title=%@ albumTitle=%@ artist=%@ _s_mediaItem_video=%d", _persistentID, _title, _albumTitle, _artist, _s_mediaItem_video);
}

// ------------------------------------------------------------------------------------
// Remember enough about the song incase the persistentid dies later
- (Song*) initWithMediaItem: (MPMediaItem*) newMediaItem 
{
	[self applyReplacement: newMediaItem];
	_label = _title;
	_nextRecordingID = 0;
	ATRACE2(@"Song: initWithMediaItem: persistentID=%@ _title=%@ _duration=%f ", persistentID, _title, _duration);

	[self initClipList];
	
	[self freshSave];
	
	return self;
}

// ------------------------------------------------------------------------------------
// Convert clip List to simple array for saving
- (NSArray*) saveClipListToArray
{
	NSMutableArray		*arr = [NSMutableArray arrayWithCapacity: [self clipCount]];
	NSDictionary		*clipDict;
	Clip				*clip;
	ATRACE2(@"Song: saveClipListToArray: clipList=%@", clipList);

	for (clip in _clipList) {
		clipDict = [clip asDict];

		[arr addObject: clipDict];
	}
	return arr;
}

// ------------------------------------------------------------------------------------
// Take an array of clip entries and create in memory clip list
- (void) initClipListFromArray: (NSArray*) arr
{
	NSDictionary		*dict;
	NSTimeInterval		startTime = 0.0;
	
	ATRACE2(@"Song: initClipListFromArray: arr=%@", arr);
	_clipList = [NSMutableArray arrayWithCapacity: [arr count]];

	for (dict in arr)
	{
		Clip *clip = [self newClip];
		[clip initFromDict: dict];
		clip.startTime = startTime;
        [_clipList addObject: clip];
		startTime += clip.subDuration;
	}
}

// ------------------------------------------------------------------------------------
// Save our internal state into Dictionary
// persistentID maybe nil if media is not in iPod library
- (NSDictionary*) saveToDict
{
	NSMutableDictionary	*dict = [NSMutableDictionary dictionaryWithCapacity: 0];
	
	[dict setValue:_persistentID			forKey: kPresistentIDKey];
	[dict setValue:_albumTitle				forKey: kAlbumTitleKey];
	[dict setValue:_title					forKey: kTitleKey];
	[dict setValue:_artist					forKey: kArtistKey];
	[dict setValue:_label					forKey: kLabelKey];
	[dict setValue:_sourceRef				forKey: kSourceRefKey];
	[dict setValue:[self saveClipListToArray] forKey: kClipListKey];
	[dict setValue:_clipsSourceRef			forKey: kClipsSourceRef];
	[dict setValue:_sourceForLocal			forKey: K_sourceForLocal];
	[dict setValue:_partialPath				forKey: K_partialPath];
	[dict setValue:@(_nextRecordingID)		forKey: kNextRecordingIDKey];
	[dict setValue:@(_duration)				forKey: kDurationKey];
	[dict setValue:@(_currentPos)			forKey: kCurrentPosKey];
	[dict setValue:@(_s_mediaItem_video)	forKey: K_s_mediaItem_video];

	[dict setValue:@(_source_stream)		forKey: K_source_stream];
	
	[dict setValue:_speed_shift_list		forKey: K_speed_shift_list];

	return dict;
}

// ------------------------------------------------------------------------------------
// Restore Song from dict. convert persistentID to MPMediaItem
- (Song*) initFromDict: (NSDictionary*) dict
{
	// fileName set by caller
	_persistentID = dict[kPresistentIDKey];
	_albumTitle = dict[kAlbumTitleKey];
	_title = dict[kTitleKey];
	_artist = dict[kArtistKey];
	_duration = [dict[kDurationKey] floatValue];
	_currentPos = [dict[kCurrentPosKey] floatValue];
	_label = dict[kLabelKey];
	if (! _label) _label = _title;
	_nextRecordingID = [dict[kNextRecordingIDKey] intValue];
	_sourceRef = dict[kSourceRefKey];
	_clipsSourceRef  = dict[kClipsSourceRef];
	
	_sourceForLocal = dict[K_sourceForLocal];
	_partialPath = dict[K_partialPath];
	_s_mediaItem_video = [dict[K_s_mediaItem_video] intValue];

	_source_stream = [dict[K_source_stream] boolValue];

	_speed_shift_list = dict[K_speed_shift_list];

	[self queryForMediaItem];
	
	[self initClipListFromArray: dict[kClipListKey] ];
	
	ATRACE2(@"Song: initFromDict: dict=%@ persistentID=%@ _title=%@ _duration=%f ", _dict, _persistentID, _title, _duration);
	
	return self;
}


// ------------------------------------------------------------------------------------
// Use title, albumTitle, artist to find a media item AND persistentID
- (void) findMediaItemTitleOnly: (BOOL) titleOnly
{
    ATRACE(@"Song: findMediaItemTitleOnly titleOnly=%d title=%@ albumTitle=%@ artist=%@ has_mediaItem=%d", titleOnly, _title, _albumTitle, _artist, _s_mediaItem_video);
	if (! _title ) {
		ATRACE(@"Song: findMediaItem FAIL title=%@ albumTitle=%@ artist=%@ url=%@", _title, _albumTitle, _artist, _s_url);
		return;
	}
	MPMediaPropertyPredicate *idPredicate;
	MPMediaQuery *idQuery = [[MPMediaQuery alloc] init];
	idPredicate =   [MPMediaPropertyPredicate predicateWithValue: _title
													 forProperty: MPMediaItemPropertyTitle];
	[idQuery addFilterPredicate: idPredicate]; 
    if (_s_mediaItem_video) {
        idPredicate = [MPMediaPropertyPredicate predicateWithValue: @(MPMediaTypeAnyVideo)
                                                   forProperty: MPMediaItemPropertyMediaType];
        [idQuery addFilterPredicate: idPredicate];
    }
    if (_albumTitle && ! titleOnly) {
        idPredicate =   [MPMediaPropertyPredicate predicateWithValue: _albumTitle
                                                         forProperty: MPMediaItemPropertyAlbumTitle];
        [idQuery addFilterPredicate: idPredicate]; 
	}
    if (_artist && ! titleOnly) {
        idPredicate =   [MPMediaPropertyPredicate predicateWithValue: _artist
                                                         forProperty: MPMediaItemPropertyArtist];
        [idQuery addFilterPredicate: idPredicate]; 
	}
	NSArray *itemArray = [idQuery items];
	if ([itemArray count] > 0) {
		_s_mediaItem = itemArray[0];
		ATRACE(@"Song: findMediaItem: mediaItem=%@ _s_mediaItem_video=%d count=%lu", _s_mediaItem, _s_mediaItem_video, (unsigned long)[itemArray count]);
		_persistentID = [_s_mediaItem valueForProperty: MPMediaItemPropertyPersistentID];
		_mediaMissing = NO;
        if (_s_mediaItem_video) {
            _s_url = (NSURL*)[_s_mediaItem valueForProperty:MPMediaItemPropertyAssetURL];
        }
	}
	else {
		_s_mediaItem = nil;
		ATRACE(@"Song: findMediaItem: CANT FIND song title=%@ albumTitle=%@ artist=%@", _title, _albumTitle, _artist);
		_mediaMissing = YES;
	}
	ATRACE(@"Song: findMediaItem: persistentID=%@ title=%@ albumTitle=%@ artist=%@", _persistentID, _title, _albumTitle, _artist);
}

// ------------------------------------------------------------------------------------
// Use title, albumTitle, artist to find a media item AND persistentID
- (void) findMediaItem
{
    [self findMediaItemTitleOnly: NO];
    
    if (_mediaMissing) [self findMediaItemTitleOnly: YES];
}

// ------------------------------------------------------------------------------------
// User persistentID to find mediaItem
- (void) queryForMediaItemByPersistenID
{
	MPMediaPropertyPredicate *idPredicate =  
	[MPMediaPropertyPredicate predicateWithValue: _persistentID
									 forProperty: MPMediaItemPropertyPersistentID]; 
	MPMediaQuery *idQuery = [[MPMediaQuery alloc] init];
	[idQuery addFilterPredicate: idPredicate];
	NSArray *itemArray = [idQuery items];
	if ([itemArray count] > 0) {
		_s_mediaItem = itemArray[ 0];
		ATRACE(@"Song: initFromDict: mediaItem=%@ _s_mediaItem_video=%d count=%lu", _s_mediaItem, _s_mediaItem_video, (unsigned long)[itemArray count]);
		if (_s_mediaItem_video) {
			_s_url = (NSURL*)[_s_mediaItem valueForProperty:MPMediaItemPropertyAssetURL];
		}
		_mediaMissing = NO;
	}
	else {
		_s_mediaItem = nil;
		ATRACE(@"Song: initFromDict: NO mediaItem for persistentID=%@", _persistentID);
		_mediaMissing = YES;
	}
}

// ------------------------------------------------------------------------------------
// User persistentID to find mediaItem
- (void) queryForMediaItem
{
	ATRACE(@"Song: queryForMediaItem _partialPath=%@ _sourceForLocal=%@ persistentID=%@ _source_stream=%d", _partialPath, _sourceForLocal, _persistentID, _source_stream);

	if (_sourceForLocal) {
		if (_source_stream) {
			_s_url = [NSURL URLWithString:_sourceForLocal];
			ATRACE(@"Song: queryForMediaItem _source_stream _s_url=%@", _s_url);
		}
		else if (_partialPath) {
			NSString *localPath = _partialPath;
			localPath = [localStoreRoot() stringByAppendingString: localPath];
			_s_url = [NSURL fileURLWithPath: localPath];
			ATRACE(@"Song: queryForMediaItem localPath=%@ _s_url=%@", localPath, _s_url);
		}
		if (! _s_url) {
			_mediaMissing = YES;
		}
		return;
	}
	if (! _persistentID) {
		[self findMediaItem];
		return;
	}
	[self queryForMediaItemByPersistenID];
	
	if (! _s_mediaItem) {
		[self findMediaItem];
	}
}

// ------------------------------------------------------------------------------------
// Read in the song from disk. Store in file <rootdoc>/<fileName>/song.plist
- (void) restoreFromDisk
{
	NSString		*path = [[self songDirectoryPath] stringByAppendingPathComponent: kSongPlistFileName ];
	NSDictionary	*songDict;
	ATRACE2(@"Song: restoreFromDisk path=%@", path);

    if ([[NSFileManager defaultManager] fileExistsAtPath: path] == NO) {
		AFLOG(@"Song: restoreFromDisk FAILED for fileName=%@", _s_store_name);
		return;
	}
	songDict = [NSDictionary dictionaryWithContentsOfFile: path];
	if (! songDict) {
		AFLOG(@"Song: restoreFromDisk dictionaryWithContentsOfFile FAILED for fileName=%@", _s_store_name);
	}
	(void) [self initFromDict: songDict];
}

// ------------------------------------------------------------------------------------
- (void) saveToDisk
{
	//ATRACE(@"Song saveToDisk: dirty=%d clipList count=%d", dirty, [clipList count]);
	ATRACE(@"Song saveToDisk: clipList count=%lu",(unsigned long)[_clipList count]);
	// Create directory for Song plist and recordings
	NSString		*path = [self songDirectoryPath];
	[[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories: YES attributes:nil error: nil];
	path = [path stringByAppendingPathComponent: kSongPlistFileName ];
	NSDictionary *songDict = [self saveToDict];
	[songDict writeToFile: path atomically: YES];
}

// ------------------------------------------------------------------------------------
// Return clip at the given index, or nil if out of bounds
- (Clip*) clipAtIndex: (int) index
{
	ATRACE2(@"Song: clipAtIndex: index=%d", index);
	if (index < 0 || index >= [self clipCount]) {
		ATRACE2(@"Song: clipAtIndex: OUT OF RANGE index=%d count=%d", index, [self clipCount]);
		return nil;
	}
	return _clipList[ index];
}

// ------------------------------------------------------------------------------------
// Split clip at index into two, first clip gets newSubDuration.
// Second clip duration is what left over
// Second clip insert next higher slot
- (void) splitClipAtIndex: (int) index newSubDuration: (NSTimeInterval) newSubDuration
{
	NSTimeInterval	orgSubDuration;
	NSTimeInterval	diffSubDuration;
	Clip		*clip;
	ATRACE(@"Song: splitClipAtIndex: index=%d newSubDuration=%f", index, newSubDuration);

	clip = [self clipAtIndex: index];
	if (! clip)
		return;
	orgSubDuration = clip.subDuration;
    // Don't allow negative duration
    diffSubDuration = orgSubDuration - newSubDuration;
    if (diffSubDuration < 0) {
        ATRACE(@"Song: splitClipAtIndex: IGNORE index=%d diffSubDuration=%f", index, diffSubDuration);
        return;
    }
	clip.subDuration = newSubDuration;
	Clip *nclip = [self newClip];
	nclip.subDuration = diffSubDuration;
	nclip.startTime = clip.startTime + newSubDuration;
	
    [_clipList insertObject:nclip atIndex: index+1];
	
	[self saveToDisk];
}

// ------------------------------------------------------------------------------------
// Remove clip at index. duration of removed clip gets added to clip to prior clip
// If no prior clip, duration is added to next clip
- (void) removeClipAtIndex: (int) index
{
	NSTimeInterval	orgSubDuration;
	Clip		*clip;
	int	priorIndex;
	Clip		*nclip;
	ATRACE(@"Song: removeClipAtIndex: index=%d", index);

	// Prevent delete last clip
	if ([self clipCount] <= 1)
		return;
	clip = [self clipAtIndex: index];
	if (! clip)
		return;
	// Hold on to clip so we can ref after removeObjectAtIndex
	orgSubDuration = clip.subDuration;
	[_clipList removeObjectAtIndex: index];
	priorIndex = index;
	if (priorIndex != 0) {
		priorIndex--;
	}
	nclip = _clipList[ priorIndex];
	if (priorIndex == index) {
		// No prior
		nclip.startTime = 0.0;
	}
	// Transfer over notation from deleted clip
	if ([nclip.notation length] <= 0 && clip.notation)
		nclip.notation = clip.notation;
	nclip.subDuration = nclip.subDuration + orgSubDuration;
	
	[clip removeMediaFiles];
	
	[self saveToDisk];
}

// ------------------------------------------------------------------------------------
- (int) clipCount
{
	return (int)[_clipList count];
}

// ------------------------------------------------------------------------------------
// Return clip index that matches given time
- (int) clipIndexForTime: (NSTimeInterval) aTime
{
	Clip	*clip;
	int		index;
	ATRACE2(@"Song: clipIndexForTime: aTime=%f", aTime);
	
	index = 0;
	for (clip in _clipList) {
		ATRACE2(@" clip.startTime=%f index=%d", clip.startTime, index);
		if (clip.startTime > aTime)
			break;
		index++;
	}
	if (index <= 0)
		return 0;
	return index-1;
}

// ------------------------------------------------------------------------------------
- (Clip*) clipForTime: (NSTimeInterval) aTime
{
	int		index = [self clipIndexForTime: aTime];
	return _clipList[ index];
}

// ------------------------------------------------------------------------------------
// Export Text: line for single line
// OR Text[ ... ]Text block for multi line string
- (void) appendToString: (NSMutableString*) str oneText: (NSString *) oneText
{
	NSRange	range = [oneText rangeOfString: @"\n"];
	if (range.location == NSNotFound) {
		[str appendFormat:@"Text: %@\n", oneText];
	}
	else {
		[str appendFormat:@"Text[\n%@\n]Text\n", oneText];
	}
}


// ------------------------------------------------------------------------------------
// Export song as string 
// !!@ should filter out newline from entries
- (NSString *) asExportString
{
	ATRACE(@"Song: asExportString: mediaItem=%@ type=%@", _s_mediaItem, [_s_mediaItem valueForProperty: MPMediaItemPropertyMediaType]);

	NSMutableString *str = [NSMutableString stringWithCapacity: 0];
	Clip	*clip;
	int		index;
	
	[str appendFormat:@"\nSong Label: %@\n", _label ];
    
	[str appendFormat:@"Song Title: %@\n", _title ];

    if (_albumTitle) {
        [str appendFormat:@"Album Title: %@\n", _albumTitle];
    }
    
    if (_artist) {
        [str appendFormat:@"Artist: %@\n", _artist];
    }
	[str appendFormat:@"Duration: %@\n", [AppUtil formatDurationExport: _duration]];
    
	[str appendFormat:@"Clips: %d\n", [self clipCount]];

	[str appendFormat:@"Exporter: %@\nExport Date: %@\n",
		[[AppDelegate default] appNameVersion],
		[[NSDate date] description] ];
    if ([_sourceRef length] > 0) {
        [str appendFormat:@"Source: %@\n", _sourceRef];
    }
	if (_s_mediaItem_video) {
		[str appendFormat:@"Video: 1\n"];
	}
	index = 1;
	for (clip in _clipList) {
		[str appendFormat:@"Clip: %d\nStartTime: %@\nDuration: %@\n",
			index, 
			[AppUtil formatDurationExport: clip.startTime], 
			[AppUtil formatDurationExport: clip.subDuration] ];
		index++;
		if (clip.imageRef)
			[str appendFormat:@"Image: %@\n", clip.imageRef];
		if (clip.linkRef)
			[str appendFormat:@"Link: %@\n", clip.linkRef];
		if (clip.webRef )
			[str appendFormat:@"Web: %@\n", clip.webRef];
		if (clip.texts) {
			for (NSString *oneText in clip.texts) {
				[self appendToString: str oneText: oneText];
			}
		}
	}
	return str;
}

// ------------------------------------------------------------------------------------
// Parse a clip
- (BOOL) parseClip: (Scanner *) scanner
{
	BOOL				more = NO;
	NSString			*tmp;
	double				ftmp;
	ATRACE2(@"Song: parseClip ");
	
	Clip *clip = [self newClip];
	clip.texts = [NSMutableArray array];
	for (; ! [scanner isAtEnd];) {
		if (! [scanner nextLine] )
			continue;
		ATRACE2(@"parseClip:                     line=%@", [scanner line]);
		if ([scanner hasPrefix: @"StartTime:" toFloatDuration: &ftmp]) {
			clip.startTime = ftmp;
		}
		else if ([scanner hasPrefix: @"Duration:" toFloatDuration: &ftmp]) {
			clip.subDuration = ftmp;
		}
		else if ([scanner hasPrefix: @"Link:" toString: &tmp]) {
			clip.linkRef = tmp;
		}
		else if ([scanner hasPrefix: @"Image:" toString: &tmp]) {
			clip.imageRef = tmp;
		}
		else if ([scanner hasPrefix: @"Web:" toString: &tmp]) {
			clip.webRef = tmp;
		}
		else if ([scanner hasPrefix: @"Clip:" toString: &tmp]) {
			more = YES;
			break;
		}
		else if ([scanner hasPrefix: @"Song End:" toString: &tmp]) {
			more = NO;
			break;
		}
		else if ([scanner hasTextBlockPrefix: @"Text" toArray: clip.texts]) {
		}
		else {
			// Add unrecoginzed line to texts
			[clip.texts addObject: [scanner line]];
		}
	}
	
	[_clipList addObject: clip];
exit:;
	return more;
}

// ------------------------------------------------------------------------------------
- (Song *) parseFromExportString: (NSString *) str
{
	Scanner		*scanner = [Scanner scannerWithString: str];
	NSString	*clipNum;
	NSString	*totalClips;
	NSString	*tmp;
	ATRACE(@"Song: parseFromExportString: str length=%lu", (unsigned long)[str length]);
	
	_clipList = [NSMutableArray arrayWithCapacity: 0];
	_label = @"";
	_title = @"";
	
	for (; ! [scanner isAtEnd];) {
		if (! [scanner nextLine] )
			continue;
		ATRACE(@"Song:		line=%@", [scanner line]);
		if ([scanner hasPrefix: @"Song Label:" toString: &tmp]) {
			_label = tmp;
		}
		else if ([scanner hasPrefix: @"Song Title:" toString: &tmp]) {
			_title = tmp;
		}
		else if ([scanner hasPrefix: @"Album Title:" toString: &tmp]) {
			_albumTitle = tmp;
		}
		else if ([scanner hasPrefix: @"Artist:" toString: &tmp]) {
			_artist = tmp;
		}
		else if ([scanner hasPrefix: @"Source:" toString: &tmp]) {
			_sourceRef = tmp;
		}
		else if ([scanner hasPrefix: @"Video:" toString: &tmp]) {
			_s_mediaItem_video = YES;
		}
		else if ([scanner hasPrefix: @"Duration:" toFloatDuration: &_duration]) {
		}
		else if ([scanner hasPrefix: @"Clips:" toString: &totalClips]) {
		}
		else if ([scanner hasPrefix: @"Exporter:" toString: &tmp]) {
		}
		else if ([scanner hasPrefix: @"Export Date:" toString: &tmp]) {
		}
		else if ([scanner hasPrefix: @"Clip:" toString: &clipNum]) {
			for (; [self parseClip: scanner ]; ) {
			}
			// ignore erros parsing clip for now
		}
		else if ([[scanner line] length]  > 0) {
			ATRACE(@"Song: SKIPPING line: %@", [scanner line]);
		}
	}
	// !! consider validating totalClips agains clipCount
	return self;
}

// ------------------------------------------------------------------------------------
- (Song *) initWithClipsRef: (NSString *)songClipsRef songLabel: (NSString *) songLabel
{
	_clipsSourceRef = songClipsRef;
	_label = songLabel;
	
	[self freshSave];

	return self;
}

// ------------------------------------------------------------------------------------
- (NSString *) songDirectoryPath
{
	NSString		*path = [AppDelegate localDir];
	return [path stringByAppendingPathComponent: _s_store_name ];
}

// ----------------------------------------------------------------------------------------------------------
// Return the next file name for new song
- (NSString*) nextMediaFileName: (NSString*) suffix
{
	NSString *nextName = [NSString stringWithFormat: @"%d-%@", _nextRecordingID, suffix ];
	_nextRecordingID++;
	
	return nextName;
}

// ----------------------------------------------------------------------------------------------------------
- (NSString*) pathNameForMediaFileName: (NSString *) mediaFileName
{
	return [[self songDirectoryPath] stringByAppendingPathComponent: mediaFileName];
}

// ----------------------------------------------------------------------------------------------------------
- (void) saveNewImage: (UIImage*) newImage forClipIndex: (int) clipIndex
{
	Clip	*clip = [self clipAtIndex: clipIndex ];
	[clip saveNewImage: newImage];
}

// ----------------------------------------------------------------------------------------------------------
- (Cache*) imageCache
{
	return [[SongList default] imageCache];
}

// ----------------------------------------------------------------------------------------------------------
- (Cache*) imageIconCache
{
	return [[SongList default] imageIconCache];
}

// ----------------------------------------------------------------------------------------------------------
- (void) removeAllClips
{
	[self initClipList];
	
	[self saveToDisk];
}

// ----------------------------------------------------------------------------------------------------------
- (void) makeClips: (int) nclips
{
	Clip	*nclip;
	int		index;
	NSTimeInterval time = 0;
	NSTimeInterval dur = [self duration] / nclips;
	
	_clipList = [NSMutableArray arrayWithCapacity: 1];
	for (index = 0; index < nclips; index++, time += dur) {
		nclip = [self newClip];
		nclip.subDuration = dur;
		nclip.startTime = time;
		
		[_clipList addObject: nclip];
		
	}
	[self saveToDisk];
}

// ----------------------------------------------------------------------------------------------------------
- (UIImage*) imageIcon
{
	ATRACE2(@"Song: imageIcon: imageIcon=%@", imageIcon);
	if (imageIcon)
		return imageIcon;
	// Get the artwork from the current media item, if it has artwork.
	MPMediaItemArtwork *artwork = [_s_mediaItem valueForProperty: MPMediaItemPropertyArtwork];
	ATRACE2(@"Song: imageIcon: artwork=%@", artwork);

	// Obtain a UIImage object from the MPMediaItemArtwork object
	imageIcon = [artwork imageWithSize: CGSizeMake(32, 32)];
	
	return imageIcon;
}

// ------------------------------------------------------------------------------------
// ------------------------------------------------------------------------------------

@end


