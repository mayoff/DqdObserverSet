/*
Created by Rob Mayoff on 7/30/12.
Copyright (c) 2012 Rob Mayoff. All rights reserved.
*/

#import <Foundation/Foundation.h>

/**
## ObserverSet

You use me when you want to manage a set of observers and send messages to all of the observers in the set.

To avoid retain cycles, I don't retain the observers.  I assume that observers retain you, and you retain me.

Before you can send a message to the observers, you need to tell me the protocol that defines the messages you want to send.  For example, suppose you have this observer protocol:

    @class Model;
    @protocol ModelObserver
    
    @required
    - (void)model:(Model *)model didChangeImportantObject:(NSObject *)object;
    
    @optional
    - (void)modelDidTick:(Model *)model;
    - (void)model:(Model *)model didChangeTrivialDetail:(NSObject *)detail;
    
    @end

You tell me to use this protocol by setting my `protocol` property:

    ObserverSet *observers = ...;
    observers.protocol = @protocol(MyObserverProtocol);
    
After you've set my `protocol`, you can send messages to the observers.  If you want to send a required message, use my `requiredMessageProxy`:

    [observers.requiredMessageProxy model:self didChangeImportantObject:someObject];

If you want to send an option message, use my `optionalMessageProxy`:

    [observers.optionalMessageProxy model:self didChangeTrivialDetail:someObject];

If you use the wrong proxy, the behavior is undefined.

The proxies can forward messages with any signature, so you can also send this message:

    [observers.optionalMessageProxy modelDidTick:self];
*/

@interface ObserverSet : NSObject

/**
Add `observer` to my set, if it's not there already.  Otherwise, do nothing.

If you send me this message while I'm sending a message to observers, and I didn't already have `observer` in my set, I won't send the current message to `observer`.
*/
- (void)addObserver:(id)observer;

/**
Remove `observer` from my set, if it's there.  Otherwise, do nothing.

If you send me this message while I'm sending a message to observers, and I have `observer` in my set but haven't sent him the current message yet, I won't send him the current message at all.
*/
- (void)removeObserver:(id)observer;

/**
The protocol adopted by the observers I manage.
*/
@property (nonatomic, strong) Protocol *protocol;

/**
An object that forwards messages to my observers.  You must only send messages to this proxy if they are required messages in my assigned protocol.
*/
@property (nonatomic, strong) id requiredMessageProxy;

/**
An object that forwards messages to my observers.  It only forwards a message to an observer if the observer responds to the message selector.  You must only send messages to this proxy if they are optional messages in my assigned protocol.
*/
@property (nonatomic, strong) id optionalMessageProxy;

@end
