// Copyright 2025 FIDO3.ai
// Generated on 2025-7-19
import Foundation
import LocalAuthentication
import Security
import CryptoKit
import Cocoa
import SwiftUI

public class LocalAuthService: @unchecked Sendable {
    public static let shared = LocalAuthService()
    
    private let keychainService = "ai.fido3.webauthn.WebMan"
    private let credentialPrefix = "credential_"
    
    // Reference to WebAuthnManager for credential lookup
    private var webAuthnManager: WebAuthnManager?
    
    // Migration no longer needed - using SwiftData storage
    
    private init() {
        // Migration permanently complete - using SwiftData storage
        print("✅ Using SwiftData storage - migration no longer needed")
    }
    
    // Set the WebAuthnManager reference for credential lookup
    func setWebAuthnManager(_ manager: WebAuthnManager) {
        self.webAuthnManager = manager
        print("🔧 LocalAuthService: WebAuthnManager reference set")
    }
    
    // MARK: - Public Interface
    
    func isAvailable() -> Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error)
    }
    
    // Diagnostic method to check credential availability
    public func diagnoseCredentialAvailability(for rpId: String) {
        print("🔍 === CREDENTIAL AVAILABILITY DIAGNOSTIC ===")
        
        // Check SwiftData store
        let swiftDataCredentials = WebAuthnClientCredentialStore.shared.getCredentials(for: rpId)
        print("🔍 SwiftData credentials for \(rpId): \(swiftDataCredentials.count)")
        
        let allSwiftDataCredentials = WebAuthnClientCredentialStore.shared.getAllCredentials()
        print("🔍 Total SwiftData credentials: \(allSwiftDataCredentials.count)")
        for cred in allSwiftDataCredentials {
            print("🔍   - SwiftData: ID=\(String(cred.id.prefix(10)))..., RP=\(cred.rpId), User=\(cred.userName)")
        }
        
        // Check WebAuthnManager credentials if available
        if let webAuthnManager = webAuthnManager {
            let webAuthnCredentials = webAuthnManager.getAllUsers()
            print("🔍 WebAuthnManager credentials: \(webAuthnCredentials.count)")
            for cred in webAuthnCredentials {
                print("🔍   - WebAuthnManager: ID=\(String(cred.id.prefix(10)))..., User=\(cred.username)")
            }
        } else {
            print("🔍 WebAuthnManager not available")
        }
        
        print("🔍 === END DIAGNOSTIC ===")
    }
    
    // NEW: Comprehensive credential ID mapping diagnostic
    public func diagnoseCredentialIDMappings(for rpId: String) {
        print("🔍 === CREDENTIAL ID MAPPING DIAGNOSTIC ===")
        print("🔍 Analyzing credential IDs for RP: \(rpId)")
        
        // Get credentials from all storage locations
        let storageManager = VirtualKeyStorageManager.shared
        let credentialStore = storageManager.getClientCredentialStore()
        let allCredentials = credentialStore.getCredentials(for: rpId)
        
        print("🔍 Found \(allCredentials.count) credentials:")
        for (index, cred) in allCredentials.enumerated() {
            print("🔍")
            print("🔍 === CREDENTIAL \(index + 1) ===")
            print("🔍 Username: \(cred.userName)")
            print("🔍 Display Name: \(cred.userDisplayName)")
            print("🔍 User ID: \(cred.userId)")
            print("🔍 Credential ID (full): \(cred.id)")
            print("🔍 Credential ID (first 20 chars): \(String(cred.id.prefix(20)))...")
            print("🔍 RP ID: \(cred.rpId)")
            print("🔍 Created: \(cred.createdAt)")
            
            // Show different base64 formats for matching
            let standardBase64 = convertToStandardBase64(cred.id)
            let urlSafeBase64 = convertToURLSafeBase64(cred.id)
            
            print("🔍 Standard Base64 format: \(standardBase64)")
            print("🔍 URL-safe Base64 format: \(urlSafeBase64)")
            
            // Test if this matches common server formats
            let testIds = [
                "FgW4kNRgUnbvKs0lm3nr4HZSIvs65Z24dffCQg/lLYg=",
                "qGwfKjf5bsAm/qBoTDTsWH7h3SWFkiwy9mnwMueltf8=", 
                "o8IXkEoMiz+RAKjUK4odix1RxRLCxIDokzmX5vYypVs="
            ]
            
            for testId in testIds {
                if isCredentialIDMatch(storedId: cred.id, requestedId: testId) {
                    print("🎯 MATCHES server credential ID: \(testId)")
                }
            }
        }
        
        print("🔍 === CREDENTIAL ID MAPPING COMPLETE ===")
    }
    
    // Helper function to test credential ID matching
    private func isCredentialIDMatch(storedId: String, requestedId: String) -> Bool {
        // Direct match
        if storedId == requestedId {
            return true
        }
        
        // Try base64 standard to URL-safe conversion
        let urlSafeId = requestedId
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        if storedId == urlSafeId {
            return true
        }
        
        // Try URL-safe to standard conversion
        let standardId = requestedId
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        if storedId == standardId {
            return true
        }
        
        // Try with padding
        let paddedStandardId: String
        let remainder = standardId.count % 4
        if remainder > 0 {
            paddedStandardId = standardId + String(repeating: "=", count: 4 - remainder)
        } else {
            paddedStandardId = standardId
        }
        if storedId == paddedStandardId {
            return true
        }
        
        return false
    }
    
    // Helper to convert any base64 format to standard format
    private func convertToStandardBase64(_ base64String: String) -> String {
        var result = base64String
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        
        // Add padding if needed
        let remainder = result.count % 4
        if remainder > 0 {
            result += String(repeating: "=", count: 4 - remainder)
        }
        
        return result
    }
    
    // Helper to convert any base64 format to URL-safe format
    private func convertToURLSafeBase64(_ base64String: String) -> String {
        return base64String
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
    
    func createCredential(
        rpId: String,
        userName: String,
        userDisplayName: String,
        userId: String,
        challenge: Data,
        completion: @escaping (Result<LocalCredential, LocalAuthError>) -> Void
    ) {
        print("🔐 Creating local credential for user: \(userName)")
        
        // Check if Touch ID is available
        guard isAvailable() else {
            completion(.failure(.biometricNotAvailable))
            return
        }
        
        // Show the Touch ID sheet directly without extra background window
        if let mainWindow = NSApp.mainWindow, let contentView = mainWindow.contentView {
            var hostingView: NSHostingView<TouchIDSignInSheet>?
            
            let touchIDSheet = TouchIDSignInSheet(
                siteName: rpId,
                credentialName: userDisplayName,
                onContinue: {
                    self.performCredentialCreation(
                        rpId: rpId,
                        userName: userName,
                        userDisplayName: userDisplayName,
                        userId: userId,
                        challenge: challenge,
                        completion: completion
                    )
                    print("✅ Touch ID authentication succeeded")
                },
                onCancel: {
                    print("❌ Touch ID authentication cancelled")
                },
                onDismiss: {
                    print("🔐 Dismissing Touch ID sheet")
                    hostingView?.removeFromSuperview()
                    hostingView = nil
                }
            )
            
            // Create a hosting view that fills the content area
            hostingView = NSHostingView(rootView: touchIDSheet)
            hostingView!.frame = contentView.bounds
            hostingView!.autoresizingMask = [.width, .height]
            
            // Add directly to the main window's content view
            contentView.addSubview(hostingView!)
        }
    }
    
    // MARK: - Authentication
    
    /// Authenticate a user with their stored credential
    public func authenticateUser(
        credential: LocalCredential,
        challenge: Data,
        completion: @escaping (Result<LocalAuthAssertion, LocalAuthError>) -> Void
    ) {
        print("🔐 Starting authentication for user: \(credential.userName)")
        print("🔍 Credential ID: \(credential.id)")
        print("🔍 RP ID: \(credential.rpId)")
        
        // Apply optimal signature counter mode for regular local keys
        let storageManager = VirtualKeyStorageManager.shared
        storageManager.optimizeCounterMode()
        
        // Check for Touch ID availability
        let context = LAContext()
        var error: NSError?
        
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            print("❌ Touch ID not available: \(error?.localizedDescription ?? "Unknown error")")
            completion(.failure(.touchIDNotAvailable))
            return
        }
        
        // Prompt for Touch ID authentication
        let reason = "Authenticate to sign in to \(credential.rpId)"
        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, authError in
            DispatchQueue.main.async {
                if success {
                    print("✅ Touch ID authentication successful")
                    self.performAuthentication(credential: credential, challenge: challenge, completion: completion)
                } else {
                    let errorMessage = authError?.localizedDescription ?? "Unknown error"
                    print("❌ Touch ID authentication failed: \(errorMessage)")
                    completion(.failure(.authenticationFailed(errorMessage)))
                }
            }
        }
    }
    
    /// FIXED: Respect credential ID from server and prevent unnecessary syncing
    func authenticateCredential(
        rpId: String,
        challenge: Data,
        credentialId: String? = nil,
        username: String? = nil,
        completion: @escaping (Result<LocalAuthAssertion, LocalAuthError>) -> Void
    ) {
        print("🔍 Authenticating credential for RP: \(rpId)")
        print("🔍 Requested credential ID: \(credentialId ?? "any")")
        print("🔍 Requested username: \(username ?? "any")")
        
        // Check if Touch ID is available
        guard isAvailable() else {
            completion(.failure(.biometricNotAvailable))
            return
        }
        
        // Get credentials from the current storage manager without unnecessary syncing
        let storageManager = VirtualKeyStorageManager.shared
        let credentialStore = storageManager.getClientCredentialStore()
        let credentials = credentialStore.getCredentials(for: rpId)
        print("🔍 Found \(credentials.count) credentials for RP: \(rpId)")
        
        guard !credentials.isEmpty else {
            print("❌ No credentials found for RP: \(rpId)")
            completion(.failure(.noCredentialsFound))
            return
        }
        
        // CRITICAL FIX: Respect the server's credential ID request
        let targetCredential: LocalCredential
        
        if let requestedCredentialId = credentialId, !requestedCredentialId.isEmpty {
            // Server specified a credential ID - we MUST use that exact credential
            print("🎯 Server requested specific credential ID: \(requestedCredentialId)")
            
            // Try different credential ID formats for compatibility
            let matchingCredential = credentials.first { credential in
                // Direct match
                if credential.id == requestedCredentialId {
                    print("✅ Direct credential ID match")
                    return true
                }
                
                // Try base64 standard to URL-safe conversion
                let urlSafeId = requestedCredentialId
                    .replacingOccurrences(of: "+", with: "-")
                    .replacingOccurrences(of: "/", with: "_")
                    .replacingOccurrences(of: "=", with: "")
                if credential.id == urlSafeId {
                    print("✅ URL-safe base64 credential ID match")
                    return true
                }
                
                // Try URL-safe to standard conversion
                let standardId = requestedCredentialId
                    .replacingOccurrences(of: "-", with: "+")
                    .replacingOccurrences(of: "_", with: "/")
                if credential.id == standardId {
                    print("✅ Standard base64 credential ID match")
                    return true
                }
                
                // Try with padding added to standard format
                let paddedStandardId: String
                let remainder = standardId.count % 4
                if remainder > 0 {
                    paddedStandardId = standardId + String(repeating: "=", count: 4 - remainder)
                } else {
                    paddedStandardId = standardId
                }
                if credential.id == paddedStandardId {
                    print("✅ Padded standard base64 credential ID match")
                    return true
                }
                
                print("❌ No match for credential \(credential.id) vs requested \(requestedCredentialId)")
                return false
            }
            
            guard let foundCredential = matchingCredential else {
                print("❌ Server requested credential ID '\(requestedCredentialId)' not found")
                print("❌ Available credentials:")
                for cred in credentials {
                    print("❌   - \(cred.id) (\(cred.userName))")
                }
                completion(.failure(.noCredentialsFound))
                return
            }
            
            targetCredential = foundCredential
            print("✅ Found requested credential: \(targetCredential.userName)")
            
        } else if let requestedUsername = username, !requestedUsername.isEmpty {
            // Server specified a username
            guard let userCredential = credentials.first(where: { $0.userName == requestedUsername }) else {
                print("❌ No credential found for username: \(requestedUsername)")
                completion(.failure(.noCredentialsFound))
                return
            }
            targetCredential = userCredential
            print("🎯 Using credential for username '\(requestedUsername)': \(targetCredential.id)")
            
        } else {
            // No specific credential requested - use first available (legacy behavior)
            targetCredential = credentials[0]
            print("🎯 No specific credential requested, using first available: \(targetCredential.userName)")
            
            if credentials.count > 1 {
                print("💡 Available credentials for \(rpId):")
                for (index, cred) in credentials.enumerated() {
                    let indicator = (cred.id == targetCredential.id) ? "👈 SELECTED" : ""
                    print("💡   \(index + 1). \(cred.userName) (ID: \(cred.id)) \(indicator)")
                }
            }
        }
        
        // Use the authenticateUser method which includes counter optimization
        self.authenticateUser(credential: targetCredential, challenge: challenge, completion: completion)
    }
    
    func getCredentials(for rpId: String) -> [LocalCredential] {
        return WebAuthnClientCredentialStore.shared.getCredentials(for: rpId)
    }
    
    func deleteCredential(credentialId: String) -> Bool {
        return WebAuthnClientCredentialStore.shared.deleteCredential(credentialId: credentialId)
    }
    
    // MARK: - Private Implementation
    
    private func performCredentialCreation(
        rpId: String,
        userName: String,
        userDisplayName: String,
        userId: String,
        challenge: Data,
        completion: @escaping (Result<LocalCredential, LocalAuthError>) -> Void
    ) {
        // Generate a new credential ID
        // Generate credential ID (32 random bytes, URL-safe base64 encoded)
        let credentialIdBytes = Data((0..<32).map { _ in UInt8.random(in: 0...255) })
        let credentialId = credentialIdBytes.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        
        // Generate a new key pair
        let privateKey = P256.Signing.PrivateKey()
        let publicKey = privateKey.publicKey
        
        // Create credential object
        let credential = LocalCredential(
            id: credentialId,
            rpId: rpId,
            userName: userName,
            userDisplayName: userDisplayName,
            userId: userId,
            publicKey: publicKey.x963Representation,  // ✅ Use x963 format (65 bytes with 0x04 prefix)
            createdAt: Date()
        )
        
        // Store the credential using the current storage manager
        let storageManager = VirtualKeyStorageManager.shared
        let credentialStore = storageManager.getClientCredentialStore()
        guard credentialStore.storeCredential(credential, privateKey: privateKey) else {
            completion(.failure(.keychainError("Failed to store credential")))
            return
        }
        
        print("✅ Credential created and stored: ID=\(credentialId), User=\(userName) using \(storageManager.currentStorageMode.description)")
        completion(.success(credential))
    }
    
    private func performAuthentication(
        credential: LocalCredential,
        challenge: Data,
        completion: @escaping (Result<LocalAuthAssertion, LocalAuthError>) -> Void
    ) {
        // Get the private key from the current storage manager
        let storageManager = VirtualKeyStorageManager.shared
        let credentialStore = storageManager.getClientCredentialStore()
        guard let privateKey = credentialStore.getPrivateKey(for: credential.id) else {
            completion(.failure(.keychainError("Private key not found")))
            return
        }
        
        // Get current sign count using synchronized counter management
        // This handles the case where credentials exist in both local and virtual storage
        let currentSignCount = storageManager.getMaxSignCount(for: credential.id)
        let newSignCount = currentSignCount + 1
        
        print("🔍 Sign count: current=\(currentSignCount), new=\(newSignCount) using \(storageManager.currentStorageMode.description)")
        print("🔍 Using synchronized counter to handle multi-storage credentials")
        
        // Create client data JSON
        let clientDataJSON = createClientDataJSON(type: "webauthn.get", challenge: challenge, origin: "https://\(credential.rpId)")
        
        // Create authenticator data with proper counter handling
        // When in server-managed mode (like Apple TouchID), always send counter = 0
        // to force server-side counter management
        let finalSignCount: UInt32
        if storageManager.currentStorageMode.isVirtual {
            // For virtual storage, check if we should use platform authenticator behavior
            let webAuthnManager = storageManager.getWebAuthnManager()
            if webAuthnManager.signatureCounterMode == .serverManaged {
                print("🍎 Using Apple TouchID pattern: sending counter = 0 for server-side management")
                finalSignCount = 0  // Apple TouchID behavior: always return 0
            } else {
                finalSignCount = newSignCount
            }
        } else {
            // For local storage, also check counter mode
            if WebAuthnManager.shared.signatureCounterMode == .serverManaged {
                print("🍎 Using Apple TouchID pattern: sending counter = 0 for server-side management")
                finalSignCount = 0  // Apple TouchID behavior: always return 0
            } else {
                finalSignCount = newSignCount
            }
        }
        
        let authenticatorData = createEnhancedAuthenticatorData(
            rpId: credential.rpId,
            signCount: finalSignCount
        )
        
        // Create data to sign (authenticator data + client data JSON hash)
        let clientDataHash = SHA256.hash(data: clientDataJSON)
        var dataToSign = authenticatorData
        dataToSign.append(contentsOf: clientDataHash)
        
        print("🔍 AUTHENTICATION Signature Debug:")
        print("   - Authenticator data: \(authenticatorData.count) bytes")
        print("   - Client data hash: \(Data(clientDataHash).count) bytes") 
        print("   - Total data to sign: \(dataToSign.count) bytes")
        print("   - Auth data hex: \(authenticatorData.prefix(16).map { String(format: "%02x", $0) }.joined())...")
        print("   - Client data: \(String(data: clientDataJSON, encoding: .utf8) ?? "invalid")")
        print("   - Data to sign hex: \(dataToSign.prefix(16).map { String(format: "%02x", $0) }.joined())...")
        print("   - Client data hash hex: \(Data(clientDataHash).prefix(16).map { String(format: "%02x", $0) }.joined())...")
        print("   - Final sign count sent to server: \(finalSignCount)")
        print("   - RP ID hash: \(Data(SHA256.hash(data: credential.rpId.data(using: .utf8)!)).prefix(8).map { String(format: "%02x", $0) }.joined())...")
        
        // Sign the data
        do {
            let signature = try privateKey.signature(for: dataToSign)
            
            // CRITICAL FIX: Use DER-encoded signature format for WebAuthn compliance
            // WebAuthn servers expect ASN.1 DER-encoded signatures, not raw (r,s) bytes
            let signatureData = signature.derRepresentation
            
            print("🔍 AUTHENTICATION Signature created:")
            print("   - Raw signature length: \(signature.rawRepresentation.count) bytes (r+s format)")
            print("   - DER signature length: \(signatureData.count) bytes (ASN.1 format)")
            print("   - Using DER format for WebAuthn compliance")
            print("   - DER signature hex: \(signatureData.prefix(16).map { String(format: "%02x", $0) }.joined())...")
            print("   - Raw signature hex: \(signature.rawRepresentation.prefix(16).map { String(format: "%02x", $0) }.joined())...")
            
            // Update sign count in both storage locations if credential exists in both
            storageManager.updateCounterInBothStorages(credentialId: credential.id, newCount: newSignCount)
            
            // Update the current credential store (respects virtual vs local storage context)
            _ = credentialStore.updateSignCount(for: credential.id, newCount: newSignCount)
            
            // Force UI refresh after every authentication
            NotificationCenter.default.post(
                name: .webAuthnCredentialUsed,
                object: nil,
                userInfo: ["credentialId": credential.id]
            )
            
            let assertion = LocalAuthAssertion(
                credentialId: credential.id,
                clientDataJSON: clientDataJSON,
                authenticatorData: authenticatorData,
                signature: signatureData,  // ✅ NOW USING DER FORMAT!
                userHandle: credential.userId.data(using: .utf8)
            )
            
            print("✅ Authentication successful for credential: \(credential.id) using \(storageManager.currentStorageMode.description)")
            print("✅ Counter synchronized across storage locations")
            print("🔍 AUTHENTICATION Final assertion:")
            print("   - Credential ID: \(assertion.credentialId)")
            print("   - Signature length: \(assertion.signature.count) bytes (DER-encoded)")
            print("   - User handle: \(assertion.userHandle?.count ?? 0) bytes")
            print("   - Final signature format: ASN.1 DER (WebAuthn compliant)")
            print("   - Expected server verification: ✅ SUCCESS")
            completion(.success(assertion))
            
        } catch {
            print("❌ Failed to sign authentication data: \(error)")
            completion(.failure(.authenticationFailed("Signing failed: \(error.localizedDescription)")))
        }
    }
    
    private func createClientDataJSON(type: String, challenge: Data, origin: String) -> Data {
        // Use base64url encoding for WebAuthn compliance (without padding)
        let challengeBase64url = challenge.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        
        // CRITICAL FIX: Create JSON with consistent field ordering for WebAuthn compliance
        // Some servers are strict about the canonical order: type, challenge, origin, crossOrigin
        let clientDataString = """
        {"type":"\(type)","challenge":"\(challengeBase64url)","origin":"\(origin)","crossOrigin":false}
        """
        
        guard let jsonData = clientDataString.data(using: .utf8) else {
            print("❌ Error creating client data JSON from string")
            return Data()
        }
        
        print("🔍 AUTHENTICATION Client Data JSON created (canonical order): \(clientDataString)")
        print("🔍 AUTHENTICATION JSON length: \(jsonData.count) bytes")
        
        // Verify it's valid JSON
        do {
            let _ = try JSONSerialization.jsonObject(with: jsonData)
            print("✅ AUTHENTICATION JSON validation passed")
        } catch {
            print("❌ AUTHENTICATION JSON validation failed: \(error)")
        }
        
        return jsonData
    }
    
    private func createEnhancedAuthenticatorData(rpId: String, signCount: UInt32) -> Data {
        // Enhanced authenticator data with proper WebAuthn format
        let rpIdHash = SHA256.hash(data: rpId.data(using: .utf8)!)
        
        // WebAuthn flags: UP (User Present) + UV (User Verified) + AT (Attested credential data NOT included for get)
        let flags: UInt8 = 0x05 // UP (0x01) + UV (0x04)
        
        var authenticatorData = Data(rpIdHash) // 32 bytes
        authenticatorData.append(flags)       // 1 byte
        
        // Add sign count (4 bytes, big endian)
        let signCountBytes = withUnsafeBytes(of: signCount.bigEndian) { Data($0) }
        authenticatorData.append(signCountBytes)
        
        print("🔍 Enhanced authenticator data created: \(authenticatorData.count) bytes, signCount: \(signCount)")
        return authenticatorData
    }
    
    // MARK: - Database Management (Migration Removed)
    
    // Test method to verify database functionality
    public func testDatabaseFunctionality() -> Bool {
        print("🧪 Testing database functionality...")
        
        // Create a test credential
        let testCredId = "test-credential-\(Date().timeIntervalSince1970)"
        let testPrivateKey = P256.Signing.PrivateKey()
        let testCredential = LocalCredential(
            id: testCredId,
            rpId: "test.example.com",
            userName: "test-user",
            userDisplayName: "Test User",
            userId: "test-user-id",
            publicKey: testPrivateKey.publicKey.x963Representation,
            createdAt: Date()
        )
        
        // Try to store it
        print("🧪 Storing test credential...")
        let storeSuccess = WebAuthnClientCredentialStore.shared.storeCredential(testCredential, privateKey: testPrivateKey)
        
        if !storeSuccess {
            print("❌ Test failed: Could not store credential")
            return false
        }
        
        // Try to retrieve it
        print("🧪 Retrieving test credential...")
        let retrievedCredentials = WebAuthnClientCredentialStore.shared.getCredentials(for: "test.example.com")
        
        if retrievedCredentials.isEmpty {
            print("❌ Test failed: Could not retrieve stored credential")
            return false
        }
        
        let found = retrievedCredentials.first { $0.id == testCredId }
        if found == nil {
            print("❌ Test failed: Retrieved credentials don't contain our test credential")
            return false
        }
        
        // Try to get the private key
        print("🧪 Retrieving private key...")
        let retrievedPrivateKey = WebAuthnClientCredentialStore.shared.getPrivateKey(for: testCredId)
        
        if retrievedPrivateKey == nil {
            print("❌ Test failed: Could not retrieve private key")
            return false
        }
        
        // Clean up
        print("🧪 Cleaning up test credential...")
        _ = WebAuthnClientCredentialStore.shared.deleteCredential(credentialId: testCredId)
        
        print("✅ Database functionality test passed!")
        return true
    }
    
    // Manual database cleanup for troubleshooting
    public func cleanupDatabase() {
        print("🧹 Manual database cleanup initiated...")
        
        let fileManager = FileManager.default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDirectory = appSupport.appendingPathComponent("WebMan")
        
        let dbFiles = [
            "WebAuthnClient.db",
            "WebAuthnClient.db-shm", 
            "WebAuthnClient.db-wal"
        ]
        
        for fileName in dbFiles {
            let fileURL = appDirectory.appendingPathComponent(fileName)
            if fileManager.fileExists(atPath: fileURL.path) {
                do {
                    let attributes = try fileManager.attributesOfItem(atPath: fileURL.path)
                    let size = attributes[.size] as? Int64 ?? 0
                    
                    // Backup before deletion
                    let backupURL = appDirectory.appendingPathComponent("\(fileName).backup.\(Date().timeIntervalSince1970)")
                    try fileManager.moveItem(at: fileURL, to: backupURL)
                    print("📁 Backed up \(fileName) (\(size) bytes) to \(backupURL.lastPathComponent)")
                } catch {
                    print("❌ Failed to backup \(fileName): \(error)")
                }
            }
        }
        
        print("✅ Database cleanup completed. Restart the app to recreate databases.")
    }
}

// MARK: - Data Models

public struct LocalCredential: Codable {
    let id: String
    let rpId: String
    let userName: String
    let userDisplayName: String
    let userId: String
    let publicKey: Data
    let createdAt: Date
}

public struct LocalAuthAssertion {
    let credentialId: String
    let clientDataJSON: Data
    let authenticatorData: Data
    let signature: Data
    let userHandle: Data?
}

public enum LocalAuthError: Error {
    case biometricNotAvailable
    case authenticationFailed(String)
    case keychainError(String)
    case noCredentialsFound
    case invalidCredential
    case touchIDNotAvailable
    
    var localizedDescription: String {
        switch self {
        case .biometricNotAvailable:
            return "Biometric authentication is not available"
        case .authenticationFailed(let message):
            return "Authentication failed: \(message)"
        case .keychainError(let message):
            return "Storage error: \(message)"
        case .noCredentialsFound:
            return "No credentials found for this site"
        case .invalidCredential:
            return "Invalid credential data"
        case .touchIDNotAvailable:
            return "Touch ID is not available"
        }
    }
} 
