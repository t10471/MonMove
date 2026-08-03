import AppKit

class MenuBarAppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    let manager = DisplayManager.shared

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            if let sysImage = NSImage(systemSymbolName: "display.2", accessibilityDescription: "Display Window Mover") {
                sysImage.isTemplate = true
                button.image = sysImage
            } else {
                button.title = "🖥"
            }
        }
        
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
        
        rebuildMenu()
    }
    
    func rebuildMenu() {
        guard let menu = statusItem.menu else { return }
        menu.removeAllItems()
        
        let displays = manager.getDisplays()
        let isTrusted = manager.isAccessibilityGranted()
        
        let headerItem = NSMenuItem(title: "🖥 MonMove", action: nil, keyEquivalent: "")
        headerItem.isEnabled = false
        menu.addItem(headerItem)
        
        if !isTrusted {
            let permItem = NSMenuItem(title: "⚠️ アクセシビリティ権限が必要です (クリックで設定)", action: #selector(requestPermission), keyEquivalent: "")
            permItem.target = self
            menu.addItem(permItem)
        }
        
        menu.addItem(NSMenuItem.separator())
        
        let windows = isTrusted ? manager.getAllWindows(displays: displays) : []
        
        for disp in displays {
            let count = windows.filter { $0.displayIndex == disp.index }.count
            let primaryTag = disp.isPrimary ? " (⭐ メイン)" : ""
            let dispItem = NSMenuItem(title: "モニター \(disp.index): \(disp.name)\(primaryTag) (\(count) 件)", action: nil, keyEquivalent: "")
            dispItem.isEnabled = false
            menu.addItem(dispItem)
        }
        
        menu.addItem(NSMenuItem.separator())
        
        if displays.count >= 2 {
            // Section 1: Window movement
            for i in 0..<displays.count {
                for j in 0..<displays.count where i != j {
                    let moveItem = NSMenuItem(
                        title: "➡️ Display \(i) の画面を全部 Display \(j) へ移動",
                        action: #selector(moveFromTo(_:)),
                        keyEquivalent: ""
                    )
                    moveItem.target = self
                    moveItem.representedObject = (src: i, dst: j)
                    menu.addItem(moveItem)
                }
            }
            
            menu.addItem(NSMenuItem.separator())
            
            // Swap action for first two displays
            let swapItem = NSMenuItem(
                title: "🔄 Display 0 と Display 1 の画面を相互入れ替え",
                action: #selector(swapDisplays),
                keyEquivalent: ""
            )
            swapItem.target = self
            menu.addItem(swapItem)
            
            menu.addItem(NSMenuItem.separator())
            
            for d in displays {
                let moveAllItem = NSMenuItem(
                    title: "🚀 全モニターの画面を Display \(d.index) へ集約",
                    action: #selector(moveAllToTarget(_:)),
                    keyEquivalent: ""
                )
                moveAllItem.target = self
                moveAllItem.representedObject = d.index
                menu.addItem(moveAllItem)
            }
            
            menu.addItem(NSMenuItem.separator())
            
            // Section 2: Set primary display
            let setPrimaryHeader = NSMenuItem(title: "⚙️ メインモニター切り替え:", action: nil, keyEquivalent: "")
            setPrimaryHeader.isEnabled = false
            menu.addItem(setPrimaryHeader)
            
            for disp in displays {
                let primaryItem = NSMenuItem(
                    title: disp.isPrimary ? "  ✓ Display \(disp.index) (現在のメイン)" : "  ⭐ Display \(disp.index) をメインモニターに設定",
                    action: #selector(setPrimaryDisplayTarget(_:)),
                    keyEquivalent: ""
                )
                primaryItem.target = self
                primaryItem.representedObject = disp.index
                primaryItem.isEnabled = !disp.isPrimary
                menu.addItem(primaryItem)
            }
        } else {
            let singleItem = NSMenuItem(title: "※ サブモニターが接続されていません", action: nil, keyEquivalent: "")
            singleItem.isEnabled = false
            menu.addItem(singleItem)
        }
        
        menu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(title: "終了 (Quit)", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
    }
    
    @objc func requestPermission() {
        manager.requestAccessibilityPermission()
    }
    
    @objc func moveFromTo(_ sender: NSMenuItem) {
        guard let tuple = sender.representedObject as? (src: Int, dst: Int) else { return }
        _ = manager.moveAllWindows(from: tuple.src, to: tuple.dst)
        rebuildMenu()
    }
    
    @objc func swapDisplays() {
        _ = manager.swapWindows(displayA: 0, displayB: 1)
        rebuildMenu()
    }
    
    @objc func moveAllToTarget(_ sender: NSMenuItem) {
        guard let target = sender.representedObject as? Int else { return }
        _ = manager.moveAllWindowsTo(targetIndex: target)
        rebuildMenu()
    }
    
    @objc func setPrimaryDisplayTarget(_ sender: NSMenuItem) {
        guard let target = sender.representedObject as? Int else { return }
        _ = manager.setPrimaryDisplay(targetIndex: target)
        rebuildMenu()
    }
    
    @objc func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}

extension MenuBarAppDelegate: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        rebuildMenu()
    }
}
