import SwiftUI
import AppKit

@main
struct MenuBarApp: App {
    // We use a strong reference to the delegate so it doesn't get deallocated
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var popover: NSPopover?
    var processManager = ProcessManager() // Shared source of truth
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide from Dock
        NSApp.setActivationPolicy(.accessory)
        
        // Create the status item in the menu bar
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "waveform.path.ecg", accessibilityDescription: nil) // Activity style icon
            button.action = #selector(togglePopover(_:))
            button.target = self
        }
        
        // Create the popover
        let popover = NSPopover()
        popover.contentSize = NSSize(width: 360, height: 550)
        popover.behavior = .transient
        // Pass shared processManager
        popover.contentViewController = NSHostingController(rootView: ProcessListView(processManager: processManager))
        self.popover = popover
    }
    
    var eventMonitor: Any?
    
    @objc func togglePopover(_ sender: AnyObject?) {
        if let button = statusItem?.button {
            if let popover = popover {
                if popover.isShown {
                    closePopover(sender)
                } else {
                    showPopover(sender)
                }
            }
        }
    }
    
    func showPopover(_ sender: AnyObject?) {
        if let button = statusItem?.button {
            popover?.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
            
            // Start monitoring for outside clicks
            eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
                if let strongSelf = self, let popover = strongSelf.popover, popover.isShown {
                    strongSelf.closePopover(event)
                }
            }
        }
    }
    
    func closePopover(_ sender: AnyObject?) {
        popover?.performClose(sender)
        // Stop monitoring
        if let eventMonitor = eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
            self.eventMonitor = nil
        }
    }
}
