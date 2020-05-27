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

#define UIColorFromRGB(rgbValue) [UIColor colorWithRed:((float)((rgbValue & 0xFF0000) >> 16))/255.0 green:((float)((rgbValue & 0xFF00) >> 8))/255.0 blue:((float)(rgbValue & 0xFF))/255.0 alpha:1.0]

@implementation RNZendeskChatModule

RCT_EXPORT_MODULE(RNZendeskChatModule);

NSInteger chatStateInt;
ZDKObservationToken *token;
NSDictionary* lastUsedChatOptions;
UIButton *globalChatButton;


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
    [self startChatFunction:options];
}

- (void) startChatFunction:(NSDictionary *)options {
    lastUsedChatOptions = options;
    if (token) {
        [token cancel];
    }
    token = [ZDKChat.chatProvider observeChatState:^(ZDKChatState *chatState) {
        chatStateInt = chatState.chatSessionStatus;
        if (chatStateInt == 3 || chatStateInt == 4) {
            [self removeGlobalChatButton];
        }
    }];
    dispatch_block_t block = ^
    {
        [self setVisitorInfo:options];
        UIColor* tintColor = [UIColor
                              colorWithRed:73.0f/255.0f green:223.0f/255.0f blue:174.0f/255.0f alpha:1.0f];
        [ZDKCommonTheme currentTheme].primaryColor = tintColor;

        ZDKMessagingConfiguration *messagingConfiguration = [[ZDKMessagingConfiguration alloc] init];
        messagingConfiguration.name = options[@"agentName"];

        ZDKChatConfiguration *chatConfiguration = [[ZDKChatConfiguration alloc] init];
            chatConfiguration.isAgentAvailabilityEnabled = YES;
            chatConfiguration.isOfflineFormEnabled = YES;
            chatConfiguration.isPreChatFormEnabled = YES;

        ZDKChatFormConfiguration *formConfiguration = [[ZDKChatFormConfiguration alloc] initWithName:ZDKFormFieldStatusRequired
                                                                                           email:ZDKFormFieldStatusOptional
                                                                                     phoneNumber:ZDKFormFieldStatusOptional
                                                                                      department:ZDKFormFieldStatusHidden];
        chatConfiguration.preChatFormConfiguration = formConfiguration;
        NSArray *topRightActions = @[@(ZDKChatMenuActionEmailTranscript), @(ZDKChatMenuActionEndChat)];
        [chatConfiguration setChatMenuActions:topRightActions];

        NSError *error = nil;
        ZDKChatEngine* chatEngine = [ZDKChatEngine engineAndReturnError: &error];
        UIViewController *chatController = [ZDKMessaging.instance buildUIWithEngines:@[chatEngine]
                                                                            configs:@[messagingConfiguration, chatConfiguration]
                                                                              error:&error];
        if (error) {
            NSLog(@"Error: %@ %@", error, [error userInfo]);
        }
        UIImage* chevronDown = [UIImage imageNamed:@"chevron_down" inBundle:[self getResourcesBundle] compatibleWithTraitCollection:nil];
        UIBarButtonItem* leftBarItem = [[UIBarButtonItem alloc] initWithImage:chevronDown
                                                                        style:UIBarButtonItemStylePlain target:self action:@selector(chatClosedClicked)];
        leftBarItem.tintColor = tintColor;
        chatController.navigationItem.leftBarButtonItem = leftBarItem;
        UIViewController *topController = [UIApplication sharedApplication].keyWindow.rootViewController;
        while (topController.presentedViewController) {
            topController = topController.presentedViewController;
        }
        UINavigationController *navControl = [[UINavigationController alloc] initWithRootViewController: chatController];
        [topController presentViewController:navControl animated:YES completion:nil];
        
        if (!globalChatButton) {
            [self addGlobalChatButton: options];
        }
    };
    if ([NSThread isMainThread]) {
        block();
    } else {
        dispatch_sync(dispatch_get_main_queue(), block);
    }
}

- (NSBundle *) getResourcesBundle {
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    return bundle;
}

- (void) chatClosedClicked {
    UIViewController *topController = [UIApplication sharedApplication].keyWindow.rootViewController;
    while (topController.presentedViewController) {
        topController = topController.presentedViewController;
    }
    [topController dismissViewControllerAnimated:TRUE completion:NULL];
}

- (void) addGlobalChatButton: (NSDictionary *)options {
    UIWindow* mainWindow = [[UIApplication sharedApplication] keyWindow];
    globalChatButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [globalChatButton addTarget:self
               action:@selector(globalChatButtonClicked)
     forControlEvents:UIControlEventTouchUpInside];
    [globalChatButton setTitle:options[@"retainButtonTitle"] forState:UIControlStateNormal];
    globalChatButton.backgroundColor = UIColorFromRGB(0x49dfae);
    globalChatButton.layer.cornerRadius = 8.0;
    globalChatButton.clipsToBounds = TRUE;
    globalChatButton.frame = CGRectMake(20.0, mainWindow.frame.size.height - 150, 100.0, 40.0);
    [mainWindow addSubview:globalChatButton];
}

- (void) removeGlobalChatButton {
    if (!globalChatButton) {
        return;
    }
    [globalChatButton removeFromSuperview];
    globalChatButton = NULL;
}

- (void) globalChatButtonClicked {
    [self startChatFunction:lastUsedChatOptions];
}

RCT_REMAP_METHOD(getChatState, getChatStateWithResolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject)
{
    resolve([NSNumber numberWithInteger:chatStateInt]);
}

RCT_EXPORT_METHOD(initSupport:(NSDictionary *)options) {
    [ZDKCoreLogger setEnabled:YES];
    [ZDKCoreLogger setLogLevel:ZDKLogLevelDebug];
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
