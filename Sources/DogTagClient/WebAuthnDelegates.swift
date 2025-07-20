import Cocoa
import AuthenticationServices

// Delegate for WebAuthn Create (Registration)
class WebAuthnCreateDelegate: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    let replyHandler: (Any?, String?) -> Void
    
    init(replyHandler: @escaping (Any?, String?) -> Void) {
        self.replyHandler = replyHandler
    }
    
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        if let keyWindow = NSApp.keyWindow {
            return keyWindow
        }
        
        // Get the main app window
//        if let appDelegate = NSApp.delegate as? AppDelegate {
//            return appDelegate.window
//        }
        
        // Fallback to any available window
        return NSApp.windows.first ?? NSWindow()
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        print("✅ WebAuthn Create authorization completed")
        
        if let credential = authorization.credential as? ASAuthorizationPlatformPublicKeyCredentialRegistration {
            let credentialId = credential.credentialID.base64EncodedString()
            
            // Use the raw client data from the credential
            let clientDataJSON = credential.rawClientDataJSON
            
            let result: [String: Any] = [
                "id": credentialId,
                "rawId": Array(credential.credentialID),
                "clientDataJSON": Array(clientDataJSON),
                "attestationObject": Array(credential.rawAttestationObject ?? Data()),
                "transports": ["internal"],
                "authenticatorAttachment": "platform"
            ]
            
            replyHandler(result, nil)
        } else {
            replyHandler(nil, "Invalid credential type")
        }
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        print("❌ WebAuthn Create failed: \(error)")
        
        let errorMessage: String
        if let authError = error as? ASAuthorizationError {
            switch authError.code {
            case .canceled:
                errorMessage = "User canceled the operation"
            case .failed:
                errorMessage = "Authentication failed"
            case .invalidResponse:
                errorMessage = "Invalid response"
            case .notHandled:
                errorMessage = "Not handled"
            case .unknown:
                errorMessage = "Unknown error"
            case .notInteractive:
                errorMessage = "Not interactive"
            case .matchedExcludedCredential:
                errorMessage = "Matched excluded credential"
            case .credentialImport:
                errorMessage = "Credential import error"
            case .credentialExport:
                errorMessage = "Credential export error"
            @unknown default:
                errorMessage = "Unknown error: \(error.localizedDescription)"
            }
        } else {
            errorMessage = error.localizedDescription
        }
        
        replyHandler(nil, errorMessage)
    }
    
    private func generateClientDataJSON(type: String) -> Data {
        let origin = "https://webauthn.me/"  // Use the actual origin
        let clientData = [
            "type": type,
            "challenge": "fallback-challenge",  // Placeholder since we prefer raw client data
            "origin": origin
        ]
        
        do {
            return try JSONSerialization.data(withJSONObject: clientData)
        } catch {
            print("❌ Error generating client data JSON: \(error)")
            return Data()
        }
    }
}

// Delegate for WebAuthn Get (Authentication)
class WebAuthnGetDelegate: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    let replyHandler: (Any?, String?) -> Void
    
    init(replyHandler: @escaping (Any?, String?) -> Void) {
        self.replyHandler = replyHandler
    }
    
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        if let keyWindow = NSApp.keyWindow {
            return keyWindow
        }
        
        // Get the main app window
        // if let appDelegate = NSApp.delegate as? AppDelegate {
        //     return appDelegate.window
        // }
        
        // Fallback to any available window
        return NSApp.windows.first ?? NSWindow()
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        print("✅ WebAuthn Get authorization completed")
        
        if let credential = authorization.credential as? ASAuthorizationPlatformPublicKeyCredentialAssertion {
            let credentialId = credential.credentialID.base64EncodedString()
            
            // Use the raw client data from the credential
            let clientDataJSON = credential.rawClientDataJSON
            
            let result: [String: Any] = [
                "id": credentialId,
                "rawId": Array(credential.credentialID),
                "clientDataJSON": Array(clientDataJSON),
                "authenticatorData": Array(credential.rawAuthenticatorData),
                "signature": Array(credential.signature),
                "userHandle": credential.userID.map { Array($0) } as Any,
                "authenticatorAttachment": "platform"
            ]
            
            replyHandler(result, nil)
        } else {
            replyHandler(nil, "Invalid credential type")
        }
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        print("❌ WebAuthn Get failed: \(error)")
        
        let errorMessage: String
        if let authError = error as? ASAuthorizationError {
            switch authError.code {
            case .canceled:
                errorMessage = "User canceled the operation"
            case .failed:
                errorMessage = "Authentication failed"
            case .invalidResponse:
                errorMessage = "Invalid response"
            case .notHandled:
                errorMessage = "Not handled"
            case .unknown:
                errorMessage = "Unknown error"
            case .notInteractive:
                errorMessage = "Not interactive"
            case .matchedExcludedCredential:
                errorMessage = "Matched excluded credential"
            case .credentialImport:
                errorMessage = "Credential import error"
            case .credentialExport:
                errorMessage = "Credential export error"
            @unknown default:
                errorMessage = "Unknown error: \(error.localizedDescription)"
            }
        } else {
            errorMessage = error.localizedDescription
        }
        
        replyHandler(nil, errorMessage)
    }
    
    private func generateClientDataJSON(type: String) -> Data {
        let origin = "https://webauthn.me/"  // Use the actual origin
        let clientData = [
            "type": type,
            "challenge": "fallback-challenge",  // Placeholder since we prefer raw client data
            "origin": origin
        ]
        
        do {
            return try JSONSerialization.data(withJSONObject: clientData)
        } catch {
            print("❌ Error generating client data JSON: \(error)")
            return Data()
        }
    }
} 
