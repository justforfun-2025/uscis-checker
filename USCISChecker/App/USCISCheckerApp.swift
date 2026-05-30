import SwiftUI

@main
struct USCISCheckerApp: App {
    @StateObject private var store = CaseStore()

    init() {
        BackgroundRefresh.register()
    }

    var body: some Scene {
        WindowGroup {
            CaseListView()
                .environmentObject(store)
                .task {
                    NotificationManager().requestPermission()
                }
        }
    }
}
