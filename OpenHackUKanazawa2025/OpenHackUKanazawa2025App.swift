import SwiftUI

@main
struct OpenHackUKanazawa2025App: App {
    @AppStorage("theme") private var themeRawValue: String = Theme.system.rawValue
    var currentTheme: Theme {
        Theme(rawValue: themeRawValue) ?? .system
    }
    
    var body: some Scene {
        WindowGroup {
            TopView()
                .preferredColorScheme(currentTheme.colorScheme)
        }
    }
}
