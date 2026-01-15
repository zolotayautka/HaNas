import SwiftUI

struct NodeInfoToast: View {
    let node: Node
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: node.isDir ? "folder.fill" : fileIcon(for: node.name))
                .resizable()
                .frame(width: 32, height: 32)
                .foregroundColor(node.isDir ? .blue : fileColor(for: node.name))
            VStack(alignment: .leading, spacing: 4) {
                Text(node.name)
                    .font(.headline)
                if let size = node.size {
                    Text("\(formatSize(size))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Text("\(formatDate(node.updatedAt))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(NSColor.controlBackgroundColor))
                .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 2)
        )
    }
    
    private func formatSize(_ size: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
    
    private func formatDate(_ dateString: String) -> String {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        guard let date = isoFormatter.date(from: dateString) else {
            return dateString
        }
        
        let displayFormatter = DateFormatter()
        displayFormatter.dateStyle = .medium
        displayFormatter.timeStyle = .short
        return displayFormatter.string(from: date)
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
}
