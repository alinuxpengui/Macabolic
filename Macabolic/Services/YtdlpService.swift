import Foundation

/// yt-dlp executable ile etkileşim sağlayan servis
@MainActor
class YtdlpService: ObservableObject {
    @Published var isAvailable: Bool = false
    @Published var version: String?
    @Published var isUpdating: Bool = false
    @Published var updateProgress: Double = 0
    
    private var ytdlpPath: URL?
    private let bundledYtdlpName = "yt-dlp_macos"
    
    init() {
        Task {
            await findYtdlp()
        }
    }
    
    // MARK: - Find yt-dlp
    
    /// Bundled yt-dlp'yi bul veya indir
    func findYtdlp() async {
        // Önce uygulama içindeki bundled yt-dlp'yi ara
        if let bundledPath = Bundle.main.url(forResource: "yt-dlp", withExtension: nil) {
            ytdlpPath = bundledPath
            isAvailable = true
            // Versiyonu arka planda al, UI'ı bekletme
            Task {
                await getVersion()
            }
            return
        }
        
        // Application Support'ta ara
        let appSupport = getAppSupportDirectory()
        let ytdlpInSupport = appSupport.appendingPathComponent("yt-dlp")
        
        if FileManager.default.fileExists(atPath: ytdlpInSupport.path) {
            ytdlpPath = ytdlpInSupport
            isAvailable = true
            // Versiyonu arka planda al
            Task {
                await getVersion()
            }
            return
        }
        
        // İndir
        await downloadYtdlp()
    }
    
    // MARK: - Download yt-dlp
    
    /// yt-dlp'yi GitHub'dan indir
    func downloadYtdlp() async {
        isUpdating = true
        updateProgress = 0
        
        let downloadURL = URL(string: "https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_macos")!
        let appSupport = getAppSupportDirectory()
        let destination = appSupport.appendingPathComponent("yt-dlp")
        
        do {
            // Klasörü oluştur
            try FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true)
            
            // İndir
            let (tempURL, _) = try await URLSession.shared.download(from: downloadURL)
            
            // Eski dosyayı sil
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            
            // Taşı
            try FileManager.default.moveItem(at: tempURL, to: destination)
            
            // Çalıştırılabilir yap
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: destination.path)
            
            ytdlpPath = destination
            isAvailable = true
            await getVersion()
            
        } catch {
            print("yt-dlp indirme hatası: \(error)")
            isAvailable = false
        }
        
        isUpdating = false
        updateProgress = 1.0
    }
    
    /// yt-dlp'yi güncelle
    func updateYtdlp() async {
        await downloadYtdlp()
    }
    
    // MARK: - Get Version
    
    func getVersion() async {
        guard let path = ytdlpPath else { return }
        
        do {
            let output = try await runCommandAsync([path.path, "--version"])
            version = output.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            print("Versiyon alınamadı: \(error)")
        }
    }
    
    // MARK: - Fetch URL Info
    
    /// URL'den video bilgilerini çek
    func fetchInfo(url: String, credential: Credential? = nil) async throws -> MediaInfo {
        guard let path = ytdlpPath else {
            throw YtdlpError.notFound
        }
        
        var args = [
            path.path,
            "--dump-json",
            "--no-playlist",
            "--no-warnings"
        ]
        
        if let credential = credential {
            args.append(contentsOf: ["--username", credential.username, "--password", credential.password])
        }
        
        args.append(url)
        
        let output = try await runCommand(args)
        
        guard let data = output.data(using: .utf8) else {
            throw YtdlpError.parseError
        }
        
        let decoder = JSONDecoder()
        let info = try decoder.decode(MediaInfo.self, from: data)
        return info
    }
    
    /// Playlist bilgilerini çek
    func fetchPlaylistInfo(url: String, credential: Credential? = nil) async throws -> [MediaInfo] {
        guard let path = ytdlpPath else {
            throw YtdlpError.notFound
        }
        
        var args = [
            path.path,
            "--dump-json",
            "--flat-playlist",
            "--no-warnings"
        ]
        
        if let credential = credential {
            args.append(contentsOf: ["--username", credential.username, "--password", credential.password])
        }
        
        args.append(url)
        
        let output = try await runCommand(args)
        
        var results: [MediaInfo] = []
        let decoder = JSONDecoder()
        
        for line in output.components(separatedBy: "\n") where !line.isEmpty {
            if let data = line.data(using: .utf8),
               let info = try? decoder.decode(MediaInfo.self, from: data) {
                results.append(info)
            }
        }
        
        return results
    }
    
    // MARK: - Download
    
    /// Video/ses indir
    func download(
        url: String,
        options: DownloadOptions,
        onProgress: @escaping (Double, String?, String?) -> Void,
        onOutput: @escaping (String) -> Void
    ) async throws -> URL {
        guard let path = ytdlpPath else {
            throw YtdlpError.notFound
        }
        
        var args = [path.path]
        
        // Output template
        let outputTemplate: String
        if let customFilename = options.customFilename, !customFilename.isEmpty {
            outputTemplate = options.saveFolder.appendingPathComponent("\(customFilename).%(ext)s").path
        } else {
            outputTemplate = options.saveFolder.appendingPathComponent("%(title)s.%(ext)s").path
        }
        args.append(contentsOf: ["-o", outputTemplate])
        
        // Format
        args.append(contentsOf: buildFormatArgs(options: options))
        
        // Subtitles
        if options.downloadSubtitles {
            args.append("--write-subs")
            if !options.subtitleLanguages.isEmpty {
                args.append(contentsOf: ["--sub-langs", options.subtitleLanguages.joined(separator: ",")])
            }
            if options.embedSubtitles && options.fileType.isVideo {
                args.append("--embed-subs")
            }
        }
        
        // Thumbnail
        if options.downloadThumbnail {
            args.append("--write-thumbnail")
        }
        if options.embedThumbnail {
            args.append("--embed-thumbnail")
        }
        
        // Metadata
        if options.embedMetadata {
            args.append("--embed-metadata")
        }
        
        // Chapters
        if options.splitChapters {
            args.append("--split-chapters")
        }
        
        // SponsorBlock
        if options.sponsorBlock {
            args.append(contentsOf: ["--sponsorblock-remove", "all"])
        }
        
        // Time frame
        if let start = options.timeFrameStart, let end = options.timeFrameEnd {
            args.append(contentsOf: ["--download-sections", "*\(start)-\(end)"])
        }
        
        // Credential
        if let credential = options.credential {
            args.append(contentsOf: ["--username", credential.username, "--password", credential.password])
        }
        
        // Progress
        args.append("--newline")
        args.append("--progress-template")
        args.append("%(progress._percent_str)s %(progress._speed_str)s %(progress._eta_str)s")
        
        args.append(url)
        
        // Process'i çalıştır ve output'u izle
        let outputPath = try await runDownloadProcess(args: args, onProgress: onProgress, onOutput: onOutput)
        
        return URL(fileURLWithPath: outputPath)
    }
    
    // MARK: - Private Helpers
    
    private func buildFormatArgs(options: DownloadOptions) -> [String] {
        var args: [String] = []
        
        if options.fileType.isVideo {
            // Video format
            var formatStr = ""
            if let resolution = options.videoResolution {
                formatStr = "\(resolution.ytdlpValue)+bestaudio"
            } else {
                formatStr = "bestvideo+bestaudio"
            }
            formatStr += "/best"
            
            args.append(contentsOf: ["-f", formatStr])
            args.append(contentsOf: ["--merge-output-format", options.fileType.fileExtension])
        } else {
            // Audio only
            args.append(contentsOf: ["-x", "--audio-format", options.fileType.fileExtension])
            args.append(contentsOf: ["--audio-quality", "0"])
        }
        
        return args
    }
    
    /// Bloklamayan komut çalıştırma (Büyük çıktılar için güvenli)
    private func runCommandAsync(_ args: [String]) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            let pipe = Pipe()
            
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = args
            process.standardOutput = pipe
            process.standardError = pipe
            
            // Veriyi parça parça oku (Buffer dolmasını önler)
            var outputData = Data()
            pipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if !data.isEmpty {
                    outputData.append(data)
                }
            }
            
            process.terminationHandler = { proc in
                // Readability handler'ı temizle
                pipe.fileHandleForReading.readabilityHandler = nil
                
                // Kalan son veriyi al
                let remainingData = pipe.fileHandleForReading.readDataToEndOfFile()
                if !remainingData.isEmpty {
                    outputData.append(remainingData)
                }
                
                let output = String(data: outputData, encoding: .utf8) ?? ""
                
                if proc.terminationStatus == 0 {
                    continuation.resume(returning: output)
                } else {
                    continuation.resume(throwing: YtdlpError.commandFailed(output))
                }
            }
            
            do {
                try process.run()
            } catch {
                pipe.fileHandleForReading.readabilityHandler = nil
                continuation.resume(throwing: error)
            }
        }
    }
    
    private func runCommand(_ args: [String]) async throws -> String {
        return try await runCommandAsync(args)
    }
    
    private func runDownloadProcess(
        args: [String],
        onProgress: @escaping (Double, String?, String?) -> Void,
        onOutput: @escaping (String) -> Void
    ) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            let outputPipe = Pipe()
            let errorPipe = Pipe()
            
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = args
            process.standardOutput = outputPipe
            process.standardError = errorPipe
            
            var outputPath = ""
            
            // Output handler
            outputPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                guard !data.isEmpty, let line = String(data: data, encoding: .utf8) else { return }
                
                DispatchQueue.main.async {
                    onOutput(line)
                    
                    // Parse progress
                    if line.contains("%") {
                        let components = line.trimmingCharacters(in: .whitespacesAndNewlines)
                            .components(separatedBy: .whitespaces)
                            .filter { !$0.isEmpty }
                        
                        if let percentStr = components.first,
                           let percent = Double(percentStr.replacingOccurrences(of: "%", with: "")) {
                            let speed = components.count > 1 ? components[1] : nil
                            let eta = components.count > 2 ? components[2] : nil
                            onProgress(percent / 100.0, speed, eta)
                        }
                    }
                    
                    // Destination path
                    if line.contains("[download] Destination:") {
                        let parts = line.components(separatedBy: "[download] Destination: ")
                        if parts.count > 1 {
                            outputPath = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
                        }
                    }
                    
                    if line.contains("[Merger] Merging formats into") {
                        let parts = line.components(separatedBy: "\"")
                        if parts.count > 1 {
                            outputPath = parts[1]
                        }
                    }
                }
            }
            
            // Error handler
            errorPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                guard !data.isEmpty, let line = String(data: data, encoding: .utf8) else { return }
                DispatchQueue.main.async {
                    onOutput("[ERROR] \(line)")
                }
            }
            
            process.terminationHandler = { proc in
                outputPipe.fileHandleForReading.readabilityHandler = nil
                errorPipe.fileHandleForReading.readabilityHandler = nil
                
                if proc.terminationStatus == 0 {
                    continuation.resume(returning: outputPath)
                } else {
                    continuation.resume(throwing: YtdlpError.downloadFailed)
                }
            }
            
            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    private func getAppSupportDirectory() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("Macabolic")
    }
}

// MARK: - Errors

enum YtdlpError: LocalizedError {
    case notFound
    case parseError
    case commandFailed(String)
    case downloadFailed
    
    var errorDescription: String? {
        switch self {
        case .notFound:
            return "yt-dlp bulunamadı"
        case .parseError:
            return "Veri ayrıştırılamadı"
        case .commandFailed(let output):
            return "Komut başarısız: \(output)"
        case .downloadFailed:
            return "İndirme başarısız"
        }
    }
}
