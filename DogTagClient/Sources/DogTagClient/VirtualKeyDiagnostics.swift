// Copyright 2025 FIDO3.ai
// Generated on 2025-7-19
import Foundation
import CryptoKit
import DogTagStorage

// MARK: - Virtual Key Diagnostics

public class VirtualKeyDiagnostics {
    public static let shared = VirtualKeyDiagnostics()
    private init() {}
    
    /// Comprehensive analysis of a virtual key's contents
    public func analyzeVirtualKey(_ virtualKey: VirtualHardwareKey, password: String? = nil) async throws -> VirtualKeyAnalysis {
        print("🔍 ANALYZING VIRTUAL KEY: \(virtualKey.name)")
        print(String(repeating: "=", count: 60))
        
        // Mount the virtual key (keep it mounted for future use)
        let mountPoint = try await VirtualHardwareKeyManager.shared.mountDiskImage(virtualKey.diskImagePath, password: password)
        
        var analysis = VirtualKeyAnalysis(
            virtualKey: virtualKey,
            mountPoint: mountPoint.path,
            clientCredentials: [],
            serverCredentials: [],
            fileStructure: [],
            databaseSizes: [:]
        )
        
        // Analyze file structure
        analysis.fileStructure = try analyzeFileStructure(at: mountPoint)
        
        // FIXED: Analyze UNIFIED database instead of separate databases
        let unifiedDbPath = mountPoint.appendingPathComponent("WebAuthnClient.db")
        if FileManager.default.fileExists(atPath: unifiedDbPath.path) {
            print("✅ Found UNIFIED database: WebAuthnClient.db")
            analysis.clientCredentials = await getVirtualClientCredentialsFromUnified(at: mountPoint)
            analysis.serverCredentials = await getVirtualServerCredentialsFromUnified(at: mountPoint)
            analysis.databaseSizes["WebAuthnClient.db"] = try getFileSize(unifiedDbPath)
        } else {
            print("⚠️ No unified database found, checking legacy separate databases...")
            // FALLBACK: Check legacy separate databases
            let clientDbPath = mountPoint.appendingPathComponent("VirtualKeyCredentials.db")
            if FileManager.default.fileExists(atPath: clientDbPath.path) {
                print("📁 Found legacy client database: VirtualKeyCredentials.db")
                analysis.clientCredentials = await getVirtualClientCredentials(at: mountPoint)
                analysis.databaseSizes["VirtualKeyCredentials.db"] = try getFileSize(clientDbPath)
            }
            
            let serverDbPath = mountPoint.appendingPathComponent("ServerCredentials.db")
            if FileManager.default.fileExists(atPath: serverDbPath.path) {
                print("📁 Found legacy server database: ServerCredentials.db")
                analysis.serverCredentials = await getVirtualServerCredentials(at: mountPoint)
                analysis.databaseSizes["ServerCredentials.db"] = try getFileSize(serverDbPath)
            }
        }
        
        // Print comprehensive analysis
        printAnalysis(analysis)
        
        return analysis
    }
    
    /// Compare local storage vs virtual key contents
    public func compareLocalVsVirtual(_ virtualKey: VirtualHardwareKey, password: String? = nil) async throws -> StorageComparison {
        print("🔍 COMPARING LOCAL vs VIRTUAL STORAGE")
        print(String(repeating: "=", count: 60))
        
        // Get local credentials
        let localClientCreds = WebAuthnClientCredentialStore.shared.getAllCredentials()
        let localServerCreds = WebAuthnManager.shared.getAllUsers()
        
        // Get virtual key analysis
        let virtualAnalysis = try await analyzeVirtualKey(virtualKey, password: password)
        
        let comparison = StorageComparison(
            localClientCount: localClientCreds.count,
            localServerCount: localServerCreds.count,
            virtualClientCount: virtualAnalysis.clientCredentials.count,
            virtualServerCount: virtualAnalysis.serverCredentials.count,
            duplicateClientIds: findDuplicateClientCredentials(local: localClientCreds, virtual: virtualAnalysis.clientCredentials),
            duplicateServerIds: findDuplicateServerCredentials(local: localServerCreds, virtual: virtualAnalysis.serverCredentials),
            localOnlyClientIds: findLocalOnlyClientCredentials(local: localClientCreds, virtual: virtualAnalysis.clientCredentials),
            localOnlyServerIds: findLocalOnlyServerCredentials(local: localServerCreds, virtual: virtualAnalysis.serverCredentials),
            virtualOnlyClientIds: findVirtualOnlyClientCredentials(local: localClientCreds, virtual: virtualAnalysis.clientCredentials),
            virtualOnlyServerIds: findVirtualOnlyServerCredentials(local: localServerCreds, virtual: virtualAnalysis.serverCredentials)
        )
        
        printComparison(comparison)
        return comparison
    }
    
    /// Load and use credentials from virtual key instead of local storage
    public func useVirtualKeyAsStorage(_ virtualKey: VirtualHardwareKey, password: String? = nil) async throws {
        print("🔄 SWITCHING TO VIRTUAL KEY STORAGE: \(virtualKey.name)")
        print(String(repeating: "=", count: 60))
        
        // Use the new storage manager to switch to virtual storage
        try await VirtualKeyStorageManager.shared.switchToVirtualStorage(virtualKey, password: password)
        
        // Get storage info
        let storageInfo = VirtualKeyStorageManager.shared.getStorageInfo()
        
        print("✅ Successfully switched to virtual key storage!")
        print("")
        print("📊 CURRENT STORAGE INFO:")
        print(storageInfo.description)
        print("")
        print("🔧 Virtual key is now active and ready for use")
        print("💡 All credential operations will now use the virtual key")
        print("⚠️  Remember to switch back to local storage when done")
    }
    
    // MARK: - Private Analysis Methods
    
    private func analyzeFileStructure(at mountPoint: URL) throws -> [VirtualKeyFile] {
        let contents = try FileManager.default.contentsOfDirectory(at: mountPoint, includingPropertiesForKeys: [.fileSizeKey, .creationDateKey])
        
        return contents.map { url in
            let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
            return VirtualKeyFile(
                name: url.lastPathComponent,
                path: url.path,
                size: attributes?[.size] as? Int64 ?? 0,
                createdAt: attributes?[.creationDate] as? Date ?? Date()
            )
        }
    }
    
    private func getVirtualClientCredentials(at mountPoint: URL) async -> [LocalCredential] {
        // Use the EXACT SAME logic as VirtualKeyStorageManager.getVirtualClientCredentials()
        let clientDbPath = mountPoint.appendingPathComponent("VirtualKeyCredentials.db")
        
        do {
            let config = StorageConfiguration(
                databaseName: "VirtualKeyCredentials",
                customDatabasePath: clientDbPath.path
            )
            let virtualKeyStorage = try await StorageFactory.createStorageManager(configuration: config)
            
            // Fetch credentials from virtual key database
            let credentials = try await virtualKeyStorage.fetchCredentials()
            
            return credentials.map { credData in
                LocalCredential(
                    id: credData.id,
                    rpId: credData.rpId,
                    userName: credData.userDisplayName ?? "Unknown",
                    userDisplayName: credData.userDisplayName ?? "Unknown",
                    userId: String(data: credData.userHandle, encoding: .utf8) ?? credData.id,
                    publicKey: credData.publicKey,
                    createdAt: credData.createdAt
                )
            }
        } catch {
            print("❌ Failed to fetch virtual client credentials: \(error)")
            return []
        }
    }
    
    private func getVirtualServerCredentials(at mountPoint: URL) async -> [WebAuthnCredential] {
        // Use the EXACT SAME logic as VirtualKeyStorageManager.getVirtualServerCredentials()
        let serverDbPath = mountPoint.appendingPathComponent("ServerCredentials.db")
        
        do {
            let config = StorageConfiguration(
                databaseName: "ServerCredentials",
                customDatabasePath: serverDbPath.path
            )
            let virtualKeyStorage = try await StorageFactory.createStorageManager(configuration: config)
            
            // Fetch server credentials from virtual key database
            let credentials = try await virtualKeyStorage.fetchServerCredentials()
            
            return credentials.map { serverData in
                WebAuthnCredential(
                    id: serverData.id,
                    publicKey: serverData.publicKeyJWK,
                    signCount: UInt32(serverData.signCount),
                    username: String(data: serverData.userHandle, encoding: .utf8) ?? "Unknown",
                    algorithm: serverData.algorithm,  // Use preserved data
                    protocolVersion: serverData.protocolVersion,  // Use preserved data
                    attestationFormat: serverData.attestationFormat ?? "none",  // Use preserved data with fallback
                    aaguid: serverData.aaguid,  // Use preserved data
                    isDiscoverable: serverData.isDiscoverable,
                    backupEligible: serverData.backupEligible,  // Use preserved data
                    backupState: serverData.backupState,  // Use preserved data
                    emoji: serverData.emoji,  // Use preserved data
                    lastLoginIP: serverData.lastLoginIP,  // Use preserved data
                    lastLoginAt: serverData.lastVerified,
                    createdAt: serverData.createdAt,
                    isEnabled: serverData.isEnabled,  // Use preserved data
                    isAdmin: serverData.isAdmin,  // Use preserved data
                    userNumber: serverData.userNumber  // Use preserved data
                )
            }
        } catch {
            print("❌ Failed to fetch virtual server credentials: \(error)")
            return []
        }
    }
    
    private func getFileSize(_ url: URL) throws -> Int64 {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        return attributes[.size] as? Int64 ?? 0
    }
    
    // MARK: - Duplicate Detection
    
    private func findDuplicateClientCredentials(local: [LocalCredential], virtual: [LocalCredential]) -> [String] {
        let localIds = Set(local.map { $0.id })
        let virtualIds = Set(virtual.map { $0.id })
        return Array(localIds.intersection(virtualIds))
    }
    
    private func findDuplicateServerCredentials(local: [WebAuthnCredential], virtual: [WebAuthnCredential]) -> [String] {
        let localIds = Set(local.map { $0.id })
        let virtualIds = Set(virtual.map { $0.id })
        return Array(localIds.intersection(virtualIds))
    }
    
    private func findLocalOnlyClientCredentials(local: [LocalCredential], virtual: [LocalCredential]) -> [String] {
        let localIds = Set(local.map { $0.id })
        let virtualIds = Set(virtual.map { $0.id })
        return Array(localIds.subtracting(virtualIds))
    }
    
    private func findLocalOnlyServerCredentials(local: [WebAuthnCredential], virtual: [WebAuthnCredential]) -> [String] {
        let localIds = Set(local.map { $0.id })
        let virtualIds = Set(virtual.map { $0.id })
        return Array(localIds.subtracting(virtualIds))
    }
    
    private func findVirtualOnlyClientCredentials(local: [LocalCredential], virtual: [LocalCredential]) -> [String] {
        let localIds = Set(local.map { $0.id })
        let virtualIds = Set(virtual.map { $0.id })
        return Array(virtualIds.subtracting(localIds))
    }
    
    private func findVirtualOnlyServerCredentials(local: [WebAuthnCredential], virtual: [WebAuthnCredential]) -> [String] {
        let localIds = Set(local.map { $0.id })
        let virtualIds = Set(virtual.map { $0.id })
        return Array(virtualIds.subtracting(localIds))
    }
    
    // MARK: - Printing Methods
    
    private func printAnalysis(_ analysis: VirtualKeyAnalysis) {
        print("📊 VIRTUAL KEY ANALYSIS RESULTS")
        print("Virtual Key: \(analysis.virtualKey.name)")
        print("Mount Point: \(analysis.mountPoint)")
        print("Disk Image: \(analysis.virtualKey.diskImagePath.path)")
        print("Is Locked: \(analysis.virtualKey.isLocked)")
        print("")
        
        print("📁 FILE STRUCTURE:")
        for file in analysis.fileStructure {
            let sizeStr = ByteCountFormatter.string(fromByteCount: file.size, countStyle: .file)
            print("   \(file.name) - \(sizeStr)")
        }
        print("")
        
        print("💾 DATABASE SIZES:")
        for (db, size) in analysis.databaseSizes {
            let sizeStr = ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
            print("   \(db): \(sizeStr)")
        }
        print("")
        
        print("🔑 CLIENT CREDENTIALS (\(analysis.clientCredentials.count)):")
        for cred in analysis.clientCredentials {
            print("   ID: \(cred.id)")
            print("   RP: \(cred.rpId)")
            print("   User: \(cred.userName) (\(cred.userDisplayName))")
            print("   Public Key: \(cred.publicKey.count) bytes")
            print("   Created: \(cred.createdAt)")
            print("   ---")
        }
        print("")
        
        print("🌐 SERVER CREDENTIALS (\(analysis.serverCredentials.count)):")
        for cred in analysis.serverCredentials {
            print("   ID: \(cred.id)")
            print("   Username: \(cred.username)")
            print("   Algorithm: \(cred.algorithm)")
            print("   Sign Count: \(cred.signCount)")
            print("   Admin: \(cred.isAdmin)")
            print("   Enabled: \(cred.isEnabled)")
            print("   Emoji: \(cred.emoji ?? "🔑")")
            print("   ---")
        }
    }
    
    private func printComparison(_ comparison: StorageComparison) {
        print("📊 STORAGE COMPARISON RESULTS")
        print("")
        print("📈 COUNTS:")
        print("   Local Client Credentials: \(comparison.localClientCount)")
        print("   Local Server Credentials: \(comparison.localServerCount)")
        print("   Virtual Client Credentials: \(comparison.virtualClientCount)")
        print("   Virtual Server Credentials: \(comparison.virtualServerCount)")
        print("")
        
        print("🔄 DUPLICATES (exist in both):")
        print("   Client Credentials: \(comparison.duplicateClientIds.count)")
        for id in comparison.duplicateClientIds {
            print("     - \(id)")
        }
        print("   Server Credentials: \(comparison.duplicateServerIds.count)")
        for id in comparison.duplicateServerIds {
            print("     - \(id)")
        }
        print("")
        
        print("🏠 LOCAL ONLY:")
        print("   Client Credentials: \(comparison.localOnlyClientIds.count)")
        for id in comparison.localOnlyClientIds {
            print("     - \(id)")
        }
        print("   Server Credentials: \(comparison.localOnlyServerIds.count)")
        for id in comparison.localOnlyServerIds {
            print("     - \(id)")
        }
        print("")
        
        print("💾 VIRTUAL ONLY:")
        print("   Client Credentials: \(comparison.virtualOnlyClientIds.count)")
        for id in comparison.virtualOnlyClientIds {
            print("     - \(id)")
        }
        print("   Server Credentials: \(comparison.virtualOnlyServerIds.count)")
        for id in comparison.virtualOnlyServerIds {
            print("     - \(id)")
        }
    }
    
    // MARK: - Unified Database Access Methods
    
    /// Get client credentials from unified database
    private func getVirtualClientCredentialsFromUnified(at mountPoint: URL) async -> [LocalCredential] {
        do {
            let unifiedDbPath = mountPoint.appendingPathComponent("WebAuthnClient.db")
            let config = StorageConfiguration(
                databaseName: "WebAuthnClient",
                customDatabasePath: unifiedDbPath.path
            )
            let storage = try await StorageFactory.createStorageManager(configuration: config)
            
            let credentialData = try await storage.fetchCredentials()
            return credentialData.compactMap { credData in
                LocalCredential(
                    id: credData.id,
                    rpId: credData.rpId,
                    userName: credData.userDisplayName ?? "Unknown",
                    userDisplayName: credData.userDisplayName ?? "Unknown",
                    userId: String(data: credData.userHandle, encoding: .utf8) ?? credData.id,
                    publicKey: credData.publicKey, // ✅ PUBLIC KEY preserved
                    createdAt: credData.createdAt
                )
            }
        } catch {
            print("❌ Failed to get client credentials from unified database: \(error)")
            return []
        }
    }
    
    /// Get server credentials from unified database
    private func getVirtualServerCredentialsFromUnified(at mountPoint: URL) async -> [WebAuthnCredential] {
        do {
            let unifiedDbPath = mountPoint.appendingPathComponent("WebAuthnClient.db")
            let config = StorageConfiguration(
                databaseName: "WebAuthnClient",
                customDatabasePath: unifiedDbPath.path
            )
            let storage = try await StorageFactory.createStorageManager(configuration: config)
            
            let serverCredentialData = try await storage.fetchServerCredentials()
            return serverCredentialData.compactMap { serverData in
                WebAuthnCredential(
                    id: serverData.id,
                    publicKey: serverData.publicKeyJWK,
                    signCount: UInt32(serverData.signCount),
                    username: String(data: serverData.userHandle, encoding: .utf8) ?? "Unknown",
                    algorithm: serverData.algorithm ?? -7,
                    protocolVersion: serverData.protocolVersion ?? "fido2CBOR",
                    attestationFormat: serverData.attestationFormat ?? "none",
                    aaguid: serverData.aaguid,
                    isDiscoverable: serverData.isDiscoverable,
                    backupEligible: serverData.backupEligible,
                    backupState: serverData.backupState,
                    emoji: serverData.emoji.isEmpty == false ? serverData.emoji : nil,
                    lastLoginIP: serverData.lastLoginIP,
                    lastLoginAt: serverData.lastVerified,
                    createdAt: serverData.createdAt,
                    isEnabled: serverData.isEnabled,
                    isAdmin: serverData.isAdmin,
                    userNumber: serverData.userNumber
                )
            }
        } catch {
            print("❌ Failed to get server credentials from unified database: \(error)")
            return []
        }
    }
    
    // MARK: - Legacy Database Access Methods (Fallback)
}

// MARK: - Data Models

public struct VirtualKeyAnalysis {
    let virtualKey: VirtualHardwareKey
    let mountPoint: String
    var clientCredentials: [LocalCredential]
    var serverCredentials: [WebAuthnCredential]
    var fileStructure: [VirtualKeyFile]
    var databaseSizes: [String: Int64]
}

public struct VirtualKeyFile {
    let name: String
    let path: String
    let size: Int64
    let createdAt: Date
}

// Custom types removed - now using LocalCredential and WebAuthnCredential directly

public struct StorageComparison {
    let localClientCount: Int
    let localServerCount: Int
    let virtualClientCount: Int
    let virtualServerCount: Int
    let duplicateClientIds: [String]
    let duplicateServerIds: [String]
    let localOnlyClientIds: [String]
    let localOnlyServerIds: [String]
    let virtualOnlyClientIds: [String]
    let virtualOnlyServerIds: [String]
}


