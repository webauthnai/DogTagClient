// Copyright 2025 FIDO3.ai
// Generated on 2025-7-19
import Foundation

// MARK: - Public Types and Enums

/// WebAuthn protocol version support
public enum WebAuthnProtocol: String, CaseIterable {
    case fido2CBOR = "fido2-cbor"
    case u2fV1A = "u2f-v1a"
    
    var description: String {
        switch self {
        case .fido2CBOR:
            return "FIDO2 CBOR"
        case .u2fV1A:
            return "U2F v1.0"
        }
    }
}

/// Storage backend options for credentials
public enum WebAuthnStorageBackend {
    case json(String)           // JSON file path
    case swiftData(String)      // Database path - now uses DogTagStorage
}

/// Supported attestation formats
public enum AttestationFormat: String, CaseIterable {
    case none = "none"
    case packed = "packed"
    case tpm = "tpm"
    case androidKey = "android-key"
    case androidSafetynet = "android-safetynet"
    case fido_u2f = "fido-u2f"
    case apple = "apple"
    
    /// Known AAGUIDs for this attestation format
    public var supportedAAGUIDs: [String] {
        switch self {
        case .apple:
            return [
                "00000000-0000-0000-0000-000000000000", // Apple Face ID
                "ADCE0002-35BC-C60A-648B-0B25F1F05503", // Apple Touch ID
            ]
        case .tpm:
            return ["08987058-CADC-4B81-B6E1-30DE50DCBE96"] // Windows Hello TPM
        case .androidKey:
            return ["B93FD961-F2E6-462F-B122-82002247DE78"] // Android Key Attestation
        default:
            return []
        }
    }
}

/// WebAuthn credential information
public struct WebAuthnCredential: Codable, Sendable {
    public let id: String
    public let publicKey: String
    public let signCount: UInt32
    public let username: String
    public let algorithm: Int
    public let protocolVersion: String
    public let attestationFormat: String
    public let aaguid: String?
    public let isDiscoverable: Bool
    public let backupEligible: Bool?
    public let backupState: Bool?
    public let emoji: String?
    public let lastLoginIP: String?
    public let lastLoginAt: Date?
    public let createdAt: Date?
    public let isEnabled: Bool
    public let isAdmin: Bool
    public let userNumber: Int?
    
    /// Legacy initializer for backward compatibility
    public init(id: String, publicKey: String, signCount: UInt32, username: String, algorithm: Int, protocolVersion: String) {
        self.id = id
        self.publicKey = publicKey
        self.signCount = signCount
        self.username = username
        self.algorithm = algorithm
        self.protocolVersion = protocolVersion
        self.attestationFormat = "none"
        self.aaguid = nil
        self.isDiscoverable = false
        self.backupEligible = nil
        self.backupState = nil
        self.emoji = nil
        self.lastLoginIP = nil
        self.lastLoginAt = nil
        self.createdAt = Date()
        self.isEnabled = true
        self.isAdmin = false
        self.userNumber = nil
    }
    
    /// Enhanced initializer with full metadata
    public init(
        id: String,
        publicKey: String,
        signCount: UInt32,
        username: String,
        algorithm: Int,
        protocolVersion: String,
        attestationFormat: String,
        aaguid: String?,
        isDiscoverable: Bool,
        backupEligible: Bool?,
        backupState: Bool?,
        emoji: String? = nil,
        lastLoginIP: String? = nil,
        lastLoginAt: Date? = nil,
        createdAt: Date? = nil,
        isEnabled: Bool = true,
        isAdmin: Bool = false,
        userNumber: Int? = nil
    ) {
        self.id = id
        self.publicKey = publicKey
        self.signCount = signCount
        self.username = username
        self.algorithm = algorithm
        self.protocolVersion = protocolVersion
        self.attestationFormat = attestationFormat
        self.aaguid = aaguid
        self.isDiscoverable = isDiscoverable
        self.backupEligible = backupEligible
        self.backupState = backupState
        self.emoji = emoji
        self.lastLoginIP = lastLoginIP
        self.lastLoginAt = lastLoginAt
        self.createdAt = createdAt ?? Date()
        self.isEnabled = isEnabled
        self.isAdmin = isAdmin
        self.userNumber = userNumber
    }
}

/// WebAuthn specific errors
public enum WebAuthnError: Error, Equatable, LocalizedError {
    case credentialNotFound
    case invalidCredential
    case verificationFailed
    case duplicateUsername
    case signCountInvalid
    case accessDenied
    case unsupportedProtocol
    case storageError
    case networkError
    case userCancelled
    case timeoutExpired
    
    public var errorDescription: String? {
        switch self {
        case .credentialNotFound:
            return "Credential not found"
        case .invalidCredential:
            return "Invalid credential data"
        case .verificationFailed:
            return "Credential verification failed"
        case .duplicateUsername:
            return "Username already exists"
        case .signCountInvalid:
            return "Invalid signature counter"
        case .accessDenied:
            return "Access denied"
        case .unsupportedProtocol:
            return "Unsupported WebAuthn protocol"
        case .storageError:
            return "Storage operation failed"
        case .networkError:
            return "Network request failed"
        case .userCancelled:
            return "User cancelled operation"
        case .timeoutExpired:
            return "Operation timed out"
        }
    }
}

/// Configuration options for WebAuthn registration
public struct WebAuthnRegistrationOptions {
    public let username: String
    public let displayName: String?
    public let enablePasskeys: Bool
    public let timeout: Int
    public let userIcon: String?
    public let additionalData: [String: Any]?
    
    public init(
        username: String,
        displayName: String? = nil,
        enablePasskeys: Bool = true,
        timeout: Int = 300000,
        userIcon: String? = nil,
        additionalData: [String: Any]? = nil
    ) {
        self.username = username
        self.displayName = displayName
        self.enablePasskeys = enablePasskeys
        self.timeout = timeout
        self.userIcon = userIcon
        self.additionalData = additionalData
    }
}

/// Configuration options for WebAuthn authentication
public struct WebAuthnAuthenticationOptions {
    public let username: String?
    public let timeout: Int
    public let userVerification: String
    public let additionalData: [String: Any]?
    
    public init(
        username: String? = nil,
        timeout: Int = 60000,
        userVerification: String = "required",
        additionalData: [String: Any]? = nil
    ) {
        self.username = username
        self.timeout = timeout
        self.userVerification = userVerification
        self.additionalData = additionalData
    }
}

/// WebAuthn manager configuration
public struct WebAuthnConfiguration {
    public let rpId: String
    public let rpName: String?
    public let rpIcon: String?
    public let defaultUserIcon: String?
    public let `protocol`: WebAuthnProtocol
    public let storageBackend: WebAuthnStorageBackend
    
    public init(
        rpId: String,
        rpName: String? = nil,
        rpIcon: String? = nil,
        defaultUserIcon: String? = nil,
        protocol: WebAuthnProtocol = .fido2CBOR,
        storageBackend: WebAuthnStorageBackend = .json("")
    ) {
        self.rpId = rpId
        self.rpName = rpName
        self.rpIcon = rpIcon
        self.defaultUserIcon = defaultUserIcon
        self.`protocol` = `protocol`
        self.storageBackend = storageBackend
    }
}

/// User management interface for WebAuthn integrations
public protocol WebAuthnUserManager {
    /// Check if a user is enabled and can authenticate
    func isUserEnabled(username: String) -> Bool
    
    /// Get user emoji for display
    func getUserEmoji(username: String) -> String?
    
    /// Update user emoji
    func updateUserEmoji(username: String, emoji: String) -> Bool
    
    /// Create or update user record after registration
    func createUser(username: String, credentialId: String, publicKey: String, clientIP: String?, emoji: String) throws
    
    /// Update user login information after authentication
    func updateUserLogin(username: String, signCount: UInt32, clientIP: String?) throws
    
    /// Delete user and associated data
    func deleteUser(username: String) throws
}

/// Simple in-memory user manager for testing
public class InMemoryUserManager: WebAuthnUserManager {
    private var users: [String: UserRecord] = [:]
    
    private struct UserRecord {
        var isEnabled: Bool = true
        var emoji: String = "👤"
        var credentialId: String
        var publicKey: String
        var signCount: UInt32 = 0
        var lastLoginIP: String?
        var createdAt: Date = Date()
        var lastLoginAt: Date?
    }
    
    public init() {}
    
    public func isUserEnabled(username: String) -> Bool {
        return users[username]?.isEnabled ?? false
    }
    
    public func getUserEmoji(username: String) -> String? {
        return users[username]?.emoji
    }
    
    public func updateUserEmoji(username: String, emoji: String) -> Bool {
        guard users[username] != nil else { return false }
        users[username]?.emoji = emoji
        return true
    }
    
    public func createUser(username: String, credentialId: String, publicKey: String, clientIP: String?, emoji: String) throws {
        users[username] = UserRecord(
            emoji: emoji,
            credentialId: credentialId,
            publicKey: publicKey,
            lastLoginIP: clientIP
        )
    }
    
    public func updateUserLogin(username: String, signCount: UInt32, clientIP: String?) throws {
        guard var user = users[username] else {
            throw WebAuthnError.credentialNotFound
        }
        user.signCount = signCount
        user.lastLoginIP = clientIP
        user.lastLoginAt = Date()
        users[username] = user
    }
    
    public func deleteUser(username: String) throws {
        users.removeValue(forKey: username)
    }
}

// MARK: - Credential Models

/// Simple credential model for storage compatibility (no longer uses SwiftData)
public class WebAuthnCredentialModel {
    public var id: String
    public var publicKey: String
    public var signCount: UInt32
    public var username: String
    public var algorithm: Int
    public var protocolVersion: String
    public var attestationFormat: String
    public var aaguid: String?
    public var isDiscoverable: Bool
    public var backupEligible: Bool?
    public var backupState: Bool?
    public var emoji: String?
    public var lastLoginIP: String?
    public var lastLoginAt: Date?
    public var createdAt: Date?
    public var isEnabled: Bool
    public var isAdmin: Bool
    public var userNumber: Int?
    
    public init(
        id: String,
        publicKey: String,
        signCount: UInt32,
        username: String,
        algorithm: Int,
        protocolVersion: String,
        attestationFormat: String,
        aaguid: String? = nil,
        isDiscoverable: Bool = true,
        backupEligible: Bool? = nil,
        backupState: Bool? = nil,
        emoji: String? = nil,
        lastLoginIP: String? = nil,
        lastLoginAt: Date? = nil,
        createdAt: Date? = nil,
        isEnabled: Bool = true,
        isAdmin: Bool = false,
        userNumber: Int? = nil
    ) {
        self.id = id
        self.publicKey = publicKey
        self.signCount = signCount
        self.username = username
        self.algorithm = algorithm
        self.protocolVersion = protocolVersion
        self.attestationFormat = attestationFormat
        self.aaguid = aaguid
        self.isDiscoverable = isDiscoverable
        self.backupEligible = backupEligible
        self.backupState = backupState
        self.emoji = emoji
        self.lastLoginIP = lastLoginIP
        self.lastLoginAt = lastLoginAt
        self.createdAt = createdAt
        self.isEnabled = isEnabled
        self.isAdmin = isAdmin
        self.userNumber = userNumber
    }
    
    public var webAuthnCredential: WebAuthnCredential {
        return WebAuthnCredential(
            id: id,
            publicKey: publicKey,
            signCount: signCount,
            username: username,
            algorithm: algorithm,
            protocolVersion: protocolVersion,
            attestationFormat: attestationFormat,
            aaguid: aaguid,
            isDiscoverable: isDiscoverable,
            backupEligible: backupEligible,
            backupState: backupState,
            emoji: emoji,
            lastLoginIP: lastLoginIP,
            lastLoginAt: lastLoginAt,
            createdAt: createdAt,
            isEnabled: isEnabled,
            isAdmin: isAdmin,
            userNumber: userNumber
        )
    }
} 
