// Copyright 2025 FIDO3.ai
// Generated on 2025-7-19
import Foundation

public struct WebAuthnJavaScript {
    
    public static let webAuthnPolyfill = """
    // WebAuthn Polyfill and Enhancement Script
    (function() {
        'use strict';
        
        // Check if WebAuthn is already available
        if (!window.PublicKeyCredential) {
            console.log('WebAuthn not natively supported, initializing polyfill...');
            
            // Basic WebAuthn polyfill structure
            window.PublicKeyCredential = function() {};
            window.PublicKeyCredential.isUserVerifyingPlatformAuthenticatorAvailable = function() {
                return Promise.resolve(true);
            };
            window.PublicKeyCredential.isConditionalMediationAvailable = function() {
                return Promise.resolve(true);
            };
        }
        
        // Enhance navigator.credentials if needed
        if (!navigator.credentials) {
            navigator.credentials = {
                create: function(options) {
                    return new Promise((resolve, reject) => {
                        // Send message to Swift
                        if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.webAuthnHandler) {
                            window.webkit.messageHandlers.webAuthnHandler.postMessage({
                                action: 'webauthn_create',
                                options: options
                            });
                        }
                        
                        // For now, simulate a successful creation
                        setTimeout(() => {
                            resolve({
                                id: 'simulated-credential-id',
                                rawId: new ArrayBuffer(32),
                                response: {
                                    clientDataJSON: new ArrayBuffer(100),
                                    attestationObject: new ArrayBuffer(200)
                                },
                                type: 'public-key'
                            });
                        }, 1000);
                    });
                },
                
                get: function(options) {
                    return new Promise((resolve, reject) => {
                        // Send message to Swift
                        if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.webAuthnHandler) {
                            window.webkit.messageHandlers.webAuthnHandler.postMessage({
                                action: 'webauthn_get',
                                options: options
                            });
                        }
                        
                        // For now, simulate a successful authentication
                        setTimeout(() => {
                            resolve({
                                id: 'simulated-credential-id',
                                rawId: new ArrayBuffer(32),
                                response: {
                                    clientDataJSON: new ArrayBuffer(100),
                                    authenticatorData: new ArrayBuffer(150),
                                    signature: new ArrayBuffer(64),
                                    userHandle: new ArrayBuffer(16)
                                },
                                type: 'public-key'
                            });
                        }, 1000);
                    });
                }
            };
        }
        
        // Array buffer to base64 conversion utility
        window.arrayBufferToBase64 = function(buffer) {
            let binary = '';
            const bytes = new Uint8Array(buffer);
            const len = bytes.byteLength;
            for (let i = 0; i < len; i++) {
                binary += String.fromCharCode(bytes[i]);
            }
            return window.btoa(binary);
        };
        
        // Base64 to array buffer conversion utility
        window.base64ToArrayBuffer = function(base64) {
            const binary_string = window.atob(base64);
            const len = binary_string.length;
            const bytes = new Uint8Array(len);
            for (let i = 0; i < len; i++) {
                bytes[i] = binary_string.charCodeAt(i);
            }
            return bytes.buffer;
        };
        
        console.log('WebAuthn support initialized');
    })();
    """
    
    public static let webAuthnEnhancements = """
    // WebAuthn Enhancements and Debugging
    (function() {
        'use strict';
        
        // Enhanced logging for WebAuthn operations
        const originalCreate = navigator.credentials.create;
        const originalGet = navigator.credentials.get;
        
        navigator.credentials.create = async function(options) {
            console.log('WebAuthn Create called with options:', options);
            
            try {
                const result = await originalCreate.call(this, options);
                console.log('WebAuthn Create successful:', result);
                return result;
            } catch (error) {
                console.error('WebAuthn Create failed:', error);
                
                // Send error to Swift
                if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.webAuthnHandler) {
                    window.webkit.messageHandlers.webAuthnHandler.postMessage({
                        action: 'webauthn_error',
                        error: error.message,
                        type: 'create'
                    });
                }
                
                throw error;
            }
        };
        
        navigator.credentials.get = async function(options) {
            console.log('WebAuthn Get called with options:', options);
            
            try {
                const result = await originalGet.call(this, options);
                console.log('WebAuthn Get successful:', result);
                return result;
            } catch (error) {
                console.error('WebAuthn Get failed:', error);
                
                // Send error to Swift
                if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.webAuthnHandler) {
                    window.webkit.messageHandlers.webAuthnHandler.postMessage({
                        action: 'webauthn_error',
                        error: error.message,
                        type: 'get'
                    });
                }
                
                throw error;
            }
        };
        
        // Add WebAuthn detection capabilities
        window.detectWebAuthnSupport = function() {
            const support = {
                publicKeyCredential: !!window.PublicKeyCredential,
                credentials: !!navigator.credentials,
                create: !!(navigator.credentials && navigator.credentials.create),
                get: !!(navigator.credentials && navigator.credentials.get),
                conditionalMediation: false,
                userVerifyingPlatformAuthenticator: false
            };
            
            // Test for conditional mediation
            if (window.PublicKeyCredential && window.PublicKeyCredential.isConditionalMediationAvailable) {
                window.PublicKeyCredential.isConditionalMediationAvailable().then(available => {
                    support.conditionalMediation = available;
                    console.log('Conditional mediation available:', available);
                });
            }
            
            // Test for platform authenticator
            if (window.PublicKeyCredential && window.PublicKeyCredential.isUserVerifyingPlatformAuthenticatorAvailable) {
                window.PublicKeyCredential.isUserVerifyingPlatformAuthenticatorAvailable().then(available => {
                    support.userVerifyingPlatformAuthenticator = available;
                    console.log('User verifying platform authenticator available:', available);
                });
            }
            
            console.log('WebAuthn support detection:', support);
            return support;
        };
        
        // Automatically detect support on page load
        if (document.readyState === 'loading') {
            document.addEventListener('DOMContentLoaded', window.detectWebAuthnSupport);
        } else {
            window.detectWebAuthnSupport();
        }
        
        // Add a test function for WebAuthn
        window.testWebAuthn = function() {
            console.log('Testing WebAuthn functionality...');
            
            // Generate user ID and convert to base64
            const userId = crypto.getRandomValues(new Uint8Array(64));
            const userIdBase64 = window.arrayBufferToBase64(userId.buffer);
            
            // Generate challenge and convert to array
            const challenge = crypto.getRandomValues(new Uint8Array(32));
            const challengeArray = Array.from(challenge);
            
            const createOptions = {
                publicKey: {
                    challenge: challengeArray,
                    rp: {
                        name: "WebMan Browser",
                        id: window.location.hostname,
                    },
                    user: {
                        id: userIdBase64,
                        name: "test@example.com",
                        displayName: "Test User",
                    },
                    pubKeyCredParams: [{alg: -7, type: "public-key"}],
                    authenticatorSelection: {
                        authenticatorAttachment: "platform",
                        userVerification: "required"
                    },
                    timeout: 60000,
                    attestation: "direct"
                }
            };
            
            return navigator.credentials.create(createOptions)
                .then(credential => {
                    console.log('WebAuthn test successful!', credential);
                    return credential;
                })
                .catch(error => {
                    console.error('WebAuthn test failed:', error);
                    throw error;
                });
        };
        
        console.log('WebAuthn enhancements loaded');
    })();
    """
} 
