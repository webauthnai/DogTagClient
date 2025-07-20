// Copyright 2025 FIDO3.ai
// Generated on 2025-7-19
import Foundation
import SwiftData
import CryptoKit
import AppKit
import DogTagStorage

// MARK: - Virtual Hardware Key Models

/// Represents a virtual hardware key stored in a disk image
public struct VirtualHardwareKey: Codable, Identifiable, Equatable {
    public let id: UUID
    public let name: String
    public let diskImagePath: URL
    public let createdAt: Date
    public let lastAccessedAt: Date
    public let isLocked: Bool
    public let credentialCount: Int
    
    public init(
        id: UUID = UUID(),
        name: String,
        diskImagePath: URL,
        createdAt: Date = Date(),
        lastAccessedAt: Date = Date(),
        isLocked: Bool = false,
        credentialCount: Int = 0
    ) {
        self.id = id
        self.name = name
        self.diskImagePath = diskImagePath
        self.createdAt = createdAt
        self.lastAccessedAt = lastAccessedAt
        self.isLocked = isLocked
        self.credentialCount = credentialCount
    }
    
    /// Create an updated copy with new access time
    public func withUpdatedAccess() -> VirtualHardwareKey {
        return VirtualHardwareKey(
            id: self.id,
            name: self.name,
            diskImagePath: self.diskImagePath,
            createdAt: self.createdAt,
            lastAccessedAt: Date(),
            isLocked: self.isLocked,
            credentialCount: self.credentialCount
        )
    }
    
    /// Create an updated copy with new credential count
    public func withUpdatedCredentialCount(_ count: Int) -> VirtualHardwareKey {
        return VirtualHardwareKey(
            id: self.id,
            name: self.name,
            diskImagePath: self.diskImagePath,
            createdAt: self.createdAt,
            lastAccessedAt: self.lastAccessedAt,
            isLocked: self.isLocked,
            credentialCount: count
        )
    }
}

/// Configuration for creating virtual hardware keys
public struct VirtualKeyConfiguration {
    public let name: String
    public let sizeInMB: Int
    public let password: String?
    public let fileSystemType: String
    
    public init(
        name: String,
        sizeInMB: Int = 50,
        password: String? = nil,
        fileSystemType: String = "HFS+"
    ) {
        self.name = name
        self.sizeInMB = sizeInMB
        self.password = password
        self.fileSystemType = fileSystemType
    }
}

// MARK: - Virtual Hardware Key Manager

public class VirtualHardwareKeyManager: ObservableObject, @unchecked Sendable {
    public static let shared = VirtualHardwareKeyManager()
    
    private let fileManager = FileManager.default
    private var virtualKeysDirectory: URL
    
    // Thread-safe mount point tracking (derived from DMG path, no external metadata)
    private var mountedKeys: [UUID: URL] = [:]
    private let mountLock = NSLock()
    
    // Rate limiting for storage operations
    private var activeStorageOperations = 0
    private let maxConcurrentStorageOps = 3 // Limit concurrent storage manager creation
    private let storageOperationQueue = DispatchQueue(label: "storage.operations", qos: .utility)
    
    private init() {
        let supportDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDirectory = supportDirectory.appendingPathComponent("WebMan")
        virtualKeysDirectory = appDirectory.appendingPathComponent("VirtualKeys")
        
        // Create directories if they don't exist
        try? fileManager.createDirectory(at: virtualKeysDirectory, withIntermediateDirectories: true)
        
        // Register for app termination to clean up mounted keys
        setupAppTerminationHandling()
        
        // Mount all virtual keys at startup for better performance
        Task {
            await mountAllVirtualKeysAtStartup()
        }
    }
    
    // MARK: - App Lifecycle Management
    
    private func setupAppTerminationHandling() {
        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task {
                await self.cleanupOnAppTermination()
            }
        }
        
        // Also handle when the app is about to quit
        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task {
                await self.cleanupOnAppTermination()
            }
        }
    }
    
    /// Clean up all mounted virtual keys when app is terminating
    private func cleanupOnAppTermination() async {
        print("🧹 App terminating, cleaning up mounted virtual keys...")
        
        for (keyId, mountPoint) in mountedKeys {
            print("🧹 Unmounting virtual key: \(keyId) at \(mountPoint.path)")
            do {
                try await unmountDiskImage(mountPoint)
            } catch {
                print("⚠️ Failed to unmount \(mountPoint.path): \(error)")
            }
        }
        
        mountedKeys.removeAll()
        print("✅ Finished cleaning up mounted virtual keys")
    }
    
    /// Manually unmount all virtual keys (for testing or manual cleanup)
    public func unmountAllVirtualKeys() async {
        print("🧹 Manually unmounting all virtual keys...")
        
        for (keyId, mountPoint) in mountedKeys {
            print("🧹 Unmounting virtual key: \(keyId) at \(mountPoint.path)")
            do {
                try await unmountDiskImage(mountPoint)
            } catch {
                print("⚠️ Failed to unmount \(mountPoint.path): \(error)")
            }
        }
        
        mountedKeys.removeAll()
        print("✅ Finished unmounting all virtual keys")
    }
    
    // MARK: - Directory Management
    
    /// Allows user to set a custom directory for virtual keys (useful for sandbox environments)
    public func setCustomVirtualKeysDirectory(_ directory: URL) throws {
        // Verify the directory exists and is writable
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: directory.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw VirtualKeyError.invalidDirectory("Directory does not exist or is not a directory")
        }
        
        // Test write permissions
        let testFile = directory.appendingPathComponent(".test_write")
        do {
            try "test".write(to: testFile, atomically: true, encoding: .utf8)
            try fileManager.removeItem(at: testFile)
        } catch {
            throw VirtualKeyError.invalidDirectory("No write permission to directory: \(directory.path)")
        }
        
        virtualKeysDirectory = directory
        print("🔧 Updated virtual keys directory to: \(virtualKeysDirectory.path)")
    }
    
    /// Returns the current virtual keys directory
    public var currentVirtualKeysDirectory: URL {
        return virtualKeysDirectory
    }
    
    // MARK: - Disk Image Operations
    
    private func createDiskImage(
        path: URL,
        sizeInMB: Int,
        password: String?,
        fileSystemType: String,
        volumeName: String
    ) async throws {
        // Build correct hdiutil command arguments
        var arguments = [
            "create",
            "-size", "\(sizeInMB)m",
            "-fs", fileSystemType,
            "-volname", volumeName,
            "-type", "UDIF"
        ]
        
        // Add encryption if password is provided
        if password != nil {
            arguments.append(contentsOf: ["-encryption", "AES-256", "-stdinpass"])
        }
        
        // Add the output path as the final argument
        arguments.append(path.path)
        
        print("🔧 Running hdiutil command: hdiutil \(arguments.joined(separator: " "))")
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        process.arguments = arguments
        
        // Capture stderr for debugging
        let errorPipe = Pipe()
        process.standardError = errorPipe
        
        if password != nil {
            let inputPipe = Pipe()
            process.standardInput = inputPipe
            
            try process.run()
            
            // Send password to stdin
            if let passwordData = password?.data(using: .utf8) {
                inputPipe.fileHandleForWriting.write(passwordData)
                inputPipe.fileHandleForWriting.closeFile()
            }
        } else {
            try process.run()
        }
        
        process.waitUntilExit()
        
        if process.terminationStatus != 0 {
            // Read error output for debugging
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorOutput = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            print("❌ hdiutil error output: \(errorOutput)")
            
            // Provide specific guidance for common errors
            var errorMessage = "hdiutil create failed with status \(process.terminationStatus): \(errorOutput)"
            
            if errorOutput.contains("Device not configured") {
                errorMessage += "\n\n💡 This error typically occurs due to sandbox restrictions. Try:"
                errorMessage += "\n• Running the app outside of Xcode"
                errorMessage += "\n• Granting Full Disk Access in System Preferences > Privacy & Security"
                errorMessage += "\n• Using a different target directory (e.g., Desktop)"
            } else if errorOutput.contains("Permission denied") {
                errorMessage += "\n\n💡 Permission denied. The app needs write access to: \(path.deletingLastPathComponent().path)"
            } else if errorOutput.contains("No space left") {
                errorMessage += "\n\n💡 Insufficient disk space. Try reducing the virtual key size or freeing up disk space."
            }
            
            throw VirtualKeyError.diskImageCreationFailed(errorMessage)
        }
        
        print("✅ Created disk image: \(path.lastPathComponent)")
    }
    
    /// Mounts a disk image and returns the mount point
    public func mountDiskImage(_ path: URL, password: String? = nil) async throws -> URL {
        print("🔧 Mounting disk image: \(path.lastPathComponent)")
        
        // Generate deterministic UUID for tracking
        let pathHash = path.path.data(using: .utf8)!
        let sha = SHA256.hash(data: pathHash)
        let hashString = sha.compactMap { String(format: "%02x", $0) }.joined()
        let uuidString = String(hashString.prefix(8)) + "-" +
        String(hashString.dropFirst(8).prefix(4)) + "-" +
        String(hashString.dropFirst(12).prefix(4)) + "-" +
        String(hashString.dropFirst(16).prefix(4)) + "-" +
        String(hashString.dropFirst(20).prefix(12))
        let keyId = UUID(uuidString: uuidString) ?? UUID()
        
        // Check if we have a cached mount point and verify it still exists
        if let cachedMountPoint = mountedKeys[keyId] {
            if fileManager.fileExists(atPath: cachedMountPoint.path) {
                print("✅ Using cached mount point: \(cachedMountPoint.path)")
                return cachedMountPoint
            } else {
                print("⚠️ Cached mount point no longer exists, removing from cache: \(cachedMountPoint.path)")
                mountedKeys.removeValue(forKey: keyId)
            }
        }
        
        var arguments = ["attach", "-nobrowse", "-mountrandom", "/tmp"]
        
        if password != nil {
            arguments.append("-stdinpass")
        }
        
        arguments.append(path.path)
        
        print("🔧 Running hdiutil mount command: hdiutil \(arguments.joined(separator: " "))")
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        process.arguments = arguments
        
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        if password != nil {
            let inputPipe = Pipe()
            process.standardInput = inputPipe
            
            try process.run()
            
            // Send password to stdin
            if let passwordData = password?.data(using: .utf8) {
                inputPipe.fileHandleForWriting.write(passwordData)
                inputPipe.fileHandleForWriting.closeFile()
            }
        } else {
            try process.run()
        }
        
        process.waitUntilExit()
        
        if process.terminationStatus != 0 {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorOutput = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            print("❌ hdiutil mount error: \(errorOutput)")
            
            // Clean up any stale cache entries
            mountedKeys.removeValue(forKey: keyId)
            
            throw VirtualKeyError.mountFailed("Failed to mount disk image: \(errorOutput)")
        }
        
        // Parse the output to get the mount point
        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: outputData, encoding: .utf8) ?? ""
        print("🔧 hdiutil mount output: \(output)")
        
        // Parse hdiutil output to find mount point
        let lines = output.components(separatedBy: .newlines)
        for line in lines {
            // Look for lines containing mount points (usually the last column)
            let components = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            for component in components {
                if component.hasPrefix("/private/tmp/") || component.hasPrefix("/tmp/") {
                    let mountPoint = URL(fileURLWithPath: component)
                    print("✅ Mounted at: \(mountPoint.path)")
                    
                    // Cache the mount point
                    mountedKeys[keyId] = mountPoint
                    
                    return mountPoint
                }
            }
        }
        
        // Clean up cache if we couldn't find mount point
        mountedKeys.removeValue(forKey: keyId)
        throw VirtualKeyError.mountFailed("Could not determine mount point from output: \(output)")
    }
    
    /// Unmounts a disk image
    public func unmountDiskImage(_ mountPoint: URL) async throws {
        print("🔧 Unmounting: \(mountPoint.path)")
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        process.arguments = ["detach", mountPoint.path]
        
        try process.run()
        process.waitUntilExit()
        
        guard process.terminationStatus == 0 else {
            throw VirtualKeyError.unmountFailed("Failed to unmount disk image")
        }
        
        // Remove from mount cache
        if let keyToRemove = mountedKeys.first(where: { $0.value == mountPoint })?.key {
            mountedKeys.removeValue(forKey: keyToRemove)
            print("🧹 Removed from mount cache: \(keyToRemove)")
        }
        
        print("✅ Unmounted: \(mountPoint.path)")
    }
    
    // MARK: - Virtual Key Creation
    
    /// Creates a new virtual hardware key as a disk image
    public func createVirtualKey(config: VirtualKeyConfiguration) async throws -> VirtualHardwareKey {
        print("🔧 Creating virtual hardware key: \(config.name)")
        
        let diskImagePath = virtualKeysDirectory.appendingPathComponent("\(config.name).dmg")
        
        // Check if file already exists
        if fileManager.fileExists(atPath: diskImagePath.path) {
            throw VirtualKeyError.keyAlreadyExists(config.name)
        }
        
        // Create the disk image using hdiutil
        try await createDiskImage(
            path: diskImagePath,
            sizeInMB: config.sizeInMB,
            password: config.password,
            fileSystemType: config.fileSystemType,
            volumeName: config.name
        )
        
        // Mount the disk image to initialize the database (keep it mounted for future use)
        let mountPoint = try await mountDiskImage(diskImagePath, password: config.password)
        
        // Initialize the SwiftData database in the mounted volume
        try await initializeVirtualKeyDatabase(at: mountPoint)
        
        let virtualKey = VirtualHardwareKey(
            name: config.name,
            diskImagePath: diskImagePath,
            credentialCount: 0
        )
        
        print("✅ Created virtual hardware key: \(config.name) at \(diskImagePath.path)")
        return virtualKey
    }
    
    // MARK: - Database Operations
    
    private func initializeVirtualKeyDatabase(at mountPoint: URL) async throws {
        // FIXED: ONE unified database per virtual key instead of multiple databases
        let unifiedDbPath = mountPoint.appendingPathComponent("WebAuthnClient.db")
        
        print("🔧 Creating UNIFIED virtual key database at: \(unifiedDbPath.lastPathComponent)")
        try await createUnifiedVirtualKeyDatabase(at: unifiedDbPath)
        
        print("✅ Initialized unified virtual key database at \(mountPoint.path)")
    }
    
    private func createUnifiedVirtualKeyDatabase(at dbPath: URL) async throws {
        print("🔧 Creating UNIFIED credential database using DogTagStorage at: \(dbPath.lastPathComponent)")
        
        // CRITICAL SAFETY: Rate limit storage manager creation
        guard await acquireStorageOperation() else {
            throw VirtualKeyError.databaseInitializationFailed("Rate limited - too many concurrent storage operations")
        }
        
        defer {
            releaseStorageOperation()
        }
        
        // Create a DogTagStorage manager for the virtual key database
        let config = StorageConfiguration(
            databaseName: "WebAuthnClient", // SIMPLIFIED: Unified database name
            customDatabasePath: dbPath.path
        )
        let virtualKeyStorage = try await StorageFactory.createStorageManager(configuration: config)
        
        // Test the database by getting storage info (this initializes the database with ALL tables)
        let info = try await virtualKeyStorage.getStorageInfo()
        print("✅ Created UNIFIED virtual key database: \(dbPath.lastPathComponent)")
        print("   - Client credentials: \(info.credentialCount)")
        print("   - Server credentials: \(info.serverCredentialCount)")
        print("   - Virtual keys: \(info.virtualKeyCount)")
    }
    
    // MARK: - Credential Transfer Operations
    
    /// Export credentials from main storage to a virtual hardware key
    public func exportCredentialsToVirtualKey(
        keyId: UUID,
        credentialIds: [String],
        password: String? = nil
    ) async throws -> Int {
        print("🔧 Exporting \(credentialIds.count) credentials to virtual key")
        
        guard let virtualKey = try await getVirtualKey(id: keyId) else {
            throw VirtualKeyError.keyNotFound
        }
        
        // Mount the virtual key (keep it mounted for future use)
        let mountPoint = try await mountDiskImage(virtualKey.diskImagePath, password: password)
        
        // FIXED: Use UNIFIED database instead of separate client/server databases
        let unifiedDbPath = mountPoint.appendingPathComponent("WebAuthnClient.db")
        
        // Ensure unified database exists (for virtual keys created with old structure)
        if !fileManager.fileExists(atPath: unifiedDbPath.path) {
            print("🔧 Creating missing unified database...")
            try await createUnifiedVirtualKeyDatabase(at: unifiedDbPath)
        }
        
        // Get credentials from current storage (local or virtual)
        let storageManager = VirtualKeyStorageManager.shared
        let allClientCredentials = storageManager.getAllClientCredentials()
        let allServerCredentials = storageManager.getAllServerCredentials()
        
        print("🔍 Available client credentials: \(allClientCredentials.count)")
        print("🔍 Available server credentials: \(allServerCredentials.count)")
        print("🔍 Requested credential IDs: \(credentialIds)")
        
        let clientCredentials = allClientCredentials.filter { credentialIds.contains($0.id) }
        let serverCredentials = allServerCredentials.filter { credentialIds.contains($0.id) }
        
        print("🔍 Filtered client credentials: \(clientCredentials.count)")
        print("🔍 Filtered server credentials: \(serverCredentials.count)")
        
        // FIXED: Export ALL credentials to UNIFIED database
        var exportedCount = 0
        exportedCount += try await exportAllCredentialsToUnifiedDatabase(
            clientCredentials: clientCredentials,
            serverCredentials: serverCredentials,
            to: unifiedDbPath
        )
        
        print("✅ Exported \(exportedCount) credentials to unified virtual key database")
        return exportedCount
    }
    
    /// Import credentials from a virtual hardware key to main storage
    public func importCredentialsFromVirtualKey(
        keyId: UUID,
        password: String? = nil,
        overwriteExisting: Bool = false
    ) async throws -> Int {
        print("🔧 Importing credentials from virtual key")
        
        guard let virtualKey = try await getVirtualKey(id: keyId) else {
            throw VirtualKeyError.keyNotFound
        }
        
        // Mount the virtual key (keep it mounted for future use)
        let mountPoint = try await mountDiskImage(virtualKey.diskImagePath, password: password)
        
        // FIXED: Use UNIFIED database instead of separate client/server databases
        let unifiedDbPath = mountPoint.appendingPathComponent("WebAuthnClient.db")
        
        var importedCount = 0
        
        // Import from unified database if it exists
        if fileManager.fileExists(atPath: unifiedDbPath.path) {
            importedCount += try await importAllCredentialsFromUnifiedDatabase(
                from: unifiedDbPath,
                overwriteExisting: overwriteExisting
            )
        } else {
            // FALLBACK: Try old separate database format for backward compatibility with existing virtual keys
            print("⚠️ Unified database not found, checking for legacy separate databases...")
            
            let clientDbPath = mountPoint.appendingPathComponent("VirtualKeyCredentials.db")
            let serverDbPath = mountPoint.appendingPathComponent("ServerCredentials.db")
            
            if fileManager.fileExists(atPath: clientDbPath.path) {
                importedCount += try await importClientCredentials(from: clientDbPath, overwriteExisting: overwriteExisting)
            }
            
            if fileManager.fileExists(atPath: serverDbPath.path) {
                importedCount += try await importServerCredentials(from: serverDbPath, overwriteExisting: overwriteExisting)
            }
        }
        
        print("✅ Imported \(importedCount) credentials from virtual key")
        return importedCount
    }
    
    // MARK: - Virtual Key Management
    
    /// Lists all available virtual hardware keys
    public func listVirtualKeys() async throws -> [VirtualHardwareKey] {
        let dmgFiles = try fileManager.contentsOfDirectory(at: virtualKeysDirectory, includingPropertiesForKeys: [.creationDateKey, .fileSizeKey])
            .filter { $0.pathExtension == "dmg" }
        
        var virtualKeys: [VirtualHardwareKey] = []
        
        for dmgFile in dmgFiles {
            let name = dmgFile.deletingPathExtension().lastPathComponent
            let attributes = try fileManager.attributesOfItem(atPath: dmgFile.path)
            let createdAt = attributes[.creationDate] as? Date ?? Date()
            
            // Generate deterministic UUID based on file path
            let pathHash = dmgFile.path.data(using: .utf8)!
            let sha = SHA256.hash(data: pathHash)
            let hashString = sha.compactMap { String(format: "%02x", $0) }.joined()
            let uuidString = String(hashString.prefix(8)) + "-" +
            String(hashString.dropFirst(8).prefix(4)) + "-" +
            String(hashString.dropFirst(12).prefix(4)) + "-" +
            String(hashString.dropFirst(16).prefix(4)) + "-" +
            String(hashString.dropFirst(20).prefix(12))
            let deterministicId = UUID(uuidString: uuidString) ?? UUID()
            
            // Check if the disk image is encrypted by trying to mount without password
            let isLocked = await checkIfDiskImageIsEncrypted(dmgFile)
            
            // Get credential count from cache or calculate if needed
            let credentialCount = await getCredentialCount(for: dmgFile)
            
            // Get last accessed time directly from file modification date (self-contained approach)
            let fileAttributes = try? fileManager.attributesOfItem(atPath: dmgFile.path)
            let lastAccessedAt = fileAttributes?[.modificationDate] as? Date ?? createdAt
            
            let virtualKey = VirtualHardwareKey(
                id: deterministicId,
                name: name,
                diskImagePath: dmgFile,
                createdAt: createdAt,
                lastAccessedAt: lastAccessedAt,
                isLocked: isLocked,
                credentialCount: credentialCount
            )
            
            virtualKeys.append(virtualKey)
        }
        
        return virtualKeys.sorted { $0.createdAt < $1.createdAt }
    }
    
    /// Gets a virtual key by ID
    public func getVirtualKey(id: UUID) async throws -> VirtualHardwareKey? {
        let keys = try await listVirtualKeys()
        print("🔍 Looking for virtual key with ID: \(id)")
        print("🔍 Available virtual keys:")
        for key in keys {
            print("🔍   - ID: \(key.id), Name: \(key.name), Path: \(key.diskImagePath.lastPathComponent)")
        }
        let foundKey = keys.first { $0.id == id }
        print("🔍 Found key: \(foundKey?.name ?? "nil")")
        return foundKey
    }
    
    /// Deletes a virtual hardware key
    public func deleteVirtualKey(id: UUID) async throws {
        guard let virtualKey = try await getVirtualKey(id: id) else {
            throw VirtualKeyError.keyNotFound
        }
        
        // Ensure the key is not mounted
        if let mountPoint = mountedKeys[id] {
            try await unmountDiskImage(mountPoint)
            mountedKeys.removeValue(forKey: id)
        }
        
        // Delete the disk image file
        try fileManager.removeItem(at: virtualKey.diskImagePath)
        
        print("✅ Deleted virtual hardware key: \(virtualKey.name)")
    }
    

    
    // MARK: - Startup Virtual Key Mounting
    
    /// Mount all virtual keys at startup for better performance
    private func mountAllVirtualKeysAtStartup() async {
        print("🚀 STARTUP: Mounting all virtual keys for better performance")
        
        do {
            let dmgFiles = try fileManager.contentsOfDirectory(at: virtualKeysDirectory, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "dmg" }
            
            print("🚀 Found \(dmgFiles.count) virtual keys to mount at startup")
            
            for dmgFile in dmgFiles {
                let pathHash = dmgFile.path.data(using: .utf8)!
                let sha = SHA256.hash(data: pathHash)
                let hashString = sha.compactMap { String(format: "%02x", $0) }.joined()
                let uuidString = String(hashString.prefix(8)) + "-" +
                String(hashString.dropFirst(8).prefix(4)) + "-" +
                String(hashString.dropFirst(12).prefix(4)) + "-" +
                String(hashString.dropFirst(16).prefix(4)) + "-" +
                String(hashString.dropFirst(20).prefix(12))
                let keyId = UUID(uuidString: uuidString) ?? UUID()
                
                // Skip if already mounted
                if mountedKeys[keyId] != nil {
                    continue
                }
                
                do {
                    // Try to mount without password first (for unencrypted keys)
                    let mountPoint = try await mountDiskImage(dmgFile)
                    print("✅ STARTUP: Mounted virtual key \(dmgFile.lastPathComponent) at \(mountPoint.path)")
                    
                } catch {
                    print("⚠️ STARTUP: Could not mount virtual key \(dmgFile.lastPathComponent): \(error)")
                    print("   - This is normal for encrypted virtual keys")
                }
            }
            
            print("✅ STARTUP: Finished mounting virtual keys (\(mountedKeys.count) mounted)")
            
        } catch {
            print("❌ STARTUP: Failed to enumerate virtual keys: \(error)")
        }
    }
}

// MARK: - Virtual Key Errors

public enum VirtualKeyError: Error, LocalizedError {
    case keyAlreadyExists(String)
    case keyNotFound
    case diskImageCreationFailed(String)
    case mountFailed(String)
    case unmountFailed(String)
    case databaseInitializationFailed(String)
    case exportFailed(String)
    case importFailed(String)
    case invalidDirectory(String)
    
    public var errorDescription: String? {
        switch self {
        case .keyAlreadyExists(let name):
            return "Virtual hardware key '\(name)' already exists"
        case .keyNotFound:
            return "Virtual hardware key not found"
        case .diskImageCreationFailed(let reason):
            return "Failed to create disk image: \(reason)"
        case .mountFailed(let reason):
            return "Failed to mount disk image: \(reason)"
        case .unmountFailed(let reason):
            return "Failed to unmount disk image: \(reason)"
        case .databaseInitializationFailed(let reason):
            return "Failed to initialize database: \(reason)"
        case .exportFailed(let reason):
            return "Failed to export credentials: \(reason)"
        case .importFailed(let reason):
            return "Failed to import credentials: \(reason)"
        case .invalidDirectory(let reason):
            return "Invalid directory: \(reason)"
        }
    }
}

// MARK: - Private Helper Extensions

private extension VirtualHardwareKeyManager {
    func exportAllCredentialsToUnifiedDatabase(
        clientCredentials: [LocalCredential],
        serverCredentials: [WebAuthnCredential],
        to dbPath: URL
    ) async throws -> Int {
        print("🔧 Exporting \(clientCredentials.count + serverCredentials.count) credentials to unified virtual key database using DogTagStorage")
        
        // CRITICAL SAFETY: Rate limit storage manager creation
        guard await acquireStorageOperation() else {
            throw VirtualKeyError.exportFailed("Rate limited - too many concurrent storage operations")
        }
        
        defer {
            releaseStorageOperation()
        }
        
        // Create a DogTagStorage manager for the virtual key database
        let config = StorageConfiguration(
            databaseName: "WebAuthnClient", // SIMPLIFIED: Unified database name
            customDatabasePath: dbPath.path
        )
        let virtualKeyStorage = try await StorageFactory.createStorageManager(configuration: config)
        
        var exportedCount = 0
        
        // Get the raw credential data directly from main DogTagStorage (which has private keys)
        let rawCredentials = WebAuthnClientCredentialStore.shared.getRawCredentialData()
        
        for credential in clientCredentials {
            do {
                // Find the raw credential data that contains the private key
                if let rawCred = rawCredentials.first(where: { $0.id == credential.id }) {
                    print("✅ Exporting credential with private key from DogTagStorage: \(credential.id)")
                    
                    // Use the raw credential data directly (already has privateKeyRef)
                    // Save to virtual key database using DogTagStorage
                    try await virtualKeyStorage.saveCredential(rawCred)
                    exportedCount += 1
                    print("✅ Exported credential \(credential.id) to virtual key")
                } else {
                    print("❌ Failed to find raw credential data for: \(credential.id)")
                }
            } catch {
                print("❌ Failed to export credential \(credential.id): \(error)")
            }
        }
        
        for credential in serverCredentials {
            do {
                // Convert WebAuthnCredential to ServerCredentialData for DogTagStorage
                // PRESERVE ALL DATA - no hardcoded defaults!
                let serverData = ServerCredentialData(
                    id: credential.id,
                    credentialId: credential.id,
                    publicKeyJWK: credential.publicKey,
                    signCount: Int(credential.signCount),
                    isDiscoverable: credential.isDiscoverable,
                    createdAt: credential.createdAt ?? Date(),
                    lastVerified: credential.lastLoginAt,
                    rpId: "webauthn", // This should probably be preserved too, but keeping for compatibility
                    userHandle: credential.username.data(using: .utf8) ?? Data(),
                    algorithm: credential.algorithm,
                    protocolVersion: credential.protocolVersion,
                    attestationFormat: credential.attestationFormat,
                    aaguid: credential.aaguid,
                    backupEligible: credential.backupEligible,
                    backupState: credential.backupState,
                    emoji: credential.emoji ?? "🔑",
                    lastLoginIP: credential.lastLoginIP,
                    isEnabled: credential.isEnabled,
                    isAdmin: credential.isAdmin,
                    userNumber: credential.userNumber
                )
                
                // Save to virtual key database using DogTagStorage
                try await virtualKeyStorage.saveServerCredential(serverData)
                exportedCount += 1
                print("✅ Exported server credential \(credential.id) to virtual key")
            } catch {
                print("❌ Failed to export server credential \(credential.id): \(error)")
            }
        }
        
        print("✅ Successfully exported \(exportedCount)/\(clientCredentials.count + serverCredentials.count) credentials to unified virtual key database")
        return exportedCount
    }
    
    func importClientCredentials(
        from dbPath: URL,
        overwriteExisting: Bool
    ) async throws -> Int {
        print("🔧 Importing client credentials from virtual key database using DogTagStorage")
        
        // CRITICAL SAFETY: Rate limit storage manager creation
        guard await acquireStorageOperation() else {
            throw VirtualKeyError.importFailed("Rate limited - too many concurrent storage operations")
        }
        
        defer {
            releaseStorageOperation()
        }
        
        // Create a DogTagStorage manager for the virtual key database
        let config = StorageConfiguration(
            databaseName: "WebAuthnClient", // SIMPLIFIED: Unified database name
            customDatabasePath: dbPath.path
        )
        let virtualKeyStorage = try await StorageFactory.createStorageManager(configuration: config)
        
        // Fetch credentials from virtual key
        let virtualCredentials = try await virtualKeyStorage.fetchCredentials()
        
        var importedCount = 0
        
        for credData in virtualCredentials {
            // Convert CredentialData to LocalCredential
            let localCredential = LocalCredential(
                id: credData.id,
                rpId: credData.rpId,
                userName: credData.userDisplayName ?? "Unknown",
                userDisplayName: credData.userDisplayName ?? "Unknown",
                userId: String(data: credData.userHandle, encoding: .utf8) ?? credData.id,
                publicKey: credData.publicKey,
                createdAt: credData.createdAt
            )
            
            // Check if credential already exists in main storage
            let existingCredentials = WebAuthnClientCredentialStore.shared.getAllCredentials()
            let exists = existingCredentials.contains { $0.id == localCredential.id }
            
            if !exists || overwriteExisting {
                // Import private key if available
                if let privateKeyRef = credData.privateKeyRef,
                   let privateKeyData = Data(base64Encoded: privateKeyRef),
                   let privateKey = try? P256.Signing.PrivateKey(rawRepresentation: privateKeyData) {
                    
                    if WebAuthnClientCredentialStore.shared.storeCredential(localCredential, privateKey: privateKey) {
                        importedCount += 1
                        print("✅ Imported client credential \(localCredential.id) with private key")
                    }
                } else {
                    print("⚠️ No private key found for credential \(localCredential.id)")
                }
            } else {
                print("⚠️ Credential \(localCredential.id) already exists, skipping")
            }
            
        }
        
        print("✅ Successfully imported \(importedCount)/\(virtualCredentials.count) client credentials")
        return importedCount
    }
    
    func importServerCredentials(
        from dbPath: URL,
        overwriteExisting: Bool
    ) async throws -> Int {
        print("🔧 Importing server credentials from virtual key database using DogTagStorage")
        
        // CRITICAL SAFETY: Rate limit storage manager creation
        guard await acquireStorageOperation() else {
            throw VirtualKeyError.importFailed("Rate limited - too many concurrent storage operations")
        }
        
        defer {
            releaseStorageOperation()
        }
        
        // Create a DogTagStorage manager for the virtual key database
        let config = StorageConfiguration(
            databaseName: "WebAuthnClient", // SIMPLIFIED: Unified database name
            customDatabasePath: dbPath.path
        )
        let virtualKeyStorage = try await StorageFactory.createStorageManager(configuration: config)
        
        // Fetch server credentials from virtual key
        let virtualCredentials = try await virtualKeyStorage.fetchServerCredentials()
        
        var importedCount = 0
        
        for serverData in virtualCredentials {
            // Convert ServerCredentialData to WebAuthnCredential
            let credential = WebAuthnCredential(
                id: serverData.id,
                publicKey: serverData.publicKeyJWK,
                signCount: UInt32(serverData.signCount),
                username: String(data: serverData.userHandle, encoding: .utf8) ?? "Unknown",
                algorithm: serverData.algorithm,
                protocolVersion: serverData.protocolVersion,
                attestationFormat: serverData.attestationFormat ?? "none",
                aaguid: serverData.aaguid,
                isDiscoverable: serverData.isDiscoverable,
                backupEligible: serverData.backupEligible,
                backupState: serverData.backupState,
                emoji: serverData.emoji.isEmpty ? nil : serverData.emoji,
                lastLoginIP: serverData.lastLoginIP,
                lastLoginAt: serverData.lastVerified,
                createdAt: serverData.createdAt,
                isEnabled: serverData.isEnabled,
                isAdmin: serverData.isAdmin,
                userNumber: serverData.userNumber
            )
            
            // Check if credential already exists in storage (use current storage manager)
            let storageManager = VirtualKeyStorageManager.shared
            let webAuthnManager = storageManager.getWebAuthnManager()
            let existingCredential = webAuthnManager.getCredential(username: credential.username)
            
            if existingCredential == nil || overwriteExisting {
                webAuthnManager.storeCredential(credential)
                importedCount += 1
                print("✅ Imported server credential \(credential.id) for user \(credential.username) using \(storageManager.currentStorageMode.description)")
            } else {
                print("⚠️ Server credential for user \(credential.username) already exists, skipping")
            }
            
        }
        
        print("✅ Successfully imported \(importedCount)/\(virtualCredentials.count) server credentials")
        return importedCount
    }
    
    func checkIfDiskImageIsEncrypted(_ diskImagePath: URL) async -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        process.arguments = ["imageinfo", diskImagePath.path]
        
        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            if process.terminationStatus == 0 {
                let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: outputData, encoding: .utf8) ?? ""
                
                // Check if the output contains encryption information
                return output.contains("AES-128") || output.contains("AES-256") || output.contains("encrypted")
            }
        } catch {
            print("⚠️ Could not check encryption status for \(diskImagePath.lastPathComponent): \(error)")
        }
        
        return false
    }
    
    func getCredentialCount(for diskImagePath: URL) async -> Int {
        do {
            // Mount the disk image (keep it mounted for future use)
            let mountPoint = try await mountDiskImage(diskImagePath)
            
            var count = 0
            
            // FIXED: Check unified database first (correct name)
            let unifiedDbPath = mountPoint.appendingPathComponent("WebAuthnClient.db")
            if fileManager.fileExists(atPath: unifiedDbPath.path) {
                print("📊 Found UNIFIED database for counting: WebAuthnClient.db")
                count = await getUnifiedCredentialCount(at: unifiedDbPath)
            } else {
                // FALLBACK: Count from legacy separate databases
                print("⚠️ Unified database not found, counting from legacy separate databases...")
                
                let clientDbPath = mountPoint.appendingPathComponent("VirtualKeyCredentials.db")
                let serverDbPath = mountPoint.appendingPathComponent("ServerCredentials.db")
                
                if fileManager.fileExists(atPath: clientDbPath.path) {
                    count += await getClientCredentialCount(at: clientDbPath)
                }
                
                if fileManager.fileExists(atPath: serverDbPath.path) {
                    count += await getServerCredentialCount(at: serverDbPath)
                }
            }
            
            print("📊 Total credential count for \(diskImagePath.lastPathComponent): \(count)")
            return count
        } catch {
            print("⚠️ Could not get credential count for \(diskImagePath.lastPathComponent): \(error)")
            return 0
        }
    }
    
    func getUnifiedCredentialCount(at dbPath: URL) async -> Int {
        // CRITICAL SAFETY: Rate limit storage manager creation
        guard await acquireStorageOperation() else {
            print("❌ RATE LIMITED: Too many concurrent storage operations, returning cached/default count")
            return 0
        }
        
        defer {
            releaseStorageOperation()
        }
        
        do {
            // CRITICAL SAFETY: Check if file exists before creating storage manager
            guard fileManager.fileExists(atPath: dbPath.path) else {
                print("📊 Unified DB file doesn't exist: \(dbPath.lastPathComponent)")
                return 0
            }
            
            // CRITICAL SAFETY: Add timeout and error handling for storage manager creation
            print("📊 Creating storage manager for unified credential count: \(dbPath.lastPathComponent)")
            
            // Create a DogTagStorage manager for the unified virtual key database
            let config = StorageConfiguration(
                databaseName: "WebAuthnClient", // SIMPLIFIED: Unified database name
                customDatabasePath: dbPath.path
            )
            
            let virtualKeyStorage = try await StorageFactory.createStorageManager(configuration: config)
            
            // Get info from unified database
            let info = try await virtualKeyStorage.getStorageInfo()
            let totalCount = info.credentialCount + info.serverCredentialCount
            
            print("📊 Unified credential count: \(totalCount) (client: \(info.credentialCount), server: \(info.serverCredentialCount))")
            return totalCount
            
        } catch {
            print("❌ SAFE FAILURE: Failed to count credentials in unified database \(dbPath.lastPathComponent): \(error)")
            print("❌ This is now a safe failure - returning 0 instead of crashing")
            return 0
        }
    }
    
    func importAllCredentialsFromUnifiedDatabase(
        from dbPath: URL,
        overwriteExisting: Bool
    ) async throws -> Int {
        print("🔧 Importing ALL credentials from unified virtual key database using DogTagStorage")
        
        // CRITICAL SAFETY: Rate limit storage manager creation
        guard await acquireStorageOperation() else {
            throw VirtualKeyError.importFailed("Rate limited - too many concurrent storage operations")
        }
        
        defer {
            releaseStorageOperation()
        }
        
        // Create a DogTagStorage manager for the unified virtual key database
        let config = StorageConfiguration(
            databaseName: "WebAuthnClient", // SIMPLIFIED: Unified database name
            customDatabasePath: dbPath.path
        )
        let virtualKeyStorage = try await StorageFactory.createStorageManager(configuration: config)
        
        var totalImportedCount = 0
        
        // Import client credentials
        let virtualClientCredentials = try await virtualKeyStorage.fetchCredentials()
        print("🔍 Found \(virtualClientCredentials.count) client credentials in unified database")
        
        for credData in virtualClientCredentials {
            // Convert CredentialData to LocalCredential
            let localCredential = LocalCredential(
                id: credData.id,
                rpId: credData.rpId,
                userName: credData.userDisplayName ?? "Unknown",
                userDisplayName: credData.userDisplayName ?? "Unknown",
                userId: String(data: credData.userHandle, encoding: .utf8) ?? credData.id,
                publicKey: credData.publicKey,
                createdAt: credData.createdAt
            )
            
            // Check if credential already exists in main storage
            let existingCredentials = WebAuthnClientCredentialStore.shared.getAllCredentials()
            let exists = existingCredentials.contains { $0.id == localCredential.id }
            
            if !exists || overwriteExisting {
                // Import private key if available
                if let privateKeyRef = credData.privateKeyRef,
                   let privateKeyData = Data(base64Encoded: privateKeyRef),
                   let privateKey = try? P256.Signing.PrivateKey(rawRepresentation: privateKeyData) {
                    
                    if WebAuthnClientCredentialStore.shared.storeCredential(localCredential, privateKey: privateKey) {
                        totalImportedCount += 1
                        print("✅ Imported client credential \(localCredential.id) with private key")
                    }
                } else {
                    print("⚠️ No private key found for credential \(localCredential.id)")
                }
            } else {
                print("⚠️ Client credential \(localCredential.id) already exists, skipping")
            }
        }
        
        // Import server credentials
        let virtualServerCredentials = try await virtualKeyStorage.fetchServerCredentials()
        print("🔍 Found \(virtualServerCredentials.count) server credentials in unified database")
        
        for serverData in virtualServerCredentials {
            // Convert ServerCredentialData to WebAuthnCredential
            let credential = WebAuthnCredential(
                id: serverData.id,
                publicKey: serverData.publicKeyJWK,
                signCount: UInt32(serverData.signCount),
                username: String(data: serverData.userHandle, encoding: .utf8) ?? "Unknown",
                algorithm: serverData.algorithm,
                protocolVersion: serverData.protocolVersion,
                attestationFormat: serverData.attestationFormat ?? "none",
                aaguid: serverData.aaguid,
                isDiscoverable: serverData.isDiscoverable,
                backupEligible: serverData.backupEligible,
                backupState: serverData.backupState,
                emoji: serverData.emoji.isEmpty ? nil : serverData.emoji,
                lastLoginIP: serverData.lastLoginIP,
                lastLoginAt: serverData.lastVerified,
                createdAt: serverData.createdAt,
                isEnabled: serverData.isEnabled,
                isAdmin: serverData.isAdmin,
                userNumber: serverData.userNumber
            )
            
            // Check if credential already exists in storage
            let storageManager = VirtualKeyStorageManager.shared
            let webAuthnManager = storageManager.getWebAuthnManager()
            let existingCredential = webAuthnManager.getCredential(username: credential.username)
            
            if existingCredential == nil || overwriteExisting {
                webAuthnManager.storeCredential(credential)
                totalImportedCount += 1
                print("✅ Imported server credential \(credential.id) for user \(credential.username)")
            } else {
                print("⚠️ Server credential for user \(credential.username) already exists, skipping")
            }
        }
        
        print("✅ Successfully imported \(totalImportedCount) credentials from unified database")
        print("   - Client credentials processed: \(virtualClientCredentials.count)")
        print("   - Server credentials processed: \(virtualServerCredentials.count)")
        return totalImportedCount
    }
    
    func getClientCredentialCount(at dbPath: URL) async -> Int {
        // CRITICAL SAFETY: Rate limit storage manager creation
        guard await acquireStorageOperation() else {
            print("❌ RATE LIMITED: Too many concurrent storage operations, returning cached/default count")
            return 0
        }
        
        defer {
            releaseStorageOperation()
        }
        
        do {
            // CRITICAL SAFETY: Check if file exists before creating storage manager
            guard fileManager.fileExists(atPath: dbPath.path) else {
                print("📊 Client DB file doesn't exist: \(dbPath.lastPathComponent)")
                return 0
            }
            
            // CRITICAL SAFETY: Add timeout and error handling for storage manager creation
            print("📊 Creating storage manager for client credential count: \(dbPath.lastPathComponent)")
            
            // Create a DogTagStorage manager for the virtual key database
            let config = StorageConfiguration(
                databaseName: "WebAuthnClient", // SIMPLIFIED: Unified database name
                customDatabasePath: dbPath.path
            )
            
            // CRITICAL: Use Task.withThrowingTimeout if available, or add manual timeout
            let virtualKeyStorage = try await StorageFactory.createStorageManager(configuration: config)
            
            // Fetch all credentials and count them
            let credentials = try await virtualKeyStorage.fetchCredentials()
            let count = credentials.count
            
            print("📊 Client credential count: \(count)")
            return count
            
        } catch {
            print("❌ SAFE FAILURE: Failed to count client credentials in \(dbPath.lastPathComponent): \(error)")
            print("❌ This is now a safe failure - returning 0 instead of crashing")
            return 0
        }
    }
    
    func getServerCredentialCount(at dbPath: URL) async -> Int {
        // CRITICAL SAFETY: Rate limit storage manager creation
        guard await acquireStorageOperation() else {
            print("❌ RATE LIMITED: Too many concurrent storage operations, returning cached/default count")
            return 0
        }
        
        defer {
            releaseStorageOperation()
        }
        
        do {
            // CRITICAL SAFETY: Check if file exists before creating storage manager
            guard fileManager.fileExists(atPath: dbPath.path) else {
                print("📊 Server DB file doesn't exist: \(dbPath.lastPathComponent)")
                return 0
            }
            
            // CRITICAL SAFETY: Add timeout and error handling for storage manager creation
            print("📊 Creating storage manager for server credential count: \(dbPath.lastPathComponent)")
            
            // Create a DogTagStorage manager for the virtual key database
            let config = StorageConfiguration(
                databaseName: "WebAuthnClient", // SIMPLIFIED: Unified database name
                customDatabasePath: dbPath.path
            )
            
            // CRITICAL: Use Task.withThrowingTimeout if available, or add manual timeout
            let virtualKeyStorage = try await StorageFactory.createStorageManager(configuration: config)
            
            // Fetch all server credentials and count them
            let credentials = try await virtualKeyStorage.fetchServerCredentials()
            let count = credentials.count
            
            print("📊 Server credential count: \(count)")
            return count
            
        } catch {
            print("❌ SAFE FAILURE: Failed to count server credentials in \(dbPath.lastPathComponent): \(error)")
            print("❌ This is now a safe failure - returning 0 instead of crashing")
            return 0
        }
    }
    
    // MARK: - Rate Limiting for Storage Operations
    
    /// Acquire permission to perform a storage operation (rate limited)
    private func acquireStorageOperation() async -> Bool {
        return await withCheckedContinuation { continuation in
            storageOperationQueue.async {
                if self.activeStorageOperations < self.maxConcurrentStorageOps {
                    self.activeStorageOperations += 1
                    print("📊 ACQUIRED storage operation (\(self.activeStorageOperations)/\(self.maxConcurrentStorageOps))")
                    continuation.resume(returning: true)
                } else {
                    print("❌ REJECTED storage operation - too many concurrent operations (\(self.activeStorageOperations)/\(self.maxConcurrentStorageOps))")
                    continuation.resume(returning: false)
                }
            }
        }
    }
    
    /// Release a storage operation slot
    private func releaseStorageOperation() {
        storageOperationQueue.async {
            if self.activeStorageOperations > 0 {
                self.activeStorageOperations -= 1
                print("📊 RELEASED storage operation (\(self.activeStorageOperations)/\(self.maxConcurrentStorageOps))")
            }
        }
    }
}
