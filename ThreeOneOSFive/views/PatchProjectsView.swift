import SwiftUI
import UIKit
import UniformTypeIdentifiers
import AudioToolbox

// ═══════════════════════════════════════════════════════════════
// MARK: - SOUND
// ═══════════════════════════════════════════════════════════════
enum SoundFX {
    static func tap()     { AudioServicesPlaySystemSound(1104) }
    static func menu()    { AudioServicesPlaySystemSound(1105) }
    static func error()   { AudioServicesPlaySystemSound(1053) }
    static func success() { AudioServicesPlaySystemSound(1057) }
    static func tingTing() {
        AudioServicesPlaySystemSound(1057)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
            AudioServicesPlaySystemSound(1057)
        }
    }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - SWEEP DISMISS (chặn popup "Xong" mạnh hơn)
// ═══════════════════════════════════════════════════════════════
enum InstallerAlertSweep {
    private static var sweepTask: Task<Void, Never>?
    private static var observer: NSObjectProtocol?
    private static var windowObserver: NSObjectProtocol?

    static func start(duration: TimeInterval = 30.0) {
        stop()

        sweepTask = Task { @MainActor in
            let deadline = Date().addingTimeInterval(duration)
            while !Task.isCancelled && Date() < deadline {
                sweepOnce()
                try? await Task.sleep(nanoseconds: 80_000_000)
            }
        }

        observer = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                sweepOnce()
                try? await Task.sleep(nanoseconds: 100_000_000)
                sweepOnce()
                try? await Task.sleep(nanoseconds: 200_000_000)
                sweepOnce()
            }
        }

        windowObserver = NotificationCenter.default.addObserver(
            forName: UIWindow.didBecomeVisibleNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 50_000_000)
                sweepOnce()
            }
        }
    }

    static func stop() {
        sweepTask?.cancel()
        sweepTask = nil
        if let o = observer { NotificationCenter.default.removeObserver(o); observer = nil }
        if let o = windowObserver { NotificationCenter.default.removeObserver(o); windowObserver = nil }
    }

    @MainActor
    private static func sweepOnce() {
        for scene in UIApplication.shared.connectedScenes {
            guard let ws = scene as? UIWindowScene else { continue }
            for window in ws.windows {
                if let root = window.rootViewController {
                    sweepVC(root)
                }
            }
        }
    }

    @MainActor
    private static func sweepVC(_ vc: UIViewController) {
        if let alert = vc as? UIAlertController, shouldDismiss(alert) {
            alert.dismiss(animated: false)
        }
        if let p = vc.presentedViewController { sweepVC(p) }
        for c in vc.children { sweepVC(c) }
    }

    private static func shouldDismiss(_ alert: UIAlertController) -> Bool {
        let rawTitle = (alert.title ?? "").trimmingCharacters(in: .whitespaces)
        let rawMsg   = (alert.message ?? "").trimmingCharacters(in: .whitespaces)
        let t = rawTitle.lowercased()
        let m = rawMsg.lowercased()

        let exactTitles: Set<String> = ["xong", "done", "hoàn tất", "thành công", "đã xong"]
        if exactTitles.contains(t) { return true }

        let msgKeys: [String] = [
            "đã cài đặt gói", "cài đặt gói thành công", "mở gói trong mục",
            "đã cài đặt", "cấu hình đã được cài đặt", "đã được cài đặt",
            "quản lý cấu hình", "profile installed", "profile has been installed",
            "installed successfully", "the profile has been installed"
        ]
        for k in msgKeys where m.contains(k) { return true }
        for k in msgKeys where t.contains(k) { return true }

        // ✅ FIX: title là String? → compactMap
        let titles = alert.actions.compactMap { $0.title?.lowercased() }
        let isSystemPattern = alert.actions.count == 1 &&
            (titles.contains("xong") || titles.contains("done") ||
             titles.contains("ok") || titles.contains("đóng"))
        if isSystemPattern && (t == "xong" || t == "done" ||
                               t.contains("thành công") || t.contains("cài đặt")) {
            return true
        }

        if alert.actions.count == 1,
           let first = alert.actions.first,
           let firstTitle = first.title?.lowercased(),
           ["xong", "done"].contains(firstTitle),
           alert.preferredStyle == .alert, !m.isEmpty {
            return true
        }
        return false
    }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - OPTIMIZED URL SESSION (tăng tốc tải file)
// ═══════════════════════════════════════════════════════════════
enum NetSession {
    /// Session tối ưu cho tải file: nhiều connection, pipelining, keep-alive
    static let shared: URLSession = {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 20
        cfg.timeoutIntervalForResource = 300
        cfg.httpMaximumConnectionsPerHost = 8
        cfg.requestCachePolicy = .reloadIgnoringLocalCacheData
        cfg.urlCache = nil
        cfg.waitsForConnectivity = true
        cfg.httpShouldUsePipelining = true
        cfg.httpAdditionalHeaders = [
            "Accept-Encoding": "gzip, deflate, br",
            "Connection": "keep-alive"
        ]
        return URLSession(configuration: cfg)
    }()

    /// Session riêng cho API JSON (nhẹ, cache ngắn)
    static let api: URLSession = {
        let cfg = URLSessionConfiguration.ephemeral
        cfg.timeoutIntervalForRequest = 15
        cfg.timeoutIntervalForResource = 30
        cfg.httpMaximumConnectionsPerHost = 4
        cfg.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        cfg.urlCache = nil
        return URLSession(configuration: cfg)
    }()
}

// ═══════════════════════════════════════════════════════════════
// MARK: - THEME
// ═══════════════════════════════════════════════════════════════
enum Theme {
    static let surface = Color(red: 0.043, green: 0.043, blue: 0.043)
    static let surfaceHi = Color(red: 0.078, green: 0.078, blue: 0.078)
    static let gold = Color(red: 0.850, green: 0.700, blue: 0.400)
    static let danger = Color(red: 1.0, green: 0.32, blue: 0.32)
}

// ═══════════════════════════════════════════════════════════════
// MARK: - BACKGROUND (static, nhẹ)
// ═══════════════════════════════════════════════════════════════
struct NeonBackgroundView: View {
    var body: some View {
        ZStack {
            Color.black
            RadialGradient(
                colors: [Color.white.opacity(0.10), .clear],
                center: .topLeading, startRadius: 0, endRadius: 550
            )
            RadialGradient(
                colors: [Color.white.opacity(0.06), .clear],
                center: .bottomTrailing, startRadius: 0, endRadius: 550
            )
        }
        .ignoresSafeArea()
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
        self.uid = uid
        self.localName = localName
        self.remoteName = remoteName
        self.gameType = gameType
        self.folder = folder
        self.tag = tag
        self.displayName = displayName
        self.note = note
        self.tagOverride = tagOverride
        self.nameOverride = nameOverride
        self.noteOverride = noteOverride
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        uid          = (try? c.decode(String.self, forKey: .uid)) ?? ""
        localName    = (try? c.decode(String.self, forKey: .localName)) ?? ""
        remoteName   = (try? c.decode(String.self, forKey: .remoteName)) ?? ""
        gameType     = (try? c.decode(String.self, forKey: .gameType)) ?? ""
        folder       = (try? c.decode(String.self, forKey: .folder)) ?? ""
        tag          = (try? c.decode(String.self, forKey: .tag)) ?? "FREE"
        displayName  = (try? c.decode(String.self, forKey: .displayName)) ?? ""
        note         = (try? c.decode(String.self, forKey: .note)) ?? ""
        tagOverride  = (try? c.decode(Bool.self, forKey: .tagOverride)) ?? false
        nameOverride = (try? c.decode(Bool.self, forKey: .nameOverride)) ?? false
        noteOverride = (try? c.decode(Bool.self, forKey: .noteOverride)) ?? false
    }
}

struct RemoteFileLite {
    let uid: String
    let filename: String
    let gameType: String
    let folder: String
    let tag: String
    let displayName: String
    let note: String
    let url: String

    init(filename: String, gameType: String, folder: String,
         tag: String, displayName: String, note: String, url: String) {
        self.filename = filename
        self.gameType = gameType
        self.folder = folder
        self.tag = tag
        self.displayName = displayName
        self.note = note
        self.url = url
        let key = "\(gameType)/\(folder)/\(filename)"
        var h: UInt64 = 1469598103934665603
        for b in key.utf8 { h = (h ^ UInt64(b)) &* 1099511628211 }
        self.uid = String(h, radix: 16)
    }
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
// MARK: - META STORE (in-memory cache để tăng tốc)
// ═══════════════════════════════════════════════════════════════
enum PatchMetaStore {
    private static let key = "patch_meta_v34"
    private static var cache: [String: PatchMeta]? = nil
    private static let lock = NSLock()

    static func all() -> [String: PatchMeta] {
        lock.lock(); defer { lock.unlock() }
        if let c = cache { return c }
        guard let d = UserDefaults.standard.data(forKey: key),
              let x = try? JSONDecoder().decode([String: PatchMeta].self, from: d)
        else { cache = [:]; return [:] }
        cache = x
        return x
    }
    static func save(_ d: [String: PatchMeta]) {
        lock.lock(); defer { lock.unlock() }
        cache = d
        if let x = try? JSONEncoder().encode(d) {
            UserDefaults.standard.set(x, forKey: key)
        }
    }
    static func set(_ m: PatchMeta, localName: String) {
        var d = all(); d[localName] = m; save(d)
    }
    static func get(localName: String) -> PatchMeta? { all()[localName] }
    static func hasUID(_ uid: String) -> Bool {
        for m in all().values where m.uid == uid { return true }
        return false
    }
    static func invalidate() {
        lock.lock(); cache = nil; lock.unlock()
    }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - GAME TYPE HELPER
// ═══════════════════════════════════════════════════════════════
enum GameTypeHelper {
    static let allPrefixes = ["ffmax", "ffnormal", "silent_ffmax", "silent_ffnormal"]

    static func prefixOf(_ item: PatchLibraryItem) -> String {
        let name = item.packageURL.lastPathComponent
        if let m = PatchMetaStore.get(localName: name), !m.gameType.isEmpty {
            return m.gameType
        }
        let sorted = allPrefixes.sorted { $0.count > $1.count }
        for p in sorted where name.hasPrefix("\(p)_") { return p }
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

    static func stripPrefix(_ name: String) -> String {
        let sorted = allPrefixes.sorted { $0.count > $1.count }
        for p in sorted where name.hasPrefix("\(p)_") {
            return String(name.dropFirst(p.count + 1))
        }
        return name
    }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - COMPONENTS
// ═══════════════════════════════════════════════════════════════
private struct NeonCard<Content: View>: View {
    @ViewBuilder let content: Content
    var body: some View {
        content
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.surface))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(LinearGradient(
                    colors: [.white, .white.opacity(0.4), .white],
                    startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 1.4))
            .shadow(color: .white.opacity(0.10), radius: 12)
    }
}

private struct GameLogoView: View {
    let imageURL: String
    var body: some View {
        AsyncImage(url: URL(string: imageURL)) { p in
            switch p {
            case .empty:
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.surfaceHi)
                    ProgressView().tint(.white)
                }
            case .success(let img):
                img.resizable().scaledToFill().clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            case .failure:
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.surfaceHi)
                    Image(systemName: "flame.fill").font(.system(size: 22, weight: .bold)).foregroundStyle(.white)
                }
            @unknown default: EmptyView()
            }
        }
        .frame(width: 58, height: 58)
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(.white, lineWidth: 1.5))
    }
}

enum AvatarShape { case circle, roundedSquare }

private struct ServerAvatarView: View {
    let size: CGFloat
    var shape: AvatarShape = .circle
    var corner: CGFloat = 14

    var body: some View {
        AsyncImage(url: URL(string: "https://solitudepremium.click/ipa/ipa/liii.jpg")) { p in
            switch p {
            case .empty:
                ZStack { shapeFill; ProgressView().tint(.white).scaleEffect(0.8) }
            case .success(let img): img.resizable().scaledToFill()
            case .failure:
                ZStack {
                    shapeFill
                    Image(systemName: "person.fill")
                        .font(.system(size: size*0.42, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                }
            @unknown default: EmptyView()
            }
        }
        .frame(width: size, height: size)
        .clipShape(clipShape)
        .overlay(clipShape.strokeBorder(.white, lineWidth: 1.5))
    }

    private var clipShape: AnyShape {
        switch shape {
        case .circle: return AnyShape(Circle())
        case .roundedSquare: return AnyShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
        }
    }
    @ViewBuilder private var shapeFill: some View {
        switch shape {
        case .circle: Circle().fill(Theme.surfaceHi)
        case .roundedSquare: RoundedRectangle(cornerRadius: corner, style: .continuous).fill(Theme.surfaceHi)
        }
    }
}

private extension Shape {
    func strokeBorder(_ c: Color, lineWidth: CGFloat) -> some View { self.stroke(c, lineWidth: lineWidth) }
}

// ✅ FIX Sendable warning Swift 6
private struct AnyShape: Shape, @unchecked Sendable {
    private let make: @Sendable (CGRect) -> Path
    init<S: Shape>(_ s: S) {
        let shape = s
        self.make = { rect in shape.path(in: rect) }
    }
    func path(in rect: CGRect) -> Path { make(rect) }
}

private struct AvatarView: View {
    var body: some View {
        ZStack {
            Circle().strokeBorder(Color.white.opacity(0.3),
                style: StrokeStyle(lineWidth: 1, dash: [2, 5])).frame(width: 108, height: 108)
            Circle().strokeBorder(.white, lineWidth: 2).frame(width: 92, height: 92)
            ServerAvatarView(size: 78, shape: .circle)
        }.frame(width: 118, height: 118)
    }
}

private struct ChevronCircle: View {
    var body: some View {
        ZStack {
            Circle().fill(.white).frame(width: 36, height: 36)
            Image(systemName: "arrow.up.right").font(.system(size: 13, weight: .heavy)).foregroundStyle(.black)
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
        .background(Capsule().fill(isVIP ? Theme.gold.opacity(0.16) : Color.white.opacity(0.06)))
        .overlay(Capsule().strokeBorder(isVIP ? Theme.gold : Color.white.opacity(0.7), lineWidth: 1.2))
    }
}

private struct PatchIconView: View {
    let tag: String
    let isApplied: Bool
    private var isVIP: Bool { tag == "VIP" }
    var body: some View {
        ZStack {
            if isApplied {
                ServerAvatarView(size: 52, shape: .circle)
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(isVIP ? Theme.gold.opacity(0.14) : Color.white.opacity(0.06))
                        .frame(width: 52, height: 52)
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(isVIP ? Theme.gold : Color.white.opacity(0.5), lineWidth: 1.5)
                        .frame(width: 52, height: 52)
                    Image(systemName: isVIP ? "crown.fill" : "shield.lefthalf.filled")
                        .font(.system(size: 21, weight: .bold))
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
                    .frame(width: 52, height: 30)
                    .overlay(Capsule().strokeBorder(isOn ? .white : Color.white.opacity(0.45), lineWidth: 1.4))
                HStack {
                    if isOn { Spacer(); Circle().fill(.black).frame(width: 22, height: 22).padding(.trailing, 3) }
                    else { Circle().fill(.white).frame(width: 22, height: 22).padding(.leading, 3); Spacer() }
                }.frame(width: 52, height: 30)
            }
            .animation(.spring(response: 0.26, dampingFraction: 0.72), value: isOn)
            .opacity(disabled ? 0.5 : 1.0)
        }
        .buttonStyle(.plain).disabled(disabled)
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
                Circle().fill(isActive ? Color.black : Color.white.opacity(0.55)).frame(width: 6, height: 6)
                Text(title).font(.system(size: 12, weight: .heavy)).tracking(1.0)
                    .foregroundStyle(isActive ? .black : .white)
                Text("\(count)").font(.system(size: 10, weight: .heavy))
                    .foregroundStyle(isActive ? .black.opacity(0.55) : .white.opacity(0.4))
                    .padding(.leading, 2)
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(Capsule().fill(isActive ? Color.white : Color.white.opacity(0.04)))
            .overlay(Capsule().strokeBorder(isActive ? Color.white : Color.white.opacity(0.28), lineWidth: 1.2))
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
                            .foregroundStyle(.white.opacity(0.62)).lineLimit(2).multilineTextAlignment(.leading)
                    }
                }
            }
            Spacer(minLength: 4)
            if isWorking {
                ProgressView().tint(.white).scaleEffect(0.8).frame(width: 52, height: 30)
            } else {
                CustomToggle(isOn: isApplied, disabled: false) { onToggle($0) }
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(LinearGradient(
                colors: isApplied ? [Color.white.opacity(0.09), Color.white.opacity(0.03)]
                                  : [Color.white.opacity(0.03), Color.white.opacity(0.012)],
                startPoint: .topLeading, endPoint: .bottomTrailing)))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .strokeBorder(isApplied ? Color.white : Color.white.opacity(0.28),
                          lineWidth: isApplied ? 1.6 : 1.1))
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
        VStack(spacing: 14) {
            ZStack {
                Circle().strokeBorder(.white.opacity(0.25),
                    style: StrokeStyle(lineWidth: 1.4, dash: [3, 5])).frame(width: 74, height: 74)
                Image(systemName: "tray").font(.system(size: 26, weight: .light))
                    .foregroundStyle(.white.opacity(0.5))
            }
            Text(message).font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.55)).multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }.padding(.top, 60).frame(maxWidth: .infinity)
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
            Color.black.ignoresSafeArea()
            VStack(spacing: 24) {
                Spacer(minLength: 30)
                VStack(spacing: 12) {
                    ServerAvatarView(size: 92, shape: .roundedSquare, corner: 20)
                    Text("MENU SILENT").font(.system(size: 20, weight: .heavy)).tracking(3)
                        .foregroundStyle(.white)
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
                            .strokeBorder(.white.opacity(0.4), lineWidth: 1.3))
                        .padding(.horizontal, 40)
                }.buttonStyle(.plain).padding(.bottom, 40)
            }
        }
    }

    private func optionCard(_ t: String, _ s: String, _ p: String) -> some View {
        Button { SoundFX.menu(); onSelect(p) } label: {
            NeonCard {
                HStack(spacing: 16) {
                    ServerAvatarView(size: 62, shape: .roundedSquare, corner: 14)
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
    private var hasNote: Bool {
        !info.note.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 22) {
                    Spacer(minLength: 50)

                    if isError {
                        ZStack {
                            Circle().fill(accent).frame(width: 88, height: 88)
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 36, weight: .heavy)).foregroundStyle(.white)
                        }
                    } else {
                        ServerAvatarView(size: 96, shape: .circle)
                            .shadow(color: .white.opacity(0.5), radius: 20)
                    }

                    if isError {
                        VStack(spacing: 10) {
                            Text("HEADLOCK ZENIS")
                                .font(.system(size: 11, weight: .heavy)).tracking(4.5)
                                .foregroundStyle(.white.opacity(0.55))
                            Text("KHÔNG KÍCH HOẠT ĐƯỢC")
                                .font(.system(size: 20, weight: .heavy)).tracking(2)
                                .foregroundStyle(accent).multilineTextAlignment(.center)
                                .padding(.horizontal, 20)
                            Text(info.patchName)
                                .font(.system(size: 15, weight: .heavy))
                                .foregroundStyle(.white).multilineTextAlignment(.center)
                                .padding(.horizontal, 28)
                            if !info.tag.isEmpty { TagPill(tag: info.tag) }
                        }
                    } else {
                        VStack(spacing: 12) {
                            Text("HEADLOCK ZENIS")
                                .font(.system(size: 13, weight: .heavy)).tracking(4.5)
                                .foregroundStyle(.white.opacity(0.85))

                            Text("ĐÃ CẬP NHẬT THÀNH CÔNG")
                                .font(.system(size: 15, weight: .heavy)).tracking(2)
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)

                            Text("BẠN CÓ THỂ SỬ DỤNG")
                                .font(.system(size: 13, weight: .heavy)).tracking(2.5)
                                .foregroundStyle(.white.opacity(0.7))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)

                            Text(info.patchName)
                                .font(.system(size: 18, weight: .heavy))
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 28)
                                .padding(.top, 4)

                            if !info.tag.isEmpty { TagPill(tag: info.tag) }
                        }
                    }

                    if isError, let e = info.errorMessage, !e.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("LÝ DO")
                                .font(.system(size: 10, weight: .heavy)).tracking(2.2)
                                .foregroundStyle(accent)
                            Text(e).font(.system(size: 12.5, weight: .medium))
                                .foregroundStyle(.white.opacity(0.9))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(accent.opacity(0.08)))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(accent.opacity(0.5), lineWidth: 1.3))
                        .padding(.horizontal, 24)
                    }

                    if hasNote {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack(spacing: 8) {
                                Image(systemName: "note.text")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(.white)
                                Text("GHI CHÚ")
                                    .font(.system(size: 10, weight: .heavy)).tracking(2.2)
                                    .foregroundStyle(.white)
                                Spacer()
                            }
                            Text(info.note).font(.system(size: 13.5, weight: .medium))
                                .foregroundStyle(.white.opacity(0.95))
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(14)
                                .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color.white.opacity(0.05)))
                                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(.white.opacity(0.25),
                                        style: StrokeStyle(lineWidth: 1, dash: [4, 4])))

                            Button {
                                SoundFX.tap()
                                UIPasteboard.general.string = info.note
                                withAnimation { copied = true }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                                    withAnimation { copied = false }
                                }
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
                                    .strokeBorder(.white, lineWidth: 1.4))
                            }.buttonStyle(.plain)
                        }
                        .padding(18)
                        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.surface))
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(.white.opacity(0.8), lineWidth: 1.3))
                        .padding(.horizontal, 22)
                    }

                    Button { SoundFX.tap(); onDismiss() } label: {
                        Text("ĐÃ HIỂU")
                            .font(.system(size: 14, weight: .heavy)).tracking(3)
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

    init(onOpenSettings: @escaping () -> Void = {},
         onOpenLogs: @escaping () -> Void = {}) {
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
            .task {
                await syncNow()
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 12_000_000_000)
                    if Task.isCancelled { break }
                    await syncNow()
                }
            }
            .onChange(of: scenePhase) { p in
                if p == .active { store.reload(); triggerSync() }
            }
            .sheet(item: $selectedGame) { g in
                PatchGameDetailView(game: g, store: store,
                                    actionAlert: $actionAlert, language: language)
            }
            .sheet(isPresented: $showSilentSubmenu) {
                SilentSubMenuSheet(
                    onSelect: { prefix in
                        showSilentSubmenu = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                            selectedGame = GameSelection(
                                title: prefix == "silent_ffmax"
                                    ? "Menu Silent · FF Max"
                                    : "Menu Silent · FF Thường",
                                prefix: prefix)
                        }
                    },
                    onCancel: { showSilentSubmenu = false })
            }
            .alert(item: $actionAlert) { a in
                Alert(title: Text(a.titleKey),
                      message: Text(a.message(language: language)),
                      dismissButton: .default(Text("OK")))
            }
        }
    }

    private var header: some View {
        VStack(spacing: 0) {
            HStack { Spacer(); syncPill }
                .padding(.horizontal, 20).padding(.top, 10).padding(.bottom, 4)
            AvatarView().padding(.top, 2)
            Text("ZENITH SOLITUDE")
                .font(.system(size: 21, weight: .black, design: .serif))
                .tracking(3.5).foregroundStyle(.white).padding(.top, 12)
            HStack(spacing: 10) {
                Rectangle().fill(.white.opacity(0.35)).frame(width: 26, height: 1)
                Text("HEADLOCK ZENIS").font(.system(size: 9.5, weight: .heavy)).tracking(4.2)
                    .foregroundStyle(.white.opacity(0.55))
                Rectangle().fill(.white.opacity(0.35)).frame(width: 26, height: 1)
            }.padding(.top, 8).padding(.bottom, 22)
        }
    }

    private var syncPill: some View {
        HStack(spacing: 7) {
            ZStack {
                Circle().fill((isSyncing ? Color.yellow : Color.green).opacity(0.18)).frame(width: 14, height: 14)
                Circle().fill(isSyncing ? Color.yellow : Color.green).frame(width: 7, height: 7)
            }
            Text(isSyncing ? "ĐANG CẬP NHẬT" : "ĐÃ KẾT NỐI").font(.system(size: 9, weight: .heavy))
                .tracking(1.6).foregroundStyle(.white.opacity(0.75))
        }
        .padding(.horizontal, 12).padding(.vertical, 7)
        .background(Capsule().fill(Color.white.opacity(0.05)))
        .overlay(Capsule().strokeBorder(.white.opacity(0.28), lineWidth: 1))
    }

    private var content: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {
                gameCard("Free Fire Max", "HEADLOCK ZENIS", "ffmax",
                         "https://solitudepremium.click/ipa/ipa/free.jpg")
                gameCard("Free Fire Thường", "HEADLOCK ZENIS", "ffnormal",
                         "https://solitudepremium.click/ipa/ipa/free.jpg")
                silentCard()
                HStack(spacing: 8) {
                    Rectangle().fill(.white.opacity(0.2)).frame(height: 1)
                    Text("BY ZENITH SOLITUDE").font(.system(size: 9, weight: .heavy)).tracking(3)
                        .foregroundStyle(.white.opacity(0.5)).fixedSize()
                    Rectangle().fill(.white.opacity(0.2)).frame(height: 1)
                }.padding(.horizontal, 40).padding(.top, 22)
            }.padding(.horizontal, 16).padding(.bottom, 50)
        }.refreshable { await syncNow() }
    }

    private func gameCard(_ t: String, _ s: String, _ p: String, _ u: String) -> some View {
        Button {
            SoundFX.menu()
            selectedGame = GameSelection(title: t, prefix: p)
        } label: {
            NeonCard {
                HStack(spacing: 14) {
                    GameLogoView(imageURL: u)
                    VStack(alignment: .leading, spacing: 5) {
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
            NeonCard {
                HStack(spacing: 14) {
                    ServerAvatarView(size: 58, shape: .roundedSquare, corner: 14)
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Menu Silent").font(.system(size: 16.5, weight: .heavy, design: .rounded)).foregroundStyle(.white)
                        Text("CHỌN PHIÊN BẢN").font(.system(size: 9.5, weight: .heavy)).tracking(2)
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    Spacer()
                    ChevronCircle()
                }.padding(.horizontal, 16).padding(.vertical, 15)
            }
        }.buttonStyle(.plain)
    }

    private func triggerSync() {
        guard !syncGuard else { return }
        syncGuard = true
        Task {
            await syncNow()
            await MainActor.run { syncGuard = false }
        }
    }

    @MainActor
    private func syncNow() async {
        isSyncing = true
        await SyncEngine.shared.run(store: store)
        store.reload()
        try? await Task.sleep(nanoseconds: 150_000_000)
        store.reload()
        isSyncing = false
    }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - SYNC ENGINE (TỐI ƯU TỐC ĐỘ)
// ═══════════════════════════════════════════════════════════════
final class SyncEngine {
    static let shared = SyncEngine()
    private let lock = NSLock()
    private var isRunning = false
    private var lastRemotes: [RemoteFileLite] = []
    private var lastFetch: Date = .distantPast
    private let remoteCacheTTL: TimeInterval = 5.0
    private init() {}

    func run(store: PatchProjectStore) async {
        lock.lock()
        if isRunning { lock.unlock(); return }
        isRunning = true
        lock.unlock()
        defer { lock.lock(); isRunning = false; lock.unlock() }

        guard let remotes = await fetchRemotesCached() else { return }

        // ── 1. Cập nhật meta hiện có
        var metaDict = PatchMetaStore.all()
        var changed = false
        for (ln, var m) in metaDict {
            if let r = remotes.first(where: { $0.uid == m.uid }) {
                if m.remoteName != r.filename { m.remoteName = r.filename; changed = true }
                if m.gameType != r.gameType { m.gameType = r.gameType; changed = true }
                if m.folder != r.folder { m.folder = r.folder; changed = true }
                if !m.tagOverride, m.tag != r.tag { m.tag = r.tag; changed = true }
                if !m.nameOverride, m.displayName != r.displayName { m.displayName = r.displayName; changed = true }
                if !m.noteOverride, m.note != r.note { m.note = r.note; changed = true }
                metaDict[ln] = m
            }
        }
        if changed { PatchMetaStore.save(metaDict) }

        await MainActor.run { store.reload() }

        // ── 2. Match local items chưa có meta
        let items = await MainActor.run { store.items }
        var toSave: [String: PatchMeta] = [:]
        for item in items {
            let ln = item.packageURL.lastPathComponent
            if PatchMetaStore.get(localName: ln) != nil { continue }
            if let r = findMatch(localName: ln, remotes: remotes) {
                toSave[ln] = makeMeta(r, localName: ln)
            }
        }
        if !toSave.isEmpty {
            var d = PatchMetaStore.all()
            for (k, v) in toSave { d[k] = v }
            PatchMetaStore.save(d)
        }

        // ── 3. Import file thiếu (song song tối đa 3)
        let missing = remotes.filter { !PatchMetaStore.hasUID($0.uid) }
        if !missing.isEmpty {
            await withTaskGroup(of: Void.self) { group in
                var active = 0
                let maxConcurrent = 3
                for r in missing {
                    if active >= maxConcurrent {
                        await group.next()
                        active -= 1
                    }
                    group.addTask { [weak self] in
                        _ = await self?.importOne(remote: r, store: store)
                    }
                    active += 1
                }
                await group.waitForAll()
            }
        }

        await MainActor.run { store.reload() }
    }

    private func makeMeta(_ r: RemoteFileLite, localName: String) -> PatchMeta {
        PatchMeta(uid: r.uid, localName: localName, remoteName: r.filename,
                  gameType: r.gameType, folder: r.folder, tag: r.tag,
                  displayName: r.displayName, note: r.note)
    }

    private func findMatch(localName: String, remotes: [RemoteFileLite]) -> RemoteFileLite? {
        if let r = remotes.first(where: { $0.filename == localName }) { return r }
        let base = (localName as NSString).deletingPathExtension.lowercased()
        if let r = remotes.first(where: {
            ($0.filename as NSString).deletingPathExtension.lowercased() == base
        }) { return r }
        return nil
    }

    /// Import 1 file — poll 120ms, tối đa 30s
    private func importOne(remote: RemoteFileLite, store: PatchProjectStore) async -> Bool {
        guard let url = URL(string: remote.url) else { return false }

        let before = await MainActor.run {
            Set(store.items.map { $0.packageURL.lastPathComponent })
        }
        await MainActor.run { store.importPackage(from: .remote(url)) }

        for i in 0..<250 {
            try? await Task.sleep(nanoseconds: 120_000_000)
            if Task.isCancelled { return false }

            if i % 3 == 0 { await MainActor.run { store.reload() } }

            let after = await MainActor.run {
                Set(store.items.map { $0.packageURL.lastPathComponent })
            }
            let newFiles = after.subtracting(before)
            guard !newFiles.isEmpty else { continue }

            var chosen = newFiles.first(where: { $0 == remote.filename })
            if chosen == nil {
                chosen = newFiles.first(where: {
                    $0.hasSuffix(remote.filename) || remote.filename.hasSuffix($0)
                })
            }
            if chosen == nil && newFiles.count == 1 { chosen = newFiles.first }
            guard let local = chosen else { continue }

            PatchMetaStore.set(makeMeta(remote, localName: local), localName: local)
            await MainActor.run { store.reload() }
            return true
        }
        return false
    }

    /// Fetch list.php với cache 5s tránh spam server
    private func fetchRemotesCached() async -> [RemoteFileLite]? {
        let now = Date()
        if now.timeIntervalSince(lastFetch) < remoteCacheTTL, !lastRemotes.isEmpty {
            return lastRemotes
        }
        guard let r = await fetchRemotes() else {
            return lastRemotes.isEmpty ? nil : lastRemotes
        }
        lastRemotes = r
        lastFetch = now
        return r
    }

    private func fetchRemotes() async -> [RemoteFileLite]? {
        let ts = Int(Date().timeIntervalSince1970)
        guard let url = URL(string:
            "https://solitudepremium.click/ipa/ipa/list.php?t=\(ts)") else { return nil }

        do {
            var req = URLRequest(url: url)
            req.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
            req.timeoutInterval = 12
            req.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
            req.setValue("no-cache", forHTTPHeaderField: "Pragma")
            req.setValue("gzip, deflate, br", forHTTPHeaderField: "Accept-Encoding")

            let (data, _) = try await NetSession.api.data(for: req)

            struct Wire: Decodable {
                let uid: String?
                let filename: String
                let gameType: String
                let folder: String?
                let displayName: String?
                let tag: String?
                let note: String?
                let url: String
            }
            let wire = try JSONDecoder().decode([Wire].self, from: data)
            return wire.map { w in
                RemoteFileLite(
                    filename: w.filename, gameType: w.gameType,
                    folder: w.folder ?? "Chung", tag: w.tag ?? "FREE",
                    displayName: w.displayName ?? "", note: w.note ?? "",
                    url: w.url)
            }
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
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 12_000_000_000)
                    if Task.isCancelled { break }
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
                Alert(title: Text(a.titleKey), message: Text(a.message(language: language)),
                      dismissButton: .default(Text("OK")))
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

    // ⭐ ĐÃ ẨN "X PATCH · Y FOLDER" — chỉ còn nút back + tên game
    private var topBar: some View {
        HStack(spacing: 14) {
            Button { SoundFX.tap(); dismiss() } label: {
                ZStack {
                    Circle().fill(Color.white.opacity(0.06)).frame(width: 40, height: 40)
                        .overlay(Circle().strokeBorder(.white, lineWidth: 1.4))
                    Image(systemName: "arrow.left").font(.system(size: 15, weight: .heavy))
                        .foregroundStyle(.white)
                }
            }.buttonStyle(.plain)

            Text(game.title)
                .font(.system(size: 15, weight: .heavy))
                .foregroundStyle(.white)

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

    private var renameBinding: Binding<Bool> {
        Binding(get: { renameItem != nil }, set: { if !$0 { renameItem = nil } })
    }
    private var tagBinding: Binding<Bool> {
        Binding(get: { tagPickerItem != nil }, set: { if !$0 { tagPickerItem = nil } })
    }
    private var noteBinding: Binding<Bool> {
        Binding(get: { noteItem != nil }, set: { if !$0 { noteItem = nil } })
    }

    private var listContent: some View {
        ScrollView(showsIndicators: false) {
            if displayedItems.isEmpty {
                EmptyStateView(message: folders.isEmpty
                    ? "Chưa có folder nào.\nĐang đồng bộ dữ liệu từ server..."
                    : "Folder này chưa có patch nào.")
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(displayedItems) { item in
                        patchRow(item: item)
                    }
                }.padding(.horizontal, 16).padding(.top, 4).padding(.bottom, 40)
            }
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
            onEditNote: {
                SoundFX.tap()
                noteItem = item
                noteText = currentNote(for: item)
            }
        )
    }

    private func localKey(for i: PatchLibraryItem) -> String {
        i.packageURL.lastPathComponent
    }
    private func meta(for i: PatchLibraryItem) -> PatchMeta? {
        PatchMetaStore.get(localName: localKey(for: i))
    }
    private func displayName(for i: PatchLibraryItem) -> String {
        if let m = meta(for: i), !m.displayName.isEmpty { return m.displayName }
        if let n = i.project?.name, !n.isEmpty { return n }
        var b = i.packageURL.deletingPathExtension().lastPathComponent
        b = GameTypeHelper.stripPrefix(b)
        b = b.replacingOccurrences(of: "_VIP", with: "")
        b = b.replacingOccurrences(of: "_FREE", with: "")
        return b
    }
    private func currentTag(for i: PatchLibraryItem) -> String {
        if let m = meta(for: i), !m.tag.isEmpty { return m.tag }
        return i.packageURL.deletingPathExtension().lastPathComponent.hasSuffix("_VIP") ? "VIP" : "FREE"
    }
    private func currentNote(for i: PatchLibraryItem) -> String {
        meta(for: i)?.note ?? ""
    }

    private func folderName(for i: PatchLibraryItem) -> String {
        if let m = meta(for: i), !m.folder.isEmpty { return m.folder }
        let c = i.packageURL.pathComponents.filter { $0 != "/" }
        if let idx = c.firstIndex(where: {
            GameTypeHelper.allPrefixes.contains($0) || $0 == "silent"
        }) {
            if c[idx] == "silent", idx + 1 < c.count,
               (c[idx+1] == "ffmax" || c[idx+1] == "ffnormal") {
                if idx + 2 < c.count { return c[idx+2] }
            } else if idx + 1 < c.count {
                return c[idx+1]
            }
        }
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
            let of = folderName(for: o)
            guard of == targetFolder else { return nil }
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
                    InstallerAlertSweep.start()
                    await MainActor.run { store.reload(); workingFileID = nil }
                } catch {
                    await MainActor.run {
                        workingFileID = nil; SoundFX.error()
                        activationInfo = ActivationInfo(
                            patchName: nameSnap, tag: tagSnap, note: noteSnap,
                            success: false,
                            errorMessage: "Không thể tắt: \(error.localizedDescription)")
                    }
                }
                return
            }

            do {
                guard let p = item.project else {
                    await MainActor.run { workingFileID = nil }; return
                }

                await MainActor.run { InstallerAlertSweep.start() }
                _ = try DevicePatchService.apply(project: p)
                await MainActor.run { InstallerAlertSweep.start() }

                await MainActor.run {
                    store.reload()
                    workingFileID = nil
                    SoundFX.success()
                    activationInfo = ActivationInfo(
                        patchName: nameSnap, tag: tagSnap, note: noteSnap,
                        success: true, errorMessage: nil)
                }
            } catch {
                await MainActor.run {
                    store.reload(); workingFileID = nil; SoundFX.error()
                    activationInfo = ActivationInfo(
                        patchName: nameSnap, tag: tagSnap, note: noteSnap,
                        success: false, errorMessage: error.localizedDescription)
                }
            }
        }
    }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - UNLOCK VIEW
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

// ═══════════════════════════════════════════════════════════════
// MARK: - PRESENTATION MODIFIER
// ═══════════════════════════════════════════════════════════════
private struct PatchStorePresentationModifier: ViewModifier {
    @ObservedObject var store: PatchProjectStore
    func body(content: Content) -> some View {
        content.sheet(item: $store.passwordRequest,
                      onDismiss: store.cancelUnlock) { r in
            PatchUnlockView(store: store, request: r)
        }
    }
}

extension View {
    func patchStorePresentation(_ store: PatchProjectStore) -> some View {
        modifier(PatchStorePresentationModifier(store: store))
    }
}
