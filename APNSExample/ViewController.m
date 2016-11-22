//
//  ViewController.m
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

#import "ViewController.h"
#import "Common.h"
#import "NSString+Flatten.h"

#define SERVICE_TOPIC @"push/notifications"

/*
 * Tags used in the storyboard to identify UITableViewCells of note
 */
static const char sessionIdTag = 10;
static const char pnSubscribeTag = 20;
static const char pnUnsubscribeTag = 21;

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];

    [nc addObserver:self
           selector:@selector(didRegisterForRemoteNotificationsWithDeviceToken:)
               name:didRegisterForRemoteNotificationsWithDeviceToken
             object:nil];

    [nc addObserver:self
           selector:@selector(didFailToRegisterForRemoteNotificationsWithError:)
               name:didFailToRegisterForRemoteNotificationsWithError
             object:nil];

    [nc addObserver:self
           selector:@selector(activate)
               name:applicationWillEnterForeground
             object:nil];

    [nc addObserver:self
           selector:@selector(deactivate)
               name:applicationDidEnterBackground
             object:nil];

    [self addObserver:self
           forKeyPath:@"deviceToken"
              options:NSKeyValueObservingOptionNew
              context:nil];

    [self addObserver:self
           forKeyPath:@"session"
              options:NSKeyValueObservingOptionNew
              context:nil];

    [self activate];
}

#pragma mark NSNotificationCenter event handling

-(void)didRegisterForRemoteNotificationsWithDeviceToken:(NSNotification*)notification {
    // Expecting notification.object to be an NSData* holding the APNs device token
    NSData *const deviceToken = notification.object;
    self.deviceToken = deviceToken;
}

-(void)didFailToRegisterForRemoteNotificationsWithError:(NSNotification*)notification {
    // Expecting notification object to be an NSError* detailing the APNs registration failure
    NSError *const error = notification.object;
    self.deviceIdLabel.text = error.localizedDescription;
}

-(void)activate {
    NSUserDefaults *const defaults = [NSUserDefaults standardUserDefaults];
    NSString *const url = [defaults stringForKey:@"URL"];
    self.topicPath = [defaults stringForKey:@"TOPIC"];
    self.silentTopicPath = [defaults stringForKey:@"SILENT_TOPIC"];
    self.topicNameLabel.text = self.topicPath;
    self.silentTopicNameLabel.text = self.silentTopicPath;

    // Make no reconnection attempts
    PTDiffusionMutableSessionConfiguration *const sessionConfiguration = [PTDiffusionMutableSessionConfiguration new];
    sessionConfiguration.reconnectionTimeout = @0;

    [PTDiffusionSession openWithURL:[NSURL URLWithString:url]
                      configuration:sessionConfiguration
                  completionHandler:^(PTDiffusionSession * session, NSError * error)
     {
         if (!session) {
             [Common displayAlert:error.localizedDescription withTitle:@"Cannot connect to Diffusion" viewControler:self];
             return;
         }
         self.session = session;

        NSNotificationCenter *const nc = [NSNotificationCenter defaultCenter];
         [nc addObserverForName:PTDiffusionSessionStateDidChangeNotification
                         object:session
                          queue:nil
                     usingBlock:^(NSNotification * note)
          {
              PTDiffusionSessionStateChange * change = note.userInfo[PTDiffusionSessionStateChangeUserInfoKey];

              if(change.state.closed) {
                  self.session = nil;
              }
          }];


         // Subscribe to both topics
         PTDiffusionTopicSelector *const selector = [PTDiffusionTopicSelector topicSelectorWithAnyExpression:@[self.topicPath, self.silentTopicPath]];

         [session.topics subscribeWithTopicSelectorExpression:selector.description
                                            completionHandler:^(NSError * error)
          {
              if (error != nil) {
                  [Common displayAlert:[NSString stringWithFormat:@"topic: %@, error: %@", self.topicPath, error.localizedDescription]
                             withTitle:@"Cannot subscribe"
                         viewControler:self];
                  return;
              }
              [session.topics addFallbackTopicStreamWithDelegate:self];
          }];
     }];
}


-(void)deactivate {
    [self.session close];
}

#pragma mark KVO obligations

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context {

    if(object != self) {
        return;
    }
    if([keyPath isEqualToString:@"session"]) {
        self.sessionIdLabel.enabled = self.session != nil;
        self.sessionIdLabel.text = (self.session != nil)
            ? [self.session.sessionId description]
            : nil;

        if(self.session) {
            // Wire up a handler for the responses from SERVICE_TOPIC
            PTDiffusionTopicSelector *const topicSelector = [PTDiffusionTopicSelector topicSelectorWithExpression:SERVICE_TOPIC];
            [self.session.messaging addMessageStreamWithSelector:topicSelector
                                                        delegate:self];
        }
    }

    else if([keyPath isEqualToString:@"deviceToken"]) {
        self.deviceIdLabel.enabled = self.deviceToken != nil;
        self.deviceIdLabel.text = self.deviceToken != nil
            ? [self formatAsURI:self.deviceToken]
            : nil;
    }

    else {
        return;
    }

    // Enable/disable the Subscribe and Unsubscribe 'buttons'
    const BOOL valid = (self.deviceToken != nil && self.session != nil);
    self.pnSubViewCell.selectionStyle = valid ? UITableViewCellSelectionStyleDefault : UITableViewCellSelectionStyleNone;
    self.pnUnsubViewCell.selectionStyle = self.pnSubViewCell.selectionStyle;
    self.pnSubLabel.enabled = self.pnUnsubLabel.enabled = valid;
}

#pragma mark UITableViewDelegate obligations

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    UITableViewCell *const cell = [tableView cellForRowAtIndexPath:indexPath];
    switch(cell.tag) {
        case sessionIdTag: {
            NSURL *const url = [NSURL URLWithString:UIApplicationOpenSettingsURLString];
            [[UIApplication sharedApplication] openURL:url
                                               options:[NSDictionary new]
                                     completionHandler:nil];
            break;
        }

        case pnSubscribeTag: {
            if (self.session != nil && self.deviceToken != nil) {
                [self doPnSubscribe:@[self.topicPath, self.silentTopicPath]
                        deviceToken:self.deviceToken];
            }
            break;
        }
        case pnUnsubscribeTag: {
            if (self.session != nil && self.deviceToken != nil) {
                [self doPnUnsubscribe:@[self.topicPath, self.silentTopicPath]
                          deviceToken:self.deviceToken];
            }
            break;
        }
    }
}

#pragma mark GUI event handling

/**
 * Compose a URI understood by the Push Notification Bridge from an APNs device token.
 * @param deviceID APNS device token.
 * @return string in format expected by the push notification bridge.
 */
-(NSString*)formatAsURI:(NSData*)deviceID {
    return [NSString stringWithFormat:@"apns://%@", [deviceID base64EncodedStringWithOptions:0]];
}

/**
 * Compose and send a subscription request to the Push Notification bridge
 * @param paths topic paths within the subscription request
 */
- (void)doPnSubscribe:(NSArray<NSString*> *)paths deviceToken:(NSData*)deviceToken {
    // Compose the JSON request from Obj-C literals
    NSString *const correlation = [[NSUUID UUID] UUIDString];
    PTDiffusionTopicSelector *const selector = [PTDiffusionTopicSelector topicSelectorWithAnyExpression:paths];
    NSDictionary *const request = 
        @{@"request": @{
                  @"correlation": correlation,
                  @"content": @{
                          @"pnsub": @{
                                  @"destination": [self formatAsURI:deviceToken],
                                  @"topic": selector.description}
                          }
                  }};
    NSData *const requestData = [NSJSONSerialization dataWithJSONObject:request options:0 error:nil];

    // Send a message to `SERVICE_TOPIC`
    [_session.messaging sendWithTopicPath:SERVICE_TOPIC
                                    value:[[PTDiffusionContent alloc] initWithData:requestData]
                        completionHandler:^(NSError * _Nullable error)
                        {
                                if(error != nil) {
                                    NSLog(@"Send to topic %@ failed: %@", SERVICE_TOPIC, error);
                                }
                        }];
}


/**
 * Compose and send a unsubscription request to the Push Notification bridge
 * @param paths topic paths within the subscription request
 */
- (void)doPnUnsubscribe:(NSArray<NSString*> *)paths deviceToken:(NSData*)deviceToken {
    // Compose the JSON request from Obj-C literals
    NSString *const correlation = [[NSUUID UUID] UUIDString];
    PTDiffusionTopicSelector *const selector = [PTDiffusionTopicSelector topicSelectorWithAnyExpression:paths];
    NSDictionary *const request =
        @{@"request": @{
                  @"correlation": correlation,
                  @"content": @{
                          @"pnunsub": @{
                                  @"destination": [self formatAsURI:deviceToken],
                                  @"topic": selector.description}
                          }
                  }};
    PTDiffusionContent *const requestContent = [[PTDiffusionContent alloc] initWithData:[NSJSONSerialization
                                                                                   dataWithJSONObject:request
                                                                                   options:0
                                                                                   error:nil]];

    // Send a message to `SERVICE_TOPIC`
    [self.session.messaging sendWithTopicPath:SERVICE_TOPIC
                                        value:requestContent
                            completionHandler:^(NSError * _Nullable error)
                            {
                                if(error != nil) {
                                    [Common displayAlert:error.localizedDescription
                                               withTitle:@"Send to topic failed"
                                           viewControler:self] ;
                                }
                            }];
}

#pragma mark PTDiffusionMessageStreamDelegate obligations

-(void)          diffusionStream:(PTDiffusionStream *)stream
    didReceiveMessageOnTopicPath:(NSString *)topicPath
                         content:(PTDiffusionContent *)topicContent
                         context:(PTDiffusionReceiveContext *)context {
    if([topicPath isEqualToString:SERVICE_TOPIC]) {
        // parse the JSON, and look for good or bad news,
        NSError *error;
        NSDictionary *const response=[NSJSONSerialization JSONObjectWithData:topicContent.data options:kNilOptions error:&error];
        if (response == nil) {
            [Common displayAlert:@"Cannot parse response"
                       withTitle:error.description
                   viewControler:self] ;
        }

        NSDictionary *const content =[[response valueForKey:@"response"] valueForKey:@"content"];
        if(content != nil) {
            [Common displayAlert:[content.description flatten]
                       withTitle:@"PNSubscription accepted"
                   viewControler:self] ;
        } else {
            NSObject *const errorObject =[[response valueForKey:@"response"] valueForKey:@"error"];
            [Common displayAlert:[errorObject description]
                       withTitle:@"PNSubscription failed"
                   viewControler:self] ;

        }
    }
}

#pragma mark PTDiffusionTopicStreamDelegate obligations

-(void)diffusionStream:(PTDiffusionStream *)stream
    didUpdateTopicPath:(NSString *)topicPath
               content:(PTDiffusionContent *)content
               context:(PTDiffusionUpdateContext *)context {

    NSString *const string = [[NSString alloc] initWithData:content.data encoding:NSUTF8StringEncoding];
    if([topicPath isEqualToString:self.topicPath]) {
        self.topicValueLabel.text = string;
        self.topicValueLabel.enabled = YES;

        // Update my app icon badge
        [[UIApplication sharedApplication] setApplicationIconBadgeNumber:string.integerValue];
    }

    else if([topicPath isEqualToString:self.silentTopicPath]) {
        self.silentTopicValueLabel.text = string;
        self.silentTopicValueLabel.enabled = YES;
    }
}


@end
