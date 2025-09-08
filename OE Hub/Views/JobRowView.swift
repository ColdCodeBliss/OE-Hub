//
//  JobRowView.swift
//  OE Hub
//
//  Created by Ryan Bliss on 9/8/25.
//


import SwiftUI
import SwiftData

struct JobRowView: View {
    let job: Job

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(job.title)
                .font(.headline)

            Text("Created: \(job.creationDate, format: .dateTime.day().month().year())")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("\(activeItemsCount(job)) active items")
                .font(.caption)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color(for: job.colorCode))
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func activeItemsCount(_ job: Job) -> Int {
        let activeDeliverables = job.deliverables.filter { !$0.isCompleted }.count
        let activeChecklistItems = job.checklistItems.filter { !$0.isCompleted }.count
        return activeDeliverables + activeChecklistItems
    }
}
