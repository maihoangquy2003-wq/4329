import SwiftUI

struct ContentView: View {
    @State private var isLoggedIn: Bool = false
    // Khởi tạo đúng kiểu FilesTabSession theo yêu cầu của FilesTabSwitcherView
    @State private var tabSession = FilesTabSession()
    
    var body: some View {
        ZStack {
            // Nền đen tuyền tối giản, sang trọng
            Color.black
                .ignoresSafeArea()
            
            if !isLoggedIn {
                MinimalLoginView(isLoggedIn: $isLoggedIn)
            } else {
                // Vào thẳng trang chủ chính của ứng dụng
                FilesTabSwitcherView(session: $tabSession)
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - MÀN HÌNH ĐĂNG NHẬP TRẮNG ĐEN TỐI GIẢN (MINIMALIST BLACK & WHITE)
struct MinimalLoginView: View {
    @Binding var isLoggedIn: Bool
    @State private var accessKey: String = ""
    @State private var hasError: Bool = false
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Tiêu đề tối giản
            VStack(spacing: 12) {
                Text("SOLITUDE")
                    .font(.system(size: 28, weight: .ultraLight, design: .monospaced))
                    .tracking(8)
                    .foregroundColor(.white)
                
                Rectangle()
                    .fill(Color.white)
                    .frame(width: 32, height: 1)
                
                Text("SECURE ACCESS")
                    .font(.system(size: 10, weight: .regular, design: .monospaced))
                    .tracking(4)
                    .foregroundColor(.gray)
            }
            
            // Khung nhập Key phong cách monochrome
            VStack(spacing: 16) {
                SecureField("", text: $accessKey, prompt: Text("Nhập mã truy cập...").foregroundColor(.gray))
                    .font(.system(size: 14, design: .monospaced))
                    .padding(16)
                    .background(Color(.systemGray6).opacity(0.1))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(hasError ? Color.white : Color.gray.opacity(0.4), lineWidth: 0.5)
                    )
                    .foregroundColor(.white)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                
                if hasError {
                    Text("Mã truy cập không hợp lệ.")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.white.opacity(0.7))
                }
                
                Button(action: {
                    if accessKey == "zenith2026" || accessKey == "123" || !accessKey.isEmpty {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isLoggedIn = true
                        }
                    } else {
                        withAnimation {
                            hasError = true
                        }
                    }
                }) {
                    Text("XÁC THỰC")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .tracking(3)
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.white)
                        .cornerRadius(8)
                }
            }
            .padding(.horizontal, 40)
            
            Spacer()
            
            // Footer
            Text("SYSTEM V2.0 • READY")
                .font(.system(size: 9, design: .monospaced))
                .tracking(2)
                .foregroundColor(.gray.opacity(0.5))
                .padding(.bottom, 30)
        }
    }
}
