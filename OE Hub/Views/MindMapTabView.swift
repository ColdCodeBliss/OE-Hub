import SwiftUI
import SwiftData

struct MindMapTabView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("isLiquidGlassEnabled") private var isLiquidGlassEnabled = false
    @AppStorage("isBetaGlassEnabled")   private var isBetaGlassEnabled   = false

    var job: Job

    // Canvas space (virtual large plane)
    private let canvasSize: CGFloat = 3000
    private var canvasRect: CGRect { CGRect(x: 0, y: 0, width: canvasSize, height: canvasSize) }
    private var canvasCenter: CGPoint { CGPoint(x: canvasSize/2, y: canvasSize/2) }

    // View state
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var selected: MindNode?

    // Track container size for proper centering
    @State private var viewSize: CGSize = .zero

    // Magnification baseline
    @State private var scaleBase: CGFloat = 1.0

    // New node placement
    private let childRadius: CGFloat = 220

    // Small node color palette (uses your Utilities.color(for:))
    private let nodeColorOptions: [String] = ["red","blue","green","yellow","orange","purple","pink","teal","gray"]

    // Clear-all confirmation
    @State private var showClearConfirm = false

    var body: some View {
        GeometryReader { geo in
            // The map canvas sits in a ZStack; gestures are attached ONLY to the canvas.
            ZStack(alignment: .topLeading) {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { selected = nil }

                mapContent
                    .frame(width: canvasSize, height: canvasSize)
                    // IMPORTANT: offset BEFORE scaling, with topLeading anchor
                    .offset(offset)
                    .scaleEffect(scale, anchor: .topLeading)
                    .gesture(panGesture.simultaneously(with: zoomGesture))
                    .animation(.interactiveSpring(), value: scale)
                    .animation(.interactiveSpring(), value: offset)
            }
            .onAppear {
                viewSize = geo.size
                ensureRoot()
                if let root = job.mindNodes.first(where: { $0.isRoot }) {
                    center(on: CGPoint(x: root.x, y: root.y))
                } else {
                    center(on: canvasCenter)
                }
            }
            .onChange(of: geo.size) { _, newSize in
                viewSize = newSize
            }
        }
        .navigationTitle("Mind Map")

        // ⬇️ Stationary controls: bottom bar
        .safeAreaInset(edge: .bottom) {
            controlsBar
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
        }

        // ⬇️ Floating clear button in the top-right (overlay, does NOT affect layout)
        .overlay(alignment: .topTrailing) {
            topRightClearButton
                .padding(.trailing, 12)
                .padding(.top, 8)
        }

        // Destructive confirmation
        .alert("Clear Mind Map?", isPresented: $showClearConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete All", role: .destructive) { clearMindMap() }
        } message: {
            Text("This will permanently delete all nodes. This action cannot be undone.")
        }
    }

    // MARK: - Map rendering

    private var mapContent: some View {
        ZStack {
            // Edges (curved)
            Canvas { ctx, _ in
                for node in job.mindNodes {
                    guard let parent = node.parent else { continue }
                    let p1 = CGPoint(x: parent.x, y: parent.y)
                    let p2 = CGPoint(x: node.x,   y: node.y)

                    var path = Path()
                    let mid = CGPoint(x: (p1.x + p2.x)/2, y: (p1.y + p2.y)/2)
                    path.move(to: p1)
                    path.addQuadCurve(to: p2, control: mid)

                    let stroke = StrokeStyle(lineWidth: 2, lineCap: .round)
                    ctx.stroke(path, with: .color(.primary.opacity(0.25)), style: stroke)
                }
            }

            // Nodes
            ForEach(job.mindNodes) { node in
                NodeBubble(node: node,
                           isSelected: node.id == selected?.id,
                           glassOn: (isLiquidGlassEnabled || isBetaGlassEnabled))
                    .position(x: node.x, y: node.y)
                    .highPriorityGesture(nodeDragGesture(for: node))
                    .onTapGesture { selected = node }
            }
        }
        .background(Color.clear)
        .clipped()
    }

    // MARK: - Stationary Controls (Safe-Area Inset)

    private var controlsBar: some View {
        HStack(spacing: 10) {
            Button { zoom(by: -0.15) } label: { controlIcon("minus.magnifyingglass") }
            Button { zoom(by:  0.15) } label: { controlIcon("plus.magnifyingglass") }
            Button { centerOnRoot() }   label: { controlIcon("target") }
            Button { addChild() }       label: { controlIcon("plus") }

            if let s = selected, !s.isRoot {
                Button(role: .destructive) { deleteSelected() } label: { controlIcon("trash") }
            }

            if let s = selected {
                Button { toggleComplete(s) } label: {
                    controlIcon(s.isCompleted ? "checkmark.circle.fill" : "circle")
                }

                // 🎨 Tiny color menu for the selected node
                Menu {
                    ForEach(nodeColorOptions, id: \.self) { code in
                        Button {
                            s.colorCode = code
                            try? modelContext.save()
                        } label: {
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(color(for: code))
                                    .frame(width: 14, height: 14)
                                Text(code.capitalized)
                            }
                        }
                    }
                } label: {
                    controlIcon("paintpalette")
                }
            }
        }
        .padding(10)
        .background(controlsBackground)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.25), radius: 10, y: 4)
    }

    @ViewBuilder
    private var controlsBackground: some View {
        if #available(iOS 18.0, *), isBetaGlassEnabled {
            Color.clear.glassEffect(.regular, in: .capsule)
        } else {
            Capsule().fill(.ultraThinMaterial)
        }
    }

    @ViewBuilder
    private func controlIcon(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 18, weight: .semibold))
            .frame(width: 36, height: 36)
            .contentShape(Rectangle())
    }

    // MARK: - Top-right floating clear button

    private var topRightClearButton: some View {
        Button {
            showClearConfirm = true
        } label: {
            Image(systemName: "trash")
                .font(.system(size: 16, weight: .semibold))
                .frame(width: 36, height: 36)
        }
        .padding(6)
        .background(topButtonBackground)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.25), radius: 10, y: 4)
        .accessibilityLabel("Clear Mind Map")
    }

    @ViewBuilder
    private var topButtonBackground: some View {
        if #available(iOS 18.0, *), isBetaGlassEnabled {
            Color.clear.glassEffect(.regular, in: .capsule)
        } else {
            Capsule().fill(.ultraThinMaterial)
        }
    }

    // MARK: - Gestures

    private var panGesture: some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { value in
                offset = CGSize(width: offset.width + value.translation.width,
                                height: offset.height + value.translation.height)
            }
    }

    private var zoomGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                // zoom around top-left anchor (simple & stable)
                scale = clamp(scaleBase * value, min: 0.4, max: 3.0)
            }
            .onEnded { _ in
                scaleBase = clamp(scale, min: 0.4, max: 3.0)
            }
    }

    private func nodeDragGesture(for node: MindNode) -> some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { v in
                // Convert drag in view space to map space
                node.x += Double(v.translation.width / scale)
                node.y += Double(v.translation.height / scale)
            }
            .onEnded { _ in try? modelContext.save() }
    }

    // MARK: - Actions

    private func ensureRoot() {
        if job.mindNodes.contains(where: { $0.isRoot }) { return }
        let root = MindNode(title: job.title.isEmpty ? "Central Idea" : job.title,
                            x: Double(canvasCenter.x),
                            y: Double(canvasCenter.y),
                            colorCode: "teal",
                            isRoot: true)
        root.job = job
        job.mindNodes.append(root)
        try? modelContext.save()
        selected = root
    }

    private func centerOnRoot() {
        if let root = job.mindNodes.first(where: { $0.isRoot }) {
            center(on: CGPoint(x: root.x, y: root.y))
        }
    }

    /// Center the given map-space point in the visible view, respecting current `scale`.
    private func center(on p: CGPoint) {
        guard viewSize != .zero else { return }
        withAnimation(.spring()) {
            // Because we apply .offset(...) BEFORE .scaleEffect(..., anchor: .topLeading),
            // a point at p ends up drawn at (p + offset) * scale.
            // We want that to equal the view center, so:
            //   (p + offset) * scale = viewCenter  =>  offset = viewCenter/scale - p
            let viewCenter = CGPoint(x: viewSize.width/2, y: viewSize.height/2)
            offset = CGSize(
                width:  viewCenter.x / scale - p.x,
                height: viewCenter.y / scale - p.y
            )
        }
    }

    private func addChild() {
        // Use selected, otherwise attach to root
        guard let anchor = selected ?? job.mindNodes.first(where: { $0.isRoot }) else { return }
        let count = max(0, anchor.children.count)
        // place around parent, cycling angles
        let angle = CGFloat(count) * (.pi / 3.0) // 0,60,120...
        let dx = cos(angle) * childRadius
        let dy = sin(angle) * childRadius
        let child = MindNode(title: "New Node",
                             x: anchor.x + Double(dx),
                             y: anchor.y + Double(dy),
                             colorCode: anchor.colorCode ?? "teal")
        child.job = job
        child.parent = anchor
        anchor.children.append(child)
        job.mindNodes.append(child)
        try? modelContext.save()
        selected = child
    }

    private func deleteSelected() {
        guard let node = selected, !node.isRoot else { return }
        if let parent = node.parent {
            for c in node.children {
                c.parent = parent
                parent.children.append(c)
            }
        }
        modelContext.delete(node)
        try? modelContext.save()
        selected = nil
    }

    private func toggleComplete(_ node: MindNode) {
        node.isCompleted.toggle()
        try? modelContext.save()
    }

    private func zoom(by delta: CGFloat) {
        scale = clamp(scale + delta, min: 0.4, max: 3.0)
        scaleBase = scale
        if let focus = selected ?? job.mindNodes.first(where: { $0.isRoot }) {
            center(on: CGPoint(x: focus.x, y: focus.y))
        }
    }

    private func clearMindMap() {
        // Delete all nodes (non-reversible)
        let nodes = job.mindNodes
        for n in nodes {
            modelContext.delete(n)
        }
        job.mindNodes.removeAll()
        try? modelContext.save()

        // Clear selection and reset transform
        selected = nil
        scale = 1.0
        scaleBase = 1.0

        // Center on the blank canvas
        center(on: canvasCenter)
    }

    private func clamp(_ v: CGFloat, min lo: CGFloat, max hi: CGFloat) -> CGFloat {
        Swift.max(lo, Swift.min(hi, v))
    }
}

// MARK: - Node bubble (compact)

private struct NodeBubble: View {
    @Environment(\.modelContext) private var modelContext
    var node: MindNode
    var isSelected: Bool
    var glassOn: Bool

    @AppStorage("isBetaGlassEnabled") private var isBetaGlassEnabled = false

    // 🔧 Compact sizing controls
    private let bubbleWidth: CGFloat = 220           // overall node width
    private let minBubbleHeight: CGFloat = 52        // minimum height
    private let radius: CGFloat = 16                 // corner radius
    private let titleFont: Font = .callout.weight(.semibold) // slightly smaller than headline
    private let hPad: CGFloat = 10
    private let vPad: CGFloat = 8

    var body: some View {
        let tint = color(for: node.colorCode ?? "teal")

        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: node.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(node.isCompleted ? .green : .secondary)
                    .onTapGesture { node.isCompleted.toggle(); try? modelContext.save() }

                TextField("Idea", text: binding(\.title))
                    .textFieldStyle(.plain)
                    .font(titleFont)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if !node.children.isEmpty {
                Text("\(node.children.count) node\(node.children.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, hPad)
        .padding(.vertical, vPad)
        .frame(width: bubbleWidth, alignment: .leading)
        .frame(minHeight: minBubbleHeight, alignment: .leading)
        .background(nodeBackground(tint: tint))
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .stroke(isSelected ? Color.accentColor.opacity(0.8) :
                                      (glassOn ? Color.white.opacity(0.10) : Color.white.opacity(0.20)),
                        lineWidth: isSelected ? 2 : 1)
        )
        .shadow(color: glassOn ? .black.opacity(0.25) : .black.opacity(0.15),
                radius: glassOn ? 12 : 5, x: 0, y: glassOn ? 7 : 0)
    }

    @ViewBuilder
    private func nodeBackground(tint: Color) -> some View {
        if #available(iOS 18.0, *), isBetaGlassEnabled {
            ZStack {
                Color.clear
                    .glassEffect(.regular.tint(tint.opacity(0.5)),
                                 in: .rect(cornerRadius: radius))
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(
                        LinearGradient(colors: [Color.white.opacity(0.18), .clear],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .blendMode(.plusLighter)
            }
        } else if glassOn {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(tint.opacity(0.55))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(LinearGradient(colors: [Color.white.opacity(0.18), .clear],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                        .blendMode(.plusLighter)
                )
        } else {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(tint.gradient)
        }
    }

    // Two-way binding into a SwiftData model property
    private func binding<T>(_ keyPath: ReferenceWritableKeyPath<MindNode, T>) -> Binding<T> {
        Binding(
            get: { node[keyPath: keyPath] },
            set: { node[keyPath: keyPath] = $0; try? modelContext.save() }
        )
    }
}
