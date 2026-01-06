import SwiftUI
import Combine

struct UploadTask: Identifiable {
    let id: String
    let filename: String
    var progress: Double
    var isComplete: Bool
    var error: String?
    
    init(filename: String, uploadId: String = UUID().uuidString) {
        self.id = uploadId
        self.filename = filename
        self.progress = 0.0
        self.isComplete = false
        self.error = nil
    }
}

@MainActor
class UploadManager: ObservableObject {
    static let shared = UploadManager()
    @Published var uploadTasks: [UploadTask] = []
    
    private init() {}
    
    func addTask(filename: String) -> String {
        let task = UploadTask(filename: filename)
        uploadTasks.append(task)
        return task.id
    }
    
    func updateProgress(uploadId: String, progress: Double) {
        if let index = uploadTasks.firstIndex(where: { $0.id == uploadId }) {
            uploadTasks[index].progress = progress
        }
    }
    
    func completeTask(uploadId: String) {
        if let index = uploadTasks.firstIndex(where: { $0.id == uploadId }) {
            uploadTasks[index].progress = 1.0
            uploadTasks[index].isComplete = true
            Task {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                await removeTask(uploadId: uploadId)
            }
        }
    }
    
    func failTask(uploadId: String, error: String) {
        if let index = uploadTasks.firstIndex(where: { $0.id == uploadId }) {
            uploadTasks[index].error = error
            uploadTasks[index].isComplete = true
            Task {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                await removeTask(uploadId: uploadId)
            }
        }
    }
    
    func removeTask(uploadId: String) {
        uploadTasks.removeAll { $0.id == uploadId }
    }
}

struct UploadTaskToast: View {
    let task: UploadTask
    @ObservedObject var manager: UploadManager
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                if let error = task.error {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                        .font(.title2)
                } else if task.isComplete {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.title2)
                } else {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(0.8)
                }
            }
            .frame(width: 32, height: 32)
            VStack(alignment: .leading, spacing: 6) {
                Text(task.filename)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                    .foregroundColor(.primary)
                if let error = task.error {
                    Text(error)
                        .font(.system(size: 11))
                        .foregroundColor(.red)
                        .lineLimit(1)
                } else if task.isComplete {
                    Text(NSLocalizedString("upload_complete", comment: "Upload complete"))
                        .font(.system(size: 11))
                        .foregroundColor(.green)
                } else {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text("\(Int(task.progress * 100))%")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(height: 6)
                                
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.blue)
                                    .frame(width: geometry.size.width * task.progress, height: 6)
                            }
                        }
                        .frame(height: 6)
                    }
                }
            }
            if task.isComplete || task.error != nil {
                Button(action: {
                    manager.removeTask(uploadId: task.id)
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.system(size: 16))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
                .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 2)
        )
        .frame(width: 320)
    }
}

struct UploadProgressToastView: View {
    @ObservedObject var manager: UploadManager
    
    var body: some View {
        VStack(alignment: .trailing, spacing: 8) {
            ForEach(manager.uploadTasks) { task in
                UploadTaskToast(task: task, manager: manager)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .trailing).combined(with: .opacity)
                    ))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: manager.uploadTasks.count)
        .padding()
    }
}

struct UploadProgressOverlay: View {
    @ObservedObject var manager = UploadManager.shared
    
    var body: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                if !manager.uploadTasks.isEmpty {
                    UploadProgressToastView(manager: manager)
                }
            }
        }
        .allowsHitTesting(false)
    }
}
