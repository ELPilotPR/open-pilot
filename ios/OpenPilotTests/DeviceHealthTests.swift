import XCTest
@testable import OpenPilot

final class DeviceHealthTests: XCTestCase {
    // MARK: - ThermalTier
    func testThermalMapping() {
        XCTAssertEqual(ThermalTier.from(.nominal), .nominal)
        XCTAssertEqual(ThermalTier.from(.fair), .fair)
        XCTAssertEqual(ThermalTier.from(.serious), .serious)
        XCTAssertEqual(ThermalTier.from(.critical), .critical)
    }
    func testThermalOrdering() {
        XCTAssertTrue(ThermalTier.nominal < .fair)
        XCTAssertTrue(ThermalTier.fair < .serious)
        XCTAssertTrue(ThermalTier.serious < .critical)
    }
    func testThermalShouldWarn() {
        XCTAssertFalse(ThermalTier.nominal.shouldWarn)
        XCTAssertFalse(ThermalTier.fair.shouldWarn)
        XCTAssertTrue(ThermalTier.serious.shouldWarn)
        XCTAssertTrue(ThermalTier.critical.shouldWarn)
    }
    func testThermalLabelsNonEmpty() {
        for t in [ThermalTier.nominal, .fair, .serious, .critical] {
            XCTAssertFalse(t.label.isEmpty)
            XCTAssertFalse(t.advice.isEmpty)
            XCTAssertFalse(t.symbol.isEmpty)
        }
    }

    // MARK: - ModelFit
    func testFitComfortableSmallModel() {
        let f = ModelFit.assess(sizeGB: 0.4, deviceRAMGB: 6, contextTokens: 8192)
        XCTAssertEqual(f.tier, .comfortable)
        XCTAssertEqual(f.budgetGB, 3.0, accuracy: 0.0001)
    }
    func testFitWontFitLargeModelOn6GB() {
        let f = ModelFit.assess(sizeGB: 2.5, deviceRAMGB: 6, contextTokens: 8192)
        XCTAssertEqual(f.tier, .wontFit)
    }
    func testFitTightMidModel() {
        let f = ModelFit.assess(sizeGB: 2.0, deviceRAMGB: 6, contextTokens: 8192)
        XCTAssertEqual(f.tier, .tight)
    }
    func testFitWontFitOnOldDevice() {
        let f = ModelFit.assess(sizeGB: 1.0, deviceRAMGB: 3, contextTokens: 8192)
        XCTAssertEqual(f.tier, .wontFit)
    }
    func testFitComfortableOn8GB() {
        let f = ModelFit.assess(sizeGB: 2.5, deviceRAMGB: 8, contextTokens: 8192)
        XCTAssertEqual(f.tier, .comfortable)
    }
    func testFitZeroRAMSafe() {
        let f = ModelFit.assess(sizeGB: 1.0, deviceRAMGB: 0, contextTokens: 8192)
        XCTAssertEqual(f.budgetGB, 0.5, accuracy: 0.0001)
        XCTAssertEqual(f.tier, .wontFit)
    }
    func testFitContextRaisesPeak() {
        let small = ModelFit.assess(sizeGB: 1.0, deviceRAMGB: 8, contextTokens: 8192)
        let big = ModelFit.assess(sizeGB: 1.0, deviceRAMGB: 8, contextTokens: 1_000_000)
        XCTAssertGreaterThan(big.estimatedPeakGB, small.estimatedPeakGB)
        XCTAssertEqual(big.estimatedPeakGB - small.estimatedPeakGB, 0.5, accuracy: 0.01)
    }
    func testFitLabelsNonEmpty() {
        for tier in [ModelFit.Tier.comfortable, .tight, .wontFit] {
            let f = ModelFit(tier: tier, estimatedPeakGB: 1, budgetGB: 3)
            XCTAssertFalse(f.label.isEmpty)
            XCTAssertFalse(f.symbol.isEmpty)
        }
    }

    // MARK: - ThrottleDetector
    func testThrottleDetected() {
        XCTAssertTrue(ThrottleDetector.isThrottling(baseline: 40, current: 20))
    }
    func testThrottleNotDetectedMildDrop() {
        XCTAssertFalse(ThrottleDetector.isThrottling(baseline: 40, current: 30))
    }
    func testThrottleGuards() {
        XCTAssertFalse(ThrottleDetector.isThrottling(baseline: 0, current: 0))
        XCTAssertFalse(ThrottleDetector.isThrottling(baseline: 40, current: 0))
        XCTAssertFalse(ThrottleDetector.isThrottling(baseline: 0.5, current: 0.1))
    }
    func testDropPercent() {
        XCTAssertEqual(ThrottleDetector.dropPercent(baseline: 40, current: 20), 50)
        XCTAssertEqual(ThrottleDetector.dropPercent(baseline: 40, current: 40), 0)
        XCTAssertEqual(ThrottleDetector.dropPercent(baseline: 0, current: 10), 0)
        XCTAssertEqual(ThrottleDetector.dropPercent(baseline: 40, current: 50), 0)
    }

    // MARK: - Live wrappers
    func testPhysicalRAMPositive() {
        XCTAssertGreaterThan(DeviceHealth.physicalRAMGB, 0)
    }
    func testFitForCatalogModel() {
        let m = GGUFSupport.catalog[0]
        let f = DeviceHealth.fit(for: m)
        XCTAssertGreaterThan(f.budgetGB, 0)
        XCTAssertGreaterThan(f.estimatedPeakGB, 0)
    }
}