/*
Created by Rob Mayoff on 7/30/12.
Copyright (c) 2012 Rob Mayoff. All rights reserved.
*/

#import "ObserverSet.h"
#import <objc/runtime.h>
#import <objc/message.h>

/*
I dynamically create a subclass of ObserverSetMessageProxy for each protocol given to an ObserverSet.  In the dynamic subclass, I try to add an instance method for each message in the protocol.  I get the IMP for the method by looking through the instance methods of either ObserverSetMessageProxyRequiredMessagesTemplate or ObserverSetMessageProxyOptionalMessagesTemplate for a method whose signature matches the protocol message.  If I can't find an IMP with a matching signature, I don't add a method to the dynamic class.  The message will instead be handled by ObserverSetMessageProxy's forwardInvocation: method.
*/

@interface ObserverSetMessageProxy : NSObject

@property (nonatomic, unsafe_unretained) ObserverSet *observerSet;

+ (Class)subclassForProtocol:(Protocol *)protocol;

+ (CFDictionaryRef)copyMethodDictionary;

@end

@interface ObserverSetMessageProxyRequiredMessagesTemplate : ObserverSetMessageProxy
+ (BOOL)requiredMessages;
+ (IMP)methodImplementationForTypes:(const char *)types;
@end

@interface ObserverSetMessageProxyOptionalMessagesTemplate: ObserverSetMessageProxy
+ (BOOL)requiredMessages;
+ (IMP)methodImplementationForTypes:(const char *)types;
@end

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

static const SEL kRequiredSelectorPlaceholder = (SEL)NULL;

@implementation ObserverSet {
    NSMutableSet *observers_;
    NSMutableSet *pendingAdditions_;
    NSMutableSet *pendingDeletions_;
    ObserverSetMessageProxy *_proxy_cached;
    BOOL isForwarding_;
}

@dynamic proxy;

#pragma mark - Public API

- (void)addObserver:(id)observer {
    __strong NSMutableSet **set = isForwarding_ ? &pendingAdditions_ : &observers_;

    if (!*set) {
        *set = nonRetainingSet();
    }
    [*set addObject:observer];
}

- (void)removeObserver:(id)observer {
    if (isForwarding_) {
        if (!pendingDeletions_) {
            pendingDeletions_ = nonRetainingSet();
        }
        [pendingDeletions_ addObject:observer];
    } else {
        [observers_ removeObject:observer];
    }
}

- (id)proxy {
    if (!_proxy_cached) {
        _proxy_cached = [[[ObserverSetMessageProxy subclassForProtocol:_protocol] alloc] init];
        _proxy_cached.observerSet = self;
    }
    return _proxy_cached;
}

#pragma mark - ObserverSetMessageProxy API

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

@implementation ObserverSetMessageProxy

@synthesize observerSet = _observerSet;

#pragma mark - Message forwarding

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
    [proxyClass copyMethodsForProtocol:protocol fromTemplateClass:[ObserverSetMessageProxyRequiredMessagesTemplate class]];
    [proxyClass copyMethodsForProtocol:protocol fromTemplateClass:[ObserverSetMessageProxyOptionalMessagesTemplate class]];
    return proxyClass;
}

+ (NSString *)proxyClassNameForProtocol:(Protocol *)protocol {
    return [NSString stringWithFormat:@"%s-%s", class_getName(self.class), protocol_getName(protocol)];
}

+ (void)copyMethodsForProtocol:(Protocol *)protocol fromTemplateClass:(Class)templateClass {
    unsigned int count;
    struct objc_method_description *descriptions = protocol_copyMethodDescriptionList(protocol, [templateClass requiredMessages], YES, &count);
    for (unsigned int i = 0; i < count; ++i) {
        [self copyMethodFromTemplateClass:templateClass forMessage:descriptions + i];
    }
    free(descriptions);
}

+ (void)copyMethodFromTemplateClass:(Class)templateClass forMessage:(struct objc_method_description *)description {
    IMP imp = [templateClass methodImplementationForTypes:description->types];
    if (imp) {
        class_addMethod(self, description->name, imp, description->types);
    }
}

#pragma mark - Method dictionary

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

+ (CFDictionaryRef)copyMethodDictionary {
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

    return CFDictionaryCreate(NULL, keys, values, count, &keyCallbacks, NULL);
}

@end

@implementation ObserverSetMessageProxyRequiredMessagesTemplate

+ (BOOL)requiredMessages {
    return YES;
}

+ (CFDictionaryRef)methodDictionary {
    // This has to be in each template class because each template class needs its own dictionary.
    static CFDictionaryRef dictionary;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        dictionary = [self copyMethodDictionary];
    });
    return dictionary;
}

+ (IMP)methodImplementationForTypes:(const char *)types {
    return CFDictionaryGetValue([self methodDictionary], types);
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

@implementation ObserverSetMessageProxyOptionalMessagesTemplate

+ (BOOL)requiredMessages {
    return NO;
}

+ (CFDictionaryRef)methodDictionary {
    // This has to be in each template class because each template class needs its own dictionary.
    static CFDictionaryRef dictionary;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        dictionary = [self copyMethodDictionary];
    });
    return dictionary;
}

+ (IMP)methodImplementationForTypes:(const char *)types {
    return CFDictionaryGetValue([self methodDictionary], types);
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
