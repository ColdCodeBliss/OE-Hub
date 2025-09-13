//
//  GitHubBrowserView.swift
//  OE Hub
//
//  Created by Ryan Bliss on 9/13/25.
//
import SwiftUI
import Foundation

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

    /// Fetch a single file's content payload via the Contents API (returns base64-encoded text for text files)
    static func fetchFile(owner: String, repo: String, path: String, ref: String) async throws -> ContentItem {
        var comps = URLComponents(url: base.appending(path: "/repos/\(owner)/\(repo)/contents/\(path)"), resolvingAgainstBaseURL: false)!
        comps.queryItems = [URLQueryItem(name: "ref", value: ref)]
        let (data, resp) = try await URLSession.shared.data(from: comps.url!)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(ContentItem.self, from: data)
    }

    /// Raw download (useful for images/PDFs, or large files)
    static func fetchRaw(url: URL) async throws -> Data {
        let (data, resp) = try await URLSession.shared.data(from: url)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return data
    }
}

// MARK: - Main Browser View

struct GitHubBrowserView: View {
    @Environment(\.dismiss) private var dismiss

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

                        if let err = errorMessage {
                            Text(err).foregroundStyle(.red).font(.footnote)
                                .padding(.horizontal)
                        }

                        Spacer()
                    }
                    .padding(.top, 24)
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
                                Image(systemName: item.type == "dir" ? "folder" : "doc.text")
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
                    .overlay {
                        if isLoading { ProgressView().scaleEffect(1.2) }
                    }
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
            fileDownloadURL = item.download_url.flatMap(URL.init(string:))
            if let enc = file.encoding?.lowercased(), enc == "base64", let b64 = file.content {
                // Attempt to decode text
                if let data = Data(base64Encoded: b64),
                   let text = String(data: data, encoding: .utf8) {
                    fileText = text
                    fileData = nil
                    fileIsText = true
                    showingFile = true
                    return
                }
            }

            // Not text (or failed to decode) → try raw download for images/PDFs
            if let rawURL = fileDownloadURL {
                let data = try await GHService.fetchRaw(url: rawURL)
                fileData = data
                fileIsText = false
                showingFile = true
            } else {
                // Fallback: show minimal info
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

    // MARK: - Parsing

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
                    // Image preview (PNG/JPEG/GIF-first frame)
                    Image(uiImage: UIImage(cgImage: cgImage))
                        .resizable()
                        .scaledToFit()
                        .padding()
                        .background(Color.black.opacity(0.05))
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

