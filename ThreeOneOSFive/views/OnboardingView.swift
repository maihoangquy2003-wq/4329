import SwiftUI

struct OnboardingView: View {
    @AppStorage(AppLanguage.storageKey) private var languageCode = "vi"
    
    @State private var textOpacity: Double = 0.0
    @State private var textScale: CGFloat = 0.85
    @State private var glowOpacity: Double = 0.0
    
    var onComplete: () -> Void

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            Text("Solitude")
                .font(.system(size: 58, weight: .heavy, design: .rounded))
                .foregroundColor(.white)
                .shadow(color: .white.opacity(glowOpacity), radius: 8, x: 0, y: 0)
                .shadow(color: .white.opacity(glowOpacity * 0.8), radius: 16, x: 0, y: 0)
                .shadow(color: .white.opacity(glowOpacity * 0.5), radius: 32, x: 0, y: 0)
                .opacity(textOpacity)
                .scaleEffect(textScale)
        }
        .onAppear {
            languageCode = "vi"
            
            withAnimation(.easeOut(duration: 1.2)) {
                textOpacity = 1.0
                textScale = 1.0
                glowOpacity = 1.0
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                withAnimation(.easeIn(duration: 0.8)) {
                    textOpacity = 0.0
                    textScale = 1.1 
                    glowOpacity = 0.0
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    onComplete()
                }
            }
        }
    }
}

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
        return true 
    }

    static func markCompleted() {
        UserDefaults.standard.set(currentVersion, forKey: completedVersionKey)
        UserDefaults.standard.set(currentFingerprint, forKey: completedFingerprintKey)
    }
}
