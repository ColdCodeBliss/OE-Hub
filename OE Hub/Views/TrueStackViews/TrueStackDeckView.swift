import SwiftUI
import SwiftData

@available(iOS 26.0, *)
struct TrueStackDeckView: View {
    let jobs: [Job]

    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme

    @AppStorage("isBetaGlassEnabled") private var isBetaGlassEnabled = false
    @AppStorage("isTrueStackEnabled") private var isTrueStackEnabled = false

    // NEW: settings presentation
    @State private var showSettings = false

    // Deck state
    @State private var deck: [Job] = []
    @State private var containerSize: CGSize = .zero
    @State private var dragProgress: Double = 0.0
    @State private var selectedIndex: Int = 0

    // Expanded
    @State private var expandedJob: Job? = nil
    @Namespace private var deckNS

    // Launchers from expanded view
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

    // Layout
    private let cardCorner: CGFloat = 22
    private let cardHorizontalMargin: CGFloat = 18
    private let topHeightRatio: CGFloat = 0.66
    private let maxCardHeight: CGFloat = 560

    var body: some View {
        GeometryReader { geo in
            let safeW = geo.size.width - (cardHorizontalMargin * 2)
            let baseH = min(geo.size.height * topHeightRatio, maxCardHeight)
            let theta = CGFloat(2.5) * .pi / 180
            let baseW = min(
                safeW,
                (safeW - baseH * sin(theta)) / max(cos(theta), 0.0001)
            )

            ZStack {
                // backdrop
                LinearGradient(
                    colors: [.white.opacity(colorScheme == .dark ? 0.02 : 0.06), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                // Deck
                ZStack {
                    ForEach(Array(deck.enumerated()), id: \.element.persistentModelID) { (i, job) in
                        card(job: job, index: i, size: CGSize(width: baseW, height: baseH))
                            .zIndex(zIndex(for: i))
                            .offset(x: xOffset(for: i))
                            .scaleEffect(scale(for: i))
                            .rotationEffect(.degrees(rotation(for: i)))
                            .shadow(color: shadow(for: i), radius: 30, y: 20)
                            .matchedGeometryEffect(id: job.persistentModelID, in: deckNS)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, cardHorizontalMargin)
                .contentShape(Rectangle())
                .gesture(dragGesture(width: geo.size.width))
                .onChange(of: selectedIndex) { _, newValue in
                    let maxIdx = max(0, deck.count - 1)
                    let clamped = min(max(0, newValue), maxIdx)
                    if clamped != newValue { selectedIndex = clamped }
                }
                .background(SizeReader { size in containerSize = size })

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

                // NEW: floating hamburger (works even if no nav bar shown)
                VStack {
                    HStack {
                        Button {
                            showSettings = true
                        } label: {
                            Image(systemName: "line.horizontal.3")
                                .font(.title3.weight(.semibold))
                                .padding(10)
                        }
                        .background(
                            Group {
                                if #available(iOS 26.0, *), isBetaGlassEnabled {
                                    Color.clear.glassEffect(.regular, in: .capsule)
                                } else {
                                    Capsule().fill(.ultraThinMaterial)
                                }
                            }
                        )
                        .overlay(Capsule().stroke(.white.opacity(0.10), lineWidth: 1))
                        .clipShape(Capsule())
                        .shadow(color: .black.opacity(0.25), radius: 10, y: 4)

                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                    Spacer()
                }
                .allowsHitTesting(expandedJob == nil) // avoid overlaps while expanded
                .zIndex(11)
            }
            .navigationTitle("") // keep nav bar slim if present
            .task {
                deck = jobs
                selectedIndex = 0
            }

            // Launches from expanded buttons (reuse your flows)
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

            // NEW: Settings presentation (mirrors the rest of the app)
            .sheet(isPresented: Binding(
                get: { showSettings && !isBetaGlassEnabled },
                set: { if !$0 { showSettings = false } }
            )) {
                SettingsView()
            }
            .overlay {
                if showSettings && isBetaGlassEnabled {
                    SettingsPanel(isPresented: $showSettings)
                        .zIndex(20)
                }
            }

            // Alerts
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
                        deck.removeAll { $0.persistentModelID == j.persistentModelID }
                        selectedIndex = min(selectedIndex, max(0, deck.count - 1))
                    }
                    jobForContext = nil
                }
            } message: { Text("This action cannot be undone.") }
        }
        // Also provide a nav-bar hamburger if this sits inside a NavigationStack
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    showSettings = true
                } label: {
                    Label("Menu", systemImage: "line.horizontal.3")
                }
            }
        }
    }

    // MARK: - Card content

    private func card(job: Job, index i: Int, size: CGSize) -> some View {
        let isTop = (i == selectedIndex)

        return ZStack {
            RoundedRectangle(cornerRadius: cardCorner, style: .continuous)
                .fill(.clear)
                .frame(width: size.width, height: size.height)
                .glassEffect(.regular.tint(color(for: job.effectiveColorIndex).opacity(0.50)),
                             in: .rect(cornerRadius: cardCorner))
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
                .contentShape(RoundedRectangle(cornerRadius: cardCorner, style: .continuous))

            if isTop && expandedJob == nil {
                Color.clear
                    .contentShape(RoundedRectangle(cornerRadius: cardCorner, style: .continuous))
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
    }

    // MARK: - CardDeck transforms

    private var progressIndex: Double { dragProgress + Double(selectedIndex) }
    private func currentPosition(for index: Int) -> Double { progressIndex - Double(index) }
    private func zIndex(for index: Int) -> Double { -abs(currentPosition(for: index)) }

    private func xOffset(for index: Int) -> Double {
        let padding = containerSize.width / 10
        let x = (Double(index) - progressIndex) * padding
        if index == selectedIndex && progressIndex < Double(max(0, deck.count - 1)) && progressIndex > 0 {
            return x * swingOutMultiplier
        }
        return x
    }
    private var swingOutMultiplier: Double { abs(sin(.pi * progressIndex) * 20) }
    private func scale(for index: Int) -> CGFloat { 1.0 - (0.1 * abs(currentPosition(for: index))) }
    private func rotation(for index: Int) -> Double { -currentPosition(for: index) * 2 }
    private func shadow(for index: Int) -> Color {
        let progress = 1.0 - abs(progressIndex - Double(index))
        return .black.opacity(0.30 * progress)
    }

    // MARK: - Drag / snap

    private func dragGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 5)
            .onChanged { value in
                guard width > 0 else { return }
                dragProgress = -(value.translation.width / width)
            }
            .onEnded { _ in snapToNearestIndex() }
    }

    private func snapToNearestIndex() {
        let threshold = 0.30
        if abs(dragProgress) < threshold {
            withAnimation(.bouncy) { dragProgress = 0.0 }
            return
        }
        if dragProgress < 0 {
            withAnimation(.smooth(duration: 0.25)) { bringLastToFront() }
        } else {
            withAnimation(.smooth(duration: 0.25)) { sendFirstToBack() }
        }
        dragProgress = 0.0
        selectedIndex = 0
    }

    private func sendFirstToBack() {
        guard let first = deck.first else { return }
        deck.removeFirst()
        deck.append(first)
    }

    private func bringLastToFront() {
        guard let last = deck.last else { return }
        deck.removeLast()
        deck.insert(last, at: 0)
    }

    // MARK: - Helpers

    private func cycleColor(_ job: Job) {
        job.cycleColorForward()
        try? modelContext.save()
    }
}

private struct SizeReader: View {
    var onChange: (CGSize) -> Void
    var body: some View {
        GeometryReader { proxy in
            Color.clear.preference(key: SizePrefKey.self, value: proxy.size)
        }
        .onPreferenceChange(SizePrefKey.self, perform: onChange)
    }
}
private struct SizePrefKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) { value = nextValue() }
}
