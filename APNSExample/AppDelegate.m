//
//  AppDelegate.m
//  APNSExample
//
//  Created by Martin Cowie on 07/11/2016.
//  Copyright © 2016 EXAMPLE. All rights reserved.
//

#import "AppDelegate.h"
#import "Common.h"

@import Diffusion;

@interface SilentFetcher : NSObject<PTDiffusionFetchStreamDelegate>

-(id)    initWithURL:(NSURL*)url
           topicPath:(NSString*)topicPath
andCompletionhandler:(void (^)(UIBackgroundFetchResult))completionHandler;

-(void)fetch;

@property NSURL *url;
@property NSString *topicPath;
@property PTDiffusionSession *session;
@property void (^completionHandler)(UIBackgroundFetchResult);

@end

@interface AppDelegate ()
@property SilentFetcher *silentFetcher;
@end

@implementation AppDelegate

#pragma clang diagnostic ignored "-Wdeprecated-declarations"

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    const UIUserNotificationType types = (UIUserNotificationTypeBadge | UIUserNotificationTypeSound | UIUserNotificationTypeAlert);
    UIUserNotificationSettings *const mySettings = [UIUserNotificationSettings settingsForTypes:types categories:nil];

    [application registerUserNotificationSettings:mySettings];
    [self registerDefaultsFromSettingsBundle];

    return YES;
}

-(void)application:(UIApplication *)application didRegisterUserNotificationSettings:(UIUserNotificationSettings *)notificationSettings {
    if (notificationSettings.types & UIUserNotificationTypeAlert) {
        [application registerForRemoteNotifications];
    } else {
        //TODO: make sure this is in the right place
        [Common displayAlert:@"Notifications" withTitle:@"Will not receive notifications"];
    }
}

-(void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
    NSLog(@"didRegisterForRemoteNotificationsWithDeviceToken:%@", deviceToken);

    NSNotification *const notification = [NSNotification notificationWithName:@"didRegisterForRemoteNotificationsWithDeviceToken" object:deviceToken];
    [[NSNotificationCenter defaultCenter] postNotification:notification];
}

-(void)application:(UIApplication *)application didFailToRegisterForRemoteNotificationsWithError:(nonnull NSError *)error {
    NSNotification *const notification = [NSNotification notificationWithName:@"didFailToRegisterForRemoteNotificationsWithError" object:error];
    [[NSNotificationCenter defaultCenter] postNotification:notification];
}

#pragma clang diagnostic pop

-(void)          application:(UIApplication *)application
didReceiveRemoteNotification:(NSDictionary *)userInfo
      fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler {

    if([userInfo[@"aps"][@"content-available"] isEqual:@1] && (application.applicationState == UIApplicationStateBackground)) {
        NSUserDefaults *const defaults = [NSUserDefaults standardUserDefaults];
        NSString *const silentTopicPath = [defaults stringForKey:@"SILENT_TOPIC"];
        NSString *const url = [defaults stringForKey:@"URL"];

        self.silentFetcher = [[SilentFetcher alloc] initWithURL:[NSURL URLWithString:url]
                                                      topicPath:silentTopicPath
                                           andCompletionhandler:completionHandler];
        [self.silentFetcher fetch];
    }
}

-(void)applicationDidEnterBackground:(UIApplication *)application {
    NSNotification *const notif = [NSNotification notificationWithName:@"applicationDidEnterBackground" object:application];
    [[NSNotificationCenter defaultCenter] postNotification:notif];
}

-(void)applicationWillEnterForeground:(UIApplication *)application {
    NSNotification *const notif = [NSNotification notificationWithName:@"applicationWillEnterForeground" object:application];
    [[NSNotificationCenter defaultCenter] postNotification:notif];
}

#pragma mark NSUserDefaults
/**
 * Read the default values from the settings bundle, and register as defaults.
 *
 * Consequent uses of `[[NSUserDefaults standardUserDefaults] objectForKey:@"someKey"]` will return
 * the default value, if no explicit value is defined.
 */
- (void)registerDefaultsFromSettingsBundle {

    NSString* const settingsBundle = [[NSBundle mainBundle] pathForResource:@"Settings" ofType:@"bundle"];
    if(!settingsBundle) {
        [NSException raise:@"Cannot load setting defaults" format:@"Cannot load settings defaults: %@", settingsBundle];
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
               content:(PTDiffusionContent *)content {

    [self.session close];

    NSString *const contentStr = [[NSString alloc] initWithData:content.data encoding:NSUTF8StringEncoding];
    UILocalNotification* localNotification = [[UILocalNotification alloc] init];
    localNotification.alertTitle = topicPath;
    localNotification.alertBody = contentStr;
    localNotification.soundName = UILocalNotificationDefaultSoundName;
    [[UIApplication sharedApplication] presentLocalNotificationNow:localNotification];

    self.completionHandler(UIBackgroundFetchResultNewData);
}

-(void)diffusionStream:(PTDiffusionStream *)stream
      didFailWithError:(NSError *)error {

    NSLog(@"Failed to fetch value of %@/%@: %@", self.url, self.topicPath, error);
    [self.session close];
    self.completionHandler(UIBackgroundFetchResultFailed);
}

@end
