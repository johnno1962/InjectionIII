//
//  FileWatcher.swift
//  InjectionIII
//
//  Created by John Holdsworth on 08/03/2015.
//  Copyright (c) 2015 John Holdsworth. All rights reserved.
//

import Foundation

let INJECTABLE_PATTERN = "[^~]\\.(mm?|swift|storyboard|xib)$"

public typealias InjectionCallback = (_ filesChanged: NSArray) -> Void

public class FileWatcher: NSObject {
    var fileEvents: FSEventStreamRef! = nil
    var callback: InjectionCallback
    var context = FSEventStreamContext()

    @objc public init(root: String, callback: @escaping InjectionCallback) {
        self.callback = callback
        super.init()
        context.info = unsafeBitCast(self, to: UnsafeMutableRawPointer.self)
        fileEvents = FSEventStreamCreate(kCFAllocatorDefault,
             { (streamRef: FSEventStreamRef,
                clientCallBackInfo: UnsafeMutableRawPointer?,
                numEvents: Int, eventPaths: UnsafeMutableRawPointer,
                eventFlags: UnsafePointer<FSEventStreamEventFlags>,
                eventIds: UnsafePointer<FSEventStreamEventId>) in
                 let watcher = unsafeBitCast(clientCallBackInfo, to: FileWatcher.self)
                 // Check that the event flags include an item renamed flag, this helps avoid
                 // unnecessary injection, such as triggering injection when switching between
                 // files in Xcode.
                 for i in 0 ..< numEvents {
                     let flag = Int(eventFlags[i])
                     if (flag & (kFSEventStreamEventFlagItemRenamed | kFSEventStreamEventFlagItemModified)) != 0 {
                        let changes = unsafeBitCast(eventPaths, to: NSArray.self)
                         DispatchQueue.main.async {
                             watcher.filesChanged(changes: changes)
                         }
                         return
                     }
                 }
             },
             &context, [root] as CFArray,
             FSEventStreamEventId(kFSEventStreamEventIdSinceNow), 0.1,
             FSEventStreamCreateFlags(kFSEventStreamCreateFlagUseCFTypes |
                kFSEventStreamCreateFlagFileEvents))!
        FSEventStreamScheduleWithRunLoop(fileEvents, CFRunLoopGetMain(),
                                         "kCFRunLoopDefaultMode" as CFString)
        FSEventStreamStart(fileEvents)
    }

    func filesChanged(changes: NSArray) {
        var changed = Set<NSString>()

        for path in changes {
            let path = path as! NSString
            if path.range(of: INJECTABLE_PATTERN,
                          options:.regularExpression).location != NSNotFound &&
                path.range(of: "DerivedData/|InjectionProject/|main.mm?$",
                            options:.regularExpression).location == NSNotFound &&
                FileManager.default.fileExists(atPath: path as String) {
                changed.insert(path)
            }
        }

        if changed.count != 0 {
            callback(Array(changed) as NSArray)
        }
    }

    deinit {
        FSEventStreamStop(fileEvents)
        FSEventStreamInvalidate(fileEvents)
        FSEventStreamRelease(fileEvents)
    }
}
