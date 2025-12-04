import SwiftUI
import AVKit
import PDFKit
import Combine

struct FileListView: View {
    @StateObject private var viewModel = FileListViewModel()
    @State private var selectedFolderID: Int?
    @State private var selectedFile: Node?
    
    var body: some View {
        NavigationSplitView(columnVisibility: .constant(.all)) {
            VStack(spacing: 0) {
                if viewModel.isLoadingTree {
                    ProgressView(NSLocalizedString("loading", comment: ""))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let rootNode = viewModel.rootNode {
                    List(selection: $selectedFolderID) {
                        FolderTreeView(
                            node: rootNode,
                            viewModel: viewModel,
                            selectedFolderID: $selectedFolderID,
                            level: 0
                        )
                    }
                    .listStyle(.sidebar)
                }
            }
            .navigationTitle(NSLocalizedString("app_name", comment: ""))
            .navigationSplitViewColumnWidth(min: 200, ideal: 250, max: 350)
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button(action: viewModel.refreshTree) {
                        Label(NSLocalizedString("refresh", comment: ""), systemImage: "arrow.clockwise")
                    }
                }
                ToolbarItem(placement: .automatic) {
                    Button(action: {
                        AppState.shared.logout()
                    }) {
                        Label(NSLocalizedString("logout_button", comment: ""), systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            }
        } detail: {
            if let file = selectedFile {
                MediaPreviewView(node: file, onClose: {
                    selectedFile = nil
                })
            } else {
                FolderContentView(
                    viewModel: viewModel,
                    selectedFolderID: selectedFolderID,
                    onFileSelect: { file in
                        selectedFile = file
                    },
                    onFolderSelect: { folderId in
                        selectedFolderID = folderId
                    }
                )
            }
        }
        .onAppear {
            viewModel.loadRootFolder()
        }
        .onChange(of: selectedFolderID) { newID in
            selectedFile = nil
            if let id = newID {
                viewModel.loadFolder(id: id)
            }
        }
    }
}

struct FolderContentView: View {
    @ObservedObject var viewModel: FileListViewModel
    let selectedFolderID: Int?
    let onFileSelect: (Node) -> Void
    let onFolderSelect: (Int) -> Void
    @State private var showingNewFolderAlert = false
    @State private var newFolderName = ""
    @State private var showingRenameAlert = false
    @State private var renameNode: Node?
    @State private var renameName = ""
    @State private var copiedNode: Node?
    @State private var cutNode: Node?
    
    var body: some View {
        VStack(spacing: 0) {
            let currentFolder = viewModel.getCurrentFolder(id: selectedFolderID)
            HStack {
                Text(currentFolder?.path ?? currentFolder?.name ?? "HaNas")
                    .font(.headline)
                    .foregroundColor(.secondary)
                Spacer()
                Button(action: {
                    newFolderName = ""
                    showingNewFolderAlert = true
                }) {
                    Label(NSLocalizedString("new_folder", comment: ""), systemImage: "folder.badge.plus")
                }
                .buttonStyle(.bordered)
                .disabled(currentFolder == nil)
                Button(action: uploadFile) {
                    Label(NSLocalizedString("upload_file", comment: ""), systemImage: "arrow.up.doc")
                }
                .buttonStyle(.bordered)
                .disabled(currentFolder == nil)
                if supportsCopyAPI, (copiedNode != nil || cutNode != nil) {
                    Button(action: pasteItem) {
                        Label(NSLocalizedString("paste", comment: ""), systemImage: "doc.on.clipboard")
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            Divider()
            if let folder = currentFolder, let children = folder.ko, !children.isEmpty {
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.adaptive(minimum: 120, maximum: 150), spacing: 20)
                    ], spacing: 20) {
                        ForEach(children, id: \.id) { child in
                            FileGridItemView(node: child, viewModel: viewModel)
                                .onTapGesture(count: 2) {
                                    handleDoubleClick(child)
                                }
                                .contextMenu {
                                    if !child.isDir {
                                        Button(NSLocalizedString("preview", comment: "")) {
                                            openPreview(child)
                                        }
                                        Divider()
                                    }
                                    Button(NSLocalizedString("copy", comment: "")) {
                                        copiedNode = child
                                        cutNode = nil
                                    }
                                    .disabled(!supportsCopyAPI)
                                    Button(NSLocalizedString("cut", comment: "")) {
                                        cutNode = child
                                        copiedNode = nil
                                    }
                                    Divider()
                                    Button(NSLocalizedString("rename", comment: "")) {
                                        renameNode = child
                                        renameName = child.name
                                        showingRenameAlert = true
                                    }
                                    if !child.isDir {
                                        Button(NSLocalizedString("export", comment: "")) {
                                            exportFile(child)
                                        }
                                        Divider()
                                        if child.shareToken != nil && !child.shareToken!.isEmpty {
                                            Button(NSLocalizedString("share_copy", comment: "")) {
                                                copyShareLink(child)
                                            }
                                            Button(NSLocalizedString("share_remove", comment: "")) {
                                                removeShare(child)
                                            }
                                        } else {
                                            Button(NSLocalizedString("share_create", comment: "")) {
                                                createShareLink(child)
                                            }
                                        }
                                    }
                                    Divider()
                                    Button(NSLocalizedString("delete", comment: ""), role: .destructive) {
                                        deleteItem(child)
                                    }
                                }
                        }
                    }
                    .padding()
                }
            } else if currentFolder != nil {
                VStack {
                    Image(systemName: "folder")
                        .font(.system(size: 60))
                        .foregroundColor(.secondary)
                    Text(NSLocalizedString("empty_folder", comment: ""))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .alert(NSLocalizedString("new_folder_title", comment: ""), isPresented: $showingNewFolderAlert) {
            TextField(NSLocalizedString("new_folder_placeholder", comment: ""), text: $newFolderName)
            Button(NSLocalizedString("cancel", comment: ""), role: .cancel) { }
            Button(NSLocalizedString("create", comment: "")) {
                createFolder()
            }
            .disabled(newFolderName.isEmpty)
        } message: {
            Text(NSLocalizedString("new_folder_message", comment: ""))
        }
        .alert(NSLocalizedString("rename_title", comment: ""), isPresented: $showingRenameAlert) {
            TextField(NSLocalizedString("rename_placeholder", comment: ""), text: $renameName)
            Button(NSLocalizedString("cancel", comment: ""), role: .cancel) { }
            Button(NSLocalizedString("change", comment: "")) {
                renameItem()
            }
            .disabled(renameName.isEmpty)
        } message: {
            Text(NSLocalizedString("rename_message", comment: ""))
        }
    }

    private var supportsCopyAPI: Bool {
        true
    }

    private func handleDoubleClick(_ node: Node) {
        if node.isDir {
            onFolderSelect(node.id)
        } else {
            openPreview(node)
        }
    }
    
    private func openPreview(_ node: Node) {
        let ext = (node.name as NSString).pathExtension.lowercased()
        let mediaExts = ["jpg", "jpeg", "png", "gif", "webp", "bmp", "mp4", "mov", "m4v", "mp3", "wav", "m4a", "aac", "pdf"]
        
        if mediaExts.contains(ext) {
            onFileSelect(node)
        } else {
            exportFile(node)
        }
    }
    
    private func exportFile(_ node: Node) {
        Task { @MainActor in
            await showSavePanel(for: node)
        }
    }
    
    @MainActor
    private func showSavePanel(for node: Node) async {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = node.name
        panel.canCreateDirectories = true
        if let window = NSApp.keyWindow ?? NSApp.windows.first {
            panel.beginSheetModal(for: window) { response in
                guard response == .OK, let url = panel.url else { return }
                Task {
                    do {
                        let data = try await HaNasAPI.shared.downloadFile(id: node.id)
                        try data.write(to: url)
                    } catch {
                    }
                }
            }
        } else {
            panel.begin { response in
                guard response == .OK, let url = panel.url else { return }
                Task {
                    do {
                        let data = try await HaNasAPI.shared.downloadFile(id: node.id)
                        try data.write(to: url)
                    } catch {
                    }
                }
            }
        }
    }
    
    private func createFolder() {
        guard let parentId = selectedFolderID else { return }
        
        Task {
            do {
                try await HaNasAPI.shared.createFolder(name: newFolderName, oyaId: parentId)
                await MainActor.run {
                    viewModel.loadFolder(id: parentId, forceRefresh: true)
                    viewModel.refreshTree()
                }
            } catch {
            }
        }
    }
    
    private func uploadFile() {
        guard let parentId = selectedFolderID else { return }
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true

        panel.begin { response in
            guard response == .OK else { return }
            Task {
                var uploadCount = 0
                for url in panel.urls {
                    do {
                        guard let data = try? Data(contentsOf: url) else {
                            continue
                        }
                        try await HaNasAPI.shared.uploadFile(filename: url.lastPathComponent, data: data, oyaId: parentId)
                        uploadCount += 1
                    } catch {
                    }
                }
                if uploadCount > 0 {
                    await MainActor.run {
                        viewModel.loadFolder(id: parentId, forceRefresh: true)
                        viewModel.refreshTree()
                    }
                }
            }
        }
    }
    
    private func pasteItem() {
        guard let parentId = selectedFolderID else { return }
        if let node = copiedNode {
            Task {
                do {
                    try await HaNasAPI.shared.copyNode(srcId: node.id, dstId: parentId, overwrite: false)
                    await MainActor.run {
                        viewModel.loadFolder(id: parentId, forceRefresh: true)
                        viewModel.refreshTree()
                        copiedNode = nil
                    }
                } catch {
                }
            }
        } else if let node = cutNode {
            Task {
                do {
                    try await HaNasAPI.shared.moveNode(id: node.id, newOyaId: parentId)
                    await MainActor.run {
                        if let oldParentId = node.oyaId {
                            viewModel.loadFolder(id: oldParentId, forceRefresh: true)
                        }
                        viewModel.loadFolder(id: parentId, forceRefresh: true)
                        viewModel.refreshTree()
                        cutNode = nil
                    }
                } catch {
                }
            }
        }
    }
    
    private func renameItem() {
        guard let node = renameNode else { return }
        
        Task {
            do {
                try await HaNasAPI.shared.renameNode(id: node.id, newName: renameName)
                await MainActor.run {
                    if let parentId = node.oyaId {
                        viewModel.loadFolder(id: parentId, forceRefresh: true)
                    } else if let selectedId = selectedFolderID {
                        viewModel.loadFolder(id: selectedId, forceRefresh: true)
                    }
                    viewModel.refreshTree()
                }
            } catch {
            }
        }
    }
    
    private func deleteItem(_ node: Node) {
        Task {
            do {
                try await HaNasAPI.shared.deleteNode(id: node.id)
                await MainActor.run {
                    if let parentId = node.oyaId {
                        viewModel.loadFolder(id: parentId, forceRefresh: true)
                    } else if let selectedId = selectedFolderID {
                        viewModel.loadFolder(id: selectedId, forceRefresh: true)
                    }
                    viewModel.refreshTree()
                }
            } catch {
            }
        }
    }

    private func createShareLink(_ node: Node) {
        Task {
            do {
                let token = try await HaNasAPI.shared.createShare(nodeId: node.id)
                let shareURL = "\(HaNasAPI.shared.getBaseURL())/s/\(token)"
                
                await MainActor.run {
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString(shareURL, forType: .string)
                    if let parentId = node.oyaId {
                        viewModel.loadFolder(id: parentId, forceRefresh: true)
                    } else if let selectedId = selectedFolderID {
                        viewModel.loadFolder(id: selectedId, forceRefresh: true)
                    }
                }
            } catch {
            }
        }
    }
    
    private func copyShareLink(_ node: Node) {
        guard let token = node.shareToken, !token.isEmpty else { return }
        let shareURL = "\(HaNasAPI.shared.getBaseURL())/s/\(token)"
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(shareURL, forType: .string)
    }
    
    private func removeShare(_ node: Node) {
        Task {
            do {
                try await HaNasAPI.shared.deleteShare(nodeId: node.id)
                await MainActor.run {
                    if let parentId = node.oyaId {
                        viewModel.loadFolder(id: parentId, forceRefresh: true)
                    } else if let selectedId = selectedFolderID {
                        viewModel.loadFolder(id: selectedId, forceRefresh: true)
                    }
                }
            } catch {
            }
        }
    }
}

struct FolderTreeView: View {
    let node: Node
    @ObservedObject var viewModel: FileListViewModel
    @Binding var selectedFolderID: Int?
    let level: Int
    @State private var isExpanded: Bool = true
    
    var body: some View {
        if node.isDir {
            DisclosureGroup(isExpanded: $isExpanded) {
                if let children = node.ko?.filter({ $0.isDir }) {
                    ForEach(children, id: \.id) { child in
                        FolderTreeView(
                            node: child,
                            viewModel: viewModel,
                            selectedFolderID: $selectedFolderID,
                            level: level + 1
                        )
                    }
                }
            } label: {
                Button(action: {
                    selectedFolderID = node.id
                }) {
                    HStack {
                        Image(systemName: "folder.fill")
                            .foregroundColor(.blue)
                        Text(node.name)
                            .foregroundColor(.primary)
                    }
                }
                .buttonStyle(.plain)
            }
            .tag(node.id as Int?)
        }
    }
}

struct FileGridItemView: View {
    let node: Node
    @ObservedObject var viewModel: FileListViewModel
    @State private var thumbnail: NSImage?

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(NSColor.controlBackgroundColor))
                    .frame(width: 100, height: 100)
                
                Group {
                    if let thumbnail = thumbnail {
                        Image(nsImage: thumbnail)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 90, height: 90)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    } else if node.isDir {
                        Image(systemName: "folder.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.blue)
                    } else {
                        Image(systemName: fileIcon(for: node.name))
                            .font(.system(size: 50))
                            .foregroundColor(fileColor(for: node.name))
                    }
                }
            }
            Text(node.name)
                .font(.caption)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(width: 100)
            
            if !node.isDir, let size = node.size {
                Text(formatFileSize(size))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .frame(width: 120)
        .onAppear {
            if shouldLoadThumbnail(for: node.name) && !node.isDir {
                loadThumbnail()
            }
        }
    }
    
    private func loadThumbnail() {
        Task {
            do {
                let data = try await HaNasAPI.shared.getThumbnail(id: node.id)
                if let image = NSImage(data: data) {
                    await MainActor.run {
                        thumbnail = image
                    }
                }
            } catch {}
            }
        }
    }
    
    private func shouldLoadThumbnail(for filename: String) -> Bool {
        let ext = (filename as NSString).pathExtension.lowercased()
        let imageExts = ["jpg", "jpeg", "png", "gif", "webp", "bmp"]
        let videoExts = ["mp4", "webm", "ogg", "mov", "mkv", "avi"]
        return imageExts.contains(ext) || videoExts.contains(ext)
    }
    
    private func fileIcon(for filename: String) -> String {
        let ext = (filename as NSString).pathExtension.lowercased()
        switch ext {
        case "jpg", "jpeg", "png", "gif", "webp", "bmp":
            return "photo.fill"
        case "mp4", "webm", "ogg", "mov", "mkv", "avi":
            return "film.fill"
        case "mp3", "wav", "aac", "flac", "m4a":
            return "music.note"
        case "pdf":
            return "doc.fill"
        case "zip", "rar", "7z", "tar", "gz":
            return "archivebox.fill"
        case "txt", "md":
            return "doc.text.fill"
        default:
            return "doc.fill"
        }
    }
    
    private func fileColor(for filename: String) -> Color {
        let ext = (filename as NSString).pathExtension.lowercased()
        switch ext {
        case "jpg", "jpeg", "png", "gif", "webp", "bmp":
            return .green
        case "mp4", "webm", "ogg", "mov", "mkv", "avi":
            return .purple
        case "mp3", "wav", "aac", "flac", "m4a":
            return .pink
        case "pdf":
            return .red
        case "zip", "rar", "7z", "tar", "gz":
            return .orange
        default:
            return .gray
        }
    }
    
    private func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

struct MediaPreviewView: View {
    let node: Node
    let onClose: () -> Void
    @State private var mediaData: Data?
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: onClose) {
                    HStack {
                        Image(systemName: "chevron.left")
                        Text(NSLocalizedString("back", comment: ""))
                    }
                }
                .buttonStyle(.plain)
                Spacer()
                Text(node.name)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                Button(NSLocalizedString("export", comment: "")) {
                    exportFile()
                }
                .buttonStyle(.bordered)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            Divider()
            if isLoading {
                ProgressView(NSLocalizedString("loading", comment: ""))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = errorMessage {
                VStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                    Text(error)
                        .foregroundColor(.secondary)
                    Button(NSLocalizedString("retry", comment: "")) {
                        loadMedia()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let data = mediaData {
                mediaContent(data: data)
            }
        }
        .onAppear {
            loadMedia()
        }
    }
    
    @ViewBuilder
    private func mediaContent(data: Data) -> some View {
        let ext = (node.name as NSString).pathExtension.lowercased()
        if ["jpg", "jpeg", "png", "gif", "webp", "bmp"].contains(ext) {
            if let image = NSImage(data: data) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        } else if ["mp4", "mov", "m4v"].contains(ext) {
            if let url = saveTemporaryFile(data: data, filename: node.name) {
                AVPlayerViewWrapper(url: url)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        } else if ["mp3", "wav", "m4a", "aac"].contains(ext) {
            VStack(spacing: 20) {
                Spacer()
                Image(systemName: "music.note")
                    .font(.system(size: 100))
                    .foregroundColor(.blue)
                Text(node.name)
                    .font(.title)
                if let size = node.size {
                    Text(formatFileSize(size))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                if let url = saveTemporaryFile(data: data, filename: node.name) {
                    VideoPlayer(player: AVPlayer(url: url))
                        .frame(height: 120)
                        .padding()
                }
            }
        } else if ext == "pdf" {
            if let url = saveTemporaryFile(data: data, filename: node.name) {
                PDFViewWrapper(url: url)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
    
    private func loadMedia() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let data = try await HaNasAPI.shared.downloadFile(id: node.id)
                await MainActor.run {
                    mediaData = data
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = String(format: "%@: %@", 
                        NSLocalizedString("cannot_load_file", comment: ""), 
                        error.localizedDescription)
                    isLoading = false
                }
            }
        }
    }
    
    private func exportFile() {
        guard let data = mediaData else { return }
        Task { @MainActor in
            await showSavePanel(with: data)
        }
    }
    
    @MainActor
    private func showSavePanel(with data: Data) async {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = node.name
        panel.canCreateDirectories = true
        
        if let window = NSApp.keyWindow ?? NSApp.windows.first {
            panel.beginSheetModal(for: window) { response in
                guard response == .OK, let url = panel.url else { return }
                Task {
                    do {
                        try data.write(to: url)
                    } catch {
                    }
                }
            }
        } else {
            panel.begin { response in
                guard response == .OK, let url = panel.url else { return }
                Task {
                    do {
                        try data.write(to: url)
                    } catch {
                    }
                }
            }
        }
    }
    
    private func saveTemporaryFile(data: Data, filename: String) -> URL? {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(filename)
        try? data.write(to: fileURL)
        return fileURL
    }
    
    private func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

class FileListViewModel: ObservableObject {
    @Published var rootNode: Node?
    @Published var loadedFolders: [Int: Node] = [:]
    @Published var isLoadingTree = false
    @Published var errorMessage: String?
    
    func loadRootFolder() {
        isLoadingTree = true
        errorMessage = nil
        Task {
            do {
                let node = try await HaNasAPI.shared.getNode()
                self.rootNode = node
                self.loadedFolders[node.id] = node
                self.isLoadingTree = false
            } catch {
                self.errorMessage = String(format: NSLocalizedString("cannot_load_data_with_error", comment: ""), error.localizedDescription)
                self.isLoadingTree = false
            }
        }
    }
    
    func loadFolder(id: Int, forceRefresh: Bool = false) {
        if !forceRefresh && loadedFolders[id] != nil { return }
        
        Task {
            do {
                let node = try await HaNasAPI.shared.getNode(id: id)
                await MainActor.run {
                    self.loadedFolders[id] = node
                    updateNodeInTree(node)
                }
            } catch {
            }
        }
    }
    
    func getCurrentFolder(id: Int?) -> Node? {
        guard let id = id else { return rootNode }
        return loadedFolders[id] ?? findNodeInTree(rootNode, id: id)
    }
    
    func refreshTree() {
        loadedFolders.removeAll()
        loadRootFolder()
    }
    
    private func updateNodeInTree(_ newNode: Node) {
        if rootNode?.id == newNode.id {
            rootNode = newNode
        } else {
            rootNode = updateNodeRecursive(rootNode, newNode: newNode)
        }
    }
    
    private func updateNodeRecursive(_ node: Node?, newNode: Node) -> Node? {
        guard let node = node else { return nil }
        if node.id == newNode.id {
            return newNode
        }
        if let children = node.ko {
            let updatedChildren: [Node] = children.map { child in
                if child.id == newNode.id {
                    return newNode
                } else if let replaced = updateNodeRecursive(child, newNode: newNode) {
                    return replaced
                } else {
                    return child
                }
            }
            return Node(
                id: node.id,
                userId: node.userId,
                name: node.name,
                isDir: node.isDir,
                oyaId: node.oyaId,
                updatedAt: node.updatedAt,
                size: node.size,
                path: node.path,
                shareToken: node.shareToken,
                ko: updatedChildren
            )
        }
        return node
    }
    
    private func findNodeInTree(_ node: Node?, id: Int) -> Node? {
        guard let node = node else { return nil }
        if node.id == id { return node }
        if let children = node.ko {
            for child in children {
                if let found = findNodeInTree(child, id: id) {
                    return found
                }
            }
        }
        return nil
    }
}

struct AVPlayerViewWrapper: NSViewRepresentable {
    let url: URL
    
    func makeNSView(context: Context) -> AVPlayerView {
        let playerView = AVPlayerView()
        playerView.player = AVPlayer(url: url)
        playerView.controlsStyle = .floating
        playerView.showsFullScreenToggleButton = true
        playerView.allowsPictureInPicturePlayback = true
        return playerView
    }
    
    func updateNSView(_ nsView: AVPlayerView, context: Context) {}
}

struct PDFViewWrapper: NSViewRepresentable {
    let url: URL
    
    func makeNSView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.document = PDFDocument(url: url)
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        return pdfView
    }
    
    func updateNSView(_ nsView: PDFView, context: Context) {}
}
