import Foundation

/// Conversión de divisas en el cliente, sin backend ni key. Usa frankfurter.dev
/// (tasas del BCE, gratis). La app detecta la intención, trae la tasa + serie de
/// 30 días y pinta una tarjeta; el modelo solo redacta 1-2 frases. Todo se guarda
/// en el iPhone.

struct CurrencySnapshot: Codable, Sendable {
    var amount: Double
    var from: String
    var to: String
    var fromName: String
    var toName: String
    var rate: Double          // 1 from = rate to
    var converted: Double     // amount * rate
    var date: String          // yyyy-MM-dd de la tasa
    var history: [Point]      // serie ~30 días (1 from -> to)

    struct Point: Codable, Sendable {
        var date: String
        var value: Double
    }
}

enum CurrencyService {

    // MARK: - Detección / parseo (puro, sin red)

    /// Mapa palabra→código (sin acentos; el query se pliega antes). "peso"→MXN
    /// por defecto (el usuario está en EE. UU.).
    private static let wordMap: [String: String] = [
        "usd": "USD", "dolar": "USD", "dolares": "USD", "dollar": "USD", "dollars": "USD",
        "eur": "EUR", "euro": "EUR", "euros": "EUR",
        "mxn": "MXN", "peso": "MXN", "pesos": "MXN", "mexicano": "MXN",
        "gbp": "GBP", "libra": "GBP", "libras": "GBP", "pound": "GBP", "pounds": "GBP",
        "jpy": "JPY", "yen": "JPY", "yenes": "JPY",
        "cad": "CAD", "chf": "CHF", "franco": "CHF", "franc": "CHF", "francos": "CHF",
        "cny": "CNY", "yuan": "CNY", "renminbi": "CNY",
        "brl": "BRL", "real": "BRL", "reales": "BRL",
        "ars": "ARS", "cop": "COP", "clp": "CLP", "pen": "PEN",
        "krw": "KRW", "won": "KRW", "inr": "INR", "rupia": "INR", "rupee": "INR", "rupees": "INR",
        "aud": "AUD", "nzd": "NZD", "sek": "SEK", "nok": "NOK", "dkk": "DKK",
        "pln": "PLN", "try": "TRY", "lira": "TRY", "rub": "RUB", "rublo": "RUB",
        "zar": "ZAR", "rand": "ZAR", "sgd": "SGD", "hkd": "HKD", "thb": "THB", "baht": "THB",
    ]

    private static let names: [String: String] = [
        "USD": "dólar estadounidense", "EUR": "euro", "MXN": "peso mexicano",
        "GBP": "libra esterlina", "JPY": "yen japonés", "CAD": "dólar canadiense",
        "CHF": "franco suizo", "CNY": "yuan chino", "BRL": "real brasileño",
        "ARS": "peso argentino", "COP": "peso colombiano", "CLP": "peso chileno",
        "PEN": "sol peruano", "KRW": "won surcoreano", "INR": "rupia india",
        "AUD": "dólar australiano", "NZD": "dólar neozelandés", "SEK": "corona sueca",
        "NOK": "corona noruega", "DKK": "corona danesa", "PLN": "esloti polaco",
        "TRY": "lira turca", "RUB": "rublo ruso", "ZAR": "rand sudafricano",
        "SGD": "dólar de Singapur", "HKD": "dólar de Hong Kong", "THB": "baht tailandés",
    ]

    /// Extrae (cantidad, desde, hacia) si el query pide una conversión clara
    /// (dos divisas distintas). Devuelve nil si no → el modelo responde normal.
    static func parse(_ query: String) -> (amount: Double, from: String, to: String)? {
        let folded = query.lowercased().folding(options: .diacriticInsensitive, locale: .current)
        let words = folded.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }
        var codes: [String] = []
        for w in words {
            if let c = wordMap[w], !codes.contains(c) { codes.append(c) }
        }
        if folded.contains("€"), !codes.contains("EUR") { codes.append("EUR") }
        if folded.contains("£"), !codes.contains("GBP") { codes.append("GBP") }
        if folded.contains("¥"), !codes.contains("JPY") { codes.append("JPY") }
        guard codes.count >= 2 else { return nil }
        let from = codes[0], to = codes[1]
        guard from != to else { return nil }
        var amount: Double = 1
        for w in words {
            let norm = w.replacingOccurrences(of: ",", with: ".")
            if let d = Double(norm), d > 0 { amount = d; break }
        }
        return (amount, from, to)
    }

    static func isCurrencyQuery(_ query: String) -> Bool { parse(query) != nil }

    // MARK: - Red (frankfurter.dev, sin key)

    static func fetch(amount: Double, from: String, to: String) async -> CurrencySnapshot? {
        guard let latestURL = URL(string: "https://api.frankfurter.dev/v1/latest?base=\(from)&symbols=\(to)"),
              let latest = try? await getJSON(latestURL),
              let rates = latest["rates"] as? [String: Any],
              let rate = (rates[to] as? NSNumber)?.doubleValue, rate > 0
        else { return nil }
        let date = (latest["date"] as? String) ?? ""

        // serie de ~30 días para el sparkline
        var history: [CurrencySnapshot.Point] = []
        let end = Date()
        let start = Calendar.current.date(byAdding: .day, value: -30, to: end) ?? end
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; f.locale = Locale(identifier: "en_US_POSIX")
        if let tsURL = URL(string: "https://api.frankfurter.dev/v1/\(f.string(from: start))..\(f.string(from: end))?base=\(from)&symbols=\(to)"),
           let ts = try? await getJSON(tsURL),
           let series = ts["rates"] as? [String: [String: Any]] {
            history = series.keys.sorted().compactMap { day in
                guard let v = (series[day]?[to] as? NSNumber)?.doubleValue else { return nil }
                return CurrencySnapshot.Point(date: day, value: v)
            }
        }

        return CurrencySnapshot(amount: amount, from: from, to: to,
                                fromName: names[from] ?? from, toName: names[to] ?? to,
                                rate: rate, converted: amount * rate, date: date, history: history)
    }

    private static func getJSON(_ url: URL) async throws -> [String: Any] {
        var req = URLRequest(url: url)
        req.timeoutInterval = 15
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, http.statusCode == 200,
              let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { throw NSError(domain: "currency", code: -1) }
        return obj
    }

    // MARK: - Contexto para el modelo (tarjeta ya visible)

    static func summaryContext(_ s: CurrencySnapshot) -> String {
        let conv = String(format: "%.2f", s.converted)
        let rate = String(format: "%.4f", s.rate)
        return """
        El usuario pide una conversión de divisas. La app YA muestra una tarjeta visual con el \
        resultado y la tendencia de 30 días, así que NO repitas las cifras, NO hagas listas ni \
        tablas ni enumeres fuentes. Responde en 1-2 frases naturales confirmando la conversión \
        (\(String(format: "%.2f", s.amount)) \(s.from) ≈ \(conv) \(s.to), tasa \(rate)) y, si acaso, \
        un comentario breve sobre la tendencia. Sin disclaimers financieros largos.
        """
    }
}