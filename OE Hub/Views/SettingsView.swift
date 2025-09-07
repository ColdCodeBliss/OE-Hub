import SwiftUI

struct SettingsView: View {
    @AppStorage("isDarkMode") private var isDarkMode = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Appearance")) {
                    Toggle("Dark Mode", isOn: $isDarkMode)
                }
                Section(header: Text("Support")) {
                    Link("Contact Support", destination: URL(string: "mailto:support@workforge.app")!)
                    Link("Donate", destination: URL(string: "https://donate.workforge.app")!)  // Replace with your actual donate URL
                }
            }
            .navigationTitle("Settings")
        }
        .preferredColorScheme(isDarkMode ? .dark : .light)
    }
}

#Preview {
    SettingsView()
}