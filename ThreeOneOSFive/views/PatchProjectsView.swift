
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
    
    // MARK: - Fetch Remote Items
    func fetchRemoteItems() async throws -> [RemoteAimItem] {
        guard let url = URL(string: "\(baseURL)/apiaim.php") else {
            throw APIError.invalidURL
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.serverError
        }
        
        do {
            return try JSONDecoder().decode([RemoteAimItem].self, from: data)
        } catch {
            throw APIError.decodingError
        }
    }
    
    // MARK: - Download and Save File
    func downloadAndSaveFile(from remoteURL: String, itemID: String) async throws -> URL {
        guard let url = URL(string: remoteURL) else {
            throw APIError.invalidURL
        }
        
        // Tạo thư mục riêng cho mỗi item
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let itemFolderURL = documentsURL.appendingPathComponent("PatchFiles/\(itemID)", isDirectory: true)
        
        if !fileManager.fileExists(atPath: itemFolderURL.path) {
            try fileManager.createDirectory(at: itemFolderURL, withIntermediateDirectories: true)
        }
        
        let fileName = "\(itemID)_\(Date().timeIntervalSince1970).3105"
        let destinationURL = itemFolderURL.appendingPathComponent(fileName)
        
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.serverError
        }
        
        try data.write(to: destinationURL)
        return destinationURL
    }
    
    // MARK: - Upload File
    func uploadFile(fileURL: URL, name: String, category: String, target: String, note: String) async throws {
        guard let url = URL(string: "\(baseURL)/upload.php") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        // Thêm file
        let fileData = try Data(contentsOf: fileURL)
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileURL.lastPathComponent)\"\r\n")
        body.append("Content-Type: application/octet-stream\r\n\r\n")
        body.append(fileData)
        body.append("\r\n")
        
        // Thêm các field
        let fields = ["name": name, "category": category, "target": target, "note": note]
        for (key, value) in fields {
            body.append("--\(boundary)\r\n")
            body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n")
            body.append("\(value)\r\n")
        }
        body.append("--\(boundary)--\r\n")
        
        request.httpBody = body
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.serverError
        }
        // Có thể parse response nếu cần
    }
    
    // MARK: - Clean Old Files
    func cleanOldFiles(for itemID: String, keepCurrent: URL? = nil) {
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let itemFolderURL = documentsURL.appendingPathComponent("PatchFiles/\(itemID)", isDirectory: true)
        
        guard let files = try? fileManager.contentsOfDirectory(at: itemFolderURL, includingPropertiesForKeys: nil) else { return }
        
        for file in files {
            if let keepCurrent = keepCurrent, file == keepCurrent { continue }
            try? fileManager.removeItem(at: file)
        }
    }
}

// MARK: - Error
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
    @State private var showUpload = false
    
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
        .sheet(isPresented: $showUpload) {
            UploadView(selectedGameBundle: selectedGameBundle)
        }
        .onAppear {
            Task { await fetchRemoteData() }
            withAnimation(.linear(duration: 6).repeatForever(autoreverses: false)) {
                avatarRotation = 360
            }
        }
    }
    
    // MARK: - Home Screen
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
    
    // MARK: - Mod Menu Screen
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
                
                Button(action: { showUpload = true }) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .padding(10)
                        .background(Circle().stroke(Color.white.opacity(0.4), lineWidth: 1.5))
                }
                .buttonStyle(NeonScaleButtonStyle())
                
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
        
        do {
            remoteItems = try await RemoteAPIManager.shared.fetchRemoteItems()
            if !dynamicTabs.contains(selectedTab), let first = dynamicTabs.first {
                selectedTab = first
            }
        } catch {
            print("Lỗi fetch remote data: \(error.localizedDescription)")
        }
        
        isFetching = false
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
            do {
                if on {
                    try await applyPatch()
                } else {
                    try await removePatch()
                }
                
                UserDefaults.standard.set(on, forKey: toggleStateKey)
                self.isApplied = on
                self.isWorking = false
                AudioServicesPlaySystemSound(1407)
                
            } catch {
                print("Lỗi hệ thống patch: \(error.localizedDescription)")
                UserDefaults.standard.set(!on, forKey: toggleStateKey)
                self.isApplied = !on
                self.isWorking = false
                AudioServicesPlaySystemSound(1053)
            }
        }
    }
    
    @MainActor
    private func applyPatch() async throws {
        let fileURL = try await RemoteAPIManager.shared.downloadAndSaveFile(from: remoteItem.url, itemID: remoteItem.id)
        
        let beforeIds = store.items.map { $0.id }
        store.importPackage(at: fileURL)
        try await Task.sleep(nanoseconds: 700_000_000)
        
        guard let freshItem = store.items.first(where: { !beforeIds.contains($0.id) }) else {
            throw NSError(domain: "ImportFailed", code: 0, userInfo: [NSLocalizedDescriptionKey: "Không thể nạp cấu hình file vào hệ thống."])
        }
        
        UserDefaults.standard.set(freshItem.id.uuidString, forKey: mappedUUIDKey)
        
        let project: PatchProject
        if freshItem.summary.schemaVersion >= 2 && freshItem.canInspectContents {
            project = try PatchProjectLibrary.synchronizeWorkspace(item: freshItem)
        } else {
            guard let baseProject = freshItem.project else {
                throw NSError(domain: "ProjectError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Không thể truy cập project."])
            }
            project = baseProject
        }
        
        _ = try DevicePatchService.apply(project: project)
        
        RemoteAPIManager.shared.cleanOldFiles(for: remoteItem.id, keepCurrent: fileURL)
    }
    
    @MainActor
    private func removePatch() async throws {
        if let uuidStr = UserDefaults.standard.string(forKey: mappedUUIDKey),
           let uuid = UUID(uuidString: uuidStr),
           let targetItem = store.items.first(where: { $0.id == uuid }),
           let receipt = DevicePatchService.latestReceipt(projectID: targetItem.id) {
            try DevicePatchService.restore(receipt: receipt, allowChangedTargets: true)
        } else {
            let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let itemFolderURL = documentsURL.appendingPathComponent("PatchFiles/\(remoteItem.id)", isDirectory: true)
            
            if let files = try? FileManager.default.contentsOfDirectory(at: itemFolderURL, includingPropertiesForKeys: nil),
               let latestFile = files.max(by: { $0.lastPathComponent < $1.lastPathComponent }) {
                let beforeIds = store.items.map { $0.id }
                store.importPackage(at: latestFile)
                try await Task.sleep(nanoseconds: 500_000_000)
                
                if let targetItem = store.items.first(where: { !beforeIds.contains($0.id) }),
                   let receipt = DevicePatchService.latestReceipt(projectID: targetItem.id) {
                    try DevicePatchService.restore(receipt: receipt, allowChangedTargets: true)
                }
            }
        }
        
        RemoteAPIManager.shared.cleanOldFiles(for: remoteItem.id)
    }
}

// MARK: - Upload View
struct UploadView: View {
    let selectedGameBundle: String
    @Environment(\.dismiss) private var dismiss
    
    @State private var fileName = ""
    @State private var category = ""
    @State private var note = ""
    @State private var fileURL: URL?
    @State private var isUploading = false
    @State private var showFilePicker = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 20) {
                    Text("Tải lên file .3105")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Tên chức năng")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.gray)
                        TextField("Nhập tên", text: $fileName)
                            .textFieldStyle(.plain)
                            .padding()
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(10)
                            .foregroundColor(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Thư mục (category)")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.gray)
                        TextField("Nhập tên thư mục", text: $category)
                            .textFieldStyle(.plain)
                            .padding()
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(10)
                            .foregroundColor(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Ghi chú")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.gray)
                        TextField("Ghi chú (không bắt buộc)", text: $note)
                            .textFieldStyle(.plain)
                            .padding()
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(10)
                            .foregroundColor(.white)
                    }
                    
                    Button(action: { showFilePicker = true }) {
                        HStack {
                            Image(systemName: "doc.badge.plus")
                            Text(fileURL?.lastPathComponent ?? "Chọn file .3105")
                                .lineLimit(1)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(10)
                        .foregroundColor(.white)
                    }
                    
                    Button(action: upload) {
                        if isUploading {
                            ProgressView()
                                .tint(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                        } else {
                            Text("Tải lên")
                                .font(.system(size: 16, weight: .bold))
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.white)
                                .foregroundColor(.black)
                                .cornerRadius(12)
                        }
                    }
                    .disabled(fileURL == nil || fileName.isEmpty || category.isEmpty || isUploading)
                    
                    Spacer()
                }
                .padding()
            }
            .navigationBarItems(trailing: Button("Đóng") { dismiss() })
        }
        .fileImporter(isPresented: $showFilePicker, allowedContentTypes: [UTType(filenameExtension: "3105") ?? .data]) { result in
            switch result {
            case .success(let url):
                fileURL = url
            case .failure(let error):
                print("Lỗi chọn file: \(error.localizedDescription)")
            }
        }
    }
    
    private func upload() {
        guard let fileURL = fileURL else { return }
        isUploading = true
        
        Task {
            do {
                try await RemoteAPIManager.shared.uploadFile(
                    fileURL: fileURL,
                    name: fileName,
                    category: category,
                    target: selectedGameBundle,
                    note: note
                )
                isUploading = false
                dismiss()
            } catch {
                print("Lỗi upload: \(error.localizedDescription)")
                isUploading = false
            }
        }
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

// MARK: - Button Style
struct NeonScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
    }
}
