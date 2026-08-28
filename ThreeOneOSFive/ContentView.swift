import SwiftUI

struct ContentView: View {
    @State private var isAuthenticated: Bool = false
    // Khởi tạo state quản lý phiên điều hướng gốc tương thích với FilesTabSwitcherView
    @State private var tabNavigationState = AppTabNavigationState()
    
    var body: some View {
        ZStack {
            // Nền tối không gian đồng bộ với toàn bộ dự án
            Color(red: 0.02, green: 0.01, blue: 0.05)
                .ignoresSafeArea()
            
            if !isAuthenticated {
                // Màn hình nhập Key kích hoạt
                RealLoginView(isAuthenticated: $isAuthenticated)
            } else {
                // Vào thẳng giao diện chính thực sự của ứng dụng (FilesTabSwitcherView)
                // Truyền đúng kiểu Binding ($tabNavigationState) theo yêu cầu của hệ thống
                FilesTabSwitcherView(session: $tabNavigationState)
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - MÀN HÌNH ĐĂNG NHẬP XÁC THỰC KEY
struct RealLoginView: View {
    @Binding var isAuthenticated: Bool
    @State private var keyInput: String = ""
    @State private var showError: Bool = false
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            VStack(spacing: 8) {
                Text("ZENITH SOLITUDE")
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                Text("SECURE GATEWAY")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.cyan)
            }
            
            VStack(spacing: 16) {
                TextField("Nhập mã kích hoạt Key...", text: $keyInput)
                    .textFieldStyle(.plain)
                    .padding(14)
                    .background(Color.black.opacity(0.5))
                    .cornerRadius(12)
                    .foregroundColor(.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(showError ? Color.red : Color.cyan.opacity(0.5), lineWidth: 1)
                    )
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                
                if showError {
                    Text("⚠️ Mã kích hoạt không hợp lệ!")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.red)
                }
                
                Button(action: {
                    // Kiểm tra key (có thể thay đổi điều kiện tùy ý)
                    if keyInput == "zenith2026" || keyInput == "123" || !keyInput.isEmpty {
                        withAnimation {
                            isAuthenticated = true
                        }
                    } else {
                        withAnimation {
                            showError = true
                        }
                    }
                }) {
                    Text("TRUY CẬP HỆ THỐNG")
                        .font(.system(size: 13, weight: .black))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(colors: [.cyan, .purple], startPoint: .leading, endPoint: .trailing)
                        )
                        .cornerRadius(12)
                }
            }
            .padding(.horizontal, 30)
            
            Spacer()
        }
    }
}
