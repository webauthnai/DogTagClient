import XCTest
@testable import DogTagClient

final class VirtualKeyManagerTests: XCTestCase {
    
    var manager: VirtualHardwareKeyManager!
    
    override func setUp() {
        super.setUp()
        manager = VirtualHardwareKeyManager.shared
    }
    
    override func tearDown() {
        super.tearDown()
        manager = nil
    }
    
    func testCreateAndDeleteVirtualKey() async throws {
        let keyName = "TestKey"
        
        let config = VirtualKeyConfiguration(
            name: keyName,
            sizeInMB: 10,
            password: nil,
            fileSystemType: "HFS+"
        )
        
        print("🧪 Testing virtual key creation with config: \(config)")
        
        // Create virtual key
        let virtualKey = try await manager.createVirtualKey(config: config)
        
        // Verify the key was created
        XCTAssertEqual(virtualKey.name, keyName)
        XCTAssertTrue(FileManager.default.fileExists(atPath: virtualKey.diskImagePath.path))
        
        // Test mounting
        let mountPoint = try await manager.mountDiskImage(virtualKey.diskImagePath)
        print("🧪 Mounted successfully at: \(mountPoint.path)")
        
        // Verify database files exist
        let clientDbPath = mountPoint.appendingPathComponent("VirtualKeyCredentials.db")
        let serverDbPath = mountPoint.appendingPathComponent("ServerCredentials.db")
        
        XCTAssertTrue(FileManager.default.fileExists(atPath: clientDbPath.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: serverDbPath.path))
        
        // Test unmounting
        try await manager.unmountDiskImage(mountPoint)
        print("🧪 Unmounted successfully")
        
        // Clean up - delete the virtual key
        try await manager.deleteVirtualKey(id: virtualKey.id)
        
        // Verify the key was deleted
        XCTAssertFalse(FileManager.default.fileExists(atPath: virtualKey.diskImagePath.path))
        
        print("✅ Test completed successfully")
    }
    
    func testCreateEncryptedVirtualKey() async throws {
        let keyName = "EncryptedTestKey"
        let password = "test123"
        
        let config = VirtualKeyConfiguration(
            name: keyName,
            sizeInMB: 10,
            password: password,
            fileSystemType: "HFS+"
        )
        
        print("🧪 Testing encrypted virtual key creation")
        
        // Create encrypted virtual key
        let virtualKey = try await manager.createVirtualKey(config: config)
        
        // Verify the key was created
        XCTAssertEqual(virtualKey.name, keyName)
        XCTAssertTrue(FileManager.default.fileExists(atPath: virtualKey.diskImagePath.path))
        
        // Test mounting with password
        let mountPoint = try await manager.mountDiskImage(virtualKey.diskImagePath, password: password)
        print("🧪 Encrypted key mounted successfully at: \(mountPoint.path)")
        
        // Test unmounting
        try await manager.unmountDiskImage(mountPoint)
        print("🧪 Encrypted key unmounted successfully")
        
        // Clean up
        try await manager.deleteVirtualKey(id: virtualKey.id)
        
        print("✅ Encrypted test completed successfully")
    }
} 