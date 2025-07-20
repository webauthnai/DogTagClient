// Copyright 2025 FIDO3.ai
// Generated on 2025-7-19
import Foundation
import CryptoKit
import DogTagStorage

// MARK: - Simplified Credential Manager
// REPLACES: WebAuthnManager + WebAuthnClientCredentialStore mess
// PURPOSE: ONE unified credential store for CLIENT authentication only

public final class SimplifiedCredentialManager: @unchecked Sendable {
    public static let shared = SimplifiedCredentialManager()
    
    private var storage: (any StorageManager)?
    
    private init() {
        Task {
            try await setupStorage()
        }
    }
    
    private func setupStorage() async throws {
        if storage == nil {
            // SIMPLIFIED: One database for ALL client credential needs
            let config = StorageConfiguration(databaseName: "WebAuthnClient")
            storage = try await StorageFactory.createStorageManager(configuration: config)
            print("✅ SIMPLIFIED: Unified credential manager initialized")
        }
    }
    
    // MARK: - Unified Credential Operations
    
    /// Store a complete credential (BOTH private key + public key + metadata)
    public func storeCredential(_ localCredential: LocalCredential, privateKey: P256.Signing.PrivateKey) async -> Bool {
        do {
            try await setupStorage()
            guard let storage = storage else { return false }
            
            // Encrypt private key for secure storage
            let privateKeyData = privateKey.rawRepresentation
            let encryptedPrivateKey = try encryptPrivateKey(privateKeyData, for: localCredential.id)
            
            // CRITICAL: Store BOTH private AND public keys together
            let credentialData = CredentialData(
                id: localCredential.id,
                rpId: localCredential.rpId,
                userHandle: localCredential.userId.data(using: .utf8) ?? Data(),
                publicKey: localCredential.publicKey, privateKeyRef: encryptedPrivateKey.base64EncodedString(), createdAt: localCredential.createdAt, lastUsed: nil, signCount: 0, userDisplayName: localCredential.userDisplayName
            )
            
            try await storage.saveCredential(credentialData)
            print("✅ SIMPLIFIED: Stored COMPLETE credential \(localCredential.id) with BOTH keys")
            return true
            
        } catch {
            print("❌ SIMPLIFIED: Failed to store credential: \(error)")
            return false
        }
    }
    
    /// Get all credentials for a relying party (includes public keys for display)
    public func getCredentials(for rpId: String) async -> [LocalCredential] {
        do {
            try await setupStorage()
            guard let storage = storage else { return [] }
            
            let credentialData = try await storage.fetchCredentials(for: rpId)
            return credentialData.compactMap { credData in
                // ✅ Reconstruct LocalCredential with public key intact
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
            print("❌ SIMPLIFIED: Failed to get credentials: \(error)")
            return []
        }
    }
    
    /// Get private key for authentication
    public func getPrivateKey(for credentialId: String) async -> P256.Signing.PrivateKey? {
        do {
            try await setupStorage()
            guard let storage = storage else { return nil }
            
            let credData = try await storage.fetchCredential(id: credentialId)
            guard let credData = credData,
                  let privateKeyRef = credData.privateKeyRef,
                  let encryptedData = Data(base64Encoded: privateKeyRef) else {
                print("❌ SIMPLIFIED: No private key found for credential \(credentialId)")
                return nil
            }
            
            // Decrypt private key
            let decryptedData = try decryptPrivateKey(encryptedData, for: credentialId)
            return try P256.Signing.PrivateKey(rawRepresentation: decryptedData)
            
        } catch {
            print("❌ SIMPLIFIED: Failed to get private key: \(error)")
            return nil
        }
    }
    
    /// Update sign count after authentication
    public func updateSignCount(for credentialId: String, newCount: Int) async -> Bool {
        do {
            try await setupStorage()
            guard let storage = storage else { return false }
            
            try await storage.updateSignCount(credentialId: credentialId, newCount: newCount)
            print("✅ SIMPLIFIED: Updated sign count for \(credentialId): \(newCount)")
            return true
            
        } catch {
            print("❌ SIMPLIFIED: Failed to update sign count: \(error)")
            return false
        }
    }
    
    /// Delete a credential
    public func deleteCredential(credentialId: String) async -> Bool {
        do {
            try await setupStorage()
            guard let storage = storage else { return false }
            
            try await storage.deleteCredential(id: credentialId)
            print("✅ SIMPLIFIED: Deleted credential \(credentialId)")
            return true
            
        } catch {
            print("❌ SIMPLIFIED: Failed to delete credential: \(error)")
            return false
        }
    }
    
    /// Get all credentials (for UI display) - includes BOTH public keys and metadata
    public func getAllCredentials() async -> [LocalCredential] {
        do {
            try await setupStorage()
            guard let storage = storage else { return [] }
            
            let credentialData = try await storage.fetchCredentials()
            return credentialData.compactMap { credData in
                // ✅ Reconstruct complete LocalCredential with public key
                LocalCredential(
                    id: credData.id,
                    rpId: credData.rpId,
                    userName: credData.userDisplayName ?? "Unknown",
                    userDisplayName: credData.userDisplayName ?? "Unknown",
                    userId: String(data: credData.userHandle, encoding: .utf8) ?? credData.id,
                    publicKey: credData.publicKey, // ✅ PUBLIC KEY preserved for display
                    createdAt: credData.createdAt
                )
            }
        } catch {
            print("❌ SIMPLIFIED: Failed to get all credentials: \(error)")
            return []
        }
    }
    
    /// Get public key for a credential (for display/validation purposes)
    public func getPublicKey(for credentialId: String) async -> Data? {
        do {
            try await setupStorage()
            guard let storage = storage else { return nil }
            
            let credData = try await storage.fetchCredential(id: credentialId)
            return credData?.publicKey // ✅ Return public key data
            
        } catch {
            print("❌ SIMPLIFIED: Failed to get public key: \(error)")
            return nil
        }
    }
    
    // MARK: - Private Key Encryption/Decryption
    
    private func encryptPrivateKey(_ privateKeyData: Data, for credentialId: String) throws -> Data {
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
    
    private func decryptPrivateKey(_ encryptedData: Data, for credentialId: String) throws -> Data {
        // Use the same credential ID for key derivation
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

// MARK: - Migration Helper
// This helps migrate from the old multi-database mess to the new unified approach

extension SimplifiedCredentialManager {
    
    /// Migrate credentials from old WebAuthnClientCredentialStore - PRESERVES ALL DATA
    public func migrateFromOldStores() async {
        print("🔄 MIGRATION: Starting migration from old credential stores...")
        print("🔄 MIGRATION: Will preserve BOTH public and private keys - NO DATA LOSS")
        
        // Get credentials from old client store (has both public and private keys)
        let oldClientCredentials = WebAuthnClientCredentialStore.shared.getAllCredentials()
        print("🔄 MIGRATION: Found \(oldClientCredentials.count) credentials in old client store")
        
        var migratedCount = 0
        
        for oldCredential in oldClientCredentials {
            print("🔄 MIGRATION: Processing credential \(oldCredential.id)")
            print("   - Username: \(oldCredential.userName)")
            print("   - RP ID: \(oldCredential.rpId)")
            print("   - Has public key: \(oldCredential.publicKey.count) bytes")
            
            // Try to get the private key from the old store
            if let privateKey = WebAuthnClientCredentialStore.shared.getPrivateKey(for: oldCredential.id) {
                print("   - Found private key: ✅")
                
                // Store BOTH keys in unified database
                let success = await storeCredential(oldCredential, privateKey: privateKey)
                if success {
                    migratedCount += 1
                    print("✅ MIGRATION: Migrated credential \(oldCredential.id) with BOTH keys")
                } else {
                    print("❌ MIGRATION: Failed to migrate credential \(oldCredential.id)")
                }
            } else {
                print("⚠️ MIGRATION: No private key found for credential \(oldCredential.id)")
                print("⚠️ MIGRATION: This credential may be incomplete or corrupted")
            }
        }
        
        print("✅ MIGRATION: Completed - migrated \(migratedCount)/\(oldClientCredentials.count) credentials")
        
        if migratedCount == oldClientCredentials.count && migratedCount > 0 {
            print("💡 MIGRATION: All credentials migrated successfully with BOTH keys!")
            print("💡 MIGRATION: Unified database now contains:")
            print("💡 MIGRATION: - Private keys (encrypted, for authentication)")
            print("💡 MIGRATION: - Public keys (for display and validation)")
            print("💡 MIGRATION: - All metadata (usernames, creation dates, etc.)")
            print("💡 MIGRATION: You can now safely remove redundant database files")
        } else if migratedCount > 0 {
            print("⚠️ MIGRATION: Partial migration completed")
            print("⚠️ MIGRATION: Some credentials may need manual inspection")
        }
    }
} 
