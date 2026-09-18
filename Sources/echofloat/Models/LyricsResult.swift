enum LyricsResult: Equatable {
    case synced([LyricLine])
    case plain(String)
    case notFound
}
