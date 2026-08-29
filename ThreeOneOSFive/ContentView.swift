import SwiftUI
import UIKit
import AudioToolbox

struct ContentView: View {
    @Environment(\.appLanguage) private var language
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @EnvironmentObject private var patchDraftCoordinator: PatchDraftCoordinator
    @EnvironmentObject private var patchStore: PatchProjectStore
    @EnvironmentObject private var repositoryStore: PackageRepositoryStore
    @AppStorage(FeatureVisibility.developerModeStorageKey)
    private var developerModeEnabled = false
     
    // Yêu cầu nhập lại key mỗi khi mở app
    @State private var isUnlocked = false

    @State private var tabNavigation: AppTabNavigationState
    @State private var showSettings = false
    @State private var showLogs = false

    init() {
#if targetEnvironment(simulator)
        let arguments = ProcessInfo.processInfo.arguments
        let initialTab: Int
        if arguments.contains("--simulate-new-tab") {
            initialTab = 1
        } else if arguments.contains("--simulate-sources-tab") {
            initialTab = 2
        } else if arguments.contains("--simulate-installed-tab")
                    || arguments.contains("--simulate-patch-tab")
                    || arguments.contains("--simulate-wallpaper-tab") {
            initialTab = 3
        } else if arguments.contains("--simulate-files-tab") {
            initialTab = 4
        } else if arguments.contains("--simulate-search-tab") {
            initialTab = 5
        } else {
            initialTab = 0
        }
        _tabNavigation = State(initialValue: AppTabNavigationState(selectedTab: initialTab))
        _showSettings = State(
            initialValue: arguments.contains("--simulate-settings")
        )
         
        if arguments.contains("--bypass-lock") {
            _isUnlocked = State(initialValue: true)
        }
#else
        _tabNavigation = State(initialValue: AppTabNavigationState())
#endif
    }

    var body: some View {
        Group {
            if isUnlocked {
                mainAppContent
            } else {
                KeyLockView(isUnlocked: $isUnlocked)
            }
        }
    }

    private var mainAppContent: some View {
        Group {
            if horizontalSizeClass == .regular {
                regularLayout
            } else {
                compactLayout
            }
        }
        .tint(AppTheme.accent)
        .imageScale(.small)
        .onChange(of: patchDraftCoordinator.request?.id) { requestID in
            if requestID != nil { tabNavigation.select(AppSection.installed.rawValue) }
        }
        .onChange(of: patchDraftCoordinator.importRequest?.id) { requestID in
            if requestID != nil { tabNavigation.select(AppSection.installed.rawValue) }
        }
        .onChange(of: developerModeEnabled) { _ in
            tabNavigation.reconcileSelection(with: featureVisibility)
        }
        .onAppear {
            tabNavigation.reconcileSelection(with: featureVisibility)
        }
        .sheet(isPresented: $showSettings) { SettingsView() }
        .sheet(isPresented: $showLogs) { LogView() }
        .patchStorePresentation(patchStore)
        .repositoryStorePresentation(repositoryStore, patchStore: patchStore)
    }

    private var compactLayout: some View {
        TabView(selection: tabSelection) {
            ForEach(featureVisibility.visibleSections) { section in
                sectionContent(section)
                    .tabItem {
                        CompactTabLabel(
                            title: language.text(section.titleKey),
                            systemImage: section.systemImage
                        )
                    }
                    .tag(section.rawValue)
            }
        }
    }

    private var regularLayout: some View {
        NavigationSplitView {
            List {
                ForEach(featureVisibility.visibleSections) { section in
                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            tabNavigation.select(section.rawValue)
                        }
                    } label: {
                        Label(language.text(section.titleKey), systemImage: section.systemImage)
                            .fontWeight(section.rawValue == tabNavigation.selectedTab ? .semibold : .regular)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(
                        section.rawValue == tabNavigation.selectedTab
                            ? AppTheme.accent.opacity(0.14)
                            : Color.clear
                    )
                    .accessibilityAddTraits(
                        section.rawValue == tabNavigation.selectedTab ? .isSelected : []
                    )
                }
            }
            .navigationTitle("3105")
            .navigationSplitViewColumnWidth(min: 210, ideal: 240, max: 300)
        } detail: {
            sectionContent(selectedVisibleSection)
                .id(selectedVisibleSection.rawValue)
        }
        .navigationSplitViewStyle(.balanced)
    }

    @ViewBuilder
    private func sectionContent(_ section: AppSection) -> some View {
        switch section {
        case .home:
            RepositoryHomeView(onOpenSettings: openSettings, onOpenLogs: openLogs)
        case .new:
            RepositoryNewView(onOpenSettings: openSettings, onOpenLogs: openLogs)
        case .sources:
            RepositorySourcesView(onOpenSettings: openSettings, onOpenLogs: openLogs)
        case .installed:
            PatchProjectsView(onOpenSettings: openSettings, onOpenLogs: openLogs)
        case .files:
            AppDataBrowserView(tabSession: filesTabSession, onOpenSettings: openSettings, onOpenLogs: openLogs)
        case .search:
            RepositorySearchView(onOpenSettings: openSettings, onOpenLogs: openLogs)
        }
    }

    private var tabSelection: Binding<Int> {
        Binding(
            get: { tabNavigation.selectedTab },
            set: { tabNavigation.select($0) }
        )
    }

    private var filesTabSession: Binding<FilesTabSession> {
        Binding(
            get: { tabNavigation.filesTabs },
            set: { tabNavigation.setFilesTabs($0) }
        )
    }

    private var featureVisibility: FeatureVisibility {
        FeatureVisibility(developerModeEnabled: developerModeActive)
    }

    private var developerModeActive: Bool {
#if targetEnvironment(simulator)
        developerModeEnabled
            || ProcessInfo.processInfo.arguments.contains("--simulate-developer-mode")
            || ProcessInfo.processInfo.arguments.contains("--simulate-files-tab")
#else
        developerModeEnabled
#endif
    }

    private var selectedVisibleSection: AppSection {
        let selected = AppSection(rawValue: tabNavigation.selectedTab)
        return selected.flatMap {
            featureVisibility.isVisible($0) ? $0 : nil
        } ?? .home
    }

    private func openSettings() { showSettings = true }
    private func openLogs() { showLogs = true }
}

// MARK: - Màn hình Khóa & Nhập Key (Đồng bộ Dark-Neon chuẩn Website)
private struct KeyLockView: View {
    @Binding var isUnlocked: Bool
    @State private var keyCode: String = ""
    @State private var deviceID: String = "APEX-ZENITH-SOLITUDE-74B2"
    @State private var clientIP: String = "113.160.225.12"
    @State private var showAlert: Bool = false
    @State private var alertMessage: String = ""
    @State private var rotationAngle: Double = 0.0
    @State private var scanlineOffset: CGFloat = -100

    private func playClickSound() {
        AudioServicesPlaySystemSound(1104)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            // Hiệu ứng hạt bay lấp lánh nền
            ParticleCanvasView()
            
            // Hiệu ứng tia quét ngang (Scanline)
            VStack {
                Rectangle()
                    .fill(LinearGradient(colors: [.clear, .white.opacity(0.08), .clear], startPoint: .top, endPoint: .bottom))
                    .frame(height: 80)
                    .offset(y: scanlineOffset)
                    .onAppear {
                        withAnimation(.linear(duration: 6).repeatForever(autoreverses: false)) {
                            scanlineOffset = 900
                        }
                    }
                Spacer()
            }
            .allowsHitTesting(false)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    
                    // MARK: - AVATAR & RADAR XOAY TRÒN (GET TRỰC TIẾP TỪ LINK YÊU CẦU)
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .stroke(
                                    AngularGradient(gradient: Gradient(colors: [.clear, .white, .clear]), center: .center),
                                    lineWidth: 2.5
                                )
                                .frame(width: 104, height: 104)
                                .rotationEffect(.degrees(rotationAngle))
                                .onAppear {
                                    withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
                                        rotationAngle = 360
                                    }
                                }
                                .shadow(color: .white, radius: 10, x: 0, y: 0)
                            
                            AsyncImage(url: URL(string: "https://solitudepremium.click/tipa/solitude/li.jpg")) { phase in
                                switch phase {
                                case .empty:
                                    ProgressView()
                                        .tint(.white)
                                        .frame(width: 90, height: 90)
                                    
                                case .success(let image):
                                    image
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 90, height: 90)
                                        .clipShape(Circle())
                                        .overlay(Circle().stroke(Color.white, lineWidth: 2))
                                        .shadow(color: .white.opacity(0.6), radius: 15)
                                    
                                case .failure(_):
                                    Image(systemName: "bolt.fill")
                                        .font(.system(size: 38))
                                        .foregroundColor(.white)
                                        .frame(width: 90, height: 90)
                                        .background(Color.black)
                                        .clipShape(Circle())
                                        .overlay(Circle().stroke(Color.white, lineWidth: 2))
                                    
                                @unknown default:
                                    EmptyView()
                                }
                            }
                        }
                        .padding(.top, 25)
                        
                        Text("ZENITH SOLITUDE")
                            .font(.system(size: 24, weight: .black, design: .monospaced))
                            .tracking(5)
                            .foregroundColor(.white)
                            .shadow(color: .white, radius: 12, x: 0, y: 0)
                        
                        HStack(spacing: 8) {
                            Circle().frame(width: 3, height: 3).foregroundColor(.white).shadow(color: .white, radius: 6)
                            Text("VERSION 23.7.20 • APEX")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .tracking(3)
                                .foregroundColor(.white.opacity(0.8))
                            Circle().frame(width: 3, height: 3).foregroundColor(.white).shadow(color: .white, radius: 6)
                        }
                    }

                    // MARK: - MAIN GLASS CARD
                    VStack(spacing: 16) {
                        
                        // ANTI-BAN BOX
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 8, height: 8)
                                    .shadow(color: .white, radius: 8)
                                Text("HEADLOCK CENTER 23.7.20")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundColor(.white)
                                Spacer()
                                Text("ANTIBAN")
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            
                            HStack {
                                Text(clientIP)
                                    .font(.system(size: 11, design: .monospaced))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Color.black.opacity(0.6))
                                    .cornerRadius(6)
                                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.35), lineWidth: 1))
                                    .foregroundColor(.white)
                                
                                Spacer()
                                
                                Button(action: {
                                    playClickSound()
                                    clientIP = "113.160.225.12"
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "arrow.clockwise")
                                        Text("Lấy lại IP")
                                    }
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 6)
                                    .background(Color.white.opacity(0.08))
                                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.35), lineWidth: 1))
                                    .foregroundColor(.white)
                                }
                            }
                            
                            HStack {
                                Text("Device ID:")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.white.opacity(0.5))
                                Text(deviceID)
                                    .font(.system(size: 9, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.85))
                                    .lineLimit(1)
                            }
                        }
                        .padding(14)
                        .background(Color.black.opacity(0.65))
                        .cornerRadius(14)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(LinearGradient(colors: [.white.opacity(0.6), .white.opacity(0.15)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.2)
                        )

                        // INPUT KEY FIELD
                        HStack(spacing: 10) {
                            Image(systemName: "key.fill")
                                .foregroundColor(.white.opacity(0.7))
                                .font(.system(size: 13))
                                .padding(.leading, 8)
                            
                            TextField("Nhập Key (VIP / FREE)...", text: $keyCode)
                                .font(.system(size: 13, design: .monospaced))
                                .foregroundColor(.white)
                                .accentColor(.white)
                            
                            Button(action: {
                                playClickSound()
                                if let pasted = UIPasteboard.general.string {
                                    keyCode = pasted.trimmingCharacters(in: .whitespacesAndNewlines)
                                }
                            }) {
                                Image(systemName: "doc.on.clipboard")
                                    .font(.system(size: 12, weight: .semibold))
                                    .padding(8)
                                    .background(Color.white.opacity(0.12))
                                    .cornerRadius(8)
                                    .foregroundColor(.white)
                            }
                            .padding(.trailing, 4)
                        }
                        .padding(.vertical, 10)
                        .background(Color.black.opacity(0.75))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(LinearGradient(colors: [.white.opacity(0.7), .white.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.5)
                        )
                        .shadow(color: .white.opacity(0.15), radius: 10)

                        // NÚT LOGIN HỆ THỐNG
                        Button(action: {
                            playClickSound()
                            let trimmedKey = keyCode.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !trimmedKey.isEmpty {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    isUnlocked = true
                                }
                            } else {
                                alertMessage = "Vui lòng nhập Key kích hoạt hợp lệ!"
                                showAlert = true
                            }
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.right.square.fill")
                                Text("LOGIN HỆ THỐNG")
                            }
                            .font(.system(size: 13, weight: .black, design: .monospaced))
                            .tracking(2)
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(
                                LinearGradient(colors: [.white, Color(white: 0.82)], startPoint: .top, endPoint: .bottom)
                            )
                            .cornerRadius(12)
                            .shadow(color: .white.opacity(0.7), radius: 15, x: 0, y: 0)
                        }

                        // SUB MENU (ĐÃ XÓA Ô TẢI CERT & XÓA Ô TÌM KEY THEO IP)
                        Button(action: { playClickSound() }) {
                            HStack {
                                Image(systemName: "key.horizontal")
                                Text("LẤY KEY MỚI TẠI ĐÂY")
                            }
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(10)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.35), lineWidth: 1))
                        }

                        Text("Headlock version 23.7.20 By Zenith Solitude")
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .tracking(1)
                            .foregroundColor(.white.opacity(0.5))
                            .padding(.top, 4)
                    }
                    .padding(20)
                    .background(.ultraThinMaterial)
                    .background(Color.black.opacity(0.75))
                    .cornerRadius(24)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(LinearGradient(colors: [.white.opacity(0.6), .white.opacity(0.15)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.5)
                    )
                    .shadow(color: .black.opacity(0.9), radius: 35, x: 0, y: 15)
                    .padding(.horizontal, 16)
                }
                .padding(.bottom, 30)
            }
        }
        .alert(isPresented: $showAlert) {
            Alert(title: Text("Thông báo"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
        }
    }
}

// MARK: - Hiệu ứng hạt bay lấp lánh
private struct ParticleCanvasView: View {
    var body: some View {
        TimelineView(.animation) { context in
            Canvas { graphicsContext, size in
                let time = context.date.timeIntervalSinceReferenceDate
                for i in 0..<70 {
                    let seed = Double(i) * 42.0
                    let x = (sin(time * 0.4 + seed) * 0.5 + 0.5) * size.width
                    let y = size.height - fmod(seed * 20.0 + time * 35.0, size.height)
                    let particleSize = CGFloat(fmod(seed, 2.5) + 1.0)
                    let opacity = Double(fmod(seed, 0.7) + 0.3)
                    
                    let rect = CGRect(x: x, y: y, width: particleSize, height: particleSize)
                    graphicsContext.fill(Path(ellipseIn: rect), with: .color(.white.opacity(opacity)))
                }
            }
        }
        .allowsHitTesting(false)
    }
}

private struct CompactTabLabel: View {
    let title: String
    let systemImage: String

    @ViewBuilder
    var body: some View {
        if let image = UIImage(
            systemName: systemImage,
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 17, weight: .medium)
        )?.withRenderingMode(.alwaysTemplate) {
            Image(uiImage: image)
        } else {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .medium))
        }
        Text(title)
    }
}

private extension AppSection {
    var titleKey: String {
        switch self {
        case .home: return "tab.home"
        case .new: return "tab.new"
        case .sources: return "tab.sources"
        case .installed: return "tab.installed"
        case .files: return "tab.files"
        case .search: return "tab.search"
        }
    }

    var systemImage: String {
        switch self {
        case .home: return "house.fill"
        case .new: return "clock.fill"
        case .sources: return "shippingbox.fill"
        case .installed: return "tray.full.fill"
        case .files: return "folder.fill"
        case .search: return "magnifyingglass"
        }
    }
}
