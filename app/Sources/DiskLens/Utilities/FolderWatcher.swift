import Foundation
import CoreServices

/// Watches a folder subtree for changes via FSEvents and calls `onChange`
/// (debounced) when anything under it is added/removed/modified. The callback
/// fires on a background queue; hop to the main actor in the handler.
final class FolderWatcher {
    private var stream: FSEventStreamRef?
    private var debounce: DispatchWorkItem?
    private let queue = DispatchQueue(label: "com.disklens.fswatch")
    private let onChange: () -> Void

    init(onChange: @escaping () -> Void) { self.onChange = onChange }
    deinit { stop() }

    func start(path: String) {
        stop()
        let callback: FSEventStreamCallback = { _, info, _, _, _, _ in
            guard let info else { return }
            Unmanaged<FolderWatcher>.fromOpaque(info).takeUnretainedValue().scheduleChange()
        }
        var ctx = FSEventStreamContext(version: 0,
                                       info: Unmanaged.passUnretained(self).toOpaque(),
                                       retain: nil, release: nil, copyDescription: nil)
        let flags = FSEventStreamCreateFlags(kFSEventStreamCreateFlagNoDefer | kFSEventStreamCreateFlagFileEvents)
        guard let s = FSEventStreamCreate(kCFAllocatorDefault, callback, &ctx,
                                          [path] as CFArray,
                                          FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
                                          1.0, flags) else { return }
        stream = s
        FSEventStreamSetDispatchQueue(s, queue)
        FSEventStreamStart(s)
    }

    func stop() {
        debounce?.cancel(); debounce = nil
        guard let s = stream else { return }
        FSEventStreamStop(s)
        FSEventStreamInvalidate(s)
        FSEventStreamRelease(s)
        stream = nil
    }

    private func scheduleChange() {
        debounce?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.onChange() }
        debounce = work
        queue.asyncAfter(deadline: .now() + 1.0, execute: work)   // coalesce bursts
    }
}
