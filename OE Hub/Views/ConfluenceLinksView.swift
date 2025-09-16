//
//  ConfluenceLinksView.swift
//  OE Hub
//
//  Created by Ryan Bliss on 9/14/25.
//

import SwiftUI
import UniformTypeIdentifiers

struct ConfluenceLinksView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.horizontalSizeClass) private var hSize

    /// Per-job storage key (e.g., "confluenceLinks.<job.repoBucketKey>")
    let storageKey: String
    /// Max links to keep
    let maxLinks: Int

    // Persisted JSON array of strings under `storageKey`
    @AppStorage private var linksJSON: String

    // In-memory working copy
    @State private var links: [String] = []
    @State private var inputURL: String = ""
    @State private var errorMessage: String?

    init(storageKey: String, maxLinks: Int = 5) {
        self.storageKey = storageKey
        self.maxLinks = maxLinks
        self._linksJSON = AppStorage(wrappedValue: "[]", storageKey)
    }

    var body: some View {
        NavigationStack {
            // Center/constrain on iPad, full-width on iPhone
            Group {
                Form {
                    Section(header: Text("Add Confluence Link")) {
                        TextField("https://your-space.atlassian.net/wiki/...", text: $inputURL)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.URL)
                            .autocorrectionDisabled(true)
                            .submitLabel(.go)
                            .onSubmit { addLink() }

                        Button("Add Link") { addLink() }
                            .disabled(!isValidURL(normalized(inputURL)))
                    }

                    if let err = errorMessage {
                        Section {
                            Text(err)
                                .font(.footnote)
                                .foregroundStyle(.red)
                        }
                    }

                    if !links.isEmpty {
                        Section(header: Text("Saved Links")) {
                            ForEach(links, id: \.self) { url in
                                Button {
                                    open(urlString: url)
                                } label: {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(shortLabel(for: url))
                                            .font(.body)
                                        Text(url)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button("Copy") {
                                        UIPasteboard.general.string = url
                                    }
                                }
                            }
                            .onDelete(perform: delete)
                        }
                    } else {
                        Section {
                            Text("No saved Confluence links yet.")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .formStyle(.grouped)
                .frame(maxWidth: hSize == .regular ? 640 : .infinity) // 💡 center on iPad
                .scrollDismissesKeyboard(.interactively)
                .onDrop(of: [.url, .text], isTargeted: nil) { providers in
                    // iPad drag & drop: accept a single URL/text
                    if let item = providers.first {
                        _ = item.loadObject(ofClass: URL.self) { url, _ in
                            if let url { Task { await MainActor.run { inputURL = url.absoluteString; addLink() } } }
                        }
                        item.loadItem(forTypeIdentifier: UTType.text.identifier, options: nil) { data, _ in
                            if let d = data as? Data, let s = String(data: d, encoding: .utf8) {
                                Task { await MainActor.run {
                                    inputURL = s.trimmingCharacters(in: .whitespacesAndNewlines)
                                    addLink()
                                } }
                            }
                        }
                    }
                    return true
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, hSize == .regular ? 12 : 0)

            .navigationTitle("Confluence")
            .navigationBarTitleDisplayMode(.inline) // saves vertical space with keyboard
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    EditButton()
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear(perform: load)
        }
    }

    // MARK: - Actions

    private func normalized(_ raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if !s.lowercased().hasPrefix("http://") && !s.lowercased().hasPrefix("https://") {
            s = "https://" + s
        }
        return s
    }

    private func addLink() {
        errorMessage = nil
        let urlString = normalized(inputURL)

        guard isValidURL(urlString) else {
            errorMessage = "Please enter a valid URL (http/https)."
            return
        }

        // De-dupe (case-insensitive) & cap
        var arr = links
        arr.removeAll { $0.caseInsensitiveCompare(urlString) == .orderedSame }
        arr.insert(urlString, at: 0)
        if arr.count > maxLinks {
            arr = Array(arr.prefix(maxLinks))
        }

        links = arr
        save()
        inputURL = ""
    }

    private func delete(at offsets: IndexSet) {
        links.remove(atOffsets: offsets)
        save()
    }

    private func open(urlString: String) {
        guard let url = URL(string: urlString) else { return }
        // Universal Link behavior: if the Confluence app claims the domain it’ll open the app,
        // otherwise it’ll fall back to the default browser.
        openURL(url)
    }

    // MARK: - Persistence

    private func load() {
        links = decode(linksJSON)
    }

    private func save() {
        linksJSON = encode(links)
    }

    private func decode(_ json: String) -> [String] {
        guard let data = json.data(using: .utf8),
              let arr = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return arr
    }

    private func encode(_ arr: [String]) -> String {
        (try? String(data: JSONEncoder().encode(arr), encoding: .utf8)) ?? "[]"
    }

    // MARK: - Helpers

    private func isValidURL(_ str: String) -> Bool {
        guard let url = URL(string: str) else { return false }
        guard let scheme = url.scheme?.lowercased() else { return false }
        return (scheme == "http" || scheme == "https") && url.host != nil
    }

    private func shortLabel(for urlString: String) -> String {
        guard let url = URL(string: urlString) else { return urlString }
        let host = url.host ?? ""
        let parts = url.path.split(separator: "/").map(String.init)
        let tail = parts.last ?? ""
        if tail.isEmpty {
            return host
        } else {
            return "\(host) • \(tail)"
        }
    }
}
