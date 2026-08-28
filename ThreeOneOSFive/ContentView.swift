import SwiftUI

enum ViewState {
    case splash
    case login
    case mainApp
}

struct ContentView: View {
    @State private var currentViewState: ViewState = .splash
    
    var body: some View {
        ZStack {
            // Nền tối không gian sâu thẳm
            LinearGradient(
                colors: [Color(red: 0.02, green: 0.03, blue: 0.07), Color(red: 0.05, green: 0.01, blue: 0.08)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            switch currentViewState {
            case .splash:
                SplashView(currentViewState: $currentViewState)
            case .login:
                LoginView(currentViewState: $currentViewState)
            case .mainApp:
                // MÀN HÌNH CHÍNH
                MainDashboardView(currentViewState: $currentViewState)
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - MÀN HÌNH 1: SPLASH SCREEN (THANH TẢI 0-100%)
struct SplashView: View {
    @Binding var currentViewState: ViewState
    @State private var progress: CGFloat = 0.0
    
    // ĐIỀN LINK ẢNH AVATAR CỦA BẠN VÀO GIỮA 2 DẤU NGOẶC KÉP BÊN DƯỚI
    let avatarURL = "https://i.imgur.com/Thay_Bang_Link_Anh_Cua_Ban.png"
    
    var body: some View {
        VStack(spacing: 25) {
            Spacer()
            
            // AVATAR CHÍNH
            AsyncImage(url: URL(string: avatarURL)) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFill()
                } else if phase.error != nil {
                    // Nếu link lỗi hoặc chưa có link, hiển thị icon mặc định
                    Image(systemName: "cube.transparent.fill")
                        .resizable().scaledToFit().padding(20)
                        .foregroundStyle(LinearGradient(colors: [.cyan, .purple], startPoint: .top, endPoint: .bottom))
                } else {
                    ProgressView().tint(.cyan)
                }
            }
            .frame(width: 120, height: 120)
            .clipShape(Circle())
            .overlay(
                Circle().stroke(LinearGradient(colors: [.cyan, .purple], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 3)
            )
            .shadow(color: .cyan.opacity(0.6), radius: 20)
            .padding(.bottom, 10)
            
            Text("ZENITH SOLITUDE")
                .font(.system(size: 30, weight: .black, design: .rounded))
                .tracking(5)
                .foregroundColor(.white)
                .shadow(color: .cyan.opacity(0.8), radius: 10)
            
            Text("QUANTUM CORE V4.0")
                .font(.system(size: 12, weight: .bold))
                .tracking(4)
                .foregroundColor(.cyan.opacity(0.8))
            
            // THANH TIẾN TRÌNH 0 - 100%
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(progress >= 1.0 ? "Khởi tạo hệ thống thành công" : "Đang giải mã dữ liệu...")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white.opacity(0.8))
                    Spacer()
                    // Hiển thị số %
                    Text("\(Int(progress * 100))%")
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundColor(.cyan)
                        .shadow(color: .cyan, radius: 5)
                }
                
                // Khung thanh chạy
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .frame(height: 8)
                            .foregroundColor(Color.white.opacity(0.1))
                        
                        Capsule()
                            .frame(width: geometry.size.width * progress, height: 8)
                            .foregroundStyle(LinearGradient(colors: [.cyan, .purple], startPoint: .leading, endPoint: .trailing))
                            .shadow(color: .cyan, radius: 8)
                    }
                }
                .frame(height: 8)
            }
            .padding(25)
            .background(Color.black.opacity(0.4))
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20).stroke(Color.cyan.opacity(0.3), lineWidth: 1)
            )
            .padding(.horizontal, 30)
            .padding(.top, 20)
            
            Spacer()
            
            Text("SECURED BY ZENITH LABS")
                .font(.system(size: 10, weight: .semibold))
                .tracking(2)
                .foregroundColor(.gray.opacity(0.5))
                .padding(.bottom, 20)
        }
        .onAppear {
            // Chạy % từ 0 đến 100
            Timer.scheduledTimer(withTimeInterval: 0.03, repeats: true) { timer in
                if self.progress < 1.0 {
                    self.progress += 0.01
                } else {
                    timer.invalidate()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        withAnimation(.easeInOut(duration: 0.6)) {
                            self.currentViewState = .login
                        }
                    }
                }
            }
        }
    }
}

// MARK: - MÀN HÌNH 2: LOGIN (NHẬP KEY)
struct LoginView: View {
    @Binding var currentViewState: ViewState
    @State private var keyInput: String = ""
    @State private var showError = false
    
    // ĐIỀN LINK ẢNH AVATAR CỦA BẠN VÀO ĐÂY NỮA NHÉ
    let avatarURL = "https://i.imgur.com/Thay_Bang_Link_Anh_Cua_Ban.png"
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // AVATAR CHÍNH
            AsyncImage(url: URL(string: avatarURL)) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFill()
                } else if phase.error != nil {
                    Image(systemName: "cube.transparent.fill")
                        .resizable().scaledToFit().padding(15)
                        .foregroundStyle(LinearGradient(colors: [.cyan, .purple], startPoint: .top, endPoint: .bottom))
                } else {
                    ProgressView().tint(.cyan)
                }
            }
            .frame(width: 90, height: 90)
            .clipShape(Circle())
            .overlay(
                Circle().stroke(LinearGradient(colors: [.cyan, .purple], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 2)
            )
            .shadow(color: .purple.opacity(0.5), radius: 10)
            
            VStack(spacing: 6) {
                Text("ZENITH SOLITUDE")
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .tracking(3)
                    .foregroundColor(.white)
                
                Text("Cổng xác thực bản quyền phần cứng")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gray)
            }
            
            // KHUNG NHẬP KEY
            VStack(spacing: 16) {
                HStack(spacing: 12) {
                    Image(systemName: "key.horizontal.fill")
                        .foregroundColor(.cyan)
                    
                    TextField("Nhập mã kích hoạt Zenith Key...", text: $keyInput)
                        .foregroundColor(.white)
                        .accentColor(.cyan)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    
                    Button(action: {
                        if let pasteboard = UIPasteboard.general.string {
                            keyInput = pasteboard
                        }
                    }) {
                        Image(systemName: "doc.on.clipboard.fill")
                            .foregroundColor(.cyan.opacity(0.8))
                            .padding(8)
                            .background(Color.cyan.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
                .padding(14)
                .background(Color.black.opacity(0.4))
                .cornerRadius(14)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(showError ? Color.red : Color.cyan.opacity(0.3), lineWidth: 1)
                )
                
                if showError {
                    Text("⚠️ Mã kích hoạt không hợp lệ!")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.red)
                }
                
                // NÚT XÁC THỰC
                Button(action: {
                    if keyInput == "zenith2026" || keyInput == "123" {
                        withAnimation(.spring()) {
                            currentViewState = .mainApp
                        }
                    } else {
                        withAnimation {
                            showError = true
                        }
                    }
                }) {
                    Text("KÍCH HOẠT TRUY CẬP")
                        .font(.system(size: 14, weight: .bold))
                        .tracking(1.5)
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(
                            LinearGradient(colors: [.cyan, Color(red: 0.4, green: 0.8, blue: 1.0)], startPoint: .leading, endPoint: .trailing)
                        )
                        .cornerRadius(14)
                        .shadow(color: .cyan.opacity(0.4), radius: 8, x: 0, y: 4)
                }
                
                Divider().background(Color.white.opacity(0.1)).padding(.vertical, 4)
                
                Button(action: {
                    if let url = URL(string: "https://solitudepremium.click") {
                        UIApplication.shared.open(url)
                    }
                }) {
                    HStack {
                        Image(systemName: "globe")
                        Text("NHẬN MÃ KEY TRÊN HỆ THỐNG")
                            .font(.system(size: 12, weight: .bold))
                        Spacer()
                        Image(systemName: "arrow.up.right")
                    }
                    .foregroundColor(.cyan)
                }
            }
            .padding(22)
            .background(.ultraThinMaterial) // Kính mờ siêu đẹp
            .cornerRadius(24)
            .overlay(
                RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
            .padding(.horizontal, 24)
            
            Spacer()
        }
    }
}

// MARK: - MÀN HÌNH CHÍNH SAU KHI VÀO
struct MainDashboardView: View {
    @Binding var currentViewState: ViewState
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(Color.cyan.opacity(0.1))
                    .frame(width: 100, height: 100)
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.cyan)
                    .shadow(color: .cyan, radius: 10)
            }
            
            Text("CHÀO MỪNG ĐẾN VỚI ZENITH")
                .font(.system(size: 22, weight: .heavy))
                .foregroundColor(.white)
                .tracking(2)
            
            Text("Không gian làm việc mã hóa của bạn đã sẵn sàng hoạt động.")
                .font(.system(size: 13))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button(action: {
                withAnimation {
                    currentViewState = .login
                }
            }) {
                Text("ĐĂNG XUẤT PHIÊN LÀM VIỆC")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.red)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.red.opacity(0.3), lineWidth: 1))
            }
            .padding(.top, 10)
            
            Spacer()
        }
    }
}
