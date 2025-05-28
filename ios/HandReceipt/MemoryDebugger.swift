import Foundation
import UIKit
import Darwin

/// A utility class for debugging memory issues in iOS apps
class MemoryDebugger {
    
    /// Singleton instance
    static let shared = MemoryDebugger()
    
    /// Private initializer
    private init() {
        debugPrint("MemoryDebugger initialized")
        setupMemoryWarningNotification()
    }
    
    /// Dictionary to store object counts for tracking
    private var objectCounts: [String: Int] = [:]
    
    /// Setup memory warning notification
    private func setupMemoryWarningNotification() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(didReceiveMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
        debugPrint("MemoryDebugger: Memory warning observer registered")
    }
    
    /// Handle memory warning
    @objc private func didReceiveMemoryWarning() {
        let memoryUsage = getMemoryUsage()
        debugPrint("⚠️ MEMORY WARNING RECEIVED ⚠️")
        debugPrint("Current memory usage: \(memoryUsage)")
        debugPrint("Object counts: \(objectCounts)")
        
        // Take a snapshot of the memory
        takeMemorySnapshot()
    }
    
    /// Get current memory usage in MB
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
    
    /// Track object creation - call this when important objects are created
    func trackObjectCreation(_ objectType: String) {
        objectCounts[objectType] = (objectCounts[objectType] ?? 0) + 1
        debugPrint("MemoryDebugger: Tracking object creation - \(objectType) - Count: \(objectCounts[objectType] ?? 0)")
    }
    
    /// Track object destruction - call this when important objects are destroyed
    func trackObjectDestruction(_ objectType: String) {
        if let count = objectCounts[objectType], count > 0 {
            objectCounts[objectType] = count - 1
        }
        debugPrint("MemoryDebugger: Tracking object destruction - \(objectType) - Count: \(objectCounts[objectType] ?? 0)")
    }
    
    /// Print current object counts
    func printObjectCounts() {
        debugPrint("MemoryDebugger: Current Object Counts:")
        for (type, count) in objectCounts.sorted(by: { $0.key < $1.key }) {
            debugPrint("  \(type): \(count)")
        }
    }
    
    /// Take a snapshot of current memory state
    func takeMemorySnapshot() {
        let memoryUsage = getMemoryUsage()
        
        debugPrint("=== MEMORY SNAPSHOT ===")
        debugPrint("Memory Usage: \(memoryUsage)")
        printObjectCounts()
        
        // Get free memory
        var pageSize: vm_size_t = 0
        var hostInfo = vm_statistics64_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        
        let hostPort = mach_host_self()
        var kernReturn = host_page_size(hostPort, &pageSize)
        
        if kernReturn == KERN_SUCCESS {
            kernReturn = withUnsafeMutablePointer(to: &hostInfo) {
                $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                    host_statistics64(hostPort, HOST_VM_INFO64, $0, &count)
                }
            }
            
            if kernReturn == KERN_SUCCESS {
                let freeMemory = Double(hostInfo.free_count) * Double(pageSize) / (1024.0 * 1024.0)
                debugPrint("Free System Memory: \(String(format: "%.1f MB", freeMemory))")
            }
        }
        
        mach_port_deallocate(mach_task_self_, hostPort)
        debugPrint("======================")
    }
    
    /// Check for potential memory leaks by analyzing object counts
    func checkForMemoryLeaks() -> [String: Int] {
        var potentialLeaks: [String: Int] = [:]
        
        for (type, count) in objectCounts {
            if count > 10 {  // Arbitrary threshold, adjust based on your app
                potentialLeaks[type] = count
                debugPrint("MemoryDebugger: Potential memory leak detected - \(type) has \(count) instances")
            }
        }
        
        return potentialLeaks
    }
    
    /// Create a memory pressure situation for testing
    func simulateMemoryPressure() {
        debugPrint("MemoryDebugger: Simulating memory pressure")
        
        var memoryHogs: [Data] = []
        for i in 1...10 {
            // Create a 10MB data object
            let size = 10 * 1024 * 1024
            let data = Data(count: size)
            memoryHogs.append(data)
            
            debugPrint("MemoryDebugger: Created \(i*10)MB of test data, current memory: \(getMemoryUsage())")
        }
        
        // Force a memory warning
        NotificationCenter.default.post(name: UIApplication.didReceiveMemoryWarningNotification, object: nil)
        
        // Clear the memory hogs
        memoryHogs.removeAll()
        debugPrint("MemoryDebugger: Cleared test data, current memory: \(getMemoryUsage())")
    }
}

/// Helper extension for UIView debugging
extension UIView {
    /// Tag all child views with identifiers for debugging
    func tagSubviewsForDebugging(prefix: String = "") {
        let className = String(describing: type(of: self))
        let debugTag = "\(prefix)_\(className)"
        
        self.accessibilityIdentifier = debugTag
        
        for (index, subview) in self.subviews.enumerated() {
            subview.tagSubviewsForDebugging(prefix: "\(debugTag)_\(index)")
        }
    }
    
    /// Print the view hierarchy for debugging
    func printViewHierarchy(indent: String = "") {
        let className = String(describing: type(of: self))
        let frame = self.frame
        let tag = self.tag
        let id = self.accessibilityIdentifier ?? "none"
        
        debugPrint("\(indent)\(className) - Frame: \(frame), Tag: \(tag), ID: \(id)")
        
        for subview in self.subviews {
            subview.printViewHierarchy(indent: indent + "  ")
        }
    }
}

/// Protocol for objects that should report their memory usage
protocol MemoryReporting {
    func reportMemoryUsage()
}

/// Extension for memory reporting to ViewControllers
extension UIViewController: MemoryReporting {
    func reportMemoryUsage() {
        let className = String(describing: type(of: self))
        debugPrint("MemoryReport: ViewController \(className) is active")
        MemoryDebugger.shared.trackObjectCreation(className)
    }
    
    /// Call in deinit to track destruction
    func reportMemoryDeallocation() {
        let className = String(describing: type(of: self))
        debugPrint("MemoryReport: ViewController \(className) is being deallocated")
        MemoryDebugger.shared.trackObjectDestruction(className)
    }
}

/// Force a memory report from any object
func reportMemory(for object: AnyObject, name: String? = nil) {
    let className = name ?? String(describing: type(of: object))
    debugPrint("MemoryReport: Object \(className) is allocated at \(Unmanaged.passUnretained(object).toOpaque())")
}

/// Force a GC cycle in debug builds
func forceGarbageCollection() {
    #if DEBUG
    debugPrint("Attempting to force garbage collection...")
    autoreleasepool {
        for _ in 0...5 {
            // Force memory pressure
            let _ = [Int](repeating: 0, count: 1000000)
        }
    }
    #endif
} 