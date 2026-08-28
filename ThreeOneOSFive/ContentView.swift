import SwiftUI

enum ViewState {
    case login
    case mainApp
}

struct ContentView: View {
    @State private var currentViewState: ViewState = .login
    
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
            case .login:
                LoginView(currentViewState: $currentViewState)
            case .mainApp:
                // GỌI TRỰC TIẾP MÀN HÌNH CHÍNH GỐC CỦA ỨNG DỤNG (THAY VÌ MÀN HÌNH CHÀO MỪNG)
                FilesTabSwitcherView()
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - MÀN HÌNH NHẬP KEY (HIỆN LÊN ĐẦU TIÊN)
struct LoginView: View {
    @Binding var currentViewState: ViewState
    @State private var keyInput: String = ""
    @State private var showError = false
    
    // ĐIỀN LINK ẢNH AVATAR CỦA BẠN VÀO ĐÂY
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
            .background(.ultraThinMaterial)
            .cornerRadius(24)
            .overlay(
                RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
            .padding(.horizontal, 24)
            
            Spacer()
        }
    }
}
