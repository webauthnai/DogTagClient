import XCTest
@testable import DogTagClient
import SwiftData
import CryptoKit

final class VirtualHardwareKeyTests: XCTestCase {
    let manager = VirtualHardwareKeyManager.shared
    
    override func setUp() async throws {
        try await super.setUp()
        // Clean up any existing test virtual keys
        await cleanupTestKeys()
    }
    
    override func tearDown() async throws {
        // Clean up test virtual keys
        await cleanupTestKeys()
        try await super.tearDown()
    }
    
    func testCreateVirtualKey() async throws {
        let config = VirtualKeyConfiguration(
            name: "TestKey",
            sizeInMB: 10,
            password: nil
        )
        
        let virtualKey = try await manager.createVirtualKey(config: config)
        
        XCTAssertEqual(virtualKey.name, "TestKey")
        XCTAssertFalse(virtualKey.isLocked)
        XCTAssertEqual(virtualKey.credentialCount, 0)
        
        // Verify the disk image file was created
        XCTAssertTrue(FileManager.default.fileExists(atPath: virtualKey.diskImagePath.path))
        
        // Clean up
        try await manager.deleteVirtualKey(id: virtualKey.id)
    }
    
    func testCreatePasswordProtectedVirtualKey() async throws {
        let config = VirtualKeyConfiguration(
            name: "SecureTestKey",
            sizeInMB: 10,
            password: "testPassword123"
        )
        
        let virtualKey = try await manager.createVirtualKey(config: config)
        
        XCTAssertEqual(virtualKey.name, "SecureTestKey")
        // Note: isLocked would need to be determined by attempting to mount
        
        // Clean up
        try await manager.deleteVirtualKey(id: virtualKey.id)
    }
    
    func testListVirtualKeys() async throws {
        // Create a test virtual key
        let config = VirtualKeyConfiguration(name: "ListTestKey", sizeInMB: 10)
        let virtualKey = try await manager.createVirtualKey(config: config)
        
        // List virtual keys
        let keys = try await manager.listVirtualKeys()
        
        XCTAssertTrue(keys.contains { $0.name == "ListTestKey" })
        
        // Clean up
        try await manager.deleteVirtualKey(id: virtualKey.id)
    }
    
    func testDeleteVirtualKey() async throws {
        // Create a test virtual key
        let config = VirtualKeyConfiguration(name: "DeleteTestKey", sizeInMB: 10)
        let virtualKey = try await manager.createVirtualKey(config: config)
        
        // Verify it exists
        let keysBeforeDelete = try await manager.listVirtualKeys()
        XCTAssertTrue(keysBeforeDelete.contains { $0.name == "DeleteTestKey" })
        
        // Delete it
        try await manager.deleteVirtualKey(id: virtualKey.id)
        
        // Verify it's gone
        let keysAfterDelete = try await manager.listVirtualKeys()
        XCTAssertFalse(keysAfterDelete.contains { $0.name == "DeleteTestKey" })
        XCTAssertFalse(FileManager.default.fileExists(atPath: virtualKey.diskImagePath.path))
    }
    
    func testVirtualKeyConfiguration() {
        let config1 = VirtualKeyConfiguration(name: "Test1")
        XCTAssertEqual(config1.name, "Test1")
        XCTAssertEqual(config1.sizeInMB, 50) // Default size
        XCTAssertNil(config1.password)
        XCTAssertEqual(config1.fileSystemType, "HFS+")
        
        let config2 = VirtualKeyConfiguration(
            name: "Test2",
            sizeInMB: 100,
            password: "secret",
            fileSystemType: "APFS"
        )
        XCTAssertEqual(config2.name, "Test2")
        XCTAssertEqual(config2.sizeInMB, 100)
        XCTAssertEqual(config2.password, "secret")
        XCTAssertEqual(config2.fileSystemType, "APFS")
    }
    
    func testVirtualKeyModel() {
        let testURL = URL(fileURLWithPath: "/tmp/test.dmg")
        let testDate = Date()
        
        let virtualKey = VirtualHardwareKey(
            name: "TestModel",
            diskImagePath: testURL,
            createdAt: testDate,
            lastAccessedAt: testDate,
            isLocked: true,
            credentialCount: 5
        )
        
        XCTAssertEqual(virtualKey.name, "TestModel")
        XCTAssertEqual(virtualKey.diskImagePath, testURL)
        XCTAssertEqual(virtualKey.createdAt, testDate)
        XCTAssertEqual(virtualKey.lastAccessedAt, testDate)
        XCTAssertTrue(virtualKey.isLocked)
        XCTAssertEqual(virtualKey.credentialCount, 5)
    }
    
    func testVirtualKeyErrors() {
        // Test error descriptions
        let errors: [VirtualKeyError] = [
            .keyAlreadyExists("TestKey"),
            .keyNotFound,
            .diskImageCreationFailed("Test reason"),
            .mountFailed("Mount reason"),
            .unmountFailed("Unmount reason"),
            .databaseInitializationFailed("DB reason"),
            .exportFailed("Export reason"),
            .importFailed("Import reason")
        ]
        
        for error in errors {
            XCTAssertNotNil(error.errorDescription)
            XCTAssertFalse(error.errorDescription?.isEmpty ?? true)
        }
        
        // Test specific error messages
        XCTAssertEqual(
            VirtualKeyError.keyAlreadyExists("TestKey").errorDescription,
            "Virtual hardware key 'TestKey' already exists"
        )
        XCTAssertEqual(
            VirtualKeyError.keyNotFound.errorDescription,
            "Virtual hardware key not found"
        )
    }
    
    // Note: Export/Import tests would require actual credentials
    // and are more complex to set up in unit tests
    
    // MARK: - Helper Methods
    
    private func cleanupTestKeys() async {
        do {
            let keys = try await manager.listVirtualKeys()
            let testKeys = keys.filter { key in
                key.name.contains("Test") || key.name.hasPrefix("Test")
            }
            
            for testKey in testKeys {
                try? await manager.deleteVirtualKey(id: testKey.id)
            }
        } catch {
            print("Warning: Failed to cleanup test keys: \(error)")
        }
    }
}

// MARK: - Integration Tests

final class VirtualHardwareKeyIntegrationTests: XCTestCase {
    let manager = VirtualHardwareKeyManager.shared
    
    func testDiskImageMountingCycle() async throws {
        // This test requires actual disk operations and might be slow
        // Skip in CI environments or when running quick tests
        try XCTSkipUnless(ProcessInfo.processInfo.environment["RUN_INTEGRATION_TESTS"] == "true")
        
        let config = VirtualKeyConfiguration(
            name: "MountTestKey",
            sizeInMB: 10
        )
        
        let virtualKey = try await manager.createVirtualKey(config: config)
        
        // Test mounting
        let mountPoint = try await manager.mountDiskImage(virtualKey.diskImagePath)
        XCTAssertTrue(FileManager.default.fileExists(atPath: mountPoint.path))
        
        // Verify database files were created
        let clientDbPath = mountPoint.appendingPathComponent("VirtualKeyCredentials.db")
        let serverDbPath = mountPoint.appendingPathComponent("ServerCredentials.db")
        XCTAssertTrue(FileManager.default.fileExists(atPath: clientDbPath.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: serverDbPath.path))
        
        // Test unmounting
        try await manager.unmountDiskImage(mountPoint)
        
        // Clean up
        try await manager.deleteVirtualKey(id: virtualKey.id)
    }
}

// MARK: - Mock Tests

final class VirtualHardwareKeyMockTests: XCTestCase {
    // These tests would use mocked file operations for faster execution
    // and to test error conditions that are hard to reproduce
    
    func testMockFileOperations() {
        // Mock tests would go here for testing error conditions
        // without actually creating disk images
        XCTAssertTrue(true, "Mock tests placeholder")
    }
} 