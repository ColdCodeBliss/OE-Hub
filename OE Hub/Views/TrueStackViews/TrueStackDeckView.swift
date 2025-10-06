//
//  TrueStackDeckView.swift
//  nexusStack / OE Hub
//

import SwiftUI
import SwiftData

@available(iOS 26.0, *)
struct TrueStackDeckView: View {
    // MARK: Input
    let jobs: [Job]

    // MARK: Environment
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme

    // MARK: Feature flags
    @AppStorage("isBetaGlassEnabled")   private var isBetaGlassEnabled   = false
    @AppStorage("isTrueStackEnabled")   private var isTrueStackEnabled   = false

    // MARK: Deck state
    @State private var deck: [Job] = []
    @State private var dragTranslation: CGFloat = 0
    @State private var isDragging = false

    // Expanded panel
    @State private var expandedJob: Job? = nil
    @Namespace private var deckNS

    // Routes launched from expanded view
    @State private var showGitHub = false
    @State private var showConfluence = false
    @State private var showDue = false
    @State private var showChecklist = false
    @State private var showMindMap = false
    @State private var showNotes = false
    @State private var showInfo = false

    // Context actions
    @State private var showRenameAlert = false
    @State private var pendingRenameText = ""
    @State private var jobForContext: Job? = nil
    @State private var showDeleteConfirm = false

    // Settings (hamburger)
    @State private var showSettings = false

    // MARK: Layout dials
    private let horizontalGutter: CGFloat = 18          // side padding for all cards
    private let topHeightRatio: CGFloat = 0.66          // top-card height vs. usable height
    private let maxCardHeight: CGFloat = 560
    private let stackDepth = 6                          // max rendered layers
    private let layerOffsetY: CGFloat = 18              // vertical fanning
    private let tiltDegrees: CGFloat = 3.0              // tiny tilt for non-top cards

    /// Scale steps for the cards beneath the top (kept modest so everything stays in-bounds)
    /// index 0 = top (1.00), 1 = 0.94, 2 = 0.90, 3 = 0.86, …
    private func scaleForIndex(_ idx: Int) -> CGFloat {
        max(0.82, 1.0 - CGFloat(idx) * 0.06)
    }

    private let nonTopOpacity: Double = 0.92
    private let swipeThreshold: CGFloat = 90

    init(jobs: [Job]) { self.jobs = jobs }

    var body: some View {
        GeometryReader { geo in
            // Safe area aware sizing
            let topInset = geo.safeAreaInsets.top
            let bottomInset = geo.safeAreaInsets.bottom
            let usableHeight = geo.size.height - topInset - bottomInset

            // Base (unscaled) card size
            let baseW = max(280, geo.size.width - (horizontalGutter * 2))
            let baseH = min(usableHeight * topHeightRatio, maxCardHeight)

            // Full deck height (so we can vertically center the fan)
            let visibleCount = min(stackDepth, deck.count)
            let deckHeight = baseH + CGFloat(max(0, visibleCount - 1)) * layerOffsetY

            ZStack {
                // Subtle backdrop
                LinearGradient(
                    colors: [.white.opacity(colorScheme == .dark ? 0.02 : 0.06), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                // Centered deck container. We use a VStack to center vertically.
                VStack {
                    Spacer(minLength: topInset)
                    ZStack {
                        ForEach(Array(deck.prefix(stackDepth).enumerated()), id: \.element.persistentModelID) { (idx, job) in
                            let scale = scaleForIndex(idx)
                            let cardSize = CGSize(width: baseW * scale, height: baseH * scale)
                            card(job: job, index: idx, size: cardSize)
                                // fan vertically
                                .offset(y: CGFloat(idx) * layerOffsetY)
                                // keep each scaled card centered (ZStack centers by default)
                        }
                    }
                    .frame(width: baseW, height: deckHeight, alignment: .center)
                    .padding(.horizontal, horizontalGutter)
                    Spacer(minLength: bottomInset)
                }

                // Expanded overlay
                if let selected = expandedJob {
                    Color.black.opacity(0.20).ignoresSafeArea()
                        .transition(.opacity)

                    TrueStackExpandedView(
                        job: selected,
                        close: { withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) { expandedJob = nil } },
                        openDue: { showDue = true },
                        openChecklist: { showChecklist = true },
                        openMindMap: { showMindMap = true },
                        openNotes: { showNotes = true },
                        openInfo: { showInfo = true },
                        openGitHub: { showGitHub = true },
                        openConfluence: { showConfluence = true }
                    )
                    .matchedGeometryEffect(id: selected.persistentModelID, in: deckNS)
                    .transition(.scale.combined(with: .opacity))
                    .zIndex(10)
                }

                // Hamburger (anchored below status bar)
                VStack {
                    HStack {
                        Button {
                            showSettings = true
                        } label: {
                            Image(systemName: "line.horizontal.3")
                                .font(.title2.weight(.semibold))
                                .padding(10)
                                .background(
                                    Group {
                                        if #available(iOS 26.0, *), isBetaGlassEnabled {
                                            Color.clear.glassEffect(.regular, in: .circle)
                                        } else {
                                            Circle().fill(.ultraThinMaterial)
                                        }
                                    }
                                )
                        }
                        .buttonStyle(.plain)
                        .padding(.leading, 12)
                        Spacer()
                    }
                    .padding(.top, topInset + 6)
                    Spacer()
                }
                .ignoresSafeArea(edges: .top)
                .zIndex(11)
            }
            .task { deck = jobs }

            // MARK: Launches from expanded buttons
            .sheet(isPresented: $showDue) { JobDetailView(job: expandedJob!).navigationBarTitleDisplayMode(.inline) }
            .sheet(isPresented: $showChecklist) { JobDetailView(job: expandedJob!).navigationBarTitleDisplayMode(.inline) }
            .sheet(isPresented: $showMindMap) { JobDetailView(job: expandedJob!).navigationBarTitleDisplayMode(.inline) }
            .sheet(isPresented: $showNotes) { JobDetailView(job: expandedJob!).navigationBarTitleDisplayMode(.inline) }
            .sheet(isPresented: $showInfo) { JobDetailView(job: expandedJob!).navigationBarTitleDisplayMode(.inline) }
            .fullScreenCover(isPresented: $showGitHub) {
                if let j = expandedJob { GitHubBrowserView(recentKey: "recentRepos.\(j.repoBucketKey)") }
            }
            .fullScreenCover(isPresented: $showConfluence) {
                if let j = expandedJob { ConfluenceLinksView(storageKey: "confluenceLinks.\(j.repoBucketKey)", maxLinks: 5) }
            }

            // Settings routing (same behavior as HomeView)
            .sheet(isPresented: Binding(
                get: { showSettings && !isBetaGlassEnabled },
                set: { if !$0 { showSettings = false } }
            )) { SettingsView() }
            .overlay {
                if showSettings && isBetaGlassEnabled {
                    SettingsPanel(isPresented: $showSettings).zIndex(20)
                }
            }

            // Rename + Delete
            .alert("Rename Stack", isPresented: $showRenameAlert) {
                TextField("Title", text: $pendingRenameText)
                Button("Cancel", role: .cancel) { jobForContext = nil }
                Button("Save") {
                    if let j = jobForContext {
                        j.title = pendingRenameText.trimmingCharacters(in: .whitespacesAndNewlines)
                        try? modelContext.save()
                    }
                    jobForContext = nil
                }
            }
            .alert("Delete Stack", isPresented: $showDeleteConfirm) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    if let j = jobForContext {
                        modelContext.delete(j)
                        try? modelContext.save()
                        removeFromDeck(j)
                    }
                    jobForContext = nil
                }
            } message: { Text("This action cannot be undone.") }
        }
    }

    // MARK: - Card

    private func card(job: Job, index idx: Int, size: CGSize) -> some View {
        let isTop = idx == 0
        let tiltSign: CGFloat = (idx % 2 == 0) ? 1 : -1

        let drag = DragGesture(minimumDistance: 8)
            .onChanged { value in
                guard isTop, expandedJob == nil else { return }
                isDragging = true
                dragTranslation = value.translation.width
            }
            .onEnded { value in
                guard isTop, expandedJob == nil else { return }
                isDragging = false
                let x = value.translation.width
                if abs(x) > swipeThreshold {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        sendTopCardToBack()
                        dragTranslation = 0
                    }
                } else {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                        dragTranslation = 0
                    }
                }
            }

        return ZStack(alignment: .topLeading) {
            // Glass surface
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.clear)
                .frame(width: size.width, height: size.height)
                .glassEffect(
                    .regular.tint(color(for: job.effectiveColorIndex).opacity(isTop ? 0.50 : 0.42)),
                    in: .rect(cornerRadius: 22)
                )

            // CONTENT: Title + Created (top), Info fills remaining
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(job.title)
                        .font(.headline.weight(.semibold))
                        .lineLimit(1)
                    Text("Created \(tsFormattedDate(job.creationDate))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 4)

                Divider().opacity(0.12)

                infoGrid(for: job)
                    .font(.subheadline)
            }
            .padding(14)
            .frame(width: size.width, height: size.height, alignment: .topLeading)
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(.white.opacity(isTop ? 0.10 : 0.06), lineWidth: 1)
            )

            // Interactions on the top card
            if isTop && expandedJob == nil {
                Color.clear
                    .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .onTapGesture {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                            expandedJob = job
                        }
                    }
                    .simultaneousGesture(
                        LongPressGesture(minimumDuration: 0.5).onEnded { _ in
                            jobForContext = job
                            pendingRenameText = job.title
                            showRenameAlert = true
                        }
                    )
                    .contextMenu {
                        Button("Rename") {
                            jobForContext = job
                            pendingRenameText = job.title
                            showRenameAlert = true
                        }
                        Button("Change Color") { cycleColor(job) }
                        Button("Delete", role: .destructive) {
                            jobForContext = job
                            showDeleteConfirm = true
                        }
                    }
            }
        }
        .opacity(isTop ? 1.0 : nonTopOpacity)
        .matchedGeometryEffect(id: job.persistentModelID, in: deckNS)
        .rotationEffect(.degrees(isTop ? 0 : Double(tiltSign) * Double(tiltDegrees)))
        .offset(x: isTop ? dragTranslation : 0)                  // swipe only top
        .gesture(isTop ? drag : nil)
        .zIndex(Double(stackDepth - idx))
        .animation(.spring(response: 0.35, dampingFraction: 0.88), value: dragTranslation)
        .shadow(color: .black.opacity(isTop ? 0.35 : 0.22),
                radius: isTop ? 20 : 12, y: isTop ? 12 : 6)
    }

    // MARK: - Info grid

    @ViewBuilder
    private func infoGrid(for job: Job) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            infoRow("Email", job.email)
            infoRow("Pay Rate", payString(rate: job.payRate, type: job.compensation))
            infoRow("Manager", job.managerName)
            infoRow("Role / Title", job.roleTitle)
            infoRow("Equipment", job.equipmentList)
            infoRow("Job Type", job.type.rawValue + (job.contractEndDate.map { "  •  Ends \(tsFormattedDate($0))" } ?? ""))
        }
    }

    @ViewBuilder
    private func infoRow(_ label: String, _ value: String?) -> some View {
        if let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(label).foregroundStyle(.secondary)
                Text(trimmed)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
        }
    }

    private func payString(rate: Double, type: Job.PayType) -> String? {
        guard rate > 0 else { return nil }
        let f = NumberFormatter()
        f.numberStyle = .currency
        let amount = f.string(from: NSNumber(value: rate)) ?? "\(rate)"
        let period = (type == .hourly) ? "/hr" : "/yr"
        return "\(amount)\(period)"
    }

    // MARK: - Deck ops

    private func sendTopCardToBack() {
        guard let first = deck.first else { return }
        deck.removeFirst()
        deck.append(first)
    }

    private func removeFromDeck(_ job: Job) {
        deck.removeAll { $0.persistentModelID == job.persistentModelID }
    }

    private func cycleColor(_ job: Job) {
        job.cycleColorForward()
        try? modelContext.save()
    }
}
