import Foundation

/// Clima 100% cliente, SIN backend y SIN key: Open-Meteo (geocoding + forecast).
/// El diseño de la tarjeta es GenUI:
/// location + temperatura grande + toggle F/C + tira diaria + gráfica horaria.
/// Los datos se guardan canónicos en °C / km·h y la vista convierte a F / mph.

struct WeatherSnapshot: Codable, Sendable {
    var location: String
    var region: String
    var countryCode: String
    var latitude: Double
    var longitude: Double
    var defaultUnit: String   // "F" (US) o "C"
    var current: Current
    var daily: [Day]
    var hourly: [Hour]
    var fetchedAt: Date

    struct Current: Codable, Sendable {
        var temp: Double          // °C
        var feelsLike: Double     // °C
        var humidity: Int
        var windSpeed: Double     // km/h
        var windDirection: Double // grados
        var code: Int
        var isDay: Bool
    }
    struct Day: Codable, Sendable {
        var date: String          // yyyy-MM-dd
        var label: String         // "Hoy", "Mañana", "Sáb 15"
        var code: Int
        var high: Double          // °C
        var low: Double           // °C
        var precip: Int           // %
        var sunrise: String       // "06:41"
        var sunset: String        // "16:29"
    }
    struct Hour: Codable, Sendable {
        var time: String          // ISO local
        var dayKey: String        // yyyy-MM-dd
        var label: String         // "2 PM"
        var temp: Double          // °C
        var code: Int
        var precip: Int           // %
    }
}

/// Códigos WMO → descripción en español + SF Symbol (el color lo pone la vista).
enum WMO {
    static func describe(_ code: Int, isDay: Bool = true) -> (desc: String, symbol: String) {
        switch code {
        case 0: return (isDay ? "Despejado" : "Despejado", isDay ? "sun.max.fill" : "moon.stars.fill")
        case 1: return ("Mayormente despejado", isDay ? "sun.max.fill" : "moon.stars.fill")
        case 2: return ("Parcialmente nublado", isDay ? "cloud.sun.fill" : "cloud.moon.fill")
        case 3: return ("Nublado", "cloud.fill")
        case 45, 48: return ("Niebla", "cloud.fog.fill")
        case 51, 53, 55: return ("Llovizna", "cloud.drizzle.fill")
        case 56, 57: return ("Llovizna helada", "cloud.sleet.fill")
        case 61, 63, 65: return ("Lluvia", "cloud.rain.fill")
        case 66, 67: return ("Lluvia helada", "cloud.sleet.fill")
        case 71, 73, 75, 77: return ("Nieve", "cloud.snow.fill")
        case 80, 81, 82: return ("Chubascos", "cloud.heavyrain.fill")
        case 85, 86: return ("Chubascos de nieve", "cloud.snow.fill")
        case 95: return ("Tormenta", "cloud.bolt.rain.fill")
        case 96, 99: return ("Tormenta con granizo", "cloud.bolt.rain.fill")
        default: return ("Variable", "cloud.sun.fill")
        }
    }
    /// Rosa de los vientos en español (8 rumbos).
    static func windDir(_ deg: Double) -> String {
        let dirs = ["N", "NE", "E", "SE", "S", "SO", "O", "NO"]
        let i = Int((deg + 22.5) / 45.0) % 8
        return dirs[i]
    }
}

enum WeatherService {

    // MARK: - Detección de intención

    static func isWeatherQuery(_ q: String) -> Bool {
        let s = q.lowercased()
        let keys = ["clima", "weather", "temperatura", "lluvia", "llover", "llueva",
                    "pronóstico", "pronostico", "forecast", "nevar", "nevada", "humedad"]
        if keys.contains(where: { s.contains($0) }) { return true }
        // "tiempo" es ambiguo (clima / duración): solo si pinta a clima.
        if s.contains("tiempo") {
            let dur = ["cuanto tiempo", "cuánto tiempo", "tiempo tarda", "tiempo dura",
                       "tiempo lleva", "tiempo falta", "tiempo de", "mucho tiempo", "poco tiempo"]
            if !dur.contains(where: { s.contains($0) }) &&
                (s.contains("hace") || s.contains("está el tiempo") || s.contains("esta el tiempo") ||
                 s.contains("como esta") || s.contains("cómo está") || s.contains("el clima")) {
                return true
            }
        }
        return false
    }

    /// Saca el lugar de la pregunta. "en <lugar>" es la señal fuerte; si no,
    /// limpia palabras de clima/pregunta y se queda con el resto.
    static func extractLocation(from q: String) -> String? {
        let s = q.replacingOccurrences(of: "¿", with: "")
                 .replacingOccurrences(of: "?", with: "")
                 .trimmingCharacters(in: .whitespacesAndNewlines)
        // "en" / "in" → el lugar viene detrás (señal fuerte).
        for sep in [" en ", " in "] {
            if let r = s.range(of: sep, options: .caseInsensitive) {
                let place = stripTail(String(s[r.upperBound...]))
                if !place.isEmpty { return place }
            }
        }
        // Sin separador: limpia coletillas de clima/pregunta (preserva el case).
        let drop: Set<String> = ["como", "cómo", "esta", "está", "el", "la", "tiempo",
            "clima", "weather", "hace", "hoy", "mañana", "ahora", "en", "in", "de", "del",
            "que", "qué", "va", "a", "llover", "temperatura", "pronóstico", "pronostico",
            "por", "favor", "dime", "sobre", "the", "what", "whats", "is", "like",
            "today", "tomorrow", "and", "y"]
        let words = s.split(separator: " ").map(String.init)
        let kept = words.filter { !drop.contains($0.lowercased()) }
        let place = stripTail(kept.joined(separator: " "))
        return place.isEmpty ? nil : place
    }

    private static func stripTail(_ s: String) -> String {
        var t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        let tails = ["hoy", "mañana", "ahora", "este fin de semana", "el fin de semana",
                     "por favor", "porfa", "ahorita", "esta semana", "los próximos días",
                     "los proximos dias", "y mañana"]
        for tail in tails {
            if t.lowercased().hasSuffix(tail) {
                t = String(t.dropLast(tail.count)).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return t.trimmingCharacters(in: CharacterSet(charactersIn: ".,;:! "))
    }

    // MARK: - Red (Open-Meteo, sin key)

    private static func getJSON(_ url: URL) async -> [String: Any]? {
        var req = URLRequest(url: url)
        req.timeoutInterval = 15
        req.setValue("OpenPilot/1.0", forHTTPHeaderField: "User-Agent")
        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              let http = resp as? HTTPURLResponse, http.statusCode == 200,
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        return obj
    }

    private struct Geo { var name, region, country: String; var lat, lon: Double }

    private static func geocode(_ place: String) async -> Geo? {
        // Prueba el lugar completo y, si falla, va quitando tokens finales
        // ("Racine WI" → "Racine").
        var candidates = [place]
        var words = place.split(separator: " ").map(String.init)
        while words.count > 1 {
            words.removeLast()
            candidates.append(words.joined(separator: " "))
        }
        for cand in candidates {
            let enc = cand.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? cand
            guard let url = URL(string: "https://geocoding-api.open-meteo.com/v1/search?name=\(enc)&count=1&language=es&format=json"),
                  let obj = await getJSON(url),
                  let results = obj["results"] as? [[String: Any]], let r = results.first
            else { continue }
            let name = r["name"] as? String ?? cand
            let region = r["admin1"] as? String ?? ""
            let country = r["country_code"] as? String ?? ""
            let lat = r["latitude"] as? Double ?? 0
            let lon = r["longitude"] as? Double ?? 0
            if lat != 0 || lon != 0 { return Geo(name: name, region: region, country: country, lat: lat, lon: lon) }
        }
        return nil
    }

    /// Busca el clima del lugar de la pregunta. nil si no es clima o no geocodifica.
    static func fetch(query: String) async -> WeatherSnapshot? {
        guard let place = extractLocation(from: query), !place.isEmpty,
              let geo = await geocode(place) else { return nil }

        let comps = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        // Canónico métrico; la vista convierte a F/mph si el usuario alterna.
        var url = comps.url!
        url = URL(string: "https://api.open-meteo.com/v1/forecast?latitude=\(geo.lat)&longitude=\(geo.lon)"
            + "&current=temperature_2m,relative_humidity_2m,apparent_temperature,weather_code,wind_speed_10m,wind_direction_10m,is_day"
            + "&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max,sunrise,sunset"
            + "&hourly=temperature_2m,weather_code,precipitation_probability"
            + "&timezone=auto&forecast_days=6")!
        guard let obj = await getJSON(url),
              let cur = obj["current"] as? [String: Any],
              let daily = obj["daily"] as? [String: Any],
              let hourly = obj["hourly"] as? [String: Any]
        else { return nil }

        let current = WeatherSnapshot.Current(
            temp: cur["temperature_2m"] as? Double ?? 0,
            feelsLike: cur["apparent_temperature"] as? Double ?? 0,
            humidity: cur["relative_humidity_2m"] as? Int ?? 0,
            windSpeed: cur["wind_speed_10m"] as? Double ?? 0,
            windDirection: cur["wind_direction_10m"] as? Double ?? 0,
            code: cur["weather_code"] as? Int ?? 0,
            isDay: (cur["is_day"] as? Int ?? 1) == 1)

        let dTime = daily["time"] as? [String] ?? []
        let dCode = daily["weather_code"] as? [Int] ?? []
        let dMax = daily["temperature_2m_max"] as? [Double] ?? []
        let dMin = daily["temperature_2m_min"] as? [Double] ?? []
        let dPrec = daily["precipitation_probability_max"] as? [Int?] ?? []
        let dRise = daily["sunrise"] as? [String] ?? []
        let dSet = daily["sunset"] as? [String] ?? []
        var days: [WeatherSnapshot.Day] = []
        for i in 0..<min(dTime.count, 6) {
            days.append(.init(
                date: dTime[i],
                label: dayLabel(dTime[i], index: i),
                code: i < dCode.count ? dCode[i] : 0,
                high: i < dMax.count ? dMax[i] : 0,
                low: i < dMin.count ? dMin[i] : 0,
                precip: (i < dPrec.count ? dPrec[i] : nil) ?? 0,
                sunrise: clock(i < dRise.count ? dRise[i] : ""),
                sunset: clock(i < dSet.count ? dSet[i] : "")))
        }

        let hTime = hourly["time"] as? [String] ?? []
        let hTemp = hourly["temperature_2m"] as? [Double] ?? []
        let hCode = hourly["weather_code"] as? [Int] ?? []
        let hPrec = hourly["precipitation_probability"] as? [Int?] ?? []
        var hours: [WeatherSnapshot.Hour] = []
        for i in 0..<hTime.count {
            let t = hTime[i]
            let dayKey = String(t.prefix(10))
            hours.append(.init(
                time: t, dayKey: dayKey, label: hourLabel(t),
                temp: i < hTemp.count ? hTemp[i] : 0,
                code: i < hCode.count ? hCode[i] : 0,
                precip: (i < hPrec.count ? hPrec[i] : nil) ?? 0))
        }

        let loc = geo.region.isEmpty ? geo.name : "\(geo.name), \(geo.region)"
        return WeatherSnapshot(
            location: loc, region: geo.region, countryCode: geo.country,
            latitude: geo.lat, longitude: geo.lon,
            defaultUnit: geo.country == "US" ? "F" : "C",
            current: current, daily: days, hourly: hours, fetchedAt: Date())
    }

    /// Contexto para el modelo: la tarjeta YA se muestra, solo debe dar una
    /// frase natural + consejo práctico, sin repetir cifras.
    static func summaryContext(_ snap: WeatherSnapshot) -> String {
        let c = snap.current
        let desc = WMO.describe(c.code, isDay: c.isDay).desc.lowercased()
        let cc = Int(c.temp.rounded())
        let f = Int((c.temp * 9 / 5 + 32).rounded())
        var s = "El usuario pregunta por el tiempo en \(snap.location). La app YA muestra una tarjeta visual con el clima actual y el pronóstico, así que NO repitas cifras, NO hagas listas, tablas ni enumeres fuentes. "
        s += "Datos: ahora \(cc)°C (\(f)°F), \(desc), sensación \(Int(c.feelsLike.rounded()))°C"
        if let d = snap.daily.first {
            s += ", hoy máx \(Int(d.high.rounded()))°C / mín \(Int(d.low.rounded()))°C, prob. de lluvia \(d.precip)%"
        }
        s += ". Responde en español con 1 o 2 frases naturales y un consejo práctico (abrigo, paraguas, etc.). Nada más."
        return s
    }

    // MARK: - Etiquetas

    private static func dayLabel(_ iso: String, index: Int) -> String {
        if index == 0 { return "Hoy" }
        if index == 1 { return "Mañana" }
        let df = DateFormatter()
        df.locale = Locale(identifier: "es_ES")
        df.dateFormat = "yyyy-MM-dd"
        guard let d = df.date(from: iso) else { return iso }
        let out = DateFormatter()
        out.locale = Locale(identifier: "es_ES")
        out.dateFormat = "EEE d"
        return out.string(from: d).capitalized
    }

    private static func hourLabel(_ iso: String) -> String {
        // "2026-11-14T14:00" → "2 PM"
        guard let h = Int(iso.dropFirst(11).prefix(2)) else { return iso }
        if h == 0 { return "12 AM" }
        if h < 12 { return "\(h) AM" }
        if h == 12 { return "12 PM" }
        return "\(h - 12) PM"
    }

    private static func clock(_ iso: String) -> String {
        // "2026-11-14T06:41" → "06:41"
        iso.count >= 16 ? String(iso.dropFirst(11).prefix(5)) : iso
    }
}
