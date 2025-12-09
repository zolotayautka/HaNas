import Foundation
import SQLite3

struct ServerConfig {
    let serverURL: String
    let username: String
    let password: String
}

class ConfigManager {
    static let shared = ConfigManager()
    private var db: OpaquePointer?
    private let configPath: String
    
    private init() {
        let homeDirectory = FileManager.default.homeDirectoryForCurrentUser
        configPath = homeDirectory.appendingPathComponent(".hanas_config").path
        openDatabase()
        createTable()
    }
    
    deinit {
        closeDatabase()
    }
    
    private func openDatabase() {
        if sqlite3_open(configPath, &db) != SQLITE_OK {
        }
    }
    
    private func closeDatabase() {
        if db != nil {
            sqlite3_close(db)
            db = nil
        }
    }
    
    private func createTable() {
        let createTableQuery = """
        CREATE TABLE IF NOT EXISTS config (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            server_url TEXT NOT NULL,
            username TEXT NOT NULL,
            password TEXT NOT NULL,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP
        );
        """
        var createTableStatement: OpaquePointer?
        if sqlite3_prepare_v2(db, createTableQuery, -1, &createTableStatement, nil) == SQLITE_OK {
            if sqlite3_step(createTableStatement) == SQLITE_DONE {
            } else {
            }
        } else {
        }
        sqlite3_finalize(createTableStatement)
    }

    func hasConfig() -> Bool {
        let query = "SELECT COUNT(*) FROM config;"
        var queryStatement: OpaquePointer?
        var count = 0
        if sqlite3_prepare_v2(db, query, -1, &queryStatement, nil) == SQLITE_OK {
            if sqlite3_step(queryStatement) == SQLITE_ROW {
                count = Int(sqlite3_column_int(queryStatement, 0))
            }
        }
        sqlite3_finalize(queryStatement)
        return count > 0
    }

    func loadConfig() -> ServerConfig? {
        let query = "SELECT server_url, username, password FROM config ORDER BY id DESC LIMIT 1;"
        var queryStatement: OpaquePointer?
        var config: ServerConfig?
        if sqlite3_prepare_v2(db, query, -1, &queryStatement, nil) == SQLITE_OK {
            if sqlite3_step(queryStatement) == SQLITE_ROW {
                let serverURL = String(cString: sqlite3_column_text(queryStatement, 0))
                let username = String(cString: sqlite3_column_text(queryStatement, 1))
                let password = String(cString: sqlite3_column_text(queryStatement, 2))
                config = ServerConfig(serverURL: serverURL, username: username, password: password)
            }
        }
        sqlite3_finalize(queryStatement)
        return config
    }
    
    func saveConfig(serverURL: String, username: String, password: String) -> Bool {
        let deleteQuery = "DELETE FROM config;"
        var deleteStatement: OpaquePointer?
        if sqlite3_prepare_v2(db, deleteQuery, -1, &deleteStatement, nil) == SQLITE_OK {
            sqlite3_step(deleteStatement)
        }
        sqlite3_finalize(deleteStatement)
        let insertQuery = "INSERT INTO config (server_url, username, password) VALUES (?, ?, ?);"
        var insertStatement: OpaquePointer?
        if sqlite3_prepare_v2(db, insertQuery, -1, &insertStatement, nil) == SQLITE_OK {
            sqlite3_bind_text(insertStatement, 1, (serverURL as NSString).utf8String, -1, nil)
            sqlite3_bind_text(insertStatement, 2, (username as NSString).utf8String, -1, nil)
            sqlite3_bind_text(insertStatement, 3, (password as NSString).utf8String, -1, nil)
            if sqlite3_step(insertStatement) == SQLITE_DONE {
                sqlite3_finalize(insertStatement)
                return true
            }
        }
        sqlite3_finalize(insertStatement)
        return false
    }

    func deleteConfig() -> Bool {
        let deleteQuery = "DELETE FROM config;"
        var deleteStatement: OpaquePointer?
        if sqlite3_prepare_v2(db, deleteQuery, -1, &deleteStatement, nil) == SQLITE_OK {
            if sqlite3_step(deleteStatement) == SQLITE_DONE {
                sqlite3_finalize(deleteStatement)
                return true
            }
        }
        sqlite3_finalize(deleteStatement)
        return false
    }
}
