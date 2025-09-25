//
//  TrueStackDeckView.swift
//  OE Hub
//
//  Updated for unified card sizing, no borders, top card straight, and safe insets.
//

import SwiftUI
import SwiftData

@available(iOS 26.0, *)
struct TrueStackDeckView: View {
    // Input — use the same models you already query in HomeView
    let jobs: [Job]

    // Environment (so we can rename/delete without changing your HomeView plumbing)
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme

    // Style flags
    @AppStorage("isBetaGlassEnabled")   private var isBetaGlassEnabled   = false
    @AppStorage("isTrueStackEnabled")   private var isTrueStackEnabled   = false

    // UI state
    @State private var deck: [Job] = []
    @State private var dragTranslation: CGFloat = 0
    @State private var isDragging = false

    // Expanded
    @State private var expandedJob: Job? = nil
    @Namespace private var deckNS

    // Sheets/panels launched from expanded view buttons
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

    // Layout (tuned to keep rotated cards inside screen)
    private let cardHorizontalMargin: CGFloat = 60     // side gutter so tilt never clips
    private let topHeightRatio: CGFloat = 0.66         // card height vs screen height
    private let stackDepth = 6                         // visible layers
    private let tiltDegrees: CGFloat = 2.5               // tilt for non-top cards only
    private let layerOffsetY: CGFloat = 11             // vertical fan
    private let swipeThreshold: CGFloat = 90           // px to complete a swipe
    private let nonTopOpacity: Double = 0.96           // shared opacity for all non-top cards

    init(jobs: [Job]) { self.jobs = jobs }

    var body: some View {
        GeometryReader { geo in
            // Single, unified card size (accounts for rotation so corners never clip)
            let safeW = geo.size.width - (cardHorizontalMargin * 2)
            let baseH = min(geo.size.height * topHeightRatio, 560)

            // Rotated width: W*cosθ + H*sinθ <= safeW  ⇒ choose W accordingly
            let theta = abs(tiltDegrees) * .pi / 180
            let cosT  = cos(theta)
            let sinT  = sin(theta)

            // Solve for W; guard against tiny/negative values and cos=0
            let maxWFromRotation = max(200, (safeW - baseH * sinT) / max(cosT, 0.0001))
            let baseW = min(safeW, maxWFromRotation)


            ZStack {
                // Background shimmer to match your app’s vibe
                LinearGradient(
                    colors: [.white.opacity(colorScheme == .dark ? 0.02 : 0.06), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                // Deck
                ZStack {
                    ForEach(Array(deck.prefix(stackDepth).enumerated()), id: \.element.persistentModelID) { (idx, job) in
                        card(job: job, index: idx, size: CGSize(width: baseW, height: baseH))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, cardHorizontalMargin)  // ensure fully on-screen
                .clipped() // ⬅️ ensure nothing renders past the container

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
            }
            .task { deck = jobs } // Initialize deck (top = first)

            // MARK: Launches from expanded buttons (reuse your existing views)
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

        return ZStack {
            // Glass card body — single layer, no inner border stroke
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.clear)
                .frame(width: size.width, height: size.height)
                .glassEffect(.regular.tint(color(for: job.effectiveColorIndex).opacity(0.50)),
                             in: .rect(cornerRadius: 22))
                .overlay(
                    VStack(spacing: 10) {
                        Text(job.title)
                            .font(.title3.weight(.semibold))
                            .lineLimit(1)
                        Text("Created \(tsFormattedDate(job.creationDate))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                )
                .opacity(isTop ? 1.0 : nonTopOpacity)

            // Tap zone (top card only)
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
        .matchedGeometryEffect(id: job.persistentModelID, in: deckNS)
        .offset(y: CGFloat(idx) * layerOffsetY)
        .rotationEffect(.degrees(isTop ? 0 : Double(tiltSign) * Double(tiltDegrees))) // top is straight
        .offset(x: isTop ? dragTranslation : 0) // swipe top card
        .gesture(isTop ? drag : nil)
        .zIndex(Double(stackDepth - idx)) // draw order: smaller idx = higher z
        .animation(.spring(response: 0.35, dampingFraction: 0.88), value: dragTranslation)
    }

    // MARK: - Deck operations

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

    // (Kept for completeness if you still reference these elsewhere)
    private func jobColorIndex(_ job: Job) -> Int {
        let maxCount = 12
        func clamp(_ v: Int) -> Int { (v % maxCount + maxCount) % maxCount }
        let mirror = Mirror(reflecting: job)
        for child in mirror.children {
            guard let label = child.label else { continue }
            let value = child.value
            if label == "colorIndex" {
                if let i = value as? Int { return clamp(i) }
                if let i = unwrapAny(value) as? Int { return clamp(i) }
            }
            if label == "colorCode" {
                if let s = value as? String, let i = stringCodeToIndex(s) { return clamp(i) }
                if let s = unwrapAny(value) as? String, let i = stringCodeToIndex(s) { return clamp(i) }
            }
        }
        return clamp(abs(job.title.hashValue))
    }

    private func unwrapAny(_ value: Any) -> Any? {
        let m = Mirror(reflecting: value)
        guard m.displayStyle == .optional else { return value }
        return m.children.first?.value
    }

    private func stringCodeToIndex(_ raw: String) -> Int? {
        let ordered = ["gray", "red", "blue", "green", "purple", "orange", "yellow", "teal", "brown"]
        let key = raw.lowercased()
        return ordered.firstIndex(of: key)
    }
}
