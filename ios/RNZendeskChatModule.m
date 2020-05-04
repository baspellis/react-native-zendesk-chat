//
//  RNZendeskChat.m
//  Tasker
//
//  Created by Jean-Richard Lai on 11/23/15.
//  Copyright © 2015 Facebook. All rights reserved.
//

#import "RNZendeskChatModule.h"
#import <ChatSDK/ChatSDK.h>
#import <ChatProvidersSDK/ChatProvidersSDK.h>

@implementation RNZendeskChatModule

RCT_EXPORT_MODULE(RNZendeskChatModule);

RCT_EXPORT_METHOD(setVisitorInfo:(NSDictionary *)options) {
  ZDKChatAPIConfiguration *config = [[ZDKChatAPIConfiguration alloc] init];
  if (options[@"department"]) {
    config.department = options[@"department"];
  }
  if (options[@"tags"]) {
    config.tags = options[@"tags"];
  }
  config.visitorInfo = [[ZDKVisitorInfo alloc] initWithName:options[@"name"]
                                                                  email:options[@"email"]
                                                            phoneNumber:options[@"phone"];
  ZDKChat.instance.configuration = config;
}

RCT_EXPORT_METHOD(startChat:(NSDictionary *)options) {
  [self setVisitorInfo:options];

  ZDKMessagingConfiguration *messagingConfiguration = [[ZDKMessagingConfiguration alloc] init];
  messagingConfiguration.name = @"VICKY";

  ZDKChatConfiguration *chatConfiguration = [[ZDKChatConfiguration alloc] init];
  chatConfiguration.isPreChatFormEnabled = YES;

  ZDKChatFormConfiguration *formConfiguration = [[ZDKChatFormConfiguration alloc] initWithName:ZDKFormFieldStatusRequired
                                                                                       email:ZDKFormFieldStatusOptional
                                                                                 phoneNumber:ZDKFormFieldStatusOptional
                                                                                  department:ZDKFormFieldStatusHidden];
  chatConfiguration.preChatFormConfiguration = formConfiguration;

  dispatch_sync(dispatch_get_main_queue(), ^{
    NSError *error = nil;
    ZDKChatEngine* chatEngine = [ZDKChatEngine engineAndReturnError: &error];
    UIViewController *chatController = [ZDKMessaging.instance buildUIWithEngines:@[chatEngine]
                                                                        configs:@[messagingConfiguration, chatConfiguration]
                                                                          error:&error];

    UIViewController *topController = [UIApplication sharedApplication].keyWindow.rootViewController;
    while (topController.presentedViewController) {
        topController = topController.presentedViewController;
    }
    [topController presentViewController:chatController animated:YES completion:nil];
  });
}

RCT_EXPORT_METHOD(init:(NSString *)zenDeskKey) {
  [ZDKChat initializeWithAccountKey:zenDeskKey queue:dispatch_get_main_queue()];
}

@end
