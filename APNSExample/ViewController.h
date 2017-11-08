//
//  ViewController.h
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


#import <UIKit/UIKit.h>
@import Diffusion;

@interface ViewController : UITableViewController<PTDiffusionJSONValueStreamDelegate>

@property (nonatomic) PTDiffusionSession *session;
@property (nonatomic) NSData *deviceToken;
@property (nonatomic) NSString *topicPath;
@property (nonatomic) NSString *silentTopicPath;

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

