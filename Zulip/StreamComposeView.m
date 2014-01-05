//
//  StreamComposeView.m
//  Zulip
//
//  Created by Michael Walker on 1/3/14.
//
//

#import "StreamComposeView.h"
#import "ZulipAPIClient.h"
#import <Crashlytics/Crashlytics.h>
#import "UIView+Layout.h"

static const CGFloat StreamComposeViewToWidth = 121.f;
static const CGFloat StreamComposeViewSubjectWidth = 166.f;
static const CGFloat StreamComposeViewMessageWidth = 200.f;
static const CGFloat StreamComposeViewInputHeight = 30.f;

@interface StreamComposeView ()<UITextViewDelegate>

@property (strong, nonatomic) UIToolbar *mainBar;
@property (strong, nonatomic) UITextView *messageInput;

@property (strong, nonatomic) UIToolbar *subjectBar;
@property (strong, nonatomic) UITextField *to;
@property (strong, nonatomic) UITextField *subject;
@property (strong, nonatomic) UIBarButtonItem *toItem;
@property (strong, nonatomic) UIBarButtonItem *subjectItem;

@end

@implementation StreamComposeView

- (id)init {
    if (self = [super init]) {
        self.mainBar = [[UIToolbar alloc] init];
        [self.mainBar sizeToFit];
        CGSize toolbarSize = self.mainBar.frame.size;

        [self resizeTo:CGSizeMake(toolbarSize.width, toolbarSize.height * 2)];

        UIBarButtonItem *flexibleSpace = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
        UIBarButtonItem *fixedSpace = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace target:nil action:nil];


        [self.mainBar moveToPoint:CGPointMake(0, toolbarSize.height)];
        self.mainBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;

        UIBarButtonItem *sendButton = [[UIBarButtonItem alloc] initWithTitle:@"Send" style:UIBarButtonItemStyleDone target:self action:@selector(didTapSendButton)];

        self.messageInput = [[UITextView alloc] initWithFrame:CGRectMake(0, 0, StreamComposeViewMessageWidth, StreamComposeViewInputHeight)];
        self.messageInput.layer.cornerRadius = 5.f;
        self.messageInput.layer.borderColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0.1f].CGColor;
        self.messageInput.layer.borderWidth = 1.f;
        self.messageInput.delegate = self;
        self.messageInput.autoresizingMask = UIViewAutoresizingFlexibleWidth;

        UIBarButtonItem *inputItem = [[UIBarButtonItem alloc] initWithCustomView:self.messageInput];


        self.mainBar.items = @[flexibleSpace, inputItem, flexibleSpace, sendButton, fixedSpace];
        [self addSubview:self.mainBar];


        // Subject bar
        CGRect secondBarFrame = CGRectZero;
        secondBarFrame.size = toolbarSize;
        self.subjectBar = [[UIToolbar alloc] initWithFrame:secondBarFrame];
        self.subjectBar.hidden = YES;
        self.subjectBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;

        self.to = [[UITextField alloc] initWithFrame:CGRectMake(0, 0, StreamComposeViewToWidth, StreamComposeViewInputHeight)];
        self.to.placeholder = @"Stream";
        self.to.borderStyle = UITextBorderStyleRoundedRect;
        self.to.backgroundColor = [UIColor whiteColor];
        self.to.autocapitalizationType = UITextAutocapitalizationTypeNone;
        self.toItem = [[UIBarButtonItem alloc] initWithCustomView:self.to];

        self.subject = [[UITextField alloc] initWithFrame:CGRectMake(0, 0, StreamComposeViewSubjectWidth, StreamComposeViewInputHeight)];
        self.subject.placeholder = @"Subject";
        self.subject.borderStyle = UITextBorderStyleRoundedRect;
        self.subject.autocapitalizationType = UITextAutocapitalizationTypeNone;
        self.subject.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        self.subject.backgroundColor = [UIColor whiteColor];
        self.subjectItem = [[UIBarButtonItem alloc] initWithCustomView:self.subject];

        self.subjectBar.items = @[self.toItem, fixedSpace, self.subjectItem];
        [self addSubview:self.subjectBar];
    }
    return self;
}

- (void)showSubjectBar {
    self.subjectBar.hidden = NO;
}

- (void)hideSubjectBar {
    self.subjectBar.hidden = YES;
}

- (CGFloat)visibleHeight {
    if (self.subjectBar.hidden) {
        return self.mainBar.frame.size.height;
    } else {
        return self.frame.size.height;
    }
}

- (NSString *)recipient {
    return self.to.text;
}

- (void)setRecipient:(NSString *)recipient {
    self.to.text = recipient;
}

- (void)setIsPrivate:(BOOL)isPrivate {
    _isPrivate = isPrivate;

    UIBarButtonItem *fixedSpace = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace target:nil action:nil];

    UIBarButtonItem *flexibleSpace = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];


    if (isPrivate) {
        self.to.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        self.to.placeholder = @"One or more people...";
        [self.to sizeToFit];
        self.subjectBar.items = @[flexibleSpace, self.toItem, flexibleSpace];
    } else {
        self.to.autoresizingMask = UIViewAutoresizingNone;
        self.to.placeholder = @"Stream";

        self.subjectBar.items = @[self.toItem, fixedSpace, self.subjectItem];
    }
}

- (BOOL)isFirstResponder {
    return self.messageInput.isFirstResponder || self.to.isFirstResponder || self.subject.isFirstResponder;
}

#pragma clang pop
- (BOOL)resignFirstResponder {
    [super resignFirstResponder];
    [self.messageInput resignFirstResponder];
    [self.to resignFirstResponder];
    [self.subject resignFirstResponder];

    return YES;
}

#pragma mark - Event handlers
- (void)didTapSendButton {
    NSDictionary *postFields;
    if (self.isPrivate) {
        NSArray* recipientArray = [self.to.text componentsSeparatedByString: @","];

        NSError *error = nil;
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:recipientArray options:NSJSONWritingPrettyPrinted error:&error];
        NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];

        postFields = @{ @"type": @"private",
                        @"to": jsonString,
                        @"content": self.messageInput.text };
    } else {
        postFields = @{ @"type": @"stream",
                        @"to": self.to.text,
                        @"subject": self.subject.text,
                        @"content": self.messageInput.text };
    }

    [[ZulipAPIClient sharedClient] postPath:@"messages" parameters:postFields success:nil failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        CLS_LOG(@"Error posting message: %@", [error localizedDescription]);
    }];

    self.messageInput.text = @"";
    self.to.text = @"";
    self.subject.text = @"";
}

#pragma mark - UITextViewDelegate
- (void)textViewDidChange:(UITextView *)textView
{
    CGFloat fixedWidth = textView.frame.size.width;
    CGSize newSize = [textView sizeThatFits:CGSizeMake(fixedWidth, MAXFLOAT)];
    CGRect newFrame = textView.frame;
    newFrame.size = CGSizeMake(fmaxf(newSize.width, fixedWidth), newSize.height);

    CGFloat heightDifference = newSize.height - textView.frame.size.height;

    CGRect toolbarFrame = self.mainBar.frame;
    toolbarFrame.size.height += heightDifference;

    CGRect viewFrame = self.frame;
    viewFrame.size.height += heightDifference;
    viewFrame.origin.y -= heightDifference;

    [UIView animateWithDuration:0.1f animations:^{
        textView.frame = newFrame;
        self.mainBar.frame = toolbarFrame;
        self.frame = viewFrame;
    }];
}

@end