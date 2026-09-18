import Foundation

enum LRCParser {
    private static let tagPattern = #"\[(\d{1,2}):(\d{2}(?:\.\d{1,3})?)\]"#

    static func parse(_ raw: String) -> [LyricLine] {
        guard let regex = try? NSRegularExpression(pattern: tagPattern) else { return [] }
        var results: [LyricLine] = []

        for rawLine in raw.split(separator: "\n", omittingEmptySubsequences: true) {
            let line = String(rawLine)
            let nsrange = NSRange(line.startIndex..<line.endIndex, in: line)
            let matches = regex.matches(in: line, range: nsrange)
            guard let lastMatch = matches.last else { continue }

            var timestamps: [TimeInterval] = []
            for match in matches {
                guard let minutesRange = Range(match.range(at: 1), in: line),
                      let secondsRange = Range(match.range(at: 2), in: line),
                      let minutes = Double(line[minutesRange]),
                      let seconds = Double(line[secondsRange]) else { continue }
                timestamps.append(minutes * 60 + seconds)
            }
            guard !timestamps.isEmpty else { continue }

            let textStartIndex = line.index(line.startIndex, offsetBy: lastMatch.range.location + lastMatch.range.length)
            let text = String(line[textStartIndex...]).trimmingCharacters(in: .whitespaces)
            guard !text.isEmpty else { continue }

            for timestamp in timestamps {
                results.append(LyricLine(timestamp: timestamp, text: text))
            }
        }

        return results.sorted { $0.timestamp < $1.timestamp }
    }
}
