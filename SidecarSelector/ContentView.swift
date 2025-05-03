//
//  ContentView.swift
//  SidecarSelector
//
//  Created by 柴田紘希 on 2025/05/03.
//

import SwiftUI
import CoreGraphics

struct ContentView: View {
    @State private var selectedDirection: Direction? = nil
    @State private var offsetX: CGFloat = 0
    @State private var offsetY: CGFloat = 0
    @State private var showDetailSettings = false
    var body: some View {
        VStack(spacing: 20) {
            Text("Sidecarの位置を選択")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .padding(.top, 8)
            // 位置関係を表すアイコン表示
            ZStack {
                // ラップトップ（常に中央）
                Image(systemName: "laptopcomputer")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 80, height: 54)
                    .foregroundColor(.accentColor)
                // タブレット（選択方向に応じて配置）
                if let dir = selectedDirection {
                    switch dir {
                    case .left:
                        Image(systemName: "ipad")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 80, height: 46)
                            .foregroundColor(.blue)
                            .rotationEffect(.degrees(90))
                            .offset(x: -54, y: 0)
                    case .right:
                        Image(systemName: "ipad")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 80, height: 46)
                            .foregroundColor(.blue)
                            .rotationEffect(.degrees(90))
                            .offset(x: 54, y: 0)
                    case .up:
                        Image(systemName: "ipad")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 80, height: 46)
                            .foregroundColor(.blue)
                            .rotationEffect(.degrees(90))
                            .offset(x: 0, y: -38)
                    case .down:
                        Image(systemName: "ipad")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 80, height: 46)
                            .foregroundColor(.blue)
                            .rotationEffect(.degrees(90))
                            .offset(x: 0, y: 38)
                    }
                }
            }
            .frame(height: 120)
            Picker("方向", selection: $selectedDirection) {
                Label("左", systemImage: "arrow.left")
                    .tag(Direction.left as Direction?)
                Label("上", systemImage: "arrow.up")
                    .tag(Direction.up as Direction?)
                Label("下", systemImage: "arrow.down")
                    .tag(Direction.down as Direction?)
                Label("右", systemImage: "arrow.right")
                    .tag(Direction.right as Direction?)
            }
            .pickerStyle(.segmented)
            .frame(width: 180)
            Button(action: {
                if let dir = selectedDirection {
                    moveSidecarDisplay(to: dir, offsetX: Int(offsetX), offsetY: Int(offsetY))
                }
            }) {
                Text("配置を変更")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
            .disabled(selectedDirection == nil)
            Button("詳細設定") {
                showDetailSettings = true
            }
            .sheet(isPresented: $showDetailSettings) {
                VStack(spacing: 20) {
                    Text("詳細設定").font(.title2).padding()
                    HStack {
                        Text("Xオフセット")
                        TextField("X", value: $offsetX, formatter: NumberFormatter())
                            .frame(width: 80)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    HStack {
                        Text("Yオフセット")
                        TextField("Y", value: $offsetY, formatter: NumberFormatter())
                            .frame(width: 80)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    Button("閉じる") {
                        showDetailSettings = false
                    }
                    .padding(.top)
                }
                .padding(32)
                .frame(width: 400)
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(NSColor.windowBackgroundColor))
                .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
        )
        .frame(width: 260)
    }
    
    enum Direction {
        case left, right, up, down
    }
    
    func moveSidecarDisplay(to direction: Direction, offsetX: Int, offsetY: Int) {
        if let sidecarID = findSidecarDisplayID() {
            let mainID = CGMainDisplayID()
            let mainBounds = CGDisplayBounds(mainID)
            let sidecarBounds = CGDisplayBounds(sidecarID)
            var newOrigin = CGPoint(x: 0, y: 0)
            switch direction {
            case .left:
                newOrigin = CGPoint(x: Int(mainBounds.origin.x) - Int(sidecarBounds.size.width) + offsetX, y: Int(mainBounds.origin.y) + offsetY)
            case .right:
                newOrigin = CGPoint(x: Int(mainBounds.origin.x + mainBounds.size.width) + offsetX, y: Int(mainBounds.origin.y) + offsetY)
            case .up:
                newOrigin = CGPoint(x: Int(mainBounds.origin.x) + offsetX, y: Int(mainBounds.origin.y - sidecarBounds.size.height) + offsetY)
            case .down:
                newOrigin = CGPoint(x: Int(mainBounds.origin.x) + offsetX, y: Int(mainBounds.origin.y + mainBounds.size.height) + offsetY)
            }
            var config: CGDisplayConfigRef?
            let err1 = CGBeginDisplayConfiguration(&config)
            if err1 == .success, let config = config {
                CGConfigureDisplayOrigin(config, sidecarID, Int32(newOrigin.x), Int32(newOrigin.y))
                let err2 = CGCompleteDisplayConfiguration(config, .permanently)
                if err2 == .success {
                    print("Sidecarディスプレイ(ID: \(sidecarID))を\(direction)に移動しました (offsetX: \(offsetX), offsetY: \(offsetY))")
                } else {
                    print("ディスプレイ配置の適用に失敗: \(err2)")
                }
            } else {
                print("ディスプレイ構成の開始に失敗: \(err1)")
            }
        } else {
            print("Sidecarディスプレイが見つかりません")
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
        print("--- ディスプレイ一覧 ---")
        for id in displayIDs {
            let vendor = CGDisplayVendorNumber(id)
            let model = CGDisplayModelNumber(id)
            let isBuiltin = CGDisplayIsBuiltin(id) != 0
            let isOnline = CGDisplayIsOnline(id) != 0
            print("ID: \(id), Vendor: \(vendor), Model: \(model), Builtin: \(isBuiltin), Online: \(isOnline)")
        }
        print("----------------------")
        // Vendorが1552（内蔵）以外、Builtin: false, Online: true のものをSidecar候補とする
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
}

#Preview {
    ContentView()
}
