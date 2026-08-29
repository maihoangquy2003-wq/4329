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

            // Hiệu ứng hạt rơi (ẩn/hiện cùng chữ)
            ParticleView()
                .opacity(textOpacity)

            // Chữ "ZENITH SOLITUDE" trên cùng một hàng
            HStack(spacing: 20) {
                Text("ZENITH")
                    .font(.system(size: 64, weight: .black, design: .serif))
                    .tracking(8)
                
                Text("SOLITUDE")
                    .font(.system(size: 38, weight: .light, design: .serif))
                    .tracking(16)
            }
            .foregroundColor(.white)
            .shadow(color: .white.opacity(glowOpacity), radius: 10, x: 0, y: 0)
            .shadow(color: .cyan.opacity(glowOpacity * 0.6), radius: 25, x: 0, y: 0)
            .shadow(color: .blue.opacity(glowOpacity * 0.3), radius: 50, x: 0, y: 0)
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

// Hiệu ứng hạt rơi dùng TimelineView + Canvas
struct ParticleView: View {
    let count = 40
    @State private var particles: [Particle] = []
    
    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let now = timeline.date.timeIntervalSinceReferenceDate
                for particle in particles {
                    var y = particle.initialY + particle.speed * now
                    y = y.truncatingRemainder(dividingBy: size.height + 20) - 20
                    let x = particle.x
                    let rect = CGRect(x: x, y: y, width: particle.size, height: particle.size)
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
            let speed = Double.random(in: 20...80)
            let size = CGFloat.random(in: 1...3)
            let opacity = Double.random(in: 0.3...0.8)
            result.append(Particle(initialY: initialY, x: x, speed: speed, size: size, opacity: opacity))
        }
        return result
    }
}

// Giữ nguyên logic Store
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
