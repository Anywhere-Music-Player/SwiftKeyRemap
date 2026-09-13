// ディスクイメージのウィンドウ背景を描いて PNG に書き出す。
// 使い方: swift Scripts/make-dmg-background.swift <出力 PNG>
// ウィンドウは 660x400。左にアプリのアイコン、右に Applications へのリンクが置かれるので、
// 地の色とその間の矢印を描く。寸法は make-dmg.sh と合わせておくこと。

import AppKit
import ImageIO
import UniformTypeIdentifiers

let arguments = CommandLine.arguments
guard arguments.count >= 2 else {
    FileHandle.standardError.write("usage: make-dmg-background.swift <output.png>\n".data(using: .utf8)!)
    exit(2)
}
let outputURL = URL(fileURLWithPath: arguments[1])

// ウィンドウの大きさと、make-dmg.sh が create-dmg に渡すアイコン中心の座標。Finder の y は上から測る
let width = 660
let height = 400
let iconY: CGFloat = 190
let appIconX: CGFloat = 165
let dropLinkX: CGFloat = 495

let ctx = CGContext(
    data: nil,
    width: width,
    height: height,
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: CGColorSpace(name: CGColorSpace.sRGB)!,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
)!
ctx.setShouldAntialias(true)

/// Finder はアイコンを上から配置し、Core Graphics は下から描く
func flip(_ y: CGFloat) -> CGFloat { CGFloat(height) - y }

// 1. 地。アイコンの台座より少し明るくして、台座つきのアイコンが埋もれないようにする
ctx.setFillColor(CGColor(red: 0.96, green: 0.96, blue: 0.97, alpha: 1))
ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))

// 2. 2 つのアイコンの間の矢印。Applications フォルダの側を指す
let arrowColor = CGColor(red: 0.72, green: 0.72, blue: 0.75, alpha: 1)
let midX = (appIconX + dropLinkX) / 2
let arrowY = flip(iconY)
let shaftHalf: CGFloat = 46
let headLength: CGFloat = 26
let headHalfHeight: CGFloat = 20

ctx.setStrokeColor(arrowColor)
ctx.setLineWidth(7)
ctx.setLineCap(.round)
ctx.move(to: CGPoint(x: midX - shaftHalf, y: arrowY))
ctx.addLine(to: CGPoint(x: midX + shaftHalf - headLength, y: arrowY))
ctx.strokePath()

ctx.setFillColor(arrowColor)
ctx.move(to: CGPoint(x: midX + shaftHalf, y: arrowY))
ctx.addLine(to: CGPoint(x: midX + shaftHalf - headLength, y: arrowY + headHalfHeight))
ctx.addLine(to: CGPoint(x: midX + shaftHalf - headLength, y: arrowY - headHalfHeight))
ctx.closePath()
ctx.fillPath()

// 3. PNG に書き出す
let image = ctx.makeImage()!
let destination = CGImageDestinationCreateWithURL(outputURL as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(destination, image, nil)
guard CGImageDestinationFinalize(destination) else {
    FileHandle.standardError.write("failed to write \(outputURL.path)\n".data(using: .utf8)!)
    exit(1)
}
