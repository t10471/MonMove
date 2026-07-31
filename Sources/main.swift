import Foundation
import AppKit

func printHelp() {
    print("""
    ========================================================
    🖥 Monitor Window Mover (monmove) - macOS Window Utility
    ========================================================
    
    使用方法 (Usage):
      monmove list                                 接続されているモニターとウィンドウ一覧を表示
      monmove move --from <src> --to <dst>         <src> モニターの全ウィンドウを <dst> へ移動
      monmove move <src> <dst>                     (省略形) <src> から <dst> へ移動
      monmove move-all --to <dst>                  全てのモニターのウィンドウを <dst> へ集約
      monmove move-all <dst>                       (省略形) 全ウィンドウを <dst> へ集約
      monmove swap --display1 <d1> --display2 <d2>  <d1> と <d2> のウィンドウを相互に入れ替え
      monmove swap <d1> <d2>                       (省略形) <d1> と <d2> のウィンドウを相互入れ替え
      monmove check-permission                     アクセシビリティ権限の状態を確認・要求
      monmove menu / --gui                         メニューバー常駐アプリモードで起動
      monmove help                                 ヘルプメッセージの表示

    例 (Examples):
      monmove list
      monmove move 0 1
      monmove move-all 0
      monmove swap 0 1
      monmove menu
    """)
}

let args = CommandLine.arguments

// If launched via GUI double click or with --gui / menu flag
if args.count == 1 || (args.count > 1 && (args[1].lowercased() == "menu" || args[1].lowercased() == "--gui")) {
    let app = NSApplication.shared
    let delegate = MenuBarAppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory) // Run as menu bar app (no dock icon)
    app.run()
    exit(0)
}

let manager = DisplayManager.shared
let command = args[1].lowercased()

// 1. Accessibility Check Command
if command == "check-permission" || command == "permission" {
    let granted = manager.isAccessibilityGranted()
    if granted {
        print("✅ アクセシビリティ権限が許可されています。(Accessibility permission granted)")
    } else {
        print("⚠️  アクセシビリティ権限が許可されていません。(Accessibility permission missing)")
        print("システム設定を開き、アクセシビリティ権限を本ツール/ターミナルに許可してください...")
        manager.requestAccessibilityPermission()
    }
    exit(0)
}

// Ensure accessibility before performing window movements
if !manager.isAccessibilityGranted() {
    print("""
    ⚠️ 【注意】アクセシビリティ権限が許可されていません。
    他のアプリケーションのウィンドウを操作するには、システム設定での許可が必要です。
    以下のコマンドで権限の確認と申請を行ってください:
      monmove check-permission
    """)
    manager.requestAccessibilityPermission()
    exit(1)
}

// 2. List Command
if command == "list" || command == "ls" {
    let displays = manager.getDisplays()
    let windows = manager.getAllWindows(displays: displays)
    
    print("\n🖥  接続されているモニター一覧 (\(displays.count) 台):")
    print("--------------------------------------------------")
    for disp in displays {
        let dispWins = windows.filter { $0.displayIndex == disp.index }
        print("  [Display \(disp.index)] '\(disp.name)'")
        print("     解像度 (Resolution): \(Int(disp.nsFrame.width))x\(Int(disp.nsFrame.height))")
        print("     位置 (Bounds): \(disp.cgFrame)")
        print("     ウィンドウ数 (Window count): \(dispWins.count) 件\n")
        
        for w in dispWins {
            print("       - [\(w.appName)] \"\(w.title)\" (pos: \(w.position), size: \(w.size))")
        }
        print("")
    }
    exit(0)
}

// Helper to parse flag or positional args
func parseTwoInts(args: [String]) -> (Int, Int)? {
    var val1: Int?
    var val2: Int?
    
    for i in 2..<args.count {
        if args[i] == "--from" || args[i] == "-f" || args[i] == "--display1" || args[i] == "-d1" {
            if i + 1 < args.count { val1 = Int(args[i + 1]) }
        } else if args[i] == "--to" || args[i] == "-t" || args[i] == "--display2" || args[i] == "-d2" {
            if i + 1 < args.count { val2 = Int(args[i + 1]) }
        } else if val1 == nil, let v = Int(args[i]) {
            val1 = v
        } else if val2 == nil, let v = Int(args[i]) {
            val2 = v
        }
    }
    
    if let v1 = val1, let v2 = val2 {
        return (v1, v2)
    }
    return nil
}

func parseOneInt(args: [String]) -> Int? {
    for i in 2..<args.count {
        if args[i] == "--to" || args[i] == "-t" || args[i] == "--display" || args[i] == "-d" {
            if i + 1 < args.count, let v = Int(args[i + 1]) { return v }
        } else if let v = Int(args[i]) {
            return v
        }
    }
    return nil
}

// 3. Move Command
if command == "move" || command == "mv" {
    guard let (src, dst) = parseTwoInts(args: args) else {
        print("エラー: モニター番号の指定が不正です。 (例: monmove move 0 1)")
        exit(1)
    }
    
    print("🚀 Display \(src) から Display \(dst) へウィンドウを移動中...")
    let result = manager.moveAllWindows(from: src, to: dst)
    print("✨ 完了: \(result.moved) 件のウィンドウを移動しました (失敗: \(result.failed) 件)")
    exit(0)
}

// 4. Move All Command
if command == "move-all" || command == "moveall" {
    guard let target = parseOneInt(args: args) else {
        print("エラー: 移動先モニター番号の指定が不正です。 (例: monmove move-all 0)")
        exit(1)
    }
    
    print("🚀 全モニターのウィンドウを Display \(target) へ移動中...")
    let result = manager.moveAllWindowsTo(targetIndex: target)
    print("✨ 完了: \(result.moved) 件のウィンドウを移動しました (失敗: \(result.failed) 件)")
    exit(0)
}

// 5. Swap Command
if command == "swap" {
    guard let (disp1, disp2) = parseTwoInts(args: args) else {
        print("エラー: モニター番号の指定が不正です。 (例: monmove swap 0 1)")
        exit(1)
    }
    
    print("🔄 Display \(disp1) と Display \(disp2) のウィンドウを相互入れ替え中...")
    let result = manager.swapWindows(displayA: disp1, displayB: disp2)
    print("✨ 完了: \(result.moved) 件のウィンドウを移動しました (失敗: \(result.failed) 件)")
    exit(0)
}

// Help fallback
if command == "help" || command == "-h" || command == "--help" {
    printHelp()
    exit(0)
}

print("不明なコマンド: \(command)")
printHelp()
exit(1)
