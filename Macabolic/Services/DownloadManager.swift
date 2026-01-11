import Foundation
import AppKit

/// İndirme işlemlerini yöneten ana servis
@MainActor
class DownloadManager: ObservableObject {
    // MARK: - Published Properties
    @Published var downloads: [Download] = []
    @Published var history: [HistoricDownload] = []
    @Published var showDisclaimer: Bool = false
    @Published var ytdlpVersion: String?
    
    // MARK: - Services
    let ytdlpService = YtdlpService()
    
    // MARK: - Configuration
    private let maxConcurrentDownloads = 3
    private let userDefaults = UserDefaults.standard
    
    // MARK: - Computed Properties
    
    var downloadingDownloads: [Download] {
        downloads.filter { $0.status == .downloading || $0.status == .fetching || $0.status == .processing }
    }
    
    var queuedDownloads: [Download] {
        downloads.filter { $0.status == .queued }
    }
    
    var completedDownloads: [Download] {
        downloads.filter { $0.status == .completed || $0.status == .failed || $0.status == .stopped }
    }
    
    var downloadingCount: Int { downloadingDownloads.count }
    var queuedCount: Int { queuedDownloads.count }
    var completedCount: Int { completedDownloads.count }
    
    // MARK: - Initialization
    
    func initialize() async {
        // yt-dlp hazır olana kadar bekle
        await ytdlpService.findYtdlp()
        ytdlpVersion = ytdlpService.version
        
        // Geçmişi yükle
        loadHistory()
        
        // Disclaimer kontrolü
        if !userDefaults.bool(forKey: "disclaimerAcknowledged") {
            showDisclaimer = true
        }
    }
    
    func acknowledgeDisclaimer() {
        userDefaults.set(true, forKey: "disclaimerAcknowledged")
        showDisclaimer = false
    }
    
    // MARK: - Add Download
    
    /// Yeni indirme ekle
    func addDownload(url: String, options: DownloadOptions) {
        let download = Download(url: url, options: options)
        downloads.append(download)
        
        Task {
            await processDownload(download)
        }
    }
    
    /// Birden fazla URL ekle
    func addDownloads(urls: [String], options: DownloadOptions) {
        for url in urls {
            addDownload(url: url, options: options)
        }
    }
    
    // MARK: - Process Download
    
    private func processDownload(_ download: Download) async {
        // Eşzamanlı indirme limitini kontrol et
        while downloadingCount >= maxConcurrentDownloads {
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 saniye bekle
        }
        
        download.status = .fetching
        
        do {
            // Video bilgilerini çek
            let info = try await ytdlpService.fetchInfo(url: download.url, credential: download.options.credential)
            
            download.title = info.title
            download.duration = info.durationString
            download.thumbnailURL = info.thumbnailURL
            download.status = .downloading
            
            // İndir
            let outputPath = try await ytdlpService.download(
                url: download.url,
                options: download.options,
                onProgress: { progress, speed, eta in
                    download.progress = progress
                    download.speed = speed
                    download.eta = eta
                },
                onOutput: { line in
                    download.log += line + "\n"
                }
            )
            
            download.filePath = outputPath
            download.status = .completed
            download.progress = 1.0
            
            // Geçmişe ekle
            addToHistory(download)
            
        } catch {
            download.status = .failed
            download.errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - Download Controls
    
    /// İndirmeyi durdur
    func stopDownload(_ download: Download) {
        download.status = .stopped
        // TODO: Process'i terminate et
    }
    
    /// İndirmeyi yeniden dene
    func retryDownload(_ download: Download) {
        download.status = .queued
        download.progress = 0
        download.errorMessage = nil
        download.log = ""
        
        Task {
            await processDownload(download)
        }
    }
    
    /// Tüm indirmeleri durdur
    func stopAllDownloads() {
        for download in downloadingDownloads {
            stopDownload(download)
        }
        for download in queuedDownloads {
            download.status = .stopped
        }
    }
    
    /// Başarısız indirmeleri yeniden dene
    func retryFailedDownloads() {
        for download in downloads where download.status == .failed {
            retryDownload(download)
        }
    }
    
    /// Kuyrukta bekleyen indirmeleri temizle
    func clearQueuedDownloads() {
        downloads.removeAll { $0.status == .queued }
    }
    
    /// Tamamlanan indirmeleri temizle
    func clearCompletedDownloads() {
        downloads.removeAll { $0.status == .completed || $0.status == .failed || $0.status == .stopped }
    }
    
    /// Belirli bir indirmeyi kaldır
    func removeDownload(_ download: Download) {
        downloads.removeAll { $0.id == download.id }
    }
    
    // MARK: - History
    
    private func loadHistory() {
        if let data = userDefaults.data(forKey: "downloadHistory"),
           let decoded = try? JSONDecoder().decode([HistoricDownload].self, from: data) {
            history = decoded
        }
    }
    
    private func saveHistory() {
        if let encoded = try? JSONEncoder().encode(history) {
            userDefaults.set(encoded, forKey: "downloadHistory")
        }
    }
    
    private func addToHistory(_ download: Download) {
        let historicDownload = HistoricDownload(
            id: download.id,
            url: download.url,
            title: download.title,
            filePath: download.filePath?.path ?? "",
            fileType: download.options.fileType
        )
        history.insert(historicDownload, at: 0)
        
        // Maximum 100 kayıt tut
        if history.count > 100 {
            history = Array(history.prefix(100))
        }
        
        saveHistory()
    }
    
    func clearHistory() {
        history.removeAll()
        saveHistory()
    }
    
    func removeFromHistory(_ download: HistoricDownload) {
        history.removeAll { $0.id == download.id }
        saveHistory()
    }
    
    // MARK: - Open File
    
    func openFile(_ path: URL) {
        NSWorkspace.shared.open(path)
    }
    
    func showInFinder(_ path: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([path])
    }
}
