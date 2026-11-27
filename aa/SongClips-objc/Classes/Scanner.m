/*
 Copyright (C) 2008 John Henry Thompson. All Rights Reserved.
 */

#import "Scanner.h"
#import	"AppDefs.h"

@implementation Scanner

//@synthesize line;

// ------------------------------------------------------------------------------------
- (void)dealloc
{
	ATRACE2(@"Scanner: dealloc");
}

// ------------------------------------------------------------------------------------
+ (Scanner*) scannerWithString: str
{
	ATRACE2(@"Scanner: scannerWithString str len=%d", [str length]);
	
	Scanner *sel = [[Scanner alloc] init];
	if (sel) {
		sel->scanner = [NSScanner scannerWithString: str];
		sel->nlcs = [NSCharacterSet newlineCharacterSet];
		sel->emptycs =  [NSCharacterSet characterSetWithCharactersInString: @""];
	}
	return sel;
}

// ------------------------------------------------------------------------------------
// Return YES if non-empty contents of next line in scream
- (BOOL) nextLine
{
	ATRACE2(@"Scanner nextLine");
	line = nil;
    NSString *aline;
	BOOL ok = [scanner scanUpToCharactersFromSet: nlcs intoString:&aline];
    line = aline;
    return ok;
}

// ------------------------------------------------------------------------------------
// Return YES if str has prefix pref and put the remainder in pstr
- (BOOL) hasPrefix: (NSString*) pref toString: (NSString **)pstr
{
	ATRACE2(@"Scanner hasPrefix: pref=%@ line=%@", pref, line);
	if (! [line hasPrefix: pref]) {
		return NO;
	}
	*pstr = [[line substringFromIndex: [pref length]] stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceCharacterSet]];
	ATRACE2(@"hasPrefix:  FOUND %@ =%@", pref, *pstr);
	return YES;
}

// ------------------------------------------------------------------------------------
// Return YES if str has prefix pref and put the time code hh:mm:ss format duration in pdur
- (BOOL) hasPrefix: (NSString*) pref toFloatDuration: (NSTimeInterval *)pdur
{
	NSString *tmp = nil;
	
	if (! [self hasPrefix: pref toString: &tmp])
		return NO;
	NSArray *digits = [tmp componentsSeparatedByString: @":"];
	switch ([digits count]) {
		case 3:
			*pdur = [digits[0] floatValue] * (60 * 60) // hours
				+ [digits[1] floatValue] * 60 // min
				+ [digits[2] floatValue]; // sec;
			break;
		case 2:
			*pdur = [digits[1] floatValue] * 60 // min
				+ [digits[0] floatValue]; // sec
			break;
		case 1:
			*pdur = [digits[0] floatValue]; // sec
			break;
		default:
			ATRACE2(@"Scanner: hasPrefix:toFloatDuration BAD DURATION FORMAT %@", line);
			return NO;
			break;
	}
	return YES;
}

// ------------------------------------------------------------------------------------
// Parse integer value
- (BOOL) hasPrefix: (NSString*) pref toInt: (int *)pint
{
	NSString *tmp = nil;

	if (! [self hasPrefix: pref toString: &tmp])
		return NO;
	*pint = [tmp intValue];
	return YES;
}

// ------------------------------------------------------------------------------------
- (NSString*) textUpTo: (NSString *) endTag
{
	ATRACE(@"Scanner textUpTo endTag=%@ [scanner scanLocation]=%lu end=%d", endTag, (unsigned long)[scanner scanLocation], [scanner isAtEnd]);
	NSString	*text = @"";
	
	[scanner setCharactersToBeSkipped: emptycs];
	
	// Advance past prior newline
	if ([scanner isAtEnd])
		return text;
	[scanner setScanLocation: [scanner scanLocation] + 1];
	
	// Must include newline in ending Clip: search
	if ([scanner scanUpToString: endTag intoString:&text]) {
		// Possition to end of line of end tag
		if (! [scanner isAtEnd]) {
			[scanner setScanLocation: [scanner scanLocation] + 1];
			NSString *tmp;
			[scanner scanUpToCharactersFromSet: nlcs intoString:&tmp];
		}
	}
	[scanner setCharactersToBeSkipped: [NSCharacterSet whitespaceAndNewlineCharacterSet]];
	ATRACE2(@"Scanner textUpTo text=%@", text);

	return text;
}

// ------------------------------------------------------------------------------------
- (BOOL) hasTextBlockPrefix: (NSString*) tag toArray: (NSMutableArray*)array
{
	ATRACE2(@"Scanner hasTextBlockPrefix tag=%@", tag);
	NSString *textOneLineBegin = [tag stringByAppendingString: @":"];
	NSString *textMultiLineBegin = [tag stringByAppendingString: @"["];
	NSString *tmp;
	
	if ([self hasPrefix: textOneLineBegin toString: &tmp]) {
	}
	else if ([self hasPrefix: textMultiLineBegin toString: &tmp]) {
		NSString *endTag = [NSString stringWithFormat:@"\n]%@", tag];
		tmp = [self textUpTo: endTag];
	}
	else {
		return NO;
	}
	[array addObject: tmp];
	return YES;
}

// ------------------------------------------------------------------------------------
- (BOOL) isAtEnd
{
	return [scanner isAtEnd];
}

// ------------------------------------------------------------------------------------
- (NSString*) line
{
	return line;
}

// ------------------------------------------------------------------------------------
// ------------------------------------------------------------------------------------

@end


