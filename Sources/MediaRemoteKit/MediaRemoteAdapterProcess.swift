//
//  MediaRemoteAdapterProcess.swift
//  MediaRemoteKit
//
//  Process manager for the mediaremote-adapter Perl script.
//
//  This spawns `/usr/bin/perl` with the bundled mediaremote-adapter.pl script
//  and MediaRemoteAdapter.dylib to bypass macOS 15.4+ entitlement checks.
//
//  The Perl script streams JSON updates to stdout in real-time, which we parse
//  and forward to subscribers.

import Foundation
import os

// MARK: - MediaRemoteAdapterProcess

/// Manages the lifecycle of the mediaremote-adapter Perl process and streams
/// now-playing updates.
final class MediaRemoteAdapterProcess {
    
    // MARK: - Types
    
    struct NowPlayingUpdate: Sendable {
        let bundleIdentifier: String?
        let playing: Bool
        let title: String?
        let artist: String?
        let album: String?
        let duration: Double?
        let elapsedTime: Double?
        let artworkData: Data?
        let artworkMimeType: String?
    }
    
    typealias UpdateHandler = @Sendable (NowPlayingUpdate) -> Void
    
    // MARK: - Properties
    
    private var process: Process?
    private var outputPipe: Pipe?
    private var updateHandler: UpdateHandler?
    private let queue = DispatchQueue(label: "com.mediaremotekit.adapter", qos: .userInitiated)
    
    private var isRunning = false
    private let logger = Logger(subsystem: "com.mediaremotekit", category: "adapter")
    
    // Line buffer to accumulate incomplete JSON lines from the pipe
    private var lineBuffer = Data()
    
    // MARK: - Lifecycle
    
    init() {}
    
    deinit {
        stop()
    }
    
    // MARK: - Control
    
    /// Starts the Perl adapter process and begins streaming updates.
    /// - Parameter handler: Called on a background queue whenever now-playing info changes.
    func start(updateHandler: @escaping UpdateHandler) throws {
        guard !isRunning else {
            logger.warning("MediaRemoteAdapter: already running")
            return
        }
        
        // Locate bundled resources in the package bundle
        guard let resourceURL = Bundle.module.url(forResource: "MediaRemoteAdapter", withExtension: "dylib", subdirectory: "Resources") else {
            throw NSError(
                domain: "com.mediaremotekit",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "MediaRemoteAdapter.dylib not found in package"]
            )
        }
        
        guard let scriptURL = Bundle.module.url(forResource: "mediaremote-adapter", withExtension: "pl", subdirectory: "Resources") else {
            throw NSError(
                domain: "com.mediaremotekit",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "mediaremote-adapter.pl not found in package"]
            )
        }
        
        // Optional: test client for validation
        let testClientURL = Bundle.module.url(forResource: "MediaRemoteAdapterTestClient", withExtension: nil, subdirectory: "Resources")
        
        self.updateHandler = updateHandler
        
        // Configure process
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
        
        var args = [scriptURL.path, resourceURL.path]
        if let testClient = testClientURL {
            args.append(testClient.path)
        }
        args.append("stream")
        args.append("--debounce=50")  // 50ms debounce to reduce update bursts
        
        process.arguments = args
        
        // Capture stdout and stderr
        let pipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = pipe
        process.standardError = errorPipe
        
        self.process = process
        self.outputPipe = pipe
        
        // Log stderr on background queue
        errorPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            if let errorLog = String(data: data, encoding: .utf8) {
                self?.logger.error("MediaRemoteAdapter (stderr): \(errorLog.trimmingCharacters(in: .whitespacesAndNewlines))")
            }
        }
        
        // Read stdout on background queue
        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            guard let self = self else { return }
            let data = handle.availableData
            guard !data.isEmpty else { return }
            self.queue.async {
                self.parseOutput(data)
            }
        }
        
        // Handle termination
        process.terminationHandler = { [weak self] _ in
            self?.logger.info("MediaRemoteAdapter: process terminated")
            self?.isRunning = false
        }
        
        // Launch
        try process.run()
        isRunning = true
        logger.info("MediaRemoteAdapter: started streaming")
    }
    
    /// Stops the Perl adapter process.
    func stop() {
        guard isRunning else { return }
        
        outputPipe?.fileHandleForReading.readabilityHandler = nil
        process?.terminate()
        process = nil
        outputPipe = nil
        updateHandler = nil
        isRunning = false
        lineBuffer.removeAll()
        
        logger.info("MediaRemoteAdapter: stopped")
    }
    
    // MARK: - Output parsing
    
    private func parseOutput(_ data: Data) {
        // Append incoming data to the line buffer
        lineBuffer.append(data)
        
        // Process all complete lines (terminated by newline)
        while let newlineRange = lineBuffer.range(of: Data([0x0A])) { // 0x0A = '\n'
            let lineData = lineBuffer.subdata(in: 0..<newlineRange.lowerBound)
            lineBuffer.removeSubrange(0..<newlineRange.upperBound)
            
            guard let line = String(data: lineData, encoding: .utf8), !line.isEmpty else {
                continue
            }
            
            parseJSONLine(line)
        }
    }
    
    private func parseJSONLine(_ line: String) {
        guard let data = line.data(using: .utf8) else { return }
        
        do {
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let type = json["type"] as? String,
                  type == "data",
                  let payload = json["payload"] as? [String: Any]
            else {
                return
            }
            
            // Parse the payload
            let update = NowPlayingUpdate(
                bundleIdentifier: payload["bundleIdentifier"] as? String,
                playing: payload["playing"] as? Bool ?? false,
                title: payload["title"] as? String,
                artist: payload["artist"] as? String,
                album: payload["album"] as? String,
                duration: parseDuration(payload),
                elapsedTime: parseElapsedTime(payload),
                artworkData: parseArtworkData(payload),
                artworkMimeType: payload["artworkMimeType"] as? String
            )
            
            updateHandler?(update)
            
        } catch {
            logger.debug("MediaRemoteAdapter: JSON parse error: \(error)")
        }
    }
    
    private func parseDuration(_ payload: [String: Any]) -> Double? {
        // Duration can be in seconds (duration) or microseconds (durationMicros)
        if let micros = payload["durationMicros"] as? Int64 {
            return Double(micros) / 1_000_000.0
        }
        return payload["duration"] as? Double
    }
    
    private func parseElapsedTime(_ payload: [String: Any]) -> Double? {
        // Elapsed time can be in seconds or microseconds
        if let micros = payload["elapsedTimeMicros"] as? Int64 {
            return Double(micros) / 1_000_000.0
        }
        return payload["elapsedTime"] as? Double
    }
    
    private func parseArtworkData(_ payload: [String: Any]) -> Data? {
        guard let base64 = payload["artworkData"] as? String else { return nil }
        return Data(base64Encoded: base64)
    }
}
