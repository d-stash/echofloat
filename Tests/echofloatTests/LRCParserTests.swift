import Testing
@testable import echofloat

@Test func parsesTimestampedLines() {
    let raw = "[00:12.00]Line one\n[00:17.50]Line two\n"
    let lines = LRCParser.parse(raw)
    #expect(lines.count == 2)
    #expect(lines[0].timestamp == 12.0)
    #expect(lines[0].text == "Line one")
    #expect(lines[1].timestamp == 17.5)
    #expect(lines[1].text == "Line two")
}

@Test func sortsLinesByTimestampRegardlessOfInputOrder() {
    let raw = "[01:00.00]Second\n[00:05.00]First\n"
    let lines = LRCParser.parse(raw)
    #expect(lines.map(\.text) == ["First", "Second"])
}

@Test func skipsLinesWithoutTimestamps() {
    let raw = "[ti:Some Title]\n[ar:Some Artist]\n[00:01.00]Real lyric\n"
    let lines = LRCParser.parse(raw)
    #expect(lines.count == 1)
    #expect(lines[0].text == "Real lyric")
}

@Test func skipsEmptyLyricAfterTimestamp() {
    let raw = "[00:01.00]   \n[00:02.00]Real lyric\n"
    let lines = LRCParser.parse(raw)
    #expect(lines.count == 1)
    #expect(lines[0].text == "Real lyric")
}

@Test func duplicatesLineForMultipleTimestampTags() {
    let raw = "[00:01.00][00:30.00]Chorus\n"
    let lines = LRCParser.parse(raw)
    #expect(lines.count == 2)
    #expect(lines.allSatisfy { $0.text == "Chorus" })
    #expect(lines.map(\.timestamp) == [1.0, 30.0])
}
