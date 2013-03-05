// The MIT License
//
// Copyright (c) 2013 Gwendal Roué
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import "GRMustacheBuffer_private.h"
#import "GRMustache_private.h"

// =============================================================================
#pragma mark - Private concrete class GRMustacheStringBuffer

/**
 * TODO
 */
@interface GRMustacheStringBuffer : GRMustacheBuffer {
@private
    NSMutableString *_outputString;
}
- (instancetype)initWithContentType:(GRMustacheContentType)contentType outputString:(NSMutableString *)outputString;
@end

// =============================================================================
#pragma mark - Private concrete class GRMustacheBufferBuffer

/**
 * TODO
 */
@interface GRMustacheBufferBuffer : GRMustacheBuffer {
@private
    GRMustacheBuffer *_outputBuffer;
}
- (instancetype)initWithContentType:(GRMustacheContentType)contentType outputBuffer:(GRMustacheBuffer *)outputBuffer;
@end

// =============================================================================
#pragma mark - Abstract class GRMustacheBuffer

@interface GRMustacheBuffer()
@property (nonatomic, retain) NSString *prefix;
- (id)initWithContentType:(GRMustacheContentType)contentType;
- (void)appendSafeString:(NSString *)string inputType:(GRMustacheBufferInputType)inputType;
@end

@implementation GRMustacheBuffer
@synthesize contentType=_contentType;
@synthesize prefix=_prefix;

+ (instancetype)bufferWithContentType:(GRMustacheContentType)contentType outputString:(NSMutableString *)outputString
{
    return [[[GRMustacheStringBuffer alloc] initWithContentType:contentType outputString:outputString] autorelease];
}

+ (instancetype)bufferWithContentType:(GRMustacheContentType)contentType outputBuffer:(GRMustacheBuffer *)outputBuffer
{
    return [[[GRMustacheBufferBuffer alloc] initWithContentType:contentType outputBuffer:outputBuffer] autorelease];
}

- (void)dealloc
{
    [super dealloc];
}

- (id)initWithContentType:(GRMustacheContentType)contentType
{
    self = [super init];
    if (self) {
        _contentType = contentType;
        _swallowsBlankEndOfLine = YES;
    }
    return self;
}

- (NSString *)appendString:(NSString *)string contentType:(GRMustacheContentType)contentType inputType:(GRMustacheBufferInputType)inputType
{
    if (string == nil) {
        string = @"";
    }
    if (_contentType == GRMustacheContentTypeHTML && contentType != GRMustacheContentTypeHTML) {
        string = [GRMustache escapeHTML:string];
    }
    
    switch (inputType) {
        case GRMustacheBufferInputTypeContent:
            if (string.length > 0) {
                if (self.prefix) {
                    if (_needsPrefixPrepending) {
                        [self appendSafeString:self.prefix inputType:GRMustacheBufferInputTypeBlankPrefix];
                        _needsPrefixPrepending = NO;
                    } else {
                        // noop for breakpoing
                        _needsPrefixPrepending = NO;
                    }
                    self.prefix = nil;
                }
                _swallowsBlankEndOfLine = NO;
                [self appendSafeString:string inputType:inputType];
                return string;
            } else {
                return @"";
            }
            break;
            
        case GRMustacheBufferInputTypeContentEndOfLine:
            if (self.prefix) {
                if (_needsPrefixPrepending) {
                    [self appendSafeString:self.prefix inputType:GRMustacheBufferInputTypeBlankPrefix];
                    _needsPrefixPrepending = NO;
                } else {
                    // noop for breakpoing
                    _needsPrefixPrepending = NO;
                }
                self.prefix = nil;
            }
            _swallowsBlankEndOfLine = YES;
            [self appendSafeString:string inputType:inputType];
            return string;
            break;
            
        case GRMustacheBufferInputTypeBlankLine:
            self.prefix = nil;
            _needsPrefixPrepending = NO;
            _swallowsBlankEndOfLine = YES;
            [self appendSafeString:string inputType:inputType];
            return string;
            break;
            
        case GRMustacheBufferInputTypeBlankEndOfLine:
            if (_swallowsBlankEndOfLine) {
                _needsPrefixPrepending = NO;
                return @"";
            } else {
                _swallowsBlankEndOfLine = YES;
                [self appendSafeString:string inputType:inputType];
                return string;
            }
            break;
            
        case GRMustacheBufferInputTypeBlankPrefix:
            self.prefix = string;
            _swallowsBlankEndOfLine = YES;
            _needsPrefixPrepending = YES;
            return string;
            break;
            
        case GRMustacheBufferInputTypeBlankSuffix:
            if (_swallowsBlankEndOfLine) {
                _needsPrefixPrepending = NO;
                return @"";
            } else {
                [self appendSafeString:string inputType:inputType];
                return string;
            }
            break;
    }
}

- (void)appendSafeString:(NSString *)string inputType:(GRMustacheBufferInputType)inputType
{
    NSAssert(NO, @"Subclasses must override");
}

@end


// =============================================================================
#pragma mark - Private concrete class GRMustacheStringBuffer

@implementation GRMustacheStringBuffer

- (void)dealloc
{
    [_outputString release];
    [super dealloc];
}

- (instancetype)initWithContentType:(GRMustacheContentType)contentType outputString:(NSMutableString *)outputString
{
    self = [super initWithContentType:contentType];
    if (self) {
        _outputString = [outputString retain];
    }
    return self;
}

- (void)appendSafeString:(NSString *)string inputType:(GRMustacheBufferInputType)inputType
{
    [_outputString appendString:string];
}

@end


// =============================================================================
#pragma mark - Private concrete class GRMustacheBufferBuffer

@implementation GRMustacheBufferBuffer

- (void)dealloc
{
    [_outputBuffer release];
    [super dealloc];
}

- (instancetype)initWithContentType:(GRMustacheContentType)contentType outputBuffer:(GRMustacheBuffer *)outputBuffer
{
    self = [super initWithContentType:contentType];
    if (self) {
        _outputBuffer = [outputBuffer retain];
    }
    return self;
}


- (void)appendSafeString:(NSString *)string inputType:(GRMustacheBufferInputType)inputType
{
    [_outputBuffer appendString:string contentType:self.contentType inputType:inputType];
}

@end
