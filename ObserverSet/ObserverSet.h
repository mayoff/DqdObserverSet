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
    
After you've set my `protocol`, you can send messages to the observers.  Just send the message to my `proxy` object:

    [observers.proxy model:self didChangeImportantObject:someObject];

You can send an optional message the same way:

    [observers.proxy model:self didChangeTrivialDetail:someObject];

The proxy will only forward the optional message to those observers that respond to the message selector.

The proxy can forward messages with any signature, so you for example can also send a message with only one argument:

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
An object that forwards messages to my observers.  If you send it an optional message, it only forwards the message to those observers that respond to the message selector.
*/
@property (nonatomic, strong) id proxy;

@end
