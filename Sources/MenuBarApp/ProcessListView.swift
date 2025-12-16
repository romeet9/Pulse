import SwiftUI

// VisualEffectView for Glassmorphism
struct VisualEffectView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.blendingMode = .behindWindow 
        view.state = .active
        view.material = .popover // Adaptive material (light in light mode, dark in dark mode)
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

struct ProcessListView: View {
    @ObservedObject var processManager: ProcessManager
    @State private var hoveredAppId: pid_t? = nil
    @State private var selectedTab: Int = 0 // 0: All, 1: User, 2: System
    @State private var showUninstallAlert: RunningApp? = nil
    
    
    var body: some View {
        ZStack {
            // Full Liquid Glass Background
            VisualEffectView().edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                // Use new Dashboard Header
                // Use new Dashboard Header
                DashboardHeader(manager: processManager)
                
                Divider().padding(.top, 10)
                
                // Tabs
                HStack(spacing: 0) {
                    TabButton(title: "All Processes", isSelected: selectedTab == 0) { selectedTab = 0 }
                    TabButton(title: "My Apps", isSelected: selectedTab == 1) { selectedTab = 1 }
                    TabButton(title: "System", isSelected: selectedTab == 2) { selectedTab = 2 }
                }
                .background(Color.clear)
                
                Divider()
                
                // Process List
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredProcesses) { process in
                            ProcessRow(process: process, onTerminate: {
                                processManager.termintateApp(process)
                            }, onUninstall: {
                                showUninstallAlert = process
                            })
                        }
                    }
                    .padding(.bottom, 10)
                }
                
                // Footer
                HStack {
                    Text("\(filteredProcesses.count) processes")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    
                    // Refresh Button (Moved to Footer)
                    Button(action: {
                        withAnimation {
                            processManager.refreshProcesses()
                        }
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Refresh")
                    .padding(.trailing, 8)
                    
                    Button("Quit Pulse") {
                        NSApplication.shared.terminate(nil)
                    }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                .padding(12)
                .background(Color.clear)
                .overlay(Divider(), alignment: .top)
            }
            

        }
        .frame(width: 360, height: 550)
        .alert(item: $showUninstallAlert) { app in
            Alert(
                title: Text("Uninstall \(app.name)?"),
                message: Text("This will move the app to Trash and attempt to remove related caches and preferences. This action cannot be undone."),
                primaryButton: .destructive(Text("Uninstall & Clean"), action: {
                    processManager.uninstallApp(app)
                }),
                secondaryButton: .cancel()
            )
        }
        // Removed .sheet
    }
    
    var filteredProcesses: [RunningApp] {
        switch selectedTab {
        case 1: return processManager.processes.filter { $0.isUserApp }
        case 2: return processManager.processes.filter { !$0.isUserApp }
        default: return processManager.processes
        }
    }
}

struct DashboardHeader: View {
    @ObservedObject var manager: ProcessManager
    
    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Pulse")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                Spacer()
                

                Spacer().frame(width: 8)
                
                // Static Pulse Icon
                Image(systemName: "waveform.path.ecg")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 22, height: 22)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            
            // Stats Cars
            HStack(spacing: 12) {
                // Physical RAM
                StatCard(
                    title: "Physical RAM",
                    value: manager.stats.memoryPressure,
                    icon: "memorychip",
                    color: .blue
                )
                
                // Swap Memory
                StatCard(
                    title: "Swap Used",
                    value: manager.stats.swapString,
                    icon: "externaldrive.fill",
                    color: .orange
                )
            }
            .padding(.horizontal)
        }
        .padding(.top, 10)
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    @State private var isHovering = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.system(size: 12))
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            Text(value)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isHovering ? color.opacity(0.5) : Color.clear, lineWidth: 1)
        )
        .scaleEffect(isHovering ? 1.02 : 1.0)
        .animation(.spring(response: 0.3), value: isHovering)
        .onHover { hover in isHovering = hover }
    }
}

struct TabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                    .foregroundColor(isSelected ? .primary : .secondary) // Adaptive colors
                    .padding(.vertical, 8)
                
                Rectangle()
                    .fill(isSelected ? Color.primary : Color.clear) // Adaptive indicator
                    .frame(height: 2)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }
}

struct ProcessRow: View {
    let process: RunningApp
    let onTerminate: () -> Void
    let onUninstall: () -> Void
    @State private var isHovering = false
    
    var body: some View {
        HStack {
            // Icon
            if let nsIcon = process.icon {
                Image(nsImage: nsIcon)
                    .resizable()
                    .frame(width: 24, height: 24)
            } else {
                Image(systemName: "gearshape.fill")
                    .resizable()
                    .frame(width: 24, height: 24)
                    .foregroundColor(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(process.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(process.isUserApp ? .primary : .secondary)
                
                let subtext = process.isUserApp ? "User App" : "System (\(process.user))"
                Text(subtext)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Memory Badge
            Text(process.memoryUsage)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    Capsule()
                        .fill(process.memoryUsageValue > 500 ? Color.orange.opacity(0.2) : Color.gray.opacity(0.1))
                )
                .foregroundColor(process.memoryUsageValue > 500 ? .orange : .secondary)
            
            Spacer()
            .frame(width: 10)
            
            HStack(spacing: 8) {
                // Terminate Button
                Button(action: onTerminate) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor((isHovering) ? .primary : .secondary)
                }
                .buttonStyle(.plain)
                .help("Force Quit Process")
                
                // Uninstall Button (Only for User Apps)
                if isUserAppTab {
                    Button(action: onUninstall) {
                        Image(systemName: "trash.fill")
                            .font(.system(size: 14))
                            .foregroundColor((isHovering) ? .red : .secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Uninstall App")
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(isHovering ? Color.primary.opacity(0.1) : Color.clear)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovering = hovering
            }
        }
    }
    
    // Quick heuristic for row helper
    var isUserAppTab: Bool {
        return process.isUserApp
    }
}

