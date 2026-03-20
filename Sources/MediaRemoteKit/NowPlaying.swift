//
//  NowPlaying.swift
//  MediaRemoteKit
//
//  Public API for accessing Now Playing information and controlling media playback on macOS.
//
//  This package wraps the mediaremote-adapter to bypass macOS 15.4+ entitlement restrictions,
//  providing system-wide access to Now Playing information from any media app.

import Foundation

/// Public API for Now Playing information and media control.
public enum NowPlaying {
    
    // MARK: - Types
    
    /// Media playback commands
    public enum Command: Int {
        case play = 0
        case pause = 1
        case togglePlayPause = 2
        case stop = 3
        case nextTrack = 4
        case previousTrack = 5
        case seekForward = 6
        case seekBackward = 7
    }
    
    /// Shuffle modes
    public enum ShuffleMode {
        case off
        case on
    }
    
    /// Repeat modes
    public enum RepeatMode {
        case off
        case one
        case all
    }
    
    /// Keys for the now-playing info dictionary
    public enum InfoKey {
        public static let title = "kMRMediaRemoteNowPlayingInfoTitle"
        public static let artist = "kMRMediaRemoteNowPlayingInfoArtist"
        public static let album = "kMRMediaRemoteNowPlayingInfoAlbum"
        public static let duration = "kMRMediaRemoteNowPlayingInfoDuration"
        public static let elapsedTime = "kMRMediaRemoteNowPlayingInfoElapsedTime"
        public static let isPlaying = "com.mediaremotekit.isPlaying"
    }
    
    // MARK: - Observation
    
    /// Starts observing Now Playing information.
    /// Call this once when your app launches.
    public static func startObserving() {
        Task { @MainActor in
            MediaRemoteAdapterBridge.shared.startObserving()
        }
    }
    
    /// Stops observing Now Playing information.
    /// Call this when your app terminates.
    public static func stopObserving() {
        Task { @MainActor in
            MediaRemoteAdapterBridge.shared.stopObserving()
        }
    }
    
    // MARK: - Player Information
    
    /// Returns the list of active media player names.
    /// - Parameter completion: Called with an array of player names (e.g., ["Spotify", "Safari"])
    @MainActor
    public static func playerNames(completion: @escaping ([String]) -> Void) {
        MediaRemoteAdapterBridge.shared.playerNames(completion: completion)
    }
    
    /// Fetches now-playing metadata for the specified player.
    /// - Parameters:
    ///   - playerName: The name of the player (from `playerNames()`)
    ///   - completion: Called with a dictionary containing metadata (title, artist, album, etc.)
    @MainActor
    public static func nowPlayingInfo(
        forPlayer playerName: String,
        completion: @escaping ([String: Any]) -> Void
    ) {
        MediaRemoteAdapterBridge.shared.nowPlayingInfo(forPlayer: playerName, completion: completion)
    }
    
    /// Fetches artwork for the specified player.
    /// - Parameter playerName: The name of the player
    /// - Returns: A tuple with optional URL (for remote artwork) and file URL (for local artwork)
    public static func artwork(forPlayer playerName: String) async -> (url: String?, fileUrl: URL?) {
        await MediaRemoteAdapterBridge.shared.artwork(forPlayer: playerName)
    }
    
    // MARK: - Playback Control
    
    /// Sends a playback command to the specified player.
    /// - Parameters:
    ///   - command: The command to send (play, pause, next, etc.)
    ///   - playerName: The name of the player
    /// - Returns: `true` if the command was sent successfully
    @MainActor
    @discardableResult
    public static func send(_ command: Command, toPlayer playerName: String) -> Bool {
        MediaRemoteAdapterBridge.shared.sendCommand(command, toPlayer: playerName)
        return true
    }
    
    /// Sets the playback position.
    /// - Parameters:
    ///   - seconds: The position in seconds
    ///   - playerName: The name of the player
    @MainActor
    public static func setPosition(_ seconds: Double, forPlayer playerName: String) {
        MediaRemoteAdapterBridge.shared.setPosition(seconds, forPlayer: playerName)
    }
    
    /// Sets the shuffle mode.
    /// - Parameters:
    ///   - mode: The shuffle mode
    ///   - playerName: The name of the player
    @MainActor
    public static func setShuffle(_ mode: ShuffleMode, forPlayer playerName: String) {
        MediaRemoteAdapterBridge.shared.setShuffle(mode, forPlayer: playerName)
    }
    
    /// Sets the repeat mode.
    /// - Parameters:
    ///   - mode: The repeat mode
    ///   - playerName: The name of the player
    @MainActor
    public static func setRepeat(_ mode: RepeatMode, forPlayer playerName: String) {
        MediaRemoteAdapterBridge.shared.setRepeat(mode, forPlayer: playerName)
    }
    
    // MARK: - System Volume
    
    /// Returns the macOS system output volume (0–100).
    /// - Returns: Volume level from 0 to 100
    public static func systemVolume() -> Int {
        return SystemVolume.shared.getVolume()
    }
    
    /// Sets the macOS system output volume (0–100).
    /// - Parameter volume: Volume level from 0 to 100
    public static func setSystemVolume(_ volume: Int) {
        SystemVolume.shared.setVolume(volume)
    }
}

// MARK: - Notification Names

extension Notification.Name {
    /// Posted when now-playing information changes
    public static let mrNowPlayingInfoDidChange =
        Notification.Name("kMRMediaRemoteNowPlayingInfoDidChangeNotification")
    
    /// Posted when the now-playing application changes
    public static let mrNowPlayingApplicationDidChange =
        Notification.Name("kMRMediaRemoteNowPlayingApplicationDidChangeNotification")
    
    /// Posted when the playing state changes (play/pause)
    public static let mrNowPlayingApplicationIsPlayingDidChange =
        Notification.Name("kMRMediaRemoteNowPlayingApplicationIsPlayingDidChange Notification")
}
