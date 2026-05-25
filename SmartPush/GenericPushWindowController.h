//
//  GenericPushWindowController.h
//  SmartPush
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface GenericPushWindowController : NSWindowController

- (instancetype)initWithTitle:(NSString *)title
                     pushType:(NSString *)pushType
                  topicSuffix:(nullable NSString *)topicSuffix
              defaultPriority:(NSUInteger)defaultPriority;

@end

NS_ASSUME_NONNULL_END
