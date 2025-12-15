import Foundation
import AppKit

struct AppCleaner {
    static func uninstall(app: RunningApp) {
        guard let bundleURL = app.app.bundleURL else { return }
        
        // 1. Terminate the app
        if !app.app.isTerminated {
            app.app.terminate()
            // Wait a moment effectively, or just proceed. 
            // In async real world we'd wait, but for filesystem moves we can try.
            // Force terminate if needed? Let's be gentle first.
        }
        
        let fileManager = FileManager.default
        
        // 2. Move .app to Trash
        do {
            try fileManager.trashItem(at: bundleURL, resultingItemURL: nil)
            print("Moved app to trash: \(bundleURL.path)")
        } catch {
            print("Failed to trash app: \(error)")
            // If failed (permissions?), maybe stop here.
            return 
        }
        
        // 3. Clean Residues (Best effort)
        // Bundle ID is needed
        guard let bundleID = app.app.bundleIdentifier else { return }
        
        let home = fileManager.homeDirectoryForCurrentUser
        let library = home.appendingPathComponent("Library")
        
        // Common locations for residues
        let searchPaths = [
            library.appendingPathComponent("Caches"),
            library.appendingPathComponent("Preferences"),
            library.appendingPathComponent("Application Support"),
            library.appendingPathComponent("Saved Application State"),
            library.appendingPathComponent("HTTPStorages"),
            library.appendingPathComponent("Containers") // Sandboxed apps
        ]
        
        for baseDir in searchPaths {
            // Logic: Look for files/folders containing the bundle ID
            // Simple match: Exact name or Starts with Bundle ID
            do {
                let items = try fileManager.contentsOfDirectory(at: baseDir, includingPropertiesForKeys: nil)
                for item in items {
                    let filename = item.lastPathComponent
                    if filename.contains(bundleID) {
                        do {
                            try fileManager.trashItem(at: item, resultingItemURL: nil)
                            print("Cleaned up residue: \(item.path)")
                        } catch {
                            print("Failed to cleanup residue \(item.path): \(error)")
                        }
                    }
                }
            } catch {
                // Directory access error or doesn't exist
            }
        }
    }
}
