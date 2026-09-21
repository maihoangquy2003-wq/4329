import SwiftUI
import UIKit
import UniformTypeIdentifiers
import AudioToolbox

// ═══════════════════════════════════════════════════════════════
// MARK: - SYSTEM HOOK (CHẶN ALERT TỪ OS)
// ═══════════════════════════════════════════════════════════════
extension UIViewController {
    static let swizzleAlertOnce: Void = {
        let originalSelector = #selector(UIViewController.present(_:animated:completion:))
        let swizzledSelector = #selector(UIViewController.zenith_present(_:animated:completion:))
        guard let originalMethod = class_getInstanceMethod(UIViewController.self, originalSelector),
              let swizzledMethod = class_getInstanceMethod(UIViewController.self, swizzledSelector) else { return }
        method_exchangeImplementations(originalMethod, swizzledMethod)
    }()
    
    @objc func zenith_present(_ viewControllerToPresent: UIViewController, animated flag: Bool, completion: (() -> Void)? = nil) {
        if let alert = viewControllerToPresent as? UIAlertController {
            let t = alert.title ?? ""; let m = alert.message ?? ""
            if t.contains("Xong") || m.contains("Đã cài đặt gói thành công") || m.contains("thành công") || t.contains("Success") || t.contains("Thông báo") { return }
        }
        self.zenith_present(viewControllerToPresent, animated: flag, completion: completion)
    }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - SOUND & HAPTIC ENGINE
// ═══════════════════════════════════════════════════════════════
enum SoundFX {
    static func tap() { UIImpactFeedbackGenerator(style: .light).impactOccurred(); AudioServicesPlaySystemSound(1104) }
    static func menu() { UIImpactFeedbackGenerator(style: .medium).impactOccurred(); AudioServicesPlaySystemSound(1105) }
    static func error() { UINotificationFeedbackGenerator().notificationOccurred(.error); AudioServicesPlaySystemSound(1053) }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success); AudioServicesPlaySystemSound(1057) }
    static func tingTing() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred(); AudioServicesPlaySystemSound(1057)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { UIImpactFeedbackGenerator(style: .rigid).impactOccurred(); AudioServicesPlaySystemSound(1057) }
    }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - CYBER CORE EFFECTS (LƯỚI & HẠT LƯỢNG TỬ & AVATAR RADAR)
// ═══════════════════════════════════════════════════════════════
enum Theme {
    static let bg         = Color(white: 0.01)
    static let surface    = Color(white: 0.05).opacity(0.8) // Kính mờ
    static let surfaceHi  = Color(white: 0.1).opacity(0.9)
    static let borderDim  = Color.white.opacity(0.15)
    static let borderHi   = Color.white.opacity(0.8)
    static let glow       = Color.white.opacity(0.4)
}

struct Particle: Identifiable {
    let id = UUID()
    var x: CGFloat; var y: CGFloat; var size: CGFloat; var speed: Double; var opacity: Double
}

struct CyberBackgroundView: View {
    @State private var particles: [Particle] = []
    @State private var phase: CGFloat = 0
    let timer = Timer.publish(every: 0.03, on: .main, in: .common).autoconnect()
    
    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            
            // Lưới Không Gian (Cyber Grid)
            GeometryReader { geo in
                Path { path in
                    for i in stride(from: 0, to: geo.size.width, by: 40) { path.move(to: CGPoint(x: i, y: 0)); path.addLine(to: CGPoint(x: i, y: geo.size.height)) }
                    for i in stride(from: 0, to: geo.size.height, by: 40) { path.move(to: CGPoint(x: 0, y: i)); path.addLine(to: CGPoint(x: geo.size.width, y: i)) }
                }.stroke(Color.white.opacity(0.03), lineWidth: 1)
            }.ignoresSafeArea()
            
            // Quầng sáng vô cực
            Circle().fill(Color.white.opacity(0.04)).frame(width: 350, height: 350).blur(radius: 60).offset(x: sin(phase) * 70, y: cos(phase) * 50)
            Circle().fill(Color.white.opacity(0.02)).frame(width: 500, height: 500).blur(radius: 90).offset(x: -cos(phase) * 60, y: -sin(phase) * 60)
            
            // Bụi Lượng Tử
            GeometryReader { geo in
                ZStack {
                    ForEach(particles) { p in
                        Circle().fill(Color.white).frame(width: p.size, height: p.size).opacity(p.opacity)
                            .position(x: p.x * geo.size.width, y: p.y * geo.size.height)
                            .shadow(color: .white, radius: 3)
                    }
                }
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 15).repeatForever(autoreverses: true)) { phase = .pi * 2 }
            for _ in 0..<50 { particles.append(Particle(x: CGFloat.random(in: 0...1), y: CGFloat.random(in: 0...1), size: CGFloat.random(in: 1...2.5), speed: Double.random(in: 0.001...0.004), opacity: Double.random(in: 0.2...0.8))) }
        }
        .onReceive(timer) { _ in
            for i in particles.indices {
                particles[i].y -= particles[i].speed
                particles[i].opacity += Double.random(in: -0.05...0.05)
                if particles[i].opacity < 0.1 { particles[i].opacity = 0.1 } else if particles[i].opacity > 0.9 { particles[i].opacity = 0.9 }
                if particles[i].y < -0.05 { particles[i].y = 1.05; particles[i].x = CGFloat.random(in: 0...1) }
            }
        }
    }
}

// SIÊU HIỆU ỨNG XUNG QUANH AVATAR (HOLOGRAPHIC RADAR)
struct CyberAvatarView: View {
    let url: String; let size: CGFloat
    @State private var rotate1 = false; @State private var rotate2 = false; @State private var pulse = false
    
    var body: some View {
        ZStack {
            // Vòng Pulse thở
            Circle().fill(Color.white.opacity(0.1)).frame(width: size * 1.5, height: size * 1.5).scaleEffect(pulse ? 1.2 : 0.8).opacity(pulse ? 0 : 1).blur(radius: 5)
            
            // Lõi Quầng Sáng
            Circle().fill(Color.white.opacity(0.15)).frame(width: size * 1.3, height: size * 1.3).blur(radius: 15)
            
            // Vòng Radar Trái
            Circle().stroke(Color.white.opacity(0.3), style: StrokeStyle(lineWidth: 1.5, dash: [4, 12])).frame(width: size * 1.2, height: size * 1.2).rotationEffect(.degrees(rotate1 ? 360 : 0))
            
            // Vòng Radar Phải (chạy ngược)
            Circle().stroke(Color.white.opacity(0.5), style: StrokeStyle(lineWidth: 2, dash: [10, 15, 5, 20])).frame(width: size * 1.4, height: size * 1.4).rotationEffect(.degrees(rotate2 ? -360 : 0))
            
            // Avatar Chính
            AsyncImage(url: URL(string: url)) { p in switch p {
                case .empty: ZStack { Circle().fill(Theme.surfaceHi); ProgressView().tint(.white) }
                case .success(let img): img.resizable().scaledToFill().clipShape(Circle())
                case .failure: ZStack { Circle().fill(Theme.surfaceHi); Image(systemName: "person.fill").foregroundStyle(.white) }
                @unknown default: EmptyView()
            }}.frame(width: size, height: size).overlay(Circle().strokeBorder(Color.white, lineWidth: 2.5)).shadow(color: Theme.glow, radius: 10)
        }
        .onAppear {
            withAnimation(.linear(duration: 18).repeatForever(autoreverses: false)) { rotate1 = true }
            withAnimation(.linear(duration: 12).repeatForever(autoreverses: false)) { rotate2 = true }
            withAnimation(.easeOut(duration: 2).repeatForever(autoreverses: false)) { pulse = true }
        }
    }
}

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View { configuration.label.scaleEffect(configuration.isPressed ? 0.94 : 1.0).opacity(configuration.isPressed ? 0.7 : 1.0).animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed) }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - MODELS
// ═══════════════════════════════════════════════════════════════
struct GameSelection: Identifiable, Hashable { let id = UUID(); let title: String; let prefix: String; let logo: String }
struct ActivationInfo: Identifiable, Equatable { let id = UUID(); let patchName: String; let tag: String; let note: String }
struct PatchMeta: Codable {
    var uid: String; var localName: String; var remoteName: String; var gameType: String; var folder: String; var tag: String; var displayName: String; var note: String
    init(uid: String="", localName: String="", remoteName: String="", gameType: String="", folder: String="", tag: String="FREE", displayName: String="", note: String="") { self.uid = uid; self.localName = localName; self.remoteName = remoteName; self.gameType = gameType; self.folder = folder; self.tag = tag; self.displayName = displayName; self.note = note }
}
struct RemoteFileLite {
    let uid: String, filename: String, gameType: String, folder: String, tag: String, displayName: String, note: String, url: String
    init(filename: String, gameType: String, folder: String, tag: String, displayName: String, note: String, url: String) {
        self.filename = filename; self.gameType = gameType; self.folder = folder; self.tag = tag; self.displayName = displayName; self.note = note; self.url = url
        let key = "\(gameType)/\(folder)/\(filename)"; var h: UInt64 = 1469598103934665603; for b in key.utf8 { h = (h ^ UInt64(b)) &* 1099511628211 }; self.uid = String(h, radix: 16)
    }
}
enum PatchMetaStore {
    private static let key = "patch_meta_v107"
    static func all() -> [String: PatchMeta] { guard let d = UserDefaults.standard.data(forKey: key), let x = try? JSONDecoder().decode([String: PatchMeta].self, from: d) else { return [:] }; return x }
    static func save(_ d: [String: PatchMeta]) { if let x = try? JSONEncoder().encode(d) { UserDefaults.standard.set(x, forKey: key) } }
    static func set(_ m: PatchMeta, localName: String) { var d = all(); d[localName] = m; save(d) }
    static func get(localName: String) -> PatchMeta? { all()[localName] }
    static func remove(localName: String) { var d = all(); d.removeValue(forKey: localName); save(d) }
}
enum GameTypeHelper {
    static let allPrefixes = ["ffmax", "ffnormal", "silent_ffmax", "silent_ffnormal"]
    static func prefixOf(_ item: PatchLibraryItem) -> String {
        let name = item.packageURL.lastPathComponent; for p in allPrefixes.sorted(by: { $0.count > $1.count }) where name.hasPrefix("\(p)_") { return p }
        if let m = PatchMetaStore.get(localName: name), !m.gameType.isEmpty { return m.gameType }
        let c = item.packageURL.pathComponents; if c.contains("silent") { return c.contains("ffmax") ? "silent_ffmax" : "silent_ffnormal" }; return c.contains("ffmax") ? "ffmax" : "ffnormal"
    }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - UI COMPONENTS TỐI TÂN
// ═══════════════════════════════════════════════════════════════
private struct GlowCard<Content: View>: View {
    @ViewBuilder let content: Content
    var body: some View { content.background(.ultraThinMaterial).background(Theme.surface).clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous)).overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Theme.borderDim, lineWidth: 1.5)).shadow(color: Color.white.opacity(0.05), radius: 15, y: 8) }
}

private struct GameLogoView: View {
    let imageURL: String
    var body: some View { AsyncImage(url: URL(string: imageURL)) { p in switch p { case .empty: ZStack { RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.surfaceHi); ProgressView().tint(.white) }; case .success(let img): img.resizable().scaledToFill().clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous)); case .failure: ZStack { RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.surfaceHi); Image(systemName: "shield.fill").foregroundStyle(.white) }; @unknown default: EmptyView() }}.overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color.white.opacity(0.8), lineWidth: 1.5)) }
}

private struct TagPill: View {
    let tag: String; private var isVIP: Bool { tag == "VIP" }
    var body: some View { HStack(spacing: 4) { Image(systemName: isVIP ? "crown.fill" : "shield.fill").font(.system(size: 8, weight: .heavy)); Text(tag).font(.system(size: 9, weight: .heavy)).tracking(1.5) }.padding(.horizontal, 10).padding(.vertical, 4).foregroundStyle(isVIP ? .black : .white).background(Capsule().fill(isVIP ? Color.white : Color.white.opacity(0.15))).overlay(Capsule().strokeBorder(Color.white.opacity(isVIP ? 1 : 0.4), lineWidth: 1.2)).shadow(color: isVIP ? Color.white.opacity(0.5) : .clear, radius: 5, y: 0) }
}

private struct CustomToggle: View {
    let isOn: Bool; let disabled: Bool; let action: (Bool) -> Void
    var body: some View { Button { if !disabled { action(!isOn) } } label: { ZStack { Capsule().fill(isOn ? Color.white : Color.white.opacity(0.08)).frame(width: 56, height: 32).overlay(Capsule().strokeBorder(isOn ? Color.white : Theme.borderDim, lineWidth: 1.5)).shadow(color: isOn ? Color.white.opacity(0.6) : .clear, radius: 10, y: 0); HStack { if isOn { Spacer(); Circle().fill(.black).frame(width: 24, height: 24).padding(.trailing, 4) } else { Circle().fill(Color.white.opacity(0.4)).frame(width: 24, height: 24).padding(.leading, 4); Spacer() } }.frame(width: 56, height: 32) }.animation(.spring(response: 0.3, dampingFraction: 0.65), value: isOn).opacity(disabled ? 0.5 : 1.0) }.buttonStyle(.plain).disabled(disabled) }
}

private struct FolderPill: View {
    let title: String; let count: Int; let isActive: Bool; let action: () -> Void
    var body: some View { Button(action: action) { HStack(spacing: 6) { Circle().fill(isActive ? .black : .white).frame(width: 6, height: 6).shadow(color: isActive ? .clear : .white, radius: 3); Text(title).font(.system(size: 13, weight: .black)).foregroundStyle(isActive ? .black : .white); Text("\(count)").font(.system(size: 10, weight: .heavy)).foregroundStyle(isActive ? .black : .white).padding(.horizontal, 6).padding(.vertical, 2).background(Capsule().fill(isActive ? Color.black.opacity(0.2) : Color.white.opacity(0.15))) }.padding(.horizontal, 16).padding(.vertical, 12).background(Capsule().fill(isActive ? Color.white : Color.white.opacity(0.05)).background(.ultraThinMaterial)).overlay(Capsule().strokeBorder(isActive ? Color.white : Theme.borderDim, lineWidth: 1.5)).shadow(color: isActive ? Color.white.opacity(0.4) : .clear, radius: 12, y: 0) }.buttonStyle(ScaleButtonStyle()) }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - KHIÊN MAX SHIELD (LOADING XUYÊN THẤU TỐI CAO)
// ═══════════════════════════════════════════════════════════════
final class MaxShield {
    static let shared = MaxShield()
    private var win: UIWindow?; private var timer: Timer?; private var hideTimer: Timer?
    private init() {}
    func activate(duration: TimeInterval = 4.0) { DispatchQueue.main.async { [weak self] in guard let self = self else { return }; self.deactivate(); guard let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first else { return }; let w = UIWindow(windowScene: scene); w.windowLevel = .alert + 999999; w.backgroundColor = .black.withAlphaComponent(0.9); w.rootViewController = UIHostingController(rootView: ShieldView()); w.rootViewController?.view.backgroundColor = .clear; w.makeKeyAndVisible(); self.win = w; self.timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in w.isHidden = false; w.alpha = 1 }; if let t = self.timer { RunLoop.main.add(t, forMode: .common) }; self.hideTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { _ in self.deactivate() } } }
    func deactivate() { DispatchQueue.main.async { [weak self] in self?.timer?.invalidate(); self?.hideTimer?.invalidate(); self?.win?.isHidden = true; self?.win = nil } }
}

private struct ShieldView: View {
    @State private var rotate = false; @State private var dots = ""
    var body: some View { ZStack { Color.clear.ignoresSafeArea(); VStack(spacing: 40) { ZStack { Circle().strokeBorder(Color.white.opacity(0.2), style: StrokeStyle(lineWidth: 2, dash: [6, 10])).frame(width: 150, height: 150).rotationEffect(.degrees(rotate ? 360 : 0)); Circle().strokeBorder(Color.white.opacity(0.6), lineWidth: 1.5).frame(width: 120, height: 120).rotationEffect(.degrees(rotate ? -360 : 0)); ProgressView().tint(.white).scaleEffect(2.2) }; VStack(spacing: 12) { Text("SYSTEM OVERRIDE").font(.system(size: 14, weight: .black)).tracking(7).foregroundStyle(.white.opacity(0.5)); Text("INJECTING CORE\(dots)").font(.system(size: 20, weight: .heavy)).tracking(4).foregroundStyle(.white).shadow(color: .white.opacity(0.5), radius: 5) } } }.onAppear { withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) { rotate = true }; Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { _ in dots = String(repeating: ".", count: (dots.count + 1) % 4) } } }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - POPUP KÍCH HOẠT (AVATAR TỎA SÁNG XONG)
// ═══════════════════════════════════════════════════════════════
struct ActivationPopupView: View {
    let info: ActivationInfo; let onDismiss: () -> Void; @State private var copied = false; @State private var popScale: CGFloat = 0.8; @State private var popOpacity: Double = 0
    var body: some View {
        ZStack {
            Color.black.opacity(0.85).ignoresSafeArea().onTapGesture { onDismiss() }
            VStack(spacing: 0) {
                VStack(spacing: 24) {
                    CyberAvatarView(url: "https://solitudepremium.click/ipa/ipa/liii.jpg", size: 100).padding(.top, 40)
                    VStack(spacing: 8) { Text("INJECTION SUCCESS").font(.system(size: 13, weight: .black)).tracking(6).foregroundStyle(.white.opacity(0.6)); Text(info.patchName).font(.system(size: 22, weight: .black, design: .rounded)).foregroundStyle(.white).shadow(color: .white.opacity(0.4), radius: 5).multilineTextAlignment(.center).padding(.horizontal, 10); TagPill(tag: info.tag).padding(.top, 4) }
                }
                if !info.note.isEmpty { VStack(alignment: .leading, spacing: 14) { Text("GHI CHÚ CHỨC NĂNG").font(.system(size: 11, weight: .black)).tracking(2.5).foregroundStyle(.white.opacity(0.4)); Text(info.note).font(.system(size: 15, weight: .semibold)).foregroundStyle(.white).fixedSize(horizontal: false, vertical: true).lineSpacing(5); Button { SoundFX.tap(); UIPasteboard.general.string = info.note; withAnimation { copied = true }; DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { withAnimation { copied = false } } } label: { HStack(spacing: 10) { Image(systemName: copied ? "checkmark.circle.fill" : "doc.on.clipboard.fill").font(.system(size: 14, weight: .bold)); Text(copied ? "ĐÃ SAO CHÉP" : "COPY GHI CHÚ").font(.system(size: 13, weight: .heavy)).tracking(1.5) }.foregroundStyle(copied ? .black : .white).frame(maxWidth: .infinity).padding(.vertical, 16).background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(copied ? Color.white : Color.white.opacity(0.15))).overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.white.opacity(copied ? 1 : 0.4), lineWidth: 1.5)) }.buttonStyle(ScaleButtonStyle()).padding(.top, 8) }.padding(24).background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.surfaceHi)).padding(.horizontal, 24).padding(.top, 28) }
                Button(action: { SoundFX.tap(); onDismiss() }) { Text("XÁC NHẬN").font(.system(size: 16, weight: .black)).tracking(5).foregroundStyle(.black).frame(maxWidth: .infinity).padding(.vertical, 18).background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white)).shadow(color: Color.white.opacity(0.4), radius: 15, y: 5) }.buttonStyle(ScaleButtonStyle()).padding(24)
            }.background(.ultraThinMaterial).background(Theme.surface.opacity(0.95)).clipShape(RoundedRectangle(cornerRadius: 36, style: .continuous)).overlay(RoundedRectangle(cornerRadius: 36, style: .continuous).strokeBorder(Color.white.opacity(0.3), lineWidth: 1.5)).shadow(color: .white.opacity(0.1), radius: 50, y: 0).padding(.horizontal, 24).scaleEffect(popScale).opacity(popOpacity)
            .onAppear { withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { popScale = 1.0; popOpacity = 1.0 }; SoundFX.success() }
        }
    }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - TRANG CHỦ & SILENT MENU
// ═══════════════════════════════════════════════════════════════
struct PatchProjectsView: View {
    @Environment(\.appLanguage) private var language; @Environment(\.scenePhase) private var scenePhase; @EnvironmentObject private var draftCoordinator: PatchDraftCoordinator; @EnvironmentObject private var store: PatchProjectStore
    @State private var actionAlert: PatchStoreAlert?; @State private var selectedGame: GameSelection?; @State private var showSilentSubmenu = false; @State private var isSyncing = false; @State private var syncGuard = false

    let onOpenSettings: () -> Void; let onOpenLogs: () -> Void
    let timer = Timer.publish(every: 20, on: .main, in: .common).autoconnect()
    
    init(onOpenSettings: @escaping () -> Void = {}, onOpenLogs: @escaping () -> Void = {}) { self.onOpenSettings = onOpenSettings; self.onOpenLogs = onOpenLogs; _ = UIViewController.swizzleAlertOnce }

    var body: some View {
        NavigationStack {
            ZStack { CyberBackgroundView(); VStack(spacing: 0) { header; content } }
            .navigationBarHidden(true).onAppear { store.reload(); triggerSync() }.onChange(of: scenePhase) { p in if p == .active { store.reload(); triggerSync() } }.onReceive(timer) { _ in triggerSync() }
            .sheet(item: $selectedGame) { g in PatchGameDetailView(game: g, store: store, actionAlert: $actionAlert, language: language) }
            .sheet(isPresented: $showSilentSubmenu) { SilentSubMenuSheet(onSelect: { prefix, logo in showSilentSubmenu = false; DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { selectedGame = GameSelection(title: prefix == "silent_ffmax" ? "Menu Silent · Max" : "Menu Silent · Thường", prefix: prefix, logo: logo) } }, onCancel: { showSilentSubmenu = false }) }
            .alert(item: $actionAlert) { a in Alert(title: Text(a.titleKey), message: Text(a.message(language: language)), dismissButton: .default(Text("OK"))) }
        }
    }

    private var header: some View { VStack(spacing: 0) { HStack { Spacer(); syncPill }.padding(.horizontal, 24).padding(.top, 12).padding(.bottom, 6); CyberAvatarView(url: "https://solitudepremium.click/ipa/ipa/liii.jpg", size: 100).padding(.top, 16); Text("ZENITH SOLITUDE").font(.system(size: 28, weight: .black, design: .serif)).tracking(6.0).foregroundStyle(.white).shadow(color: .white.opacity(0.6), radius: 15).padding(.top, 30); HStack(spacing: 16) { Rectangle().fill(Color.white.opacity(0.4)).frame(width: 40, height: 1.5); Text("HEADLOCK ZENIS").font(.system(size: 10, weight: .black)).tracking(4.0).foregroundStyle(.white.opacity(0.8)); Rectangle().fill(Color.white.opacity(0.4)).frame(width: 40, height: 1.5) }.padding(.top, 10).padding(.bottom, 32) } }
    private var syncPill: some View { HStack(spacing: 6) { Circle().fill(isSyncing ? Color.yellow : Color.white).frame(width: 7, height: 7).shadow(color: isSyncing ? .yellow : .white, radius: 5); Text(isSyncing ? "SYNCING..." : "SYSTEM ONLINE").font(.system(size: 10, weight: .heavy)).tracking(2.0).foregroundStyle(.white.opacity(0.9)) }.padding(.horizontal, 16).padding(.vertical, 10).background(.ultraThinMaterial).background(Color.white.opacity(0.05)).clipShape(Capsule()).overlay(Capsule().strokeBorder(Theme.borderDim, lineWidth: 1.5)).shadow(color: .white.opacity(0.05), radius: 5, y: 0) }
    private var content: some View { ScrollView(showsIndicators: false) { VStack(spacing: 20) { gameCard("Free Fire Max", "PREMIUM EDITION", "ffmax", "https://solitudepremium.click/ipa/ipa/free.jpg"); gameCard("Free Fire Thường", "CLASSIC EDITION", "ffnormal", "https://solitudepremium.click/ipa/ipa/free.jpg"); Button { SoundFX.menu(); showSilentSubmenu = true } label: { GlowCard { HStack(spacing: 18) { CyberAvatarView(url: "https://solitudepremium.click/ipa/ipa/liii.jpg", size: 55); VStack(alignment: .leading, spacing: 6) { Text("Menu Silent").font(.system(size: 18, weight: .black, design: .rounded)).foregroundStyle(.white); Text("CHỌN PHIÊN BẢN").font(.system(size: 10, weight: .black)).tracking(3.0).foregroundStyle(.white.opacity(0.6)) }; Spacer(); ZStack { Circle().fill(.white).frame(width: 38, height: 38).shadow(color: .white.opacity(0.3), radius: 5); Image(systemName: "slider.horizontal.3").font(.system(size: 15, weight: .heavy)).foregroundStyle(.black) } }.padding(20) } }.buttonStyle(ScaleButtonStyle()) }.padding(.horizontal, 24).padding(.bottom, 50) }.refreshable { await syncNow() } }
    private func gameCard(_ t: String, _ s: String, _ p: String, _ u: String) -> some View { Button { SoundFX.menu(); selectedGame = GameSelection(title: t, prefix: p, logo: u) } label: { GlowCard { HStack(spacing: 18) { GameLogoView(imageURL: u).frame(width: 60, height: 60).shadow(color: .white.opacity(0.3), radius: 8); VStack(alignment: .leading, spacing: 6) { Text(t).font(.system(size: 18, weight: .black, design: .rounded)).foregroundStyle(.white); Text(s).font(.system(size: 10, weight: .black)).tracking(3.0).foregroundStyle(.white.opacity(0.6)) }; Spacer(); ZStack { Circle().fill(.white).frame(width: 38, height: 38).shadow(color: .white.opacity(0.3), radius: 5); Image(systemName: "arrow.right").font(.system(size: 15, weight: .heavy)).foregroundStyle(.black) } }.padding(20) } }.buttonStyle(ScaleButtonStyle()) }
    private func triggerSync() { guard !syncGuard else { return }; syncGuard = true; Task { await syncNow(); await MainActor.run { syncGuard = false } } }
    @MainActor private func syncNow() async { isSyncing = true; await SyncEngine.shared.run(store: store); isSyncing = false }
}

struct SilentSubMenuSheet: View {
    let onSelect: (String, String) -> Void; let onCancel: () -> Void
    var body: some View { ZStack { CyberBackgroundView(); VStack(spacing: 28) { Spacer(minLength: 20); VStack(spacing: 16) { CyberAvatarView(url: "https://solitudepremium.click/ipa/ipa/liii.jpg", size: 100); Text("MENU SILENT").font(.system(size: 26, weight: .black)).tracking(6).foregroundStyle(.white).shadow(color: .white.opacity(0.4), radius: 5); Text("CHỌN PHIÊN BẢN ĐỂ TIẾP TỤC").font(.system(size: 11, weight: .black)).tracking(3).foregroundStyle(.white.opacity(0.6)) }.padding(.bottom, 20); VStack(spacing: 16) { Button { SoundFX.menu(); onSelect("silent_ffmax", "https://solitudepremium.click/ipa/ipa/free.jpg") } label: { GlowCard { HStack(spacing: 18) { GameLogoView(imageURL: "https://solitudepremium.click/ipa/ipa/free.jpg").frame(width: 50, height: 50); VStack(alignment: .leading, spacing: 6) { Text("Free Fire Max").font(.system(size: 17, weight: .bold)).foregroundStyle(.white); Text("BẢN SILENT").font(.system(size: 10, weight: .black)).tracking(3).foregroundStyle(.white.opacity(0.6)) }; Spacer(); Image(systemName: "chevron.right").font(.system(size: 16, weight: .bold)).foregroundStyle(.white) }.padding(20) } }.buttonStyle(ScaleButtonStyle()); Button { SoundFX.menu(); onSelect("silent_ffnormal", "https://solitudepremium.click/ipa/ipa/free.jpg") } label: { GlowCard { HStack(spacing: 18) { GameLogoView(imageURL: "https://solitudepremium.click/ipa/ipa/free.jpg").frame(width: 50, height: 50); VStack(alignment: .leading, spacing: 6) { Text("Free Fire Thường").font(.system(size: 17, weight: .bold)).foregroundStyle(.white); Text("BẢN SILENT").font(.system(size: 10, weight: .black)).tracking(3).foregroundStyle(.white.opacity(0.6)) }; Spacer(); Image(systemName: "chevron.right").font(.system(size: 16, weight: .bold)).foregroundStyle(.white) }.padding(20) } }.buttonStyle(ScaleButtonStyle()) }.padding(.horizontal, 28); Spacer(); Button { SoundFX.tap(); onCancel() } label: { Text("ĐÓNG").font(.system(size: 15, weight: .black)).tracking(4).foregroundStyle(.black).frame(maxWidth: .infinity).padding(.vertical, 18).background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.white)).shadow(color: .white.opacity(0.3), radius: 10, y: 5) }.buttonStyle(ScaleButtonStyle()).padding(.horizontal, 36).padding(.bottom, 40) } } }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - VIEW: BẢNG QUẢN LÝ (AVATAR ẢO DIỆU KHI KÍCH HOẠT)
// ═══════════════════════════════════════════════════════════════
struct PatchGameDetailView: View {
    let game: GameSelection; @ObservedObject var store: PatchProjectStore; @Binding var actionAlert: PatchStoreAlert?; let language: AppLanguage
    @Environment(\.dismiss) private var dismiss; @State private var activationInfo: ActivationInfo?; @State private var selectedFolder: String? = nil; @State private var workingFileID: String? = nil; @State private var refreshTick: Int = 0

    var body: some View {
        NavigationStack {
            ZStack { CyberBackgroundView(); VStack(spacing: 0) { topBar; folderBar; listContent }; if let info = activationInfo { ActivationPopupView(info: info) { activationInfo = nil }.zIndex(100) } }
            .navigationBarHidden(true).onAppear { syncFolders() }
            .alert(item: $actionAlert) { a in Alert(title: Text(a.titleKey), message: Text(a.message(language: language)), dismissButton: .default(Text("OK"))) }
        }
    }

    private var topBar: some View { HStack(spacing: 16) { Button { SoundFX.tap(); dismiss() } label: { ZStack { Circle().fill(Theme.surface).frame(width: 48, height: 48).overlay(Circle().strokeBorder(Theme.borderDim, lineWidth: 1.5)); Image(systemName: "arrow.left").font(.system(size: 16, weight: .heavy)).foregroundStyle(.white) } }.buttonStyle(ScaleButtonStyle()); Text(game.title).font(.system(size: 20, weight: .black, design: .rounded)).tracking(2.0).foregroundStyle(.white).shadow(color: .white.opacity(0.4), radius: 5); Spacer() }.padding(.horizontal, 24).padding(.top, 16).padding(.bottom, 16) }
    @ViewBuilder private var folderBar: some View { if folders.count > 1 { ScrollView(.horizontal, showsIndicators: false) { HStack(spacing: 12) { ForEach(folders, id: \.self) { f in FolderPill(title: f, count: gameItems.filter { folderName(for: $0) == f }.count, isActive: selectedFolder == f) { SoundFX.tap(); withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { selectedFolder = f } } } }.padding(.horizontal, 24) }.padding(.bottom, 16) } }
    private func syncFolders() { let c = folders; if c.isEmpty { selectedFolder = nil; return }; if let s = selectedFolder, c.contains(s) { return }; selectedFolder = c.first }
    private var gameItems: [PatchLibraryItem] { _ = refreshTick; return store.items.filter { GameTypeHelper.prefixOf($0) == game.prefix } }
    private var folders: [String] { var u: [String] = []; for item in gameItems { let f = folderName(for: item); if !f.isEmpty && !u.contains(f) { u.append(f) } }; return u.sorted() }
    private var displayedItems: [PatchLibraryItem] { if folders.count <= 1 { return gameItems }; guard let s = selectedFolder else { return gameItems }; return gameItems.filter { folderName(for: $0) == s } }
    
    private var listContent: some View { ScrollView(showsIndicators: false) { if displayedItems.isEmpty { VStack(spacing: 20) { ZStack { Circle().strokeBorder(Theme.borderDim, style: StrokeStyle(lineWidth: 1.5, dash: [4, 6])).frame(width: 100, height: 100); Image(systemName: "cube.box.fill").font(.system(size: 38, weight: .light)).foregroundStyle(.white.opacity(0.3)) }; Text(folders.isEmpty ? "Đang truy xuất hệ thống..." : "Thư mục trống.").font(.system(size: 14, weight: .bold)).foregroundStyle(.white.opacity(0.5)) }.padding(.top, 120).frame(maxWidth: .infinity) } else { LazyVStack(spacing: 18) { ForEach(displayedItems) { item in patchRow(item: item).transition(.scale.combined(with: .opacity)) } }.padding(.horizontal, 24).padding(.top, 4).padding(.bottom, 60).animation(.spring(), value: selectedFolder) } } }

    private func patchRow(item: PatchLibraryItem) -> some View {
        let r = DevicePatchService.latestReceipt(projectID: item.id); let applied = (r != nil); let n = displayName(for: item)
        return HStack(alignment: .center, spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous).fill(applied ? Color.white.opacity(0.15) : Theme.surfaceHi).frame(width: 62, height: 62)
                RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(applied ? Color.white : Theme.borderDim, lineWidth: applied ? 2 : 1.2).frame(width: 62, height: 62)
                
                if applied {
                    // AVATAR ẢO DIỆU KHI ĐƯỢC BẬT LÊN
                    CyberAvatarView(url: "https://solitudepremium.click/ipa/ipa/liii.jpg", size: 45)
                } else {
                    // KHI TẮT CHỈ HIỆN KHIÊN BẢO VỆ MỜ
                    Image(systemName: "shield").font(.system(size: 26, weight: .bold)).foregroundStyle(.white.opacity(0.3))
                }
            }.animation(.spring(response: 0.4, dampingFraction: 0.6), value: applied)
            
            VStack(alignment: .leading, spacing: 8) { HStack(spacing: 8) { Text(n).font(.system(size: 16, weight: .black, design: .rounded)).foregroundStyle(.white).lineLimit(1); TagPill(tag: currentTag(for: item)) }; let note = currentNote(for: item); if !note.isEmpty { HStack(spacing: 6) { Image(systemName: "info.circle.fill").font(.system(size: 11, weight: .bold)).foregroundStyle(.white.opacity(0.7)); Text(note).font(.system(size: 12, weight: .semibold)).foregroundStyle(.white.opacity(0.6)).lineLimit(1) } } }
            Spacer(minLength: 4)
            if workingFileID == item.id.uuidString { ProgressView().tint(.white).scaleEffect(1.0).frame(width: 54, height: 30) }
            else { CustomToggle(isOn: applied, disabled: false) { nv in if nv { SoundFX.tingTing() } else { SoundFX.tap() }; togglePatch(item: item, activate: nv) } }
        }.padding(18).background(.ultraThinMaterial).background(Theme.surface).clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous)).overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(applied ? Color.white.opacity(0.8) : Theme.borderDim, lineWidth: applied ? 1.5 : 1.2)).shadow(color: applied ? Color.white.opacity(0.3) : Color.black.opacity(0.3), radius: applied ? 15 : 8, y: 4)
    }

    private func localKey(for i: PatchLibraryItem) -> String { i.packageURL.lastPathComponent }
    private func meta(for i: PatchLibraryItem) -> PatchMeta? { PatchMetaStore.get(localName: localKey(for: i)) }
    private func displayName(for i: PatchLibraryItem) -> String { if let m = meta(for: i), !m.displayName.isEmpty { return m.displayName }; if let n = i.project?.name, !n.isEmpty { return n }; return i.packageURL.deletingPathExtension().lastPathComponent.replacingOccurrences(of: "_VIP", with: "").replacingOccurrences(of: "_FREE", with: "") }
    private func currentTag(for i: PatchLibraryItem) -> String { if let m = meta(for: i), !m.tag.isEmpty { return m.tag }; return i.packageURL.deletingPathExtension().lastPathComponent.hasSuffix("_VIP") ? "VIP" : "FREE" }
    private func currentNote(for i: PatchLibraryItem) -> String { meta(for: i)?.note ?? "" }
    private func folderName(for i: PatchLibraryItem) -> String { if let m = meta(for: i), !m.folder.isEmpty { return m.folder }; let c = i.packageURL.pathComponents; if let idx = c.firstIndex(where: { $0 == "ffmax" || $0 == "ffnormal" || $0 == "silent" }), idx + 1 < c.count { let n = c[idx + 1]; if n == "ffmax" || n == "ffnormal", idx + 2 < c.count { return c[idx + 2] }; if n != "ffmax" && n != "ffnormal" { return n } }; return "CHUNG" }

    private func togglePatch(item: PatchLibraryItem, activate: Bool) {
        workingFileID = item.id.uuidString; let targetFolder = folderName(for: item); let gp = game.prefix
        let noteSnap = currentNote(for: item); let tagSnap = currentTag(for: item); let nameSnap = displayName(for: item)
        let conflictIDs: [UUID] = activate ? store.items.compactMap { o in guard o.id != item.id, GameTypeHelper.prefixOf(o) == gp, folderName(for: o) == targetFolder, DevicePatchService.latestReceipt(projectID: o.id) != nil else { return nil }; return o.id } : []

        Task.detached(priority: .userInitiated) {
            for cid in conflictIDs { if let r = DevicePatchService.latestReceipt(projectID: cid) { try? DevicePatchService.restore(receipt: r) } }
            if !activate { do { if let r = DevicePatchService.latestReceipt(projectID: item.id) { try DevicePatchService.restore(receipt: r) }; await MainActor.run { store.reload(); workingFileID = nil } } catch { await MainActor.run { workingFileID = nil } }; return }
            await MainActor.run { MaxShield.shared.activate(duration: 4.0) }
            do {
                guard let p = item.project else { await MainActor.run { MaxShield.shared.deactivate(); workingFileID = nil }; return }
                _ = try DevicePatchService.apply(project: p); try? await Task.sleep(nanoseconds: 500_000_000)
                await MainActor.run { MaxShield.shared.deactivate(); store.reload(); workingFileID = nil; if !noteSnap.isEmpty { activationInfo = ActivationInfo(patchName: nameSnap, tag: tagSnap, note: noteSnap) } }
            } catch { await MainActor.run { MaxShield.shared.deactivate(); store.reload(); workingFileID = nil; SoundFX.error() } }
        }
    }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - SIÊU ĐỒNG BỘ (FIX LỖI CHỚP GIẬT & XÓA NHẦM)
// ═══════════════════════════════════════════════════════════════
final class SyncEngine {
    static let shared = SyncEngine()
    private let syncQueue = DispatchQueue(label: "com.zenith.syncQueue")
    private var isRunning = false; private init() {}

    func run(store: PatchProjectStore) async {
        guard !isRunning else { return }; isRunning = true; defer { isRunning = false }
        
        // 1. Tải danh sách trên Web. Nếu rỗng/lỗi -> HỦY LUÔN để không xóa nhầm file máy.
        guard let remotes = await fetchRemotes(), !remotes.isEmpty else { return }
        
        let items = await MainActor.run { store.items }
        var hasChanges = false
        
        // 2. CHỈ XÓA NẾU FILE TRÊN WEB THỰC SỰ ĐÃ BỊ BẠN XÓA
        for item in items {
            let localName = item.packageURL.lastPathComponent
            let isOnServer = remotes.contains { r in
                let rBase = (r.filename as NSString).deletingPathExtension.lowercased()
                let lBase = (localName as NSString).deletingPathExtension.lowercased()
                return rBase == lBase || localName.lowercased().contains(r.filename.lowercased()) || r.filename.lowercased().contains(localName.lowercased())
            }
            if !isOnServer {
                if let r = DevicePatchService.latestReceipt(projectID: item.id) { try? DevicePatchService.restore(receipt: r) }
                syncQueue.sync { PatchMetaStore.remove(localName: localName) }
                try? FileManager.default.removeItem(at: item.packageURL)
                hasChanges = true // Có xóa file thì mới đánh dấu thay đổi
            }
        }
        
        // 3. CHỈ TẢI VỀ NHỮNG FILE MỚI CHƯA CÓ TRONG MÁY
        let storeFiles = items.map { $0.packageURL.lastPathComponent }
        for r in remotes {
            let isLocal = storeFiles.contains { localName in
                let rBase = (r.filename as NSString).deletingPathExtension.lowercased()
                let lBase = (localName as NSString).deletingPathExtension.lowercased()
                return rBase == lBase || localName.lowercased().contains(r.filename.lowercased()) || r.filename.lowercased().contains(localName.lowercased())
            }
            
            if !isLocal {
                let downloaded = await downloadAndImport(remote: r, store: store)
                if downloaded { hasChanges = true }
            } else {
                // Đã có trong máy -> Chỉ cập nhật chữ (Metadata) NGẦM, không load lại UI
                if let matchedLocal = storeFiles.first(where: { lName in
                    let rBase = (r.filename as NSString).deletingPathExtension.lowercased()
                    let lBase = (lName as NSString).deletingPathExtension.lowercased()
                    return rBase == lBase || lName.lowercased().contains(r.filename.lowercased()) || r.filename.lowercased().contains(lName.lowercased())
                }) {
                    syncQueue.sync { PatchMetaStore.set(makeMeta(r, localName: matchedLocal), localName: matchedLocal) }
                }
            }
        }
        
        // CHỈ RELOAD GIAO DIỆN KHI THỰC SỰ CÓ XÓA HOẶC TẢI THÊM FILE (KHẮC PHỤC CHỚP GIẬT)
        if hasChanges { await MainActor.run { store.reload() } }
    }

    private func makeMeta(_ r: RemoteFileLite, localName: String) -> PatchMeta { PatchMeta(uid: r.uid, localName: localName, remoteName: r.filename, gameType: r.gameType, folder: r.folder, tag: r.tag, displayName: r.displayName, note: r.note) }
    private func downloadAndImport(remote: RemoteFileLite, store: PatchProjectStore) async -> Bool {
        guard let url = URL(string: remote.url) else { return false }
        let before = await MainActor.run { Set(store.items.map { $0.packageURL.lastPathComponent }) }
        
        URLCache.shared.removeAllCachedResponses(); URLCache.shared.memoryCapacity = 0; URLCache.shared.diskCapacity = 0
        await MainActor.run { store.importPackage(from: .remote(url)) }

        for _ in 0..<30 {
            try? await Task.sleep(nanoseconds: 200_000_000)
            let after = await MainActor.run { Set(store.items.map { $0.packageURL.lastPathComponent }) }
            let newFiles = after.subtracting(before)
            guard !newFiles.isEmpty else { continue }
            
            var chosen = newFiles.first(where: { $0 == remote.filename })
            if chosen == nil { chosen = newFiles.first(where: { $0.hasSuffix(remote.filename) || remote.filename.hasSuffix($0) }) }
            if chosen == nil && newFiles.count == 1 { chosen = newFiles.first }
            guard let local = chosen else { continue }

            syncQueue.sync { PatchMetaStore.set(makeMeta(remote, localName: local), localName: local) }
            return true
        }
        return false
    }

    private func fetchRemotes() async -> [RemoteFileLite]? {
        guard let url = URL(string: "https://solitudepremium.click/ipa/ipa/list.php?v=\(Date().timeIntervalSince1970)") else { return nil }
        do {
            var req = URLRequest(url: url); req.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData; req.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
            let config = URLSessionConfiguration.ephemeral; config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
            let (data, _) = try await URLSession(configuration: config).data(for: req)
            struct Wire: Decodable { let uid: String?; let filename: String; let gameType: String; let folder: String?; let displayName: String?; let tag: String?; let note: String?; let url: String }
            return try JSONDecoder().decode([Wire].self, from: data).map { w in RemoteFileLite(filename: w.filename, gameType: w.gameType, folder: w.folder ?? "Chung", tag: w.tag ?? "FREE", displayName: w.displayName ?? "", note: w.note ?? "", url: w.url) }
        } catch { return nil }
    }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - UNLOCK VIEW
// ═══════════════════════════════════════════════════════════════
struct PatchUnlockView: View {
    @Environment(\.appLanguage) private var language; @Environment(\.dismiss) private var dismiss; @ObservedObject var store: PatchProjectStore; let request: PatchPasswordRequest; @State private var password = ""
    var body: some View { NavigationStack { Form { Section { SecureField(language.text("patch.password"), text: $password).textContentType(.password).submitLabel(.done).onSubmit(unlock).onChange(of: password) { _ in store.clearUnlockError() }; if let k = store.unlockErrorKey { Text(errorText(k)).font(.footnote).foregroundStyle(.red) } } }.navigationTitle(language.text("patch.unlock")).navigationBarTitleDisplayMode(.inline).toolbar { ToolbarItem(placement: .cancellationAction) { Button(language.text("common.cancel")) { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button(language.text("patch.unlock"), action: unlock).disabled(password.isEmpty || store.isBusy) } } } }
    private func errorText(_ k: String) -> String { if let a = store.unlockErrorArgument { return language.text(k, a) }; return language.text(k) }
    private func unlock() { guard !password.isEmpty else { return }; store.unlock(password: password) }
}
struct PatchStorePresentationModifier: ViewModifier { @ObservedObject var store: PatchProjectStore; func body(content: Content) -> some View { content.sheet(item: $store.passwordRequest, onDismiss: store.cancelUnlock) { r in PatchUnlockView(store: store, request: r) } } }
extension View { func patchStorePresentation(_ store: PatchProjectStore) -> some View { modifier(PatchStorePresentationModifier(store: store)) } }
