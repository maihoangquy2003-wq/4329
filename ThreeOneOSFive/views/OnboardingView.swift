
import SwiftUI

struct OnboardingView: View {
    // Tự động thiết lập tiếng Việt
    @AppStorage(AppLanguage.storageKey) private var languageCode = "vi"
    
    // Các biến kiểm soát hiệu ứng (Animation States)
    @State private var textOpacity: Double = 0.0
    @State private var textOffset: CGFloat = -60 // Bắt đầu rơi từ trên cao
    @State private var blurRadius: CGFloat = 15 // Bắt đầu với hiệu ứng mờ ảo
    @State private var glowOpacity: Double = 0.0
    
    var onComplete: () -> Void

    var body: some View {
        ZStack {
            // Nền đen tuyền
            Color.black
                .ignoresSafeArea()

            // Nhóm chữ hiển thị
            VStack(spacing: 0) {
                Text("ZENITH")
                    .font(.system(size: 64, weight: .black, design: .serif))
                    .tracking(8) // Kéo giãn khoảng cách giữa các chữ
                
                Text("SOLITUDE")
                    .font(.system(size: 38, weight: .light, design: .serif))
                    .tracking(16)
            }
            .foregroundColor(.white)
            // Hiệu ứng phát sáng Neon tinh tế (pha chút trắng xanh)
            .shadow(color: .white.opacity(glowOpacity), radius: 10, x: 0, y: 0)
            .shadow(color: .cyan.opacity(glowOpacity * 0.6), radius: 25, x: 0, y: 0)
            .shadow(color: .blue.opacity(glowOpacity * 0.3), radius: 50, x: 0, y: 0)
            
            // Áp dụng các trạng thái biến đổi
            .blur(radius: blurRadius)
            .opacity(textOpacity)
            .offset(y: textOffset)
        }
        .onAppear {
            // 1. Ép hệ thống dùng tiếng Việt ngay lập tức
            languageCode = "vi"
            
            // 2. Giai đoạn xuất hiện: Hiệu ứng rơi xuống, rõ dần và phát sáng
            withAnimation(.spring(response: 1.5, dampingFraction: 0.7, blendDuration: 0.5)) {
                textOffset = 0 // Rơi về vị trí trung tâm
            }
            withAnimation(.easeOut(duration: 1.5)) {
                textOpacity = 1.0
                blurRadius = 0 // Nét căng
                glowOpacity = 1.0 // Tỏa sáng
            }
            
            // 3. Đợi 3 giây hiển thị, sau đó bắt đầu hiệu ứng chìm đi
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                withAnimation(.easeIn(duration: 1.2)) {
                    textOpacity = 0.0
                    blurRadius = 15 // Mờ nhòe ra
                    glowOpacity = 0.0 // Tắt đèn
                    textOffset = 30 // Chìm nhẹ xuống dưới
                }
                
                // 4. Đợi hiệu ứng mờ kết thúc rồi tiến thẳng vào Main App
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    onComplete()
                }
            }
        }
    }
}

// Giữ nguyên logic Store bên dưới để App không bị lỗi biên dịch
enum OnboardingStore {
    static let completedVersionKey = "onboarding.completedVersion"
    static let completedFingerprintKey = "onboarding.completedFingerprint"

    static var currentVersion: String {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
        let b = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
        return "\(v) (\(b))"
    }

    static var bundleToken: String {
        if let exe = Bundle.main.executablePath,
           let attrs = try? FileManager.default.attributesOfItem(atPath: exe),
           let date = attrs[.modificationDate] as? Date {
            return String(Int(date.timeIntervalSince1970))
        }
        if let attrs = try? FileManager.default.attributesOfItem(atPath: Bundle.main.bundlePath),
           let date = (attrs[.creationDate] as? Date) ?? (attrs[.modificationDate] as? Date) {
            return String(Int(date.timeIntervalSince1970))
        }
        return "0"
    }

    static var currentFingerprint: String { "\(currentVersion)#\(bundleToken)" }

    static var completedVersion: String? {
        UserDefaults.standard.string(forKey: completedVersionKey)
    }

    static var completedFingerprint: String? {
        UserDefaults.standard.string(forKey: completedFingerprintKey)
    }

    static func shouldShow() -> Bool {
        // Luôn trả về true để lúc nào mở app cũng thấy hiệu ứng Splash Screen cực đẹp này
        return true 
    }

    static func markCompleted() {
        UserDefaults.standard.set(currentVersion, forKey: completedVersionKey)
        UserDefaults.standard.set(currentFingerprint, forKey: completedFingerprintKey)
    }
}
