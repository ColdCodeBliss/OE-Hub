//
//  JobHistorySheetView.swift
//  OE Hub
//
//  Created by Ryan Bliss on 9/8/25.
//


import SwiftUI
import SwiftData

struct JobHistorySheetView: View {
    let deletedJobs: [Job]
    @Binding var jobToDeletePermanently: Job?
    var onDone: () -> Void

    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            List {
                ForEach(deletedJobs, id: \.persistentModelID) { job in
                    VStack(alignment: .trailing) {
                        Text(job.title)
                            .font(.headline)
                        Text("Deleted: \(job.deletionDate ?? Date(), format: .dateTime.day().month().year())")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            jobToDeletePermanently = job
                        } label: {
                            Label("Total Deletion", systemImage: "trash.fill")
                        }
                    }
                }
            }
            .navigationTitle("Stack History")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { onDone() }
                }
            }
        }
    }
}
