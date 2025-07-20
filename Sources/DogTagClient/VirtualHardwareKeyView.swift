import SwiftUI
import SwiftData
import AppKit
import CryptoKit
// Copyright 2025 FIDO3.ai
// Generated on 2025-7-19
import Foundation
import DogTagStorage

// Import the credential types from VirtualKeyDiagnostics
// (Note: These should be accessible since they're public in VirtualKeyDiagnostics.swift)

// MARK: - Notification Extensions

extension NSNotification.Name {
    static let credentialsChanged = NSNotification.Name("credentialsChanged")
}

// MARK: - Virtual Hardware Key Management View

public struct VirtualHardwareKeyView: View {
    @State private var virtualKeys: [VirtualHardwareKey] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingCreateSheet = false
    @State private var selectedDirectory: URL?
    @State private var showingDirectoryPicker = false
    @State private var selectedCredentials: Set<String> = []
    @State private var clientCredentials: [LocalCredential] = []
    @State private var serverCredentials: [WebAuthnCredential] = []
    @State private var isExporting = false
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Virtual Hardware Keys")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        Text("Portable credential storage using encrypted disk images")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 12) {
                        Button(action: { Task { await loadVirtualKeys() } }) {
                            Label("Refresh Info", systemImage: "arrow.clockwise")
                                .font(.system(size: 13))
                        }
                        .buttonStyle(.bordered)
                        
                        Button(action: { showingDirectoryPicker = true }) {
                            Label("Change Directory", systemImage: "folder")
                                .font(.system(size: 13))
                        }
                        .buttonStyle(.bordered)
                        
                        Button(action: { showingCreateSheet = true }) {
                            Label("Create New Key", systemImage: "plus")
                                .font(.system(size: 13))
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 8)
                
                // Storage location
                HStack(spacing: 4) {
                    Text("Storage Location:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(VirtualHardwareKeyManager.shared.currentVirtualKeysDirectory.path)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
            }
            .background(Color(NSColor.windowBackgroundColor).opacity(0.8))
            
            Divider()
            
            // Content
            ScrollView {
                VStack(spacing: 16) {
                    if isLoading {
                        ProgressView("Loading virtual keys...")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding(40)
                    } else if virtualKeys.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "key.fill")
                                .font(.system(size: 48))
                                .foregroundColor(.secondary.opacity(0.5))
                            
                            Text("No Virtual Keys")
                                .font(.title3)
                                .foregroundColor(.secondary)
                            
                            Text("Create a virtual hardware key to store credentials securely")
                                .font(.caption)
                                .foregroundColor(.secondary.opacity(0.8))
                            
                            Button(action: { showingCreateSheet = true }) {
                                Label("Create Virtual Key", systemImage: "plus.circle.fill")
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(40)
                    } else {
                        ForEach(virtualKeys) { virtualKey in
                            VirtualKeyCard(
                                virtualKey: virtualKey,
                                onDelete: {
                                    await deleteVirtualKey(virtualKey)
                                },
                                onRefresh: {
                                    await loadVirtualKeys()
                                }
                            )
                        }
                    }
                }
                .padding(20)
            }
            .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
        }
        .frame(minWidth: 800, minHeight: 600)
        .background(Color(NSColor.windowBackgroundColor))
        .task {
            await loadVirtualKeys()
        }
        .sheet(isPresented: $showingCreateSheet) {
            CreateVirtualKeySheet(
                isPresented: $showingCreateSheet,
                onCreate: { config in
                    await createVirtualKey(config: config)
                }
            )
        }
        .fileImporter(
            isPresented: $showingDirectoryPicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    do {
                        try VirtualHardwareKeyManager.shared.setCustomVirtualKeysDirectory(url)
                        Task {
                            await loadVirtualKeys()
                        }
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                }
            case .failure(let error):
                errorMessage = error.localizedDescription
            }
        }
        .alert("Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }
    
    private func loadVirtualKeys() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            virtualKeys = try await VirtualHardwareKeyManager.shared.listVirtualKeys()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    private func createVirtualKey(config: VirtualKeyConfiguration) async {
        do {
            _ = try await VirtualHardwareKeyManager.shared.createVirtualKey(config: config)
            await loadVirtualKeys()
        } catch {
            errorMessage = "Failed to create virtual key: \(error.localizedDescription)"
        }
    }
    
    private func deleteVirtualKey(_ virtualKey: VirtualHardwareKey) async {
        do {
            try await VirtualHardwareKeyManager.shared.deleteVirtualKey(id: virtualKey.id)
            await loadVirtualKeys()
        } catch {
            errorMessage = "Failed to delete virtual key: \(error.localizedDescription)"
        }
    }
}

// MARK: - Virtual Key Card

private struct VirtualKeyCard: View {
    let virtualKey: VirtualHardwareKey
    let onDelete: () async -> Void
    let onRefresh: () async -> Void
    
    @State private var showingDeleteAlert = false
    @State private var showingCredentials = true  // Show credentials by default
    @State private var isLoadingCredentials = false
    @State private var virtualKeyCredentials: [LocalCredential] = []
    @State private var serverCredentials: [WebAuthnCredential] = []
    @State private var credentialsError: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header row
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(virtualKey.name)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        if virtualKey.isLocked {
                            Image(systemName: "lock.fill")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                    
                    HStack(spacing: 16) {
                        Label("\(virtualKeyCredentials.count + serverCredentials.count) credentials", systemImage: "key.fill")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Button(action: {
                            withAnimation {
                                showingCredentials.toggle()
                            }
                        }) {
                            Image(systemName: showingCredentials ? "chevron.up" : "chevron.down")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                Spacer()
                
                HStack(spacing: 8) {
                    Button(action: { loadVirtualKey() }) {
                        Label("Insert Key", systemImage: "key.fill")
                            .font(.caption)
                    }
                    .buttonStyle(.borderedProminent)
                    .help("Insert this virtual key to use its credentials instead of local credentials")
                    
                    Button(role: .destructive) {
                        showingDeleteAlert = true
                    } label: {
                        Image(systemName: "trash")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                }
            }
            
            // Expandable credentials section
            if showingCredentials {
                VStack(alignment: .leading, spacing: 8) {
                    Divider()
                    
                    if isLoadingCredentials {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.7)
                            Text("Loading credentials...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 8)
                    } else if let error = credentialsError {
                        HStack {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(.orange)
                            Text("Error: \(error)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 8)
                    } else if virtualKeyCredentials.isEmpty && serverCredentials.isEmpty {
                        Text("No credentials found in this virtual key")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.vertical, 8)
                    } else {
                        // Show client credentials
                        if !virtualKeyCredentials.isEmpty {
                            Text("Client Credentials (\(virtualKeyCredentials.count))")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.blue)
                            
                            ForEach(virtualKeyCredentials, id: \.id) { credential in
                                VirtualCredentialRow(credential: credential, virtualKey: virtualKey, onExport: {
                                    Task {
                                        await exportCredentialToLocal(credential)
                                    }
                                }, onRemove: {
                                    Task {
                                        await removeCredentialFromVirtualKey(credential)
                                    }
                                })
                                .padding(.leading, 12)
                            }
                        }
                        
                        // Show server credentials
                        if !serverCredentials.isEmpty {
                            Text("Server Credentials (\(serverCredentials.count))")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.green)
                            
                            ForEach(serverCredentials, id: \.id) { credential in
                                VirtualServerCredentialRow(credential: credential, onRemove: {
                                    Task {
                                        await removeServerCredentialFromVirtualKey(credential)
                                    }
                                })
                                .padding(.leading, 12)
                            }
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.8))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(NSColor.separatorColor).opacity(0.5), lineWidth: 1)
        )
        .task {
            // Load credentials immediately when the card appears
            await loadCredentials()
        }
        .alert("Delete Virtual Key?", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task {
                    await onDelete()
                }
            }
        } message: {
            Text("Are you sure you want to delete '\(virtualKey.name)'? This cannot be undone.")
        }
    }
    
    private func loadCredentials() async {
        isLoadingCredentials = true
        credentialsError = nil
        defer { isLoadingCredentials = false }
        
        do {
            let analysis = try await VirtualKeyDiagnostics.shared.analyzeVirtualKey(
                virtualKey,
                password: virtualKey.isLocked ? nil : nil
            )
            
            await MainActor.run {
                virtualKeyCredentials = analysis.clientCredentials
                serverCredentials = analysis.serverCredentials
                print("🔍 Loaded \(virtualKeyCredentials.count) client credentials and \(serverCredentials.count) server credentials")
            }
        } catch {
            await MainActor.run {
                credentialsError = error.localizedDescription
                print("❌ Failed to load credentials: \(error)")
            }
        }
    }
    
    private func openExportWindow() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 800),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Export from \(virtualKey.name)"
        window.center()
        window.isReleasedWhenClosed = false
        
        let hostingView = NSHostingView(rootView: ExportFromVirtualKeyView(
            virtualKey: virtualKey,
            onExport: { credential in
                Task {
                    await exportCredentialToLocal(credential)
                }
            }
        ))
        window.contentView = hostingView
        window.makeKeyAndOrderFront(nil)
    }
    
    private func openImportWindow() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 400),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Import to \(virtualKey.name)"
        window.center()
        window.isReleasedWhenClosed = false
        
        let hostingView = NSHostingView(rootView: ImportCredentialsView(
            virtualKey: virtualKey,
            onImport: { keyId, password, overwrite in
                Task {
                    await importCredentials(keyId: keyId, password: password, overwriteExisting: overwrite)
                }
                window.close()
            }
        ))
        window.contentView = hostingView
        window.makeKeyAndOrderFront(nil)
    }
    
    private func importCredentials(keyId: UUID, password: String?, overwriteExisting: Bool) async {
        do {
            let count = try await VirtualHardwareKeyManager.shared.importCredentialsFromVirtualKey(
                keyId: keyId,
                password: password,
                overwriteExisting: overwriteExisting
            )
            print("✅ Imported \(count) credentials")
            await onRefresh()
        } catch {
            print("❌ Failed to import credentials: \(error)")
        }
    }
    
    private func loadVirtualKey() {
        // Ask for password if key is locked
        if virtualKey.isLocked {
            let alert = NSAlert()
            alert.messageText = "Enter Password"
            alert.informativeText = "This virtual key requires a password to access."
            alert.addButton(withTitle: "OK")
            alert.addButton(withTitle: "Cancel")
            
            let passwordField = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
            alert.accessoryView = passwordField
            
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                let password = passwordField.stringValue
                Task {
                    await mountAndLoadCredentials(password: password)
                }
            }
        } else {
            // Key is not locked, just mount it
            Task {
                await mountAndLoadCredentials(password: nil)
            }
        }
    }
    
    private func mountAndLoadCredentials(password: String?) async {
        isLoadingCredentials = true
        credentialsError = nil
        defer { isLoadingCredentials = false }
        
        do {
            // Switch the storage mode to use this virtual key instead of local storage
            try await VirtualKeyStorageManager.shared.switchToVirtualStorage(virtualKey, password: password)
            
            // Analyze the virtual key to get credentials
            let analysis = try await VirtualKeyDiagnostics.shared.analyzeVirtualKey(
                virtualKey,
                password: password
            )
            
            await MainActor.run {
                virtualKeyCredentials = analysis.clientCredentials
                serverCredentials = analysis.serverCredentials
                showingCredentials = true // Expand to show credentials
                print("✅ Successfully inserted key: \(virtualKey.name)")
                print("🔍 Now using \(virtualKeyCredentials.count) client credentials and \(serverCredentials.count) server credentials from this virtual key")
                
                // Post notification to update any credential views
                NotificationCenter.default.post(name: .credentialsChanged, object: nil)
            }
            
            // Update access tracking is handled by the storage manager
            
        } catch {
            await MainActor.run {
                credentialsError = "Failed to insert key: \(error.localizedDescription)"
                print("❌ Failed to insert key: \(error)")
            }
        }
    }
    
    private func exportCredentialToLocal(_ credential: LocalCredential) async {
        Task {
            print("🔄 Exporting credential \(credential.id) to local SwiftData database")
            
            // The credential is already in the correct LocalCredential format
            let success = await WebAuthnClientCredentialStore.shared.storeCredentialFromVirtualKey(credential)
            
            await MainActor.run {
                if success {
                    print("✅ Successfully exported credential \(credential.id) to local storage")
                    NotificationCenter.default.post(name: .credentialsChanged, object: nil)
                } else {
                    print("❌ Failed to export credential \(credential.id) to local storage")
                }
            }
        }
    }
    
    private func removeCredentialFromVirtualKey(_ credential: LocalCredential) async {
        print("🔄 Removing credential \(credential.id) from virtual key: \(virtualKey.name)")
        
        do {
            // Get the virtual key mount point
            guard let mountPoint = try? await VirtualHardwareKeyManager.shared.mountDiskImage(
                virtualKey.diskImagePath, 
                password: virtualKey.isLocked ? nil : nil
            ) else {
                print("❌ Failed to mount virtual key for credential removal")
                return
            }
            
            // Remove from the virtual key's UNIFIED database
            let unifiedDbPath = mountPoint.appendingPathComponent("WebAuthnClient.db")
            if FileManager.default.fileExists(atPath: unifiedDbPath.path) {
                let config = StorageConfiguration(
                    databaseName: "WebAuthnClient", // UNIFIED DATABASE
                    customDatabasePath: unifiedDbPath.path
                )
                let virtualKeyStorage = try await StorageFactory.createStorageManager(configuration: config)
                try await virtualKeyStorage.deleteCredential(id: credential.id)
                print("✅ Removed credential \(credential.id) from virtual key UNIFIED database")
            }
            
            // Refresh the credentials list
            await loadCredentials()
            
            // Post notification to update any credential views
            await MainActor.run {
                NotificationCenter.default.post(name: .credentialsChanged, object: nil)
            }
            
            print("✅ Successfully removed credential \(credential.id) from virtual key: \(virtualKey.name)")
            
        } catch {
            print("❌ Failed to remove credential \(credential.id) from virtual key: \(error)")
        }
    }
    
    private func removeServerCredentialFromVirtualKey(_ credential: WebAuthnCredential) async {
        print("🔄 Removing server credential \(credential.id) from virtual key: \(virtualKey.name)")
        
        do {
            // Get the virtual key mount point
            guard let mountPoint = try? await VirtualHardwareKeyManager.shared.mountDiskImage(
                virtualKey.diskImagePath, 
                password: virtualKey.isLocked ? nil : nil
            ) else {
                print("❌ Failed to mount virtual key for server credential removal")
                return
            }
            
            // Remove from the virtual key's UNIFIED database
            let unifiedDbPath = mountPoint.appendingPathComponent("WebAuthnClient.db")
            if FileManager.default.fileExists(atPath: unifiedDbPath.path) {
                let config = StorageConfiguration(
                    databaseName: "WebAuthnClient", // UNIFIED DATABASE
                    customDatabasePath: unifiedDbPath.path
                )
                let virtualKeyStorage = try await StorageFactory.createStorageManager(configuration: config)
                try await virtualKeyStorage.deleteServerCredential(id: credential.id)
                print("✅ Removed server credential \(credential.id) from virtual key UNIFIED database")
            }
            
            // Refresh the credentials list
            await loadCredentials()
            
            // Post notification to update any credential views
            await MainActor.run {
                NotificationCenter.default.post(name: .credentialsChanged, object: nil)
            }
            
            print("✅ Successfully removed server credential \(credential.id) from virtual key: \(virtualKey.name)")
            
        } catch {
            print("❌ Failed to remove server credential \(credential.id) from virtual key: \(error)")
        }
    }
}

// MARK: - Virtual Credential Row

private struct VirtualCredentialRow: View {
    let credential: LocalCredential
    let virtualKey: VirtualHardwareKey
    let onExport: () async -> Void
    let onRemove: () async -> Void
    
    @State private var isExpanded = false
    @State private var showingRemoveAlert = false
    @State private var privateKeyData: Data? = nil
    @State private var isLoadingPrivateKey = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header row with expand/collapse
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(credential.userDisplayName.isEmpty ? credential.userName : credential.userDisplayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text(credential.rpId)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                HStack(spacing: 8) {
                    Button("Export") {
                        Task {
                            await onExport()
                        }
                    }
                    .buttonStyle(.bordered)
                    .font(.caption)
                    
                    Button("Remove") {
                        showingRemoveAlert = true
                    }
                    .buttonStyle(.bordered)
                    .font(.caption)
                    .foregroundColor(.red)
                    
                    Button(action: {
                        withAnimation {
                            isExpanded.toggle()
                        }
                    }) {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            // Expandable details
            if isExpanded {
                VStack(alignment: .leading, spacing: 6) {
                    // Basic Info Section
                    RawDataSection(title: "Basic Information", color: .blue) {
                        RawDataField(label: "ID", value: credential.id)
                        RawDataField(label: "Username", value: credential.userName)
                        RawDataField(label: "Display Name", value: credential.userDisplayName.isEmpty ? "none" : credential.userDisplayName)
                        RawDataField(label: "RP ID", value: credential.rpId)
                        RawDataField(label: "User ID", value: credential.userId)
                        RawDataField(label: "Created", value: DateFormatter.localizedString(from: credential.createdAt, dateStyle: .medium, timeStyle: .short))
                    }
                    
                    // Public Key Section
                    RawDataSection(title: "Public Key Data", color: .green) {
                        RawDataField(label: "Size", value: "\(credential.publicKey.count) bytes")
                        RawDataField(label: "Hex Data", value: credential.publicKey.map { String(format: "%02x", $0) }.joined())
                        RawDataField(label: "Base64", value: credential.publicKey.base64EncodedString())
                    }
                    
                    // Private Key Data Section
                    RawDataSection(title: "Private Key Data", color: .red) {
                        if let privateKeyData = getPrivateKeyData() {
                            RawDataField(label: "Size", value: "\(privateKeyData.count) bytes")
                            RawDataField(label: "Hex Data", value: privateKeyData.map { String(format: "%02x", $0) }.joined())
                            RawDataField(label: "Base64", value: privateKeyData.base64EncodedString())
                        } else {
                            RawDataField(label: "Status", value: isLoadingPrivateKey ? "Loading..." : "Not Available")
                        }
                    }
                }
                .padding(.leading, 16)
                .padding(.top, 4)
                .padding(.bottom, 8)
                .background(Color(.controlBackgroundColor).opacity(0.5))
                .cornerRadius(6)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(Color(.textBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(.separatorColor), lineWidth: 1)
        )
        .alert("Remove Credential?", isPresented: $showingRemoveAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Remove", role: .destructive) {
                Task {
                    await onRemove()
                }
            }
        } message: {
            Text("Are you sure you want to remove '\(credential.userDisplayName.isEmpty ? credential.userName : credential.userDisplayName)' from this virtual key? This action cannot be undone.")
        }
        .onAppear {
            if isExpanded {
                loadPrivateKeyData()
            }
        }
        .onChange(of: isExpanded) { expanded in
            if expanded {
                loadPrivateKeyData()
            }
        }
    }
    
    // MARK: - Private Key Data Functions
    
    private func getPrivateKeyData() -> Data? {
        return privateKeyData
    }
    
    private func loadPrivateKeyData() {
        guard !isLoadingPrivateKey else { return }
        isLoadingPrivateKey = true
        
        Task {
            // Get the actual private key from the virtual key database
            do {
                // Mount the virtual key
                guard let mountPoint = try? await VirtualHardwareKeyManager.shared.mountDiskImage(
                    virtualKey.diskImagePath, 
                    password: virtualKey.isLocked ? nil : nil
                ) else {
                    await MainActor.run {
                        privateKeyData = nil
                        isLoadingPrivateKey = false
                    }
                    return
                }
                
                // Access the virtual key's UNIFIED database
                let unifiedDbPath = mountPoint.appendingPathComponent("WebAuthnClient.db")
                if FileManager.default.fileExists(atPath: unifiedDbPath.path) {
                    let config = StorageConfiguration(
                        databaseName: "WebAuthnClient", // UNIFIED DATABASE
                        customDatabasePath: unifiedDbPath.path
                    )
                    let virtualKeyStorage = try await StorageFactory.createStorageManager(configuration: config)
                    
                    // Get the raw credential data with private key
                    if let credData = try await virtualKeyStorage.fetchCredential(id: credential.id),
                       let privateKeyRef = credData.privateKeyRef,
                       let encryptedData = Data(base64Encoded: privateKeyRef) {
                        await MainActor.run {
                            privateKeyData = encryptedData
                            isLoadingPrivateKey = false
                        }
                    } else {
                        await MainActor.run {
                            privateKeyData = nil
                            isLoadingPrivateKey = false
                        }
                    }
                } else {
                    await MainActor.run {
                        privateKeyData = nil
                        isLoadingPrivateKey = false
                    }
                }
            } catch {
                await MainActor.run {
                    privateKeyData = nil
                    isLoadingPrivateKey = false
                }
            }
        }
    }
}

// MARK: - Virtual Server Credential Row

private struct VirtualServerCredentialRow: View {
    let credential: WebAuthnCredential
    let onRemove: () async -> Void
    
    @State private var isExpanded = false
    @State private var showingRemoveAlert = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header row with expand/collapse
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(credential.username)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text("Server Credential")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                HStack(spacing: 8) {
                    Button("Remove") {
                        showingRemoveAlert = true
                    }
                    .buttonStyle(.bordered)
                    .font(.caption)
                    .foregroundColor(.red)
                    
                    Button(action: {
                        withAnimation {
                            isExpanded.toggle()
                        }
                    }) {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            // Expandable details
            if isExpanded {
                VStack(alignment: .leading, spacing: 6) {
                    RawDataSection(title: "Basic Information", color: .green) {
                        RawDataField(label: "ID", value: credential.id)
                        RawDataField(label: "Username", value: credential.username)
                        RawDataField(label: "Algorithm", value: "\(credential.algorithm)")
                        RawDataField(label: "Sign Count", value: "\(credential.signCount)")
                        RawDataField(label: "Enabled", value: credential.isEnabled ? "Yes" : "No")
                        RawDataField(label: "Admin", value: credential.isAdmin ? "Yes" : "No")
                        RawDataField(label: "Emoji", value: credential.emoji?.isEmpty == false ? credential.emoji! : "none")
                    }
                }
                .padding(.leading, 16)
                .padding(.top, 4)
                .padding(.bottom, 8)
                .background(Color(.controlBackgroundColor).opacity(0.5))
                .cornerRadius(6)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(Color(.textBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(.separatorColor), lineWidth: 1)
        )
        .alert("Remove Server Credential?", isPresented: $showingRemoveAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Remove", role: .destructive) {
                Task {
                    await onRemove()
                }
            }
        } message: {
            Text("Are you sure you want to remove server credential '\(credential.username)' from this virtual key? This action cannot be undone.")
        }
    }
}

// MARK: - Create Virtual Key Sheet

private struct CreateVirtualKeySheet: View {
    @Binding var isPresented: Bool
    let onCreate: (VirtualKeyConfiguration) async -> Void
    
    @State private var name = ""
    @State private var sizeInMB = 50
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var usePassword = false
    @State private var isCreating = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Key Information")) {
                    TextField("Key Name", text: $name)
                    
                    Stepper("Size: \(sizeInMB) MB", value: $sizeInMB, in: 10...500, step: 10)
                }
                
                Section(header: Text("Security")) {
                    Toggle("Password Protection", isOn: $usePassword)
                    
                    if usePassword {
                        SecureField("Password", text: $password)
                        SecureField("Confirm Password", text: $confirmPassword)
                        
                        if !password.isEmpty && !confirmPassword.isEmpty && password != confirmPassword {
                            Text("Passwords do not match")
                                .foregroundColor(.red)
                                .font(.caption)
                        }
                    }
                }
            }
            .navigationTitle("Create Virtual Key")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                    .disabled(isCreating)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        Task {
                            await createKey()
                        }
                    }
                    .disabled(!canCreate || isCreating)
                }
            }
        }
    }
    
    private var canCreate: Bool {
        !name.isEmpty && (!usePassword || (password == confirmPassword && !password.isEmpty))
    }
    
    private func createKey() async {
        isCreating = true
        defer { isCreating = false }
        
        let config = VirtualKeyConfiguration(
            name: name,
            sizeInMB: sizeInMB,
            password: usePassword ? password : nil
        )
        
        await onCreate(config)
        isPresented = false
    }
}

// MARK: - Export From Virtual Key View

private struct ExportFromVirtualKeyView: View {
    let virtualKey: VirtualHardwareKey
    let onExport: (LocalCredential) -> Void
    
    @State private var credentials: [LocalCredential] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Export Credentials from \(virtualKey.name)")
                .font(.title2)
                .fontWeight(.semibold)
            
            if isLoading {
                ProgressView("Loading credentials...")
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else if let error = errorMessage {
                Text("Error: \(error)")
                    .foregroundColor(.red)
                    .padding()
            } else if credentials.isEmpty {
                Text("No credentials found in this virtual key")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(credentials, id: \.id) { credential in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(credential.userDisplayName.isEmpty ? credential.userName : credential.userDisplayName)
                                        .font(.headline)
                                    Text(credential.rpId)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Button("Export") {
                                    onExport(credential)
                                }
                                .buttonStyle(.borderedProminent)
                            }
                            .padding()
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(8)
                        }
                    }
                }
            }
        }
        .padding()
        .task {
            await loadCredentials()
        }
    }
    
    private func loadCredentials() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        do {
            let analysis = try await VirtualKeyDiagnostics.shared.analyzeVirtualKey(
                virtualKey,
                password: virtualKey.isLocked ? nil : nil
            )
            
            await MainActor.run {
                credentials = analysis.clientCredentials
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
        }
    }
}

// MARK: - Import Credentials View

private struct ImportCredentialsView: View {
    let virtualKey: VirtualHardwareKey
    let onImport: (UUID, String?, Bool) -> Void
    
    @State private var password = ""
    @State private var overwriteExisting = false
    @State private var isImporting = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Import Credentials to \(virtualKey.name)")
                .font(.title2)
                .fontWeight(.semibold)
            
            if virtualKey.isLocked {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Password Required")
                        .font(.headline)
                    SecureField("Enter password", text: $password)
                        .textFieldStyle(.roundedBorder)
                }
            }
            
            Toggle("Overwrite existing credentials", isOn: $overwriteExisting)
            
            Spacer()
            
            HStack {
                Spacer()
                
                Button("Import") {
                    isImporting = true
                    onImport(virtualKey.id, virtualKey.isLocked ? password : nil, overwriteExisting)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isImporting || (virtualKey.isLocked && password.isEmpty))
            }
        }
        .padding()
    }
}

// MARK: - Raw Data Components

struct RawDataSection<Content: View>: View {
    let title: String
    let color: Color
    let content: Content
    
    init(title: String, color: Color, @ViewBuilder content: () -> Content) {
        self.title = title
        self.color = color
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Rectangle()
                    .fill(color)
                    .frame(width: 3, height: 12)
                Text(title)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(color)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                content
            }
            .padding(.leading, 8)
        }
    }
}

struct RawDataField: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\(label):")
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .frame(minWidth: 80, alignment: .leading)
            
            Text(value)
                .font(.caption2)
                .foregroundColor(.primary)
                .textSelection(.enabled)
                .lineLimit(nil)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
} 
