#if canImport(SwiftUI)
import SwiftUI

/// Root view — displays the list of saved server profiles.
public struct ServerListView: View {
    @Environment(ServerStore.self) private var store
    @State private var showingForm = false

    public init() {}

    public var body: some View {
        NavigationStack {
            List {
                ForEach(store.profiles) { profile in
                    NavigationLink(value: profile) {
                        ServerRowView(profile: profile)
                    }
                }
                .onDelete { offsets in store.remove(at: offsets) }
            }
            .navigationTitle("Servers")
            .navigationDestination(for: ServerProfile.self) { profile in
                TerminalViewWrapper(profile: profile)
                    .ignoresSafeArea()
                    .navigationTitle(profile.displayName)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingForm = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add Server")
                }
                ToolbarItem(placement: .topBarLeading) {
                    EditButton()
                }
            }
            .sheet(isPresented: $showingForm) {
                ServerFormView()
                    .environment(store)
            }
            .overlay {
                if store.profiles.isEmpty {
                    ContentUnavailableView(
                        "No Servers",
                        systemImage: "server.rack",
                        description: Text("Tap + to add your first SSH server.")
                    )
                }
            }
        }
    }
}

// MARK: - Row

private struct ServerRowView: View {
    let profile: ServerProfile

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(profile.displayName)
                .font(.headline)
            Text("\(profile.username)@\(profile.host):\(profile.port)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.vertical, 4)
    }
}
#endif
