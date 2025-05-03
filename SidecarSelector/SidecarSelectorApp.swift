//
//  SidecarSelectorApp.swift
//  SidecarSelector
//
//  Created by 柴田紘希 on 2025/05/03.
//

import SwiftUI
import AppKit
import CoreGraphics
import Combine

@main
struct SidecarSelectorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    var body: some Scene {
        // メインウィンドウは表示しない
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var popover: NSPopover?
    var rulerWindow: NSWindow?
    var cancellable: AnyCancellable?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "display", accessibilityDescription: "SidecarSelector")
            button.action = #selector(togglePopover(_:))
            button.target = self
        }
        popover = NSPopover()
        popover?.contentSize = NSSize(width: 240, height: 160)
        popover?.contentViewController = NSHostingController(rootView: ContentView())

        // NotificationCenterで詳細設定の表示/非表示を監視
        cancellable = NotificationCenter.default.publisher(for: .showDetailSettingsChanged)
            .sink { [weak self] notification in
                guard let self = self else { return }
                if let isShown = notification.object as? Bool {
                    if isShown {
                        self.showRulerWindow()
                    } else {
                        self.hideRulerWindow()
                    }
                }
            }
    }

    @objc func togglePopover(_ sender: AnyObject?) {
        if let button = statusItem?.button {
            if popover?.isShown == true {
                popover?.performClose(sender)
            } else {
                popover?.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }

    /// Sidecar（iPad）ディスプレイらしきものを推定して返す
    func findSidecarDisplayID() -> CGDirectDisplayID? {
        var displayCount: UInt32 = 0
        var result = CGGetActiveDisplayList(0, nil, &displayCount)
        if result != .success || displayCount == 0 { return nil }
        var displayIDs = [CGDirectDisplayID](repeating: 0, count: Int(displayCount))
        result = CGGetActiveDisplayList(displayCount, &displayIDs, &displayCount)
        if result != .success { return nil }
        for id in displayIDs {
            let vendor = CGDisplayVendorNumber(id)
            if CGDisplayIsBuiltin(id) != 0 { continue }
            if CGDisplayIsOnline(id) == 0 { continue }
            if vendor != 1552 {
                return id
            }
        }
        return nil
    }

    func showRulerWindow() {
        if let sidecarID = findSidecarDisplayID() {
            let bounds = CGDisplayBounds(sidecarID)
            let screenRect = NSRect(x: bounds.origin.x, y: bounds.origin.y, width: bounds.size.width, height: bounds.size.height)
            let window = NSWindow(
                contentRect: screenRect,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            window.isOpaque = false
            window.backgroundColor = NSColor.clear
            window.level = .floating
            window.ignoresMouseEvents = true
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            window.contentView = NSHostingView(rootView: RulerOverlayView(width: bounds.size.width, height: bounds.size.height))
            window.makeKeyAndOrderFront(nil)
            self.rulerWindow = window
        }
    }

    func hideRulerWindow() {
        rulerWindow?.orderOut(nil)
        rulerWindow = nil
    }
}

// Sidecarディスプレイ全体にルーラーを表示するView
struct RulerOverlayView: View {
    let width: CGFloat
    let height: CGFloat
    var body: some View {
        ZStack {
            // 横補助目盛り（10ptごと、5分の1）
            ForEach(0...Int(width/10), id: \.self) { i in
                if i % 5 != 0 { // 50ptごとの主目盛りは除く
                    Path { path in
                        let x = CGFloat(i) * 10
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: height))
                    }
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                }
            }
            // 縦補助目盛り（10ptごと、5分の1）
            ForEach(0...Int(height/10), id: \.self) { i in
                if i % 5 != 0 {
                    Path { path in
                        let y = CGFloat(i) * 10
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: width, y: y))
                    }
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                }
            }
            // 横ルーラー
            ForEach(0...Int(width/50), id: \.self) { i in
                Path { path in
                    let x = CGFloat(i) * 50
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: height))
                }
                .stroke(Color.black.opacity(0.7), lineWidth: 2)
                Text("\(Int(CGFloat(i) * 50))")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.black)
                    .position(x: CGFloat(i) * 50 + 18, y: 20)
            }
            // 縦ルーラー
            ForEach(0...Int(height/50), id: \.self) { i in
                Path { path in
                    let y = CGFloat(i) * 50
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: width, y: y))
                }
                .stroke(Color.black.opacity(0.7), lineWidth: 2)
                Text("\(Int(CGFloat(i) * 50))")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.black)
                    .position(x: 36, y: CGFloat(i) * 50 + 12)
            }
        }
    }
}

// Notification用拡張
extension Notification.Name {
    static let showDetailSettingsChanged = Notification.Name("showDetailSettingsChanged")
}
