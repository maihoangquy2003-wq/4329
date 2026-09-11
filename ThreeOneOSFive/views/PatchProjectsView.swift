import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct PatchProjectsView: View {
    @Environment(\.appLanguage) private var language
    @EnvironmentObject private var draftCoordinator: PatchDraftCoordinator
    @EnvironmentObject private var store: PatchProjectStore
    
    @State private var searchText = ""
    @State private var isAutoSyncing = false
    @State private var workingFileID: String? = nil
    @State private var actionAlert: PatchStoreAlert?
    
    let onOpenSettings: () -> Void
    let onOpenLogs: () -> Void

    init(
        onOpenSettings: @escaping () -> Void = {},
        onOpenLogs: @escaping () -> Void = {}
    ) {
        self.onOpenSettings = onOpenSettings
        self.onOpenLogs = onOpenLogs
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // HEADER VỚI AVATAR LẤY TỪ LI.JPG
                    VStack(spacing: 12) {
                        AsyncImage(url: URL(string: "https://solitudepremium.click/ipa/proxy/li.jpg")) { phase in
                            switch phase {
                            case .empty:
                                ProgressView()
                                    .frame(width: 80, height: 80)
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 80, height: 80)
                                    .clipShape(Circle())
                                    .overlay(Circle().stroke(Color.yellow, lineWidth: 2))
                                    .shadow(color: Color.yellow.opacity(0.5), radius: 8)
                            case .failure(_):
                                Image(systemName: "person.crop.circle.fill")
                                    .font(.system(size: 80))
                                    .foregroundStyle(.gray)
                            @unknown default:
                                EmptyView()
                            }
                        }
                        
                        Text("Zenith Solitude")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(.white)
                            .shadow(color: .white.opacity(0.3), radius: 5)
                    }
                    .padding(.vertical, 20)
                    
                    // DANH SÁCH GAME CARD (FREE FIRE MAX & THƯỜNG)
                    ScrollView {
                        VStack(spacing: 16) {
                            gameCardView(
                                title: "Free Fire Max",
                                prefix: "ffmax_"
                            )
                            
                            gameCardView(
                                title: "Free Fire Thường",
                                prefix: "ffnormal_"
                            )
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 30)
                    }
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                syncRemotePatches()
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

    @ViewBuilder
    private func gameCardView(title: String, prefix: String) -> some View {
        let matchedItems = store.items.filter { item in
            let name = item.packageURL.lastPathComponent
            return name.hasPrefix(prefix) || (!name.hasPrefix("ffmax_") && !name.hasPrefix("ffnormal_") && prefix == "ffnormal_")
        }
        
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                // ICON TẢI TỪ FREE.JPG
                AsyncImage(url: URL(string: "https://solitudepremium.click/ipa/proxy/free.jpg")) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 55, height: 55)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    default:
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 55, height: 55)
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.white)
                    
                    Text(matchedItems.isEmpty ? "Chưa có file patch" : "Đã tải: \(matchedItems.count) file")
                        .font(.caption)
                        .foregroundStyle(.gray)
                }
                
                Spacer()
                
                if isAutoSyncing {
                    ProgressView()
                }
            }
            
            Divider().background(Color.gray.opacity(0.3))
            
            if matchedItems.isEmpty {
                Text("Hệ thống chưa có gói patch nào.")
                    .font(.footnote)
                    .foregroundStyle(.gray)
                    .italic()
                    .padding(.vertical, 4)
            } else {
                ForEach(matchedItems) { item in
                    let receipt = DevicePatchService.latestReceipt(projectID: item.id)
                    let isApplied = receipt != nil
                    let fileID = item.id.uuidString
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.project?.name ?? item.packageURL.lastPathComponent)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                            
                            Text(isApplied ? "Đang kích hoạt" : "Đã tắt")
                                .font(.caption2)
                                .foregroundStyle(isApplied ? .green : .orange)
                        }
                        
                        Spacer()
                        
                        // NÚT GẠT BÊN NGOÀI
                        Toggle("", isOn: Binding(
                            get: { isApplied },
                            set: { newValue in
                                togglePatch(item: item, activate: newValue)
                            }
                        ))
                        .labelsHidden()
                        .tint(.green)
                        .disabled(workingFileID == fileID)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(#colorLiteral(red: 0.1176470588, green: 0.1607843137, blue: 0.231372549, alpha: 1))))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.gray.opacity(0.2), lineWidth: 1))
    }

    private func togglePatch(item: PatchLibraryItem, activate: Bool) {
        let fileID = item.id.uuidString
        workingFileID = fileID
        
        Task.detached(priority: .userInitiated) {
            do {
                if activate {
                    guard let project = item.project else { return }
                    _ = try DevicePatchService.apply(project: project)
                    await MainActor.run {
                        store.reload()
                        workingFileID = nil
                        actionAlert = PatchStoreAlert(titleKey: "Thành công", messageKey: "Đã kích hoạt patch thành công!")
                    }
                } else {
                    guard let receipt = DevicePatchService.latestReceipt(projectID: item.id) else {
                        await MainActor.run { workingFileID = nil }
                        return
                    }
                    try DevicePatchService.restore(receipt: receipt)
                    await MainActor.run {
                        store.reload()
                        workingFileID = nil
                        actionAlert = PatchStoreAlert(titleKey: "Thành công", messageKey: "Đã tắt/khôi phục patch!")
                    }
                }
            } catch {
                await MainActor.run {
                    workingFileID = nil
                    actionAlert = PatchStoreAlert(titleKey: "Lỗi", messageKey: "Thao tác thất bại: \(error.localizedDescription)")
                }
            }
        }
    }

    private func syncRemotePatches() {
        guard !isAutoSyncing else { return }
        isAutoSyncing = true
        
        Task {
            do {
                guard let listUrl = URL(string: "https://solitudepremium.click/ipa/proxy/list.php") else {
                    await MainActor.run { isAutoSyncing = false }
                    return
                }
                let (data, _) = try await URLSession.shared.data(from: listUrl)
                
                struct RemoteFile: Decodable {
                    let filename: String
                    let gameType: String
                    let url: String
                }
                
                let remoteFiles = try JSONDecoder().decode([RemoteFile].self, from: data)
                let localFilenames = store.items.map { $0.packageURL.lastPathComponent }
                
                for file in remoteFiles {
                    if localFilenames.contains(file.filename) { continue }
                    
                    if let fileURL = URL(string: file.url) {
                        await MainActor.run {
                            store.importPackage(from: .remote(fileURL))
                        }
                        try await Task.sleep(nanoseconds: 5_000_000_000)
                    }
                }
            } catch {
                print("Lỗi đồng bộ: \(error.localizedDescription)")
            }
            
            await MainActor.run {
                isAutoSyncing = false
            }
        }
    }
}

// BỔ SUNG LẠI CÁC EXTENSION ĐỂ KHỚP VỚI HỆ THỐNG GỐC CỦA DỰ ÁN
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
                        Text(store.unlockErrorArgument.map { language.text(errorKey, $0) }
                            ?? language.text(errorKey))
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

    private func unlock() {
        guard !password.isEmpty else { return }
        store.unlock(password: password)
    }
}

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
