/*
Created by Rob Mayoff on 7/30/12.
This file is public domain.
*/

#import "DqdObserverSetReentrancyTests.h"
#import "DqdObserverSet.h"

@protocol ReentrantTestProtocol
- (void)message;
@end

@interface ReentrantTestObserver : NSObject <ReentrantTestProtocol>
@property (nonatomic, strong) dispatch_block_t block;
@property (nonatomic) BOOL receivedMessage;
@end

@implementation DqdObserverSetReentrancyTests {
    DqdObserverSet *observerSet_;
    ReentrantTestObserver *observer0_;
    ReentrantTestObserver *observer1_;
}

- (void)setUp {
    [super setUp];
    observerSet_ = [[DqdObserverSet alloc] initWithProtocol:@protocol(ReentrantTestProtocol)];
    observer0_ = [[ReentrantTestObserver alloc] init];
    observer1_ = [[ReentrantTestObserver alloc] init];
}

- (void)tearDown {
    observer0_.block = nil;
    observer1_.block = nil;
    [super tearDown];
}

- (void)testObserverSetDoesNotSendMessageToObserverRemovedWhileInCallback {
    __unsafe_unretained DqdObserverSetReentrancyTests *me = self;
    
    observer0_.block = ^{
        [me->observerSet_ removeObserver:me->observer1_];
    };

    observer1_.block = ^{
        [me->observerSet_ removeObserver:me->observer0_];
    };

    [observerSet_ addObserver:observer0_];
    [observerSet_ addObserver:observer1_];
    [observerSet_.proxy message];

    STAssertTrue(observer0_.receivedMessage ^ observer1_.receivedMessage, @"only one of the observers received the message");
}

- (void)testObserverSetDoesNotSendMessageToObserverAddingWhileInCallback {
    __unsafe_unretained DqdObserverSetReentrancyTests *me = self;
    observer0_.block = ^{
        [me->observerSet_ addObserver:me->observer1_];
    };

    [observerSet_ addObserver:observer0_];
    [observerSet_.proxy message];

    STAssertTrue(observer0_.receivedMessage, @"observer0 received the message");
    STAssertFalse(observer1_.receivedMessage, @"observer1 didn't receive the message");
}

- (void)testObserverSetForgetsObserverThatIsAddedThenDeletedWhileInCallback {
    __unsafe_unretained DqdObserverSetReentrancyTests *me = self;
    observer0_.block = ^{
        [me->observerSet_ addObserver:me->observer1_];
        [me->observerSet_ removeObserver:me->observer1_];
    };

    [observerSet_  addObserver:observer0_];
    [observerSet_.proxy message];

    // Now make sure observer1_ isn't in observerSet_.
    [observerSet_.proxy message];
    STAssertFalse(observer1_.receivedMessage, @"observer1 didn't receive any messages");
}

- (void)testObserverSetRemembersObserverThatIsDeletedThenAddedWhileInCallback {
    __unsafe_unretained DqdObserverSetReentrancyTests *me = self;
    observer0_.block = ^{
        [me->observerSet_ removeObserver:me->observer1_];
        [me->observerSet_ addObserver:me->observer1_];
    };

    [observerSet_  addObserver:observer0_];
    [observerSet_.proxy message];
    STAssertFalse(observer1_.receivedMessage, @"observer1 didn't receive a message on the first send");

    // Now make sure observer1_ is in observerSet_.
    observer0_.block = nil;
    [observerSet_.proxy message];
    STAssertTrue(observer1_.receivedMessage, @"observer1 received a message on the second send");
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
