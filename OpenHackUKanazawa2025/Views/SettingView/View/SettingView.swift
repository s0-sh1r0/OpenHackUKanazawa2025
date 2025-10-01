import SwiftUI

struct SettingView: View {
    @AppStorage("theme") private var themeRawValue: String = Theme.system.rawValue
    
    var body: some View {
        List {
            Section(header: Text("テーマ")) {
                Menu {
                    Button("ライトモード") {
                        themeRawValue = Theme.light.rawValue
                    }
                    Button("ダークモード") {
                        themeRawValue = Theme.dark.rawValue
                    }
                    Button("システムに従う") {
                        themeRawValue = Theme.system.rawValue
                    }
                } label: {
                    HStack {
                        Text("現在のテーマ")
                        Spacer()
                        Text(themeRawValue)
                    }
                }
            }
        }
    }
}

#Preview {
    SettingView()
}
