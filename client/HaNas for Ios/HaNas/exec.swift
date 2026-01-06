import Foundation

struct User: Codable {
    let id: Int
    let username: String
    let createdAt: String?
    enum CodingKeys: String, CodingKey {
        case id
        case username
        case createdAt = "created_at"
    }
}

struct Node: Codable, Hashable, Identifiable {
    let id: Int
    let userId: Int
    let name: String
    let isDir: Bool
    let oyaId: Int?
    let updatedAt: String
    let size: Int64?
    let path: String?
    let shareToken: String?
    var ko: [Node]?

    init(id: Int, userId: Int, name: String, isDir: Bool, oyaId: Int?, updatedAt: String, size: Int64?, path: String?, shareToken: String?, ko: [Node]?) {
        self.id = id
        self.userId = userId
        self.name = name
        self.isDir = isDir
        self.oyaId = oyaId
        self.updatedAt = updatedAt
        self.size = size
        self.path = path
        self.shareToken = shareToken
        self.ko = ko
    }

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case isDir = "is_dir"
        case oyaId = "oya_id"
        case updatedAt = "updated_at"
        case size
        case path
        case shareToken = "share_token"
        case ko
    }
    
    static func == (lhs: Node, rhs: Node) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct AuthResponse: Codable {
    let success: Bool
    let userId: Int?
    let username: String?

    enum CodingKeys: String, CodingKey {
        case success
        case userId = "user_id"
        case username
    }
}

struct UploadResponse: Codable {
    let success: Bool
    let nodeId: Int?
    let name: String?
    
    enum CodingKeys: String, CodingKey {
        case success
        case nodeId = "node_id"
        case name
    }
}

struct ErrorResponse: Codable {
    let error: String
}

struct MeResponse: Codable {
    let userId: Int
    let username: String
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case username
    }
}

struct ShareResponse: Codable {
    let success: Bool?
    let token: String
}

class HaNasAPI {
    static let shared = HaNasAPI()
    private var baseURL: String
    private var token: String?
    private let session: URLSession
    
    private init() {
        self.baseURL = ""
        let config = URLSessionConfiguration.default
        config.httpCookieAcceptPolicy = .always
        config.httpShouldSetCookies = true
        config.httpCookieStorage = HTTPCookieStorage.shared
        self.session = URLSession(configuration: config)
    }
    
    func setBaseURL(_ url: String) {
        self.baseURL = url
    }
    
    func getBaseURL() -> String {
        return baseURL
    }
    
    func setToken(_ token: String?) {
        self.token = token
    }

    func register(username: String, password: String) async throws -> AuthResponse {
        let endpoint = "/register"
        let body: [String: Any] = [
            "username": username,
            "password": password
        ]
        let response: AuthResponse = try await performRequest(
            endpoint: endpoint,
            method: "POST",
            body: body,
            requiresAuth: false
        )
        return response
    }
    
    func login(username: String, password: String) async throws -> AuthResponse {
        let endpoint = "/login"
        let body: [String: Any] = [
            "username": username,
            "password": password
        ]
        let response: AuthResponse = try await performRequest(
            endpoint: endpoint,
            method: "POST",
            body: body,
            requiresAuth: false,
            extractToken: true
        )
        return response
    }

    func logout() async throws {
        let endpoint = "/logout"
        try await performRequestWithoutResponse(
            endpoint: endpoint,
            method: "POST",
            requiresAuth: false
        )
        self.token = nil
    }

    func getCurrentUser() async throws -> (userId: Int, username: String) {
        let endpoint = "/me"
        let response: MeResponse = try await performRequest(
            endpoint: endpoint,
            method: "GET",
            requiresAuth: true
        )
        return (response.userId, response.username)
    }
    
    func getNode(id: Int? = nil) async throws -> Node {
        let endpoint = id != nil ? "/node/\(id!)" : "/node/"
        let response: Node = try await performRequest(
            endpoint: endpoint,
            method: "GET",
            requiresAuth: true
        )
        return response
    }
    
    func downloadFile(id: Int, inline: Bool = false) async throws -> Data {
        var endpoint = "/file/\(id)"
        if inline {
            endpoint += "?inline=1"
        }
        guard let url = URL(string: baseURL + endpoint) else {
            throw HaNasError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw HaNasError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw HaNasError.httpError(statusCode: httpResponse.statusCode)
        }
        return data
    }
    
    func getThumbnail(id: Int) async throws -> Data {
        let endpoint = "/thumbnail/\(id)"
        guard let url = URL(string: baseURL + endpoint) else {
            throw HaNasError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw HaNasError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw HaNasError.httpError(statusCode: httpResponse.statusCode)
        }
        return data
    }

    func uploadFile(filename: String, data: Data, oyaId: Int? = nil) async throws -> UploadResponse {
        let endpoint = "/upload"
        let base64String = data.base64EncodedString()
        var body: [String: Any] = [
            "filename": filename,
            "is_dir": false,
            "data_base64": base64String
        ]
        if let oyaId = oyaId {
            body["oya_id"] = oyaId
        }
        let response: UploadResponse = try await performRequest(
            endpoint: endpoint,
            method: "POST",
            body: body,
            requiresAuth: true
        )
        return response
    }
  
    func uploadFileMultipart(filename: String, fileURL: URL, oyaId: Int? = nil, uploadId: String? = nil, progressCallback: ((Double) -> Void)? = nil) async throws -> UploadResponse {
        let endpoint = "/upload"
        guard let url = URL(string: baseURL + endpoint) else {
            throw HaNasError.invalidURL
        }
        var didStartAccessing = false
        if fileURL.startAccessingSecurityScopedResource() {
            didStartAccessing = true
        }
        defer {
            if didStartAccessing {
                fileURL.stopAccessingSecurityScopedResource()
            }
        }
        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        let fileData = try Data(contentsOf: fileURL)
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"filename\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(filename)\r\n".data(using: .utf8)!)
        if let oyaId = oyaId {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"oya_id\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(oyaId)\r\n".data(using: .utf8)!)
        }
        if let uploadId = uploadId {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"upload_id\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(uploadId)\r\n".data(using: .utf8)!)
        }
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: application/octet-stream\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body
        if let uploadId = uploadId, let progressCallback = progressCallback {
            Task {
                await monitorUploadProgress(uploadId: uploadId, progressCallback: progressCallback)
            }
        }
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw HaNasError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw HaNasError.serverError(message: errorResponse.error)
            }
            throw HaNasError.httpError(statusCode: httpResponse.statusCode)
        }
        let uploadResponse = try JSONDecoder().decode(UploadResponse.self, from: data)
        return uploadResponse
    }
    
    private func monitorUploadProgress(uploadId: String, progressCallback: @escaping (Double) -> Void) async {
        let endpoint = "/upload/progress?upload_id=\(uploadId)"
        guard let url = URL(string: baseURL + endpoint) else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        do {
            let (bytes, _) = try await session.bytes(for: request)
            
            for try await line in bytes.lines {
                if line.hasPrefix("data: ") {
                    let dataStr = line.replacingOccurrences(of: "data: ", with: "").trimmingCharacters(in: .whitespaces)
                    if let progress = Int(dataStr) {
                        await MainActor.run {
                            progressCallback(Double(progress) / 100.0)
                        }
                        if progress >= 100 {
                            break
                        }
                    }
                }
            }
        } catch {}
    }
    
    func createFolder(name: String, oyaId: Int? = nil) async throws -> UploadResponse {
        let endpoint = "/upload"
        var body: [String: Any] = [
            "filename": name,
            "is_dir": true
        ]
        if let oyaId = oyaId {
            body["oya_id"] = oyaId
        }
        let response: UploadResponse = try await performRequest(
            endpoint: endpoint,
            method: "POST",
            body: body,
            requiresAuth: true
        )
        return response
    }
    
    func deleteNode(id: Int) async throws {
        let endpoint = "/delete"
        let body: [String: Any] = [
            "src_id": id
        ]
        try await performRequestWithoutResponse(
            endpoint: endpoint,
            method: "POST",
            body: body,
            requiresAuth: true
        )
    }
    
    func moveNode(id: Int, newOyaId: Int, overwrite: Bool = false) async throws {
        let endpoint = "/move"
        let body: [String: Any] = [
            "src_id": id,
            "dst_id": newOyaId,
            "overwrite": overwrite
        ]
        try await performRequestWithoutResponse(
            endpoint: endpoint,
            method: "POST",
            body: body,
            requiresAuth: true
        )
    }
    
    func renameNode(id: Int, newName: String) async throws {
        let endpoint = "/rename"
        let body: [String: Any] = [
            "src_id": id,
            "new_name": newName
        ]
        try await performRequestWithoutResponse(
            endpoint: endpoint,
            method: "POST",
            body: body,
            requiresAuth: true
        )
    }
    
    func copyNode(srcId: Int, dstId: Int, overwrite: Bool = false) async throws {
        let endpoint = "/copy"
        let body: [String: Any] = [
            "src_id": srcId,
            "dst_id": dstId,
            "overwrite": overwrite
        ]
        try await performRequestWithoutResponse(
            endpoint: endpoint,
            method: "POST",
            body: body,
            requiresAuth: true
        )
    }

    func createShare(nodeId: Int) async throws -> String {
        let endpoint = "/share/create"
        let body: [String: Any] = [
            "node_id": nodeId
        ]
        let response: ShareResponse = try await performRequest(
            endpoint: endpoint,
            method: "POST",
            body: body,
            requiresAuth: true
        )
        return response.token
    }

    func deleteShare(nodeId: Int) async throws {
        let endpoint = "/share/delete"
        let body: [String: Any] = [
            "node_id": nodeId
        ]
        try await performRequestWithoutResponse(
            endpoint: endpoint,
            method: "POST",
            body: body,
            requiresAuth: true
        )
    }
    
    func getSharedNode(token: String) async throws -> Node {
        let endpoint = "/s/\(token)"
        let response: Node = try await performRequest(
            endpoint: endpoint,
            method: "GET",
            requiresAuth: false
        )
        return response
    }

    func downloadSharedFile(token: String, inline: Bool = false) async throws -> Data {
        var endpoint = "/share/\(token)/download"
        if inline {
            endpoint += "?inline=1"
        }
        guard let url = URL(string: baseURL + endpoint) else {
            throw HaNasError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw HaNasError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw HaNasError.httpError(statusCode: httpResponse.statusCode)
        }
        return data
    }
    
    func getUploadProgress(uploadId: String) async throws -> Int {
        let endpoint = "/progress/\(uploadId)"
        let response: [String: Int] = try await performRequest(
            endpoint: endpoint,
            method: "GET",
            requiresAuth: true
        )
        guard let progress = response["progress"] else {
            throw HaNasError.invalidResponse
        }
        return progress
    }
    
    func getStreamURL(id: Int, type: String) async throws -> URL {
        let endpoint = "/file/\(id)?inline=1"
        guard let url = URL(string: baseURL + endpoint) else {
            throw HaNasError.invalidURL
        }
        return url
    }

    private func performRequestWithoutResponse(
        endpoint: String,
        method: String,
        body: [String: Any]? = nil,
        requiresAuth: Bool
    ) async throws {
        guard let url = URL(string: baseURL + endpoint) else {
            throw HaNasError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        if let body = body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw HaNasError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw HaNasError.serverError(message: errorResponse.error)
            }
            throw HaNasError.httpError(statusCode: httpResponse.statusCode)
        }
    }
    
    private func performRequest<T: Codable>(
        endpoint: String,
        method: String,
        body: [String: Any]? = nil,
        requiresAuth: Bool,
        extractToken: Bool = false
    ) async throws -> T {
        guard let url = URL(string: baseURL + endpoint) else {
            throw HaNasError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        if let body = body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw HaNasError.invalidResponse
        }
        if extractToken {
            if let cookies = HTTPCookieStorage.shared.cookies(for: url) {
                for cookie in cookies {
                    if cookie.name == "token" {
                        self.token = cookie.value
                    }
                }
            }
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw HaNasError.serverError(message: errorResponse.error)
            }
            throw HaNasError.httpError(statusCode: httpResponse.statusCode)
        }
        let decoder = JSONDecoder()
        let result = try decoder.decode(T.self, from: data)
        return result
    }
    
    func deleteAccount(password: String) async throws {
        let endpoint = "/delete-account"
        let body: [String: Any] = [
            "password": password
        ]
        try await performRequestWithoutResponse(
            endpoint: endpoint,
            method: "POST",
            body: body,
            requiresAuth: true
        )
    }
}

enum HaNasError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int)
    case serverError(message: String)
    case unauthorized
    case notFound
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return NSLocalizedString("error_invalid_url", comment: "")
        case .invalidResponse:
            return NSLocalizedString("error_invalid_response", comment: "")
        case .httpError(let statusCode):
            return String(format: NSLocalizedString("error_http", comment: ""), statusCode)
        case .serverError(let message):
            return String(format: NSLocalizedString("error_server", comment: ""), message)
        case .unauthorized:
            return NSLocalizedString("error_unauthorized", comment: "")
        case .notFound:
            return NSLocalizedString("error_not_found", comment: "")
        }
    }
}
