//
//  MediaRemoteFramework.swift
//  MediaRemoteKit
//
//  Minimal wrapper for MediaRemote.framework command sending.
//  Commands work universally without entitlements.

import Foundation

enum MRCommand: Int32 {
    case play = 0
    case pause = 1
    case togglePlayPause = 2
    case stop = 3
    case nextTrack = 4
    case previousTrack = 5
    case toggleShuffle = 6
    case toggleRepeat = 7
    case seekForward = 17
    case seekBackward = 18
}

final class MediaRemoteFramework {
    static let shared = MediaRemoteFramework()
    
    private typealias SendCommandFn = @convention(c) (UInt32, AnyObject?) -> DarwinBoolean
    private typealias SetElapsedTimeFn = @convention(c) (Double) -> DarwinBoolean
    
    private let sendCommand: SendCommandFn?
    private let setElapsedTime: SetElapsedTimeFn?
    
    private init() {
        guard let handle = dlopen(
            "/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote",
            RTLD_NOW
        ) else {
            sendCommand = nil
            setElapsedTime = nil
            return
        }
        
        if let ptr = dlsym(handle, "MRMediaRemoteSendCommand") {
            sendCommand = unsafeBitCast(ptr, to: SendCommandFn.self)
        } else {
            sendCommand = nil
        }
        
        if let ptr = dlsym(handle, "MRMediaRemoteSetElapsedTime") {
            setElapsedTime = unsafeBitCast(ptr, to: SetElapsedTimeFn.self)
        } else {
            setElapsedTime = nil
        }
    }
    
    func send(_ command: MRCommand) {
        guard let fn = sendCommand else { return }
        _ = fn(UInt32(command.rawValue), nil)
    }
    
    func seek(to seconds: Double) {
        guard let fn = setElapsedTime else { return }
        _ = fn(seconds)
    }
}
