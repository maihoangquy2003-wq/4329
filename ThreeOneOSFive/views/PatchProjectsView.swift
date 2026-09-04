import SwiftUI
import UIKit
import UniformTypeIdentifiers

// MARK: - MÀN HÌNH QUẢN LÝ AIM (MOD MENU)
struct PatchProjectsView: View {
    @Environment(\.appLanguage) private var language
    @EnvironmentObject private var store: PatchProjectStore
    
    @State private var isFetchingRemote = false
    @State private var fetchMessage: String? = nil
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                
                // NÚT TẢI AIM TỪ SERVER VỀ TRỰC TIẾP
                Button(action: fetchRemoteAim) {
                    HStack {
                        if isFetchingRemote {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: "cloud.arrow.down.fill")
                        }
                        Text(isFetchingRemote ? "Đang Tải Dữ Liệu..." : "Cập Nhật Dữ Liệu Từ Máy Chủ")
                            .font(.system(size: 14, weight: .bold))
                    }
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(isFetchingRemote ? Color.gray : Color.white)
                    .cornerRadius(12)
                    .shadow(color: .white.opacity(0.3), radius: 5)
                }
                .disabled(isFetchingRemote)
                .padding(16)
                
                // DANH SÁCH FILE VÀ NÚT GẠT MENU
                List {
                    Section(header: Text("TÍNH NĂNG ĐÃ TẢI VỀ").font(.caption).foregroundColor(.gray)) {
                        if store.items.isEmpty {
                            Text("Chưa có dữ liệu nào. Vui lòng bấm Cập Nhật ở trên.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .padding(.vertical, 10)
                        } else {
                            ForEach(store.items) { item in
                                PatchProjectToggleRow(item: item, language: language, store: store)
                            }
                            .onDelete { offsets in
                                offsets.map { store.items[$0] }.forEach(store.delete)
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
            .navigationTitle("TRUNG TÂM CHỨC NĂNG")
            .navigationBarTitleDisplayMode(.inline)
            .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
        }
    }
    
    // MARK: - LOGIC TẢI FILE 3105 TỪ XA
    private func fetchRemoteAim() {
        guard !isFetchingRemote else { return }
        isFetchingRemote = true
        
        // Trỏ tới link PHP của bạn
        guard let apiURL = URL(string: "https://solitudepremium.click/ipa/proxy/4329.php?api=1") else {
            isFetchingRemote = false
            return
        }
        
        URLSession.shared.dataTask(with: apiURL) { data, response, error in
            defer { DispatchQueue.main.async { self.isFetchingRemote = false } }
            guard let data = data, error == nil else { return }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let fileUrlString = json["url"] as? String,
                   let fileUrl = URL(string: fileUrlString) {
                    
                    // Tiến hành tải file .3105 về máy lưu tạm
                    if let fileData = try? Data(contentsOf: fileUrl) {
                        let tempFileName = UUID().uuidString + ".3105"
                        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(tempFileName)
                        try fileData.write(to: tempURL)
                        
                        DispatchQueue.main.async {
                            // Gọi hàm import của app để cài đặt tự động
                            self.store.importPackage(at: tempURL)
                            UXFeedback.success()
                        }
                    }
                }
            } catch {
                DispatchQueue.main.async { UXFeedback.error() }
                print("Lỗi khi tải hoặc phân tích file JSON")
            }
        }.resume()
    }
}

// MARK: - HÀNG DANH SÁCH (CÓ NÚT GẠT BẬT TẮT)
private struct PatchProjectToggleRow: View {
    let item: PatchLibraryItem
    let language: AppLanguage
    @ObservedObject var store: PatchProjectStore
    
    @State private var isApplied: Bool = false
    @State private var isWorking: Bool = false
    @State private var receipt: PatchTransactionReceipt? = nil
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon bên trái
            ZStack {
                RoundedRectangle(cornerRadius: 10).fill(isApplied ? Color.green.opacity(0.2) : Color.gray.opacity(0.1)).frame(width: 40, height: 40)
                Image(systemName: isApplied ? "flame.fill" : "flame")
                    .foregroundColor(isApplied ? .green : .gray)
            }
            
            // Tên và Trạng thái (Lấy trực tiếp tên từ Info.json mà PHP đã lưu)
            VStack(alignment: .leading, spacing: 4) {
                Text(item.project?.name ?? "Aim Vô Danh")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.primary)
                Text(isApplied ? "Đang Ghi Đè Dữ Liệu" : "Đã Dừng")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(isApplied ? .green : .secondary)
            }
            
            Spacer()
            
            // Cục Loading hoặc Nút Gạt
            if isWorking {
                ProgressView().tint(AppTheme.accent).padding(.trailing, 5)
            } else {
                Toggle("", isOn: Binding(
                    get: { isApplied },
                    set: { newValue in handleToggle(turnOn: newValue) }
                ))
                .labelsHidden()
                .tint(.green)
            }
        }
        .padding(.vertical, 4)
        .onAppear(perform: loadCurrentStatus)
    }
    
    // Kiểm tra xem máy đã apply patch này chưa
    private func loadCurrentStatus() {
        if let currentReceipt = DevicePatchService.latestReceipt(projectID: item.id) {
            self.receipt = currentReceipt
            self.isApplied = true
        } else {
            self.receipt = nil
            self.isApplied = false
        }
    }
    
    // Xử lý Gạt Công Tắc
    private func handleToggle(turnOn: Bool) {
        guard !isWorking else { return }
        isWorking = true
        
        Task.detached(priority: .userInitiated) {
            if turnOn {
                // HÀNH ĐỘNG 1: BẬT (ÁP DỤNG PATCH)
                do {
                    guard let baseProject = item.project else { throw PatchPackageError.invalidFormat }
                    let project = item.summary.schemaVersion >= 2 && item.canInspectContents ? try PatchProjectLibrary.synchronizeWorkspace(item: item) : baseProject
                    
                    _ = try DevicePatchService.apply(project: project)
                    
                    await MainActor.run {
                        self.isApplied = true
                        self.loadCurrentStatus() // Cập nhật lại receipt
                        self.isWorking = false
                        UXFeedback.success()
                    }
                } catch {
                    await MainActor.run {
                        self.isApplied = false
                        self.isWorking = false
                        UXFeedback.error()
                    }
                }
            } else {
                // HÀNH ĐỘNG 2: TẮT (KHÔI PHỤC FILE GỐC)
                do {
                    if let validReceipt = self.receipt {
                        try DevicePatchService.restore(receipt: validReceipt, allowChangedTargets: true)
                    }
                    
                    await MainActor.run {
                        self.isApplied = false
                        self.loadCurrentStatus()
                        self.isWorking = false
                        UXFeedback.success()
                    }
                } catch {
                    await MainActor.run {
                        self.isApplied = true
                        self.isWorking = false
                        UXFeedback.error()
                    }
                }
            }
        }
    }
}
