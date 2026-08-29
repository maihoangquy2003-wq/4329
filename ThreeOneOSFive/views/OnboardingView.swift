
import SwiftUI

struct OnboardingView: View {
    @AppStorage(AppLanguage.storageKey) private var languageCode = "vi"
    
    @State private var textOpacity: Double = 0.0
    @State private var textOffset: CGFloat = -60
    @State private var blurRadius: CGFloat = 15
    @State private var glowOpacity: Double = 0.0
    
    var onComplete: () -> Void

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            // Hiệu ứng hạt rơi từ trên trời
            ParticleView()
                .opacity(textOpacity)

            // Nội dung chữ
            VStack(spacing: 12) {
                HStack(spacing: 16) {
                    Text("ZENITH")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .tracking(4)
                    
                    Text("SOLITUDE")
                        .font(.system(size: 20, weight: .light, design: .rounded))
                        .tracking(6)
                }
                
                Text("Headlock Version 4.3.29")
                    .font(.system(size: 14, weight: .light, design: .rounded))
                    .tracking(2)
                    .foregroundColor(.white.opacity(0.8))
            }
            .foregroundColor(.white)
            // Neon trắng tinh khiết
            .shadow(color: .white.opacity(glowOpacity), radius: 8, x: 0, y: 0)
            .shadow(color: .white.opacity(glowOpacity * 0.7), radius: 20, x: 0, y: 0)
            .shadow(color: .white.opacity(glowOpacity * 0.3), radius: 40, x: 0, y: 0)
            .blur(radius: blurRadius)
            .opacity(textOpacity)
            .offset(y: textOffset)
        }
        .onAppear {
            languageCode = "vi"
            
            withAnimation(.spring(response: 1.5, dampingFraction: 0.7, blendDuration: 0.5)) {
                textOffset = 0
            }
            withAnimation(.easeOut(duration: 1.5)) {
                textOpacity = 1.0
                blurRadius = 0
                glowOpacity = 1.0
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                withAnimation(.easeIn(duration: 1.2)) {
                    textOpacity = 0.0
                    blurRadius = 15
                    glowOpacity = 0.0
                    textOffset = 30
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    onComplete()
                }
            }
        }
    }
}

// MARK: - Hiệu ứng hạt bụi rơi
struct ParticleView: View {
    let count = 60
    @State private var particles: [Particle] = []
    
    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let now = timeline.date.timeIntervalSinceReferenceDate
                for particle in particles {
                    var y = particle.initialY + particle.speed * now
                    y = y.truncatingRemainder(dividingBy: size.height + 20) - 20
                    let rect = CGRect(x: particle.x, y: y, width: particle.size, height: particle.size)
                    context.fill(
                        Path(ellipseIn: rect),
                        with: .color(.white.opacity(particle.opacity))
                    )
                }
            }
            .onAppear {
                if particles.isEmpty {
                    particles = generateParticles()
                }
            }
        }
        .ignoresSafeArea()
    }
    
    struct Particle {
        let initialY: Double
        let x: Double
        let speed: Double
        let size: CGFloat
        let opacity: Double
    }
    
    func generateParticles() -> [Particle] {
        var result = [Particle]()
        let screenWidth = UIScreen.main.bounds.width
        let screenHeight = UIScreen.main.bounds.height
        for _ in 0..<count {
            let x = Double.random(in: 0...screenWidth)
            let initialY = Double.random(in: -screenHeight...0)
            let speed = Double.random(in: 15...60) // Chậm hơn để tạo cảm giác hạt bụi nhẹ
            let size = CGFloat.random(in: 1...2.5)
            let opacity = Double.random(in: 0.2...0.7)
            result.append(Particle(initialY: initialY, x: x, speed: speed, size: size, opacity: opacity))
        }
        return result
    }
}

// MARK: - Store không thay đổi
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
