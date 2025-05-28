import Foundation
import UIKit

/// A utility class for debugging iOS build issues and runtime problems
class DebugUtility {
    
    /// Singleton instance
    static let shared = DebugUtility()
    
    /// Private initializer for singleton
    private init() {
        setupDebugMode()
    }
    
    /// Whether debug mode is enabled
    private(set) var debugModeEnabled: Bool = false
    
    /// The log level for debug prints
    var logLevel: LogLevel = .verbose
    
    /// Start time for app launch timing
    private let appStartTime = Date()
    
    /// Enum for log levels
    enum LogLevel: Int {
        case off = 0
        case error = 1
        case warning = 2
        case info = 3
        case debug = 4
        case verbose = 5
    }
    
    /// Setup debug mode based on environment
    private func setupDebugMode() {
        #if DEBUG
        debugModeEnabled = true
        debugPrint("DebugUtility: Debug mode enabled")
        #else
        debugModeEnabled = false
        #endif
        
        // Print system information on startup
        if debugModeEnabled {
            printSystemInfo()
        }
    }
    
    /// Log a message with a specific log level
    func log(_ message: String, level: LogLevel = .debug, file: String = #file, function: String = #function, line: Int = #line) {
        guard debugModeEnabled && level.rawValue <= logLevel.rawValue else { return }
        
        let timestamp = Date()
        let elapsedTime = timestamp.timeIntervalSince(appStartTime)
        let fileName = (file as NSString).lastPathComponent
        
        let levelString: String
        switch level {
        case .error:
            levelString = "❌ ERROR"
        case .warning:
            levelString = "⚠️ WARNING"
        case .info:
            levelString = "ℹ️ INFO"
        case .debug:
            levelString = "🔧 DEBUG"
        case .verbose:
            levelString = "🔎 VERBOSE"
        case .off:
            levelString = ""
        }
        
        print("[\(String(format: "%.3f", elapsedTime))s] \(levelString) [\(fileName):\(line)] \(function) - \(message)")
    }
    
    /// Print detailed system information for debugging
    func printSystemInfo() {
        log("==== SYSTEM INFORMATION ====", level: .info)
        log("Device: \(UIDevice.current.model)", level: .info)
        log("iOS Version: \(UIDevice.current.systemVersion)", level: .info)
        log("Device Name: \(UIDevice.current.name)", level: .info)
        log("System Name: \(UIDevice.current.systemName)", level: .info)
        log("Available Memory: \(getMemoryUsage())", level: .info)
        log("Bundle ID: \(Bundle.main.bundleIdentifier ?? "Unknown")", level: .info)
        log("Build Version: \(getBuildVersion())", level: .info)
        log("============================", level: .info)
    }
    
    /// Get memory usage as formatted string
    func getMemoryUsage() -> String {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let result: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if result == KERN_SUCCESS {
            let usedMB = Double(info.resident_size) / 1024.0 / 1024.0
            return String(format: "%.1f MB", usedMB)
        } else {
            return "Unknown"
        }
    }
    
    /// Get the build version string
    func getBuildVersion() -> String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
        return "\(version) (\(build))"
    }
    
    /// Check network reachability
    func checkNetworkReachability(urlString: String, completion: @escaping (Bool, Error?) -> Void) {
        guard let url = URL(string: urlString) else {
            completion(false, NSError(domain: "DebugUtility", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"]))
            return
        }
        
        let task = URLSession.shared.dataTask(with: url) { _, response, error in
            if let error = error {
                self.log("Network error: \(error.localizedDescription)", level: .error)
                completion(false, error)
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                self.log("Invalid response type", level: .error)
                completion(false, NSError(domain: "DebugUtility", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"]))
                return
            }
            
            let isSuccess = (200...299).contains(httpResponse.statusCode)
            self.log("Network test result: \(httpResponse.statusCode) \(isSuccess ? "Success" : "Failed")", level: .info)
            completion(isSuccess, nil)
        }
        
        task.resume()
    }
    
    /// Clear all cookies for a specific domain
    func clearCookies(for domain: String) {
        if let cookies = HTTPCookieStorage.shared.cookies {
            let domainCookies = cookies.filter { $0.domain.contains(domain) }
            
            self.log("Clearing \(domainCookies.count) cookies for domain: \(domain)", level: .info)
            
            for cookie in domainCookies {
                HTTPCookieStorage.shared.deleteCookie(cookie)
                self.log("Deleted cookie: \(cookie.name)", level: .debug)
            }
        }
    }
    
    /// Get a list of all active HTTP cookies
    func getAllCookies() -> [HTTPCookie] {
        return HTTPCookieStorage.shared.cookies ?? []
    }
    
    /// Print detailed information about all cookies
    func logAllCookies() {
        let cookies = getAllCookies()
        log("==== COOKIES (\(cookies.count)) ====", level: .info)
        
        for (index, cookie) in cookies.enumerated() {
            log("Cookie [\(index)]: \(cookie.name) = \(cookie.value)", level: .debug)
            log("  Domain: \(cookie.domain)", level: .verbose)
            log("  Path: \(cookie.path)", level: .verbose)
            log("  Secure: \(cookie.isSecure)", level: .verbose)
            log("  HTTPOnly: \(cookie.isHTTPOnly)", level: .verbose)
            log("  Expires: \(cookie.expiresDate?.description ?? "Session")", level: .verbose)
        }
        
        log("===========================", level: .info)
    }
    
    /// Record and log network requests for debugging
    func logNetworkRequest(_ request: URLRequest, data: Data? = nil) {
        guard debugModeEnabled else { return }
        
        log("==== NETWORK REQUEST ====", level: .debug)
        log("URL: \(request.url?.absoluteString ?? "nil")", level: .debug)
        log("Method: \(request.httpMethod ?? "nil")", level: .debug)
        
        if let headers = request.allHTTPHeaderFields, !headers.isEmpty {
            log("Headers:", level: .debug)
            for (key, value) in headers {
                log("  \(key): \(value)", level: .debug)
            }
        }
        
        if let body = request.httpBody, !body.isEmpty {
            if let bodyString = String(data: body, encoding: .utf8) {
                log("Body: \(bodyString)", level: .debug)
            } else {
                log("Body: \(body.count) bytes (binary data)", level: .debug)
            }
        }
        
        log("==========================", level: .debug)
    }
    
    /// Log network response for debugging
    func logNetworkResponse(_ response: URLResponse?, data: Data?, error: Error?) {
        guard debugModeEnabled else { return }
        
        log("==== NETWORK RESPONSE ====", level: .debug)
        
        if let error = error {
            log("Error: \(error.localizedDescription)", level: .error)
        }
        
        if let httpResponse = response as? HTTPURLResponse {
            log("Status: \(httpResponse.statusCode)", level: .debug)
            log("URL: \(httpResponse.url?.absoluteString ?? "nil")", level: .debug)
            
            if let headers = httpResponse.allHeaderFields as? [String: Any], !headers.isEmpty {
                log("Headers:", level: .debug)
                for (key, value) in headers {
                    log("  \(key): \(value)", level: .debug)
                }
            }
        } else {
            log("Response: \(String(describing: response))", level: .debug)
        }
        
        if let data = data, !data.isEmpty {
            if let responseString = String(data: data, encoding: .utf8) {
                if responseString.count > 1000 {
                    let truncated = responseString.prefix(1000)
                    log("Body: \(truncated)... (truncated, \(data.count) bytes total)", level: .debug)
                } else {
                    log("Body: \(responseString)", level: .debug)
                }
            } else {
                log("Body: \(data.count) bytes (binary data)", level: .debug)
            }
        }
        
        log("===========================", level: .debug)
    }
}

// Convenience global functions
func debugLog(_ message: String, level: DebugUtility.LogLevel = .debug, file: String = #file, function: String = #function, line: Int = #line) {
    DebugUtility.shared.log(message, level: level, file: file, function: function, line: line)
}

// Custom URLSession that logs network activity
class DebugURLSession: URLSession {
    
    static let shared = DebugURLSession()
    
    private let session = URLSession.shared
    
    override func dataTask(with request: URLRequest, completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void) -> URLSessionDataTask {
        
        DebugUtility.shared.logNetworkRequest(request)
        
        return session.dataTask(with: request) { data, response, error in
            DebugUtility.shared.logNetworkResponse(response, data: data, error: error)
            completionHandler(data, response, error)
        }
    }
    
    override func dataTask(with url: URL, completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void) -> URLSessionDataTask {
        let request = URLRequest(url: url)
        return dataTask(with: request, completionHandler: completionHandler)
    }
} 