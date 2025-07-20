import Cocoa
import WebKit

// Chrome User Agent Handler
class ChromeUserAgentHandler: NSObject, WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        // This is just for the side effect of having a handler
    }
}

// WebView UI Delegate for JavaScript dialogs
public class WebUIDelegate: NSObject, WKUIDelegate {
    public func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping @MainActor @Sendable () -> Void) {
        let alert = NSAlert()
        alert.messageText = "Alert"
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
        completionHandler()
    }
    
    public func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping @MainActor @Sendable (Bool) -> Void) {
        let alert = NSAlert()
        alert.messageText = "Confirm"
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        let response = alert.runModal()
        completionHandler(response == .alertFirstButtonReturn)
    }
}

// WebAuthn Browser Setup Manager
public class WebAuthnBrowserSetup {
    
    public static func createWebViewConfiguration() -> WKWebViewConfiguration {
        let config = WKWebViewConfiguration()
        
        // Enable JavaScript and disable deprecated settings warnings
        config.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
        config.setValue(true, forKey: "allowUniversalAccessFromFileURLs")
        
        // Enable developer tools
        #if DEBUG
        config.preferences.setValue(true, forKey: "developerExtrasEnabled")
        #endif
        
        // Set Chrome user agent to maximize compatibility
        config.applicationNameForUserAgent = "Chrome/120.0.0.0"
        config.userContentController.add(ChromeUserAgentHandler(), name: "setUserAgent")
        
        // Create the native WebAuthn bridge
        let webAuthnBridge = WebAuthnNativeBridge()
        
        // Connect LocalAuthService with WebAuthnClientManager for credential lookup (lazy initialization)
        LocalAuthService.shared.setWebAuthnManager(WebAuthnClientManagerSingleton.shared.manager)
        print("🔗 Connected LocalAuthService with WebAuthnClientManager singleton")
        
        // Add message handlers for WebAuthn with reply support
        config.userContentController.addScriptMessageHandler(webAuthnBridge, contentWorld: .page, name: "webAuthnCreate")
        config.userContentController.addScriptMessageHandler(webAuthnBridge, contentWorld: .page, name: "webAuthnGet")
        config.userContentController.addScriptMessageHandler(webAuthnBridge, contentWorld: .page, name: "webAuthnAvailable")
        config.userContentController.addScriptMessageHandler(webAuthnBridge, contentWorld: .page, name: "serverCounterUpdate")
        
        // Inject JavaScript to override WebAuthn API and user agent
        let webAuthnScript = Self.createWebAuthnScript()
        
        // Inject at document start
        let startScript = WKUserScript(source: webAuthnScript, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        config.userContentController.addUserScript(startScript)
        
        // Also inject at document end to catch any late-loaded scripts
        let endScript = WKUserScript(source: webAuthnScript, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
        config.userContentController.addUserScript(endScript)
        
        return config
    }
    
    private static func createWebAuthnScript() -> String {
        return """
        (function() {
            console.log('🚀 ULTRA-AGGRESSIVE NATIVE WebAuthn Bridge Starting...');
            
            // COMPLETE CHROME BROWSER SPOOFING
            const chromeUserAgent = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
            
            try {
                // Override user agent
                Object.defineProperty(navigator, 'userAgent', {
                    value: chromeUserAgent,
                    writable: false,
                    configurable: false
                });
                
                // Override vendor
                Object.defineProperty(navigator, 'vendor', {
                    value: 'Google Inc.',
                    writable: false,
                    configurable: false
                });
                
                // Override app name
                Object.defineProperty(navigator, 'appName', {
                    value: 'Netscape',
                    writable: false,
                    configurable: false
                });
                
                // Override app version
                Object.defineProperty(navigator, 'appVersion', {
                    value: '5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
                    writable: false,
                    configurable: false
                });
                
                // Override platform
                Object.defineProperty(navigator, 'platform', {
                    value: 'MacIntel',
                    writable: false,
                    configurable: false
                });
                
                // Add Chrome-specific properties
                if (!navigator.webkitGetUserMedia) {
                    navigator.webkitGetUserMedia = navigator.getUserMedia;
                }
                
                // Add Chrome plugins
                if (!navigator.plugins.namedItem('Chrome PDF Plugin')) {
                    // Simulate Chrome plugins
                    console.log('🔧 Adding Chrome plugin spoofing');
                }
                
                console.log('✅ Complete Chrome browser spoofing applied');
            } catch (e) {
                console.log('⚠️ Could not complete browser spoofing:', e);
            }
            
            // Test message handler availability
            function checkMessageHandlers() {
                const hasWebKit = window.webkit && window.webkit.messageHandlers;
                const hasCreate = hasWebKit && window.webkit.messageHandlers.webAuthnCreate;
                const hasGet = hasWebKit && window.webkit.messageHandlers.webAuthnGet;
                const hasAvailable = hasWebKit && window.webkit.messageHandlers.webAuthnAvailable;
                
                console.log('🔧 Message Handlers Check:', {
                    webkit: !!window.webkit,
                    messageHandlers: !!hasWebKit,
                    webAuthnCreate: !!hasCreate,
                    webAuthnGet: !!hasGet,
                    webAuthnAvailable: !!hasAvailable
                });
                
                return hasCreate && hasGet && hasAvailable;
            }
            
            // NUCLEAR OPTION: Completely replace WebAuthn
            function replaceWebAuthn() {
                console.log('🧨 NUCLEAR WEBAUTHN REPLACEMENT');
                
                // IMMEDIATELY override WebAuthn detection
                window.isWebAuthnSupported = true;
                window.hasWebAuthn = true;
                
                // Override common WebAuthn detection functions
                window.webAuthnSupported = function() { return true; };
                window.checkWebAuthnSupport = function() { return true; };
                window.isWebAuthnAvailable = function() { return true; };
                
                // Store original APIs to track if they get replaced
                const originalPublicKeyCredential = window.PublicKeyCredential;
                const originalCredentials = navigator.credentials;
                
                // Delete everything WebAuthn related
                try {
                    delete window.PublicKeyCredential;
                    delete navigator.credentials;
                    console.log('🗑️ Deleted existing WebAuthn APIs');
                } catch (e) {
                    console.log('⚠️ Error deleting existing APIs:', e);
                }
                
                // Recreate PublicKeyCredential with EXTENSIVE logging
                window.PublicKeyCredential = class PublicKeyCredential {
                    constructor(credentialId) {
                        this.id = credentialId;
                        this.type = 'public-key';
                        console.log('🆕 NATIVE PublicKeyCredential created:', credentialId);
                    }
                    
                    static isUserVerifyingPlatformAuthenticatorAvailable() {
                        console.log('📱 NATIVE platform authenticator check (from our custom class)');
                        return Promise.resolve(true);
                    }
                    
                    static isConditionalMediationAvailable() {
                        console.log('📱 NATIVE conditional mediation check (from our custom class)');
                        return Promise.resolve(true);
                    }
                };
                
                // Mark our class so we can identify it
                window.PublicKeyCredential._isNativeReplacement = true;
                
                // Create our custom credentials object with EXTENSIVE logging
                const customCredentials = {
                    create: async function(options) {
                        console.log('🔥🔥🔥 DEFINITELY USING OUR NATIVE WebAuthn Create!!! 🔥🔥🔥');
                        console.log('🔐 NATIVE WebAuthn Create called with options:', options);
                        
                        // TRIPLE CHECK: Make sure this is really our function
                        console.trace('🔍 Call stack trace for WebAuthn create:');
                        
                        if (!options?.publicKey) {
                            console.error('❌ No publicKey options provided');
                            throw new Error('No publicKey options provided');
                        }
                        
                        if (!checkMessageHandlers()) {
                            console.error('❌ Native bridge not available');
                            throw new Error('Native bridge not available');
                        }
                        
                        try {
                            console.log('📤 Sending to NATIVE bridge...');
                            
                            // Properly convert challenge ArrayBuffer to array
                            let challengeArray;
                            if (options.publicKey.challenge instanceof ArrayBuffer) {
                                challengeArray = Array.from(new Uint8Array(options.publicKey.challenge));
                            } else if (options.publicKey.challenge instanceof Uint8Array) {
                                challengeArray = Array.from(options.publicKey.challenge);
                            } else {
                                challengeArray = Array.from(new Uint8Array(options.publicKey.challenge));
                            }
                            
                            console.log('🔍 Challenge conversion:', {
                                originalType: options.publicKey.challenge.constructor.name,
                                originalLength: options.publicKey.challenge.byteLength || options.publicKey.challenge.length,
                                convertedLength: challengeArray.length,
                                first4Bytes: challengeArray.slice(0, 4)
                            });
                            
                            // Debug user object before processing
                            console.log('🔍 Raw user object:', options.publicKey.user);
                            console.log('🔍 User.id type:', typeof options.publicKey.user.id);
                            console.log('🔍 User.id value:', options.publicKey.user.id);
                            console.log('🔍 User.id constructor:', options.publicKey.user.id?.constructor?.name);
                            
                            // Ensure user.id is a proper string (not ArrayBuffer or other type)
                            let processedUser = {
                                id: options.publicKey.user.id,
                                name: options.publicKey.user.name,
                                displayName: options.publicKey.user.displayName
                            };
                            
                            // If user.id is not a string, try to convert it
                            if (typeof processedUser.id !== 'string') {
                                console.log('⚠️ User.id is not a string, attempting conversion...');
                                if (processedUser.id instanceof ArrayBuffer) {
                                    processedUser.id = btoa(String.fromCharCode(...new Uint8Array(processedUser.id)));
                                } else if (processedUser.id instanceof Uint8Array) {
                                    processedUser.id = btoa(String.fromCharCode(...processedUser.id));
                                } else if (Array.isArray(processedUser.id)) {
                                    processedUser.id = btoa(String.fromCharCode(...processedUser.id));
                                } else {
                                    console.error('❌ Unable to convert user.id:', processedUser.id);
                                    throw new Error('Invalid user.id format');
                                }
                                console.log('✅ Converted user.id to:', processedUser.id);
                            }
                            
                            console.log('🔍 Processed user object:', processedUser);

                            const messagePayload = {
                                rp: options.publicKey.rp,
                                user: processedUser,
                                challenge: challengeArray,
                                pubKeyCredParams: options.publicKey.pubKeyCredParams,
                                timeout: options.publicKey.timeout,
                                excludeCredentials: options.publicKey.excludeCredentials,
                                authenticatorSelection: options.publicKey.authenticatorSelection,
                                attestation: options.publicKey.attestation,
                                extensions: options.publicKey.extensions,
                                hints: options.publicKey.hints,
                                attestationFormats: options.publicKey.attestationFormats
                            };
                            
                            console.log('🔍 Final message payload:', messagePayload);
                            
                            // Debug extensions being sent
                            if (messagePayload.extensions && Object.keys(messagePayload.extensions).length > 0) {
                                console.log('🔍 Extensions requested for REGISTRATION:', messagePayload.extensions);
                            } else {
                                console.log('🔍 No extensions requested for registration');
                            }
                            
                            const result = await window.webkit.messageHandlers.webAuthnCreate.postMessage(messagePayload);
                            
                            console.log('📥 NATIVE bridge response:', result);
                            
                            if (result && result.error) {
                                throw new DOMException(result.error, 'NotAllowedError');
                            }
                            
                            if (!result || !result.id) {
                                throw new Error('Invalid response from native bridge');
                            }
                            
                            const credential = {
                                id: result.id,
                                rawId: new Uint8Array(result.rawId).buffer,
                                response: {
                                    clientDataJSON: new Uint8Array(result.clientDataJSON).buffer,
                                    attestationObject: new Uint8Array(result.attestationObject).buffer,
                                    getTransports: () => result.transports || ['internal']
                                },
                                type: 'public-key',
                                authenticatorAttachment: result.authenticatorAttachment || 'platform',
                                clientExtensionResults: result.clientExtensionResults || {},
                                getClientExtensionResults: function() {
                                    console.log('🔧 getClientExtensionResults called for REGISTRATION, returning:', this.clientExtensionResults);
                                    console.log('🔧 Extension keys:', Object.keys(this.clientExtensionResults));
                                    if (Object.keys(this.clientExtensionResults).length > 0) {
                                        console.log('🔧 Extension details:', JSON.stringify(this.clientExtensionResults, null, 2));
                                    }
                                    return this.clientExtensionResults;
                                }
                            };
                            
                            console.log('✅ NATIVE WebAuthn Create SUCCESS:', credential);
                            return credential;
                        } catch (error) {
                            console.error('❌ NATIVE WebAuthn Create FAILED:', error);
                            throw error;
                        }
                    },
                    
                    get: async function(options) {
                        console.log('🔥🔥🔥 DEFINITELY USING OUR NATIVE WebAuthn Get!!! 🔥🔥🔥');
                        console.log('🔍 NATIVE WebAuthn Get called with options:', options);
                        
                        if (!options?.publicKey) {
                            throw new Error('No publicKey options provided');
                        }
                        
                        if (!checkMessageHandlers()) {
                            throw new Error('Native bridge not available');
                        }
                        
                        try {
                            console.log('📤 Sending get request to NATIVE bridge...');
                            
                            // CRITICAL FIX: Convert credential IDs from ArrayBuffers to byte arrays
                            let processedAllowCredentials = [];
                            if (options.publicKey.allowCredentials && Array.isArray(options.publicKey.allowCredentials)) {
                                processedAllowCredentials = options.publicKey.allowCredentials.map(cred => {
                                    console.log('🔍 Processing credential:', {
                                        type: cred.type,
                                        idType: typeof cred.id,
                                        idConstructor: cred.id?.constructor?.name,
                                        idLength: cred.id?.byteLength || cred.id?.length,
                                        transports: cred.transports
                                    });
                                    
                                    let processedId;
                                    
                                    // Handle different credential ID formats
                                    if (typeof cred.id === 'string') {
                                        // Already a string (base64) - convert to bytes for native bridge
                                        console.log('🔍 Credential ID is string (base64):', cred.id);
                                        try {
                                            const binaryString = atob(cred.id);
                                            processedId = Array.from(binaryString, char => char.charCodeAt(0));
                                            console.log('✅ Converted base64 string to byte array:', processedId.length, 'bytes');
                                        } catch (e) {
                                            console.warn('⚠️ Failed to decode base64 credential ID, using as-is');
                                            processedId = cred.id;
                                        }
                                    } else if (cred.id instanceof ArrayBuffer) {
                                        // ArrayBuffer - convert to byte array
                                        processedId = Array.from(new Uint8Array(cred.id));
                                        console.log('✅ Converted ArrayBuffer to byte array:', processedId.length, 'bytes');
                                    } else if (cred.id instanceof Uint8Array) {
                                        // Already Uint8Array - convert to regular array
                                        processedId = Array.from(cred.id);
                                        console.log('✅ Converted Uint8Array to byte array:', processedId.length, 'bytes');
                                    } else if (Array.isArray(cred.id)) {
                                        // Already an array
                                        processedId = cred.id;
                                        console.log('✅ Credential ID already an array:', processedId.length, 'bytes');
                                    } else {
                                        console.warn('⚠️ Unknown credential ID type:', typeof cred.id, cred.id);
                                        processedId = cred.id; // Pass through as-is
                                    }
                                    
                                    return {
                                        type: cred.type,
                                        id: processedId,
                                        transports: cred.transports
                                    };
                                });
                                
                                console.log('🔍 Processed allowCredentials:', processedAllowCredentials.length, 'credentials');
                                processedAllowCredentials.forEach((cred, index) => {
                                    console.log(`🔍   Credential ${index}:`, {
                                        type: cred.type,
                                        idType: typeof cred.id,
                                        idLength: cred.id?.length,
                                        idPreview: Array.isArray(cred.id) ? cred.id.slice(0, 4) : cred.id,
                                        transports: cred.transports
                                    });
                                });
                            }
                            
                            const getMessagePayload = {
                                challenge: Array.from(new Uint8Array(options.publicKey.challenge)),
                                timeout: options.publicKey.timeout,
                                rpId: options.publicKey.rpId,
                                allowCredentials: processedAllowCredentials,
                                userVerification: options.publicKey.userVerification,
                                extensions: options.publicKey.extensions,
                                hints: options.publicKey.hints // Enhanced UI hints support for authentication
                            };
                            
                            // Debug extensions being sent for authentication
                            if (getMessagePayload.extensions && Object.keys(getMessagePayload.extensions).length > 0) {
                                console.log('🔍 Extensions requested for AUTHENTICATION:', getMessagePayload.extensions);
                            } else {
                                console.log('🔍 No extensions requested for authentication');
                            }
                            
                            const result = await window.webkit.messageHandlers.webAuthnGet.postMessage(getMessagePayload);
                            
                            console.log('📥 NATIVE bridge get response:', result);
                            
                            if (result && result.error) {
                                throw new DOMException(result.error, 'NotAllowedError');
                            }
                            
                            if (!result || !result.id) {
                                throw new Error('Invalid response from native bridge');
                            }
                            
                            const credential = {
                                id: result.id,
                                rawId: new Uint8Array(result.rawId).buffer,
                                response: {
                                    clientDataJSON: new Uint8Array(result.clientDataJSON).buffer,
                                    authenticatorData: new Uint8Array(result.authenticatorData).buffer,
                                    signature: new Uint8Array(result.signature).buffer,
                                    userHandle: result.userHandle ? new Uint8Array(result.userHandle).buffer : null
                                },
                                type: 'public-key',
                                authenticatorAttachment: result.authenticatorAttachment || 'platform',
                                clientExtensionResults: result.clientExtensionResults || {},
                                getClientExtensionResults: function() {
                                    console.log('🔧 getClientExtensionResults called for AUTHENTICATION, returning:', this.clientExtensionResults);
                                    console.log('🔧 Extension keys:', Object.keys(this.clientExtensionResults));
                                    if (Object.keys(this.clientExtensionResults).length > 0) {
                                        console.log('🔧 Extension details:', JSON.stringify(this.clientExtensionResults, null, 2));
                                    }
                                    return this.clientExtensionResults;
                                }
                            };
                            
                            // Add base64 strings to credential for direct server access
                            credential._base64Data = {
                                clientDataJSON: result.clientDataJSONBase64,
                                authenticatorData: result.authenticatorDataBase64,
                                signature: result.signatureBase64,
                                userHandle: result.userHandleBase64
                            };
                            
                            console.log('✅ NATIVE WebAuthn Get SUCCESS:', credential);
                            console.log('🔍 Base64 data available:', credential._base64Data);
                            return credential;
                        } catch (error) {
                            console.error('❌ NATIVE WebAuthn Get FAILED:', error);
                            throw error;
                        }
                    }
                };
                
                // Mark our credentials object
                customCredentials._isNativeReplacement = true;
                
                // USE DEFINEPROPERTY TO MAKE IT HARDER TO OVERRIDE
                Object.defineProperty(navigator, 'credentials', {
                    value: customCredentials,
                    writable: false,
                    configurable: false
                });
                
                console.log('✅ NATIVE WebAuthn APIs recreated with DEFINEPROPERTY');
                
                // Monitor for API replacements
                let checkCount = 0;
                const monitorAPIs = () => {
                    checkCount++;
                    
                    const currentPKC = window.PublicKeyCredential;
                    const currentCreds = navigator.credentials;
                    
                    const pkcIsOurs = currentPKC && currentPKC._isNativeReplacement;
                    const credsIsOurs = currentCreds && currentCreds._isNativeReplacement;
                    
                    console.log(`🕵️ API Check #${checkCount}:`, {
                        publicKeyCredentialIsOurs: pkcIsOurs,
                        credentialsIsOurs: credsIsOurs,
                        publicKeyCredentialExists: !!currentPKC,
                        credentialsExists: !!currentCreds
                    });
                    
                    if (!pkcIsOurs || !credsIsOurs) {
                        console.warn('⚠️ Our APIs were replaced! Re-applying...');
                        replaceWebAuthn();
                    }
                };
                
                // Check every 100ms for the first few seconds
                for (let i = 0; i < 50; i++) {
                    setTimeout(monitorAPIs, i * 100);
                }
            }
            
            // IMMEDIATE OVERRIDE - Run before anything else
            window.isWebAuthnSupported = true;
            window.hasWebAuthn = true;
            window.webAuthnSupported = function() { return true; };
            
            // Override any early browser detection
            window.isSafari = false;
            window.isWebKit = false;
            window.isChrome = true;
            
            // Run replacement immediately
            replaceWebAuthn();
            
            // EXTREMELY AGGRESSIVE: Override any function that might disable WebAuthn
            const originalError = console.error;
            console.error = function(...args) {
                const message = args.join(' ');
                if (message.includes('WebAuthn') || message.includes('Chrome') || message.includes('compatible')) {
                    console.log('🛡️ Blocked error message:', message);
                    return;
                }
                originalError.apply(console, args);
            };
            
            // Block any alerts about browser compatibility
            const originalAlert = window.alert;
            window.alert = function(message) {
                if (message && (message.includes('WebAuthn') || message.includes('Chrome') || message.includes('compatible'))) {
                    console.log('🛡️ Blocked alert:', message);
                    return;
                }
                originalAlert.call(window, message);
            };
            
            // Test native bridge connectivity
            try {
                if (checkMessageHandlers()) {
                    window.webkit.messageHandlers.webAuthnAvailable.postMessage({}).then(available => {
                        console.log('🔍 Native WebAuthn Available:', available);
                    }).catch(err => {
                        console.warn('⚠️ Native WebAuthn check failed:', err);
                    });
                }
            } catch (e) {
                console.log('⚠️ Native bridge test failed:', e);
            }
            
            // MASSIVE AGGRESSIVE MONITORING
            function debugWebAuthnState() {
                console.log('🔬 DEBUGGING WebAuthn State:');
                console.log('  PublicKeyCredential exists:', !!window.PublicKeyCredential);
                console.log('  PublicKeyCredential is ours:', !!(window.PublicKeyCredential && window.PublicKeyCredential._isNativeReplacement));
                console.log('  navigator.credentials exists:', !!navigator.credentials);
                console.log('  navigator.credentials is ours:', !!(navigator.credentials && navigator.credentials._isNativeReplacement));
                console.log('  Message handlers check:', checkMessageHandlers());
                
                // Test if our functions are being called
                if (navigator.credentials && navigator.credentials.create) {
                    console.log('  credentials.create function source:', navigator.credentials.create.toString().substring(0, 200));
                }
                
                if (window.PublicKeyCredential && window.PublicKeyCredential.isUserVerifyingPlatformAuthenticatorAvailable) {
                    console.log('  PKC.isUserVerifying... source:', window.PublicKeyCredential.isUserVerifyingPlatformAuthenticatorAvailable.toString().substring(0, 200));
                }
            }
            
            // Re-run replacement after page loads
            if (document.readyState === 'loading') {
                document.addEventListener('DOMContentLoaded', function() {
                    console.log('🔄 Re-running WebAuthn replacement after DOM loaded');
                    replaceWebAuthn();
                    setTimeout(debugWebAuthnState, 100);
                });
            }
            
            // Also run after window loads
            window.addEventListener('load', function() {
                console.log('🔄 Re-running WebAuthn replacement after window loaded');
                replaceWebAuthn();
                setTimeout(debugWebAuthnState, 500);
            });
            
            // Monitor for any script changes to our APIs
            let scriptObserver = new MutationObserver(function(mutations) {
                mutations.forEach(function(mutation) {
                    if (mutation.type === 'childList') {
                        mutation.addedNodes.forEach(function(node) {
                            if (node.tagName === 'SCRIPT') {
                                console.log('🚨 New script added:', node.src || 'inline script');
                                // Re-apply our overrides after new scripts
                                setTimeout(() => {
                                    replaceWebAuthn();
                                    debugWebAuthnState();
                                }, 10);
                            }
                        });
                    }
                });
            });
            
            // Start monitoring when DOM is available
            if (document.body) {
                scriptObserver.observe(document.body, { childList: true, subtree: true });
            } else {
                document.addEventListener('DOMContentLoaded', function() {
                    scriptObserver.observe(document.body, { childList: true, subtree: true });
                });
            }
            
            console.log('✅ ULTRA-AGGRESSIVE NATIVE WebAuthn Bridge loaded');
            console.log('🌐 Final User Agent:', navigator.userAgent);
            debugWebAuthnState();
            
            // Log fetch requests for debugging, but let them go through to real server
            const originalFetch = window.fetch;
            window.fetch = function(url, options) {
                console.log('🌐 Real server request:', url, options);
                
                // Debug WebAuthn registration complete payload
                if (url.includes('/webauthn/register/complete') && options.body) {
                    try {
                        const payload = JSON.parse(options.body);
                        console.log('🔍 WebAuthn registration payload being sent to server:');
                        console.log('📋 Credential ID:', payload.id);
                        console.log('📋 Raw ID length:', payload.rawId ? payload.rawId.length : 'N/A');
                        console.log('📋 Client Data JSON length:', payload.response?.clientDataJSON ? payload.response.clientDataJSON.length : 'N/A');
                        console.log('📋 Attestation Object length:', payload.response?.attestationObject ? payload.response.attestationObject.length : 'N/A');
                        console.log('📋 Full payload structure:', Object.keys(payload));
                        if (payload.response) {
                            console.log('📋 Response structure:', Object.keys(payload.response));
                        }
                    } catch (e) {
                        console.log('❌ Could not parse registration payload:', e);
                    }
                }
                
                // Let all requests go through to the real https://webauthn.me/ server
                return originalFetch.apply(this, arguments);
            };
            
            console.log('🌐 REAL SERVER MODE: All requests will go to actual https://webauthn.me/ server');
            
            // Add notification that we're using real server
            console.log('✅ Mock server DISABLED - using real https://webauthn.me/ server with local Touch ID credentials');
            
            // Replace WebAuthn APIs
            replaceWebAuthn();
        })();
        """
    }
} 
