#import "../TTSCommon.h"
#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>

static NSString *const TTSPeerIDProperty = @"TTSPeerID";

static CGFloat const TTSIconSide = 29.0;

static UIImage *TTSCircularImage(NSData *imageData) {
    UIImage *image = [UIImage imageWithData:imageData];
    if (!image) return nil;

    CGRect bounds = CGRectMake(0, 0, TTSIconSide, TTSIconSide);
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithBounds:bounds];

    return [renderer imageWithActions:^(UIGraphicsImageRendererContext *context) {
        [[UIBezierPath bezierPathWithOvalInRect:bounds] addClip];
        [image drawInRect:bounds];
    }];
}

// Telegram only attaches an avatar when the chat has a picture cached, so the
// rest get initials on a colour picked from the peer id, which keeps a chat
// looking the same every time the pane is opened.
static UIImage *TTSMonogramImage(NSString *title, NSString *peerID) {
    static NSArray<UIColor *> *palette = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        palette = @[[UIColor colorWithRed:0.90 green:0.36 blue:0.33 alpha:1.0],
                    [UIColor colorWithRed:0.95 green:0.65 blue:0.24 alpha:1.0],
                    [UIColor colorWithRed:0.60 green:0.47 blue:0.85 alpha:1.0],
                    [UIColor colorWithRed:0.44 green:0.75 blue:0.36 alpha:1.0],
                    [UIColor colorWithRed:0.25 green:0.70 blue:0.85 alpha:1.0],
                    [UIColor colorWithRed:0.22 green:0.53 blue:0.91 alpha:1.0],
                    [UIColor colorWithRed:0.93 green:0.45 blue:0.60 alpha:1.0]];
    });

    NSString *initial = title.length > 0 ? [[title substringToIndex:1] uppercaseString] : @"?";
    UIColor *color = palette[ABS((NSInteger)peerID.hash) % palette.count];

    CGRect bounds = CGRectMake(0, 0, TTSIconSide, TTSIconSide);
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithBounds:bounds];

    return [renderer imageWithActions:^(UIGraphicsImageRendererContext *context) {
        [color setFill];
        [[UIBezierPath bezierPathWithOvalInRect:bounds] fill];

        NSDictionary *attributes = @{
            NSFontAttributeName: [UIFont systemFontOfSize:TTSIconSide * 0.5 weight:UIFontWeightMedium],
            NSForegroundColorAttributeName: UIColor.whiteColor
        };

        CGSize size = [initial sizeWithAttributes:attributes];
        [initial drawAtPoint:CGPointMake((TTSIconSide - size.width) / 2.0, (TTSIconSide - size.height) / 2.0)
              withAttributes:attributes];
    }];
}

static UIImage *TTSChatIcon(NSString *peerID, NSString *title) {
    return TTSCircularImage(TTSAvatarData(peerID)) ?: TTSMonogramImage(title, peerID);
}

@interface TTSRootListController : PSListController
@end

@implementation TTSRootListController

- (NSArray *)specifiers {
    if (_specifiers) return _specifiers;

    NSMutableArray *specifiers = [NSMutableArray array];

    [specifiers addObject:[PSSpecifier emptyGroupSpecifier]];

    PSSpecifier *enabled = [PSSpecifier preferenceSpecifierNamed:@"Enabled"
                                                         target:self
                                                            set:@selector(setEnabledValue:specifier:)
                                                            get:@selector(readEnabledValue:)
                                                         detail:nil
                                                           cell:PSSwitchCell
                                                           edit:nil];
    [specifiers addObject:enabled];

    NSDictionary<NSString *, NSString *> *chats = TTSDiscoveredChats();

    PSSpecifier *group = [PSSpecifier groupSpecifierWithName:@"Chats"];
    [group setProperty:(chats.count > 0
                        ? @"Notifications from the selected chats are promoted to Time Sensitive, so they break through Focus and stay on the lock screen."
                        : @"No chats yet. A chat appears here once it has sent you a notification.")
                forKey:@"footerText"];
    [specifiers addObject:group];

    NSArray<NSString *> *peerIDs = [chats.allKeys sortedArrayUsingComparator:^NSComparisonResult(NSString *a, NSString *b) {
        return [chats[a] localizedCaseInsensitiveCompare:chats[b]];
    }];

    for (NSString *peerID in peerIDs) {
        PSSpecifier *chat = [PSSpecifier preferenceSpecifierNamed:chats[peerID]
                                                          target:self
                                                             set:@selector(setChatValue:specifier:)
                                                             get:@selector(readChatValue:)
                                                          detail:nil
                                                            cell:PSSwitchCell
                                                            edit:nil];
        [chat setProperty:peerID forKey:TTSPeerIDProperty];
        [chat setProperty:TTSChatIcon(peerID, chats[peerID]) forKey:@"iconImage"];
        [specifiers addObject:chat];
    }

    _specifiers = specifiers;
    return _specifiers;
}

// Chats are discovered while this pane is closed, so rebuild the list each time
// it appears rather than only on first load.
- (void)viewWillAppear:(BOOL)animated {
    _specifiers = nil;
    [self reloadSpecifiers];
    [super viewWillAppear:animated];
}

- (id)readEnabledValue:(PSSpecifier *)specifier {
    return @(TTSEnabled());
}

- (void)setEnabledValue:(id)value specifier:(PSSpecifier *)specifier {
    TTSSetEnabled([value boolValue]);
}

- (id)readChatValue:(PSSpecifier *)specifier {
    NSString *peerID = [specifier propertyForKey:TTSPeerIDProperty];
    return @([TTSPromotedPeerIDs() containsObject:peerID]);
}

- (void)setChatValue:(id)value specifier:(PSSpecifier *)specifier {
    TTSSetPeerID([specifier propertyForKey:TTSPeerIDProperty], [value boolValue]);
}

@end
