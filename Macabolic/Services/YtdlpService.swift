import Foundation


@MainActor
class YtdlpService: ObservableObject {
    @Published var isAvailable: Bool = false
    @Published var version: String?
    @Published var isUpdating: Bool = false
    @Published var updateProgress: Double = 0
    
    private var ytdlpPath: URL?
    private var ffmpegPath: URL?
    private let localVersion = "1.5.5"
    private let bundledYtdlpName = "yt-dlp_macos"
    
    init() {
        Task {
            await setupBinaries()
        }
    }
    

    
    func setupBinaries() async {
        await findYtdlp()
        await findFfmpeg()
    }
    

    

    func findYtdlp() async {

        if let bundledPath = Bundle.main.url(forResource: "yt-dlp", withExtension: nil) {
            ytdlpPath = bundledPath
            isAvailable = true

            Task {
                await getVersion()
            }
            return
        }
        

        let appSupport = getAppSupportDirectory()
        let ytdlpInSupport = appSupport.appendingPathComponent("yt-dlp")
        
        if FileManager.default.fileExists(atPath: ytdlpInSupport.path) {
            ytdlpPath = ytdlpInSupport
            isAvailable = true

            Task {
                await getVersion()
            }
            return
        }
        

        await downloadYtdlp()
    }
    

    

    func downloadYtdlp() async {
        isUpdating = true
        updateProgress = 0
        
        let downloadURL = URL(string: "https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_macos")!
        let appSupport = getAppSupportDirectory()
        let destination = appSupport.appendingPathComponent("yt-dlp")
        
        do {
            try FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true)
            let (tempURL, _) = try await URLSession.shared.download(from: downloadURL)
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.moveItem(at: tempURL, to: destination)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: destination.path)
            
            ytdlpPath = destination
            isAvailable = true
            await getVersion()
        } catch {
            print("yt-dlp indirme hatası: \(error)")
            isAvailable = false
        }
        
        isUpdating = false
    }



    func findFfmpeg() async {
        let appSupport = getAppSupportDirectory()
        let ffmpegInSupport = appSupport.appendingPathComponent("ffmpeg")
        let ffprobeInSupport = appSupport.appendingPathComponent("ffprobe")
        
        if FileManager.default.fileExists(atPath: ffmpegInSupport.path) {
            ffmpegPath = ffmpegInSupport
        }
        
        if !FileManager.default.fileExists(atPath: ffmpegInSupport.path) || 
           !FileManager.default.fileExists(atPath: ffprobeInSupport.path) {
            await downloadFfmpeg()
            await downloadFfprobe()
        }
    }

    func downloadFfmpeg() async {
        let ffmpegURL = URL(string: "https://evermeet.cx/ffmpeg/get/zip")!
        let appSupport = getAppSupportDirectory()
        let destinationZip = appSupport.appendingPathComponent("ffmpeg.zip")
        let ffmpegDest = appSupport.appendingPathComponent("ffmpeg")
        
        do {
            try FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true)
            let (tempURL, _) = try await URLSession.shared.download(from: ffmpegURL)
            if FileManager.default.fileExists(atPath: destinationZip.path) {
                try FileManager.default.removeItem(at: destinationZip)
            }
            try FileManager.default.moveItem(at: tempURL, to: destinationZip)
            
            let unzipProcess = Process()
            unzipProcess.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
            unzipProcess.arguments = ["-o", destinationZip.path, "-d", appSupport.path]
            try unzipProcess.run()
            unzipProcess.waitUntilExit()
            
            if FileManager.default.fileExists(atPath: ffmpegDest.path) {
                try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: ffmpegDest.path)
                ffmpegPath = ffmpegDest
            }
            try? FileManager.default.removeItem(at: destinationZip)
        } catch {
            print("FFmpeg indirme hatası: \(error)")
        }
    }

    func downloadFfprobe() async {
        let ffprobeURL = URL(string: "https://evermeet.cx/ffmpeg/get/ffprobe/zip")!
        let appSupport = getAppSupportDirectory()
        let destinationZip = appSupport.appendingPathComponent("ffprobe.zip")
        let ffprobeDest = appSupport.appendingPathComponent("ffprobe")
        
        do {
            try FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true)
            let (tempURL, _) = try await URLSession.shared.download(from: ffprobeURL)
            if FileManager.default.fileExists(atPath: destinationZip.path) {
                try FileManager.default.removeItem(at: destinationZip)
            }
            try FileManager.default.moveItem(at: tempURL, to: destinationZip)
            
            let unzipProcess = Process()
            unzipProcess.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
            unzipProcess.arguments = ["-o", destinationZip.path, "-d", appSupport.path]
            try unzipProcess.run()
            unzipProcess.waitUntilExit()
            
            if FileManager.default.fileExists(atPath: ffprobeDest.path) {
                try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: ffprobeDest.path)
            }
            try? FileManager.default.removeItem(at: destinationZip)
        } catch {
            print("FFprobe indirme hatası: \(error)")
        }
    }
    

    func updateYtdlp() async {
        await downloadYtdlp()
    }
    

    
    func getVersion() async {
        guard let path = ytdlpPath else { return }
        
        do {
            let output = try await runCommandAsync([path.path, "--version"])
            version = output.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            print("Versiyon alınamadı: \(error)")
        }
    }
    

    

    func fetchInfo(url: String, credential: Credential? = nil) async throws -> MediaInfo {
        guard let path = ytdlpPath else {
            throw YtdlpError.notFound
        }
        
        do {
             return try await fetchSingleVideoInfo(path: path.path, url: url, credential: credential)
        } catch {
            if url.contains("list=") || url.contains("/playlist") {
                 return try await fetchPlaylistSummaryInfo(path: path.path, url: url, credential: credential)
            }
            throw error // Playlist değilse orijinal hatayı fırlat
        }
    }
    
    private func fetchSingleVideoInfo(path: String, url: String, credential: Credential?) async throws -> MediaInfo {
        var args = [
            path,
            "--dump-json",
            "--no-playlist",
            "--no-warnings"
        ]
        
        if let credential = credential {
            args.append(contentsOf: ["--username", credential.username, "--password", credential.password])
        }
        
        args.append(url)
        
        let output = try await runCommand(args)
        guard let data = output.data(using: .utf8) else { throw YtdlpError.parseError }
        return try JSONDecoder().decode(MediaInfo.self, from: data)
    }

    private func fetchPlaylistSummaryInfo(path: String, url: String, credential: Credential?) async throws -> MediaInfo {
        var args = [
            path,
            "--dump-single-json",
            "--flat-playlist",
            "--no-warnings"
        ]
        
        if let credential = credential {
            args.append(contentsOf: ["--username", credential.username, "--password", credential.password])
        }
        
        args.append(url)
        
        let output = try await runCommand(args)
        guard let data = output.data(using: .utf8) else { throw YtdlpError.parseError }
        
        let decoder = JSONDecoder()
        
        var info = try decoder.decode(MediaInfo.self, from: data)
        
        
        return MediaInfo(
            id: info.id,
            title: info.title,
            description: info.description,
            thumbnail: info.thumbnail, // Bazen playlist thumbnail gelir
            duration: nil,
            uploader: info.uploader,
            uploadDate: nil,
            viewCount: info.viewCount,
            likeCount: nil,
            formats: nil,
            subtitles: nil,
            automaticCaptions: nil,
            chapters: nil,
            playlist: info.id, // Playlist olduğunu belirtmek için ID'yi buraya da koyuyoruz
            playlistIndex: nil,
            playlistCount: info.playlistCount ?? info.viewCount // Bazen viewCount yerine entry count gelebilir
        )
    }
    

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
    

    

    func download(
        url: String,
        options: DownloadOptions,
        onProcessCreated: @escaping (Process) -> Void,
        onProgress: @escaping (Double, String?, String?) -> Void,
        onOutput: @escaping (String) -> Void
    ) async throws -> URL {
        guard let path = ytdlpPath else {
            throw YtdlpError.notFound
        }
        
        var args = [path.path]
        args.append("--no-playlist")
        
        let appSupport = getAppSupportDirectory()
        args.append(contentsOf: ["--ffmpeg-location", appSupport.path])
        args.append(contentsOf: ["--paths", "temp:/tmp"])
        
        let outputTemplate: String
        if let customFilename = options.customFilename, !customFilename.isEmpty {
            outputTemplate = options.saveFolder.appendingPathComponent("\(customFilename).%(ext)s").path
        } else {
            outputTemplate = options.saveFolder.appendingPathComponent("%(title)s.%(ext)s").path
        }
        args.append(contentsOf: ["-o", outputTemplate])
        

        args.append(contentsOf: buildFormatArgs(options: options))
        

        if options.downloadSubtitles && !options.subtitleLanguages.isEmpty {
            args.append("--write-subs")
            args.append("--write-auto-subs")
            args.append(contentsOf: ["--sub-langs", options.subtitleLanguages.joined(separator: ",")])
            if options.embedSubtitles && options.fileType.isVideo {
                args.append("--embed-subs")
            }
        }
        

        if options.downloadThumbnail {
            args.append("--write-thumbnail")
        }
        if options.embedThumbnail {
            args.append("--embed-thumbnail")
        }
        

        if options.embedMetadata {
            args.append("--embed-metadata")
        }
        

        if options.splitChapters {
            args.append("--split-chapters")
        }
        

        if options.sponsorBlock {
            args.append(contentsOf: ["--sponsorblock-remove", "all"])
        }
        

        if let start = options.timeFrameStart, let end = options.timeFrameEnd {
            args.append(contentsOf: ["--download-sections", "*\(start)-\(end)"])
        }
        

        if let credential = options.credential {
            args.append(contentsOf: ["--username", credential.username, "--password", credential.password])
        }
        

        args.append("--newline")
        args.append("--progress-template")
        args.append("%(progress._percent_str)s %(progress._speed_str)s %(progress._eta_str)s")
        
        args.append(url)
        

        let outputPath = try await runDownloadProcess(
            args: args,
            saveFolder: options.saveFolder,
            onProcessCreated: onProcessCreated,
            onProgress: onProgress,
            onOutput: onOutput
        )
        
        return URL(fileURLWithPath: outputPath)
    }
    

    
    private func buildFormatArgs(options: DownloadOptions) -> [String] {
        var args: [String] = []
        
        if options.fileType.isVideo {
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
            args.append(contentsOf: ["-f", "ba/best"])
            args.append(contentsOf: ["-x", "--audio-format", options.fileType.fileExtension])
            
            if let quality = options.audioQuality {
                args.append(contentsOf: ["--audio-quality", quality.ytdlpValue])
            } else {
                args.append(contentsOf: ["--audio-quality", "0"]) // Best quality by default
            }
        }
        
        return args
    }
    

    private func runCommandAsync(_ args: [String]) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            let pipe = Pipe()
            
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = args
            process.standardOutput = pipe
            process.standardError = pipe
            
            var env = ProcessInfo.processInfo.environment
            let appSupport = getAppSupportDirectory()
            let currentPath = env["PATH"] ?? ""
            env["PATH"] = "\(appSupport.path):\(currentPath)"
            process.environment = env
            

            var outputData = Data()
            pipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if !data.isEmpty {
                    outputData.append(data)
                }
            }
            
            process.terminationHandler = { proc in

                pipe.fileHandleForReading.readabilityHandler = nil
                

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
        saveFolder: URL,
        onProcessCreated: @escaping (Process) -> Void,
        onProgress: @escaping (Double, String?, String?) -> Void,
        onOutput: @escaping (String) -> Void
    ) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            let outputPipe = Pipe()
            let errorPipe = Pipe()
            
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = args
            process.currentDirectoryURL = saveFolder
            process.standardOutput = outputPipe
            process.standardError = errorPipe
            
            var env = ProcessInfo.processInfo.environment
            let appSupport = getAppSupportDirectory()
            let currentPath = env["PATH"] ?? ""
            env["PATH"] = "\(appSupport.path):\(currentPath)"
            process.environment = env
            
            onProcessCreated(process)
            
            var outputPath = ""
            

            outputPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                guard !data.isEmpty, let line = String(data: data, encoding: .utf8) else { return }
                
                DispatchQueue.main.async {
                    onOutput(line)
                    

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
