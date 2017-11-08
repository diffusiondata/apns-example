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

/*
 * Fetches a topic content from a nominated server and topic-path.
 * Passes the result to a completionhandler.
 *
 * Used for handling silent push notifications.
 */
@interface TopicFetcher : NSObject<PTDiffusionFetchStreamDelegate>
-(id)    initWithURL:(NSURL*)url
           topicPath:(NSString*)topicPath
andCompletionhandler:(void (^)(UIBackgroundFetchResult))completionHandler;

-(void)fetch;

@end

@implementation AppDelegate {
    TopicFetcher *_fetcher;
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

        _fetcher = [[TopicFetcher alloc] initWithURL:[NSURL URLWithString:url]
                                                  topicPath:silentTopicPath
                                       andCompletionhandler:completionHandler];
        [_fetcher fetch];
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

@implementation TopicFetcher {
    NSURL *_url;
    NSString *_topicPath;
    PTDiffusionSession *_session;
    void (^_completionHandler)(UIBackgroundFetchResult);
}

-(id)    initWithURL:(NSURL*)url
           topicPath:(NSString*)topicPath
andCompletionhandler:(void (^)(UIBackgroundFetchResult))completionHandler {
    if (self = [super init]) {
        _url = url;
        _topicPath = topicPath;
        _completionHandler = completionHandler;
        return self;
    }
    return nil;
}

-(void)fetch {
    // Make no reconnection attempts
    PTDiffusionMutableSessionConfiguration *const sessionConfiguration = [PTDiffusionMutableSessionConfiguration new];
    sessionConfiguration.reconnectionTimeout = @0;

    [PTDiffusionSession openWithURL:_url
                      configuration:sessionConfiguration
                  completionHandler:^(PTDiffusionSession * session, NSError * error)
     {
         _session = session;
         if (!session) {
             NSLog(@"Session connection to %@ failed: %@", _url, error);
             return;
         }

         [session.topics fetchWithTopicSelectorExpression:_topicPath
                                                 delegate:self];
     }];
}

-(void)diffusionStream:(PTDiffusionStream *)stream
     didFetchTopicPath:(NSString *)topicPath
               content:(PTDiffusionContent *)topicContent {

    [_session close];

    // Convert the raw bytes into a JSON
    PTDiffusionJSON *const json = [[PTDiffusionJSON alloc] initWithData:topicContent.data];
    NSLog(@"Got \"%@\" from %@", json, topicPath);

    // Convert the JSON into a native object
    NSError *error;
    const id topicValue = [json objectWithError:&error];
    if (!topicValue) {
        NSLog(@"Cannot parse topic content as object: %@", error);
        return;
    }

    UNMutableNotificationContent *const content = [UNMutableNotificationContent new];
    content.title = topicPath;
    content.body = [NSString stringWithFormat:@"Topic %@ = %@", topicPath, topicValue];
    content.sound = [UNNotificationSound defaultSound];

    UNNotificationRequest *const notification = [UNNotificationRequest requestWithIdentifier:@"fetch-result"
                                                                                     content:content
                                                                                     trigger:nil];
    UNUserNotificationCenter* center = [UNUserNotificationCenter currentNotificationCenter];
    [center addNotificationRequest:notification withCompletionHandler:nil];

    [self complete:UIBackgroundFetchResultNewData];
}

-(void)diffusionStream:(PTDiffusionStream *)stream
      didFailWithError:(NSError *)error {

    NSLog(@"Failed to fetch value of %@/%@: %@", _url, _topicPath, error);
    [_session close];
    [self complete:UIBackgroundFetchResultFailed];
}

- (void)diffusionDidCloseStream:(nonnull PTDiffusionStream *)stream {
    /* do nothing */
}

-(void)complete:(UIBackgroundFetchResult)completionValue {
    void const (^completionHandler)(UIBackgroundFetchResult) = _completionHandler;
    _completionHandler = nil;
    if (completionHandler == nil) {
        [NSException raise:NSInternalInconsistencyException
                    format:@"self.compl"];
    }
    completionHandler(UIBackgroundFetchResultFailed);
}

@end
