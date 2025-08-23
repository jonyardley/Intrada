import SharedTypes
import SwiftUI

enum HttpError: Error {
    case generic(Error)
    case message(String)
}

func requestHttp(_ request: HttpRequest) async -> Result<HttpResponse, HttpError> {
    // Use Mac IP for device builds, localhost for simulator
    #if targetEnvironment(simulator)
    let serverBaseURL = "http://localhost:3000"
    #else
    let serverBaseURL = "http://192.168.68.103:3000"
    #endif

    // Clean URL resolution: if it's already a full server URL, use as-is
    // Otherwise, treat it as a relative path and prepend the server base URL
    let finalURL: String = if request.url.hasPrefix("http://localhost:3000") || request.url.hasPrefix("http://192.168.68.103:3000") {
        request.url
    } else if request.url.hasPrefix("/") {
        // Relative path - prepend server base URL
        "\(serverBaseURL)\(request.url)"
    } else {
        // Assume it's a relative path without leading slash
        "\(serverBaseURL)/\(request.url)"
    }

    print("🌐 HTTP Request: \(request.method) \(finalURL)")

    var req = URLRequest(url: URL(string: finalURL)!)
    req.httpMethod = request.method

    for header in request.headers {
        req.addValue(header.value, forHTTPHeaderField: header.name)
    }

    if !request.body.isEmpty {
        req.httpBody = Data(request.body)
    }

    do {
        let (data, response) = try await URLSession.shared.data(for: req)
        if let httpResponse = response as? HTTPURLResponse {
            let status = UInt16(httpResponse.statusCode)
            let body = [UInt8](data)
            return .success(HttpResponse(status: status, headers: [], body: body))
        } else {
            return .failure(.message("bad response"))
        }
    } catch {
        return .failure(.generic(error))
    }
}