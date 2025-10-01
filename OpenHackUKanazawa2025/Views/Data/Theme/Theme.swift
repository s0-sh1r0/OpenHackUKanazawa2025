import SwiftUI

enum Theme: String {
    case light, dark, system

    var colorScheme: ColorScheme? {
        switch self {
        case .light: return .light
        case .dark: return .dark
        case .system: return nil
        }
    }
    
    var effectiveColor: Color {
        switch self {
        case .light:
            return .black
        case .dark:
            return .white
        case .system:
            return .primary
        }
    }
}
