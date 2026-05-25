//
//  LiveActivityPayloadBuilder.h
//  SmartPush
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface LiveActivityPayloadBuilder : NSObject

+ (nullable NSString *)payloadWithEvent:(NSString *)event
                              timestamp:(nullable NSNumber *)timestamp
                         attributesType:(nullable NSString *)attributesType
                         attributesJSON:(nullable NSString *)attributesJSON
                       contentStateJSON:(nullable NSString *)contentStateJSON
                              staleDate:(nullable NSNumber *)staleDate
                          dismissalDate:(nullable NSNumber *)dismissalDate
                              alertJSON:(nullable NSString *)alertJSON
                                  error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
