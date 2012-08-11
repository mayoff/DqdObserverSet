@interface DqdObserverSet : NSObject

- (id)initWithProtocol:(Protocol *)protocol;

@property (nonatomic, strong, readonly) Protocol *protocol;

- (void)addObserver:(id)observer;
- (void)removeObserver:(id)observer;

@property (nonatomic, strong) id proxy;

@end
