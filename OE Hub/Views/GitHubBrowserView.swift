//
//  GitHubBrowserView.swift
//  OE Hub
//
//  Created by Ryan Bliss on 9/13/25.
//
import SwiftUI
import Foundation
import PDFKit   // ← for inline PDF preview

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

// Recent repo persistence (UserDefaults via AppStorage)
fileprivate struct SavedRepo: Codable, Equatable, Identifiable {
    var url: String
    var savedAt: Date
    var id: String { url }
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
    @State private var fileIsPDF: Bool = false
    @State private var fileDownloadURL: URL? = nil
    @State private var fileExt: String = ""

    // Recents (persisted)
    @AppStorage("gh_recent_repos") private var recentJSON: String = "[]"
    @State private var recents: [SavedRepo] = []

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
                            Text(err)
                                .foregroundStyle(.red)
                                .font(.footnote)
                                .padding(.horizontal)
                        }

                        // Recent repos
                        if !recents.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Recent")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal)

                                ForEach(recents.sorted(by: { $0.savedAt > $1.savedAt })) { r in
                                    Button {
                                        repoURLString = r.url
                                        Task { await loadFromURL() }
                                    } label: {
                                        HStack(spacing: 10) {
                                            Image(systemName: "clock")
                                                .foregroundStyle(.secondary)
                                            Text(prettyName(for: r.url))
                                                .lineLimit(1)
                                            Spacer()
                                        }
                                        .padding(.vertical, 8)
                                        .padding(.horizontal, 12)
                                        .background(
                                            RoundedRectangle(cornerRadius: 10)
                                                .fill(Color(.secondarySystemBackground))
                                        )
                                    }
                                    .buttonStyle(.plain)
                                    .padding(.horizontal)
                                }
                            }
                            .padding(.top, 8)
                        }

                        Spacer()
                    }
                    .padding(.top, 24)
                    .onAppear {
                        recents = loadRecents()
                    }
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
        let raw = repoURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let parsed = parseRepoURL(raw) else {
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

            // Save (or bump) in recents after a successful load
            saveRecent(url: raw)
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

        isLoading = true
        defer { isLoading = false }

        let ext = (item.name as NSString).pathExtension.lowercased()
        fileExt = ext

        do {
            // Fetch full content via the API (for text/base64)
            let file = try await GHService.fetchFile(owner: r.owner, repo: r.name, path: item.path, ref: branch)
            fileTitle = item.name
            fileDownloadURL = file.download_url.flatMap(URL.init(string:))

            // 1) Try base64 text path first (GitHub returns base64 for text files)
            if let enc = file.encoding?.lowercased(), enc == "base64", let b64 = file.content {
                if let data = Data(base64Encoded: b64) {
                    if isTextExtension(ext) {
                        fileText = String(decoding: data, as: UTF8.self)
                        fileIsText = true
                        fileIsPDF = false
                        fileData = nil
                        showingFile = true
                        return
                    }
                    if isImageExtension(ext), let img = UIImage(data: data), img.cgImage != nil {
                        fileData = data
                        fileIsText = false
                        fileIsPDF = false
                        showingFile = true
                        return
                    }
                    if ext == "pdf" {
                        fileData = data
                        fileIsText = false
                        fileIsPDF = true
                        showingFile = true
                        return
                    }
                    // If unknown but decodes as UTF-8 reasonably, show as text
                    if let str = String(data: data, encoding: .utf8), looksLikeText(str) {
                        fileText = str
                        fileIsText = true
                        fileIsPDF = false
                        fileData = nil
                        showingFile = true
                        return
                    }
                }
            }

            // 2) Fallback to raw download (images, PDFs, or when base64 path wasn't text)
            if let rawURL = fileDownloadURL {
                let data = try await GHService.fetchRaw(url: rawURL)
                if isImageExtension(ext), let img = UIImage(data: data), img.cgImage != nil {
                    fileData = data
                    fileIsText = false
                    fileIsPDF = false
                    showingFile = true
                    return
                }
                if ext == "pdf" {
                    fileData = data
                    fileIsText = false
                    fileIsPDF = true
                    showingFile = true
                    return
                }
                // Try as UTF-8 text if extension is text-like or payload seems textual
                if isTextExtension(ext) {
                    fileText = String(decoding: data, as: UTF8.self)
                    fileIsText = true
                    fileIsPDF = false
                    fileData = nil
                    showingFile = true
                    return
                }
                if let str = String(data: data, encoding: .utf8), looksLikeText(str) {
                    fileText = str
                    fileIsText = true
                    fileIsPDF = false
                    fileData = nil
                    showingFile = true
                    return
                }
                // Otherwise: unsupported preview, but we still open the sheet so Share is available
                fileData = data
                fileIsText = false
                fileIsPDF = false
                showingFile = true
            } else {
                // No raw URL—fallback minimal info
                fileText = "(Unable to display file. Try 'Share' → 'Open in…')"
                fileData = nil
                fileIsText = true
                fileIsPDF = false
                showingFile = true
            }
        } catch {
            fileTitle = item.name
            fileText = "Failed to load file."
            fileData = nil
            fileIsText = true
            fileIsPDF = false
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

    // MARK: - Recents (persist last 3)

    private func loadRecents() -> [SavedRepo] {
        guard let data = recentJSON.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([SavedRepo].self, from: data)) ?? []
    }

    private func persistRecents(_ arr: [SavedRepo]) {
        guard let data = try? JSONEncoder().encode(arr),
              let str = String(data: data, encoding: .utf8) else { return }
        recentJSON = str
    }

    private func saveRecent(url raw: String) {
        let norm = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        var arr = loadRecents()
        if let idx = arr.firstIndex(where: { $0.url == norm }) {
            arr[idx].savedAt = Date()
        } else {
            arr.append(SavedRepo(url: norm, savedAt: Date()))
        }
        // Keep newest first; limit to 5
        arr.sort { $0.savedAt > $1.savedAt }
        if arr.count > 5 { arr = Array(arr.prefix(5)) }
        persistRecents(arr)
        recents = arr
    }

    private func prettyName(for urlStr: String) -> String {
        if let r = parseRepoURL(urlStr) {
            return "\(r.owner)/\(r.name)"
        }
        return urlStr
    }

    // MARK: - File Preview

    @ViewBuilder
    private var filePreview: some View {
        NavigationStack {
            Group {
                if fileIsText {
                    // Markdown: render nicely when possible
                    if fileExt == "md", let attributed = try? AttributedString(markdown: fileText) {
                        ScrollView {
                            Text(attributed)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                        }
                    } else {
                        ScrollView {
                            Text(fileText)
                                .font(.system(.body, design: .monospaced))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                        }
                    }
                } else if fileIsPDF, let data = fileData {
                    PDFKitView(data: data) // inline PDF viewer
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
                    } else if let data = fileData {
                        // Share raw data via temporary file
                        let tmpURL = writeTempFile(named: fileTitle, data: data, ext: fileExt)
                        if let tmpURL { ShareLink(item: tmpURL) { Image(systemName: "square.and.arrow.up") } }
                    }
                }
            }
        }
    }

    // MARK: - Helpers (preview type heuristics)

    private func isTextExtension(_ ext: String) -> Bool {
        let textExts: Set<String> = [
            "txt","md","markdown","json","yml","yaml","xml","csv",
            "ini","cfg","conf","log",
            "html","htm","css","js","ts",
            "swift","m","mm","h","hpp","c","cpp","kt","java","py","rb","sh","bat","ps1","sql","rs","go","php"
        ]
        return textExts.contains(ext)
    }

    private func isImageExtension(_ ext: String) -> Bool {
        let imgExts: Set<String> = ["png","jpg","jpeg","gif","bmp","tiff","tif","heic","heif","webp"]
        return imgExts.contains(ext)
    }

    private func looksLikeText(_ s: String) -> Bool {
        // crude heuristic—if it has lots of NULs or very low ASCII, probably binary
        // Here we just say “if it’s decodable and not empty, go with it”
        return !s.isEmpty
    }

    private func writeTempFile(named name: String, data: Data, ext: String) -> URL? {
        let safeName = name.isEmpty ? "file" : name
        let filename = (safeName as NSString).deletingPathExtension + "." + (ext.isEmpty ? "bin" : ext)
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(filename)
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }
}

// MARK: - PDFKit SwiftUI wrapper

fileprivate struct PDFKitView: UIViewRepresentable {
    let data: Data
    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.document = PDFDocument(data: data)
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        return view
    }
    func updateUIView(_ uiView: PDFView, context: Context) { }
}
