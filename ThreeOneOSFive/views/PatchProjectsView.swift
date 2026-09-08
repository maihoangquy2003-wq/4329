import SwiftUI
import UniformTypeIdentifiers

struct ServerPatchItem: Identifiable, Codable {
    var id: String { url }
    let name: String
    let url: String
    let size: Int
    let date: TimeInterval
}

final class WebSyncManager: ObservableObject {
    @Published var serverItems: [ServerPatchItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    func fetchServerPatches() {
        guard let apiURL = URL(string: "https://solitudepremium.click/ipa/proxy/api_list.php") else { return }
        isLoading = true
        
        URLSession.shared.dataTask(with: apiURL) { data, _, error in
            DispatchQueue.main.async {
                self.isLoading = false
                if let error = error {
                    self.errorMessage = error.localizedDescription
                    return
                }
                
                guard let data = data,
                      let jsonDict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let list = jsonDict["items"] as? [[String: Any]] else {
                    return
                }
                
                do {
                    let decodedData = try JSONSerialization.data(withJSONObject: list)
                    self.serverItems = try JSONDecoder().decode([ServerPatchItem].self, from: decodedData)
                } catch {
                    self.errorMessage = "Lỗi giải mã dữ liệu"
                }
            }
        }.resume()
    }
}

struct WebSyncListView: View {
    @StateObject private var syncManager = WebSyncManager()
    @EnvironmentObject private var store: PatchProjectStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(syncManager.serverItems) { item in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.name).font(.headline)
                        Text("Dung lượng: \(item.size / 1024) KB").font(.caption).foregroundColor(.secondary)
                    }
                    Spacer()
                    Button("Tải & Import") {
                        downloadAndImport(item.url)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .navigationTitle("Kho Patch Từ Web")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Đóng") { dismiss() }
                }
            }
            .onAppear {
                syncManager.fetchServerPatches()
            }
        }
    }

    private func downloadAndImport(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        URLSession.shared.downloadTask(with: url) { localURL, _, _ in
            guard let localURL = localURL else { return }
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(url.lastPathComponent)
            try? FileManager.default.removeItem(at: tempURL)
            try? FileManager.default.moveItem(at: localURL, to: tempURL)
            
            DispatchQueue.main.async {
                store.importPackage(at: tempURL)
                dismiss()
            }
        }.resume()
    }
}

private enum PatchPackagePickerPolicy {
    static let packageType = UTType(filenameExtension: "3105") ?? .data
    static let allowedContentTypes: [UTType] = [packageType, .data]
    static let copiesSelectedDocument = true
}

private struct WallpaperImportFeedback: Identifiable {
    let id = UUID()
    let titleKey: String
    let message: String
}

struct PatchProjectsView: View {
    @Environment(\.appLanguage) private var language
    @EnvironmentObject private var draftCoordinator: PatchDraftCoordinator
    @EnvironmentObject private var store: PatchProjectStore
    @AppStorage(FeatureVisibility.cleanerStorageKey) private var cleanerEnabled = true
    
    @State private var showCreate = false
    @State private var showImporter = false
    @State private var searchText = ""
    @State private var showWebSyncList = false
    
    let onOpenSettings: () -> Void
    let onOpenLogs: () -> Void

    private var filteredItems: [PatchLibraryItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return store.items }
        return store.items.filter { item in
            if item.packageURL.lastPathComponent.localizedCaseInsensitiveContains(query) { return true }
            guard let project = item.project else { return false }
            return project.name.localizedCaseInsensitiveContains(query) || project.author.localizedCaseInsensitiveContains(query)
        }
    }

    private var hasLocalContent: Bool { !store.items.isEmpty }
    private var hasSearchResults: Bool { !filteredItems.isEmpty }

    init(onOpenSettings: @escaping () -> Void = {}, onOpenLogs: @escaping () -> Void = {}) {
        self.onOpenSettings = onOpenSettings
        self.onOpenLogs = onOpenLogs
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                AppSearchField(
                    text: $searchText,
                    prompt: language.text("installed.search"),
                    clearLabel: language.text("common.clear")
                )
                Divider()
                List {
                    if !hasLocalContent && store.isBusy {
                        loadingState.listRowSeparator(.hidden)
                    } else if !hasLocalContent {
                        emptyState.listRowSeparator(.hidden)
                    } else if !hasSearchResults && !store.isBusy {
                        searchEmptyState.listRowSeparator(.hidden)
                    } else {
                        Section(language.text("patch.title")) {
                            ForEach(filteredItems) { item in itemRow(item) }
                            .onDelete { offsets in offsets.map { filteredItems[$0] }.forEach(store.delete) }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
            .navigationTitle(language.text("tab.installed"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button { showCreate = true } label: { Label(language.text("patch.new"), systemImage: "doc.badge.plus") }
                        Button { showImporter = true } label: { Label(language.text("patch.import"), systemImage: "square.and.arrow.down") }
                        Button { showWebSyncList = true } label: { Label("Kho Patch từ Web", systemImage: "cloud.download") }
                    } label: {
                        if store.isBusy {
                            ProgressView()
                        } else {
                            Image(systemName: "plus")
                        }
                    }
                    .disabled(store.isBusy)
                }
                AppUtilityToolbar(language: language, onOpenSettings: onOpenSettings, onOpenLogs: onOpenLogs)
            }
            .sheet(isPresented: $showWebSyncList) {
                WebSyncListView().environmentObject(store)
            }
            .sheet(isPresented: $showImporter) {
                FileDocumentPicker(
                    allowedContentTypes: PatchPackagePickerPolicy.allowedContentTypes,
                    copiesSelectedDocument: PatchPackagePickerPolicy.copiesSelectedDocument,
                    allowsMultipleSelection: false,
                    onSelection: { result in
                        showImporter = false
                        if case .success(let urls) = result, let url = urls.first { store.importPackage(at: url) }
                    },
                    onCancel: { showImporter = false }
                ).ignoresSafeArea()
            }
            .sheet(isPresented: $showCreate) {
                PatchProjectEditorView(existingProject: nil, passwordIsProtected: false) { project, password in
                    store.create(project: project, password: password)
                }
            }
        }
    }

    @ViewBuilder
    private func itemRow(_ item: PatchLibraryItem) -> some View {
        if item.isLocked {
            Button { store.requestUnlock(for: item) } label: { PatchProjectRow(item: item, language: language) }.buttonStyle(.plain)
        } else {
            NavigationLink { PatchProjectDetailView(store: store, projectID: item.id) } label: { PatchProjectRow(item: item, language: language) }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "shippingbox").font(.system(size: AppTheme.emptyIconSize, weight: .light)).foregroundStyle(AppTheme.accent)
            Text(language.text("installed.empty_title")).font(.headline)
            Text(language.text("installed.empty_message")).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Button(language.text("patch.new")) { showCreate = true }.buttonStyle(.bordered).controlSize(.large)
        }.frame(maxWidth: .infinity).padding(.vertical, 64)
    }

    private var loadingState: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text(language.text("installed.loading")).font(.subheadline).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity).padding(.vertical, 64)
    }

    private var searchEmptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "magnifyingglass").font(.system(size: AppTheme.emptyIconSize, weight: .light)).foregroundStyle(.secondary)
            Text(language.text("patch.search_empty")).font(.headline)
            Text(language.text("patch.search_empty_message")).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }.frame(maxWidth: .infinity).padding(.vertical, 64)
    }
}

private struct PatchProjectRow: View {
    let item: PatchLibraryItem
    let language: AppLanguage

    var body: some View {
        HStack(spacing: 12) {
            AppRowIcon(systemName: item.isLocked ? "lock.doc.fill" : "shippingbox.fill")
            VStack(alignment: .leading, spacing: 3) {
                Text(item.project?.name ?? language.text("patch.locked_project")).font(.body.weight(.semibold)).foregroundStyle(.primary).lineLimit(1)
                if let author = item.project?.author, !author.isEmpty {
                    Text(language.text("patch.by_author", author)).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
        }.padding(.vertical, 4)
    }
}

// Bổ sung modifier patchStorePresentation để sửa lỗi ở ContentView.swift
struct PatchStorePresentationModifier: ViewModifier {
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

// Màn hình chi tiết tích hợp nút gạt (Toggle) Áp dụng / Khôi phục
private struct PatchProjectDetailView: View {
    @Environment(\.appLanguage) private var language
    @ObservedObject var store: PatchProjectStore
    let projectID: UUID
    @State private var isWorking = false
    @State private var actionAlert: PatchStoreAlert?

    private var item: PatchLibraryItem? { store.items.first(where: { $0.id == projectID }) }
    private var receipt: PatchTransactionReceipt? { DevicePatchService.latestReceipt(projectID: projectID) }

    var body: some View {
        List {
            if let item {
                Section {
                    Toggle(isOn: Binding(
                        get: { receipt != nil },
                        set: { isApplying in
                            if isApplying { apply() } else { prepareRestore() }
                        }
                    )) {
                        Label(
                            language.text(receipt != nil ? "patch.applied_message" : "patch.apply"),
                            systemImage: receipt != nil ? "checkmark.shield.fill" : "shield"
                        )
                    }
                    .disabled(isWorking)
                    .tint(AppTheme.accent)
                } footer: {
                    Text(language.text("patch.apply_footer"))
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(item?.project?.name ?? "Patch")
        .alert(item: $actionAlert) { alert in
            Alert(title: Text(language.text(alert.titleKey)), message: Text(alert.message(language: language)), dismissButton: .default(Text(language.text("common.ok"))))
        }
    }

    private func apply() {
        guard let item, let baseProject = item.project else { return }
        isWorking = true
        Task.detached(priority: .userInitiated) {
            do {
                _ = try DevicePatchService.apply(project: baseProject)
                await MainActor.run { store.reload(); isWorking = false; actionAlert = PatchStoreAlert(titleKey: "common.done", messageKey: "patch.applied_message") }
            } catch {
                await MainActor.run { isWorking = false; actionAlert = PatchStoreAlert(titleKey: "common.failed", messageKey: "patch.error.apply") }
            }
        }
    }

    private func prepareRestore() {
        guard let receipt else { return }
        isWorking = true
        Task.detached(priority: .userInitiated) {
            do {
                try DevicePatchService.restore(receipt: receipt)
                await MainActor.run { isWorking = false; actionAlert = PatchStoreAlert(titleKey: "common.done", messageKey: "patch.restored_message") }
            } catch {
                await MainActor.run { isWorking = false; actionAlert = PatchStoreAlert(titleKey: "common.failed", messageKey: "patch.error.restore") }
            }
        }
    }
}
