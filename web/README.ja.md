# HaNas Web クライアント

React ベースの HaNas Web フロントエンドです。iOS クライアントと同様のスタイルで設計されています。

## 主な機能

- ユーザーログイン・会員登録
- ファイル・フォルダ管理
- ファイルのアップロード・ダウンロード
- ファイル/フォルダのコピー、削除、リネーム、貼り付け
- ファイル名の変更
- ファイル共有リンクの生成
- 複数選択・一括操作
- iOSスタイルのモダンUI

## はじめに

### 事前要件

- Node.js 16 以上
- npm または yarn

### インストール

```bash
cd web
npm install
```

### 開発サーバー起動

```bash
npm run dev
```

ブラウザで http://localhost:3000 にアクセスしてください。

開発サーバーは `/api` 経由のリクエストを `http://localhost:8080` にプロキシします。サーバーが別ポートの場合は `vite.config.js` で設定を変更してください。

### プロダクションビルド

```bash
npm run build
```

ビルド成果物は `dist` フォルダに生成されます。

### プレビュー

```bash
npm run preview
```

## 技術スタック

- **React 18** - UI ライブラリ
- **React Router** - ルーティング
- **Axios** - HTTP クライアント
- **Vite** - ビルドツール

## プロジェクト構成

```
web/
├── src/
│   ├── components/         # Reactコンポーネント
│   │   ├── LoginView.jsx   # ログイン/会員登録画面
│   │   ├── FileListView.jsx # ファイル一覧画面
│   │   └── FileItem.jsx    # ファイル/フォルダアイテム
│   ├── context/            # React Context
│   │   └── AppContext.jsx  # アプリ状態管理
│   ├── utils/              # ユーティリティ
│   │   └── api.js          # APIクライアント
│   ├── App.jsx             # メインアプリコンポーネント
│   ├── main.jsx            # エントリーポイント
│   └── index.css           # グローバルスタイル
├── index.html              # HTMLテンプレート
├── vite.config.js          # Vite設定
└── package.json            # パッケージ情報
```

## サーバー連携

このWebクライアントはHaNasサーバーと連携して動作します。サーバーを先に起動してください。

サーバーの起動方法はプロジェクトルートのREADMEを参照してください。

## ライセンス・著作権

### 利用オープンソースコンポーネント

本プロジェクトは以下のオープンソースアイコンを利用しています：

#### Material Design Icons
- **著作権**: Copyright © Google LLC
- **ライセンス**: Apache License 2.0
- **用途**: UIアイコン (SVGパスデータ)
- **出典**: https://github.com/google/material-design-icons

Apache License 2.0の全文は以下のリンクでご確認いただけます：
http://www.apache.org/licenses/LICENSE-2.0
