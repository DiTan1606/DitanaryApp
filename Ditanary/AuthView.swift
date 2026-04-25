import SwiftUI
import Supabase

struct AuthView: View {
    @State private var isLogin = true
    
    @State private var email = ""
    @State private var password = ""
    @State private var displayName = ""
    
    @State private var isLoading = false
    @State private var errorMessage = ""
    
    // (Removed unused Codable metadata struct.)
    
    var body: some View {
        ZStack {
            // Background
            Color(UIColor.systemBackground)
                .edgesIgnoringSafeArea(.all)
            
            VStack {
                Spacer()
                
                // Logo
                Image("AppLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 300, height: 300)
                
                VStack(spacing: 20) {
                    if !isLogin {
                        CustomTextField(icon: "person.text.rectangle", placeholder: "Display Name", text: $displayName)
                    }
                    
                    CustomTextField(icon: "person.fill", placeholder: "Username", text: $email, keyboardType: .emailAddress)
                    
                    CustomTextField(icon: "lock.fill", placeholder: "Password", text: $password, isSecure: true)
                    
                    if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                            .multilineTextAlignment(.center)
                    }
                    
                    Button(action: {
                        Task { await authenticate() }
                    }) {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color(red: 0/255, green: 132/255, blue: 255/255))
                                .cornerRadius(30)
                                .shadow(color: Color.blue.opacity(0.3), radius: 10, x: 0, y: 5)
                        } else {
                            Text(isLogin ? "SIGN IN" : "SIGN UP")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color(red: 0/255, green: 132/255, blue: 255/255))
                                .cornerRadius(30)
                                .shadow(color: Color.blue.opacity(0.3), radius: 10, x: 0, y: 5)
                        }
                    }
                    .disabled(isLoading || email.isEmpty || password.isEmpty || (!isLogin && displayName.isEmpty))
                    .opacity((isLoading || email.isEmpty || password.isEmpty || (!isLogin && displayName.isEmpty)) ? 0.6 : 1.0)
                    .padding(.top, 10)
                }
                .padding(.horizontal, 30)
                
                Spacer()
                
                VStack(spacing: 10) {
                    Text(isLogin ? "Don't have an account?" : "Already have an account?")
                        .foregroundColor(.secondary)
                        .font(.system(size: 14))
                    
                    Button(action: {
                        withAnimation {
                            isLogin.toggle()
                            errorMessage = ""
                        }
                    }) {
                        Text(isLogin ? "SIGN UP NOW" : "SIGN IN NOW")
                            .fontWeight(.bold)
                            .foregroundColor(Color(red: 0/255, green: 132/255, blue: 255/255))
                            .font(.system(size: 14))
                    }
                }
            }
        }
    }
    
    func authenticate() async {
        isLoading = true
        errorMessage = ""
        
        do {
            if isLogin {
                try await supabase.auth.signIn(email: email, password: password)
            } else {
                let metadata: [String: AnyJSON] = [
                    "full_name": .string(displayName),
                    "display_name": .string(displayName),
                    "name": .string(displayName)
                ]

                try await supabase.auth.signUp(
                    email: email,
                    password: password,
                    data: metadata
                )
            }
        } catch {
            errorMessage = "Lỗi: \(error.localizedDescription)"
            print("Auth error: \(error)")
        }
        
        isLoading = false
    }
}

struct CustomTextField: View {
    var icon: String
    var placeholder: String
    @Binding var text: String
    var isSecure: Bool = false
    var keyboardType: UIKeyboardType = .default
    
    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: icon)
                .foregroundColor(.gray)
                .font(.system(size: 18))
                .frame(width: 24)
            
            if isSecure {
                SecureField(placeholder, text: $text)
                    .foregroundColor(.primary)
                    .accentColor(.blue)
            } else {
                TextField(placeholder, text: $text)
                    .keyboardType(keyboardType)
                    .autocapitalization(.none)
                    .foregroundColor(.primary)
                    .accentColor(.blue)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(30)
        .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 4)
    }
}
