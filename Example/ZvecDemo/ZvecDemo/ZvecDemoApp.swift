import SwiftUI
import Zvec

@main
struct ZvecDemoApp: App {
    init() {
        // Initialize the Zvec library once on app launch
        do {
            try Zvec.initialize()
            print("[ZvecDemo] Zvec initialized successfully")
        } catch {
            print("[ZvecDemo] Failed to initialize Zvec: \(error)")
        }

        // Initialize the collection manager
        ZvecManager.shared.setup()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

