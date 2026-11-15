import Foundation

/// Salud del dispositivo para inferencia local (GGUF): estado térmico, ajuste
/// del modelo a la RAM disponible y detección de throttling de tok/s.
/// 100% local, sin backend. La lógica pura es testeable sin el runtime; los
/// wrappers en vivo leen `ProcessInfo`.
///
/// Motiva: los fallos #1 de LLM local en iPhone son (a) calor → throttling que
/// desploma los tok/s y (b) OOM por cargar un modelo que no cabe en la RAM que
/// iOS permite por app. Este servicio avisa de ambos antes de que ocurran.

/// Nivel térmico del dispositivo (mapea `ProcessInfo.ThermalState`).
enum ThermalTier: Int, Comparable {
    case nominal = 0, fair = 1, serious = 2, critical = 3

    static func < (a: ThermalTier, b: ThermalTier) -> Bool { a.rawValue < b.rawValue }

    static func from(_ state: ProcessInfo.ThermalState) -> ThermalTier {
        switch state {
        case .nominal: return .nominal
        case .fair: return .fair
        case .serious: return .serious
        case .critical: return .critical
        @unknown default: return .fair
        }
    }

    /// true si conviene avisar al usuario (serious / critical).
    var shouldWarn: Bool { self >= .serious }

    var symbol: String {
        switch self {
        case .nominal: return "thermometer.low"
        case .fair: return "thermometer.medium"
        case .serious: return "thermometer.high"
        case .critical: return "thermometer.sun.fill"
        }
    }

    var label: String {
        switch self {
        case .nominal: return T("Cool", "Fresco")
        case .fair: return T("Warm", "Tibio")
        case .serious: return T("Hot — slowing down", "Caliente — bajando velocidad")
        case .critical: return T("Very hot — pause recommended", "Muy caliente — pausa recomendada")
        }
    }

    var advice: String {
        switch self {
        case .nominal, .fair:
            return T("Running at full speed.", "A velocidad completa.")
        case .serious:
            return T("iOS is throttling to cool down; tokens/s may drop. A smaller model or a short pause helps.",
                     "iOS reduce el rendimiento para enfriar; los tok/s pueden bajar. Un modelo menor o una pausa ayuda.")
        case .critical:
            return T("Let the device cool before continuing to avoid a shutdown.",
                     "Deja enfriar el dispositivo antes de seguir para evitar un apagado.")
        }
    }
}

/// Estimación de si un modelo GGUF cabe en la RAM que iOS deja por app.
/// Aproximación conservadora: presupuesto ≈ mitad de la RAM física; pico ≈
/// pesos + overhead del runtime + KV cache. Solo orientativo (no es una promesa).
struct ModelFit: Equatable {
    enum Tier: Int { case comfortable = 0, tight = 1, wontFit = 2 }

    let tier: Tier
    let estimatedPeakGB: Double
    let budgetGB: Double

    /// Overhead fijo del runtime + activaciones (GB).
    static let runtimeOverheadGB = 0.6
    /// KV cache aproximado: ~0.5 GB por cada millón de tokens de contexto.
    static let kvGBPerMillionTokens = 0.5

    static func assess(sizeGB: Double, deviceRAMGB: Double, contextTokens: Int) -> ModelFit {
        let budget = max(0.5, deviceRAMGB * 0.5)
        let kv = Double(max(0, contextTokens)) / 1_000_000 * kvGBPerMillionTokens
        let peak = max(0, sizeGB) + runtimeOverheadGB + kv
        let tier: Tier
        if peak > budget { tier = .wontFit }
        else if peak > budget * 0.8 { tier = .tight }
        else { tier = .comfortable }
        return ModelFit(tier: tier, estimatedPeakGB: peak, budgetGB: budget)
    }

    var symbol: String {
        switch tier {
        case .comfortable: return "checkmark.circle.fill"
        case .tight: return "exclamationmark.triangle.fill"
        case .wontFit: return "xmark.octagon.fill"
        }
    }

    var label: String {
        switch tier {
        case .comfortable: return T("Fits this iPhone", "Cabe en este iPhone")
        case .tight: return T("Tight on RAM", "Justo de RAM")
        case .wontFit: return T("Too large for this iPhone", "Demasiado grande para este iPhone")
        }
    }
}

/// Detecta una caída sostenida de tok/s (throttling térmico) comparando la
/// velocidad actual contra una línea base de la misma sesión.
enum ThrottleDetector {
    /// Aviso si la velocidad cae por debajo del 60% de la base (≥40% de caída).
    static func isThrottling(baseline: Double, current: Double) -> Bool {
        guard baseline > 1, current > 0 else { return false }
        return current < baseline * 0.6
    }

    static func dropPercent(baseline: Double, current: Double) -> Int {
        guard baseline > 0 else { return 0 }
        return max(0, Int(((baseline - current) / baseline * 100).rounded()))
    }
}

/// Wrappers en vivo (leen el dispositivo). La lógica de arriba es pura.
enum DeviceHealth {
    static var thermalTier: ThermalTier { ThermalTier.from(ProcessInfo.processInfo.thermalState) }

    static var physicalRAMGB: Double {
        Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824
    }

    static func fit(for model: GGUFModel, contextTokens: Int = 8192) -> ModelFit {
        ModelFit.assess(sizeGB: model.sizeGB, deviceRAMGB: physicalRAMGB, contextTokens: contextTokens)
    }
}