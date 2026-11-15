import XCTest
import SwiftData
@testable import OpenPilot

/// Regresión del bug "no puedo agregar modelos": SwiftData no observa ni persiste
/// fiable la mutación in-place (.append/.remove) de un [String] en un @Model.
/// El fix reasigna el array completo (SET). Estos tests verifican el ciclo real
/// insert → reasignar → save → fetch sobre un contenedor en memoria.
@MainActor
final class ProviderConfigModelsTests: XCTestCase {

    private func makeContext() throws -> ModelContext {
        let schema = Schema([ProviderConfig.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return ModelContext(container)
    }

    func testAddModelByReassignmentPersists() throws {
        let ctx = try makeContext()
        let p = ProviderConfig(id: "t1", name: "T", baseURL: "https://x", models: ["a"])
        ctx.insert(p)
        try ctx.save()
        p.models = p.models + ["b"]          // el fix: reasignar, no .append
        try ctx.save()
        let fetched = try ctx.fetch(FetchDescriptor<ProviderConfig>())
        XCTAssertEqual(fetched.first?.models, ["a", "b"])
    }

    func testDiscoverDedupesAgainstExisting() throws {
        let ctx = try makeContext()
        let p = ProviderConfig(id: "t2", name: "T", baseURL: "https://x", models: ["m1"])
        ctx.insert(p)
        let ms = ["m1", "m2", "m3"]
        let fresh = ms.filter { !p.models.contains($0) }
        p.models = p.models + fresh
        try ctx.save()
        XCTAssertEqual(p.models, ["m1", "m2", "m3"])
    }

    func testRemoveByReassignmentPersists() throws {
        let ctx = try makeContext()
        let p = ProviderConfig(id: "t3", name: "T", baseURL: "https://x", models: ["a", "b", "c"])
        ctx.insert(p)
        try ctx.save()
        var copy = p.models
        copy.remove(atOffsets: IndexSet(integer: 1))
        p.models = copy
        try ctx.save()
        let fetched = try ctx.fetch(FetchDescriptor<ProviderConfig>())
        XCTAssertEqual(fetched.first?.models, ["a", "c"])
    }

    func testAddManyModelsAllPersist() throws {
        let ctx = try makeContext()
        let p = ProviderConfig(id: "t4", name: "T", baseURL: "https://x", models: [])
        ctx.insert(p)
        for m in ["qwen-plus", "qwen-max", "qwen-turbo", "qwen-long"] {
            if !p.models.contains(m) { p.models = p.models + [m] }
        }
        try ctx.save()
        let fetched = try ctx.fetch(FetchDescriptor<ProviderConfig>())
        XCTAssertEqual(fetched.first?.models.count, 4)
        XCTAssertEqual(fetched.first?.models.last, "qwen-long")
    }
}