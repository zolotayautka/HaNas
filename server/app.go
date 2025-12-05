package main

import (
	"bytes"
	_ "embed"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"image"
	_ "image/gif"
	"image/jpeg"
	_ "image/png"
	"io"
	mrand "math/rand"
	"mime"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/nfnt/resize"
	"golang.org/x/crypto/bcrypt"
	"gorm.io/driver/sqlite"
	"gorm.io/gorm"
)

const (
	dataDir     = "./data"
	thumbDir    = "./thumbnails"
	dbFile      = "./database.db"
	programName = "HaNas"
	jwtSecret   = "your-secret-key-change-this-in-production"
)

var db *gorm.DB

var progressChannels = struct {
	sync.RWMutex
	m map[string]chan int
}{m: make(map[string]chan int)}

var (
	fileLocks = struct {
		sync.RWMutex
		m map[uint]*sync.RWMutex
	}{m: make(map[uint]*sync.RWMutex)}
	nodeLocks = struct {
		sync.RWMutex
		m map[uint]*sync.Mutex
	}{m: make(map[uint]*sync.Mutex)}
	uploadMutex    sync.Mutex
	thumbnailMutex sync.Map
)

type User struct {
	ID        uint      `gorm:"primaryKey;autoIncrement" json:"id"`
	Username  string    `gorm:"uniqueIndex;not null" json:"username"`
	Password  string    `gorm:"not null" json:"-"`
	CreatedAt time.Time `gorm:"autoCreateTime" json:"created_at"`
}

type Claims struct {
	UserID   uint   `json:"user_id"`
	Username string `json:"username"`
	jwt.RegisteredClaims
}

type Share struct {
	ID        uint       `gorm:"primaryKey;autoIncrement" json:"id"`
	Token     string     `gorm:"uniqueIndex;not null" json:"token"`
	NodeID    uint       `gorm:"not null;index" json:"node_id"`
	UserID    uint       `gorm:"not null;index" json:"user_id"`
	CreatedAt time.Time  `gorm:"autoCreateTime" json:"created_at"`
	ExpiresAt *time.Time `json:"expires_at,omitempty"`
}

type Node struct {
	ID         uint      `gorm:"primaryKey;autoIncrement" json:"id"`
	UserID     uint      `gorm:"not null;index" json:"user_id"`
	Fid        *uint     `gorm:"uniqueIndex;check:((is_dir = true AND fid IS NULL) OR (is_dir = false AND fid IS NOT NULL))" json:"-"`
	Name       string    `gorm:"not null" json:"name"`
	IsDir      bool      `gorm:"not null" json:"is_dir"`
	OyaID      *uint     `gorm:"index" json:"oya_id,omitempty"`
	Ko         []Node    `gorm:"foreignKey:OyaID;references:ID;constraint:OnDelete:CASCADE" json:"ko,omitempty"`
	UpdatedAt  time.Time `gorm:"autoUpdateTime" json:"updated_at"`
	Size       int64     `gorm:"-" json:"size,omitempty"`
	Path       string    `gorm:"-" json:"path,omitempty"`
	ShareToken string    `gorm:"-" json:"share_token,omitempty"`
}

func (n Node) to_json() []byte {
	data, _ := json.Marshal(n)
	return data
}

func (n Node) return_file() []byte {
	if n.Fid == nil {
		return nil
	}
	p := dataDir + "/" + fmt.Sprintf("%d", *n.Fid)
	data, _ := os.ReadFile(p)
	return data
}

func return_root(userID uint) Node {
	var root Node
	db.Preload("Ko").First(&root, "oya_id IS NULL AND user_id = ?", userID)
	return root
}

func hashPassword(password string) (string, error) {
	bytes, err := bcrypt.GenerateFromPassword([]byte(password), 14)
	return string(bytes), err
}

func checkPasswordHash(password, hash string) bool {
	err := bcrypt.CompareHashAndPassword([]byte(hash), []byte(password))
	return err == nil
}

func generateToken(userID uint, username string) (string, error) {
	claims := &Claims{
		UserID:   userID,
		Username: username,
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(time.Now().Add(876000 * time.Hour)), // ~100 years
			IssuedAt:  jwt.NewNumericDate(time.Now()),
		},
	}
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	return token.SignedString([]byte(jwtSecret))
}

func authMiddleware(next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		cookie, err := r.Cookie("token")
		if err != nil {
			http.Error(w, "Unauthorized", http.StatusUnauthorized)
			return
		}
		tokenStr := cookie.Value
		claims := &Claims{}
		token, err := jwt.ParseWithClaims(tokenStr, claims, func(token *jwt.Token) (interface{}, error) {
			return []byte(jwtSecret), nil
		})
		if err != nil || !token.Valid {
			http.Error(w, "Unauthorized", http.StatusUnauthorized)
			return
		}
		r.Header.Set("X-User-ID", fmt.Sprintf("%d", claims.UserID))
		r.Header.Set("X-Username", claims.Username)
		next.ServeHTTP(w, r)
	}
}

func getUserIDFromRequest(r *http.Request) (uint, error) {
	userIDStr := r.Header.Get("X-User-ID")
	if userIDStr == "" {
		return 0, fmt.Errorf("user ID not found in request")
	}
	userID, err := strconv.ParseUint(userIDStr, 10, 64)
	if err != nil {
		return 0, err
	}
	return uint(userID), nil
}

func UploadFile(data []byte) (uint, error) {
	if err := os.MkdirAll(dataDir, 0755); err != nil {
		return 0, fmt.Errorf("cannot create data dir: %w", err)
	}
	uploadMutex.Lock()
	r := mrand.New(mrand.NewSource(time.Now().UnixNano()))
	var filename uint
	for {
		filename = uint(r.Intn(100000000))
		filepath := fmt.Sprintf("%s/%d", dataDir, filename)
		file, err := os.OpenFile(filepath, os.O_CREATE|os.O_EXCL|os.O_WRONLY, 0644)
		if err != nil {
			if os.IsExist(err) {
				continue
			}
			uploadMutex.Unlock()
			return 0, fmt.Errorf("cannot create file: %w", err)
		}
		uploadMutex.Unlock()
		_, err = file.Write(data)
		file.Close()
		if err != nil {
			return 0, fmt.Errorf("cannot write file: %w", err)
		}
		break
	}
	return filename, nil
}

func UploadNode(filename string, data []byte, isDir bool, oyaID *uint, userID uint) (uint, error) {
	return uploadNodeWithTransaction(filename, data, isDir, oyaID, userID)
}

func uploadNodeWithTransaction(filename string, data []byte, isDir bool, oyaID *uint, userID uint) (uint, error) {
	var nodeID uint
	err := db.Transaction(func(tx *gorm.DB) error {
		var existing Node
		if err := tx.First(&existing, "name = ? AND oya_id = ? AND user_id = ?", filename, oyaID, userID).Error; err == nil {
			if isDir {
				if existing.IsDir {
					nodeID = existing.ID
					return nil
				}
				if err := DeleteNodeRecursive(existing.ID, userID); err != nil {
					return err
				}
				newNode := Node{
					UserID: userID,
					Name:   filename,
					IsDir:  true,
					OyaID:  oyaID,
				}
				if res := tx.Create(&newNode); res.Error != nil {
					return res.Error
				}
				nodeID = newNode.ID
				return nil
			}
			if existing.IsDir {
				return fmt.Errorf("folder_exists")
			}
			if !UpdateNode(existing.Fid, data) {
				return fmt.Errorf("failed to update existing node")
			}
			existing.UpdatedAt = time.Now()
			if err := tx.Save(&existing).Error; err != nil {
				return fmt.Errorf("failed to update timestamp: %w", err)
			}
			nodeID = existing.ID
			return nil
		}
		if isDir {
			newNode := Node{
				UserID: userID,
				Name:   filename,
				IsDir:  true,
				OyaID:  oyaID,
			}
			if result := tx.Create(&newNode); result.Error != nil {
				return result.Error
			}
			nodeID = newNode.ID
			return nil
		}
		fid, err := UploadFile(data)
		if err != nil {
			return err
		}
		newNode := Node{
			UserID: userID,
			Fid:    &fid,
			Name:   filename,
			IsDir:  false,
			OyaID:  oyaID,
		}
		if result := tx.Create(&newNode); result.Error != nil {
			return result.Error
		}
		nodeID = newNode.ID
		return nil
	})
	return nodeID, err
}

func UpdateNode(fid *uint, data []byte) bool {
	if fid == nil {
		return false
	}
	fileLocks.Lock()
	lock, exists := fileLocks.m[*fid]
	if !exists {
		lock = &sync.RWMutex{}
		fileLocks.m[*fid] = lock
	}
	fileLocks.Unlock()
	lock.Lock()
	defer lock.Unlock()
	filepath := fmt.Sprintf("%s/%d", dataDir, *fid)
	tmpPath := filepath + ".tmp"
	file, err := os.OpenFile(tmpPath, os.O_CREATE|os.O_WRONLY|os.O_TRUNC, 0644)
	if err != nil {
		return false
	}
	_, err = file.Write(data)
	file.Close()
	if err != nil {
		os.Remove(tmpPath)
		return false
	}
	if err := os.Rename(tmpPath, filepath); err != nil {
		os.Remove(tmpPath)
		return false
	}
	return true
}

func CopyNode(src Node, newOyaID uint, userID uint) (uint, error) {
	if src.IsDir {
		newNode := Node{
			UserID: userID,
			Name:   src.Name,
			IsDir:  true,
			OyaID:  &newOyaID,
		}
		if res := db.Create(&newNode); res.Error != nil {
			return 0, res.Error
		}
		var children []Node
		db.Where("oya_id = ? AND user_id = ?", src.ID, userID).Find(&children)
		for _, c := range children {
			_, err := CopyNode(c, newNode.ID, userID)
			if err != nil {
				fmt.Println("warning: copy child failed:", err)
			}
		}
		return newNode.ID, nil
	}
	fid, err := UploadFile(src.return_file())
	if err != nil {
		return 0, err
	}
	newNode := Node{
		UserID: userID,
		Fid:    &fid,
		Name:   src.Name,
		IsDir:  false,
		OyaID:  &newOyaID,
	}
	result := db.Create(&newNode)
	if result.Error != nil {
		return 0, result.Error
	}
	return newNode.ID, nil
}

func findChildByName(oyaID uint, name string, userID uint) (Node, bool) {
	var n Node
	if err := db.First(&n, "oya_id = ? AND name = ? AND user_id = ?", oyaID, name, userID).Error; err != nil {
		return Node{}, false
	}
	return n, true
}

func isAncestor(ancestorID uint, nodeID uint, userID uint) bool {
	var cur Node
	if err := db.First(&cur, "id = ? AND user_id = ?", nodeID, userID).Error; err != nil {
		return false
	}
	for cur.OyaID != nil {
		if *cur.OyaID == ancestorID {
			return true
		}
		if err := db.First(&cur, "id = ? AND user_id = ?", *cur.OyaID, userID).Error; err != nil {
			break
		}
	}
	return false
}

func DeleteNodeRecursive(id uint, userID uint) error {
	var n Node
	if err := db.Preload("Ko").First(&n, "id = ? AND user_id = ?", id, userID).Error; err != nil {
		return err
	}
	for _, c := range n.Ko {
		_ = DeleteNodeRecursive(c.ID, userID)
	}
	if n.Fid != nil {
		p := fmt.Sprintf("%s/%d", dataDir, *n.Fid)
		_ = os.Remove(p)
	}
	result := db.Delete(&n)
	if result.Error != nil {
		return result.Error
	}
	return nil
}

func MoveNode(src Node, newOyaID uint) error {
	src.OyaID = &newOyaID
	result := db.Save(&src)
	return result.Error
}

func RenameNode(src Node, newName string) error {
	src.Name = newName
	result := db.Save(&src)
	return result.Error
}

func DeleteNode(src Node) error {
	result := db.Delete(&src)
	success := result.Error == nil && result.RowsAffected > 0
	if !success {
		return fmt.Errorf("delete failed")
	}
	fid := src.Fid
	if fid != nil {
		p := dataDir + "/" + fmt.Sprintf("%d", *fid)
		_ = os.Remove(p)
	}
	return nil
}

func GetJson(w http.ResponseWriter, r *http.Request) {
	userID, err := getUserIDFromRequest(r)
	if err != nil {
		http.Error(w, "Unauthorized", http.StatusUnauthorized)
		return
	}
	idStr := r.URL.Path[len("/node/"):]
	var node Node
	if idStr == "" {
		node = return_root(userID)
	} else {
		id, err := strconv.Atoi(idStr)
		if err != nil || id <= 0 {
			node = return_root(userID)
		} else {
			db.Preload("Ko").First(&node, "id = ? AND user_id = ?", id, userID)
		}
	}
	buildPath := func(n Node) string {
		if n.OyaID == nil {
			return "/"
		}
		parts := []string{n.Name}
		cur := n
		for cur.OyaID != nil {
			var parent Node
			if err := db.First(&parent, "id = ? AND user_id = ?", *cur.OyaID, userID).Error; err != nil {
				break
			}
			if parent.OyaID == nil {
				break
			}
			parts = append([]string{parent.Name}, parts...)
			cur = parent
		}
		return "/" + strings.Join(parts, "/")
	}
	node.Path = buildPath(node)
	if node.Fid != nil {
		p := fmt.Sprintf("%s/%d", dataDir, *node.Fid)
		if st, err := os.Stat(p); err == nil {
			node.Size = st.Size()
		}
	}
	var share Share
	if err := db.First(&share, "node_id = ? AND user_id = ?", node.ID, userID).Error; err == nil {
		node.ShareToken = share.Token
	}
	for i := range node.Ko {
		if node.Ko[i].Fid != nil {
			p := fmt.Sprintf("%s/%d", dataDir, *node.Ko[i].Fid)
			if st, err := os.Stat(p); err == nil {
				node.Ko[i].Size = st.Size()
			}
		}
		var childShare Share
		if err := db.First(&childShare, "node_id = ? AND user_id = ?", node.Ko[i].ID, userID).Error; err == nil {
			node.Ko[i].ShareToken = childShare.Token
		}
	}
	w.Header().Set("Content-Type", "application/json")
	w.Write(node.to_json())
}

func GetFile(w http.ResponseWriter, r *http.Request) {
	userID, err := getUserIDFromRequest(r)
	if err != nil {
		http.Error(w, "Unauthorized", http.StatusUnauthorized)
		return
	}
	idStr := strings.TrimPrefix(r.URL.Path, "/file/")
	id, _ := strconv.Atoi(idStr)
	var node Node
	db.First(&node, "id = ? AND user_id = ?", id, userID)
	if node.Fid == nil {
		http.Error(w, "file not found", http.StatusNotFound)
		return
	}
	p := fmt.Sprintf("%s/%d", dataDir, *node.Fid)
	f, err := os.Open(p)
	if err != nil {
		http.Error(w, "failed to open file", http.StatusInternalServerError)
		return
	}
	defer f.Close()
	fi, err := f.Stat()
	if err != nil {
		http.Error(w, "failed to stat file", http.StatusInternalServerError)
		return
	}
	ext := strings.ToLower("." + strings.TrimPrefix(strings.TrimPrefix(filepath.Ext(node.Name), "."), "."))
	ctype := mime.TypeByExtension(ext)
	if ctype == "" {
		ctype = "application/octet-stream"
	}
	inline := r.URL.Query().Get("inline")
	if inline == "1" || inline == "true" {
		w.Header().Set("Content-Disposition", fmt.Sprintf("inline; filename=\"%s\"", node.Name))
	} else {
		w.Header().Set("Content-Disposition", fmt.Sprintf("attachment; filename=\"%s\"", node.Name))
	}
	w.Header().Set("Content-Type", ctype)
	http.ServeContent(w, r, node.Name, fi.ModTime(), f)
}

func GetThumbnail(w http.ResponseWriter, r *http.Request) {
	userID, err := getUserIDFromRequest(r)
	if err != nil {
		http.Error(w, "Unauthorized", http.StatusUnauthorized)
		return
	}
	idStr := strings.TrimPrefix(r.URL.Path, "/thumbnail/")
	id, _ := strconv.Atoi(idStr)
	var node Node
	db.First(&node, "id = ? AND user_id = ?", id, userID)
	if node.Fid == nil {
		fmt.Printf("Thumbnail request failed: node %d not found or no file\n", id)
		http.Error(w, "file not found", http.StatusNotFound)
		return
	}
	p := fmt.Sprintf("%s/%d", dataDir, *node.Fid)
	fmt.Printf("Thumbnail request for %s (node_id=%d, fid=%d)\n", node.Name, id, *node.Fid)
	if err := os.MkdirAll(thumbDir, 0755); err != nil {
		http.Error(w, "failed to create thumbnail directory", http.StatusInternalServerError)
		return
	}
	thumbPath := fmt.Sprintf("%s/%d.jpg", thumbDir, *node.Fid)
	if thumbFile, err := os.Open(thumbPath); err == nil {
		defer thumbFile.Close()
		if thumbInfo, err := thumbFile.Stat(); err == nil {
			fmt.Printf("Serving cached thumbnail for %s\n", node.Name)
			w.Header().Set("Content-Type", "image/jpeg")
			w.Header().Set("Cache-Control", "public, max-age=86400")
			http.ServeContent(w, r, "thumbnail.jpg", thumbInfo.ModTime(), thumbFile)
			return
		}
	}
	lockKey := fmt.Sprintf("thumb_%d", *node.Fid)
	actual, loaded := thumbnailMutex.LoadOrStore(lockKey, &sync.Mutex{})
	lock := actual.(*sync.Mutex)
	lock.Lock()
	defer func() {
		lock.Unlock()
		if loaded {
			thumbnailMutex.Delete(lockKey)
		}
	}()
	if thumbFile, err := os.Open(thumbPath); err == nil {
		defer thumbFile.Close()
		if thumbInfo, err := thumbFile.Stat(); err == nil {
			fmt.Printf("Serving cached thumbnail for %s (created by another request)\n", node.Name)
			w.Header().Set("Content-Type", "image/jpeg")
			w.Header().Set("Cache-Control", "public, max-age=86400")
			http.ServeContent(w, r, "thumbnail.jpg", thumbInfo.ModTime(), thumbFile)
			return
		}
	}
	ext := strings.ToLower(filepath.Ext(node.Name))
	isImage := ext == ".jpg" || ext == ".jpeg" || ext == ".png" || ext == ".gif" || ext == ".webp" || ext == ".bmp"
	isVideo := ext == ".mp4" || ext == ".webm" || ext == ".ogg" || ext == ".mov" || ext == ".mkv" || ext == ".avi"
	if !isImage && !isVideo {
		fmt.Printf("Unsupported file type %s for %s\n", ext, node.Name)
		http.Error(w, "not a supported media file", http.StatusBadRequest)
		return
	}
	var thumbnail image.Image
	if isImage {
		fmt.Printf("Generating image thumbnail for %s\n", node.Name)
		file, err := os.Open(p)
		if err != nil {
			http.Error(w, "failed to open file", http.StatusInternalServerError)
			return
		}
		defer file.Close()
		img, _, err := image.Decode(file)
		if err != nil {
			fmt.Printf("Image decode failed for %s: %v\n", node.Name, err)
			http.Error(w, "failed to decode image", http.StatusInternalServerError)
			return
		}
		thumbnail = resize.Thumbnail(200, 200, img, resize.Lanczos3)
	} else if isVideo {
		fmt.Printf("Generating video thumbnail for %s\n", node.Name)
		thumbnail, err = extractVideoFrame(p)
		if err != nil {
			fmt.Printf("Video thumbnail generation failed for %s: %v\n", node.Name, err)
			http.Error(w, fmt.Sprintf("thumbnail generation failed: %v", err), http.StatusNotFound)
			return
		}
		fmt.Printf("Video thumbnail generated successfully for %s\n", node.Name)
	}
	tmpThumbPath := thumbPath + ".tmp"
	cacheFile, err := os.Create(tmpThumbPath)
	if err == nil {
		jpeg.Encode(cacheFile, thumbnail, &jpeg.Options{Quality: 85})
		cacheFile.Close()
		os.Rename(tmpThumbPath, thumbPath)
	}
	w.Header().Set("Content-Type", "image/jpeg")
	w.Header().Set("Cache-Control", "public, max-age=86400")
	var buf bytes.Buffer
	if err := jpeg.Encode(&buf, thumbnail, &jpeg.Options{Quality: 85}); err != nil {
		http.Error(w, "failed to encode thumbnail", http.StatusInternalServerError)
		return
	}
	w.Write(buf.Bytes())
}

func extractVideoFrame(videoPath string) (image.Image, error) {
	ffmpegPath, err := exec.LookPath("ffmpeg")
	if err != nil {
		return nil, fmt.Errorf("ffmpeg not found: %v", err)
	}
	tmpFile := filepath.Join(os.TempDir(), fmt.Sprintf("thumb_%d.jpg", time.Now().UnixNano()))
	defer os.Remove(tmpFile)
	cmd := exec.Command(ffmpegPath,
		"-ss", "00:00:00",
		"-i", videoPath,
		"-vframes", "1",
		"-vf", "scale=200:200:force_original_aspect_ratio=decrease,pad=200:200:-1:-1:color=black",
		"-q:v", "2",
		"-f", "image2",
		"-update", "1",
		"-y",
		tmpFile,
	)
	var stdout, stderr bytes.Buffer
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr
	if err := cmd.Run(); err != nil {
		return nil, fmt.Errorf("ffmpeg error: %v - stderr: %s", err, stderr.String())
	}
	file, err := os.Open(tmpFile)
	if err != nil {
		return nil, fmt.Errorf("failed to open thumbnail: %v", err)
	}
	defer file.Close()
	img, _, err := image.Decode(file)
	if err != nil {
		return nil, fmt.Errorf("failed to decode thumbnail: %v", err)
	}
	return img, nil
}

func UpFile(w http.ResponseWriter, r *http.Request) {
	userID, err := getUserIDFromRequest(r)
	if err != nil {
		http.Error(w, "Unauthorized", http.StatusUnauthorized)
		return
	}
	contentType := r.Header.Get("Content-Type")
	var filename string
	var isDir bool
	var oyaPtr *uint
	var data []byte
	var uploadID string
	if strings.HasPrefix(contentType, "multipart/form-data") {
		err := r.ParseMultipartForm(1024 << 20) // 1024MB
		if err != nil {
			http.Error(w, "failed to parse multipart form: "+err.Error(), http.StatusBadRequest)
			return
		}
		filename = r.FormValue("filename")
		if filename == "" {
			if fh := r.MultipartForm.File["file"]; len(fh) > 0 && fh[0] != nil {
				filename = fh[0].Filename
			}
		}
		isDir = r.FormValue("is_dir") == "true" || r.FormValue("is_dir") == "1"
		oyaStr := r.FormValue("oya_id")
		if oyaStr != "" {
			if id, err := strconv.Atoi(oyaStr); err == nil {
				u := uint(id)
				oyaPtr = &u
			}
		}
		if !isDir {
			file, fh, err := r.FormFile("file")
			if err != nil {
				http.Error(w, "missing file: "+err.Error(), http.StatusBadRequest)
				return
			}
			defer file.Close()
			totalSize := int64(0)
			if fh != nil {
				totalSize = fh.Size
			}
			uploadID = r.FormValue("upload_id")
			if uploadID == "" {
				uploadID = r.URL.Query().Get("upload_id")
			}
			buf := make([]byte, 32*1024)
			var b []byte
			var readBytes int64
			for {
				n, err := file.Read(buf)
				if n > 0 {
					b = append(b, buf[:n]...)
					readBytes += int64(n)
					if uploadID != "" && totalSize > 0 {
						pct := int((readBytes * 100) / totalSize)
						progressChannels.RLock()
						ch, ok := progressChannels.m[uploadID]
						progressChannels.RUnlock()
						if ok {
							select {
							case ch <- pct:
							default:
							}
						}
					}
				}
				if err != nil {
					if err == io.EOF {
						break
					}
					http.Error(w, "failed to read file: "+err.Error(), http.StatusInternalServerError)
					return
				}
			}
			data = b
		}
	} else if strings.HasPrefix(contentType, "application/json") {
		var body struct {
			Filename   string `json:"filename"`
			IsDir      bool   `json:"is_dir"`
			OyaID      *uint  `json:"oya_id"`
			DataBase64 string `json:"data_base64"`
		}
		dec := json.NewDecoder(r.Body)
		if err := dec.Decode(&body); err != nil {
			http.Error(w, "failed to decode json: "+err.Error(), http.StatusBadRequest)
			return
		}
		filename = body.Filename
		isDir = body.IsDir
		oyaPtr = body.OyaID
		if !isDir && body.DataBase64 != "" {
			d, err := base64.StdEncoding.DecodeString(body.DataBase64)
			if err != nil {
				http.Error(w, "failed to decode base64: "+err.Error(), http.StatusBadRequest)
				return
			}
			data = d
		}
	} else {
		http.Error(w, "unsupported content type: "+contentType, http.StatusUnsupportedMediaType)
		return
	}
	if filename == "" {
		http.Error(w, "filename is required", http.StatusBadRequest)
		return
	}
	if oyaPtr == nil {
		root := return_root(userID)
		oyaPtr = &root.ID
	}
	nodeID, err := UploadNode(filename, data, isDir, oyaPtr, userID)
	if err != nil {
		if err.Error() == "folder_exists" {
			http.Error(w, "folder_exists", http.StatusConflict)
			return
		}
		http.Error(w, "upload_error: "+err.Error(), http.StatusInternalServerError)
		return
	}
	if uploadID != "" {
		progressChannels.RLock()
		ch, ok := progressChannels.m[uploadID]
		progressChannels.RUnlock()
		if ok {
			select {
			case ch <- 100:
			default:
			}
		}
	}
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	resp := fmt.Sprintf(`{"success":true,"node_id":%d,"name":"%s"}`, nodeID, filename)
	_, _ = w.Write([]byte(resp))
}

func UploadProgressSSE(w http.ResponseWriter, r *http.Request) {
	uploadID := r.URL.Query().Get("upload_id")
	if uploadID == "" {
		http.Error(w, "upload_id query parameter is required", http.StatusBadRequest)
		return
	}
	flusher, ok := w.(http.Flusher)
	if !ok {
		http.Error(w, "streaming unsupported", http.StatusInternalServerError)
		return
	}
	w.Header().Set("Content-Type", "text/event-stream")
	w.Header().Set("Cache-Control", "no-cache")
	w.Header().Set("Connection", "keep-alive")
	ch := make(chan int, 10)
	progressChannels.Lock()
	progressChannels.m[uploadID] = ch
	progressChannels.Unlock()
	defer func() {
		progressChannels.Lock()
		delete(progressChannels.m, uploadID)
		progressChannels.Unlock()
		close(ch)
	}()
	fmt.Fprintf(w, "data: %d\n\n", 0)
	flusher.Flush()
	for {
		select {
		case <-r.Context().Done():
			return
		case pct, ok := <-ch:
			if !ok {
				return
			}
			fmt.Fprintf(w, "data: %d\n\n", pct)
			flusher.Flush()
			if pct >= 100 {
				return
			}
		case <-time.After(30 * time.Second):
			fmt.Fprint(w, ": keepalive\n\n")
			flusher.Flush()
		}
	}
}

func CpFile(w http.ResponseWriter, r *http.Request) {
	userID, err := getUserIDFromRequest(r)
	if err != nil {
		http.Error(w, "Unauthorized", http.StatusUnauthorized)
		return
	}
	var req struct {
		SrcID     uint `json:"src_id"`
		DstID     uint `json:"dst_id"`
		Overwrite bool `json:"overwrite"`
	}
	dec := json.NewDecoder(r.Body)
	if err := dec.Decode(&req); err != nil {
		http.Error(w, "invalid json: "+err.Error(), http.StatusBadRequest)
		return
	}
	if req.SrcID == 0 || req.DstID == 0 {
		http.Error(w, "src_id and dst_id required", http.StatusBadRequest)
		return
	}
	var src Node
	if err := db.First(&src, "id = ? AND user_id = ?", req.SrcID, userID).Error; err != nil {
		http.Error(w, "source not found", http.StatusNotFound)
		return
	}
	err = db.Transaction(func(tx *gorm.DB) error {
		if existing, ok := findChildByName(req.DstID, src.Name, userID); ok {
			if !req.Overwrite {
				return fmt.Errorf("conflict: destination already contains an entry with same name")
			}
			if err := DeleteNodeRecursive(existing.ID, userID); err != nil {
				return fmt.Errorf("failed to remove existing target: %w", err)
			}
		}
		_, err := CopyNode(src, req.DstID, userID)
		if err != nil {
			return fmt.Errorf("copy failed: %w", err)
		}
		return nil
	})
	if err != nil {
		if strings.Contains(err.Error(), "conflict:") {
			http.Error(w, err.Error(), http.StatusConflict)
		} else {
			http.Error(w, err.Error(), http.StatusInternalServerError)
		}
		return
	}
	w.Header().Set("Content-Type", "application/json")
	w.Write([]byte(fmt.Sprintf(`{"success":true,"name":"%s"}`, src.Name)))
}

func MvFile(w http.ResponseWriter, r *http.Request) {
	userID, err := getUserIDFromRequest(r)
	if err != nil {
		http.Error(w, "Unauthorized", http.StatusUnauthorized)
		return
	}
	var req struct {
		SrcID     uint `json:"src_id"`
		DstID     uint `json:"dst_id"`
		Overwrite bool `json:"overwrite"`
	}
	dec := json.NewDecoder(r.Body)
	if err := dec.Decode(&req); err != nil {
		http.Error(w, "invalid json: "+err.Error(), http.StatusBadRequest)
		return
	}
	if req.SrcID == 0 || req.DstID == 0 {
		http.Error(w, "src_id and dst_id required", http.StatusBadRequest)
		return
	}
	var src Node
	if err := db.First(&src, "id = ? AND user_id = ?", req.SrcID, userID).Error; err != nil {
		http.Error(w, "source not found", http.StatusNotFound)
		return
	}
	if src.ID == req.DstID || isAncestor(src.ID, req.DstID, userID) {
		http.Error(w, "cannot move into self or descendant", http.StatusBadRequest)
		return
	}
	err = db.Transaction(func(tx *gorm.DB) error {
		if existing, ok := findChildByName(req.DstID, src.Name, userID); ok {
			if !req.Overwrite {
				return fmt.Errorf("conflict: destination already contains an entry with same name")
			}
			if err := DeleteNodeRecursive(existing.ID, userID); err != nil {
				return fmt.Errorf("failed to remove existing target: %w", err)
			}
		}
		if err := MoveNode(src, req.DstID); err != nil {
			return fmt.Errorf("move failed: %w", err)
		}
		return nil
	})
	if err != nil {
		if strings.Contains(err.Error(), "conflict:") {
			http.Error(w, err.Error(), http.StatusConflict)
		} else {
			http.Error(w, err.Error(), http.StatusInternalServerError)
		}
		return
	}
	w.Header().Set("Content-Type", "application/json")
	w.Write([]byte(fmt.Sprintf(`{"success":true,"name":"%s"}`, src.Name)))
}

func RnFile(w http.ResponseWriter, r *http.Request) {
	userID, err := getUserIDFromRequest(r)
	if err != nil {
		http.Error(w, "Unauthorized", http.StatusUnauthorized)
		return
	}
	var req struct {
		SrcID   uint   `json:"src_id"`
		NewName string `json:"new_name"`
	}
	dec := json.NewDecoder(r.Body)
	if err := dec.Decode(&req); err != nil {
		http.Error(w, "invalid json: "+err.Error(), http.StatusBadRequest)
		return
	}
	if req.SrcID == 0 || strings.TrimSpace(req.NewName) == "" {
		http.Error(w, "src_id and new_name required", http.StatusBadRequest)
		return
	}
	var src Node
	if err := db.First(&src, "id = ? AND user_id = ?", req.SrcID, userID).Error; err != nil {
		http.Error(w, "source not found", http.StatusNotFound)
		return
	}
	if err := RenameNode(src, req.NewName); err != nil {
		http.Error(w, "rename failed: "+err.Error(), http.StatusInternalServerError)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	w.Write([]byte(`{"success":true}`))
}

func DlFile(w http.ResponseWriter, r *http.Request) {
	userID, err := getUserIDFromRequest(r)
	if err != nil {
		http.Error(w, "Unauthorized", http.StatusUnauthorized)
		return
	}
	var req struct {
		SrcID uint `json:"src_id"`
	}
	dec := json.NewDecoder(r.Body)
	if err := dec.Decode(&req); err != nil {
		http.Error(w, "invalid json: "+err.Error(), http.StatusBadRequest)
		return
	}
	if req.SrcID == 0 {
		http.Error(w, "src_id required", http.StatusBadRequest)
		return
	}
	var src Node
	if err := db.First(&src, "id = ? AND user_id = ?", req.SrcID, userID).Error; err != nil {
		http.Error(w, "source not found", http.StatusNotFound)
		return
	}
	if err := DeleteNodeRecursive(src.ID, userID); err != nil {
		http.Error(w, "delete failed: "+err.Error(), http.StatusInternalServerError)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	w.Write([]byte(`{"success":true}`))
}

//go:embed index.html
var indexHtmlContent string

//go:embed index.js
var js_script string

//go:embed i18n.js
var i18n_script string

func Register(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Username string `json:"username"`
		Password string `json:"password"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "invalid json", http.StatusBadRequest)
		return
	}
	if strings.TrimSpace(req.Username) == "" || strings.TrimSpace(req.Password) == "" {
		http.Error(w, "username and password required", http.StatusBadRequest)
		return
	}
	var existing User
	if err := db.First(&existing, "username = ?", req.Username).Error; err == nil {
		http.Error(w, "username already exists", http.StatusConflict)
		return
	}
	hashedPassword, err := hashPassword(req.Password)
	if err != nil {
		http.Error(w, "failed to hash password", http.StatusInternalServerError)
		return
	}
	user := User{
		Username: req.Username,
		Password: hashedPassword,
	}
	if err := db.Create(&user).Error; err != nil {
		http.Error(w, "failed to create user", http.StatusInternalServerError)
		return
	}
	root := Node{
		UserID: user.ID,
		Name:   "/",
		IsDir:  true,
		OyaID:  nil,
	}
	if err := db.Create(&root).Error; err != nil {
		fmt.Println("warning: failed to create root node for user:", err)
	}
	token, err := generateToken(user.ID, user.Username)
	if err != nil {
		http.Error(w, "failed to generate token", http.StatusInternalServerError)
		return
	}
	http.SetCookie(w, &http.Cookie{
		Name:     "token",
		Value:    token,
		Path:     "/",
		MaxAge:   86400,
		HttpOnly: true,
		SameSite: http.SameSiteStrictMode,
	})
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"success":  true,
		"user_id":  user.ID,
		"username": user.Username,
	})
}

func Login(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Username string `json:"username"`
		Password string `json:"password"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "invalid json", http.StatusBadRequest)
		return
	}
	var user User
	if err := db.First(&user, "username = ?", req.Username).Error; err != nil {
		http.Error(w, "invalid credentials", http.StatusUnauthorized)
		return
	}
	if !checkPasswordHash(req.Password, user.Password) {
		http.Error(w, "invalid credentials", http.StatusUnauthorized)
		return
	}
	token, err := generateToken(user.ID, user.Username)
	if err != nil {
		http.Error(w, "failed to generate token", http.StatusInternalServerError)
		return
	}
	http.SetCookie(w, &http.Cookie{
		Name:     "token",
		Value:    token,
		Path:     "/",
		MaxAge:   86400,
		HttpOnly: true,
		SameSite: http.SameSiteStrictMode,
	})
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"success":  true,
		"user_id":  user.ID,
		"username": user.Username,
	})
}

func Logout(w http.ResponseWriter, r *http.Request) {
	http.SetCookie(w, &http.Cookie{
		Name:     "token",
		Value:    "",
		Path:     "/",
		MaxAge:   -1,
		HttpOnly: true,
	})
	w.Header().Set("Content-Type", "application/json")
	w.Write([]byte(`{"success":true}`))
}

func Me(w http.ResponseWriter, r *http.Request) {
	userID, err := getUserIDFromRequest(r)
	if err != nil {
		http.Error(w, "Unauthorized", http.StatusUnauthorized)
		return
	}
	username := r.Header.Get("X-Username")
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"user_id":  userID,
		"username": username,
	})
}

func generateShareToken() string {
	b := make([]byte, 16)
	for i := range b {
		b[i] = byte(mrand.Intn(256))
	}
	return base64.URLEncoding.EncodeToString(b)
}

func CreateShare(w http.ResponseWriter, r *http.Request) {
	userID, err := getUserIDFromRequest(r)
	if err != nil {
		http.Error(w, "Unauthorized", http.StatusUnauthorized)
		return
	}
	var req struct {
		NodeID uint `json:"node_id"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "invalid json", http.StatusBadRequest)
		return
	}
	if req.NodeID == 0 {
		http.Error(w, "node_id required", http.StatusBadRequest)
		return
	}
	var node Node
	if err := db.First(&node, "id = ? AND user_id = ?", req.NodeID, userID).Error; err != nil {
		http.Error(w, "node not found", http.StatusNotFound)
		return
	}
	var existingShare Share
	if err := db.First(&existingShare, "node_id = ? AND user_id = ?", req.NodeID, userID).Error; err == nil {
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]interface{}{
			"success": true,
			"token":   existingShare.Token,
		})
		return
	}
	token := generateShareToken()
	share := Share{
		Token:  token,
		NodeID: req.NodeID,
		UserID: userID,
	}
	if err := db.Create(&share).Error; err != nil {
		http.Error(w, "failed to create share", http.StatusInternalServerError)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"success": true,
		"token":   token,
	})
}

func GetSharedFile(w http.ResponseWriter, r *http.Request) {
	token := strings.TrimPrefix(r.URL.Path, "/s/")
	var share Share
	if err := db.First(&share, "token = ?", token).Error; err != nil {
		http.Error(w, "shared link not found", http.StatusNotFound)
		return
	}
	if share.ExpiresAt != nil && share.ExpiresAt.Before(time.Now()) {
		http.Error(w, "shared link expired", http.StatusGone)
		return
	}
	var node Node
	if err := db.First(&node, "id = ?", share.NodeID).Error; err != nil {
		http.Error(w, "file not found", http.StatusNotFound)
		return
	}
	if node.Fid == nil {
		http.Error(w, "not a file", http.StatusBadRequest)
		return
	}
	p := fmt.Sprintf("%s/%d", dataDir, *node.Fid)
	f, err := os.Open(p)
	if err != nil {
		http.Error(w, "failed to open file", http.StatusInternalServerError)
		return
	}
	defer f.Close()
	fi, err := f.Stat()
	if err != nil {
		http.Error(w, "failed to stat file", http.StatusInternalServerError)
		return
	}
	ext := strings.ToLower("." + strings.TrimPrefix(strings.TrimPrefix(filepath.Ext(node.Name), "."), "."))
	ctype := mime.TypeByExtension(ext)
	if ctype == "" {
		ctype = "application/octet-stream"
	}
	inline := r.URL.Query().Get("inline")
	if inline == "1" || inline == "true" {
		w.Header().Set("Content-Disposition", fmt.Sprintf("inline; filename=\"%s\"", node.Name))
	} else {
		w.Header().Set("Content-Disposition", fmt.Sprintf("attachment; filename=\"%s\"", node.Name))
	}
	w.Header().Set("Content-Type", ctype)
	http.ServeContent(w, r, node.Name, fi.ModTime(), f)
}

func DeleteShare(w http.ResponseWriter, r *http.Request) {
	userID, err := getUserIDFromRequest(r)
	if err != nil {
		http.Error(w, "Unauthorized", http.StatusUnauthorized)
		return
	}
	var req struct {
		NodeID uint `json:"node_id"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "invalid json", http.StatusBadRequest)
		return
	}
	if req.NodeID == 0 {
		http.Error(w, "node_id required", http.StatusBadRequest)
		return
	}
	result := db.Where("node_id = ? AND user_id = ?", req.NodeID, userID).Delete(&Share{})
	if result.Error != nil {
		http.Error(w, "failed to delete share", http.StatusInternalServerError)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	w.Write([]byte(`{"success":true}`))
}

func main() {
	var err error
	db, err = gorm.Open(sqlite.Open(dbFile), &gorm.Config{})
	if err != nil {
		panic(err)
	}
	db.AutoMigrate(&User{}, &Node{}, &Share{})
	http.HandleFunc("/register", Register)
	http.HandleFunc("/login", Login)
	http.HandleFunc("/logout", Logout)
	http.HandleFunc("/me", authMiddleware(Me))
	http.HandleFunc("/file/", authMiddleware(GetFile))
	http.HandleFunc("/thumbnail/", authMiddleware(GetThumbnail))
	http.HandleFunc("/node/", authMiddleware(GetJson))
	http.HandleFunc("/upload", authMiddleware(UpFile))
	http.HandleFunc("/upload/progress", UploadProgressSSE)
	http.HandleFunc("/copy", authMiddleware(CpFile))
	http.HandleFunc("/move", authMiddleware(MvFile))
	http.HandleFunc("/rename", authMiddleware(RnFile))
	http.HandleFunc("/delete", authMiddleware(DlFile))
	http.HandleFunc("/share/create", authMiddleware(CreateShare))
	http.HandleFunc("/share/delete", authMiddleware(DeleteShare))
	http.HandleFunc("/s/", GetSharedFile)
	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "text/html; charset=utf-8")
		_, _ = w.Write([]byte(indexHtmlContent))
	})
	http.HandleFunc("/index.js", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/javascript")
		w.Write([]byte(js_script))
	})
	http.HandleFunc("/i18n.js", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/javascript")
		w.Write([]byte(i18n_script))
	})
	fmt.Printf("%s server started at :80\n", programName)
	http.ListenAndServe(":80", nil)
}
