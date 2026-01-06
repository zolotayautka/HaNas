import SwiftUI

struct NodeInfoToast: View {
    let node: Node
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: node.isDir ? "folder.fill" : "doc.fill")
                .resizable()
                .frame(width: 32, height: 32)
                .foregroundColor(node.isDir ? .yellow : .blue)
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
        .background(BlurView(style: .systemMaterial))
        .cornerRadius(16)
        .shadow(radius: 8)
    }
    
    func formatSize(_ size: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
    
    func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            displayFormatter.timeStyle = .short
            return displayFormatter.string(from: date)
        }
        return dateString
    }
}

struct BlurView: UIViewRepresentable {
    var style: UIBlurEffect.Style
    func makeUIView(context: Context) -> UIVisualEffectView {
        return UIVisualEffectView(effect: UIBlurEffect(style: style))
    }
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {}
}