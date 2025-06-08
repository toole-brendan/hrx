import Foundation

enum LogLevel: Int {
    case verbose = 0
    case debug = 1
    case info = 2
    case warning = 3
    case error = 4
}

struct AppLogger {
    #if DEBUG
    static let currentLevel: LogLevel = .debug
    #else
    static let currentLevel: LogLevel = .warning
    #endif
    
    static func verbose(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .verbose, file: file, function: function, line: line)
    }
    
    static func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .debug, file: file, function: function, line: line)
    }
    
    static func info(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .info, file: file, function: function, line: line)
    }
    
    static func warning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .warning, file: file, function: function, line: line)
    }
    
    static func error(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .error, file: file, function: function, line: line)
    }
    
    private static func log(_ message: String, level: LogLevel, file: String, function: String, line: Int) {
        guard level.rawValue >= currentLevel.rawValue else { return }
        
        let filename = URL(fileURLWithPath: file).lastPathComponent
        let prefix: String
        
        switch level {
        case .verbose: prefix = "🔍 VERBOSE"
        case .debug: prefix = "🐛 DEBUG"
        case .info: prefix = "ℹ️ INFO"
        case .warning: prefix = "⚠️ WARNING"
        case .error: prefix = "❌ ERROR"
        }
        
        #if DEBUG
        print("\(prefix) [\(filename):\(line)] \(function) - \(message)")
        #else
        if level.rawValue >= LogLevel.warning.rawValue {
            print("\(prefix) - \(message)")
        }
        #endif
    }
} 