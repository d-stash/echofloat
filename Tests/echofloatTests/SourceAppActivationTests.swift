import Testing
@testable import echofloat

@Test func mapsKnownSourceNamesToBundleIdentifiers() {
    #expect(sourceAppBundleID(for: "Music") == "com.apple.Music")
    #expect(sourceAppBundleID(for: "Spotify") == "com.spotify.client")
    #expect(sourceAppBundleID(for: "YouTube Music") == "com.google.Chrome")
}

@Test func returnsNilForUnknownSourceName() {
    #expect(sourceAppBundleID(for: "Safari") == nil)
    #expect(sourceAppBundleID(for: "") == nil)
}
