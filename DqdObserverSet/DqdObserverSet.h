/*
Created by Rob Mayoff on 7/30/12.
This file is public domain.
*/

#import <Foundation/Foundation.h>

@interface DqdObserverSet : NSObject

- (id)initWithProtocol:(Protocol *)protocol;	// Configure me to send messages defined in this protocol.

@property (nonatomic, strong, readonly) Protocol *protocol;

- (void)addObserver:(id)observer;	// Add an observer that should receive protocol messages.
- (void)removeObserver:(id)observer;	// Remove an observer that should no longer receive protocol messages.

@property (nonatomic, strong, readonly) id proxy;	// This object forwards any message in the protocol to all observers
    // that implement it.
@end
