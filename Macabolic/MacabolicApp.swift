import SwiftUI

@main
struct MacabolicApp: App {
    @StateObject private var downloadManager = DownloadManager()
    @StateObject private var appState = AppState()
    @StateObject private var languageService = LanguageService()
    @StateObject private var updateChecker = UpdateChecker()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(downloadManager)
                .environmentObject(appState)
                .environmentObject(languageService)
                .environmentObject(updateChecker)
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
                    downloadManager.stopAllDownloads()
                }
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button(languageService.s("new_download") + "...") {
                    appState.showAddDownloadSheet = true
                }
                .keyboardShortcut("n", modifiers: .command)
            }
            CommandGroup(after: .appSettings) {
                Button(languageService.s("ytdlp_update")) {
                    Task {
                        await downloadManager.ytdlpService.updateYtdlp()
                    }
                }
            }
        }
        
        #if os(macOS)
        Settings {
            PreferencesView()
                .environmentObject(downloadManager)
                .environmentObject(languageService)
                .environmentObject(updateChecker)
        }
        #endif
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
    @Published var needsRestart = false
    
    @Published var availableReleases: [GitHubRelease] = []
    
    struct GitHubRelease: Codable, Identifiable {
        let id: Int
        let tagName: String
        let assets: [GitHubAsset]
        var idString: String { tagName.replacingOccurrences(of: "v", with: "") }
        
        enum CodingKeys: String, CodingKey {
            case id
            case tagName = "tag_name"
            case assets
        }
    }

    struct GitHubAsset: Codable {
        let name: String
        let browserDownloadURL: String
        enum CodingKeys: String, CodingKey {
            case name
            case browserDownloadURL = "browser_download_url"
        }
    }

    private var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "2.1.1"
    }
    private let repoOwner = "alinuxpengui"
    private let repoName = "Macabolic"
    private var downloadURL: URL?
    
    func fetchAllReleases() async {
        let url = URL(string: "https://api.github.com/repos/\(repoOwner)/\(repoName)/releases")!
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let releases = try JSONDecoder().decode([GitHubRelease].self, from: data)
            DispatchQueue.main.async {
                self.availableReleases = releases.filter { $0.tagName != "v1.0.0" }
            }
        } catch {
            print("Releases fetch error: \(error)")
        }
    }
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
    
    func installSpecificRelease(_ release: GitHubRelease) async {
        guard let dlpAsset = release.assets.first(where: { $0.name.hasSuffix(".dmg") }),
              let url = URL(string: dlpAsset.browserDownloadURL) else { return }
        
        downloadURL = url
        await downloadAndInstallUpdate()
    }

    func downloadAndInstallUpdate() async {
        guard let url = downloadURL else { return }
        isDownloading = true
        updateProgress = 0
        
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: .main)
        let downloadTask = session.downloadTask(with: url)
        downloadTask.resume()
    }
    
    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite totalBytesExpectedToWrite: Int64) {
        Task { @MainActor in
            updateProgress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        }
    }
    
    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        let tempDmg = FileManager.default.temporaryDirectory.appendingPathComponent("Macabolic_Update.dmg")
        try? FileManager.default.removeItem(at: tempDmg)
        try? FileManager.default.moveItem(at: location, to: tempDmg)
        
        Task { @MainActor in
            isDownloading = false
            isInstalling = true
            installUpdate(dmgPath: tempDmg.path)
        }
    }
    
    private func installUpdate(dmgPath: String) {
        let appPath = Bundle.main.bundlePath
        let script = """
        (
            exec > /tmp/macabolic_update.log 2>&1
            echo "Starting update..."
            sleep 3
            MOUNT_POINT="/tmp/MacabolicUpdate_$(date +%s)"
            mkdir -p "$MOUNT_POINT"
            hdiutil mount "\(dmgPath)" -mountpoint "$MOUNT_POINT" -quiet
            
            if [ -d "$MOUNT_POINT/Macabolic.app" ]; then
                echo "Found new app, replacing..."
                rm -rf "\(appPath)"
                ditto "$MOUNT_POINT/Macabolic.app" "\(appPath)"
                hdiutil unmount "$MOUNT_POINT" -quiet
                rm -rf "$MOUNT_POINT"
                echo "Update files replaced. Waiting for app to restart."
            else
                echo "New app not found in DMG!"
                hdiutil unmount "$MOUNT_POINT" -quiet
                rm -rf "$MOUNT_POINT"
            fi
        ) & disown
        """
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", script]
        
        do {
            try process.run()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 8) {
                self.isInstalling = false
                self.needsRestart = true
            }
        } catch {
            print("Update error: \(error)")
            isInstalling = false
        }
    }
    
    func restartApp() {
        let script = "pkill Macabolic"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", script]
        
        do {
            try process.run()
        } catch {
            NSApp.terminate(nil)
        }
    }
}


@MainActor
class AppState: ObservableObject {
    @Published var showAddDownloadSheet = false
    @Published var selectedNavItem: NavigationItem = .home
    @Published var urlToDownload: String = ""
}

enum NavigationItem: String, CaseIterable, Identifiable {
    case home
    case downloading
    case queued
    case completed
    case history
    case keyring
    
    var id: String { rawValue }
    
    func title(lang: LanguageService) -> String {
        switch self {
        case .home: return lang.s("home")
        case .downloading: return lang.s("downloading")
        case .queued: return lang.s("queued")
        case .completed: return lang.s("completed")
        case .history: return lang.s("history")
        case .keyring: return lang.s("keyring")
        }
    }
    
    var icon: String {
        switch self {
        case .home: return "house"
        case .downloading: return "arrow.down.circle"
        case .queued: return "clock"
        case .completed: return "checkmark.circle"
        case .history: return "clock.arrow.circlepath"
        case .keyring: return "key"
        }
    }
}

enum Language: String, CaseIterable, Identifiable {
    case turkish = "tr"
    case english = "en"
    
    var id: String { self.rawValue }
    
    var displayName: String {
        switch self {
        case .turkish: return "Türkçe"
        case .english: return "English"
        }
    }
}

class LanguageService: ObservableObject {
    @AppStorage("selectedLanguage") var selectedLanguage: Language = .english {
        didSet {
            applyAppleLanguages(for: selectedLanguage)
        }
    }
    @AppStorage("isFirstLaunch") var isFirstLaunch: Bool = true
    
    init() {
        if UserDefaults.standard.object(forKey: "selectedLanguage") == nil {
            self.selectedLanguage = .english
        }
        
        applyAppleLanguages(for: selectedLanguage)
    }
    
    private func applyAppleLanguages(for language: Language) {
        UserDefaults.standard.set([language.rawValue], forKey: "AppleLanguages")
        UserDefaults.standard.synchronize()
    }
    
    func s(_ key: String) -> String {
        return translations[selectedLanguage]?[key] ?? key
    }
    
    private let translations: [Language: [String: String]] = [
        .turkish: [
            "home": "Ana Sayfa",
            "downloading": "İndiriliyor",
            "queued": "Kuyrukta",
            "completed": "Tamamlandı",
            "history": "Geçmiş",
            "keyring": "Kimlik Bilgileri",
            "settings": "Ayarlar",
            "new_download": "Yeni İndirme Ekle",
            "url_placeholder": "YouTube ve diğer [desteklenen](https://github.com/yt-dlp/yt-dlp/blob/master/supportedsites.md) sitelerden video indirin",
            "stat_downloading": "İndiriliyor",
            "stat_queued": "Kuyrukta",
            "stat_completed": "Tamamlandı",
            "preferences": "Ayarlar",
            "general": "Genel",
            "download": "İndirme",
            "advanced": "Gelişmiş",
            "about": "Hakkında",
            "theme": "Tema",
            "system": "Sistem",
            "light": "Açık",
            "dark": "Koyu",
            "language": "Dil",
            "save_folder": "Varsayılan Kayıt Yeri",
            "select": "Seç...",
            "updates": "Güncellemeler",
            "check_updates": "Kontrol Et",
            "update_now": "Güncelle",
            "format_settings": "Format Ayarları",
            "file_type": "Varsayılan Dosya Tipi",
            "video_quality": "Varsayılan Video Kalitesi",
            "embed_options": "Gömme Seçenekleri",
            "embed_thumbnail": "Kapak resmini göm",
            "embed_metadata": "Metadata'yı göm",
            "concurrent_downloads": "Eşzamanlı İndirmeler",
            "max": "Maksimum",
            "sponsorblock_desc": "SponsorBlock, YouTube videolarındaki sponsor segmentlerini otomatik olarak atlar.",
            "ytdlp_update": "yt-dlp'yi Güncelle",
            "update_complete": "✅ Güncelleme tamamlandı!",
            "update_error": "❌ Hata:",
            "downloading_ytdlp": "İndiriliyor...",
            "version": "Versiyon",
            "credits": "Katkıda Bulunanlar",
            "license": "Lisans",
            "license_desc": "Bu yazılım özgür yazılımdır. Değiştirebilir ve dağıtabilirsiniz.",
            "supported_sites": "Desteklenen Siteler",
            "other": "Diğer",
            "empty_downloading": "Şu an indirilen video yok",
            "empty_queued": "Kuyrukta bekleyen video yok",
            "empty_completed": "Tamamlandı indirme yok",
            "video": "Video",
            "audio": "Ses",
            "audio_quality": "Ses Kalitesi",
            "default_video_resolution": "Varsayılan Video Çözünürlüğü",
            "sponsorblock": "SponsorBlock",
            "app_updates": "Uygulama Güncellemesi",
            "latest": "En son",
            "original_project": "Orijinal Proje",
            "macos_port": "macOS Portu",
            "video_downloading": "Video İndirme",
            "view_license": "Lisansı Görüntüle",
            "app_desc": "YouTube ve binlerce siteden video indirmenizi sağlayan modern bir macOS uygulaması.",
            "extra_settings": "Ekstra Ayarlar",
            "video_url": "Video / Playlist URL",
            "url_hint": "YouTube, Instagram, X (Twitter) video veya oynatma listesi linki...",
            "no_subtitles": "Altyazı bulunamadı",
            "whats_new_title": "Macabolic v2.1.4 - Yenilikler",
            "whats_new_message": "• 🎬 Video Codec Seçimi: İndirme yapmadan önce tercih ettiğiniz video codec'ini (H.264, VP9, AV1 vb.) manuel olarak seçebilirsiniz. Varsayılan 'Auto (H.264)' seçeneği, uyumluluk için H.264'ü önceler.\n• ⚠️ Akıllı Kalite İpuçları: Yüksek çözünürlük (2K, 4K veya En İyi) seçtiğinizde beliren yeni bir bilgilendirme notu eklendi: 'Not: 1080p üzeri çözünürlükler için lütfen AV1 veya VP9 codec'ini seçin.'",
            "paste_from_clipboard": "Panodan Yapıştır",
            "fetch_info": "Bilgi Al",
            "quality": "Kalite",
            "custom_filename_hint": "Dosya adı (boş bırakılırsa video başlığı kullanılır)",
            "subtitles": "Altyazılar",
            "download_subtitles": "Altyazıları indir",
            "subtitles_selected": "%d dil seçildi",
            "languages": "Diller:",
            "all_versions": "Tüm Sürümler",
            "select_version": "Sürüm Seç...",
            "install": "Kur",
            "internal": "Dahili",
            "auto_subs": "Otomatik (Auto)",
            "embed_video": "Videoya göm",
            "embedded_data": "Gömülü Veriler",
            "metadata_desc": "Metadata göm (başlık, sanatçı vb.)",
            "split_chapters": "Bölümlere ayır",
            "sponsorblock_hint": "SponsorBlock (reklamları atla)",
            "playlist_detected": "Oynatma listesi algılandı!",
            "load_playlist": "Listeyi Yükle",
            "select_all": "Tümünü Seç",
            "deselect_all": "Seçimleri Kaldır",
            "download_selected": "Seçilenleri İndir (%d)",
            "single_video": "Sadece Bu Video",
            "entire_playlist": "Tüm Liste",
            "cancel": "İptal",
            "ok": "Tamam",
            "download_btn": "İndir",
            "clear_history": "Geçmişi Temizle",
            "history_empty": "İndirme geçmişi boş",
            "history_desc": "Tamamlanan indirmeler burada görünecek",
            "search_history": "Geçmişte ara...",
            "play": "Oynat",
            "redownload": "Yeniden İndir",
            "copy_url": "URL Kopyala",
            "add_new": "Yeni Ekle",
            "keyring_empty": "Kimlik bilgisi yok",
            "keyring_desc": "Parola korumalı içeriklere erişmek için kimlik bilgisi ekleyin",
            "add_credential": "Kimlik Bilgisi Ekle",
            "new_credential": "Yeni Kimlik Bilgisi",
            "edit_credential": "Kimlik Bilgisini Düzenle",
            "name_hint": "Ad (örn: YouTube Premium)",
            "name": "Ad",
            "username": "Kullanıcı Adı",
            "password": "Şifre",
            "save": "Kaydet",
            "fetching": "Bilgi Alınıyor",
            "processing": "İşleniyor",
            "failed": "Hata",
            "paused": "Duraklatıldı",
            "stop_all": "Tümünü Durdur",
            "finder": "Finder'da Göster",
            "retry": "Yeniden Dene",
            "stop": "Durdur",
            "log": "Log Göster",
            "remove": "Kaldır",
            "download_log": "İndirme Logu",
            "close": "Kapat",
            "no_log": "Henüz log yok...",
            "codec": "Codec",
            "auto_h264": "Otomatik (H.264)",
            "codec_warning": "Not: 1080p üzeri çözünürlükler için lütfen AV1 veya VP9 codec'ini seçin.",
            "clear": "Temizle",
            "support_btn": "Macabolic'i Destekleyin",
            "res_best": "En İyi",
            "res_worst": "En Düşük",
            "app_up_to_date": "Uygulama güncel",
            "downloading_update": "Güncelleme indiriliyor...",
            "installing_update": "Güncelleme kuruluyor...",
            "update_available_title": "Yeni Güncelleme Mevcut!",
            "update_available_message": "Macabolic'in yeni sürümü (v%@) hazır. Şimdi indirmek ister misiniz?",
            "later": "Daha Sonra",
            "restart": "Yeniden Başlat",
            "update_ready_title": "Güncelleme Kuruldu",
            "update_ready_message": "Yeni sürüm başarıyla kuruldu. Değişikliklerin etkili olması için lütfen önce bu pencereyi kapatın, ardından önce kırmızı butonla ayarları kapatın, ardından 'Command + Q' ile uygulamadan tamamen çıkıp tekrar başlatın.",
            "legal_disclaimer_title": "Yasal Uyarı & Kullanım Şartları",
            "legal_disclaimer_message": "YouTube ve diğer sitelerdeki videolar DMCA (Telif Hakkı) korumasına tabi olabilir. Macabolic geliştiricileri, bu uygulamanın yasaları ihlal eden şekilde kullanılmasını onaylamaz ve bundan sorumlu değildir.\n\nBu araç yalnızca kişisel kullanım, eğitim veya araştırma amaçlıdır. YouTube videolarını indirmek, videoda açık bir indirme butonu yoksa veya içerik indirmeye izin veren bir lisansa sahip değilse, Hizmet Şartlarını ihlal edebilir.\n\nBu uygulamayı kullanarak, indirdiğiniz tüm içeriklerin ve bunları nasıl kullandığınızın tüm sorumluluğunu üstlenmiş olursunuz. Geliştirici, bu aracın telif haklarını çiğnemek veya platform kurallarını ihlal etmek amacıyla kötüye kullanılmasını uygun görmez veya desteklemez.",
            "welcome_title": "Macabolic'e Hoş Geldiniz",
            "select_language": "Lütfen tercih ettiğiniz dili seçin:",
            "start_using": "Kullanmaya Başla",
            "language_changed_title": "Dil Değiştirildi",
            "language_changed_message": "Uygulama içi dil başarıyla değiştirildi.\n\nmacOS üst menü barının da değişmesi için lütfen önce Tamam'a basın, ardından sol üstteki kırmızı butonla ayarları kapatın ve Command+Q ile uygulamayı tamamen kapatıp yeniden açın."
        ],
        .english: [
            "home": "Home",
            "downloading": "Downloading",
            "queued": "Queued",
            "completed": "Completed",
            "history": "History",
            "keyring": "Keyring",
            "settings": "Settings",
            "new_download": "Add New Download",
            "url_placeholder": "Download video from YouTube and other [supported](https://github.com/yt-dlp/yt-dlp/blob/master/supportedsites.md) sites",
            "stat_downloading": "Downloading",
            "stat_queued": "In Queue",
            "stat_completed": "Completed",
            "preferences": "Preferences",
            "general": "General",
            "download": "Download",
            "advanced": "Advanced",
            "about": "About",
            "theme": "Theme",
            "system": "System",
            "light": "Light",
            "dark": "Dark",
            "language": "Language",
            "save_folder": "Default Save Folder",
            "select": "Select...",
            "updates": "Updates",
            "check_updates": "Check for Updates",
            "update_now": "Update Now",
            "format_settings": "Format Settings",
            "file_type": "Default File Type",
            "video_quality": "Default Video Quality",
            "embed_options": "Embedding Options",
            "embed_thumbnail": "Embed Thumbnail",
            "embed_metadata": "Embed Metadata",
            "concurrent_downloads": "Concurrent Downloads",
            "max": "Maximum",
            "sponsorblock_desc": "SponsorBlock automatically skips sponsor segments in YouTube videos.",
            "ytdlp_update": "Update yt-dlp",
            "update_complete": "✅ Update complete!",
            "update_error": "❌ Error:",
            "downloading_ytdlp": "Downloading...",
            "version": "Version",
            "credits": "Credits",
            "license": "License",
            "license_desc": "This software is free software. You can redistribute and modify it.",
            "supported_sites": "Supported Sites",
            "other": "Other",
            "empty_downloading": "No videos are currently being downloaded",
            "empty_queued": "No videos waiting in queue",
            "empty_completed": "No completed downloads",
            "video": "Video",
            "audio": "Audio",
            "audio_quality": "Audio Quality",
            "default_video_resolution": "Default Video Resolution",
            "sponsorblock": "SponsorBlock",
            "app_updates": "App Updates",
            "latest": "Latest",
            "original_project": "Original Project",
            "macos_port": "macOS Port",
            "video_downloading": "Video Downloading",
            "view_license": "View License",
            "app_desc": "A modern macOS application that allows you to download videos from YouTube and thousands of sites.",
            "extra_settings": "Extra Settings",
            "video_url": "Video / Playlist URL",
            "url_hint": "YouTube, Instagram, X (Twitter) video or playlist link...",
            "no_subtitles": "No subtitles found",
            "whats_new_title": "Macabolic v2.1.4 - What's New",
            "whats_new_message": "• 🎬 Video Codec Selection: You can now manually select your preferred video codec (H.264, VP9, AV1, etc.) before downloading. The default 'Auto (H.264)' option prioritizes H.264 for compatibility.\n• ⚠️ Smart Quality Tips: A new helpful note appears when you select high resolutions (2K, 4K, or Best): 'Note: For resolutions higher than 1080p, please select AV1 or VP9 codec.'",
            "paste_from_clipboard": "Paste from Clipboard",
            "fetch_info": "Get Video Information",
            "quality": "Quality",
            "custom_filename_hint": "Custom Filename (optional)",
            "subtitles": "Subtitles",
            "download_subtitles": "Download Subtitles",
            "subtitles_selected": "%d languages selected",
            "languages": "Languages:",
            "all_versions": "All Versions",
            "select_version": "Select Version...",
            "install": "Install",
            "internal": "Internal",
            "auto_subs": "Auto-generated",
            "embed_video": "Embed into Video",
            "embedded_data": "Embedded Data",
            "metadata_desc": "Embed Metadata (Title, Artist, etc.)",
            "split_chapters": "Split into Chapters",
            "sponsorblock_hint": "SponsorBlock (skip ads/intro)",
            "playlist_detected": "Playlist detected!",
            "load_playlist": "Load Playlist",
            "select_all": "Select All",
            "deselect_all": "Deselect All",
            "download_selected": "Download Selected (%d)",
            "single_video": "Single Video",
            "entire_playlist": "Entire Playlist",
            "cancel": "Cancel",
            "ok": "OK",
            "download_btn": "Download",
            "clear_history": "Clear History",
            "history_empty": "Download history is empty",
            "history_desc": "Completed downloads will appear here",
            "search_history": "Search in history...",
            "play": "Play",
            "redownload": "Re-download",
            "copy_url": "Copy URL",
            "add_new": "Add New",
            "keyring_empty": "No credentials",
            "keyring_desc": "Add credentials to access password-protected content",
            "add_credential": "Add Credential",
            "new_credential": "Add Credential",
            "edit_credential": "Edit Credential",
            "name_hint": "Name (e.g. YouTube Premium)",
            "name": "Name",
            "username": "Username",
            "password": "Password",
            "save": "Save",
            "fetching": "Retrieving Information...",
            "processing": "Finalizing Download...",
            "failed": "Failed",
            "paused": "Paused",
            "stop_all": "Stop All",
            "finder": "Show in Finder",
            "retry": "Retry",
            "stop": "Stop",
            "log": "Show Log",
            "remove": "Remove",
            "download_log": "Download Log",
            "close": "Close",
            "no_log": "No logs available.",
            "codec": "Codec",
            "auto_h264": "Auto (H.264)",
            "codec_warning": "Note: For resolutions higher than 1080p, please select AV1 or VP9 codec.",
            "clear": "Clear",
            "support_btn": "Support Macabolic",
            "res_best": "Best Quality",
            "res_worst": "Worst Quality",
            "app_up_to_date": "App is up to date",
            "downloading_update": "Downloading update...",
            "installing_update": "Installing update...",
            "update_available_title": "New Update Available!",
            "update_available_message": "A new version of Macabolic (v%@) is ready. Would you like to download it now?",
            "later": "Later",
            "restart": "Restart",
            "update_ready_title": "Update Installed",
            "update_ready_message": "The new version has been installed successfully. To apply the changes, please close this window first, then close the settings with the red button, and finally quit the app completely with 'Command + Q' and restart it.",
            "legal_disclaimer_title": "Legal Copyright Disclaimer",
            "legal_disclaimer_message": "Videos on YouTube and other sites may be subject to DMCA protection. The authors of Macabolic do not endorse, and are not responsible for, the use of this application in means that will violate these laws.\n\nThis tool is intended solely for personal use and educational or research purposes. Downloading videos from YouTube may violate their Terms of Service unless the video has an explicit download button or the content is licensed in a way that permits downloading.\n\nBy using this app, you assume full responsibility for any content you download and how you use it. The developer does not condone or support any misuse of this tool to infringe upon copyrights or violate platform rules.",
            "welcome_title": "Welcome to Macabolic",
            "select_language": "Please select your preferred language:",
            "start_using": "Get Started",
            "language_changed_title": "Language Changed",
            "language_changed_message": "The in-app language has been changed successfully.\n\nTo also change the macOS menu bar language, please click OK first, then close the settings using the red button in the top-left corner, and quit the app completely with Command+Q before reopening it."
        ]
    ]
}
struct WelcomeView: View {
    @EnvironmentObject var languageService: LanguageService
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 30) {
            VStack(spacing: 15) {
                Image(systemName: "hand.wave.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.accentColor)
                
                Text(languageService.s("welcome_title"))
                    .font(.largeTitle)
                    .fontWeight(.bold)
            }
            
            VStack(alignment: .leading, spacing: 10) {
                Text(languageService.s("select_language"))
                    .font(.headline)
                
                Picker("", selection: $languageService.selectedLanguage) {
                    ForEach(Language.allCases) { lang in
                        Text(lang.displayName).tag(lang)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
            .padding(.horizontal, 40)
            
            VStack(alignment: .leading, spacing: 12) {
                Text(languageService.s("legal_disclaimer_title"))
                    .font(.headline)
                
                ScrollView {
                    Text(languageService.s("legal_disclaimer_message"))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxHeight: 200)
                .padding(10)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(8)
            }
            .padding(.horizontal, 40)
            
            Button {
                UserDefaults.standard.set(true, forKey: "disclaimerAcknowledged")
                languageService.isFirstLaunch = false
                dismiss()
            } label: {
                Text(languageService.s("start_using"))
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 40)
        }
        .padding(.vertical, 40)
        .frame(width: 500)
    }
}
