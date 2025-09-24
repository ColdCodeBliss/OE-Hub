import SwiftUI

struct HelpView: View {
    @AppStorage("isLiquidGlassEnabled") private var isLiquidGlassEnabled = false
    @AppStorage("isBetaGlassEnabled")   private var isBetaGlassEnabled   = false

    private var useBetaGlass: Bool {
        if #available(iOS 26.0, *) { return isBetaGlassEnabled }
        return false
    }
    private var useClassicGlass: Bool { isLiquidGlassEnabled && !useBetaGlass }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    SectionCard(title: "Getting Started",
                                useBetaGlass: useBetaGlass,
                                useClassicGlass: useClassicGlass) {
                        Label("Create your first Stack", systemImage: "folder.badge.plus")
                            .font(.subheadline.weight(.semibold))
                        Text("Tap the **+** button in the top-right of Home to add a new stack. On iPad, select a stack in the sidebar.")
                            .foregroundStyle(.secondary)
                    }

                    SectionCard(title: "Tabs Overview",
                                useBetaGlass: useBetaGlass,
                                useClassicGlass: useClassicGlass) {
                        tipRow(icon: "calendar", title: "Due",
                               text: "Plan deliverables & reminders. Tap left side to rename; swipe to complete/color/delete.")
                        tipRow(icon: "checkmark.square", title: "Checklist",
                               text: "Light to-dos per stack.")
                        tipRow(icon: "point.topleft.down.curvedto.point.bottomright.up", title: "Mind Map",
                               text: "Pinch to zoom, drag to pan; node drag sensitivity tuned for precision.")
                        tipRow(icon: "note.text", title: "Notes",
                               text: "Rich text: bold, underline, strikethrough, bullets.")
                        tipRow(icon: "info.circle", title: "Info",
                               text: "Edit metadata; open GitHub & Confluence tools.")
                    }

                    SectionCard(title: "Toolbars & Integrations",
                                useBetaGlass: useBetaGlass,
                                useClassicGlass: useClassicGlass) {
                        tipRow(icon: "link", title: "Confluence",
                               text: "Add up to 5 links per stack with Universal Links.")
                        tipRow(icon: "chevron.left.slash.chevron.right", title: "GitHub",
                               text: "Browse public repos, preview files, keep recents per stack.")
                    }

                    SectionCard(title: "Tips",
                                useBetaGlass: useBetaGlass,
                                useClassicGlass: useClassicGlass) {
                        tipRow(icon: "bell", title: "Reminders",
                               text: "Quick offsets like 2w/1w/2d/day-of on each deliverable.")
                        tipRow(icon: "paintbrush", title: "Colors",
                               text: "Tint deliverables from swipe actions.")
                        tipRow(icon: "gear", title: "Appearance",
                               text: "Switch Liquid Glass styles in Settings.")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(maxWidth: 1100)
                .frame(maxWidth: .infinity)
            }
            .navigationTitle("Help")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func tipRow(icon: String, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon).frame(width: 18)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(text).foregroundStyle(.secondary)
            }
        }
    }
}
