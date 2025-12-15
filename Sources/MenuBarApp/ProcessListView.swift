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
    
    // Smart Clean State
    @State private var showSmartSheet = false
    @State private var smartSuggestions: [RunningApp] = []
    
    var body: some View {
        ZStack {
            // Full Liquid Glass Background
            VisualEffectView().edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                // Header: RAM Stats
                HStack(spacing: 12) {
                    VStack(alignment: .leading) {
                        Text("Total RAM")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(processManager.stats.totalString)
                            .font(.headline)
                            .foregroundColor(.primary)
                    }
                    
                    Divider().frame(height: 24)
                    
                    VStack(alignment: .leading) {
                        Text("Used")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(processManager.stats.usedString)
                            .font(.headline)
                            .foregroundColor(.primary)
                    }
                    
                    Spacer()
                    
                    // Smart Clean Button (New)
                    Button(action: {
                        // Just open the sheet, let the sheet handle scanning animation
                        // But we can pre-fetch or scan inside the view. 
                        // To make "Scanning" animation real, let's fetch in the view or fetch here. 
                        // The plan is: Animations in Sheet.
                        // So we just set showSmartSheet = true, but we need suggestions.
                        // We can calculate them now or let the view do it. 
                        // To support the "Scanning" phase of 2 seconds, we should calculate effectively during that time or before. 
                        
                        // Heuristic check: if empty, maybe show "All Good"? 
                        // The user wants theatrics. So always show scanning.
                        
                        smartSuggestions = processManager.getSmartCleanSuggestions()
                        showSmartSheet = true
                    }) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.purple)
                    }
                    .buttonStyle(.plain)
                    .help("Smart Clean Suggestions")
                    
                    Divider().frame(height: 16)
                    
                    // Refresh Button
                    Button(action: {
                        withAnimation {
                            processManager.refreshProcesses()
                        }
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(16)
                .background(Color.clear) // Transparent to show glass
                
                Divider() 
                
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
                            ProcessRow(process: process, isHovering: hoveredAppId == process.id, onHover: { hovering in
                                hoveredAppId = hovering ? process.id : nil
                            }, onTerminate: {
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
            
            // Intelligence Overlay
            if showSmartSheet {
                VisualEffectView().edgesIgnoringSafeArea(.all) // Blur background content
                    .opacity(0.8)
                    .transition(.opacity)
                
                IntelligenceView(processManager: processManager, showSheet: $showSmartSheet, suggestions: $smartSuggestions)
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
                    .zIndex(1)
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

enum IntelligenceState {
    case scanning
    case results
    case cleaning
    case success
}

struct IntelligenceView: View {
    @ObservedObject var processManager: ProcessManager
    @Binding var showSheet: Bool
    @Binding var suggestions: [RunningApp]
    
    @State private var state: IntelligenceState = .scanning
    @State private var scanRotation: Double = 0
    @State private var scanScale: CGFloat = 0.8
    @State private var scanOpacity: Double = 0.5
    @State private var savedMemory: String = "0 MB"
    
    var body: some View {
        ZStack {
            VisualEffectView().edgesIgnoringSafeArea(.all)
            
            VStack {
                if state == .scanning {
                    LiquidScanningView()
                        .onAppear {
                            // Mock scan delay
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { // Extended duration for effect
                                withAnimation {
                                    state = .results
                                }
                            }
                        }
                } else if state == .results {
                    ResultsView(processManager: processManager, suggestions: suggestions, onClean: {
                        withAnimation {
                            state = .cleaning
                        }
                        
                        // Calculate saved memory for display
                        let totalVal = suggestions.reduce(0) { $0 + $1.memoryUsageValue }
                        if totalVal > 1024 {
                             savedMemory = String(format: "%.1f GB", totalVal / 1024)
                        } else {
                             savedMemory = String(format: "%.0f MB", totalVal)
                        }
                        
                        // Perform Clean
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                            for app in suggestions {
                                processManager.termintateApp(app)
                            }
                            withAnimation {
                                state = .success
                            }
                            
                            // Auto dismiss
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                showSheet = false
                            }
                        }
                    }, onDismiss: {
                        showSheet = false
                    })
                } else if state == .cleaning {
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Releasing Memory...")
                            .font(.headline)
                    }
                } else if state == .success {
                    VStack(spacing: 20) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.green)
                            .scaleEffect(1.2)
                        
                        Text("Optimized!")
                            .font(.title2.bold())
                        
                        Text("Freed \(savedMemory) of RAM")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .transition(.scale)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity) // Fill parent
            .background(Color.clear)
        }
    }
}

struct LiquidScanningView: View {
    @State private var wave1 = false
    @State private var wave2 = false
    @State private var wave3 = false
    
    var body: some View {
        ZStack {
            // Background - Liquid Glass
            VisualEffectView().edgesIgnoringSafeArea(.all)
                .opacity(0.9) // Strong blur
            
            // Central Pulse Core
            Circle()
                .fill(Color.purple.opacity(0.3))
                .frame(width: 80, height: 80)
                .blur(radius: 10)
            
            // Wave 1
            Circle()
                .stroke(Color.primary.opacity(0.3), lineWidth: 2) // Adaptive color
                .frame(width: 80, height: 80)
                .scaleEffect(wave1 ? 3 : 1)
                .opacity(wave1 ? 0 : 1)
                .onAppear {
                    withAnimation(.easeOut(duration: 2).repeatForever(autoreverses: false)) {
                        wave1 = true
                    }
                }
            
            // Wave 2
            Circle()
                .stroke(Color.purple.opacity(0.4), lineWidth: 1.5)
                .frame(width: 80, height: 80)
                .scaleEffect(wave2 ? 2.5 : 1)
                .opacity(wave2 ? 0 : 1)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        withAnimation(.easeOut(duration: 2).repeatForever(autoreverses: false)) {
                            wave2 = true
                        }
                    }
                }
            
            // Wave 3 (Inner)
            Circle()
                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                .frame(width: 80, height: 80)
                .scaleEffect(wave3 ? 2 : 1)
                .opacity(wave3 ? 0 : 1)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        withAnimation(.easeOut(duration: 2).repeatForever(autoreverses: false)) {
                            wave3 = true
                        }
                    }
                }
            
            // Icon
            Image(systemName: "sparkles")
                .font(.system(size: 30))
                .foregroundColor(.primary) // Adaptive
                .shadow(color: .purple.opacity(0.5), radius: 10)
            
            VStack(spacing: 8) {
                Spacer()
                Text("Analyzing System Memory...")
                    .font(.system(size: 11, weight: .semibold, design: .rounded)) // Modern rounded font
                    .foregroundColor(.secondary)
                    .padding(.bottom, 60)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ResultsView: View {
    @ObservedObject var processManager: ProcessManager
    let suggestions: [RunningApp]
    let onClean: () -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundColor(.orange)
                .padding(.top, 20)
            
            Text("Optimization Ready")
                .font(.title2.weight(.bold))
            
            Text("Found \(suggestions.count) background apps consuming significant memory.")
                .font(.body)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(suggestions) { app in
                        HStack {
                            if let icon = app.icon {
                                Image(nsImage: icon)
                                    .resizable()
                                    .frame(width: 24, height: 24)
                            }
                            Text(app.name)
                                .fontWeight(.medium)
                            Spacer()
                            Text(app.memoryUsage)
                                .font(.caption.monospaced())
                                .foregroundColor(.secondary)
                        }
                        .padding(8)
                        .background(Color.primary.opacity(0.05))
                        .cornerRadius(8)
                    }
                }
                .padding()
            }
            .frame(height: 120)
            
            HStack(spacing: 12) {
                Button("Dismiss") {
                    onDismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Button(action: onClean) {
                    Text("Clean All")
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.purple)
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 20)
        }
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
    let isHovering: Bool
    let onHover: (Bool) -> Void
    let onTerminate: () -> Void
    let onUninstall: () -> Void
    
    var body: some View {
        HStack {
            // Icon
            if let icon = process.icon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 28, height: 28)
            } else {
                Image(systemName: "app")
                    .foregroundColor(.secondary)
                    .frame(width: 28, height: 28)
            }
            
            // Name & Details
            VStack(alignment: .leading, spacing: 2) {
                Text(process.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)
                
                HStack(spacing: 6) {
                    Text(process.memoryUsage)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                // Terminate Button (Always Visible)
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
        .onHover(perform: onHover)
    }
    
    // Quick heuristic for row helper
    var isUserAppTab: Bool {
        return process.isUserApp
    }
}

