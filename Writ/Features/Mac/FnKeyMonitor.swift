import Foundation
#if os(macOS)
import Cocoa
import Carbon

/// fn 키 길게 누르기 감지. macOS에서 녹음 트리거로 사용.
@MainActor
final class FnKeyMonitor: ObservableObject {
    @Published var isFnPressed = false

    private var globalMonitor: Any?
    private var localMonitor: Any?

    var onFnDown: (() -> Void)?
    var onFnUp: (() -> Void)?

    func start() {
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            Task { @MainActor in
                self?.handleFlags(event)
            }
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            Task { @MainActor in
                self?.handleFlags(event)
            }
            return event
        }
    }

    func stop() {
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
    }

    private func handleFlags(_ event: NSEvent) {
        let fnPressed = event.modifierFlags.contains(.function)
        if fnPressed && !isFnPressed {
            isFnPressed = true
            onFnDown?()
        } else if !fnPressed && isFnPressed {
            isFnPressed = false
            onFnUp?()
        }
    }

    deinit {
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}
#endif
