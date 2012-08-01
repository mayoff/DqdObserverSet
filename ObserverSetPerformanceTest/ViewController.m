/*
Created by Rob Mayoff on 8/1/12.
Copyright (c) 2012 Rob Mayoff. All rights reserved.
*/

#import "ViewController.h"
#import "PerformanceTestProtocol.h"
#import "PerformanceTestObserver.h"
#import "PerformanceTestObserverWithOptionalMessages.h"
#import <ObserverSet/ObserverSet.h>
#import <sys/time.h>

@interface ViewController ()

@end

@implementation ViewController {
    IBOutlet UITextView *textView_;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return YES;
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    dispatch_queue_t queue = dispatch_queue_create("com.dqd.ObserverSetPerformanceTest", 0);
    dispatch_async(queue, ^{
        [self runTests];
    });
}

static volatile sig_atomic_t profileAlarmExpired;

+ (void)setProfileAlarm:(NSTimeInterval)duration {
    profileAlarmExpired = 0;
    dispatch_sync(dispatch_get_main_queue(), ^{
        NSTimer *timer = [NSTimer timerWithTimeInterval:duration target:self selector:@selector(profileAlarmDidExpire:) userInfo:nil repeats:NO];
        [[NSRunLoop mainRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
    });
}

+ (void)profileAlarmDidExpire:(NSTimer *)timer {
    profileAlarmExpired = 1;
    [timer invalidate];
}

typedef struct {
    CFTimeInterval elapsed;
    NSUInteger iterations;
} PerformanceData;

#define TestPreamble \
    NSUInteger executionCount = 0; \
    [[ViewController class] setProfileAlarm:5]; \
    CFAbsoluteTime startTime = CFAbsoluteTimeGetCurrent(); \
    for ( ; !profileAlarmExpired; ++executionCount) \

#define TestPostamble \
    CFAbsoluteTime endTime = CFAbsoluteTimeGetCurrent(); \
    return (PerformanceData){ .elapsed = endTime - startTime, .iterations = executionCount };

static PerformanceData testCreateAndSendWithNoObservers(void) {
    TestPreamble {
        @autoreleasepool {
            ObserverSet *set = [[ObserverSet alloc] init];
            set.protocol = @protocol(PerformanceTestProtocol);
            [set.proxy requiredMessage0WithObject:nil object:nil];
        }
    } TestPostamble
}

static PerformanceData testSendRequiredMessageWithObserverCount(NSUInteger observerCount) {
    ObserverSet *set = [[ObserverSet alloc] init];
    set.protocol = @protocol(PerformanceTestProtocol);
    NSMutableArray *strongRefs = [[NSMutableArray alloc] init];
    for (NSUInteger i = 0; i < observerCount; ++i) {
        PerformanceTestObserver *observer = [[PerformanceTestObserver alloc] init];
        [strongRefs addObject:observer];
        [set addObserver:observer];
    }

    TestPreamble {
        [set.proxy requiredMessage0WithObject:nil object:nil];
    } TestPostamble
}

static PerformanceData testSendIgnoredOptionalMessageWithObserverCount(NSUInteger observerCount) {
    ObserverSet *set = [[ObserverSet alloc] init];
    set.protocol = @protocol(PerformanceTestProtocol);
    NSMutableArray *strongRefs = [[NSMutableArray alloc] init];
    for (NSUInteger i = 0; i < observerCount; ++i) {
        PerformanceTestObserver *observer = [[PerformanceTestObserver alloc] init];
        [strongRefs addObject:observer];
        [set addObserver:observer];
    }

    TestPreamble {
        [set.proxy optionalMessage0WithObject:nil object:nil];
    } TestPostamble
}

static PerformanceData testSendHandledOptionalMessageWithObserverCount(NSUInteger observerCount) {
    ObserverSet *set = [[ObserverSet alloc] init];
    set.protocol = @protocol(PerformanceTestProtocol);
    NSMutableArray *strongRefs = [[NSMutableArray alloc] init];
    for (NSUInteger i = 0; i < observerCount; ++i) {
        PerformanceTestObserver *observer = [[PerformanceTestObserverWithOptionalMessages alloc] init];
        [strongRefs addObject:observer];
        [set addObserver:observer];
    }

    TestPreamble {
        [set.proxy optionalMessage0WithObject:nil object:nil];
    } TestPostamble
}

- (void)logTestWithLabel:(NSString *)label block:(PerformanceData (^)(void))block {
    @autoreleasepool {
        PerformanceData data = block();
        NSString *message = [NSString stringWithFormat:@"%.9f\t%u\t%@\n", data.elapsed, data.iterations, label];
        fputs(message.UTF8String, stdout);
        fflush(stdout);
        [self appendMessage:message];
    }
    usleep(500000); // wait for the UI update to finish (hopefully) so it won't affect the next performance test
}

- (void)logTestSendingWithLabel:(NSString *)label testFunction:(PerformanceData (*)(NSUInteger))testFunction {
    for (NSUInteger count = 0; count <= 5; ++count) {
        [self logTestWithLabel:[NSString stringWithFormat:@"%u\t%@", count, label] block:^PerformanceData{
            return testFunction(count);
        }];
    }
    for (NSUInteger count = 10; count <= 25; count += 5) {
        [self logTestWithLabel:[NSString stringWithFormat:@"%u\t%@", count, label] block:^PerformanceData{
            return testFunction(count);
        }];
    }
}

- (void)runTests {
    @autoreleasepool {
        [self appendMessage:@"starting\n"];

        [self logTestWithLabel:@"\ttestCreateAndSendWithNoObservers" block:^{
            return testCreateAndSendWithNoObservers();
        }];

        [self logTestSendingWithLabel:@"testSendingRequiredMessageWithObserverCount" testFunction:testSendRequiredMessageWithObserverCount];
        [self logTestSendingWithLabel:@"testSendingIgnoredOptionalMessageWithObserverCount" testFunction:testSendIgnoredOptionalMessageWithObserverCount];
        [self logTestSendingWithLabel:@"testSendingHandledOptionalMessageWithObserverCount" testFunction:testSendHandledOptionalMessageWithObserverCount];
        
        [self appendMessage:@"done\n"];
    }
}

- (void)appendMessage:(NSString *)message {
    dispatch_sync(dispatch_get_main_queue(), ^{
        UITextPosition *end = textView_.endOfDocument;
        UITextRange *endRange = [textView_ textRangeFromPosition:end toPosition:end];
        [textView_ replaceRange:endRange withText:message];
        [textView_ scrollRangeToVisible:NSMakeRange(textView_.text.length, 0)];
    });
}

@end
