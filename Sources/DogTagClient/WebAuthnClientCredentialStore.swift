// Copyright 2025 FIDO3.ai
// Generated on 2025-7-19
import Foundation
import DogTagStorage
import CryptoKit

// MARK: - Credential Store using DogTagStorage
// SIMPLIFIED: This is now the ONLY local credential database
// No more separate "server verification" or "admin" databases - this is a CLIENT app!

final class WebAuthnClientCredentialStore: @unchecked Sendable {
    static let shared = WebAuthnClientCredentialStore()
    
    private var storage: (any StorageManager)?
    private let customStorageConfig: StorageConfiguration?
    
    private init() {
        self.customStorageConfig = nil
        Task {
            try await setupStorage()
        }
    }
    
    // Initializer for virtual storage with custom database path
    init(customDatabasePath: String) {
        self.customStorageConfig = StorageConfiguration(
            databaseName: "WebAuthnClient", // SIMPLIFIED: One unified database name
            customDatabasePath: customDatabasePath
        )
        Task {
            try await setupStorage()
        }
        print("✅ UNIFIED WebAuthn credential store initialized: \(customDatabasePath)")
    }
    
    // Legacy initializer for compatibility - now redirects to custom database path initializer
    init(container: Any) {
        // This is a stub for compatibility - the real configuration should use the custom database path initializer
        self.customStorageConfig = nil
        Task {
            try await setupStorage()
        }
        print("⚠️ WebAuthn credential store initialized with legacy container interface - use custom database path instead")
    }
    
    private func setupStorage() async throws {
        if storage == nil {
            if let customConfig = customStorageConfig {
                storage = try await StorageFactory.createStorageManager(configuration: customConfig)
                print("✅ UNIFIED WebAuthn credential store initialized with DogTagStorage at: \(customConfig.customDatabasePath ?? "default")")
            } else {
                // SIMPLIFIED: Use unified configuration for default storage
                let config = StorageConfiguration(databaseName: "WebAuthnClient")
                storage = try await StorageFactory.createStorageManager(configuration: config)
                print("✅ UNIFIED WebAuthn credential store initialized with default DogTagStorage")
            }
        }
    }
    
    // MARK: - Public Interface
    
    func storeCredential(_ credential: LocalCredential, privateKey: P256.Signing.PrivateKey) -> Bool {
        print("🔧 [WebAuthnClientCredentialStore] Starting credential storage...")
        print("🔧 [WebAuthnClientCredentialStore] Credential ID: \(credential.id)")
        print("🔧 [WebAuthnClientCredentialStore] RP ID: \(credential.rpId)")
        print("🔧 [WebAuthnClientCredentialStore] User: \(credential.userName)")
        
        let task = Task {
            do {
                try await setupStorage()
                guard let storage = storage else {
                    print("❌ [WebAuthnClientCredentialStore] Storage not available")
                    return false
                }
                
                print("✅ [WebAuthnClientCredentialStore] Storage available")
                
                // Encrypt the private key for storage
                print("🔧 [WebAuthnClientCredentialStore] Encrypting private key...")
                let privateKeyData = privateKey.rawRepresentation
                let encryptedPrivateKey = try encryptPrivateKey(privateKeyData, for: credential.id)
                print("✅ [WebAuthnClientCredentialStore] Private key encrypted successfully")
                
                let credentialData = CredentialData(
                    id: credential.id,
                    rpId: credential.rpId,
                    userHandle: credential.userId.data(using: .utf8) ?? Data(),
                    publicKey: credential.publicKey,
                    privateKeyRef: encryptedPrivateKey.base64EncodedString(),
                    createdAt: credential.createdAt,
                    lastUsed: Date(),
                    signCount: 0,
                    isResident: false,
                    userDisplayName: credential.userDisplayName,
                    credentialType: "public-key"
                )
                
                print("🔧 [WebAuthnClientCredentialStore] Created DogTagStorage credential")
                print("🔧 [WebAuthnClientCredentialStore] Saving to storage...")
                
                try await storage.saveCredential(credentialData)
                print("✅ [WebAuthnClientCredentialStore] Saved successfully")
                
                print("✅ Stored credential in DogTagStorage: ID=\(credential.id), User=\(credential.userName)")
                return true
                
            } catch {
                print("❌ [WebAuthnClientCredentialStore] Failed to store credential: \(error)")
                return false
            }
        }
        
        // Use RunLoop to wait for async task completion
        var result = false
        let semaphore = DispatchSemaphore(value: 0)
        
        Task {
            result = await task.value
            semaphore.signal()
        }
        
        semaphore.wait()
        return result
    }
    
    // Store credential with already-encrypted private key data (for virtual key export)
    func storeCredentialWithEncryptedKey(_ credential: LocalCredential, encryptedPrivateKeyData: Data) -> Bool {
        print("🔧 [WebAuthnClientCredentialStore] Storing credential with pre-encrypted key...")
        print("🔧 [WebAuthnClientCredentialStore] Credential ID: \(credential.id)")
        print("🔧 [WebAuthnClientCredentialStore] RP ID: \(credential.rpId)")
        print("🔧 [WebAuthnClientCredentialStore] User: \(credential.userName)")
        
        let task = Task {
            do {
                try await setupStorage()
                guard let storage = storage else {
                    print("❌ [WebAuthnClientCredentialStore] Storage not available")
                    return false
                }
                
                let credentialData = CredentialData(
                    id: credential.id,
                    rpId: credential.rpId,
                    userHandle: credential.userId.data(using: .utf8) ?? Data(),
                    publicKey: credential.publicKey,
                    privateKeyRef: encryptedPrivateKeyData.base64EncodedString(),
                    createdAt: credential.createdAt,
                    lastUsed: Date(),
                    signCount: 0,
                    isResident: false,
                    userDisplayName: credential.userDisplayName,
                    credentialType: "public-key"
                )
                
                try await storage.saveCredential(credentialData)
                
                print("✅ Stored credential with encrypted key in DogTagStorage: ID=\(credential.id), User=\(credential.userName)")
                return true
                
            } catch {
                print("❌ [WebAuthnClientCredentialStore] Failed to store credential: \(error)")
                return false
            }
        }
        
        // Use RunLoop to wait for async task completion
        var result = false
        let semaphore = DispatchSemaphore(value: 0)
        
        Task {
            result = await task.value
            semaphore.signal()
        }
        
        semaphore.wait()
        return result
    }
    
    func getCredentials(for rpId: String) -> [LocalCredential] {
        let task = Task {
            do {
                try await setupStorage()
                guard let storage = storage else {
                    print("❌ Storage not available")
                    return [LocalCredential]()
                }
                
                let credentials = try await storage.fetchCredentials(for: rpId)
                
                let localCredentials = credentials.compactMap { credData -> LocalCredential? in
                    return LocalCredential(
                        id: credData.id,
                        rpId: credData.rpId,
                        userName: credData.userDisplayName ?? "Unknown",
                        userDisplayName: credData.userDisplayName ?? "Unknown",
                        userId: String(data: credData.userHandle, encoding: .utf8) ?? credData.id,
                        publicKey: credData.publicKey,
                        createdAt: credData.createdAt
                    )
                }
                
                print("🔍 Found \(localCredentials.count) credentials for RP: \(rpId)")
                return localCredentials.sorted { $0.createdAt > $1.createdAt }
                
            } catch {
                print("❌ Failed to fetch credentials: \(error)")
                return [LocalCredential]()
            }
        }
        
        // Use RunLoop to wait for async task completion
        var result = [LocalCredential]()
        let semaphore = DispatchSemaphore(value: 0)
        
        Task {
            result = await task.value
            semaphore.signal()
        }
        
        semaphore.wait()
        return result
    }
    
    func getAllCredentials() -> [LocalCredential] {
        let task = Task {
            do {
                try await setupStorage()
                guard let storage = storage else {
                    print("❌ Storage not available")
                    return [LocalCredential]()
                }
                
                let credentials = try await storage.fetchCredentials()
                
                print("🔍 DogTagStorage fetch: Found \(credentials.count) raw credentials")
                
                let localCredentials = credentials.compactMap { credData -> LocalCredential? in
                    print("🔍 Processing credential: ID=\(credData.id), RP=\(credData.rpId), User=\(credData.userDisplayName ?? "Unknown")")
                    return LocalCredential(
                        id: credData.id,
                        rpId: credData.rpId,
                        userName: credData.userDisplayName ?? "Unknown",
                        userDisplayName: credData.userDisplayName ?? "Unknown",
                        userId: String(data: credData.userHandle, encoding: .utf8) ?? credData.id,
                        publicKey: credData.publicKey,
                        createdAt: credData.createdAt
                    )
                }
                
                print("🔍 DogTagStorage converted: \(localCredentials.count) local credentials")
                return localCredentials.sorted { $0.createdAt > $1.createdAt }
                
            } catch {
                print("❌ Failed to fetch all credentials: \(error)")
                return [LocalCredential]()
            }
        }
        
        // Use RunLoop to wait for async task completion
        var result = [LocalCredential]()
        let semaphore = DispatchSemaphore(value: 0)
        
        Task {
            result = await task.value
            semaphore.signal()
        }
        
        semaphore.wait()
        return result
    }
    
    func getPrivateKey(for credentialId: String) -> P256.Signing.PrivateKey? {
        let task = Task {
            do {
                try await setupStorage()
                guard let storage = storage else {
                    print("❌ Storage not available for getPrivateKey")
                    return nil as P256.Signing.PrivateKey?
                }
                
                print("🔍 Getting private key for credential: \(credentialId)")
                
                let credentials = try await storage.fetchCredentials()
                
                guard let credData = credentials.first(where: { $0.id == credentialId }) else {
                    print("❌ No credential found for ID: \(credentialId)")
                    return nil as P256.Signing.PrivateKey?
                }
                
                print("🔍 Found credential, extracting private key...")
                
                guard let privateKeyRef = credData.privateKeyRef,
                      let encryptedData = Data(base64Encoded: privateKeyRef) else {
                    print("❌ No private key data found")
                    return nil as P256.Signing.PrivateKey?
                }
                
                print("🔍 Encrypted private key size: \(encryptedData.count) bytes")
                
                // Decrypt the private key
                let decryptedPrivateKey = try decryptPrivateKey(encryptedData, for: credentialId)
                print("🔍 Decrypted private key size: \(decryptedPrivateKey.count) bytes")
                
                let privateKey = try P256.Signing.PrivateKey(rawRepresentation: decryptedPrivateKey)
                print("✅ Successfully reconstructed private key")
                return privateKey
                
            } catch {
                print("❌ Failed to retrieve private key: \(error)")
                return nil as P256.Signing.PrivateKey?
            }
        }
        
        // Use RunLoop to wait for async task completion
        var result: P256.Signing.PrivateKey? = nil
        let semaphore = DispatchSemaphore(value: 0)
        
        Task {
            result = await task.value
            semaphore.signal()
        }
        
        semaphore.wait()
        return result
    }
    
    func updateSignCount(for credentialId: String, newCount: UInt32) -> Bool {
        let task = Task<Bool, Never> {
            do {
                try await setupStorage()
                guard let storage = storage else {
                    print("❌ Storage not available")
                    return false
                }
                
                let credentials = try await storage.fetchCredentials()
                
                guard let credData = credentials.first(where: { $0.id == credentialId }) else {
                    print("❌ No credential found for ID: \(credentialId)")
                    return false
                }
                
                let oldCount = credData.signCount
                let countChanged = oldCount != newCount
                
                // Update the credential with new sign count and last used time
                let updatedCred = CredentialData(
                    id: credData.id,
                    rpId: credData.rpId,
                    userHandle: credData.userHandle,
                    publicKey: credData.publicKey,
                    privateKeyRef: credData.privateKeyRef,
                    createdAt: credData.createdAt,
                    lastUsed: Date(),
                    signCount: max(Int(newCount), Int(oldCount)), // Convert both to Int before max
                    isResident: credData.isResident,
                    userDisplayName: credData.userDisplayName,
                    credentialType: credData.credentialType
                )
                
                try await storage.saveCredential(updatedCred)
                
                if countChanged && newCount > oldCount {
                    print("✅ Updated sign count from \(oldCount) to \(newCount)")
                }
                print("✅ Updated last used timestamp")
                
                return true
                
            } catch {
                print("❌ Failed to update sign count: \(error)")
                return false
            }
        }
        
        // Use RunLoop to wait for async task completion
        var result = false
        let semaphore = DispatchSemaphore(value: 0)
        
        Task {
            result = await task.value
            semaphore.signal()
        }
        
        semaphore.wait()
        return result
    }
    
    func updateDisplayName(for credentialId: String, newDisplayName: String) -> Bool {
        let task = Task {
            do {
                try await setupStorage()
                guard let storage = storage else {
                    print("❌ Storage not available")
                    return false
                }
                
                let credentials = try await storage.fetchCredentials()
                
                guard let credData = credentials.first(where: { $0.id == credentialId }) else {
                    print("❌ No credential found for ID: \(credentialId)")
                    return false
                }
                
                // Update the credential with new display name
                let updatedCred = CredentialData(
                    id: credData.id,
                    rpId: credData.rpId,
                    userHandle: credData.userHandle,
                    publicKey: credData.publicKey,
                    privateKeyRef: credData.privateKeyRef,
                    createdAt: credData.createdAt,
                    lastUsed: credData.lastUsed,
                    signCount: credData.signCount,
                    isResident: credData.isResident,
                    userDisplayName: newDisplayName,
                    credentialType: credData.credentialType
                )
                
                try await storage.saveCredential(updatedCred)
                
                print("✅ Updated display name for credential \(credentialId): \(newDisplayName)")
                return true
                
            } catch {
                print("❌ Failed to update display name: \(error)")
                return false
            }
        }
        
        // Use RunLoop to wait for async task completion
        var result = false
        let semaphore = DispatchSemaphore(value: 0)
        
        Task {
            result = await task.value
            semaphore.signal()
        }
        
        semaphore.wait()
        return result
    }
    
    func getSignCount(for credentialId: String) -> UInt32? {
        let task = Task {
            do {
                try await setupStorage()
                guard let storage = storage else {
                    print("❌ Storage not available")
                    return nil as UInt32?
                }
                
                let credentials = try await storage.fetchCredentials()
                
                guard let credData = credentials.first(where: { $0.id == credentialId }) else {
                    print("❌ No credential found for ID: \(credentialId)")
                    return nil as UInt32?
                }
                
                return UInt32(credData.signCount)
                
            } catch {
                print("❌ Failed to get sign count: \(error)")
                return nil as UInt32?
            }
        }
        
        // Use RunLoop to wait for async task completion
        var result: UInt32? = nil
        let semaphore = DispatchSemaphore(value: 0)
        
        Task {
            result = await task.value
            semaphore.signal()
        }
        
        semaphore.wait()
        return result
    }
    
    // Get raw credential data for export (includes private keys)
    func getRawCredentialData() -> [CredentialData] {
        let task = Task {
            do {
                try await setupStorage()
                guard let storage = storage else {
                    print("❌ Storage not available")
                    return [CredentialData]()
                }
                
                let credentials = try await storage.fetchCredentials()
                print("🔍 Retrieved \(credentials.count) raw credentials for export")
                return credentials
                
            } catch {
                print("❌ Failed to fetch raw credential data: \(error)")
                return [CredentialData]()
            }
        }
        
        // Use RunLoop to wait for async task completion
        var result = [CredentialData]()
        let semaphore = DispatchSemaphore(value: 0)
        
        Task {
            result = await task.value
            semaphore.signal()
        }
        
        semaphore.wait()
        return result
    }
    
    func deleteCredential(credentialId: String) -> Bool {
        let task = Task {
            do {
                try await setupStorage()
                guard let storage = storage else {
                    print("❌ Storage not available")
                    return false
                }
                
                try await storage.deleteCredential(id: credentialId)
                
                print("✅ Deleted credential: \(credentialId)")
                return true
                
            } catch {
                print("❌ Failed to delete credential: \(error)")
                return false
            }
        }
        
        // Use RunLoop to wait for async task completion
        var result = false
        let semaphore = DispatchSemaphore(value: 0)
        
        Task {
            result = await task.value
            semaphore.signal()
        }
        
        semaphore.wait()
        return result
    }
    
    /// Store a credential from a virtual key to local storage
    /// This method handles transferring private keys from virtual key databases
    func storeCredentialFromVirtualKey(_ credential: LocalCredential) async -> Bool {
        do {
            // When storing from virtual key, we need to get the raw credential data
            // that includes the private key from the current virtual key storage
            if let currentStorage = storage {
                let rawCredentials = try await currentStorage.fetchCredentials()
                if let rawCred = rawCredentials.first(where: { $0.id == credential.id }) {
                    // Store the credential with its private key in local storage
                    let localStore = WebAuthnClientCredentialStore.shared
                    try await localStore.setupStorage()
                    if let localStorage = localStore.storage {
                        try await localStorage.saveCredential(rawCred)
                        return true
                    }
                }
            }
            return false
        } catch {
            print("❌ Failed to transfer credential from virtual key: \\(error)")
            return false
        }
    }
    
    // MARK: - Private Encryption/Decryption
    
    internal func encryptPrivateKey(_ privateKeyData: Data, for credentialId: String) throws -> Data {
        // Use the credential ID as part of the encryption key derivation
        let salt = credentialId.data(using: .utf8) ?? Data()
        let keyData = HKDF<SHA256>.deriveKey(
            inputKeyMaterial: SymmetricKey(data: salt),
            salt: "WebAuthnClient.PrivateKey.Salt".data(using: .utf8)!,
            info: "WebAuthnClient.Encryption".data(using: .utf8)!,
            outputByteCount: 32
        )
        
        let sealedBox = try AES.GCM.seal(privateKeyData, using: keyData)
        return sealedBox.combined!
    }
    
    internal func decryptPrivateKey(_ encryptedData: Data, for credentialId: String) throws -> Data {
        // Use the same key derivation as encryption
        let salt = credentialId.data(using: .utf8) ?? Data()
        let keyData = HKDF<SHA256>.deriveKey(
            inputKeyMaterial: SymmetricKey(data: salt),
            salt: "WebAuthnClient.PrivateKey.Salt".data(using: .utf8)!,
            info: "WebAuthnClient.Encryption".data(using: .utf8)!,
            outputByteCount: 32
        )
        
        let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
        return try AES.GCM.open(sealedBox, using: keyData)
    }
} 
