import SwiftUI

@main
struct MacabolicApp: App {
    @StateObject private var downloadManager = DownloadManager()
    @StateObject private var appState = AppState()
    @StateObject private var languageService = LanguageService()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(downloadManager)
                .environmentObject(appState)
                .environmentObject(languageService)
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
        }
        #endif
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
    @AppStorage("selectedLanguage") var selectedLanguage: Language = .english
    
    init() {

        if UserDefaults.standard.object(forKey: "selectedLanguage") == nil {
            let systemLang = Locale.current.language.languageCode?.identifier ?? "en"
            if systemLang == "tr" {
                self.selectedLanguage = .turkish
            } else {
                self.selectedLanguage = .english
            }
        }
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
            "url_placeholder": "YouTube ve binlerce siteden video indirin",
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
            "default_video_resolution": "Varsayılan Video Çözünürlüğü",
            "sponsorblock": "SponsorBlock",
            "app_updates": "Uygulama Güncellemesi",
            "latest": "En son",
            "original_project": "Orijinal Proje",
            "view_license": "Lisansı Görüntüle",
            "app_desc": "YouTube ve binlerce siteden video indirmenizi sağlayan modern bir macOS uygulaması.",
            "extra_settings": "Ekstra Ayarlar",
            "video_url": "Video URL'si",
            "url_hint": "YouTube, Vimeo, Twitter ve daha fazlası...",
            "paste_from_clipboard": "Panodan Yapıştır",
            "fetch_info": "Bilgi Al",
            "quality": "Kalite",
            "custom_filename_hint": "Dosya adı (boş bırakılırsa video başlığı kullanılır)",
            "subtitles": "Altyazılar",
            "download_subtitles": "Altyazıları indir",
            "languages": "Diller:",
            "embed_video": "Videoya göm",
            "embedded_data": "Gömülü Veriler",
            "metadata_desc": "Metadata göm (başlık, sanatçı vb.)",
            "split_chapters": "Bölümlere ayır",
            "sponsorblock_hint": "SponsorBlock (reklamları atla)",
            "cancel": "İptal",
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
            "clear": "Temizle",
            "format": "Format",
            "res_best": "En İyi",
            "res_worst": "En Düşük",
            "app_up_to_date": "Uygulama güncel"
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
            "url_placeholder": "Download video from YouTube and other sites",
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
            "default_video_resolution": "Default Video Resolution",
            "sponsorblock": "SponsorBlock",
            "app_updates": "App Updates",
            "latest": "Latest",
            "original_project": "Original Project",
            "view_license": "View License",
            "app_desc": "A modern macOS application that allows you to download videos from YouTube and thousands of sites.",
            "extra_settings": "Extra Settings",
            "video_url": "Video URL",
            "url_hint": "Enter YouTube, Vimeo or Twitter URL...",
            "paste_from_clipboard": "Paste from Clipboard",
            "fetch_info": "Get Video Information",
            "quality": "Quality",
            "custom_filename_hint": "Custom Filename (optional)",
            "subtitles": "Subtitles",
            "download_subtitles": "Download Subtitles",
            "languages": "Languages:",
            "embed_video": "Embed into Video",
            "embedded_data": "Embedded Data",
            "metadata_desc": "Embed Metadata (Title, Artist, etc.)",
            "split_chapters": "Split into Chapters",
            "sponsorblock_hint": "SponsorBlock (skip ads/intro)",
            "cancel": "Cancel",
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
            "new_credential": "New Credential",
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
            "clear": "Clear",
            "format": "Format",
            "res_best": "Best Quality",
            "res_worst": "Worst Quality",
            "app_up_to_date": "App is up to date"
        ]
    ]
}
