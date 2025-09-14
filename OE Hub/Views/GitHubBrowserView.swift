//
//  GitHubBrowserView.swift
//  OE Hub
//
//  Created by Ryan Bliss on 9/13/25.
//
import SwiftUI
import Foundation
import UniformTypeIdentifiers

// MARK: - Models

fileprivate struct RepoRef: Equatable {
    var owner: String
    var name: String
    var branch: String?      // optional override from URL (e.g., .../tree/<branch>/...)
    var initialPath: String? // optional initial subpath from URL
}

fileprivate struct ContentItem: Decodable, Identifiable {
    let name: String
    let path: String
    let sha: String
    let size: Int?
    let type: String           // "file" | "dir" | "symlink" | "submodule"
    let download_url: String?  // only for files
    let html_url: String?      // nice to have
    let encoding: String?
    let content: String?
    var id: String { sha }
}

// MARK: - Service

fileprivate enum GHService {
    static let base = URL(string: "https://api.github.com")!

    static func fetchDefaultBranch(owner: String, repo: String) async throws -> String {
        let url = base.appending(path: "/repos/\(owner)/\(repo)")
        let (data, resp) = try await URLSession.shared.data(from: url)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        return (obj?["default_branch"] as? String) ?? "main"
    }

    static func listContents(owner: String, repo: String, path: String?, ref: String) async throws -> [ContentItem] {
        var comps = URLComponents(url: base.appending(path: "/repos/\(owner)/\(repo)/contents/\(path ?? "")"), resolvingAgainstBaseURL: false)!
        comps.queryItems = [URLQueryItem(name: "ref", value: ref)]
        let (data, resp) = try await URLSession.shared.data(from: comps.url!)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode([ContentItem].self, from: data)
    }

    static func fetchFile(owner: String, repo: String, path: String, ref: String) async throws -> ContentItem {
        var comps = URLComponents(url: base.appending(path: "/repos/\(owner)/\(repo)/contents/\(path)"), resolvingAgainstBaseURL: false)!
        comps.queryItems = [URLQueryItem(name: "ref", value: ref)]
        let (data, resp) = try await URLSession.shared.data(from: comps.url!)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(ContentItem.self, from: data)
    }

    static func fetchRaw(url: URL) async throws -> Data {
        let (data, resp) = try await URLSession.shared.data(from: url)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return data
    }
}

// MARK: - Main Browser View (per-job recents)

struct GitHubBrowserView: View {
    @Environment(\.dismiss) private var dismiss

    /// Per-job UserDefaults key (namespaced by Job.repoBucketKey via caller)
    let recentKey: String
    /// Max recent repos to keep (change to 5 or 10 later if desired)
    let maxRecents: Int = 3

    // MARK: Persistence via @AppStorage (dynamic key)
    @AppStorage private var recentReposJSON: String

    // Input
    @State private var repoURLString: String = ""
    // Parsed
    @State private var repo: RepoRef? = nil
    @State private var branch: String = "main"
    @State private var currentPath: String = ""

    // Data
    @State private var items: [ContentItem] = []
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?

    // File preview
    @State private var showingFile: Bool = false
    @State private var fileTitle: String = ""
    @State private var fileText: String = ""
    @State private var fileData: Data? = nil
    @State private var fileIsText: Bool = true
    @State private var fileDownloadURL: URL? = nil

    // Per-job recents (in-memory working copy)
    @State private var recentRepos: [String] = []

    // Bind @AppStorage to dynamic key
    init(recentKey: String) {
        self.recentKey = recentKey
        self._recentReposJSON = AppStorage(wrappedValue: "[]", recentKey)
    }

    var body: some View {
        NavigationStack {
            Group {
                if repo == nil {
                    // URL entry
                    VStack(spacing: 16) {
                        Text("Load a public GitHub repository")
                            .font(.headline)

                        TextField("e.g. https://github.com/apple/swift", text: $repoURLString)
                            .textFieldStyle(.roundedBorder)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                            .keyboardType(.URL)
                            .padding(.horizontal)

                        Button {
                            Task { await loadFromURL() }
                        } label: {
                            Text("Load Repository")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(.blue.opacity(0.85))
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .padding(.horizontal)

                        // Recent per-job repos
                        if !recentRepos.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Recent").font(.subheadline).foregroundStyle(.secondary)
                                FlowLayout(spacing: 8) {
                                    ForEach(recentRepos, id: \.self) { url in
                                        Button {
                                            repoURLString = url
                                            Task { await loadFromURL() }
                                        } label: {
                                            HStack(spacing: 6) {
                                                Image(systemName: "clock.arrow.circlepath")
                                                Text(shortLabel(for: url))
                                            }
                                            .font(.caption)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .background(Color.gray.opacity(0.15))
                                            .clipShape(Capsule())
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }

                        if let err = errorMessage {
                            Text(err).foregroundStyle(.red).font(.footnote)
                                .padding(.horizontal)
                        }

                        Spacer()
                    }
                    .padding(.top, 24)
                    .onAppear { loadRecents() }
                } else {
                    // Directory listing
                    List {
                        if !currentPath.isEmpty {
                            Section {
                                Button {
                                    goUpOne()
                                } label: {
                                    Label("..", systemImage: "arrow.up.left")
                                }
                            }
                        }

                        ForEach(items) { item in
                            HStack {
                                Image(systemName: iconName(for: item))
                                    .foregroundStyle(item.type == "dir" ? .yellow : .secondary)
                                VStack(alignment: .leading) {
                                    Text(item.name).font(.body)
                                    Text(item.path).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                Task { await handleTap(item) }
                            }
                        }
                    }
                    .overlay { if isLoading { ProgressView().scaleEffect(1.2) } }
                }
            }
            .navigationTitle(repoTitle)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .principal) {
                    if let r = repo {
                        Text("\(r.owner)/\(r.name)")
                            .font(.subheadline.bold())
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if repo != nil {
                        Button {
                            Task { await reloadCurrentFolder() }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .disabled(isLoading)
                    }
                }
            }
            .sheet(isPresented: $showingFile) { filePreview }
        }
    }

    private var repoTitle: String {
        if let r = repo { return r.name }
        return "GitHub"
    }

    // MARK: - Actions

    private func loadFromURL() async {
        errorMessage = nil
        guard let parsed = parseRepoURL(repoURLString) else {
            errorMessage = "Unable to parse owner/repo from URL."
            return
        }
        repo = parsed
        isLoading = true
        do {
            let defaultBranch = try await GHService.fetchDefaultBranch(owner: parsed.owner, repo: parsed.name)
            branch = parsed.branch ?? defaultBranch
            currentPath = parsed.initialPath ?? ""
            items = try await GHService.listContents(owner: parsed.owner, repo: parsed.name, path: currentPath.isEmpty ? nil : currentPath, ref: branch)

            // Save to per-job recents
            pushRecent(url: repoURLString)
        } catch {
            errorMessage = "Failed to load repository. Please check the URL and try again."
            repo = nil
        }
        isLoading = false
    }

    private func reloadCurrentFolder() async {
        guard let r = repo else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            items = try await GHService.listContents(owner: r.owner, repo: r.name, path: currentPath.isEmpty ? nil : currentPath, ref: branch)
        } catch {
            errorMessage = "Failed to reload folder."
        }
    }

    private func handleTap(_ item: ContentItem) async {
        guard let r = repo else { return }
        if item.type == "dir" {
            currentPath = item.path
            await reloadCurrentFolder()
            return
        }

        // File tap
        isLoading = true
        defer { isLoading = false }
        do {
            // Fetch full content via the API to get base64 for text files
            let file = try await GHService.fetchFile(owner: r.owner, repo: r.name, path: item.path, ref: branch)
            fileTitle = item.name
            fileDownloadURL = file.download_url.flatMap(URL.init(string:))

            // Try text via base64
            if let enc = file.encoding?.lowercased(), enc == "base64", let b64 = file.content,
               let data = Data(base64Encoded: b64),
               let text = String(data: data, encoding: .utf8) {
                fileText = text
                fileData = nil
                fileIsText = true
                showingFile = true
                return
            }

            // Not text (or failed to decode) → raw
            if let rawURL = fileDownloadURL {
                let data = try await GHService.fetchRaw(url: rawURL)
                fileData = data
                fileIsText = isProbablyText(data) == true ? true : false
                if fileIsText, let text = String(data: data, encoding: .utf8) {
                    fileText = text
                    fileData = nil
                }
                showingFile = true
            } else {
                fileText = "(Unable to display file. Try 'Open Raw'.)"
                fileData = nil
                fileIsText = true
                showingFile = true
            }
        } catch {
            fileTitle = item.name
            fileText = "Failed to load file."
            fileData = nil
            fileIsText = true
            showingFile = true
        }
    }

    private func goUpOne() {
        guard !currentPath.isEmpty else { return }
        var comps = currentPath.split(separator: "/").map(String.init)
        _ = comps.popLast()
        currentPath = comps.joined(separator: "/")
        Task { await reloadCurrentFolder() }
    }

    // MARK: - Per-job recents (@AppStorage JSON)

    private func loadRecents() {
        recentRepos = decodeRecent(recentReposJSON)
    }

    private func pushRecent(url: String) {
        var arr = decodeRecent(recentReposJSON)
        // Remove duplicates (move to front, case-insensitive)
        arr.removeAll { $0.caseInsensitiveCompare(url) == .orderedSame }
        arr.insert(url, at: 0)
        // Cap
        if arr.count > maxRecents {
            arr = Array(arr.prefix(maxRecents))
        }
        recentRepos = arr
        recentReposJSON = encodeRecent(arr)
    }

    private func decodeRecent(_ json: String) -> [String] {
        guard let data = json.data(using: .utf8),
              let arr = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return arr
    }

    private func encodeRecent(_ arr: [String]) -> String {
        (try? String(data: JSONEncoder().encode(arr), encoding: .utf8)) ?? "[]"
    }

    // MARK: - Parsing / helpers

    /// Accepts: https://github.com/<owner>/<repo>
    /// Also accepts: https://github.com/<owner>/<repo>/tree/<branch>/<optional/path...>
    private func parseRepoURL(_ str: String) -> RepoRef? {
        guard let url = URL(string: str), url.host?.lowercased().contains("github.com") == true else { return nil }
        let parts = url.path.split(separator: "/").map(String.init)
        guard parts.count >= 2 else { return nil }
        let owner = parts[0]
        let name  = parts[1]

        if parts.count >= 4, parts[2] == "tree" {
            let branch = parts[3]
            let extraPath = parts.dropFirst(4).joined(separator: "/")
            return RepoRef(owner: owner, name: name, branch: branch, initialPath: extraPath.isEmpty ? nil : extraPath)
        }
        return RepoRef(owner: owner, name: name, branch: nil, initialPath: nil)
    }

    private func shortLabel(for urlString: String) -> String {
        guard let url = URL(string: urlString) else { return urlString }
        let comps = url.path.split(separator: "/").map(String.init)
        if comps.count >= 2 {
            return "\(comps[0])/\(comps[1])"
        }
        return urlString.replacingOccurrences(of: "https://", with: "")
    }

    private func iconName(for item: ContentItem) -> String {
        if item.type == "dir" { return "folder" }
        let ext = (item.name as NSString).pathExtension.lowercased()
        switch ext {
        case "md": return "doc.text"
        case "json", "yml", "yaml", "xml", "plist": return "curlybraces.square"
        case "swift", "m", "mm", "h", "cpp", "c", "js", "ts", "java", "kt", "py", "rb", "go", "rs", "php":
            return "chevron.left.slash.chevron.right"
        case "png", "jpg", "jpeg", "gif", "webp", "bmp", "heic": return "photo"
        case "pdf": return "doc.richtext"
        default: return "doc"
        }
    }

    private func isProbablyText(_ data: Data) -> Bool {
        // Heuristic: if it decodes as UTF-8 without nils, treat as text
        if let _ = String(data: data, encoding: .utf8) { return true }
        return false
    }

    // MARK: - File Preview

    @ViewBuilder
    private var filePreview: some View {
        NavigationStack {
            Group {
                if fileIsText {
                    ScrollView {
                        Text(fileText)
                            .font(.system(.body, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                    }
                } else if let data = fileData,
                          let image = UIImage(data: data),
                          let cgImage = image.cgImage {
                    Image(uiImage: UIImage(cgImage: cgImage))
                        .resizable()
                        .scaledToFit()
                        .padding()
                        .background(Color.black.opacity(0.05))
                } else if let _ = fileData {
                    VStack(spacing: 12) {
                        Image(systemName: "doc")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text("Preview not supported")
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "doc")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text("Preview not supported")
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                }
            }
            .navigationTitle(fileTitle)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { showingFile = false }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if let url = fileDownloadURL {
                        ShareLink(item: url) { Image(systemName: "square.and.arrow.up") }
                    } else if fileIsText {
                        ShareLink(item: fileText) { Image(systemName: "square.and.arrow.up") }
                    }
                }
            }
        }
    }
}

// MARK: - Simple flow layout for recent chips

fileprivate struct FlowLayout<Content: View>: View {
    var spacing: CGFloat = 8
    @ViewBuilder var content: Content

    var body: some View {
        var width: CGFloat = 0
        var height: CGFloat = 0

        return GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                content
                    .fixedSize()
                    .alignmentGuide(.leading) { d in
                        if abs(width - d.width) > geo.size.width {
                            width = 0; height -= d.height + spacing
                        }
                        let result = width
                        if d.width != 0 { width -= d.width + spacing }
                        return result
                    }
                    .alignmentGuide(.top) { _ in
                        let result = height
                        return result
                    }
            }
        }.frame(height: 0) // container expands via its parent VStack/HStack
    }
}
