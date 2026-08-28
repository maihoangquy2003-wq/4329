import SwiftUI

enum ViewState {
    case login
    case mainApp
}

struct ContentView: View {
    @State private var currentViewState: ViewState = .login
    // Khởi tạo state quản lý phiên điều hướng gốc của ứng dụng
    @StateObject private var tabNavigationState = AppTabNavigationState()
    
    var body: some View {
        ZStack {
            // Nền không gian tối thẳm huyền bí
            LinearGradient(
                colors: [Color(red: 0.01, green: 0.02, blue: 0.05), Color(red: 0.04, green: 0.01, blue: 0.08)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // Hiệu ứng hạt sáng lấp lánh nền phía sau
            ParticleRainView()
            
            switch currentViewState {
            case .login:
                NeonLoginView(currentViewState: $currentViewState)
            case .mainApp:
                // Truyền đúng kiểu @Binding dạng $tabNavigationState theo yêu cầu của ứng dụng gốc
                FilesTabSwitcherView(session: $tabNavigationState)
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - HIỆU ỨNG HẠT SÁNG NỀN
struct ParticleRainView: View {
    var body: some View {
        TimelineView(.animation) { context in
            Canvas { graphicsContext, size in
                let time = context.date.timeIntervalSinceReferenceDate
                for i in 0..<30 {
                    let seed = Double(i) * 40.0
                    let x = (sin(time * 0.4 + seed) * 0.5 + 0.5) * size.width
                    let y = fmod(seed + time * 50.0, size.height)
                    let rect = CGRect(x: x, y: y, width: 2.5, height: 2.5)
                    
                    graphicsContext.fill(Path(ellipseIn: rect), with: .color(i % 2 == 0 ? .cyan : .purple))
                    graphicsContext.addFilter(.glow(color: i % 2 == 0 ? .cyan : .purple, radius: 3))
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

// MARK: - MÀN HÌNH ĐĂNG NHẬP NEON ĐẲNG CẤP
struct NeonLoginView: View {
    @Binding var currentViewState: ViewState
    @State private var keyInput: String = ""
    @State private var showError = false
    @State private var glowPulse = false
    
    // ĐIỀN LINK ẢNH AVATAR CỦA BẠN VÀO ĐÂY (Phải kết thúc bằng .png hoặc .jpg)
    let avatarURL = "https://i.imgur.com/Thay_Bang_Link_Anh_Cua_Ban.png"
    
    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            
            // AVATAR NEON PHÁT SÁNG
            ZStack {
                Circle()
                    .stroke(LinearGradient(colors: [.cyan, .purple], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 3)
                    .frame(width: 105, height: 105)
                    .shadow(color: .cyan, radius: glowPulse ? 16 : 6)
                    .scaleEffect(glowPulse ? 1.03 : 0.98)
                
                AsyncImage(url: URL(string: avatarURL)) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else {
                        Image(systemName: "atom")
                            .resizable().scaledToFit().padding(22)
                            .foregroundStyle(LinearGradient(colors: [.cyan, .purple], startPoint: .top, endPoint: .bottom))
                    }
                }
                .frame(width: 95, height: 95)
                .clipShape(Circle())
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                    glowPulse.toggle()
                }
            }
            
            // TIÊU ĐỀ CHỮ NEON RỰC RỠ
            VStack(spacing: 8) {
                Text("ZENITH SOLITUDE")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .tracking(4)
                    .foregroundColor(.white)
                    .shadow(color: .cyan, radius: 10)
                    .shadow(color: .cyan, radius: 20)
                
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
                    
                    TextField("Nhập Zenith Key kích hoạt...", text: $keyInput)
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
