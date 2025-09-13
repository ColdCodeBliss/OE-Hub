//
//  GitHubBrowserView.swift
//  OE Hub
//
//  Created by Ryan Bliss on 9/13/25.
//

import SwiftUI
import Foundation
import UniformTypeIdentifiers
import PDFKit
import QuickLook

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
    let html_url: String?
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

    /// Fetch a single file's content payload via the Contents API (returns base64-encoded text for many text files)
    static func fetchFile(owner: String, repo: String, path: String, ref: String) async throws -> ContentItem {
        var comps = URLComponents(url: base.appending(path: "/repos/\(owner)/\(repo)/contents/\(path)"), resolvingAgainstBaseURL: false)!
        comps.queryItems = [URLQueryItem(name: "ref", value: ref)]
        let (data, resp) = try await URLSession.shared.data(from: comps.url!)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(ContentItem.self, from: data)
    }

    /// Raw download (useful for images/PDFs/anything else)
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

    // File preview state
    @State private var showingFile: Bool = false
    @State private var fileTitle: String = ""
    @State private var fileText: String = ""
    @State private var fileData: Data? = nil
    @State private var fileIsText: Bool = true
    @State private var fileIsPDF: Bool = false
    @State private var fileDownloadURL: URL? = nil
    @State private var quickLookURL: URL? = nil

    var body: some View {
        NavigationStack {
            Group {
                if repo == nil {
                    urlEntryView
                } else {
                    directoryView
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
                        } label: { Image(systemName: "arrow.clockwise") }
                        .disabled(isLoading)
                    }
                }
            }
            .sheet(isPresented: $showingFile) { filePreview }
        }
    }

    // MARK: - Subviews

    private var urlEntryView: some View {
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
    }

    private var directoryView: some View {
        List {
            if !currentPath.isEmpty {
                Section {
                    Button { goUpOne() } label: {
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
                .onTapGesture { Task { await handleTap(item) } }
            }
        }
        .overlay { if isLoading { ProgressView().scaleEffect(1.2) } }
    }

    private var repoTitle: String { repo?.name ?? "GitHub" }

    // MARK: - Actions

    private func loadFromURL() async {
        errorMessage = nil
        guard let parsed = parseRepoURL(repoURLString) else {
            errorMessage = "Unable to parse owner/repo from URL."
            return
        }
        repo = parsed
        isLoading = true
        defer { isLoading = false }
        do {
            let defaultBranch = try await GHService.fetchDefaultBranch(owner: parsed.owner, repo: parsed.name)
            branch = parsed.branch ?? defaultBranch
            currentPath = parsed.initialPath ?? ""
            items = try await GHService.listContents(owner: parsed.owner, repo: parsed.name, path: currentPath.isEmpty ? nil : currentPath, ref: branch)
        } catch {
            errorMessage = "Failed to load repository. Please check the URL and try again."
            repo = nil
        }
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

        // Dir navigation
        if item.type == "dir" {
            currentPath = item.path
            await reloadCurrentFolder()
            return
        }

        // Reset preview state
        fileTitle = item.name
        fileText = ""
        fileData = nil
        fileIsText = true
        fileIsPDF = false
        quickLookURL = nil
        fileDownloadURL = nil

        isLoading = true
        defer { isLoading = false }

        do {
            // Fetch full metadata/content (some list items omit fields)
            let file = try await GHService.fetchFile(owner: r.owner, repo: r.name, path: item.path, ref: branch)
            fileDownloadURL = (file.download_url ?? item.download_url).flatMap(URL.init(string:))

            // 1) Try base64 text from API
            if let enc = file.encoding?.lowercased(), enc == "base64", let b64 = file.content, let data = Data(base64Encoded: b64) {
                if let text = String(data: data, encoding: .utf8) {
                    fileText = text
                    fileIsText = true
                    showingFile = true
                    return
                }
            }

            // 2) Otherwise, raw download
            guard let rawURL = fileDownloadURL else {
                // No raw URL — show what we can
                fileText = "(Unable to display file. Try opening on GitHub.)"
                fileIsText = true
                showingFile = true
                return
            }

            let data = try await GHService.fetchRaw(url: rawURL)

            // Detect type via extension
            let ext = (item.name as NSString).pathExtension
            let type = UTType(filenameExtension: ext.lowercased())

            if type?.conforms(to: .pdf) == true || data.starts(with: Data("%PDF".utf8)) {
                fileData = data
                fileIsText = false
                fileIsPDF = true
                showingFile = true
                return
            }

            if type?.conforms(to: .image) == true, UIImage(data: data) != nil {
                fileData = data
                fileIsText = false
                fileIsPDF = false
                showingFile = true
                return
            }

            if type?.conforms(to: .text) == true, let text = String(data: data, encoding: .utf8) {
                fileText = text
                fileIsText = true
                showingFile = true
                return
            }

            // 3) Fallback: Quick Look any other file types
            let tmpURL = try writeTempFile(named: item.name, data: data)
            quickLookURL = tmpURL
            fileIsText = false
            fileIsPDF = false
            showingFile = true

        } catch {
            fileText = "Failed to load file."
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
                } else if fileIsPDF, let data = fileData {
                    PDFKitView(data: data)
                        .background(Color.black.opacity(0.05))
                } else if let data = fileData, let image = UIImage(data: data), let cgImage = image.cgImage {
                    Image(uiImage: UIImage(cgImage: cgImage))
                        .resizable()
                        .scaledToFit()
                        .padding()
                        .background(Color.black.opacity(0.05))
                } else if let url = quickLookURL {
                    QuickLookPreview(url: url)
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
                    // Share text, file URL, or raw URL
                    if fileIsText {
                        ShareLink(item: fileText) { Image(systemName: "square.and.arrow.up") }
                    } else if let url = quickLookURL {
                        ShareLink(item: url) { Image(systemName: "square.and.arrow.up") }
                    } else if let url = fileDownloadURL {
                        ShareLink(item: url) { Image(systemName: "square.and.arrow.up") }
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func writeTempFile(named name: String, data: Data) throws -> URL {
        let tmpDir = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let url = tmpDir.appendingPathComponent(name)
        try? FileManager.default.removeItem(at: url)
        try data.write(to: url, options: .atomic)
        return url
    }
}

// MARK: - PDF & QuickLook bridges

private struct PDFKitView: UIViewRepresentable {
    let data: Data
    func makeUIView(context: Context) -> PDFView {
        let v = PDFView()
        v.autoScales = true
        v.displayMode = .singlePageContinuous
        v.document = PDFDocument(data: data)
        return v
    }
    func updateUIView(_ uiView: PDFView, context: Context) {}
}

private struct QuickLookPreview: UIViewControllerRepresentable {
    let url: URL
    func makeCoordinator() -> Coordinator { Coordinator(url: url) }

    func makeUIViewController(context: Context) -> QLPreviewController {
        let c = QLPreviewController()
        c.dataSource = context.coordinator
        return c
    }
    func updateUIViewController(_ uiViewController: QLPreviewController, context: Context) {}

    class Coordinator: NSObject, QLPreviewControllerDataSource {
        let url: URL
        init(url: URL) { self.url = url }
        func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }
        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            url as NSURL
        }
    }
}
