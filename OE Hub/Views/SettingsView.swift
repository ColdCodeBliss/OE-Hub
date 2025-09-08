import SwiftUI

struct SettingsView: View {
    @AppStorage("isDarkMode") private var isDarkMode = false
    @State private var showDonateSheet = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Appearance") {
                    Toggle("Dark Mode", isOn: $isDarkMode)
                }
                Section("Support") {
                    Link("Contact Support", destination: URL(string: "mailto:support@workforge.app")!)
                        .accessibilityLabel("Contact Support via Email")

                    Button("Donate") { showDonateSheet = true }
                        .accessibilityLabel("Open Donate Sheet")
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showDonateSheet) {
                DonateSheet()
            }
        }
        .preferredColorScheme(isDarkMode ? .dark : .light)
    }
}

struct DonateSheet: View {
    var body: some View {
        VStack(spacing: 20) {
            Text("Please consider donating to support the app")
                .font(.headline)
                .multilineTextAlignment(.center)
                .padding()

            // TODO: replace placeholder with your actual Venmo link
            Link("Donate via Venmo", destination: URL(string: "https://x.com")!)
                .font(.body)
                .padding()
                .background(Color.blue.opacity(0.8))
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .accessibilityLabel("Donate via Venmo")
        }
        .padding()
        .presentationDetents([.medium])
    }
}

#Preview {
    SettingsView()
}
