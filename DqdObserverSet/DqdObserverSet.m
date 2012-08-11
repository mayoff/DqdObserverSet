/*
Created by Rob Mayoff on 7/30/12.
Copyright (c) 2012 Rob Mayoff. All rights reserved.
*/

#import "DqdObserverSet.h"
#import <objc/runtime.h>
#import <objc/message.h>

/*
I dynamically create a subclass of ObserverSetMessageProxy for each protocol given to an ObserverSet.  In the dynamic subclass, I try to add an instance method for each message in the protocol.  I get the IMP for the method by looking through the instance methods of either ObserverSetMessageProxyRequiredMessagesTemplate or ObserverSetMessageProxyOptionalMessagesTemplate for a method whose signature matches the protocol message.  If I can't find an IMP with a matching signature, I don't add a method to the dynamic class.  The message will instead be handled by ObserverSetMessageProxy's forwardInvocation: method.
*/

@interface DqdObserverSetMessageProxy : NSObject

@property (nonatomic, unsafe_unretained) DqdObserverSet *observerSet;

+ (Class)subclassForProtocol:(Protocol *)protocol;

@end

/*
Since I don't want to retain the observers, I pass non-retaining callbacks to `CFSetCreateMutable` and then use toll-free-bridging to treat the result as an `NSMutableSet`.
*/

static NSMutableSet *nonRetainingSet(void) {
    CFSetCallBacks callbacks = {
        .version = 0,
        .retain = NULL,
        .release = NULL,
        .copyDescription = kCFTypeSetCallBacks.copyDescription,
        .equal = kCFTypeSetCallBacks.equal,
        .hash = kCFTypeSetCallBacks.hash

    };
    return CFBridgingRelease(CFSetCreateMutable(NULL, 0, &callbacks));
}

/*
I use this instead of a selector to indicate that I need not bother testing the observer with `respondsToSelector:` before sending it a message.
*/

static const SEL kRequiredSelectorPlaceholder = (SEL)NULL;

@implementation DqdObserverSet {
    NSMutableSet *observers_;
    NSMutableSet *pendingAdditions_;
    NSMutableSet *pendingDeletions_;
    BOOL isForwarding_;
}

#pragma mark - Public API

@synthesize proxy = _proxy;

- (id)init {
    NSLog(@"I only understand -[%@ initWithProtocol:], not -[%@ init].", self.class, self.class);
    [self doesNotRecognizeSelector:_cmd]; abort();
}

- (id)initWithProtocol:(Protocol *)protocol {
    if ((self = [super init])) {
        _protocol = protocol;
        _proxy = [[[DqdObserverSetMessageProxy subclassForProtocol:_protocol] alloc] init];
        [_proxy setObserverSet:self];
    }
    return self;
}

- (void)addObserver:(id)observer {
    if (isForwarding_ && pendingDeletions_) {
        [pendingDeletions_ removeObject:observer];
    }
    
    __strong NSMutableSet **set = isForwarding_ ? &pendingAdditions_ : &observers_;

    if (!*set) {
        *set = nonRetainingSet();
    }
    [*set addObject:observer];
}

- (void)removeObserver:(id)observer {
    if (isForwarding_) {
        if (pendingAdditions_) {
            [pendingAdditions_ removeObject:observer];
        }
        if (!pendingDeletions_) {
            pendingDeletions_ = nonRetainingSet();
        }
        [pendingDeletions_ addObject:observer];
    } else {
        [observers_ removeObject:observer];
    }
}

#pragma mark - DqdObserverSetMessageProxy API

- (NSMethodSignature *)protocolMethodSignatureForSelector:(SEL)selector {
    NSAssert(_protocol != nil, @"%@ protocol not set", self);
    struct objc_method_description description = protocol_getMethodDescription(_protocol, selector, YES, YES);
    if (!description.name) {
        description = protocol_getMethodDescription(_protocol, selector, NO, YES);
    }
    NSAssert(description.name, @"%@ couldn't find selector %s in protocol %s", self, sel_getName(selector), protocol_getName(_protocol));
    return [NSMethodSignature signatureWithObjCTypes:description.types];
}

- (void)forwardMessageToObserversThatRespondToSelector:(SEL)selector withBlock:(void (^)(id observer))block {
    NSAssert(!isForwarding_, @"%@ asked to forward a message to observers recursively", self);

    isForwarding_ = YES;
    @try {
        for (id observer in observers_) {
            if (pendingDeletions_ && [pendingDeletions_ containsObject:observer])
                continue;
            if (selector == kRequiredSelectorPlaceholder || [observer respondsToSelector:selector]) {
                block(observer);
            }
        }
    }
    @finally {
        isForwarding_ = NO;

        if (pendingAdditions_) {
            [observers_ unionSet:pendingAdditions_];
            pendingAdditions_ = nil;
        }
        
        if (pendingDeletions_) {
            [observers_ minusSet:pendingDeletions_];
            pendingDeletions_ = nil;
        }
    }
}

@end

@interface DqdObserverSetMessageProxyRequiredMessagesTemplate : DqdObserverSetMessageProxy
+ (BOOL)requiredMessages;
@end

@interface DqdObserverSetMessageProxyOptionalMessagesTemplate: DqdObserverSetMessageProxy
+ (BOOL)requiredMessages;
@end

@implementation DqdObserverSetMessageProxy

@synthesize observerSet = _observerSet;

#pragma mark - Generic message forwarding

- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector {
    return [self.observerSet protocolMethodSignatureForSelector:aSelector];
}

- (void)forwardInvocation:(NSInvocation *)anInvocation {
    [self.observerSet forwardMessageToObserversThatRespondToSelector:anInvocation.selector withBlock:^(id observer) {
        [anInvocation invokeWithTarget:observer];
    }];
}

#pragma mark - Dynamic subclass creation

+ (Class)subclassForProtocol:(Protocol *)protocol {
    NSString *proxyClassName = [self proxyClassNameForProtocol:protocol];
    Class proxyClass = objc_lookUpClass(proxyClassName.UTF8String);
    if (proxyClass)
        return proxyClass;

    proxyClass = objc_allocateClassPair(self, proxyClassName.UTF8String, 0);
    objc_registerClassPair(proxyClass);
    [proxyClass copyMethodsForProtocol:protocol fromTemplateClass:[DqdObserverSetMessageProxyRequiredMessagesTemplate class]];
    [proxyClass copyMethodsForProtocol:protocol fromTemplateClass:[DqdObserverSetMessageProxyOptionalMessagesTemplate class]];
    return proxyClass;
}

+ (NSString *)proxyClassNameForProtocol:(Protocol *)protocol {
    return [NSString stringWithFormat:@"%s-%s", class_getName(self.class), protocol_getName(protocol)];
}

+ (void)copyMethodsForProtocol:(Protocol *)protocol fromTemplateClass:(Class)templateClass {
    unsigned int count;
    struct objc_method_description *descriptions = protocol_copyMethodDescriptionList(protocol, [templateClass requiredMessages], YES, &count);
    CFDictionaryRef dictionary = [self methodImplementationsForTypesDictionary];
    for (unsigned int i = 0; i < count; ++i) {
        [self copyMethodFromDictionary:dictionary forMessage:descriptions + i];
    }
    free(descriptions);
}

+ (void)copyMethodFromDictionary:(CFDictionaryRef)methodImplementationsForTypes forMessage:(struct objc_method_description *)description {
    IMP imp = CFDictionaryGetValue(methodImplementationsForTypes, description->types);
    if (imp) {
        class_addMethod(self, description->name, imp, description->types);
    }
}

#pragma mark - Method types to IMP dictionary

static CFStringRef methodDictionaryCopyKeyDescription(const void *key) {
    return CFStringCreateWithCString(NULL, key, kCFStringEncodingUTF8);
}

static Boolean methodDictionaryKeyEqual(const void *key0, const void *key1) {
    return strcmp(key0, key1) == 0;
}

static CFHashCode methodDictionaryKeyHash(const void *key) {
    // djb hash function - xor variant
    CFHashCode hash = 5381;
    for (const unsigned char *p = key ; *p; ++p) {
        hash = (hash * 33) ^ *p;
    }
    return hash;
}

+ (CFDictionaryRef)methodImplementationsForTypesDictionary {
    // This method is to be called on the template subclasses only.

    @synchronized (self) {
        static const void *kKey = (void *)"methodImplementationsForTypesDictionary";

        CFDictionaryRef dictionary = (__bridge CFDictionaryRef)objc_getAssociatedObject(self, kKey);
        if (!dictionary) {
            unsigned int count;
            Method *methods = class_copyMethodList(self, &count);

            const void **keys = malloc(count * sizeof *keys);
            const void **values = malloc(count * sizeof *values);
            for (unsigned int i = 0; i < count; ++i) {
                keys[i] = method_getTypeEncoding(methods[i]);
                values[i] = method_getImplementation(methods[i]);
            }

            free(methods);

            CFDictionaryKeyCallBacks keyCallbacks = {
                .version = 0,
                .retain = NULL,
                .release = NULL,
                .copyDescription  = methodDictionaryCopyKeyDescription,
                .equal = methodDictionaryKeyEqual,
                .hash = methodDictionaryKeyHash
            };

            dictionary = CFDictionaryCreate(NULL, keys, values, count, &keyCallbacks, NULL);
            free(keys);
            free(values);
            objc_setAssociatedObject(self, kKey, CFBridgingRelease(dictionary), OBJC_ASSOCIATION_RETAIN);
        }
        return dictionary;
    }
}

@end

@implementation DqdObserverSetMessageProxyRequiredMessagesTemplate

+ (BOOL)requiredMessages {
    return YES;
}

- (void)message {
    typedef void MethodType(id, SEL);
    [self.observerSet forwardMessageToObserversThatRespondToSelector:kRequiredSelectorPlaceholder withBlock:^(id observer) {
        ((MethodType *)objc_msgSend)(observer, _cmd);
    }];
}

- (void)messageWithObject:(id)object0 {
    typedef void MethodType(id, SEL, id);
    [self.observerSet forwardMessageToObserversThatRespondToSelector:kRequiredSelectorPlaceholder withBlock:^(id observer) {
        ((MethodType *)objc_msgSend)(observer, _cmd, object0);
    }];
}

- (void)messageWithObject:(id)object0 object:(id)object1 {
    typedef void MethodType(id, SEL, id, id);
    [self.observerSet forwardMessageToObserversThatRespondToSelector:kRequiredSelectorPlaceholder withBlock:^(id observer) {
        ((MethodType *)objc_msgSend)(observer, _cmd, object0, object1);
    }];
}

@end

@implementation DqdObserverSetMessageProxyOptionalMessagesTemplate

+ (BOOL)requiredMessages {
    return NO;
}

- (void)message {
    typedef void MethodType(id, SEL);
    [self.observerSet forwardMessageToObserversThatRespondToSelector:_cmd withBlock:^(id observer) {
        ((MethodType *)objc_msgSend)(observer, _cmd);
    }];
}

- (void)messageWithObject:(id)object0 {
    typedef void MethodType(id, SEL, id);
    [self.observerSet forwardMessageToObserversThatRespondToSelector:_cmd withBlock:^(id observer) {
        ((MethodType *)objc_msgSend)(observer, _cmd, object0);
    }];
}

- (void)messageWithObject:(id)object0 object:(id)object1 {
    typedef void MethodType(id, SEL, id, id);
    [self.observerSet forwardMessageToObserversThatRespondToSelector:_cmd withBlock:^(id observer) {
        ((MethodType *)objc_msgSend)(observer, _cmd, object0, object1);
    }];
}

@end
