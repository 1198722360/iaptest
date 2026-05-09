import SwiftUI

@main
struct IAPTestApp: App {
    init() {
        StoreKitHelper.shared.start()
    }
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
