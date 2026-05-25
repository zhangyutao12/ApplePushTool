//
//  LiveActivityPayloadBuilder.m
//  SmartPush
//

#import "LiveActivityPayloadBuilder.h"

static NSString * const LiveActivityPayloadBuilderErrorDomain = @"LiveActivityPayloadBuilderErrorDomain";

@implementation LiveActivityPayloadBuilder

+ (nullable NSString *)payloadWithEvent:(NSString *)event
                              timestamp:(nullable NSNumber *)timestamp
                         attributesType:(nullable NSString *)attributesType
                         attributesJSON:(nullable NSString *)attributesJSON
                       contentStateJSON:(nullable NSString *)contentStateJSON
                              staleDate:(nullable NSNumber *)staleDate
                          dismissalDate:(nullable NSNumber *)dismissalDate
                              alertJSON:(nullable NSString *)alertJSON
                                  error:(NSError **)error {
    NSString *normalizedEvent = [[event stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] lowercaseString];
    if (![self isSupportedEvent:normalizedEvent]) {
        [self assignError:error message:@"event 必须是 start、update 或 end"];
        return nil;
    }

    NSMutableDictionary *aps = [NSMutableDictionary dictionary];
    aps[@"timestamp"] = timestamp ?: @((NSInteger)[[NSDate date] timeIntervalSince1970]);
    aps[@"event"] = normalizedEvent;

    NSDictionary *contentState = [self JSONObjectWithString:contentStateJSON fieldName:@"content-state" error:error];
    if (!contentState) {
        return nil;
    }
    aps[@"content-state"] = contentState;

    BOOL isStartEvent = [normalizedEvent isEqualToString:@"start"];

    if (isStartEvent) {
        NSString *trimmedAttributesType = [attributesType stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (trimmedAttributesType.length == 0) {
            [self assignError:error message:@"start 事件必须填写 attributes-type"];
            return nil;
        }

        NSDictionary *attributes = [self JSONObjectWithString:attributesJSON fieldName:@"attributes" error:error];
        if (!attributes) {
            return nil;
        }
        aps[@"attributes-type"] = trimmedAttributesType;
        aps[@"attributes"] = attributes;
        aps[@"input-push-token"] = @1;
    } else if ([normalizedEvent isEqualToString:@"update"]) {
        aps[@"relevance-score"] = @100;
    }

    if (staleDate) {
        aps[@"stale-date"] = staleDate;
    }

    if ([normalizedEvent isEqualToString:@"end"] && dismissalDate) {
        aps[@"dismissal-date"] = dismissalDate;
    }

    NSDictionary *alert = [self optionalJSONObjectWithString:alertJSON fieldName:@"alert" error:error];
    if (isStartEvent && !alert) {
        if (error && !*error) {
            [self assignError:error message:@"start 事件必须填写 alert JSON"];
        }
        return nil;
    }
    if (alert) {
        aps[@"alert"] = alert;
    }

    NSDictionary *payload = @{@"aps": aps};
    NSData *data = [NSJSONSerialization dataWithJSONObject:payload options:NSJSONWritingPrettyPrinted error:error];
    if (!data) {
        return nil;
    }

    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}

+ (BOOL)isSupportedEvent:(NSString *)event {
    return [event isEqualToString:@"start"] || [event isEqualToString:@"update"] || [event isEqualToString:@"end"];
}

+ (nullable NSDictionary *)JSONObjectWithString:(nullable NSString *)string fieldName:(NSString *)fieldName error:(NSError **)error {
    NSDictionary *object = [self optionalJSONObjectWithString:string fieldName:fieldName error:error];
    if (!object) {
        if (error && !*error) {
            [self assignError:error message:[NSString stringWithFormat:@"%@ 必须是 JSON 对象", fieldName]];
        }
        return nil;
    }
    return object;
}

+ (nullable NSDictionary *)optionalJSONObjectWithString:(nullable NSString *)string fieldName:(NSString *)fieldName error:(NSError **)error {
    NSString *trimmedString = [string stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (trimmedString.length == 0) {
        return nil;
    }

    NSData *data = [trimmedString dataUsingEncoding:NSUTF8StringEncoding];
    NSError *parseError = nil;
    id object = [NSJSONSerialization JSONObjectWithData:data options:0 error:&parseError];
    if (!object || ![object isKindOfClass:[NSDictionary class]]) {
        NSString *message = parseError.localizedDescription ?: [NSString stringWithFormat:@"%@ 必须是 JSON 对象", fieldName];
        [self assignError:error message:[NSString stringWithFormat:@"%@ 解析失败：%@", fieldName, message]];
        return nil;
    }

    return object;
}

+ (void)assignError:(NSError **)error message:(NSString *)message {
    if (!error) {
        return;
    }

    *error = [NSError errorWithDomain:LiveActivityPayloadBuilderErrorDomain
                                 code:-1
                             userInfo:@{NSLocalizedDescriptionKey: message}];
}

@end
