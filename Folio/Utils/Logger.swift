import Foundation

enum Logger {
    static func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        #if DEBUG
        let fileName = (file as NSString).lastPathComponent
        print("[DEBUG] [\(fileName):\(line)] \(function) - \(message)")
        #endif
    }

    static func error(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        let fileName = (file as NSString).lastPathComponent
        print("[ERROR] [\(fileName):\(line)] \(function) - \(message)")
    }
}
