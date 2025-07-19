// Copyright 2025 FIDO3.ai
// Generated on 2025-7-19
import Foundation

// MARK: - Virtual Key Database Cleanup Utility
// Removes redundant database files from virtual keys, keeping only the unified WebAuthnClient.db

public final class VirtualKeyCleanupUtility {
    
    public static let shared = VirtualKeyCleanupUtility()
    
    private init() {}
    
    /// Clean up redundant database files from ALL virtual keys
    public func cleanupAllVirtualKeys() async {
        print("🧹 CLEANUP: Starting cleanup of redundant databases in all virtual keys...")
        
        do {
            let virtualKeys = try await VirtualHardwareKeyManager.shared.listVirtualKeys()
            print("🧹 Found \(virtualKeys.count) virtual keys to clean")
            
            var totalCleaned = 0
            var totalSize: Int64 = 0
            
            for virtualKey in virtualKeys {
                let (cleaned, size) = await cleanupVirtualKey(virtualKey)
                totalCleaned += cleaned
                totalSize += size
            }
            
            print("🧹 ✅ CLEANUP COMPLETE:")
            print("   - Cleaned \(totalCleaned) redundant database files")
            print("   - Freed \(formatSize(totalSize)) of disk space")
            print("   - All virtual keys now use ONLY unified WebAuthnClient.db")
            
        } catch {
            print("🧹 ❌ Failed to cleanup virtual keys: \(error)")
        }
    }
    
    /// Clean up redundant database files from a specific virtual key
    public func cleanupVirtualKey(_ virtualKey: VirtualHardwareKey) async -> (filesRemoved: Int, bytesFreed: Int64) {
        print("🧹 Cleaning up redundant databases in virtual key: \(virtualKey.name)")
        
        do {
            // Mount the virtual key
            let mountPoint = try await VirtualHardwareKeyManager.shared.mountDiskImage(
                virtualKey.diskImagePath, 
                password: virtualKey.isLocked ? nil : nil
            )
            
            // List of redundant database files to remove
            let redundantDatabases = [
                "VirtualKey.db",
                "VirtualKeyCredentials.db", 
                "ServerCredentials.db"
            ]
            
            var filesRemoved = 0
            var bytesFreed: Int64 = 0
            
            for dbName in redundantDatabases {
                let removed = removeRedundantDatabase(dbName, from: mountPoint)
                filesRemoved += removed.count
                bytesFreed += removed.size
            }
            
            if filesRemoved > 0 {
                print("🧹 ✅ Cleaned \(virtualKey.name): removed \(filesRemoved) files, freed \(formatSize(bytesFreed))")
            } else {
                print("🧹 ✅ \(virtualKey.name) already clean")
            }
            
            return (filesRemoved, bytesFreed)
            
        } catch {
            print("🧹 ❌ Failed to cleanup \(virtualKey.name): \(error)")
            return (0, 0)
        }
    }
    
    /// Remove a specific redundant database and its associated files
    private func removeRedundantDatabase(_ dbName: String, from mountPoint: URL) -> (count: Int, size: Int64) {
        let fileManager = FileManager.default
        let extensions = ["", "-shm", "-wal"]
        
        var removedCount = 0
        var totalSize: Int64 = 0
        
        for ext in extensions {
            let fileName = "\(dbName)\(ext)"
            let fileURL = mountPoint.appendingPathComponent(fileName)
            
            if fileManager.fileExists(atPath: fileURL.path) {
                do {
                    // Get file size before deletion
                    let attributes = try fileManager.attributesOfItem(atPath: fileURL.path)
                    let size = attributes[.size] as? Int64 ?? 0
                    
                    // Remove the file
                    try fileManager.removeItem(at: fileURL)
                    
                    removedCount += 1
                    totalSize += size
                    print("🧹 🗑️ Removed redundant file: \(fileName) (\(formatSize(size)))")
                    
                } catch {
                    print("🧹 ⚠️ Failed to remove \(fileName): \(error)")
                }
            }
        }
        
        return (removedCount, totalSize)
    }
    
    /// Analyze virtual key databases and show what would be cleaned
    public func analyzeVirtualKey(_ virtualKey: VirtualHardwareKey) async {
        print("🧹 ANALYZING: \(virtualKey.name)")
        print(String(repeating: "=", count: 50))
        
        do {
            let mountPoint = try await VirtualHardwareKeyManager.shared.mountDiskImage(
                virtualKey.diskImagePath,
                password: virtualKey.isLocked ? nil : nil
            )
            
            let fileManager = FileManager.default
            let contents = try fileManager.contentsOfDirectory(at: mountPoint, includingPropertiesForKeys: [.fileSizeKey])
            
            let dbFiles = contents.filter { $0.lastPathComponent.hasSuffix(".db") || $0.lastPathComponent.contains(".db-") }
            
            var unifiedFiles: [URL] = []
            var redundantFiles: [URL] = []
            
            for file in dbFiles {
                let fileName = file.lastPathComponent
                if fileName.hasPrefix("WebAuthnClient.db") {
                    unifiedFiles.append(file)
                } else {
                    redundantFiles.append(file)
                }
            }
            
            print("✅ UNIFIED DATABASE (keep):")
            for file in unifiedFiles {
                let size = getFileSize(file)
                print("   \(file.lastPathComponent) - \(formatSize(size))")
            }
            
            print("❌ REDUNDANT DATABASES (remove):")
            var totalRedundantSize: Int64 = 0
            for file in redundantFiles {
                let size = getFileSize(file)
                totalRedundantSize += size
                print("   \(file.lastPathComponent) - \(formatSize(size))")
            }
            
            if redundantFiles.isEmpty {
                print("   (none - already clean)")
            } else {
                print("💾 Total redundant space: \(formatSize(totalRedundantSize))")
            }
            
        } catch {
            print("❌ Failed to analyze \(virtualKey.name): \(error)")
        }
    }
    
    // MARK: - Helper Methods
    
    private func getFileSize(_ url: URL) -> Int64 {
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
    
    /// Public interface to clean up a specific virtual key by name
    public func cleanupVirtualKey(named keyName: String) async {
        do {
            let virtualKeys = try await VirtualHardwareKeyManager.shared.listVirtualKeys()
            guard let virtualKey = virtualKeys.first(where: { $0.name == keyName }) else {
                print("🧹 ❌ Virtual key '\(keyName)' not found")
                return
            }
            
            let _ = await cleanupVirtualKey(virtualKey)
            
        } catch {
            print("🧹 ❌ Failed to find virtual key '\(keyName)': \(error)")
        }
    }
} 
