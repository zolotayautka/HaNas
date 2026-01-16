import SwiftUI
import AVKit
import PhotosUI
import UniformTypeIdentifiers
import Combine
import PDFKit
import MediaPlayer

struct FileListView: View {
    @StateObject private var viewModel = FileListViewModel()
    @State private var selectedFile: Node?
    @State private var showingNodeInfo: Bool = false
    @State private var nodeInfoTarget: Node? = nil
    @State private var showingImagePicker = false
    @State private var showingDocumentPicker = false
    @State private var showingNewFolderAlert = false
    @State private var newFolderName = ""
    @State private var showingRenameAlert = false
    @State private var renameNode: Node?
    @State private var renameName = ""
    @State private var copiedNode: Node?
    @State private var cutNode: Node?
    @State private var showShareSheet = false
    @State private var shareFileURL: URL?
    @State private var showingDuplicateAlert = false
    @State private var duplicateAlertMessage = ""
    @State private var showingOverwriteAlert = false
    @State private var overwriteAction: (() -> Void)?
    @State private var showingAccountInfo = false
    @State private var showingDeleteConfirm = false
    @State private var deleteNodeToConfirm: Node?
    @State private var showingDeleteMultipleConfirm = false
    @State private var nodesToDelete: [Node] = []
    @EnvironmentObject var appState: AppState
    @State private var isSelectionMode = false
    @State private var selectedNodes: Set<Int> = []
    @State private var copiedNodes: [Node] = []
    @State private var cutNodes: [Node] = []
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
            if isSelectionMode && !selectedNodes.isEmpty {
                HStack {
                    Button(action: { handleCopySelected() }) {
                        Label(NSLocalizedString("copy", comment: ""), systemImage: "doc.on.doc")
                    }
                    Button(action: { handleCutSelected() }) {
                        Label(NSLocalizedString("cut", comment: ""), systemImage: "scissors")
                    }
                    Button(role: .destructive, action: { handleDeleteSelected() }) {
                        Label(NSLocalizedString("delete", comment: ""), systemImage: "trash")
                    }
                }
                .padding(.horizontal)
                .background(Color(UIColor.systemBackground))
            }
            if viewModel.isLoading {
                ProgressView(NSLocalizedString("loading", comment: ""))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let currentFolder = viewModel.currentFolder {
                HStack {
                    Text(currentFolder.path ?? currentFolder.name)
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    Spacer()
                    Button(action: {
                        viewModel.loadFolder(id: -1)
                    }) {
                        Image(systemName: "house")
                    }
                    if let oyaId = currentFolder.oyaId {
                        Button(action: {
                            viewModel.loadFolder(id: oyaId)
                        }) {
                            Image(systemName: "arrow.up")
                        }
                    }
                    Button(action: {
                        isSelectionMode.toggle()
                        if !isSelectionMode { selectedNodes.removeAll() }
                    }) {
                        Image(systemName: isSelectionMode ? "checkmark.circle.fill" : "checkmark.circle")
                            .foregroundColor(isSelectionMode ? .blue : .gray)
                    }
                }
                .padding()
                .background(Color(UIColor.systemBackground))
                Divider()
                if let children = currentFolder.ko, !children.isEmpty {
                    ScrollView {
                        LazyVGrid(columns: [
                            GridItem(.adaptive(minimum: 100, maximum: 120), spacing: 15)
                        ], spacing: 15) {
                            ForEach(children, id: \.id) { child in
                                ZStack(alignment: .topTrailing) {
                                    FileGridItemView(node: child)
                                        .onTapGesture {
                                            if isSelectionMode {
                                                if selectedNodes.contains(child.id) {
                                                    selectedNodes.remove(child.id)
                                                } else {
                                                    selectedNodes.insert(child.id)
                                                }
                                            } else {
                                                handleTap(child)
                                            }
                                        }
                                        .contextMenu {
                                            fileContextMenu(for: child)
                                        }
                                    if isSelectionMode {
                                        Image(systemName: selectedNodes.contains(child.id) ? "checkmark.circle.fill" : "circle")
                                            .foregroundColor(selectedNodes.contains(child.id) ? .blue : .gray)
                                            .padding(4)
                                    }
                                }
                            }
                        }
                        .padding()
                    }
                } else {
                    VStack {
                        Image(systemName: "folder")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        Text(NSLocalizedString("empty_folder", comment: ""))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            }
            if showingNodeInfo, let node = nodeInfoTarget {
                VStack {
                    Spacer()
                    NodeInfoToast(node: node)
                        .padding(.bottom, 60)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.easeInOut, value: showingNodeInfo)
            }
            UploadProgressOverlay()
        }
        .navigationTitle(NSLocalizedString("app_name", comment: ""))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: { showingImagePicker = true }) {
                        Label(NSLocalizedString("upload_photo", comment: ""), systemImage: "photo")
                    }
                    Button(action: { showingDocumentPicker = true }) {
                        Label(NSLocalizedString("upload_file", comment: ""), systemImage: "doc")
                    }
                    Button(action: {
                        newFolderName = ""
                        showingNewFolderAlert = true
                    }) {
                        Label(NSLocalizedString("new_folder", comment: ""), systemImage: "folder.badge.plus")
                    }
                    if !copiedNodes.isEmpty || !cutNodes.isEmpty {
                        Divider()
                        Button(action: pasteItem) {
                            Label(NSLocalizedString("paste", comment: ""), systemImage: "doc.on.clipboard")
                        }
                    }
                    Divider()
                    Button(action: {
                        viewModel.loadFolder(id: viewModel.currentFolderId ?? -1)
                    }) {
                        Label(NSLocalizedString("refresh", comment: ""), systemImage: "arrow.clockwise")
                    }
                } label: {
                    Image(systemName: "plus.circle")
                }
            }
            ToolbarItemGroup(placement: .navigationBarLeading) {
                Button(action: {
                    showingAccountInfo = true
                }) {
                    Image(systemName: "person.circle")
                }
            }
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(onImagePicked: { items in
                for (data, filename) in items {
                    uploadFile(data: data, filename: filename)
                }
            })
        }
        .sheet(isPresented: $showingDocumentPicker) {
            DocumentPicker { urls in
                for url in urls {
                    uploadDocument(url: url)
                }
            }
        }
        .sheet(item: $selectedFile) { file in
            MediaPreviewView(node: file)
                .onDisappear {
                    if let currentId = viewModel.currentFolderId {
                        viewModel.loadFolder(id: currentId)
                    }
                }
        }
        .alert(NSLocalizedString("new_folder_title", comment: ""), isPresented: $showingNewFolderAlert) {
            TextField(NSLocalizedString("folder_name_placeholder", comment: ""), text: $newFolderName)
            Button(NSLocalizedString("cancel", comment: ""), role: .cancel) { }
            Button(NSLocalizedString("create", comment: "")) {
                createFolder()
            }
            .disabled(newFolderName.isEmpty)
        } message: {
            Text(NSLocalizedString("new_folder_message", comment: ""))
        }
        .alert(NSLocalizedString("rename_title", comment: ""), isPresented: $showingRenameAlert) {
            TextField(NSLocalizedString("new_name_placeholder", comment: ""), text: $renameName)
            Button(NSLocalizedString("cancel", comment: ""), role: .cancel) { }
            Button(NSLocalizedString("rename", comment: "")) {
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
        .sheet(isPresented: $showingAccountInfo) {
            AccountInfoSheet()
                .environmentObject(appState)
                .presentationDetents([.height(400), .medium])
                .presentationDragIndicator(.visible)
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
                nodesToDelete.removeAll()
            }
            Button(NSLocalizedString("delete", comment: ""), role: .destructive, action: confirmDeleteMultiple)
        } message: {
            Text("\(nodesToDelete.count) items")
        }
        .background(
            Group {
                if showShareSheet, let url = shareFileURL {
                    ShareSheetPresenter(url: url, isPresented: $showShareSheet)
                }
            }
        )
        .onAppear {
            viewModel.loadFolder(id: -1)
            configureAudioSessionForBackground()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshFileList"))) { _ in
            if let currentId = viewModel.currentFolderId {
                viewModel.loadFolder(id: currentId)
            }
        }
    }
    
    private func handleCopySelected() {
        guard let currentFolder = viewModel.currentFolder, let children = currentFolder.ko else { return }
        let nodes = children.filter { selectedNodes.contains($0.id) }
        if !nodes.isEmpty {
            copiedNodes = nodes
            cutNodes = []
            isSelectionMode = false
            selectedNodes.removeAll()
        }
    }

    private func handleCutSelected() {
        guard let currentFolder = viewModel.currentFolder, let children = currentFolder.ko else { return }
        let nodes = children.filter { selectedNodes.contains($0.id) }
        if !nodes.isEmpty {
            cutNodes = nodes
            copiedNodes = []
            isSelectionMode = false
            selectedNodes.removeAll()
        }
    }

    private func handleDeleteSelected() {
        guard let currentFolder = viewModel.currentFolder, let children = currentFolder.ko else { return }
        let nodes = children.filter { selectedNodes.contains($0.id) }
        guard !nodes.isEmpty else { return }
        nodesToDelete = nodes
        showingDeleteMultipleConfirm = true
    }
    
    private func confirmDeleteMultiple() {
        let nodes = nodesToDelete
        Task {
            for node in nodes {
                do {
                    try await HaNasAPI.shared.deleteNode(id: node.id)
                } catch {}
            }
            await MainActor.run {
                if let folderId = viewModel.currentFolderId {
                    viewModel.loadFolder(id: folderId)
                }
                isSelectionMode = false
                selectedNodes.removeAll()
                nodesToDelete.removeAll()
            }
        }
    }
    
    private func configureAudioSessionForBackground() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [])
        } catch {}
    }
    
    @ViewBuilder
    private func fileContextMenu(for node: Node) -> some View {
        Button(action: {
            nodeInfoTarget = node
            showingNodeInfo = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                showingNodeInfo = false
            }
        }) {
            Label(NSLocalizedString("node_info", comment: ""), systemImage: node.isDir ? "folder.fill" : "doc.fill")
        }
        Divider()
        if !node.isDir {
            Button(action: { selectedFile = node }) {
                Label(NSLocalizedString("preview", comment: ""), systemImage: "eye")
            }
            Button(action: { exportFile(node) }) {
                Label(NSLocalizedString("export", comment: ""), systemImage: "square.and.arrow.up")
            }
            Divider()
            if node.shareToken != nil && !node.shareToken!.isEmpty {
                Button(action: { copyShareLink(node) }) {
                    Label(NSLocalizedString("copy_share_link", comment: ""), systemImage: "link")
                }
                Button(action: { removeShare(node) }) {
                    Label(NSLocalizedString("remove_share", comment: ""), systemImage: "link.badge.minus")
                }
            } else {
                Button(action: { createShareLink(node) }) {
                    Label(NSLocalizedString("create_share_link", comment: ""), systemImage: "link.badge.plus")
                }
            }
            Divider()
        }
        Button(action: {
            copiedNodes = [node]
            cutNodes = []
        }) {
            Label(NSLocalizedString("copy", comment: ""), systemImage: "doc.on.doc")
        }
        Button(action: {
            cutNodes = [node]
            copiedNodes = []
        }) {
            Label(NSLocalizedString("cut", comment: ""), systemImage: "scissors")
        }
        Divider()
        Button(action: {
            renameNode = node
            renameName = node.name
            showingRenameAlert = true
        }) {
            Label(NSLocalizedString("rename", comment: ""), systemImage: "pencil")
        }
        Button(role: .destructive, action: {
            deleteItem(node)
        }) {
            Label(NSLocalizedString("delete", comment: ""), systemImage: "trash")
        }
    }
    
    private func handleTap(_ node: Node) {
        if node.isDir {
            viewModel.loadFolder(id: node.id)
        } else {
            selectedFile = node
        }
    }
    
    private func uploadFile(data: Data, filename: String) {
        guard let folderId = viewModel.currentFolderId else { return }
        if let currentFolder = viewModel.currentFolder,
           let children = currentFolder.ko {
            let duplicate = children.first { $0.name == filename }
            if duplicate != nil {
                overwriteAction = {
                    Task {
                        let uploadId = await MainActor.run {
                            UploadManager.shared.addTask(filename: filename)
                        }
                        do {
                            _ = try await HaNasAPI.shared.uploadFile(filename: filename, data: data, oyaId: folderId == -1 ? nil : folderId)
                            await MainActor.run {
                                UploadManager.shared.completeTask(uploadId: uploadId)
                                viewModel.loadFolder(id: folderId)
                            }
                        } catch {
                            await MainActor.run {
                                UploadManager.shared.failTask(uploadId: uploadId, error: error.localizedDescription)
                            }
                        }
                    }
                }
                showingOverwriteAlert = true
                return
            }
        }
        
        Task {
            let uploadId = await MainActor.run {
                UploadManager.shared.addTask(filename: filename)
            }
            do {
                _ = try await HaNasAPI.shared.uploadFile(filename: filename, data: data, oyaId: folderId == -1 ? nil : folderId)
                await MainActor.run {
                    UploadManager.shared.completeTask(uploadId: uploadId)
                    viewModel.loadFolder(id: folderId)
                }
            } catch {
                await MainActor.run {
                    UploadManager.shared.failTask(uploadId: uploadId, error: error.localizedDescription)
                }
            }
        }
    }
    
    private func uploadDocument(url: URL) {
        guard let folderId = viewModel.currentFolderId else { return }
        let filename = url.lastPathComponent
        if let currentFolder = viewModel.currentFolder,
           let children = currentFolder.ko {
            let duplicate = children.first { $0.name == filename }
            if duplicate != nil {
                overwriteAction = {
                    Task {
                        let uploadId = await MainActor.run {
                            UploadManager.shared.addTask(filename: filename)
                        }
                        do {
                            _ = try await HaNasAPI.shared.uploadFileMultipart(
                                filename: filename,
                                fileURL: url,
                                oyaId: folderId == -1 ? nil : folderId,
                                uploadId: uploadId,
                                progressCallback: { progress in
                                    Task { @MainActor in
                                        UploadManager.shared.updateProgress(uploadId: uploadId, progress: progress)
                                    }
                                }
                            )
                            await MainActor.run {
                                UploadManager.shared.completeTask(uploadId: uploadId)
                                viewModel.loadFolder(id: folderId)
                            }
                        } catch {
                            await MainActor.run {
                                UploadManager.shared.failTask(uploadId: uploadId, error: error.localizedDescription)
                            }
                        }
                    }
                }
                showingOverwriteAlert = true
                return
            }
        }
        
        Task {
            let uploadId = await MainActor.run {
                UploadManager.shared.addTask(filename: filename)
            }
            do {
                _ = try await HaNasAPI.shared.uploadFileMultipart(
                    filename: filename,
                    fileURL: url,
                    oyaId: folderId == -1 ? nil : folderId,
                    uploadId: uploadId,
                    progressCallback: { progress in
                        Task { @MainActor in
                            UploadManager.shared.updateProgress(uploadId: uploadId, progress: progress)
                        }
                    }
                )
                await MainActor.run {
                    UploadManager.shared.completeTask(uploadId: uploadId)
                    viewModel.loadFolder(id: folderId)
                }
            } catch {
                await MainActor.run {
                    UploadManager.shared.failTask(uploadId: uploadId, error: error.localizedDescription)
                }
            }
        }
    }
    
    private func createFolder() {
        guard let folderId = viewModel.currentFolderId else { return }
        
        Task {
            do {
                _ = try await HaNasAPI.shared.createFolder(name: newFolderName, oyaId: folderId == -1 ? nil : folderId)
                await MainActor.run {
                    viewModel.loadFolder(id: folderId)
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
                    viewModel.loadFolder(id: viewModel.currentFolderId ?? -1)
                    deleteNodeToConfirm = nil
                }
            } catch {
                await MainActor.run {
                    deleteNodeToConfirm = nil
                }
            }
        }
    }
    
    private func renameItem() {
        guard let node = renameNode else { return }
        if let currentFolder = viewModel.currentFolder,
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
                    viewModel.loadFolder(id: viewModel.currentFolderId ?? -1)
                }
            } catch {
            }
        }
    }
    
    private func pasteItem() {
        guard let folderId = viewModel.currentFolderId else { return }
        let targetId = folderId == -1 ? nil : folderId
        if !copiedNodes.isEmpty {
            Task {
                for node in copiedNodes {
                    if let currentFolder = viewModel.currentFolder, let children = currentFolder.ko {
                        let duplicate = children.first { $0.name == node.name }
                        if duplicate != nil {
                            overwriteAction = { [folderId, targetId] in
                                Task {
                                    do {
                                        try await HaNasAPI.shared.copyNode(srcId: node.id, dstId: targetId ?? -1, overwrite: true)
                                        await MainActor.run {
                                            viewModel.loadFolder(id: folderId)
                                        }
                                    } catch {}
                                }
                            }
                            showingOverwriteAlert = true
                            return
                        }
                    }
                    do {
                        try await HaNasAPI.shared.copyNode(srcId: node.id, dstId: targetId ?? -1, overwrite: false)
                    } catch {}
                }
                await MainActor.run {
                    copiedNodes = []
                    viewModel.loadFolder(id: folderId)
                }
            }
        } else if !cutNodes.isEmpty {
            Task {
                for node in cutNodes {
                    if let currentFolder = viewModel.currentFolder, let children = currentFolder.ko {
                        let duplicate = children.first { $0.name == node.name && $0.id != node.id }
                        if duplicate != nil {
                            overwriteAction = { [folderId, targetId] in
                                Task {
                                    do {
                                        try await HaNasAPI.shared.moveNode(id: node.id, newOyaId: targetId ?? -1, overwrite: true)
                                        await MainActor.run {
                                            viewModel.loadFolder(id: folderId)
                                        }
                                    } catch {}
                                }
                            }
                            showingOverwriteAlert = true
                            return
                        }
                    }
                    do {
                        try await HaNasAPI.shared.moveNode(id: node.id, newOyaId: targetId ?? -1, overwrite: false)
                    } catch {}
                }
                await MainActor.run {
                    cutNodes = []
                    viewModel.loadFolder(id: folderId)
                }
            }
        }
    }
    
    private func exportFile(_ node: Node) {
        Task {
            do {
                let data = try await HaNasAPI.shared.downloadFile(id: node.id)
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(node.name)
                try data.write(to: tempURL)
                await MainActor.run {
                    let ext = (node.name as NSString).pathExtension.lowercased()
                    let imageExts = ["jpg", "jpeg", "png", "gif", "webp", "bmp"]
                    if imageExts.contains(ext), let image = UIImage(data: data) {
                        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
                    }
                    self.shareFileURL = tempURL
                    self.showShareSheet = true
                }
            } catch {
            }
        }
    }
    
    private func saveAndShareFile(data: Data, filename: String) {
        let ext = (filename as NSString).pathExtension.lowercased()
        let imageExts = ["jpg", "jpeg", "png", "gif", "webp", "bmp"]
        if imageExts.contains(ext), let image = UIImage(data: data) {
            UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        }
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        do {
            try data.write(to: tempURL)
            self.shareFileURL = tempURL
            self.showShareSheet = true
        } catch {
        }
    }

    private func copyShareLink(_ node: Node) {
        guard let token = node.shareToken, !token.isEmpty else { return }
        let url = HaNasAPI.shared.getBaseURL() + "/s/" + token
        UIPasteboard.general.string = url
    }
    
    private func createShareLink(_ node: Node) {
        Task {
            do {
                _ = try await HaNasAPI.shared.createShare(nodeId: node.id)
                await MainActor.run {
                    viewModel.loadFolder(id: viewModel.currentFolderId ?? -1)
                }
            } catch {}
        }
    }
    
    private func removeShare(_ node: Node) {
        Task {
            do {
                try await HaNasAPI.shared.deleteShare(nodeId: node.id)
                await MainActor.run {
                    viewModel.loadFolder(id: viewModel.currentFolderId ?? -1)
                }
            } catch {}
        }
    }
    
    private func showIncorrectPasswordAlert() {
        let alert = UIAlertController(title: nil, message: NSLocalizedString("incorrectPassword", comment: "Incorrect password."), preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: NSLocalizedString("ok", comment: "OK"), style: .default))
        UIApplication.shared.windows.first?.rootViewController?.present(alert, animated: true)
    }
}

struct FileGridItemView: View {
    let node: Node
    @State private var thumbnail: UIImage?
    @State private var isLoadingThumbnail = false
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                if node.isDir {
                    Image(systemName: "folder.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 50, height: 50)
                        .foregroundColor(.blue)
                } else if let thumbnail = thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 100, height: 70)
                        .clipped()
                        .cornerRadius(8)
                } else if isLoadingThumbnail {
                    ZStack {
                        Color(UIColor.tertiarySystemBackground)
                            .frame(width: 100, height: 70)
                            .cornerRadius(8)
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .gray))
                    }
                } else {
                    Image(systemName: fileIcon(for: node.name))
                        .resizable()
                        .scaledToFit()
                        .frame(width: 50, height: 50)
                        .foregroundColor(.gray)
                }
                if !node.isDir && isVideo(node.name) && thumbnail != nil {
                    Image(systemName: "play.circle.fill")
                        .resizable()
                        .frame(width: 30, height: 30)
                        .foregroundColor(.white.opacity(0.9))
                        .shadow(radius: 2)
                }
            }
            .frame(height: 70)
            Text(node.name)
                .font(.caption)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .frame(width: 100, height: 100)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(10)
        .onAppear {
            loadThumbnailIfNeeded()
        }
    }
    
    private func loadThumbnailIfNeeded() {
        guard !node.isDir else { return }
        let ext = (node.name as NSString).pathExtension.lowercased()
        let supportedExts = ["jpg", "jpeg", "png", "gif", "webp", "bmp", "mp4", "mov", "m4v"]
        guard supportedExts.contains(ext) else { return }
        isLoadingThumbnail = true
        
        Task {
            do {
                let data = try await HaNasAPI.shared.getThumbnail(id: node.id)
                if let image = UIImage(data: data) {
                    await MainActor.run {
                        self.thumbnail = image
                        self.isLoadingThumbnail = false
                    }
                } else {
                    await MainActor.run {
                        self.isLoadingThumbnail = false
                    }
                }
            } catch {
                await MainActor.run {
                    self.isLoadingThumbnail = false
                }
            }
        }
    }
    
    private func isVideo(_ filename: String) -> Bool {
        let ext = (filename as NSString).pathExtension.lowercased()
        return ["mp4", "mov", "m4v", "avi", "mkv"].contains(ext)
    }
    
    private func fileIcon(for filename: String) -> String {
        let ext = (filename as NSString).pathExtension.lowercased()
        let imageExts = ["jpg", "jpeg", "png", "gif", "webp", "bmp"]
        let videoExts = ["mp4", "mov", "m4v", "avi", "mkv"]
        let audioExts = ["mp3", "m4a", "wav", "aac"]
        let docExts = ["pdf", "doc", "docx", "txt"]
        if imageExts.contains(ext) {
            return "photo"
        } else if videoExts.contains(ext) {
            return "play.rectangle"
        } else if audioExts.contains(ext) {
            return "music.note"
        } else if docExts.contains(ext) {
            return "doc.text"
        } else {
            return "doc"
        }
    }
}

class FileListViewModel: ObservableObject {
    @Published var currentFolder: Node?
    @Published var currentFolderId: Int?
    @Published var isLoading = false
    
    func loadFolder(id: Int) {
        isLoading = true
        currentFolderId = id
        
        Task {
            do {
                let node = try await HaNasAPI.shared.getNode(id: id == -1 ? nil : id)
                await MainActor.run {
                    self.currentFolder = node
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
}

struct MediaPreviewView: View {
    let node: Node
    @Environment(\.dismiss) var dismiss
    @State private var showShareSheet = false
    @State private var shareFileURL: URL?
    @State private var showShareLinkAlert = false
    @State private var shareLinkURL = ""
    @State private var shouldStopPlayback = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                if isImage(node.name) {
                    AsyncImageView(nodeId: node.id)
                } else if isVideo(node.name) {
                    AsyncVideoView(nodeId: node.id, stopPlayback: $shouldStopPlayback)
                } else if isAudio(node.name) {
                    AsyncAudioView(nodeId: node.id, filename: node.name, stopPlayback: $shouldStopPlayback)
                } else if isPDF(node.name) {
                    AsyncPDFView(nodeId: node.id)
                } else {
                    Text("Preview not available")
                        .foregroundColor(.white)
                }
            }
            .navigationTitle(node.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Menu {
                        Button(action: shareFile) {
                            Label("Share File", systemImage: "square.and.arrow.up")
                        }
                        if node.shareToken != nil && !node.shareToken!.isEmpty {
                            Button(action: { showExistingShareLink() }) {
                                Label("View Share Link", systemImage: "link")
                            }
                        } else {
                            Button(action: { createAndShowShareLink() }) {
                                Label("Create Share Link", systemImage: "link.badge.plus")
                            }
                        }
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        shouldStopPlayback = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            dismiss()
                        }
                    }
                }
            }
            .background(
                Group {
                    if showShareSheet, let url = shareFileURL {
                        ShareSheetPresenter(url: url, isPresented: $showShareSheet)
                    }
                }
            )
            .alert("Share Link", isPresented: $showShareLinkAlert) {
                Button("Copy") {
                    UIPasteboard.general.string = shareLinkURL
                }
                Button("OK", role: .cancel) { }
            } message: {
                Text(shareLinkURL)
            }
        }
    }
    
    private func createAndShowShareLink() {
        Task {
            do {
                let token = try await HaNasAPI.shared.createShare(nodeId: node.id)
                await MainActor.run {
                    shareLinkURL = HaNasAPI.shared.getBaseURL() + "/s/" + token
                    showShareLinkAlert = true
                    NotificationCenter.default.post(name: NSNotification.Name("RefreshFileList"), object: nil)
                }
            } catch {}
        }
    }
    
    private func showExistingShareLink() {
        if let token = node.shareToken {
            shareLinkURL = HaNasAPI.shared.getBaseURL() + "/s/" + token
            showShareLinkAlert = true
        }
    }
    
    private func shareFile() {
        Task {
            do {
                let data = try await HaNasAPI.shared.downloadFile(id: node.id)
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(node.name)
                try data.write(to: tempURL)
                await MainActor.run {
                    shareFileURL = tempURL
                    showShareSheet = true
                }
            } catch {}
        }
    }
    
    private func isImage(_ filename: String) -> Bool {
        let ext = (filename as NSString).pathExtension.lowercased()
        return ["jpg", "jpeg", "png", "gif", "webp", "bmp"].contains(ext)
    }
    
    private func isVideo(_ filename: String) -> Bool {
        let ext = (filename as NSString).pathExtension.lowercased()
        return ["mp4", "mov", "m4v", "avi", "mkv"].contains(ext)
    }
    
    private func isAudio(_ filename: String) -> Bool {
        let ext = (filename as NSString).pathExtension.lowercased()
        return ["mp3", "m4a", "wav", "aac"].contains(ext)
    }
    
    private func isPDF(_ filename: String) -> Bool {
        let ext = (filename as NSString).pathExtension.lowercased()
        return ext == "pdf"
    }
}

struct AsyncImageView: View {
    let nodeId: Int
    @State private var image: UIImage?
    @State private var isLoading = true
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @GestureState private var magnifyBy = 1.0
    
    var body: some View {
        GeometryReader { geometry in
            Group {
                if isLoading {
                    ProgressView()
                } else if let image = image {
                    ScrollView([.horizontal, .vertical], showsIndicators: false) {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .scaleEffect(scale * magnifyBy)
                            .gesture(
                                MagnificationGesture()
                                    .updating($magnifyBy) { currentState, gestureState, _ in
                                        gestureState = currentState
                                    }
                                    .onEnded { value in
                                        scale *= value
                                        scale = min(max(scale, 1.0), 5.0)
                                    }
                            )
                            .onTapGesture(count: 2) {
                                withAnimation {
                                    scale = scale > 1.0 ? 1.0 : 2.0
                                }
                            }
                    }
                } else {
                    Text("Failed to load image")
                        .foregroundColor(.white)
                }
            }
        }
        .onAppear {
            loadImage()
        }
    }
    
    private func loadImage() {
        Task {
            do {
                let data = try await HaNasAPI.shared.downloadFile(id: nodeId)
                await MainActor.run {
                    self.image = UIImage(data: data)
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
}

struct AsyncVideoView: View {
    let nodeId: Int
    @Binding var stopPlayback: Bool
    @State private var player: AVPlayer?
    @State private var isLoading = true
    @State private var videoURL: URL?
    
    var body: some View {
        ZStack {
            if isLoading {
                ProgressView()
            } else if let player = player {
                VideoPlayerView(player: player)
            } else {
                Text("Failed to load video")
                    .foregroundColor(.white)
            }
        }
        .onAppear {
            AudioPlaybackManager.shared.stopCurrent()
            UIApplication.shared.isIdleTimerDisabled = true
            if player == nil {
                loadVideo()
            } else {
                player?.play()
            }
        }
        .onChange(of: stopPlayback) { shouldStop in
            if shouldStop {
                cleanup()
            }
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }
    
    private func loadVideo() {
        Task {
            do {
                let streamURL = try await HaNasAPI.shared.getStreamURL(id: nodeId, type: "video")
                await MainActor.run {
                        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback, options: [])
                        try? AVAudioSession.sharedInstance().setActive(true)
                    self.videoURL = streamURL
                    self.player = AVPlayer(url: streamURL)
                    self.player?.play()
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
    
    private func cleanup() {
        player?.pause()
        player = nil
        if let url = videoURL {
            DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 1.0) {
                try? FileManager.default.removeItem(at: url)
            }
        }
        UIApplication.shared.isIdleTimerDisabled = false
    }
}

struct VideoPlayerView: UIViewControllerRepresentable {
    let player: AVPlayer
    
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = true
        controller.allowsPictureInPicturePlayback = true
        controller.canStartPictureInPictureAutomaticallyFromInline = true
        controller.entersFullScreenWhenPlaybackBegins = false
        controller.exitsFullScreenWhenPlaybackEnds = true
        return controller
    }
    
    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        if uiViewController.player !== player {
            uiViewController.player = player
        }
    }
}

struct ImagePicker: UIViewControllerRepresentable {
    let onImagePicked: ([(Data, String)]) -> Void
    @Environment(\.dismiss) var dismiss
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 0
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.dismiss()
            guard !results.isEmpty else { return }
            var pickedImages: [(Data, String)] = []
            let group = DispatchGroup()
            for (idx, result) in results.enumerated() {
                let provider = result.itemProvider
                if provider.canLoadObject(ofClass: UIImage.self) {
                    group.enter()
                    provider.loadObject(ofClass: UIImage.self) { image, _ in
                        if let image = image as? UIImage, let data = image.jpegData(compressionQuality: 0.8) {
                            let filename = "photo_\(Date().timeIntervalSince1970)_\(idx).jpg"
                            pickedImages.append((data, filename))
                        }
                        group.leave()
                    }
                }
            }
            group.notify(queue: .main) {
                if !pickedImages.isEmpty {
                    self.parent.onImagePicked(pickedImages)
                }
            }
        }
    }
}

struct ShareSheetPresenter: UIViewControllerRepresentable {
    let url: URL
    @Binding var isPresented: Bool
    
    func makeUIViewController(context: Context) -> UIViewController {
        let controller = UIViewController()
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        if isPresented && uiViewController.presentedViewController == nil {
            let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
            activityVC.completionWithItemsHandler = { _, _, _, _ in
                isPresented = false
            }
            uiViewController.present(activityVC, animated: true)
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct DocumentPicker: UIViewControllerRepresentable {
    let onDocumentPicked: ([URL]) -> Void
    @Environment(\.dismiss) var dismiss
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.item])
        picker.allowsMultipleSelection = true
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPicker
        
        init(_ parent: DocumentPicker) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            parent.dismiss()
            if !urls.isEmpty {
                parent.onDocumentPicked(urls)
            }
        }
    }
}

struct AsyncAudioView: View {
    let nodeId: Int
    let filename: String
    @Binding var stopPlayback: Bool
    @State private var player: AVPlayer?
    @State private var isLoading = true
    @State private var isPlaying = false
    @State private var duration: Double = 0
    @State private var currentTime: Double = 0
    @State private var timeObserver: Any?
    @State private var repeatEnabled: Bool = false
    @State private var endObserver: Any?
    
    var body: some View {
        VStack(spacing: 16) {
            if isLoading {
                ProgressView()
                    .tint(.white)
            } else if player != nil {
                Text(filename)
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                
                HStack(spacing: 24) {
                    Button {
                        togglePlayPause()
                    } label: {
                        Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .resizable()
                            .frame(width: 64, height: 64)
                            .foregroundColor(.white)
                    }
                    
                    Button {
                        repeatEnabled.toggle()
                    } label: {
                        Image(systemName: repeatEnabled ? "repeat.circle.fill" : "repeat.circle")
                            .resizable()
                            .frame(width: 44, height: 44)
                            .foregroundColor(repeatEnabled ? .green : .white)
                            .accessibilityLabel(repeatEnabled ? "Repeat On" : "Repeat Off")
                    }
                }
                VStack {
                    Slider(value: Binding(
                        get: { currentTime },
                        set: { newValue in
                            seek(to: newValue)
                        }
                    ), in: 0...max(duration, 0.1))
                    .tint(.white)
                    
                    HStack {
                        Text(formatTime(currentTime))
                        Spacer()
                        Text(formatTime(duration))
                    }
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
                }
                .padding(.horizontal)
            } else {
                Text("Failed to load audio")
                    .foregroundColor(.white)
            }
        }
        .padding()
        .onAppear {
            AudioPlaybackManager.shared.stopCurrent()
            UIApplication.shared.isIdleTimerDisabled = true
            loadAudio()
        }
        .onChange(of: stopPlayback) { shouldStop in
            if shouldStop {
                cleanup()
            }
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }
    
    private func loadAudio() {
        Task {
            do {
                let streamURL = try await HaNasAPI.shared.getStreamURL(id: nodeId, type: "audio")
                await MainActor.run {
                    let item = AVPlayerItem(url: streamURL)
                    let p = AVPlayer(playerItem: item)
                    self.player = p
                    self.isLoading = false
                    let assetDuration = item.asset.duration.seconds
                    self.duration = assetDuration.isFinite ? assetDuration : 0
                    let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
                    self.timeObserver = p.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
                        self.currentTime = time.seconds
                        if self.duration == 0, let d = p.currentItem?.duration.seconds, d.isFinite {
                            self.duration = d
                        }
                        AudioPlaybackManager.shared.updateNowPlaying(elapsedTime: self.currentTime, duration: self.duration)
                    }
                    self.endObserver = NotificationCenter.default.addObserver(
                        forName: .AVPlayerItemDidPlayToEndTime,
                        object: item,
                        queue: .main
                    ) { _ in
                        if repeatEnabled {
                            let zero = CMTime(seconds: 0, preferredTimescale: 600)
                            self.player?.seek(to: zero) { _ in
                                self.player?.play()
                                self.isPlaying = true
                                AudioPlaybackManager.shared.updateNowPlaying(rate: 1.0, elapsedTime: 0, duration: self.duration)
                            }
                        } else {
                            self.isPlaying = false
                            AudioPlaybackManager.shared.updateNowPlaying(rate: 0.0, elapsedTime: self.currentTime, duration: self.duration)
                        }
                    }
                    try? AVAudioSession.sharedInstance().setActive(true, options: [])
                    AudioPlaybackManager.shared.setActive(
                        player: p,
                        title: filename,
                        duration: duration,
                        onToggle: self.togglePlayPause,
                        onSeek: self.seek
                    )
                    p.play()
                    self.isPlaying = true
                    AudioPlaybackManager.shared.updateNowPlaying(rate: 1.0, elapsedTime: 0, duration: self.duration)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        AudioPlaybackManager.shared.updateNowPlaying(rate: 1.0, elapsedTime: self.currentTime, duration: self.duration)
                    }
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
    
    private func play() {
        player?.play()
        isPlaying = true
        AudioPlaybackManager.shared.updateNowPlaying(rate: 1.0, elapsedTime: currentTime, duration: duration)
    }
    
    private func pause() {
        player?.pause()
        isPlaying = false
        AudioPlaybackManager.shared.updateNowPlaying(rate: 0.0, elapsedTime: currentTime, duration: duration)
    }
    
    private func togglePlayPause() {
        guard let _ = player else { return }
        if isPlaying {
            pause()
        } else {
            play()
        }
    }
    
    private func seek(to time: Double) {
        guard let player = player else { return }
        let cm = CMTime(seconds: time, preferredTimescale: 600)
        player.seek(to: cm) { _ in
            self.currentTime = time
            AudioPlaybackManager.shared.updateNowPlaying(elapsedTime: time, duration: self.duration)
        }
    }
    
    private func cleanup() {
        if let obs = timeObserver, let p = player {
            p.removeTimeObserver(obs)
            timeObserver = nil
        }
        if let endObs = endObserver {
            NotificationCenter.default.removeObserver(endObs)
            endObserver = nil
        }
        if AudioPlaybackManager.shared.isCurrent(player: player) {
            AudioPlaybackManager.shared.stopCurrent()
        } else {
            player?.pause()
        }
        player = nil
        isPlaying = false
        UIApplication.shared.isIdleTimerDisabled = false
    }
    
    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite && !seconds.isNaN else { return "--:--" }
        let s = Int(seconds.rounded())
        let mPart = s / 60
        let sPart = s % 60
        return String(format: "%02d:%02d", mPart, sPart)
    }
}

struct AsyncPDFView: View {
    let nodeId: Int
    @State private var pdfDocument: PDFDocument?
    @State private var isLoading = true
    
    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .tint(.white)
            } else if let document = pdfDocument {
                PDFKitView(document: document)
            } else {
                Text("Failed to load PDF")
                    .foregroundColor(.white)
            }
        }
        .onAppear {
            loadPDF()
        }
    }
    
    private func loadPDF() {
        Task {
            do {
                let data = try await HaNasAPI.shared.downloadFile(id: nodeId)
                await MainActor.run {
                    self.pdfDocument = PDFDocument(data: data)
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
}

struct PDFKitView: UIViewRepresentable {
    let document: PDFDocument
    
    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.document = document
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.backgroundColor = .black
        return pdfView
    }
    
    func updateUIView(_ uiView: PDFView, context: Context) {
        uiView.document = document
    }
}

final class AudioPlaybackManager {
    static let shared = AudioPlaybackManager()
    private var player: AVPlayer?
    private var title: String = ""
    private var duration: Double = 0
    private var timeObserver: Any?
    private var onToggle: (() -> Void)?
    private var onSeek: ((Double) -> Void)?
    
    private init() {
        setupRemoteCommands()
    }
    
    func isCurrent(player: AVPlayer?) -> Bool {
        guard let p = player else { return false }
        return self.player === p
    }
    
    func setActive(player: AVPlayer, title: String, duration: Double, onToggle: @escaping () -> Void, onSeek: @escaping (Double) -> Void) {
        if let current = self.player, current !== player {
            stopCurrent()
        }
        self.player = player
               self.title = title
        self.duration = duration
        self.onToggle = onToggle
        self.onSeek = onSeek
        try? AVAudioSession.sharedInstance().setActive(true, options: [])
        setupNowPlaying(elapsed: currentElapsed(), rate: currentRate())
        setupRemoteCommands()
    }
    
    func stopCurrent() {
        if let p = player {
            p.pause()
            if let obs = timeObserver {
                p.removeTimeObserver(obs)
                timeObserver = nil
            }
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        player = nil
        onToggle = nil
        onSeek = nil
    }
    
    func updateNowPlaying(rate: Float? = nil, elapsedTime: Double? = nil, duration: Double? = nil) {
        if let duration = duration { self.duration = duration }
        setupNowPlaying(elapsed: elapsedTime ?? currentElapsed(), rate: rate ?? currentRate())
    }
    
    func updateNowPlaying(elapsedTime: Double, duration: Double) {
        updateNowPlaying(rate: nil, elapsedTime: elapsedTime, duration: duration)
    }
    
    private func setupRemoteCommands() {
        let cc = MPRemoteCommandCenter.shared()
        cc.playCommand.isEnabled = true
        cc.pauseCommand.isEnabled = true
        cc.togglePlayPauseCommand.isEnabled = true
        cc.changePlaybackPositionCommand.isEnabled = true
        cc.skipForwardCommand.isEnabled = true
        cc.skipBackwardCommand.isEnabled = true
        cc.skipForwardCommand.preferredIntervals = [15]
        cc.skipBackwardCommand.preferredIntervals = [15]
        cc.playCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            if self.currentRate() == 0 { self.onToggle?() }
            return .success
        }
        cc.pauseCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            if self.currentRate() != 0 { self.onToggle?() }
            return .success
        }
        cc.togglePlayPauseCommand.addTarget { [weak self] _ in
            self?.onToggle?()
            return .success
        }
        cc.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard
                let self,
                let evt = event as? MPChangePlaybackPositionCommandEvent
            else { return .commandFailed }
            self.onSeek?(evt.positionTime)
            return .success
        }
        cc.skipForwardCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            self.onSeek?(self.currentElapsed() + 15)
            return .success
        }
        cc.skipBackwardCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            self.onSeek?(max(self.currentElapsed() - 15, 0))
            return .success
        }
    }
    
    private func setupNowPlaying(elapsed: Double, rate: Float) {
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: title,
            MPMediaItemPropertyMediaType: MPMediaType.anyAudio.rawValue,
            MPNowPlayingInfoPropertyPlaybackRate: rate,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: elapsed
        ]
        if duration.isFinite && duration > 0 {
            info[MPMediaItemPropertyPlaybackDuration] = duration
        }
        if #available(iOS 13.0, *) {
            let size = CGSize(width: 512, height: 512)
            let renderer = UIGraphicsImageRenderer(size: size)
            let img = renderer.image { ctx in
                UIColor.systemBlue.setFill()
                ctx.fill(CGRect(origin: .zero, size: size))
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.boldSystemFont(ofSize: 80),
                    .foregroundColor: UIColor.white
                ]
                let text = "HaNas"
                let textSize = (text as NSString).size(withAttributes: attrs)
                let rect = CGRect(x: (size.width - textSize.width)/2, y: (size.height - textSize.height)/2, width: textSize.width, height: textSize.height)
                (text as NSString).draw(in: rect, withAttributes: attrs)
            }
            let artwork = MPMediaItemArtwork(boundsSize: img.size) { _ in img }
            info[MPMediaItemPropertyArtwork] = artwork
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
    
    private func currentElapsed() -> Double {
        guard let p = player, let t = p.currentItem?.currentTime().seconds, t.isFinite else { return 0 }
        return t
    }
    
    private func currentRate() -> Float {
        guard let p = player else { return 0 }
        return p.rate
    }
}
