import SwiftUI

@main
struct PhotoSwipeCleanerApp: App {
    @StateObject private var store = ReviewSessionStore(service: PhotoLibraryService())

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
        }
    }
}
