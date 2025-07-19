// Copyright 2025 FIDO3.ai
// Generated on 2025-7-19
import Foundation

// MARK: - WebAuthn Content Provider
public enum WebAuthnContent {
    
    // MARK: - WebAuthn JavaScript Functions
    public static func generateWebAuthnJS() -> String {
        return """
        // WebAuthn Implementation - Standalone Library
        // Can be integrated into any web application
        
        class WebAuthnClient {
            constructor(rpId, rpName = null, rpIcon = null) {
                this.rpId = rpId;
                this.rpName = rpName || rpId;
                this.rpIcon = rpIcon;
                this.webauthnInProgress = false;
            }
            
            // Registration Methods
            async beginRegistration(username, options = {}) {
                if (this.webauthnInProgress) {
                    console.log('WebAuthn operation already in progress');
                    throw new Error('WebAuthn operation already in progress');
                }
                this.webauthnInProgress = true;
                
                try {
                    // Check username availability
                    if (options.checkUsername !== false) {
                        const isAvailable = await this.checkUsernameAvailability(username);
                        if (!isAvailable) {
                            throw new Error('Username is already taken');
                        }
                    }
                    
                    // Get registration options from server
                    const registrationOptions = await this.getRegistrationOptions(username, options);
                    
                    // Create credentials
                    const credential = await this.createCredentials(registrationOptions);
                    
                    // Verify registration with server
                    const result = await this.verifyRegistration(username, credential, options);
                    
                    return result;
                } finally {
                    this.webauthnInProgress = false;
                }
            }
            
            async checkUsernameAvailability(username) {
                const response = await fetch('/webauthn/username/check', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ username })
                });
                
                if (!response.ok) {
                    throw new Error('Failed to check username availability');
                }
                
                const result = await response.json();
                return result.available;
            }
            
            async getRegistrationOptions(username, options = {}) {
                const requestBody = { 
                    username,
                    enablePasskeys: options.enablePasskeys !== false,
                    ...options.additionalData
                };
                
                const response = await fetch('/webauthn/register/begin', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify(requestBody)
                });
                
                if (!response.ok) {
                    throw new Error('Failed to get registration options');
                }
                
                return await response.json();
            }
            
            async createCredentials(options) {
                if (!options.publicKey || !options.publicKey.challenge) {
                    throw new Error('Invalid registration options from server');
                }
                
                // Convert base64 strings to ArrayBuffer
                options.publicKey.challenge = this.base64ToArrayBuffer(options.publicKey.challenge);
                options.publicKey.user.id = this.base64ToArrayBuffer(options.publicKey.user.id);
                
                // Create credentials
                const credential = await navigator.credentials.create(options);
                
                if (!credential) {
                    throw new Error('Failed to create credential');
                }
                
                return credential;
            }
            
            async verifyRegistration(username, credential, options = {}) {
                const requestData = {
                    username,
                    id: this.arrayBufferToBase64(credential.rawId),
                    rawId: this.arrayBufferToBase64(credential.rawId),
                    response: {
                        attestationObject: this.arrayBufferToBase64(credential.response.attestationObject),
                        clientDataJSON: this.arrayBufferToBase64(credential.response.clientDataJSON)
                    },
                    type: credential.type,
                    ...options.additionalData
                };
                
                const response = await fetch('/webauthn/register/complete', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify(requestData)
                });
                
                if (!response.ok) {
                    const errorData = await response.json().catch(() => ({}));
                    throw new Error(errorData.error || 'Registration verification failed');
                }
                
                return await response.json();
            }
            
            // Authentication Methods
            async beginAuthentication(username = null, options = {}) {
                if (this.webauthnInProgress) {
                    console.log('WebAuthn operation already in progress');
                    throw new Error('WebAuthn operation already in progress');
                }
                this.webauthnInProgress = true;
                
                try {
                    // Get authentication options from server
                    const authOptions = await this.getAuthenticationOptions(username, options);
                    
                    // Get assertion
                    const assertion = await this.getAssertion(authOptions);
                    
                    // Verify authentication with server
                    const result = await this.verifyAuthentication(username, assertion, options);
                    
                    return result;
                } finally {
                    this.webauthnInProgress = false;
                }
            }
            
            async getAuthenticationOptions(username = null, options = {}) {
                const requestBody = {
                    username: username || '',
                    ...options.additionalData
                };
                
                const response = await fetch('/webauthn/authenticate/begin', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify(requestBody)
                });
                
                if (!response.ok) {
                    throw new Error('Failed to get authentication options');
                }
                
                return await response.json();
            }
            
            async getAssertion(options) {
                if (!options.publicKey || !options.publicKey.challenge) {
                    throw new Error('Invalid authentication options from server');
                }
                
                // Convert challenge to ArrayBuffer
                options.publicKey.challenge = this.base64ToArrayBuffer(options.publicKey.challenge);
                
                // Convert allowCredentials if present
                if (options.publicKey.allowCredentials) {
                    options.publicKey.allowCredentials = options.publicKey.allowCredentials.map(cred => ({
                        ...cred,
                        id: this.base64ToArrayBuffer(cred.id)
                    }));
                }
                
                const assertion = await navigator.credentials.get({ publicKey: options.publicKey });
                
                if (!assertion) {
                    throw new Error('Authentication cancelled or failed');
                }
                
                return assertion;
            }
            
            async verifyAuthentication(username, assertion, options = {}) {
                const requestData = {
                    username: username || '',
                    id: assertion.id,
                    rawId: this.arrayBufferToBase64(assertion.rawId),
                    type: assertion.type,
                    response: {
                        clientDataJSON: this.arrayBufferToBase64(assertion.response.clientDataJSON),
                        authenticatorData: this.arrayBufferToBase64(assertion.response.authenticatorData),
                        signature: this.arrayBufferToBase64(assertion.response.signature),
                        userHandle: assertion.response.userHandle ? 
                                   this.arrayBufferToBase64(assertion.response.userHandle) : null
                    },
                    ...options.additionalData
                };
                
                const response = await fetch('/webauthn/authenticate/complete', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify(requestData)
                });
                
                if (!response.ok) {
                    const errorData = await response.json().catch(() => ({}));
                    throw new Error(errorData.error || 'Authentication failed');
                }
                
                const result = await response.json();
                
                // SAFE: Extract server counter if available and update local storage
                // This will only work if server counter updates are enabled
                if (result && assertion && assertion.id) {
                    try {
                        // Try to send server counter update to native bridge
                        if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.serverCounterUpdate) {
                            const updateData = {
                                credentialId: assertion.id,
                                serverResponse: result
                            };
                            
                            console.log('💫 Sending server counter update to native bridge:', updateData);
                            window.webkit.messageHandlers.serverCounterUpdate.postMessage(updateData);
                        }
                    } catch (error) {
                        // SAFETY: Never let server counter updates break authentication
                        console.log('💫 Server counter update failed (non-critical):', error);
                    }
                }
                
                return result;
            }
            
            // Utility Methods
            base64ToArrayBuffer(base64) {
                const binaryString = window.atob(base64);
                const bytes = new Uint8Array(binaryString.length);
                for (let i = 0; i < binaryString.length; i++) {
                    bytes[i] = binaryString.charCodeAt(i);
                }
                return bytes.buffer;
            }
            
            arrayBufferToBase64(buffer) {
                const bytes = new Uint8Array(buffer);
                let binary = '';
                for (let i = 0; i < bytes.byteLength; i++) {
                    binary += String.fromCharCode(bytes[i]);
                }
                return window.btoa(binary);
            }
            
            // Feature Detection
            static isSupported() {
                return !!(navigator.credentials && 
                         navigator.credentials.create && 
                         navigator.credentials.get &&
                         window.PublicKeyCredential);
            }
            
            static async isUserVerifyingPlatformAuthenticatorAvailable() {
                if (!this.isSupported()) return false;
                
                try {
                    return await PublicKeyCredential.isUserVerifyingPlatformAuthenticatorAvailable();
                } catch (error) {
                    console.warn('Failed to check platform authenticator availability:', error);
                    return false;
                }
            }
            
            // Status and Error Handling
            showStatus(message, type = 'info', duration = 3000) {
                console.log(`[WebAuthn ${type.toUpperCase()}] ${message}`);
                
                // If a status element exists, update it
                const statusEl = document.getElementById('webauthn-status');
                if (statusEl) {
                    statusEl.textContent = message;
                    statusEl.className = `webauthn-status ${type}`;
                    statusEl.style.display = 'block';
                    
                    if (duration > 0) {
                        setTimeout(() => {
                            statusEl.style.display = 'none';
                        }, duration);
                    }
                }
                
                // Dispatch custom event for integration
                window.dispatchEvent(new CustomEvent('webauthn-status', {
                    detail: { message, type, duration }
                }));
            }
            
            // Admin Functions (if admin access is available)
            async updateUserEmoji(username, emoji) {
                const response = await fetch(`/admin/api/users/${username}/emoji`, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ emoji })
                });
                
                if (!response.ok) {
                    throw new Error('Failed to update user emoji');
                }
                
                return await response.json();
            }
        }
        
        // Global WebAuthn convenience functions
        window.WebAuthn = {
            Client: WebAuthnClient,
            
            // Quick setup for common use cases
            async register(username, options = {}) {
                const client = new WebAuthnClient(
                    options.rpId || window.location.hostname,
                    options.rpName,
                    options.rpIcon
                );
                return await client.beginRegistration(username, options);
            },
            
            async authenticate(username = null, options = {}) {
                const client = new WebAuthnClient(
                    options.rpId || window.location.hostname,
                    options.rpName,
                    options.rpIcon
                );
                return await client.beginAuthentication(username, options);
            },
            
            isSupported: WebAuthnClient.isSupported,
            isPlatformAuthenticatorAvailable: WebAuthnClient.isUserVerifyingPlatformAuthenticatorAvailable
        };
        
        // Export for module systems
        if (typeof module !== 'undefined' && module.exports) {
            module.exports = { WebAuthnClient, WebAuthn: window.WebAuthn };
        }
        """
    }
    
    // MARK: - WebAuthn CSS Styles
    public static func generateWebAuthnCSS() -> String {
        return """
        /* WebAuthn Specific Styles */
        .webauthn-container {
            max-width: 400px;
            margin: 0 auto;
            padding: 20px;
        }
        
        .webauthn-form {
            background: var(--bg-secondary, #ffffff);
            border-radius: 12px;
            padding: 24px;
            box-shadow: 0 4px 15px rgba(0, 0, 0, 0.1);
            border: 1px solid var(--border-color, #e2e8f0);
        }
        
        .webauthn-title {
            font-size: 1.5rem;
            font-weight: 600;
            text-align: center;
            margin-bottom: 1.5rem;
            color: var(--text-primary, #2d3748);
        }
        
        .webauthn-input {
            width: 100%;
            padding: 12px 16px;
            border: 2px solid var(--border-color, #e2e8f0);
            border-radius: 8px;
            font-size: 16px;
            background: var(--input-bg, #ffffff);
            color: var(--input-text, #2d3748);
            margin-bottom: 16px;
            box-sizing: border-box;
            transition: border-color 0.3s ease, box-shadow 0.3s ease;
        }
        
        .webauthn-input:focus {
            outline: none;
            border-color: var(--accent-color, #007AFF);
            box-shadow: 0 0 0 3px rgba(0, 122, 255, 0.1);
        }
        
        .webauthn-button {
            width: 100%;
            padding: 12px 20px;
            border: none;
            border-radius: 8px;
            color: white;
            cursor: pointer;
            font-size: 16px;
            font-weight: 500;
            transition: all 0.15s ease;
            text-align: center;
            box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
            margin-bottom: 12px;
        }
        
        .webauthn-button:hover {
            transform: translateY(-2px);
            box-shadow: 0 6px 8px rgba(0, 0, 0, 0.15);
        }
        
        .webauthn-button:active {
            transform: translateY(1px);
            box-shadow: 0 2px 4px rgba(0, 0, 0, 0.15);
        }
        
        .webauthn-button:disabled {
            opacity: 0.7;
            cursor: not-allowed;
            transform: none;
        }
        
        .webauthn-register {
            background-color: #2196F3;
        }
        
        .webauthn-register:hover:not(:disabled) {
            background-color: #1976D2;
        }
        
        .webauthn-authenticate {
            background-color: #FF9800;
        }
        
        .webauthn-authenticate:hover:not(:disabled) {
            background-color: #F57C00;
        }
        
        .webauthn-status {
            padding: 8px 16px;
            border-radius: 6px;
            font-size: 14px;
            font-weight: 500;
            text-align: center;
            margin-top: 12px;
            display: none;
            transition: opacity 0.3s ease;
        }
        
        .webauthn-status.success {
            background: rgba(52, 199, 89, 0.15);
            color: var(--green-color, #34C759);
            border: 1px solid rgba(52, 199, 89, 0.3);
        }
        
        .webauthn-status.error {
            background: rgba(255, 59, 48, 0.15);
            color: var(--red-color, #FF3B30);
            border: 1px solid rgba(255, 59, 48, 0.3);
        }
        
        .webauthn-status.info {
            background: rgba(0, 122, 255, 0.15);
            color: var(--accent-color, #007AFF);
            border: 1px solid rgba(0, 122, 255, 0.3);
        }
        
        /* Emoji Picker Styles */
        .webauthn-emoji-picker {
            display: flex;
            flex-direction: column;
            align-items: center;
            margin-bottom: 20px;
        }
        
        .webauthn-selected-emoji {
            font-size: 4rem;
            width: 80px;
            height: 80px;
            display: flex;
            align-items: center;
            justify-content: center;
            margin-bottom: 1rem;
            border-radius: 20px;
            border: 3px solid rgba(255, 255, 255, 0.3);
            box-shadow: 0 4px 15px rgba(0, 0, 0, 0.2);
            cursor: pointer;
            transition: all 0.3s ease;
        }
        
        .webauthn-selected-emoji:hover {
            transform: scale(1.05);
        }
        
        .webauthn-emoji-grid {
            display: grid;
            grid-template-columns: repeat(6, 1fr);
            gap: 8px;
            max-height: 200px;
            overflow-y: auto;
            padding: 10px;
            border-radius: 8px;
            background: rgba(42, 42, 42, 0.8);
            width: 100%;
            max-width: 300px;
        }
        
        .webauthn-emoji-option {
            font-size: 1.5rem;
            padding: 8px;
            text-align: center;
            cursor: pointer;
            border-radius: 6px;
            transition: all 0.2s ease;
            border: 2px solid transparent;
        }
        
        .webauthn-emoji-option:hover {
            background: rgba(255, 255, 255, 0.1);
            transform: scale(1.1);
        }
        
        .webauthn-emoji-option.selected {
            background: rgba(66, 153, 225, 0.8);
            border-color: rgba(66, 153, 225, 1);
        }
        
        /* Feature Detection Styles */
        .webauthn-not-supported {
            background: rgba(255, 59, 48, 0.15);
            color: var(--red-color, #FF3B30);
            border: 1px solid rgba(255, 59, 48, 0.3);
            padding: 16px;
            border-radius: 8px;
            text-align: center;
            margin-bottom: 16px;
        }
        
        .webauthn-feature-info {
            background: rgba(0, 122, 255, 0.15);
            color: var(--accent-color, #007AFF);
            border: 1px solid rgba(0, 122, 255, 0.3);
            padding: 12px;
            border-radius: 8px;
            font-size: 14px;
            margin-bottom: 16px;
        }
        
        /* Dark Mode Support */
        @media (prefers-color-scheme: dark) {
            .webauthn-form {
                background: var(--bg-secondary, #1e1e1e);
                border-color: var(--border-color, #2d3748);
            }
            
            .webauthn-title {
                color: var(--text-primary, #e2e8f0);
            }
            
            .webauthn-input {
                background: var(--input-bg, #2d3748);
                color: var(--input-text, #e2e8f0);
                border-color: var(--border-color, #2d3748);
            }
            
            .webauthn-status.success {
                background: rgba(48, 209, 88, 0.2);
                color: var(--green-color, #30D158);
            }
            
            .webauthn-status.error {
                background: rgba(255, 69, 58, 0.2);
                color: var(--red-color, #FF453A);
            }
            
            .webauthn-status.info {
                background: rgba(0, 122, 255, 0.2);
                color: var(--accent-color, #007AFF);
            }
        }
        
        /* Mobile Responsive */
        @media (max-width: 768px) {
            .webauthn-container {
                padding: 16px;
            }
            
            .webauthn-form {
                padding: 20px;
            }
            
            .webauthn-title {
                font-size: 1.25rem;
            }
            
            .webauthn-selected-emoji {
                font-size: 3rem;
                width: 60px;
                height: 60px;
            }
            
            .webauthn-emoji-grid {
                grid-template-columns: repeat(5, 1fr);
                max-height: 150px;
            }
            
            .webauthn-emoji-option {
                font-size: 1.25rem;
                padding: 6px;
            }
        }
        """
    }
    
    // MARK: - WebAuthn HTML Templates
    public static func generateWebAuthnRegistrationHTML() -> String {
        return """
        <div class="webauthn-container">
            <form class="webauthn-form" id="webauthn-registration-form">
                <h2 class="webauthn-title">Create Account</h2>
                
                <div class="webauthn-emoji-picker" id="webauthn-emoji-picker">
                    <div class="webauthn-selected-emoji" id="webauthn-selected-emoji">👤</div>
                    <div class="webauthn-emoji-grid" id="webauthn-emoji-grid">
                        <!-- Emoji options will be populated by JavaScript -->
                    </div>
                </div>
                
                <input type="text" 
                       id="webauthn-username" 
                       class="webauthn-input" 
                       placeholder="Enter your username"
                       maxlength="20"
                       required>
                
                <button type="button" 
                        id="webauthn-register-btn" 
                        class="webauthn-button webauthn-register">
                    Register with Passkey
                </button>
                
                <div id="webauthn-status" class="webauthn-status"></div>
            </form>
        </div>
        """
    }
    
    public static func generateWebAuthnLoginHTML() -> String {
        return """
        <div class="webauthn-container">
            <form class="webauthn-form" id="webauthn-login-form">
                <h2 class="webauthn-title">Sign In</h2>
                
                <input type="text" 
                       id="webauthn-username" 
                       class="webauthn-input" 
                       placeholder="Enter username"
                       maxlength="20">
                
                <button type="button" 
                        id="webauthn-authenticate-btn" 
                        class="webauthn-button webauthn-authenticate">
                    Sign In with Passkey
                </button>
                
                <div id="webauthn-status" class="webauthn-status"></div>
            </form>
        </div>
        """
    }
    
    // MARK: - Complete WebAuthn Integration HTML
    public static func generateCompleteWebAuthnHTML(rpId: String, rpName: String? = nil) -> String {
        let actualRpName = rpName ?? rpId
        
        return """
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>WebAuthn - \(actualRpName)</title>
            <style>
                \(generateWebAuthnCSS())
            </style>
        </head>
        <body>
            <div id="webauthn-app">
                <!-- Registration Form -->
                <div id="registration-container" class="webauthn-screen">
                    \(generateWebAuthnRegistrationHTML())
                </div>
                
                <!-- Login Form -->
                <div id="login-container" class="webauthn-screen" style="display: none;">
                    \(generateWebAuthnLoginHTML())
                </div>
                
                <!-- Feature Check -->
                <div id="feature-check" class="webauthn-not-supported" style="display: none;">
                    WebAuthn is not supported in this browser. Please use a modern browser with passkey support.
                </div>
            </div>
            
            <script>
                \(generateWebAuthnJS())
                
                // Initialize WebAuthn for this app
                document.addEventListener('DOMContentLoaded', function() {
                    initializeWebAuthnApp('\(rpId)', '\(actualRpName)');
                });
                
                function initializeWebAuthnApp(rpId, rpName) {
                    // Check WebAuthn support
                    if (!WebAuthn.isSupported()) {
                        document.getElementById('feature-check').style.display = 'block';
                        document.getElementById('webauthn-app').style.display = 'none';
                        return;
                    }
                    
                    const webauthnClient = new WebAuthn.Client(rpId, rpName);
                    
                    // Setup emoji picker
                    setupEmojiPicker();
                    
                    // Setup registration
                    document.getElementById('webauthn-register-btn').addEventListener('click', async function() {
                        const username = document.getElementById('webauthn-username').value.trim();
                        if (!username) {
                            webauthnClient.showStatus('Please enter a username', 'error');
                            return;
                        }
                        
                        try {
                            this.disabled = true;
                            this.textContent = 'Creating account...';
                            
                            const result = await webauthnClient.beginRegistration(username, {
                                additionalData: {
                                    emoji: document.getElementById('webauthn-selected-emoji').textContent
                                }
                            });
                            
                            webauthnClient.showStatus('Account created successfully!', 'success');
                            
                            // Switch to login view or redirect
                            setTimeout(() => {
                                switchToLogin();
                            }, 2000);
                            
                        } catch (error) {
                            webauthnClient.showStatus(error.message, 'error');
                        } finally {
                            this.disabled = false;
                            this.textContent = 'Register with Passkey';
                        }
                    });
                    
                    // Setup authentication
                    document.getElementById('webauthn-authenticate-btn').addEventListener('click', async function() {
                        const username = document.getElementById('webauthn-username').value.trim();
                        
                        try {
                            this.disabled = true;
                            this.textContent = 'Signing in...';
                            
                            const result = await webauthnClient.beginAuthentication(username);
                            
                            webauthnClient.showStatus('Signed in successfully!', 'success');
                            
                            // Handle successful login
                            handleSuccessfulLogin(result);
                            
                        } catch (error) {
                            webauthnClient.showStatus(error.message, 'error');
                        } finally {
                            this.disabled = false;
                            this.textContent = 'Sign In with Passkey';
                        }
                    });
                }
                
                function setupEmojiPicker() {
                    const emojiGrid = document.getElementById('webauthn-emoji-grid');
                    const selectedEmoji = document.getElementById('webauthn-selected-emoji');
                    
                    const emojis = ['👤', '🐶', '🐱', '🐭', '🐹', '🐰', '🦊', '🐻', '🐼', '🐨', '🐯', '🦁', '🐸', '🐵', '🐒', '🦍', '🐕', '🐈'];
                    
                    emojiGrid.innerHTML = emojis.map(emoji => 
                        `<div class="webauthn-emoji-option" onclick="selectEmoji('${emoji}')">${emoji}</div>`
                    ).join('');
                }
                
                function selectEmoji(emoji) {
                    document.getElementById('webauthn-selected-emoji').textContent = emoji;
                    
                    // Update selection
                    document.querySelectorAll('.webauthn-emoji-option').forEach(option => {
                        option.classList.remove('selected');
                    });
                    event.target.classList.add('selected');
                }
                
                function switchToLogin() {
                    document.getElementById('registration-container').style.display = 'none';
                    document.getElementById('login-container').style.display = 'block';
                }
                
                function switchToRegistration() {
                    document.getElementById('login-container').style.display = 'none';
                    document.getElementById('registration-container').style.display = 'block';
                }
                
                function handleSuccessfulLogin(result) {
                    // Override this function to handle successful login in your app
                    console.log('Login successful:', result);
                    
                    // Example: redirect to dashboard
                    // window.location.href = '/dashboard';
                }
            </script>
        </body>
        </html>
        """
    }
} 
