import AppKit
import Foundation

struct RunningApp: Identifiable {
    let id: pid_t
    let name: String
    let icon: NSImage?
    let app: NSRunningApplication
    let memoryUsageValue: Double // In MB
    let isUserApp: Bool
    
    var memoryUsage: String {
        if memoryUsageValue > 1024 {
            return String(format: "%.1f GB", memoryUsageValue / 1024)
        }
        return String(format: "%.0f MB", memoryUsageValue)
    }
}

struct SystemStats {
    var totalRAM: Double // GB
    var usedRAM: Double // GB
    var freeRAM: Double // GB
    
    var usedString: String { String(format: "%.1f GB", usedRAM) }
    var totalString: String { String(format: "%.0f GB", totalRAM) }
    var percentage: Double { usedRAM / totalRAM }
}

class ProcessManager: ObservableObject {
    @Published var processes: [RunningApp] = []
    @Published var stats: SystemStats = SystemStats(totalRAM: 8, usedRAM: 4, freeRAM: 4)
    
    init() {
        refreshProcesses()
    }
    
    func refreshProcesses() {
        refreshStats()
        
        let apps = NSWorkspace.shared.runningApplications
        
        let relevantApps = apps.filter { app in
            if app.processIdentifier == ProcessInfo.processInfo.processIdentifier { return false }
            return app.activationPolicy == .regular || app.activationPolicy == .accessory
        }
        
        let appsWithMemory = relevantApps.map { app -> RunningApp in
            let mem = getMemoryUsageValue(pid: app.processIdentifier)
            
            // Categorization Logic
            var isUser = false
            if let url = app.bundleURL {
                let path = url.path
                // Consider apps in /Applications, /Users/x/Applications, or user's Downloads/Desktop as "User Apps"
                // Exclude /System
                if path.hasPrefix("/System") || path.hasPrefix("/usr") || path.hasPrefix("/bin") {
                    isUser = false
                } else if path.contains("/Applications") || path.hasPrefix("/Users") {
                    isUser = true
                }
            }
            
            return RunningApp(
                id: app.processIdentifier,
                name: app.localizedName ?? "Unknown",
                icon: app.icon,
                app: app,
                memoryUsageValue: mem,
                isUserApp: isUser
            )
        }
        
        // Sort by Memory (Descending)
        self.processes = appsWithMemory.sorted { $0.memoryUsageValue > $1.memoryUsageValue }
    }
    
    func getSmartCleanSuggestions() -> [RunningApp] {
        // Heuristic:
        // 1. Is User App
        // 2. High Memory (> 300 MB for demo, maybe 500MB in prod)
        // 3. Not the active app
        
        // Note: In a real "AI" scenario, we might track usage over time.
        // Here we look for immediate "heavy background" apps.
        
        let activeApp = NSWorkspace.shared.frontmostApplication
        
        return processes.filter { app in
            guard app.isUserApp else { return false }
            
            // Don't suggest the app user is currently using
            if app.app.processIdentifier == activeApp?.processIdentifier { return false }
            
            // Threshold: 300MB (Lowered for visibility/testing, user asked for "High RAM")
            if app.memoryUsageValue > 300 {
                return true
            }
            
            return false
        }
    }
    
    func termintateApp(_ app: RunningApp) {
        app.app.terminate()
        // Optimistic remove
        if let index = processes.firstIndex(where: { $0.id == app.id }) {
            processes.remove(at: index)
        }
    }
    
    func uninstallApp(_ app: RunningApp) {
        AppCleaner.uninstall(app: app)
        // It will terminate in the process
        if let index = processes.firstIndex(where: { $0.id == app.id }) {
            processes.remove(at: index)
        }
    }
    
    private func getMemoryUsageValue(pid: pid_t) -> Double {
        let task = Process()
        task.launchPath = "/bin/ps"
        task.arguments = ["-o", "rss=", "-p", "\(pid)"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        
        do {
            try task.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
               let kb = Double(output) {
                return kb / 1024.0
            }
        } catch { } // Ignore
        return 0.0
    }
    
    private func refreshStats() {
        // Get Total RAM
        let total = Double(ProcessInfo.processInfo.physicalMemory) / 1024 / 1024 / 1024 // Bytes -> GB
        
        // Get Page Size
        var pageSize: vm_size_t = 0
        let hostPort: mach_port_t = mach_host_self()
        var hostSize: mach_msg_type_number_t = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        var hostInfo = vm_statistics64_data_t()
        
        host_page_size(hostPort, &pageSize)
        
        let status = withUnsafeMutablePointer(to: &hostInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(hostSize)) {
                host_statistics64(hostPort, HOST_VM_INFO64, $0, &hostSize)
            }
        }
        
        if status == KERN_SUCCESS {
            // Calculate Used Memory (Active + Wired + Compressed for "Used" perception)
            // Or simpler: (active + wired)
            let active = Double(hostInfo.active_count) * Double(pageSize)
            let wired = Double(hostInfo.wire_count) * Double(pageSize)
            let compressed = Double(hostInfo.compressor_page_count) * Double(pageSize)
            
            let usedBytes = active + wired + compressed
            let used = usedBytes / 1024 / 1024 / 1024
            
            self.stats = SystemStats(totalRAM: total, usedRAM: used, freeRAM: total - used)
        }
    }
}
