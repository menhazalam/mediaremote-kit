# MediaRemoteKit

A Swift package for accessing Now Playing information and controlling media playback on macOS, bypassing macOS 15.4+ restrictions.

## Features

- ✅ **System-wide media detection** - Works with ANY app (Spotify, Apple Music, Safari, Chrome, VLC, etc.)
- ✅ **No permissions required** - No per-app Automation permissions needed
- ✅ **Real-time updates** - Streaming updates via mediaremote-adapter
- ✅ **Full control** - Play, pause, next, previous, seek, shuffle, repeat
- ✅ **Artwork support** - Fetch album artwork from any player
- ✅ **macOS 15.4+ compatible** - Bypasses entitlement restrictions

## Installation

### Swift Package Manager

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/menhazalam/mediaremote-kit", from: "1.0.0")
]
```

Or in Xcode:
1. File → Add Package Dependencies
2. Enter: `https://github.com/menhazalam/mediaremote-kit`
3. Click "Add Package"

## Usage

```swift
import MediaRemoteKit

// Start observing
NowPlaying.startObserving()

// Get active players
NowPlaying.playerNames { names in
    print("Active players: \(names)")
}

// Get now-playing info
NowPlaying.nowPlayingInfo(forPlayer: "Spotify") { info in
    if let title = info[NowPlaying.InfoKey.title] as? String {
        print("Now playing: \(title)")
    }
}

// Control playback
NowPlaying.send(.play, toPlayer: "Spotify")
NowPlaying.send(.pause, toPlayer: "Spotify")
NowPlaying.send(.nextTrack, toPlayer: "Spotify")

// Get artwork
let artwork = await NowPlaying.artwork(forPlayer: "Spotify")
if let fileURL = artwork.fileUrl {
    let image = NSImage(contentsOf: fileURL)
}

// System volume control
let currentVolume = NowPlaying.systemVolume()
NowPlaying.setSystemVolume(75)

// Stop observing when done
NowPlaying.stopObserving()
```

## How It Works

This package wraps [mediaremote-adapter](https://github.com/ungive/mediaremote-adapter) by spawning `/usr/bin/perl` (which has the required entitlements) to access the private MediaRemote.framework. This bypasses the macOS 15.4+ restrictions that prevent third-party apps from reading Now Playing information.

## Requirements

- macOS 13.0+
- Swift 5.9+

## Credits

- [mediaremote-adapter](https://github.com/ungive/mediaremote-adapter) by [@ungive](https://github.com/ungive) - The core Perl/C adapter
- Inspired by the need for system-wide media control after macOS 15.4 broke MediaRemote access

## License

BSD 3-Clause License - See LICENSE file

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
