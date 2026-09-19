import SwiftUI
import UIKit
import UniformTypeIdentifiers
import AudioToolbox

// ═══════════════════════════════════════════════════════════════
// MARK: - SOUND FX
// ═══════════════════════════════════════════════════════════════
enum SoundFX {
    static func tap()      { AudioServicesPlaySystemSound(1104) }
    static func menu()     { AudioServicesPlaySystemSound(1105) }
    static func error()    { AudioServicesPlaySystemSound(1053) }
    static func success()  { AudioServicesPlaySystemSound(1057) }
    static func tingTing() {
        AudioServicesPlaySystemSound(1057)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
            AudioServicesPlaySystemSound(1057)
        }
    }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - MAX SHIELD
// ═══════════════════════════════════════════════════════════════
final class MaxShield {
    static let shared = MaxShield()
    private var win: UIWindow?
    private var timer: Timer?
    private var hideTimer: Timer?

    private init() {}

    func activate(duration: TimeInterval = 12.0) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.deactivate()
            guard let scene = UIApplication.shared.connectedScenes
                    .compactMap({ $0 as? UIWindowScene }).first else { return }
            let w = UIWindow(windowScene: scene)
            w.windowLevel = UIWindow.Level.alert + 999999
            w.backgroundColor = .black
            w.rootViewController = UIHostingController(rootView: ShieldView())
            w.rootViewController?.view.backgroundColor = .black
            w.makeKeyAndVisible()
            self.win = w

            self.timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                w.isHidden = false
                w.alpha = 1
            }
            if let t = self.timer { RunLoop.main.add(t, forMode: .common) }

            self.hideTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { _ in
                self.deactivate()
            }
        }
    }

    func deactivate() {
        DispatchQueue.main.async { [weak self] in
            self?.timer?.invalidate(); self?.timer = nil
            self?.hideTimer?.invalidate(); self?.hideTimer = nil
            self?.win?.isHidden = true
            self?.win = nil
        }
    }
}

private struct ShieldView: View {
    @State private var pulse = false
    @State private var dots = ""

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 28) {
                ZStack {
                    Circle()
                        .strokeBorder(Color.white.opacity(0.15), lineWidth: 1.5)
                        .frame(width: 140, height: 140)
                        .scaleEffect(pulse ? 1.15 : 0.92)
                    Circle()
                        .fill(Color.white.opacity(0.05))
                        .frame(width: 100, height: 100)
                    ProgressView().tint(.white).scaleEffect(1.6)
                }
                VStack(spacing: 10) {
                    Text("HEADLOCK ZENIS").font(.system(size: 11, weight: .heavy))
                        .tracking(4.5).foregroundStyle(.white.opacity(0.6))
                    Text("ĐANG KÍCH HOẠT\(dots)").font(.system(size: 16, weight: .heavy))
                        .tracking(2.5).foregroundStyle(.white)
                    Text("Vui lòng không thoát ứng dụng")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5)).padding(.top, 4)
                }
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.3).repeatForever(autoreverses: true)) { pulse = true }
            Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { _ in
                let n = (dots.count + 1) % 4
                dots = String(repeating: ".", count: n)
            }
        }
    }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - THEME V15 (COMMERCIAL)
// ═══════════════════════════════════════════════════════════════
enum Theme {
    static let surface    = Color(red: 0.05, green: 0.05, blue: 0.05)
    static let surfaceHi  = Color(red: 0.08, green: 0.08, blue: 0.08)
    static let surfaceTop = Color(red: 0.12, green: 0.12, blue: 0.12)
    static let gold       = Color(red: 0.90, green: 0.75, blue: 0.45)
    static let danger     = Color(red: 1.0,  green: 0.32, blue: 0.32)
    static let success    = Color(red: 0.20, green: 0.85, blue: 0.45)
}

struct NeonBackgroundView: View {
    var body: some View {
        ZStack {
            Color.black
            RadialGradient(colors: [Color.white.opacity(0.06), .clear],
                center: .topLeading, startRadius: 0, endRadius: 600)
            RadialGradient(colors: [Color.white.opacity(0.04), .clear],
                center: .bottomTrailing, startRadius: 0, endRadius: 600)
        }.ignoresSafeArea()
    }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - MODELS
// ═══════════════════════════════════════════════════════════════
struct GameSelection: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let prefix: String
}

struct PatchMeta: Codable {
    var uid: String
    var localName: String
    var remoteName: String
    var gameType: String
    var folder: String
    var tag: String
    var displayName: String
    var note: String
    var tagOverride: Bool
    var nameOverride: Bool
    var noteOverride: Bool

    init(uid: String = "", localName: String = "", remoteName: String = "",
         gameType: String = "", folder: String = "", tag: String = "FREE",
         displayName: String = "", note: String = "",
         tagOverride: Bool = false, nameOverride: Bool = false,
         noteOverride: Bool = false) {
        self.uid = uid; self.localName = localName
        self.remoteName = remoteName; self.gameType = gameType
        self.folder = folder; self.tag = tag
        self.displayName = displayName; self.note = note
        self.tagOverride = tagOverride; self.nameOverride = nameOverride
        self.noteOverride = noteOverride
    }
}

struct RemoteFileLite: Decodable {
    let uid: String
    let filename: String
    let gameType: String
    let folder: String
    let displayName: String
    let tag: String
    let note: String
    let url: String
}

struct ActivationInfo: Identifiable {
    let id = UUID()
    let patchName: String
    let tag: String
    let note: String
    let success: Bool
    let errorMessage: String?
}

// ═══════════════════════════════════════════════════════════════
// MARK: - META STORE
// ═══════════════════════════════════════════════════════════════
enum PatchMetaStore {
    private static let key = "patch_meta_commercial_v15"

    static func all() -> [String: PatchMeta] {
        guard let d = UserDefaults.standard.data(forKey: key),
              let x = try? JSONDecoder().decode([String: PatchMeta].self, from: d)
        else { return [:] }
        return x
    }
    static func save(_ d: [String: PatchMeta]) {
        if let x = try? JSONEncoder().encode(d) {
            UserDefaults.standard.set(x, forKey: key)
        }
    }
    static func set(_ m: PatchMeta, localName: String) {
        var d = all(); d[localName] = m; save(d)
    }
    static func get(localName: String) -> PatchMeta? { all()[localName] }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - GAME TYPE HELPER
// ═══════════════════════════════════════════════════════════════
enum GameTypeHelper {
    static let allPrefixes = ["ffmax", "ffnormal", "silent_ffmax", "silent_ffnormal"]

    static func prefixOf(_ item: PatchLibraryItem) -> String {
        let name = item.packageURL.lastPathComponent
        let sorted = allPrefixes.sorted { $0.count > $1.count }
        for p in sorted where name.hasPrefix("\(p)_") { return p }
        if let m = PatchMetaStore.get(localName: name), !m.gameType.isEmpty {
            return m.gameType
        }
        let c = item.packageURL.pathComponents
        if c.contains("silent") {
            if c.contains("ffmax") { return "silent_ffmax" }
            if c.contains("ffnormal") { return "silent_ffnormal" }
            return "silent_ffnormal"
        }
        if c.contains("ffmax") { return "ffmax" }
        if c.contains("ffnormal") { return "ffnormal" }
        return "ffnormal"
    }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - UI COMPONENTS
// ═══════════════════════════════════════════════════════════════
private struct GlowCard<Content: View>: View {
    @ViewBuilder let content: Content
    var body: some View {
        content
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(LinearGradient(colors: [Theme.surfaceTop, Theme.surface],
                    startPoint: .top, endPoint: .bottom)))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(LinearGradient(
                    colors: [.white.opacity(0.8), .white.opacity(0.1), .white.opacity(0.3)],
                    startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.2))
            .shadow(color: .white.opacity(0.05), radius: 14)
            .shadow(color: .black.opacity(0.6), radius: 10, y: 8)
    }
}

private struct GameLogoView: View {
    let imageURL: String
    var body: some View {
        AsyncImage(url: URL(string: imageURL)) { p in
            switch p {
            case .empty:
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.surfaceHi)
                    ProgressView().tint(.white).scaleEffect(0.8)
                }
            case .success(let img):
                img.resizable().scaledToFill()
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            case .failure:
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.surfaceHi)
                    Image(systemName: "flame.fill").font(.system(size: 22, weight: .bold)).foregroundStyle(.white)
                }
            @unknown default: EmptyView()
            }
        }
        .frame(width: 60, height: 60)
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.white.opacity(0.8), lineWidth: 1.2))
    }
}

enum AvatarShape { case circle, roundedSquare }

private struct ServerAvatarView: View {
    let size: CGFloat
    var shape: AvatarShape = .circle
    var corner: CGFloat = 16

    var body: some View {
        let imgView = AsyncImage(url: URL(string: "https://solitudepremium.click/ipa/ipa/liii.jpg")) { p in
            switch p {
            case .empty: ZStack { fill; ProgressView().tint(.white).scaleEffect(0.8) }
            case .success(let img): img.resizable().scaledToFill()
            case .failure: ZStack { fill; Image(systemName: "person.fill").foregroundStyle(.white.opacity(0.5)) }
            @unknown default: EmptyView()
            }
        }
        .frame(width: size, height: size)
        
        // Fixed Swift 6 Concurrency Issue - No longer using AnyShape
        if shape == .circle {
            imgView
                .clipShape(Circle())
                .overlay(Circle().strokeBorder(.white.opacity(0.8), lineWidth: 1.2))
        } else {
            imgView
                .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: corner, style: .continuous).strokeBorder(.white.opacity(0.8), lineWidth: 1.2))
        }
    }
    
    @ViewBuilder private var fill: some View {
        if shape == .circle {
            Circle().fill(Theme.surfaceHi)
        } else {
            RoundedRectangle(cornerRadius: corner, style: .continuous).fill(Theme.surfaceHi)
        }
    }
}

private struct AvatarView: View {
    @State private var rotate = false
    @State private var pulse = false
    var body: some View {
        ZStack {
            Circle().fill(Color.white.opacity(0.1))
                .frame(width: pulse ? 128 : 110, height: pulse ? 128 : 110)
                .blur(radius: 20)
            Circle()
                .strokeBorder(Color.white.opacity(0.2), style: StrokeStyle(lineWidth: 1, dash: [3, 6]))
                .frame(width: 116, height: 116)
                .rotationEffect(.degrees(rotate ? 360 : 0))
            Circle()
                .strokeBorder(LinearGradient(colors: [.white, .white.opacity(0.1), .white],
                    startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.5)
                .frame(width: 96, height: 96)
            ServerAvatarView(size: 80, shape: .circle)
        }
        .frame(width: 130, height: 130)
        .onAppear {
            withAnimation(.linear(duration: 24).repeatForever(autoreverses: false)) { rotate = true }
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) { pulse = true }
        }
    }
}

private struct ChevronCircle: View {
    var body: some View {
        ZStack {
            Circle().fill(.white).frame(width: 36, height: 36)
                .shadow(color: .white.opacity(0.3), radius: 8)
            Image(systemName: "arrow.up.right").font(.system(size: 13, weight: .heavy))
                .foregroundStyle(.black)
        }
    }
}

private struct TagPill: View {
    let tag: String
    private var isVIP: Bool { tag == "VIP" }
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: isVIP ? "crown.fill" : "shield.fill").font(.system(size: 8, weight: .heavy))
            Text(tag).font(.system(size: 9, weight: .heavy)).tracking(1.0)
        }
        .padding(.horizontal, 8).padding(.vertical, 4)
        .foregroundStyle(isVIP ? Theme.gold : .white)
        .background(Capsule().fill(isVIP ? Theme.gold.opacity(0.15) : Color.white.opacity(0.08)))
        .overlay(Capsule().strokeBorder(isVIP ? Theme.gold : Color.white.opacity(0.5), lineWidth: 1.0))
    }
}

private struct PatchIconView: View {
    let tag: String
    let isApplied: Bool
    private var isVIP: Bool { tag == "VIP" }
    var body: some View {
        ZStack {
            if isApplied {
                ServerAvatarView(size: 54, shape: .circle)
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .fill(isVIP ? Theme.gold.opacity(0.1) : Color.white.opacity(0.05))
                        .frame(width: 54, height: 54)
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .strokeBorder(isVIP ? Theme.gold.opacity(0.8) : Color.white.opacity(0.3), lineWidth: 1.2)
                        .frame(width: 54, height: 54)
                    Image(systemName: isVIP ? "crown.fill" : "shield.lefthalf.filled")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(isVIP ? Theme.gold : .white)
                }
            }
        }
    }
}

private struct CustomToggle: View {
    let isOn: Bool
    let disabled: Bool
    let action: (Bool) -> Void
    var body: some View {
        Button { if !disabled { action(!isOn) } } label: {
            ZStack {
                Capsule().fill(isOn ? Color.white : Color.white.opacity(0.08))
                    .frame(width: 54, height: 32)
                    .overlay(Capsule().strokeBorder(isOn ? .white : Color.white.opacity(0.4), lineWidth: 1.2))
                    .shadow(color: isOn ? .white.opacity(0.5) : .clear, radius: 10)
                HStack {
                    if isOn { Spacer(); Circle().fill(.black).frame(width: 24, height: 24).padding(.trailing, 3) }
                    else { Circle().fill(.white).frame(width: 24, height: 24).padding(.leading, 3); Spacer() }
                }.frame(width: 54, height: 32)
            }
            .animation(.spring(response: 0.26, dampingFraction: 0.72), value: isOn)
            .opacity(disabled ? 0.5 : 1.0)
        }.buttonStyle(.plain).disabled(disabled)
    }
}

private struct FolderPill: View {
    let title: String
    let count: Int
    let isActive: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Circle().fill(isActive ? Color.black : Color.white.opacity(0.5)).frame(width: 6, height: 6)
                Text(title).font(.system(size: 12, weight: .heavy)).tracking(1.0)
                    .foregroundStyle(isActive ? .black : .white)
                Text("\(count)").font(.system(size: 10, weight: .heavy))
                    .foregroundStyle(isActive ? .black.opacity(0.6) : .white.opacity(0.4))
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(Capsule().fill(isActive ? Color.white : Color.white.opacity(0.05)))
            .overlay(Capsule().strokeBorder(isActive ? Color.white : Color.white.opacity(0.2), lineWidth: 1.0))
            .shadow(color: isActive ? .white.opacity(0.4) : .clear, radius: 10)
        }.buttonStyle(.plain)
    }
}

private struct PatchCard: View {
    let isApplied: Bool
    let isWorking: Bool
    let displayName: String
    let tag: String
    let note: String
    let onToggle: (Bool) -> Void
    let onTapTag: () -> Void
    let onRename: () -> Void
    let onEditNote: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            PatchIconView(tag: tag, isApplied: isApplied)
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 8) {
                    Text(displayName).font(.system(size: 14.5, weight: .heavy))
                        .foregroundStyle(.white).lineLimit(1)
                    Button(action: onTapTag) { TagPill(tag: tag) }.buttonStyle(.plain)
                }
                if !note.isEmpty {
                    HStack(alignment: .top, spacing: 5) {
                        Image(systemName: "text.alignleft").font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white.opacity(0.4)).padding(.top, 2)
                        Text(note).font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.65)).lineLimit(2).multilineTextAlignment(.leading)
                    }
                }
            }
            Spacer(minLength: 4)
            if isWorking {
                ProgressView().tint(.white).scaleEffect(0.8).frame(width: 54, height: 32)
            } else {
                CustomToggle(isOn: isApplied, disabled: false) { onToggle($0) }
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(LinearGradient(colors: isApplied
                ? [Color.white.opacity(0.12), Color.white.opacity(0.04)]
                : [Color.white.opacity(0.04), Color.white.opacity(0.01)],
                startPoint: .topLeading, endPoint: .bottomTrailing)))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
            .strokeBorder(isApplied
                ? LinearGradient(colors: [.white, .white.opacity(0.4), .white],
                    startPoint: .topLeading, endPoint: .bottomTrailing)
                : LinearGradient(colors: [Color.white.opacity(0.2), Color.white.opacity(0.05)],
                    startPoint: .topLeading, endPoint: .bottomTrailing),
                lineWidth: isApplied ? 1.5 : 1.0))
        .shadow(color: isApplied ? .white.opacity(0.15) : .black.opacity(0.4),
                radius: isApplied ? 12 : 8, y: 4)
        .contextMenu {
            Button(action: onRename) { Label("Đổi tên", systemImage: "pencil") }
            Button(action: onTapTag) { Label("Đổi VIP/FREE", systemImage: "crown") }
            Button(action: onEditNote) { Label("Sửa ghi chú", systemImage: "note.text") }
        }
    }
}

private struct EmptyStateView: View {
    let message: String
    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle().strokeBorder(.white.opacity(0.2),
                    style: StrokeStyle(lineWidth: 1.4, dash: [3, 5])).frame(width: 84, height: 84)
                Image(systemName: "tray").font(.system(size: 30, weight: .light))
                    .foregroundStyle(.white.opacity(0.4))
            }
            Text(message).font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.5)).multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }.padding(.top, 70).frame(maxWidth: .infinity)
    }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - SILENT SUB-MENU
// ═══════════════════════════════════════════════════════════════
struct SilentSubMenuSheet: View {
    let onSelect: (String) -> Void
    let onCancel: () -> Void
    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            RadialGradient(colors: [Color.white.opacity(0.05), .clear],
                center: .top, startRadius: 0, endRadius: 500).ignoresSafeArea()
            VStack(spacing: 24) {
                Spacer(minLength: 30)
                VStack(spacing: 14) {
                    ServerAvatarView(size: 96, shape: .roundedSquare, corner: 22)
                    Text("MENU SILENT").font(.system(size: 22, weight: .heavy)).tracking(3)
                        .foregroundStyle(.white).shadow(color: .white.opacity(0.4), radius: 10)
                    Text("CHỌN PHIÊN BẢN GAME").font(.system(size: 10, weight: .heavy)).tracking(3.5)
                        .foregroundStyle(.white.opacity(0.5))
                }.padding(.bottom, 6)
                VStack(spacing: 14) {
                    optionCard("Free Fire Max", "PREMIUM EDITION", "silent_ffmax")
                    optionCard("Free Fire Thường", "CLASSIC EDITION", "silent_ffnormal")
                }.padding(.horizontal, 22)
                Spacer()
                Button { SoundFX.tap(); onCancel() } label: {
                    Text("HUỶ").font(.system(size: 13, weight: .heavy)).tracking(2.5)
                        .foregroundStyle(.white).frame(maxWidth: .infinity).padding(.vertical, 15)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.white.opacity(0.06)))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(.white.opacity(0.2), lineWidth: 1.0))
                        .padding(.horizontal, 40)
                }.buttonStyle(.plain).padding(.bottom, 40)
            }
        }
    }
    private func optionCard(_ t: String, _ s: String, _ p: String) -> some View {
        Button { SoundFX.menu(); onSelect(p) } label: {
            GlowCard {
                HStack(spacing: 16) {
                    ServerAvatarView(size: 64, shape: .roundedSquare, corner: 16)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(t).font(.system(size: 16, weight: .heavy, design: .rounded)).foregroundStyle(.white)
                        Text(s).font(.system(size: 9.5, weight: .heavy)).tracking(2)
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    Spacer()
                    ChevronCircle()
                }.padding(.horizontal, 16).padding(.vertical, 14)
            }
        }.buttonStyle(.plain)
    }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - ACTIVATION SHEET
// ═══════════════════════════════════════════════════════════════
struct ActivationNoteSheet: View {
    let info: ActivationInfo
    let onDismiss: () -> Void
    @State private var copied = false

    private var isError: Bool { !info.success }
    private var accent: Color { isError ? Theme.danger : .white }
    private var hasNote: Bool { !info.note.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            RadialGradient(colors: [accent.opacity(0.06), .clear],
                center: .top, startRadius: 0, endRadius: 500).ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 22) {
                    Spacer(minLength: 50)
                    if isError {
                        ZStack {
                            Circle().fill(accent.opacity(0.1)).frame(width: 130, height: 130).blur(radius: 20)
                            Circle().fill(accent).frame(width: 92, height: 92)
                                .shadow(color: accent.opacity(0.5), radius: 20)
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 38, weight: .heavy)).foregroundStyle(.black)
                        }
                    } else {
                        ZStack {
                            Circle().fill(Color.white.opacity(0.1)).frame(width: 130, height: 130).blur(radius: 20)
                            ServerAvatarView(size: 100, shape: .circle)
                                .shadow(color: .white.opacity(0.4), radius: 20)
                        }
                    }
                    if isError {
                        VStack(spacing: 10) {
                            Text("HEADLOCK ZENIS").font(.system(size: 11, weight: .heavy)).tracking(4.5)
                                .foregroundStyle(.white.opacity(0.5))
                            Text("KHÔNG KÍCH HOẠT ĐƯỢC").font(.system(size: 20, weight: .heavy)).tracking(2)
                                .foregroundStyle(accent).multilineTextAlignment(.center).padding(.horizontal, 20)
                            Text(info.patchName).font(.system(size: 15, weight: .heavy))
                                .foregroundStyle(.white).multilineTextAlignment(.center).padding(.horizontal, 28)
                            if !info.tag.isEmpty { TagPill(tag: info.tag) }
                        }
                    } else {
                        VStack(spacing: 12) {
                            Text("HEADLOCK ZENIS").font(.system(size: 13, weight: .heavy)).tracking(4.5)
                                .foregroundStyle(.white.opacity(0.8))
                            Text("ĐÃ CẬP NHẬT THÀNH CÔNG").font(.system(size: 15, weight: .heavy)).tracking(2)
                                .foregroundStyle(.white).multilineTextAlignment(.center).padding(.horizontal, 20)
                            Text("BẠN CÓ THỂ SỬ DỤNG").font(.system(size: 13, weight: .heavy)).tracking(2.5)
                                .foregroundStyle(.white.opacity(0.6)).multilineTextAlignment(.center).padding(.horizontal, 20)
                            Text(info.patchName).font(.system(size: 18, weight: .heavy))
                                .foregroundStyle(.white).multilineTextAlignment(.center)
                                .padding(.horizontal, 28).padding(.top, 4)
                            if !info.tag.isEmpty { TagPill(tag: info.tag) }
                        }
                    }
                    if isError, let e = info.errorMessage, !e.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("LÝ DO").font(.system(size: 10, weight: .heavy)).tracking(2.2).foregroundStyle(accent)
                            Text(e).font(.system(size: 12.5, weight: .medium))
                                .foregroundStyle(.white.opacity(0.9)).fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(accent.opacity(0.08)))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(accent.opacity(0.4), lineWidth: 1.0))
                        .padding(.horizontal, 24)
                    }
                    if hasNote {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack(spacing: 8) {
                                Image(systemName: "note.text").font(.system(size: 12, weight: .bold)).foregroundStyle(.white)
                                Text("GHI CHÚ").font(.system(size: 10, weight: .heavy)).tracking(2.2).foregroundStyle(.white)
                                Spacer()
                            }
                            Text(info.note).font(.system(size: 13.5, weight: .medium))
                                .foregroundStyle(.white.opacity(0.9)).fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .leading).padding(14)
                                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.white.opacity(0.05)))
                                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(.white.opacity(0.2), style: StrokeStyle(lineWidth: 1, dash: [4, 4])))
                            Button {
                                SoundFX.tap()
                                UIPasteboard.general.string = info.note
                                withAnimation { copied = true }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { withAnimation { copied = false } }
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: copied ? "checkmark" : "doc.on.doc.fill")
                                        .font(.system(size: 12, weight: .heavy))
                                    Text(copied ? "ĐÃ COPY" : "COPY GHI CHÚ")
                                        .font(.system(size: 11.5, weight: .heavy)).tracking(1.8)
                                }
                                .foregroundStyle(copied ? .black : .white)
                                .frame(maxWidth: .infinity).padding(.vertical, 13)
                                .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(copied ? Color.white : Color.white.opacity(0.06)))
                                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(.white, lineWidth: 1.0))
                            }.buttonStyle(.plain)
                        }
                        .padding(18)
                        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.surface))
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(.white.opacity(0.2), lineWidth: 1.0))
                        .padding(.horizontal, 22)
                    }
                    Button { SoundFX.tap(); onDismiss() } label: {
                        Text("ĐÃ HIỂU").font(.system(size: 14, weight: .heavy)).tracking(3)
                            .foregroundStyle(.black).frame(maxWidth: .infinity).padding(.vertical, 16)
                            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.white))
                            .padding(.horizontal, 40)
                    }.buttonStyle(.plain).padding(.bottom, 50)
                }
            }
        }
    }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - MAIN VIEW
// ═══════════════════════════════════════════════════════════════
struct PatchProjectsView: View {
    @Environment(\.appLanguage) private var language
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var draftCoordinator: PatchDraftCoordinator
    @EnvironmentObject private var store: PatchProjectStore

    @State private var actionAlert: PatchStoreAlert?
    @State private var selectedGame: GameSelection?
    @State private var showSilentSubmenu = false
    @State private var isSyncing = false
    @State private var syncGuard = false

    let onOpenSettings: () -> Void
    let onOpenLogs: () -> Void

    init(onOpenSettings: @escaping () -> Void = {}, onOpenLogs: @escaping () -> Void = {}) {
        self.onOpenSettings = onOpenSettings
        self.onOpenLogs = onOpenLogs
    }

    var body: some View {
        NavigationStack {
            ZStack {
                NeonBackgroundView()
                VStack(spacing: 0) { header; content }
            }
            .navigationBarHidden(true)
            .onAppear { store.reload() }
            .task { await triggerSync() }
            .onChange(of: scenePhase) { p in
                if p == .active { store.reload(); Task { await triggerSync() } }
            }
            .sheet(item: $selectedGame) { g in
                PatchGameDetailView(game: g, store: store, actionAlert: $actionAlert, language: language)
            }
            .sheet(isPresented: $showSilentSubmenu) {
                SilentSubMenuSheet(
                    onSelect: { prefix in
                        showSilentSubmenu = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            selectedGame = GameSelection(
                                title: prefix == "silent_ffmax" ? "Menu Silent · FF Max" : "Menu Silent · FF Thường",
                                prefix: prefix)
                        }
                    },
                    onCancel: { showSilentSubmenu = false })
            }
            .alert(item: $actionAlert) { a in
                Alert(title: Text(a.titleKey), message: Text(a.message(language: language)),
                      dismissButton: .default(Text("OK")))
            }
        }
    }

    private var header: some View {
        VStack(spacing: 0) {
            HStack { Spacer(); syncPill }
                .padding(.horizontal, 20).padding(.top, 10).padding(.bottom, 4)
            AvatarView().padding(.top, 6)
            Text("ZENITH SOLITUDE")
                .font(.system(size: 22, weight: .black, design: .serif))
                .tracking(3.5).foregroundStyle(.white)
                .shadow(color: .white.opacity(0.3), radius: 10).padding(.top, 14)
            HStack(spacing: 10) {
                Rectangle().fill(.white.opacity(0.3)).frame(width: 28, height: 1)
                Text("COMMERCIAL V15").font(.system(size: 9.5, weight: .heavy)).tracking(4.2)
                    .foregroundStyle(.white.opacity(0.5))
                Rectangle().fill(.white.opacity(0.3)).frame(width: 28, height: 1)
            }.padding(.top, 8).padding(.bottom, 22)
        }
    }

    private var syncPill: some View {
        HStack(spacing: 7) {
            ZStack {
                Circle().fill((isSyncing ? Color.yellow : Theme.success).opacity(0.2)).frame(width: 14, height: 14)
                Circle().fill(isSyncing ? Color.yellow : Theme.success).frame(width: 7, height: 7)
                    .shadow(color: (isSyncing ? Color.yellow : Theme.success).opacity(0.8), radius: 6)
            }
            Text(isSyncing ? "ĐANG CẬP NHẬT" : "ĐÃ KẾT NỐI").font(.system(size: 9, weight: .heavy))
                .tracking(1.6).foregroundStyle(.white.opacity(0.7))
        }
        .padding(.horizontal, 12).padding(.vertical, 7)
        .background(Capsule().fill(Color.white.opacity(0.08)))
        .overlay(Capsule().strokeBorder(.white.opacity(0.2), lineWidth: 1))
    }

    private var content: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {
                gameCard("Free Fire Max", "PREMIUM EDITION", "ffmax", "https://solitudepremium.click/ipa/ipa/free.jpg")
                gameCard("Free Fire Thường", "CLASSIC EDITION", "ffnormal", "https://solitudepremium.click/ipa/ipa/free.jpg")
                silentCard()
                HStack(spacing: 8) {
                    Rectangle().fill(.white.opacity(0.15)).frame(height: 1)
                    Text("BY ZENITH SOLITUDE").font(.system(size: 9, weight: .heavy)).tracking(3)
                        .foregroundStyle(.white.opacity(0.4)).fixedSize()
                    Rectangle().fill(.white.opacity(0.15)).frame(height: 1)
                }.padding(.horizontal, 40).padding(.top, 22)
            }.padding(.horizontal, 16).padding(.bottom, 50)
        }.refreshable { await triggerSync() }
    }

    private func gameCard(_ t: String, _ s: String, _ p: String, _ u: String) -> some View {
        Button {
            SoundFX.menu()
            selectedGame = GameSelection(title: t, prefix: p)
        } label: {
            GlowCard {
                HStack(spacing: 14) {
                    GameLogoView(imageURL: u)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(t).font(.system(size: 16.5, weight: .heavy, design: .rounded)).foregroundStyle(.white)
                        Text(s).font(.system(size: 9.5, weight: .heavy)).tracking(2)
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    Spacer()
                    ChevronCircle()
                }.padding(.horizontal, 16).padding(.vertical, 15)
            }
        }.buttonStyle(.plain)
    }

    private func silentCard() -> some View {
        Button {
            SoundFX.menu(); showSilentSubmenu = true
        } label: {
            GlowCard {
                HStack(spacing: 14) {
                    ServerAvatarView(size: 60, shape: .roundedSquare, corner: 16)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Menu Silent").font(.system(size: 16.5, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                        Text("STEALTH MODE").font(.system(size: 9.5, weight: .heavy)).tracking(2)
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    Spacer()
                    ChevronCircle()
                }.padding(.horizontal, 16).padding(.vertical, 15)
            }
        }.buttonStyle(.plain)
    }

    @MainActor
    private func triggerSync() async {
        guard !syncGuard else { return }
        syncGuard = true; isSyncing = true
        await SyncEngine.shared.run(store: store)
        store.reload()
        try? await Task.sleep(nanoseconds: 200_000_000)
        store.reload()
        isSyncing = false; syncGuard = false
    }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - SYNC ENGINE (TỐI ƯU HÓA KHÔNG GÂY LOOP)
// ═══════════════════════════════════════════════════════════════
final class SyncEngine {
    static let shared = SyncEngine()
    private let lock = NSLock()
    private var isRunning = false
    private init() {}

    func run(store: PatchProjectStore) async {
        if isRunning { return }
        isRunning = true
        defer { isRunning = false }

        guard let remotes = await fetchRemotes() else { return }
        await MainActor.run { store.reload() }
        let items = await MainActor.run { store.items }
        let storeFiles = Set(items.map { $0.packageURL.lastPathComponent })

        for item in items {
            let ln = item.packageURL.lastPathComponent
            if PatchMetaStore.get(localName: ln) != nil { continue }
            if let r = remotes.first(where: { $0.filename == ln }) {
                lock.lock()
                PatchMetaStore.set(makeMeta(r, localName: ln), localName: ln)
                lock.unlock()
            }
        }

        var missing: [RemoteFileLite] = []
        for r in remotes {
            if !storeFiles.contains(r.filename) {
                missing.append(r)
            } else if PatchMetaStore.get(localName: r.filename) == nil {
                lock.lock()
                PatchMetaStore.set(makeMeta(r, localName: r.filename), localName: r.filename)
                lock.unlock()
            }
        }

        guard !missing.isEmpty else {
            await MainActor.run { store.reload() }
            return
        }

        for r in missing {
            var ok = false
            for attempt in 1...3 {
                ok = await importOne(remote: r, store: store)
                if ok { break }
                if attempt < 3 { try? await Task.sleep(nanoseconds: 700_000_000) }
            }
        }
        await MainActor.run { store.reload() }
    }

    private func makeMeta(_ r: RemoteFileLite, localName: String) -> PatchMeta {
        PatchMeta(uid: r.uid, localName: localName, remoteName: r.filename,
                  gameType: r.gameType, folder: r.folder, tag: r.tag,
                  displayName: r.displayName, note: r.note)
    }

    private func importOne(remote: RemoteFileLite, store: PatchProjectStore) async -> Bool {
        guard let url = URL(string: remote.url) else { return false }
        let before = await MainActor.run { Set(store.items.map { $0.packageURL.lastPathComponent }) }
        await MainActor.run { store.importPackage(from: .remote(url)) }

        for i in 0..<30 {
            try? await Task.sleep(nanoseconds: 300_000_000)
            if i % 2 == 0 { await MainActor.run { store.reload() } }

            let after = await MainActor.run { Set(store.items.map { $0.packageURL.lastPathComponent }) }
            let newFiles = after.subtracting(before)
            guard !newFiles.isEmpty else { continue }

            var chosen = newFiles.first(where: { $0 == remote.filename })
            if chosen == nil { chosen = newFiles.first(where: { $0.hasSuffix(remote.filename) || remote.filename.hasSuffix($0) }) }
            if chosen == nil && newFiles.count == 1 { chosen = newFiles.first }
            guard let local = chosen else { continue }

            lock.lock()
            PatchMetaStore.set(makeMeta(remote, localName: local), localName: local)
            lock.unlock()
            await MainActor.run { store.reload() }
            return true
        }
        return false
    }

    private func fetchRemotes() async -> [RemoteFileLite]? {
        let ts = Int(Date().timeIntervalSince1970)
        guard let url = URL(string: "https://solitudepremium.click/ipa/ipa/list.php?t=\(ts)") else { return nil }
        do {
            var req = URLRequest(url: url)
            req.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
            req.timeoutInterval = 10
            req.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
            let (data, _) = try await URLSession.shared.data(for: req)
            return try JSONDecoder().decode([RemoteFileLite].self, from: data)
        } catch { return nil }
    }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - DETAIL VIEW
// ═══════════════════════════════════════════════════════════════
struct PatchGameDetailView: View {
    let game: GameSelection
    @ObservedObject var store: PatchProjectStore
    @Binding var actionAlert: PatchStoreAlert?
    let language: AppLanguage

    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var activationInfo: ActivationInfo?
    @State private var selectedFolder: String? = nil
    @State private var workingFileID: String? = nil
    @State private var renameItem: PatchLibraryItem?
    @State private var renameText: String = ""
    @State private var tagPickerItem: PatchLibraryItem?
    @State private var noteItem: PatchLibraryItem?
    @State private var noteText: String = ""
    @State private var refreshTick: Int = 0
    @State private var didInitialSync = false

    var body: some View {
        NavigationStack {
            ZStack {
                NeonBackgroundView()
                VStack(spacing: 0) { topBar; folderBar; listContent }
            }
            .navigationBarHidden(true)
            .onAppear { store.reload(); syncFolders() }
            .task {
                if !didInitialSync {
                    didInitialSync = true
                    await SyncEngine.shared.run(store: store)
                    await MainActor.run { store.reload(); refreshTick &+= 1; syncFolders() }
                }
            }
            .onChange(of: scenePhase) { p in
                if p == .active {
                    Task {
                        await SyncEngine.shared.run(store: store)
                        await MainActor.run { store.reload(); refreshTick &+= 1; syncFolders() }
                    }
                }
            }
            .alert(item: $actionAlert) { a in
                Alert(title: Text(a.titleKey), message: Text(a.message(language: language)), dismissButton: .default(Text("OK")))
            }
            .alert("Đổi tên", isPresented: renameBinding) {
                TextField("Tên mới", text: $renameText)
                Button("Huỷ", role: .cancel) { renameItem = nil }
                Button("Lưu") { commitRename() }
            }
            .alert("Ghi chú", isPresented: noteBinding) {
                TextField("Ghi chú", text: $noteText)
                Button("Huỷ", role: .cancel) { noteItem = nil }
                Button("Lưu") { commitNote() }
            }
            .confirmationDialog("Chọn tag", isPresented: tagBinding, titleVisibility: .visible) {
                Button("VIP 👑") { commitTag("VIP") }
                Button("FREE 🛡") { commitTag("FREE") }
                Button("Huỷ", role: .cancel) { tagPickerItem = nil }
            }
            .fullScreenCover(item: $activationInfo) { i in
                ActivationNoteSheet(info: i) { activationInfo = nil }
            }
        }
    }

    private var topBar: some View {
        HStack(spacing: 14) {
            Button { SoundFX.tap(); dismiss() } label: {
                ZStack {
                    Circle().fill(Color.white.opacity(0.08)).frame(width: 40, height: 40)
                        .overlay(Circle().strokeBorder(.white.opacity(0.4), lineWidth: 1.2))
                    Image(systemName: "arrow.left").font(.system(size: 15, weight: .heavy))
                        .foregroundStyle(.white)
                }
            }.buttonStyle(.plain)
            Text(game.title).font(.system(size: 15, weight: .heavy)).foregroundStyle(.white)
            Spacer()
        }.padding(.horizontal, 18).padding(.top, 14).padding(.bottom, 12)
    }

    @ViewBuilder
    private var folderBar: some View {
        if folders.count > 1 {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(folders, id: \.self) { f in
                        FolderPill(title: f,
                            count: gameItems.filter { folderName(for: $0) == f }.count,
                            isActive: selectedFolder == f) {
                            SoundFX.tap()
                            withAnimation { selectedFolder = f }
                        }
                    }
                }.padding(.horizontal, 18)
            }.padding(.bottom, 14)
        }
    }

    private func syncFolders() {
        let c = folders
        if c.isEmpty { selectedFolder = nil; return }
        if let s = selectedFolder, c.contains(s) { return }
        selectedFolder = c.first
    }

    private var gameItems: [PatchLibraryItem] {
        _ = refreshTick
        return store.items.filter { GameTypeHelper.prefixOf($0) == game.prefix }
    }

    private var folders: [String] {
        var u: [String] = []
        for item in gameItems {
            let f = folderName(for: item)
            if !f.isEmpty && !u.contains(f) { u.append(f) }
        }
        return u.sorted()
    }

    private var displayedItems: [PatchLibraryItem] {
        if folders.count <= 1 { return gameItems }
        guard let s = selectedFolder else { return [] }
        return gameItems.filter { folderName(for: $0) == s }
    }

    private var renameBinding: Binding<Bool> { Binding(get: { renameItem != nil }, set: { if !$0 { renameItem = nil } }) }
    private var tagBinding: Binding<Bool> { Binding(get: { tagPickerItem != nil }, set: { if !$0 { tagPickerItem = nil } }) }
    private var noteBinding: Binding<Bool> { Binding(get: { noteItem != nil }, set: { if !$0 { noteItem = nil } }) }

    private var listContent: some View {
        ScrollView(showsIndicators: false) {
            if displayedItems.isEmpty {
                EmptyStateView(message: folders.isEmpty
                    ? "Chưa có folder nào.\nVuốt xuống để làm mới dữ liệu..."
                    : "Folder này chưa có patch nào.")
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(displayedItems) { item in patchRow(item: item) }
                }.padding(.horizontal, 16).padding(.top, 4).padding(.bottom, 40)
            }
        }.refreshable {
            await SyncEngine.shared.run(store: store)
            store.reload()
            refreshTick &+= 1
        }
    }

    private func patchRow(item: PatchLibraryItem) -> some View {
        let r = DevicePatchService.latestReceipt(projectID: item.id)
        let applied = (r != nil)
        let n = displayName(for: item)
        return PatchCard(
            isApplied: applied,
            isWorking: workingFileID == item.id.uuidString,
            displayName: n,
            tag: currentTag(for: item),
            note: currentNote(for: item),
            onToggle: { nv in
                if nv { SoundFX.tingTing() } else { SoundFX.tap() }
                togglePatch(item: item, activate: nv)
            },
            onTapTag: { SoundFX.tap(); tagPickerItem = item },
            onRename: { SoundFX.tap(); renameItem = item; renameText = n },
            onEditNote: { SoundFX.tap(); noteItem = item; noteText = currentNote(for: item) }
        )
    }

    private func localKey(for i: PatchLibraryItem) -> String { i.packageURL.lastPathComponent }
    private func meta(for i: PatchLibraryItem) -> PatchMeta? { PatchMetaStore.get(localName: localKey(for: i)) }
    
    private func displayName(for i: PatchLibraryItem) -> String {
        if let m = meta(for: i), !m.displayName.isEmpty { return m.displayName }
        if let n = i.project?.name, !n.isEmpty { return n }
        var b = i.packageURL.deletingPathExtension().lastPathComponent
        b = b.replacingOccurrences(of: "_VIP", with: "").replacingOccurrences(of: "_FREE", with: "")
        return b
    }
    
    private func currentTag(for i: PatchLibraryItem) -> String {
        if let m = meta(for: i), !m.tag.isEmpty { return m.tag }
        return i.packageURL.deletingPathExtension().lastPathComponent.hasSuffix("_VIP") ? "VIP" : "FREE"
    }
    
    private func currentNote(for i: PatchLibraryItem) -> String { meta(for: i)?.note ?? "" }
    
    private func folderName(for i: PatchLibraryItem) -> String {
        if let m = meta(for: i), !m.folder.isEmpty { return m.folder }
        return "CHƯA PHÂN LOẠI"
    }

    private func commitRename() {
        guard let i = renameItem else { return }
        let t = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { renameItem = nil; return }
        let ln = localKey(for: i)
        guard var m = PatchMetaStore.get(localName: ln) else { renameItem = nil; return }
        m.displayName = t; m.nameOverride = true
        PatchMetaStore.set(m, localName: ln)
        store.reload(); renameItem = nil
    }
    
    private func commitTag(_ tag: String) {
        guard let i = tagPickerItem else { return }
        let ln = localKey(for: i)
        guard var m = PatchMetaStore.get(localName: ln) else { tagPickerItem = nil; return }
        m.tag = tag; m.tagOverride = true
        PatchMetaStore.set(m, localName: ln)
        store.reload(); tagPickerItem = nil
    }
    
    private func commitNote() {
        guard let i = noteItem else { return }
        let t = noteText.trimmingCharacters(in: .whitespacesAndNewlines)
        let ln = localKey(for: i)
        guard var m = PatchMetaStore.get(localName: ln) else { noteItem = nil; return }
        m.note = t; m.noteOverride = true
        PatchMetaStore.set(m, localName: ln)
        store.reload(); noteItem = nil
    }

    private func togglePatch(item: PatchLibraryItem, activate: Bool) {
        workingFileID = item.id.uuidString
        let nameSnap = displayName(for: item)
        let tagSnap = currentTag(for: item)
        let noteSnap = currentNote(for: item)
        let targetFolder = folderName(for: item)
        let gp = game.prefix

        let conflictIDs: [UUID] = activate ? store.items.compactMap { o in
            guard o.id != item.id else { return nil }
            guard GameTypeHelper.prefixOf(o) == gp else { return nil }
            guard folderName(for: o) == targetFolder else { return nil }
            guard DevicePatchService.latestReceipt(projectID: o.id) != nil else { return nil }
            return o.id
        } : []

        Task.detached(priority: .userInitiated) {
            for cid in conflictIDs {
                if let r = DevicePatchService.latestReceipt(projectID: cid) {
                    try? DevicePatchService.restore(receipt: r)
                }
            }
            if !activate {
                do {
                    if let r = DevicePatchService.latestReceipt(projectID: item.id) {
                        try DevicePatchService.restore(receipt: r)
                    }
                    await MainActor.run { store.reload(); workingFileID = nil }
                } catch {
                    await MainActor.run {
                        workingFileID = nil; SoundFX.error()
                        activationInfo = ActivationInfo(patchName: nameSnap, tag: tagSnap, note: noteSnap, success: false, errorMessage: "Không thể tắt: \(error.localizedDescription)")
                    }
                }
                return
            }

            // Bật Shield UI Lock
            await MainActor.run { MaxShield.shared.activate(duration: 12.0) }

            do {
                guard let p = item.project else {
                    await MainActor.run { MaxShield.shared.deactivate(); workingFileID = nil }
                    return
                }
                _ = try DevicePatchService.apply(project: p)
                try? await Task.sleep(nanoseconds: 2_500_000_000) // Sleep tạo cảm giác xử lý

                await MainActor.run {
                    MaxShield.shared.deactivate()
                    store.reload()
                    workingFileID = nil
                    SoundFX.success()
                    activationInfo = ActivationInfo(patchName: nameSnap, tag: tagSnap, note: noteSnap, success: true, errorMessage: nil)
                }
            } catch {
                await MainActor.run {
                    MaxShield.shared.deactivate()
                    store.reload(); workingFileID = nil; SoundFX.error()
                    activationInfo = ActivationInfo(patchName: nameSnap, tag: tagSnap, note: noteSnap, success: false, errorMessage: error.localizedDescription)
                }
            }
        }
    }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - UNLOCK VIEW & EXTENSIONS
// ═══════════════════════════════════════════════════════════════
struct PatchUnlockView: View {
    @Environment(\.appLanguage) private var language
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: PatchProjectStore
    let request: PatchPasswordRequest
    @State private var password = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField(language.text("patch.password"), text: $password)
                        .textContentType(.password)
                        .submitLabel(.done)
                        .onSubmit(unlock)
                        .onChange(of: password) { _ in store.clearUnlockError() }
                    if let k = store.unlockErrorKey {
                        Text(errorText(k)).font(.footnote).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(language.text("patch.unlock"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(language.text("common.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(language.text("patch.unlock"), action: unlock)
                        .disabled(password.isEmpty || store.isBusy)
                }
            }
        }
    }
    private func errorText(_ k: String) -> String {
        if let a = store.unlockErrorArgument { return language.text(k, a) }
        return language.text(k)
    }
    private func unlock() {
        guard !password.isEmpty else { return }
        store.unlock(password: password)
    }
}

private struct PatchStorePresentationModifier: ViewModifier {
    @ObservedObject var store: PatchProjectStore
    func body(content: Content) -> some View {
        content.sheet(item: $store.passwordRequest, onDismiss: store.cancelUnlock) { r in
            PatchUnlockView(store: store, request: r)
        }
    }
}

extension View {
    func patchStorePresentation(_ store: PatchProjectStore) -> some View {
        modifier(PatchStorePresentationModifier(store: store))
    }
}
