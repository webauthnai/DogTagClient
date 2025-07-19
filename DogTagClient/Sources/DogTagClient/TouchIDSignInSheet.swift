import SwiftUI
import LocalAuthenticationEmbeddedUI

public struct TouchIDSignInSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var authenticationContext = LAContext()
    @State private var isPresented = false
    @State private var dialogOffset: CGFloat = 50
    @State private var backgroundOpacity: Double = 0
    @State private var HelloWorldText: String = "Hello, World!"
    @State private var isPressed: Bool = false

    // Add these state variables to your view
    @FocusState private var isFocused: Bool
    @State private var cursorVisible: Bool = false
    
    let siteName: String
    let credentialName: String
    let onContinue: () -> Void
    let onCancel: () -> Void
    let onDismiss: () -> Void
    
    public init(siteName: String = "xcf.ai", credentialName: String = "XCF Admin", onContinue: @escaping () -> Void = {}, onCancel: @escaping () -> Void = {}, onDismiss: @escaping () -> Void = {}) {
        self.siteName = siteName
        self.credentialName = credentialName
        self.onContinue = onContinue
        self.onCancel = onCancel
        self.onDismiss = onDismiss
    }
    
    public var body: some View {
        ZStack {
            backgroundView
            dialogContent
        }
        .onAppear {
            animateIn()
        }
    }
    
    private var backgroundView: some View {
        Color.black.opacity(backgroundOpacity)
            .ignoresSafeArea()
            .onTapGesture {
                animateOut(delay: 0) {
                    onCancel()
                    onDismiss()
                }
            }
    }
    
    private var dialogContent: some View {
        VStack(spacing: 0) {
            headerSection
            appIconSection
            titleSection
            descriptionSection
            touchIDSection
            // MARK: - Usage
             VStack(spacing: 20) {
                 passwordField
                 continueButton
             }
             .padding(20)
            
            
        }
        .background(dialogBackground)
        .padding(.horizontal, 40)
        .offset(y: dialogOffset)
        .scaleEffect(isPresented ? 1.0 : 0.95)
        .opacity(isPresented ? 1.0 : 0.0)
    }
    
    private var headerSection: some View {
        HStack {
            signInLabel
            Spacer()
            cancelButton
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .padding(.bottom, 32)
    }

  
    // MARK: - Common Styles
    private var commonFieldStyle: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.black.opacity(0.3))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isFocused ? Color.blue.opacity(0.6) : Color.white.opacity(0.15),
                        lineWidth: isFocused ? 1.5 : 1
                    )
            )
    }

    // MARK: - Password Field
    private var passwordField: some View {
        ZStack(alignment: .center) {
            // Placeholder
            if HelloWorldText.isEmpty && !isFocused {
                Text("Enter your password")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.4))
            }
            
            // Password dots - centered
            HStack(spacing: 4) {
                ForEach(0..<HelloWorldText.count, id: \.self) { _ in
                    Circle()
                        .fill(Color.white.opacity(0.8))
                        .frame(width: 8, height: 8)
                }
                
                // Cursor
                if isFocused {
                    Rectangle()
                        .fill(Color.white.opacity(0.9))
                        .frame(width: 1.5, height: 18)
                        .opacity(cursorVisible ? 1 : 0)
                        .onAppear {
                            withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                                cursorVisible.toggle()
                            }
                        }
                }
            }
            .frame(maxWidth: .infinity)
        }
        .frame(height: 52)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.3))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            isFocused ? Color.blue.opacity(0.6) : Color.white.opacity(0.15),
                            lineWidth: isFocused ? 1.5 : 1
                        )
                )
        )
        .onTapGesture { isFocused = true }
        .onAppear { cursorVisible = true }
        .background(
            SecureField("", text: $HelloWorldText)
                .opacity(0)
                .focused($isFocused)
                .onSubmit { handleContinue() }
        )
    }

    private var continueButton: some View {
        Button(action: {
            print("Continue pressed")
            // Your action here
        }) {
            HStack(spacing: 8) {
                Text("Continue with Password")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                
                Image(systemName: "arrow.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.3))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .opacity(isPressed ? 0.8 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }

    // MARK: - Action
    private func handleContinue() {
        print("Continue: \(HelloWorldText)")
        // Your logic here
    }

    // MARK: - Usage
    // VStack(spacing: 16) {
    //     passwordField
    //     continueButton
    // }
    // .padding(.horizontal, 20)
    
    private var signInLabel: some View {
        HStack(spacing: 8) {
            
            Image(internalSystemName: "apple.passwords")
                .symbolRenderingMode(.palette)
                .foregroundStyle(.orange, .green, .blue)
                .font(.system(size: 16, weight: .medium))
            
            Text("Sign In")
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(.white)
        }
    }
    
    private var cancelButton: some View {
        Button("Cancel") {
            authenticationContext.invalidate()
            animateOut(delay: 0) {
                onCancel()
                onDismiss()
            }
        }
        .font(.system(size: 15, weight: .medium))
        .foregroundColor(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                )
        )
        .contentShape(Rectangle())
        .buttonStyle(.plain)
    }
    
    private var appIconSection: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color.white)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.black.opacity(0.3), lineWidth: 5)
            )
            .frame(width: 80, height: 80)
            .overlay(appIconContent)
            .padding(.bottom, 32)
    }
    
    private var appIconContent: some View {
        VStack(spacing: 2) {
            keyIcon
        }
    }
    
    private var keyIcon: some View {
        Image(internalSystemName: "apple.passwords")
            .symbolRenderingMode(.palette)
            .foregroundStyle(.blue, .green, .orange)
            .font(.system(size: 40, weight: .medium))
    }
    
    private var keyLines: some View {
        VStack(spacing: 2) {
            Rectangle()
                .fill(Color.white)
                .frame(width: 8, height: 2)
            Rectangle()
                .fill(Color.white)
                .frame(width: 6, height: 2)
            Rectangle()
                .fill(Color.white)
                .frame(width: 10, height: 2)
        }
    }
    
    private var titleSection: some View {
        Text("Use Touch ID to sign in?")
            .font(.system(size: 24, weight: .medium))
            .foregroundColor(.white)
            .padding(.bottom, 24)
    }
    
    private var descriptionSection: some View {
        Text("You will be signed in to \"\(siteName)\" with your shared passkey for \"\(credentialName)\".")
            .font(.system(size: 16))
            .foregroundColor(.white.opacity(0.8))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
    }
    
    private var touchIDSection: some View {
        LAAuthenticationViewWrapper(
            context: authenticationContext,
            onSuccess: {
                print("✅ Touch ID authentication succeeded! _")
                animateOut(delay: 2.0) {
                    onContinue()
                    onDismiss()
                }
            },
            onFailure: {
                print("❌ Touch ID authentication failed")
                animateOut(delay: 0.1) {
                    onCancel()
                    onDismiss()
                }
            }
        )
        .frame(width: 80, height: 80)
        .padding(.bottom, 32)
    }
    
    private var continueButtonSection: some View {
        Button(action: {
            //startAuthentication()
        }) {
            HStack(spacing: 8) {
                Image(systemName: "pass")
                    .font(.system(size: 16, weight: .medium))
                
                Text("Continue with Passsword")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.25),
                                Color.white.opacity(0.15)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.3), lineWidth: 0.5)
                    )
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 32)
        .padding(.bottom, 32)
    }
    
    private var dialogBackground: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(Color.black.opacity(0.9))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
    }
    
    private func animateIn() {
        withAnimation(.easeIn(duration: 0.1)) {
            backgroundOpacity = 0.5
            isPresented = true
            dialogOffset = 0
        }
       
    }
    
    private func animateOut(delay: Double, completion: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            withAnimation(.easeIn(duration: 0.2)) {
                backgroundOpacity = 0
                isPresented = false
                dialogOffset = 30
            }
        }
        
        // Delay the completion to allow animation to finish
        DispatchQueue.main.asyncAfter(deadline: .now() + delay + 0.5) {
            completion()
        }
    }
}

// MARK: - LAAuthenticationView Wrapper for SwiftUI
struct LAAuthenticationViewWrapper: NSViewRepresentable {
    let context: LAContext
    let onSuccess: () -> Void
    let onFailure: () -> Void
    
    init(context: LAContext, onSuccess: @escaping () -> Void = {}, onFailure: @escaping () -> Void = {}) {
        self.context = context
        self.onSuccess = onSuccess
        self.onFailure = onFailure
    }
    
    func makeNSView(context: Context) -> NSView {
        // Create container view like Apple's example
        let containerView = NSView()
        
        // Check if biometrics are available first
        var error: NSError?
        let canEvaluate = self.context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        
        print("🔧 Can evaluate biometrics: \(canEvaluate)")
        if let error = error {
            print("🔧 Biometric error: \(error.localizedDescription)")
        }
        
        // Follow Apple's exact pattern from loadView()
        let laView = LAAuthenticationView(context: self.context, controlSize: .large)
        
        // Add as subview exactly like Apple's documentation
        containerView.addSubview(laView)
        laView.translatesAutoresizingMaskIntoConstraints = false
        
        // Add proper constraints like Apple's example suggests
        NSLayoutConstraint.activate([
            laView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            laView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            laView.widthAnchor.constraint(equalToConstant: 80),
            laView.heightAnchor.constraint(equalToConstant: 80),
            containerView.widthAnchor.constraint(equalToConstant: 80),
            containerView.heightAnchor.constraint(equalToConstant: 80)
        ])
        
        print("🔧 Created LAAuthenticationView with proper constraints")
        
        // Follow Apple's viewDidAppear pattern - call evaluatePolicy after view is attached
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.2) {
            print("🔧 Calling evaluatePolicy to show TouchID icon...")
            self.context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometricsOrWatch,
                localizedReason: "Use Touch ID to sign in"
                
            ) { success, error in
                if success {
                    print("🔧 Icon display authentication result: \(success)")
                    onSuccess()
                }
                
                if let error = error {
                    print("🔧 Icon display error: \(error.localizedDescription)")
                    onFailure()
                }
            }
           
        }
        
        return containerView
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        // No updates needed
    }
}

#Preview {
    TouchIDSignInSheet()
} 

@_silgen_name("$s7SwiftUI5ImageV19_internalSystemNameACSS_tcfC")
func _swiftUI_image(internalSystemName: String) -> Image?

extension Image {
    init?(internalSystemName systemName: String) {
        guard let systemImage = _swiftUI_image(internalSystemName: systemName) else {
            return nil
        }

        self = systemImage
    }
}
