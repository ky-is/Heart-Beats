# Going fully native on the Mac

The Mac app is Mac Catalyst. A native macOS target would drop the AppKit bundle workaround for the menu bar item (`MenuBar/`) and give the Mac its own UI. Both alternatives to Catalyst were tested on 2026-11-01 with Xcode 27.2 and the macOS 27.2 SDK, and neither is ready.

## What we're waiting for

Switch when the first three are true. Each was checked in a native macOS app, sandboxed with only `com.apple.security.assets.music.read-only`, built as a universal binary (arm64 and x86_64), and the results were the same on both slices.

1. **MediaPlayer's library and player on macOS.** `MPMediaLibrary`, `MPMediaQuery`'s library classes and `MPMusicPlayerController` are `API_UNAVAILABLE(macos)` in the SDK headers. `MusicLibrary`, `GroupedCollection`, `YearsCollection`, `MacPlayback` and `playSongs` are all built on them, so without them the data and playback layers are written twice.
2. **Playing local library songs natively.** `SystemMusicPlayer` is unavailable on macOS. `ApplicationMusicPlayer` is available (macOS 14+) but plays inside the app rather than in Music, and MusicKit library song IDs (`i.JLrroFbMxZJA`) don't match the library persistent IDs `iTunesLibrary` returns, so each song would have to be matched by title, artist and album. The other route is scripting Music.app by persistent ID, which needs an Automation permission and the scripting-targets entitlement. Neither was tried playing audio, since that would make sound and could change the library.
3. **Favorites on `iTunesLibrary`.** `ITLibMediaItem` has no favorite flag. The Apple Music favorites that count with 5-star songs (`AppleMusicFavorites`) would have to come from MusicKit on Mac.

Smaller gaps to settle first:

- **Ratings.** In the test, 3,688 of 7,665 five-star songs were flagged `isRatingComputed` (derived from the album's rating). It's unchecked whether iOS `MPMediaItem.rating` counts those too, so the "5-star" lists might not match between iOS and Mac.
- **Change notifications.** `MPMediaLibraryDidChangeNotification` is unavailable on macOS. How a native app would learn the library changed wasn't tested.
- **Counts.** `iTunesLibrary` reported 925 artists against 907 through MediaPlayer on the same library, so grouping and name normalizing would need checking.

## What works today

| | Mac Catalyst (shipping) | iOS app on Mac (Designed for iPad) | Native macOS |
|---|---|---|---|
| Library, ratings, artwork | Yes | Yes (13,145 songs, 7,657 five-star, artwork) | Yes, through `iTunesLibrary` (13,228 songs) |
| Player | `MPMusicPlayerController` | Queue accepted, no audio tried | `ApplicationMusicPlayer` only |
| Menu bar item, Dock icon control | Yes, through the AppKit bundle in `MenuBar/` | No | Yes, `MenuBarExtra` |

Designed for iPad was ruled out for the menu bar: it can't create a status item or hide its Dock icon. There, `audio-player-event:` also doesn't open, so the iOS play path would still need the Catalyst `music://` route.

## How to check again

- Whether MediaPlayer is available on macOS yet:

```bash
grep -n "API_UNAVAILABLE" "$(xcrun --sdk macosx --show-sdk-path)/System/Library/Frameworks/MediaPlayer.framework/Headers/MPMediaLibrary.h"
```

- Whether `SystemMusicPlayer` is available on macOS yet:

```bash
grep -n -B3 "class SystemMusicPlayer" "$(xcrun --sdk macosx --show-sdk-path)/System/Library/Frameworks/MusicKit.framework/Modules/MusicKit.swiftmodule/arm64e-apple-macos.swiftinterface"
```

- A bare command-line tool can't reach the Music library service (`com.apple.amp.library.framework`), so probes need to be an app bundle signed with the team identity and, for the sandboxed case, the entitlement above.
