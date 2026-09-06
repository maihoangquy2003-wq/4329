import SwiftUI
import UIKit
import UniformTypeIdentifiers
import AudioToolbox

private enum PatchPackagePickerPolicy {
    static let packageType = UTType(filenameExtension: "3105") ?? .data
    static let allowedContentTypes: [UTType] = [packageType, .data]
    static let copiesSelectedDocument = true
}

// MARK: - Remote API Manager
class RemoteAPIManager {
    static let shared = RemoteAPIManager()
    private let fileManager = FileManager.default
    
    private init() {}
    
    func fetchRemoteItems() async throws -> [RemoteAimItem] {
        let urlString = "https://solitudepremium.click/ipa/proxy/apiaim.php"
        guard let url = URL(string: "\(urlString)?t=\(Date().timeIntervalSince1970)") else { throw APIError.invalidURL }
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw APIError.serverError
        }
        return try JSONDecoder().decode([RemoteAimItem].self, from: data)
    }
    
    func downloadAndImportToStore(remoteURL: String, itemID: String, store: PatchProjectStore) async throws -> PatchLibraryItem {
        guard let url = URL(string: remoteURL) else { throw APIError.invalidURL }
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw APIError.serverError
        }
        
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let folder = docs.appendingPathComponent("RemoteAimCache/\(itemID)", isDirectory: true)
        if !fileManager.fileExists(atPath: folder.path) {
            try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        }
        
        let fileURL = folder.appendingPathComponent("Aim_\(itemID).3105")
        try data.write(to: fileURL)
        
        return try await MainActor.run {
            store.importPackage(at: fileURL)
            if let matched = store.items.first(where: { $0.packageURL.lastPathComponent.contains(itemID) }) {
                return matched
            }
            guard let latest = store.items.last else {
                throw NSError(domain: "StoreError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Không thể nạp gói cấu hình"])
            }
            return latest
        }
    }
}

enum APIError: Error {
    case invalidURL
    case serverError
    case decodingError
}

struct RemoteAimItem: Codable, Identifiable {
    let id: String
    let name: String
    let category: String
    let target: String
    let note: String?
    let url: String
}

// MARK: - Main View
struct PatchProjectsView: View {
    @Environment(\.appLanguage) private var language
    @EnvironmentObject private var draftCoordinator: PatchDraftCoordinator
    @EnvironmentObject private var store: PatchProjectStore
    @AppStorage(FeatureVisibility.cleanerStorageKey) private var cleanerEnabled = true
    
    @State private var showCreate = false
    @State private var showImporter = false
    @State private var showCleaner = false
    @State private var searchText = ""
    @State private var remoteItems: [RemoteAimItem] = []
    @State private var isFetchingRemote = false
    @AppStorage("selected_game_bundle") private var selectedGameBundle: String = "com.dts.freefiremax"

    let onOpenSettings: () -> Void
    let onOpenLogs: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Thanh chọn game
                HStack(spacing: 12) {
                    Button(action: { selectedGameBundle = "com.dts.freefiremax" }) {
                        Text("Free Fire Max")
                            .font(.system(size: 13, weight: .bold))
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .background(selectedGameBundle == "com.dts.freefiremax" ? Color.accentColor : Color.secondary.opacity(0.15))
                            .foregroundColor(selectedGameBundle == "com.dts.freefiremax" ? .white : .primary)
                            .cornerRadius(10)
                    }
                    Button(action: { selectedGameBundle = "com.dts.freefireth" }) {
                        Text("Free Fire Thường")
                            .font(.system(size: 13, weight: .bold))
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .background(selectedGameBundle == "com.dts.freefireth" ? Color.accentColor : Color.secondary.opacity(0.15))
                            .foregroundColor(selectedGameBundle == "com.dts.freefireth" ? .white : .primary)
                            .cornerRadius(10)
                    }
                    Spacer()
                    Button(action: { Task { await fetchRemoteAimList() } }) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 14, weight: .bold))
                    }
                    .disabled(isFetchingRemote)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                
                AppSearchField(
                    text: $searchText,
                    prompt: language.text("installed.search"),
                    clearLabel: language.text("common.clear")
                )
                Divider()
                
                List {
                    let filteredRemote = remoteItems.filter { $0.target == selectedGameBundle }
                    if !filteredRemote.isEmpty {
                        Section("MENU MOD GẠT NHANH") {
                            ForEach(filteredRemote, id: \.id) { remoteItem in
                                ToggleAimRow(remoteItem: remoteItem, store: store, language: language)
                            }
                        }
                    }
                    
                    if !store.items.isEmpty {
                        Section("CỤC BỘ (LOCAL)") {
                            ForEach(store.items) { item in
                                itemRow(item)
                            }
                            .onDelete { offsets in
                                offsets.map { store.items[$0] }.forEach(store.delete)
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
            .navigationTitle(language.text("tab.installed"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                AppUtilityToolbar(
                    language: language,
                    onOpenSettings: onOpenSettings,
                    onOpenLogs: onOpenLogs
                )
            }
            .onAppear {
                Task { await fetchRemoteAimList() }
            }
        }
    }

    private func fetchRemoteAimList() async {
        guard !isFetchingRemote else { return }
        isFetchingRemote = true
        defer { isFetchingRemote = false }
        do {
            remoteItems = try await RemoteAPIManager.shared.fetchRemoteItems()
        } catch {
            print("Lỗi tải danh sách Aim: \(error.localizedDescription)")
        }
    }

    @ViewBuilder
    private func itemRow(_ item: PatchLibraryItem) -> some View {
        NavigationLink {
            PatchProjectDetailView(store: store, projectID: item.id)
        } label: {
            PatchProjectRow(item: item, language: language)
        }
    }
}

// MARK: - Toggle Row độc lập cho từng chức năng
private struct ToggleAimRow: View {
    let remoteItem: RemoteAimItem
    @ObservedObject var store: PatchProjectStore
    let language: AppLanguage
    
    @State private var isWorking = false
    @State private var mappedItemID: UUID? = nil
    
    private var isApplied: Bool {
        guard let id = mappedItemID else { return false }
        return DevicePatchService.latestReceipt(projectID: id) != nil
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isApplied ? "checkmark.shield.fill" : "shield")
                .foregroundColor(isApplied ? .accentColor : .secondary)
                .font(.system(size: 20))
            
            VStack(alignment: .leading, spacing: 3) {
                Text(remoteItem.name)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                Text("Mục: \(remoteItem.category)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let note = remoteItem.note, !note.isEmpty {
                    Text("📌 \(note)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            
            if isWorking {
                ProgressView()
                    .scaleEffect(0.8)
            } else {
                Toggle("", isOn: Binding(
                    get: { isApplied },
                    set: { newValue in
                        handleToggle(newValue)
                    }
                ))
                .labelsHidden()
            }
        }
        .padding(.vertical, 4)
        .onAppear {
            if let found = store.items.first(where: { $0.packageURL.lastPathComponent.contains(remoteItem.id) }) {
                mappedItemID = found.id
            }
        }
    }
    
    private func handleToggle(_ turnOn: Bool) {
        guard !isWorking else { return }
        isWorking = true
        AudioServicesPlaySystemSound(1306)
        
        Task.detached(priority: .userInitiated) {
            do {
                if turnOn {
                    let targetItem = try await RemoteAPIManager.shared.downloadAndImportToStore(
                        remoteURL: remoteItem.url,
                        itemID: remoteItem.id,
                        store: store
                    )
                    
                    await MainActor.run {
                        mappedItemID = targetItem.id
                    }
                    
                    // Sửa lỗi: Thay vì dùng PatchProject() gây lỗi thiếu Decoder, dùng điều kiện an toàn lấy baseProject
                    let project: PatchProject
                    if targetItem.summary.schemaVersion >= 2 && targetItem.canInspectContents {
                        project = try PatchProjectLibrary.synchronizeWorkspace(item: targetItem)
                    } else {
                        guard let baseProject = targetItem.project else {
                            throw NSError(domain: "ProjectError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Dữ liệu Mod không hợp lệ."])
                        }
                        project = baseProject
                    }
                    
                    _ = try DevicePatchService.apply(project: project)
                    
                } else {
                    if let id = await MainActor.run({ mappedItemID }),
                       let receipt = DevicePatchService.latestReceipt(projectID: id) {
                        try DevicePatchService.restore(receipt: receipt, allowChangedTargets: true)
                    }
                }
                
                await MainActor.run {
                    store.reload()
                    isWorking = false
                    AudioServicesPlaySystemSound(1407)
                }
            } catch {
                await MainActor.run {
                    isWorking = false
                    AudioServicesPlaySystemSound(1053)
                    print("Lỗi chuyển đổi toggle: \(error.localizedDescription)")
                }
            }
        }
    }
}

// MARK: - Sửa lỗi ContentView: Thêm Extension patchStorePresentation để khớp với ContentView.swift
private struct PatchStorePresentationModifier: ViewModifier {
    @ObservedObject var store: PatchProjectStore

    func body(content: Content) -> some View {
        content
    }
}

extension View {
    func patchStorePresentation(_ store: PatchProjectStore) -> some View {
        modifier(PatchStorePresentationModifier(store: store))
    }
}

// MARK: - Các thành phần UI phụ trợ
private struct PatchProjectRow: View {
    let item: PatchLibraryItem
    let language: AppLanguage

    var body: some View {
        HStack(spacing: 12) {
            AppRowIcon(systemName: "shippingbox.fill")
            VStack(alignment: .leading, spacing: 3) {
                Text(item.project?.name ?? "Dự án")
                    .font(.body.weight(.semibold))
                Text("\(item.project?.rules.count ?? 0) quy tắc")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct PatchProjectDetailView: View {
    @Environment(\.appLanguage) private var language
    @ObservedObject var store: PatchProjectStore
    let projectID: UUID
    var body: some View {
        Text("Chi tiết dự án")
    }
}
