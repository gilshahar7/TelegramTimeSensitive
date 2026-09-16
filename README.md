# TelegramTimeSensitive

Promotes notifications from chosen Telegram chats to Time Sensitive, so they break through Focus modes, skip the notification summary, and stay on the lock screen.

I wrote this for a Telegram bot that tells me when my doorbell rings. Muting everything else in Telegram but still getting the doorbell through Do Not Disturb was not possible otherwise.

Tested on iOS 16.1.1 with Dopamine (rootless).

## Settings

The tweak adds a pane to Settings called Telegram Time Sensitive. There is a master switch, plus one switch per chat.

Chats are not typed in by hand. Every time SpringBoard shows a Telegram notification, the tweak records that chat's peer id and title, so the chat appears in the list with its name and profile picture. Enable the ones you care about. A chat shows up after it has sent you at least one notification.

## How it works

Three pieces:

1. A hook in Telegram's notification service extension, which is where the push payload gets decrypted and is the last place the content can still be changed. If the chat is enabled, the interruption level is set to time sensitive.

2. A hook on `-[UNSNotificationSourceDescription allowTimeSensitive]` in SpringBoard. Telegram ships the `usernotifications.communication` and `.filtering` entitlements but not `.time-sensitive`, so iOS would otherwise quietly downgrade the level back to active. Returning YES for Telegram also makes the Time Sensitive row appear under Settings > Notifications > Telegram.

3. A hook on `-[BBBulletin setInterruptionLevel:]` in SpringBoard, used only to collect the chat list. The bulletin carries the title next to the peer id, and its communication context points at the avatar the system filed under `/var/mobile/Library/Intents/Images`, which is where the profile pictures in the settings pane come from.

Settings live in `/var/jb/var/mobile/Library/Preferences/com.gilshahar7.telegramtimesensitive.plist`. That path rather than the usual one because the notification service extension is sandboxed and gets denied on other apps' preferences. It can read the jbroot copy, though it cannot write there, which is why the avatars are collected by SpringBoard and not by the extension.

## Building

Needs [Theos](https://theos.dev).

```
make package FINALPACKAGE=1
```

Then install the deb from `packages/`.

One thing that will waste your time if you hack on this: Telegram's notification service extension process stays alive for a long time between notifications, so after installing a new build it keeps running the old dylib. Kill it first.

```
killall -9 NotificationServiceExtensionv1
```

Changes to the SpringBoard hooks need a respring.

## License

MIT
