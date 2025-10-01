import SwiftUI
import AuthenticationServices

struct SignInView: View {
    @State private var isLoading = false
    @State private var showWelcome = false
    @State private var showButton = false
    @State private var logoScale: CGFloat = 0.5
    @State private var logoRotation: Double = 0
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Animated background
                AnimatedBackground()
                
                VStack(spacing: 0) {
                    Spacer()
                    
                    // Animated App Logo
                    VStack(spacing: 24) {
                        ZStack {
                            // Outer glow effect
                            Circle()
                                .fill(
                                    RadialGradient(
                                        gradient: Gradient(colors: [
                                            Color.orange.opacity(0.3),
                                            Color.clear
                                        ]),
                                        center: .center,
                                        startRadius: 50,
                                        endRadius: 80
                                    )
                                )
                                .frame(width: 160, height: 160)
                                .scaleEffect(logoScale)
                                .animation(
                                    Animation.easeInOut(duration: 2)
                                        .repeatForever(autoreverses: true),
                                    value: logoScale
                                )
                            
                            // Main logo
                            Circle()
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(stops: [
                                            .init(color: Color.orange, location: 0.0),
                                            .init(color: Color.orange.opacity(0.8), location: 0.5),
                                            .init(color: Color.pink.opacity(0.9), location: 1.0)
                                        ]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 120, height: 120)
                                .overlay(
                                    Image(systemName: "pencil.and.ruler.fill")
                                        .font(.system(size: 60, weight: .light))
                                        .foregroundColor(.white)
                                        .rotationEffect(.degrees(logoRotation))
                                )
                                .shadow(color: Color.orange.opacity(0.4), radius: 15, x: 0, y: 8)
                                .scaleEffect(logoScale)
                        }
                        
                        // App Name with typewriter effect
                        if showWelcome {
                            Text("MemorAIze")
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                                .foregroundStyle(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            Color.orange,
                                            Color.pink.opacity(0.7)
                                        ]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .transition(.opacity.combined(with: .scale))
                        }
                    }
                    
                    Spacer()
                    
                    // Welcome Message
                    if showWelcome {
                        VStack(spacing: 20) {
                            Text("ようこそ")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                            
                            Text("続行するにはApple IDでサインインしてください")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .lineSpacing(4)
                                .padding(.horizontal, 40)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                        .animation(.easeOut(duration: 0.8).delay(0.3), value: showWelcome)
                    }
                    
                    Spacer()
                    
                    // Sign in Button Area
                    VStack(spacing: 24) {
                        if showButton {
                            // Custom Sign in with Apple Button
                            Button(action: {
                                handleSignInTap()
                            }) {
                                HStack(spacing: 12) {
                                    if isLoading {
                                        ProgressView()
                                            .scaleEffect(0.9)
                                            .tint(.white)
                                    } else {
                                        Image(systemName: "applelogo")
                                            .font(.system(size: 20, weight: .medium))
                                            .foregroundColor(.white)
                                    }
                                    
                                    Text(isLoading ? "サインイン中..." : "Appleでサインイン")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundColor(.white)
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(
                                    RoundedRectangle(cornerRadius: 28)
                                        .fill(Color.black)
                                        .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
                                )
                                .scaleEffect(isLoading ? 0.95 : 1.0)
                                .animation(.easeInOut(duration: 0.1), value: isLoading)
                            }
                            .disabled(isLoading)
                            .padding(.horizontal, 32)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                        
                        // Security note
                        if showButton && !isLoading {
                            HStack(spacing: 6) {
                                Image(systemName: "lock.shield.fill")
                                    .font(.caption)
                                    .foregroundStyle(
                                        LinearGradient(
                                            gradient: Gradient(colors: [
                                                Color.orange,
                                                Color.pink.opacity(0.7)
                                            ]),
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                
                                Text("安全で高速なサインイン")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .transition(.opacity)
                            .animation(.easeOut(duration: 0.5).delay(0.8), value: showButton)
                        }
                    }
                    
                    Spacer()
                    
                    // Terms and Privacy
                    if showButton {
                        VStack(spacing: 12) {
                            Text("続行することで、以下に同意したものとみなされます")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                            
                            HStack(spacing: 8) {
                                Button("利用規約") {
                                    // Handle terms action
                                }
                                .font(.caption2)
                                .foregroundStyle(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            Color.orange,
                                            Color.pink.opacity(0.7)
                                        ]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                
                                Text("•")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                
                                Button("プライバシーポリシー") {
                                    // Handle privacy policy action
                                }
                                .font(.caption2)
                                .foregroundStyle(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            Color.orange,
                                            Color.pink.opacity(0.7)
                                        ]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                            }
                        }
                        .padding(.bottom, 40)
                        .transition(.opacity)
                        .animation(.easeOut(duration: 0.5).delay(1.0), value: showButton)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .onAppear {
            startAnimations()
        }
    }
    
    private func startAnimations() {
        // Logo scale animation
        withAnimation(.easeOut(duration: 1.0)) {
            logoScale = 1.0
        }
        
        // Logo rotation
        withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
            logoRotation = 360
        }
        
        // Welcome text
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeOut(duration: 0.8)) {
                showWelcome = true
            }
        }
        
        // Sign in button
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeOut(duration: 0.8)) {
                showButton = true
            }
        }
    }
    
    private func handleSignInTap() {
        
        withAnimation(.easeInOut(duration: 0.2)) {
            isLoading = true
        }
        
        // Simulate sign in process
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation(.easeInOut(duration: 0.2)) {
                isLoading = false
            }
            // Handle success or error
            
            dismiss()
        }
    }
}

struct SignInView_Previews: PreviewProvider {
    static var previews: some View {
        SignInView()
            .preferredColorScheme(.light)
        
        SignInView()
            .preferredColorScheme(.dark)
    }
}
