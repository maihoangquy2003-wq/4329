import SwiftUI
import UIKit
import UniformTypeIdentifiers
import AudioToolbox

// MARK: - API Manager
class RemoteAPIManager {
    static let shared = RemoteAPIManager()
    private let baseURL = "https://solitudepremium.click/ipa/proxy"
    private let fileManager = FileManager.default
    
    private init() {}
    
    func fetchRemoteItems() async throws -> [RemoteAimItem] {
        guard let url = URL(string: "\(baseURL)/apiaim.php") else { throw APIError.invalidURL }
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else { throw APIError.serverError }
        do {
            return try JSONDecoder().decode([RemoteAimItem].self, from: data)
        } catch {
            throw APIError.decodingError
        }
    }
    
    func downloadAndSaveFile(from remoteURL: String, itemID: String) async throws -> URL {
        guard let url = URL(string: remoteURL) else { throw APIError.invalidURL }
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let itemFolderURL = documentsURL.appendingPathComponent("PatchFiles/\(itemID)", isDirectory: true)
        if !fileManager.fileExists(atPath: itemFolderURL.path) {
            try fileManager.createDirectory(at: itemFolderURL, withIntermediateDirectories: true)
        }
        let fileName = "\(itemID)_\(Date().timeIntervalSince1970).3105"
        let destinationURL = itemFolderURL.appendingPathComponent(fileName)
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else { throw APIError.serverError }
        try data.write(to: destinationURL)
        return destinationURL
    }
    
    func removeAllFiles(for itemID: String) {
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let itemFolderURL = documentsURL.appendingPathComponent("PatchFiles/\(itemID)", isDirectory: true)
        try? fileManager.removeItem(at: itemFolderURL)
    }
}

enum APIError: Error {
    case invalidURL
    case serverError
    case decodingError
}

// MARK: - Main View
struct PatchProjectsView: View {
    @Environment(\.appLanguage) private var language
    @EnvironmentObject private var store: PatchProjectStore
    
    let onOpenSettings: () -> Void
    let onOpenLogs: () -> Void
    
    @State private var showModMenu = false
    @AppStorage("selected_game_bundle") private var selectedGameBundle: String = "com.dts.freefiremax"
    @State private var remoteItems: [RemoteAimItem] = []
    @State private var selectedTab: String = ""
    @State private var isFetching = false
    @State private var avatarRotation: Double = 0.0
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            NeonParticleBackgroundView()
            
            if !showModMenu {
                homeScreen.transition(.opacity.combined(with: .scale(scale: 0.95)))
            } else {
                modMenuScreen.transition(.move(edge: .trailing))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: showModMenu)
        .onAppear {
            Task { await fetchRemoteData() }
            withAnimation(.linear(duration: 6).repeatForever(autoreverses: false)) {
                avatarRotation = 360
            }
        }
    }
    
    private var homeScreen: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 30)
            ScrollView(showsIndicators: false) {
                VStack(spacing: 30) {
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .stroke(AngularGradient(gradient: Gradient(colors: [.white, .gray, .black, .white]), center: .center), lineWidth: 3)
                                .frame(width: 104, height: 104)
                                .rotationEffect(.degrees(avatarRotation))
                                .shadow(color: .white.opacity(0.5), radius: 10)
                            AsyncImage(url: URL(string: "https://solitudepremium.click/ipa/proxy/li.jpg")) { phase in
                                if let image = phase.image { image.resizable().scaledToFill() }
                                else { Image(systemName: "person.circle.fill").resizable().foregroundColor(.white) }
                            }
                            .frame(width: 90, height: 90)
                            .clipShape(Circle())
                        }
                        Text("Zenith Solitude")
                            .font(.system(size: 24, weight: .black, design: .monospaced))
                            .foregroundColor(.white)
                            .shadow(color: .white.opacity(0.7), radius: 6)
                        HStack(spacing: 10) {
                            Rectangle().fill(LinearGradient(colors: [.clear, .white], startPoint: .leading, endPoint: .trailing)).frame(width: 30, height: 1)
                            Text("HEADLOCK ZENIS")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(.white.opacity(0.8))
                            Rectangle().fill(LinearGradient(colors: [.white, .clear], startPoint: .leading, endPoint: .trailing)).frame(width: 30, height: 1)
                        }
                    }
                    VStack(spacing: 16) {
                        homeGameCard(title: "Free Fire Max", icon: "https://solitudepremium.click/ipa/proxy/free.jpg", bundle: "com.dts.freefiremax")
                        homeGameCard(title: "Free Fire Thường", icon: "https://solitudepremium.click/ipa/proxy/free.jpg", bundle: "com.dts.freefireth")
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.bottom, 40)
            }
        }
    }
    
    private func homeGameCard(title: String, icon: String, bundle: String) -> some View {
        Button(action: {
            AudioServicesPlaySystemSound(1306)
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            selectedGameBundle = bundle
            if !dynamicTabs.contains(selectedTab), let first = dynamicTabs.first {
                selectedTab = first
            }
            withAnimation { showModMenu = true }
        }) {
            HStack(spacing: 16) {
                AsyncImage(url: URL(string: icon)) { phase in
                    if let image = phase.image { image.resizable().scaledToFill() }
                    else { Image(systemName: "gamecontroller.fill").foregroundColor(.white) }
                }
                .frame(width: 52, height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.3), lineWidth: 1))
                VStack(alignment: .leading, spacing: 5) {
                    Text(title)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)
                    Text("Hệ thống sẵn sàng")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.white.opacity(0.5))
                }
                Spacer()
                HStack(spacing: 6) {
                    Text("MỞ MENU")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundColor(.black)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.white)
                .cornerRadius(16)
                .shadow(color: .white.opacity(0.3), radius: 6)
            }
            .padding(16)
            .background(Color.black)
            .cornerRadius(20)
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.25), lineWidth: 1.5))
            .shadow(color: .white.opacity(0.1), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(NeonScaleButtonStyle())
    }
    
    private var modMenuScreen: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button(action: {
                    AudioServicesPlaySystemSound(1306)
                    withAnimation { showModMenu = false }
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.black)
                        .frame(width: 40, height: 40)
                        .background(Color.white)
                        .clipShape(Circle())
                        .shadow(color: .white.opacity(0.4), radius: 4)
                }
                .buttonStyle(NeonScaleButtonStyle())
                Text(selectedGameBundle == "com.dts.freefiremax" ? "Free Fire Max" : "Free Fire Thường")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Button(action: {
                    Task { await fetchRemoteData() }
                }) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .padding(10)
                        .background(Circle().stroke(Color.white.opacity(0.4), lineWidth: 1.5))
                }
                .disabled(isFetching)
                .buttonStyle(NeonScaleButtonStyle())
            }
            .padding(.horizontal, 20).padding(.top, 15)
            
            if !dynamicTabs.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(dynamicTabs, id: \.self) { tab in
                            let isSelected = selectedTab.lowercased() == tab.lowercased()
                            Button(action: {
                                AudioServicesPlaySystemSound(1306)
                                selectedTab = tab
                            }) {
                                Text(tab)
                                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                                    .padding(.horizontal, 20).padding(.vertical, 10)
                                    .background(isSelected ? Color.white : Color.black)
                                    .foregroundColor(isSelected ? .black : .white)
                                    .cornerRadius(20)
                                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(isSelected ? 1.0 : 0.3), lineWidth: 1.5))
                                    .shadow(color: isSelected ? .white.opacity(0.4) : .clear, radius: 6)
                            }
                            .buttonStyle(NeonScaleButtonStyle())
                        }
                    }
                    .padding(.horizontal, 20).padding(.vertical, 16)
                }
            }
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    let filtered = remoteItems.filter { $0.target == selectedGameBundle && $0.category.lowercased() == selectedTab.lowercased() }
                    if filtered.isEmpty {
                        VStack(spacing: 10) {
                            Image(systemName: "folder.badge.questionmark").font(.system(size: 40)).foregroundColor(.white.opacity(0.2))
                            Text("Chưa có tính năng nào trong mục này").font(.system(size: 12, design: .monospaced)).foregroundColor(.gray)
                        }.padding(.top, 100)
                    } else {
                        ForEach(filtered, id: \.id) { item in
                            ModFunctionRow(remoteItem: item, store: store)
                        }
                    }
                }
                .padding(.horizontal, 20).padding(.bottom, 40)
            }
            Spacer()
        }
    }
    
    private var dynamicTabs: [String] {
        var tabs: [String] = []
        for item in remoteItems where item.target == selectedGameBundle {
            if !tabs.contains(where: { $0.caseInsensitiveCompare(item.category) == .orderedSame }) {
                tabs.append(item.category)
            }
        }
        return tabs
    }
    
    @MainActor
    private func fetchRemoteData() async {
        guard !isFetching else { return }
        isFetching = true
        defer { isFetching = false }
        do {
            remoteItems = try await RemoteAPIManager.shared.fetchRemoteItems()
            if !dynamicTabs.contains(selectedTab), let first = dynamicTabs.first {
                selectedTab = first
            }
        } catch {
            print("Lỗi fetch remote data: \(error.localizedDescription)")
        }
    }
}

// MARK: - Mod Function Row
struct ModFunctionRow: View {
    let remoteItem: RemoteAimItem
    @ObservedObject var store: PatchProjectStore
    
    @State private var isApplied = false
    @State private var isWorking = false
    
    private var toggleStateKey: String { "isolated_toggle_\(remoteItem.id)_\(remoteItem.target)" }
    private var mappedUUIDKey: String { "isolated_uuid_\(remoteItem.id)_\(remoteItem.target)" }
    
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.1)).frame(width: 42, height: 42)
                Image(systemName: isApplied ? "checkmark.shield.fill" : "shield.fill")
                    .foregroundColor(isApplied ? .white : .gray)
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(remoteItem.name).font(.system(size: 15, weight: .bold)).foregroundColor(.white)
                    Text("VIP").font(.system(size: 8, weight: .bold)).padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.white).cornerRadius(4).foregroundColor(.black)
                }
                if let note = remoteItem.note, !note.isEmpty {
                    Text("📌 \(note)").font(.system(size: 10, design: .monospaced)).foregroundColor(.gray)
                }
            }
            Spacer()
            if isWorking {
                ProgressView().tint(.white).scaleEffect(0.7)
            } else {
                Toggle("", isOn: Binding(get: { isApplied }, set: { val in toggleIsolatedPatch(on: val) }))
                    .labelsHidden().tint(.white)
            }
        }
        .padding(14).background(Color.black).cornerRadius(18)
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(isApplied ? 0.6 : 0.2), lineWidth: isApplied ? 1.5 : 1))
        .onAppear {
            self.isApplied = UserDefaults.standard.bool(forKey: toggleStateKey)
        }
    }
    
    private func toggleIsolatedPatch(on: Bool) {
        guard !isWorking else { return }
        isWorking = true
        AudioServicesPlaySystemSound(1306)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        
        Task { @MainActor in
            defer { isWorking = false }
            do {
                if on {
                    try await applyPatch()
                } else {
                    try await removePatch()
                }
                UserDefaults.standard.set(on, forKey: toggleStateKey)
                self.isApplied = on
                AudioServicesPlaySystemSound(1407)
            } catch {
                print("Lỗi hệ thống patch: \(error.localizedDescription)")
                UserDefaults.standard.set(!on, forKey: toggleStateKey)
                self.isApplied = !on
                AudioServicesPlaySystemSound(1053)
            }
        }
    }
    
    @MainActor
    private func applyPatch() async throws {
        // KIỂM TRA BỘ NHỚ: Nếu Aim này ĐÃ TỪNG được import rồi thì tái sử dụng, KHÔNG import lại.
        if let uuidStr = UserDefaults.standard.string(forKey: mappedUUIDKey),
           let uuid = UUID(uuidString: uuidStr),
           let existingItem = store.items.first(where: { $0.id == uuid }) {
            
            // Tìm thấy bản cũ -> Apply trực tiếp luôn
            try await doApply(for: existingItem)
            return
        }
        
        // NẾU CHƯA CÓ TRONG BỘ NHỚ: Tải file mới và Import
        let fileURL = try await RemoteAPIManager.shared.downloadAndSaveFile(from: remoteItem.url, itemID: remoteItem.id)
        
        let beforeIds = Set(store.items.map { $0.id })
        store.importPackage(at: fileURL)
        try await Task.sleep(nanoseconds: 700_000_000)
        
        guard let freshItem = store.items.first(where: { !beforeIds.contains($0.id) }) else {
            throw NSError(domain: "ImportFailed", code: 0, userInfo: [NSLocalizedDescriptionKey: "Không thể nạp cấu hình file vào hệ thống."])
        }
        
        // Lưu lại UUID để lần sau Bật lại thì xài luôn
        UserDefaults.standard.set(freshItem.id.uuidString, forKey: mappedUUIDKey)
        
        // Apply
        try await doApply(for: freshItem)
    }
    
    @MainActor
    private func doApply(for item: PatchLibraryItem) async throws {
        let project: PatchProject
        if item.summary.schemaVersion >= 2 && item.canInspectContents {
            // Ép đồng bộ Workspace để lấy cấu trúc project mới
            project = try PatchProjectLibrary.synchronizeWorkspace(item: item)
        } else {
            guard let baseProject = item.project else {
                throw NSError(domain: "ProjectError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Không thể truy cập project."])
            }
            project = baseProject
        }
        _ = try DevicePatchService.apply(project: project)
    }
    
    @MainActor
    private func removePatch() async throws {
        // CHỈ Restore (gỡ tác dụng file) - TUYỆT ĐỐI KHÔNG XÓA FILE HAY XÓA UUID
        if let uuidStr = UserDefaults.standard.string(forKey: mappedUUIDKey),
           let uuid = UUID(uuidString: uuidStr),
           let targetItem = store.items.first(where: { $0.id == uuid }),
           let receipt = DevicePatchService.latestReceipt(projectID: targetItem.id) {
            
            try DevicePatchService.restore(receipt: receipt, allowChangedTargets: true)
        }
        
        // Chú ý: Đã xóa dòng gọi RemoteAPIManager.shared.removeAllFiles ở đây
        // Chú ý: Đã xóa dòng xóa mappedUUIDKey khỏi UserDefaults
    }
}

// MARK: - Remote Item Model
struct RemoteAimItem: Codable, Identifiable {
    let id: String
    let name: String
    let category: String
    let target: String
    let note: String?
    let url: String
}

// MARK: - Background View
struct NeonParticleBackgroundView: View {
    var body: some View {
        TimelineView(.animation) { context in
            Canvas { ctx, size in
                let time = context.date.timeIntervalSinceReferenceDate
                for i in 0..<60 {
                    let seed = Double(i) * 55.0
                    let x = (sin(time * 0.2 + seed) * 0.5 + 0.5) * size.width
                    let y = size.height - fmod(time * (50.0 + fmod(seed, 25.0)) + seed, size.height)
                    ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 2, height: 2)), with: .color(.white.opacity(0.35)))
                }
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Modifier
struct PatchStorePresentationModifier: ViewModifier {
    @ObservedObject var store: PatchProjectStore
    func body(content: Content) -> some View { content }
}
extension View {
    func patchStorePresentation(_ store: PatchProjectStore) -> some View {
        modifier(PatchStorePresentationModifier(store: store))
    }
}
