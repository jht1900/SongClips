/*
 Copyright (C) 2008 John Henry Thompson. All Rights Reserved.
 */

#import <UIKit/UIKit.h>

#import "DD_Access.h"

@interface DD_AccessPostFile : DD_Access <NSStreamDelegate>
{
    
    NSURLConnection *           _connection;
    NSData *                    _bodyPrefixData;
    NSInputStream *             _fileStream;
    NSData *                    _bodySuffixData;
    NSOutputStream *            _producerStream;
    NSInputStream *             _consumerStream;
    const uint8_t *             _buffer;
    uint8_t *                   _bufferOnHeap;
    size_t                      _bufferOffset;
    size_t                      _bufferLimit;
	
	NSString					*uploadFilePath;
	NSString					*partName;
}

@property (nonatomic, strong)	NSString		*uploadFilePath;
@property (nonatomic, strong)	NSString		*partName;

- (BOOL) upLoadFile: (NSString*)filePath ;
//- (BOOL) upLoadFile: (NSString*)filePath remoteSite: (RemoteSite*)remoteSite1;

@end

// ----------------------------------------------------------------------------------------------------------
// ----------------------------------------------------------------------------------------------------------
