import Foundation

/// Fetches time-synced LRC lyrics from LRCLIB (free, no API key required)
/// to upgrade plain lyrics into Apple Music-style real-time synced lyrics.
struct SyncedLyricsProvider {
    private struct LRCLibRecord: Decodable {
        let trackName: String?
        let artistName: String?
        let duration: Double?
        let syncedLyrics: String?
        let plainLyrics: String?
    }

    static func fetchSyncedLyrics(
        title: String,
        artist: String,
        duration: Double
    ) async -> LyricsData? {
        let cleanTitle = sanitizeTitle(title)
        let cleanArtist = sanitizeArtist(artist)
        guard !cleanTitle.isEmpty else { return nil }

        // 1. Exact match endpoint (/api/get)
        if let exact = await fetchExact(title: cleanTitle, artist: cleanArtist, duration: duration),
           let synced = exact.syncedLyrics,
           let parsed = parseLRC(synced), !parsed.isEmpty {
            return LyricsData(lines: parsed, source: AppConstants.lrcLibSourceLabel)
        }

        // 2. Search fallback (/api/search)
        if let searchMatch = await fetchSearch(title: cleanTitle, artist: cleanArtist, duration: duration),
           let synced = searchMatch.syncedLyrics,
           let parsed = parseLRC(synced), !parsed.isEmpty {
            return LyricsData(lines: parsed, source: AppConstants.lrcLibSourceLabel)
        }

        return nil
    }

    private static func fetchExact(title: String, artist: String, duration: Double) async -> LRCLibRecord? {
        guard var comps = URLComponents(string: AppConstants.lrcLibExactEndpoint) else { return nil }
        var items = [
            URLQueryItem(name: "track_name", value: title),
            URLQueryItem(name: "artist_name", value: artist)
        ]
        if duration > 10 {
            items.append(URLQueryItem(name: "duration", value: String(Int(duration.rounded()))))
        }
        comps.queryItems = items
        guard let url = comps.url else { return nil }

        var req = URLRequest(url: url)
        req.timeoutInterval = AppConstants.lrcLibTimeout
        req.setValue(AppConstants.lrcLibUserAgent, forHTTPHeaderField: "User-Agent")

        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            return nil
        }
        return try? JSONDecoder().decode(LRCLibRecord.self, from: data)
    }

    private static func fetchSearch(title: String, artist: String, duration: Double) async -> LRCLibRecord? {
        guard var comps = URLComponents(string: AppConstants.lrcLibSearchEndpoint) else { return nil }
        let q = artist.isEmpty ? title : "\(title) \(artist)"
        comps.queryItems = [URLQueryItem(name: "q", value: q)]
        guard let url = comps.url else { return nil }

        var req = URLRequest(url: url)
        req.timeoutInterval = AppConstants.lrcLibTimeout
        req.setValue(AppConstants.lrcLibUserAgent, forHTTPHeaderField: "User-Agent")

        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode),
              let results = try? JSONDecoder().decode([LRCLibRecord].self, from: data) else {
            return nil
        }

        let withSynced = results.filter { !($0.syncedLyrics ?? "").isEmpty }
        guard !withSynced.isEmpty else { return nil }

        if duration > 10 {
            return withSynced.min { a, b in
                abs((a.duration ?? duration) - duration) < abs((b.duration ?? duration) - duration)
            }
        }
        return withSynced.first
    }

    /// Parses standard LRC format `[mm:ss.xx] Lyric text` into sorted `[LyricLine]`.
    static func parseLRC(_ lrc: String) -> [LyricLine]? {
        let pattern = #"\[(\d{1,2}):(\d{2})(?:\.(\d{1,3}))?\]\s*(.*)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }

        var rawLines: [(Double, String)] = []
        for raw in lrc.components(separatedBy: .newlines) {
            let trimmed = raw.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            let nsRange = NSRange(trimmed.startIndex..., in: trimmed)
            guard let match = regex.firstMatch(in: trimmed, range: nsRange),
                  let minRange = Range(match.range(at: 1), in: trimmed),
                  let secRange = Range(match.range(at: 2), in: trimmed),
                  let textRange = Range(match.range(at: 4), in: trimmed) else {
                continue
            }

            let mins = Double(trimmed[minRange]) ?? 0
            let secs = Double(trimmed[secRange]) ?? 0
            var frac = 0.0
            if let fracRange = Range(match.range(at: 3), in: trimmed) {
                let fracStr = String(trimmed[fracRange])
                if fracStr.count == 2 {
                    frac = (Double(fracStr) ?? 0) / 100.0
                } else if fracStr.count == 3 {
                    frac = (Double(fracStr) ?? 0) / 1000.0
                } else if fracStr.count == 1 {
                    frac = (Double(fracStr) ?? 0) / 10.0
                }
            }

            let text = String(trimmed[textRange]).trimmingCharacters(in: .whitespaces)
            guard !text.isEmpty else { continue }
            rawLines.append((mins * 60 + secs + frac, text))
        }

        rawLines.sort { $0.0 < $1.0 }
        return rawLines.enumerated().map { idx, entry in
            LyricLine(id: idx, text: entry.1, startTime: entry.0)
        }
    }

    private static func sanitizeTitle(_ raw: String) -> String {
        // Strip common YouTube suffixes like "(Official Video)", "(Audio)", "[MV]"
        let patterns = [
            #"\s*[\(\[](?:official\s*(?:music\s*)?(?:video|audio|lyric\s*video)|mv|m/v|audio|lyrics|hd|4k)[\)\]]"#
        ]
        var out = raw
        for p in patterns {
            if let regex = try? NSRegularExpression(pattern: p, options: [.caseInsensitive]) {
                out = regex.stringByReplacingMatches(
                    in: out,
                    range: NSRange(out.startIndex..., in: out),
                    withTemplate: ""
                )
            }
        }
        return out.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func sanitizeArtist(_ raw: String) -> String {
        // Take primary artist before bullet/metadata separators (e.g. "Wham! • Make It Big • 1984")
        let firstPart = raw.components(separatedBy: " • ").first ?? raw
        return firstPart
            .replacingOccurrences(of: " - Topic", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
