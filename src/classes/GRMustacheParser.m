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

#import "GRMustacheParser_private.h"
#import "GRMustacheConfiguration_private.h"
#import "GRMustacheError.h"
#import "GRMustacheFilteredExpression_private.h"
#import "GRMustacheIdentifierExpression_private.h"
#import "GRMustacheImplicitIteratorExpression_private.h"
#import "GRMustacheScopedExpression_private.h"

@interface GRMustacheParser()

/**
 * The Mustache tag opening delimiter.
 */
@property (nonatomic, copy) NSString *tagStartDelimiter;

/**
 * The Mustache tag opening delimiter.
 */
@property (nonatomic, copy) NSString *tagEndDelimiter;

// Documented in GRMustacheParser_private.h
@property (nonatomic, strong) NSMutableSet *pragmas;

/**
 * Wrapper around the delegate's `parser:shouldContinueAfterParsingToken:`
 * method.
 */
- (BOOL)shouldContinueAfterParsingToken:(GRMustacheToken *)token;

/**
 * Wrapper around the delegate's `parser:didFailWithError:` method.
 * 
 * @param line          The line at which the error occurred.
 * @param description   A human-readable error message
 * @param templateID    A template ID (see GRMustacheTemplateRepository)
 */
- (void)failWithParseErrorAtLine:(NSInteger)line description:(NSString *)description templateID:(id)templateID;

@end

@implementation GRMustacheParser
@synthesize delegate=_delegate;
@synthesize tagStartDelimiter=_tagStartDelimiter;
@synthesize tagEndDelimiter=_tagEndDelimiter;
@synthesize pragmas=_pragmas;

- (id)initWithConfiguration:(GRMustacheConfiguration *)configuration
{
    self = [super init];
    if (self) {
        self.tagStartDelimiter = configuration.tagStartDelimiter;
        self.tagEndDelimiter = configuration.tagEndDelimiter;
    }
    return self;
}

- (void)dealloc
{
    [_tagStartDelimiter release];
    [_tagEndDelimiter release];
    [_pragmas release];
    [super dealloc];
}

- (void)parseTemplateString:(NSString *)templateString templateID:(id)templateID
{
    // Extract characters
    
    NSUInteger length = [templateString length];
    const UniChar *characters = CFStringGetCharactersPtr((CFStringRef)templateString);
    if (!characters) {
        NSMutableData *data = [NSMutableData dataWithLength:length * sizeof(UniChar)];
        [templateString getCharacters:[data mutableBytes] range:(NSRange){ .location = 0, .length = length }];
        characters = [data bytes];
    }
    
    // state machine internal states
    enum {
        stateStart,
        stateSpaceRun,
        stateContent,
        stateTag,
        stateUnescapedTag,
    } state = stateStart;
    
    NSString *unescapedTagStartDelimiter = [NSString stringWithFormat:@"%@{", self.tagStartDelimiter];
    NSString *unescapedTagEndDelimiter = [NSString stringWithFormat:@"}%@", self.tagEndDelimiter];

    UniChar tagStartDelimiterCharacter = [self.tagStartDelimiter characterAtIndex:0];
    NSUInteger tagStartDelimiterLength = self.tagStartDelimiter.length;
    UniChar tagEndDelimiterCharacter = [self.tagEndDelimiter characterAtIndex:0];
    NSUInteger tagEndDelimiterLength = self.tagEndDelimiter.length;
    
    UniChar unescapedTagStartDelimiterCharacter = [unescapedTagStartDelimiter characterAtIndex:0];
    NSUInteger unescapedTagStartDelimiterLength = unescapedTagStartDelimiter.length;
    UniChar unescapedTagEndDelimiterCharacter = [unescapedTagEndDelimiter characterAtIndex:0];
    NSUInteger unescapedTagEndDelimiterLength = unescapedTagEndDelimiter.length;
    
    NSCharacterSet *whitespaceCharacterSet = [NSCharacterSet whitespaceAndNewlineCharacterSet];
    GRMustacheToken *lastToken = nil;
    NSUInteger start = 0;
    NSUInteger lineStart = 0;
    NSUInteger i = 0;
    NSUInteger line = 1;
    for (; i<length; ++i) {
        UniChar c = characters[i];
        switch (state) {
            case stateStart: {
                if (c == ' ' || c == '\t')
                {
                    start = i;
                    state = stateSpaceRun;
                }
                else if (c == '\n')
                {
                    if (lineStart == start) {
                        // Blank line
                        // Blank lines do not coalesce: consume last token.
                        if (lastToken) {
                            if (![self.delegate parser:self shouldContinueAfterParsingToken:lastToken]) return;
                            lastToken = nil;
                        }
                        GRMustacheToken *token = [GRMustacheToken tokenWithType:GRMustacheTokenTypeBlankLine
                                                                 templateString:templateString
                                                                     templateID:templateID
                                                                           line:line
                                                                          range:(NSRange){ .location = lineStart, .length = (i+1)-lineStart}];
                        if (![self.delegate parser:self shouldContinueAfterParsingToken:token]) return;
                    } else {
                        // Blank end of line
                        // Blank end of line do not coalesce: consume last token.
                        if (lastToken) {
                            if (![self.delegate parser:self shouldContinueAfterParsingToken:lastToken]) return;
                            lastToken = nil;
                        }
                        GRMustacheToken *token = [GRMustacheToken tokenWithType:GRMustacheTokenTypeBlankEndOfLine
                                                                 templateString:templateString
                                                                     templateID:templateID
                                                                           line:line
                                                                          range:(NSRange){ .location = start, .length = (i+1)-start}];
                        if (![self.delegate parser:self shouldContinueAfterParsingToken:token]) return;
                    }
                    ++line;
                    lineStart = start = i + 1;
                    state = stateStart;
                }
                else if (c == unescapedTagStartDelimiterCharacter && (i+unescapedTagStartDelimiterLength <= length) && [[templateString substringWithRange:NSMakeRange(i, unescapedTagStartDelimiterLength)] isEqualToString:unescapedTagStartDelimiter])
                {
                    start = i;
                    state = stateUnescapedTag;
                    i += unescapedTagStartDelimiterLength - 1;
                }
                else if (c == tagStartDelimiterCharacter && (i+tagStartDelimiterLength <= length) && [[templateString substringWithRange:NSMakeRange(i, tagStartDelimiterLength)] isEqualToString:self.tagStartDelimiter])
                {
                    start = i;
                    state = stateTag;
                    i += tagStartDelimiterLength - 1;
                }
                else
                {
                    start = i;
                    state = stateContent;
                }
            } break;
                
            case stateSpaceRun: {
                if (c == ' ' || c == '\t')
                {
                }
                else if (c == '\n')
                {
                    if (lineStart == start) {
                        // Blank line
                        // Blank lines do not coalesce: consume last token.
                        if (lastToken) {
                            if (![self.delegate parser:self shouldContinueAfterParsingToken:lastToken]) return;
                            lastToken = nil;
                        }
                        GRMustacheToken *token = [GRMustacheToken tokenWithType:GRMustacheTokenTypeBlankLine
                                                                 templateString:templateString
                                                                     templateID:templateID
                                                                           line:line
                                                                          range:(NSRange){ .location = lineStart, .length = (i+1)-lineStart}];
                        if (![self.delegate parser:self shouldContinueAfterParsingToken:token]) return;
                    } else {
                        // Blank end of line
                        // Blank end of line do not coalesce: consume last token.
                        if (lastToken) {
                            if (![self.delegate parser:self shouldContinueAfterParsingToken:lastToken]) return;
                            lastToken = nil;
                        }
                        GRMustacheToken *token = [GRMustacheToken tokenWithType:GRMustacheTokenTypeBlankEndOfLine
                                                                 templateString:templateString
                                                                     templateID:templateID
                                                                           line:line
                                                                          range:(NSRange){ .location = start, .length = (i+1)-start}];
                        if (![self.delegate parser:self shouldContinueAfterParsingToken:token]) return;
                    }
                    ++line;
                    lineStart = start = i + 1;
                    state = stateStart;
                }
                else if (c == unescapedTagStartDelimiterCharacter && (i+unescapedTagStartDelimiterLength <= length) && [[templateString substringWithRange:NSMakeRange(i, unescapedTagStartDelimiterLength)] isEqualToString:unescapedTagStartDelimiter])
                {
                    if (start != i) {
                        if (lineStart == start) {
                            // Blank prefix
                            // Blank prefix do not coalesce: consume last token.
                            if (lastToken) {
                                if (![self.delegate parser:self shouldContinueAfterParsingToken:lastToken]) return;
                                lastToken = nil;
                            }
                            GRMustacheToken *token = [GRMustacheToken tokenWithType:GRMustacheTokenTypeBlankPrefix
                                                                     templateString:templateString
                                                                         templateID:templateID
                                                                               line:line
                                                                              range:(NSRange){ .location = start, .length = i-start}];
                            if (![self.delegate parser:self shouldContinueAfterParsingToken:token]) return;
                        } else {
                            // Content
                            // Content coalesce
                            if (lastToken) {
                                if (lastToken.type == GRMustacheTokenTypeContent) {
                                    lastToken.range = (NSRange){ .location = lastToken.range.location, .length = i-lastToken.range.location };
                                } else {
                                    if (![self.delegate parser:self shouldContinueAfterParsingToken:lastToken]) return;
                                }
                            } else {
                                lastToken = [GRMustacheToken tokenWithType:GRMustacheTokenTypeContent
                                                            templateString:templateString
                                                                templateID:templateID
                                                                      line:line
                                                                     range:(NSRange){ .location = start, .length = i-start}];
                            }
                        }
                    }
                    start = i;
                    state = stateUnescapedTag;
                    i += unescapedTagStartDelimiterLength - 1;
                }
                else if (c == tagStartDelimiterCharacter && (i+tagStartDelimiterLength <= length) && [[templateString substringWithRange:NSMakeRange(i, tagStartDelimiterLength)] isEqualToString:self.tagStartDelimiter])
                {
                    if (start != i) {
                        if (lineStart == start) {
                            // Blank prefix
                            // Blank prefix do not coalesce: consume last token.
                            if (lastToken) {
                                if (![self.delegate parser:self shouldContinueAfterParsingToken:lastToken]) return;
                                lastToken = nil;
                            }
                            GRMustacheToken *token = [GRMustacheToken tokenWithType:GRMustacheTokenTypeBlankPrefix
                                                                     templateString:templateString
                                                                         templateID:templateID
                                                                               line:line
                                                                              range:(NSRange){ .location = start, .length = i-start}];
                            if (![self.delegate parser:self shouldContinueAfterParsingToken:token]) return;
                        } else {
                            // Content
                            // Content coalesce
                            if (lastToken) {
                                if (lastToken.type == GRMustacheTokenTypeContent) {
                                    lastToken.range = (NSRange){ .location = lastToken.range.location, .length = i-lastToken.range.location };
                                } else {
                                    if (![self.delegate parser:self shouldContinueAfterParsingToken:lastToken]) return;
                                }
                            } else {
                                lastToken = [GRMustacheToken tokenWithType:GRMustacheTokenTypeContent
                                                            templateString:templateString
                                                                templateID:templateID
                                                                      line:line
                                                                     range:(NSRange){ .location = start, .length = i-start}];
                            }
                        }
                    }
                    start = i;
                    state = stateTag;
                    i += tagStartDelimiterLength - 1;
                }
                else
                {
                    state = stateContent;
                }
            } break;
                
            case stateContent: {
                if (c == '\n')
                {
                    if (start != (i+1)) {
                        // Content
                        // Content coalesce
                        if (lastToken) {
                            if (lastToken.type == GRMustacheTokenTypeContent) {
                                lastToken.range = (NSRange){ .location = lastToken.range.location, .length = (i+1)-lastToken.range.location };
                            } else {
                                if (![self.delegate parser:self shouldContinueAfterParsingToken:lastToken]) return;
                            }
                        } else {
                            lastToken = [GRMustacheToken tokenWithType:GRMustacheTokenTypeContent
                                                        templateString:templateString
                                                            templateID:templateID
                                                                  line:line
                                                                 range:(NSRange){ .location = start, .length = (i+1)-start}];
                        }
                    }
                    ++line;
                    lineStart = start = i + 1;
                    state = stateStart;
                }
                else if (c == unescapedTagStartDelimiterCharacter && (i+unescapedTagStartDelimiterLength <= length) && [[templateString substringWithRange:NSMakeRange(i, unescapedTagStartDelimiterLength)] isEqualToString:unescapedTagStartDelimiter])
                {
                    if (start != i) {
                        // Content
                        // Content coalesce
                        if (lastToken) {
                            if (lastToken.type == GRMustacheTokenTypeContent) {
                                lastToken.range = (NSRange){ .location = lastToken.range.location, .length = i-lastToken.range.location };
                            } else {
                                if (![self.delegate parser:self shouldContinueAfterParsingToken:lastToken]) return;
                            }
                        } else {
                            lastToken = [GRMustacheToken tokenWithType:GRMustacheTokenTypeContent
                                                        templateString:templateString
                                                            templateID:templateID
                                                                  line:line
                                                                 range:(NSRange){ .location = start, .length = i-start}];
                        }
                    }
                    start = i;
                    state = stateUnescapedTag;
                    i += unescapedTagStartDelimiterLength - 1;
                }
                else if (c == tagStartDelimiterCharacter && (i+tagStartDelimiterLength <= length) && [[templateString substringWithRange:NSMakeRange(i, tagStartDelimiterLength)] isEqualToString:self.tagStartDelimiter])
                {
                    if (start != i) {
                        // Content
                        // Content coalesce
                        if (lastToken) {
                            if (lastToken.type == GRMustacheTokenTypeContent) {
                                lastToken.range = (NSRange){ .location = lastToken.range.location, .length = i-lastToken.range.location };
                            } else {
                                if (![self.delegate parser:self shouldContinueAfterParsingToken:lastToken]) return;
                            }
                        } else {
                            lastToken = [GRMustacheToken tokenWithType:GRMustacheTokenTypeContent
                                                        templateString:templateString
                                                            templateID:templateID
                                                                  line:line
                                                                 range:(NSRange){ .location = start, .length = i-start}];
                        }
                    }
                    start = i;
                    state = stateTag;
                    i += tagStartDelimiterLength - 1;
                }
            } break;
                
            case stateTag: {
                if (c == tagEndDelimiterCharacter && [[templateString substringWithRange:NSMakeRange(i, tagEndDelimiterLength)] isEqualToString:self.tagEndDelimiter])
                {
                    // Tag
                    // Tag do not coalesce: consume last token.
                    if (lastToken) {
                        if (![self.delegate parser:self shouldContinueAfterParsingToken:lastToken]) return;
                        lastToken = nil;
                    }
                    NSUInteger currentTagEndDelimiterLength = tagEndDelimiterLength;    // tagEndDelimiterLength may be changed by {{=| |=}}
                    GRMustacheTokenType type = GRMustacheTokenTypeEscapedVariable;
                    UniChar tagInitial = characters[start+tagStartDelimiterLength];
                    NSRange tagInnerRange;
                    switch (tagInitial) {
                        case '!':
                            type = GRMustacheTokenTypeComment;
                            tagInnerRange = (NSRange){ .location = start+tagStartDelimiterLength+1, .length = i-(start+tagStartDelimiterLength+1) };
                            break;
                        case '#':
                            type = GRMustacheTokenTypeSectionOpening;
                            tagInnerRange = (NSRange){ .location = start+tagStartDelimiterLength+1, .length = i-(start+tagStartDelimiterLength+1) };
                            break;
                        case '^':
                            type = GRMustacheTokenTypeInvertedSectionOpening;
                            tagInnerRange = (NSRange){ .location = start+tagStartDelimiterLength+1, .length = i-(start+tagStartDelimiterLength+1) };
                            break;
                        case '$':
                            type = GRMustacheTokenTypeOverridableSectionOpening;
                            tagInnerRange = (NSRange){ .location = start+tagStartDelimiterLength+1, .length = i-(start+tagStartDelimiterLength+1) };
                            break;
                        case '/':
                            type = GRMustacheTokenTypeClosing;
                            tagInnerRange = (NSRange){ .location = start+tagStartDelimiterLength+1, .length = i-(start+tagStartDelimiterLength+1) };
                            break;
                        case '>':
                            type = GRMustacheTokenTypePartial;
                            tagInnerRange = (NSRange){ .location = start+tagStartDelimiterLength+1, .length = i-(start+tagStartDelimiterLength+1) };
                            break;
                        case '<':
                            type = GRMustacheTokenTypeOverridablePartial;
                            tagInnerRange = (NSRange){ .location = start+tagStartDelimiterLength+1, .length = i-(start+tagStartDelimiterLength+1) };
                            break;
                        case '=':
                            type = GRMustacheTokenTypeSetDelimiter;
                            tagInnerRange = (NSRange){ .location = start+tagStartDelimiterLength+1, .length = i-(start+tagStartDelimiterLength+1) };
                            
                            // set delimiter tags must end with =
                            if (characters[i-1] != '=') {
                                [self failWithParseErrorAtLine:line description:@"Invalid set delimiters tag" templateID:templateID];
                                return;
                            }
                            
                            // extract new delimiters
                            NSString *innerContent = [templateString substringWithRange:(NSRange){ .location = start+tagStartDelimiterLength+1, .length = i-(start+tagStartDelimiterLength+2) }];
                            NSArray *newTags = [innerContent componentsSeparatedByCharactersInSet:whitespaceCharacterSet];
                            NSMutableArray *nonBlankNewTags = [NSMutableArray array];
                            for (NSString *newTag in newTags) {
                                if (newTag.length > 0) {
                                    [nonBlankNewTags addObject:newTag];
                                }
                            }
                            if (nonBlankNewTags.count == 2) {
                                self.tagStartDelimiter = [nonBlankNewTags objectAtIndex:0];
                                self.tagEndDelimiter = [nonBlankNewTags objectAtIndex:1];
                                
                                // update cache
                                unescapedTagStartDelimiter = [NSString stringWithFormat:@"%@{", self.tagStartDelimiter];
                                unescapedTagEndDelimiter = [NSString stringWithFormat:@"}%@", self.tagEndDelimiter];
                                
                                tagStartDelimiterCharacter = [self.tagStartDelimiter characterAtIndex:0];
                                tagStartDelimiterLength = self.tagStartDelimiter.length;
                                tagEndDelimiterCharacter = [self.tagEndDelimiter characterAtIndex:0];
                                tagEndDelimiterLength = self.tagEndDelimiter.length;
                                
                                unescapedTagStartDelimiterCharacter = [unescapedTagStartDelimiter characterAtIndex:0];
                                unescapedTagStartDelimiterLength = unescapedTagStartDelimiter.length;
                                unescapedTagEndDelimiterCharacter = [unescapedTagEndDelimiter characterAtIndex:0];
                                unescapedTagEndDelimiterLength = unescapedTagEndDelimiter.length;
                            } else {
                                [self failWithParseErrorAtLine:line description:@"Invalid set delimiters tag" templateID:templateID];
                                return;
                            }

                            break;
                        case '{':
                            type = GRMustacheTokenTypeUnescapedVariable;
                            tagInnerRange = (NSRange){ .location = start+tagStartDelimiterLength+1, .length = i-(start+tagStartDelimiterLength+1) };
                            break;
                        case '&':
                            type = GRMustacheTokenTypeUnescapedVariable;
                            tagInnerRange = (NSRange){ .location = start+tagStartDelimiterLength+1, .length = i-(start+tagStartDelimiterLength+1) };
                            break;
                        case '%':
                            type = GRMustacheTokenTypePragma;
                            tagInnerRange = (NSRange){ .location = start+tagStartDelimiterLength+1, .length = i-(start+tagStartDelimiterLength+1) };
                            break;
                        default:
                            type = GRMustacheTokenTypeEscapedVariable;
                            tagInnerRange = (NSRange){ .location = start+tagStartDelimiterLength, .length = i-(start+tagStartDelimiterLength) };
                            break;
                    }
                    GRMustacheToken *token = [GRMustacheToken tokenWithType:type
                                                             templateString:templateString
                                                                 templateID:templateID
                                                                       line:line
                                                                      range:(NSRange){ .location = start, .length = (i+tagEndDelimiterLength)-start}];
                    token.tagInnerRange = tagInnerRange;
                    if (![self.delegate parser:self shouldContinueAfterParsingToken:token]) return;
                    
                    start = i + currentTagEndDelimiterLength;
                    state = stateStart;
                    i += currentTagEndDelimiterLength - 1;
                }
            } break;
                
            case stateUnescapedTag: {
                if (c == unescapedTagEndDelimiterCharacter && [[templateString substringWithRange:NSMakeRange(i, unescapedTagEndDelimiterLength)] isEqualToString:unescapedTagEndDelimiter])
                {
                    // Tag
                    // Tag do not coalesce: consume last token.
                    if (lastToken) {
                        if (![self.delegate parser:self shouldContinueAfterParsingToken:lastToken]) return;
                        lastToken = nil;
                    }
                    GRMustacheToken *token = [GRMustacheToken tokenWithType:GRMustacheTokenTypeUnescapedVariable
                                                             templateString:templateString
                                                                 templateID:templateID
                                                                       line:line
                                                                      range:(NSRange){ .location = start, .length = (i+unescapedTagEndDelimiterLength)-start}];
                    token.tagInnerRange = (NSRange){ .location = start+unescapedTagStartDelimiterLength, .length = i-(start+unescapedTagStartDelimiterLength) };
                    if (![self.delegate parser:self shouldContinueAfterParsingToken:token]) return;

                    start = i + unescapedTagEndDelimiterLength;
                    state = stateStart;
                    i += unescapedTagEndDelimiterLength - 1;
                }
            } break;
                
            default:
                break;
        }
    }

    // EOF
    switch (state) {
        case stateStart:
            if (lastToken) {
                if (![self.delegate parser:self shouldContinueAfterParsingToken:lastToken]) return;
                lastToken = nil;
            }
            break;
            
        case stateSpaceRun: {
            // Blank suffix
            // Blank suffix do not coalesce: consume last token.
            if (lastToken) {
                if (![self.delegate parser:self shouldContinueAfterParsingToken:lastToken]) return;
                lastToken = nil;
            }
            GRMustacheToken *token = [GRMustacheToken tokenWithType:GRMustacheTokenTypeBlankSuffix
                                                     templateString:templateString
                                                         templateID:templateID
                                                               line:line
                                                              range:(NSRange){ .location = start, .length = i-start}];
            if (![self.delegate parser:self shouldContinueAfterParsingToken:token]) return;
        } break;
            
        case stateContent: {
            // Content
            // Content coalesce
            if (lastToken) {
                if (lastToken.type == GRMustacheTokenTypeContent) {
                    lastToken.range = (NSRange){ .location = lastToken.range.location, .length = i-lastToken.range.location };
                }
            } else {
                lastToken = [GRMustacheToken tokenWithType:GRMustacheTokenTypeContent
                                            templateString:templateString
                                                templateID:templateID
                                                      line:line
                                                     range:(NSRange){ .location = start, .length = i-start}];
            }
            if (![self.delegate parser:self shouldContinueAfterParsingToken:lastToken]) return;
        } break;
            
        case stateTag:
        case stateUnescapedTag: {
            [self failWithParseErrorAtLine:line description:@"Unclosed Mustache tag" templateID:templateID];
            return;
        } break;
            
        default:
            break;
    }
}

+ (GRMustacheExpression *)parseExpression:(NSString *)string invalid:(BOOL *)outInvalid
{
    //    -> ;;sm_parenLevel=0 -> stateInitial
    //    stateInitial -> ' ' -> stateInitial
    //    stateInitial -> '.' -> stateLeadingDot
    //    stateInitial -> 'a' -> stateIdentifier
    //    stateInitial -> sm_parenLevel==0;EOF; -> stateEmpty
    //    stateLeadingDot -> 'a' -> stateIdentifier
    //    stateLeadingDot -> ' ' -> stateIdentifierDone
    //    stateIdentifier -> '(';++sm_parenLevel -> stateInitial
    //    stateLeadingDot -> sm_parenLevel>0;')';--sm_parenLevel -> stateFilterDone
    //    stateLeadingDot -> sm_parenLevel==0;EOF; -> stateValid
    //    stateIdentifier -> 'a' -> stateIdentifier
    //    stateIdentifier -> '.' -> stateWaitingForIdentifier
    //    stateIdentifier -> ' ' -> stateIdentifierDone
    //    stateIdentifier -> '(';++sm_parenLevel -> stateInitial
    //    stateIdentifier -> sm_parenLevel>0;')';--sm_parenLevel -> stateFilterDone
    //    stateIdentifier -> sm_parenLevel==0;EOF; -> stateValid
    //    stateWaitingForIdentifier -> 'a' -> stateIdentifier
    //    stateIdentifierDone -> ' ' -> stateIdentifierDone
    //    stateIdentifierDone -> sm_parenLevel==0;EOF; -> stateValid
    //    stateIdentifierDone -> '(';++sm_parenLevel -> stateInitial
    //    stateFilterDone -> ' ' -> stateFilterDone
    //    stateFilterDone -> '.' -> stateWaitingForIdentifier
    //    stateFilterDone -> '(';++sm_parenLevel -> stateInitial
    //    stateFilterDone -> sm_parenLevel==0;EOF; -> stateValid
    //    stateFilterDone -> sm_parenLevel>0;')';--sm_parenLevel -> stateFilterDone
    
    // state machine internal states
    enum {
        stateInitial,
        stateLeadingDot,
        stateIdentifier,
        stateWaitingForIdentifier,
        stateIdentifierDone,
        stateFilterDone,
        stateEmpty,
        stateError,
        stateValid
    } state = stateInitial;
    NSUInteger identifierStart = NSNotFound;
    NSMutableArray *filterExpressionStack = [NSMutableArray array];
    GRMustacheExpression *currentExpression=nil;
    GRMustacheExpression *validExpression=nil;
    
    NSUInteger length = string.length;
    for (NSUInteger i = 0; i < length; ++i) {
        
        // shortcut
        if (state == stateError) {
            break;
        }
        
        unichar c = [string characterAtIndex:i];
        switch (state) {
            case stateInitial:
                switch (c) {
                    case ' ':
                    case '\r':
                    case '\n':
                    case '\t':
                        break;
                        
                    case '.':
                        NSAssert(currentExpression == nil, @"WTF");
                        state = stateLeadingDot;
                        currentExpression = [GRMustacheImplicitIteratorExpression expression];
                        break;
                        
                    case '(':
                        state = stateError;
                        break;
                        
                    case ')':
                        state = stateError;
                        break;
                        
                    case ',':
                        state = stateError;
                        break;
                        
                    case '{':
                    case '}':
                    case '&':
                    case '$':
                    case '#':
                    case '^':
                    case '/':
                    case '<':
                    case '>':
                        // invalid as an identifier start
                        state = stateError;
                        break;
                        
                    default:
                        state = stateIdentifier;
                        
                        // enter stateIdentifier
                        identifierStart = i;
                        break;
                }
                break;
                
            case stateLeadingDot:
                switch (c) {
                    case ' ':
                    case '\r':
                    case '\n':
                    case '\t':
                        state = stateIdentifierDone;
                        break;
                        
                    case '.':
                        state = stateError;
                        break;
                        
                    case '(': {
                        NSAssert(currentExpression, @"WTF");
                        state = stateInitial;
                        [filterExpressionStack addObject:currentExpression];
                        currentExpression = nil;
                    } break;
                        
                    case ')':
                        if (filterExpressionStack.count > 0) {
                            NSAssert(currentExpression, @"WTF");
                            NSAssert(filterExpressionStack.count > 0, @"WTF");
                            
                            state = stateFilterDone;
                            GRMustacheExpression *filterExpression = [filterExpressionStack lastObject];
                            [filterExpressionStack removeLastObject];
                            currentExpression = [GRMustacheFilteredExpression expressionWithFilterExpression:filterExpression argumentExpression:currentExpression curry:NO];
                        } else {
                            state = stateError;
                        }
                        break;
                        
                    case ',':
                        if (filterExpressionStack.count > 0) {
                            NSAssert(currentExpression, @"WTF");
                            NSAssert(filterExpressionStack.count > 0, @"WTF");
                            
                            state = stateInitial;
                            GRMustacheExpression *filterExpression = [filterExpressionStack lastObject];
                            [filterExpressionStack removeLastObject];
                            [filterExpressionStack addObject:[GRMustacheFilteredExpression expressionWithFilterExpression:filterExpression argumentExpression:currentExpression curry:YES]];
                            currentExpression = nil;
                        } else {
                            state = stateError;
                        }
                        break;
                        
                    case '{':
                    case '}':
                    case '&':
                    case '$':
                    case '#':
                    case '^':
                    case '/':
                    case '<':
                    case '>':
                        // invalid as an identifier start
                        state = stateError;
                        break;
                        
                    default:
                        state = stateIdentifier;
                        
                        // enter stateIdentifier
                        identifierStart = i;
                        break;
                }
                break;
                
            case stateIdentifier:
                switch (c) {
                    case ' ':
                    case '\r':
                    case '\n':
                    case '\t': {
                        // leave stateIdentifier
                        NSString *identifier = [string substringWithRange:(NSRange){ .location = identifierStart, .length = i - identifierStart }];
                        if (currentExpression) {
                            currentExpression = [GRMustacheScopedExpression expressionWithBaseExpression:currentExpression scopeIdentifier:identifier];
                        } else {
                            currentExpression = [GRMustacheIdentifierExpression expressionWithIdentifier:identifier];
                        }
                        
                        state = stateIdentifierDone;
                    } break;
                        
                    case '.': {
                        // leave stateIdentifier
                        NSString *identifier = [string substringWithRange:(NSRange){ .location = identifierStart, .length = i - identifierStart }];
                        if (currentExpression) {
                            currentExpression = [GRMustacheScopedExpression expressionWithBaseExpression:currentExpression scopeIdentifier:identifier];
                        } else {
                            currentExpression = [GRMustacheIdentifierExpression expressionWithIdentifier:identifier];
                        }
                        
                        state = stateWaitingForIdentifier;
                    } break;
                        
                    case '(': {
                        // leave stateIdentifier
                        NSString *identifier = [string substringWithRange:(NSRange){ .location = identifierStart, .length = i - identifierStart }];
                        if (currentExpression) {
                            currentExpression = [GRMustacheScopedExpression expressionWithBaseExpression:currentExpression scopeIdentifier:identifier];
                        } else {
                            currentExpression = [GRMustacheIdentifierExpression expressionWithIdentifier:identifier];
                        }
                        
                        NSAssert(currentExpression, @"WTF");
                        state = stateInitial;
                        [filterExpressionStack addObject:currentExpression];
                        currentExpression = nil;
                    } break;
                        
                    case ')': {
                        // leave stateIdentifier
                        NSString *identifier = [string substringWithRange:(NSRange){ .location = identifierStart, .length = i - identifierStart }];
                        if (currentExpression) {
                            currentExpression = [GRMustacheScopedExpression expressionWithBaseExpression:currentExpression scopeIdentifier:identifier];
                        } else {
                            currentExpression = [GRMustacheIdentifierExpression expressionWithIdentifier:identifier];
                        }
                        
                        if (filterExpressionStack.count > 0) {
                            NSAssert(currentExpression, @"WTF");
                            NSAssert(filterExpressionStack.count > 0, @"WTF");
                            state = stateFilterDone;
                            GRMustacheExpression *filterExpression = [filterExpressionStack lastObject];
                            [filterExpressionStack removeLastObject];
                            currentExpression = [GRMustacheFilteredExpression expressionWithFilterExpression:filterExpression argumentExpression:currentExpression curry:NO];
                        } else {
                            state = stateError;
                        }
                    } break;
                        
                    case ',': {
                        // leave stateIdentifier
                        NSString *identifier = [string substringWithRange:(NSRange){ .location = identifierStart, .length = i - identifierStart }];
                        if (currentExpression) {
                            currentExpression = [GRMustacheScopedExpression expressionWithBaseExpression:currentExpression scopeIdentifier:identifier];
                        } else {
                            currentExpression = [GRMustacheIdentifierExpression expressionWithIdentifier:identifier];
                        }
                        
                        if (filterExpressionStack.count > 0) {
                            NSAssert(currentExpression, @"WTF");
                            NSAssert(filterExpressionStack.count > 0, @"WTF");
                            state = stateInitial;
                            GRMustacheExpression *filterExpression = [filterExpressionStack lastObject];
                            [filterExpressionStack removeLastObject];
                            [filterExpressionStack addObject:[GRMustacheFilteredExpression expressionWithFilterExpression:filterExpression argumentExpression:currentExpression curry:YES]];
                            currentExpression = nil;
                        } else {
                            state = stateError;
                        }
                    } break;
                        
                        
                    default:
                        break;
                }
                break;
                
            case stateWaitingForIdentifier:
                switch (c) {
                    case ' ':
                    case '\r':
                    case '\n':
                    case '\t':
                        state = stateError;
                        break;
                        
                    case '.':
                        state = stateError;
                        break;
                        
                    case '(':
                        state = stateError;
                        break;
                        
                    case ')':
                        state = stateError;
                        break;
                        
                    case ',':
                        state = stateError;
                        break;
                        
                    case '{':
                    case '}':
                    case '&':
                    case '$':
                    case '#':
                    case '^':
                    case '/':
                    case '<':
                    case '>':
                        // invalid as an identifier start
                        state = stateError;
                        break;
                        
                    default:
                        state = stateIdentifier;
                        
                        // enter stateIdentifier
                        identifierStart = i;
                        break;
                }
                break;
                
            case stateIdentifierDone:
                switch (c) {
                    case ' ':
                    case '\r':
                    case '\n':
                    case '\t':
                        break;
                        
                    case '.':
                        state = stateError;
                        break;
                        
                    case '(':
                        NSAssert(currentExpression, @"WTF");
                        state = stateInitial;
                        [filterExpressionStack addObject:currentExpression];
                        currentExpression = nil;
                        break;
                        
                    case ')':
                        if (filterExpressionStack.count > 0) {
                            NSAssert(currentExpression, @"WTF");
                            NSAssert(filterExpressionStack.count > 0, @"WTF");
                            state = stateFilterDone;
                            GRMustacheExpression *filterExpression = [filterExpressionStack lastObject];
                            [filterExpressionStack removeLastObject];
                            currentExpression = [GRMustacheFilteredExpression expressionWithFilterExpression:filterExpression argumentExpression:currentExpression curry:NO];
                        } else {
                            state = stateError;
                        }
                        break;
                        
                    case ',':
                        if (filterExpressionStack.count > 0) {
                            NSAssert(currentExpression, @"WTF");
                            NSAssert(filterExpressionStack.count > 0, @"WTF");
                            state = stateInitial;
                            GRMustacheExpression *filterExpression = [filterExpressionStack lastObject];
                            [filterExpressionStack removeLastObject];
                            [filterExpressionStack addObject:[GRMustacheFilteredExpression expressionWithFilterExpression:filterExpression argumentExpression:currentExpression curry:YES]];
                            currentExpression = nil;
                        } else {
                            state = stateError;
                        }
                        break;
                        
                    default:
                        state = stateError;
                        break;
                }
                break;
                
            case stateFilterDone:
                switch (c) {
                    case ' ':
                    case '\r':
                    case '\n':
                    case '\t':
                        break;
                        
                    case '.':
                        state = stateWaitingForIdentifier;
                        break;
                        
                    case '(':
                        NSAssert(currentExpression, @"WTF");
                        state = stateInitial;
                        [filterExpressionStack addObject:currentExpression];
                        currentExpression = nil;
                        break;
                        
                    case ')':
                        if (filterExpressionStack.count > 0) {
                            NSAssert(currentExpression, @"WTF");
                            NSAssert(filterExpressionStack.count > 0, @"WTF");
                            state = stateFilterDone;
                            GRMustacheExpression *filterExpression = [filterExpressionStack lastObject];
                            [filterExpressionStack removeLastObject];
                            currentExpression = [GRMustacheFilteredExpression expressionWithFilterExpression:filterExpression argumentExpression:currentExpression curry:NO];
                        } else {
                            state = stateError;
                        }
                        break;
                        
                    case ',':
                        if (filterExpressionStack.count > 0) {
                            NSAssert(currentExpression, @"WTF");
                            NSAssert(filterExpressionStack.count > 0, @"WTF");
                            state = stateInitial;
                            GRMustacheExpression *filterExpression = [filterExpressionStack lastObject];
                            [filterExpressionStack removeLastObject];
                            [filterExpressionStack addObject:[GRMustacheFilteredExpression expressionWithFilterExpression:filterExpression argumentExpression:currentExpression curry:YES]];
                            currentExpression = nil;
                        } else {
                            state = stateError;
                        }
                        break;
                        
                    default:
                        state = stateError;
                        break;
                }
                break;
            default:
                NSAssert(NO, @"WTF");
                break;
        }
    }
    
    
    // EOF
    
    switch (state) {
        case stateInitial:
            if (filterExpressionStack.count == 0) {
                state = stateEmpty;
            } else {
                state = stateError;
            }
            break;
            
        case stateLeadingDot:
            if (filterExpressionStack.count == 0) {
                NSAssert(currentExpression, @"WTF");
                validExpression = currentExpression;
                state = stateValid;
            } else {
                state = stateError;
            }
            break;
            
        case stateIdentifier: {
            // leave stateIdentifier
            NSString *identifier = [string substringFromIndex:identifierStart];
            if (currentExpression) {
                currentExpression = [GRMustacheScopedExpression expressionWithBaseExpression:currentExpression scopeIdentifier:identifier];
            } else {
                currentExpression = [GRMustacheIdentifierExpression expressionWithIdentifier:identifier];
            }
            
            if (filterExpressionStack.count == 0) {
                NSAssert(currentExpression, @"WTF");
                validExpression = currentExpression;
                state = stateValid;
            } else {
                state = stateError;
            }
        } break;
            
        case stateWaitingForIdentifier:
            state = stateError;
            break;
            
        case stateIdentifierDone:
            if (filterExpressionStack.count == 0) {
                NSAssert(currentExpression, @"WTF");
                validExpression = currentExpression;
                state = stateValid;
            } else {
                state = stateError;
            }
            break;
            
        case stateFilterDone:
            if (filterExpressionStack.count == 0) {
                NSAssert(currentExpression, @"WTF");
                validExpression = currentExpression;
                state = stateValid;
            } else {
                state = stateError;
            }
            break;
            
        case stateError:
            break;
            
        default:
            NSAssert(NO, @"WTF");
            break;
    }
    
    
    // End
    
    switch (state) {
        case stateEmpty:
            if (outInvalid) {
                *outInvalid = NO;
            }
            return nil;
            
        case stateError:
            if (outInvalid) {
                *outInvalid = YES;
            }
            return nil;
            
        case stateValid:
            NSAssert(validExpression, @"WTF");
            return validExpression;
            
        default:
            NSAssert(NO, @"WTF");
            break;
    }
    
    return nil;
}

+ (NSString *)parseTemplateName:(NSString *)string
{
    NSString *templateName = [string stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (templateName.length == 0) {
        return nil;
    }
    return templateName;
}

+ (NSString *)parsePragma:(NSString *)string
{
    NSString *pragma = [string stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (pragma.length == 0) {
        return nil;
    }
    return pragma;
}


#pragma mark - Private

- (BOOL)shouldContinueAfterParsingToken:(GRMustacheToken *)token
{
    if ([_delegate respondsToSelector:@selector(parser:shouldContinueAfterParsingToken:)]) {
        return [_delegate parser:self shouldContinueAfterParsingToken:token];
    }
    return YES;
}

- (void)failWithParseErrorAtLine:(NSInteger)line description:(NSString *)description templateID:(id)templateID
{
    if ([_delegate respondsToSelector:@selector(parser:didFailWithError:)]) {
        NSString *localizedDescription;
        if (templateID) {
            localizedDescription = [NSString stringWithFormat:@"Parse error at line %lu of template %@: %@", (unsigned long)line, templateID, description];
        } else {
            localizedDescription = [NSString stringWithFormat:@"Parse error at line %lu: %@", (unsigned long)line, description];
        }
        [_delegate parser:self didFailWithError:[NSError errorWithDomain:GRMustacheErrorDomain
                                                                       code:GRMustacheErrorCodeParseError
                                                                   userInfo:[NSDictionary dictionaryWithObject:localizedDescription
                                                                                                        forKey:NSLocalizedDescriptionKey]]];
    }
}

@end
