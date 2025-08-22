import SharedTypes
import SwiftUI

enum HttpError: Error {
    case generic(Error)
    case message(String)
}

func requestHttp(_ request: HttpRequest) async -> Result<HttpResponse, HttpError> {
    // TEMPORARY: Hardcode server URL to bypass Config.plist issue
    let serverBaseURL = "http://localhost:3000"
    
    // Replace any external URLs with our local server
    var finalURL = request.url
    if request.url.contains("appwrite.io") || request.url.contains("fra.cloud") {
        // Replace Appwrite URLs with local server endpoints
        if request.url.contains("/databases/") {
            finalURL = "\(serverBaseURL)/api/goals"  // Map database requests to goals endpoint
        } else {
            finalURL = "\(serverBaseURL)/api/goals"  // Default to goals endpoint
        }
    } else if request.url.hasPrefix("http://localhost:3000") {
        finalURL = request.url  // Keep localhost URLs as-is
    } else {
        finalURL = "\(serverBaseURL)/api/goals"  // Default fallback
    }
    
    print("🌐 HTTP Request Debug:")
    print("   Original URL: \(request.url)")
    print("   Server Base URL: \(serverBaseURL)")
    print("   Final URL: \(finalURL)")
    print("   Method: \(request.method)")
    
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