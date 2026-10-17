import Cocoa

protocol AppTrackerDelegate: AnyObject {
    func appWasActivated(runningApp: NSRunningApplication)
    func appWasLaunched(runningApp: NSRunningApplication)
    func appWasQuit(runningApp: NSRunningApplication)
    func volumesDidChange()
}

extension AppTrackerDelegate {
    func volumesDidChange() {}
}

/// Event-driven tracking: no timer or periodic process polling.
final class AppTracker {
    weak var delegate: AppTrackerDelegate?
    private let center: NotificationCenter
    private var observers: [NSObjectProtocol] = []

    init(center: NotificationCenter = NSWorkspace.shared.notificationCenter) {
        self.center = center
        observe(NSWorkspace.didActivateApplicationNotification) { tracker, app in
            // Accessory apps can become frontmost too. Forward every activation
            // so hide-active-app never keeps the previous regular app hidden.
            tracker.delegate?.appWasActivated(runningApp: app)
        }
        observe(NSWorkspace.didLaunchApplicationNotification) { tracker, app in
            tracker.delegate?.appWasLaunched(runningApp: app)
        }
        observe(NSWorkspace.didTerminateApplicationNotification) { tracker, app in
            tracker.delegate?.appWasQuit(runningApp: app)
        }
        for name in [NSWorkspace.didMountNotification, NSWorkspace.didUnmountNotification,
                     NSWorkspace.didRenameVolumeNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.delegate?.volumesDidChange()
            })
        }
    }

    deinit { observers.forEach { center.removeObserver($0) } }

    private func observe(_ name: Notification.Name,
                         action: @escaping (AppTracker, NSRunningApplication) -> Void) {
        observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] notification in
            guard let self = self,
                  let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            action(self, app)
        })
    }
}
