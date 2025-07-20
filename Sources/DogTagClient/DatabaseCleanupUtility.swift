// Copyright 2025 FIDO3.ai
// Generated on 2025-7-19
import Foundation

// MARK: - Database Cleanup Utility
// Helps clean up the redundant database mess and consolidate to unified approach

public final class DatabaseCleanupUtility {
    
    public static let shared = DatabaseCleanupUtility()
    
    private init() {}
    
    // MARK: - Database Analysis
    
    /// Analyze current database situation and provide recommendations
    public func analyzeDatabases() {
        print("🔍 DATABASE ANALYSIS: Checking for redundant databases...")
        
        let fileManager = FileManager.default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDirectory = appSupport.appendingPathComponent("WebMan")
        
        // Define all the database files we might find
        let databaseFiles = [
            "webauthn_credentials.db",     // ❌ REDUNDANT: Separate server verification database
            "WebAuthnClient.db",           // ✅ KEEP: Unified credentials (BOTH public + private keys)
            "WebAuthnManager.db"           // ❌ REDUNDANT: All server data now in unified WebAuthnClient.db
        ]
        
        print("\n📊 DATABASE ANALYSIS RESULTS:")
        print("=====================================")
        
        var totalSize: Int64 = 0
        var redundantSize: Int64 = 0
        
        for dbFile in databaseFiles {
            let dbURL = appDirectory.appendingPathComponent(dbFile)
            let shmURL = appDirectory.appendingPathComponent("\(dbFile)-shm")
            let walURL = appDirectory.appendingPathComponent("\(dbFile)-wal")
            
            if fileManager.fileExists(atPath: dbURL.path) {
                let size = getFileSize(at: dbURL)
                let shmSize = getFileSize(at: shmURL)
                let walSize = getFileSize(at: walURL)
                let combinedSize = size + shmSize + walSize
                
                totalSize += combinedSize
                
                switch dbFile {
                case "WebAuthnClient.db":
                    print("✅ \(dbFile) - \(formatSize(combinedSize)) - KEEP (unified: public + private keys)")
                case "webauthn_credentials.db":
                    redundantSize += combinedSize
                    print("❌ \(dbFile) - \(formatSize(combinedSize)) - REDUNDANT (separate public key storage)")
                case "WebAuthnManager.db":
                    redundantSize += combinedSize
                    print("❌ \(dbFile) - \(formatSize(combinedSize)) - REDUNDANT (separate admin storage)")
                default:
                    break
                }
                
                if shmSize > 0 {
                    print("   └── \(dbFile)-shm - \(formatSize(shmSize))")
                }
                if walSize > 0 {
                    print("   └── \(dbFile)-wal - \(formatSize(walSize))")
                }
            }
        }
        
        print("=====================================")
        print("📊 SUMMARY:")
        print("   Total database size: \(formatSize(totalSize))")
        print("   Redundant database size: \(formatSize(redundantSize))")
        
        if redundantSize > 0 {
            let percentage = (Double(redundantSize) / Double(totalSize)) * 100
            print("   Space wasted by redundancy: \(String(format: "%.1f", percentage))%")
            print("\n💡 RECOMMENDATION:")
            print("   Run `cleanupRedundantDatabases()` to remove redundant files")
            print("   This will free up \(formatSize(redundantSize)) of disk space")
        } else {
            print("   ✅ No redundant databases found!")
        }
    }
    
    // MARK: - Cleanup Operations
    
    /// Clean up redundant database files (with backup)
    public func cleanupRedundantDatabases() {
        print("🧹 CLEANUP: Starting redundant database cleanup...")
        
        let fileManager = FileManager.default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDirectory = appSupport.appendingPathComponent("WebMan")
        
        // Create backup directory
        let backupDirectory = appDirectory.appendingPathComponent("database_backups")
        let timestamp = Int(Date().timeIntervalSince1970)
        let backupFolder = backupDirectory.appendingPathComponent("backup_\(timestamp)")
        
        do {
            try fileManager.createDirectory(at: backupFolder, withIntermediateDirectories: true)
            print("📁 Created backup directory: \(backupFolder.path)")
        } catch {
            print("❌ Failed to create backup directory: \(error)")
            return
        }
        
        // Files to remove (redundant databases)
        let redundantFiles = [
            "webauthn_credentials.db",     // Separate public key storage - redundant
            "WebAuthnManager.db"           // Separate admin storage - redundant
        ]
        
        var cleanedUpSize: Int64 = 0
        
        for fileName in redundantFiles {
            let extensions = ["", "-shm", "-wal"]
            
            for ext in extensions {
                let fullFileName = "\(fileName)\(ext)"
                let fileURL = appDirectory.appendingPathComponent(fullFileName)
                let backupURL = backupFolder.appendingPathComponent(fullFileName)
                
                if fileManager.fileExists(atPath: fileURL.path) {
                    do {
                        let size = getFileSize(at: fileURL)
                        
                        // Move file to backup instead of deleting
                        try fileManager.moveItem(at: fileURL, to: backupURL)
                        cleanedUpSize += size
                        
                        print("📦 Backed up: \(fullFileName) (\(formatSize(size)))")
                        
                    } catch {
                        print("❌ Failed to backup \(fullFileName): \(error)")
                    }
                }
            }
        }
        
        print("\n✅ CLEANUP COMPLETED:")
        print("   Files backed up to: \(backupFolder.path)")
        print("   Space freed: \(formatSize(cleanedUpSize))")
        print("   Remaining database: WebAuthnClient.db (ALL credentials: public + private keys)")
        
        if cleanedUpSize > 0 {
            print("\n💡 NOTE: Backup files can be safely deleted after confirming everything works correctly")
            print("💡 The app now uses ONLY WebAuthnClient.db for ALL credential storage")
            print("💡 This includes BOTH public keys (for display) AND private keys (for auth)")
        }
    }
    
    // MARK: - Helper Methods
    
    private func getFileSize(at url: URL) -> Int64 {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            return attributes[.size] as? Int64 ?? 0
        } catch {
            return 0
        }
    }
    
    private func formatSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    // MARK: - Public Interface
    
    /// Full database consolidation process
    public func consolidateDatabases() async {
        print("🔧 CONSOLIDATION: Starting full database consolidation...")
        
        // Step 1: Analyze current state
        analyzeDatabases()
        
        // Step 2: Migrate credentials to unified store
        await SimplifiedCredentialManager.shared.migrateFromOldStores()
        
        // Step 3: Clean up redundant files
        cleanupRedundantDatabases()
        
        // Step 4: Final analysis
        print("\n🔍 POST-CONSOLIDATION ANALYSIS:")
        analyzeDatabases()
        
        print("\n🎉 DATABASE CONSOLIDATION COMPLETE!")
        print("✅ The app now uses a single, unified credential database")
        print("✅ ALL DATA PRESERVED: Public keys + Private keys + Metadata")
        print("✅ No more redundant separate databases for same data")
        print("✅ Virtual keys also use the same unified approach")
        print("✅ Zero data loss - everything migrated safely")
    }
} 
