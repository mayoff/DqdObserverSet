/*
Created by Rob Mayoff on 7/31/12.
Copyright (c) 2012 Rob Mayoff. All rights reserved.
*/

#import <UIKit/UIKit.h>
#import <ObserverSet/ObserverSet.h>
#import <sys/time.h>

@protocol PerformanceTestProtocol <NSObject>

- (void)requiredMessage0WithObject:(id)object0 object:(id)object1;
- (void)requiredMessage1WithObject:(id)object0 object:(id)object1;
- (void)requiredMessage2WithObject:(id)object0 object:(id)object1;
- (void)requiredMessage3WithObject:(id)object0 object:(id)object1;
- (void)requiredMessage4WithObject:(id)object0 object:(id)object1;

@optional

- (void)optionalMessage0WithObject:(id)object0 object:(id)object1;
- (void)optionalMessage1WithObject:(id)object0 object:(id)object1;
- (void)optionalMessage2WithObject:(id)object0 object:(id)object1;
- (void)optionalMessage3WithObject:(id)object0 object:(id)object1;
- (void)optionalMessage4WithObject:(id)object0 object:(id)object1;

@end

@interface PerformanceTestObserver : NSObject <PerformanceTestProtocol>
@end

@interface PerformanceTestObserverWithOptionalMessages : PerformanceTestObserver
@end

static volatile sig_atomic_t profileAlarmExpired;

static void signalHandler(int signalNumber) {
    profileAlarmExpired = 1;
}

static void setProfileAlarm(NSTimeInterval duration) {
    struct sigaction sa;
    memset(&sa, 0, sizeof sa);
    sa.sa_handler = signalHandler;
    sigaction(SIGALRM, &sa, NULL);
    sigaction(SIGVTALRM, &sa, NULL);
    sigaction(SIGPROF, &sa, NULL);

    struct itimerval itimer = {
        .it_interval = { 0 },
        .it_value = (struct timeval){
            .tv_sec = (long)duration,
            .tv_usec = (long)(duration / 1000000)
        }
    };
    profileAlarmExpired = 0;
    setitimer(ITIMER_REAL, &itimer, NULL);
}

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

int main(int argc, char *argv[])
{
    @autoreleasepool {
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
    }
}

@implementation PerformanceTestObserver

- (void)requiredMessage0WithObject:(id)object0 object:(id)object1 { }
- (void)requiredMessage1WithObject:(id)object0 object:(id)object1 { }
- (void)requiredMessage2WithObject:(id)object0 object:(id)object1 { }
- (void)requiredMessage3WithObject:(id)object0 object:(id)object1 { }
- (void)requiredMessage4WithObject:(id)object0 object:(id)object1 { }

@end

@implementation PerformanceTestObserverWithOptionalMessages

- (void)optionalMessage0WithObject:(id)object0 object:(id)object1 { }
- (void)optionalMessage1WithObject:(id)object0 object:(id)object1 { }
- (void)optionalMessage2WithObject:(id)object0 object:(id)object1 { }
- (void)optionalMessage3WithObject:(id)object0 object:(id)object1 { }
- (void)optionalMessage4WithObject:(id)object0 object:(id)object1 { }

@end

