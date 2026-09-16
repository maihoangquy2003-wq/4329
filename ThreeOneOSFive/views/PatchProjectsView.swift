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
// MARK: - THEME (giữ nguyên tên biến)
// ═══════════════════════════════════════════════════════════════
enum Theme {
    static let bg        = Color.black
    static let surface   = Color(red: 0.05, green: 0.05, blue: 0.05)
    static let surfaceHi = Color(red: 0.09, green: 0.09, blue: 0.09)
    static let ink       = Color.white
    static let inkSoft   = Color.white.opacity(0.7)
    static let inkMuted  = Color.white.opacity(0.4)
    static let line      = Color.white
    static let lineHi    = Color.white.opacity(0.9)
    static let lineMid   = Color.white.opacity(0.35)
    static let lineFaint = Color.white.opacity(0.14)
    static let gold      = Color(red: 0.85, green: 0.7, blue: 0.4)
    static let danger    = Color(red: 1.0, green: 0.32, blue: 0.32)
}

// ═══════════════════════════════════════════════════════════════
// MARK: - BACKGROUND (đơn giản, không lag)
// ═══════════════════════════════════════════════════════════════
struct NeonBackgroundView: View {
    var body: some View {
        ZStack {
            Color.black
            // Two soft glows only — no animation, no canvas
            RadialGradient(
                colors: [Color.white.opacity(0.06), .clear],
                center: .topLeading, startRadius: 0, endRadius: 500
            )
            RadialGradient(
                colors: [Color.white.opacity(0.04), .clear],
                center: .bottomTrailing, startRadius: 0, endRadius: 500
            )
        }
        .ignoresSafeArea()
    }
}

// Giữ tên cũ cho tương thích với code cũ
struct AuroraView: View {
    var body: some View { EmptyView() }
}
struct VignetteView: View {
    var body: some View { EmptyView() }
}
struct CosmicFieldView: View {
    var paused: Bool = false
    var body: some View { EmptyView() }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - MODELS (KHÔNG ĐỔI)
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
        gameType     = (try? c.decode(String.self, forKey: .gameType)) ?? ""
        folder       = (try? c.decode(String.self, forKey: .folder)) ?? ""
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
    let tag: String
    let note: String
    let success: Bool
    let errorMessage: String?
}

// ═══════════════════════════════════════════════════════════════
// MARK: - META STORE (KHÔNG ĐỔI KEY)
// ═══════════════════════════════════════════════════════════════
enum PatchMetaStore {
    private static let key = "patch_meta_v21"

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
    static func set(_ meta: PatchMeta, uid: String) {
        var d = all()
        d[uid] = meta
        save(d)
    }
    static func get(uid: String) -> PatchMeta? { all()[uid] }

    static func lookup(localName: String) -> PatchMeta? {
        let dict = all()
        if let uid = LocalMapStore.uid(forLocal: localName), let m = dict[uid] {
            return m
        }
        for m in dict.values where m.remoteName == localName { return m }
        let base = (localName as NSString).deletingPathExtension.lowercased()
        for m in dict.values {
            let rbase = (m.remoteName as NSString).deletingPathExtension.lowercased()
            if !rbase.isEmpty && rbase == base { return m }
        }
        return nil
    }
}

enum LocalMapStore {
    private static let key = "patch_localmap_v21"
    static func all() -> [String: String] {
        (UserDefaults.standard.dictionary(forKey: key) as? [String: String]) ?? [:]
    }
    static func save(_ d: [String: String]) {
        UserDefaults.standard.set(d, forKey: key)
    }
    static func link(local: String, uid: String) {
        var d = all()
        d[local] = uid
        save(d)
    }
    static func uid(forLocal local: String) -> String? { all()[local] }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - COMPONENTS
// ═══════════════════════════════════════════════════════════════
private struct TagPill: View {
    let tag: String
    private var isVIP: Bool { tag == "VIP" }
    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: isVIP ? "crown.fill" : "shield.fill")
                .font(.system(size: 7, weight: .heavy))
            Text(tag)
                .font(.system(size: 8.5, weight: .heavy))
                .tracking(0.8)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .foregroundStyle(isVIP ? Theme.gold : .white.opacity(0.85))
        .background(
            Capsule().fill(isVIP ? Theme.gold.opacity(0.14)
                                 : Color.white.opacity(0.06))
        )
        .overlay(
            Capsule().strokeBorder(
                isVIP ? Theme.gold.opacity(0.8) : Color.white.opacity(0.35),
                lineWidth: 1
            )
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
                    .fill(isOn ? Color.white : Color.white.opacity(0.08))
                    .frame(width: 50, height: 28)
                    .overlay(
                        Capsule().strokeBorder(
                            isOn ? .white : Color.white.opacity(0.4),
                            lineWidth: 1.3
                        )
                    )
                HStack {
                    if isOn {
                        Spacer()
                        Circle().fill(.black)
                            .frame(width: 20, height: 20)
                            .padding(.trailing, 4)
                    } else {
                        Circle().fill(.white)
                            .frame(width: 20, height: 20)
                            .padding(.leading, 4)
                        Spacer()
                    }
                }
                .frame(width: 50, height: 28)
            }
            .animation(.spring(response: 0.25, dampingFraction: 0.75), value: isOn)
            .opacity(disabled ? 0.5 : 1)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }
}

private struct SearchBar: View {
    @Binding var text: String
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white.opacity(0.4))
            ZStack(alignment: .leading) {
                if text.isEmpty {
                    Text("Tìm patch...")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.35))
                }
                TextField("", text: $text)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            if !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.35))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(.white.opacity(0.18), lineWidth: 1)
        )
    }
}

private struct FolderChip: View {
    let title: String
    let count: Int
    let isActive: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 11.5, weight: .heavy))
                    .tracking(0.6)
                    .lineLimit(1)
                Text("\(count)")
                    .font(.system(size: 9, weight: .heavy))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(
                        Capsule().fill(
                            isActive ? Color.black.opacity(0.15)
                                     : Color.white.opacity(0.1)
                        )
                    )
            }
            .foregroundStyle(isActive ? .black : .white.opacity(0.85))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule().fill(isActive ? Color.white : Color.white.opacity(0.04))
            )
            .overlay(
                Capsule().strokeBorder(
                    isActive ? .white : Color.white.opacity(0.22),
                    lineWidth: 1.2
                )
            )
        }
        .buttonStyle(.plain)
    }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - PATCH ROW (đơn giản, sạch)
// ═══════════════════════════════════════════════════════════════
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

    private var isVIP: Bool { tag == "VIP" }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 11) {
                iconBox

                VStack(alignment: .leading, spacing: 3) {
                    Text(displayName)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Button(action: onTapTag) {
                        TagPill(tag: tag)
                    }
                    .buttonStyle(.plain)
                }

                Spacer(minLength: 4)

                if isWorking {
                    ProgressView().tint(.white).scaleEffect(0.75)
                        .frame(width: 50, height: 28)
                } else {
                    CustomToggle(isOn: isApplied, disabled: false) { nv in
                        onToggle(nv)
                    }
                }
            }

            if !note.isEmpty {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "note.text")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white.opacity(0.4))
                        .padding(.top, 2)
                    Text(note)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.65))
                        .multilineTextAlignment(.leading)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(Color.white.opacity(0.03))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .strokeBorder(.white.opacity(0.12), lineWidth: 1)
                )
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(isApplied ? Color.white.opacity(0.07)
                                : Color.white.opacity(0.025))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(
                    isApplied ? Color.white : Color.white.opacity(0.2),
                    lineWidth: isApplied ? 1.6 : 1
                )
        )
        .contextMenu {
            Button(action: onRename) {
                Label("Đổi tên", systemImage: "pencil")
            }
            Button(action: onTapTag) {
                Label("Đổi VIP/FREE", systemImage: "crown")
            }
            Button(action: onEditNote) {
                Label("Sửa ghi chú", systemImage: "note.text")
            }
        }
    }

    private var iconBox: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(isVIP ? Theme.gold.opacity(0.14)
                            : Color.white.opacity(0.06))
                .frame(width: 42, height: 42)
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .strokeBorder(
                    isVIP ? Theme.gold.opacity(0.85)
                          : Color.white.opacity(0.35),
                    lineWidth: 1.2
                )
                .frame(width: 42, height: 42)
            Image(systemName: isVIP ? "crown.fill"
                                    : "shield.lefthalf.filled")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(isVIP ? Theme.gold : .white)
        }
    }
}

private struct EmptyStateView: View {
    let message: String
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "tray")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(.white.opacity(0.3))
            Text(message)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .padding(.top, 70)
        .frame(maxWidth: .infinity)
    }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - ACTIVATION SHEET (chỉ khi lỗi hoặc có note)
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

                    // Icon
                    ZStack {
                        Circle()
                            .fill(accent)
                            .frame(width: 78, height: 78)
                            .shadow(color: accent.opacity(0.55), radius: 22)
                        Image(systemName: isError
                              ? "exclamationmark.triangle.fill"
                              : "checkmark")
                            .font(.system(size: 32, weight: .heavy))
                            .foregroundStyle(isError ? .white : .black)
                    }

                    // Title
                    VStack(spacing: 8) {
                        Text("HEADLOCK ZENIS")
                            .font(.system(size: 10, weight: .heavy))
                            .tracking(4)
                            .foregroundStyle(.white.opacity(0.5))

                        Text(isError ? "KHÔNG KÍCH HOẠT ĐƯỢC"
                                     : "KÍCH HOẠT THÀNH CÔNG")
                            .font(.system(size: 15, weight: .heavy))
                            .tracking(1.5)
                            .foregroundStyle(isError ? accent : .white.opacity(0.9))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)

                        Text(info.patchName)
                            .font(.system(size: 18, weight: .heavy))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                            .padding(.top, 4)

                        if !info.tag.isEmpty {
                            TagPill(tag: info.tag)
                                .padding(.top, 2)
                        }
                    }

                    // Error reason
                    if isError,
                       let err = info.errorMessage,
                       !err.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("LÝ DO")
                                .font(.system(size: 10, weight: .heavy))
                                .tracking(2)
                                .foregroundStyle(accent)
                            Text(err)
                                .font(.system(size: 12.5, weight: .medium))
                                .foregroundStyle(.white.opacity(0.9))
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(accent.opacity(0.08))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(accent.opacity(0.5), lineWidth: 1.2)
                        )
                        .padding(.horizontal, 22)
                    }

                    // Note + copy
                    if hasNote {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 6) {
                                Image(systemName: "note.text")
                                    .font(.system(size: 11, weight: .bold))
                                Text("GHI CHÚ")
                                    .font(.system(size: 10, weight: .heavy))
                                    .tracking(2)
                                Spacer()
                            }
                            .foregroundStyle(.white)

                            Text(info.note)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.white.opacity(0.95))
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 10,
                                                     style: .continuous)
                                        .fill(Color.white.opacity(0.05))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10,
                                                     style: .continuous)
                                        .strokeBorder(.white.opacity(0.15),
                                                      lineWidth: 1)
                                )

                            Button {
                                SoundFX.tap()
                                UIPasteboard.general.string = info.note
                                withAnimation(.spring(response: 0.3,
                                                     dampingFraction: 0.75)) {
                                    copied = true
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                    withAnimation(.spring(response: 0.3,
                                                         dampingFraction: 0.75)) {
                                        copied = false
                                    }
                                }
                            } label: {
                                HStack(spacing: 7) {
                                    Image(systemName: copied
                                          ? "checkmark"
                                          : "doc.on.doc.fill")
                                        .font(.system(size: 11, weight: .heavy))
                                    Text(copied ? "ĐÃ COPY"
                                                : "COPY GHI CHÚ")
                                        .font(.system(size: 11, weight: .heavy))
                                        .tracking(1.5)
                                }
                                .foregroundStyle(copied ? .black : .white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 11,
                                                     style: .continuous)
                                        .fill(copied ? Color.white
                                                     : Color.white.opacity(0.06))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 11,
                                                     style: .continuous)
                                        .strokeBorder(.white, lineWidth: 1.3)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Theme.surface)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(.white.opacity(0.85), lineWidth: 1.2)
                        )
                        .padding(.horizontal, 22)
                    }

                    // Close
                    Button {
                        SoundFX.tap()
                        onDismiss()
                    } label: {
                        Text("ĐÃ HIỂU")
                            .font(.system(size: 13, weight: .heavy))
                            .tracking(2.5)
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(
                                RoundedRectangle(cornerRadius: 13,
                                                 style: .continuous)
                                    .fill(.white)
                            )
                            .padding(.horizontal, 40)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 6)
                    .padding(.bottom, 40)
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
    @State private var isSyncing = false
    @State private var lastSyncDate: Date = .distantPast
    @State private var syncGuard = false

    private let autoTimer = Timer.publish(every: 10, on: .main,
                                          in: .common).autoconnect()

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
                    homeHeader
                    homeContent
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                store.reload()
                triggerSync(force: true)
            }
            .onReceive(autoTimer) { _ in
                if Date().timeIntervalSince(lastSyncDate) > 20 {
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

    // ─── HOME HEADER ───
    private var homeHeader: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                syncPill
            }
            .padding(.horizontal, 18)
            .padding(.top, 12)

            VStack(spacing: 6) {
                Text("HEADLOCK ZENIS")
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .tracking(2)
                    .foregroundStyle(.white)

                Rectangle()
                    .fill(.white.opacity(0.5))
                    .frame(width: 40, height: 1)

                Text("BY ZENITH SOLITUDE")
                    .font(.system(size: 9, weight: .heavy))
                    .tracking(3.5)
                    .foregroundStyle(.white.opacity(0.45))
            }
            .padding(.top, 10)
            .padding(.bottom, 24)
        }
    }

    private var syncPill: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(isSyncing ? Color.yellow : Color.green)
                .frame(width: 7, height: 7)
                .shadow(color: (isSyncing ? Color.yellow : Color.green)
                    .opacity(0.9), radius: 5)
            Text(isSyncing ? "ĐANG CẬP NHẬT" : "ĐÃ KẾT NỐI")
                .font(.system(size: 9, weight: .heavy))
                .tracking(1.4)
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Capsule().fill(Color.white.opacity(0.04)))
        .overlay(Capsule().strokeBorder(.white.opacity(0.2), lineWidth: 1))
        .animation(.easeInOut(duration: 0.25), value: isSyncing)
    }

    private var homeContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 12) {
                gameCard(
                    title: "Free Fire Max",
                    subtitle: "PREMIUM EDITION",
                    prefix: "ffmax",
                    count: countFor(prefix: "ffmax")
                ) {
                    SoundFX.menu()
                    selectedGame = GameSelection(
                        title: "Free Fire Max", prefix: "ffmax"
                    )
                }

                gameCard(
                    title: "Free Fire Thường",
                    subtitle: "CLASSIC EDITION",
                    prefix: "ffnormal",
                    count: countFor(prefix: "ffnormal")
                ) {
                    SoundFX.menu()
                    selectedGame = GameSelection(
                        title: "Free Fire Thường", prefix: "ffnormal"
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 50)
        }
        .refreshable { triggerSync(force: true) }
    }

    private func gameCard(title: String,
                          subtitle: String,
                          prefix: String,
                          count: Int,
                          action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                AsyncImage(url: URL(string:
                    "https://solitudepremium.click/ipa/ipa/free.jpg")) { phase in
                    switch phase {
                    case .empty:
                        ZStack {
                            RoundedRectangle(cornerRadius: 12,
                                             style: .continuous)
                                .fill(Theme.surfaceHi)
                            ProgressView().tint(.white)
                        }
                    case .success(let img):
                        img.resizable().scaledToFill()
                            .clipShape(RoundedRectangle(cornerRadius: 12,
                                                        style: .continuous))
                    case .failure:
                        ZStack {
                            RoundedRectangle(cornerRadius: 12,
                                             style: .continuous)
                                .fill(Theme.surfaceHi)
                            Image(systemName: "flame.fill")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    @unknown default:
                        EmptyView()
                    }
                }
                .frame(width: 52, height: 52)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(.white.opacity(0.9), lineWidth: 1.3)
                )

                VStack(alignment: .leading, spacing: 5) {
                    Text(title)
                        .font(.system(size: 16, weight: .heavy))
                        .foregroundStyle(.white)
                    Text(subtitle)
                        .font(.system(size: 9, weight: .heavy))
                        .tracking(2)
                        .foregroundStyle(.white.opacity(0.4))
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(count)")
                        .font(.system(size: 22, weight: .black))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                    Text("PATCH")
                        .font(.system(size: 8, weight: .heavy))
                        .tracking(1.5)
                        .foregroundStyle(.white.opacity(0.4))
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 15)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.05),
                                     Color.white.opacity(0.015)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [.white, .white.opacity(0.35), .white],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.3
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func countFor(prefix: String) -> Int {
        store.items.filter { item in
            Self.gameTypeOf(item: item) == prefix
        }.count
    }

    // ⭐ Xác định game type — ưu tiên meta, fallback filename/path
    static func gameTypeOf(item: PatchLibraryItem) -> String {
        let name = item.packageURL.lastPathComponent
        if let m = PatchMetaStore.lookup(localName: name),
           !m.gameType.isEmpty {
            if m.orphaned { return "" }
            return m.gameType
        }
        // Fallback from filename
        if name.hasPrefix("ffmax_") { return "ffmax" }
        if name.hasPrefix("ffnormal_") { return "ffnormal" }
        // Fallback from path
        let comps = item.packageURL.pathComponents
        if comps.contains("ffmax") { return "ffmax" }
        if comps.contains("ffnormal") { return "ffnormal" }
        return "ffnormal"
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
// MARK: - SYNC ENGINE (giảm lag: poll 500ms, reload mỗi 3 poll)
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

        var remoteByUID: [String: RemoteFileLite] = [:]
        remoteByUID.reserveCapacity(remotes.count)
        for r in remotes { remoteByUID[r.uid] = r }

        var metaDict = PatchMetaStore.all()
        for (uid, var meta) in metaDict {
            if let remote = remoteByUID[uid] {
                meta.orphaned   = false
                meta.remoteKey  = remote.compositeKey
                meta.remoteName = remote.filename
                meta.gameType   = remote.gameType
                meta.folder     = remote.folder
                if !meta.tagOverride  { meta.tag         = remote.tag }
                if !meta.nameOverride { meta.displayName = remote.displayName }
                if !meta.noteOverride { meta.note        = remote.note }
            } else {
                meta.orphaned = true
            }
            metaDict[uid] = meta
        }
        PatchMetaStore.save(metaDict)

        await MainActor.run { store.reload() }

        let missing = remotes.filter { metaDict[$0.uid] == nil }
        guard !missing.isEmpty else { return }

        // Tải song song giới hạn 3 luồng — vừa nhanh vừa không nghẽn UI
        await withTaskGroup(of: Void.self) { group in
            var iterator = missing.makeIterator()
            var inFlight = 0
            let maxParallel = 3

            while inFlight < maxParallel, let next = iterator.next() {
                group.addTask { [weak self] in
                    await self?.importOne(remote: next, store: store)
                }
                inFlight += 1
            }

            for await _ in group {
                if let next = iterator.next() {
                    group.addTask { [weak self] in
                        await self?.importOne(remote: next, store: store)
                    }
                }
            }
        }

        await MainActor.run { store.reload() }
    }

    private func importOne(remote: RemoteFileLite,
                           store: PatchProjectStore) async {
        guard let url = URL(string: remote.url) else { return }

        let before = await MainActor.run {
            Set(store.items.map { $0.packageURL.lastPathComponent })
        }

        await MainActor.run {
            store.importPackage(from: .remote(url))
        }

        // ⭐ Poll 500ms, reload store mỗi 3 vòng (~1.5s) → giảm lag 5x
        for i in 0..<180 {
            try? await Task.sleep(nanoseconds: 500_000_000)

            // Chỉ reload store mỗi 3 vòng
            if i % 3 == 0 {
                await MainActor.run { store.reload() }
            }

            let after = await MainActor.run {
                Set(store.items.map { $0.packageURL.lastPathComponent })
            }
            let newFiles = after.subtracting(before)

            guard let newFile = newFiles.first else { continue }

            lock.lock()
            LocalMapStore.link(local: newFile, uid: remote.uid)

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
            PatchMetaStore.set(meta, uid: remote.uid)
            lock.unlock()

            print("✅ \(remote.compositeKey) → local:\(newFile)")
            return
        }

        print("⚠️ Timeout: \(remote.compositeKey)")
    }

    private func fetchRemotes() async -> [RemoteFileLite]? {
        let ts = Int(Date().timeIntervalSince1970)
        guard let url = URL(
            string: "https://solitudepremium.click/ipa/ipa/list.php?t=\(ts)"
        ) else { return nil }

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
                print("Fetch \(attempt) failed: \(error.localizedDescription)")
                if attempt == 0 {
                    try? await Task.sleep(nanoseconds: 500_000_000)
                }
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
    @State private var searchText: String = ""
    @State private var refreshTick: Int = 0
    @State private var didInitialSync = false

    // ⭐ 10s thay vì 5s → ít lag hơn
    private let refreshTimer = Timer.publish(every: 10, on: .main,
                                             in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            ZStack {
                NeonBackgroundView()
                VStack(spacing: 0) {
                    detailTopBar
                    searchBarRow
                    folderChips
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
                        refreshTick &+= 1
                        syncFolders()
                    }
                }
            }
            .onChange(of: scenePhase) { phase in
                if phase == .active {
                    Task {
                        await SyncEngine.shared.run(store: store)
                        await MainActor.run {
                            store.reload()
                            refreshTick &+= 1
                            syncFolders()
                        }
                    }
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
            .confirmationDialog("Chọn tag",
                                isPresented: tagBinding,
                                titleVisibility: .visible) {
                Button("VIP 👑") { commitTag("VIP") }
                Button("FREE 🛡") { commitTag("FREE") }
                Button("Huỷ", role: .cancel) { tagPickerItem = nil }
            }
            .fullScreenCover(item: $activationInfo) { info in
                ActivationNoteSheet(info: info) { activationInfo = nil }
            }
        }
    }

    // ─── TOP BAR ───
    private var detailTopBar: some View {
        HStack(spacing: 12) {
            Button {
                SoundFX.tap()
                dismiss()
            } label: {
                ZStack {
                    Circle().fill(Color.white.opacity(0.05))
                        .frame(width: 38, height: 38)
                        .overlay(Circle().strokeBorder(.white.opacity(0.85),
                                                       lineWidth: 1.2))
                    Image(systemName: "arrow.left")
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundStyle(.white)
                }
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(game.title)
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundStyle(.white)
                Text("\(displayedItems.count) PATCH · \(folders.count) FOLDER")
                    .font(.system(size: 9, weight: .heavy))
                    .tracking(1.2)
                    .foregroundStyle(.white.opacity(0.45))
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 12)
    }

    private var searchBarRow: some View {
        SearchBar(text: $searchText)
            .padding(.horizontal, 16)
            .padding(.bottom, 10)
    }

    @ViewBuilder
    private var folderChips: some View {
        if folders.count > 1 {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(folders, id: \.self) { f in
                        FolderChip(
                            title: f,
                            count: gameItems.filter { folderName(for: $0) == f }.count,
                            isActive: selectedFolder == f
                        ) {
                            SoundFX.tap()
                            withAnimation(.spring(response: 0.3,
                                                 dampingFraction: 0.75)) {
                                selectedFolder = f
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.bottom, 12)
        }
    }

    private func syncFolders() {
        let currentFolders = folders
        if currentFolders.isEmpty { selectedFolder = nil; return }
        if let sel = selectedFolder, currentFolders.contains(sel) { return }
        selectedFolder = currentFolders.first
    }

    // ⭐ FILTER ITEM — fallback filename/path khi meta thiếu
    private var gameItems: [PatchLibraryItem] {
        _ = refreshTick
        return store.items.filter { item in
            PatchProjectsView.gameTypeOf(item: item) == game.prefix
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
        var base: [PatchLibraryItem]
        if folders.count <= 1 {
            base = gameItems
        } else if let sel = selectedFolder {
            base = gameItems.filter { folderName(for: $0) == sel }
        } else {
            base = gameItems
        }

        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard !q.isEmpty else { return base }
        return base.filter { item in
            let dn = displayName(for: item).lowercased()
            let nt = currentNote(for: item).lowercased()
            let tg = currentTag(for: item).lowercased()
            let fn = item.packageURL.lastPathComponent.lowercased()
            return dn.contains(q) || nt.contains(q)
                || tg.contains(q) || fn.contains(q)
        }
    }

    private var renameBinding: Binding<Bool> {
        Binding(get: { renameItem != nil },
                set: { if !$0 { renameItem = nil } })
    }
    private var tagBinding: Binding<Bool> {
        Binding(get: { tagPickerItem != nil },
                set: { if !$0 { tagPickerItem = nil } })
    }
    private var noteBinding: Binding<Bool> {
        Binding(get: { noteItem != nil },
                set: { if !$0 { noteItem = nil } })
    }

    private var listContent: some View {
        ScrollView(showsIndicators: false) {
            if displayedItems.isEmpty {
                EmptyStateView(
                    message: folders.isEmpty
                        ? "Chưa có folder nào.\nĐang đồng bộ dữ liệu từ server..."
                        : (searchText.isEmpty
                           ? "Folder này chưa có patch nào."
                           : "Không tìm thấy patch phù hợp.")
                )
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(displayedItems) { item in
                        patchRowView(item: item)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 40)
            }
        }
    }

    private func patchRowView(item: PatchLibraryItem) -> some View {
        let receipt = DevicePatchService.latestReceipt(projectID: item.id)
        let isApplied = (receipt != nil)
        let name = displayName(for: item)
        return PatchRow(
            isApplied: isApplied,
            isWorking: workingFileID == item.id.uuidString,
            displayName: name,
            tag: currentTag(for: item),
            note: currentNote(for: item),
            onToggle: { nv in
                if nv { SoundFX.tingTing() } else { SoundFX.tap() }
                togglePatch(item: item, activate: nv)
            },
            onTapTag: { SoundFX.tap(); tagPickerItem = item },
            onRename: {
                SoundFX.tap()
                renameItem = item
                renameText = name
            },
            onEditNote: {
                SoundFX.tap()
                noteItem = item
                noteText = currentNote(for: item)
            }
        )
    }

    private func localKey(for item: PatchLibraryItem) -> String {
        item.packageURL.lastPathComponent
    }

    private func meta(for item: PatchLibraryItem) -> PatchMeta? {
        PatchMetaStore.lookup(localName: localKey(for: item))
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
        if let range = fname.range(of: #"^ZENITH_([a-zA-Z0-9]+)_"#,
                                    options: .regularExpression) {
            let matched = String(fname[range])
                .replacingOccurrences(of: "ZENITH_", with: "")
                .trimmingCharacters(in: CharacterSet(charactersIn: "_"))
            if !matched.isEmpty { return matched.uppercased() }
        }

        let comps = item.packageURL.pathComponents.filter { $0 != "/" }
        if let idx = comps.firstIndex(where: {
            $0 == "ffmax" || $0 == "ffnormal"
        }), idx + 1 < comps.count {
            return comps[idx + 1]
        }

        return "CHƯA PHÂN LOẠI"
    }

    private func commitRename() {
        guard let item = renameItem else { return }
        let t = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { renameItem = nil; return }
        let localName = localKey(for: item)
        guard let uid = LocalMapStore.uid(forLocal: localName),
              var m = PatchMetaStore.get(uid: uid) else {
            renameItem = nil; return
        }
        m.displayName = t
        m.nameOverride = true
        PatchMetaStore.set(m, uid: uid)
        store.reload()
        renameItem = nil
    }

    private func commitTag(_ tag: String) {
        guard let item = tagPickerItem else { return }
        let localName = localKey(for: item)
        guard let uid = LocalMapStore.uid(forLocal: localName),
              var m = PatchMetaStore.get(uid: uid) else {
            tagPickerItem = nil; return
        }
        m.tag = tag
        m.tagOverride = true
        PatchMetaStore.set(m, uid: uid)
        store.reload()
        tagPickerItem = nil
    }

    private func commitNote() {
        guard let item = noteItem else { return }
        let t = noteText.trimmingCharacters(in: .whitespacesAndNewlines)
        let localName = localKey(for: item)
        guard let uid = LocalMapStore.uid(forLocal: localName),
              var m = PatchMetaStore.get(uid: uid) else {
            noteItem = nil; return
        }
        m.note = t
        m.noteOverride = true
        PatchMetaStore.set(m, uid: uid)
        store.reload()
        noteItem = nil
    }

    // ⭐ Toggle — KHÔNG hiện alert "đã đặt gói"
    private func togglePatch(item: PatchLibraryItem, activate: Bool) {
        workingFileID = item.id.uuidString
        let nameSnap = displayName(for: item)
        let tagSnap = currentTag(for: item)
        let noteSnap = currentNote(for: item)

        Task.detached(priority: .userInitiated) {
            if !activate {
                do {
                    if let r = DevicePatchService.latestReceipt(
                        projectID: item.id
                    ) {
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
                            patchName: nameSnap,
                            tag: tagSnap,
                            note: noteSnap,
                            success: false,
                            errorMessage: "Không thể tắt: \(error.localizedDescription)"
                        )
                    }
                }
                return
            }

            do {
                guard let p = item.project else {
                    print("❌ project nil: \(item.packageURL)")
                    await MainActor.run { workingFileID = nil }
                    return
                }
                _ = try DevicePatchService.apply(project: p)

                // ⭐ THÀNH CÔNG: không alert, chỉ sheet khi có note
                await MainActor.run {
                    store.reload()
                    workingFileID = nil
                    SoundFX.success()

                    if !noteSnap.trimmingCharacters(in: .whitespaces).isEmpty {
                        activationInfo = ActivationInfo(
                            patchName: nameSnap,
                            tag: tagSnap,
                            note: noteSnap,
                            success: true,
                            errorMessage: nil
                        )
                    }
                }
            } catch {
                await MainActor.run {
                    store.reload()
                    workingFileID = nil
                    SoundFX.error()
                    activationInfo = ActivationInfo(
                        patchName: nameSnap,
                        tag: tagSnap,
                        note: noteSnap,
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
                        .onChange(of: password) { _ in
                            store.clearUnlockError()
                        }
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
        if let a = store.unlockErrorArgument {
            return language.text(key, a)
        }
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
            .sheet(item: $store.passwordRequest,
                   onDismiss: store.cancelUnlock) { request in
                PatchUnlockView(store: store, request: request)
            }
    }
}

extension View {
    func patchStorePresentation(_ store: PatchProjectStore) -> some View {
        modifier(PatchStorePresentationModifier(store: store))
    }
}
