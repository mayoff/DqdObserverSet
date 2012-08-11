#import "DqdObserverSet.h"
#import <objc/runtime.h>

@interface DqdObserverSetMessageProxy : NSObject
@property (nonatomic,unsafe_unretained) DqdObserverSet *observerSet;
@end

@implementation DqdObserverSet {
    NSMutableSet *observers_;
    NSMutableSet *pendingObservers_;
}

#pragma mark - Public API

@synthesize proxy = _proxy;

- (id)initWithProtocol:(Protocol *)protocol {
    if (self = [super init]) {
        _protocol = protocol;
        _proxy = [[DqdObserverSetMessageProxy alloc] init];
        [_proxy setObserverSet:self];
    }
    return self;
}

- (void)addObserver:(id)observer {
    if (!observers_) {
        // Create a non-retaining set.
        observers_ = CFBridgingRelease(CFSetCreateMutable(NULL, 0,
            &(CFSetCallBacks){
                .equal = kCFTypeSetCallBacks.equal,
                .hash = kCFTypeSetCallBacks.hash
        }));
    }
    [observers_ addObject:observer];
}

- (void)removeObserver:(id)observer {
    [observers_ removeObject:observer];
    [pendingObservers_ removeObject:observer];
}

#pragma mark - DqdObserverSetMessageProxy API

- (void)forwardInvocationToObservers:(NSInvocation *)invocation {
    pendingObservers_ = CFBridgingRelease(
        CFSetCreateMutableCopy(NULL, 0,
            (__bridge CFTypeRef)observers_));
    while (pendingObservers_.count > 0) {
        id observer = pendingObservers_.anyObject;
        [pendingObservers_ removeObject:observer];
        if ([observer respondsToSelector:invocation.selector]) {
            [invocation invokeWithTarget:observer];
        }
    }
}

- (NSMethodSignature *)protocolMethodSignatureForSelector:(SEL)selector {
    struct objc_method_description description =
        protocol_getMethodDescription(_protocol, selector, YES, YES);
    if (!description.name) {
        description = protocol_getMethodDescription(_protocol, selector,
            NO, YES);
    }
    return [NSMethodSignature
        signatureWithObjCTypes:description.types];
}

@end

@implementation DqdObserverSetMessageProxy

@synthesize observerSet = _observerSet;

- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector {
    return [self.observerSet
        protocolMethodSignatureForSelector:aSelector];
}

- (void)forwardInvocation:(NSInvocation *)anInvocation {
    [self.observerSet forwardInvocationToObservers:anInvocation];
}

@end
