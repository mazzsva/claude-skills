// Copyright © 2026 Lorenzo Mazzarotto

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

struct ToolError: LocalizedError {
  var message: String
  init(_ message: String) { self.message = message }
  var errorDescription: String? { message }
}

enum ImageFile {
  static func read(at url: URL) throws -> CGImage {
    guard
      let source = CGImageSourceCreateWithURL(url as CFURL, nil),
      let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
    else { throw ToolError("Cannot read the image at \(url.path)") }
    return image
  }

  static func write(_ image: CGImage, to url: URL) throws {
    guard
      let destination = CGImageDestinationCreateWithURL(
        url as CFURL, UTType.png.identifier as CFString, 1, nil
      )
    else { throw ToolError("Cannot write the image to \(url.path)") }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
      throw ToolError("Cannot write the image to \(url.path)")
    }
  }
}

enum Orientation: String {
  case portrait = "Portrait"
  case landscape = "Landscape"
}

struct Bezel {
  var image: CGImage
  var screen: CGRect
  var mask: CGImage

  init(at url: URL) throws {
    image = try ImageFile.read(at: url)
    (screen, mask) = try Bezel.findScreen(in: image)
  }

  // The bezel is transparent both inside the screen and outside the device outline, so the screen
  // cutout is found by scanning out from the center until the opaque frame starts.
  private static func findScreen(in bezel: CGImage) throws -> (CGRect, CGImage) {
    let width = bezel.width
    let height = bezel.height
    var alpha = [UInt8](repeating: 0, count: width * height)
    guard
      let context = CGContext(
        data: &alpha,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width,
        space: CGColorSpaceCreateDeviceGray(),
        bitmapInfo: CGImageAlphaInfo.alphaOnly.rawValue
      )
    else { throw ToolError("Cannot inspect the bezel") }
    context.draw(bezel, in: CGRect(x: 0, y: 0, width: width, height: height))

    let centerX = width / 2
    let centerY = height / 2
    let opaque: (Int, Int) -> Bool = { x, y in alpha[y * width + x] > 127 }
    guard !opaque(centerX, centerY) else {
      throw ToolError("The bezel has no transparent screen area")
    }

    var minX = centerX
    while minX > 0, !opaque(minX - 1, centerY) { minX -= 1 }
    var maxX = centerX
    while maxX < width - 1, !opaque(maxX + 1, centerY) { maxX += 1 }
    // The bezel paints the Dynamic Island, so the vertical scan keeps clear of the center column.
    let scanX = minX + (maxX - minX) / 4
    var minY = centerY
    while minY > 0, !opaque(scanX, minY - 1) { minY -= 1 }
    var maxY = centerY
    while maxY < height - 1, !opaque(scanX, maxY + 1) { maxY += 1 }

    // The frame does not cover the corners of the screen, so the screenshot is masked to the shape
    // of the cutout. A flood fill from the center keeps the area outside the device out.
    var coverage = [UInt8](repeating: 0, count: width * height)
    var filled = [Bool](repeating: false, count: width * height)
    let start = centerY * width + centerX
    filled[start] = true
    coverage[start] = 255 - alpha[start]
    var stack = [(centerX, centerY)]
    while let (x, y) = stack.popLast() {
      for (nextX, nextY) in [(x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)] {
        guard nextX >= 0, nextX < width, nextY >= 0, nextY < height else { continue }
        let index = nextY * width + nextX
        guard !filled[index], alpha[index] < 250 else { continue }
        filled[index] = true
        coverage[index] = 255 - alpha[index]
        stack.append((nextX, nextY))
      }
    }

    guard
      let maskContext = CGContext(
        data: &coverage,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width,
        space: CGColorSpaceCreateDeviceGray(),
        bitmapInfo: CGImageAlphaInfo.none.rawValue
      ),
      let mask = maskContext.makeImage()
    else { throw ToolError("Cannot make the screen mask") }

    let top = CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
    let rect = CGRect(
      x: top.minX,
      y: CGFloat(height) - top.maxY,
      width: top.width,
      height: top.height
    )
    return (rect, mask)
  }

  func frame(_ screenshot: CGImage) throws -> CGImage {
    guard
      let context = CGContext(
        data: nil,
        width: image.width,
        height: image.height,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
      )
    else { throw ToolError("Cannot make the framed image") }

    let bounds = CGRect(x: 0, y: 0, width: image.width, height: image.height)
    let scale = max(
      screen.width / CGFloat(screenshot.width),
      screen.height / CGFloat(screenshot.height)
    )
    let size = CGSize(
      width: CGFloat(screenshot.width) * scale,
      height: CGFloat(screenshot.height) * scale
    )
    context.saveGState()
    context.clip(to: bounds, mask: mask)
    context.draw(
      screenshot,
      in: CGRect(
        x: screen.midX - size.width / 2,
        y: screen.midY - size.height / 2,
        width: size.width,
        height: size.height
      )
    )
    context.restoreGState()
    context.draw(image, in: bounds)

    guard let framed = context.makeImage() else {
      throw ToolError("Cannot make the framed image")
    }
    return framed
  }
}

// Apple's licence does not allow the bezels to be redistributed, so a published copy of this repo
// must not carry the Bezels resource folder.
struct BezelLibrary {
  static let downloadPage = "https://developer.apple.com/design/resources/#product-bezels"

  var roots: [URL]

  init() {
    let manager = FileManager.default
    let home = manager.homeDirectoryForCurrentUser
    var roots: [URL] = []
    if let configured = ProcessInfo.processInfo.environment["DEVTOOLS_BEZELS"] {
      roots.append(URL(fileURLWithPath: configured))
    }
    roots.append(home.appending(path: "Pictures/Apple Bezels"))
    roots.append(home.appending(path: "Developer/Bezels"))
    let volumes = (try? manager.contentsOfDirectory(
      at: URL(fileURLWithPath: "/Volumes"),
      includingPropertiesForKeys: nil
    )) ?? []
    roots += volumes.filter { $0.lastPathComponent.hasPrefix("Bezel") }
    self.roots = roots.filter { manager.fileExists(atPath: $0.path) }
  }

  func colors(device: String) -> [String] {
    var found: Set<String> = []
    for root in roots {
      guard
        let files = FileManager.default.enumerator(
          at: root, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]
        )
      else { continue }
      for case let file as URL in files {
        let name = file.deletingPathExtension().lastPathComponent
        let parts = name.components(separatedBy: " - ")
        guard parts.count == 3, parts[0] == device, parts[2] == Orientation.portrait.rawValue
        else { continue }
        found.insert(parts[1])
      }
    }
    return found.sorted()
  }

  func url(device: String, color: String, orientation: Orientation) throws -> URL {
    let name = "\(device) - \(color) - \(orientation.rawValue).png"
    for root in roots {
      guard
        let files = FileManager.default.enumerator(
          at: root, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]
        )
      else { continue }
      for case let file as URL in files where file.lastPathComponent == name {
        return file
      }
    }
    throw ToolError(
      """
      Cannot find "\(name)".
      Searched: \(roots.isEmpty ? "nothing" : roots.map(\.path).joined(separator: ", "))
      Put the PNG folder in the skill's Bezels folder, and keep Apple's own file names. Apple \
      draws the art at \(Self.downloadPage).
      """
    )
  }
}

func fail(_ message: String) -> Never {
  FileHandle.standardError.write(Data((message + "\n").utf8))
  exit(1)
}

do {
  let args = Array(CommandLine.arguments.dropFirst())
  guard !args.isEmpty else {
    throw ToolError(
      "Usage: frame <image.png> [device] [colour], such as: frame shot.png \"iPhone 17 Pro\" Silver\n" +
      "       frame --list [device]  lists the colours the bezel pack holds for that device"
    )
  }

  if args[0] == "--list" {
    let wanted = args.count > 1 ? args[1] : "iPhone 17 Pro"
    let library = BezelLibrary()
    let colors = library.colors(device: wanted)
    guard !colors.isEmpty else {
      throw ToolError(
        """
        The bezel pack holds no art for "\(wanted)".
        Searched: \(library.roots.isEmpty ? "nothing" : library.roots.map(\.path).joined(separator: ", "))
        Put the PNG folder in the skill's Bezels folder, and keep Apple's own file names. Apple \
        draws the art at \(BezelLibrary.downloadPage).
        """
      )
    }
    print(colors.joined(separator: "\n"))
    exit(0)
  }
  let device = args.count > 1 ? args[1] : "iPhone 17 Pro"
  let color = args.count > 2 ? args[2] : "Silver"
  let source = URL(fileURLWithPath: args[0])
  let shot = try ImageFile.read(at: source)
  let orientation: Orientation = shot.width > shot.height ? .landscape : .portrait
  let url = try BezelLibrary().url(device: device, color: color, orientation: orientation)
  let out = source.deletingLastPathComponent()
    .appending(path: source.deletingPathExtension().lastPathComponent + " Framed.png")
  try ImageFile.write(try Bezel(at: url).frame(shot), to: out)
  print("Framed \(out.path)")
} catch let error as ToolError {
  fail(error.message)
} catch {
  fail(error.localizedDescription)
}
