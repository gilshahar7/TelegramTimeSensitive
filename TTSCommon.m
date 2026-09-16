#import "TTSCommon.h"
#import <sys/stat.h>

NSString *const TTSTelegramBundleID = @"ph.telegra.Telegraph";

// Under the jailbreak root, not /var/mobile/Library/Preferences. The latter is
// the "other apps' preferences" location that the sandbox blocks, so Telegram's
// notification service extension gets EPERM reading it; the jbroot path is
// permitted by the jailbreak's sandbox extension.
//
// Read straight from disk rather than through CFPreferences, which caches
// aggressively across processes and would hand the extension stale values.
static NSString *const TTSSettingsPath = @"/var/jb/var/mobile/Library/Preferences/com.gilshahar7.telegramtimesensitive.plist";
static NSString *const TTSChatsPath = @"/var/jb/var/mobile/Library/Preferences/com.gilshahar7.telegramtimesensitive-chats.plist";
static NSString *const TTSAvatarsDirectory = @"/var/jb/var/mobile/Library/Preferences/com.gilshahar7.telegramtimesensitive-avatars";

static NSString *const TTSEnabledKey = @"Enabled";
static NSString *const TTSPeerIDsKey = @"PromotedPeerIDs";

static NSDictionary *TTSReadPlist(NSString *path) {
    return [NSDictionary dictionaryWithContentsOfFile:path] ?: @{};
}

static void TTSWritePlist(NSDictionary *plist, NSString *path) {
    [plist writeToFile:path atomically:YES];
}

// Telegram's notification service extension stays alive across many
// notifications, so the settings are parsed once and kept. A change made in
// Settings still has to apply to the very next notification, so every read
// stats the file and reparses when it has moved; that is far cheaper than
// decoding the plist, and an atomic write always lands a new modification time.
static NSDictionary *TTSSettings(void) {
    static NSDictionary *cached = nil;
    static struct timespec cachedModified = {0};
    static off_t cachedSize = -1;

    struct stat info;
    if (stat(TTSSettingsPath.fileSystemRepresentation, &info) != 0) return @{};

    @synchronized (TTSSettingsPath) {
        if (cached
            && info.st_mtimespec.tv_sec == cachedModified.tv_sec
            && info.st_mtimespec.tv_nsec == cachedModified.tv_nsec
            && info.st_size == cachedSize) {
            return cached;
        }

        cached = TTSReadPlist(TTSSettingsPath);
        cachedModified = info.st_mtimespec;
        cachedSize = info.st_size;
        return cached;
    }
}

BOOL TTSEnabled(void) {
    id value = TTSSettings()[TTSEnabledKey];
    return value ? [value boolValue] : YES;
}

NSArray<NSString *> *TTSPromotedPeerIDs(void) {
    NSArray *peerIDs = TTSSettings()[TTSPeerIDsKey];
    return [peerIDs isKindOfClass:NSArray.class] ? peerIDs : @[];
}

void TTSSetEnabled(BOOL enabled) {
    NSMutableDictionary *settings = [TTSReadPlist(TTSSettingsPath) mutableCopy];
    settings[TTSEnabledKey] = @(enabled);
    TTSWritePlist(settings, TTSSettingsPath);
}

void TTSSetPeerID(NSString *peerID, BOOL promoted) {
    NSMutableDictionary *settings = [TTSReadPlist(TTSSettingsPath) mutableCopy];

    NSArray *existing = settings[TTSPeerIDsKey];
    NSMutableArray *peerIDs = [existing isKindOfClass:NSArray.class] ? [existing mutableCopy] : [NSMutableArray array];

    [peerIDs removeObject:peerID];
    if (promoted) [peerIDs addObject:peerID];

    settings[TTSPeerIDsKey] = peerIDs;
    TTSWritePlist(settings, TTSSettingsPath);
}

NSDictionary<NSString *, NSString *> *TTSDiscoveredChats(void) {
    return TTSReadPlist(TTSChatsPath);
}

// Called for every Telegram bulletin, including the burst replayed on respring,
// so the known set is cached in memory and only a genuinely new or renamed chat
// touches the disk.
void TTSRecordChat(NSString *peerID, NSString *title) {
    if (peerID.length == 0 || title.length == 0) return;

    static NSMutableDictionary *cache = nil;
    static dispatch_queue_t queue = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        cache = [TTSDiscoveredChats() mutableCopy];
        queue = dispatch_queue_create("com.gilshahar7.tts.chats", DISPATCH_QUEUE_SERIAL);
    });

    dispatch_async(queue, ^{
        if ([cache[peerID] isEqualToString:title]) return;
        cache[peerID] = title;
        TTSWritePlist(cache, TTSChatsPath);
    });
}

static NSString *TTSAvatarPath(NSString *peerID) {
    return [NSString stringWithFormat:@"%@/%@.img", TTSAvatarsDirectory, peerID];
}

void TTSRecordAvatar(NSString *peerID, NSData *imageData) {
    if (peerID.length == 0 || imageData.length == 0) return;

    // An avatar arrives with every notification from the chat, so only a first
    // sighting or a changed picture is worth a write. Comparing sizes keeps
    // that check to a stat rather than a read of the stored copy.
    NSString *path = TTSAvatarPath(peerID);
    NSDictionary *attributes = [NSFileManager.defaultManager attributesOfItemAtPath:path error:NULL];
    if ([attributes[NSFileSize] unsignedLongLongValue] == imageData.length) return;

    [NSFileManager.defaultManager createDirectoryAtPath:TTSAvatarsDirectory
                            withIntermediateDirectories:YES
                                             attributes:nil
                                                  error:NULL];
    [imageData writeToFile:path atomically:YES];
}

NSData *TTSAvatarData(NSString *peerID) {
    if (peerID.length == 0) return nil;
    return [NSData dataWithContentsOfFile:TTSAvatarPath(peerID)];
}

BOOL TTSShouldPromote(NSDictionary *userInfo) {
    // One lookup for both values.
    NSDictionary *settings = TTSSettings();

    id enabled = settings[TTSEnabledKey];
    if (enabled && ![enabled boolValue]) return NO;

    NSArray<NSString *> *targets = settings[TTSPeerIDsKey];
    if (![targets isKindOfClass:NSArray.class] || targets.count == 0) return NO;

    for (NSString *key in @[@"from_id", @"chat_id", @"channel_id", @"peerId"]) {
        id value = userInfo[key];
        if (!value) continue;

        // Telegram writes these as strings, but normalise in case that changes.
        NSString *stringValue = [value isKindOfClass:NSString.class] ? value : [value description];
        if ([targets containsObject:stringValue]) return YES;
    }

    return NO;
}

// Only the three thread keys, and in this order: they carry the same value as
// BBBulletin.threadID, which is what discovered chats are keyed by.
NSString *TTSPeerIDFromUserInfo(NSDictionary *userInfo) {
    for (NSString *key in @[@"from_id", @"chat_id", @"channel_id"]) {
        id value = userInfo[key];
        if (!value) continue;
        return [value isKindOfClass:NSString.class] ? value : [value description];
    }

    return nil;
}
