// The Swift Programming Language
// https://docs.swift.org/swift-book

// Add WebAuthn JavaScript bridge with native support
public let webAuthnScript = """
// Override WebAuthn to use native macOS implementation
console.log('🔐 Overriding WebAuthn with native bridge');

if (window.PublicKeyCredential) {
    const originalCreate = navigator.credentials.create;
    const originalGet = navigator.credentials.get;
    
    navigator.credentials.create = async function(options) {
        console.log('🔐 Native WebAuthn create called', options);
        
        try {
            // Send to native handler
            window.webkit.messageHandlers.webAuthnNative.postMessage({
                action: 'create',
                options: JSON.stringify(options)
            });
            
            // Wait for native response (simulated for now)
            return await originalCreate.call(this, options);
        } catch (error) {
            console.log('🔐 Falling back to original implementation');
            return await originalCreate.call(this, options);
        }
    };
    
    navigator.credentials.get = async function(options) {
        console.log('🔐 Native WebAuthn get called', options);
        
        try {
            // Send to native handler
            window.webkit.messageHandlers.webAuthnNative.postMessage({
                action: 'get',
                options: JSON.stringify(options)
            });
            
            // Wait for native response (simulated for now)
            return await originalGet.call(this, options);
        } catch (error) {
            console.log('🔐 Falling back to original implementation');
            return await originalGet.call(this, options);
        }
    };
}

window.webAuthnSupported = true;
console.log('🔐 WebAuthn native bridge active');
"""
