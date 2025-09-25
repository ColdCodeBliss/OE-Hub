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
            let w = min(geo.size.width * 0.82, 560)
            let h = min(geo.size.height * 0.78, 700)

            VStack(spacing: 10) {
                HStack {
                    Spacer()
                    Button {
                        close()
                    } label: {
                        Image(systemName: "chevron.backward")
                            .font(.headline.weight(.semibold))
                            .frame(width: 36, height: 36)
                    }
                    .glassButton()
                }

                Text(job.title)
                    .font(.title2.weight(.semibold))
                    .lineLimit(1)
                    .padding(.top, -4)

                LazyVGrid(columns: grid, spacing: 12) {
                    CardButton(title: "Due", system: "calendar", action: openDue)
                    CardButton(title: "Checklist", system: "checkmark.square", action: openChecklist)
                    CardButton(title: "Mind Map", system: "point.topleft.down.curvedto.point.bottomright.up", action: openMindMap)

                    CardButton(title: "Notes", system: "note.text", action: openNotes)
                    CardButton(title: "Info", system: "info.circle", action: openInfo)
                    CardButton(title: "GitHub", system: "chevron.left.slash.chevron.right", action: openGitHub)

                    CardButton(title: "Confluence", system: "link", action: openConfluence)
                    // two blanks to complete 3×3 look (or add future features)
                    Spacer().frame(maxHeight: .infinity)
                    Spacer().frame(maxHeight: .infinity)
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
            .frame(width: w, height: h)
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
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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
