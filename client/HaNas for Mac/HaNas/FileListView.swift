import SwiftUI
import AVKit
import PDFKit
import Combine
import AVFoundation

struct FileListView: View {
    @StateObject private var viewModel = FileListViewModel()
    @State private var selectedFolderID: Int?
    @State private var selectedFile: Node?
    @State private var showingAccountInfo = false
    
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
                    Button(action: {
                        viewModel.refreshTree(currentFolderID: selectedFolderID)
                    }) {
                        Label(NSLocalizedString("refresh", comment: ""), systemImage: "arrow.clockwise")
                    }
                }
                ToolbarItem(placement: .automatic) {
                    Button(action: {
                        showingAccountInfo = true
                    }) {
                        Label(NSLocalizedString("account_info", comment: "Account Info"), systemImage: "person.circle")
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
        .overlay(
            UploadProgressOverlay()
        )
        .sheet(isPresented: $showingAccountInfo) {
            AccountInfoModal()
                .environmentObject(AppState.shared)
        }
        .onAppear {
            viewModel.loadRootFolder()
        }
        .onChange(of: viewModel.rootNode) { newRoot in
            if selectedFolderID == nil, let root = newRoot {
                selectedFolderID = root.id
            }
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
    @State private var copiedNodes: Set<Node>? = nil
    @State private var cutNodes: Set<Node>? = nil
    @State private var showingDuplicateAlert = false
    @State private var duplicateAlertMessage = ""
    @State private var showingOverwriteAlert = false
    @State private var overwriteAction: (() -> Void)?
    @State private var selectedFiles: Set<Node> = []
    @State private var selectionMode: Bool = false
    @State private var showingDeleteConfirm = false
    @State private var deleteNodeToConfirm: Node?
    @State private var showingDeleteMultipleConfirm = false
    @State private var filesToDelete: Set<Node> = []
    
    var body: some View {
        VStack(spacing: 0) {
            let currentFolder = viewModel.getCurrentFolder(id: selectedFolderID)
            HStack {
                Text(currentFolder?.path ?? currentFolder?.name ?? "HaNas")
                    .font(.headline)
                    .foregroundColor(.secondary)
                Spacer()
                if selectionMode {
                    Button(action: { selectionMode = false; selectedFiles.removeAll() }) {
                        Label(NSLocalizedString("cancel", comment: ""), systemImage: "xmark.circle")
                    }
                    .buttonStyle(.bordered)
                    .tint(.gray)
                    if !selectedFiles.isEmpty {
                        Button(action: copySelectedFiles) {
                            Label(NSLocalizedString("copy", comment: ""), systemImage: "doc.on.doc")
                        }
                        .buttonStyle(.bordered)
                        Button(action: cutSelectedFiles) {
                            Label(NSLocalizedString("cut", comment: ""), systemImage: "scissors")
                        }
                        .buttonStyle(.bordered)
                        Button(action: deleteSelectedFiles) {
                            Label(NSLocalizedString("delete", comment: ""), systemImage: "trash")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                    }
                } else {
                    Button(action: { selectionMode = true }) {
                        Label(NSLocalizedString("select_mode", comment: "선택"), systemImage: "checkmark.circle")
                    }
                    .buttonStyle(.bordered)
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
                    if supportsCopyAPI, ((copiedNodes != nil && !(copiedNodes?.isEmpty ?? true)) || (cutNodes != nil && !(cutNodes?.isEmpty ?? true))) {
                        Button(action: pasteItem) {
                            Label(NSLocalizedString("paste", comment: ""), systemImage: "doc.on.clipboard")
                        }
                        .buttonStyle(.borderedProminent)
                    }
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
                            FileGridItemView(node: child, viewModel: viewModel, isSelected: selectedFiles.contains(child))
                                .onTapGesture {
                                    if selectionMode {
                                        if selectedFiles.contains(child) {
                                            selectedFiles.remove(child)
                                        } else {
                                            selectedFiles.insert(child)
                                        }
                                    }
                                }
                                .onTapGesture(count: 2) {
                                    if !selectionMode {
                                        handleDoubleClick(child)
                                    }
                                }
                                .contextMenu {
                                    if !child.isDir {
                                        Button(NSLocalizedString("preview", comment: "")) {
                                            openPreview(child)
                                        }
                                        Divider()
                                    }
                                    Button(NSLocalizedString("copy", comment: "")) {
                                        copiedNodes = [child]
                                        cutNodes = nil
                                    }
                                    .disabled(!supportsCopyAPI)
                                    Button(NSLocalizedString("cut", comment: "")) {
                                        cutNodes = [child]
                                        copiedNodes = nil
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
                .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                    handleDrop(providers: providers)
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
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            handleDrop(providers: providers)
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
        .alert(NSLocalizedString("error", comment: ""), isPresented: $showingDuplicateAlert) {
            Button(NSLocalizedString("ok", comment: ""), role: .cancel) { }
        } message: {
            Text(duplicateAlertMessage)
        }
        .alert(NSLocalizedString("overwrite_confirm_title", comment: ""), isPresented: $showingOverwriteAlert) {
            Button(NSLocalizedString("cancel", comment: ""), role: .cancel) { }
            Button(NSLocalizedString("overwrite", comment: ""), role: .destructive) {
                overwriteAction?()
            }
        } message: {
            Text(NSLocalizedString("overwrite_confirm_message", comment: ""))
        }
        .alert(NSLocalizedString("delete_confirm_title", comment: "Delete this item?"), isPresented: $showingDeleteConfirm, presenting: deleteNodeToConfirm) { node in
            Button(NSLocalizedString("cancel", comment: ""), role: .cancel) {
                deleteNodeToConfirm = nil
            }
            Button(NSLocalizedString("delete", comment: ""), role: .destructive, action: confirmDelete)
        } message: { node in
            Text(node.name)
        }
        .alert(NSLocalizedString("delete_multiple_confirm_title", comment: "Delete selected items?"), isPresented: $showingDeleteMultipleConfirm) {
            Button(NSLocalizedString("cancel", comment: ""), role: .cancel) {
                filesToDelete.removeAll()
            }
            Button(NSLocalizedString("delete", comment: ""), role: .destructive, action: confirmDeleteMultiple)
        } message: {
            Text("\(filesToDelete.count) items")
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
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.begin { response in
            guard response == .OK else { return }
            uploadFiles(urls: panel.urls, parentId: parentId)
        }
    }
    
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let parentId = selectedFolderID else { return false }
        
        Task {
            var fileURLs: [URL] = []
            for provider in providers {
                if provider.hasItemConformingToTypeIdentifier("public.file-url") {
                    do {
                        let data = try await provider.loadItem(forTypeIdentifier: "public.file-url", options: nil)
                        if let url = data as? URL {
                            fileURLs.append(url)
                        } else if let urlData = data as? Data, let urlString = String(data: urlData, encoding: .utf8) {
                            if let url = URL(string: urlString) {
                                fileURLs.append(url)
                            }
                        }
                    } catch {}
                }
            }
            if !fileURLs.isEmpty {
                await MainActor.run {
                    uploadFiles(urls: fileURLs, parentId: parentId)
                }
            }
        }
        return true
    }
    
    private func uploadFiles(urls: [URL], parentId: Int) {
        Task {
            for url in urls {
                var isDirectory: ObjCBool = false
                FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
                
                if isDirectory.boolValue {
                    await uploadDirectory(url: url, parentId: parentId)
                } else {
                    await uploadSingleFile(url: url, parentId: parentId)
                }
            }
            await MainActor.run {
                viewModel.loadFolder(id: parentId, forceRefresh: true)
                viewModel.refreshTree()
            }
        }
    }
    
    private func uploadDirectory(url: URL, parentId: Int) async {
        let folderName = url.lastPathComponent  
        let currentFolder = await MainActor.run { viewModel.getCurrentFolder(id: selectedFolderID) }
        let existingNames = currentFolder?.ko?.map { $0.name } ?? []
        let isDuplicate = existingNames.contains(folderName)
        if isDuplicate {
            let shouldOverwrite = await MainActor.run {
                let alert = NSAlert()
                alert.messageText = NSLocalizedString("overwrite_confirm_title", comment: "")
                alert.informativeText = String(format: NSLocalizedString("folder_exists_overwrite", comment: "A folder named '%@' already exists. Continue?"), folderName)
                alert.addButton(withTitle: NSLocalizedString("continue", comment: "Continue"))
                alert.addButton(withTitle: NSLocalizedString("cancel", comment: ""))
                alert.alertStyle = .warning
                return alert.runModal() == .alertFirstButtonReturn
            }
            if !shouldOverwrite {
                return
            }
        }
        do {
            let response = try await HaNasAPI.shared.createFolder(name: folderName, oyaId: parentId)
            guard let newFolderId = response.nodeId else { return }
            let fileManager = FileManager.default
            if let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) {
                var directoriesToCreate: [(URL, Int)] = []
                var filesToUpload: [(URL, Int)] = []
                for case let fileURL as URL in enumerator {
                    let resourceValues = try? fileURL.resourceValues(forKeys: [.isDirectoryKey])
                    let isDir = resourceValues?.isDirectory ?? false
                    let relativePath = fileURL.path.replacingOccurrences(of: url.path + "/", with: "")
                    
                    if isDir {
                        directoriesToCreate.append((fileURL, newFolderId))
                    } else {
                        filesToUpload.append((fileURL, newFolderId))
                    }
                }
                var folderMap: [String: Int] = [url.path: newFolderId]
                for (dirURL, _) in directoriesToCreate {
                    let parentPath = dirURL.deletingLastPathComponent().path
                    if let parentFolderId = folderMap[parentPath] {
                        do {
                            let response = try await HaNasAPI.shared.createFolder(name: dirURL.lastPathComponent, oyaId: parentFolderId)
                            if let createdId = response.nodeId {
                                folderMap[dirURL.path] = createdId
                            }
                        } catch {}
                    }
                }
                for (fileURL, _) in filesToUpload {
                    let parentPath = fileURL.deletingLastPathComponent().path
                    if let targetParentId = folderMap[parentPath] {
                        await uploadSingleFile(url: fileURL, parentId: targetParentId)
                    }
                }
            }
        } catch {
            await MainActor.run {
                let uploadId = UploadManager.shared.addTask(filename: folderName)
                UploadManager.shared.failTask(uploadId: uploadId, error: error.localizedDescription)
            }
        }
    }
    
    private func uploadSingleFile(url: URL, parentId: Int) async {
        let filename = url.lastPathComponent
        let currentFolder = await MainActor.run { viewModel.getCurrentFolder(id: selectedFolderID) }
        let existingNames = currentFolder?.ko?.map { $0.name } ?? []
        let isDuplicate = existingNames.contains(filename)
        if isDuplicate {
            let shouldOverwrite = await MainActor.run {
                let alert = NSAlert()
                alert.messageText = NSLocalizedString("overwrite_confirm_title", comment: "")
                alert.informativeText = String(format: NSLocalizedString("file_exists_overwrite", comment: ""), filename)
                alert.addButton(withTitle: NSLocalizedString("overwrite", comment: ""))
                alert.addButton(withTitle: NSLocalizedString("cancel", comment: ""))
                alert.alertStyle = .warning
                return alert.runModal() == .alertFirstButtonReturn
            }
            if !shouldOverwrite {
                return
            }
        }
        let uploadId = await MainActor.run {
            UploadManager.shared.addTask(filename: filename)
        }
        do {
            try await HaNasAPI.shared.uploadFileMultipart(
                filename: filename,
                fileURL: url,
                oyaId: parentId,
                uploadId: uploadId,
                progressCallback: { progress in
                    Task { @MainActor in
                        UploadManager.shared.updateProgress(uploadId: uploadId, progress: progress)
                    }
                }
            )
            await MainActor.run {
                UploadManager.shared.completeTask(uploadId: uploadId)
            }
        } catch {
            await MainActor.run {
                UploadManager.shared.failTask(uploadId: uploadId, error: error.localizedDescription)
            }
        }
    }
    
    private func copySelectedFiles() {
        guard !selectedFiles.isEmpty else { return }
        copiedNodes = selectedFiles
        cutNodes = nil
        selectionMode = false
        selectedFiles.removeAll()
    }

    private func cutSelectedFiles() {
        guard !selectedFiles.isEmpty else { return }
        cutNodes = selectedFiles
        copiedNodes = nil
        selectionMode = false
        selectedFiles.removeAll()
    }
    
    private func deleteSelectedFiles() {
        guard !selectedFiles.isEmpty else { return }
        filesToDelete = selectedFiles
        showingDeleteMultipleConfirm = true
    }
    
    private func confirmDeleteMultiple() {
        let files = filesToDelete
        Task {
            for file in files {
                do {
                    try await HaNasAPI.shared.deleteNode(id: file.id)
                } catch {}
            }
            await MainActor.run {
                if let parentId = selectedFolderID {
                    viewModel.loadFolder(id: parentId, forceRefresh: true)
                    viewModel.refreshTree()
                }
                selectionMode = false
                selectedFiles.removeAll()
                filesToDelete.removeAll()
            }
        }
    }
    
    private func pasteItem() {
        guard let parentId = selectedFolderID else { return }
        if let nodes = copiedNodes, !nodes.isEmpty {
            Task {
                let currentFolder = viewModel.getCurrentFolder(id: selectedFolderID)
                let existingNames = currentFolder?.ko?.map { $0.name } ?? []
                for node in nodes {
                    let isDuplicate = existingNames.contains(node.name)
                    if isDuplicate {
                        let shouldOverwrite = await MainActor.run {
                            let alert = NSAlert()
                            alert.messageText = NSLocalizedString("overwrite_confirm_title", comment: "")
                            alert.informativeText = String(format: NSLocalizedString("file_exists_overwrite", comment: ""), node.name)
                            alert.addButton(withTitle: NSLocalizedString("overwrite", comment: ""))
                            alert.addButton(withTitle: NSLocalizedString("cancel", comment: ""))
                            alert.alertStyle = .warning
                            return alert.runModal() == .alertFirstButtonReturn
                        }
                        if !shouldOverwrite { continue }
                    }
                    do {
                        try await HaNasAPI.shared.copyNode(srcId: node.id, dstId: parentId, overwrite: isDuplicate)
                    } catch {}
                }
                await MainActor.run {
                    viewModel.loadFolder(id: parentId, forceRefresh: true)
                    viewModel.refreshTree()
                    copiedNodes = nil
                }
            }
        } else if let nodes = cutNodes, !nodes.isEmpty {
            Task {
                let currentFolder = viewModel.getCurrentFolder(id: selectedFolderID)
                let existingNames = currentFolder?.ko?.map { $0.name } ?? []
                for node in nodes {
                    let isDuplicate = existingNames.contains(node.name)
                    if isDuplicate {
                        let shouldOverwrite = await MainActor.run {
                            let alert = NSAlert()
                            alert.messageText = NSLocalizedString("overwrite_confirm_title", comment: "")
                            alert.informativeText = String(format: NSLocalizedString("file_exists_overwrite", comment: ""), node.name)
                            alert.addButton(withTitle: NSLocalizedString("overwrite", comment: ""))
                            alert.addButton(withTitle: NSLocalizedString("cancel", comment: ""))
                            alert.alertStyle = .warning
                            return alert.runModal() == .alertFirstButtonReturn
                        }
                        if !shouldOverwrite { continue }
                    }
                    do {
                        try await HaNasAPI.shared.moveNode(id: node.id, newOyaId: parentId, overwrite: isDuplicate)
                    } catch {}
                }
                await MainActor.run {
                    viewModel.loadFolder(id: parentId, forceRefresh: true)
                    viewModel.refreshTree()
                    cutNodes = nil
                }
            }
        }
    }
    
    private func renameItem() {
        guard let node = renameNode else { return }
        if let currentFolder = viewModel.getCurrentFolder(id: selectedFolderID),
           let children = currentFolder.ko {
            let duplicate = children.first { $0.name == renameName && $0.id != node.id }
            if duplicate != nil {
                duplicateAlertMessage = NSLocalizedString("name_exists", comment: "")
                showingDuplicateAlert = true
                return
            }
        }
        
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
        deleteNodeToConfirm = node
        showingDeleteConfirm = true
    }
    
    private func confirmDelete() {
        guard let node = deleteNodeToConfirm else { return }
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
                    deleteNodeToConfirm = nil
                }
            } catch {
                await MainActor.run {
                    deleteNodeToConfirm = nil
                }
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
                let loadedNode = viewModel.loadedFolders[node.id] ?? node
                if let children = loadedNode.ko?.filter({ $0.isDir }) {
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
            .onAppear {
                viewModel.loadFolder(id: node.id, forceRefresh: false)
            }
            .onChange(of: isExpanded) { expanded in
                if expanded {
                    viewModel.loadFolder(id: node.id, forceRefresh: false)
                }
            }
        }
    }
}

struct FileGridItemView: View {
    let node: Node
    @ObservedObject var viewModel: FileListViewModel
    var isSelected: Bool = false
    @State private var thumbnail: NSImage?

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor.opacity(0.3) : Color(NSColor.controlBackgroundColor))
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
                if isSelected {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.accentColor, lineWidth: 3)
                        .frame(width: 100, height: 100)
                }
            }
            Text(node.name)
                .font(.caption)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(width: 100)
            if let size = node.size {
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
            } catch {
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
}

struct MediaPreviewView: View {
    let node: Node
    let onClose: () -> Void
    @State private var mediaData: Data?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var videoURL: URL?
    @State private var audioURL: URL?
    @State private var isAudioLooping: Bool = false
    
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
            if let streamURL = videoURL {
                AVPlayerViewWrapper(url: streamURL)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ProgressView()
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
                if let streamURL = audioURL {
                    AudioLoopPlayerView(url: streamURL, isLooping: $isAudioLooping)
                        .frame(height: 120)
                        .padding()
                    Button(action: { isAudioLooping.toggle() }) {
                        Label(NSLocalizedString(isAudioLooping ? "loop_cancel" : "loop_repeat", comment: ""), systemImage: isAudioLooping ? "repeat.circle.fill" : "repeat.circle")
                    }
                    .buttonStyle(.borderedProminent)
                    .padding()
                } else {
                    ProgressView()
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
                let ext = (node.name as NSString).pathExtension.lowercased()
                if ["mp4", "mov", "m4v"].contains(ext) {
                    let url = try await HaNasAPI.shared.getStreamURL(id: node.id, type: "video")
                    await MainActor.run {
                        videoURL = url
                        mediaData = Data()
                        isLoading = false
                    }
                } else if ["mp3", "wav", "m4a", "aac"].contains(ext) {
                    let url = try await HaNasAPI.shared.getStreamURL(id: node.id, type: "audio")
                    await MainActor.run {
                        audioURL = url
                        mediaData = Data()
                        isLoading = false
                    }
                } else {
                    let data = try await HaNasAPI.shared.downloadFile(id: node.id)
                    await MainActor.run {
                        mediaData = data
                        isLoading = false
                    }
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
        Task {
            do {
                let data = try await HaNasAPI.shared.downloadFile(id: node.id)
                showSavePanel(with: data)
            } catch {}
        }
    }
    
    @MainActor
    private func showSavePanel(with data: Data) {
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
            } catch {}
        }
    }
    
    func getCurrentFolder(id: Int?) -> Node? {
        guard let id = id else { return rootNode }
        return loadedFolders[id] ?? findNodeInTree(rootNode, id: id)
    }
    
    func refreshTree(currentFolderID: Int? = nil) {
        let folderToReload = currentFolderID
        loadedFolders.removeAll()
        isLoadingTree = true
        errorMessage = nil
        Task {
            do {
                let node = try await HaNasAPI.shared.getNode()
                await MainActor.run {
                    self.rootNode = node
                    self.loadedFolders[node.id] = node
                    self.isLoadingTree = false
                    if let folderId = folderToReload, folderId != node.id {
                        self.loadFolder(id: folderId, forceRefresh: true)
                    }
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = String(format: NSLocalizedString("cannot_load_data_with_error", comment: ""), error.localizedDescription)
                    self.isLoadingTree = false
                }
            }
        }
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

struct AudioLoopPlayerView: View {
    let url: URL
    @Binding var isLooping: Bool
    @State private var player: AVPlayer? = nil
    @State private var observer: Any?

    var body: some View {
        VStack {
            if let player = player {
                VideoPlayer(player: player)
                    .onAppear {
                        player.play()
                        addLoopObserver()
                    }
                    .onDisappear {
                        player.pause()
                        removeLoopObserver()
                    }
            } else {
                ProgressView()
            }
        }
        .onAppear {
            if player == nil {
                player = AVPlayer(url: url)
            }
        }
    }

    private func addLoopObserver() {
        removeLoopObserver()
        guard let player = player else { return }
        observer = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { _ in
            if isLooping {
                player.seek(to: .zero)
                player.play()
            }
        }
    }

    private func removeLoopObserver() {
        if let observer = observer {
            NotificationCenter.default.removeObserver(observer)
        }
        observer = nil
    }
}
