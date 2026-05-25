//
//  LiveActivityWindowController.m
//  SmartPush
//

#import "LiveActivityWindowController.h"
#import "LiveActivityPayloadBuilder.h"
#import "NetworkManager.h"
#import "Sec.h"
#import "SecManager.h"

@interface LiveActivityViewController : NSViewController
@end

@interface LiveActivityViewController ()
@property (nonatomic, strong) NSPopUpButton *certificatePopUpButton;
@property (nonatomic, strong) NSSegmentedControl *environmentControl;
@property (nonatomic, strong) NSSegmentedControl *priorityControl;
@property (nonatomic, strong) NSSegmentedControl *eventControl;
@property (nonatomic, strong) NSTextField *tokenField;
@property (nonatomic, strong) NSTextField *topicField;
@property (nonatomic, strong) NSTextField *collapseIDField;
@property (nonatomic, strong) NSTextField *attributesTypeField;
@property (nonatomic, strong) NSTextField *timestampField;
@property (nonatomic, strong) NSTextField *staleDateField;
@property (nonatomic, strong) NSTextField *dismissalDateField;
@property (nonatomic, strong) NSTextView *attributesView;
@property (nonatomic, strong) NSTextView *contentStateView;
@property (nonatomic, strong) NSTextView *alertView;
@property (nonatomic, strong) NSTextView *payloadView;
@property (nonatomic, strong) NSTextView *logView;
@property (nonatomic, strong) NSMutableArray *certificates;
@property (nonatomic, strong) Sec *currentSec;
@property (nonatomic) SecIdentityRef identity;
@end

@implementation LiveActivityWindowController

- (instancetype)init {
    NSWindow *window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 980, 720)
                                                   styleMask:(NSWindowStyleMaskTitled | NSWindowStyleMaskClosable)
                                                     backing:NSBackingStoreBuffered
                                                       defer:NO];
    self = [super initWithWindow:window];
    if (self) {
        window.title = @"Live Activity Push";
        window.minSize = window.frame.size;
        window.maxSize = window.frame.size;
        window.contentViewController = [[LiveActivityViewController alloc] init];
    }
    return self;
}

@end

@implementation LiveActivityViewController

- (void)dealloc {
    if (_identity != NULL) {
        CFRelease(_identity);
    }
}

- (void)loadView {
    self.view = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 980, 720)];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self buildView];
    [self loadCertificates];
    [self applyDefaults];
    [self refreshPayload:nil];
}

- (void)buildView {
    NSTextField *title = [self label:@"实时活动推送" frame:NSMakeRect(18, 676, 180, 24) size:18];
    title.autoresizingMask = NSViewMinYMargin;
    [self.view addSubview:title];

    NSBox *leftBox = [self box:@"APNs 配置" frame:NSMakeRect(18, 74, 330, 588)];
    NSBox *rightBox = [self box:@"Payload 参数" frame:NSMakeRect(366, 74, 596, 588)];
    leftBox.autoresizingMask = NSViewHeightSizable | NSViewMaxXMargin;
    rightBox.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    [self.view addSubview:leftBox];
    [self.view addSubview:rightBox];

    [leftBox addSubview:[self label:@"证书" frame:NSMakeRect(14, 526, 90, 17) size:12]];
    self.certificatePopUpButton = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(14, 498, 302, 28)];
    self.certificatePopUpButton.autoresizingMask = NSViewMinYMargin | NSViewWidthSizable;
    self.certificatePopUpButton.target = self;
    self.certificatePopUpButton.action = @selector(certificateChanged:);
    [leftBox addSubview:self.certificatePopUpButton];

    [leftBox addSubview:[self label:@"环境" frame:NSMakeRect(14, 462, 90, 17) size:12]];
    self.environmentControl = [self segments:@[@"开发", @"生产"] frame:NSMakeRect(14, 434, 140, 28)];
    self.environmentControl.autoresizingMask = NSViewMinYMargin;
    [leftBox addSubview:self.environmentControl];

    [leftBox addSubview:[self label:@"Priority" frame:NSMakeRect(180, 462, 90, 17) size:12]];
    self.priorityControl = [self segments:@[@"5", @"10"] frame:NSMakeRect(180, 434, 110, 28)];
    self.priorityControl.autoresizingMask = NSViewMinYMargin;
    [leftBox addSubview:self.priorityControl];

    self.tokenField = [self field:NSMakeRect(14, 364, 302, 28) placeholder:@"Activity push token / push-to-start token"];
    self.tokenField.autoresizingMask = NSViewMinYMargin | NSViewWidthSizable;
    [leftBox addSubview:[self label:@"Token" frame:NSMakeRect(14, 392, 90, 17) size:12]];
    [leftBox addSubview:self.tokenField];

    self.topicField = [self field:NSMakeRect(14, 294, 302, 28) placeholder:@"Bundle ID，发送时自动追加 .push-type.liveactivity"];
    self.topicField.autoresizingMask = NSViewMinYMargin | NSViewWidthSizable;
    [leftBox addSubview:[self label:@"Topic" frame:NSMakeRect(14, 322, 90, 17) size:12]];
    [leftBox addSubview:self.topicField];

    self.collapseIDField = [self field:NSMakeRect(14, 224, 302, 28) placeholder:@"apns-collapse-id（可选）"];
    self.collapseIDField.autoresizingMask = NSViewMinYMargin | NSViewWidthSizable;
    [leftBox addSubview:[self label:@"Collapse ID" frame:NSMakeRect(14, 252, 120, 17) size:12]];
    [leftBox addSubview:self.collapseIDField];

    self.logView = [self textView:NSMakeRect(14, 18, 302, 150) editable:NO];
    self.logView.enclosingScrollView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    [leftBox addSubview:[self label:@"日志" frame:NSMakeRect(14, 168, 90, 17) size:12]];
    [leftBox addSubview:self.logView.enclosingScrollView];

    [rightBox addSubview:[self label:@"事件" frame:NSMakeRect(14, 526, 90, 17) size:12]];
    self.eventControl = [self segments:@[@"start", @"update", @"end"] frame:NSMakeRect(14, 498, 210, 28)];
    self.eventControl.autoresizingMask = NSViewMinYMargin;
    self.eventControl.target = self;
    self.eventControl.action = @selector(eventChanged:);
    [rightBox addSubview:self.eventControl];

    self.timestampField = [self field:NSMakeRect(250, 498, 180, 28) placeholder:@"留空自动当前时间"];
    self.timestampField.autoresizingMask = NSViewMinYMargin;
    [rightBox addSubview:[self label:@"timestamp" frame:NSMakeRect(250, 526, 120, 17) size:12]];
    [rightBox addSubview:self.timestampField];

    self.attributesTypeField = [self field:NSMakeRect(14, 428, 260, 28) placeholder:@"例如 OrderAttributes"];
    self.attributesTypeField.autoresizingMask = NSViewMinYMargin;
    [rightBox addSubview:[self label:@"attributes-type（start 必填）" frame:NSMakeRect(14, 456, 180, 17) size:12]];
    [rightBox addSubview:self.attributesTypeField];

    self.staleDateField = [self field:NSMakeRect(300, 428, 120, 28) placeholder:@"秒级时间戳"];
    self.staleDateField.autoresizingMask = NSViewMinYMargin;
    [rightBox addSubview:[self label:@"stale-date" frame:NSMakeRect(300, 456, 120, 17) size:12]];
    [rightBox addSubview:self.staleDateField];

    self.dismissalDateField = [self field:NSMakeRect(448, 428, 120, 28) placeholder:@"end 可选"];
    self.dismissalDateField.autoresizingMask = NSViewMinYMargin | NSViewMinXMargin;
    [rightBox addSubview:[self label:@"dismissal-date" frame:NSMakeRect(448, 456, 120, 17) size:12]];
    [rightBox addSubview:self.dismissalDateField];

    self.attributesView = [self textView:NSMakeRect(14, 306, 270, 86) editable:YES];
    self.contentStateView = [self textView:NSMakeRect(304, 306, 264, 86) editable:YES];
    self.attributesView.enclosingScrollView.autoresizingMask = NSViewMinYMargin;
    self.contentStateView.enclosingScrollView.autoresizingMask = NSViewMinYMargin | NSViewWidthSizable;
    [rightBox addSubview:[self label:@"attributes JSON（start 必填）" frame:NSMakeRect(14, 392, 180, 17) size:12]];
    [rightBox addSubview:[self label:@"content-state JSON（必填）" frame:NSMakeRect(304, 392, 180, 17) size:12]];
    [rightBox addSubview:self.attributesView.enclosingScrollView];
    [rightBox addSubview:self.contentStateView.enclosingScrollView];

    self.alertView = [self textView:NSMakeRect(14, 194, 554, 72) editable:YES];
    self.alertView.enclosingScrollView.autoresizingMask = NSViewMinYMargin | NSViewWidthSizable;
    [rightBox addSubview:[self label:@"alert JSON（start 必填）" frame:NSMakeRect(14, 266, 180, 17) size:12]];
    [rightBox addSubview:self.alertView.enclosingScrollView];

    self.payloadView = [self textView:NSMakeRect(14, 18, 554, 136) editable:NO];
    self.payloadView.enclosingScrollView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    [rightBox addSubview:[self label:@"最终 payload 预览" frame:NSMakeRect(14, 154, 180, 17) size:12]];
    [rightBox addSubview:self.payloadView.enclosingScrollView];

    NSButton *generateButton = [self button:@"生成 Payload" frame:NSMakeRect(366, 24, 110, 32) action:@selector(refreshPayload:)];
    NSButton *copyButton = [self button:@"复制 Payload" frame:NSMakeRect(486, 24, 110, 32) action:@selector(copyPayload:)];
    NSButton *sendButton = [self button:@"发送实时活动推送" frame:NSMakeRect(808, 24, 154, 32) action:@selector(sendPush:)];
    generateButton.autoresizingMask = NSViewMaxYMargin;
    copyButton.autoresizingMask = NSViewMaxYMargin;
    sendButton.autoresizingMask = NSViewMinXMargin | NSViewMaxYMargin;
    [self.view addSubview:generateButton];
    [self.view addSubview:copyButton];
    [self.view addSubview:sendButton];
}

- (void)loadCertificates {
    self.certificates = [[SecManager allPushCertificatesWithEnvironment:YES] mutableCopy];
    [self.certificatePopUpButton removeAllItems];
    [self.certificatePopUpButton addItemWithTitle:@"请选择推送证书"];
    for (NSUInteger i = 0; i < self.certificates.count; i++) {
        Sec *sec = self.certificates[i];
        [self.certificatePopUpButton addItemWithTitle:[NSString stringWithFormat:@"%lu. %@ %@", (unsigned long)i + 1, sec.name, sec.expire]];
    }
}

- (void)applyDefaults {
    self.attributesTypeField.stringValue = @"CarLiveActivityAttributes";
    self.attributesView.string = @"{\n  \"orderID\": \"ORD20260326081542\",\n  \"orderUrl\": \"https://example.com/orders/ORD20260326081542\",\n  \"orderType\": \"1\"\n}";
    self.contentStateView.string = @"{\n  \"orderState\": 1,\n  \"carNumber\": \"沪A·12345\",\n  \"carName\": \"特斯拉 Model 3\",\n  \"carColor\": \"珍珠白\",\n  \"carType\": \"专车\",\n  \"orderEstTime\": \"15分钟\",\n  \"orderEstPrice\": \"36.8\",\n  \"orderEstMileage\": \"8.6公里\"\n}";
    self.alertView.string = @"{\n  \"title\": \"打车行程\",\n  \"body\": \"司机已接单\"\n}";
}

- (void)certificateChanged:(id)sender {
    NSInteger index = self.certificatePopUpButton.indexOfSelectedItem - 1;
    if (index < 0 || index >= (NSInteger)self.certificates.count) {
        self.currentSec = nil;
        return;
    }
    self.currentSec = self.certificates[index];
    self.topicField.stringValue = self.currentSec.topicName ?: @"";
    [self log:[NSString stringWithFormat:@"选择证书 %@", self.currentSec.name]];
}

- (void)eventChanged:(id)sender {
    BOOL isStart = self.eventControl.selectedSegment == 0;
    self.attributesTypeField.enabled = isStart;
    self.attributesView.editable = isStart;
    [self refreshPayload:nil];
}

- (void)refreshPayload:(id)sender {
    NSError *error = nil;
    NSString *payload = [self currentPayloadWithError:&error];
    self.payloadView.string = payload ?: (error.localizedDescription ?: @"Payload 生成失败");
}

- (void)copyPayload:(id)sender {
    [self refreshPayload:nil];
    [[NSPasteboard generalPasteboard] clearContents];
    [[NSPasteboard generalPasteboard] setString:self.payloadView.string forType:NSPasteboardTypeString];
    [self log:@"已复制 payload"];
}

- (void)sendPush:(id)sender {
    NSError *error = nil;
    NSString *payload = [self currentPayloadWithError:&error];
    if (!payload) {
        [self showMessage:error.localizedDescription ?: @"Payload 生成失败"];
        return;
    }
    NSString *token = [self.tokenField.stringValue stringByReplacingOccurrencesOfString:@" " withString:@""];
    if (token.length == 0) {
        [self showMessage:@"请填写 Activity push token 或 push-to-start token"];
        return;
    }
    if (!self.currentSec) {
        [self showMessage:@"请选择推送证书"];
        return;
    }
    if (![self prepareIdentity]) {
        return;
    }

    NSString *topic = [self.topicField.stringValue stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (topic.length == 0) {
        [self showMessage:@"请填写 Topic"];
        return;
    }

    NSString *collapseID = [self.collapseIDField.stringValue stringByReplacingOccurrencesOfString:@" " withString:@""];
    NSUInteger priority = self.priorityControl.selectedSegment == 0 ? 5 : 10;
    BOOL sandbox = self.environmentControl.selectedSegment == 0;

    [self log:@"发送实时活动推送"];
    [[NetworkManager sharedManager] postWithPayload:payload
                                            toToken:token
                                          withTopic:topic
                                           priority:priority
                                         collapseID:collapseID
                                        payloadType:@"liveactivity"
                                          inSandbox:sandbox
                                         exeSuccess:^(id responseObject) {
        [self showMessage:@"发送成功"];
        [self log:@"发送成功"];
    } exeFailed:^(NSString *errorMessage) {
        [self showMessage:@"发送失败"];
        [self log:errorMessage ?: @"发送失败"];
    }];
}

- (NSString *)currentPayloadWithError:(NSError **)error {
    NSNumber *timestamp = [self number:self.timestampField.stringValue fieldName:@"timestamp" error:error];
    if (error && *error) {
        return nil;
    }

    NSNumber *staleDate = [self number:self.staleDateField.stringValue fieldName:@"stale-date" error:error];
    if (error && *error) {
        return nil;
    }

    NSNumber *dismissalDate = [self number:self.dismissalDateField.stringValue fieldName:@"dismissal-date" error:error];
    if (error && *error) {
        return nil;
    }

    return [LiveActivityPayloadBuilder payloadWithEvent:[self selectedEvent]
                                              timestamp:timestamp
                                         attributesType:self.attributesTypeField.stringValue
                                         attributesJSON:self.attributesView.string
                                       contentStateJSON:self.contentStateView.string
                                              staleDate:staleDate
                                          dismissalDate:dismissalDate
                                              alertJSON:self.alertView.string
                                                  error:error];
}

- (NSString *)selectedEvent {
    if (self.eventControl.selectedSegment == 1) {
        return @"update";
    }
    if (self.eventControl.selectedSegment == 2) {
        return @"end";
    }
    return @"start";
}

- (NSNumber *)number:(NSString *)string fieldName:(NSString *)fieldName error:(NSError **)error {
    NSString *trimmed = [string stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (trimmed.length == 0) {
        return nil;
    }

    NSScanner *scanner = [NSScanner scannerWithString:trimmed];
    long long value = 0;
    if (![scanner scanLongLong:&value] || !scanner.isAtEnd || value < 0) {
        if (error) {
            *error = [NSError errorWithDomain:@"LiveActivityWindowControllerErrorDomain"
                                         code:-1
                                     userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"%@ 必须是非负秒级时间戳", fieldName]}];
        }
        return nil;
    }

    return @(value);
}

- (BOOL)prepareIdentity {
    if (self.identity != NULL) {
        CFRelease(self.identity);
        self.identity = NULL;
    }
    OSStatus result = SecIdentityCreateWithCertificate(NULL, self.currentSec.certificateRef, &_identity);
    if (result != errSecSuccess) {
        [self showMessage:[NSString stringWithFormat:@"创建证书身份失败：%d", result]];
        return NO;
    }
    [[NetworkManager sharedManager] setIdentity:self.identity];
    return YES;
}

- (NSTextField *)label:(NSString *)title frame:(NSRect)frame size:(CGFloat)size {
    NSTextField *label = [[NSTextField alloc] initWithFrame:frame];
    label.stringValue = title;
    label.bezeled = NO;
    label.drawsBackground = NO;
    label.editable = NO;
    label.selectable = NO;
    label.font = [NSFont systemFontOfSize:size];
    return label;
}

- (NSTextField *)field:(NSRect)frame placeholder:(NSString *)placeholder {
    NSTextField *field = [[NSTextField alloc] initWithFrame:frame];
    field.placeholderString = placeholder;
    field.font = [NSFont systemFontOfSize:12];
    return field;
}

- (NSTextView *)textView:(NSRect)frame editable:(BOOL)editable {
    NSScrollView *scrollView = [[NSScrollView alloc] initWithFrame:frame];
    scrollView.hasVerticalScroller = YES;
    scrollView.borderType = NSBezelBorder;
    NSTextView *textView = [[NSTextView alloc] initWithFrame:NSMakeRect(0, 0, frame.size.width, frame.size.height)];
    textView.font = [NSFont fontWithName:@"Menlo" size:12] ?: [NSFont systemFontOfSize:12];
    textView.automaticQuoteSubstitutionEnabled = NO;
    textView.editable = editable;
    scrollView.documentView = textView;
    return textView;
}

- (NSSegmentedControl *)segments:(NSArray *)labels frame:(NSRect)frame {
    NSSegmentedControl *control = [[NSSegmentedControl alloc] initWithFrame:frame];
    control.segmentCount = labels.count;
    for (NSInteger i = 0; i < (NSInteger)labels.count; i++) {
        [control setLabel:labels[i] forSegment:i];
        [control setWidth:frame.size.width / labels.count forSegment:i];
    }
    control.selectedSegment = 0;
    return control;
}

- (NSButton *)button:(NSString *)title frame:(NSRect)frame action:(SEL)action {
    NSButton *button = [[NSButton alloc] initWithFrame:frame];
    button.title = title;
    button.bezelStyle = NSBezelStyleRounded;
    button.target = self;
    button.action = action;
    return button;
}

- (NSBox *)box:(NSString *)title frame:(NSRect)frame {
    NSBox *box = [[NSBox alloc] initWithFrame:frame];
    box.title = title;
    box.boxType = NSBoxPrimary;
    return box;
}

- (void)showMessage:(NSString *)message {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = message;
    [alert beginSheetModalForWindow:self.view.window completionHandler:nil];
}

- (void)log:(NSString *)message {
    if (message.length == 0) {
        return;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.logView.textStorage appendAttributedString:[[NSAttributedString alloc] initWithString:message]];
        [self.logView.textStorage.mutableString appendString:@"\n"];
        [self.logView scrollRangeToVisible:NSMakeRange(MAX((NSInteger)self.logView.textStorage.length - 1, 0), 1)];
    });
}

@end
