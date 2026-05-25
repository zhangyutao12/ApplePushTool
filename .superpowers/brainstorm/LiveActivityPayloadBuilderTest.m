#import <Foundation/Foundation.h>
#import "LiveActivityPayloadBuilder.h"

static void Assert(BOOL condition, NSString *message) {
    if (!condition) {
        [NSException raise:@"AssertionFailed" format:@"%@", message];
    }
}

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSError *error = nil;
        NSString *payload = [LiveActivityPayloadBuilder payloadWithEvent:@"start"
                                                                timestamp:@1779523200
                                                           attributesType:@"OrderAttributes"
                                                            attributesJSON:@"{\"orderId\":\"A123\"}"
                                                          contentStateJSON:@"{\"status\":\"shipping\",\"progress\":0.45}"
                                                                 staleDate:nil
                                                            dismissalDate:nil
                                                                 alertJSON:@"{\"title\":\"订单更新\",\"body\":\"实时活动已开始\"}"
                                                                     error:&error];
        Assert(payload != nil, @"start payload should be generated");
        NSData *data = [payload dataUsingEncoding:NSUTF8StringEncoding];
        NSDictionary *object = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
        NSDictionary *aps = object[@"aps"];
        Assert([aps[@"event"] isEqualToString:@"start"], @"event should be start");
        Assert([aps[@"attributes-type"] isEqualToString:@"OrderAttributes"], @"attributes-type should be included");
        Assert([aps[@"timestamp"] integerValue] == 1779523200, @"timestamp should be included");
        Assert([aps[@"content-state"][@"status"] isEqualToString:@"shipping"], @"content-state should be parsed");
        Assert([aps[@"alert"][@"title"] isEqualToString:@"订单更新"], @"alert should be included");
        Assert([aps[@"input-push-token"] integerValue] == 1, @"start should request an update push token");

        payload = [LiveActivityPayloadBuilder payloadWithEvent:@"update"
                                                     timestamp:@1779523300
                                                attributesType:nil
                                                 attributesJSON:nil
                                               contentStateJSON:@"{\"status\":\"done\"}"
                                                      staleDate:@1779523600
                                                 dismissalDate:nil
                                                      alertJSON:@"{\"title\":\"更新\",\"body\":\"状态变化\"}"
                                                          error:&error];
        Assert(payload != nil, @"update payload should be generated");
        data = [payload dataUsingEncoding:NSUTF8StringEncoding];
        object = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
        aps = object[@"aps"];
        Assert([aps[@"relevance-score"] integerValue] == 100, @"update should include relevance-score");

        payload = [LiveActivityPayloadBuilder payloadWithEvent:@"end"
                                                     timestamp:@1779523400
                                                attributesType:nil
                                                 attributesJSON:nil
                                               contentStateJSON:@"{\"status\":\"done\"}"
                                                      staleDate:nil
                                                 dismissalDate:@1779527000
                                                      alertJSON:nil
                                                          error:&error];
        Assert(payload != nil, @"end payload should be generated");

        payload = [LiveActivityPayloadBuilder payloadWithEvent:@"start"
                                                     timestamp:@1779523200
                                                attributesType:@""
                                                 attributesJSON:@"{}"
                                               contentStateJSON:@"{}"
                                                      staleDate:nil
                                                 dismissalDate:nil
                                                      alertJSON:nil
                                                          error:&error];
        Assert(payload == nil, @"start without attributes-type should fail");

        payload = [LiveActivityPayloadBuilder payloadWithEvent:@"start"
                                                     timestamp:@1779523200
                                                attributesType:@"OrderAttributes"
                                                 attributesJSON:@"{}"
                                               contentStateJSON:@"{}"
                                                      staleDate:nil
                                                 dismissalDate:nil
                                                      alertJSON:nil
                                                          error:&error];
        Assert(payload == nil, @"start without alert should fail");
    }
    return 0;
}
