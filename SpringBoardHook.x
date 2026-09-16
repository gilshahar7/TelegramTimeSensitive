#import "TTSCommon.h"
#import <objc/runtime.h>

// Telegram ships com.apple.developer.usernotifications.communication and
// .filtering but not .time-sensitive, so iOS downgrades a timeSensitive level
// back to active. On iOS the UserNotifications server runs inside SpringBoard,
// so the gate is reachable from here. Reporting YES for Telegram also makes the
// Time Sensitive row appear in Settings > Notifications > Telegram.
@interface UNSNotificationSourceDescription : NSObject
@property (nonatomic, readonly) NSString *bundleIdentifier;
- (BOOL)allowTimeSensitive;
@end

// The avatar a communication notification is drawn with never reaches the
// bulletin as pixels: the extension hands its INImage to the intent, the system
// files a copy under /var/mobile/Library/Intents/Images, and the bulletin keeps
// a proxy URL pointing into that store.
@interface BBCommunicationContext : NSObject
@property (nonatomic, readonly) NSURL *contentURL;
@end

@interface BBBulletin : NSObject
@property (nonatomic, copy) NSString *sectionID;
@property (nonatomic, copy) NSString *threadID;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, readonly) BBCommunicationContext *communicationContext;
@end

static NSString *const TTSIntentsImages = @"/var/mobile/Library/Intents/Images";

// The context points at the image with an intents-remote-image-proxy URL whose
// proxyIdentifier, once decoded, is the file's name in the store.
static NSString *TTSAvatarFileName(BBCommunicationContext *context) {
    NSURLComponents *components = [NSURLComponents componentsWithURL:context.contentURL
                                            resolvingAgainstBaseURL:NO];

    for (NSURLQueryItem *item in components.queryItems) {
        if ([item.name isEqualToString:@"proxyIdentifier"]) return item.value;
    }

    return nil;
}

static void TTSHarvestAvatar(BBBulletin *bulletin) {
    NSString *fileName = TTSAvatarFileName(bulletin.communicationContext);
    if (fileName.length == 0) return;

    // A bulletin is configured several times over as it is decoded and copied,
    // so the same picture would otherwise be read and compared repeatedly.
    static NSMutableDictionary<NSString *, NSString *> *seen = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ seen = [NSMutableDictionary dictionary]; });

    @synchronized (seen) {
        if ([seen[bulletin.threadID] isEqualToString:fileName]) return;
        seen[bulletin.threadID] = fileName;
    }

    NSString *path = [TTSIntentsImages stringByAppendingPathComponent:fileName];
    TTSRecordAvatar(bulletin.threadID, [NSData dataWithContentsOfFile:path]);
}

%group UserNotificationsServer

%hook UNSNotificationSourceDescription

- (BOOL)allowTimeSensitive {
    if ([self.bundleIdentifier isEqualToString:TTSTelegramBundleID]) return YES;
    return %orig;
}

%end

%end

%group Bulletins

%hook BBBulletin

// Bulletins carry the chat title next to the peer id, which is what lets the
// preference bundle show a list of chats instead of raw identifiers. Empty
// bulletins get configured repeatedly while records are decoded and copied, so
// only populated ones are worth recording.
- (void)setInterruptionLevel:(NSInteger)level {
    %orig;

    if (self.title.length > 0 && [self.sectionID isEqualToString:TTSTelegramBundleID]) {
        TTSRecordChat(self.threadID, self.title);
        TTSHarvestAvatar(self);
    }
}

%end

%end

%ctor {
    if (objc_getClass("UNSNotificationSourceDescription")) {
        %init(UserNotificationsServer);
    }

    if (objc_getClass("BBBulletin")) {
        %init(Bulletins);
    }
}
