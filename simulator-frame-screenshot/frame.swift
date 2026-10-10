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
      CGImageSourceGetStatusAtIndex(source, 0) == .statusComplete,
      let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
    else { throw ToolError("Cannot read the image at \(url.path)") }
    guard isComplete(url, type: CGImageSourceGetType(source) as String?) else {
      throw ToolError("The image at \(url.path) is cut off, so it cannot be framed")
    }
    let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
    let orientation = properties?[kCGImagePropertyOrientation] as? UInt32 ?? 1
    guard orientation != 1 else { return image }
    let options: [CFString: Any] = [
      kCGImageSourceCreateThumbnailFromImageAlways: true,
      kCGImageSourceCreateThumbnailWithTransform: true,
      kCGImageSourceThumbnailMaxPixelSize: max(image.width, image.height),
    ]
    guard let upright = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    else { throw ToolError("Cannot read the image at \(url.path)") }
    return upright
  }

  private static func isComplete(_ url: URL, type: String?) -> Bool {
    guard type == UTType.png.identifier || type == UTType.jpeg.identifier else { return true }
    guard let data = try? Data(contentsOf: url, options: .alwaysMapped) else { return false }
    let bytes = [UInt8](data)
    let length: (Int, Int) -> Int = { offset, count in
      (0..<count).reduce(0) { $0 << 8 | Int(bytes[offset + $1]) }
    }
    if type == UTType.png.identifier {
      var offset = 8
      while offset + 8 <= bytes.count {
        let next = offset + 12 + length(offset, 4)
        guard next <= bytes.count else { return false }
        if bytes[(offset + 4)..<(offset + 8)].elementsEqual("IEND".utf8) { return true }
        offset = next
      }
      return false
    }
    var offset = 2
    while offset + 1 < bytes.count {
      guard bytes[offset] == 0xFF else { offset += 1; continue }
      let marker = bytes[offset + 1]
      if marker == 0xD9 { return true }
      if marker == 0xFF { offset += 1; continue }
      if marker == 0x01 || (0xD0...0xD7).contains(marker) { offset += 2; continue }
      guard offset + 4 <= bytes.count else { return false }
      offset += 2 + length(offset + 2, 2)
      guard marker == 0xDA else { continue }
      while offset + 1 < bytes.count {
        if bytes[offset] == 0xFF, bytes[offset + 1] != 0x00, !(0xD0...0xD7).contains(bytes[offset + 1]) {
          break
        }
        offset += 1
      }
    }
    return false
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

enum Orientation: String, CaseIterable {
  case portrait = "Portrait"
  case landscape = "Landscape"
}

struct Bezel {
  var image: CGImage
  var screen: CGRect
  var mask: CGImage

  init(at url: URL) throws {
    image = try ImageFile.read(at: url)
    guard let found = try Bezel.findScreen(in: image) else {
      throw ToolError("The bezel at \(url.path) has no closed screen, so it cannot frame an image")
    }
    (screen, mask) = found
  }

  // The bezel is transparent both inside the screen and outside the device outline, so the screen
  // cutout is found by scanning out from the center until the opaque frame starts.
  private static func findScreen(in bezel: CGImage) throws -> (CGRect, CGImage)? {
    let width = bezel.width
    let height = bezel.height
    var alpha = [UInt8](repeating: 0, count: width * height)
    let drawn = alpha.withUnsafeMutableBytes { buffer -> Bool in
      guard
        let context = CGContext(
          data: buffer.baseAddress,
          width: width,
          height: height,
          bitsPerComponent: 8,
          bytesPerRow: width,
          space: CGColorSpaceCreateDeviceGray(),
          bitmapInfo: CGImageAlphaInfo.alphaOnly.rawValue
        )
      else { return false }
      context.draw(bezel, in: CGRect(x: 0, y: 0, width: width, height: height))
      return true
    }
    guard drawn else { throw ToolError("Cannot inspect the bezel") }

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
    let scanY = minY + (maxY - minY) / 4
    minX = centerX
    while minX > 0, !opaque(minX - 1, scanY) { minX -= 1 }
    maxX = centerX
    while maxX < width - 1, !opaque(maxX + 1, scanY) { maxX += 1 }

    // The frame does not cover the corners of the screen, so the screenshot is masked to the shape
    // of the cutout. A flood fill from the center keeps the area outside the device out.
    var coverage = [UInt8](repeating: 0, count: width * height)
    let start = centerY * width + centerX
    coverage[start] = 255
    var stack = [(centerX, centerY)]
    while let (x, y) = stack.popLast() {
      if x == 0 || y == 0 || x == width - 1 || y == height - 1 { return nil }
      for (nextX, nextY) in [(x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)] {
        let index = nextY * width + nextX
        guard coverage[index] == 0, alpha[index] < 250 else { continue }
        coverage[index] = 255
        stack.append((nextX, nextY))
      }
    }

    guard
      let provider = CGDataProvider(data: Data(coverage) as CFData),
      let mask = CGImage(
        width: width,
        height: height,
        bitsPerComponent: 8,
        bitsPerPixel: 8,
        bytesPerRow: width,
        space: CGColorSpaceCreateDeviceGray(),
        bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
        provider: provider,
        decode: nil,
        shouldInterpolate: false,
        intent: .defaultIntent
      )
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
    let wide = screenshot.colorSpace.flatMap { $0.isWideGamutRGB ? $0 : nil }
    let spaces = [wide, CGColorSpace(name: CGColorSpace.displayP3), CGColorSpace(name: CGColorSpace.sRGB)]
      .compactMap { $0 }
      .filter { wide != nil || $0.name == CGColorSpace.sRGB }
    let depth = screenshot.bitsPerComponent > 8 ? 16 : 8
    guard
      let context = spaces.lazy.compactMap({
        CGContext(
          data: nil,
          width: image.width,
          height: image.height,
          bitsPerComponent: depth,
          bytesPerRow: 0,
          space: $0,
          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
      }).first
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
    context.setFillColor(CGColor(gray: 0, alpha: 1))
    context.fill(bounds)
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

  struct Entry {
    var device: String
    var color: String
    var orientation: Orientation
    var url: URL
  }

  var roots: [URL] = []
  var searched: [String] = []
  var entries: [Entry] = []

  init() {
    let manager = FileManager.default
    let home = manager.homeDirectoryForCurrentUser
    var candidates: [URL] = []
    var configuredRoot: URL?
    if let configured = ProcessInfo.processInfo.environment["DEVTOOLS_BEZELS"], !configured.isEmpty {
      configuredRoot = URL(fileURLWithPath: configured)
      candidates.append(URL(fileURLWithPath: configured))
    }
    candidates.append(home.appending(path: "Pictures/Apple Bezels"))
    candidates.append(home.appending(path: "Developer/Bezels"))
    let volumes = (try? manager.contentsOfDirectory(
      at: URL(fileURLWithPath: "/Volumes"),
      includingPropertiesForKeys: nil
    )) ?? []
    candidates += volumes.filter { $0.lastPathComponent.lowercased().hasPrefix("bezel") }

    var seen: Set<String> = []
    for candidate in candidates {
      let root = candidate.resolvingSymlinksInPath()
      var isFolder: ObjCBool = false
      let exists = manager.fileExists(atPath: root.path, isDirectory: &isFolder)
      guard exists, isFolder.boolValue else {
        if candidate == configuredRoot {
          searched.append("\(candidate.path) (\(exists ? "not a folder" : "not found"))")
        }
        continue
      }
      guard seen.insert(root.path).inserted else { continue }
      roots.append(root)
      searched.append(candidate.path)
    }

    for root in roots {
      guard
        let files = manager.enumerator(
          at: root, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]
        )
      else { continue }
      var found: [Entry] = []
      for case let file as URL in files {
        guard
          file.pathExtension.lowercased() == "png",
          (try? file.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile == true
        else { continue }
        let parts = file.deletingPathExtension().lastPathComponent.components(separatedBy: " - ")
        guard
          parts.count == 3,
          let orientation = Orientation.allCases.first(where: { Self.same($0.rawValue, parts[2]) })
        else { continue }
        found.append(Entry(device: parts[0], color: parts[1], orientation: orientation, url: file))
      }
      entries += found.sorted {
        $0.url.path.localizedStandardCompare($1.url.path) == .orderedAscending
      }
    }
  }

  static func same(_ a: String, _ b: String) -> Bool {
    a.caseInsensitiveCompare(b) == .orderedSame
  }

  private static func unique(_ names: [String]) -> [String] {
    var seen: Set<String> = []
    return names.filter {
      seen.insert($0.precomposedStringWithCanonicalMapping.lowercased()).inserted
    }.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
  }

  func devices() -> [String] {
    Self.unique(entries.map(\.device))
  }

  func colors(device: String) -> [String] {
    Self.unique(entries.filter { Self.same($0.device, device) }.map(\.color))
  }

  func url(device: String, color: String, orientation: Orientation) throws -> URL {
    if let entry = entries.first(where: {
      Self.same($0.device, device) && Self.same($0.color, color) && $0.orientation == orientation
    }) {
      return entry.url
    }
    throw noArt("\(device) - \(color) - \(orientation.rawValue).png")
  }

  func noArt(_ name: String?) -> ToolError {
    let devices = devices()
    return ToolError(
      """
      The bezel pack holds no art\(name.map { " for \"\($0)\"" } ?? "").
      Devices: \(devices.isEmpty ? "none" : devices.joined(separator: ", "))
      Searched: \(searched.isEmpty ? "nothing" : searched.joined(separator: ", "))
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
      "Usage: frame <image.png> <device> <colour>, such as: frame shot.png \"iPhone 18 Pro\" Silver\n" +
      "       frame --list [device]  lists the devices, or the colours of one device"
    )
  }

  if args[0] == "--list" {
    guard args.count <= 2 else {
      throw ToolError(
        "Too many arguments. Put a name that has spaces in quotes, such as \"iPhone 18 Pro\"."
      )
    }
    let library = BezelLibrary()
    guard args.count > 1 else {
      let devices = library.devices()
      guard !devices.isEmpty else { throw library.noArt(nil) }
      print(devices.joined(separator: "\n"))
      exit(0)
    }
    let colors = library.colors(device: args[1])
    guard !colors.isEmpty else { throw library.noArt(args[1]) }
    print(colors.joined(separator: "\n"))
    exit(0)
  }
  guard args.count > 2 else {
    let devices = BezelLibrary().devices()
    throw ToolError(
      "Name a device and a colour: frame <image.png> <device> <colour>\n" +
      "Devices: \(devices.isEmpty ? "none" : devices.joined(separator: ", "))\n" +
      "Run frame --list <device> for its colours."
    )
  }
  guard args.count == 3 else {
    throw ToolError(
      "Too many arguments. Put a name that has spaces in quotes, such as \"iPhone 18 Pro\"."
    )
  }
  let library = BezelLibrary()
  guard let device = library.devices().first(where: { BezelLibrary.same($0, args[1]) }) else {
    throw library.noArt(args[1])
  }
  let colors = library.colors(device: device)
  guard let color = colors.first(where: { BezelLibrary.same($0, args[2]) }) else {
    throw ToolError(
      "\(device) has no colour \"\(args[2])\". Colours: \(colors.joined(separator: ", "))"
    )
  }
  let source = URL(fileURLWithPath: args[0])
  let folder = source.deletingLastPathComponent()
  let out = folder.appending(path: source.deletingPathExtension().lastPathComponent + " Framed.png")
  guard !FileManager.default.fileExists(atPath: out.path) else {
    throw ToolError("\(out.path) already exists. Move it or rename it, then run again.")
  }
  let shot = try ImageFile.read(at: source)
  let orientation: Orientation = shot.width > shot.height ? .landscape : .portrait
  let bezel = try Bezel(at: library.url(device: device, color: color, orientation: orientation))
  let framed = try bezel.frame(shot)
  let temporary = folder.appending(path: ".\(UUID().uuidString).png")
  do {
    try ImageFile.write(framed, to: temporary)
  } catch {
    try? FileManager.default.removeItem(at: temporary)
    let reason = FileManager.default.isWritableFile(atPath: folder.path) ? "" : ", because the folder is read-only"
    throw ToolError("Cannot write the image to \(out.path)\(reason)")
  }
  var result = renamex_np(temporary.path, out.path, UInt32(RENAME_EXCL))
  var code = errno
  if result != 0, code == ENOTSUP, !FileManager.default.fileExists(atPath: out.path) {
    result = rename(temporary.path, out.path)
    code = errno
  }
  guard result == 0 else {
    try? FileManager.default.removeItem(at: temporary)
    throw ToolError(
      code == EEXIST
        ? "\(out.path) already exists. Move it or rename it, then run again."
        : "Cannot save \(out.path): \(String(cString: strerror(code)))"
    )
  }
  print("Framed \(out.path)")
  let shape = (CGFloat(shot.width) / CGFloat(shot.height)) / (bezel.screen.width / bezel.screen.height)
  if abs(shape - 1) > 0.02 {
    FileHandle.standardError.write(
      Data("The image is not the shape of the \(device) screen, so its edges are cut off.\n".utf8)
    )
  }
} catch let error as ToolError {
  fail(error.message)
} catch {
  fail(error.localizedDescription)
}
