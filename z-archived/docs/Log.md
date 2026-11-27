# SongClips Dev Log

# --
2023-01-19 11:43:06

>> Attemp to use Assets catalog - still have icons warning from app store submit

# --
2023-01-18


	[firstStopViewCtl becomeActive];
		[g_appDelegate.songListViewCtl becomeActive];

// !!@ 2023 temp

    g_appDelegate.askForSong = YES;

-------------------------------------------------------
2016-09-13 Tue

[x] source_stream

[x] clip_rate

-------------------------------------------------------
2016-09-08 Thu

- disconnect ALL devices to build for app store
- enable 'hide status bar' in General settings
- version 3.0.7 submitted to app store

[x] disable auto show of picker on launch

[x] auto hide and start

-------------------------------------------------------
2016-09-07 Wed

[x] 240fps slow motion test on iOS 5.1.1
/Users/epdev/Desktop/-songclips-dice-media/j4u2.com/songclips/songs/dice/6877-slowmo-shorter.mp4 

-------------------------------------------------------
2016-03-09

[x] Done update to ARC. 
[x] Replace UIActionSheet with JGActionSheet

-------------------------------------------------------
2016-03-07

[-] Start update to ARC

[x] Compiles with in Xcode 7.2.1, with warnings.

-------------------------------------------------------
2012-04-13

[-] SongClipsDemo prep for store
Rejected - no demos allowed.

-------------------------------------------------------
2012-03-01

[x] SongClipsDemo

http://www.ashtangayoga.info/philosophy/mantra/ashtanga-yoga-mantra/

typeo: Like a Shaman in the Jungle he brings total complete well-beeing.

-------------------------------------------------------
2012-02-25

[x] Go previous on first clip should restart

-------------------------------------------------------
2012-02-12??

[x] responsive design for http://www.j4u2.com/songclips/

-------------------------------------------------------
2012-01-17 Tue

[x] Avoid double missing-song alert on new song
MissingViewCtl alloc

[x] Touch on Song List top left gives option for songclips website

[x] Add right button to web view to open in Safari

[x] In Clip Edit on last clip, does not loop back to first clip.

-------------------------------------------------------
2012-01-14 Sat

[x] Hide Add Image: if no image source on device (iPad1)
[x] Show Add Image on iPad2
[-] Fix touch image to launch web view

-------------------------------------------------------
2012-01-10 Tue

[x] Custom Back and Edit buttons 40x40

[x] Show no-image song icon if artwork missing

[x] Show album art in song list view

[x] NO Clip Editing in SongClipLite

[x] SongCell-ipad

[x] SongClipsLite UI update

[x] Song Info:
removed "Remove All Clips"
remove Make n clips
Show album:
Show artist:

optional itune store link

Add SongClips info web site

[x] Update hilight graphics from adam

[-] Update UI: 
<[     ]>

-------------------------------------------------------
2012-01-09 Mon

-------------------------------------------------------
2012-01-05 Thur

[x] Remove Songs access from Info screen
[x] Remove Clips access from Info screen
[x] Remove Clips access form SongList

[x] Auto alloc MainViewCtl

[x] In clip edit view time line is always that of clip

[x] SongClips Lite

[x] Better docs at 

-------------------------------------------------------
2011-11-22 Tu

NS_BLOCK_ASSERTIONS

-------------------------------------------------------
2011-11-21 Mo

[x] Release 1.10 to App Store

http://www.j4u2.com/songclips/songs/Krishna-Das/Hanuman-Chaleesa-img-clips.txt

[x] Song Missing
Song:
Album:
Artist:
not found in your music library.

[ Select Alternative From Library ]
[ Search in iTunes ]
[ Continue ]

ClipView-iPad

-------------------------------------------------------
2011-11-20 Su

[x] "Click to Add Song" --> "Touch here to add song from your Music Library"

[x] Setup local svn file:///Library/Subversion/Repository/LocalStash

[x] Web: to open link in web browser

[x] Source: link to itunes file.

[x] prompt to launch source link if not in library

[x] Email header: SongClips for <title> (x clips)

-------------------------------------------------------
2011-11-19 Sa

[x] Document SongClips on www.johnhenrythompson.com
Using SongClips

[x] Rich example with http links:
Song Label: Hanuman Chaleesa (with Images)

-------------------------------------------------------
2011-11-18 Fi

[x] add the English translation under each transliteration

Tried Link: http://itunes.apple.com/us/album/breath-of-the-heart/id6804030
failed with NSURLErrorDomain -999

[x] Clean up songclip examples on j4u2.com/songclips/songs


-------------------------------------------------------
2011-11-17 Th

[x] add the English translation under each transliteration
[x] Build OTA KD Hanuman Chalisa


-------------------------------------------------------
2011-11-16 We

http://www.j4u2.com/songclips/dist/KDHChalisa.ipa

Krishn Das Hanuman Chalisa

-------------------------------------------------------
2011-11-15 Tu

Setup Nina 

songclips://www.j4u2.com/songclips/songs/Krishna-Das/Baba-Hanuman-clips.txt
songclips://www.j4u2.com/songclips/songs/Krishna-Das/Hallelujah-Chaisa-clips.txt

-------------------------------------------------------
2011-02-11

[x] Promotion code of Krishna Das
T4RALHMH4YEA
RLER4HJMWXNA

[-] deprecated in iPad: allowsImageEditing

[-] On iPad, UIImagePickerController must be presented via UIPopoverController

[x] Disable photo/camer on ipad
fCameraButton.hidden = YES;
fPhotoButton.hidden =  YES;

---------------------------------
2009-09-04 Fri

[x] Track playing Clip in SongView, show current time in [starttime] [curpos] [dur]
[x] Track playing song + clip on and main screen
[x] Copy / Paste Song Clips
[x] Full Screen text, photo behind
[x] White on black text on main screen

---------------------------------
2009-09-05 Sat

[x] Remember and restore Song and location in Song
[x] dont' reply on mediaItem change notification
[x] Remember currentPlay time as it runs
[x] use NSScanner
[x] Song user title, song.label - use in ui, export

---------------------------------
2009-09-06 Sun

[x] Allow screen rotation

---------------------------------
2009-09-07 Mon

[x] ClipView: Photo/Camera button. Save to file.
[x] SongList: Save one song per file
[x] SongView: on display scroll to playing clip
[x] Hilight current clip of Song
[x] SongList: on display, scrool to current song
[x] Hilight current song of songList
[x] Dont' restart clip if already playing: SongView --> Clip, MainView --> Clip 
[x] Info screen:  Copy/Paste/Email, scrolling for other options
[Copy]
[Paste]
[Email]
[x] Main Screen:  [Clips]  [ << ]  [>] [ >> ] [Songs] 

---------------------------------
2009-09-08 Tue

[x] MainScreen : toggle Play button
[x] SongCell: Title / album + author 
[x] Animated image change
[x] Main screen: ALbum art top left bar
[x] Main screen: Song name in title.
title / artist - album
[x] InfoScreen: email

---------------------------------
2009-09-09 Wed

[x] ClipView: Record button / Review button
[x] ClipView: track recording and playback time
[x] ClipView: save recording to file

---------------------------------
2009-09-10 Thu

[x] Main Screen: alert on copy/paste "copied/paste n clips of <title>"

---------------------------------
2009-09-20 Sun

[x] Import ref to image
[x] Multi text
[x] clip.notation --> text // array of strings

---------------------------------
2009-09-21 Mon

Image: <http ref to image>
Link: <http link for image>
Text[
]Text
Text:
If not reconized, import as text until next Clip:
Song End:

---------------------------------
2009-09-23 Wed

[x] Use ImageRef 
[x] Scale image
[x] Main: click on left top album art for Songs List
[x] Group Paste/Email/Copy
[x] Add Songs to info
[x] After paste select import song
[x] Export multi line texts
[x] Export ImageRef, LinkRef

---------------------------------
2009-09-24 Thu

[x] Image in Clip List view
[x] Clip List: cheron to get clip view, other wise just select and play clip
[x] Song List: chevron to get song view, other wise just select and play

---------------------------------
2009-09-25 Fri

[x] Memory manage image references on Clips
only keep n newest images around
Image cache, indexed by file name
[x] Image icon rep
[-] De-select before select in song view
[x] Hilight and track in clip list / song view

---------------------------------
2009-09-28 Mon

[x] Make clips
[x] Remove all clips
[x] Move Songs to info screen

---------------------------------
2009-09-30 Wed

[x] Que for Access, do one at a time

---------------------------------
2009-10-05 Mon

[x] Use LinkRef
[x] click image to bring up web view of link

---------------------------------
2009-10-07 Wed

[x] j4u2.com/songclips/
[x] Loop song on main screen
[x] Loop clip on main screen
[x] Scrubber for song time on main screen
clip loop --> clip duration
else song duration
[x] MainScreen: when paused, next/prev  should update notes/images
[x] When song stops playing, does not jump to consistent time
[x] [Loop] -Loop-
[x] Trunc clip start time to 4 decimal places
[x] HIDE record button/ review 

[x] Delete song should clear media item if playing

---------------------------------
2009-10-11 Sun

[x] songclips:// pull down form web
[x] Protect from no camera
[x] Delete song should clear save song position

---------------------------------
2009-11-10 Tue -- Post 1.0

[x]CRASH podcast not installed.
[x] Include podcasts

---------------------------------
2009-11-11 Wed

[x] reset currentTime when new song selected
[x] If no media item, playback continues on old media item
[x] delete song, song continues to playing
[x] [clip n of m] [x sec]	[song dur] (when not looped)
[x] After Song delete: select next song

---------------------------------
2009-11-12 Thu

[x] Delete song should reset currentSongIndex
[x] dead link: www.geocities.com

---------------------------------
2009-11-25 Wed

---------------------------------
2009-11-30 Mon

[x] missingMediaPlaying handling
[x] Use timer to simulate playing of not found media
[x] Test for null playing item. 
nowPlayingItem
handle_NowPlayingItemChanged
handle_PlaybackStateChanged
clipStartTime

---------------------------------
---------------------------------

