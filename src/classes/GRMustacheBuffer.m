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
@property (nonatomic, readonly) GRMustacheContentType contentType;
- (id)initWithContentType:(GRMustacheContentType)contentType;
- (void)appendSafeString:(NSString *)string blank:(BOOL)blank prefix:(BOOL)prefix suffix:(BOOL)suffix;
- (NSString *)appendSafeRendering:(NSString *)string;
@end

@implementation GRMustacheBuffer
@synthesize contentType=_contentType;

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
    }
    return self;
}

- (void)appendString:(NSString *)string contentType:(GRMustacheContentType)contentType blank:(BOOL)blank prefix:(BOOL)prefix suffix:(BOOL)suffix
{
    if (string == nil) return;
    if (_contentType == GRMustacheContentTypeHTML && contentType != GRMustacheContentTypeHTML) {
        string = [GRMustache escapeHTML:string];
    }
    
    [self appendSafeString:string blank:blank prefix:prefix suffix:suffix];
}

- (NSString *)appendRendering:(NSString *)string contentType:(GRMustacheContentType)contentType
{
    if (string == nil) return @"";
    if (_contentType == GRMustacheContentTypeHTML && contentType != GRMustacheContentTypeHTML) {
        string = [GRMustache escapeHTML:string];
    }
    
    return [self appendSafeRendering:string];
}

- (void)flush
{
    
}

- (void)appendSafeString:(NSString *)string blank:(BOOL)blank prefix:(BOOL)prefix suffix:(BOOL)suffix
{
    NSAssert(NO, @"Subclasses must override");
}

- (NSString *)appendSafeRendering:(NSString *)string
{
    NSAssert(NO, @"Subclasses must override");
    return nil;
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

- (void)appendSafeString:(NSString *)string blank:(BOOL)blank prefix:(BOOL)prefix suffix:(BOOL)suffix
{
    [_outputString appendString:string];
}

- (NSString *)appendSafeRendering:(NSString *)string
{
    [_outputString appendString:string];
    return string;
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


- (void)appendSafeString:(NSString *)string blank:(BOOL)blank prefix:(BOOL)prefix suffix:(BOOL)suffix
{
    [_outputBuffer appendString:string contentType:self.contentType blank:blank prefix:prefix suffix:suffix];
}

- (NSString *)appendSafeRendering:(NSString *)string
{
    return [_outputBuffer appendRendering:string contentType:self.contentType];
}

@end
