# HaNas for iOS

Native iOS client for the HaNas file management system. Built with SwiftUI for a modern, native iOS experience.

## ✨ Features

### File Management
- 📁 **Browse**: Grid-based file and folder browsing optimized for touch
- 📤 **Upload**: Photos from library and documents from Files app
- 📥 **Download**: Save files to device or view inline
- 🗂️ **Organize**: Create, rename, delete, copy, cut, and paste files/folders
- 🔍 **Preview**: Native iOS previews for images, videos, PDFs, and audio

### Advanced Features
- 🔐 **Secure Authentication**: JWT-based login with persistent storage
- 🖼️ **Thumbnails**: Automatic thumbnail loading for images and videos
- 🔗 **Sharing**: Create and manage shareable links
- 📊 **Progress Tracking**: Real-time upload progress with percentage
- 🎨 **Native UI**: SwiftUI-based interface with iOS design patterns
- 🌍 **Multi-language**: English, Japanese, and Korean support
- ⚡ **Performance**: Efficient caching and lazy loading

### User Experience
- Context menu for quick actions (long press)
- Swipe gestures and intuitive navigation
- Automatic login on app launch
- Persistent server configuration
- Error handling with user-friendly messages

## 📋 Requirements

- **iOS**: 15.0 or later
- **Xcode**: 14.0 or later
- **Swift**: 5.7 or later
- **HaNas Server**: Running instance of HaNas server

## 🚀 Installation

### From Xcode

1. Open the project:
   ```bash
   cd "client/hanas for ios"
   open "Hanas for ios.xcodeproj"
   ```

2. Configure signing:
   - Select your development team in **Signing & Capabilities**
   - Update bundle identifier if needed

3. Select target device (iPhone or iPad)

4. Build and run:
   - Press `⌘R` or click the Run button
   - App will install and launch on your device

### First Launch Setup

1. **Enter Server URL**
   - Format: `http://your-server-ip:8080`
   - Example: `http://192.168.1.100:8080`
   - Must include `http://` or `https://`

2. **Authentication**
   - **New Users**: Tap "Register" and create an account
   - **Existing Users**: Enter username and password
   - Credentials are securely stored for auto-login

3. **Start Using**
   - Browse your files in grid layout
   - Upload photos or documents
   - Create folders and organize files

## 📱 Usage Guide

### Navigation
- **Tap folder**: Navigate into folder
- **Tap file**: Preview or play media
- **Up arrow**: Go to parent folder
- **Path display**: Shows current location

### Upload Files
1. Tap the **+** button in top right
2. Choose upload method:
   - **Upload Photo**: Select from photo library
   - **Upload File**: Choose from Files app
   - Supports multiple file formats

### Create Folder
1. Tap **+** button
2. Select **New Folder**
3. Enter folder name
4. Tap **Create**

### File Operations (Long Press)
- **Rename**: Change file/folder name
- **Delete**: Remove file/folder
- **Copy**: Copy to clipboard
- **Cut**: Cut for moving
- **Share**: Create shareable link (folders and files)
- **Download**: Save to device

### Paste Operations
1. Copy or Cut a file/folder
2. Navigate to destination folder
3. Tap **+** → **Paste**

## ⚙️ Configuration

### Server Connection
- **URL Storage**: Saved in app's Documents directory
- **Credentials**: Encrypted storage using SQLite
- **Auto-reconnect**: Automatic login on app restart

### Permissions Required

The app needs these iOS permissions:

#### Photo Library Access
- **When**: Uploading photos/videos
- **Usage**: `NSPhotoLibraryUsageDescription`
- **Requested**: Only when selecting photos

#### File Access
- **When**: Uploading documents
- **Usage**: Document Picker
- **Requested**: Only when selecting files

### Network Requirements
- Server must be accessible from device
- For local network: same WiFi/LAN
- For remote access: proper port forwarding or VPN
- Both WiFi and cellular supported

## 🏗️ Architecture

### App Structure

```
HaNas for iOS/
├── HaNas_iOSApp.swift      # App entry point with @main
├── AppState.swift          # Global state management
├── ConfigManager.swift     # Persistent configuration
├── ContentView.swift       # Main view switcher
├── LoginView.swift         # Authentication UI
├── FileListView.swift      # File browser (main feature)
├── exec.swift              # HaNasAPI client
└── Localizable.strings     # Translations (en, ja, ko)
```

### Key Components

#### HaNasAPI (`exec.swift`)
- Singleton API client
- RESTful endpoint wrappers
- JWT token management
- Cookie-based authentication
- Multipart file upload support
- Error handling with custom types

#### AppState (`AppState.swift`)
- Observable global state
- Authentication status
- Server URL and username
- Auto-login on app launch
- Logout functionality

#### ConfigManager (`ConfigManager.swift`)
- SQLite-based storage
- Secure credential persistence
- Server configuration management
- Located in app Documents directory

#### FileListView (`FileListView.swift`)
- Main file browser interface
- Grid-based layout with LazyVGrid
- Context menus for operations
- Image picker and document picker integration
- Media preview with PDFKit and AVKit
- Real-time upload progress
- Clipboard operations (copy/cut/paste)

### Design Patterns
- **MVVM**: View-ViewModel separation
- **Combine**: Reactive state management
- **Singleton**: API and state management
- **ObservableObject**: SwiftUI state binding

## 🔧 API Client Details

### HaNasAPI Methods

#### Authentication
```swift
// Register new user
let response = try await HaNasAPI.shared.register(
    username: "user",
    password: "pass"
)

// Login
let response = try await HaNasAPI.shared.login(
    username: "user",
    password: "pass"
)

// Logout
try await HaNasAPI.shared.logout()

// Get current user
let (userId, username) = try await HaNasAPI.shared.getCurrentUser()
```

#### File Operations
```swift
// Get node (folder or file)
let node = try await HaNasAPI.shared.getNode(id: nodeId)
let rootNode = try await HaNasAPI.shared.getNode() // root

// Download file
let data = try await HaNasAPI.shared.downloadFile(id: fileId)

// Get thumbnail
let thumbnailData = try await HaNasAPI.shared.getThumbnail(id: fileId)

// Upload file (multipart)
let response = try await HaNasAPI.shared.uploadFileMultipart(
    filename: "photo.jpg",
    fileURL: fileURL,
    oyaId: currentFolderId,
    uploadId: UUID().uuidString
)

// Create folder
let response = try await HaNasAPI.shared.createFolder(
    name: "New Folder",
    oyaId: parentFolderId
)

// Delete node
try await HaNasAPI.shared.deleteNode(id: nodeId)

// Rename node
try await HaNasAPI.shared.renameNode(
    id: nodeId,
    newName: "New Name"
)

// Copy node
try await HaNasAPI.shared.copyNode(
    srcId: sourceId,
    dstId: destinationId,
    overwrite: false
)

// Move node
try await HaNasAPI.shared.moveNode(
    id: nodeId,
    newOyaId: newParentId,
    overwrite: false
)
```

#### Sharing
```swift
// Create share link
let token = try await HaNasAPI.shared.createShare(nodeId: fileId)
let shareURL = "\(baseURL)/s/\(token)"

// Delete share
try await HaNasAPI.shared.deleteShare(nodeId: fileId)

// Get shared node (no auth)
let node = try await HaNasAPI.shared.getSharedNode(token: token)

// Download shared file
let data = try await HaNasAPI.shared.downloadSharedFile(token: token)
```

#### Progress Tracking
```swift
// Get upload progress (0-100)
let progress = try await HaNasAPI.shared.getUploadProgress(
    uploadId: uploadId
)
```

### Error Handling

```swift
enum HaNasError: Error {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int)
    case serverError(message: String)
    case decodingError(Error)
}

// Usage
do {
    let node = try await HaNasAPI.shared.getNode(id: 123)
    // Process node
} catch HaNasError.invalidURL {
    print("Invalid server URL")
} catch HaNasError.serverError(let message) {
    print("Server error: \(message)")
} catch {
    print("Unknown error: \(error)")
}
```

## 🎨 Localization

### Supported Languages
- **English** (en)
- **Japanese** (ja) - 日本語
- **Korean** (ko) - 한국어

### Adding New Language

1. **Add Localization in Xcode**
   - Select `Localizable.strings`
   - Click **Localize** in File Inspector
   - Add your language

2. **Translate Strings**
   - Open `[language].lproj/Localizable.strings`
   - Add all translations:
   ```
   "app_name" = "HaNas";
   "login_title" = "Your Translation";
   // ... all keys
   ```

3. **Test**
   - Change device language in Settings
   - Restart app to see translations

### Key Localizable Strings
- Authentication: `login_title`, `register_title`, etc.
- File operations: `upload_photo`, `new_folder`, etc.
- Messages: `empty_folder`, `loading`, etc.

## 🐛 Troubleshooting

### Common Issues

#### "Cannot connect to server"
**Cause**: Network or URL issue  
**Solutions**:
- Verify server URL format: `http://ip:port`
- Check server is running: `curl http://server:8080`
- Ensure same network (for local servers)
- Check firewall settings
- Try server URL in Safari first

#### "Authentication failed"
**Cause**: Wrong credentials or expired token  
**Solutions**:
- Verify username and password
- Try registering new account
- Check server logs for errors
- Clear app data and re-login

#### "Upload fails"
**Cause**: Network, permissions, or server issue  
**Solutions**:
- Check photo library permissions
- Try smaller files first
- Check server disk space
- Verify network connection
- Check server logs

#### "Thumbnails not loading"
**Cause**: Server thumbnail generation issue  
**Solutions**:
- Ensure server has FFmpeg (for videos)
- Check server thumbnail directory permissions
- Wait for thumbnail generation (async)
- Check server logs for errors

#### "App crashes on preview"
**Cause**: Unsupported file format or corrupted file  
**Solutions**:
- Check file format is iOS-compatible
- Try downloading instead of preview
- Update to latest iOS version
- Check Xcode console for crash logs

### Debug Mode

To enable detailed logging:
1. Run app from Xcode
2. Check Console output
3. Look for API request/response logs
4. Check for error messages

## 🔐 Security Notes

### Data Storage
- **Server URL**: Plain text in SQLite (app sandbox)
- **Credentials**: Plain text in SQLite (app sandbox)
- **JWT Token**: HTTP-only cookies, managed by URLSession
- **Files**: Temporary downloads in app sandbox

### Recommendations
- Use HTTPS in production
- Set strong passwords
- Don't share device with untrusted users
- Regular server security updates

### App Sandbox
- All data stored in app's container
- Isolated from other apps
- Deleted when app is uninstalled

## 📊 Performance

### Optimization Techniques
- **Lazy Loading**: LazyVGrid for efficient scrolling
- **Thumbnail Caching**: Images cached by URLSession
- **Async Operations**: All API calls use async/await
- **Memory Management**: Automatic cleanup with ARC
- **Progress Tracking**: Real-time upload feedback

### Best Practices
- Limit concurrent uploads (API handles this)
- Use thumbnails for preview grid
- Download files on-demand
- Clear cache periodically (reinstall app)

## 🤝 Contributing

### Development Setup
1. Clone repository
2. Open project in Xcode
3. Install developer account
4. Run on simulator or device

### Code Style
- Follow Swift conventions
- Use SwiftUI best practices
- Add comments for complex logic
- Write descriptive commit messages

### Testing
- Test on physical devices
- Test different iOS versions
- Test with slow network
- Test error scenarios

## 📄 License

Same as HaNas main project (MIT License)

## 🙏 Acknowledgments

- SwiftUI for modern UI framework
- Combine for reactive programming
- GORM for server database
- JWT for authentication

---

**Native iOS Experience for HaNas File Management**
