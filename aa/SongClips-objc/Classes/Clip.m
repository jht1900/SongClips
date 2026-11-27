/*
 Copyright (C) 2008 John Henry Thompson. All Rights Reserved.
 */

#import "Clip.h"
#import "Song.h"
#import "AppDefs.h"
#import "AppUtil.h"
#import "SongList.h"

// ------------------------------------------------------------------------------------
// Per Clip

#define kTextsKey					@"texts"
#define kRecordingFileNameKey		@"recordingFileName"
#define kRecordingDurationKey		@"recordingDuration"
#define kSubDurationKey				@"subDuration"
#define kImageFileNameKey			@"imageFileName"
#define kImageRefKey				@"imageRef"
#define kLinkRefKey					@"linkRef"
#define kWebRefKey					@"webRef"
#define K_clip_rate					@"K_clip_rate"


// ------------------------------------------------------------------------------------
@implementation Clip

// ------------------------------------------------------------------------------------
- (void)dealloc
{
	access.delegate = nil;
}

// ------------------------------------------------------------------------------------
- (NSDictionary *) asDict
{
	NSMutableDictionary *clipDict = [NSMutableDictionary dictionaryWithDictionary:
					@{kSubDurationKey: @(_subDuration), kRecordingDurationKey: @(_recordingDuration)}];
	[clipDict setValue: _recordingFileName forKey: kRecordingFileNameKey];
	[clipDict setValue: _imageFileName forKey: kImageFileNameKey];
	[clipDict setValue: _imageRef forKey: kImageRefKey];
	[clipDict setValue: _linkRef forKey: kLinkRefKey];
	[clipDict setValue: _webRef forKey: kWebRefKey];
	[clipDict setValue: _texts forKey: kTextsKey];
	
	[clipDict setValue: @(_clip_rate) forKey: K_clip_rate];
	
	return clipDict;
}

// ------------------------------------------------------------------------------------
- (void) initFromDict: (NSDictionary *) dict
{
	_subDuration = [dict[kSubDurationKey] floatValue];
	_recordingFileName = dict[kRecordingFileNameKey];
	_recordingDuration = [dict[kRecordingDurationKey] floatValue];
	_imageFileName = dict[kImageFileNameKey];
	_imageRef = dict[kImageRefKey];
	_linkRef = dict[kLinkRefKey];
	_webRef	= dict[kWebRefKey];
	NSMutableArray *texts = dict[kTextsKey];
	if (texts) {
		texts = [NSMutableArray arrayWithArray: texts];
	}
	_texts = texts;
	
	_clip_rate = [dict[K_clip_rate] floatValue];
}

// ------------------------------------------------------------------------------------
// Access notation
- (NSString *) notation
{
	if (! _texts || [_texts count] < 1)
		return nil;
#if APP_FULL_NOTATION
    NSMutableString *buf = [NSMutableString stringWithCapacity: 100];
    int count = (int)[_texts count];
    int index = 0;
    NSString *line;
    for (line in _texts) {
        [buf appendString: line];
        index++;
        if (index < count)
            [buf appendString:@"\n\n"];
    }
    return buf;
#else
    return texts [ 0];
#endif
}

// Set notation, create array and set 0 index
- (void) setNotation: (NSString *)newText
{
    ATRACE2(@"Clip: setNotation: texts=%p class=%@ count=%lu isKindOfClass-NSMutableArray=%d", _texts, [_texts class], (unsigned long)[_texts count], [_texts isKindOfClass:[NSMutableArray class]]);
	if (! _texts) {
		_texts = [NSMutableArray array];
	}
	else if ([_texts count] > 0) {
		[_texts replaceObjectAtIndex: 0 withObject: newText];
        ATRACE(@"Clip: setNotation: after replace texts=%p class=%@ count=%lu", _texts, [_texts class], (unsigned long)[_texts count]);
		return;
	}
	[_texts addObject: newText];
}

// ----------------------------------------------------------------------------------------------------------
// Keep only 4 decimals for start time. media player resolution.
//
#define kTimePrecisionFactor (10000.0)
- (void) setStartTime: (NSTimeInterval) newTime
{
	_startTime = trunc( newTime * kTimePrecisionFactor ) / kTimePrecisionFactor;
}

// ----------------------------------------------------------------------------------------------------------
// Create a bitmap context, caller must release
static CGContextRef MyCreateBitmapContext(int pixelsWide, int pixelsHigh)
{
	void			*data = nil;
	size_t			bitsPerComponent = 8;
	size_t			bytesPerRow = 0;
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
	// this will give us an optimal BGRA format for the device:
	CGBitmapInfo	bitmapInfo = (kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst); 
	
	CGContextRef	bitmapContext = 
	CGBitmapContextCreate( data, pixelsWide, pixelsHigh, bitsPerComponent, bytesPerRow, colorSpace, bitmapInfo);
	
	CGColorSpaceRelease(colorSpace);
	
    return bitmapContext;
}

// ----------------------------------------------------------------------------------------------------------
- (UIImage *)scaleImage: (UIImage*) inputImage width: (CGFloat)width height: (CGFloat)height
{
	ATRACE(@"Clip: scaleImage inputImage=%@ width=%f height=%f ", inputImage, width, height );
	CGRect myContextRect = CGRectMake(0, 0, width, height);
	
	// create a bitmap graphics context the size of the image
	CGContextRef context = MyCreateBitmapContext(width, height);
	
    CGImageRef cgImageRef = inputImage.CGImage;
	
	CGContextDrawImage (context, myContextRect, cgImageRef );
		
	CGImageRef bitmap = CGBitmapContextCreateImage( context);
	
	CGContextRelease( context);
	
	UIImage *theImage = [UIImage imageWithCGImage: bitmap];
	
	CGImageRelease( bitmap);
	
	return theImage;
}

// ----------------------------------------------------------------------------------------------------------
- (NSString *) imagePath
{
	return [_song pathNameForMediaFileName: _imageFileName];
}

// ----------------------------------------------------------------------------------------------------------
- (NSString *) imageCacheKey
{
	if (_imageRef)
		return _imageRef;
	// !!@ What if there is no imagePath ??
	return [self imagePath];
}

// ----------------------------------------------------------------------------------------------------------
- (NSString *) imageIconPath
{
	return [[self imagePath] stringByAppendingString: @"-icon"];
}

// ----------------------------------------------------------------------------------------------------------
- (NSString *) imageIconCacheKey
{
	return [[self imageCacheKey] stringByAppendingString: @"-icon"];
}

// ----------------------------------------------------------------------------------------------------------
- (void) removeMediaFiles
{
	NSString	*path;
	if ([_imageFileName length] > 0) {
		ATRACE(@"Clip: removeMediaFiles: deleting file=%@", [self imagePath]);
		
		[[NSFileManager defaultManager] removeItemAtPath: [self imagePath] error: NULL];
		
		[[NSFileManager defaultManager] removeItemAtPath: [self imageIconPath] error: NULL];
		
		[_song.imageCache flushForKey: [self imageCacheKey]];
		
		[_song.imageIconCache flushForKey: [self imageIconCacheKey]];
	}
	if ([_recordingFileName length] > 0) {
		path = [[_song songDirectoryPath] stringByAppendingPathComponent: _recordingFileName];
		ATRACE(@"Clip: removeMediaFiles: deleting file=%@", path);
		[[NSFileManager defaultManager] removeItemAtPath: path error: NULL];
	}
}

// ----------------------------------------------------------------------------------------------------------
- (void) saveNewImage2: (UIImage*) newImage path: (NSString	*)path cacheKey: (NSString*)cacheKey
{	
	NSData		*imageData = UIImagePNGRepresentation( newImage );
	
	ATRACE2(@"Clip: saveNewImage2: imageData=%@", imageData);
	if (! imageData) {
		ATRACE(@"Clip: saveNewImage2: UIImagePNGRepresentation failed for path=%@", path);
	}
	
	NSError *error = nil;
	[imageData writeToFile: path options: NSAtomicWrite error: &error];
	if (error) {
		// !!@ Alert needed
		ATRACE(@"Clip: saveNewImage2: error=%@ writing path=%@", [error localizedDescription], path);
	}
	
	[_song.imageCache addItem: newImage key: cacheKey];
}

// ----------------------------------------------------------------------------------------------------------
- (void) saveNewImageIcon: (UIImage*) newImage
{
	newImage = [self scaleImage: newImage width: kImageIconWidth height: kImageIconHeight];
	
	[self saveNewImage2: newImage path: [self imageIconPath] cacheKey: [self imageIconCacheKey]];
}

// ----------------------------------------------------------------------------------------------------------
// Save main image along with icon
- (void) saveNewImage: (UIImage*) newImage
{
	ATRACE(@"Clip: saveNewImage newImage=%@ width=%f height=%f ", newImage, newImage.size.width, newImage.size.height );
	CGFloat		width = kMaxImageWidth;
	CGFloat		height = kMaxImageHeight;
	CGFloat		srcWidth = newImage.size.width;
	CGFloat		srcHeight = newImage.size.height;
	
	if (srcWidth > width || srcHeight > height) {
		if (srcWidth > srcHeight && srcWidth != 0) {
			height = height * (srcHeight / srcWidth);
		}
		else if (srcHeight != 0) {
			width = width * (srcWidth / srcHeight);
		}
		newImage = [self scaleImage: newImage width: width height: height];
	}
	
	// Assign a new file name for media if not present
	if ([_imageFileName length] <= 0) {
		_imageFileName = [_song nextMediaFileName: @"image.png"];
	}
	
	// Write out image
	[self saveNewImage2: newImage path: [self imagePath] cacheKey: [self imageCacheKey]];

	[self saveNewImageIcon: newImage];
			
	[_song saveToDisk];
}

// ----------------------------------------------------------------------------------------------------------
// Request image from http addresss
- (void) reqeustImageRef
{
	if (_imageRef) {
		// We have image http reference
		if (! access) {
			ATRACE(@"Clip: requesting imageRef=%@", _imageRef);
			access = [[Access alloc] init];
			access.delegate = self;
			[access sendOp: _imageRef];
		}
	}
}

// ----------------------------------------------------------------------------------------------------------
// Lookup image in cache, if not there, create image and add it to the cache
- (UIImage*) loadImage: (NSString *)imagePath2 cacheKey: (NSString*) cacheKey cache: (Cache*) cache
{
	UIImage *anImage = [cache findItem: cacheKey];
	if (! anImage ) {
		// Is there image file on disk?
		if ([_imageFileName length] > 0) {
			anImage = [UIImage imageWithContentsOfFile: imagePath2];
			if (anImage) {
				[cache addItem: anImage key: cacheKey];
				ATRACE(@"Clip: loadImage cacheKey=%@ anImage=%@", [cacheKey lastPathComponent], anImage);
			}
			else {
				ATRACE2(@"Clip: loadImage FAILED imagePath2=%@ imageRef=%@", imagePath2, imageRef);
				AFLOG(@"Clip: loadImage FAILED imagePath2=%@ imageRef=%@", imagePath2, _imageRef);
			}
		}
		else  {
			[self reqeustImageRef];
		}
	}
	return anImage;
}

// ----------------------------------------------------------------------------------------------------------
// Load icon image
- (UIImage*) imageIcon
{
	return [self loadImage: [self imageIconPath] 
				  cacheKey: [self imageIconCacheKey] 
					 cache: _song.imageIconCache];
}

// ----------------------------------------------------------------------------------------------------------
// Load main image
- (UIImage*) image
{
	return [self loadImage: [self imagePath] 
				  cacheKey: [self imageCacheKey] 
					 cache: _song.imageCache];
}

// ----------------------------------------------------------------------------------------------------------
// Done with http request
- (void) accessDone
{
	ATRACE(@"Clip: accessDone imageRef=%@", _imageRef);
	access.delegate = nil;
	access = nil;
}

// ----------------------------------------------------------------------------------------------------------
- (void) access:(Access*)access err:(NSString*)errMsg
{
	ATRACE(@"Clip: access errMsg=%@", errMsg);
	//[AppUtil showMsg: errMsg title:@"Clip image load failed"];

	[self accessDone];
}

- (void) access:(Access*)access done:(NSData*)resultData
{
	ATRACE(@"Clip: access access done resultData len=%lu", (unsigned long)[resultData length]);
	
	// We received data for the image.
	UIImage *rawImage = [UIImage imageWithData: resultData];
	ATRACE(@"Clip: recieved rawImage=%@", rawImage);
	
	[self accessDone];

	[self saveNewImage:	rawImage];
	
	[[SongList default] reportSongChange];
}

// ----------------------------------------------------------------------------------------------------------
// ----------------------------------------------------------------------------------------------------------

@end


