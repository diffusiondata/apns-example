//
//  Common.m
//  APNSExample
//
//  Created by Martin Cowie on 16/11/2016.
//  Copyright © 2016 EXAMPLE. All rights reserved.
//

@import Foundation;
@import UIKit;
#import "Common.h"

NSString *const didRegisterForRemoteNotificationsWithDeviceToken = @"didRegisterForRemoteNotificationsWithDeviceToken";
NSString *const didFailToRegisterForRemoteNotificationsWithError = @"didFailToRegisterForRemoteNotificationsWithError";
NSString *const applicationWillEnterForeground = @"applicationWillEnterForeground";
NSString *const applicationDidEnterBackground = @"applicationDidEnterBackground";

@implementation Common

+(void)displayAlert:(NSString*)message withTitle:(NSString*)title viewControler:(UIViewController*)viewControler{
    UIAlertController *const alert = [UIAlertController alertControllerWithTitle:title
                                                                         message:message
                                                                  preferredStyle:UIAlertControllerStyleAlert];

    UIAlertAction* defaultAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault
                                                          handler:^(UIAlertAction * action) {}];
    [alert addAction:defaultAction];

    [viewControler presentViewController:alert animated:YES completion:nil];
}

@end

