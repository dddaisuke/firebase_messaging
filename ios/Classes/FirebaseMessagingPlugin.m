// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "FirebaseMessagingPlugin.h"

#import "Firebase/Firebase.h"

#if defined(__IPHONE_10_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_10_0
@interface FLTFirebaseMessagingPlugin ()<FIRMessagingDelegate>
@end
#endif

@implementation FLTFirebaseMessagingPlugin {
  FlutterMethodChannel *_channel;
  NSDictionary *_launchNotification;
  BOOL _resumingFromBackground;
}

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar> *)registrar {
  FlutterMethodChannel *channel =
      [FlutterMethodChannel methodChannelWithName:@"plugins.flutter.io/firebase_messaging"
                                  binaryMessenger:[registrar messenger]];
  FLTFirebaseMessagingPlugin *instance =
      [[FLTFirebaseMessagingPlugin alloc] initWithChannel:channel];

    if(@available(iOS 10.0, *)) {
        UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
        center.delegate = instance;
    }
    [registrar addApplicationDelegate:instance];
  [registrar addMethodCallDelegate:instance channel:channel];
}

- (instancetype)initWithChannel:(FlutterMethodChannel *)channel {
  self = [super init];

  if (self) {
    _channel = channel;
    _resumingFromBackground = NO;
    if (![FIRApp defaultApp]) {
      [FIRApp configure];
    }
    [FIRMessaging messaging].delegate = self;
  }
  return self;
}

- (void)userNotificationCenter:(UNUserNotificationCenter *)center
didReceiveNotificationResponse:(UNNotificationResponse *)response
         withCompletionHandler:(void (^)())completionHandler {
    completionHandler();
}

- (void)userNotificationCenter:(UNUserNotificationCenter *)center
       willPresentNotification:(UNNotification *)notification
         withCompletionHandler:(void (^)(UNNotificationPresentationOptions))completionHandler {
    // アプリがフォアグランドにいた場合の通知動作を指定する。
    completionHandler(UNNotificationPresentationOptionBadge |
                      UNNotificationPresentationOptionSound |
                      UNNotificationPresentationOptionAlert);
};

// アプリが foreground の時に通知を受け取った時に呼ばれるメソッド
func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: (UNNotificationPresentationOptions) -> Void) {
    print("fire! notification ID:\(notification.request.identifier)")

}

- (void)handleMethodCall:(FlutterMethodCall *)call result:(FlutterResult)result {
  NSString *method = call.method;
  if ([@"requestNotificationPermissions" isEqualToString:method]) {
    UIUserNotificationType notificationTypes = 0;
    NSDictionary *arguments = call.arguments;
    if (arguments[@"sound"]) {
      notificationTypes |= UIUserNotificationTypeSound;
    }
    if (arguments[@"alert"]) {
      notificationTypes |= UIUserNotificationTypeAlert;
    }
    if (arguments[@"badge"]) {
      notificationTypes |= UIUserNotificationTypeBadge;
    }
    UIUserNotificationSettings *settings =
        [UIUserNotificationSettings settingsForTypes:notificationTypes categories:nil];
    [[UIApplication sharedApplication] registerUserNotificationSettings:settings];

    result(nil);
  } else if ([@"configure" isEqualToString:method]) {
    [[UIApplication sharedApplication] registerForRemoteNotifications];
    if (_launchNotification != nil) {
      [_channel invokeMethod:@"onLaunch" arguments:_launchNotification];
    }
    result(nil);
  } else if ([@"subscribeToTopic" isEqualToString:method]) {
    NSString *topic = call.arguments;
    [[FIRMessaging messaging] subscribeToTopic:topic];
    result(nil);
  } else if ([@"unsubscribeFromTopic" isEqualToString:method]) {
    NSString *topic = call.arguments;
    [[FIRMessaging messaging] unsubscribeFromTopic:topic];
    result(nil);
  } else {
    result(FlutterMethodNotImplemented);
  }
}

#if defined(__IPHONE_10_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_10_0
// Receive data message on iOS 10 devices while app is in the foreground.
- (void)applicationReceivedRemoteMessage:(FIRMessagingRemoteMessage *)remoteMessage {
  [self didReceiveRemoteNotification:remoteMessage.appData];
}
#endif

- (void)didReceiveRemoteNotification:(NSDictionary *)userInfo {
  if (_resumingFromBackground) {
    [_channel invokeMethod:@"onResume" arguments:userInfo];
  } else {
    [_channel invokeMethod:@"onMessage" arguments:userInfo];
  }
}

#pragma mark - AppDelegate

- (BOOL)application:(UIApplication *)application
    didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
  if (launchOptions != nil) {
      NSLog("aaa");
    _launchNotification = launchOptions[UIApplicationLaunchOptionsRemoteNotificationKey];
  }
  return YES;
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
  _resumingFromBackground = YES;
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
  _resumingFromBackground = NO;
  // Clears push notifications from the notification center, with the
  // side effect of resetting the badge count. We need to clear notifications
  // because otherwise the user could tap notifications in the notification
  // center while the app is in the foreground, and we wouldn't be able to
  // distinguish that case from the case where a message came in and the
  // user dismissed the notification center without tapping anything.
  // TODO(goderbauer): Revisit this behavior once we provide an API for managing
  // the badge number, or if we add support for running Dart in the background.
  // Setting badgeNumber to 0 is a no-op (= notifications will not be cleared)
  // if it is already 0,
  // therefore the next line is setting it to 1 first before clearing it again
  // to remove all
  // notifications.
  application.applicationIconBadgeNumber = 1;
  application.applicationIconBadgeNumber = 0;
}

- (bool)application:(UIApplication *)application
    didReceiveRemoteNotification:(NSDictionary *)userInfo
          fetchCompletionHandler:(void (^)(UIBackgroundFetchResult result))completionHandler {
  [self didReceiveRemoteNotification:userInfo];
  completionHandler(UIBackgroundFetchResultNoData);
  return YES;
}

- (void)application:(UIApplication *)application didReceiveLocalNotification:(UILocalNotification *)notification {

    NSLog("zzz");
    var alert = UIAlertView();
    alert.title = "Message";
    alert.message = notification.alertBody;
    alert.addButtonWithTitle(notification.alertAction);
    alert.show();

    NSLog(notification.alertBody);
    NSLog(notification.fireDate);
  NSDictionary *localNotification = [NSDictionary dictionaryWithObjectsAndKeys:
    notification.fireDate, @"fireDate",
    notification.alertBody, @"alertBody",
                                     nil];

  if (application.applicationState == UIApplicationStateActive) {
    //パターン２：画面が既に表示されていて通知が飛んできた時に勝手に呼ばれる
    [_channel invokeMethod:@"onStateActive" arguments:localNotification];
    return;
  }

  if (application.applicationState == UIApplicationStateInactive) {
    //パターン３：アプリがバックグラウンドでは生きている時に通知をタップ
    [_channel invokeMethod:@"onStateInactive" arguments:localNotification];
    return;
  }

  [[UIApplication sharedApplication] cancelLocalNotification:notification];
}

- (void)application:(UIApplication *)application
    didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
#ifdef DEBUG
  [[FIRMessaging messaging] setAPNSToken:deviceToken type:FIRMessagingAPNSTokenTypeSandbox];
#else
  [[FIRMessaging messaging] setAPNSToken:deviceToken type:FIRMessagingAPNSTokenTypeProd];
#endif

  [_channel invokeMethod:@"onToken" arguments:[[FIRInstanceID instanceID] token]];
}

- (void)application:(UIApplication *)application
    didRegisterUserNotificationSettings:(UIUserNotificationSettings *)notificationSettings {
  NSDictionary *settingsDictionary = @{
    @"sound" : [NSNumber numberWithBool:notificationSettings.types & UIUserNotificationTypeSound],
    @"badge" : [NSNumber numberWithBool:notificationSettings.types & UIUserNotificationTypeBadge],
    @"alert" : [NSNumber numberWithBool:notificationSettings.types & UIUserNotificationTypeAlert],
  };
  [_channel invokeMethod:@"onIosSettingsRegistered" arguments:settingsDictionary];
}

- (void)messaging:(nonnull FIRMessaging *)messaging
    didReceiveRegistrationToken:(nonnull NSString *)fcmToken {
  [_channel invokeMethod:@"onToken" arguments:fcmToken];
}

@end
