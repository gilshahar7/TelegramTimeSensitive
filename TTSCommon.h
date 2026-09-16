#import <Foundation/Foundation.h>

extern NSString *const TTSTelegramBundleID;

// User settings, written by the preference bundle.
extern BOOL TTSEnabled(void);
extern NSArray<NSString *> *TTSPromotedPeerIDs(void);
extern void TTSSetEnabled(BOOL enabled);
extern void TTSSetPeerID(NSString *peerID, BOOL promoted);

// Chats SpringBoard has seen a notification from, keyed by peer id with the
// chat title as the value. This is what the preference bundle lists, so there
// are no identifiers to look up by hand.
extern NSDictionary<NSString *, NSString *> *TTSDiscoveredChats(void);
extern void TTSRecordChat(NSString *peerID, NSString *title);

// Chat avatars, harvested from the communication intent Telegram's extension
// builds. Whatever encoding Telegram handed over is stored verbatim.
extern void TTSRecordAvatar(NSString *peerID, NSData *imageData);
extern NSData *TTSAvatarData(NSString *peerID);

// Peer ids come from the notification userInfo: "from_id" for private chats and
// bots, "chat_id" for groups, "channel_id" for channels (negative). This is the
// same value as BBBulletin.threadID. The composite "peerId" is also matched,
// but it is a different, namespace-encoded number.
extern BOOL TTSShouldPromote(NSDictionary *userInfo);
extern NSString *TTSPeerIDFromUserInfo(NSDictionary *userInfo);
