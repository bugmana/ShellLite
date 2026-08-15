#if canImport(SwiftUI)
import SwiftUI

/// App entry point — iOS 18 only.
@main
struct ShellLiteApp: App {
    @State private var serverStore = ServerStore()

    var body: some Scene {
        WindowGroup {
            ServerListView()
                .environment(serverStore)
        }
    }
}

/// Observable store for the server profile list, backed by UserDefaults JSON.
@Observable
final class ServerStore {
    private static let defaultsKey = "shelllite.profiles"

    var profiles: [ServerProfile] = [] { didSet { persist() } }

    init() { load() }

    func add(_ profile: ServerProfile) { profiles.append(profile) }
    func remove(at offsets: IndexSet)  { profiles.remove(atOffsets: offsets) }

    private func persist() {
        UserDefaults.standard.set(
            try? JSONEncoder().encode(profiles),
            forKey: Self.defaultsKey
        )
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: Self.defaultsKey),
              let saved = try? JSONDecoder().decode([ServerProfile].self, from: data)
        else { return }
        profiles = saved
    }
}
#else
@main
struct ShellLiteApp {
    static func main() {
        print("ShellLite is designed for iOS/macOS.")
    }
}
#endif
