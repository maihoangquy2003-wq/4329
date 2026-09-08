import SwiftUI
import UIKit
import UniformTypeIdentifiers
import AudioToolbox

// MARK: - 1. SMART REMOTE API MANAGER
class RemoteAPIManager {
    static let shared = RemoteAPIManager()
    
    private init() {}
    
    func fetchRemoteItems() async throws -> [RemoteAimItem] {
        let urlString = "https://solitudepremium.click/ipa/proxy/apiaim.php?action=list&t=\(Date().timeIntervalSince1970)"
        guard let url = URL(string: urlString) else { throw APIError.invalidURL }
        
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 15
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw APIError.serverError
        }
        return try JSONDecoder().decode([RemoteAimItem].self, from: data)
    }
    
    // Tải file về, sau đó can thiệp sửa đổi trực tiếp metadata bên trong ruột file để đổi ID và Tên nội bộ chống trùng
    func downloadAndMutateFile(remoteItem: RemoteAimItem, onLog: @escaping (String) -> Void) async throws -> URL {
        let urlString = "\(remoteItem.url)?action=download&id=\(remoteItem.id)&nocache=\(Date().timeIntervalSince1970)"
        onLog("🌐 [API URL]: \(urlString)")
        
        guard let url = URL(string: urlString) else { throw APIError.invalidURL }
        
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 30
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw APIError.serverError
        }
        
        // ĐẶC TRỊ TẬN GỐC: Can thiệp sửa đổi nội dung JSON bên trong ruột file .3105
        var finalData = data
        if var json = try? JSONSerialization.jsonObject(with: data, options: .mutableContainers) as? [String: Any] {
            // Ép đổi ID và Tên bên trong ruột thành ID thực tế của nút bạn đang bấm
            json["id"] = UUID().uuidString
            json["name"] = "\(remoteItem.name) [\(remoteItem.id)]"
            if let modifiedData = try? JSONSerialization.data(withJSONObject: json, options: []) {
                finalData = modifiedData
                onLog("✨ [MUTATE]: Đã bẻ khóa và đổi ID/Tên ruột file thành công.")
            }
        }
        
        let tempDir = FileManager.default.temporaryDirectory
        let uniqueFileName = "Zenith_Forced_\(remoteItem.id)_\(UUID().uuidString.prefix(4)).3105"
        let fileURL = tempDir.appendingPathComponent(uniqueFileName)
        
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try? FileManager.default.removeItem(at: fileURL)
        }
        try finalData.write(to: fileURL)
        onLog("📂 [LƯU TẠM]: \(uniqueFileName) (Size: \(finalData.count) bytes)")
        return fileURL
    }
}

enum APIError: Error { case invalidURL, serverError, decodingError }
struct RemoteAimItem: Codable, Identifiable { let id, name, category, target: String; let note: String?; let url: String }

// MARK: - 2. CYBERPUNK MAIN MENU
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
    
    @State private var debugLogs: [String] = ["🚀 Console Đã sẵn sàng..."]
    @State private var showDebugConsole = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            NeonParticleBackgroundView()
            if !showModMenu { homeScreen.transition(.opacity.combined(with: .scale(scale: 0.95))) } 
            else { modMenuScreen.transition(.move(edge: .trailing)) }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: showModMenu)
        .onAppear {
            Task { await fetchRemoteData() }
            withAnimation(.linear(duration: 6).repeatForever(autoreverses: false)) { avatarRotation = 360 }
        }
    }
    
    private var homeScreen: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button(action: { showDebugConsole.toggle() }) {
                    Image(systemName: "ladybug.fill").foregroundColor(.yellow).padding(10).background(Circle().stroke(Color.yellow.opacity(0.5), lineWidth: 1))
                }.padding(.trailing, 20).padding(.top, 10)
            }
            ScrollView(showsIndicators: false) {
                VStack(spacing: 30) {
                    VStack(spacing: 16) {
                        ZStack {
                            Circle().stroke(AngularGradient(gradient: Gradient(colors: [.white, .gray, .black, .white]), center: .center), lineWidth: 3)
                                .frame(width: 104, height: 104).rotationEffect(.degrees(avatarRotation)).shadow(color: .white.opacity(0.5), radius: 10)
                            AsyncImage(url: URL(string: "https://solitudepremium.click/ipa/proxy/li.jpg")) { phase in
                                if let image = phase.image { image.resizable().scaledToFill() } else { Image(systemName: "person.circle.fill").resizable().foregroundColor(.white) }
                            }.frame(width: 90, height: 90).clipShape(Circle())
                        }
                        Text("Zenith Solitude").font(.system(size: 24, weight: .black, design: .monospaced)).foregroundColor(.white).shadow(color: .white.opacity(0.7), radius: 6)
                    }
                    VStack(spacing: 16) {
                        homeGameCard(title: "Free Fire Max", icon: "https://solitudepremium.click/ipa/proxy/free.jpg", bundle: "com.dts.freefiremax")
                        homeGameCard(title: "Free Fire Thường", icon: "https://solitudepremium.click/ipa/proxy/free.jpg", bundle: "com.dts.freefireth")
                    }.padding(.horizontal, 20)
                    
                    if showDebugConsole {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("🛠 SIÊU LOG CONSOLE").font(.system(size: 11, weight: .bold, design: .monospaced)).foregroundColor(.yellow)
                                Spacer()
                                Button("Xóa") { debugLogs.removeAll() }.font(.caption2).foregroundColor(.gray)
                            }
                            ForEach(debugLogs.prefix(20), id: \.self) { log in
                                Text(log).font(.system(size: 8, design: .monospaced)).foregroundColor(log.contains("❌") ? .red : (log.contains("✅") ? .green : (log.contains("🚀") ? .yellow : .white)))
                            }
                        }.padding(14).background(Color.black.opacity(0.9)).cornerRadius(12).overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.yellow.opacity(0.4), lineWidth: 1)).padding(.horizontal, 20)
                    }
                }.padding(.bottom, 40)
            }
        }
    }
    
    private func homeGameCard(title: String, icon: String, bundle: String) -> some View {
        Button(action: {
            AudioServicesPlaySystemSound(1306); UIImpactFeedbackGenerator(style: .medium).impactOccurred(); selectedGameBundle = bundle
            if !dynamicTabs.contains(selectedTab), let first = dynamicTabs.first { selectedTab = first }
            withAnimation { showModMenu = true }
        }) {
            HStack(spacing: 16) {
                AsyncImage(url: URL(string: icon)) { phase in
                    if let image = phase.image { image.resizable().scaledToFill() } else { Image(systemName: "gamecontroller.fill").foregroundColor(.white) }
                }.frame(width: 52, height: 52).clipShape(RoundedRectangle(cornerRadius: 14)).overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.3), lineWidth: 1))
                VStack(alignment: .leading, spacing: 5) {
                    Text(title).font(.system(size: 17, weight: .bold)).foregroundColor(.white)
                    Text("Hệ thống sẵn sàng").font(.system(size: 11, design: .monospaced)).foregroundColor(.white.opacity(0.5))
                }
                Spacer()
                HStack(spacing: 6) { Text("MỞ MENU").font(.system(size: 11, weight: .black, design: .monospaced)); Image(systemName: "chevron.right").font(.system(size: 10, weight: .bold)) }
                .foregroundColor(.black).padding(.horizontal, 16).padding(.vertical, 12).background(Color.white).cornerRadius(16).shadow(color: .white.opacity(0.3), radius: 6)
            }.padding(16).background(Color.black).cornerRadius(20).overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.25), lineWidth: 1.5)).shadow(color: .white.opacity(0.1), radius: 8, x: 0, y: 4)
        }.buttonStyle(NeonScaleButtonStyle())
    }
    
    private var modMenuScreen: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button(action: { AudioServicesPlaySystemSound(1306); withAnimation { showModMenu = false } }) {
                    Image(systemName: "chevron.left").font(.system(size: 16, weight: .bold)).foregroundColor(.black).frame(width: 40, height: 40).background(Color.white).clipShape(Circle()).shadow(color: .white.opacity(0.4), radius: 4)
                }.buttonStyle(NeonScaleButtonStyle())
                Text(selectedGameBundle == "com.dts.freefiremax" ? "Free Fire Max" : "Free Fire Thường").font(.system(size: 18, weight: .bold)).foregroundColor(.white)
                Spacer()
                Button(action: { Task { await fetchRemoteData() } }) {
                    Image(systemName: "arrow.triangle.2.circlepath").font(.system(size: 14, weight: .bold)).foregroundColor(.white).padding(10).background(Circle().stroke(Color.white.opacity(0.4), lineWidth: 1.5))
                }.disabled(isFetching).buttonStyle(NeonScaleButtonStyle())
            }.padding(.horizontal, 20).padding(.top, 15)
            
            if !dynamicTabs.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(dynamicTabs, id: \.self) { tab in
                            let isSelected = selectedTab.lowercased() == tab.lowercased()
                            Button(action: { AudioServicesPlaySystemSound(1306); selectedTab = tab }) {
                                Text(tab).font(.system(size: 13, weight: .bold, design: .monospaced)).padding(.horizontal, 20).padding(.vertical, 10)
                                    .background(isSelected ? Color.white : Color.black).foregroundColor(isSelected ? .black : .white).cornerRadius(20)
                                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(isSelected ? 1.0 : 0.3), lineWidth: 1.5)).shadow(color: isSelected ? .white.opacity(0.4) : .clear, radius: 6)
                            }.buttonStyle(NeonScaleButtonStyle())
                        }
                    }.padding(.horizontal, 20).padding(.vertical, 16)
                }
            }
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    let filtered = remoteItems.filter { $0.target == selectedGameBundle && $0.category.lowercased() == selectedTab.lowercased() }
                    if filtered.isEmpty {
                        VStack(spacing: 10) { Image(systemName: "folder.badge.questionmark").font(.system(size: 40)).foregroundColor(.white.opacity(0.2)); Text("Chưa có tính năng nào trong mục này").font(.system(size: 12, design: .monospaced)).foregroundColor(.gray) }.padding(.top, 100)
                    } else {
                        ForEach(filtered, id: \.id) { item in 
                            CyberpunkToggleAimRow(remoteItem: item, store: store, onLog: { msg in appendLog(msg) }) 
                        }
                    }
                }.padding(.horizontal, 20).padding(.bottom, 40)
            }
            Spacer()
        }
    }
    
    private var dynamicTabs: [String] {
        var tabs: [String] = []
        for item in remoteItems where item.target == selectedGameBundle { if !tabs.contains(where: { $0.caseInsensitiveCompare(item.category) == .orderedSame }) { tabs.append(item.category) } }
        return tabs
    }
    
    @MainActor private func fetchRemoteData() async {
        guard !isFetching else { return }; isFetching = true; defer { isFetching = false }
        do {
            remoteItems = try await RemoteAPIManager.shared.fetchRemoteItems()
            if !dynamicTabs.contains(selectedTab), let first = dynamicTabs.first { selectedTab = first }
            appendLog("✅ [SYNC]: Tải danh sách thành công (\(remoteItems.count) mục).")
        } catch {
            appendLog("❌ [SYNC ERROR]: \(error.localizedDescription)")
        }
    }
    
    private func appendLog(_ text: String) {
        debugLogs.insert("[\(TimeFormatter.current())] \(text)", at: 0)
        if debugLogs.count > 50 { debugLogs.removeLast() }
    }
}

// MARK: - 3. SMART TOGGLE ROW (TIÊU DIỆT TẬN GỐC CACHE STORE)
struct CyberpunkToggleAimRow: View {
    let remoteItem: RemoteAimItem
    @ObservedObject var store: PatchProjectStore
    let onLog: (String) -> Void
    
    @State private var isWorking = false
    @AppStorage("ZENITH_ACTIVE_AIM") private var activeAimID: String = ""
    private var isApplied: Bool { return activeAimID == remoteItem.id }
    
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.1)).frame(width: 42, height: 42)
                Image(systemName: isApplied ? "checkmark.shield.fill" : "shield.fill").foregroundColor(isApplied ? .white : .gray)
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) { Text(remoteItem.name).font(.system(size: 15, weight: .bold)).foregroundColor(.white); Text("ID: \(remoteItem.id)").font(.system(size: 8, weight: .bold)).padding(.horizontal, 6).padding(.vertical, 2).background(Color.white).cornerRadius(4).foregroundColor(.black) }
                if let note = remoteItem.note, !note.isEmpty { Text("📌 \(note)").font(.system(size: 10, design: .monospaced)).foregroundColor(.gray) }
            }
            Spacer()
            if isWorking { ProgressView().tint(.white).scaleEffect(0.7) } 
            else { Toggle("", isOn: Binding(get: { isApplied }, set: { val in executeSmartAction(on: val) }))
                .labelsHidden()
                .tint(.white) }
        }.padding(14).background(Color.black).cornerRadius(18).overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(isApplied ? 0.6 : 0.2), lineWidth: isApplied ? 1.5 : 1))
    }
    
    // HÀM NUKE CHUYÊN SÂU: XÓA SẠCH MỌI DỮ LIỆU STORE VÀ INDEX NGẦM TRONG THƯ MỤC DOCUMENTS
    private func nukeStoreCache() async {
        let currentItems = await MainActor.run { store.items }
        for item in currentItems {
            if let receipt = DevicePatchService.latestReceipt(projectID: item.id) {
                try? DevicePatchService.restore(receipt: receipt, allowChangedTargets: true)
            }
        }
        
        await MainActor.run {
            let docsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            
            // Xóa sạch mọi file và thư mục con trong Documents để không còn file rác nào của Store sót lại
            let contents = (try? FileManager.default.contentsOfDirectory(at: docsURL, includingPropertiesForKeys: nil)) ?? []
            for url in contents {
                // Xóa cả file .3105 lẫn các thư mục index/workspaces ngầm của Store
                try? FileManager.default.removeItem(at: url)
                onLog("🗑️ [NUKE]: Đã xóa sạch -> \(url.lastPathComponent)")
            }
            
            store.reload()
            onLog("✨ [STORE ĐÃ ĐƯỢC LÀM TRỐNG TUYỆT ĐỐI]")
        }
    }
    
    private func executeSmartAction(on: Bool) {
        guard !isWorking else { return }; isWorking = true
        AudioServicesPlaySystemSound(1306); UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        
        Task.detached(priority: .userInitiated) {
            do {
                if on {
                    onLog("🚀 [BẬT MỚI]: \(remoteItem.name) [ID: \(remoteItem.id)]")
                    
                    // Bước 1: Nuke toàn bộ dữ liệu cũ của Store
                    await nukeStoreCache()
                    
                    // Bước 2: Tải file mới và sửa trực tiếp ruột file
                    let fileURL = try await RemoteAPIManager.shared.downloadAndMutateFile(remoteItem: remoteItem, onLog: onLog)
                    
                    // Bước 3: Import vào Store hoàn toàn trống
                    await MainActor.run {
                        store.importPackage(at: fileURL)
                        store.reload()
                        onLog("📥 [IMPORT OK]: Đã đưa file mới vào Store trống.")
                    }
                    
                    let updatedItems = await MainActor.run { store.items }
                    guard let targetItem = updatedItems.first else {
                        throw NSError(domain: "StoreError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Store trống, không nhận được file!"])
                    }
                    
                    var project: PatchProject
                    if targetItem.summary.schemaVersion >= 2 && targetItem.canInspectContents {
                        project = try PatchProjectLibrary.synchronizeWorkspace(item: targetItem)
                    } else {
                        guard let baseProject = targetItem.project else {
                            throw NSError(domain: "ProjectError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Không đọc được project."])
                        }
                        project = baseProject
                    }
                    
                    onLog("🔍 [RUỘT SAU KHI BẺ KHÓA]: Tên = '\(project.name)' | ID = \(project.id)")
                    
                    // Bước 4: Áp dụng bản vá
                    _ = try DevicePatchService.apply(project: project)
                    
                    await MainActor.run { activeAimID = remoteItem.id }
                    onLog("🎉 [KÍCH HOẠT THÀNH CÔNG]: \(remoteItem.name)")
                    
                } else {
                    onLog("🛑 [TẮT]: Đang tiến hành dọn dẹp hệ thống...")
                    await nukeStoreCache()
                    await MainActor.run { activeAimID = "" }
                    onLog("🔄 [ĐÃ TẮT VÀ DỌN SẠCH SẼ]")
                }
                
                await MainActor.run { store.reload(); isWorking = false; AudioServicesPlaySystemSound(1407) }
            } catch {
                await MainActor.run {
                    activeAimID = ""
                    isWorking = false
                    AudioServicesPlaySystemSound(1053)
                    onLog("❌ [LỖI KHÔNG THỂ BỎ QUA]: \(error.localizedDescription)")
                }
            }
        }
    }
}

// MARK: - 4. UTILITIES
struct TimeFormatter { static func current() -> String { let f = DateFormatter(); f.dateFormat = "HH:mm:ss.SSS"; return f.string(from: Date()) } }
struct NeonParticleBackgroundView: View {
    var body: some View {
        TimelineView(.animation) { context in
            Canvas { ctx, size in
                let time = context.date.timeIntervalSinceReferenceDate
                for i in 0..<60 {
                    let seed = Double(i) * 55.0; let x = (sin(time * 0.2 + seed) * 0.5 + 0.5) * size.width
                    let y = size.height - fmod(time * (50.0 + fmod(seed, 25.0)) + seed, size.height)
                    ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 2, height: 2)), with: .color(.white.opacity(0.35)))
                }
            }
        }.allowsHitTesting(false)
    }
}
private struct PatchStorePresentationModifier: ViewModifier { @ObservedObject var store: PatchProjectStore; func body(content: Content) -> some View { content } }
extension View { func patchStorePresentation(_ store: PatchProjectStore) -> some View { modifier(PatchStorePresentationModifier(store: store)) } }
