# Virtual Hardware Keys for DogTagClient

## Overview

Virtual Hardware Keys enhance the DogTagClient system by providing portable credential storage using encrypted disk images. This feature allows you to:

- Create portable "hardware keys" stored as disk images (.dmg files)
- Transfer credentials between devices and systems
- Use the same SwiftData database format as the main DogTagClient system
- Optionally encrypt virtual keys with AES-256 password protection

## Features

### ✅ What's Implemented

- **Disk Image Creation**: Creates encrypted DMG files using macOS `hdiutil`
- **Database Compatibility**: Uses the same SwiftData models (`WebAuthnCredentialModel` and `WebAuthnClientCredential`)
- **Credential Export/Import**: Transfer credentials to/from virtual keys
- **Password Protection**: Optional AES-256 encryption for virtual keys
- **SwiftUI Interface**: Integrated tabbed interface in DogTagManager
- **Automatic Mounting**: Virtual keys are automatically mounted/unmounted as needed

### 🎯 Core Components

1. **VirtualHardwareKeyManager**: Main manager class handling disk operations
2. **VirtualHardwareKeyView**: SwiftUI interface for managing virtual keys
3. **Database Integration**: Uses existing WebAuthnManager and WebAuthnClientCredentialStore

## How to Use

### Creating a Virtual Hardware Key

1. Open DogTagManager and switch to the "Virtual Keys" tab
2. Click "Create New Key"
3. Enter a name for your virtual key
4. Choose the size (10-500 MB)
5. Optionally set a password for encryption
6. Click "Create"

The system will:
- Create an encrypted disk image at `~/Library/Application Support/WebMan/VirtualKeys/`
- Initialize empty SwiftData databases inside the virtual key
- Mount and unmount the disk image automatically

### Exporting Credentials

1. Select a virtual key from the list
2. Click the menu (⋯) and choose "Export Credentials"
3. Select which credentials to export
4. Enter the password if the virtual key is encrypted
5. Click "Export"

### Importing Credentials

1. Select a virtual key from the list
2. Click the menu (⋯) and choose "Import Credentials"
3. Choose whether to overwrite existing credentials
4. Enter the password if the virtual key is encrypted
5. Click "Import"

## Technical Details

### File Structure

```
~/Library/Application Support/WebMan/VirtualKeys/
├── MyVirtualKey.dmg                 # Encrypted disk image
├── AnotherKey.dmg
└── ...

# Inside each mounted virtual key:
/Volumes/VirtualKeyName/
├── VirtualKeyCredentials.db         # Client credentials (with private keys)
├── VirtualKeyCredentials.db-shm     # SQLite shared memory
├── VirtualKeyCredentials.db-wal     # SQLite write-ahead log
├── ServerCredentials.db             # Server-side credentials
├── ServerCredentials.db-shm
└── ServerCredentials.db-wal
```

### Database Schema

Virtual keys use the exact same SwiftData models as the main system:

- **WebAuthnClientCredential**: Client-side credentials with encrypted private keys
- **WebAuthnCredentialModel**: Server-side credential metadata

### Security Features

- **AES-256 Encryption**: Optional password-based encryption for disk images
- **Private Key Protection**: Private keys are encrypted before storage
- **Automatic Unmounting**: Virtual keys are unmounted when not in use
- **Secure Password Handling**: Passwords are passed to `hdiutil` via stdin

### Platform Requirements

- **macOS 14+**: Required for SwiftData support
- **System Tools**: Uses macOS built-in `hdiutil` for disk image operations
- **File System**: Creates HFS+ formatted disk images by default

## Code Integration

### Using VirtualHardwareKeyManager

```swift
// Create a new virtual key
let config = VirtualKeyConfiguration(
    name: "MyPortableKey",
    sizeInMB: 50,
    password: "securePassword"
)

let virtualKey = try await VirtualHardwareKeyManager.shared.createVirtualKey(config: config)

// Export credentials
let exportedCount = try await VirtualHardwareKeyManager.shared.exportCredentialsToVirtualKey(
    keyId: virtualKey.id,
    credentialIds: ["credential1", "credential2"],
    password: "securePassword"
)

// Import credentials
let importedCount = try await VirtualHardwareKeyManager.shared.importCredentialsFromVirtualKey(
    keyId: virtualKey.id,
    password: "securePassword",
    overwriteExisting: false
)
```

### Adding to SwiftUI

```swift
import SwiftUI

struct MyView: View {
    var body: some View {
        TabView {
            // Your existing content
            
            VirtualHardwareKeyView()
                .tabItem {
                    Label("Virtual Keys", systemImage: "externaldrive.badge.plus")
                }
        }
    }
}
```

## Error Handling

The system includes comprehensive error handling for:

- **Disk Image Creation Failures**: Invalid paths, insufficient disk space
- **Mount/Unmount Errors**: Permission issues, conflicting mounts
- **Database Errors**: Schema incompatibilities, corruption
- **Export/Import Failures**: Missing credentials, access denied

## Limitations

- **macOS Only**: Uses macOS-specific `hdiutil` command
- **Single Platform**: Disk images are macOS-specific format
- **Manual Transfer**: Users must manually copy .dmg files between systems
- **Password Recovery**: No password recovery mechanism for encrypted virtual keys

## Future Enhancements

Potential improvements for future versions:

- **Cross-Platform Support**: Use portable disk image formats
- **Cloud Sync**: Automatic synchronization with cloud storage
- **Backup/Restore**: Automated backup scheduling
- **Compression**: Better compression for smaller virtual keys
- **QR Code Export**: Export virtual keys as QR codes for easy transfer

## Troubleshooting

### Virtual Key Won't Mount
- Check if the .dmg file exists and isn't corrupted
- Ensure you have the correct password for encrypted keys
- Try manually mounting with Disk Utility

### Export/Import Fails
- Verify the virtual key has sufficient space
- Check database permissions
- Ensure credentials exist and are accessible

### Performance Issues
- Larger virtual keys (>100MB) may be slower to mount
- Consider using smaller keys for better performance
- Check available disk space

## Development Notes

The Virtual Hardware Key system is designed to enhance, not replace, the existing DogTagClient functionality. It maintains full backward compatibility with existing credential storage while adding portable export/import capabilities.

All virtual key operations are implemented as `async` functions to prevent UI blocking during disk operations and database access. 