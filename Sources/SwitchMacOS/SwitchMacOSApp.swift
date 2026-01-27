import SwiftUI
import SwitchCore

@main
struct SwitchMacOSApp: App {
    @StateObject private var model = SwitchAppModel()

    var body: some Scene {
        WindowGroup {
            RootView(model: model)
        }
        .windowStyle(.automatic)
    }
}
