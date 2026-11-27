/*


*/

#import "AppUtil.h"
#import "AppDefs.h"

#define Minutes	(60.0)
#define Hours	(60.0*Minutes)
#define Days	(24.0*Hours)


@implementation AppUtil

// --------------------------------------------------------------------------------------------------------
+ (NSString*)formatRunningTimeUI: (double)sec
{
	if (sec < Minutes) return [AppUtil formatDoubleDuration: sec];

	int		h = sec / (60*60);
	sec -= h * 60*60;
	int		m = sec / 60.0;
	sec -= m * 60;
	
	int sec1 = sec;
	int sec2 = sec * 10;
	sec2 = sec2 % 10;
    
//    if (1)
    {
        if (h == 0) return [NSString stringWithFormat:@"%d:%02d.%01d", m, sec1, sec2];
        return [NSString stringWithFormat:@"%d:%02d:%02d.%01d", h, m, sec1, sec2];
    }
//    else
//    {
//        if (h == 0) return [NSString stringWithFormat:@"%d:%d.%d", m, sec1, sec2];
//        return [NSString stringWithFormat:@"%d:%d:%d.%d", h, m, sec1, sec2];
//    }
}

// --------------------------------------------------------------------------------------------------------
+ (NSString*)formatDurationUI: (double)sec
{
	return [AppUtil formatDoubleDuration: sec];
}

// --------------------------------------------------------------------------------------------------------
+ (NSString*)formatDurationExport: (double)sec
{
	int		h = sec / (60*60);
	sec -= h * 60*60;
	int		m = sec / 60.0;
	sec -= m * 60;
	
	int sec1 = sec;
	int sec2 = sec * 10000;
	sec2 = sec2 % 10000;
#if 1
	return [NSString stringWithFormat:@"%02d:%02d:%02d.%04d", h, m, sec1, sec2];
#else
	return [NSString stringWithFormat:@"%02d:%02d:%f", h, m, sec];
#endif
}

// ----------------------------------------------------------------------------------------------------------

+ (NSString*)formatDoubleDuration: (double)num
{
	NSString *units;
	
	if (num < Minutes)
	{
		units = @" secs";
	}
	else if (num < Hours)
	{
		num = num / Minutes;
		units = @" mins";
	}
	else if (num < Days)
	{
		num = num / Hours;
		units = @" hours";
	}
	else
	{
		num = num / Days;
		units = @" days";
	}
	return [[AppUtil formatDouble: num] stringByAppendingString: units];
}

// ----------------------------------------------------------------------------------------------------------

#define Kilo		((double)1024.0)
#define Mega		(Kilo*Kilo)
#define Giga		(Mega*Kilo)

+ (NSString*)formatDoubleBytes: (double) num
{
	NSString *units;
	if (num < Kilo)
	{
		units = @" bytes";
	}
	else if (num < Mega)
	{
		num = num / Kilo;
		units = @" KB";
	}
	else if ( num < Giga)
	{
		num = num / Mega;
		units = @" MB";
	}
	else
	{
		num = num / Giga;
		units = @" GB";
	}
	return [[AppUtil formatDouble: num] stringByAppendingString: units];
}

+ (NSString*)formatDouble: (double) numarg
{
	NSNumberFormatter *nf = [[NSNumberFormatter alloc] init];
	[nf setGroupingSize:3];
	[nf setGroupingSeparator:@","];
	[nf setUsesGroupingSeparator: YES];
	if ((SInt64)numarg != numarg)
	{
		[nf setMinimumFractionDigits: 1];
	}
	NSNumber *num = [NSNumber numberWithDouble: numarg ];
	NSString *str = [nf stringFromNumber:num];
	return str;
}

+ (NSString*)formatNumber: (SInt64) numarg
{
	NSNumberFormatter *nf = [[NSNumberFormatter alloc] init];
	[nf setGroupingSize:3];
	[nf setGroupingSeparator:@","];
	[nf setUsesGroupingSeparator: YES];
	NSNumber *num = [NSNumber numberWithLongLong: numarg ];
	NSString *str = [nf stringFromNumber:num];
	return str;
}

+ (NSString*)formatDate: (NSDate*)date
{
	NSDateFormatter *ds = [[NSDateFormatter alloc] init];
	[ds setDateStyle: NSDateFormatterMediumStyle];
	[ds setTimeStyle: NSDateFormatterMediumStyle];
	NSString* strDate = [ds stringFromDate: date];
	return strDate;
}

// ----------------------------------------------------------------------------------------------------------
+ (BOOL) isMovieExtension: (NSString *)pathExt
{
	return ([pathExt isEqualToString: @"m4v"]
			|| [pathExt isEqualToString: @"mov"]
			|| [pathExt isEqualToString: @"mp4"]
			|| [pathExt isEqualToString: @"3gp"]
			);
}

// ----------------------------------------------------------------------------------------------------------
+ (BOOL) isAudioExtension: (NSString *)pathExt
{
	return ([pathExt isEqualToString: @"mp3"]
			|| [pathExt isEqualToString: @"m4a"]	// Apple loss less
			|| [pathExt isEqualToString: @"wav"]
			|| [pathExt isEqualToString: @"aif"]
			);
}

// ----------------------------------------------------------------------------------------------------------
+ (BOOL) yesValue: (NSString*)value
{
	if ([value length] == 0) return NO;
	else return [value caseInsensitiveCompare:@"n"] != NSOrderedSame;
}

// ----------------------------------------------------------------------------------------------------------
+ (NSArray*)parseKeyValue: (NSString *)param
{
	NSString *key;
	NSString *value;
	
	NSRange rg = [param rangeOfString: @"="];
	if (rg.location != NSNotFound) 
	{
		key = [param substringToIndex: rg.location];
		value = [param substringFromIndex: rg.location+1];
		return [NSArray arrayWithObjects: key, value, nil];
	}
	else
	{
		return [NSArray array];
	}
}

// ----------------------------------------------------------------------------------------------------------
+ (int) packEncodeSecret: (NSString*) esecret
{
	int		len = (int)[esecret length];
	int		seed = 1;
	int		index;
	int		ch;
	int		shift = 0;
	
	for (index = 0; index < len; index++)
	{
		ch = [esecret characterAtIndex: index];
		seed = seed ^ (ch << shift);
		shift = (shift + 8) & 31;
	}
	ATRACE(@"AppUtil packEncodeSecret esecret=%@ seed=%x", esecret, seed);
	return seed;
}

// ----------------------------------------------------------------------------------------------------------
// Nesting level of path. "/" --> 0, "/A/" --> 1
+ (int) pathLevel: (NSString *)str
{
	NSArray *pathComponents = [str componentsSeparatedByString: @"/"];
	return (int)[pathComponents count] - 2;
}

// ----------------------------------------------------------------------------------------------------------
// Remove last directory component /A/B/C/ --> /A/B/
// OR: /A/B/i --> /A/B/
+ (NSString*) deleteLastComponentToDirectory: (NSString*)str
{
	ATRACE2(@"AppDelegate deleteLastComponentToDirectory: str=%@", str);

	NSRange range = { 0, [str length] -1 };
	NSRange r2 = [str rangeOfString:@"/" options:(NSLiteralSearch|NSBackwardsSearch) range:range];

	ATRACE2(@"AppDelegate deleteLastComponentToDirectory: r2=%d %d", r2.location, r2.length);

	if (r2.location != NSNotFound)
	{
		ATRACE2(@"AppDelegate deleteLastComponentToDirectory: return %@", [str substringToIndex:r2.location+1]);

		return [str substringToIndex:r2.location+1];
	}
	else
	{
		ATRACE2(@"AppDelegate deleteLastComponentToDirectory: NSNotFound return %@", str);

		return str;
	}
}

#if 0
// -----------------------------------------------------------------------------------------------------------------
// Return the outter directory for a path, or path it self if its a directory
// for path=/A/B/ return=/A/B/
// for path=/A/B/i return=/A/B/
+ (NSString*) deleteLastFileComponent: (NSString*)path
{
	if ([AppUtil isDirectoryPath:path])
		return path;
	return [[path stringByDeletingLastPathComponent] stringByAppendingString:@"/"];
}
#endif

// ----------------------------------------------------------------------------------------------------------
// Return YES for directory path /A/B/, 
// Return NO for file path /A/B/i
+ (BOOL) isDirectoryPath: (NSString*)str
{
	NSUInteger len = [str length];
	if (len == 0)
		return NO;
	return ([str characterAtIndex:len-1] == '/');
}

// ----------------------------------------------------------------------------------------------------------
// Remove ftp:// from string if present
+ (NSString*) removeFtpSchemeIfPresent: (NSString*)str
{
	NSRange range = {0, 6};
	
	if ([str length] < 6)
		return str;
	
	NSString* prefix = [str substringWithRange:range];
	
	if ([prefix isEqualToString: @"ftp://"]) 
	{
		str = [str substringFromIndex: range.length];
	}
	return str;
}

// ----------------------------------------------------------------------------------------------------------
// Add url scheme for ftp if not there
+ (NSString*) addFtpSchemeIfAbsent: (NSString*)str
{
	NSRange range = {0, 6};
	
	if ([str length] < 6)
		return [@"ftp://" stringByAppendingString: str];
	
	NSString* prefix = [str substringWithRange:range];
	
	if (! [prefix isEqualToString: @"ftp://"]) 
	{
		str = [@"ftp://" stringByAppendingString: str];
	}
	return str;
}

// ----------------------------------------------------------------------------------------------------------
+ (NSString*) escapeForURL: (NSString*) str
{
#if 0
	CFStringRef CFURLCreateStringByAddingPercentEscapes (
														 CFAllocatorRef allocator,
														 CFStringRef originalString,
														 CFStringRef charactersToLeaveUnescaped,
														 CFStringRef legalURLCharactersToBeEscaped,
														 CFStringEncoding encoding
														 );
#endif
	return ((NSString*) CFBridgingRelease(CFURLCreateStringByAddingPercentEscapes(
			kCFAllocatorDefault,
			(CFStringRef) str,
			(CFStringRef) @"",
			//(CFStringRef) @"@:&?%<>",
			(CFStringRef) @":&?%<>\t\n",
			CFStringConvertNSStringEncodingToEncoding( NSUTF8StringEncoding ) ))) ;
	
}

// ----------------------------------------------------------------------------------------------------------
// Escapes @ too.
+ (NSString*) escapeForPartialURL: (NSString*) str
{
#if 0
	CFStringRef CFURLCreateStringByAddingPercentEscapes (
														 CFAllocatorRef allocator,
														 CFStringRef originalString,
														 CFStringRef charactersToLeaveUnescaped,
														 CFStringRef legalURLCharactersToBeEscaped,
														 CFStringEncoding encoding
														 );
#endif
	return (NSString*) CFBridgingRelease(CFURLCreateStringByAddingPercentEscapes(
															   kCFAllocatorDefault,
															   (CFStringRef) str,
															   (CFStringRef) @"",
															   (CFStringRef) @":@/&?%<>\t\n=",
															   //(CFStringRef) @":&?%<>\t\n",
															   CFStringConvertNSStringEncodingToEncoding( NSUTF8StringEncoding ) ));
	
}

// ----------------------------------------------------------------------------------------------------------
#if 0
CFStringRef CFURLCreateStringByReplacingPercentEscapesUsingEncoding (
																	 CFAllocatorRef allocator,
																	 CFStringRef origString,
																	 CFStringRef charsToLeaveEscaped,
																	 CFStringEncoding encoding
																	 );

- (NSString *)stringByReplacingPercentEscapesUsingEncoding:(NSStringEncoding)encoding

#endif

// ----------------------------------------------------------------------------------------------------------

+ (void)showMsg: (NSString*)msg title:(NSString*)title
{    
    UIAlertView *alert = 
		[[UIAlertView alloc] initWithTitle:title 
								   message:msg 
								  delegate:nil
						 cancelButtonTitle:@"OK" 
						 otherButtonTitles:nil];
    [alert show];
}

+ (void)showErr: (NSString*)msg
{
	[self showMsg:msg title: @"Error"];
}

// ----------------------------------------------------------------------------------------------------------
// ----------------------------------------------------------------------------------------------------------

@end


// ----------------------------------------------------------------------------------------------------------
CGFloat Random1(void)
{
	return (CGFloat)random() / (CGFloat)RAND_MAX;
}


// ----------------------------------------------------------------------------------------------------------
UIColor* colorFromArray( id arr)
{
	if (! arr)
		return arr;
	
	float red = [arr[ 0] floatValue];
	float green = [arr[ 1] floatValue];
	float blue = [arr[ 2] floatValue];
	
	return [UIColor colorWithRed: red green: green  blue: blue alpha: 1.0];
}

// ----------------------------------------------------------------------------------------------------------
NSArray* colorToArray( UIColor* acolor)
{
	const CGFloat		*ccomp = CGColorGetComponents(acolor.CGColor);
	NSMutableArray		*arr = [NSMutableArray array];
	
	[arr addObject: [NSNumber numberWithFloat: ccomp[0] ]];
	[arr addObject: [NSNumber numberWithFloat: ccomp[1] ]];
	[arr addObject: [NSNumber numberWithFloat: ccomp[2] ]];
	
	return arr;
}

// ----------------------------------------------------------------------------------------------------------
// ----------------------------------------------------------------------------------------------------------

