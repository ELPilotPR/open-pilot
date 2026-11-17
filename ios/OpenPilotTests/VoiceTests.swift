import XCTest
@testable import OpenPilot

final class VoiceTests: XCTestCase {

    private func v(_ id: String, _ name: String, _ lang: String, _ q: Int) -> VoiceOption {
        VoiceOption(id: id, name: name, language: lang, quality: q)
    }

    func testFilterByLanguagePrefix() {
        let voices = [v("1", "Mónica", "es-ES", 1), v("2", "Samantha", "en-US", 1), v("3", "Paulina", "es-MX", 2)]
        let es = VoiceCatalog.filterAndSort(voices, languagePrefix: "es")
        XCTAssertEqual(es.count, 2)
        XCTAssertTrue(es.allSatisfy { $0.language.hasPrefix("es") })
    }

    func testSortQualityThenName() {
        let voices = [v("1", "Zoe", "en-US", 1), v("2", "Amy", "en-US", 3), v("3", "Bob", "en-US", 2)]
        let sorted = VoiceCatalog.filterAndSort(voices, languagePrefix: "en")
        XCTAssertEqual(sorted.map { $0.id }, ["2", "3", "1"])   // premium, enhanced, default
    }

    func testSortNameWithinSameQuality() {
        let voices = [v("1", "Zoe", "en-US", 1), v("2", "Amy", "en-US", 1)]
        let sorted = VoiceCatalog.filterAndSort(voices, languagePrefix: "en")
        XCTAssertEqual(sorted.map { $0.name }, ["Amy", "Zoe"])
    }

    func testCaseInsensitivePrefix() {
        let voices = [v("1", "Mónica", "ES-es", 1)]
        XCTAssertEqual(VoiceCatalog.filterAndSort(voices, languagePrefix: "es").count, 1)
    }

    func testShouldBargeIn() {
        XCTAssertTrue(VoiceCatalog.shouldBargeIn(transcript: "hola", enabled: true))
        XCTAssertFalse(VoiceCatalog.shouldBargeIn(transcript: "hola", enabled: false))
        XCTAssertFalse(VoiceCatalog.shouldBargeIn(transcript: "   ", enabled: true))
        XCTAssertFalse(VoiceCatalog.shouldBargeIn(transcript: "", enabled: true))
    }

    func testSettingsRoundTrip() {
        let savedID = VoiceSettings.identifier
        let savedBarge = VoiceSettings.bargeIn
        VoiceSettings.identifier = "com.apple.voice.test"
        VoiceSettings.bargeIn = false
        XCTAssertEqual(VoiceSettings.identifier, "com.apple.voice.test")
        XCTAssertFalse(VoiceSettings.bargeIn)
        VoiceSettings.identifier = savedID
        VoiceSettings.bargeIn = savedBarge
    }

    // MARK: - Regression: el dictado sigue el idioma de la app (no es-ES fijo)
    func testRecognizerLocaleFollowsAppLanguage() {
        XCTAssertEqual(VoiceManager.recognizerIdentifier(for: .en), "en-US")
        XCTAssertEqual(VoiceManager.recognizerIdentifier(for: .es), "es-ES")
    }
}