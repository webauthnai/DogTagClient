// Copyright 2025 FIDO3.ai
// Generated on 2025-7-19
import Foundation
import SwiftUI

// MARK: - Key Storage Preferences

/// Preferences for how future WebAuthn keys should be created and stored
public class KeyStoragePreferences: ObservableObject {
    public static let shared = KeyStoragePreferences()
    
    // MARK: - UserDefaults Keys
    private enum Keys {
        static let keyStorageMode = "WebMan.KeyStorageMode"
        static let allowCloudSharing = "WebMan.AllowCloudSharing"
        static let preferHardwareBacking = "WebMan.PreferHardwareBacking"
        static let keyBackingPreference = "WebMan.KeyBackingPreference"
        static let requireBiometricAuth = "WebMan.RequireBiometricAuth"
        static let keyExportPolicy = "WebMan.KeyExportPolicy"
        static let cloudSyncEnabled = "WebMan.CloudSyncEnabled"
    }
    
    // MARK: - Key Storage Mode
    public enum KeyStorageMode: String, CaseIterable {
        case hardwareOnly = "hardware_only"        // Secure Enclave/TPM only
        case softwareOnly = "software_only"        // Software encryption only
        case adaptive = "adaptive"                 // Choose based on availability
        case cloudOptimized = "cloud_optimized"    // Optimized for cloud sharing
        
        public var displayName: String {
            switch self {
            case .hardwareOnly:
                return "Hardware Only"
            case .softwareOnly:
                return "Software Only"
            case .adaptive:
                return "Adaptive (Recommended)"
            case .cloudOptimized:
                return "Cloud Optimized"
            }
        }
        
        public var description: String {
            switch self {
            case .hardwareOnly:
                return "Keys stored in Secure Enclave/TPM. Maximum security, cannot be shared."
            case .softwareOnly:
                return "Keys encrypted in software. Can be exported and shared."
            case .adaptive:
                return "Use hardware when available, software as fallback."
            case .cloudOptimized:
                return "Software-based keys optimized for cloud synchronization."
            }
        }
        
        public var isCloudCompatible: Bool {
            switch self {
            case .hardwareOnly:
                return false
            case .softwareOnly, .adaptive, .cloudOptimized:
                return true
            }
        }
    }
    
    // MARK: - Key Backing Preference for Future Keys
    public enum KeyBackingPreference: String, CaseIterable {
        case hardwareBacked = "hardware_backed"    // Secure Enclave/TPM
        case softwareBacked = "software_backed"    // Software encryption
        case automatic = "automatic"               // System decides based on availability
        
        public var displayName: String {
            switch self {
            case .hardwareBacked:
                return "Hardware-Backed (Secure Enclave)"
            case .softwareBacked:
                return "Software-Backed (Non-Secure Enclave)"
            case .automatic:
                return "Automatic (System Decides)"
            }
        }
        
        public var description: String {
            switch self {
            case .hardwareBacked:
                return "Future keys will be stored in Secure Enclave/TPM for maximum security. Keys cannot be exported or shared."
            case .softwareBacked:
                return "Future keys will use software encryption. Keys can be exported and shared across devices."
            case .automatic:
                return "System automatically chooses hardware backing when available, software as fallback."
            }
        }
        
        public var securityLevel: String {
            switch self {
            case .hardwareBacked:
                return "🔒 Maximum Security"
            case .softwareBacked:
                return "🔓 Standard Security"
            case .automatic:
                return "⚖️ Balanced Security"
            }
        }
        
        public var portability: String {
            switch self {
            case .hardwareBacked:
                return "❌ Device-Locked"
            case .softwareBacked:
                return "✅ Portable"
            case .automatic:
                return "⚠️ Depends on Choice"
            }
        }
        
        public var isExportable: Bool {
            switch self {
            case .hardwareBacked:
                return false
            case .softwareBacked, .automatic:
                return true
            }
        }
    }

    // MARK: - Key Export Policy
    public enum KeyExportPolicy: String, CaseIterable {
        case never = "never"                       // Never allow export
        case biometricOnly = "biometric_only"      // Only with biometric auth
        case passwordProtected = "password_protected" // Export with password
        case unrestricted = "unrestricted"         // Allow free export
        
        public var displayName: String {
            switch self {
            case .never:
                return "Never"
            case .biometricOnly:
                return "Biometric Only"
            case .passwordProtected:
                return "Password Protected"
            case .unrestricted:
                return "Unrestricted"
            }
        }
        
        public var description: String {
            switch self {
            case .never:
                return "Keys cannot be exported under any circumstances."
            case .biometricOnly:
                return "Export requires biometric authentication (Touch ID/Face ID)."
            case .passwordProtected:
                return "Export requires a strong password."
            case .unrestricted:
                return "Keys can be exported freely (not recommended)."
            }
        }
    }
    
    // MARK: - Published Properties
    @Published public var keyStorageMode: KeyStorageMode {
        didSet {
            UserDefaults.standard.set(keyStorageMode.rawValue, forKey: Keys.keyStorageMode)
            print("🔧 Key storage mode changed to: \(keyStorageMode.displayName)")
        }
    }
    
    @Published public var allowCloudSharing: Bool {
        didSet {
            UserDefaults.standard.set(allowCloudSharing, forKey: Keys.allowCloudSharing)
            print("☁️ Cloud sharing \(allowCloudSharing ? "enabled" : "disabled")")
        }
    }
    
    @Published public var preferHardwareBacking: Bool {
        didSet {
            UserDefaults.standard.set(preferHardwareBacking, forKey: Keys.preferHardwareBacking)
            print("🔒 Hardware backing preference: \(preferHardwareBacking)")
        }
    }
    
    @Published public var keyBackingPreference: KeyBackingPreference {
        didSet {
            UserDefaults.standard.set(keyBackingPreference.rawValue, forKey: Keys.keyBackingPreference)
            print("🔑 Future key backing preference: \(keyBackingPreference.displayName)")
        }
    }
    
    @Published public var requireBiometricAuth: Bool {
        didSet {
            UserDefaults.standard.set(requireBiometricAuth, forKey: Keys.requireBiometricAuth)
            print("👆 Biometric auth requirement: \(requireBiometricAuth)")
        }
    }
    
    @Published public var keyExportPolicy: KeyExportPolicy {
        didSet {
            UserDefaults.standard.set(keyExportPolicy.rawValue, forKey: Keys.keyExportPolicy)
            print("📤 Key export policy: \(keyExportPolicy.displayName)")
        }
    }
    
    @Published public var cloudSyncEnabled: Bool {
        didSet {
            UserDefaults.standard.set(cloudSyncEnabled, forKey: Keys.cloudSyncEnabled)
            print("🔄 Cloud sync \(cloudSyncEnabled ? "enabled" : "disabled")")
        }
    }
    
    // MARK: - Initialization
    private init() {
        // Load from UserDefaults with sensible defaults
        let storageModeRaw = UserDefaults.standard.string(forKey: Keys.keyStorageMode) ?? KeyStorageMode.adaptive.rawValue
        self.keyStorageMode = KeyStorageMode(rawValue: storageModeRaw) ?? .adaptive
        
        self.allowCloudSharing = UserDefaults.standard.bool(forKey: Keys.allowCloudSharing)
        self.preferHardwareBacking = UserDefaults.standard.object(forKey: Keys.preferHardwareBacking) as? Bool ?? true
        
        let keyBackingRaw = UserDefaults.standard.string(forKey: Keys.keyBackingPreference) ?? KeyBackingPreference.automatic.rawValue
        self.keyBackingPreference = KeyBackingPreference(rawValue: keyBackingRaw) ?? .automatic
        
        self.requireBiometricAuth = UserDefaults.standard.object(forKey: Keys.requireBiometricAuth) as? Bool ?? true
        
        let exportPolicyRaw = UserDefaults.standard.string(forKey: Keys.keyExportPolicy) ?? KeyExportPolicy.biometricOnly.rawValue
        self.keyExportPolicy = KeyExportPolicy(rawValue: exportPolicyRaw) ?? .biometricOnly
        
        self.cloudSyncEnabled = UserDefaults.standard.bool(forKey: Keys.cloudSyncEnabled)
        
        print("🔧 KeyStoragePreferences initialized:")
        print("   - Storage Mode: \(keyStorageMode.displayName)")
        print("   - Cloud Sharing: \(allowCloudSharing)")
        print("   - Hardware Backing: \(preferHardwareBacking)")
        print("   - Future Key Backing: \(keyBackingPreference.displayName)")
        print("   - Biometric Auth: \(requireBiometricAuth)")
        print("   - Export Policy: \(keyExportPolicy.displayName)")
        print("   - Cloud Sync: \(cloudSyncEnabled)")
    }
    
    // MARK: - Computed Properties
    
    /// Whether new keys should be hardware-backed based on current preferences
    public var shouldUseHardwareBacking: Bool {
        switch keyBackingPreference {
        case .hardwareBacked:
            return isHardwareAvailable
        case .softwareBacked:
            return false
        case .automatic:
            return isHardwareAvailable && preferHardwareBacking
        }
    }
    
    /// Whether new keys should be hardware-backed (legacy compatibility)
    public var shouldUseHardwareBackingLegacy: Bool {
        switch keyStorageMode {
        case .hardwareOnly:
            return true
        case .softwareOnly, .cloudOptimized:
            return false
        case .adaptive:
            return preferHardwareBacking && isHardwareAvailable
        }
    }
    
    /// Whether new keys should be exportable based on current preferences
    public var shouldAllowKeyExport: Bool {
        return keyExportPolicy != .never && keyStorageMode.isCloudCompatible
    }
    
    /// Whether hardware backing is available on this platform
    public var isHardwareAvailable: Bool {
        #if os(macOS) || os(iOS)
        return true  // Secure Enclave available
        #else
        return false
        #endif
    }
    
    /// Whether cloud features should be enabled
    public var shouldEnableCloudFeatures: Bool {
        return allowCloudSharing && cloudSyncEnabled && keyStorageMode.isCloudCompatible
    }
    
    // MARK: - Validation Methods
    
    /// Validate that current preferences are compatible with cloud sharing
    public func validateCloudCompatibility() -> (isValid: Bool, issues: [String]) {
        var issues: [String] = []
        
        if allowCloudSharing && !keyStorageMode.isCloudCompatible {
            issues.append("Cloud sharing requires software-based or adaptive key storage")
        }
        
        if cloudSyncEnabled && keyExportPolicy == .never {
            issues.append("Cloud sync requires exportable keys")
        }
        
        if keyStorageMode == .hardwareOnly && allowCloudSharing {
            issues.append("Hardware-only keys cannot be shared in the cloud")
        }
        
        return (isValid: issues.isEmpty, issues: issues)
    }
    
    // MARK: - Preset Configurations
    
    /// Configure for maximum security (hardware-only, no cloud)
    public func configureForMaximumSecurity() {
        keyStorageMode = .hardwareOnly
        keyBackingPreference = .hardwareBacked
        allowCloudSharing = false
        preferHardwareBacking = true
        requireBiometricAuth = true
        keyExportPolicy = .never
        cloudSyncEnabled = false
        print("🔒 Configured for maximum security")
    }
    
    /// Configure for cloud sharing and collaboration
    public func configureForCloudSharing() {
        keyStorageMode = .cloudOptimized
        keyBackingPreference = .softwareBacked
        allowCloudSharing = true
        preferHardwareBacking = false
        requireBiometricAuth = true
        keyExportPolicy = .biometricOnly
        cloudSyncEnabled = true
        print("☁️ Configured for cloud sharing")
    }
    
    /// Configure for balanced security and usability
    public func configureForBalanced() {
        keyStorageMode = .adaptive
        keyBackingPreference = .automatic
        allowCloudSharing = false
        preferHardwareBacking = true
        requireBiometricAuth = true
        keyExportPolicy = .biometricOnly
        cloudSyncEnabled = false
        print("⚖️ Configured for balanced security")
    }
    
    /// Reset to default settings
    public func resetToDefaults() {
        keyStorageMode = .adaptive
        keyBackingPreference = .automatic
        allowCloudSharing = false
        preferHardwareBacking = true
        requireBiometricAuth = true
        keyExportPolicy = .biometricOnly
        cloudSyncEnabled = false
        print("🔄 Reset to default preferences")
    }
}

// MARK: - SwiftUI Preferences View

public struct KeyStoragePreferencesView: View {
    @StateObject private var preferences = KeyStoragePreferences.shared
    @State private var showingValidationAlert = false
    @State private var validationIssues: [String] = []
    
    public init() {}
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Key Storage Preferences")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text("Configure how future WebAuthn keys will be created and stored. These settings affect new credentials only.")
                .font(.caption)
                .foregroundColor(.secondary)
            
            // Storage Mode Section
            GroupBox("Storage Mode") {
                VStack(alignment: .leading, spacing: 12) {
                    Picker("Key Storage Mode", selection: $preferences.keyStorageMode) {
                        ForEach(KeyStoragePreferences.KeyStorageMode.allCases, id: \.self) { mode in
                            VStack(alignment: .leading) {
                                Text(mode.displayName)
                                    .foregroundColor(.primary)
                                Text(mode.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .tag(mode)
                        }
                    }
                    .pickerStyle(.menu)
                    
                    if preferences.keyStorageMode == .adaptive {
                        Toggle("Prefer Hardware Backing", isOn: $preferences.preferHardwareBacking)
                            .help("Use Secure Enclave when available")
                            .foregroundColor(.primary)
                    }
                }
                .padding(12)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(8)
            }
            
            // Cloud Features Section
            GroupBox("Cloud Features") {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Allow Cloud Sharing", isOn: $preferences.allowCloudSharing)
                        .help("Enable sharing keys across devices via cloud")
                        .foregroundColor(.primary)
                    
                    if preferences.allowCloudSharing {
                        Toggle("Enable Cloud Sync", isOn: $preferences.cloudSyncEnabled)
                            .help("Automatically sync keys across devices")
                            .disabled(!preferences.keyStorageMode.isCloudCompatible)
                            .foregroundColor(.primary)
                    }
                }
                .padding(12)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
            }
            
            // Future Key Creation Section
            GroupBox("Future Key Creation") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Key Backing Preference")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("Choose how future WebAuthn credentials will be secured:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Picker("Key Backing", selection: $preferences.keyBackingPreference) {
                        ForEach(KeyStoragePreferences.KeyBackingPreference.allCases, id: \.self) { backing in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(backing.displayName)
                                        .fontWeight(.medium)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Text(backing.securityLevel)
                                        .font(.caption)
                                }
                                
                                Text(backing.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                HStack {
                                    Text("Security: \(backing.securityLevel)")
                                        .font(.caption2)
                                    Spacer()
                                    Text("Portability: \(backing.portability)")
                                        .font(.caption2)
                                }
                                .foregroundColor(.secondary)
                            }
                            .tag(backing)
                        }
                    }
                    .pickerStyle(.menu)
                    
                    // Hardware availability indicator
                    HStack {
                        Image(systemName: preferences.isHardwareAvailable ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(preferences.isHardwareAvailable ? .green : .red)
                        
                        Text(preferences.isHardwareAvailable ? "Secure Enclave Available" : "Secure Enclave Not Available")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    // Current selection summary
                    if preferences.keyBackingPreference != .automatic {
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundColor(.blue)
                            
                            Text("Future keys will be: \(preferences.keyBackingPreference.displayName)")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                        .padding(.top, 4)
                    }
                }
                .padding(12)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
            }

            // Security Section
            GroupBox("Security") {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Require Biometric Authentication", isOn: $preferences.requireBiometricAuth)
                        .help("Require Touch ID/Face ID for key operations")
                        .foregroundColor(.primary)
                    
                    Picker("Key Export Policy", selection: $preferences.keyExportPolicy) {
                        ForEach(KeyStoragePreferences.KeyExportPolicy.allCases, id: \.self) { policy in
                            VStack(alignment: .leading) {
                                Text(policy.displayName)
                                    .foregroundColor(.primary)
                                Text(policy.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .tag(policy)
                        }
                    }
                    .pickerStyle(.menu)
                }
                .padding(12)
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
            }
            
            // Preset Configurations
            GroupBox("Quick Configurations") {
                HStack(spacing: 12) {
                    Button("Maximum Security") {
                        preferences.configureForMaximumSecurity()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    
                    Button("Cloud Sharing") {
                        preferences.configureForCloudSharing()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                    
                    Button("Balanced") {
                        preferences.configureForBalanced()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    
                    Spacer()
                    
                    Button("Reset Defaults") {
                        preferences.resetToDefaults()
                    }
                    .buttonStyle(.bordered)
                    .foregroundColor(.secondary)
                }
                .padding(12)
                .background(Color.secondary.opacity(0.05))
                .cornerRadius(8)
            }
            
            // Validation Status
            let validation = preferences.validateCloudCompatibility()
            if !validation.isValid {
                GroupBox {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(.orange)
                            Text("Configuration Issues")
                                .fontWeight(.semibold)
                        }
                        
                        ForEach(validation.issues, id: \.self) { issue in
                            Text("• \(issue)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            Spacer()
        }
        .padding()
        .background(Color(NSColor.textBackgroundColor))
        .alert("Configuration Issues", isPresented: $showingValidationAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("There are issues with the current configuration. Please review the issues and make adjustments.")
        }
    }
}

#Preview {
    KeyStoragePreferencesView()
} 
