import SwiftUI

struct SettingsView: View {
    @AppStorage("isDarkMode") private var isDarkMode = false
    @AppStorage("isLiquidGlassEnabled") private var isLiquidGlassEnabled = false   // Classic (fallback)
    @AppStorage("isBetaGlassEnabled") private var isBetaGlassEnabled = false       // Real Liquid Glass (iOS 18+)

    @State private var showDonateSheet = false

    // Convenience flags
    private var useBetaGlass: Bool {
        if #available(iOS 26.0, *) { return isBetaGlassEnabled }
        return false
    }
    private var useClassicGlass: Bool { isLiquidGlassEnabled && !useBetaGlass }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {

                    // MARK: Appearance
                    SectionCard(title: "Appearance",
                                useBetaGlass: useBetaGlass,
                                useClassicGlass: useClassicGlass) {

                        Toggle("Dark Mode", isOn: $isDarkMode)

                        // Classic glass (SDK-safe), mutually exclusive with Beta
                        Toggle("Liquid Glass (Classic)", isOn:
                            Binding(
                                get: { isLiquidGlassEnabled },
                                set: { newValue in
                                    isLiquidGlassEnabled = newValue
                                    if newValue { isBetaGlassEnabled = false }
                                }
                            )
                        )

                        // Real Liquid Glass (iOS 18+), mutually exclusive with Classic
                        if #available(iOS 26.0, *) {
                            Toggle("Liquid Glass (Beta, iOS 18+)", isOn:
                                Binding(
                                    get: { isBetaGlassEnabled },
                                    set: { newValue in
                                        isBetaGlassEnabled = newValue
                                        if newValue { isLiquidGlassEnabled = false }
                                    }
                                )
                            )
                        } else {
                            Toggle("Liquid Glass (Beta, iOS 20+)", isOn: .constant(false))
                                .disabled(true)
                                .foregroundStyle(.secondary)
                        }
                    }

                    // MARK: Support
                    SectionCard(title: "Support",
                                useBetaGlass: useBetaGlass,
                                useClassicGlass: useClassicGlass) {

                        Link("Bug Submission", destination: URL(string: "mailto:support@workforge.app")!)

                        if #available(iOS 26.0, *), useBetaGlass {
                            Button("Donate") { showDonateSheet = true }
                                .buttonStyle(.glass)
                        } else if useClassicGlass {
                            Button("Donate") { showDonateSheet = true }
                                .frame(maxWidth: .infinity)
                                .padding(10)
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.1)))
                        } else {
                            Button("Donate") { showDonateSheet = true }
                                .frame(maxWidth: .infinity)
                                .padding(10)
                                .background(Color.blue.opacity(0.85), in: RoundedRectangle(cornerRadius: 12))
                                .foregroundStyle(.white)
                        }
                    }

                    // MARK: About
                    SectionCard(useBetaGlass: useBetaGlass, useClassicGlass: useClassicGlass) {
                        Text(".nexusStack helps freelancers, teams, and OE professionals manage jobs, deliverables, and GitHub repo's efficiently.")
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showDonateSheet) {
                DonateSheet()
                    .presentationDetents([.medium, .large])   // lets the system apply Liquid Glass to the sheet
            }
            // Resolve legacy state if both were ON previously
            .onAppear {
                if isBetaGlassEnabled && isLiquidGlassEnabled {
                    // Prefer Beta when both are true
                    isLiquidGlassEnabled = false
                }
            }
        }
    }
}

// MARK: - Glassy Section Card

private struct SectionCard<Content: View>: View {
    var title: String? = nil
    let useBetaGlass: Bool
    let useClassicGlass: Bool
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title {
                Text(title)
                    .font(.headline)
                    .padding(.bottom, 2)
            }
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)  // glass vs classic vs solid
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(borderColor, lineWidth: 1)
        )
    }

    @ViewBuilder
    private var cardBackground: some View {
        if #available(iOS 26.0, *), useBetaGlass {
            // ✅ Real Liquid Glass
            Color.clear.glassEffect(.regular, in: .rect(cornerRadius: 16))
        } else if useClassicGlass {
            // 🌈 Classic glassy fallback
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        } else {
            // 🎨 Solid card
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        }
    }

    private var borderColor: Color {
        useBetaGlass || useClassicGlass ? .white.opacity(0.10) : .black.opacity(0.06)
    }
}

// MARK: - Donate sheet (unchanged)

private struct DonateSheet: View {
    var body: some View {
        VStack(spacing: 16) {
            Text("Support Development").font(.title2.bold())
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
