//
//  ViewController.h
//  APNSExample
//
//  Created by Martin Cowie on 07/11/2016.
//  Copyright © 2016 EXAMPLE. All rights reserved.
//

#import <UIKit/UIKit.h>
@import Diffusion;

@interface ViewController : UITableViewController<PTDiffusionTopicStreamDelegate, PTDiffusionMessageStreamDelegate>

@property PTDiffusionSession *session;
@property NSData *deviceToken;
@property NSString *topicPath;
@property NSString *silentTopicPath;


@property (weak, nonatomic) IBOutlet UILabel *sessionIdLabel;
@property (weak, nonatomic) IBOutlet UILabel *deviceIdLabel;

@property (weak, nonatomic) IBOutlet UILabel *topicNameLabel;
@property (weak, nonatomic) IBOutlet UILabel *topicValueLabel;
@property (weak, nonatomic) IBOutlet UILabel *silentTopicNameLabel;
@property (weak, nonatomic) IBOutlet UILabel *silentTopicValueLabel;

@property (weak, nonatomic) IBOutlet UITableViewCell *pnSubViewCell;
@property (weak, nonatomic) IBOutlet UITableViewCell *pnUnsubViewCell;
@property (weak, nonatomic) IBOutlet UILabel *pnSubLabel;
@property (weak, nonatomic) IBOutlet UILabel *pnUnsubLabel;

@end

