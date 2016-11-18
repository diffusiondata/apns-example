//
//  Common.m
//  APNSExample
//
//  Created by Martin Cowie on 16/11/2016.
//  Copyright © 2016 EXAMPLE. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "Common.h"

@implementation Common

+(void)displayAlert:(NSString*)message withTitle:(NSString*)title {
#   pragma clang diagnostic ignored "-Wdeprecated-declarations"
    UIAlertView *const alert = [[UIAlertView alloc] initWithTitle:title
                                                          message:message
                                                         delegate:nil
                                                cancelButtonTitle:@"Ok"
                                                otherButtonTitles:nil];
    [alert show];
#   pragma clang diagnostic pop
}

@end
