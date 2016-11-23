//
//  AppDelegate.m
//
//  Copyright (C) 2016 Push Technology Ltd.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.

#import "AppDelegate.h"
#import "Common.h"

@import Diffusion;
@import UserNotifications;

@interface SilentFetcher : NSObject<PTDiffusionFetchStreamDelegate>

-(id)    initWithURL:(NSURL*)url
           topicPath:(NSString*)topicPath
andCompletionhandler:(void (^)(UIBackgroundFetchResult))completionHandler;

-(void)fetch;

@property (nonatomic) NSURL *url;
@property (nonatomic) NSString *topicPath;
@property (nonatomic) PTDiffusionSession *session;
@property (nonatomic) void (^completionHandler)(UIBackgroundFetchResult);

@end

@implementation AppDelegate {
    SilentFetcher *_silentFetcher;
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    [self registerDefaultsFromSettingsBundle];
    [application registerForRemoteNotifications];
    return YES;
}

-(void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
    NSNotification *const notification = [NSNotification notificationWithName:didRegisterForRemoteNotificationsWithDeviceToken
                                                                       object:deviceToken];
    [[NSNotificationCenter defaultCenter] postNotification:notification];

    UNUserNotificationCenter* center = [UNUserNotificationCenter currentNotificationCenter];
    [center requestAuthorizationWithOptions:(UNAuthorizationOptionBadge | UNAuthorizationOptionSound | UNAuthorizationOptionAlert)
                          completionHandler:^(BOOL granted, NSError * _Nullable error) {
                              if (granted) {
                              }
                          }];
}

-(void)application:(UIApplication *)application didFailToRegisterForRemoteNotificationsWithError:(nonnull NSError *)error {
    NSNotification *const notification = [NSNotification notificationWithName:didFailToRegisterForRemoteNotificationsWithError
                                                                       object:error];
    [[NSNotificationCenter defaultCenter] postNotification:notification];
}

-(void)          application:(UIApplication *)application
didReceiveRemoteNotification:(NSDictionary *)userInfo
      fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler {

    if([userInfo[@"aps"][@"content-available"] isEqual:@1] && (application.applicationState == UIApplicationStateBackground)) {
        /*
         * Fetch the value of `SILENT_TOPIC` from Diffusion in the background. The remote notification
         * acts as a signal stimulating the app to get the topic value.

         * This may be desirable when transmitting sensitive data, or in circumstances where local data
         * protection legislation mandates data not leave a geography.
         */

        NSUserDefaults *const defaults = [NSUserDefaults standardUserDefaults];
        NSString *const silentTopicPath = [defaults stringForKey:@"SILENT_TOPIC"];
        NSString *const url = [defaults stringForKey:@"URL"];

        _silentFetcher = [[SilentFetcher alloc] initWithURL:[NSURL URLWithString:url]
                                                  topicPath:silentTopicPath
                                       andCompletionhandler:completionHandler];
        [_silentFetcher fetch];
    }
}

-(void)applicationDidEnterBackground:(UIApplication *)application {
    NSNotification *const notif = [NSNotification notificationWithName:applicationDidEnterBackground
                                                                object:application];
    [[NSNotificationCenter defaultCenter] postNotification:notif];
}

-(void)applicationWillEnterForeground:(UIApplication *)application {
    NSNotification *const notif = [NSNotification notificationWithName:applicationWillEnterForeground
                                                                object:application];
    [[NSNotificationCenter defaultCenter] postNotification:notif];
}

#pragma mark NSUserDefaults
/**
 * Read the default values from the settings bundle, and register as defaults.
 *
 * Subsequent uses of `[[NSUserDefaults standardUserDefaults] objectForKey:@"someKey"]` will return
 * the default value, if no explicit value is defined.
 */
- (void)registerDefaultsFromSettingsBundle {

    NSString* const settingsBundle = [[NSBundle mainBundle] pathForResource:@"Settings"
                                                                     ofType:@"bundle"];
    if(!settingsBundle) {
        [NSException raise:NSInternalInconsistencyException
                    format:@"Cannot load settings defaults: %@", settingsBundle];
    }

    NSDictionary *const settings = [NSDictionary dictionaryWithContentsOfFile:[settingsBundle stringByAppendingPathComponent:@"Root.plist"]];
    NSArray *const preferences = [settings objectForKey:@"PreferenceSpecifiers"];

    NSMutableDictionary *const defaultsToRegister = [[NSMutableDictionary alloc] initWithCapacity:preferences.count];
    for(NSDictionary *const prefSpecification in preferences) {
        NSString *const key = [prefSpecification objectForKey:@"Key"];
        if(key) {
            [defaultsToRegister setObject:[prefSpecification objectForKey:@"DefaultValue"]
                                   forKey:key];
        }
    }

    [[NSUserDefaults standardUserDefaults] registerDefaults:defaultsToRegister];
}

@end

@implementation SilentFetcher

-(id)    initWithURL:(NSURL*)url
           topicPath:(NSString*)topicPath
andCompletionhandler:(void (^)(UIBackgroundFetchResult))completionHandler {
    if (self = [super init]) {
        self.url = url;
        self.topicPath = topicPath;
        self.completionHandler = completionHandler;
        return self;
    }
    return nil;
}

-(void)fetch {
    // Make no reconnection attempts
    PTDiffusionMutableSessionConfiguration *const sessionConfiguration = [PTDiffusionMutableSessionConfiguration new];
    sessionConfiguration.reconnectionTimeout = @0;

    [PTDiffusionSession openWithURL:self.url
                      configuration:sessionConfiguration
                  completionHandler:^(PTDiffusionSession * session, NSError * error)
     {
         self.session = session;
         if (!session) {
             NSLog(@"Session connection to %@ failed: %@", self.url, error);
             return;
         }
         [session.topics fetchWithTopicSelectorExpression:self.topicPath
                                                 delegate:self];
     }];
}

-(void)diffusionStream:(PTDiffusionStream *)stream
     didFetchTopicPath:(NSString *)topicPath
               content:(PTDiffusionContent *)topicContent {

    [self.session close];

    UNMutableNotificationContent *const content = [UNMutableNotificationContent new];
    content.title = topicPath;
    content.body = [[NSString alloc] initWithData:topicContent.data encoding:NSUTF8StringEncoding];
    content.sound = [UNNotificationSound defaultSound];

    UNNotificationRequest *const notification = [UNNotificationRequest requestWithIdentifier:@"fetch-result"
                                                                                     content:content
                                                                                     trigger:nil];
    UNUserNotificationCenter* center = [UNUserNotificationCenter currentNotificationCenter];
    [center addNotificationRequest:notification withCompletionHandler:nil];

    self.completionHandler(UIBackgroundFetchResultNewData);
}

-(void)diffusionStream:(PTDiffusionStream *)stream
      didFailWithError:(NSError *)error {

    NSLog(@"Failed to fetch value of %@/%@: %@", self.url, self.topicPath, error);
    [self.session close];

    void const (^completionHandler)(UIBackgroundFetchResult) = self.completionHandler;
    self.completionHandler = nil;
    if (completionHandler == nil) {
        [NSException raise:NSInternalInconsistencyException
                    format:@"completionHandler is nil"];
    }
    completionHandler(UIBackgroundFetchResultFailed);
}

@end
