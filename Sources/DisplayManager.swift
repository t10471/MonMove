import AppKit
import ApplicationServices

public struct DisplayInfo {
    public let index: Int
    public let name: String
    public let displayID: CGDirectDisplayID
    public let isPrimary: Bool
    public let nsFrame: CGRect
    public let cgFrame: CGRect
    public let visibleCgFrame: CGRect
}

public struct WindowInfo {
    public let axElement: AXUIElement
    public let appName: String
    public let pid: pid_t
    public let title: String
    public let position: CGPoint
    public let size: CGSize
    public let displayIndex: Int?
}

public class DisplayManager {
    public static let shared = DisplayManager()
    
    public init() {}
    
    /// Check if Accessibility permission is granted
    public func isAccessibilityGranted() -> Bool {
        return AXIsProcessTrusted()
    }
    
    /// Request Accessibility permission from macOS System Settings
    @discardableResult
    public func requestAccessibilityPermission() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        if !trusted {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
        }
        return trusted
    }
    
    /// Retrieve all connected displays with CoreGraphics coordinate system frames
    public func getDisplays() -> [DisplayInfo] {
        guard let primaryScreen = NSScreen.screens.first else { return [] }
        let primaryHeight = primaryScreen.frame.height
        let mainDisplayID = CGMainDisplayID()
        
        return NSScreen.screens.enumerated().compactMap { (index, screen) in
            guard let displayID = screen.deviceDescription[NSDeviceDescriptionKey(rawValue: "NSScreenNumber")] as? CGDirectDisplayID else {
                return nil
            }
            let nsFrame = screen.frame
            let nsVis = screen.visibleFrame
            
            // Convert Cocoa (Y-up) to CG (Y-down) coordinates
            let cgY = primaryHeight - (nsFrame.origin.y + nsFrame.size.height)
            let cgFrame = CGRect(x: nsFrame.origin.x, y: cgY, width: nsFrame.size.width, height: nsFrame.size.height)
            
            let visCgY = primaryHeight - (nsVis.origin.y + nsVis.size.height)
            let visibleCgFrame = CGRect(x: nsVis.origin.x, y: visCgY, width: nsVis.size.width, height: nsVis.size.height)
            
            let isPrimary = (displayID == mainDisplayID)
            let name = screen.localizedName
            
            return DisplayInfo(
                index: index,
                name: name,
                displayID: displayID,
                isPrimary: isPrimary,
                nsFrame: nsFrame,
                cgFrame: cgFrame,
                visibleCgFrame: visibleCgFrame
            )
        }
    }
    
    /// Change the main (primary) display to the target display index
    public func setPrimaryDisplay(targetIndex: Int) -> Bool {
        let displays = getDisplays()
        guard let targetDisp = displays.first(where: { $0.index == targetIndex }) else {
            return false
        }
        
        let deltaX = -Int32(targetDisp.cgFrame.origin.x)
        let deltaY = -Int32(targetDisp.cgFrame.origin.y)
        
        var configRef: CGDisplayConfigRef?
        let beginErr = CGBeginDisplayConfiguration(&configRef)
        guard beginErr == .success, let config = configRef else {
            return false
        }
        
        for disp in displays {
            let newX = Int32(disp.cgFrame.origin.x) + deltaX
            let newY = Int32(disp.cgFrame.origin.y) + deltaY
            let configErr = CGConfigureDisplayOrigin(config, disp.displayID, newX, newY)
            if configErr != .success {
                CGCancelDisplayConfiguration(config)
                return false
            }
        }
        
        let completeErr = CGCompleteDisplayConfiguration(config, .forSession)
        return completeErr == .success
    }
    
    /// Get all visible GUI windows across all running applications
    public func getAllWindows(displays: [DisplayInfo]? = nil) -> [WindowInfo] {
        let activeDisplays = displays ?? getDisplays()
        var results: [WindowInfo] = []
        
        let runningApps = NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular }
        
        for app in runningApps {
            let pid = app.processIdentifier
            let appName = app.localizedName ?? "Unknown App"
            let axApp = AXUIElementCreateApplication(pid)
            
            var windowsValue: CFTypeRef?
            let axResult = AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &windowsValue)
            
            guard axResult == .success, let axWindows = windowsValue as? [AXUIElement] else {
                continue
            }
            
            for axWin in axWindows {
                var posVal: CFTypeRef?
                var sizeVal: CFTypeRef?
                var titleVal: CFTypeRef?
                var roleVal: CFTypeRef?
                
                AXUIElementCopyAttributeValue(axWin, kAXPositionAttribute as CFString, &posVal)
                AXUIElementCopyAttributeValue(axWin, kAXSizeAttribute as CFString, &sizeVal)
                AXUIElementCopyAttributeValue(axWin, kAXTitleAttribute as CFString, &titleVal)
                AXUIElementCopyAttributeValue(axWin, kAXRoleAttribute as CFString, &roleVal)
                
                // Skip if not a standard window role
                if let role = roleVal as? String, role != kAXWindowRole as String {
                    continue
                }
                
                var pos = CGPoint.zero
                var size = CGSize.zero
                if let posVal = posVal { AXValueGetValue(posVal as! AXValue, .cgPoint, &pos) }
                if let sizeVal = sizeVal { AXValueGetValue(sizeVal as! AXValue, .cgSize, &size) }
                
                // Ignore zero-sized or invalid position windows
                if size.width <= 10 || size.height <= 10 { continue }
                
                let title = (titleVal as? String) ?? "(No Title)"
                let center = CGPoint(x: pos.x + size.width / 2.0, y: pos.y + size.height / 2.0)
                
                let matchingDisplay = activeDisplays.first(where: { $0.cgFrame.contains(center) })
                
                results.append(WindowInfo(
                    axElement: axWin,
                    appName: appName,
                    pid: pid,
                    title: title,
                    position: pos,
                    size: size,
                    displayIndex: matchingDisplay?.index
                ))
            }
        }
        
        return results
    }
    
    /// Move a specific window to a target display
    public func moveWindow(_ window: WindowInfo, from srcDisplay: DisplayInfo, to dstDisplay: DisplayInfo) -> Bool {
        // Calculate relative position within source display
        let relX = (window.position.x - srcDisplay.cgFrame.minX) / srcDisplay.cgFrame.width
        let relY = (window.position.y - srcDisplay.cgFrame.minY) / srcDisplay.cgFrame.height
        
        // Target top-left
        var newX = dstDisplay.cgFrame.minX + relX * dstDisplay.cgFrame.width
        var newY = dstDisplay.cgFrame.minY + relY * dstDisplay.cgFrame.height
        
        // Ensure window dimensions fit in target display if oversized
        var newW = window.size.width
        var newH = window.size.height
        if newW > dstDisplay.cgFrame.width {
            newW = dstDisplay.cgFrame.width * 0.9
        }
        if newH > dstDisplay.cgFrame.height {
            newH = dstDisplay.cgFrame.height * 0.9
        }
        
        // Clamp position so title bar stays accessible
        let minX = dstDisplay.cgFrame.minX
        let maxX = dstDisplay.cgFrame.maxX - min(newW, 100)
        let minY = dstDisplay.cgFrame.minY
        let maxY = dstDisplay.cgFrame.maxY - 40
        
        newX = max(minX, min(newX, maxX))
        newY = max(minY, min(newY, maxY))
        
        // Update Size first if resized
        if newW != window.size.width || newH != window.size.height {
            var newSize = CGSize(width: newW, height: newH)
            if let sizeVal = AXValueCreate(.cgSize, &newSize) {
                AXUIElementSetAttributeValue(window.axElement, kAXSizeAttribute as CFString, sizeVal)
            }
        }
        
        // Update Position
        var newPoint = CGPoint(x: newX, y: newY)
        guard let posVal = AXValueCreate(.cgPoint, &newPoint) else { return false }
        let result = AXUIElementSetAttributeValue(window.axElement, kAXPositionAttribute as CFString, posVal)
        
        return result == .success
    }
    
    /// Move all windows on source display to target display
    public func moveAllWindows(from srcIndex: Int, to dstIndex: Int) -> (moved: Int, failed: Int) {
        let displays = getDisplays()
        guard let srcDisplay = displays.first(where: { $0.index == srcIndex }),
              let dstDisplay = displays.first(where: { $0.index == dstIndex }) else {
            return (0, 0)
        }
        
        let allWindows = getAllWindows(displays: displays)
        let srcWindows = allWindows.filter { $0.displayIndex == srcIndex }
        
        var successCount = 0
        var failCount = 0
        
        for win in srcWindows {
            if moveWindow(win, from: srcDisplay, to: dstDisplay) {
                successCount += 1
            } else {
                failCount += 1
            }
        }
        
        return (successCount, failCount)
    }
    
    /// Move all windows from all other displays to target display
    public func moveAllWindowsTo(targetIndex: Int) -> (moved: Int, failed: Int) {
        let displays = getDisplays()
        guard let dstDisplay = displays.first(where: { $0.index == targetIndex }) else {
            return (0, 0)
        }
        
        let allWindows = getAllWindows(displays: displays)
        var successCount = 0
        var failCount = 0
        
        for win in allWindows {
            guard let curDispIndex = win.displayIndex, curDispIndex != targetIndex,
                  let srcDisplay = displays.first(where: { $0.index == curDispIndex }) else {
                continue
            }
            if moveWindow(win, from: srcDisplay, to: dstDisplay) {
                successCount += 1
            } else {
                failCount += 1
            }
        }
        
        return (successCount, failCount)
    }
    
    /// Swap windows between two displays
    public func swapWindows(displayA: Int, displayB: Int) -> (moved: Int, failed: Int) {
        let displays = getDisplays()
        guard let dispA = displays.first(where: { $0.index == displayA }),
              let dispB = displays.first(where: { $0.index == displayB }) else {
            return (0, 0)
        }
        
        let allWindows = getAllWindows(displays: displays)
        let windowsA = allWindows.filter { $0.displayIndex == displayA }
        let windowsB = allWindows.filter { $0.displayIndex == displayB }
        
        var successCount = 0
        var failCount = 0
        
        for win in windowsA {
            if moveWindow(win, from: dispA, to: dispB) {
                successCount += 1
            } else {
                failCount += 1
            }
        }
        
        for win in windowsB {
            if moveWindow(win, from: dispB, to: dispA) {
                successCount += 1
            } else {
                failCount += 1
            }
        }
        
        return (successCount, failCount)
    }
}
