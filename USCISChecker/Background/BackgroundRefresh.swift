import BackgroundTasks
import Foundation

enum BackgroundRefresh {
    static let taskIdentifier = "com.uscischecker.refresh"

    // Must be called before `application(_:didFinishLaunchingWithOptions:)` returns —
    // SwiftUI's App.init() is the right place.
    static func register() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: taskIdentifier, using: nil) { task in
            handle(task)
        }
    }

    // Ask iOS to schedule another refresh. iOS decides the actual timing based on
    // budget and usage patterns; earliestBeginDate is a hint, not a guarantee.
    static func schedule() {
        let request = BGAppRefreshTaskRequest(identifier: taskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 60 * 60 * 4)  // hint: ≥4h from now
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            // Common reasons: identifier not in Info.plist's
            // BGTaskSchedulerPermittedIdentifiers, or user has disabled
            // Background App Refresh in Settings. Either way, fail silently —
            // the foreground refresh path still works.
        }
    }

    private static func handle(_ task: BGTask) {
        // Schedule the next refresh before doing the work — if we crash or time
        // out, iOS still has a pending request to fire later.
        schedule()

        let work = Task { @MainActor in
            let store = CaseStore()
            await store.refreshAll()
            task.setTaskCompleted(success: !Task.isCancelled)
        }

        task.expirationHandler = {
            work.cancel()
        }
    }
}
