import CoreServices
import Foundation

/// 用 FSEvents 監看狀態目錄。latency 期間內的連續變動會合併成一次回呼（即 debounce）。
@MainActor
final class StateWatcher {
    private let directory: URL
    private let latency: TimeInterval
    private let onChange: @MainActor () -> Void
    private var stream: FSEventStreamRef?

    init(directory: URL, latency: TimeInterval = 0.1, onChange: @escaping @MainActor () -> Void) {
        self.directory = directory
        self.latency = latency
        self.onChange = onChange
    }

    func start() {
        guard stream == nil else { return }

        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )
        let callback: FSEventStreamCallback = { _, info, _, _, _, _ in
            guard let info else { return }
            // stream 綁在 main queue 上，回呼一定在主執行緒
            MainActor.assumeIsolated {
                Unmanaged<StateWatcher>.fromOpaque(info).takeUnretainedValue().onChange()
            }
        }
        // FileEvents：檔案層級的變動也要通知（手動 echo 覆寫既有檔案時，目錄本身不會變）
        let flags = FSEventStreamCreateFlags(kFSEventStreamCreateFlagFileEvents)

        guard let stream = FSEventStreamCreate(
            nil,
            callback,
            &context,
            [directory.path] as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            latency,
            flags
        ) else {
            NSLog("NotchStatus: failed to create FSEventStream for \(directory.path)")
            return
        }
        FSEventStreamSetDispatchQueue(stream, .main)
        FSEventStreamStart(stream)
        self.stream = stream
    }

    func stop() {
        guard let stream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        self.stream = nil
    }
}
