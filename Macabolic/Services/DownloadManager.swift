import Foundation
import AppKit


@MainActor
class DownloadManager: ObservableObject {

    @Published var downloads: [Download] = []
    @Published var history: [HistoricDownload] = []
    @Published var showDisclaimer: Bool = false
    @Published var ytdlpVersion: String?
    

    let ytdlpService = YtdlpService()
    

    private let maxConcurrentDownloads = 3
    private let userDefaults = UserDefaults.standard
    private var activeProcesses: [UUID: Process] = [:]
    

    
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
    

    
    func initialize() async {

        await ytdlpService.findYtdlp()
        ytdlpVersion = ytdlpService.version
        

        loadHistory()
        

        if !userDefaults.bool(forKey: "disclaimerAcknowledged") {
            showDisclaimer = true
        }
    }
    
    func acknowledgeDisclaimer() {
        userDefaults.set(true, forKey: "disclaimerAcknowledged")
        showDisclaimer = false
    }
    

    

    func addDownload(url: String, options: DownloadOptions) {
        let download = Download(url: url, options: options)
        downloads.append(download)
        
        Task {
            await processDownload(download)
        }
    }
    

    func addDownloads(urls: [String], options: DownloadOptions) {
        for url in urls {
            addDownload(url: url, options: options)
        }
    }
    

    
    private func processDownload(_ download: Download) async {

        while downloadingCount >= maxConcurrentDownloads {
            try? await Task.sleep(nanoseconds: 500_000_000)
        }
        
        download.status = .fetching
        
        do {

            let info = try await ytdlpService.fetchInfo(url: download.url, credential: download.options.credential)
            
            download.title = info.title
            download.duration = info.durationString
            download.thumbnailURL = info.thumbnailURL
            download.status = .downloading
            

            let outputPath = try await ytdlpService.download(
                url: download.url,
                options: download.options,
                onProcessCreated: { [weak self] process in
                    Task { @MainActor in
                        self?.activeProcesses[download.id] = process
                    }
                },
                onProgress: { progress, speed, eta in
                    download.progress = progress
                    download.speed = speed
                    download.eta = eta
                },
                onOutput: { line in
                    download.log += line + "\n"
                }
            )
            
            activeProcesses.removeValue(forKey: download.id)
            
            download.filePath = outputPath
            download.status = .completed
            download.progress = 1.0
            

            addToHistory(download)
            
        } catch {
            download.status = .failed
            download.errorMessage = error.localizedDescription
        }
    }
    

    

    func stopDownload(_ download: Download) {
        if let process = activeProcesses[download.id] {
            process.terminate()
            activeProcesses.removeValue(forKey: download.id)
        }
        download.status = .stopped
    }
    

    func retryDownload(_ download: Download) {
        download.status = .queued
        download.progress = 0
        download.errorMessage = nil
        download.log = ""
        
        Task {
            await processDownload(download)
        }
    }
    

    func stopAllDownloads() {
        for download in downloadingDownloads {
            stopDownload(download)
        }
        for download in queuedDownloads {
            download.status = .stopped
        }
    }
    

    func retryFailedDownloads() {
        for download in downloads where download.status == .failed {
            retryDownload(download)
        }
    }
    

    func clearQueuedDownloads() {
        downloads.removeAll { $0.status == .queued }
    }
    

    func clearCompletedDownloads() {
        downloads.removeAll { $0.status == .completed || $0.status == .failed || $0.status == .stopped }
    }
    

    func removeDownload(_ download: Download) {
        stopDownload(download)
        downloads.removeAll { $0.id == download.id }
    }
    

    
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
    

    
    func openFile(_ path: URL) {
        NSWorkspace.shared.open(path)
    }
    
    func showInFinder(_ path: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([path])
    }
}
