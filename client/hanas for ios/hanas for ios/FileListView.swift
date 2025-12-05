import SwiftUI
import AVKit
import PhotosUI
import UniformTypeIdentifiers
import Combine
import PDFKit

struct FileListView: View {
    @StateObject private var viewModel = FileListViewModel()
    @State private var selectedFile: Node?
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
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        VStack(spacing: 0) {
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
                    if let oyaId = currentFolder.oyaId {
                        Button(action: {
                            viewModel.loadFolder(id: oyaId)
                        }) {
                            Image(systemName: "arrow.up")
                        }
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
                                FileGridItemView(node: child)
                                    .onTapGesture {
                                        handleTap(child)
                                    }
                                    .contextMenu {
                                        fileContextMenu(for: child)
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
                    if copiedNode != nil || cutNode != nil {
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
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    appState.logout()
                }) {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                }
            }
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(onImagePicked: { data, filename in
                uploadFile(data: data, filename: filename)
            })
        }
        .sheet(isPresented: $showingDocumentPicker) {
            DocumentPicker { url in
                uploadDocument(url: url)
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
        .background(
            Group {
                if showShareSheet, let url = shareFileURL {
                    ShareSheetPresenter(url: url, isPresented: $showShareSheet)
                }
            }
        )
        .onAppear {
            viewModel.loadFolder(id: -1)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshFileList"))) { _ in
            if let currentId = viewModel.currentFolderId {
                viewModel.loadFolder(id: currentId)
            }
        }
    }
    
    @ViewBuilder
    private func fileContextMenu(for node: Node) -> some View {
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
            copiedNode = node
            cutNode = nil
        }) {
            Label(NSLocalizedString("copy", comment: ""), systemImage: "doc.on.doc")
        }
        Button(action: {
            cutNode = node
            copiedNode = nil
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
        
        Task {
            do {
                _ = try await HaNasAPI.shared.uploadFile(filename: filename, data: data, oyaId: folderId == -1 ? nil : folderId)
                await MainActor.run {
                    viewModel.loadFolder(id: folderId)
                }
            } catch {
            }
        }
    }
    
    private func uploadDocument(url: URL) {
        guard let folderId = viewModel.currentFolderId else { return }
        
        Task {
            do {
                _ = try await HaNasAPI.shared.uploadFileMultipart(filename: url.lastPathComponent, fileURL: url, oyaId: folderId == -1 ? nil : folderId)
                await MainActor.run {
                    viewModel.loadFolder(id: folderId)
                }
            } catch {
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
        Task {
            do {
                try await HaNasAPI.shared.deleteNode(id: node.id)
                await MainActor.run {
                    viewModel.loadFolder(id: viewModel.currentFolderId ?? -1)
                }
            } catch {
            }
        }
    }
    
    private func renameItem() {
        guard let node = renameNode else { return }
        
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
        
        Task {
            do {
                if let copied = copiedNode {
                    try await HaNasAPI.shared.copyNode(srcId: copied.id, dstId: targetId ?? -1, overwrite: true)
                    copiedNode = nil
                } else if let cut = cutNode {
                    try await HaNasAPI.shared.moveNode(id: cut.id, newOyaId: targetId ?? -1, overwrite: true)
                    cutNode = nil
                }
                await MainActor.run {
                    viewModel.loadFolder(id: folderId)
                }
            } catch {}
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
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                if isImage(node.name) {
                    AsyncImageView(nodeId: node.id)
                } else if isVideo(node.name) {
                    AsyncVideoView(nodeId: node.id)
                } else if isAudio(node.name) {
                    AsyncAudioView(nodeId: node.id, filename: node.name)
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
                        dismiss()
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
            UIApplication.shared.isIdleTimerDisabled = true
            if player == nil {
                loadVideo()
            } else {
                player?.play()
            }
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }
    
    private func loadVideo() {
        Task {
            do {
                let data = try await HaNasAPI.shared.downloadFile(id: nodeId)
                let fileName = "hanas_video_\(nodeId)_\(UUID().uuidString).mp4"
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
                try data.write(to: tempURL)
                await MainActor.run {
                    self.videoURL = tempURL
                    self.player = AVPlayer(url: tempURL)
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
    let onImagePicked: (Data, String) -> Void
    @Environment(\.dismiss) var dismiss
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
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
            guard let provider = results.first?.itemProvider else { return }
            if provider.canLoadObject(ofClass: UIImage.self) {
                provider.loadObject(ofClass: UIImage.self) { image, _ in
                    if let image = image as? UIImage, let data = image.jpegData(compressionQuality: 0.8) {
                        let filename = "photo_\(Date().timeIntervalSince1970).jpg"
                        self.parent.onImagePicked(data, filename)
                    }
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
    let onDocumentPicked: (URL) -> Void
    @Environment(\.dismiss) var dismiss
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.item])
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
            if let url = urls.first {
                parent.onDocumentPicked(url)
            }
        }
    }
}

struct AsyncAudioView: View {
    let nodeId: Int
    let filename: String
    @State private var player: AVPlayer?
    @State private var isLoading = true
    @State private var isPlaying = false
    @State private var duration: Double = 0
    @State private var currentTime: Double = 0
    @State private var timeObserver: Any?
    @State private var wasIdleTimerDisabled = false
    
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
                
                HStack(spacing: 20) {
                    Button {
                        togglePlayPause()
                    } label: {
                        Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .resizable()
                            .frame(width: 64, height: 64)
                            .foregroundColor(.white)
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
            UIApplication.shared.isIdleTimerDisabled = true
            loadAudio()
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
            if let obs = timeObserver, let p = player {
                p.removeTimeObserver(obs)
            }
            player?.pause()
        }
    }
    
    private func loadAudio() {
        Task {
            do {
                let data = try await HaNasAPI.shared.downloadFile(id: nodeId)
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension((filename as NSString).pathExtension.isEmpty ? "m4a" : (filename as NSString).pathExtension)
                try data.write(to: tempURL)
                
                await MainActor.run {
                    let item = AVPlayerItem(url: tempURL)
                    let p = AVPlayer(playerItem: item)
                    self.player = p
                    self.isLoading = false
                    let assetDuration = item.asset.duration.seconds
                    if assetDuration.isFinite {
                        self.duration = assetDuration
                    } else {
                        self.duration = 0
                    }
                    let interval = CMTime(seconds: 0.2, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
                    self.timeObserver = p.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
                        self.currentTime = time.seconds
                        if self.duration == 0, let d = p.currentItem?.duration.seconds, d.isFinite {
                            self.duration = d
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
    
    private func togglePlayPause() {
        guard let player = player else { return }
        if isPlaying {
            player.pause()
        } else {
            player.play()
        }
        isPlaying.toggle()
    }
    
    private func seek(to time: Double) {
        guard let player = player else { return }
        let cm = CMTime(seconds: time, preferredTimescale: 600)
        player.seek(to: cm)
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
