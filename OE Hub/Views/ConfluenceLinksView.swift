import SwiftUI

struct ConfluenceLinksView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

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
            Form {
                Section(header: Text("Add Confluence Link")) {
                    TextField("https://your-space.atlassian.net/wiki/...", text: $inputURL)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .autocorrectionDisabled(true)

                    Button("Add Link") { addLink() }
                        .disabled(!isValidURL(inputURL))
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
            .navigationTitle("Confluence")
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

    private func addLink() {
        errorMessage = nil
        var urlString = inputURL.trimmingCharacters(in: .whitespacesAndNewlines)

        // Normalize: prepend https:// if user omitted scheme
        if !urlString.lowercased().hasPrefix("http://") && !urlString.lowercased().hasPrefix("https://") {
            urlString = "https://" + urlString
        }

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
        // Universal Link behavior: if Confluence app is installed & handles the domain,
        // iOS will open the app. Otherwise it opens in the default browser.
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
