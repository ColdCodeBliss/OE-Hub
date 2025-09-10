//
//  SettingsPanel.swift
//  OE Hub
//
//  Created by Ryan Bliss on 9/10/25.
//


import SwiftUI

struct SettingsPanel: View {
    @Binding var isPresented: Bool

    @AppStorage("isDarkMode") private var isDarkMode = false
    @AppStorage("isLiquidGlassEnabled") private var isLiquidGlassEnabled = false   // Classic
    @AppStorage("isBetaGlassEnabled") private var isBetaGlassEnabled = false       // Real glass

    @State private var showDonateSheet = false

    var body: some View {
        ZStack {
            // Dimmed backdrop; tap outside to dismiss
            Color.black.opacity(0.25)
                .ignoresSafeArea()
                .onTapGesture { isPresented = false }

            // Floating panel
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Settings")
                        .font(.headline)
                    Spacer()
                    Button {
                        isPresented = false
                    } label: {
                        Image(systemName: "xmark")
                            .font(.body.weight(.semibold))
                    }
                    .buttonStyle(.plain)
                }
                .padding(12)

                Divider().opacity(0.15)

                // Content
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {

                        // Appearance
                        Group {
                            Text("Appearance")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                            VStack(alignment: .leading, spacing: 12) {
                                Toggle("Dark Mode", isOn: $isDarkMode)

                                Toggle("Liquid Glass (Classic)", isOn:
                                    Binding(
                                        get: { isLiquidGlassEnabled },
                                        set: { newValue in
                                            isLiquidGlassEnabled = newValue
                                            if newValue { isBetaGlassEnabled = false } // mutual exclusivity
                                        }
                                    )
                                )

                                if #available(iOS 18.0, *) {
                                    Toggle("Liquid Glass (Beta, iOS 18+)", isOn:
                                        Binding(
                                            get: { isBetaGlassEnabled },
                                            set: { newValue in
                                                isBetaGlassEnabled = newValue
                                                if newValue { isLiquidGlassEnabled = false } // mutual exclusivity
                                            }
                                        )
                                    )
                                } else {
                                    Toggle("Liquid Glass (Beta, iOS 18+)", isOn: .constant(false))
                                        .disabled(true)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(12)
                            .background(cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.08)))
                        }

                        // Support
                        Group {
                            Text("Support")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                            VStack(alignment: .leading, spacing: 12) {
                                Link("Contact Support", destination: URL(string: "mailto:support@workforge.app")!)

                                if #available(iOS 18.0, *), isBetaGlassEnabled {
                                    Button("Donate") { showDonateSheet = true }
                                        .buttonStyle(.glass)
                                } else if isLiquidGlassEnabled {
                                    Button("Donate") { showDonateSheet = true }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(10)
                                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
                                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(.white.opacity(0.1)))
                                } else {
                                    Button("Donate") { showDonateSheet = true }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(10)
                                        .background(Color.blue.opacity(0.85), in: RoundedRectangle(cornerRadius: 10))
                                        .foregroundStyle(.white)
                                }
                            }
                            .padding(12)
                            .background(cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.08)))
                        }

                        // About
                        VStack(alignment: .leading, spacing: 8) {
                            Text("About")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Text("NexusForge Stack helps OE professionals manage jobs, deliverables, and checklists efficiently.")
                                .foregroundStyle(.secondary)
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(cardBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.08)))
                        }
                    }
                    .padding(16)
                }
            }
            .frame(maxWidth: 520)
            .background(panelBackground)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.10), lineWidth: 1))
            .shadow(color: .black.opacity(0.35), radius: 28, y: 10)
            .padding(.horizontal, 16)
            .transition(.scale.combined(with: .opacity))
        }
        .sheet(isPresented: $showDonateSheet) {
            DonateSheet()
                .presentationDetents([.medium, .large])
        }
    }

    // Panel (outer) background: true Liquid Glass when available, else material
    @ViewBuilder
    private var panelBackground: some View {
        if #available(iOS 18.0, *), isBetaGlassEnabled {
            Color.clear.glassEffect(.regular, in: .rect(cornerRadius: 20))
        } else if isLiquidGlassEnabled {
            RoundedRectangle(cornerRadius: 20).fill(.ultraThinMaterial)
        } else {
            // If neither glass mode is on, still look premium
            RoundedRectangle(cornerRadius: 20).fill(Color(.systemBackground))
        }
    }

    // Inner card background
    @ViewBuilder
    private var cardBackground: some View {
        if #available(iOS 18.0, *), isBetaGlassEnabled {
            Color.clear.glassEffect(.clear, in: .rect(cornerRadius: 14))
        } else if isLiquidGlassEnabled {
            RoundedRectangle(cornerRadius: 14).fill(.ultraThinMaterial)
        } else {
            RoundedRectangle(cornerRadius: 14).fill(Color(.secondarySystemBackground))
        }
    }
}

// Simple donate sheet used inside the panel
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
