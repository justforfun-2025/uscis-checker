import SwiftUI

@main
struct USCISCheckerApp: App {
    @StateObject private var store = CaseStore()

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
