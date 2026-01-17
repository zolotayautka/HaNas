
# HaNas Web Client

This is the React-based web frontend for HaNas, designed with a modern UI similar to the iOS client.

## Features

- User login and registration
- File and folder management
- File upload and download
- Copy, cut, and paste files/folders
- Rename files
- Generate shareable file links
- Multi-select and batch operations
- Modern iOS-style UI

## Getting Started

### Prerequisites

- Node.js 16 or higher
- npm or yarn

### Installation

```bash
cd web
npm install
```

### Start Development Server

```bash
npm run dev
```

Open your browser and go to http://localhost:3000

The development server proxies `/api` requests to `http://localhost:8080` by default.
If your server runs on a different port, update the proxy settings in `vite.config.js`.

### Production Build

```bash
npm run build
```

The build output will be generated in the `dist` folder.

### Preview Production Build

```bash
npm run preview
```

## Tech Stack

- **React 18** - UI library
- **React Router** - Routing
- **Axios** - HTTP client
- **Vite** - Build tool

## Project Structure

```
web/
├── src/
│   ├── components/         # React components
│   │   ├── LoginView.jsx   # Login/Register screen
│   │   ├── FileListView.jsx # File list screen
│   │   └── FileItem.jsx    # File/Folder item
│   ├── context/            # React Context
│   │   └── AppContext.jsx  # App state management
│   ├── utils/              # Utilities
│   │   └── api.js          # API client
│   ├── App.jsx             # Main app component
│   ├── main.jsx            # App entry point
│   └── index.css           # Global styles
├── index.html              # HTML template
├── vite.config.js          # Vite config
└── package.json            # Package info
```

## Server Integration

This web client is used together with the HaNas server.
Start the server first, then run the web client.

For server setup instructions, see the project root README.

## License & Attribution

### Open Source Components Used

#### Material Design Icons
- **Copyright**: Copyright © Google LLC
- **License**: Apache License 2.0
- **Usage**: UI icons (SVG path data)
- **Source**: https://github.com/google/material-design-icons

The full text of the Apache License 2.0 is available at:
http://www.apache.org/licenses/LICENSE-2.0
