# HaNas Web Client

React 기반의 HaNas 웹 프론트엔드입니다. iOS 클라이언트와 비슷한 스타일로 디자인되었습니다.

## 주요 기능

- 사용자 로그인 및 회원가입
- 파일 및 폴더 관리
- 파일 업로드 및 다운로드
- 파일/폴더 복사, 잘라내기, 붙여넣기
- 파일 이름 변경
- 파일 공유 링크 생성
- 다중 선택 및 일괄 작업
- iOS 스타일의 모던한 UI

## 시작하기

### 사전 요구사항

- Node.js 16 이상
- npm 또는 yarn

### 설치

```bash
cd web
npm install
```

### 개발 서버 실행

```bash
npm run dev
```

브라우저에서 http://localhost:3000 으로 접속합니다.

개발 서버는 `/api` 경로를 `http://localhost:8080` 으로 프록시합니다.
서버가 다른 포트에서 실행 중이라면 `vite.config.js` 파일에서 프록시 설정을 변경하세요.

### 프로덕션 빌드

```bash
npm run build
```

빌드된 파일은 `dist` 폴더에 생성됩니다.

### 빌드 미리보기

```bash
npm run preview
```

## 기술 스택

- **React 18** - UI 라이브러리
- **React Router** - 라우팅
- **Axios** - HTTP 클라이언트
- **Vite** - 빌드 도구

## 프로젝트 구조

```
web/
├── src/
│   ├── components/         # React 컴포넌트
│   │   ├── LoginView.jsx   # 로그인/회원가입 화면
│   │   ├── FileListView.jsx # 파일 목록 화면
│   │   └── FileItem.jsx    # 파일/폴더 아이템
│   ├── context/            # React Context
│   │   └── AppContext.jsx  # 앱 상태 관리
│   ├── utils/              # 유틸리티
│   │   └── api.js          # API 클라이언트
│   ├── App.jsx             # 메인 앱 컴포넌트
│   ├── main.jsx            # 앱 진입점
│   └── index.css           # 전역 스타일
├── index.html              # HTML 템플릿
├── vite.config.js          # Vite 설정
└── package.json            # 패키지 정보
```

## 서버 연동

이 웹 클라이언트는 HaNas 서버와 함께 사용됩니다.
서버를 먼저 실행한 후 웹 클라이언트를 실행하세요.

서버 실행 방법은 프로젝트 루트의 README를 참조하세요.

## 라이선스 및 저작권

### 사용된 오픈소스 컴포넌트

이 프로젝트는 다음 오픈소스 아이콘을 사용합니다:

#### Material Design Icons
- **저작권**: Copyright © Google LLC
- **라이선스**: Apache License 2.0
- **사용**: UI 아이콘 (SVG path 데이터)
- **출처**: https://github.com/google/material-design-icons

Apache License 2.0의 전문은 다음 링크에서 확인할 수 있습니다:
http://www.apache.org/licenses/LICENSE-2.0
