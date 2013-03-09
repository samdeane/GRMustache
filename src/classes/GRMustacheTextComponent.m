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

#import "GRMustacheTextComponent_private.h"
#import "GRMustacheBuffer_private.h"


@interface GRMustacheTextComponent()
@property (nonatomic, retain) NSString *string;
- (id)initWithString:(NSString *)string inputType:(GRMustacheBufferInputType)inputType;
@end


@implementation GRMustacheTextComponent
@synthesize string=_string;

+ (instancetype)textComponentWithString:(NSString *)string inputType:(GRMustacheBufferInputType)inputType
{
    return [[[self alloc] initWithString:string inputType:inputType] autorelease];
}

- (void)dealloc
{
    [_string release];
    [super dealloc];
}

#pragma mark <GRMustacheTemplateComponent>

- (BOOL)renderContentType:(GRMustacheContentType)requiredContentType inBuffer:(GRMustacheBuffer *)buffer withContext:(GRMustacheContext *)context error:(NSError **)error
{
    [buffer appendString:_string contentType:requiredContentType inputType:_inputType];
    return YES;
}

- (id<GRMustacheTemplateComponent>)resolveTemplateComponent:(id<GRMustacheTemplateComponent>)component
{
    // text components can not override any other component
    return component;
}

#pragma mark Private

- (id)initWithString:(NSString *)string inputType:(GRMustacheBufferInputType)inputType
{
    NSAssert(string, @"WTF expected string");
    self = [self init];
    if (self) {
        self.string = string;
        _inputType = inputType;
    }
    return self;
}

@end
