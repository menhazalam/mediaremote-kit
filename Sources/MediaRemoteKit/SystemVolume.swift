//
//  SystemVolume.swift
//  MediaRemoteKit
//
//  AppleScript-based system volume control.
//  MediaRemote.framework doesn't expose system volume, so we use AppleScript.

import Foundation
import os

/// Manages macOS system volume via AppleScript.
final class SystemVolume {
    
    static let shared = SystemVolume()
    
    private let queue = DispatchQueue(label: "com.mediaremotekit.volume", qos: .userInitiated)
    private let logger = Logger(subsystem: "com.mediaremotekit", category: "volume")
    
    private init() {}
    
    /// Returns the macOS system output volume (0–100).
    /// Returns 50 as a safe default if the script fails.
    func getVolume() -> Int {
        let script = "output volume of (get volume settings)"
        guard let desc = run(script) else { return 50 }
        
        let v = Int(desc.int32Value)
        if v >= 0 && v <= 100 { return v }
        
        if let s = desc.stringValue, let parsed = Int(s), parsed >= 0 && parsed <= 100 {
            return parsed
        }
        
        return 50
    }
    
    /// Sets the macOS system output volume (0–100).
    func setVolume(_ volume: Int) {
        let clamped = max(0, min(100, volume))
        let script = "set volume output volume \(clamped)"
        run(script)
    }
    
    // MARK: - AppleScript execution
    
    @discardableResult
    private func run(_ source: String) -> NSAppleEventDescriptor? {
        guard !source.isEmpty else { return nil }
        
        var result: NSAppleEventDescriptor?
        queue.sync {
            var error: NSDictionary?
            let desc = NSAppleScript(source: source)?.executeAndReturnError(&error)
            if let err = error {
                logger.debug("AppleScript error: \(String(describing: err))")
            }
            result = desc
        }
        return result
    }
}
