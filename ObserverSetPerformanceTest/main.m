/*
Created by Rob Mayoff on 7/31/12.
Copyright (c) 2012 Rob Mayoff. All rights reserved.
*/

#import <UIKit/UIKit.h>

#if 0
static void perform(NSString *label, dispatch_block_t block) {
    NSUInteger executionCount = 0;
    setProfileAlarm(5);
    CFAbsoluteTime startTime = CFAbsoluteTimeGetCurrent();
    for ( ; !profileAlarmExpired; ++executionCount) {
        block();
    }
    CFAbsoluteTime endTime = CFAbsoluteTimeGetCurrent();

    NSLog(@"\t%.9f\t%u\t%.9f\tseconds/iterations/seconds-per-iteration to\t%@", endTime - startTime, executionCount, (endTime - startTime) / executionCount, label);
}

static void testCreateAndSendWithNoObservers(void) {
    perform(@"create ObserverSet and send message to proxy with no observers", ^{
        @autoreleasepool {
            ObserverSet *set = [[ObserverSet alloc] init];
            set.protocol = @protocol(PerformanceTestProtocol);
            [set.proxy requiredMessage0WithObject:nil object:nil];
        }
    });
}

static void testSendRequiredMessageWithObservers(NSUInteger observerCount) {
    @autoreleasepool {
        ObserverSet *set = [[ObserverSet alloc] init];
        set.protocol = @protocol(PerformanceTestProtocol);
        NSMutableArray *strongRefs = [[NSMutableArray alloc] init];
        for (NSUInteger i = 0; i < observerCount; ++i) {
            PerformanceTestObserver *observer = [[PerformanceTestObserver alloc] init];
            [strongRefs addObject:observer];
            [set addObserver:observer];
        }

        perform([NSString stringWithFormat:@"send a required message with %u observers", observerCount], ^{
            [set.proxy requiredMessage0WithObject:nil object:nil];
        });
    }
}

static void testSendOptionalMessageWithNonRespondingObservers(NSUInteger observerCount) {
    @autoreleasepool {
        ObserverSet *set = [[ObserverSet alloc] init];
        set.protocol = @protocol(PerformanceTestProtocol);
        NSMutableArray *strongRefs = [[NSMutableArray alloc] init];
        for (NSUInteger i = 0; i < observerCount; ++i) {
            PerformanceTestObserver *observer = [[PerformanceTestObserver alloc] init];
            [strongRefs addObject:observer];
            [set addObserver:observer];
        }

        perform([NSString stringWithFormat:@"send an optional message with %u non-responding observers", observerCount], ^{
            [set.proxy optionalMessage0WithObject:nil object:nil];
        });
    }
}

static void testSendOptionalMessageWithRespondingObservers(NSUInteger observerCount) {
    @autoreleasepool {
        ObserverSet *set = [[ObserverSet alloc] init];
        set.protocol = @protocol(PerformanceTestProtocol);
        NSMutableArray *strongRefs = [[NSMutableArray alloc] init];
        for (NSUInteger i = 0; i < observerCount; ++i) {
            PerformanceTestObserver *observer = [[PerformanceTestObserverWithOptionalMessages alloc] init];
            [strongRefs addObject:observer];
            [set addObserver:observer];
        }

        perform([NSString stringWithFormat:@"send an optional message with %u responding observers", observerCount], ^{
            [set.proxy optionalMessage0WithObject:nil object:nil];
        });
    }
}
#endif

int main(int argc, char *argv[])
{
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, nil);

#if 0
        testCreateAndSendWithNoObservers();
        
        testSendRequiredMessageWithObservers(1);
        testSendRequiredMessageWithObservers(2);
        testSendRequiredMessageWithObservers(3);
        testSendRequiredMessageWithObservers(4);
        testSendRequiredMessageWithObservers(5);
        testSendRequiredMessageWithObservers(10);
        
        testSendOptionalMessageWithNonRespondingObservers(1);
        testSendOptionalMessageWithNonRespondingObservers(2);
        testSendOptionalMessageWithNonRespondingObservers(3);
        testSendOptionalMessageWithNonRespondingObservers(4);
        testSendOptionalMessageWithNonRespondingObservers(5);
        testSendOptionalMessageWithNonRespondingObservers(10);
        
        testSendOptionalMessageWithRespondingObservers(1);
        testSendOptionalMessageWithRespondingObservers(2);
        testSendOptionalMessageWithRespondingObservers(3);
        testSendOptionalMessageWithRespondingObservers(4);
        testSendOptionalMessageWithRespondingObservers(5);
        testSendOptionalMessageWithRespondingObservers(10);

        return 0;
#endif
    }
}

