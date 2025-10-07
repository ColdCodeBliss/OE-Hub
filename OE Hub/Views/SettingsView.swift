import SwiftUI
import StoreKit

struct SettingsView: View {
    @AppStorage("isDarkMode") private var isDarkMode = false
    @AppStorage("isLiquidGlassEnabled") private var isLiquidGlassEnabled = false   // Classic (fallback)
    @AppStorage("isBetaGlassEnabled") private var isBetaGlassEnabled = false       // Real Liquid Glass (iOS 26+)
    @AppStorage("isTrueStackEnabled") private var isTrueStackEnabled = false


    @Environment(\.horizontalSizeClass) private var hSize

    // StoreKit
    @StateObject private var store = DonationStore()

    // Convenience flags
    private var useBetaGlass: Bool {
        if #available(iOS 26.0, *) { return isBetaGlassEnabled }
        return false
    }
    private var useClassicGlass: Bool { isLiquidGlassEnabled && !useBetaGlass }

    var body: some View {
        NavigationStack {
            ScrollView {
                let columns: [GridItem] = [
                    GridItem(.adaptive(minimum: 360, maximum: 520), spacing: 16, alignment: .top)
                ]

                LazyVGrid(columns: columns, alignment: .leading, spacing: 16) {

                    // MARK: Appearance
                    SectionCard(title: "Appearance",
                                useBetaGlass: useBetaGlass,
                                useClassicGlass: useClassicGlass) {

                        Toggle("Dark Mode", isOn: $isDarkMode)

                        Toggle("Liquid Glass (Classic)", isOn:
                            Binding(
                                get: { isLiquidGlassEnabled },
                                set: { newValue in
                                    isLiquidGlassEnabled = newValue
                                    if newValue { isBetaGlassEnabled = false }
                                }
                            )
                        )

                        if #available(iOS 26.0, *) {
                            Toggle("Liquid Glass (Beta, iOS 26+)", isOn:
                                Binding(
                                    get: { isBetaGlassEnabled },
                                    set: { newValue in
                                        isBetaGlassEnabled = newValue
                                        if newValue { isLiquidGlassEnabled = false }
                                    }
                                )
                            )
                        } else {
                            Toggle("Liquid Glass (Beta, iOS 26+)", isOn: .constant(false))
                                .disabled(true)
                                .foregroundStyle(.secondary)
                        }
                        
                        if #available(iOS 26.0, *), isBetaGlassEnabled {
                            Toggle("True Stack (Card Deck UI)", isOn: $isTrueStackEnabled)
                                .tint(.blue)
                        }

                    }

                    // MARK: Support
                    SectionCard(title: "Support",
                                useBetaGlass: useBetaGlass,
                                useClassicGlass: useClassicGlass) {

                        Link("Bug Submission", destination: URL(string: "mailto:coldcodebliss@gmail.com")!)

                        VStack(alignment: .leading, spacing: 10) {
                            Text("Support the Developer")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)

                            if store.isLoading && store.products.isEmpty {
                                ProgressView().padding(.vertical, 4)
                            }

                            HStack(spacing: 10) {
                                ForEach(store.products, id: \.id) { product in
                                    donateButton(for: product, useBetaGlass: useBetaGlass, useClassicGlass: useClassicGlass)
                                }
                            }

                            if let msg = store.lastMessage {
                                Text(msg)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    // MARK: About
                    SectionCard(useBetaGlass: useBetaGlass, useClassicGlass: useClassicGlass) {
                        Text(".nexusStack helps freelancers, teams, and IT professionals manage jobs, deliverables, and GitHub repo's efficiently.")
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(maxWidth: 1100)
                .frame(maxWidth: .infinity)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .task { await store.load() }
            .onAppear {
                if isBetaGlassEnabled && isLiquidGlassEnabled {
                    isLiquidGlassEnabled = false
                }
            }
        }
    }

    // MARK: - Donate button style picker
    @ViewBuilder
    private func donateButton(for product: Product, useBetaGlass: Bool, useClassicGlass: Bool) -> some View {
        Button {
            Task { await store.purchase(product) }
        } label: {
            Text(product.displayPrice) // shows $5.00, $10.00, etc.
                .font(.body.weight(.semibold))
                .frame(minWidth: 68)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            Group {
                if #available(iOS 26.0, *), useBetaGlass {
                    Color.clear.glassEffect(.regular, in: .rect(cornerRadius: 12))
                } else if useClassicGlass {
                    RoundedRectangle(cornerRadius: 12).fill(.ultraThinMaterial)
                } else {
                    RoundedRectangle(cornerRadius: 12).fill(Color.blue.opacity(0.85))
                }
            }
        )
        .foregroundStyle((useBetaGlass || useClassicGlass) ? Color.primary : Color.white)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke((useBetaGlass || useClassicGlass) ? .white.opacity(0.08) : .clear, lineWidth: 1)
        )
    }
}

// MARK: - Glassy Section Card (unchanged)
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
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(borderColor, lineWidth: 1)
        )
    }

    @ViewBuilder
    private var cardBackground: some View {
        if #available(iOS 26.0, *), useBetaGlass {
            Color.clear.glassEffect(.regular, in: .rect(cornerRadius: 16))
        } else if useClassicGlass {
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        } else {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        }
    }

    private var borderColor: Color {
        useBetaGlass || useClassicGlass ? .white.opacity(0.10) : .black.opacity(0.06)
    }
}
