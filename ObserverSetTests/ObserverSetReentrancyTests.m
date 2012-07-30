/*
Created by Rob Mayoff on 7/30/12.
Copyright (c) 2012 Rob Mayoff. All rights reserved.
*/

#import "ObserverSetReentrancyTests.h"
#import "ObserverSet.h"

@protocol ReentrantTestProtocol
- (void)message;
@end

@interface ReentrantTestObserver : NSObject <ReentrantTestProtocol>
@property (nonatomic, strong) dispatch_block_t block;
@property (nonatomic, readonly) BOOL receivedMessage;
@end

@implementation ObserverSetReentrancyTests {
    ObserverSet *observerSet_;
    ReentrantTestObserver *observer0_;
    ReentrantTestObserver *observer1_;
}

- (void)setUp {
    [super setUp];
    observerSet_ = [[ObserverSet alloc] init];
    observerSet_.protocol = @protocol(ReentrantTestProtocol);
    observer0_ = [[ReentrantTestObserver alloc] init];
    observer1_ = [[ReentrantTestObserver alloc] init];
}

- (void)tearDown {
    observer0_.block = nil;
    observer1_.block = nil;
    [super tearDown];
}

- (void)testObserverSetDoesNotSendMessageToObserverRemovedWhileInCallback {
    __unsafe_unretained ObserverSetReentrancyTests *me = self;
    
    observer0_.block = ^{
        [me->observerSet_ removeObserver:me->observer1_];
    };

    observer1_.block = ^{
        [me->observerSet_ removeObserver:me->observer0_];
    };

    [observerSet_ addObserver:observer0_];
    [observerSet_ addObserver:observer1_];
    [observerSet_.requiredMessageProxy message];

    STAssertTrue(observer0_.receivedMessage ^ observer1_.receivedMessage, @"only one of the observers received the message");
}

- (void)testObserverSetDoesNotSendMessageToObserverAddingWhileInCallback {
    __unsafe_unretained ObserverSetReentrancyTests *me = self;
    observer0_.block = ^{
        [me->observerSet_ addObserver:me->observer1_];
    };

    [observerSet_ addObserver:observer0_];
    [observerSet_.requiredMessageProxy message];

    STAssertTrue(observer0_.receivedMessage, @"observer0 received the message");
    STAssertFalse(observer1_.receivedMessage, @"observer1 didn't receive the message");
}

@end

@implementation ReentrantTestObserver

- (void)message {
    _receivedMessage = YES;
    if (_block) {
        _block();
    }
}

@end
