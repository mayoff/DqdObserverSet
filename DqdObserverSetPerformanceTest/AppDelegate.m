/*
Created by Rob Mayoff on 8/1/12.
This file is public domain.
*/

#import "AppDelegate.h"

@implementation AppDelegate {
    IBOutlet UIWindow *window_;
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    [window_ makeKeyAndVisible];
    return YES;
}

@end
