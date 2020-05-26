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
#import <MessagingSDK/MessagingSDK.h>
#import <CommonUISDK/CommonUISDK.h>
#import <SupportSDK/SupportSDK.h>
#import <ZendeskCoreSDK/ZendeskCoreSDK.h>


@implementation RNZendeskChatModule

RCT_EXPORT_MODULE(RNZendeskChatModule);

NSInteger chatStateInt;
ZDKObservationToken *token;

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
                                                            phoneNumber:options[@"phone"]];
  ZDKChat.instance.configuration = config;

    NSLog(@"Setting visitor info: department: %@ tags: %@, email: %@, name: %@, phone: %@", config.department, config.tags, config.visitorInfo.email, config.visitorInfo.name, config.visitorInfo.phoneNumber);
}

RCT_EXPORT_METHOD(startChat:(NSDictionary *)options) {
    if (token) {
        [token cancel];
    }
    token = [ZDKChat.chatProvider observeChatState:^(ZDKChatState *chatState) {
        chatStateInt = chatState.chatSessionStatus;
    }];
    dispatch_sync(dispatch_get_main_queue(), ^{
  [self setVisitorInfo:options];

  [ZDKCommonTheme currentTheme].primaryColor = [UIColor
                            colorWithRed:75.0f/255.0f green:219.0f/255.0f blue:255.0f/255.0f alpha:1.0f];

  ZDKMessagingConfiguration *messagingConfiguration = [[ZDKMessagingConfiguration alloc] init];
  messagingConfiguration.name = @"VICKY";

  ZDKChatConfiguration *chatConfiguration = [[ZDKChatConfiguration alloc] init];
        chatConfiguration.isAgentAvailabilityEnabled = YES;
        chatConfiguration.isOfflineFormEnabled = YES;
        chatConfiguration.isPreChatFormEnabled = YES;

  ZDKChatFormConfiguration *formConfiguration = [[ZDKChatFormConfiguration alloc] initWithName:ZDKFormFieldStatusRequired
                                                                                       email:ZDKFormFieldStatusOptional
                                                                                 phoneNumber:ZDKFormFieldStatusOptional
                                                                                  department:ZDKFormFieldStatusHidden];
    chatConfiguration.preChatFormConfiguration = formConfiguration;
    NSArray *options = @[@(ZDKChatMenuActionEmailTranscript), @(ZDKChatMenuActionEndChat)];
    [chatConfiguration setChatMenuActions:options];

    NSError *error = nil;
    ZDKChatEngine* chatEngine = [ZDKChatEngine engineAndReturnError: &error];
    UIViewController *chatController = [ZDKMessaging.instance buildUIWithEngines:@[chatEngine]
                                                                        configs:@[messagingConfiguration, chatConfiguration]
                                                                          error:&error];
      if (error) {
          NSLog(@"Error: %@ %@", error, [error userInfo]);
      }
        UIViewController *topController = [UIApplication sharedApplication].keyWindow.rootViewController;
        while (topController.presentedViewController) {
            topController = topController.presentedViewController;
        }
        UINavigationController *navControl = [[UINavigationController alloc] initWithRootViewController: chatController];
        [topController presentViewController:navControl animated:YES completion:nil];
  });
}

RCT_REMAP_METHOD(getChatState, getChatStateWithResolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject)
{
    resolve([NSNumber numberWithInteger:chatStateInt]);
}

RCT_EXPORT_METHOD(initSupport:(NSDictionary *)options) {
  [ZDKZendesk initializeWithAppId:options[@"appId"] clientId:options[@"clientId"] zendeskUrl:options[@"url"]];
  [ZDKSupport initializeWithZendesk:[ZDKZendesk instance]];
}

RCT_EXPORT_METHOD(setUserIdentity:(NSDictionary *)options) {
  id<ZDKObjCIdentity> userIdentity = [[ZDKObjCAnonymous alloc] initWithName:options[@"name"] email:options[@"email"]];
  [[ZDKZendesk instance] setIdentity:userIdentity];
}

RCT_EXPORT_METHOD(showHelpCenter:(NSDictionary *)options) {
    dispatch_sync(dispatch_get_main_queue(), ^{
      UIViewController *helpCenter = [ZDKHelpCenterUi buildHelpCenterOverviewUiWithConfigs:@[]];
      UIViewController *topController = [UIApplication sharedApplication].keyWindow.rootViewController;
      while (topController.presentedViewController) {
        topController = topController.presentedViewController;
      }
      UINavigationController *navControl = [[UINavigationController alloc] initWithRootViewController: helpCenter];
      [topController presentViewController:navControl animated:YES completion:nil];
    });
}

RCT_EXPORT_METHOD(showTickets:(NSDictionary *)options) {
    dispatch_sync(dispatch_get_main_queue(), ^{
          UIViewController *requestListController = [ZDKRequestUi buildRequestList];
          UIViewController *topController = [UIApplication sharedApplication].keyWindow.rootViewController;
          while (topController.presentedViewController) {
            topController = topController.presentedViewController;
          }
          UINavigationController *navControl = [[UINavigationController alloc] initWithRootViewController: requestListController];
          [topController presentViewController:navControl animated:YES completion:nil];
    });
}

RCT_EXPORT_METHOD(init:(NSString *)zenDeskKey) {
  [ZDKChat initializeWithAccountKey:zenDeskKey queue:dispatch_get_main_queue()];
}

RCT_EXPORT_METHOD(sendMessage:(NSString *)message) {
  [ZDKChat.chatProvider sendMessage:message completion:^(NSString *messageId, NSError *error) {
  }];
}
@end
