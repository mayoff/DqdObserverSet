/*
Created by Rob Mayoff on 8/1/12.
This file is public domain.
*/

@protocol PerformanceTestProtocol <NSObject>

- (void)requiredMessage0WithObject:(id)object0 object:(id)object1;
- (void)requiredMessage1WithObject:(id)object0 object:(id)object1;
- (void)requiredMessage2WithObject:(id)object0 object:(id)object1;
- (void)requiredMessage3WithObject:(id)object0 object:(id)object1;
- (void)requiredMessage4WithObject:(id)object0 object:(id)object1;

@optional

- (void)optionalMessage0WithObject:(id)object0 object:(id)object1;
- (void)optionalMessage1WithObject:(id)object0 object:(id)object1;
- (void)optionalMessage2WithObject:(id)object0 object:(id)object1;
- (void)optionalMessage3WithObject:(id)object0 object:(id)object1;
- (void)optionalMessage4WithObject:(id)object0 object:(id)object1;

@end
