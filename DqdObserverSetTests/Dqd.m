/*
Created by Rob Mayoff on 7/30/12.
This file is public domain.
*/

#import "DqdObserverSetTests.h"
#import "DqdObserverSet.h"

@protocol TestProtocol

@required
- (void)requiredMessageWithNoArguments;
- (void)requiredMessageWithObject:(id)object;
- (void)requiredMessageWithObject:(id)object0 object:(id)object1;

@optional

- (void)optionalMessageWithNoArguments;
- (void)optionalMessageWithObject:(id)object;
- (void)optionalMessageWithObject:(id)object0 object:(id)object1;

@end

@interface TestObserver : NSObject {
    NSUInteger messageCount_;
    SEL receivedSelector_;
    NSArray *receivedArguments_;
}

// Imperative
- (void)didReceiveMessageWithSelector:(SEL)selector arguments:(NSArray *)arguments;

// Inquisitive
- (BOOL)receivedExactlyOneMessage;
- (BOOL)receivedNoMessages;
- (BOOL)receivedMessageWithSelector:(SEL)selector arguments:(NSArray *)arguments;

@end

@interface RequiredMessagesObserver : TestObserver <TestProtocol>
@end

@interface OptionalMessagesObserver : RequiredMessagesObserver <TestProtocol>
@end

@implementation DqdObserverSetTests {
    DqdObserverSet *observerSet_;
    NSMutableArray *observers_;
}

- (void)setUp {
    [super setUp];
    observerSet_ = [[DqdObserverSet alloc] initWithProtocol:@protocol(TestProtocol)];
    observers_ = [[NSMutableArray alloc] init];
}

- (void)addRequiredMessagesObserver {
    RequiredMessagesObserver *observer = [[RequiredMessagesObserver alloc] init];
    [observers_ addObject:observer];
    [observerSet_ addObserver:observer];
}

- (void)addOptionalMessagesObserver {
    OptionalMessagesObserver *observer = [[OptionalMessagesObserver alloc] init];
    [observers_ addObject:observer];
    [observerSet_ addObserver:observer];
}

- (void)verifyObserversReceivedMessageWithSelector:(SEL)selector arguments:(NSArray *)arguments {
    for (TestObserver *observer in observers_) {
        STAssertTrue([observer receivedExactlyOneMessage], @"observer received only one message");
        STAssertTrue([observer receivedMessageWithSelector:selector arguments:arguments], @"observer received expected message");
    }
}

- (void)verifyObserversReceivedOptionalMessageIfImplementedWithSelector:(SEL)selector arguments:(NSArray *)arguments {
    for (TestObserver *observer in observers_) {
        if ([observer respondsToSelector:selector]) {
            STAssertTrue([observer receivedExactlyOneMessage], @"observer received only one message");
            STAssertTrue([observer receivedMessageWithSelector:selector arguments:arguments], @"observer received expected message");
        } else {
            STAssertTrue([observer receivedNoMessages], @"observer received no messages");
        }
    }
}

- (void)testObserverSetSendsRequiredMessageToAllObservers {
    [self addRequiredMessagesObserver];
    [self addRequiredMessagesObserver];
    [observerSet_.proxy requiredMessageWithNoArguments];
    [self verifyObserversReceivedMessageWithSelector:@selector(requiredMessageWithNoArguments) arguments:@[]];
}

- (void)testObserverSetForgetsRemovedObserver {
    [self addRequiredMessagesObserver];
    [self addRequiredMessagesObserver];
    TestObserver *removedObserver = [observers_ lastObject];
    [observers_ removeLastObject];
    [observerSet_ removeObserver:removedObserver];
    [observerSet_.proxy requiredMessageWithNoArguments];
    STAssertTrue([removedObserver receivedNoMessages], @"removed observer received no messages");
}

- (void)testObserverSetSendsOptionalMessageToImplementingObservers {
    [self addRequiredMessagesObserver];
    [self addOptionalMessagesObserver];
    [observerSet_.proxy optionalMessageWithNoArguments];
    [self verifyObserversReceivedOptionalMessageIfImplementedWithSelector:@selector(optionalMessageWithNoArguments) arguments:@[]];
}

- (void)testObserverSetSendsRequiredMessageWithNoArguments {
    [self addRequiredMessagesObserver];
    [observerSet_.proxy requiredMessageWithNoArguments];
    [self verifyObserversReceivedMessageWithSelector:@selector(requiredMessageWithNoArguments) arguments:@[]];
}

- (void)testObserverSetSendsRequiredMessageWithOneArgument {
    [self addRequiredMessagesObserver];
    id argument = @"hello";
    [observerSet_.proxy requiredMessageWithObject:argument];
    [self verifyObserversReceivedMessageWithSelector:@selector(requiredMessageWithObject:) arguments:@[argument]];
}

- (void)testObserverSetSendsRequiredMessageWithTwoArguments {
    [self addRequiredMessagesObserver];
    id argument0 = @"hello";
    id argument1 = @"world";
    [observerSet_.proxy requiredMessageWithObject:argument0 object:argument1];
    [self verifyObserversReceivedMessageWithSelector:@selector(requiredMessageWithObject:object:) arguments:@[argument0, argument1]];
}

- (void)testObserverSetSendsOptionalMessageWithNoArguments {
    [self addOptionalMessagesObserver];
    [observerSet_.proxy optionalMessageWithNoArguments];
    [self verifyObserversReceivedMessageWithSelector:@selector(optionalMessageWithNoArguments) arguments:@[]];
}

- (void)testObserverSetSendsOptionalMessageWithOneArgument {
    [self addOptionalMessagesObserver];
    id argument = @"hello";
    [observerSet_.proxy optionalMessageWithObject:argument];
    [self verifyObserversReceivedMessageWithSelector:@selector(optionalMessageWithObject:) arguments:@[argument]];
}

- (void)testObserverSetSendsOptionalMessageWithTwoArguments {
    [self addOptionalMessagesObserver];
    id argument0 = @"hello";
    id argument1 = @"world";
    [observerSet_.proxy optionalMessageWithObject:argument0 object:argument1];
    [self verifyObserversReceivedMessageWithSelector:@selector(optionalMessageWithObject:object:) arguments:@[argument0, argument1]];
}

@end

@implementation TestObserver

- (void)didReceiveMessageWithSelector:(SEL)selector arguments:(NSArray *)arguments {
    messageCount_ += 1;
    if (messageCount_ > 1)
        return;
    receivedSelector_ = selector;
    receivedArguments_ = [arguments copy];
}

- (BOOL)receivedExactlyOneMessage {
    return messageCount_ == 1;
}

- (BOOL)receivedNoMessages {
    return messageCount_ == 0;
}

- (BOOL)receivedMessageWithSelector:(SEL)selector arguments:(NSArray *)arguments {
    return selector == receivedSelector_ && [arguments isEqual:receivedArguments_];
}

@end

@implementation RequiredMessagesObserver

- (void)requiredMessageWithNoArguments {
    [self didReceiveMessageWithSelector:_cmd arguments:@[]];
}

- (void)requiredMessageWithObject:(id)object {
    [self didReceiveMessageWithSelector:_cmd arguments:@[object]];
}

- (void)requiredMessageWithObject:(id)object0 object:(id)object1 {
    [self didReceiveMessageWithSelector:_cmd arguments:@[object0, object1]];
}

@end

@implementation OptionalMessagesObserver

- (void)optionalMessageWithNoArguments {
    [self didReceiveMessageWithSelector:_cmd arguments:@[]];
}

- (void)optionalMessageWithObject:(id)object {
    [self didReceiveMessageWithSelector:_cmd arguments:@[object]];
}

- (void)optionalMessageWithObject:(id)object0 object:(id)object1 {
    [self didReceiveMessageWithSelector:_cmd arguments:@[object0, object1]];
}

@end
