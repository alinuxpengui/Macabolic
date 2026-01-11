import SwiftUI
import AppKit

struct PreferencesView: View {
    @AppStorage("theme") private var theme: String = "system"
    @AppStorage("defaultSaveFolder") private var defaultSaveFolder: String = ""
    @AppStorage("maxConcurrentDownloads") private var maxConcurrentDownloads: Int = 3
    @AppStorage("embedThumbnail") private var embedThumbnail: Bool = true
    @AppStorage("embedMetadata") private var embedMetadata: Bool = true
    @AppStorage("defaultFileType") private var defaultFileType: String = "mp4"
    @AppStorage("defaultVideoResolution") private var defaultVideoResolution: String = "best"
    @AppStorage("sponsorBlock") private var sponsorBlock: Bool = false
    
    @EnvironmentObject var languageService: LanguageService
    @StateObject private var updateChecker = UpdateChecker()
    @State private var isUpdatingYtdlp = false
    @State private var ytdlpUpdateMessage: String?
    
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {

                Spacer()
                    .frame(height: 44)
                
                TabView {
                    generalTab
                        .tabItem {
                            Label(languageService.s("general"), systemImage: "gear")
                        }
                    
                    downloadTab
                        .tabItem {
                            Label(languageService.s("download"), systemImage: "arrow.down.circle")
                        }
                    
                    advancedTab
                        .tabItem {
                            Label(languageService.s("advanced"), systemImage: "wrench.and.screwdriver")
                        }
                    
                    aboutTab
                        .tabItem {
                            Label(languageService.s("about"), systemImage: "info.circle")
                        }
                }
            }
            

            Button {
                dismiss()
            } label: {
                CloseButton()
            }
            .buttonStyle(.plain)
            .padding(16)
        }
        .frame(width: 550, height: 450)
        .onChange(of: theme) { newValue in
            applyTheme(newValue)
        }
        .onAppear {
            applyTheme(theme)
        }
    }
    

    struct CloseButton: View {
        @State private var isHovering = false
        
        var body: some View {
            Circle()
                .fill(Color.red)
                .frame(width: 12, height: 12)
                .overlay(
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.black.opacity(0.5))
                        .opacity(isHovering ? 1 : 0)
                )
                .onHover { hovering in
                    isHovering = hovering
                }
        }
    }
    

    
    private func applyTheme(_ theme: String) {
        switch theme {
        case "light":
            NSApp.appearance = NSAppearance(named: .aqua)
        case "dark":
            NSApp.appearance = NSAppearance(named: .darkAqua)
        default:
            NSApp.appearance = nil
        }
    }
    

    
    private var generalTab: some View {
        Form {
            Section(languageService.s("theme")) {
                Picker(languageService.s("theme"), selection: $theme) {
                    Text(languageService.s("system")).tag("system")
                    Text(languageService.s("light")).tag("light")
                    Text(languageService.s("dark")).tag("dark")
                }
                .pickerStyle(.segmented)
            }
            
            Section(languageService.s("language")) {
                Picker(languageService.s("language"), selection: $languageService.selectedLanguage) {
                    ForEach(Language.allCases) { lang in
                        Text(lang.displayName).tag(lang)
                    }
                }
            }
            
            Section(languageService.s("save_folder")) {
                HStack {
                    TextField(languageService.s("save_folder"), text: .constant(defaultSaveFolder.isEmpty ? (languageService.selectedLanguage == .turkish ? "İndirilenler" : "Downloads") : defaultSaveFolder))
                        .textFieldStyle(.roundedBorder)
                        .disabled(true)
                    
                    Button(languageService.s("select")) {
                        selectFolder()
                    }
                    
                    if !defaultSaveFolder.isEmpty {
                        Button {
                            defaultSaveFolder = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            
            Section(languageService.s("updates")) {
                HStack {
                    VStack(alignment: .leading) {
                        Text(languageService.s("app_updates"))
                        if let latestVersion = updateChecker.latestVersion {
                            Text("\(languageService.s("latest")): \(latestVersion)")
                                .font(.caption)
                                .foregroundColor(updateChecker.hasUpdate ? .orange : .green)
                        }
                    }
                    Spacer()
                    if updateChecker.isChecking {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else if updateChecker.hasUpdate {
                        VStack(alignment: .trailing, spacing: 8) {
                            if updateChecker.isDownloading {
                                HStack {
                                    ProgressView(value: updateChecker.updateProgress)
                                        .controlSize(.small)
                                    Text(languageService.s("downloading_update"))
                                        .font(.caption)
                                }
                                .frame(width: 200)
                            } else if updateChecker.isInstalling {
                                Text(languageService.s("installing_update"))
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            } else {
                                Button(languageService.s("update_now")) {
                                    Task {
                                        await updateChecker.downloadAndInstallUpdate()
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        }
                    } else if updateChecker.showUpToDateMessage {
                        Text(languageService.s("app_up_to_date"))
                            .font(.caption)
                            .foregroundColor(.green)
                    } else {
                        Button(languageService.s("check_updates")) {
                            Task {
                                await updateChecker.checkForUpdates()
                            }
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
    

    
    private var downloadTab: some View {
        Form {
            Section(languageService.s("format_settings")) {
                Picker(languageService.s("file_type"), selection: $defaultFileType) {
                    ForEach(MediaFileType.allCases) { type in
                        Text(type.rawValue).tag(type.rawValue.lowercased())
                    }
                }
                
                Picker(languageService.s("video_quality"), selection: $defaultVideoResolution) {
                    ForEach(VideoResolution.allCases) { res in
                        Text(res.title(lang: languageService)).tag(res.rawValue)
                    }
                }
            }
            
            Section(languageService.s("embed_options")) {
                Toggle(languageService.s("embed_thumbnail"), isOn: $embedThumbnail)
                Toggle(languageService.s("embed_metadata"), isOn: $embedMetadata)
            }
            
            Section(languageService.s("concurrent_downloads")) {
                Stepper("\(languageService.s("max")): \(maxConcurrentDownloads)", value: $maxConcurrentDownloads, in: 1...10)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
    

    
    private var advancedTab: some View {
        Form {
            Section("SponsorBlock") {
                Toggle(languageService.s("sponsorblock_desc"), isOn: $sponsorBlock)
            }
            
            Section("yt-dlp") {
                HStack {
                    VStack(alignment: .leading) {
                        Text(languageService.s("ytdlp_update"))
                        if let message = ytdlpUpdateMessage {
                            Text(message)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                    if isUpdatingYtdlp {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text(languageService.s("downloading_ytdlp"))
                            .font(.caption)
                    } else {
                        Button(languageService.s("update_now")) {
                            updateYtdlp()
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
    

    
    private var aboutTab: some View {
        ScrollView {
            VStack(spacing: 16) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.linearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                
                Text("Macabolic")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text(languageService.s("version") + " 1.2.2")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text(languageService.s("app_desc"))
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                
                Divider()
                    .padding(.horizontal, 40)
                

                GroupBox(languageService.s("credits")) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(languageService.s("original_project") + ":")
                            Spacer()
                            Link("Parabolic by Nickvision", destination: URL(string: "https://github.com/NickvisionApps/Parabolic")!)
                                .font(.caption)
                        }
                        HStack {
                            Text("macOS Port:")
                            Spacer()
                            Text("alinuxpengui")
                                .font(.caption)
                        }
                        HStack {
                            Text("Video İndirme:")
                            Spacer()
                            Link("yt-dlp", destination: URL(string: "https://github.com/yt-dlp/yt-dlp")!)
                                .font(.caption)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .padding(.horizontal, 20)
                

                GroupBox(languageService.s("license")) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("GNU General Public License v3.0")
                            .font(.caption)
                            .fontWeight(.semibold)
                        Text(languageService.s("license_desc"))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Link(languageService.s("view_license"), destination: URL(string: "https://www.gnu.org/licenses/gpl-3.0.html")!)
                            .font(.caption)
                    }
                    .padding(.vertical, 4)
                }
                .padding(.horizontal, 20)
                
                HStack(spacing: 16) {
                    Link(destination: URL(string: "https://github.com/alinuxpengui/Macabolic")!) {
                        Label("GitHub", systemImage: "link")
                    }
                    Link(destination: URL(string: "https://github.com/yt-dlp/yt-dlp/blob/master/supportedsites.md")!) {
                        Label(languageService.s("supported_sites"), systemImage: "globe")
                    }
                }
                .font(.caption)
                
                Text("alinuxpengui • bytemeowster")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding()
        }
    }
    

    
    private func selectFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = "Seç"
        
        if panel.runModal() == .OK, let url = panel.url {
            defaultSaveFolder = url.path
        }
    }
    
    private func updateYtdlp() {
        isUpdatingYtdlp = true
        ytdlpUpdateMessage = nil
        
        Task {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let macabolicDir = appSupport.appendingPathComponent("Macabolic")
            let destination = macabolicDir.appendingPathComponent("yt-dlp")
            
            do {
                try FileManager.default.createDirectory(at: macabolicDir, withIntermediateDirectories: true)
                
                let downloadURL = URL(string: "https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_macos")!
                let (tempURL, _) = try await URLSession.shared.download(from: downloadURL)
                
                if FileManager.default.fileExists(atPath: destination.path) {
                    try FileManager.default.removeItem(at: destination)
                }
                
                try FileManager.default.moveItem(at: tempURL, to: destination)
                try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: destination.path)
                
                await MainActor.run {
                    ytdlpUpdateMessage = "✅ Güncelleme tamamlandı!"
                    isUpdatingYtdlp = false
                }
            } catch {
                await MainActor.run {
                    ytdlpUpdateMessage = "❌ Hata: \(error.localizedDescription)"
                    isUpdatingYtdlp = false
                }
            }
        }
    }
}



@MainActor
class UpdateChecker: NSObject, ObservableObject, URLSessionDownloadDelegate {
    @Published var isChecking = false
    @Published var hasUpdate = false
    @Published var latestVersion: String?
    @Published var showUpToDateMessage = false
    @Published var isDownloading = false
    @Published var updateProgress: Double = 0
    @Published var isInstalling = false
    
    private let currentVersion = "1.2.2"
    private let repoOwner = "alinuxpengui"
    private let repoName = "Macabolic"
    private var downloadURL: URL?
    
    func checkForUpdates() async {
        isChecking = true
        let url = URL(string: "https://api.github.com/repos/\(repoOwner)/\(repoName)/releases/latest")!
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let tagName = json["tag_name"] as? String,
               let assets = json["assets"] as? [[String: Any]] {
                
                latestVersion = tagName.replacingOccurrences(of: "v", with: "")
                hasUpdate = (latestVersion ?? currentVersion) != currentVersion
                

                if let dlpAsset = assets.first(where: { ($0["name"] as? String)?.hasSuffix(".dmg") == true }),
                   let downloadUrlStr = dlpAsset["browser_download_url"] as? String {
                    downloadURL = URL(string: downloadUrlStr)
                }
                
                if !hasUpdate {
                    showUpToDateMessage = true
                    try? await Task.sleep(nanoseconds: 3 * 1_000_000_000)
                    showUpToDateMessage = false
                }
            }
        } catch {
            latestVersion = currentVersion
            hasUpdate = false
        }
        isChecking = false
    }
    
    func downloadAndInstallUpdate() async {
        guard let url = downloadURL else { return }
        isDownloading = true
        updateProgress = 0
        
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: .main)
        let downloadTask = session.downloadTask(with: url)
        downloadTask.resume()
    }
    

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        updateProgress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        isDownloading = false
        isInstalling = true
        
        let tempDmg = FileManager.default.temporaryDirectory.appendingPathComponent("Macabolic_Update.dmg")
        try? FileManager.default.removeItem(at: tempDmg)
        try? FileManager.default.moveItem(at: location, to: tempDmg)
        
        installUpdate(dmgPath: tempDmg.path)
    }
    
    private func installUpdate(dmgPath: String) {
        let appPath = Bundle.main.bundlePath
        let script = """
        sleep 2
        hdiutil mount "\(dmgPath)" -mountpoint /tmp/MacabolicUpdateMount -quiet
        if [ -d "/tmp/MacabolicUpdateMount/Macabolic.app" ]; then
            rm -rf "\(appPath)"
            cp -R "/tmp/MacabolicUpdateMount/Macabolic.app" "\(appPath)"
            hdiutil unmount /tmp/MacabolicUpdateMount -quiet
            open "\(appPath)"
        fi
        """
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", script]
        
        do {
            try process.run()
            NSApplication.shared.terminate(nil)
        } catch {
            print("Guncelleme hatasi: \(error)")
            isInstalling = false
        }
    }
}

#Preview {
    PreferencesView()
}
