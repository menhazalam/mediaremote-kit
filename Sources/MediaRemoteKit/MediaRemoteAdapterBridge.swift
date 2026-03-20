//
//  MediaRemoteAdapterBridge.swift
//  MediaRemoteKit
//
//  Internal bridge between the Perl adapter and the public NowPlaying API.

import Foundation
import AppKit
import os

// MARK: - MediaRemoteAdapterBridge

@MainActor
final class MediaRemoteAdapterBridge: ObservableObject {
    
    static let shared = MediaRemoteAdapterBridge()
    
    private var adapterProcess: MediaRemoteAdapterProcess?
    private var isObserving = false
    private var currentState: MediaRemoteAdapterProcess.NowPlayingUpdate?
    private var artworkFileURL: URL?
    private let logger = Logger(subsystem: "com.mediaremotekit", category: "bridge")
    
    private init() {}
    
    func startObserving() {
        guard !isObserving else { return }
        
        let process = MediaRemoteAdapterProcess()
        self.adapterProcess = process
        
        do {
            try process.start { [weak self] update in
                Task { @MainActor [weak self] in
                    self?.handleUpdate(update)
                }
            }
            isObserving = true
            logger.info("Started observing")
        } catch {
            logger.error("Failed to start: \(error)")
        }
    }
    
    func stopObserving() {
        guard isObserving else { return }
        adapterProcess?.stop()
        adapterProcess = nil
        currentState = nil
        lastKnownBundleID = nil
        lastKnownTitle = nil
        cleanupArtworkFile()
        isObserving = false
        logger.info("Stopped observing")
    }
    
    private var lastKnownBundleID: String?
    private var lastKnownTitle: String?
    
    private func handleUpdate(_ update: MediaRemoteAdapterProcess.NowPlayingUpdate) {
        let previousBundleID = currentState?.bundleIdentifier
        let previousTitle = currentState?.title
        currentState = update
        
        // Track the last known valid bundle ID
        if let bundleID = update.bundleIdentifier {
            lastKnownBundleID = bundleID
        }
        
        // Clear artwork when track changes (different title)
        if let prevTitle = previousTitle, let currTitle = update.title, prevTitle != currTitle {
            cleanupArtworkFile()
        }
        
        // Only post playerListDidChange when switching between different valid players,
        // not when bundle ID becomes nil (which happens during transitions)
        if let prev = previousBundleID, let curr = update.bundleIdentifier, prev != curr {
            NotificationCenter.default.post(name: .playerListDidChange, object: nil)
            NotificationCenter.default.post(name: .mrNowPlayingApplicationDidChange, object: nil)
        }
        
        if let artworkData = update.artworkData, !artworkData.isEmpty {
            saveArtworkToTempFile(artworkData, mimeType: update.artworkMimeType)
        }
        
        NotificationCenter.default.post(name: .mrNowPlayingInfoDidChange, object: nil)
        NotificationCenter.default.post(name: .mrNowPlayingApplicationIsPlayingDidChange, object: nil)
    }
    
    private func saveArtworkToTempFile(_ data: Data, mimeType: String?) {
        cleanupArtworkFile()
        let ext = mimeType?.contains("png") == true ? "png" : "jpg"
        let tmpURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("mediaremotekit_art.\(ext)")
        try? data.write(to: tmpURL, options: .atomic)
        artworkFileURL = tmpURL
    }
    
    private func cleanupArtworkFile() {
        if let url = artworkFileURL {
            try? FileManager.default.removeItem(at: url)
            artworkFileURL = nil
        }
    }
    
    func playerNames(completion: @escaping ([String]) -> Void) {
        // Return the last known player even if nothing is currently playing
        let bundleID = currentState?.bundleIdentifier ?? lastKnownBundleID
        
        guard let bundleID = bundleID else {
            completion([])
            return
        }
        
        let name = displayName(forBundleID: bundleID)
        completion([name])
    }
    
    func nowPlayingInfo(forPlayer playerName: String, completion: @escaping ([String: Any]) -> Void) {
        guard let state = currentState else {
            completion([NowPlaying.InfoKey.isPlaying: false])
            return
        }
        
        var info: [String: Any] = [NowPlaying.InfoKey.isPlaying: state.playing]
        if let title = state.title { info[NowPlaying.InfoKey.title] = title }
        if let artist = state.artist { info[NowPlaying.InfoKey.artist] = artist }
        if let album = state.album { info[NowPlaying.InfoKey.album] = album }
        if let duration = state.duration { info[NowPlaying.InfoKey.duration] = duration }
        if let elapsed = state.elapsedTime { info[NowPlaying.InfoKey.elapsedTime] = elapsed }
        
        completion(info)
    }
    
    func artwork(forPlayer playerName: String) async -> (url: String?, fileUrl: URL?) {
        return (url: nil, fileUrl: artworkFileURL)
    }
    
    func sendCommand(_ command: NowPlaying.Command, toPlayer playerName: String) {
        let mrCommand: MRCommand
        switch command {
        case .play: mrCommand = .play
        case .pause: mrCommand = .pause
        case .togglePlayPause: mrCommand = .togglePlayPause
        case .stop: mrCommand = .stop
        case .nextTrack: mrCommand = .nextTrack
        case .previousTrack: mrCommand = .previousTrack
        case .seekForward: mrCommand = .seekForward
        case .seekBackward: mrCommand = .seekBackward
        }
        MediaRemoteFramework.shared.send(mrCommand)
    }
    
    func setPosition(_ seconds: Double, forPlayer playerName: String) {
        MediaRemoteFramework.shared.seek(to: seconds)
    }
    
    func setShuffle(_ mode: NowPlaying.ShuffleMode, forPlayer playerName: String) {
        MediaRemoteFramework.shared.send(.toggleShuffle)
    }
    
    func setRepeat(_ mode: NowPlaying.RepeatMode, forPlayer playerName: String) {
        MediaRemoteFramework.shared.send(.toggleRepeat)
    }
    
    private func displayName(forBundleID bundleID: String) -> String {
        let running = NSWorkspace.shared.runningApplications
        if let app = running.first(where: { $0.bundleIdentifier == bundleID }),
           let name = app.localizedName {
            return name
        }
        
        let components = bundleID.components(separatedBy: ".")
        if components.count >= 2 {
            return components[components.count - 2].capitalized
        }
        
        return bundleID
    }
}
