//
//  NSString+Flatten.m
//  APNSExample
//
//  Created by Martin Cowie on 22/11/2016.
//  Copyright © 2016 EXAMPLE. All rights reserved.
//

#import "NSString+Flatten.h"

@implementation NSString(flatten)

-(NSString*)flatten {
    return [self stringByReplacingOccurrencesOfString:@"\\s+"
                                           withString:@""
                                              options:NSRegularExpressionSearch
                                                range:NSMakeRange(0, self.length)];
}

@end
