# HaNas

[한국어](./README.ko.md) | [日本語](./README.ja.md) | **English**

A lightweight, secure file management system with web and native mobile clients. Upload, organize, share, and stream media files across all your devices.

## 🌟 Features

### Core Features
- 📁 **File Management**: Create folders, upload files, copy, move, rename, and delete
- 🔐 **User Authentication**: Secure JWT-based authentication with user registration
- 🎵 **Media Playback**: Built-in audio and video player for common formats
- 🖼️ **Thumbnail Generation**: Automatic thumbnail creation for images and videos
- 🔗 **File Sharing**: Share files and folders with unique shareable links
- 📊 **Upload Progress**: Real-time upload progress tracking with multipart support
- 🔄 **File Overwrite**: Automatically updates existing files when re-uploaded
- 🌍 **Multi-language**: Support for Japanese, Korean, and English

### Platform Support
- 🌐 **Web Interface**: Responsive web UI with drag-and-drop support
- 📱 **iOS Native Client**: Full-featured SwiftUI app for iPhone and iPad
- 💻 **macOS Native Client**: Native Mac application
- 📦 **Single Binary Server**: All assets embedded, no external dependencies

## Supported Media Formats

**Audio**: MP3, M4A, WAV, OGG, FLAC, AAC  
**Video**: MP4, WebM, OGG, MOV, MKV  
**Images**: JPG, PNG, GIF, WebP (with thumbnail support)

## 🚀 Installation

### Server Setup

#### Prerequisites
- Go 1.16 or higher

#### Build from source

```bash
git clone https://github.com/zolotayautka/HaNas.git
cd HaNas/server
go build -o hanas
```

#### Usage

1. Start the server:
```bash
./hanas
```

2. Open your browser and navigate to:
```
http://localhost:80
```

3. Register a new account and start managing your files!

### iOS Client Setup

#### Prerequisites
- iOS 15.0 or later
- Xcode 14.0 or later
- Swift 5.7 or later

#### Installation

1. Open `client/hanas for ios/Hanas for ios.xcodeproj` in Xcode
2. Select your development team in signing settings
3. Build and run on your device or simulator

#### Usage

1. Launch the app
2. Enter your HaNas server URL (e.g., `http://192.168.1.100`)
3. Login with your credentials or register a new account
4. Browse and manage your files with native iOS interface

### macOS Client Setup

1. Open `client/HaNas for Mac/HaNas for Mac.xcodeproj` in Xcode
2. Build and run the native Mac application

## ⚙️ Configuration

### Server Configuration
- **Port**: Default is `80` (modify in `main()` function)
- **Data Directory**: `./data` (file storage location)
- **Thumbnails Directory**: `./thumbnails` (thumbnail cache)
- **Database**: `./database.db` (SQLite database)
- **JWT Secret**: Configure in production (see Security section)

### iOS Client Configuration
- **Server URL**: Configured during first login
- **Credentials**: Securely stored in app's Documents directory using SQLite
- **Auto-login**: Automatic authentication on app launch

## 📡 API Endpoints

For detailed API documentation, see [API_README.md](./API_README.md)

### Authentication
- `POST /register` - Create new user account
- `POST /login` - Login and receive JWT token
- `POST /logout` - Logout and clear token
- `GET /me` - Get current user information

### File Operations
- `GET /node/:id` - Get node information and children
- `GET /file/:id` - Download or stream file
- `GET /thumbnail/:id` - Get thumbnail for image/video
- `POST /upload` - Upload file or create folder (supports multipart)
- `POST /copy` - Copy file/folder
- `POST /move` - Move file/folder
- `POST /rename` - Rename file/folder
- `POST /delete` - Delete file/folder

### Sharing
- `POST /share/create` - Create shareable link for node
- `POST /share/delete` - Delete share link
- `GET /s/:token` - Access shared node (no auth required)
- `GET /share/:token/download` - Download shared file

### Progress Tracking
- `GET /progress/:upload_id` - Get upload progress (0-100)

## 📂 Project Structure

```
HaNas/
├── client/                        
│   ├── HaNas for Ios/
│   │   ├── HaNas/                 
│   │   └── HaNas.xcodeproj/       
│   └── HaNas for Mac/
│       ├── HaNas/                 
│       └── HaNas.xcodeproj/       
├── server/                        
│   ├── app.go                     
│   ├── config.js                  
│   ├── go.mod, go.sum             
│   ├── index.html                 
│   └── assets/                    
├── web/                           
│   ├── public/                    
│   ├── src/                       
│   │   ├── components/            
│   │   ├── context/               
│   │   ├── locales/               
│   │   └── utils/                 
│   ├── index.html                 
│   └── vite.config.js             
├── README.md                      
├── README.ko.md
└── README.ja.md
```

## 🔧 Technical Details

### Backend (Server)
- **Language**: Go
- **Database**: SQLite with GORM
- **Authentication**: JWT with HTTP-only cookies (24h expiration)
- **Key Features**: 
  - User authentication and registration
  - File streaming with Range request support
  - Real-time upload progress tracking
  - Automatic thumbnail generation for images and videos
  - Shareable links with token-based access
  - MIME type detection
  - Hierarchical folder structure with cascade delete
  - Concurrent upload handling with mutex locks
  - Base64 and multipart file upload support

### Web Frontend
- **Technology**: Vanilla JavaScript (no frameworks)
- **Features**:
  - Drag-and-drop file upload
  - Real-time upload progress with SSE
  - Integrated media player
  - Image thumbnail previews
  - File sharing UI
  - Responsive grid layout
  - Browser language detection

### iOS Client
- **Language**: Swift 5.7+
- **Framework**: SwiftUI
- **Target**: iOS 15.0+
- **Architecture**: MVVM with Combine
- **Key Features**:
  - Native iOS file picker integration
  - Photo library access
  - Document picker for all file types
  - PDF preview support
  - Video/Audio player with AVKit
  - Grid-based file browsing
  - Context menu actions (copy, cut, paste, delete, rename)
  - Persistent authentication with secure storage
  - Multi-language support (en, ja, ko)
  - Thumbnail caching

### macOS Client
- **Language**: Swift
- **Framework**: SwiftUI
- **Target**: macOS 12.0+
- **Features**: Similar to iOS client with Mac-optimized UI

## 🌍 Language Support

The interface automatically detects your browser/device language and displays in:
- 🇯🇵 **Japanese** (ja) - 日本語
- 🇰🇷 **Korean** (ko) - 한국어
- 🇬🇧 **English** (en) - default

### Supported Platforms
- Web interface (browser language detection)
- iOS app (device language settings)
- macOS app (system language settings)

## 🔐 Security Features

- **Password Hashing**: bcrypt with cost factor 14
- **JWT Authentication**: HTTP-only cookies with 24-hour expiration
- **Secure Token Storage**: Platform-specific secure storage (iOS/Mac)
- **File Access Control**: User-based file isolation
- **Share Tokens**: UUID-based shareable links
- **API Authorization**: Middleware-based authentication on all protected endpoints

## 🛡️ Security Considerations for Production

⚠️ **This is designed for personal/development use**. For production deployment:

### Critical Security Updates Needed
1. **Change JWT Secret**: Update `jwtSecret` in `app.go` to a strong, random value
2. **Enable HTTPS**: Add TLS/SSL certificate support
3. **Add Rate Limiting**: Prevent brute force attacks on authentication
4. **File Upload Limits**: Set maximum file size and concurrent uploads
5. **Input Sanitization**: Enhance file name and path validation
6. **CORS Configuration**: Restrict cross-origin requests
7. **Environment Variables**: Move secrets to environment configuration
8. **Database Security**: Use proper database credentials and encryption
9. **Audit Logging**: Implement comprehensive logging for security events
10. **Update Dependencies**: Regular security updates for Go modules

### Network Security
- Deploy behind reverse proxy (nginx, Apache)
- Use firewall rules to restrict access
- Consider VPN for remote access
- Enable HTTPS-only connections

## 🛠️ Development

### Adding a New Language

#### Server (Web Interface)

1. Edit `server/i18n.js` and add your language code:
```javascript
const i18n = {
  // ... existing languages
  fr: {
    home: 'Accueil',
    upload: 'Télécharger',
    // ... add all translations
  }
};
```

2. Update `server/index.js` language detection:
```javascript
if(userLang.startsWith('ja')) lang = 'ja';
else if(userLang.startsWith('ko')) lang = 'ko';
else if(userLang.startsWith('fr')) lang = 'fr'; // add this
else lang = 'en';
```

#### iOS/Mac Client

1. Add new `.lproj` folder in Xcode (e.g., `fr.lproj/`)
2. Create `Localizable.strings` file with translations:
```
"app_name" = "HaNas";
"login_title" = "Connexion";
// ... add all keys
```

### Modifying Supported Media Formats

Edit the `isMediaByName()` function in `server/index.js`:
```javascript
const audio = ['mp3','m4a','wav','ogg','flac','aac','your-format'];
const video = ['mp4','webm','ogg','mov','mkv','your-format'];
```

## 🖼️ Material Design Icons Attribution (English)

This project uses Material Design Icons SVG path data for UI icons.
- **Copyright**: Copyright © Google LLC
- **License**: Apache License 2.0
- **Usage**: UI icons (SVG path data)
- **Source**: https://github.com/google/material-design-icons

The full text of the Apache License 2.0 is available at:
http://www.apache.org/licenses/LICENSE-2.0

### Adding New API Endpoints

1. Define handler function in `server/app.go`
2. Register route in `main()` function
3. Add authentication middleware if needed:
```go
http.HandleFunc("/your-endpoint", authMiddleware(yourHandler))
```

### iOS Client Development

#### Key Components
- **HaNasAPI**: Singleton API client (`exec.swift`)
- **AppState**: Global authentication state
- **ConfigManager**: Persistent configuration storage
- **FileListView**: Main file browser with grid layout

#### API Client Usage
```swift
// Example: Upload file
let api = HaNasAPI.shared
let response = try await api.uploadFileMultipart(
    filename: "photo.jpg",
    fileURL: fileURL,
    oyaId: currentFolderId
)
```

## 🐛 Troubleshooting

### Server Issues

**Issue**: Server won't start  
**Solution**: 
- Check if port 8080 is available: `lsof -i :8080`
- Ensure `./data` and `./thumbnails` directories are writable
- Check database file permissions

**Issue**: Upload fails with large files  
**Solution**: 
- Check available disk space
- Consider increasing server timeout settings
- Use multipart upload for files > 10MB

**Issue**: Thumbnail generation fails  
**Solution**: 
- Ensure FFmpeg is installed for video thumbnails
- Check thumbnail directory write permissions
- Verify image format is supported

### Web Client Issues

**Issue**: Cannot upload file with same name as folder  
**Solution**: This is by design to prevent conflicts. Rename the file or folder first.

**Issue**: Media file won't play  
**Solution**: Check if the file format is supported. The browser may not support all codecs even if the container format is listed.

**Issue**: Upload progress stuck at 0%  
**Solution**: Check browser console for errors. Ensure the upload_id parameter is being generated correctly.

### iOS/Mac Client Issues

**Issue**: Cannot connect to server  
**Solution**: 
- Verify server URL is correct (include http:// or https://)
- Ensure device is on same network as server
- Check firewall settings on server
- Try accessing server URL in Safari first

**Issue**: Login fails but credentials are correct  
**Solution**: 
- Clear app data and try again
- Check server logs for authentication errors
- Verify JWT token is being set in cookies

**Issue**: Files won't upload from iOS  
**Solution**: 
- Grant photo library permission in Settings
- Check available storage on device
- Try smaller files first to test connection
- Check server logs for upload errors

**Issue**: App crashes on file preview  
**Solution**: 
- File format may not be supported on iOS
- Try updating to latest iOS version
- Check console logs in Xcode for error details

## 📱 iOS Client Permissions

The iOS app requires these permissions:
- **Photo Library** (`NSPhotoLibraryUsageDescription`): To upload photos and videos
- **Files Access** (`UIFileSharingEnabled`): To access and upload documents
- **Network** (automatic): To communicate with HaNas server

Permissions are requested only when needed.

## 🗺️ Roadmap

### Planned Features
- [ ] End-to-end encryption
- [ ] Real-time collaboration
- [ ] File versioning
- [ ] Advanced search with filters
- [ ] Batch operations
- [ ] Android client
- [ ] Linux/Windows desktop clients
- [ ] Docker containerization
- [ ] Cloud storage integration (S3, etc.)
- [ ] Two-factor authentication
- [ ] User groups and permissions
- [ ] Activity logs and analytics

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

### Contribution Guidelines
1. Fork the repository
2. Create a feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

### Development Setup
- Follow Go best practices for server code
- Use SwiftLint for iOS/Mac client code
- Write unit tests for new features
- Update documentation for API changes

## 📞 Support

- **Issues**: Use GitHub Issues for bug reports and feature requests
- **Documentation**: See [API_README.md](./API_README.md) for detailed API docs
- **iOS Client**: See [client/hanas for ios/hanas for ios/README.md](./client/hanas%20for%20ios/hanas%20for%20ios/README.md)

## 🙏 Acknowledgments

- GORM for database ORM
- JWT for authentication
- FFmpeg for video thumbnails
- nfnt/resize for image processing

---

Made with ❤️ using Go, Swift, and vanilla JavaScript

**Multi-platform File Management for Everyone**
