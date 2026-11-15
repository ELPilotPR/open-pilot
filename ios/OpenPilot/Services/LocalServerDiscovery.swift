import Foundation
#if canImport(Darwin)
import Darwin
#endif

/// Un servidor local de inferencia encontrado en la red (Ollama / LM Studio).
struct LocalServer: Identifiable, Hashable, Sendable {
    let id: String          // base URL, p. ej. http://192.168.1.50:11434/v1
    let name: String        // "Ollama" / "LM Studio"
    let baseURL: String
    let models: [String]
}

/// Descubre servidores OpenAI-compatible en la red local (Ollama :11434,
/// LM Studio :1234) sin ningún backend propio: sondea la subred /24 del iPhone
/// con GET /models. Los helpers puros son testeables sin red.
enum LocalServerDiscovery {
    static let ollamaPort = 11434
    static let lmStudioPort = 1234

    /// URLs candidatas (Ollama + LM Studio) para cada host de una subred /24.
    static func candidates(subnet: String, hosts: ClosedRange<Int> = 1...254) -> [String] {
        var out: [String] = []
        for h in hosts {
            out.append("http://\(subnet).\(h):\(ollamaPort)/v1")
            out.append("http://\(subnet).\(h):\(lmStudioPort)/v1")
        }
        return out
    }

    /// Prefijo /24 de una IPv4: "192.168.1.42" -> "192.168.1". nil si no es IPv4.
    static func subnetPrefix(ofIPv4 ip: String) -> String? {
        let parts = ip.split(separator: ".")
        guard parts.count == 4, parts.allSatisfy({ Int($0) != nil }) else { return nil }
        return parts.prefix(3).joined(separator: ".")
    }

    static func serverName(port: Int) -> String {
        if port == ollamaPort { return "Ollama" }
        if port == lmStudioPort { return "LM Studio" }
        return "Server"
    }

    /// Puerto y etiqueta de una base URL candidata.
    static func info(forBaseURL base: String) -> (port: Int, name: String)? {
        guard let comps = URLComponents(string: base), let port = comps.port else { return nil }
        return (port, serverName(port: port))
    }

    /// IPv4 actual del dispositivo (en0/en1). nil en simulador sin interfaz.
    static func currentIPv4() -> String? {
        #if canImport(Darwin)
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return nil }
        defer { freeifaddrs(ifaddr) }
        for ptr in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let iface = ptr.pointee
            guard iface.ifa_addr.pointee.sa_family == UInt8(AF_INET) else { continue }
            let name = String(cString: iface.ifa_name)
            guard name == "en0" || name == "en1" else { continue }
            var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            getnameinfo(iface.ifa_addr, socklen_t(iface.ifa_addr.pointee.sa_len),
                        &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST)
            address = String(cString: host)
        }
        return address
        #else
        return nil
        #endif
    }

    /// Sondea una base URL (GET /models) con timeout corto. Devuelve los ids de
    /// modelo si responde 2xx con JSON OpenAI-compatible; nil si no alcanza.
    static func probe(baseURL: String, timeout: TimeInterval = 1.5) async -> [String]? {
        guard let url = URL(string: baseURL + "/models") else { return nil }
        var req = URLRequest(url: url)
        req.timeoutInterval = timeout
        req.httpMethod = "GET"
        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { return nil }
            if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let arr = obj["data"] as? [[String: Any]] {
                return arr.compactMap { $0["id"] as? String }
            }
            return []
        } catch {
            return nil
        }
    }

    /// Escanea la subred /24 con concurrencia limitada. `onFound` se invoca por
    /// cada servidor alcanzable (para mostrar progreso). Devuelve todos, ordenados.
    static func scan(subnet: String, limit: Int = 24,
                     onFound: (@Sendable (LocalServer) -> Void)? = nil) async -> [LocalServer] {
        let urls = candidates(subnet: subnet)
        var found: [LocalServer] = []
        await withTaskGroup(of: LocalServer?.self) { group in
            var next = 0
            func enqueue() {
                guard next < urls.count else { return }
                let base = urls[next]; next += 1
                group.addTask {
                    guard let models = await probe(baseURL: base) else { return nil }
                    let info = LocalServerDiscovery.info(forBaseURL: base)
                    return LocalServer(id: base, name: info?.name ?? "Server",
                                       baseURL: base, models: models)
                }
            }
            for _ in 0..<min(limit, urls.count) { enqueue() }
            while let result = await group.next() {
                if let srv = result {
                    found.append(srv)
                    onFound?(srv)
                }
                enqueue()
            }
        }
        return found.sorted { $0.baseURL < $1.baseURL }
    }
}