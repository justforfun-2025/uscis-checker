import Foundation

@MainActor
class CaseStore: ObservableObject {
    @Published private(set) var cases: [CaseRecord] = []
    @Published var isRefreshing = false
    @Published var errorMessage: String?

    private let client: USCISClient
    private let notificationManager = NotificationManager()
    private let defaults: UserDefaults
    private let defaultsKey = "uscis_cases"

    init(client: USCISClient = USCISClient(), defaults: UserDefaults = .standard) {
        self.client = client
        self.defaults = defaults
        load()
    }

    func add(_ record: CaseRecord) {
        cases.append(record)
        save()
    }

    func delete(_ record: CaseRecord) {
        cases.removeAll { $0.id == record.id }
        save()
    }

    func refreshAll() async {
        isRefreshing = true
        errorMessage = nil
        await withTaskGroup(of: Void.self) { group in
            for record in cases {
                group.addTask { await self.refresh(record) }
            }
        }
        isRefreshing = false
    }

    func refresh(_ record: CaseRecord) async {
        guard cases.contains(where: { $0.id == record.id }) else { return }
        do {
            let status = try await client.fetchStatus(receiptNumber: record.receiptNumber)
            guard let index = cases.firstIndex(where: { $0.id == record.id }) else { return }
            let oldTitle = cases[index].lastStatus?.title
            cases[index].lastStatus = status
            cases[index].lastChecked = Date()
            cases[index].errorMessage = nil
            if let old = oldTitle, old != status.title {
                notificationManager.notify(displayName: cases[index].displayName, newStatus: status.title)
            }
        } catch {
            guard let index = cases.firstIndex(where: { $0.id == record.id }) else { return }
            cases[index].errorMessage = "Failed to refresh status"
            errorMessage = "Failed to refresh \(cases[index].displayName)"
        }
        save()
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(cases) else { return }
        defaults.set(data, forKey: defaultsKey)
    }

    private func load() {
        guard let data = defaults.data(forKey: defaultsKey),
              let records = try? JSONDecoder().decode([CaseRecord].self, from: data)
        else { return }
        cases = records
    }
}
