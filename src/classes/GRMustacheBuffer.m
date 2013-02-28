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

@interface GRMustacheBuffer()
@property (nonatomic, readonly) GRMustacheContentType contentType;
@property (nonatomic, retain, readonly) NSString *string;
- (id)initWithContentType:(GRMustacheContentType)contentType;
@end

@implementation GRMustacheBuffer
@synthesize contentType=_contentType;
@synthesize string=_string;

+ (instancetype)bufferWithContentType:(GRMustacheContentType)contentType
{
    return [[[GRMustacheBuffer alloc] initWithContentType:contentType] autorelease];
}

- (void)dealloc
{
    [_string release];
    [super dealloc];
}

- (id)initWithContentType:(GRMustacheContentType)contentType
{
    self = [super init];
    if (self) {
        _string = [[NSMutableString alloc] init];
        _contentType = contentType;
    }
    return self;
}

- (NSString *)stringHTMLSafe:(BOOL *)HTMLSafe
{
    if (HTMLSafe != NULL) {
        *HTMLSafe = (_contentType == GRMustacheContentTypeHTML);
    }
    return [[_string retain] autorelease];
}

- (void)appendString:(NSString *)string contentType:(GRMustacheContentType)contentType blank:(BOOL)blank prefix:(BOOL)prefix suffix:(BOOL)suffix
{
    if (string == nil) return;
    if (_contentType == GRMustacheContentTypeHTML && contentType != GRMustacheContentTypeHTML) {
        string = [GRMustache escapeHTML:string];
    }
    [_string appendString:string];
}

- (NSString *)appendRendering:(NSString *)string contentType:(GRMustacheContentType)contentType
{
    if (string == nil) return @"";
    if (_contentType == GRMustacheContentTypeHTML && contentType != GRMustacheContentTypeHTML) {
        string = [GRMustache escapeHTML:string];
    }
    [_string appendString:string];
    return string;
}

@end
