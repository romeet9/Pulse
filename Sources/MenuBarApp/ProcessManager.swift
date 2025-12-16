import AppKit
import Foundation


struct RunningApp: Identifiable {
    let id: pid_t
    let name: String
    let icon: NSImage?
    let app: NSRunningApplication? // Nullable now, as many won't have it
    let memoryUsageValue: Double // In MB
    let isUserApp: Bool
    let user: String
    
    var memoryUsage: String {
        if memoryUsageValue > 1024 {
            return String(format: "%.1f GB", memoryUsageValue / 1024)
        }
        return String(format: "%.0f MB", memoryUsageValue)
    }
}

struct SystemStats {
    var totalRAM: Double // GB
    var physicalUsedRAM: Double // GB
    var swapUsedRAM: Double // GB
    var freeRAM: Double // GB
    
    var memoryPressure: String {
        return String(format: "Phy: %.1f/%.0f GB", physicalUsedRAM, totalRAM)
    }
    
    var swapString: String {
        return String(format: "Swap: %.1f GB", swapUsedRAM)
    }
}

class ProcessManager: ObservableObject {
    @Published var processes: [RunningApp] = []
    @Published var stats: SystemStats = SystemStats(totalRAM: 8, physicalUsedRAM: 4, swapUsedRAM: 2, freeRAM: 2)
    
    init() {
        refreshProcesses()
    }
    
    func refreshProcesses() {
        refreshStats()
        
        // 1. Get raw process list via `ps`
        // Columns: pid, ppid, rss (kb), user, command
        let output = runCommand("/bin/ps", args: ["-Ao", "pid,rss,user,comm"])
        let lines = output.components(separatedBy: "\n")
        
        // 2. Map existing NSRunningApplications for Icons/Pretty Names
        let workspaceApps = NSWorkspace.shared.runningApplications
        var appMap: [pid_t: NSRunningApplication] = [:]
        for app in workspaceApps {
            appMap[app.processIdentifier] = app
        }
        
        let currentUser = NSUserName()
        var newProcesses: [RunningApp] = []
        
        // Skip header row
        for line in lines.dropFirst() {
            let components = line.trimmingCharacters(in: .whitespaces).components(separatedBy: .whitespaces)
            let filtered = components.filter { !$0.isEmpty }
            
            // Need at least PID, RSS, USER, COMM
            if filtered.count >= 4 {
                if let pid = pid_t(filtered[0]),
                   let rssKB = Double(filtered[1]) {
                    
                    let user = filtered[2]
                    // Command might differ, usually the rest of tokens
                    // But `comm` gives short name usually. 
                    // Let's rely on NSRunningApplication name if available, else binary name.
                    
                    // Filter out this app itself to avoid confusion? Optional.
                    if pid == ProcessInfo.processInfo.processIdentifier { continue }
                    
                    let workspaceApp = appMap[pid]
                    let name = workspaceApp?.localizedName ?? (filtered.last ?? "Unknown").components(separatedBy: "/").last ?? "Unknown"
                    
                    // Icon logic
                    let icon = workspaceApp?.icon ?? NSWorkspace.shared.icon(forFileType: NSFileTypeForHFSTypeCode(OSType(kGenericApplicationIcon)))
                    
                    // Categorization
                    // "User App" if: Running as current user AND likely has a UI (in AppMap) OR in /Applications
                    // "System" if: root, _coreaudiod, etc.
                    
                    var isUser = false
                    if user == currentUser {
                        // Further refinement: If it's a known GUI app or path contains App
                        if workspaceApp != nil {
                            isUser = true
                        } else if line.contains("/Applications") || line.contains("/Users/") {
                             isUser = true  
                        }
                    }
                    
                    // Special Case: kernel_task
                    if pid == 0 { 
                         // Doesn't show up in ps usually as pid 0, but if it does:
                    }

                    newProcesses.append(RunningApp(
                        id: pid,
                        name: name,
                        icon: workspaceApp?.icon, // Pass nil if no Workspace App, UI will handle generic
                        app: workspaceApp,
                        memoryUsageValue: rssKB / 1024.0, // KB -> MB
                        isUserApp: isUser,
                        user: user
                    ))
                }
            }
        }
        
        self.processes = newProcesses.sorted { $0.memoryUsageValue > $1.memoryUsageValue }
    }
    

    
    func termintateApp(_ app: RunningApp) {
        if let nsApp = app.app {
            nsApp.terminate()
        } else {
            // Force Kill for non-NSApps (using kill command)
            // Only if owned by user
            if app.user == NSUserName() {
                let _ = runCommand("/bin/kill", args: ["\(app.id)"])
            }
        }
        
        if let index = processes.firstIndex(where: { $0.id == app.id }) {
            processes.remove(at: index)
        }
    }
    
    func uninstallApp(_ app: RunningApp) {
        guard let nsApp = app.app else { return } // Cannot uninstall CLI tools easily
        AppCleaner.uninstall(app: app)
        if let index = processes.firstIndex(where: { $0.id == app.id }) {
            processes.remove(at: index)
        }
    }
    
    // Helper to run shell commands
    private func runCommand(_ launchPath: String, args: [String]) -> String {
        let task = Process()
        task.launchPath = launchPath
        task.arguments = args
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe() // Ignore errors
        do {
            try task.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8) ?? ""
        } catch {
            return ""
        }
    }
    
    private func refreshStats() {
        // Physical Memory
        let total = Double(ProcessInfo.processInfo.physicalMemory) / 1024 / 1024 / 1024
        
        // Host Info for Physical Used
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
        
        var physicalUsed: Double = 0
        if status == KERN_SUCCESS {
            let active = Double(hostInfo.active_count) * Double(pageSize)
            let wired = Double(hostInfo.wire_count) * Double(pageSize)
            let compressed = Double(hostInfo.compressor_page_count) * Double(pageSize)
            // Used = Active + Wired + Compressed
            physicalUsed = (active + wired + compressed) / 1024 / 1024 / 1024
        }
        
        // Swap Usage via sysctl
        // using generic shell because Swift sysctl wrapper is verbose
        var swapUsed: Double = 0
        let swapOutput = runCommand("/usr/sbin/sysctl", args: ["vm.swapusage"])
        // output format: vm.swapusage: total = 1024.00M  used = 12.00M  free = 1012.00M  (encrypted)
        if let usedRange = swapOutput.range(of: "used = ") {
            let substring = swapOutput[usedRange.upperBound...]
            let components = substring.components(separatedBy: " ")
            if let valStr = components.first {
                // valStr is like "12.00M" or "0.00M"
                let value = Double(valStr.dropLast()) ?? 0
                let unit = valStr.last
                
                if unit == "M" { swapUsed = value / 1024 }
                else if unit == "G" { swapUsed = value }
                else if unit == "K" { swapUsed = value / 1024 / 1024 }
            }
        }
        
        self.stats = SystemStats(
            totalRAM: total,
            physicalUsedRAM: physicalUsed,
            swapUsedRAM: swapUsed,
            freeRAM: total - physicalUsed
        )
    }
}

