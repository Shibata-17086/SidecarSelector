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
    var offsetAdjustWindow: NSWindow?

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
            let menuBarHeight = NSStatusBar.system.thickness
            let screenRect = NSRect(x: bounds.origin.x, y: bounds.origin.y + menuBarHeight, width: bounds.size.width, height: bounds.size.height - menuBarHeight)
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
            window.contentView = NSHostingView(rootView: RulerOverlayView(width: bounds.size.width, height: bounds.size.height - menuBarHeight))
            window.makeKeyAndOrderFront(nil)
            self.rulerWindow = window
        }
    }

    func hideRulerWindow() {
        rulerWindow?.orderOut(nil)
        rulerWindow = nil
    }

    // オフセット調整用フルスクリーンウインドウを表示
    func showOffsetAdjustWindow() {
        if let sidecarID = findSidecarDisplayID() {
            let bounds = CGDisplayBounds(sidecarID)
            let menuBarHeight = NSStatusBar.system.thickness
            let screenRect = NSRect(x: bounds.origin.x, y: bounds.origin.y + menuBarHeight, width: bounds.size.width, height: bounds.size.height - menuBarHeight)
            let window = NSWindow(
                contentRect: screenRect,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            window.isOpaque = false
            window.backgroundColor = NSColor.clear
            window.level = .screenSaver
            window.ignoresMouseEvents = false
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            window.contentView = NSHostingView(rootView: OffsetAdjustView(width: bounds.size.width, height: bounds.size.height - menuBarHeight, onFinish: {
                window.orderOut(nil)
                self.offsetAdjustWindow = nil
            }))
            window.makeKeyAndOrderFront(nil)
            self.offsetAdjustWindow = window
        }
    }
}

// Sidecarディスプレイ全体にルーラーを表示するView
struct RulerOverlayView: View {
    let width: CGFloat
    let height: CGFloat
    @State private var firstCorner: CGPoint? = nil
    var body: some View {
        let centerX = width / 2
        let centerY = height / 2
        GeometryReader { geo in
            ZStack {
                // 横補助目盛り（10ptごと、5分の1）
                ForEach(-Int(centerX/10)...Int(centerX/10), id: \.self) { i in
                    if i % 5 != 0 {
                        let x = width / 2 + CGFloat(i) * 10
                        Path { path in
                            path.move(to: CGPoint(x: x, y: 0))
                            path.addLine(to: CGPoint(x: x, y: 20))
                        }
                        .stroke(Color.orange, lineWidth: 1)
                        Path { path in
                            path.move(to: CGPoint(x: x, y: height - 20))
                            path.addLine(to: CGPoint(x: x, y: height))
                        }
                        .stroke(Color.orange, lineWidth: 1)
                    }
                }
                // 縦補助目盛り（10ptごと、5分の1）
                ForEach(-Int(centerY/10)...Int(centerY/10), id: \.self) { i in
                    if i % 5 != 0 {
                        let y = height / 2 + CGFloat(i) * 10
                        Path { path in
                            path.move(to: CGPoint(x: 0, y: y))
                            path.addLine(to: CGPoint(x: 20, y: y))
                        }
                        .stroke(Color.orange, lineWidth: 1)
                        Path { path in
                            path.move(to: CGPoint(x: width - 20, y: y))
                            path.addLine(to: CGPoint(x: width, y: y))
                        }
                        .stroke(Color.orange, lineWidth: 1)
                    }
                }
                // 横ルーラー
                ForEach(-Int(centerX/50)...Int(centerX/50), id: \.self) { i in
                    let x = width / 2 + CGFloat(i) * 50
                    Path { path in
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: 20))
                    }
                    .stroke(Color.red, lineWidth: 2)
                    Path { path in
                        path.move(to: CGPoint(x: x, y: height - 20))
                        path.addLine(to: CGPoint(x: x, y: height))
                    }
                    .stroke(Color.red, lineWidth: 2)
                    // 上辺
                    Text("\(i * 50)")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.red)
                        .position(x: x, y: 32)
                    // 下辺
                    Text("\(i * 50)")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.red)
                        .position(x: x, y: height - 32)
                }
                // 縦ルーラー
                ForEach(-Int(centerY/50)...Int(centerY/50), id: \.self) { i in
                    let y = height / 2 + CGFloat(i) * 50
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: 20, y: y))
                    }
                    .stroke(Color.red, lineWidth: 2)
                    Path { path in
                        path.move(to: CGPoint(x: width - 20, y: y))
                        path.addLine(to: CGPoint(x: width, y: y))
                    }
                    .stroke(Color.red, lineWidth: 2)
                    // 左辺
                    Text("\(i * 50)")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.red)
                        .frame(width: 40, alignment: .trailing)
                        .position(x: 34, y: y)
                    // 右辺
                    Text("\(i * 50)")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.red)
                        .frame(width: 40, alignment: .leading)
                        .position(x: width - 34, y: y)
                }
                // 1点目が選択されている場合、点を表示
                if let first = firstCorner {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 16, height: 16)
                        .position(first)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                TapGesture()
                    .onEnded { value in
                        let mouseLocation = NSEvent.mouseLocation
                        let windowOrigin = geo.frame(in: .global).origin
                        let clickX = mouseLocation.x - windowOrigin.x
                        let clickY = mouseLocation.y - windowOrigin.y
                        let clickPoint = CGPoint(x: clickX, y: clickY)
                        if firstCorner == nil {
                            firstCorner = clickPoint
                        } else {
                            // 2点目クリック時、中点を中心に
                            let midX = (firstCorner!.x + clickPoint.x) / 2
                            let midY = (firstCorner!.y + clickPoint.y) / 2
                            let offsetX = Int(midX - width / 2)
                            let offsetY = Int(midY - height / 2)
                            NotificationCenter.default.post(name: .rulerOffsetChanged, object: ["offsetX": offsetX, "offsetY": offsetY])
                            firstCorner = nil
                        }
                    }
            )
        }
    }
}

// オフセット調整専用のフルスクリーンView
struct OffsetAdjustView: View {
    let width: CGFloat
    let height: CGFloat
    let onFinish: () -> Void
    @State private var firstCorner: CGPoint? = nil
    var body: some View {
        ZStack {
            Color.black.opacity(0.2).ignoresSafeArea()
            RulerOverlayView(width: width, height: height)
            if let first = firstCorner {
                Circle()
                    .fill(Color.green)
                    .frame(width: 16, height: 16)
                    .position(first)
            }
            VStack {
                HStack {
                    Spacer()
                    Button("閉じる") {
                        onFinish()
                    }
                    .padding()
                }
                Spacer()
            }
        }
        .contentShape(Rectangle())
        .gesture(
            TapGesture()
                .onEnded { _ in
                    let mouseLocation = NSEvent.mouseLocation
                    let clickX = mouseLocation.x
                    let clickY = mouseLocation.y
                    let clickPoint = CGPoint(x: clickX, y: clickY)
                    if firstCorner == nil {
                        firstCorner = clickPoint
                    } else {
                        let midX = (firstCorner!.x + clickPoint.x) / 2
                        let midY = (firstCorner!.y + clickPoint.y) / 2
                        let offsetX = Int(midX - width / 2)
                        let offsetY = Int(midY - height / 2)
                        NotificationCenter.default.post(name: .rulerOffsetChanged, object: ["offsetX": offsetX, "offsetY": offsetY])
                        firstCorner = nil
                        onFinish()
                    }
                }
        )
    }
}

// Notification用拡張
extension Notification.Name {
    static let showDetailSettingsChanged = Notification.Name("showDetailSettingsChanged")
    static let rulerOffsetChanged = Notification.Name("rulerOffsetChanged")
}
