import Foundation


@MainActor
class Download: ObservableObject, Identifiable {
    let id: UUID
    let url: String
    let options: DownloadOptions
    
    @Published var title: String
    @Published var duration: String?
    @Published var thumbnailURL: URL?
    @Published var status: DownloadStatus
    @Published var progress: Double
    @Published var speed: String?
    @Published var eta: String?
    @Published var filePath: URL?
    @Published var errorMessage: String?
    @Published var log: String = ""
    
    var displayProgress: String {
        let percentage = Int(progress * 100)
        if let speed = speed, let eta = eta {
            return "\(percentage)% • \(speed) • \(eta)"
        }
        return "\(percentage)%"
    }
    
    init(url: String, options: DownloadOptions, title: String = "___FETCHING___") {
        self.id = UUID()
        self.url = url
        self.options = options
        self.title = title
        self.status = .queued
        self.progress = 0
    }
}


enum DownloadStatus: String, Codable {
    case fetching = "Bilgi Alınıyor"
    case queued = "Kuyrukta"
    case downloading = "İndiriliyor"
    case processing = "İşleniyor"
    case completed = "Tamamlandı"
    case failed = "Hata"
    case stopped = "Durduruldu"
    case paused = "Duraklatıldı"
    
    func title(lang: LanguageService) -> String {
        switch self {
        case .fetching: return lang.s("fetching")
        case .queued: return lang.s("queued")
        case .downloading: return lang.s("downloading")
        case .processing: return lang.s("processing")
        case .completed: return lang.s("completed")
        case .failed: return lang.s("failed")
        case .stopped: return lang.s("stopped")
        case .paused: return lang.s("paused")
        }
    }
    
    var color: String {
        switch self {
        case .queued: return "orange"
        case .fetching: return "blue"
        case .downloading: return "blue"
        case .processing: return "purple"
        case .paused: return "yellow"
        case .completed: return "green"
        case .failed: return "red"
        case .stopped: return "gray"
        }
    }
}


struct DownloadOptions: Codable {
    var saveFolder: URL
    var fileType: MediaFileType
    var videoFormat: VideoFormat?
    var audioFormat: AudioFormat?
    var videoResolution: VideoResolution?
    var audioQuality: AudioQuality?
    var downloadSubtitles: Bool
    var subtitleLanguages: [String]
    var embedSubtitles: Bool
    var downloadThumbnail: Bool
    var embedThumbnail: Bool
    var embedMetadata: Bool
    var splitChapters: Bool
    var sponsorBlock: Bool
    var timeFrameStart: String?
    var timeFrameEnd: String?
    var customFilename: String?
    var credential: Credential?
    
    static var `default`: DownloadOptions {
        DownloadOptions(
            saveFolder: FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!,
            fileType: .mp4,
            downloadSubtitles: false,
            subtitleLanguages: ["tr", "en"],
            embedSubtitles: false,
            downloadThumbnail: false,
            embedThumbnail: true,
            embedMetadata: true,
            splitChapters: false,
            sponsorBlock: false
        )
    }
}


enum MediaFileType: String, Codable, CaseIterable, Identifiable {
    case mp4 = "MP4"
    case webm = "WebM"
    case mkv = "MKV"
    case mp3 = "MP3"
    case opus = "Opus"
    case flac = "FLAC"
    case wav = "WAV"
    case m4a = "M4A"
    
    var id: String { rawValue }
    
    var isVideo: Bool {
        switch self {
        case .mp4, .webm, .mkv: return true
        default: return false
        }
    }
    
    var isAudio: Bool {
        !isVideo
    }
    
    var fileExtension: String {
        rawValue.lowercased()
    }
    
    static var videoTypes: [MediaFileType] {
        [.mp4, .webm, .mkv]
    }
    
    static var audioTypes: [MediaFileType] {
        [.mp3, .opus, .flac, .wav, .m4a]
    }
}


enum AudioQuality: String, Codable, CaseIterable, Identifiable {
    case best
    case q320 = "320kbps"
    case q256 = "256kbps"
    case q192 = "192kbps"
    case q128 = "128kbps"
    
    var id: String { rawValue }
    
    func title(lang: LanguageService) -> String {
        switch self {
        case .best: return lang.s("res_best")
        default: return rawValue
        }
    }
    
    var ytdlpValue: String {
        switch self {
        case .best: return "0"
        case .q320: return "320K"
        case .q256: return "256K"
        case .q192: return "192K"
        case .q128: return "128K"
        }
    }
}


struct VideoFormat: Codable, Identifiable, Hashable {
    let id: String
    let ext: String
    let resolution: String?
    let fps: Int?
    let vcodec: String?
    let filesize: Int64?
    
    var displayName: String {
        var parts: [String] = []
        if let res = resolution { parts.append(res) }
        if let fps = fps { parts.append("\(fps)fps") }
        if let codec = vcodec { parts.append(codec) }
        return parts.isEmpty ? id : parts.joined(separator: " • ")
    }
}


struct AudioFormat: Codable, Identifiable, Hashable {
    let id: String
    let ext: String
    let abr: Int?
    let acodec: String?
    let filesize: Int64?
    
    var displayName: String {
        var parts: [String] = []
        if let abr = abr { parts.append("\(abr)kbps") }
        if let codec = acodec { parts.append(codec) }
        return parts.isEmpty ? id : parts.joined(separator: " • ")
    }
}


enum VideoResolution: String, Codable, CaseIterable, Identifiable {
    case best
    case r2160p
    case r1440p
    case r1080p
    case r720p
    case r480p
    case r360p
    case r240p
    case worst
    
    var id: String { rawValue }
    
    func title(lang: LanguageService) -> String {
        switch self {
        case .best: return lang.s("res_best")
        case .r2160p: return "2160p (4K)"
        case .r1440p: return "1440p (2K)"
        case .r1080p: return "1080p (Full HD)"
        case .r720p: return "720p (HD)"
        case .r480p: return "480p"
        case .r360p: return "360p"
        case .r240p: return "240p"
        case .worst: return lang.s("res_worst")
        }
    }
    
    var ytdlpValue: String {
        switch self {
        case .best: return "bestvideo"
        case .r2160p: return "bestvideo[height<=2160]"
        case .r1440p: return "bestvideo[height<=1440]"
        case .r1080p: return "bestvideo[height<=1080]"
        case .r720p: return "bestvideo[height<=720]"
        case .r480p: return "bestvideo[height<=480]"
        case .r360p: return "bestvideo[height<=360]"
        case .r240p: return "bestvideo[height<=240]"
        case .worst: return "worstvideo"
        }
    }
}


struct Credential: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    var username: String
    var password: String
    
    init(name: String, username: String, password: String) {
        self.id = UUID()
        self.name = name
        self.username = username
        self.password = password
    }
}


struct MediaInfo: Codable {
    let id: String
    let title: String
    let description: String?
    let thumbnail: String?
    let duration: Double?
    let uploader: String?
    let uploadDate: String?
    let viewCount: Int?
    let likeCount: Int?
    let formats: [MediaFormat]?
    let subtitles: [String: [SubtitleInfo]]?
    let automaticCaptions: [String: [SubtitleInfo]]?
    let chapters: [ChapterInfo]?
    let playlist: String?
    let playlistIndex: Int?
    let playlistCount: Int?
    
    var durationString: String? {
        guard let duration = duration else { return nil }
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
    
    var thumbnailURL: URL? {
        if let thumbnail = thumbnail, !thumbnail.isEmpty {
            return URL(string: thumbnail)
        }
        
        if id.count == 11 {
            return URL(string: "https://i.ytimg.com/vi/\(id)/mqdefault.jpg")
        }
        
        return nil
    }
    
    enum CodingKeys: String, CodingKey {
        case id, title, description, thumbnail, duration, uploader, formats, subtitles, chapters, playlist
        case automaticCaptions = "automatic_captions"
        case uploadDate = "upload_date"
        case viewCount = "view_count"
        case likeCount = "like_count"
        case playlistIndex = "playlist_index"
        case playlistCount = "playlist_count"
    }
}

struct MediaFormat: Codable {
    let formatId: String
    let ext: String
    let resolution: String?
    let fps: Double?
    let vcodec: String?
    let acodec: String?
    let abr: Double?
    let vbr: Double?
    let filesize: Int64?
    let filesizeApprox: Int64?
    let formatNote: String?
    
    var isVideoOnly: Bool {
        acodec == "none" || acodec == nil
    }
    
    var isAudioOnly: Bool {
        vcodec == "none" || vcodec == nil
    }
    
    enum CodingKeys: String, CodingKey {
        case formatId = "format_id"
        case ext, resolution, fps, vcodec, acodec, abr, vbr, filesize
        case filesizeApprox = "filesize_approx"
        case formatNote = "format_note"
    }
}

struct SubtitleInfo: Codable {
    let ext: String
    let url: String?
    let name: String?
}

struct ChapterInfo: Codable {
    let startTime: Double
    let endTime: Double
    let title: String
    
    enum CodingKeys: String, CodingKey {
        case startTime = "start_time"
        case endTime = "end_time"
        case title
    }
}


struct HistoricDownload: Codable, Identifiable {
    let id: UUID
    let url: String
    let title: String
    let filePath: String
    let downloadDate: Date
    let fileType: MediaFileType
    
    init(id: UUID, url: String, title: String, filePath: String, fileType: MediaFileType) {
        self.id = id
        self.url = url
        self.title = title
        self.filePath = filePath
        self.downloadDate = Date()
        self.fileType = fileType
    }
}
