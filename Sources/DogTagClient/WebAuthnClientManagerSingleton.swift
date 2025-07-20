// Copyright 2025 FIDO3.ai
// Generated on 2025-7-19
import Foundation

// WebAuthnClientManager singleton with lazy initialization
class WebAuthnClientManagerSingleton {
    nonisolated(unsafe) static let shared = WebAuthnClientManagerSingleton()
    
    private var _manager: WebAuthnManager?
    
    var manager: WebAuthnManager {
        if let manager = _manager {
            print("🔍 DEBUG: Returning existing WebAuthnClientManager singleton")
            return manager
        }
        
        print("🔧 Initializing WebAuthnClientManager singleton...")
        
        // Create proper database path in user's Application Support directory
        let fileManager = FileManager.default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDirectory = appSupport.appendingPathComponent("WebMan")
        
        print("🔍 DEBUG: App Support directory: \(appSupport.path)")
        print("🔍 DEBUG: WebMan directory: \(appDirectory.path)")
        
        // Ensure directory exists
        do {
            try fileManager.createDirectory(at: appDirectory, withIntermediateDirectories: true)
            print("✅ Created/verified WebMan directory")
        } catch {
            print("❌ Failed to create WebMan directory: \(error)")
        }
        
        // Use separate database file for WebAuthnManager to avoid schema conflicts
        let dbPath = appDirectory.appendingPathComponent("WebAuthnClient.db").path
        print("🔍 DEBUG: WebAuthnManager database path: \(dbPath)")
        
        let manager = WebAuthnManager(
            rpId: "https://webauthn.me/",
            webAuthnProtocol: .fido2CBOR,
            storageBackend: .swiftData(dbPath),
            rpName: "XCF Chat",
            rpIcon: nil,
            defaultUserIcon: nil,
            adminUsername: nil
        )
        
        _manager = manager
        print("✅ WebAuthnClientManager singleton initialized successfully")
        
        return manager
    }
    
    private init() {}
} 
