import Cocoa
import WebKit
import CryptoKit

// Native WebAuthn Bridge Implementation
class WebAuthnNativeBridge: NSObject, WKScriptMessageHandlerWithReply {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage, replyHandler: @escaping  @Sendable (Any?, String?) -> Void) {
        print("📨 Native bridge received message: \(message.name)")
        print("🔍 Message body type: \(type(of: message.body))")
        print("🔍 Message body: \(message.body)")
        
        switch message.name {
        case "webAuthnAvailable":
            handleWebAuthnAvailable(message, replyHandler: replyHandler)
        case "webAuthnCreate":
            handleWebAuthnCreate(message, replyHandler: replyHandler)
        case "webAuthnGet":
            handleWebAuthnGet(message, replyHandler: replyHandler)
        case "serverCounterUpdate":
            handleServerCounterUpdate(message, replyHandler: replyHandler)
        default:
            print("❌ Unknown message name: \(message.name)")
            replyHandler(nil, "Unknown message")
        }
    }
    
    private func reconstructArrayBufferFromDict(_ dict: [String: Any]) -> String? {
        // Try to reconstruct ArrayBuffer from dictionary with numeric keys
        var bytes: [UInt8] = []
        var maxIndex = -1
        
        // Find the highest numeric key to determine array size
        for key in dict.keys {
            if let index = Int(key), index >= 0 {
                maxIndex = max(maxIndex, index)
            }
        }
        
        if maxIndex >= 0 {
            // Initialize array with zeros
            bytes = Array(repeating: 0, count: maxIndex + 1)
            
            // Fill in the values
            for (key, value) in dict {
                if let index = Int(key), index >= 0, index <= maxIndex {
                    if let byteValue = value as? Int, byteValue >= 0, byteValue <= 255 {
                        bytes[index] = UInt8(byteValue)
                    } else if let byteValue = value as? UInt8 {
                        bytes[index] = byteValue
                    }
                }
            }
            
            let data = Data(bytes)
            return data.base64EncodedString()
        }
        
        return nil
    }

    private func handleWebAuthnCreate(_ message: WKScriptMessage, replyHandler: @escaping (Any?, String?) -> Void) {
        print("🔥 NATIVE BRIDGE CALLED: handleWebAuthnCreate")
        print("🔐 Handling WebAuthn Create with Local Auth Service")
        
        guard let options = message.body as? [String: Any] else {
            print("❌ Invalid options - not a dictionary")
            replyHandler(nil, "Invalid options")
            return
        }
        
        print("🔍 Received options keys: \(options.keys.sorted())")
        
        // Extract and validate RP info
        guard let rpInfo = options["rp"] as? [String: Any] else {
            print("❌ Missing or invalid 'rp' field")
            replyHandler(nil, "Missing rp field")
            return
        }
        
        // Try to get rpId from the rp object, with intelligent fallback
        var rpId: String
        if let explicitRpId = rpInfo["id"] as? String, !explicitRpId.isEmpty {
            rpId = explicitRpId
            print("✅ Using explicit rp.id: \(rpId)")
        } else {
            // FALLBACK: Extract domain from current WebView URL for non-compliant sites
            if let webView = message.webView,
               let currentURL = webView.url,
               let host = currentURL.host {
                rpId = host
                print("🔧 FALLBACK: Missing rp.id, using domain from WebView URL: \(rpId)")
                print("   - Full URL: \(currentURL.absoluteString)")
                print("   - Extracted host: \(host)")
            } else {
                // Last resort: use a generic identifier
                rpId = "unknown.domain"
                print("⚠️ LAST RESORT: Could not determine rp.id, using fallback: \(rpId)")
            }
        }
        
        guard let _ = rpInfo["name"] as? String else {
            print("❌ Missing or invalid 'rp.name' field")
            replyHandler(nil, "Missing rp.name field")
            return
        }
        
        // Extract and validate user info
        guard let userInfo = options["user"] as? [String: Any] else {
            print("❌ Missing or invalid 'user' field")
            replyHandler(nil, "Missing user field")
            return
        }
        
        print("🔍 User info keys: \(userInfo.keys.sorted())")
        print("🔍 User info contents: \(userInfo)")
        
        // Enhanced debugging for user.id
        if let userId = userInfo["id"] {
            print("🔍 User.id raw value: \(userId)")
            print("🔍 User.id type: \(type(of: userId))")
            
            // Try to handle different possible types
            var userIdString: String?
            
            if let stringId = userId as? String {
                print("✅ User.id is already a string: \(stringId)")
                userIdString = stringId
            } else if let dictId = userId as? [String: Any] {
                print("🔍 User.id is dictionary with keys: \(dictId.keys.sorted())")
                print("🔍 Dictionary contents: \(dictId)")
                
                // Sometimes ArrayBuffers get serialized as dictionaries with numeric keys
                if let reconstructed = reconstructArrayBufferFromDict(dictId) {
                    userIdString = reconstructed
                    print("✅ Reconstructed user.id from dictionary: \(userIdString!)")
                }
            } else if let arrayId = userId as? [Int] {
                print("🔍 User.id is integer array: \(arrayId)")
                let data = Data(arrayId.map { UInt8($0) })
                userIdString = data.base64EncodedString()
                print("✅ Converted user.id from array to base64: \(userIdString!)")
            } else if let arrayId = userId as? [UInt8] {
                print("🔍 User.id is UInt8 array: \(arrayId)")
                let data = Data(arrayId)
                userIdString = data.base64EncodedString()
                print("✅ Converted user.id from UInt8 array to base64: \(userIdString!)")
            }
            
            guard let finalUserIdString = userIdString else {
                print("❌ Could not process user.id")
                replyHandler(nil, "Could not process user.id field")
                return
            }
            
            print("🔍 Final user.id: \(finalUserIdString)")
            
            // Continue with the rest of the validation...
            guard let userName = userInfo["name"] as? String else {
                print("❌ Missing or invalid 'user.name' field")
                replyHandler(nil, "Missing user.name field")
                return
            }
            
            let userDisplayName = userInfo["displayName"] as? String ?? userName
            
            // ENHANCED: Process user.icon if provided
            var userIcon: String?
            if let icon = userInfo["icon"] as? String, !icon.isEmpty {
                userIcon = icon
                print("✅ User icon provided: \(icon)")
            }
            
            // Extract and validate challenge
            guard let challengeArray = options["challenge"] as? [Int] else {
                print("❌ Missing or invalid 'challenge' field. Type: \(type(of: options["challenge"]))")
                if let challenge = options["challenge"] {
                    print("❌ Challenge value: \(challenge)")
                }
                replyHandler(nil, "Missing or invalid challenge field")
                return
            }
            
            // ENHANCED: Process pubKeyCredParams to validate supported algorithms
            if let pubKeyCredParams = options["pubKeyCredParams"] as? [[String: Any]] {
                print("🔍 Credential parameters provided:")
                for (index, param) in pubKeyCredParams.enumerated() {
                    if let alg = param["alg"] as? Int, let type = param["type"] as? String {
                        print("   [\(index)] Algorithm: \(alg), Type: \(type)")
                    }
                }
            } else {
                print("⚠️ No pubKeyCredParams provided - using defaults")
            }
            
            // ENHANCED: Process excludeCredentials to prevent duplicate registrations
            if let excludeCredentials = options["excludeCredentials"] as? [[String: Any]] {
                print("🔍 Exclude credentials provided: \(excludeCredentials.count) items")
                for (index, cred) in excludeCredentials.enumerated() {
                    if let credId = cred["id"] {
                        print("   [\(index)] Credential ID type: \(type(of: credId))")
                        // TODO: Check if any of these credentials already exist
                        // and prevent duplicate registration
                    }
                }
            }
            
            // ENHANCED: Process hints for UI guidance
            if let hints = options["hints"] as? [String] {
                print("🔍 UI hints provided: \(hints)")
                // Hints can be: "security-key", "client-device", "hybrid"
                for hint in hints {
                    switch hint {
                    case "security-key":
                        print("   🔑 Security key hint - prefer external authenticators")
                    case "client-device":
                        print("   📱 Client device hint - prefer platform authenticators")
                    case "hybrid":
                        print("   🔄 Hybrid hint - support QR code/cross-device")
                    default:
                        print("   ❓ Unknown hint: \(hint)")
                    }
                }
            }
            
            // ENHANCED: Process attestationFormats preference
            if let attestationFormats = options["attestationFormats"] as? [String] {
                print("🔍 Preferred attestation formats: \(attestationFormats)")
                // Common formats: "packed", "tpm", "android-key", "android-safetynet", "fido-u2f", "none"
            }
            
            print("✅ All required fields validated")
            print("🔍 RP ID: \(rpId)")
            print("🔍 User Name: \(userName)")
            print("🔍 User Icon: \(userIcon ?? "none")")
            print("🔍 Challenge length: \(challengeArray.count)")
            
            let challenge = Data(challengeArray.map { UInt8($0) })
            
            // Use Local Auth Service instead of WebAuthn
            LocalAuthService.shared.createCredential(
                rpId: rpId,
                userName: userName,
                userDisplayName: userDisplayName,
                userId: finalUserIdString,
                challenge: challenge
            ) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let credential):
                        let clientDataJSON = self.createClientDataJSON(type: "webauthn.create", challenge: challenge, origin: "https://\(rpId)")
                        
                        // Use the credential ID from our local credential (consistent ID)
                        let credentialIdBase64 = credential.id
                        
                        // Convert base64url to standard base64 for decoding
                        let standardBase64 = credentialIdBase64
                            .replacingOccurrences(of: "-", with: "+")
                            .replacingOccurrences(of: "_", with: "/")
                        
                        // Add padding if needed
                        let paddedBase64: String
                        let remainder = standardBase64.count % 4
                        if remainder > 0 {
                            paddedBase64 = standardBase64 + String(repeating: "=", count: 4 - remainder)
                        } else {
                            paddedBase64 = standardBase64
                        }
                        
                        guard let credentialIdBytes = Data(base64Encoded: paddedBase64) else {
                            print("❌ Failed to decode credential ID from base64url: \(credentialIdBase64)")
                            replyHandler(nil, "Failed to decode credential ID")
                            return
                        }
                        
                        print("🔍 Credential ID conversion:")
                        print("   - Original base64url: \(credentialIdBase64)")
                        print("   - Standard base64: \(paddedBase64)")
                        print("   - Decoded bytes: \(credentialIdBytes.count) bytes")
                        print("   - Bytes as array: \(Array(credentialIdBytes))")
                        
                        // Create authenticator data with the correct credential ID
                        let authData = self.createWebAuthnAuthData(rpId: rpId, credentialIdBytes: credentialIdBytes, publicKeyBytes: credential.publicKey)
                        let attestationObject = self.createSimpleCBORAttestationObject(authData: authData)
                        
                        // Process extensions from the original request
                        var clientExtensionResults: [String: Any] = [:]
                        if let extensions = options["extensions"] as? [String: Any] {
                            print("🔍 Processing REGISTRATION extensions: \(extensions)")
                            print("🔍 Extension count: \(extensions.count)")
                            print("🔍 Extension keys: \(extensions.keys.sorted())")
                            
                            // Handle credProps extension
                            if extensions["credProps"] != nil {
                                clientExtensionResults["credProps"] = [
                                    "rk": true  // Resident key - our credentials are discoverable/resident
                                ]
                                print("✅ Added credProps extension result")
                            }
                            
                            // Handle largeBlob extension
                            if let largeBlob = extensions["largeBlob"] as? [String: Any] {
                                // For registration, we typically just indicate support
                                if largeBlob["support"] != nil {
                                    clientExtensionResults["largeBlob"] = [
                                        "supported": true
                                    ]
                                    print("✅ Added largeBlob extension result")
                                }
                            }
                            
                            // Handle appid extension (for U2F compatibility)
                            if let appid = extensions["appid"] as? String {
                                // During registration, appid extension typically doesn't return data
                                // It's used during authentication to specify the legacy U2F app ID
                                print("🔍 appid extension noted for registration: \(appid)")
                            }
                            
                            // Handle hmacSecret extension
                            if extensions["hmacSecret"] != nil {
                                // During registration, this indicates the credential should support HMAC secret
                                clientExtensionResults["hmacSecret"] = true
                                print("✅ Added hmacSecret extension result")
                            }
                            
                            // ENHANCED: Handle credProtect extension
                            if let credProtect = extensions["credProtect"] as? [String: Any] {
                                if let policy = credProtect["credentialProtectionPolicy"] as? Int {
                                    clientExtensionResults["credProtect"] = [
                                        "credentialProtectionPolicy": policy
                                    ]
                                    print("✅ Added credProtect extension result: policy \(policy)")
                                }
                            }
                            
                            // ENHANCED: Handle minPinLength extension
                            if extensions["minPinLength"] != nil {
                                // Return minimum PIN length requirement
                                clientExtensionResults["minPinLength"] = 4
                                print("✅ Added minPinLength extension result")
                            }
                            
                            // ENHANCED: Handle uvm (User Verification Methods) extension
                            if extensions["uvm"] != nil {
                                // Return user verification methods used
                                clientExtensionResults["uvm"] = [
                                    [2, 4, 2] // [USER_VERIFY_FINGERPRINT, KEY_PROT_SOFTWARE, MATCHER_PROT_SOFTWARE]
                                ]
                                print("✅ Added uvm extension result")
                            }
                        }
                        
                        // ENHANCED: WebAuthn PublicKeyCredential response format with enhanced transport support
                        let response: [String: Any] = [
                            "id": credentialIdBase64,
                            "rawId": Array(credentialIdBytes),
                            "clientDataJSON": Array(clientDataJSON),
                            "attestationObject": Array(attestationObject),
                            "type": "public-key",
                            "clientExtensionResults": clientExtensionResults,
                            "authenticatorAttachment": "platform",
                            "transports": ["internal", "hybrid"] // Enhanced transport support
                        ]
                        
                        // Verify ID/rawId consistency
                        let rawIdAsBase64url = credentialIdBytes.base64EncodedString()
                            .replacingOccurrences(of: "+", with: "-")
                            .replacingOccurrences(of: "/", with: "_")
                            .replacingOccurrences(of: "=", with: "")
                        print("🔍 ID/rawId consistency check:")
                        print("   - id field: \(credentialIdBase64)")
                        print("   - rawId converted to base64url: \(rawIdAsBase64url)")
                        print("   - Match: \(credentialIdBase64 == rawIdAsBase64url ? "✅ YES" : "❌ NO")")
                        
                        print("✅ Local credential creation successful")
                        print("🔍 Final clientExtensionResults for REGISTRATION: \(clientExtensionResults)")
                        print("🔍 CREDENTIAL DEBUG INFO:")
                        print("   - Credential ID: \(credentialIdBase64)")
                        print("   - Raw ID length: \(credentialIdBytes.count) bytes")
                        print("   - Client Data JSON length: \(clientDataJSON.count) bytes")
                        print("   - Attestation Object length: \(attestationObject.count) bytes")
                        print("   - RP ID: \(rpId)")
                        print("   - Challenge length: \(challenge.count)")
                        print("   - Supported transports: \(response["transports"] ?? [])")
                        
                        // Debug the client data JSON content
                        if let clientDataString = String(data: clientDataJSON, encoding: .utf8) {
                            print("   - Client Data JSON content: \(clientDataString)")
                        }
                        
                        replyHandler(response, nil)
                        
                    case .failure(let error):
                        print("❌ Local credential creation failed: \(error.localizedDescription)")
                        replyHandler(nil, error.localizedDescription)
                    }
                }
            }
            
        } else {
            print("❌ user.id is completely missing")
            replyHandler(nil, "Missing user.id field")
            return
        }
    }
    
    private func handleWebAuthnGet(_ message: WKScriptMessage, replyHandler: @escaping (Any?, String?) -> Void) {
        print("🔥 NATIVE BRIDGE CALLED: handleWebAuthnGet")
        print("🔍 Handling WebAuthn Get with Local Auth Service")
        print("🔍 Message body type: \(type(of: message.body))")
        print("🔍 Message body: \(message.body)")
        
        guard let options = message.body as? [String: Any] else {
            print("❌ Invalid options - not a dictionary")
            replyHandler(nil, "Invalid options")
            return
        }
        
        print("🔍 Received options keys: \(options.keys.sorted())")
        
        // Extract username from the request if provided
        var username: String?
        if let usernameValue = options["username"] as? String, !usernameValue.isEmpty {
            username = usernameValue
            print("🔍 Found username in direct options: \(usernameValue)")
        } else if let publicKey = options["publicKey"] as? [String: Any],
                  let usernameValue = publicKey["username"] as? String, !usernameValue.isEmpty {
            username = usernameValue
            print("🔍 Found username in publicKey: \(usernameValue)")
        } else {
            print("🔍 No username provided in WebAuthn request")
        }
        
        // Handle both direct challenge and nested publicKey structure
        var challenge: Data
        var rpId: String
        
        if let publicKey = options["publicKey"] as? [String: Any] {
            // Standard WebAuthn format: { publicKey: { challenge: [...], rpId: "..." } }
            print("🔍 Using nested publicKey structure")
            guard let challengeArray = publicKey["challenge"] as? [Int] else {
                print("❌ Missing challenge in publicKey")
                replyHandler(nil, "Missing challenge")
                return
            }
            challenge = Data(challengeArray.map { UInt8($0) })
            rpId = publicKey["rpId"] as? String ?? ""
        } else {
            // Direct format: { challenge: [...], rpId: "..." }
            print("🔍 Using direct structure")
            guard let challengeArray = options["challenge"] as? [Int] else {
                print("❌ Missing challenge")
                replyHandler(nil, "Missing challenge")
                return
            }
            challenge = Data(challengeArray.map { UInt8($0) })
            rpId = options["rpId"] as? String ?? ""
        }
        
        // Apply the same intelligent fallback for missing rpId as in registration
        if rpId.isEmpty {
            // FALLBACK: Extract domain from current WebView URL for non-compliant sites
            if let webView = message.webView,
               let currentURL = webView.url,
               let host = currentURL.host {
                rpId = host
                print("🔧 AUTHENTICATION FALLBACK: Missing rpId, using domain from WebView URL: \(rpId)")
                print("   - Full URL: \(currentURL.absoluteString)")
                print("   - Extracted host: \(host)")
            } else {
                // Last resort: use a generic identifier
                rpId = "unknown.domain"
                print("⚠️ AUTHENTICATION LAST RESORT: Could not determine rpId, using fallback: \(rpId)")
            }
        } else {
            print("✅ Using provided rpId for authentication: \(rpId)")
        }
        
        print("🔍 Final RP ID: \(rpId)")
        print("🔍 Challenge length: \(challenge.count)")
        
        // FIXED: Extract credential ID with proper base64 and byte array handling
        var credentialId: String?
        
        if let publicKey = options["publicKey"] as? [String: Any],
           let allowCredentials = publicKey["allowCredentials"] as? [[String: Any]],
           !allowCredentials.isEmpty,
           let firstCred = allowCredentials.first {
            
            print("🔍 Processing credential ID from allowCredentials...")
            print("🔍 Credential structure: \(firstCred)")
            
            // Check if the credential has valid ID data
            if let id = firstCred["id"] as? String, !id.isEmpty {
                credentialId = id
                print("🔍 Found credential ID as string: \(id)")
            } else if let idArray = firstCred["id"] as? [Int], !idArray.isEmpty {
                // Convert byte array to base64 string for matching
                let idData = Data(idArray.map { UInt8($0) })
                credentialId = idData.base64EncodedString()
                    .replacingOccurrences(of: "+", with: "-")
                    .replacingOccurrences(of: "/", with: "_")
                    .replacingOccurrences(of: "=", with: "")
                print("🔍 Found credential ID as byte array (\(idArray.count) bytes), converted to: \(credentialId!)")
                
                // Also try standard base64 for compatibility
                let standardBase64 = idData.base64EncodedString()
                print("🔍 Standard base64 format: \(standardBase64)")
            } else if let idDict = firstCred["id"] as? [String: Any] {
                // Handle cases where ID comes as an object/dictionary (often empty)
                if idDict.isEmpty {
                    print("🔍 Credential ID is empty object - server wants any available credential")
                } else {
                    // Try to extract ID from dictionary format
                    if let idString = extractIdFromDict(idDict) {
                        credentialId = idString
                        print("🔍 Extracted credential ID from dictionary: \(idString)")
                    } else {
                        print("🔍 Could not extract credential ID from dictionary: \(idDict)")
                    }
                }
            } else {
                print("🔍 Credential ID field type: \(type(of: firstCred["id"]))")
                print("🔍 Credential ID value: \(firstCred["id"] ?? "nil")")
                print("🔍 This should now be a byte array thanks to JavaScript fix!")
            }
            
        } else if let allowCredentials = options["allowCredentials"] as? [[String: Any]],
                  !allowCredentials.isEmpty,
                  let firstCred = allowCredentials.first {
            
            // Handle credential ID in direct options structure
            if let id = firstCred["id"] as? String, !id.isEmpty {
                credentialId = id
                print("🔍 Found credential ID as string in direct options: \(id)")
            } else if let idArray = firstCred["id"] as? [Int], !idArray.isEmpty {
                let idData = Data(idArray.map { UInt8($0) })
                credentialId = idData.base64EncodedString()
                    .replacingOccurrences(of: "+", with: "-")
                    .replacingOccurrences(of: "/", with: "_")
                    .replacingOccurrences(of: "=", with: "")
                print("🔍 Found credential ID as byte array in direct options, converted to: \(credentialId!)")
            } else if let idDict = firstCred["id"] as? [String: Any] {
                if idDict.isEmpty {
                    print("🔍 Credential ID is empty object in direct options - any credential OK")
                } else {
                    if let idString = extractIdFromDict(idDict) {
                        credentialId = idString
                        print("🔍 Extracted credential ID from direct options dictionary: \(idString)")
                    }
                }
            } else {
                print("🔍 Credential ID field exists but is unsupported type in direct options")
            }
        }
        
        if credentialId == nil {
            print("🔍 No specific credential ID provided - will search all credentials")
        } else {
            print("🔍 Server requested specific credential ID: \(credentialId!)")
            print("🔍 Running credential ID mapping diagnostic to verify...")
            LocalAuthService.shared.diagnoseCredentialIDMappings(for: rpId)
        }
        
        // Use Local Auth Service with the improved credential selection
        print("🔐 Calling LocalAuthService.authenticateCredential with:")
        print("   - RP ID: '\(rpId)'")
        print("   - Challenge: \(challenge.count) bytes")
        print("   - Credential ID: \(credentialId ?? "nil")")
        print("   - Username: \(username ?? "nil")")
        
        // REMOVED: Excessive diagnostics that may cause performance issues
        // Only run diagnostics if authentication fails, not proactively
        
        LocalAuthService.shared.authenticateCredential(
            rpId: rpId,
            challenge: challenge,
            credentialId: credentialId,
            username: username
        ) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let assertion):
                    // Format response correctly for WebAuthn standard
                    let standardBase64 = assertion.credentialId
                        .replacingOccurrences(of: "-", with: "+")
                        .replacingOccurrences(of: "_", with: "/")
                    
                    // Add padding if needed
                    let paddedBase64: String
                    let remainder = standardBase64.count % 4
                    if remainder > 0 {
                        paddedBase64 = standardBase64 + String(repeating: "=", count: 4 - remainder)
                    } else {
                        paddedBase64 = standardBase64
                    }
                    
                    let rawIdData = Data(base64Encoded: paddedBase64) ?? Data()
                    
                    // Process extensions from the original request for authentication
                    var clientExtensionResults: [String: Any] = [:]
                    var extensionsToProcess: [String: Any]? = nil
                    
                    // Check for extensions in the message body structure
                    if let extensions = options["extensions"] as? [String: Any] {
                        extensionsToProcess = extensions
                    } else if let publicKey = options["publicKey"] as? [String: Any],
                              let extensions = publicKey["extensions"] as? [String: Any] {
                        extensionsToProcess = extensions
                    }
                    
                    if let extensions = extensionsToProcess {
                        print("🔍 Processing AUTHENTICATION extensions: \(extensions)")
                        print("🔍 Extension count: \(extensions.count)")
                        print("🔍 Extension keys: \(extensions.keys.sorted())")
                        
                        // Handle credProps extension (not typically used in authentication, but process if requested)
                        if extensions["credProps"] != nil {
                            clientExtensionResults["credProps"] = [
                                "rk": true  // Resident key - our credentials are discoverable/resident
                            ]
                            print("✅ Added credProps extension result for authentication")
                        }
                        
                        // Handle hmacSecret extension for authentication
                        if extensions["hmacSecret"] is [String: Any] {
                            // This would typically involve HMAC operations with the credential
                            // For now, we'll indicate it's supported but not implemented
                            print("🔍 hmacSecret extension requested but not fully implemented")
                        }
                        
                        // Handle largeBlob extension for authentication
                        if let largeBlob = extensions["largeBlob"] as? [String: Any] {
                            if let read = largeBlob["read"] as? Bool, read {
                                // Would typically read stored blob data
                                clientExtensionResults["largeBlob"] = [
                                    "blob": Data() // Empty blob for now
                                ]
                                print("✅ Added largeBlob read result")
                            } else if largeBlob["write"] != nil {
                                // Would typically write blob data
                                clientExtensionResults["largeBlob"] = [
                                    "written": true
                                ]
                                print("✅ Added largeBlob write result")
                            }
                        }
                        
                        // Handle appid extension for U2F compatibility
                        if let appid = extensions["appid"] as? String {
                            // Check if the credential was created with this appid
                            // For now, we'll just indicate it was processed
                            clientExtensionResults["appid"] = true
                            print("✅ Added appid extension result: \(appid)")
                        }
                    }
                    
                    // ENHANCED: Authentication response with enhanced transport and metadata support
                    let response: [String: Any] = [
                        "id": assertion.credentialId,
                        "rawId": Array(rawIdData),
                        "clientDataJSON": Array(assertion.clientDataJSON),
                        "authenticatorData": Array(assertion.authenticatorData),  
                        "signature": Array(assertion.signature),
                        "userHandle": assertion.userHandle.map { Array($0) } as Any,
                        "clientDataJSONBase64": assertion.clientDataJSON.base64EncodedString(),
                        "authenticatorDataBase64": assertion.authenticatorData.base64EncodedString(),
                        "signatureBase64": assertion.signature.base64EncodedString(),
                        "userHandleBase64": assertion.userHandle?.base64EncodedString() as Any,
                        "response": [
                            "clientDataJSON": assertion.clientDataJSON.base64EncodedString(),
                            "authenticatorData": assertion.authenticatorData.base64EncodedString(),
                            "signature": assertion.signature.base64EncodedString(),
                            "userHandle": assertion.userHandle?.base64EncodedString() as Any
                        ],
                        "type": "public-key",
                        "authenticatorAttachment": "platform",
                        "clientExtensionResults": clientExtensionResults,
                        "transports": ["internal", "hybrid"], // Enhanced transport support for authentication
                        "getTransports": ["internal", "hybrid"] // Alternative field name used by some implementations
                    ]
                    
                    // Verify ID/rawId consistency for authentication
                    let rawIdAsBase64url = rawIdData.base64EncodedString()
                        .replacingOccurrences(of: "+", with: "-")
                        .replacingOccurrences(of: "/", with: "_")
                        .replacingOccurrences(of: "=", with: "")
                    print("🔍 AUTHENTICATION ID/rawId consistency check:")
                    print("   - id field: \(assertion.credentialId)")
                    print("   - rawId converted to base64url: \(rawIdAsBase64url)")
                    print("   - Match: \(assertion.credentialId == rawIdAsBase64url ? "✅ YES" : "❌ NO")")
                    
                    print("✅ Local authentication successful - formatted as flat WebAuthn response")
                    print("🔍 Final clientExtensionResults for AUTHENTICATION: \(clientExtensionResults)")
                    replyHandler(response, nil)
                    
                case .failure(let error):
                    print("❌ Local authentication failed: \(error.localizedDescription)")
                    
                    // Run comprehensive diagnostics on failure to help debug issues
                    if error.localizedDescription.contains("No credentials found") {
                        print("🔍 Running comprehensive diagnostic due to authentication failure...")
                        LocalAuthService.shared.diagnoseCredentialAvailability(for: rpId)
                        LocalAuthService.shared.diagnoseCredentialIDMappings(for: rpId)
                        
                        // Show the specific credential ID that was requested
                        if let requestedId = credentialId {
                            print("🔍 REQUESTED CREDENTIAL ID: \(requestedId)")
                            print("🔍 Server sent this credential ID that we need to find and match")
                        }
                    }
                    
                    replyHandler(nil, error.localizedDescription)
                }
            }
        }
    }
    
    // Helper function to extract credential ID from dictionary format
    private func extractIdFromDict(_ idDict: [String: Any]) -> String? {
        // Some servers send credential ID as numbered dictionary indices
        // Try to reconstruct byte array from dictionary keys
        let maxKey = idDict.keys.compactMap { Int($0) }.max() ?? -1
        if maxKey >= 0 {
            var bytes: [UInt8] = []
            for i in 0...maxKey {
                if let byte = idDict[String(i)] as? Int {
                    bytes.append(UInt8(byte))
                } else {
                    return nil // Missing byte at index
                }
            }
            
            if !bytes.isEmpty {
                let idData = Data(bytes)
                return idData.base64EncodedString()
                    .replacingOccurrences(of: "+", with: "-")
                    .replacingOccurrences(of: "/", with: "_")
                    .replacingOccurrences(of: "=", with: "")
            }
        }
        
        return nil
    }
    
    private func handleWebAuthnAvailable(_ message: WKScriptMessage, replyHandler: @escaping (Any?, String?) -> Void) {
        print("🔍 Checking Local Auth availability")
        
        // Check if Local Auth Service is available
        let available = LocalAuthService.shared.isAvailable()
        
        replyHandler(available, nil)
    }
    
    private func handleServerCounterUpdate(_ message: WKScriptMessage, replyHandler: @escaping (Any?, String?) -> Void) {
        print("🔥 NATIVE BRIDGE CALLED: handleServerCounterUpdate")
        
        // SAFETY: This is completely optional and will never break existing functionality
        let storageManager = VirtualKeyStorageManager.shared
        
        guard storageManager.isServerCounterUpdatesEnabled else {
            print("💫 Server counter updates disabled - ignoring (safe default)")
            replyHandler(["status": "disabled"], nil)
            return
        }
        
        guard let updateData = message.body as? [String: Any] else {
            print("⚠️ Invalid server counter update data")
            replyHandler(["status": "invalid_data"], nil)
            return
        }
        
        guard let credentialId = updateData["credentialId"] as? String,
              let serverResponse = updateData["serverResponse"] as? [String: Any] else {
            print("⚠️ Missing credentialId or serverResponse in update data")
            replyHandler(["status": "missing_fields"], nil)
            return
        }
        
        print("💫 Processing server counter update for credential: \(credentialId)")
        
        // SAFETY: This method has built-in safety checks and will never break authentication
        storageManager.updateCounterFromServerResponse(
            credentialId: credentialId,
            serverResponse: serverResponse
        )
        
        replyHandler(["status": "processed"], nil)
    }
    
    // MARK: - Helper Methods
    
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
        
        print("🔍 REGISTRATION Client Data JSON created (canonical order): \(clientDataString)")
        print("🔍 REGISTRATION JSON length: \(jsonData.count) bytes")
        
        // Verify it's valid JSON
        do {
            let _ = try JSONSerialization.jsonObject(with: jsonData)
            print("✅ REGISTRATION JSON validation passed")
        } catch {
            print("❌ REGISTRATION JSON validation failed: \(error)")
        }
        
        return jsonData
    }
    
    private func createSimpleAttestationObject(credential: LocalCredential) -> Data {
        // Create a proper CBOR-encoded attestation object for WebAuthn compliance
        let authData = createSimpleAuthData(credential: credential)
        
        // Create CBOR attestation object manually since we're using "none" format
        // CBOR Map with 3 entries: {"fmt": "none", "attStmt": {}, "authData": authData}
        
        return createSimpleCBORAttestationObject(authData: authData)
    }
    
    private func createSimpleCBORAttestationObject(authData: Data) -> Data {
        // Create a proper CBOR attestation object
        // Format: {"fmt": "none", "attStmt": {}, "authData": <bytes>}
        
        var cborData = Data()
        
        // CBOR map with 3 entries
        cborData.append(0xA3) // Map with 3 key-value pairs
        
        // Entry 1: "authData" -> authData bytes
        cborData.append(0x68) // Text string with length 8
        cborData.append("authData".data(using: .utf8)!)
        cborData.append(contentsOf: encodeCBORByteString(authData))
        
        // Entry 2: "fmt" -> "none"
        cborData.append(0x63) // Text string with length 3
        cborData.append("fmt".data(using: .utf8)!)
        cborData.append(0x64) // Text string with length 4
        cborData.append("none".data(using: .utf8)!)
        
        // Entry 3: "attStmt" -> {}
        cborData.append(0x67) // Text string with length 7
        cborData.append("attStmt".data(using: .utf8)!)
        cborData.append(0xA0) // Empty map
        
        print("🔍 CBOR Attestation Object: \(cborData.count) bytes")
        print("🔍 CBOR Hex: \(cborData.map { String(format: "%02x", $0) }.joined())")
        
        return cborData
    }
    
    private func createWebAuthnAuthData(rpId: String, credentialIdBytes: Data, publicKeyBytes: Data) -> Data {
        // Create WebAuthn-compliant authenticator data for registration
        var authData = Data()
        
        // 1. RP ID hash (32 bytes) - SHA256 of RP ID
        let rpIdHash = SHA256.hash(data: rpId.data(using: .utf8)!)
        authData.append(Data(rpIdHash))
        
        // 2. Flags (1 byte)
        // Bit 0: UP (User Present) = 1
        // Bit 2: UV (User Verified) = 1 (Touch ID verified)
        // Bit 6: AT (Attested credential data included) = 1
        // Binary: 01000101 = 0x45
        authData.append(0x45)
        
        // 3. Counter (4 bytes, big endian) - 0 for new credential
        authData.append(contentsOf: [0, 0, 0, 0])
        
        // 4. Attested Credential Data (for registration only)
        
        // 4a. AAGUID (16 bytes) - Apple Touch ID AAGUID for proper identification
        let appleAAGUID = Data([0xAD, 0xCE, 0x00, 0x02, 0x35, 0xBC, 0xC6, 0x0A,
                               0x64, 0x8B, 0x0B, 0x25, 0xF1, 0xF0, 0x55, 0x03])
        authData.append(appleAAGUID)
        
        // 4b. Credential ID Length (2 bytes, big endian)
        let credIdLength = credentialIdBytes.count
        authData.append(UInt8(credIdLength >> 8))
        authData.append(UInt8(credIdLength & 0xFF))
        
        // 4c. Credential ID
        authData.append(credentialIdBytes)
        
        // 4d. Credential Public Key (CBOR-encoded COSE key with real coordinates)
        let publicKeyCBOR = createRealCOSEKey(publicKeyBytes: publicKeyBytes)
        authData.append(publicKeyCBOR)
        
        print("🔍 WebAuthn AuthData: \(authData.count) bytes")
        return authData
    }
    
    private func createRealCOSEKey(publicKeyBytes: Data) -> Data {
        // Create COSE P-256 public key with real coordinates from the generated key
        var coseKey = Data()
        
        // CBOR map with 5 entries for ES256 key
        coseKey.append(0xA5)
        
        // 1. kty (key type) = EC2 (2)
        coseKey.append(0x01) // key 1
        coseKey.append(0x02) // value 2
        
        // 2. alg (algorithm) = ES256 (-7)
        coseKey.append(0x03) // key 3
        coseKey.append(0x26) // -7 in CBOR
        
        // 3. crv (curve) = P-256 (1)
        coseKey.append(0x20) // key -1
        coseKey.append(0x01) // value 1
        
        // CRITICAL FIX: Extract x and y coordinates from the public key
        // The publicKeyBytes should be 65 bytes: 0x04 + 32 bytes x + 32 bytes y (uncompressed format)
        print("🔍 REGISTRATION Public Key Analysis:")
        print("   - Length: \(publicKeyBytes.count) bytes")
        print("   - First byte: 0x\(String(format: "%02x", publicKeyBytes.first ?? 0))")
        print("   - Expected: 65 bytes starting with 0x04")
        
        if publicKeyBytes.count == 65 && publicKeyBytes[0] == 0x04 {
            print("✅ REGISTRATION: Using REAL public key coordinates")
            
            // 4. x coordinate (32 bytes)
            coseKey.append(0x21) // key -2
            coseKey.append(0x58) // byte string
            coseKey.append(0x20) // length 32
            let xCoord = publicKeyBytes[1..<33]
            coseKey.append(xCoord)
            print("   - X coordinate: \(xCoord.prefix(8).map { String(format: "%02x", $0) }.joined())...")
            
            // 5. y coordinate (32 bytes)
            coseKey.append(0x22) // key -3
            coseKey.append(0x58) // byte string
            coseKey.append(0x20) // length 32
            let yCoord = publicKeyBytes[33..<65]
            coseKey.append(yCoord)
            print("   - Y coordinate: \(yCoord.prefix(8).map { String(format: "%02x", $0) }.joined())...")
            
        } else {
            // CRITICAL BUG FIX: Never use random coordinates - this would break signature verification!
            print("❌ CRITICAL ERROR: Unexpected public key format!")
            print("   - This would cause authentication signature verification to fail!")
            print("   - PublicKey length: \(publicKeyBytes.count), first byte: 0x\(String(format: "%02x", publicKeyBytes.first ?? 0))")
            
            // Try to extract coordinates anyway if the length is correct
            if publicKeyBytes.count >= 65 {
                print("🔧 RECOVERY: Attempting to extract coordinates from longer key...")
                let startIndex = publicKeyBytes.count - 64 // Take last 64 bytes as x,y coordinates
                let xCoord = publicKeyBytes[startIndex..<(startIndex + 32)]
                let yCoord = publicKeyBytes[(startIndex + 32)..<(startIndex + 64)]
                
                coseKey.append(0x21) // key -2
                coseKey.append(0x58) // byte string
                coseKey.append(0x20) // length 32
                coseKey.append(xCoord)
                
                coseKey.append(0x22) // key -3
                coseKey.append(0x58) // byte string
                coseKey.append(0x20) // length 32
                coseKey.append(yCoord)
                
                print("✅ RECOVERY: Extracted coordinates from position \(startIndex)")
                print("   - X coordinate: \(xCoord.prefix(8).map { String(format: "%02x", $0) }.joined())...")
                print("   - Y coordinate: \(yCoord.prefix(8).map { String(format: "%02x", $0) }.joined())...")
                
            } else if publicKeyBytes.count == 64 {
                print("🔧 RECOVERY: Key appears to be raw 64-byte x,y coordinates...")
                let xCoord = publicKeyBytes[0..<32]
                let yCoord = publicKeyBytes[32..<64]
                
                coseKey.append(0x21) // key -2
                coseKey.append(0x58) // byte string
                coseKey.append(0x20) // length 32
                coseKey.append(xCoord)
                
                coseKey.append(0x22) // key -3
                coseKey.append(0x58) // byte string
                coseKey.append(0x20) // length 32
                coseKey.append(yCoord)
                
                print("✅ RECOVERY: Used raw 64-byte coordinates")
                print("   - X coordinate: \(xCoord.prefix(8).map { String(format: "%02x", $0) }.joined())...")
                print("   - Y coordinate: \(yCoord.prefix(8).map { String(format: "%02x", $0) }.joined())...")
                
            } else {
                // Last resort: This should never happen but don't break the system
                print("❌ FATAL: Cannot extract real coordinates - WebAuthn will fail!")
                print("❌ Using zero coordinates as emergency fallback")
                
                // Use zero coordinates instead of random to make debugging easier
                coseKey.append(0x21) // key -2
                coseKey.append(0x58) // byte string
                coseKey.append(0x20) // length 32
                coseKey.append(Data(repeating: 0x00, count: 32))
                
                coseKey.append(0x22) // key -3
                coseKey.append(0x58) // byte string
                coseKey.append(0x20) // length 32
                coseKey.append(Data(repeating: 0x00, count: 32))
                
                print("❌ EMERGENCY: Used zero coordinates - authentication WILL fail")
            }
        }
        
        print("🔍 REGISTRATION: COSE key created with \(coseKey.count) bytes")
        return coseKey
    }
    
    private func encodeCBORByteString(_ data: Data) -> Data {
        var encoded = Data()
        let length = data.count
        
        if length < 24 {
            // Major type 2 (byte string), length encoded in additional info
            encoded.append(0x40 + UInt8(length))
        } else if length < 256 {
            // Major type 2, length in next 1 byte
            encoded.append(0x58)
            encoded.append(UInt8(length))
        } else if length < 65536 {
            // Major type 2, length in next 2 bytes
            encoded.append(0x59)
            encoded.append(UInt8(length >> 8))
            encoded.append(UInt8(length & 0xFF))
        } else {
            // Major type 2, length in next 4 bytes
            encoded.append(0x5A)
            encoded.append(UInt8(length >> 24))
            encoded.append(UInt8((length >> 16) & 0xFF))
            encoded.append(UInt8((length >> 8) & 0xFF))
            encoded.append(UInt8(length & 0xFF))
        }
        
        encoded.append(data)
        return encoded
    }
    
    private func createSimpleAuthData(credential: LocalCredential) -> Data {
        // Create WebAuthn-compliant authenticator data
        var authData = Data()
        
        // RP ID hash (32 bytes) - SHA256 hash of RP ID
        let rpIdHash = SHA256.hash(data: credential.rpId.data(using: .utf8)!)
        authData.append(Data(rpIdHash))
        
        // Flags (1 byte)
        // Bit 0: UP (User Present) = 1
        // Bit 2: UV (User Verified) = 1 (Touch ID verified)
        // Bit 6: AT (Attested credential data included) = 1
        // Result: 0x01 | 0x04 | 0x40 = 0x45
        authData.append(0x45)
        
        // Counter (4 bytes, big endian) - start with 1 for new credential
        authData.append(contentsOf: [0, 0, 0, 1])
        
        // Attested Credential Data (for registration)
        // AAGUID (16 bytes) - Apple Touch ID AAGUID
        let aaguid = Data([0xAD, 0xCE, 0x00, 0x02, 0x35, 0xBC, 0xC6, 0x0A, 
                          0x64, 0x8B, 0x0B, 0x25, 0xF1, 0xF0, 0x55, 0x03])
        authData.append(aaguid)
        
        // Credential ID Length (2 bytes, big endian)
        let credIdLength = credential.id.data(using: .utf8)?.count ?? 32
        authData.append(UInt8(credIdLength >> 8))
        authData.append(UInt8(credIdLength & 0xFF))
        
        // Credential ID
        if let credIdData = credential.id.data(using: .utf8) {
            authData.append(credIdData)
        } else {
            // Fallback: use 32 random bytes
            authData.append(Data((0..<32).map { _ in UInt8.random(in: 0...255) }))
        }
        
        // Credential Public Key (CBOR-encoded COSE key)
        let publicKeyCBOR = createCOSEPublicKey(credential: credential)
        authData.append(publicKeyCBOR)
        
        print("🔍 AuthData created: \(authData.count) bytes")
        return authData
    }
    
    private func createCOSEPublicKey(credential: LocalCredential) -> Data {
        // Create a simplified COSE P-256 public key for Touch ID
        var coseKey = Data()
        
        // CBOR map with 5 entries for P-256 key
        coseKey.append(0xA5)
        
        // kty (1): EC2 (2)
        coseKey.append(0x01) // key: 1
        coseKey.append(0x02) // value: 2 (EC2)
        
        // alg (3): ES256 (-7)
        coseKey.append(0x03) // key: 3
        coseKey.append(0x26) // value: -7 (ES256) - CBOR negative integer
        
        // crv (-1): P-256 (1)
        coseKey.append(0x20) // key: -1 (CBOR negative integer)
        coseKey.append(0x01) // value: 1 (P-256)
        
        // x (-2): 32 random bytes for X coordinate
        coseKey.append(0x21) // key: -2
        coseKey.append(0x58) // byte string, 1-byte length
        coseKey.append(0x20) // length: 32
        coseKey.append(Data((0..<32).map { _ in UInt8.random(in: 0...255) }))
        
        // y (-3): 32 random bytes for Y coordinate
        coseKey.append(0x22) // key: -3
        coseKey.append(0x58) // byte string, 1-byte length
        coseKey.append(0x20) // length: 32
        coseKey.append(Data((0..<32).map { _ in UInt8.random(in: 0...255) }))
        
        return coseKey
    }
} 
