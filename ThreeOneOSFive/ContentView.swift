import SwiftUI

// Trạng thái của toàn bộ App
enum AppState {
    case splash
    case login
    case mainApp
}

struct ContentView: View {
    @State private var currentState: AppState = .splash
    
    var body: some View {
        ZStack {
            // Nền đen tuyền cho toàn bộ app
            Color(red: 0.05, green: 0.0, blue: 0.02).ignoresSafeArea()
            
            // Điều hướng các màn hình
            switch currentState {
            case .splash:
                SplashView(currentState: $currentState)
            case .login:
                LoginView(currentState: $currentState)
            case .mainApp:
                // KHI NHẬP ĐÚNG KEY SẼ NHẢY VÀO ĐÂY
                // Bạn có thể đổi Text này thành View gốc của app 3105 (ví dụ: FileBrowserView)
                VStack {
                    Text("ĐĂNG NHẬP THÀNH CÔNG")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                        .shadow(color: .green, radius: 10)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - MÀN HÌNH 1: SPLASH SCREEN (TẢI THANH TIẾN ĐỘ)
struct SplashView: View {
    @Binding var currentState: AppState
    @State private var progress: CGFloat = 0.0
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            // Logo (Tạm dùng icon khiên, bạn có thể thay bằng tên file ảnh thật sau)
            ZStack {
                Circle()
                    .stroke(Color.red, lineWidth: 2)
                    .frame(width: 120, height: 120)
                    .shadow(color: .red, radius: 15)
                
                Image(systemName: "shield.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 60, height: 60)
                    .foregroundColor(.white)
            }
            .padding(.bottom, 20)
            
            Text("HEADLOCK KEZIS")
                .font(.system(size: 32, weight: .heavy, design: .default))
                .foregroundColor(.white)
                .shadow(color: .red, radius: 10)
            
            Text("POWERED BY MITXY SECURITY")
                .font(.caption)
                .fontWeight(.bold)
                .tracking(2) // Khoảng cách chữ
                .foregroundColor(Color(red: 0.8, green: 0.4, blue: 0.4))
            
            // Khung chứa thanh Loading
            VStack(alignment: .leading, spacing: 15) {
                HStack {
                    Text(progress >= 1.0 ? "Khởi động Hệ thống Hoàn tất!" : "Đang tải dữ liệu...")
                        .font(.footnote)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    Spacer()
                    Text("\(Int(progress * 100))%")
                        .font(.footnote)
                        .fontWeight(.bold)
                        .foregroundColor(.red)
                }
                
                // Thanh chạy (Progress Bar)
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .frame(height: 6)
                            .foregroundColor(Color.red.opacity(0.2))
                        
                        Capsule()
                            .frame(width: geometry.size.width * progress, height: 6)
                            .foregroundColor(.red)
                            .shadow(color: .red, radius: 5)
                    }
                }
                .frame(height: 6)
                
                HStack {
                    Spacer()
                    Circle().frame(width: 6, height: 6).foregroundColor(.green)
                    Text("Anti-Ban v2.8 • Kernel Sandboxed • Verified")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                    Spacer()
                }
            }
            .padding(25)
            .background(Color.black)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.red.opacity(0.5), lineWidth: 1)
            )
            .padding(.horizontal, 30)
            .padding(.top, 30)
            
            Spacer()
            
            Text("MITXY SECURITY ARCHITECTURE • 2026")
                .font(.caption2)
                .fontWeight(.bold)
                .tracking(1)
                .foregroundColor(.red.opacity(0.5))
                .padding(.bottom, 20)
        }
        .onAppear {
            // Hiệu ứng thanh chạy từ 0 đến 100% trong khoảng 2.5 giây
            Timer.scheduledTimer(withTimeInterval: 0.025, repeats: true) { timer in
                if self.progress < 1.0 {
                    self.progress += 0.01
                } else {
                    timer.invalidate()
                    // Dừng 0.5 giây khi đầy cây rồi mới chuyển sang màn Login
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        withAnimation(.easeInOut(duration: 0.5)) {
                            self.currentState = .login
                        }
                    }
                }
            }
        }
    }
}

// MARK: - MÀN HÌNH 2: LOGIN (NHẬP KEY)
struct LoginView: View {
    @Binding var currentState: AppState
    @State private var keyInput: String = ""
    @State private var showErrorMessage = false
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            ZStack {
                Circle()
                    .stroke(Color.red, lineWidth: 2)
                    .frame(width: 120, height: 120)
                    .shadow(color: .red, radius: 15)
                
                Image(systemName: "shield.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 60, height: 60)
                    .foregroundColor(.white)
            }
            .padding(.bottom, 20)
            
            Text("HEADLOCK KEZIS")
                .font(.system(size: 32, weight: .heavy, design: .default))
                .foregroundColor(.white)
                .shadow(color: .red, radius: 10)
            
            Text("— MOD MENU ONLINE —")
                .font(.caption)
                .fontWeight(.bold)
                .tracking(2)
                .foregroundColor(Color(red: 0.8, green: 0.4, blue: 0.4))
            
            // Khung nhập Key
            VStack(spacing: 20) {
                // Ô TextField
                HStack {
                    Image(systemName: "key.fill")
                        .foregroundColor(.red)
                    
                    TextField("Nhập mã Key (VIP hoặc FREE)...", text: $keyInput)
                        .foregroundColor(.white)
                        .accentColor(.red) // Màu con trỏ chuột
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    
                    Button(action: {
                        // Nút dán (Paste)
                        if let clipboard = UIPasteboard.general.string {
                            keyInput = clipboard
                        }
                    }) {
                        Image(systemName: "doc.on.clipboard")
                            .foregroundColor(.red.opacity(0.7))
                            .padding(8)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
                .padding()
                .background(Color.white.opacity(0.05))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.red.opacity(0.5), lineWidth: 1)
                )
                
                // Cảnh báo sai key
                if showErrorMessage {
                    Text("Key không hợp lệ hoặc đã hết hạn!")
                        .font(.caption)
                        .foregroundColor(.red)
                        .transition(.opacity)
                }
                
                // Nút LOGIN
                Button(action: {
                    // LOGIC KIỂM TRA KEY TẠI ĐÂY
                    if keyInput == "123" {
                        withAnimation(.easeInOut(duration: 0.5)) {
                            currentState = .mainApp
                        }
                    } else {
                        withAnimation {
                            showErrorMessage = true
                        }
                    }
                }) {
                    HStack {
                        Image(systemName: "door.right.hand.open")
                        Text("LOGIN")
                            .fontWeight(.bold)
                            .tracking(1)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        LinearGradient(gradient: Gradient(colors: [Color.red, Color(red: 0.6, green: 0, blue: 0)]), startPoint: .top, endPoint: .bottom)
                    )
                    .cornerRadius(15)
                    .shadow(color: .red.opacity(0.6), radius: 8, x: 0, y: 4)
                }
                
                Divider().background(Color.red.opacity(0.3)).padding(.vertical, 5)
                
                // Nút lấy key
                Button(action: {
                    // Mở link web lấy key
                    if let url = URL(string: "https://solitudepremium.click") {
                        UIApplication.shared.open(url)
                    }
                }) {
                    HStack {
                        Image(systemName: "questionmark.circle")
                        Text("CHƯA CÓ KEY? LẤY KEY TẠI ĐÂY")
                            .font(.caption)
                            .fontWeight(.bold)
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .foregroundColor(Color(red: 0.8, green: 0.4, blue: 0.4))
                }
            }
            .padding(25)
            .background(Color.black)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.red.opacity(0.3), lineWidth: 1)
            )
            .padding(.horizontal, 30)
            .padding(.top, 20)
            
            Spacer()
            
            // Footer Anti-ban
            HStack {
                Circle().frame(width: 8, height: 8).foregroundColor(.green)
                Text("Hệ thống bảo vệ Anti-Ban MITXY v2.8 Online")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.green)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 20)
            .background(Color.black)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.red.opacity(0.2), lineWidth: 1)
            )
            .padding(.bottom, 20)
        }
    }
}
