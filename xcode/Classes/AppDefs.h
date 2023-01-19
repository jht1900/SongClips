/*
 Replay
 
 Copyright (C) 2009-2016 John Henry Thompson.

*/

#define APP_TRACE				1
#define APP_LOG					1

#define APP_DD_TEST				0

#define APP_FULL_NOTATION       1

#define APP_ACTIONSHEET_ANIM    1

#define kSongClipsWebSite		@"http://www.j4u2.com/songclips"

#define kSongClipsAppRef		@"http://itunes.apple.com/us/app/songclips/id335528135?mt=8"

#define K_dsite_uname			@"art"
#define K_dsite_pword			@"media201610"
#define K_dsite_realm			@"dice"


// --------------------------------------------------------------------------------------------------------
#define kPLAYER_TYPE_PREF_KEY @"player_type_preference"

// --------------------------------------------------------------------------------------------------------

#if APP_TRACE
#define ATRACE(...) NSLog(__VA_ARGS__)
#else
#define ATRACE(...)
#endif

#define ATRACE2(...) 

#if APP_LOG
//#define AFLOG(...) flog(__VA_ARGS__)
#define AFLOG(...) NSLog(__VA_ARGS__)
#else
#define AFLOG(...) 
#endif

// --------------------------------------------------------------------------------------------------------
#define kOurScheme				@"songclips://"
#define kOurScheme2				@"songclips:"

// --------------------------------------------------------------------------------------------------------

#define kSongListKey		@"kSongListKey"
//#define kSongIdKey			@"kSongIdKey"

#define kSongCurrentIndexKey	@"kSongCurrentIndexKey"
#define kSongCurrentTimeKey		@"kSongCurrentTimeKey"
#define kSongPlayModeKey		@"kSongPlayModeKey"

#define kAppExporterName		@"SongClipper"

// --------------------------------------------------------------------------------------------------------

// File to store SongList 

#define kAppPlistFileName	@"app.plist"

#define kSongFileNameArrayKey	@"kSongFileNameArrayKey"
#define kNextSongIDKey			@"kNextSongIDKey"

#define kSongPlistFileName	@"song.plist"

#define K_song_media_file_prefix	@"media-"

// --------------------------------------------------------------------------------------------------------

#define kMaxImageWidth			400.0
#define kMaxImageHeight			400.0

#define kImageIconWidth			32.0
#define kImageIconHeight		32.0

#define kMaxCacheImage			5
#define kMaxCacheImageIcon		100

// --------------------------------------------------------------------------------------------------------
// --------------------------------------------------------------------------------------------------------
