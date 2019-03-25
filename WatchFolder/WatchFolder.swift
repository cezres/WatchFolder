//
//  WatchFolder.swift
//  WatchFolder
//
//  Created by 翟泉 on 2019/3/25.
//  Copyright © 2019 cezres. All rights reserved.
//

import Foundation

public protocol  WatchFolderDelegate: class {
    func watchFolderNotification(_ folder: WatchFolder)
}

public enum WatchFolderError: Error {
    case invalidFolderPath
    case otherError
}

public class WatchFolder {
    fileprivate var directoryFD: Int32 = -1
    fileprivate var directoryDescriptor: CFFileDescriptor!
    fileprivate var kq: Int32 = -1
    fileprivate var ref: WatchFolder!

    public let url: URL
    public weak var delegate: WatchFolderDelegate?

    public init(url: URL) {
        self.url = url
    }

    public func invalidate() {
        if directoryDescriptor != nil {
            CFFileDescriptorInvalidate(directoryDescriptor)
            directoryDescriptor = nil
            kq = -1
        }
        if directoryFD != -1 {
            close(directoryFD)
            directoryFD = -1
        }
        ref = nil
    }

    public func start() throws {
        guard directoryDescriptor == nil && directoryFD == -1 && kq == -1 else { return }
        guard let path = url.path.cString(using: .utf8) else { throw WatchFolderError.invalidFolderPath }
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue else {
            throw WatchFolderError.invalidFolderPath
        }
        var error: Error!

        directoryFD = open(path, O_EVTONLY)
        if directoryFD >= 0 {
            kq = kqueue()
            if kq >= 0 {
                var event = kevent()
                event.ident = UInt(directoryFD)
                event.filter = Int16(EVFILT_VNODE)
                event.flags = UInt16(EV_ADD | EV_CLEAR)
                event.fflags = UInt32(NOTE_WRITE)
                event.data = 0
                event.udata = nil
                let errNum = kevent(kq, &event, 1, nil, 0, nil)
                if (errNum == 0) {
                    ref = self
                    var context = CFFileDescriptorContext(version: 0, info: &ref, retain: nil, release: nil, copyDescription: nil)
                    directoryDescriptor = CFFileDescriptorCreate(nil, kq, true, FileDescriptorCallBack, &context)
                    if directoryDescriptor != nil {
                        if let runLoopSource = CFFileDescriptorCreateRunLoopSource(nil, directoryDescriptor, 0) {
                            CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, CFRunLoopMode.defaultMode)
                            CFFileDescriptorEnableCallBacks(directoryDescriptor, kCFFileDescriptorReadCallBack)
                            return
                        }
                        CFFileDescriptorInvalidate(directoryDescriptor)
                        directoryDescriptor = nil
                    }
                    ref = nil
                }
                close(kq)
                kq = -1
            }
            close(directoryFD)
            directoryFD = -1
        } else {
            error = WatchFolderError.invalidFolderPath
        }
        throw error ?? WatchFolderError.otherError
    }

    fileprivate func callback() {
        delegate?.watchFolderNotification(self)
    }
}

private func FileDescriptorCallBack(kqRef: CFFileDescriptor?, callBackTypes: CFOptionFlags, info: UnsafeMutableRawPointer?) -> Void {
    guard let result = info?.load(as: WatchFolder.self).ref else { return }
    var event = kevent()
    var timeout = timespec(tv_sec: 0, tv_nsec: 0)
    var eventCount: Int32 = 0
    eventCount = kevent(result.kq, nil, 0, &event, 1, &timeout)
    assert(eventCount >= 0 && eventCount < 2)
    CFFileDescriptorEnableCallBacks(result.directoryDescriptor, kCFFileDescriptorReadCallBack)

    result.callback()
}

