import SwiftUI

enum ViewState {
    case login
    case mainApp
}

struct ContentView: View {
    @State private var currentViewState: ViewState = .login
    
    var body: some View {
        ZStack {
            // Nền không gian tối thẳm huyền bí, sang trọng
            LinearGradient(
                colors: [Color(red: 0.02, green: 0.01, blue: 0.06), Color(red: 0.05, green: 0.02, blue: 0.10)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // Hiệu ứng ánh sáng nền neon động mượt mà
            BackgroundGlowEffect()
            
            switch currentViewState {
            case .login:
                NeonLoginView(currentViewState: $currentViewState)
            case .mainApp:
                MainDashboardView(currentViewState: $currentViewState)
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - HIỆU ỨNG ÁNH SÁNG NỀN NEON
struct BackgroundGlowEffect: View {
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.cyan.opacity(0.15))
                .frame(width: 300, height: 300)
                .blur(radius: 80)
                .offset(x: isAnimating ? -100 : 100, y: isAnimating ? -150 : 150)
            
            Circle()
                .fill(Color.purple.opacity(0.15))
                .frame(width: 300, height: 300)
                .blur(radius: 80)
                .offset(x: isAnimating ? 120 : -120, y: isAnimating ? 160 : -160)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 6).repeatForever(autoreverses: true)) {
                isAnimating.toggle()
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - MÀN HÌNH ĐĂNG NHẬP NEON ĐẲNG CẤP
struct NeonLoginView: View {
    @Binding var currentViewState: ViewState
    @State private var keyInput: String = ""
    @State private var showError = false
    @State private var isGlowing = false
    
    // ĐIỀN LINK ẢNH AVATAR CỦA BẠN VÀO ĐÂY (Phải kết thúc bằng .png hoặc .jpg)
    let avatarURL = "https://i.imgur.com/Thay_Bang_Link_Anh_Cua_Ban.png"
    
    var body: some View {
        VStack(spacing: 26) {
            Spacer()
            
            // AVATAR NEON PHÁT SÁNG
            ZStack {
                Circle()
                    .stroke(LinearGradient(colors: [.cyan, .purple], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 3)
                    .frame(width: 110, height: 110)
                    .shadow(color: .cyan, radius: isGlowing ? 18 : 6)
                    .scaleEffect(isGlowing ? 1.04 : 0.98)
                
                AsyncImage(url: URL(string: avatarURL)) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else {
                        Image(systemName: "person.crop.circle.fill.badge.checkmark")
                            .resizable().scaledToFit().padding(22)
                            .foregroundStyle(LinearGradient(colors: [.cyan, .purple], startPoint: .top, endPoint: .bottom))
                    }
                }
                .frame(width: 100, height: 100)
                .clipShape(Circle())
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                    isGlowing.toggle()
                }
            }
            
            // TIÊU ĐỀ CHỮ NEON RỰC RỠ
            VStack(spacing: 8) {
                Text("ZENITH SOLITUDE")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .tracking(4)
                    .foregroundColor(.white)
                    .shadow(color: .cyan, radius: 10)
                    .shadow(color: .cyan, radius: 25)
                
                Text("QUANTUM SECURE GATEWAY")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(3)
                    .foregroundColor(.purple)
                    .shadow(color: .purple, radius: 8)
            }
            
            // KHUNG NHẬP KEY THIẾT KẾ KÍNH MỜ NEON
            VStack(spacing: 18) {
                HStack(spacing: 12) {
                    Image(systemName: "key.fill")
                        .foregroundColor(.cyan)
                        .shadow(color: .cyan, radius: 5)
                    
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
                            .foregroundColor(.cyan)
                            .padding(8)
                            .background(Color.cyan.opacity(0.15))
                            .cornerRadius(8)
                    }
                }
                .padding(14)
                .background(Color.black.opacity(0.6))
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(showError ? Color.red : Color.cyan.opacity(0.5), lineWidth: 1.2)
                        .shadow(color: showError ? .red : .cyan.opacity(0.3), radius: 6)
                )
                
                if showError {
                    Text("⚠️ Mã kích hoạt không chính xác hoặc đã hết hạn!")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.red)
                        .shadow(color: .red, radius: 5)
                }
                
                // NÚT LOGIN NEON
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
                    Text("XÁC THỰC TRUY CẬP")
                        .font(.system(size: 14, weight: .black))
                        .tracking(2)
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(colors: [.cyan, .purple], startPoint: .leading, endPoint: .trailing)
                        )
                        .cornerRadius(16)
                        .shadow(color: .cyan.opacity(0.6), radius: 10, x: 0, y: 0)
                }
                
                Divider().background(Color.white.opacity(0.15)).padding(.vertical, 4)
                
                // NÚT LẤY KEY
                Button(action: {
                    if let url = URL(string: "https://solitudepremium.click") {
                        UIApplication.shared.open(url)
                    }
                }) {
                    HStack {
                        Image(systemName: "network")
                        Text("NHẬN KEY KÍCH HOẠT HỆ THỐNG")
                            .font(.system(size: 11, weight: .bold))
                        Spacer()
                        Image(systemName: "arrow.up.right")
                    }
                    .foregroundColor(.cyan)
                }
            }
            .padding(24)
            .background(.ultraThinMaterial)
            .cornerRadius(26)
            .overlay(
                RoundedRectangle(cornerRadius: 26)
                    .stroke(LinearGradient(colors: [.cyan.opacity(0.4), .purple.opacity(0.4)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
            )
            .padding(.horizontal, 22)
            
            Spacer()
            
            // FOOTER TRẠNG THÁI
            HStack(spacing: 6) {
                Circle().frame(width: 6, height: 6).foregroundColor(.cyan).shadow(color: .cyan, radius: 6)
                Text("Zenith Core • Secure Node Online")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.gray)
            }
            .padding(.bottom, 25)
        }
    }
}

// MARK: - MÀN HÌNH CHÍNH SAU KHI ĐĂNG NHẬP
struct MainDashboardView: View {
    @Binding var currentViewState: ViewState
    
    var body: some View {
        VStack(spacing: 22) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(Color.cyan.opacity(0.15))
                    .frame(width: 110, height: 110)
                    .blur(radius: 10)
                
                Image(systemName: "shield.checkered")
                    .font(.system(size: 55))
                    .foregroundStyle(LinearGradient(colors: [.cyan, .purple], startPoint: .top, endPoint: .bottom))
                    .shadow(color: .cyan, radius: 12)
            }
            
            Text("ZENITH SECURE DASHBOARD")
                .font(.system(size: 22, weight: .black))
                .foregroundColor(.white)
                .tracking(2)
                .shadow(color: .cyan, radius: 8)
            
            Text("Phiên làm việc đã được mã hóa và xác thực toàn quyền thành công.")
                .font(.system(size: 13))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "cpu").foregroundColor(.cyan)
                    Text("Trạng thái Lõi: Hoạt động tối ưu").font(.system(size: 12, weight: .bold)).foregroundColor(.white)
                }
                HStack {
                    Image(systemName: "lock.shield").foregroundColor(.purple)
                    Text("Bảo mật: Mã hóa phần cứng độc lập").font(.system(size: 12, weight: .bold)).foregroundColor(.white)
                }
            }
            .padding(20)
            .background(.ultraThinMaterial)
            .cornerRadius(16)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.cyan.opacity(0.3), lineWidth: 1))
            .padding(.horizontal, 30)
            
            Button(action: {
                withAnimation {
                    currentViewState = .login
                }
            }) {
                Text("ĐĂNG XUẤT PHIÊN LÀM VIỆC")
                    .font(.system(size: 13, weight: .bold))
                    .tracking(1)
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(14)
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.red.opacity(0.4), lineWidth: 1))
            }
            .padding(.horizontal, 30)
            .padding(.top, 10)
            
            Spacer()
        }
    }
}
