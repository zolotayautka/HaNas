# NetFS API 문서

NetFS는 웹 기반 파일 저장 시스템으로, 파일 및 폴더 관리를 위한 RESTful API를 제공합니다.

**서버 정보**
- 포트: 80
- 데이터베이스: SQLite (`database.db`)
- 파일 저장 경로: `./data/`
- 썸네일 저장 경로: `./thumbnails/`

## 목차
1. [인증 (Authentication)](#인증-authentication)
2. [파일/폴더 조회 (Read Operations)](#파일폴더-조회-read-operations)
3. [파일/폴더 업로드 (Upload Operations)](#파일폴더-업로드-upload-operations)
4. [파일/폴더 조작 (File Operations)](#파일폴더-조작-file-operations)
5. [공유 기능 (Sharing)](#공유-기능-sharing)
6. [정적 파일 (Static Files)](#정적-파일-static-files)
7. [에러 코드](#에러-코드)

---

## 인증 (Authentication)

### 인증 방식
- JWT 토큰을 `token` 쿠키에 저장
- 유효기간: 24시간
- 인증이 필요한 엔드포인트는 자동으로 쿠키를 확인합니다

---

### POST `/register`
새 사용자 계정을 생성합니다.

**인증**: 불필요

**요청 본문**:
```json
{
  "username": "사용자명",
  "password": "비밀번호"
}
```

**응답 (200 OK)**:
```json
{
  "success": true,
  "user_id": 1,
  "username": "사용자명"
}
```

**쿠키 설정**: `token` (JWT, HttpOnly, 24시간 유효)

**에러**:
- `400`: username 또는 password 누락
- `409`: 이미 존재하는 사용자명
- `500`: 서버 에러

---

### POST `/login`
로그인하여 JWT 토큰을 발급받습니다.

**인증**: 불필요

**요청 본문**:
```json
{
  "username": "사용자명",
  "password": "비밀번호"
}
```

**응답 (200 OK)**:
```json
{
  "success": true,
  "user_id": 1,
  "username": "사용자명"
}
```

**쿠키 설정**: `token` (JWT, HttpOnly, 24시간 유효)

**에러**:
- `400`: 잘못된 JSON
- `401`: 잘못된 인증 정보

---

### POST `/logout`
로그아웃하여 토큰 쿠키를 제거합니다.

**인증**: 불필요

**응답 (200 OK)**:
```json
{
  "success": true
}
```

---

### GET `/me`
현재 로그인된 사용자의 정보를 조회합니다.

**인증**: 필요

**응답 (200 OK)**:
```json
{
  "user_id": 1,
  "username": "사용자명"
}
```

**에러**:
- `401`: 인증되지 않음

---

## 파일/폴더 조회 (Read Operations)

### GET `/node/` 또는 `/node/{id}`
폴더의 내용을 조회합니다. ID를 생략하면 루트 폴더를 반환합니다.

**인증**: 필요

**경로 파라미터**:
- `id` (선택사항): 조회할 노드 ID

**응답 (200 OK)**:
```json
{
  "id": 1,
  "user_id": 1,
  "name": "폴더명",
  "is_dir": true,
  "oya_id": null,
  "updated_at": "2025-12-04T10:00:00Z",
  "size": 0,
  "path": "/폴더명",
  "share_token": "공유토큰(있는경우)",
  "ko": [
    {
      "id": 2,
      "name": "파일.txt",
      "is_dir": false,
      "size": 1024,
      "updated_at": "2025-12-04T09:30:00Z",
      "share_token": ""
    },
    {
      "id": 3,
      "name": "하위폴더",
      "is_dir": true,
      "size": 0,
      "updated_at": "2025-12-04T09:00:00Z"
    }
  ]
}
```

**필드 설명**:
- `id`: 노드 고유 ID
- `user_id`: 소유자 사용자 ID
- `name`: 파일/폴더명
- `is_dir`: 폴더 여부 (true/false)
- `oya_id`: 부모 폴더 ID (null이면 루트)
- `updated_at`: 최종 수정 시간
- `size`: 파일 크기 (바이트, 폴더는 0)
- `path`: 전체 경로
- `share_token`: 공유 토큰 (공유된 경우에만)
- `ko`: 하위 파일/폴더 목록 배열

**에러**:
- `401`: 인증되지 않음

---

### GET `/file/{id}`
파일을 다운로드합니다.

**인증**: 필요

**경로 파라미터**:
- `id`: 파일 노드 ID

**쿼리 파라미터**:
- `inline`: `1` 또는 `true` 설정 시 브라우저에서 바로 열기 (다운로드 대신)

**응답 (200 OK)**:
- Content-Type: 파일의 MIME 타입
- Content-Disposition: attachment 또는 inline
- Body: 파일 바이너리 데이터

**에러**:
- `401`: 인증되지 않음
- `404`: 파일을 찾을 수 없음
- `500`: 파일 열기 실패

**예시**:
```
GET /file/123
GET /file/123?inline=1
```

---

### GET `/thumbnail/{id}`
이미지 또는 비디오 파일의 썸네일을 생성하거나 조회합니다.

**인증**: 필요

**경로 파라미터**:
- `id`: 파일 노드 ID

**지원 형식**:
- **이미지**: `.jpg`, `.jpeg`, `.png`, `.gif`, `.webp`, `.bmp`
- **비디오**: `.mp4`, `.webm`, `.ogg`, `.mov`, `.mkv`, `.avi` (ffmpeg 필요)

**응답 (200 OK)**:
- Content-Type: image/jpeg
- Cache-Control: public, max-age=86400
- Body: 200x200 JPEG 썸네일

**에러**:
- `400`: 지원하지 않는 파일 형식
- `401`: 인증되지 않음
- `404`: 파일을 찾을 수 없음 또는 썸네일 생성 실패
- `500`: 서버 에러

**참고**:
- 생성된 썸네일은 `./thumbnails/` 디렉토리에 캐시됩니다
- 비디오 썸네일 생성에는 ffmpeg가 필요합니다

---

## 파일/폴더 업로드 (Upload Operations)

### POST `/upload`
파일 또는 폴더를 업로드합니다.

**인증**: 필요

**요청 방식 1: Multipart Form Data**

**폼 필드**:
- `filename`: 파일/폴더명
- `is_dir`: 폴더 생성 시 `true` 또는 `1`
- `oya_id`: 부모 폴더 ID (생략 시 루트)
- `file`: 파일 데이터 (파일인 경우)
- `upload_id`: 진행률 추적용 ID (선택사항)

**예시 (curl)**:
```bash
# 파일 업로드
curl -X POST http://localhost/upload \
  -H "Cookie: token=YOUR_JWT_TOKEN" \
  -F "filename=example.txt" \
  -F "oya_id=1" \
  -F "file=@/path/to/example.txt"

# 폴더 생성
curl -X POST http://localhost/upload \
  -H "Cookie: token=YOUR_JWT_TOKEN" \
  -F "filename=새폴더" \
  -F "is_dir=true" \
  -F "oya_id=1"
```

**요청 방식 2: JSON (Base64)**

**요청 본문**:
```json
{
  "filename": "파일명.txt",
  "is_dir": false,
  "oya_id": 1,
  "data_base64": "SGVsbG8gV29ybGQh"
}
```

**응답 (200 OK)**:
```json
{
  "success": true,
  "node_id": 123,
  "name": "파일명.txt"
}
```

**에러**:
- `400`: filename 누락 또는 잘못된 요청
- `401`: 인증되지 않음
- `409`: 같은 이름의 폴더가 이미 존재 (folder_exists)
- `500`: 업로드 실패

**참고**:
- 같은 이름의 파일이 이미 존재하면 덮어씁니다 (폴더는 충돌 시 에러)
- 최대 업로드 크기: 1024MB (multipart form)

---

### GET `/upload/progress?upload_id={id}`
파일 업로드 진행률을 실시간으로 조회합니다 (Server-Sent Events).

**인증**: 불필요

**쿼리 파라미터**:
- `upload_id`: `/upload` 요청 시 전달한 ID

**응답 (200 OK, text/event-stream)**:
```
data: 0

data: 25

data: 50

data: 100
```

**참고**:
- SSE (Server-Sent Events) 프로토콜 사용
- 30초마다 keepalive 메시지 전송
- 100% 완료 시 연결 자동 종료

**예시 (JavaScript)**:
```javascript
const eventSource = new EventSource('/upload/progress?upload_id=abc123');
eventSource.onmessage = (event) => {
  console.log('Progress:', event.data + '%');
  if (event.data === '100') {
    eventSource.close();
  }
};
```

---

## 파일/폴더 조작 (File Operations)

### POST `/copy`
파일 또는 폴더를 복사합니다.

**인증**: 필요

**요청 본문**:
```json
{
  "src_id": 1,
  "dst_id": 2,
  "overwrite": false
}
```

**필드 설명**:
- `src_id`: 복사할 노드 ID
- `dst_id`: 대상 폴더 ID
- `overwrite`: 같은 이름 존재 시 덮어쓰기 여부 (true/false)

**응답 (200 OK)**:
```json
{
  "success": true,
  "name": "복사된파일명.txt"
}
```

**에러**:
- `400`: src_id 또는 dst_id 누락
- `401`: 인증되지 않음
- `404`: 원본을 찾을 수 없음
- `409`: 같은 이름 존재 (overwrite=false인 경우)
- `500`: 복사 실패

**참고**:
- 폴더 복사 시 모든 하위 항목도 재귀적으로 복사됩니다

---

### POST `/move`
파일 또는 폴더를 이동합니다.

**인증**: 필요

**요청 본문**:
```json
{
  "src_id": 1,
  "dst_id": 2,
  "overwrite": false
}
```

**필드 설명**: `/copy`와 동일

**응답 (200 OK)**:
```json
{
  "success": true,
  "name": "이동된파일명.txt"
}
```

**에러**:
- `400`: 자기 자신이나 하위 폴더로 이동 시도
- `401`: 인증되지 않음
- `404`: 원본을 찾을 수 없음
- `409`: 같은 이름 존재 (overwrite=false인 경우)
- `500`: 이동 실패

**참고**:
- 폴더를 자신의 하위 폴더로 이동할 수 없습니다

---

### POST `/rename`
파일 또는 폴더의 이름을 변경합니다.

**인증**: 필요

**요청 본문**:
```json
{
  "src_id": 1,
  "new_name": "새이름.txt"
}
```

**필드 설명**:
- `src_id`: 이름을 변경할 노드 ID
- `new_name`: 새 이름

**응답 (200 OK)**:
```json
{
  "success": true
}
```

**에러**:
- `400`: src_id 또는 new_name 누락
- `401`: 인증되지 않음
- `404`: 파일/폴더를 찾을 수 없음
- `500`: 이름 변경 실패

---

### POST `/delete`
파일 또는 폴더를 삭제합니다.

**인증**: 필요

**요청 본문**:
```json
{
  "src_id": 1
}
```

**필드 설명**:
- `src_id`: 삭제할 노드 ID

**응답 (200 OK)**:
```json
{
  "success": true
}
```

**에러**:
- `400`: src_id 누락
- `401`: 인증되지 않음
- `404`: 파일/폴더를 찾을 수 없음
- `500`: 삭제 실패

**참고**:
- 폴더 삭제 시 모든 하위 항목도 재귀적으로 삭제됩니다
- 실제 파일 데이터도 `./data/` 디렉토리에서 제거됩니다

---

## 공유 기능 (Sharing)

### POST `/share/create`
파일에 대한 공유 링크를 생성합니다.

**인증**: 필요

**요청 본문**:
```json
{
  "node_id": 1
}
```

**필드 설명**:
- `node_id`: 공유할 파일 노드 ID

**응답 (200 OK)**:
```json
{
  "success": true,
  "token": "랜덤생성된토큰"
}
```

**에러**:
- `400`: node_id 누락
- `401`: 인증되지 않음
- `404`: 노드를 찾을 수 없음
- `500`: 공유 생성 실패

**참고**:
- 이미 공유 링크가 존재하면 기존 토큰을 반환합니다
- 공유 링크: `http://서버주소/s/{token}`

---

### POST `/share/delete`
파일의 공유 링크를 삭제합니다.

**인증**: 필요

**요청 본문**:
```json
{
  "node_id": 1
}
```

**필드 설명**:
- `node_id`: 공유를 삭제할 파일 노드 ID

**응답 (200 OK)**:
```json
{
  "success": true
}
```

**에러**:
- `400`: node_id 누락
- `401`: 인증되지 않음
- `500`: 삭제 실패

---

### GET `/s/{token}`
공유 링크를 통해 파일을 다운로드합니다 (공개 엔드포인트).

**인증**: 불필요

**경로 파라미터**:
- `token`: 공유 토큰

**쿼리 파라미터**:
- `inline`: `1` 또는 `true` 설정 시 브라우저에서 바로 열기

**응답 (200 OK)**:
- Content-Type: 파일의 MIME 타입
- Content-Disposition: attachment 또는 inline
- Body: 파일 바이너리 데이터

**에러**:
- `400`: 폴더는 공유 불가
- `404`: 공유 링크를 찾을 수 없음
- `410`: 공유 링크가 만료됨
- `500`: 파일 열기 실패

**예시**:
```
GET /s/abc123xyz
GET /s/abc123xyz?inline=1
```

---

## 정적 파일 (Static Files)

### GET `/`
웹 UI HTML 페이지를 반환합니다.

**인증**: 불필요

**응답**: `index.html` 내용

---

### GET `/index.js`
웹 UI JavaScript 파일을 반환합니다.

**인증**: 불필요

**응답**: `index.js` 내용

---

### GET `/i18n.js`
다국어 지원 스크립트를 반환합니다.

**인증**: 불필요

**응답**: `i18n.js` 내용

---

## 에러 코드

| 상태 코드 | 설명 |
|---------|------|
| 200 | 성공 |
| 400 | 잘못된 요청 (필수 파라미터 누락, 잘못된 JSON 등) |
| 401 | 인증 필요 또는 인증 실패 |
| 404 | 리소스를 찾을 수 없음 |
| 409 | 충돌 (중복된 이름 등) |
| 410 | 리소스가 만료됨 |
| 415 | 지원하지 않는 Content-Type |
| 500 | 서버 내부 에러 |

---

## 사용 예시

### Python 클라이언트 예시

```python
import requests

BASE_URL = "http://localhost"

# 회원가입
response = requests.post(f"{BASE_URL}/register", json={
    "username": "user1",
    "password": "pass123"
})
session = requests.Session()
session.cookies.update(response.cookies)

# 파일 업로드
with open("test.txt", "rb") as f:
    response = session.post(f"{BASE_URL}/upload", files={
        "file": f,
        "filename": (None, "test.txt"),
        "oya_id": (None, "1")
    })
    print(response.json())

# 폴더 내용 조회
response = session.get(f"{BASE_URL}/node/1")
print(response.json())

# 파일 다운로드
response = session.get(f"{BASE_URL}/file/2")
with open("downloaded.txt", "wb") as f:
    f.write(response.content)

# 공유 링크 생성
response = session.post(f"{BASE_URL}/share/create", json={"node_id": 2})
share_token = response.json()["token"]
print(f"공유 링크: {BASE_URL}/s/{share_token}")
```

### JavaScript (Fetch API) 예시

```javascript
const BASE_URL = 'http://localhost';

// 로그인
async function login(username, password) {
  const response = await fetch(`${BASE_URL}/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ username, password }),
    credentials: 'include'
  });
  return response.json();
}

// 파일 업로드 (진행률 포함)
async function uploadFile(file, oyaId, uploadId) {
  const formData = new FormData();
  formData.append('file', file);
  formData.append('filename', file.name);
  formData.append('oya_id', oyaId);
  formData.append('upload_id', uploadId);

  // 진행률 모니터링
  const eventSource = new EventSource(`${BASE_URL}/upload/progress?upload_id=${uploadId}`);
  eventSource.onmessage = (event) => {
    console.log('Upload progress:', event.data + '%');
    if (event.data === '100') {
      eventSource.close();
    }
  };

  const response = await fetch(`${BASE_URL}/upload`, {
    method: 'POST',
    body: formData,
    credentials: 'include'
  });

  return response.json();
}

// 폴더 내용 조회
async function getFolder(nodeId = '') {
  const response = await fetch(`${BASE_URL}/node/${nodeId}`, {
    credentials: 'include'
  });
  return response.json();
}

// 파일 삭제
async function deleteFile(nodeId) {
  const response = await fetch(`${BASE_URL}/delete`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ src_id: nodeId }),
    credentials: 'include'
  });
  return response.json();
}
```

---

## 데이터베이스 스키마

### Users 테이블
```sql
CREATE TABLE users (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  username TEXT UNIQUE NOT NULL,
  password TEXT NOT NULL,
  created_at DATETIME
);
```

### Nodes 테이블
```sql
CREATE TABLE nodes (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL,
  fid INTEGER UNIQUE,
  name TEXT NOT NULL,
  is_dir BOOLEAN NOT NULL,
  oya_id INTEGER,
  updated_at DATETIME,
  FOREIGN KEY (user_id) REFERENCES users(id),
  FOREIGN KEY (oya_id) REFERENCES nodes(id) ON DELETE CASCADE
);
```

### Shares 테이블
```sql
CREATE TABLE shares (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  token TEXT UNIQUE NOT NULL,
  node_id INTEGER NOT NULL,
  user_id INTEGER NOT NULL,
  created_at DATETIME,
  expires_at DATETIME,
  FOREIGN KEY (node_id) REFERENCES nodes(id),
  FOREIGN KEY (user_id) REFERENCES users(id)
);
```

---

## 주의사항

1. **보안**: 프로덕션 환경에서는 `jwtSecret` 상수를 반드시 변경하세요
2. **HTTPS**: 프로덕션에서는 HTTPS를 사용하여 쿠키와 데이터를 보호하세요
3. **ffmpeg**: 비디오 썸네일 생성을 위해서는 시스템에 ffmpeg가 설치되어 있어야 합니다
4. **포트**: 기본 포트는 80입니다. 변경이 필요한 경우 `main()` 함수를 수정하세요
5. **파일 크기**: 대용량 파일 업로드 시 서버 메모리와 타임아웃 설정을 고려하세요
