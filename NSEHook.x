#import "TTSCommon.h"
#import <UserNotifications/UserNotifications.h>
#import <objc/runtime.h>

// Telegram decrypts the push payload inside its notification service extension,
// so this is the earliest point where the chat is identifiable and the last
// point where the content is still mutable.
static UNNotificationContent *TTSPromote(UNNotificationContent *content) {
    if (!TTSShouldPromote(content.userInfo)) return content;

    // Mutate in place: Telegram runs the content through -updating:fromProvider:
    // with an INSendMessageIntent, and a mutableCopy can drop that communication
    // attribution (sender name and avatar).
    @try {
        [content setValue:@(UNNotificationInterruptionLevelTimeSensitive) forKey:@"interruptionLevel"];
    } @catch (NSException *exception) {}

    if (content.interruptionLevel == UNNotificationInterruptionLevelTimeSensitive) {
        return content;
    }

    UNMutableNotificationContent *mutableContent = [content mutableCopy];
    mutableContent.interruptionLevel = UNNotificationInterruptionLevelTimeSensitive;
    return mutableContent;
}

%group TelegramNotificationService

%hook NotificationService

- (void)didReceiveNotificationRequest:(UNNotificationRequest *)request
                   withContentHandler:(void (^)(UNNotificationContent *))contentHandler {
    // Wrapping the block covers both the normal completion and
    // serviceExtensionTimeWillExpire, since Telegram stores the block we pass.
    %orig(request, ^(UNNotificationContent *content) {
        contentHandler(TTSPromote(content));
    });
}

%end

%end

%ctor {
    if (objc_getClass("NotificationService")) {
        %init(TelegramNotificationService);
    }
}
