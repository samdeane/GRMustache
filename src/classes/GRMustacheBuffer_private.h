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

#import <Foundation/Foundation.h>
#import "GRMustacheAvailabilityMacros_private.h"
#import "GRMustacheConfiguration_private.h"

typedef NS_ENUM(NSInteger, GRMustacheBufferInputType) {
    GRMustacheBufferInputTypeStrippableContent,
    GRMustacheBufferInputTypeContent,
    GRMustacheBufferInputTypeContentEndOfLine,
    GRMustacheBufferInputTypeBlank,
    GRMustacheBufferInputTypeBlankEndOfLine,
};

/**
 * TODO
 */
@interface GRMustacheBuffer : NSObject {
@private
    GRMustacheContentType _contentType;
    NSString *_prefix;
    BOOL _atLineStart;
}

/**
 * TODO
 */
@property (nonatomic, readonly) GRMustacheContentType contentType;

/**
 * TODO
 */
+ (instancetype)bufferWithContentType:(GRMustacheContentType)contentType outputString:(NSMutableString *)outputString GRMUSTACHE_API_INTERNAL;

/**
 * TODO
 */
+ (instancetype)bufferWithContentType:(GRMustacheContentType)contentType outputBuffer:(GRMustacheBuffer *)outputBuffer GRMUSTACHE_API_INTERNAL;

/**
 * TODO
 */
- (NSString *)appendString:(NSString *)string contentType:(GRMustacheContentType)contentType inputType:(GRMustacheBufferInputType)inputType GRMUSTACHE_API_INTERNAL;

/**
 * TODO
 */
- (void)flush GRMUSTACHE_API_INTERNAL;

@end
