//
//  GenericPushWindowController.m
//  SmartPush
//

#import "GenericPushWindowController.h"
#import "NetworkManager.h"
#import "Sec.h"
#import "SecManager.h"

@interface GenericPushViewController : NSViewController

- (instancetype)initWithPushType:(NSString *)pushType topicSuffix:(nullable NSString *)topicSuffix defaultPriority:(NSUInteger)defaultPriority;

@end

@interface GenericPushViewController ()
@property (nonatomic, copy) NSString *pushType;
@property (nonatomic, copy, nullable) NSString *topicSuffix;
@property (nonatomic) NSUInteger defaultPriority;
@property (nonatomic, strong) NSPopUpButton *certificatePopUpButton;
@property (nonatomic, strong) NSSegmentedControl *environmentControl;
@property (nonatomic, strong) NSSegmentedControl *priorityControl;
@property (nonatomic, strong) NSTextField *tokenField;
@property (nonatomic, strong) NSTextField *topicField;
@property (nonatomic, strong) NSTextField *collapseIDField;
@property (nonatomic, strong) NSTextField *alertTitleField;
@property (nonatomic, strong) NSTextField *alertBodyField;
@property (nonatomic, strong) NSTextField *badgeField;
@property (nonatomic, strong) NSTextField *soundField;
@property (nonatomic, strong) NSTextView *customJSONView;
@property (nonatomic, strong) NSTextView *payloadView;
@property (nonatomic, strong) NSTextView *logView;
@property (nonatomic, strong) NSMutableArray *certificates;
@property (nonatomic, strong) Sec *currentSec;
@property (nonatomic) SecIdentityRef identity;
@end

@implementation GenericPushWindowController

- (instancetype)initWithTitle:(NSString *)title pushType:(NSString *)pushType topicSuffix:(nullable NSString *)topicSuffix defaultPriority:(NSUInteger)defaultPriority {
    NSWindow *window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 960, 680)
                                                   styleMask:(NSWindowStyleMaskTitled | NSWindowStyleMaskClosable)
                                                     backing:NSBackingStoreBuffered
                                                       defer:NO];
    self = [super initWithWindow:window];
    if (self) {
        window.title = title;
        window.minSize = window.frame.size;
        window.maxSize = window.frame.size;
        window.contentViewController = [[GenericPushViewController alloc] initWithPushType:pushType topicSuffix:topicSuffix defaultPriority:defaultPriority];
    }
    return self;
}

@end

@implementation GenericPushViewController

- (instancetype)initWithPushType:(NSString *)pushType topicSuffix:(nullable NSString *)topicSuffix defaultPriority:(NSUInteger)defaultPriority {
    self = [super init];
    if (self) {
        _pushType = [pushType copy];
        _topicSuffix = [topicSuffix copy];
        _defaultPriority = defaultPriority;
    }
    return self;
}

- (void)dealloc {
    if (_identity != NULL) {
        CFRelease(_identity);
    }
}

- (void)loadView {
    self.view = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 960, 680)];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self buildView];
    [self loadCertificates];
    [self applyDefaults];
    [self refreshPayload:nil];
}

- (void)buildView {
    CGFloat margin = 18;
    CGFloat leftWidth = 330;
    CGFloat rightX = margin + leftWidth + 18;
    CGFloat bottom = 72;

    NSTextField *title = [self label:[NSString stringWithFormat:@"%@ 推送", self.pushType] frame:NSMakeRect(margin, self.view.bounds.size.height - 44, 240, 24) size:18];
    title.autoresizingMask = NSViewMinYMargin;
    [self.view addSubview:title];

    NSBox *leftBox = [self box:@"APNs 配置" frame:NSMakeRect(margin, bottom, leftWidth, self.view.bounds.size.height - bottom - 60)];
    leftBox.autoresizingMask = NSViewHeightSizable | NSViewMaxXMargin;
    [self.view addSubview:leftBox];

    NSBox *rightBox = [self box:@"Payload 组装" frame:NSMakeRect(rightX, bottom, self.view.bounds.size.width - rightX - margin, self.view.bounds.size.height - bottom - 60)];
    rightBox.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    [self.view addSubview:rightBox];

    [leftBox addSubview:[self label:@"证书" frame:NSMakeRect(14, leftBox.bounds.size.height - 62, 100, 17) size:12]];
    self.certificatePopUpButton = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(14, leftBox.bounds.size.height - 90, leftWidth - 28, 28)];
    self.certificatePopUpButton.autoresizingMask = NSViewMinYMargin | NSViewWidthSizable;
    self.certificatePopUpButton.target = self;
    self.certificatePopUpButton.action = @selector(certificateChanged:);
    [leftBox addSubview:self.certificatePopUpButton];

    [leftBox addSubview:[self label:@"环境" frame:NSMakeRect(14, leftBox.bounds.size.height - 126, 100, 17) size:12]];
    self.environmentControl = [self segments:@[@"开发", @"生产"] frame:NSMakeRect(14, leftBox.bounds.size.height - 154, 140, 28)];
    self.environmentControl.autoresizingMask = NSViewMinYMargin;
    [leftBox addSubview:self.environmentControl];

    [leftBox addSubview:[self label:@"Priority" frame:NSMakeRect(180, leftBox.bounds.size.height - 126, 100, 17) size:12]];
    self.priorityControl = [self segments:@[@"5", @"10"] frame:NSMakeRect(180, leftBox.bounds.size.height - 154, 110, 28)];
    self.priorityControl.autoresizingMask = NSViewMinYMargin;
    self.priorityControl.selectedSegment = self.defaultPriority == 5 ? 0 : 1;
    [leftBox addSubview:self.priorityControl];

    self.tokenField = [self field:NSMakeRect(14, leftBox.bounds.size.height - 224, leftWidth - 28, 28) placeholder:@"device token / push token"];
    self.tokenField.autoresizingMask = NSViewMinYMargin | NSViewWidthSizable;
    [leftBox addSubview:[self label:@"Token" frame:NSMakeRect(14, leftBox.bounds.size.height - 196, 100, 17) size:12]];
    [leftBox addSubview:self.tokenField];

    self.topicField = [self field:NSMakeRect(14, leftBox.bounds.size.height - 294, leftWidth - 28, 28) placeholder:self.topicSuffix ? [NSString stringWithFormat:@"Bundle ID，发送时追加 %@", self.topicSuffix] : @"Bundle ID"];
    self.topicField.autoresizingMask = NSViewMinYMargin | NSViewWidthSizable;
    [leftBox addSubview:[self label:@"Topic" frame:NSMakeRect(14, leftBox.bounds.size.height - 266, 100, 17) size:12]];
    [leftBox addSubview:self.topicField];

    self.collapseIDField = [self field:NSMakeRect(14, leftBox.bounds.size.height - 364, leftWidth - 28, 28) placeholder:@"apns-collapse-id（可选）"];
    self.collapseIDField.autoresizingMask = NSViewMinYMargin | NSViewWidthSizable;
    [leftBox addSubview:[self label:@"Collapse ID" frame:NSMakeRect(14, leftBox.bounds.size.height - 336, 120, 17) size:12]];
    [leftBox addSubview:self.collapseIDField];

    self.logView = [self textView:NSMakeRect(14, 18, leftWidth - 28, 150) editable:NO];
    self.logView.enclosingScrollView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    [leftBox addSubview:[self label:@"日志" frame:NSMakeRect(14, 168, 100, 17) size:12]];
    [leftBox addSubview:self.logView.enclosingScrollView];

    self.alertTitleField = [self field:NSMakeRect(14, rightBox.bounds.size.height - 90, 250, 28) placeholder:@"alert.title"];
    self.alertBodyField = [self field:NSMakeRect(284, rightBox.bounds.size.height - 90, rightBox.bounds.size.width - 298, 28) placeholder:@"alert.body"];
    self.alertTitleField.autoresizingMask = NSViewMinYMargin;
    self.alertBodyField.autoresizingMask = NSViewMinYMargin | NSViewWidthSizable;
    [rightBox addSubview:[self label:@"标题" frame:NSMakeRect(14, rightBox.bounds.size.height - 62, 100, 17) size:12]];
    [rightBox addSubview:[self label:@"内容" frame:NSMakeRect(284, rightBox.bounds.size.height - 62, 100, 17) size:12]];
    [rightBox addSubview:self.alertTitleField];
    [rightBox addSubview:self.alertBodyField];

    self.badgeField = [self field:NSMakeRect(14, rightBox.bounds.size.height - 160, 120, 28) placeholder:@"badge"];
    self.soundField = [self field:NSMakeRect(154, rightBox.bounds.size.height - 160, 180, 28) placeholder:@"default"];
    self.badgeField.autoresizingMask = NSViewMinYMargin;
    self.soundField.autoresizingMask = NSViewMinYMargin;
    [rightBox addSubview:[self label:@"Badge" frame:NSMakeRect(14, rightBox.bounds.size.height - 132, 100, 17) size:12]];
    [rightBox addSubview:[self label:@"Sound" frame:NSMakeRect(154, rightBox.bounds.size.height - 132, 100, 17) size:12]];
    [rightBox addSubview:self.badgeField];
    [rightBox addSubview:self.soundField];

    self.customJSONView = [self textView:NSMakeRect(14, 206, rightBox.bounds.size.width - 28, rightBox.bounds.size.height - 392) editable:YES];
    self.customJSONView.enclosingScrollView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    [rightBox addSubview:[self label:@"自定义 JSON（会合并到最终 payload 顶层；如包含 aps，会合并到 aps）" frame:NSMakeRect(14, rightBox.bounds.size.height - 190, 420, 17) size:12]];
    [rightBox addSubview:self.customJSONView.enclosingScrollView];

    self.payloadView = [self textView:NSMakeRect(14, 18, rightBox.bounds.size.width - 28, 150) editable:NO];
    self.payloadView.enclosingScrollView.autoresizingMask = NSViewWidthSizable | NSViewMinYMargin;
    [rightBox addSubview:[self label:@"最终 payload 预览" frame:NSMakeRect(14, 168, 180, 17) size:12]];
    [rightBox addSubview:self.payloadView.enclosingScrollView];

    NSButton *generateButton = [self button:@"生成 Payload" frame:NSMakeRect(rightX, 24, 110, 32) action:@selector(refreshPayload:)];
    NSButton *copyButton = [self button:@"复制 Payload" frame:NSMakeRect(rightX + 120, 24, 110, 32) action:@selector(copyPayload:)];
    NSButton *sendButton = [self button:@"发送推送" frame:NSMakeRect(self.view.bounds.size.width - 128, 24, 110, 32) action:@selector(sendPush:)];
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
    if ([self.pushType isEqualToString:@"voip"]) {
        self.alertTitleField.stringValue = @"";
        self.alertBodyField.stringValue = @"";
        self.badgeField.stringValue = @"";
        self.soundField.stringValue = @"";
        self.customJSONView.string = @"{\n  \"callUUID\": \"550e8400-e29b-41d4-a716-446655440000\",\n  \"callerName\": \"测试来电\",\n  \"handle\": \"10086\"\n}";
    } else {
        self.alertTitleField.stringValue = @"普通推送";
        self.alertBodyField.stringValue = @"这是一条测试推送";
        self.badgeField.stringValue = @"1";
        self.soundField.stringValue = @"default";
        self.customJSONView.string = @"{\n  \"bizType\": \"demo\"\n}";
    }
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
        [self showMessage:@"请填写 Token"];
        return;
    }
    if (!self.currentSec) {
        [self showMessage:@"请选择推送证书"];
        return;
    }
    if (![self prepareIdentity]) {
        return;
    }

    NSString *topic = [self normalizedTopic];
    if (topic.length == 0) {
        [self showMessage:@"请填写 Topic"];
        return;
    }

    NSString *collapseID = [self.collapseIDField.stringValue stringByReplacingOccurrencesOfString:@" " withString:@""];
    NSUInteger priority = self.priorityControl.selectedSegment == 0 ? 5 : 10;
    BOOL sandbox = self.environmentControl.selectedSegment == 0;

    [self log:@"发送推送"];
    [[NetworkManager sharedManager] postWithPayload:payload
                                            toToken:token
                                          withTopic:topic
                                           priority:priority
                                         collapseID:collapseID
                                        payloadType:self.pushType
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
    NSMutableDictionary *payload = [NSMutableDictionary dictionary];
    NSMutableDictionary *aps = [NSMutableDictionary dictionary];

    NSString *title = [self.alertTitleField.stringValue stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSString *body = [self.alertBodyField.stringValue stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (title.length > 0 || body.length > 0) {
        aps[@"alert"] = @{ @"title": title ?: @"", @"body": body ?: @"" };
    }

    NSString *badge = [self.badgeField.stringValue stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (badge.length > 0) {
        NSScanner *scanner = [NSScanner scannerWithString:badge];
        NSInteger badgeValue = 0;
        if (![scanner scanInteger:&badgeValue] || !scanner.isAtEnd || badgeValue < 0) {
            if (error) {
                *error = [NSError errorWithDomain:@"GenericPushWindowControllerErrorDomain" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"badge 必须是非负整数"}];
            }
            return nil;
        }
        aps[@"badge"] = @(badgeValue);
    }

    NSString *sound = [self.soundField.stringValue stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (sound.length > 0) {
        aps[@"sound"] = sound;
    }

    NSDictionary *custom = [self customJSONObjectWithError:error];
    if (error && *error) {
        return nil;
    }
    if (custom) {
        [payload addEntriesFromDictionary:custom];
        NSDictionary *customAPS = custom[@"aps"];
        if ([customAPS isKindOfClass:[NSDictionary class]]) {
            [aps addEntriesFromDictionary:customAPS];
        }
    }

    payload[@"aps"] = aps;
    NSData *data = [NSJSONSerialization dataWithJSONObject:payload options:NSJSONWritingPrettyPrinted error:error];
    if (!data) {
        return nil;
    }
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}

- (NSDictionary *)customJSONObjectWithError:(NSError **)error {
    NSString *trimmed = [self.customJSONView.string stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (trimmed.length == 0) {
        return nil;
    }
    NSData *data = [trimmed dataUsingEncoding:NSUTF8StringEncoding];
    id object = [NSJSONSerialization JSONObjectWithData:data options:0 error:error];
    if (!object || ![object isKindOfClass:[NSDictionary class]]) {
        if (error && !*error) {
            *error = [NSError errorWithDomain:@"GenericPushWindowControllerErrorDomain" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"自定义 JSON 必须是对象"}];
        }
        return nil;
    }
    return object;
}

- (NSString *)normalizedTopic {
    NSString *topic = [self.topicField.stringValue stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (self.topicSuffix.length > 0 && ![topic hasSuffix:self.topicSuffix]) {
        topic = [topic stringByAppendingString:self.topicSuffix];
    }
    return topic;
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
    textView.minSize = NSMakeSize(0, frame.size.height);
    textView.maxSize = NSMakeSize(CGFLOAT_MAX, CGFLOAT_MAX);
    textView.verticallyResizable = YES;
    textView.horizontallyResizable = NO;
    textView.autoresizingMask = NSViewWidthSizable;
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
