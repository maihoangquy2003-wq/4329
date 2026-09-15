import SwiftUI
import UIKit
import UniformTypeIdentifiers
import AudioToolbox

// ═══════════════════════════════════════════════════════════════
// MARK: - SOUND
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
// MARK: - THEME
// ═══════════════════════════════════════════════════════════════
enum Theme {
    static let bg       = Color(red: 0.980, green: 0.980, blue: 0.972)
    static let bgSoft   = Color(red: 0.955, green: 0.955, blue: 0.945)
    static let surface  = Color.white
    static let ink      = Color(red: 0.039, green: 0.039, blue: 0.039)
    static let inkSoft  = Color(red: 0.42,  green: 0.42,  blue: 0.42)
    static let inkMuted = Color(red: 0.62,  green: 0.62,  blue: 0.62)
    static let line     = Color(red: 0.039, green: 0.039, blue: 0.039)
    static let gold     = Color(red: 0.788, green: 0.663, blue: 0.380)
    static let danger   = Color(red: 0.859, green: 0.208, blue: 0.208)

    static let border: CGFloat = 1.5
    static let radius: CGFloat = 18
    static let radiusSm: CGFloat = 12
}

// ═══════════════════════════════════════════════════════════════
// MARK: - BACKGROUND
// ═══════════════════════════════════════════════════════════════
struct NeonBackgroundView: View {
    var body: some View {
        ZStack {
            Theme.bg
            // Soft corner glow
            RadialGradient(
                colors: [Color.black.opacity(0.045), .clear],
                center: .topLeading, startRadius: 0, endRadius: 560
            )
            RadialGradient(
                colors: [Color.black.opacity(0.04), .clear],
                center: .bottomTrailing, startRadius: 0, endRadius: 560
            )
            GrainView()
        }
        .ignoresSafeArea()
    }
}

private struct GrainView: View {
    @State private var dots: [(CGPoint, CGFloat)] = []
    var body: some View {
        GeometryReader { geo in
            Canvas { ctx, size in
                for (pos, s) in dots {
                    let r = CGRect(x: pos.x * size.width,
                                   y: pos.y * size.height,
                                   width: s, height: s)
                    ctx.fill(Path(ellipseIn: r),
                             with: .color(Color.black.opacity(0.055)))
                }
            }
        }
        .allowsHitTesting(false)
        .onAppear {
            guard dots.isEmpty else { return }
            dots = (0..<140).map { _ in
                (CGPoint(x: .random(in: 0...1), y: .random(in: 0...1)),
                 CGFloat.random(in: 0.6...1.4))
            }
        }
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
    var remoteKey: String
    var remoteName: String
    var gameType: String
    var folder: String
    var tag: String
    var displayName: String
    var note: String
    var tagOverride: Bool
    var nameOverride: Bool
    var noteOverride: Bool
    var orphaned: Bool

    init(uid: String = "",
         remoteKey: String,
         remoteName: String,
         gameType: String,
         folder: String,
         tag: String,
         displayName: String,
         note: String,
         tagOverride: Bool = false,
         nameOverride: Bool = false,
         noteOverride: Bool = false,
         orphaned: Bool = false) {
        self.uid = uid
        self.remoteKey = remoteKey
        self.remoteName = remoteName
        self.gameType = gameType
        self.folder = folder
        self.tag = tag
        self.displayName = displayName
        self.note = note
        self.tagOverride = tagOverride
        self.nameOverride = nameOverride
        self.noteOverride = noteOverride
        self.orphaned = orphaned
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        uid          = (try? c.decode(String.self, forKey: .uid)) ?? ""
        remoteKey    = (try? c.decode(String.self, forKey: .remoteKey)) ?? ""
        remoteName   = (try? c.decode(String.self, forKey: .remoteName)) ?? ""
        gameType     = (try? c.decode(String.self, forKey: .gameType)) ?? "ffnormal"
        folder       = (try? c.decode(String.self, forKey: .folder)) ?? "Chung"
        tag          = (try? c.decode(String.self, forKey: .tag)) ?? "FREE"
        displayName  = (try? c.decode(String.self, forKey: .displayName)) ?? ""
        note         = (try? c.decode(String.self, forKey: .note)) ?? ""
        tagOverride  = (try? c.decode(Bool.self, forKey: .tagOverride)) ?? false
        nameOverride = (try? c.decode(Bool.self, forKey: .nameOverride)) ?? false
        noteOverride = (try? c.decode(Bool.self, forKey: .noteOverride)) ?? false
        orphaned     = (try? c.decode(Bool.self, forKey: .orphaned)) ?? false
    }
}

struct RemoteFileLite {
    let filename: String
    let gameType: String
    let folder: String
    let tag: String
    let displayName: String
    let note: String
    let url: String

    var compositeKey: String { "\(gameType)/\(folder)/\(filename)" }

    var uid: String {
        var h: UInt64 = 1469598103934665603
        for b in compositeKey.utf8 { h = (h ^ UInt64(b)) &* 1099511628211 }
        return String(h, radix: 16)
    }
}

struct ActivationInfo: Identifiable {
    let id = UUID()
    let patchName: String
    let note: String
    let success: Bool
    let errorMessage: String?
}

// ═══════════════════════════════════════════════════════════════
// MARK: - META STORE
// ═══════════════════════════════════════════════════════════════
enum PatchMetaStore {
    private static let key = "patch_meta_v17"

    static func all() -> [String: PatchMeta] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let dict = try? JSONDecoder().decode([String: PatchMeta].self, from: data)
        else { return [:] }
        return dict
    }
    static func save(_ dict: [String: PatchMeta]) {
        if let data = try? JSONEncoder().encode(dict) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
    static func set(_ meta: PatchMeta, forLocal local: String) {
        var d = all(); d[local] = meta; save(d)
    }
    static func get(forLocal local: String) -> PatchMeta? { all()[local] }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - SUB VIEWS
// ═══════════════════════════════════════════════════════════════
private struct NeoCard<Content: View>: View {
    @ViewBuilder let content: Content
    var body: some View {
        content
            .background(
                RoundedRectangle(cornerRadius: Theme.radius, style: .continuous)
                    .fill(Theme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radius, style: .continuous)
                    .strokeBorder(Theme.line, lineWidth: Theme.border)
            )
            .shadow(color: .black.opacity(0.08), radius: 14, x: 0, y: 6)
            .shadow(color: .black.opacity(0.04), radius: 3, x: 0, y: 2)
    }
}

private struct FFLogoView: View {
    var body: some View {
        AsyncImage(url: URL(string: "https://solitudepremium.click/ipa/ipa/free.jpg")) { phase in
            switch phase {
            case .empty:
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Theme.bgSoft)
                    ProgressView().tint(Theme.ink)
                }
            case .success(let img):
                img.resizable().scaledToFill()
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            case .failure:
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Theme.bgSoft)
                    Image(systemName: "flame.fill")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Theme.ink)
                }
            @unknown default: EmptyView()
            }
        }
        .frame(width: 58, height: 58)
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Theme.line, lineWidth: 1.5)
        )
    }
}

private struct AvatarView: View {
    @State private var rotate = false
    var body: some View {
        ZStack {
            // Thin rotating dashed ring
            Circle()
                .strokeBorder(
                    Theme.ink.opacity(0.35),
                    style: StrokeStyle(lineWidth: 1, dash: [2, 5])
                )
                .frame(width: 118, height: 118)
                .rotationEffect(.degrees(rotate ? 360 : 0))

            // Main solid ring
            Circle()
                .strokeBorder(Theme.line, lineWidth: 2)
                .frame(width: 98, height: 98)

            avatarImage
                .frame(width: 84, height: 84)
                .clipShape(Circle())
                .overlay(Circle().strokeBorder(Theme.line, lineWidth: 1.5))
        }
        .frame(width: 128, height: 128)
        .onAppear {
            withAnimation(.linear(duration: 22).repeatForever(autoreverses: false)) {
                rotate = true
            }
        }
    }
    private var avatarImage: some View {
        AsyncImage(url: URL(string: "https://solitudepremium.click/ipa/ipa/li.jpg")) { phase in
            switch phase {
            case .empty:
                ZStack { Theme.bgSoft; ProgressView().tint(Theme.ink) }
            case .success(let img): img.resizable().scaledToFill()
            case .failure:
                ZStack {
                    Theme.bgSoft
                    Image(systemName: "person.fill")
                        .font(.system(size: 42, weight: .medium))
                        .foregroundStyle(Theme.inkMuted)
                }
            @unknown default: EmptyView()
            }
        }
    }
}

private struct ChevronCircle: View {
    var body: some View {
        ZStack {
            Circle().fill(Theme.ink).frame(width: 36, height: 36)
            Image(systemName: "arrow.up.right")
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(.white)
        }
    }
}

private struct TagPill: View {
    let tag: String
    private var isVIP: Bool { tag == "VIP" }
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: isVIP ? "crown.fill" : "shield.fill")
                .font(.system(size: 8, weight: .heavy))
            Text(tag)
                .font(.system(size: 9, weight: .heavy))
                .tracking(1.0)
        }
        .padding(.horizontal, 8).padding(.vertical, 4)
        .foregroundStyle(isVIP ? Theme.gold : Theme.ink)
        .background(
            Capsule().fill(isVIP ? Theme.gold.opacity(0.14) : Theme.ink.opacity(0.06))
        )
        .overlay(
            Capsule().strokeBorder(
                isVIP ? Theme.gold : Theme.ink.opacity(0.6),
                lineWidth: 1.2
            )
        )
    }
}

private struct PatchIconView: View {
    let tag: String
    private var isVIP: Bool { tag == "VIP" }
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isVIP ? Theme.gold.opacity(0.14) : Theme.surface)
                .frame(width: 46, height: 46)
            Image(systemName: isVIP ? "crown.fill" : "shield.lefthalf.filled")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(isVIP ? Theme.gold : Theme.ink)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(isVIP ? Theme.gold : Theme.line, lineWidth: 1.5)
        )
    }
}

private struct CustomToggle: View {
    let isOn: Bool
    let disabled: Bool
    let action: (Bool) -> Void
    var body: some View {
        Button {
            guard !disabled else { return }
            action(!isOn)
        } label: {
            ZStack {
                Capsule()
                    .fill(isOn ? Theme.ink : Theme.surface)
                    .frame(width: 52, height: 30)
                    .overlay(
                        Capsule().strokeBorder(
                            isOn ? Theme.ink : Theme.line,
                            lineWidth: 1.5
                        )
                    )
                HStack {
                    if isOn {
                        Spacer()
                        Circle()
                            .fill(.white)
                            .frame(width: 22, height: 22)
                            .padding(.trailing, 3)
                    } else {
                        Circle()
                            .fill(Theme.ink)
                            .frame(width: 22, height: 22)
                            .padding(.leading, 3)
                        Spacer()
                    }
                }
                .frame(width: 52, height: 30)
            }
            .animation(.spring(response: 0.28, dampingFraction: 0.72), value: isOn)
            .opacity(disabled ? 0.45 : 1.0)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }
}

private struct FolderTab: View {
    let title: String
    let isActive: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .heavy))
                .tracking(1.3)
                .padding(.horizontal, 18).padding(.vertical, 10)
                .background(
                    Capsule().fill(isActive ? Theme.ink : Theme.surface)
                )
                .foregroundStyle(isActive ? .white : Theme.ink)
                .overlay(
                    Capsule().strokeBorder(Theme.line, lineWidth: 1.5)
                )
                .shadow(
                    color: isActive ? .black.opacity(0.2) : .clear,
                    radius: 10, x: 0, y: 4
                )
        }
        .buttonStyle(.plain)
    }
}

private struct PatchRow: View {
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
        HStack(spacing: 13) {
            PatchIconView(tag: tag)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 7) {
                    Text(displayName)
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                    Button(action: onTapTag) { TagPill(tag: tag) }
                        .buttonStyle(.plain)
                }
                if !note.isEmpty {
                    HStack(alignment: .top, spacing: 5) {
                        Image(systemName: "text.alignleft")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(Theme.inkMuted)
                            .padding(.top, 1)
                        Text(note)
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundStyle(Theme.inkSoft)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                }
            }

            Spacer(minLength: 6)

            if isWorking {
                ProgressView()
                    .tint(Theme.ink)
                    .scaleEffect(0.8)
                    .frame(width: 52, height: 30)
            } else {
                CustomToggle(isOn: isApplied, disabled: false) { nv in
                    onToggle(nv)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(isApplied ? Theme.bgSoft : Theme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(
                    isApplied ? Theme.line : Theme.line.opacity(0.28),
                    lineWidth: isApplied ? 1.6 : 1.2
                )
        )
        .shadow(
            color: isApplied ? .black.opacity(0.09) : .black.opacity(0.04),
            radius: isApplied ? 12 : 6, x: 0, y: 4
        )
        .contextMenu {
            Button(action: onRename)   { Label("Đổi tên", systemImage: "pencil") }
            Button(action: onTapTag)   { Label("Đổi VIP/FREE", systemImage: "crown") }
            Button(action: onEditNote) { Label("Sửa ghi chú", systemImage: "note.text") }
        }
    }
}

private struct EmptyStateView: View {
    let message: String
    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .strokeBorder(Theme.line.opacity(0.25),
                                  style: StrokeStyle(lineWidth: 1.4, dash: [3, 5]))
                    .frame(width: 74, height: 74)
                Image(systemName: "tray")
                    .font(.system(size: 26, weight: .light))
                    .foregroundStyle(Theme.inkSoft)
            }
            Text(message)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .padding(.top, 60)
        .frame(maxWidth: .infinity)
    }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - ACTIVATION SHEET (hiện cả khi THÀNH CÔNG & THẤT BẠI)
// ═══════════════════════════════════════════════════════════════
struct ActivationNoteSheet: View {
    let info: ActivationInfo
    let onDismiss: () -> Void

    @State private var appear = false
    @State private var pulse = false
    @State private var copied = false

    private var accent: Color {
        info.success ? Theme.ink : Theme.danger
    }
    private var titleText: String {
        info.success ? "ĐÃ KÍCH HOẠT" : "KHÔNG KÍCH HOẠT ĐƯỢC"
    }
    private var iconName: String {
        info.success ? "checkmark" : "xmark"
    }
    private var hasNote: Bool {
        !info.note.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            // Subtle corner glow
            RadialGradient(
                colors: [accent.opacity(0.06), .clear],
                center: .top, startRadius: 0, endRadius: 400
            )
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 26) {
                    Spacer(minLength: 50)

                    // ─── BIG ICON ───
                    ZStack {
                        Circle()
                            .strokeBorder(accent.opacity(0.18), lineWidth: 1.5)
                            .frame(width: pulse ? 130 : 108,
                                   height: pulse ? 130 : 108)

                        Circle()
                            .fill(accent)
                            .frame(width: 90, height: 90)
                            .shadow(color: accent.opacity(0.35), radius: 22, y: 8)

                        Image(systemName: iconName)
                            .font(.system(size: 38, weight: .heavy))
                            .foregroundStyle(.white)
                    }
                    .onAppear {
                        withAnimation(.easeInOut(duration: 1.8)
                            .repeatForever(autoreverses: true)) {
                            pulse = true
                        }
                    }

                    // ─── TITLE BLOCK ───
                    VStack(spacing: 10) {
                        Text("HEADLOCK ZENIS")
                            .font(.system(size: 10, weight: .heavy))
                            .tracking(4)
                            .foregroundStyle(Theme.inkMuted)

                        Text(titleText)
                            .font(.system(size: 24, weight: .heavy))
                            .tracking(2)
                            .foregroundStyle(accent)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)

                        Text(info.patchName)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Theme.inkSoft)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 28)
                            .padding(.top, 2)
                    }

                    // ─── ERROR BOX ───
                    if !info.success,
                       let errMsg = info.errorMessage, !errMsg.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 7) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 11, weight: .heavy))
                                    .foregroundStyle(Theme.danger)
                                Text("LÝ DO")
                                    .font(.system(size: 10, weight: .heavy))
                                    .tracking(2)
                                    .foregroundStyle(Theme.danger)
                            }
                            Text(errMsg)
                                .font(.system(size: 12.5, weight: .medium))
                                .foregroundStyle(Theme.ink)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Theme.danger.opacity(0.06))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(Theme.danger.opacity(0.5), lineWidth: 1.2)
                        )
                        .padding(.horizontal, 24)
                    }

                    // ─── NOTE + COPY BUTTON ───
                    if hasNote {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack(spacing: 8) {
                                Image(systemName: "note.text")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(Theme.ink)
                                Text("GHI CHÚ")
                                    .font(.system(size: 10, weight: .heavy))
                                    .tracking(2.2)
                                    .foregroundStyle(Theme.ink)
                                Spacer()
                            }

                            Text(info.note)
                                .font(.system(size: 13.5, weight: .medium))
                                .foregroundStyle(Theme.ink)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(14)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(Theme.bgSoft)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .strokeBorder(Theme.line.opacity(0.25),
                                                      style: StrokeStyle(lineWidth: 1,
                                                                         dash: [4, 4]))
                                )

                            // ⚡ NÚT COPY GHI CHÚ
                            Button {
                                SoundFX.tap()
                                UIPasteboard.general.string = info.note
                                withAnimation(.spring(response: 0.3,
                                                     dampingFraction: 0.72)) {
                                    copied = true
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                                    withAnimation(.spring(response: 0.3,
                                                         dampingFraction: 0.72)) {
                                        copied = false
                                    }
                                }
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: copied
                                          ? "checkmark"
                                          : "doc.on.doc.fill")
                                        .font(.system(size: 12, weight: .heavy))
                                    Text(copied ? "ĐÃ COPY VÀO CLIPBOARD"
                                                : "COPY GHI CHÚ")
                                        .font(.system(size: 11.5, weight: .heavy))
                                        .tracking(1.8)
                                }
                                .foregroundStyle(copied ? .white : Theme.ink)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 13)
                                .background(
                                    RoundedRectangle(cornerRadius: 12,
                                                     style: .continuous)
                                        .fill(copied ? Theme.ink : Theme.surface)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12,
                                                     style: .continuous)
                                        .strokeBorder(Theme.line, lineWidth: 1.5)
                                )
                                .shadow(color: .black.opacity(copied ? 0.15 : 0.06),
                                        radius: 8, y: 4)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(18)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Theme.surface)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(Theme.line, lineWidth: 1.6)
                        )
                        .shadow(color: .black.opacity(0.06), radius: 12, y: 5)
                        .padding(.horizontal, 22)
                    }

                    // ─── DISMISS BUTTON ───
                    Button {
                        SoundFX.tap()
                        onDismiss()
                    } label: {
                        Text("ĐÃ HIỂU")
                            .font(.system(size: 14, weight: .heavy))
                            .tracking(3)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Theme.ink)
                            )
                            .shadow(color: .black.opacity(0.25), radius: 14, y: 8)
                            .padding(.horizontal, 40)
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, 50)
                }
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.4)) { appear = true }
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
    @State private var isSyncing = false
    @State private var lastSyncDate: Date = .distantPast
    @State private var syncGuard = false

    private let autoTimer = Timer.publish(every: 6, on: .main, in: .common).autoconnect()

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
                VStack(spacing: 0) {
                    header
                    content
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                store.reload()
                triggerSync(force: true)
            }
            .onReceive(autoTimer) { _ in
                if Date().timeIntervalSince(lastSyncDate) > 12 {
                    triggerSync(force: false)
                }
            }
            .onChange(of: scenePhase) { phase in
                if phase == .active {
                    store.reload()
                    triggerSync(force: true)
                }
            }
            .sheet(item: $selectedGame) { game in
                PatchGameDetailView(
                    game: game,
                    store: store,
                    actionAlert: $actionAlert,
                    language: language
                )
            }
            .alert(item: $actionAlert) { alert in
                Alert(
                    title: Text(alert.titleKey),
                    message: Text(alert.message(language: language)),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }

    // ─── HEADER ───
    private var header: some View {
        VStack(spacing: 0) {

            // Top strip with sync pill
            HStack {
                Spacer()
                syncPill
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 6)

            // Avatar
            AvatarView()
                .padding(.top, 4)

            // Brand
            Text("ZENITH SOLITUDE")
                .font(.system(size: 21, weight: .black, design: .serif))
                .tracking(3.5)
                .foregroundStyle(Theme.ink)
                .padding(.top, 14)

            // Subtitle with double border line
            HStack(spacing: 10) {
                Rectangle()
                    .fill(Theme.line.opacity(0.35))
                    .frame(width: 26, height: 1)
                Text("HEADLOCK ZENIS")
                    .font(.system(size: 9.5, weight: .heavy))
                    .tracking(4.2)
                    .foregroundStyle(Theme.inkSoft)
                Rectangle()
                    .fill(Theme.line.opacity(0.35))
                    .frame(width: 26, height: 1)
            }
            .padding(.top, 8)
            .padding(.bottom, 22)
        }
    }

    private var syncPill: some View {
        HStack(spacing: 7) {
            ZStack {
                Circle()
                    .fill((isSyncing ? Color.orange : Color.green).opacity(0.16))
                    .frame(width: 14, height: 14)
                Circle()
                    .fill(isSyncing ? Color.orange : Color.green)
                    .frame(width: 7, height: 7)
            }
            Text(isSyncing ? "ĐANG CẬP NHẬT" : "ĐÃ KẾT NỐI")
                .font(.system(size: 9, weight: .heavy))
                .tracking(1.6)
                .foregroundStyle(Theme.ink)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(
            Capsule().fill(Theme.surface)
        )
        .overlay(Capsule().strokeBorder(Theme.line, lineWidth: 1.2))
        .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
        .animation(.easeInOut(duration: 0.25), value: isSyncing)
    }

    // ─── CONTENT ───
    private var content: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {
                gameCard(title: "Free Fire Max", subtitle: "PREMIUM EDITION", prefix: "ffmax")
                gameCard(title: "Free Fire Thường", subtitle: "CLASSIC EDITION", prefix: "ffnormal")

                HStack(spacing: 8) {
                    Rectangle().fill(Theme.line.opacity(0.25)).frame(height: 1)
                    Text("BY ZENITH SOLITUDE")
                        .font(.system(size: 9, weight: .heavy))
                        .tracking(3)
                        .foregroundStyle(Theme.inkMuted)
                        .fixedSize()
                    Rectangle().fill(Theme.line.opacity(0.25)).frame(height: 1)
                }
                .padding(.horizontal, 40)
                .padding(.top, 22)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 50)
        }
        .refreshable { triggerSync(force: true) }
    }

    @ViewBuilder
    private func gameCard(title: String, subtitle: String, prefix: String) -> some View {
        Button {
            SoundFX.menu()
            selectedGame = GameSelection(title: title, prefix: prefix)
        } label: {
            NeoCard {
                HStack(spacing: 14) {
                    FFLogoView()
                    VStack(alignment: .leading, spacing: 5) {
                        Text(title)
                            .font(.system(size: 16.5, weight: .heavy, design: .rounded))
                            .foregroundStyle(Theme.ink)
                        Text(subtitle)
                            .font(.system(size: 9.5, weight: .heavy))
                            .tracking(2)
                            .foregroundStyle(Theme.inkMuted)
                    }
                    Spacer()
                    ChevronCircle()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 15)
            }
        }
        .buttonStyle(.plain)
    }

    private func triggerSync(force: Bool) {
        guard !syncGuard else { return }
        syncGuard = true
        Task {
            await syncNow(force: force)
            await MainActor.run { syncGuard = false }
        }
    }

    private func syncNow(force: Bool) async {
        if !force {
            let elapsed = Date().timeIntervalSince(lastSyncDate)
            if elapsed < 2.0 { return }
        }
        await MainActor.run { isSyncing = true }
        await SyncEngine.shared.run(store: store)
        await MainActor.run {
            isSyncing = false
            lastSyncDate = Date()
        }
    }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - SYNC ENGINE
// ═══════════════════════════════════════════════════════════════
final class SyncEngine {
    static let shared = SyncEngine()
    private let metaLock = NSLock()
    private var isRunning = false
    private init() {}

    func run(store: PatchProjectStore) async {
        if isRunning { return }
        isRunning = true
        defer { isRunning = false }

        guard let remotes = await fetchRemotes() else { return }

        // 1) Lookup remote
        var remoteByKey: [String: RemoteFileLite] = [:]
        remoteByKey.reserveCapacity(remotes.count)
        for r in remotes { remoteByKey[r.compositeKey] = r }

        // 2) Sync meta + mark orphan
        var metaDict = PatchMetaStore.all()
        for (localName, var meta) in metaDict {
            let key = meta.remoteKey.isEmpty
                ? "\(meta.gameType)/\(meta.folder)/\(meta.remoteName)"
                : meta.remoteKey
            if let remote = remoteByKey[key] {
                meta.orphaned  = false
                meta.remoteKey = remote.compositeKey
                meta.uid       = remote.uid
                meta.gameType  = remote.gameType
                meta.folder    = remote.folder
                if !meta.tagOverride  { meta.tag         = remote.tag }
                if !meta.nameOverride { meta.displayName = remote.displayName }
                if !meta.noteOverride { meta.note        = remote.note }
            } else {
                meta.orphaned = true
            }
            metaDict[localName] = meta
        }
        PatchMetaStore.save(metaDict)

        // 3) Missing files
        var existingUIDs = Set<String>()
        for meta in metaDict.values where !meta.orphaned {
            existingUIDs.insert(meta.uid)
        }
        let missing = remotes.filter { !existingUIDs.contains($0.uid) }

        await MainActor.run { store.reload() }
        guard !missing.isEmpty else { return }

        // 4) Fire all downloads
        await MainActor.run {
            for r in missing {
                if let url = URL(string: r.url) {
                    store.importPackage(from: .remote(url))
                }
            }
        }

        // 5) Central poll loop
        var pendingByUID: [String: RemoteFileLite] = [:]
        for r in missing { pendingByUID[r.uid] = r }

        var seen = Set(metaDict.keys)

        for _ in 0..<300 {
            try? await Task.sleep(nanoseconds: 200_000_000)
            await MainActor.run { store.reload() }

            let after = await MainActor.run {
                Set(store.items.map { $0.packageURL.lastPathComponent })
            }
            let newFiles = after.subtracting(seen)
            guard !newFiles.isEmpty else {
                if pendingByUID.isEmpty { break }
                continue
            }

            for newFile in newFiles {
                seen.insert(newFile)

                if let remote = pendingByUID.values.first(where: { $0.filename == newFile }) {
                    assign(remote: remote, localName: newFile)
                    pendingByUID.removeValue(forKey: remote.uid)
                    continue
                }
                if let remote = pendingByUID.values.first(where: {
                    newFile.hasSuffix($0.filename) || $0.filename.hasSuffix(newFile)
                }) {
                    assign(remote: remote, localName: newFile)
                    pendingByUID.removeValue(forKey: remote.uid)
                    continue
                }
                if pendingByUID.count == 1 && newFiles.count == 1,
                   let (_, remote) = pendingByUID.first {
                    assign(remote: remote, localName: newFile)
                    pendingByUID.removeAll()
                }
            }
            if pendingByUID.isEmpty { break }
        }

        await MainActor.run { store.reload() }
    }

    private func assign(remote: RemoteFileLite, localName: String) {
        metaLock.lock()
        defer { metaLock.unlock() }
        let meta = PatchMeta(
            uid:         remote.uid,
            remoteKey:   remote.compositeKey,
            remoteName:  remote.filename,
            gameType:    remote.gameType,
            folder:      remote.folder,
            tag:         remote.tag,
            displayName: remote.displayName,
            note:        remote.note,
            orphaned:    false
        )
        PatchMetaStore.set(meta, forLocal: localName)
    }

    private func fetchRemotes() async -> [RemoteFileLite]? {
        let ts = Int(Date().timeIntervalSince1970)
        guard let url = URL(string:
            "https://solitudepremium.click/ipa/ipa/list.php?t=\(ts)") else { return nil }

        for attempt in 0..<2 {
            do {
                var req = URLRequest(url: url)
                req.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
                req.timeoutInterval = 12
                req.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
                req.setValue("no-cache", forHTTPHeaderField: "Pragma")
                req.setValue("gzip, deflate, br", forHTTPHeaderField: "Accept-Encoding")

                let (data, _) = try await URLSession.shared.data(for: req)

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
                        filename:    w.filename,
                        gameType:    w.gameType,
                        folder:      w.folder      ?? "Chung",
                        tag:         w.tag         ?? "FREE",
                        displayName: w.displayName ?? "",
                        note:        w.note        ?? "",
                        url:         w.url
                    )
                }
            } catch {
                print("Fetch attempt \(attempt) failed: \(error.localizedDescription)")
                if attempt == 0 { try? await Task.sleep(nanoseconds: 500_000_000) }
            }
        }
        return nil
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

    private let refreshTimer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            ZStack {
                NeonBackgroundView()
                VStack(spacing: 0) {
                    topBar
                    if !folders.isEmpty { folderTabs }
                    listContent
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                store.reload()
                syncFolders()
                guard !didInitialSync else { return }
                didInitialSync = true
                Task {
                    await SyncEngine.shared.run(store: store)
                    await MainActor.run {
                        store.reload()
                        syncFolders()
                    }
                }
            }
            .onChange(of: scenePhase) { phase in
                if phase == .active {
                    Task { await SyncEngine.shared.run(store: store) }
                }
            }
            .onReceive(refreshTimer) { _ in
                refreshTick &+= 1
                store.reload()
                syncFolders()
            }
            .alert(item: $actionAlert) { alert in
                Alert(
                    title: Text(alert.titleKey),
                    message: Text(alert.message(language: language)),
                    dismissButton: .default(Text("OK"))
                )
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
            .fullScreenCover(item: $activationInfo) { info in
                ActivationNoteSheet(info: info) { activationInfo = nil }
            }
        }
    }

    // ─── CUSTOM TOP BAR ───
    private var topBar: some View {
        HStack(spacing: 14) {
            Button {
                SoundFX.tap(); dismiss()
            } label: {
                ZStack {
                    Circle()
                        .fill(Theme.surface)
                        .frame(width: 40, height: 40)
                        .overlay(Circle().strokeBorder(Theme.line, lineWidth: 1.5))
                        .shadow(color: .black.opacity(0.08), radius: 6, y: 3)
                    Image(systemName: "arrow.left")
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundStyle(Theme.ink)
                }
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(game.title)
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                Text("\(displayedItems.count) PATCH · \(folders.count) FOLDER")
                    .font(.system(size: 9.5, weight: .heavy))
                    .tracking(1.4)
                    .foregroundStyle(Theme.inkMuted)
            }

            Spacer()
        }
        .padding(.horizontal, 18)
        .padding(.top, 14)
        .padding(.bottom, 14)
    }

    private func syncFolders() {
        let currentFolders = folders
        if currentFolders.isEmpty { selectedFolder = nil; return }
        if let sel = selectedFolder, currentFolders.contains(sel) { return }
        selectedFolder = currentFolders.first
    }

    private var gameItems: [PatchLibraryItem] {
        _ = refreshTick
        return store.items.filter { item in
            let name = item.packageURL.lastPathComponent
            let meta = PatchMetaStore.get(forLocal: name)
            if let m = meta, !m.gameType.isEmpty {
                if m.orphaned { return false }
                return m.gameType == game.prefix
            }
            let isMax = name.hasPrefix("ffmax_")
            let isNormal = name.hasPrefix("ffnormal_")
            let isPlain = !isMax && !isNormal
            if game.prefix == "ffmax" { return isMax }
            return isNormal || isPlain
        }
    }

    private var folders: [String] {
        let names = gameItems
            .map { folderName(for: $0) }
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        var unique: [String] = []
        for n in names { if !unique.contains(n) { unique.append(n) } }
        return unique.sorted()
    }

    private var displayedItems: [PatchLibraryItem] {
        guard let sel = selectedFolder else { return [] }
        return gameItems.filter { folderName(for: $0) == sel }
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

    private var folderTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 9) {
                ForEach(folders, id: \.self) { f in
                    FolderTab(title: f, isActive: selectedFolder == f) {
                        SoundFX.tap()
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.75)) {
                            selectedFolder = f
                        }
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 4)
        }
        .padding(.bottom, 14)
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
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 40)
            }
        }
    }

    @ViewBuilder
    private func patchRow(item: PatchLibraryItem) -> some View {
        let receipt = DevicePatchService.latestReceipt(projectID: item.id)
        let isApplied = (receipt != nil)
        let name = displayName(for: item)
        PatchRow(
            isApplied: isApplied,
            isWorking: workingFileID == item.id.uuidString,
            displayName: name,
            tag: currentTag(for: item),
            note: currentNote(for: item),
            onToggle: { nv in
                if nv { SoundFX.tingTing() } else { SoundFX.tap() }
                togglePatch(item: item, activate: nv)
            },
            onTapTag:  { SoundFX.tap(); tagPickerItem = item },
            onRename:  { SoundFX.tap(); renameItem = item; renameText = name },
            onEditNote:{ SoundFX.tap(); noteItem = item; noteText = currentNote(for: item) }
        )
    }

    private func localKey(for item: PatchLibraryItem) -> String {
        item.packageURL.lastPathComponent
    }
    private func meta(for item: PatchLibraryItem) -> PatchMeta? {
        PatchMetaStore.get(forLocal: localKey(for: item))
    }
    private func displayName(for item: PatchLibraryItem) -> String {
        if let m = meta(for: item), !m.displayName.isEmpty { return m.displayName }
        if let n = item.project?.name, !n.isEmpty { return n }
        return item.packageURL.deletingPathExtension().lastPathComponent
            .replacingOccurrences(of: "_VIP", with: "")
            .replacingOccurrences(of: "_FREE", with: "")
            .replacingOccurrences(of: "ffmax_", with: "")
            .replacingOccurrences(of: "ffnormal_", with: "")
    }
    private func currentTag(for item: PatchLibraryItem) -> String {
        if let m = meta(for: item), !m.tag.isEmpty { return m.tag }
        return item.packageURL.deletingPathExtension().lastPathComponent
            .hasSuffix("_VIP") ? "VIP" : "FREE"
    }
    private func currentNote(for item: PatchLibraryItem) -> String {
        meta(for: item)?.note ?? ""
    }
    private func folderName(for item: PatchLibraryItem) -> String {
        if let m = meta(for: item), !m.folder.isEmpty { return m.folder }
        let fname = item.packageURL.lastPathComponent
        if let range = fname.range(of: #"^ZENITH_([a-zA-Z0-9]+)_"#, options: .regularExpression) {
            let matched = String(fname[range])
                .replacingOccurrences(of: "ZENITH_", with: "")
                .trimmingCharacters(in: CharacterSet(charactersIn: "_"))
            if !matched.isEmpty { return matched.uppercased() }
        }
        let comps = item.packageURL.pathComponents.filter { $0 != "/" }
        if let idx = comps.firstIndex(where: { $0 == "ffmax" || $0 == "ffnormal" }),
           idx + 2 < comps.count {
            return comps[idx + 1]
        }
        return "Chung"
    }

    private func commitRename() {
        guard let item = renameItem else { return }
        let t = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { renameItem = nil; return }
        let key = localKey(for: item)
        if var m = PatchMetaStore.get(forLocal: key) {
            m.displayName = t; m.nameOverride = true
            PatchMetaStore.set(m, forLocal: key)
        }
        store.reload()
        renameItem = nil
    }
    private func commitTag(_ tag: String) {
        guard let item = tagPickerItem else { return }
        let key = localKey(for: item)
        if var m = PatchMetaStore.get(forLocal: key) {
            m.tag = tag; m.tagOverride = true
            PatchMetaStore.set(m, forLocal: key)
        }
        store.reload()
        tagPickerItem = nil
    }
    private func commitNote() {
        guard let item = noteItem else { return }
        let t = noteText.trimmingCharacters(in: .whitespacesAndNewlines)
        let key = localKey(for: item)
        if var m = PatchMetaStore.get(forLocal: key) {
            m.note = t; m.noteOverride = true
            PatchMetaStore.set(m, forLocal: key)
        }
        store.reload()
        noteItem = nil
    }

    private func togglePatch(item: PatchLibraryItem, activate: Bool) {
        workingFileID = item.id.uuidString
        let nameSnap = displayName(for: item)
        let noteSnap = currentNote(for: item)

        Task.detached(priority: .userInitiated) {
            if !activate {
                do {
                    if let r = DevicePatchService.latestReceipt(projectID: item.id) {
                        try DevicePatchService.restore(receipt: r)
                    }
                    await MainActor.run {
                        store.reload()
                        workingFileID = nil
                    }
                } catch {
                    await MainActor.run {
                        workingFileID = nil
                        SoundFX.error()
                        activationInfo = ActivationInfo(
                            patchName: nameSnap, note: noteSnap,
                            success: false,
                            errorMessage: "Không thể tắt: \(error.localizedDescription)"
                        )
                    }
                }
                return
            }

            do {
                guard let p = item.project else {
                    await MainActor.run { workingFileID = nil }
                    return
                }
                _ = try DevicePatchService.apply(project: p)
                // ⚡ HIỆN SHEET KHI THÀNH CÔNG — có note + nút copy
                await MainActor.run {
                    store.reload()
                    workingFileID = nil
                    SoundFX.success()
                    activationInfo = ActivationInfo(
                        patchName: nameSnap, note: noteSnap,
                        success: true, errorMessage: nil
                    )
                }
            } catch {
                await MainActor.run {
                    store.reload()
                    workingFileID = nil
                    SoundFX.error()
                    activationInfo = ActivationInfo(
                        patchName: nameSnap, note: noteSnap,
                        success: false,
                        errorMessage: error.localizedDescription
                    )
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
                    if let errorKey = store.unlockErrorKey {
                        Text(errorText(errorKey))
                            .font(.footnote)
                            .foregroundStyle(.red)
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
    private func errorText(_ key: String) -> String {
        if let a = store.unlockErrorArgument { return language.text(key, a) }
        return language.text(key)
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
        content
            .sheet(item: $store.passwordRequest, onDismiss: store.cancelUnlock) { request in
                PatchUnlockView(store: store, request: request)
            }
    }
}

extension View {
    func patchStorePresentation(_ store: PatchProjectStore) -> some View {
        modifier(PatchStorePresentationModifier(store: store))
    }
}
