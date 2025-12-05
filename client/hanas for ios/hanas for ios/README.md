# HaNas iOS

iOS client for HaNas file management system.

## Features

- Login and registration
- Browse files and folders
- Upload photos and documents
- Download and preview files (images, videos)
- Create, rename, and delete folders
- Grid-based file browsing optimized for touch
- Native iOS UI with SwiftUI

## Requirements

- iOS 15.0 or later
- Xcode 14.0 or later
- Swift 5.7 or later

## Installation

1. Open the project in Xcode
2. Select your development team in the signing settings
3. Build and run on your device or simulator

## Usage

1. Launch the app
2. Enter your HaNas server URL (e.g., `http://192.168.1.100`)
3. Login with your credentials or register a new account
4. Browse and manage your files

## Configuration

The app stores server configuration securely in the iOS Documents directory using SQLite.

## Permissions

The app requires the following permissions:
- Photo Library access (for uploading photos)
- File access (for uploading documents)

## Notes

- Make sure your HaNas server is accessible from your iOS device
- For local network access, ensure your device is on the same network as the server
- The app supports both Wi-Fi and cellular connections

## License

Same as the HaNas project.
