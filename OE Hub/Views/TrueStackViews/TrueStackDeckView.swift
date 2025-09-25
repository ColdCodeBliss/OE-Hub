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

    // Layout
    private let cardSizeRatio: CGFloat = 0.78   // top card ~78% width of screen
    private let stackDepth = 6                  // show up to N visible layers
    private let tilt: CGFloat = 4               // degrees; alternates L/R
    private let layerOffset: CGFloat = 11       // y-offset per layer
    private let layerScaleStep: CGFloat = 0.04  // scale step per layer
    private let swipeThreshold: CGFloat = 90    // px to complete a swipe

    init(jobs: [Job]) {
        self.jobs = jobs
    }

    var body: some View {
        GeometryReader { geo in
            let baseW = min(geo.size.width * cardSizeRatio, 520)
            let baseH = min(geo.size.height * 0.66, 520)

            ZStack {
                // Background shimmer to match your app’s vibe
                LinearGradient(colors: [
                    .white.opacity(colorScheme == .dark ? 0.02 : 0.06),
                    .clear
                ], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

                // Deck
                ZStack {
                    ForEach(Array(deck.prefix(stackDepth).enumerated()), id: \.element.persistentModelID) { (idx, job) in
                        card(job: job, index: idx, size: CGSize(width: baseW, height: baseH))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

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
            .task {
                // Initialize deck (top = first)
                deck = jobs
            }
            // MARK: Launches from expanded buttons (Beta = panels or sheets—reuse your existing views)
            .sheet(isPresented: $showDue) { JobDetailView(job: expandedJob!).navigationBarTitleDisplayMode(.inline) }
            .sheet(isPresented: $showChecklist) { JobDetailView(job: expandedJob!).navigationBarTitleDisplayMode(.inline) }
            .sheet(isPresented: $showMindMap) { JobDetailView(job: expandedJob!).navigationBarTitleDisplayMode(.inline) }
            .sheet(isPresented: $showNotes) { JobDetailView(job: expandedJob!).navigationBarTitleDisplayMode(.inline) }
            .sheet(isPresented: $showInfo) { JobDetailView(job: expandedJob!).navigationBarTitleDisplayMode(.inline) }
            .fullScreenCover(isPresented: $showGitHub) {
                if let j = expandedJob {
                    GitHubBrowserView(recentKey: "recentRepos.\(j.repoBucketKey)")
                }
            }
            .fullScreenCover(isPresented: $showConfluence) {
                if let j = expandedJob {
                    ConfluenceLinksView(storageKey: "confluenceLinks.\(j.repoBucketKey)", maxLinks: 5)
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
        let opacity: Double = 1.0 - Double(idx) * 0.12
        let scale: CGFloat = 1.0 - CGFloat(idx) * layerScaleStep

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
            // Glass card body
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.clear)
                .frame(width: size.width, height: size.height)
                .glassEffect(.regular.tint(color(for: job.colorCode).opacity(0.50)), in: .rect(cornerRadius: 22))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                )
                .overlay(
                    VStack(spacing: 10) {
                        Text(job.title)
                            .font(.title3.weight(.semibold))
                            .lineLimit(1)
                        Text("Created \(formattedDate(job.creationDate))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                        .padding()
                )
                .opacity(opacity)

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
                            // Context actions
                            jobForContext = job
                            pendingRenameText = job.title
                            // Present a simple action sheet via ConfirmationDialog
                        }
                    )
                    .contextMenu {
                        Button("Rename") {
                            jobForContext = job
                            pendingRenameText = job.title
                            showRenameAlert = true
                        }
                        Button("Change Color") {
                            cycleColor(job)
                        }
                        Button("Delete", role: .destructive) {
                            jobForContext = job
                            showDeleteConfirm = true
                        }
                    }
            }
        }
        .matchedGeometryEffect(id: job.persistentModelID, in: deckNS)
        .offset(y: CGFloat(idx) * layerOffset)
        .rotationEffect(.degrees(Double(tiltSign) * Double(tilt)))
        .scaleEffect(scale)
        .offset(x: isTop ? dragTranslation : 0) // swipe top card
        .gesture(isTop ? drag : nil)
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
        // Simple example cycle across your 0...N palette
        job.colorCode = (job.colorCode + 1) % 12
        try? modelContext.save()
    }
}
