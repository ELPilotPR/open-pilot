import Foundation
import SwiftData

@Model
final class Message {
    @Attribute(.unique) var id: UUID
    var role: String          // "user" | "assistant" | "system"
    var text: String
    var reasoning: String
    var sourcesData: Data = Data()   // [WebSource] codificado (fuentes del browse)
    var imageData: Data = Data()     // foto adjunta (user) o imagen generada (assistant)
    var attachmentName: String?      // nombre del archivo adjunto (PDF/doc/código)
    var attachmentText: String?      // texto extraído del archivo (se envía al modelo)
    var weatherData: Data = Data()   // WeatherSnapshot codificado (tarjeta de clima)
    var currencyData: Data = Data()  // CurrencySnapshot codificado (tarjeta de divisas)
    var citationsData: Data = Data() // [CitationReference] (contrato content_references)
    var promptTokens: Int = 0
    var completionTokens: Int = 0
    var tokensPerSecond: Double = 0
    var createdAt: Date
    var conversation: Conversation?

    // Árbol de versiones: cada mensaje apunta a su predecesor
    // en la rama. Editar un user / regenerar un assistant crea hermanos con el
    // mismo parentID; `version` los ordena y `preferredChildID` recuerda la rama
    // elegida al navegar < n/m >.
    var parentID: UUID?
    var version: Int = 1
    var preferredChildID: UUID?

    init(role: String, text: String = "", reasoning: String = "") {
        self.id = UUID()
        self.role = role
        self.text = text
        self.reasoning = reasoning
        self.createdAt = Date()
    }

    var sources: [WebSource] {
        get { (try? JSONDecoder().decode([WebSource].self, from: sourcesData)) ?? [] }
        set { sourcesData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }
    /// Tarjeta de clima (Open-Meteo) embebida en la respuesta.
    var weather: WeatherSnapshot? {
        get { try? JSONDecoder().decode(WeatherSnapshot.self, from: weatherData) }
        set { weatherData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }
    /// Tarjeta de divisas (frankfurter.dev) embebida en la respuesta.
    var currency: CurrencySnapshot? {
        get { try? JSONDecoder().decode(CurrencySnapshot.self, from: currencyData) }
        set { currencyData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }
    /// Citas estructuradas (content_references) derivadas de [n] + fuentes.
    var citations: [CitationReference] {
        get { (try? JSONDecoder().decode([CitationReference].self, from: citationsData)) ?? [] }
        set { citationsData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }
}