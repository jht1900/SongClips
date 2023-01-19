/*
 Copyright (C) 2008 John Henry Thompson. All Rights Reserved.
 */


#import "JSONKit.h"
#import "DD_AppDefs.h"
#import "UtilApp.h"

// --------------------------------------------------------------------------------------------------------
@implementation NSString (JSONKitDeserializing)

- (id)objectFromJSONString
{
	return [self objectFromJSONStringOptions: 0];
}

- (id)mutableObjectFromJSONString
{
	return [self objectFromJSONStringOptions: NSJSONReadingMutableContainers];
}

- (id)objectFromJSONStringOptions: (NSJSONReadingOptions) options
{
	NSError *err = nil;
	id dict = nil;
	// - (NSData *)dataUsingEncoding:(NSStringEncoding)encoding allowLossyConversion:(BOOL)flag
	NSData *data = [self dataUsingEncoding: NSUTF8StringEncoding];
	if (data) {
		// NSJSONReadingMutableContainers
		// + (id)JSONObjectWithData:(NSData *)data options:(NSJSONReadingOptions)opt error:(NSError **)error
		dict = [NSJSONSerialization JSONObjectWithData: data options:options error:&err];
		if (err) {
			show_alert_error(@"objectFromJSONStringOptions: err=%@ ", err);
		}
	}
	return dict;
}

@end
// --------------------------------------------------------------------------------------------------------

// --------------------------------------------------------------------------------------------------------
@implementation NSArray (JSONKitSerializing)

- (NSString *)JSONString
{
	NSError *err = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject: self options:0 error:&err];
	if (err) {
		show_alert_error(@"NSString JSONString: err=%@ ", err);
	}
	return [[NSString alloc] initWithBytes:[data bytes] length:[data length] encoding:NSUTF8StringEncoding];
}

@end
// --------------------------------------------------------------------------------------------------------

// --------------------------------------------------------------------------------------------------------
@implementation NSDictionary (JSONKitSerializing)

- (NSString *)JSONString
{
	NSError *err = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject: self options:0 error:&err];
	if (err) {
		show_alert_error(@"NSDictionary JSONString: err=%@ ", err);
	}
	return [[NSString alloc] initWithBytes:[data bytes] length:[data length] encoding:NSUTF8StringEncoding];
}

@end
// --------------------------------------------------------------------------------------------------------

// --------------------------------------------------------------------------------------------------------
// --------------------------------------------------------------------------------------------------------
