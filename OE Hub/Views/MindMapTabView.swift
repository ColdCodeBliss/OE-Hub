//
//  MindMapTabView.swift
//  OE Hub
//
//  Created by Ryan Bliss on 9/10/25.
//


import SwiftUI
import SwiftData

struct MindMapTabView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("isLiquidGlassEnabled") private var isLiquidGlassEnabled = false
    @AppStorage("isBetaGlassEnabled") private var isBetaGlassEnabled = false

    var job: Job

    // Canvas space (big virtual plane)
    private let canvasSize: CGFloat = 3000
    private var canvasRect: CGRect { CGRect(x: 0, y: 0, width: canvasSize, height: canvasSize) }
    private var canvasCenter: CGPoint { CGPoint(x: canvasSize/2, y: canvasSize/2) }

    // View state
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastDrag: CGSize = .zero
    @State private var selected: MindNode?

    // New node placement
    private let childRadius: CGFloat = 220

    var body: some View {
        GeometryReader { _ in
            ZStack {
                // Background tap to deselect
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { selected = nil }

                // The entire map (we transform this)
                mapContent
                    .frame(width: canvasSize, height: canvasSize)
                    .scaleEffect(scale)
                    .offset(offset)
                    .gesture(panGesture.simultaneously(with: zoomGesture))
                    .animation(.interactiveSpring(), value: scale)
                    .animation(.interactiveSpring(), value: offset)

                // HUD controls
                controls
            }
            .onAppear { ensureRoot() }
        }
        .navigationTitle("Mind Map")
    }

    // MARK: - Map rendering

    private var mapContent: some View {
        ZStack {
            // Edges first
            Canvas { ctx, _ in
                let nodes = job.mindNodes
                for node in nodes {
                    guard let parent = node.parent else { continue }
                    let p1 = CGPoint(x: parent.x, y: parent.y)
                    let p2 = CGPoint(x: node.x,   y: node.y)

                    var path = Path()
                    // soft curved edge
                    let mid = CGPoint(x: (p1.x + p2.x)/2, y: (p1.y + p2.y)/2)
                    path.move(to: p1)
                    path.addQuadCurve(to: p2, control: mid)

                    let stroke = StrokeStyle(lineWidth: 2, lineCap: .round)
                    ctx.stroke(path, with: .color(.primary.opacity(0.25)), style: stroke)
                }
            }

            // Nodes on top
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
        // start with the root roughly centered
        .task {
            if let root = job.mindNodes.first(where: { $0.isRoot }) {
                center(on: CGPoint(x: root.x, y: root.y))
            }
        }
    }

    // MARK: - Controls

    private var controls: some View {
        VStack {
            Spacer()
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
                }
            }
            .padding(10)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .padding(.bottom, 16)
        }
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private func controlIcon(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 18, weight: .semibold))
            .frame(width: 36, height: 36)
    }

    // MARK: - Gestures

    private var panGesture: some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { value in
                offset = CGSize(width: lastDrag.width + value.translation.width,
                                height: lastDrag.height + value.translation.height)
            }
            .onEnded { _ in lastDrag = offset }
    }

    private var zoomGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                scale = clamp(scaleBase * value, min: 0.4, max: 3.0)
            }
            .onEnded { _ in
                scaleBase = clamp(scale, min: 0.4, max: 3.0)
            }
    }

    @State private var scaleBase: CGFloat = 1.0

    private func nodeDragGesture(for node: MindNode) -> some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { v in
                // Convert drag in view space to map space (divide by scale)
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

    private func center(on p: CGPoint) {
        // Offset so that point p lands roughly in the middle of the screen
        // We can just zero offset first (simple approach).
        withAnimation(.spring()) {
            offset = .zero
            lastDrag = .zero
            scale = 1.0
            scaleBase = 1.0
        }
    }

    private func addChild() {
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
        // orphan children -> reattach to parent
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
    }

    private func clamp(_ v: CGFloat, min lo: CGFloat, max hi: CGFloat) -> CGFloat {
        Swift.max(lo, Swift.min(hi, v))
    }
}

// MARK: - Node bubble

private struct NodeBubble: View {
    @Environment(\.modelContext) private var modelContext
    var node: MindNode
    var isSelected: Bool
    var glassOn: Bool

    @AppStorage("isBetaGlassEnabled") private var isBetaGlassEnabled = false

    private let radius: CGFloat = 18

    var body: some View {
        let tint = color(for: node.colorCode ?? "teal")

        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: node.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(node.isCompleted ? .green : .secondary)
                    .onTapGesture { node.isCompleted.toggle(); try? modelContext.save() }

                TextField("Idea", text: binding(\.title))
                    .textFieldStyle(.plain)
                    .font(.headline)
                    .foregroundStyle(.primary)
            }

            if !node.children.isEmpty {
                Text("\(node.children.count) node\(node.children.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(nodeBackground(tint: tint))
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .stroke(isSelected ? Color.accentColor.opacity(0.8) :
                                      (glassOn ? Color.white.opacity(0.10) : Color.white.opacity(0.20)),
                        lineWidth: isSelected ? 2 : 1)
        )
        .shadow(color: glassOn ? .black.opacity(0.25) : .black.opacity(0.15),
                radius: glassOn ? 14 : 5, x: 0, y: glassOn ? 8 : 0)
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
