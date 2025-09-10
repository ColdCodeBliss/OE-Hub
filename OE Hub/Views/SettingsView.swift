import SwiftUI

struct SettingsView: View {
    @AppStorage("isDarkMode") private var isDarkMode = false
    @AppStorage("isLiquidGlassEnabled") private var isLiquidGlassEnabled = false
    @State private var showDonateSheet = false

    var body: some View {
        NavigationStack {
            Form {
                // MARK: - Appearance
                Section(header: Text("Appearance")) {
                    Toggle("Dark Mode", isOn: $isDarkMode)

                    if #available(iOS 18.0, *) {
                        Toggle("Liquid Glass", isOn: $isLiquidGlassEnabled)
                    } else {
                        Toggle("Liquid Glass (iOS 18+)", isOn: .constant(false))
                            .disabled(true)
                            .foregroundStyle(.secondary)
                    }
                }

                // MARK: - Support
                Section(header: Text("Support")) {
                    Link("Contact Support", destination: URL(string: "mailto:support@workforge.app")!)
                    Button("Donate") { showDonateSheet = true }
                }

                // MARK: - About
                Section(footer:
                    Text("NexusForge Stack helps OE professionals manage jobs, deliverables, and checklists efficiently.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                ) {
                    EmptyView()
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showDonateSheet) {
                DonateSheet()
                    .presentationDetents([.medium, .large])
            }
        }
    }
}

// MARK: - Simple donate sheet (unchanged behavior)
private struct DonateSheet: View {
    var body: some View {
        VStack(spacing: 16) {
            Text("Support Development")
                .font(.title2.bold())
            Text("If you find value in NexusForge Stack, consider a small donation. Thank you!")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Link("Open Venmo", destination: URL(string: "https://venmo.com/")!)
                .font(.body)
                .padding()
                .background(Color.blue.opacity(0.8))
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding()
    }
}

#Preview {
    SettingsView()
}
