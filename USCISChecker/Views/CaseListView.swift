import SwiftUI

struct CaseListView: View {
    @EnvironmentObject var store: CaseStore
    @Environment(\.scenePhase) private var scenePhase
    @State private var showingAddCase = false

    var body: some View {
        NavigationStack {
            Group {
                if store.cases.isEmpty {
                    ContentUnavailableView(
                        "No Cases",
                        systemImage: "doc.text.magnifyingglass",
                        description: Text("Tap + to add a receipt number.")
                    )
                } else {
                    List {
                        ForEach(store.cases) { record in
                            NavigationLink(destination: CaseDetailView(record: record)) {
                                CaseCardView(record: record)
                            }
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                store.delete(store.cases[index])
                            }
                        }
                    }
                }
            }
            .navigationTitle("USCIS Cases")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if store.isRefreshing {
                        ProgressView()
                    } else {
                        Button {
                            Task { await store.refreshAll() }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .disabled(store.cases.isEmpty)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddCase = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddCase) {
                AddCaseSheet()
            }
            .overlay(alignment: .top) {
                if let error = store.errorMessage {
                    Text(error)
                        .padding()
                        .background(.red.opacity(0.85))
                        .foregroundStyle(.white)
                        .clipShape(.rect(cornerRadius: 8))
                        .padding(.horizontal)
                        .transition(.move(edge: .top))
                }
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                Task { await store.refreshAll() }
            case .background:
                BackgroundRefresh.schedule()
            default:
                break
            }
        }
    }
}
