import XCTest
@testable import OpenPilot

/// Lógica de la preferencia de haptics: por defecto activada, round-trip y
/// aislamiento entre suites. No toca UIKit (los generadores de feedback no se
/// prueban aquí; solo la decisión de enabled/disabled).
final class HapticsPreferenceTests: XCTestCase {
    private let suite = "com.openpilot.tests.haptics"
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suite)
        defaults.removePersistentDomain(forName: suite)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
        defaults = nil
        super.tearDown()
    }

    func testDefaultIsEnabled() {
        XCTAssertTrue(HapticsPreference.isEnabled(defaults), "Sin preferencia guardada, las haptics deben estar activadas")
    }

    func testDisable() {
        HapticsPreference.setEnabled(false, defaults)
        XCTAssertFalse(HapticsPreference.isEnabled(defaults))
    }

    func testReEnable() {
        HapticsPreference.setEnabled(false, defaults)
        HapticsPreference.setEnabled(true, defaults)
        XCTAssertTrue(HapticsPreference.isEnabled(defaults))
    }

    func testPersistsAcrossInstances() {
        HapticsPreference.setEnabled(false, defaults)
        let other = UserDefaults(suiteName: suite)!
        XCTAssertFalse(HapticsPreference.isEnabled(other), "La preferencia debe persistir entre instancias de UserDefaults")
    }

    func testKeyStable() {
        XCTAssertEqual(HapticsPreference.key, "hapticsEnabled", "La clave debe coincidir con el @AppStorage de SettingsView")
    }

    func testSuiteIsolation() {
        HapticsPreference.setEnabled(false, defaults)
        let otherName = suite + ".other"
        let other = UserDefaults(suiteName: otherName)!
        other.removePersistentDomain(forName: otherName)
        XCTAssertTrue(HapticsPreference.isEnabled(other), "Otra suite no debe heredar el disabled")
        other.removePersistentDomain(forName: otherName)
    }
}
