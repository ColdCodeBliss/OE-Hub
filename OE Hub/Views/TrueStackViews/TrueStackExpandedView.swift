//
//  TrueStackExpandedView.swift
//  OE Hub
//
//  Created by Ryan Bliss on 9/24/25.
//

import SwiftUI

@available(iOS 26.0, *)
struct TrueStackExpandedView: View {
    let job: Job

    let close: () -> Void
    let openDue: () -> Void
    let openChecklist: () -> Void
    let openMindMap: () -> Void
    let openNotes: () -> Void
    let openInfo: () -> Void
    let openGitHub: () -> Void
    let openConfluence: () -> Void

    private let grid: [GridItem] = Array(repeating: .init(.flexible(), spacing: 12), count: 3)

    var body: some View {
        GeometryReader { geo in
            // Width cap; height will hug content (no more big blank bottom)
            let maxW = min(geo.size.width * 0.82, 560)

            VStack(spacing: 10) {
                // Chevron on the LEFT, nudged down/right so it clears the rounded corner
                HStack {
                    Button(action: close) {
                        Image(systemName: "chevron.backward")
                            .font(.headline.weight(.semibold))
                            .frame(width: 36, height: 36)
                    }
                    .glassButton()
                    .padding(.leading, 4)  // ← slight right nudge
                    .padding(.top, 6)      // ↓ slight down nudge

                    Spacer()
                }

                // Tighter top spacing under the chevron
                Text(job.title)
                    .font(.title2.weight(.semibold))
                    .lineLimit(1)
                    .padding(.top, 2)

                LazyVGrid(columns: grid, spacing: 12) {
                    CardButton(title: "Due",        system: "calendar",                                         action: openDue)
                    CardButton(title: "Checklist",  system: "checkmark.square",                                 action: openChecklist)
                    CardButton(title: "Mind Map",   system: "point.topleft.down.curvedto.point.bottomright.up", action: openMindMap)

                    CardButton(title: "Notes",      system: "note.text",                                        action: openNotes)
                    CardButton(title: "Info",       system: "info.circle",                                      action: openInfo)
                    CardButton(title: "GitHub",     system: "chevron.left.slash.chevron.right",                 action: openGitHub)

                    CardButton(title: "Confluence", system: "link",                                             action: openConfluence)
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 6)   // slightly tighter bottom padding to remove extra space
            }
            // Make the panel size itself to its content vertically (this removes the big blank bottom)
            .fixedSize(horizontal: false, vertical: true)
            .frame(width: maxW, alignment: .top)

            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.clear)
                    .glassEffect(.regular, in: .rect(cornerRadius: 24))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(Color.white.opacity(0.10), lineWidth: 1)
                    )
            )
            .shadow(color: .black.opacity(0.35), radius: 24, y: 10)
            // keep it centered within available space
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }
}

// MARK: - Buttons

@available(iOS 26.0, *)
private struct CardButton: View {
    let title: String
    let system: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: system)
                    .font(.title3)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 86)
        }
        .glassButton()
    }
}
